class_name Player
extends Node3D
## The player: owns the simulated PhysicsPoint and the active Rope, and runs the per-step
## simulation against the level (spec §5.6). The Node3D transform is pure render — it
## follows the 2D point each frame; the simulation never reads the node. State is a small
## set of flags (grounded / has-rope / aiming) rather than a heavyweight FSM, as the spec
## explicitly permits (§5.6).
##
## Per attached step the order matters (spec §6.3): integrate -> pump -> reel ->
## solve(N) -> unwrap -> wrap -> solve(2), then collision. Pump and wrapping are added in
## later milestones at their marked spots.

var config: GameConfig
var _point: PhysicsPoint
var _phys_dt: float = 1.0 / 120.0

var _grounded: bool = false
var _ground_index: int = -1
var _last_height_int: int = 2147483647

var _rope: Rope = null
var _aiming: bool = false
var _grip: float = 1.0
var _grip_critical_latched: bool = false

# References handed in by the composition root (Main._wire).
var _camera: GameCamera = null
var _rope_view: RopeView = null
var _aim_preview: AimPreview = null
var _throw: ThrowController = null

@onready var _creature: Creature = $Visual/Creature

func _ready() -> void:
	config = GameDirector.config
	_phys_dt = 1.0 / float(Engine.physics_ticks_per_second)
	_point = PhysicsPoint.new(GameDirector.get_start_pos())
	EventBus.run_reset.connect(_on_run_reset)
	_update_visual()

func setup(camera: GameCamera, rope_view: RopeView, aim_preview: AimPreview) -> void:
	_camera = camera
	_rope_view = rope_view
	_aim_preview = aim_preview
	if camera != null and aim_preview != null:
		_throw = ThrowController.new(camera, aim_preview, config)
	_maybe_demo()

# --- queries used by the camera (continuous follow is inherently coupled) -----
func get_pos() -> Vector2:
	return _point.pos

func get_speed() -> float:
	return _velocity().length()

func _velocity() -> Vector2:
	return _point.step_delta() / _phys_dt

## Snapshot for the debug overlay (spec §13). Read-only — the overlay is a dev tool.
func get_debug() -> Dictionary:
	var hinges := PackedVector2Array()
	var active_len := 0.0
	if _rope != null:
		hinges = _rope.render_points(_point.pos)   # [player, pivot.., anchor]
		active_len = _rope.active_length()
	return {
		"pos": _point.pos,
		"vel": _velocity(),
		"grip": _grip,
		"grounded": _grounded,
		"has_rope": _rope != null,
		"aiming": _aiming,
		"hinge_count": (_rope.hinges.size() if _rope != null else 0),
		"active_len": active_len,
		"hinges": hinges,
	}

# --- main loop ---------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if EffectsManager.is_hitstopped():        # catch-freeze: render but don't step (spec §9.2)
		_update_visual()
		return
	if GameDirector.state != GameDirector.State.PLAYING:
		_update_visual()
		return
	_simulate(delta)
	_update_visual()

func _simulate(delta: float) -> void:
	_handle_input(delta)
	_advance_hook(delta)

	_point.integrate(config.gravity, config.damping, delta)
	if _rope != null:
		_apply_pump(delta)
		_apply_reel(delta)
		_rope.solve(_point, config.constraint_iterations)
		_rope.unwrap(_point)
		_rope.wrap(_point, GameDirector.platforms)
		_rope.solve(_point, 2)   # settle the hard radial snap after a wrap (spec §6.3)

	var vy_before := _point.step_delta().y / delta
	var was_grounded := _grounded
	_ground_index = AabbUtil.resolve_aabb(_point, config.player_radius, GameDirector.platforms)
	_grounded = _ground_index >= 0
	if _grounded and not was_grounded:
		_on_landed(vy_before)

	_update_grip(delta)
	_emit_fast_motion()
	_check_win()
	_report_height()

