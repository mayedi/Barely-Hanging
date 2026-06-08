class_name ThrowController
extends RefCounted
## Everything about getting a rope attached: project the cursor onto the play plane,
## derive aim direction + power, draw the live arc preview with a contact reticle, fire
## the hook, and simulate its flight until it sticks to a surface or is cancelled
## (spec §6.1, §6.2). It owns the in-flight hook PhysicsPoint; the player owns the rope
## that results. Driven by the player each physics step — no _process of its own.

enum HookResult { FLYING, ATTACHED, CANCELLED }

const PREVIEW_STRIDE: int = 4   ## draw every Nth arc sample so the dotted line isn't dense

var _config: GameConfig
var _camera: Camera3D
var _aim_preview: AimPreview

# in-flight hook
var _hook: PhysicsPoint = null
var _origin: Vector2
var _steps: int = 0

# cached aim (updated while aiming, consumed by fire)
var _launch_vel: Vector2 = Vector2.ZERO
var _dir: Vector2 = Vector2.UP
var _power: float = 0.0

# attach result (read by the player when simulate_hook returns ATTACHED)
var anchor: Vector2 = Vector2.ZERO
var platform_index: int = -1

func _init(camera: Camera3D, aim_preview: AimPreview, config: GameConfig) -> void:
	_camera = camera
	_aim_preview = aim_preview
	_config = config

func has_hook() -> bool:
	return _hook != null

func hook_pos() -> Vector2:
	return _hook.pos if _hook != null else Vector2.ZERO

## Project the mouse onto the z=0 plane (spec §6.1).
func cursor_world(player_pos: Vector2) -> Vector2:
	var vp := _camera.get_viewport()
	var mouse := vp.get_mouse_position()
	var from := _camera.project_ray_origin(mouse)
	var dir := _camera.project_ray_normal(mouse)
	var hit = Plane(Vector3(0, 0, 1), 0.0).intersects_ray(from, dir)
	if hit == null:
		return player_pos
	return Vector2(hit.x, hit.y)

## While the throw button is held: recompute aim/power and refresh the preview.
## Returns the current power (0..1) so the player can drive the HUD power meter.
func update_aim(player_pos: Vector2, dt: float) -> float:
	var cursor := cursor_world(player_pos)
	var to_cursor := cursor - player_pos
	_power = clampf(to_cursor.length() / _config.power_scale, 0.0, 1.0)
	var speed := lerpf(_config.throw_min_speed, _config.throw_max_speed, _power)
	_dir = to_cursor.normalized() if to_cursor.length() > 0.001 else Vector2.UP
	_launch_vel = _dir * speed
	_build_preview(player_pos, dt)
	return _power

## Fire the hook with the cached launch velocity (spec §6.2). Same integration as the
## preview, so what you saw is what you get.
func fire(player_pos: Vector2, dt: float) -> void:
	_hook = PhysicsPoint.new(player_pos)
	_hook.set_velocity(_launch_vel, dt)
	_origin = player_pos
	_steps = 0
	_aim_preview.clear()
	EventBus.rope_fired.emit(player_pos, _dir, _power)

## Advance the hook one step; report whether it stuck, is still flying, or was cancelled.
func simulate_hook(dt: float) -> HookResult:
	if _hook == null:
		return HookResult.CANCELLED
	_hook.integrate(_config.gravity, 1.0, dt)   # projectile: no damping
	_steps += 1
	var plat := _first_hit(_hook.prev_pos, _hook.pos)
	if plat != null:
		anchor = AabbUtil.closest_point_on_box(_hook.pos, plat.center, plat.half)
		platform_index = plat.index
		_hook = null
		return HookResult.ATTACHED
	if _hook.pos.y < _origin.y - _config.hook_cancel_drop or _steps > _config.preview_steps * 2:
		_hook = null
		return HookResult.CANCELLED
	return HookResult.FLYING

func cancel() -> void:
	_hook = null
	_aim_preview.clear()

func clear_preview() -> void:
	_aim_preview.clear()

# --- internals ---------------------------------------------------------------
## First platform the step a->b contacts (expanded box catches fast hooks before they
## tunnel). On a tie, the one whose surface point is nearest the segment start.
func _first_hit(a: Vector2, b: Vector2) -> PlatformRect:
	var best: PlatformRect = null
	var best_d := INF
	var m := _config.hook_attach_margin
	for plat: PlatformRect in GameDirector.platforms:
		var minp := plat.min_corner() - Vector2(m, m)
		var maxp := plat.max_corner() + Vector2(m, m)
		if AabbUtil.point_in_box(b, minp, maxp) or AabbUtil.seg_hits_box(a, b, minp, maxp):
			var sp := AabbUtil.closest_point_on_box(b, plat.center, plat.half)
			var d := sp.distance_squared_to(a)
			if d < best_d:
				best_d = d
				best = plat
	return best

func _build_preview(player_pos: Vector2, dt: float) -> void:
	var h := PhysicsPoint.new(player_pos)
	h.set_velocity(_launch_vel, dt)
	var dots := PackedVector2Array()
	var contact := Vector2.ZERO
	var has_contact := false
	for i in _config.preview_steps:
		var prev := h.pos
		h.integrate(_config.gravity, 1.0, dt)
		var plat := _first_hit(prev, h.pos)
		if plat != null:
			contact = AabbUtil.closest_point_on_box(h.pos, plat.center, plat.half)
			has_contact = true
			dots.append(contact)
			break
		if i % PREVIEW_STRIDE == 0:
			dots.append(h.pos)
		if h.pos.y < player_pos.y - _config.hook_cancel_drop:
			break
	# Height hint only (teal above / amber below): NOT a validity gate — every hook is legal.
	var above := has_contact and contact.y > player_pos.y
	_aim_preview.show_arc(dots, contact, has_contact, above)
