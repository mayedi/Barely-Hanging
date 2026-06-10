class_name Rope
extends RefCounted
## The attached rope: a stack of hinges plus a length budget (spec §6.3). hinges[0] is
## the anchor; the last hinge is the active pivot the player swings around. As the rope
## bends around platform corners, hinges are pushed/popped, and the matching drop/rise in
## active length is what produces the whip and the corner release.
##
## It is pure simulation state: methods take the player PhysicsPoint as a parameter and
## never store a reference to it (keeps ownership one-way: player -> rope, no cycle).
## The distance constraint moves the player purely radially, which preserves tangential
## velocity — that conservation is the pendulum and the source of all the feel.

## One bend point. `wind` is the signed side the player was on when this corner was
## caught; the sign flipping is how we know the rope has swung back and should unwrap.
class Hinge:
	var pos: Vector2
	var wind: int
	func _init(p: Vector2, w: int = 0) -> void:
		pos = p
		wind = w

var hinges: Array[Hinge] = []
var length: float = 0.0          ## total rope budget (world units)
var anchor_platform: int = -1    ## platform the anchor sits ON — never wrapped (see wrap())
var _config: GameConfig

func _init(anchor: Vector2, total_length: float, config: GameConfig, anchor_platform_index: int = -1) -> void:
	hinges = [Hinge.new(anchor, 0)]
	length = total_length
	anchor_platform = anchor_platform_index
	_config = config

func anchor() -> Vector2:
	return hinges[0].pos

func active_pivot() -> Vector2:
	return hinges[hinges.size() - 1].pos

## Length already spent on the fixed bends between anchor and active pivot.
func consumed_length() -> float:
	var c := 0.0
	for i in range(hinges.size() - 1):
		c += hinges[i].pos.distance_to(hinges[i + 1].pos)
	return c

## Rope length still free to swing on, never below the minimum.
func active_length() -> float:
	return maxf(_config.rope_min_length, length - consumed_length())

## The distance constraint: pull the player back onto the active radius, then let the taut
## rope arrest its OUTWARD radial velocity while leaving the tangential velocity untouched
## (that conservation is the pendulum). Two safeguards keep a corner wrap physical instead
## of glitchy, no matter where the player is:
##   1. The inward reposition is capped at `max_rope_pull` per call AND moves prev_pos with
##      pos, so a sudden active-length drop (a wrap) reels the player in smoothly over a few
##      frames WITHOUT injecting the inward velocity that used to fling them to the top.
##   2. Only OUTWARD radial velocity is removed; inward motion (rope going slack, the player
##      descending / reeling out) is always free.
func solve(player: PhysicsPoint, iters: int) -> void:
	var al := active_length()
	var pv := active_pivot()
	var budget := _config.max_rope_pull
	for _i in iters:
		var d := player.pos - pv
		var dist := d.length()
		if dist > al and dist > 0.0 and budget > 0.0:
			var pull := minf(dist - al, budget)
			var corr := d * (pull / dist)
			player.pos -= corr
			player.prev_pos -= corr   # move prev WITH pos: the reposition adds no velocity
			budget -= pull
	# Taut rope: cancel outward radial velocity only. Slack (inward) motion stays free.
	var d2 := player.pos - pv
	var dist2 := d2.length()
	if dist2 > al - 0.001 and dist2 > 0.0001:
		var radial := d2 / dist2
		var radial_vel := (player.pos - player.prev_pos).dot(radial)
		if radial_vel > 0.0:
			player.prev_pos += radial * radial_vel

## Reel: W shortens (down to the minimum), S lengthens. Shortening near the bottom of a
## swing injects energy — an intentional, emergent skill move (spec §6.3).
func reel(amount: float) -> void:
	length = maxf(_config.rope_min_length, length + amount)

## Polyline for rendering, player-first: [player, activePivot, ..., anchor].
func render_points(player_pos: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(player_pos)
	for i in range(hinges.size() - 1, -1, -1):
		pts.append(hinges[i].pos)
	return pts

# --- corner wrapping (wired in by the player in M6) --------------------------
## UNWRAP first: if the player has swung back past the last corner (its winding sign
## flipped), pop it; the consumed-length recompute returns that length to the swing.
func unwrap(player: PhysicsPoint) -> void:
	while hinges.size() > 1:
		var h := hinges[hinges.size() - 1]
		var hp := hinges[hinges.size() - 2]
		var s := signf((h.pos.x - hp.pos.x) * (player.pos.y - h.pos.y) \
			- (h.pos.y - hp.pos.y) * (player.pos.x - h.pos.x))
		if s != 0.0 and int(s) != h.wind:
			var corner := h.pos
			hinges.remove_at(hinges.size() - 1)
			EventBus.rope_unwrapped.emit(corner)
		else:
			break

## WRAP: if the segment active-pivot -> player cuts through a platform interior, bend the
## rope around the best corner of that platform. At most one wrap per step; capped at
## max_hinges. Uses a slightly shrunk box so edge-grazing never false-wraps.
func wrap(player: PhysicsPoint, platforms: Array) -> void:
	if hinges.size() >= _config.max_hinges:
		return
	var a := active_pivot()
	var p := player.pos
	for plat: PlatformRect in platforms:
		# Never wrap the platform the anchor is stuck to. Its surface is coincident with the
		# anchor, so the rope always "enters" it — wrapping there has no clean graze point and
		# the sudden length drop would teleport the player to the corner. Other platforms wrap
		# normally (their graze transition is smooth).
		if plat.index == anchor_platform:
			continue
		var shrink := _config.wrap_shrink
		var minp := plat.min_corner() + Vector2(shrink, shrink)
		var maxp := plat.max_corner() - Vector2(shrink, shrink)
		if minp.x >= maxp.x or minp.y >= maxp.y:
			continue
		if not AabbUtil.seg_hits_box(a, p, minp, maxp):
			continue
		var c := _best_corner(a, p, plat, minp, maxp)
		if is_inf(c.x):
			continue
		var w := signf((c.x - a.x) * (p.y - c.y) - (c.y - a.y) * (p.x - c.x))
		hinges.append(Hinge.new(c, 1 if w == 0.0 else int(w)))
		EventBus.rope_wrapped.emit(c)
		return   # one wrap per step

## Of a platform's four (real) corners, pick the one where BOTH sub-segments avoid the
## (shrunk) interior, with the shortest total path. Returns Vector2(INF, INF) if none.
func _best_corner(a: Vector2, p: Vector2, plat: PlatformRect, minp: Vector2, maxp: Vector2) -> Vector2:
	var best := Vector2(INF, INF)
	var best_cost := INF
	for c: Vector2 in AabbUtil.box_corners(plat.center, plat.half):
		if c.distance_to(a) < 0.001 or c.distance_to(p) < 0.001:
			continue
		if AabbUtil.seg_hits_box(a, c, minp, maxp):
			continue
		if AabbUtil.seg_hits_box(c, p, minp, maxp):
			continue
		var cost := a.distance_to(c) + c.distance_to(p)
		if cost < best_cost:
			best_cost = cost
			best = c
	return best