## Speed-gated pulse that drives the motion trail and wind whoosh. Consumers (Effects /
## Audio managers) apply their own cooldowns, so emitting per fast frame is fine.
func _emit_fast_motion() -> void:
	if _grounded:
		return
	var spd := _velocity().length()
	if spd >= config.trail_speed:
		EventBus.fast_motion.emit(_point.pos, spd)

# --- input -------------------------------------------------------------------
func _handle_input(delta: float) -> void:
	if _throw == null:
		return
	if Input.is_action_just_pressed("throw") and not _throw.has_hook():
		_aiming = true
	if _aiming:
		var power := _throw.update_aim(_point.pos, delta)
		EventBus.aim_updated.emit(true, power)
		if Input.is_action_just_released("throw"):
			_throw.fire(_point.pos, delta)
			_aiming = false
			EventBus.aim_updated.emit(false, 0.0)
	if Input.is_action_just_pressed("release"):
		_drop_rope()

## Tangential, amplitude-building pump (spec §6.4). Pushing WITH the current swing adds
## energy (boost); pushing against only brakes a little. Timing it across swings is the
## skill. Works grounded too, so A/D walks the player off a ledge into the first swing.
func _apply_pump(delta: float) -> void:
	var left := Input.is_action_pressed("pump_left")
	var right := Input.is_action_pressed("pump_right")
	if not (left or right):
		return
	var pv := _rope.active_pivot()
	var radial := _point.pos - pv
	if radial.length() < 0.001:
		return
	radial = radial.normalized()
	var tangent := Vector2(-radial.y, radial.x)
	var d := 1.0 if right else -1.0     # A = -1, D = +1
	tangent *= d
	var vel := _point.pos - _point.prev_pos
	var along := vel.dot(tangent)
	var boost := config.pump_align_boost if along > 0.0 else config.pump_counter
	_point.prev_pos -= tangent * config.pump_accel * delta * delta * boost
	EventBus.player_pumped.emit()

func _apply_reel(delta: float) -> void:
	var dir := 0.0
	if Input.is_action_pressed("reel_in"):
		dir -= 1.0
	if Input.is_action_pressed("reel_out"):
		dir += 1.0
	if dir != 0.0:
		_rope.reel(dir * config.reel_speed * delta)

# --- hook / rope -------------------------------------------------------------
func _advance_hook(delta: float) -> void:
	if _throw == null or not _throw.has_hook():
		return
	var res := _throw.simulate_hook(delta)
	if res == ThrowController.HookResult.ATTACHED:
		_attach_rope(_throw.anchor, _throw.platform_index)

func _attach_rope(at: Vector2, platform_index: int) -> void:
	# Chaining: a fresh hook replaces any existing rope with no rest (spec §3 mastery path).
	_rope = Rope.new(at, _point.pos.distance_to(at), config)
	EventBus.rope_attached.emit(at, platform_index)

func _drop_rope() -> void:
	if _rope == null:
		return
	_rope = null
	EventBus.rope_dropped.emit()   # keep current momentum — no artificial boost (spec §6.6)

# --- grip / endurance (spec §6.5) --------------------------------------------
func _update_grip(delta: float) -> void:
	if _grounded:
		_set_grip(minf(1.0, _grip + config.grip_restore * delta))
		if _grip > config.grip_warn:
			_grip_critical_latched = false   # re-arm the one-shot critical warning
	elif _rope != null:
		_set_grip(_grip - config.grip_drain * delta)
		if _grip <= 0.0:
			_fail()

func _set_grip(value: float) -> void:
	var v := clampf(value, 0.0, 1.0)
	if v == _grip:
		return
	_grip = v
	EventBus.grip_changed.emit(_grip)
	if _grip < config.grip_critical and not _grip_critical_latched:
		_grip_critical_latched = true
		EventBus.grip_critical.emit()

