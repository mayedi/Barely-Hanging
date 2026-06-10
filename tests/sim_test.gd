extends Node
## Headless logic tests for the core simulation math (spec §13: pure helpers are easy to
## unit-test). Run with:
##   godot --headless --path <project> res://tests/sim_test.tscn
## Exit code = number of failures (0 = all passed). Covers Verlet, AABB resolution, the
## rope distance constraint, hook contact, and corner wrap/unwrap — the highest-risk code.

var _fail: int = 0

func _ready() -> void:
	print("=== SIM TESTS ===")
	_t_verlet()
	_t_aabb()
	_t_constraint()
	_t_pull_clamp()
	_t_no_fling()
	_t_closest_point()
	_t_seg_hits_box()
	_t_first_hit()
	_t_wrap()
	_t_no_self_wrap()
	_t_unwrap()
	_t_pump()
	_t_no_loop()
	_t_progress()
	_t_goal()
	if _fail == 0:
		print("ALL TESTS PASSED")
	else:
		printerr("FAILURES: ", _fail)
	get_tree().quit(_fail)

func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		_fail += 1
		printerr("  FAIL  ", msg)

func _approx(a: float, b: float, eps: float = 0.01) -> bool:
	return absf(a - b) <= eps

# --- tests -------------------------------------------------------------------
func _t_verlet() -> void:
	var p := PhysicsPoint.new(Vector2.ZERO)
	var dt := 1.0 / 120.0
	for _i in 120:
		p.integrate(36.0, 1.0, dt)   # 1 second of free fall, g=36
	# analytic ~ -0.5*g*t^2 = -18 (plus a small half-step offset)
	_ok(_approx(p.pos.y, -18.0, 0.5), "verlet free fall ~ -18 (got %.3f)" % p.pos.y)

func _t_aabb() -> void:
	var plat := PlatformRect.new(Vector2(0, 0), Vector2(10, 2), 7)   # top at y=1
	var p := PhysicsPoint.new(Vector2(0, 1.0))
	var gi := AabbUtil.resolve_aabb(p, 0.6, [plat])
	_ok(gi == 7, "aabb grounded on correct platform index (got %d)" % gi)
	_ok(_approx(p.pos.y, 1.6), "aabb rests at top+radius (got %.3f)" % p.pos.y)

func _t_constraint() -> void:
	var config := GameDirector.config
	var rope := Rope.new(Vector2(0, 0), 5.0, config)
	# A small overshoot (within the per-call pull budget) is corrected fully in one call.
	var p := PhysicsPoint.new(Vector2(0, -5.3))
	rope.solve(p, config.constraint_iterations)
	_ok(_approx(p.pos.distance_to(Vector2(0, 0)), 5.0, 0.001),
		"constraint pulls a small overshoot to active length (got %.4f)" % p.pos.distance_to(Vector2.ZERO))
	# Radial-only correction must not move a point already inside the radius.
	var inside := PhysicsPoint.new(Vector2(0, -3))
	rope.solve(inside, config.constraint_iterations)
	_ok(inside.pos == Vector2(0, -3), "constraint leaves slack point untouched")

## A huge overshoot (e.g. a corner wrap collapsing the rope) must NOT snap in one step — the
## inward pull is capped, so the player reels in smoothly instead of teleporting to the top.
func _t_pull_clamp() -> void:
	var config := GameDirector.config
	var rope := Rope.new(Vector2(0, 0), 5.0, config)
	var p := PhysicsPoint.new(Vector2(0, -10))            # 5 units beyond the active length
	rope.solve(p, config.constraint_iterations)
	var moved := 10.0 - p.pos.distance_to(Vector2(0, 0))
	_ok(moved <= config.max_rope_pull + 0.001 and moved > 0.0,
		"a big wrap snap is clamped (moved %.3f, cap %.3f)" % [moved, config.max_rope_pull])

