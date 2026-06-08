class_name AabbUtil
extends RefCounted
## Pure, stateless math helpers for the 2D simulation: AABB collision resolution,
## segment-vs-box tests (Liang–Barsky) and closest-point queries. All static so they
## can be reasoned about and unit-tested in isolation (spec §13). No node access.

## Resolve `p` (a box of half-size `radius`) out of every platform via least-penetration
## push, exactly as the spec's reference (§4.4). Returns the index of the platform whose
## TOP we ended up resting on, or -1 if not grounded this step. Velocity into a resolved
## face is killed by snapping prev_pos to pos on that axis.
static func resolve_aabb(p: PhysicsPoint, radius: float, platforms: Array) -> int:
	var ground_index := -1
	for plat: PlatformRect in platforms:
		var d := p.pos - plat.center
		var ox := (plat.half.x + radius) - absf(d.x)
		var oy := (plat.half.y + radius) - absf(d.y)
		if ox > 0.0 and oy > 0.0:
			if ox < oy:
				p.pos.x += ox if d.x > 0.0 else -ox
				p.prev_pos.x = p.pos.x          # kill x velocity
			else:
				p.pos.y += oy if d.y > 0.0 else -oy
				if d.y > 0.0:
					ground_index = plat.index    # pushed up => standing on this platform
				p.prev_pos.y = p.pos.y          # kill y velocity
	return ground_index

## True if `point` lies inside the box [minp, maxp] (inclusive).
static func point_in_box(point: Vector2, minp: Vector2, maxp: Vector2) -> bool:
	return point.x >= minp.x and point.x <= maxp.x and point.y >= minp.y and point.y <= maxp.y

## Liang–Barsky: does the open segment a->b pass through the box interior [minp,maxp]?
## Used (against a slightly SHRUNK box) to decide when the rope must bend round a corner
## and (against a slightly EXPANDED box) to catch a fast hook before it tunnels.
static func seg_hits_box(a: Vector2, b: Vector2, minp: Vector2, maxp: Vector2) -> bool:
	var t0 := 0.0
	var t1 := 1.0
	var dd := b - a
	var pp := [-dd.x, dd.x, -dd.y, dd.y]
	var qq := [a.x - minp.x, maxp.x - a.x, a.y - minp.y, maxp.y - a.y]
	for i in 4:
		if pp[i] == 0.0:
			if qq[i] < 0.0:
				return false                     # parallel and outside this slab
		else:
			var r: float = qq[i] / pp[i]
			if pp[i] < 0.0:
				if r > t1:
					return false
				if r > t0:
					t0 = r
			else:
				if r < t0:
					return false
				if r < t1:
					t1 = r
	return t1 > t0

## Closest point on the SURFACE (perimeter) of an axis-aligned box to `point`.
## If `point` is outside, that's the clamped point; if inside, it's projected to the
## nearest face. Used to stick the hook onto whatever surface it contacted (spec §6.2).
static func closest_point_on_box(point: Vector2, center: Vector2, half: Vector2) -> Vector2:
	var minp := center - half
	var maxp := center + half
	var clamped := Vector2(clampf(point.x, minp.x, maxp.x), clampf(point.y, minp.y, maxp.y))
	if clamped != point:
		return clamped                           # outside: nearest surface point is the clamp
	# inside: snap to nearest face
	var dl := point.x - minp.x
	var dr := maxp.x - point.x
	var db := point.y - minp.y
	var dt := maxp.y - point.y
	var m: float = min(dl, dr, db, dt)
	if m == dl:
		return Vector2(minp.x, point.y)
	if m == dr:
		return Vector2(maxp.x, point.y)
	if m == db:
		return Vector2(point.x, minp.y)
	return Vector2(point.x, maxp.y)

## The four corners of a box (min, +x, +y, max order is irrelevant to callers).
static func box_corners(center: Vector2, half: Vector2) -> Array[Vector2]:
	var minp := center - half
	var maxp := center + half
	return [minp, Vector2(maxp.x, minp.y), Vector2(minp.x, maxp.y), maxp]