## Grip ran out while hanging: drop the rope, fall, and (the dread cost, spec §14) snap
## back to the last checkpoint, losing all the height climbed above it.
func _fail() -> void:
	_rope = null
	EventBus.rope_dropped.emit()
	EventBus.player_fell.emit()
	if config.fall_to_checkpoint:
		_respawn_at(GameDirector.get_checkpoint_pos())

func _respawn_at(pos: Vector2) -> void:
	_point.place(pos)
	_grounded = false
	_ground_index = -1
	_grip_critical_latched = false
	_set_grip(config.respawn_grip)
	EventBus.player_respawned.emit(pos)

# --- events ------------------------------------------------------------------
func _on_landed(vy_before: float) -> void:
	var impact := maxf(0.0, -vy_before)
	if impact >= config.land_impact_threshold:
		EventBus.player_landed.emit(_point.pos, impact)

func _check_win() -> void:
	var goal := GameDirector.goal_platform()
	if goal == null:
		return
	if _point.pos.distance_to(goal.center) < goal.half.x + config.goal_radius_bonus \
			and _point.pos.y > goal.center.y - config.goal_y_tolerance:
		EventBus.reached_goal.emit()

func _report_height() -> void:
	var h := _point.pos.y - GameDirector.get_start_pos().y
	var hi := int(roundf(h))
	if hi != _last_height_int:
		_last_height_int = hi
		EventBus.height_changed.emit(h)

# --- lifecycle ---------------------------------------------------------------
func _on_run_reset() -> void:
	_point.place(GameDirector.get_start_pos())
	_grounded = false
	_ground_index = -1
	_rope = null
	_aiming = false
	_grip = 1.0
	_grip_critical_latched = false
	_last_height_int = 2147483647
	EventBus.grip_changed.emit(1.0)
	if _throw != null:
		_throw.cancel()
	if _aim_preview != null:
		_aim_preview.clear()
	_update_visual()

# --- render ------------------------------------------------------------------
func _update_visual() -> void:
	global_position = Vector3(_point.pos.x, _point.pos.y, 0.0)
	if _creature != null:
		_creature.react(_velocity())
	if _rope_view == null:
		return
	if _throw != null and _throw.has_hook():
		_rope_view.set_rope(PackedVector2Array([_point.pos, _throw.hook_pos()]))
	elif _rope != null:
		_rope_view.set_rope(_rope.render_points(_point.pos))
	else:
		_rope_view.clear()

# --- dev demo (visual verification only) -------------------------------------
## Dev demos (visual verification only, no effect in normal play):
##   --demo       drop into a mid-air swing (confirms rope + pendulum render)
##   --demo-wrap  force the rope to bend around a platform corner + turn the debug overlay
##                on (confirms wrapping + the hinge/active-length debug draw)
func _maybe_demo() -> void:
	var args := OS.get_cmdline_args()
	if args.has("--demo-wrap"):
		_demo_wrap()
	elif args.has("--demo"):
		_demo_swing()

func _demo_swing() -> void:
	var plats := GameDirector.platforms
	if plats.size() <= 4:
		return
	var plat: PlatformRect = plats[4]
	var start := Vector2(4.0, 21.0)
	_point.place(start)
	var a := AabbUtil.closest_point_on_box(start, plat.center, plat.half)
	_rope = Rope.new(a, start.distance_to(a), config)
	_grounded = false
	EventBus.rope_attached.emit(a, 4)

func _demo_wrap() -> void:
	# Anchor at a top corner of platform 2 with the player below-left, so the straight
	# segment crosses the platform interior and the rope must bend round its corner.
	var anchor := Vector2(-0.5, 10.7)
	var start := Vector2(-9.5, 6.0)
	_point.place(start)
	_rope = Rope.new(anchor, 30.0, config)
	_grounded = false
	EventBus.rope_attached.emit(anchor, 2)
	_rope.wrap(_point, GameDirector.platforms)
	GameDirector.debug_draw = true