## The wrap fling: a player swinging fast on a long rope when a wrap abruptly shortens it.
## The corrected solve must not inject a huge inward velocity — speed stays bounded.
func _t_no_fling() -> void:
	var config := GameDirector.config
	var dt := 1.0 / 120.0
	var rope := Rope.new(Vector2(0, 0), 15.0, config)
	var p := PhysicsPoint.new(Vector2(0, -15))
	p.prev_pos = p.pos - Vector2(24.0, 0.0) * dt          # swinging fast through the bottom
	rope.hinges.append(Rope.Hinge.new(Vector2(0, -5), 1)) # a wrap drops active length 15 -> 5
	var max_speed := 0.0
	for _s in 60:
		p.integrate(config.gravity, config.damping, dt)
		rope.solve(p, config.constraint_iterations)
		max_speed = maxf(max_speed, (p.pos - p.prev_pos).length() / dt)
	_ok(max_speed < 45.0, "wrap on a fast rope does not fling the player (max speed %.1f)" % max_speed)

func _t_closest_point() -> void:
	var c := Vector2(0, 0)
	var h := Vector2(2, 2)
	_ok(AabbUtil.closest_point_on_box(Vector2(5, 0), c, h) == Vector2(2, 0), "closest: outside clamps to face")
	_ok(AabbUtil.closest_point_on_box(Vector2(0.5, 0), c, h) == Vector2(2, 0), "closest: inside snaps to nearest face")

func _t_seg_hits_box() -> void:
	var minp := Vector2(-2, -2)
	var maxp := Vector2(2, 2)
	_ok(AabbUtil.seg_hits_box(Vector2(-5, 0), Vector2(5, 0), minp, maxp), "seg crossing box = true")
	_ok(not AabbUtil.seg_hits_box(Vector2(-5, 5), Vector2(5, 5), minp, maxp), "seg above box = false")

func _t_first_hit() -> void:
	var tc := ThrowController.new(null, null, GameDirector.config)
	var plat := tc._first_hit(Vector2(5, 9), Vector2(5, 5.5))   # toward platform index 1 (centre 5,5)
	_ok(plat != null and plat.index == 1, "hook first-hit finds platform 1")

func _t_wrap() -> void:
	var config := GameDirector.config
	var plat := PlatformRect.new(Vector2(0, 0), Vector2(4, 4), 0)   # box [-2,2]^2
	var rope := Rope.new(Vector2(0, 5), 100.0, config)             # long: no constraint interference
	var p := PhysicsPoint.new(Vector2(-3, -5))                      # anchor->player crosses the box
	rope.wrap(p, [plat])
	_ok(rope.hinges.size() == 2, "wrap inserts a hinge (size=%d)" % rope.hinges.size())
	if rope.hinges.size() == 2:
		var corner: Vector2 = rope.hinges[1].pos
		var corners := AabbUtil.box_corners(plat.center, plat.half)
		_ok(corners.has(corner), "wrap hinge sits on a real corner")

## The rope must never wrap the platform its anchor sits on — that false wrap is what
## teleported the player up when the hook landed on top of a platform.
func _t_no_self_wrap() -> void:
	var config := GameDirector.config
	var plat := PlatformRect.new(Vector2(0, 0), Vector2(4, 4), 0)
	var rope := Rope.new(Vector2(0, 5), 100.0, config, 0)   # anchor sits ON platform 0
	var p := PhysicsPoint.new(Vector2(-3, -5))              # segment crosses platform 0
	rope.wrap(p, [plat])
	_ok(rope.hinges.size() == 1, "rope never wraps its own anchor platform (no teleport)")

func _t_unwrap() -> void:
	var config := GameDirector.config
	var rope := Rope.new(Vector2(0, 5), 100.0, config)
	rope.hinges.append(Rope.Hinge.new(Vector2(-2, 2), 1))   # corner with winding +1
	# Player on the same side keeps the hinge; the opposite side flips winding -> pop.
	rope.unwrap(PhysicsPoint.new(Vector2(0, 0)))
	_ok(rope.hinges.size() == 2, "unwrap keeps hinge while winding matches")
	rope.unwrap(PhysicsPoint.new(Vector2(-10, 0)))
	_ok(rope.hinges.size() == 1, "unwrap pops hinge when winding flips")

