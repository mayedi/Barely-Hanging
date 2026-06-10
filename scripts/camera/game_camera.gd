class_name GameCamera
extends Camera3D
## Side-locked perspective camera (spec §8). It sits back along +Z with a low FOV so the
## 3D world reads as a flat side view, frames a fixed vertical extent (`view_height`),
## follows the player on Y (clamped so the start floor stays visible early), keeps X at
## 0, eases back as the player speeds up, and shakes on landings / falls.
##
## Follow uses a direct reference to the player (camera follow is inherently continuous);
## shake is driven by EventBus events, keeping that feedback decoupled.

var _config: GameConfig
var _target: Node = null          ## the Player; must expose get_pos() and get_speed()
var _base_dist: float = 0.0
var _cur_y: float = 0.0
var _cur_x: float = 0.0
var _cur_dist: float = 0.0
var _shake: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_config = GameDirector.config
	projection = PROJECTION_PERSPECTIVE
	fov = _config.fov_degrees
	_base_dist = (_config.view_height * 0.5) / tan(deg_to_rad(_config.fov_degrees * 0.5))
	_cur_dist = _base_dist
	_cur_y = maxf(GameDirector.get_start_pos().y, _config.cam_min_y)
	_apply_transform(Vector3.ZERO)
	EventBus.player_landed.connect(_on_landed)
	EventBus.player_fell.connect(_on_fell)
	EventBus.player_respawned.connect(_on_respawned)
	EventBus.run_reset.connect(_on_run_reset)

func setup(target: Node) -> void:
	_target = target

func _on_landed(_at: Vector2, impact: float) -> void:
	_shake = maxf(_shake, impact * _config.cam_shake_land)

func _on_fell() -> void:
	_shake = maxf(_shake, _config.cam_shake_fall)

func _on_respawned(at: Vector2) -> void:
	_cur_y = maxf(at.y, _config.cam_min_y)

func _on_run_reset() -> void:
	_cur_y = maxf(GameDirector.get_start_pos().y, _config.cam_min_y)

func _process(delta: float) -> void:
	var target_y := _cur_y
	var target_x := 0.0
	var target_dist := _base_dist
	if _target != null:
		target_y = maxf(_target.get_pos().y, _config.cam_min_y)
		# Subtle horizontal drift toward the player — reveals horizontal parallax in the
		# layered backdrop (a strong 3D depth cue) without losing the side-view framing.
		target_x = clampf(_target.get_pos().x * 0.22, -4.5, 4.5)
		var speed: float = _target.get_speed()
		# ease back up to cam_speed_zoom extra units as speed approaches ~30 u/s
		target_dist = _base_dist + clampf(speed / 30.0, 0.0, 1.0) * _config.cam_speed_zoom

	var follow := clampf(_config.cam_follow_lerp * delta, 0.0, 1.0)
	_cur_y = lerpf(_cur_y, target_y, follow)
	_cur_x = lerpf(_cur_x, target_x, follow)
	_cur_dist = lerpf(_cur_dist, target_dist, follow)

	var shake_off := Vector3.ZERO
	if _shake > 0.001:
		shake_off = Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), 0.0) * _shake
		_shake = move_toward(_shake, 0.0, delta * 4.0)
	_apply_transform(shake_off)

func _apply_transform(shake_off: Vector3) -> void:
	position = Vector3(_cur_x + shake_off.x, _cur_y + shake_off.y, _cur_dist)
	look_at(Vector3(_cur_x, _cur_y, 0.0), Vector3.UP)
