class_name PhysicsPoint
extends RefCounted
## A single Verlet-integrated point in the 2D simulation plane (spec §4.3).
##
## We store position and previous position; velocity is implicit in their
## difference. This is the heart of the game — the pendulum, pump and whip all
## emerge from this integration plus the rope constraint. The player and the
## in-flight hook are both PhysicsPoints.
##
## Units: `pos`/`prev_pos` are world units; gravity and injected velocities are
## per-second quantities (scaled by dt on use), NOT per-step.

var pos: Vector2
var prev_pos: Vector2

func _init(start: Vector2 = Vector2.ZERO) -> void:
	pos = start
	prev_pos = start

## Per-second velocity implied by the last step.
func velocity(dt: float) -> Vector2:
	return (pos - prev_pos) / dt

## Raw per-step displacement (pos - prev_pos). Cheap; useful for direction tests.
func step_delta() -> Vector2:
	return pos - prev_pos

## One Verlet step. `gravity` pulls -Y. `damping` < 1 bleeds energy each step
## (the player uses ~0.9945; the hook uses 1.0 so its arc is a clean projectile).
func integrate(gravity: float, damping: float, dt: float) -> void:
	var vel := (pos - prev_pos) * damping
	prev_pos = pos
	pos = pos + vel + Vector2(0.0, -gravity) * dt * dt

## Inject a per-second velocity `v` by shifting prev_pos against it (spec §4.3).
func add_velocity(v: Vector2, dt: float) -> void:
	prev_pos -= v * dt

## Hard-set the point's velocity to a per-second value `v`.
func set_velocity(v: Vector2, dt: float) -> void:
	prev_pos = pos - v * dt

## Teleport with zero velocity (used for reset / respawn).
func place(at: Vector2) -> void:
	pos = at
	prev_pos = at