const SWING_LEN: float = 8.0   ## test pivot at origin, so the top of the loop is y = +SWING_LEN

## Well-timed pumping must build amplitude across swings (spec §6.4). Compare the peak
## height of a pumped pendulum against an un-pumped one from the same start.
func _t_pump() -> void:
	var pumped := _swing_peak(true, 720)
	var coasting := _swing_peak(false, 720)
	_ok(pumped > coasting + 1.0,
		"pumping builds amplitude (pumped peak %.2f > coast %.2f)" % [pumped, coasting])

## A heavy, realistic swing must PLATEAU below the top — even with perfectly-timed pumping
## for a long time it can never loop over (no 360). It must still reach a useful amplitude.
func _t_no_loop() -> void:
	var peak := _swing_peak(true, 4000)
	_ok(peak < SWING_LEN * 0.75,
		"swing cannot loop over the top (peak %.2f < %.2f)" % [peak, SWING_LEN * 0.75])
	_ok(peak > -SWING_LEN * 0.2,
		"swing still builds a useful amplitude (peak %.2f)" % peak)

## Returns the highest y reached over `steps` of swinging from a fixed small displacement.
func _swing_peak(do_pump: bool, steps: int) -> float:
	var config := GameDirector.config
	var pivot := Vector2(0, 0)
	var rope := Rope.new(pivot, SWING_LEN, config)
	var p := PhysicsPoint.new(Vector2(2.0, -sqrt(SWING_LEN * SWING_LEN - 4.0)))
	var dt := 1.0 / 120.0
	var peak := p.pos.y
	for _i in steps:
		p.integrate(config.gravity, config.damping, dt)
		if do_pump:
			_pump_with_motion(p, pivot, config, dt)
		rope.solve(p, config.constraint_iterations)
		peak = maxf(peak, p.pos.y)
	return peak

## Mirror of Player._apply_pump but always perfectly timed (pushes WITH the swing).
## Checkpoints save progress and the dread respawn returns there (spec §14).
func _t_progress() -> void:
	var tracker := GameDirector.progress
	var start := GameDirector.get_start_pos()
	var radius := GameDirector.config.player_radius
	EventBus.run_reset.emit()
	_ok(tracker.checkpoint_pos == start, "checkpoint starts at start_pos")
	var cp: PlatformRect = GameDirector.platforms[2]   # (-5,10) is_checkpoint
	var cp_top := cp.center.y + cp.half.y + radius
	EventBus.player_landed.emit(Vector2(cp.center.x, cp_top), 5.0)
	_ok(tracker.checkpoint_pos.y > start.y + 1.0, "checkpoint advances on a checkpoint ledge")
	var saved := tracker.checkpoint_pos
	var nc: PlatformRect = GameDirector.platforms[1]   # (5,5) not a checkpoint
	var nc_top := nc.center.y + nc.half.y + radius
	EventBus.player_landed.emit(Vector2(nc.center.x, nc_top), 5.0)
	_ok(tracker.checkpoint_pos == saved, "non-checkpoint landing does not move the checkpoint")
	EventBus.run_reset.emit()
	_ok(tracker.checkpoint_pos == start, "reset returns the checkpoint to start")

func _t_goal() -> void:
	var g := GameDirector.goal_platform()
	_ok(g != null and g.is_goal, "goal platform exists and is flagged")

func _pump_with_motion(p: PhysicsPoint, pivot: Vector2, config: GameConfig, dt: float) -> void:
	var radial := (p.pos - pivot).normalized()
	var tangent := Vector2(-radial.y, radial.x)
	var vel := p.pos - p.prev_pos
	var d := signf(vel.dot(tangent))
	if d == 0.0:
		d = 1.0
	tangent *= d
	p.prev_pos -= tangent * config.pump_accel * dt * dt * config.pump_align_boost
