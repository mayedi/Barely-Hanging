class_name ProgressTracker
extends RefCounted
## The "dread" engine (spec §14). Owned by GameDirector. Listens (via EventBus) for
## landings; when the player rests on a checkpoint platform it saves that spot as the
## new respawn point — but only ever upward, so you can lose progress, never gain it
## for free. On a grip-fail fall the player is returned here, which is the real cost
## of climbing badly. The amount of punishment is set by checkpoint spacing in the
## level data plus `respawn_grip` in GameConfig.

var checkpoint_pos: Vector2
var _platforms: Array
var _config: GameConfig
var _start_pos: Vector2

func _init(platforms: Array, config: GameConfig, start_pos: Vector2) -> void:
	_platforms = platforms
	_config = config
	_start_pos = start_pos
	checkpoint_pos = start_pos
	EventBus.player_landed.connect(_on_player_landed)
	EventBus.run_reset.connect(_on_run_reset)

func _on_run_reset() -> void:
	checkpoint_pos = _start_pos

## On landing, find the platform we are resting on; if it's a checkpoint and higher
## than the one we have saved, advance the respawn point.
func _on_player_landed(at: Vector2, _impact: float) -> void:
	var plat := _platform_under(at)
	if plat == null:
		return
	if (plat.is_checkpoint or plat.is_ground) and at.y > checkpoint_pos.y + 0.01:
		checkpoint_pos = plat.top_center(_config.player_radius)
		EventBus.checkpoint_saved.emit(checkpoint_pos)

## The platform whose top the point `at` is standing on (within a small tolerance).
func _platform_under(at: Vector2) -> PlatformRect:
	for plat: PlatformRect in _platforms:
		var top := plat.center.y + plat.half.y
		var near_top := absf(at.y - (top + _config.player_radius)) < 0.35
		var within_x := absf(at.x - plat.center.x) <= plat.half.x + _config.player_radius
		if near_top and within_x:
			return plat
	return null
