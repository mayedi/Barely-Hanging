extends Node
## Autoload "GameDirector" — owns the high-level run lifecycle and is the single
## source of truth for the active config, level data and platform rects (spec §5.2).
##
## Responsibilities:
##   * set the fixed 120 Hz physics rate (the rope/wrapping are stability-sensitive),
##   * register the input map in code (robust, no fragile project.godot hand-editing),
##   * build the typed platform list the whole sim queries,
##   * own run state (PLAYING / WON), handle reset, and the dread ProgressTracker.
## It holds NO per-frame gameplay logic — the player drives the simulation.

enum State { PLAYING, WON }

const PHYSICS_TICKS := 120

@export var config: GameConfig = preload("res://resources/default_config.tres")
@export var level_data: LevelData = preload("res://resources/levels/level_01.tres")

var state: State = State.PLAYING
var platforms: Array[PlatformRect] = []
var progress: ProgressTracker
var debug_draw: bool = false

func _ready() -> void:
	Engine.physics_ticks_per_second = PHYSICS_TICKS
	_setup_input_map()
	_build_platforms()
	progress = ProgressTracker.new(platforms, config, level_data.start_pos)
	EventBus.reached_goal.connect(_on_reached_goal)

func _build_platforms() -> void:
	platforms.clear()
	var i := 0
	for plat in level_data.platforms:
		var rect := PlatformRect.new(plat["center"], plat["size"], i)
		rect.is_ground = LevelData.flag(plat, "is_ground")
		rect.is_goal = LevelData.flag(plat, "is_goal")
		rect.is_checkpoint = LevelData.flag(plat, "is_checkpoint")
		platforms.append(rect)
		i += 1

func get_start_pos() -> Vector2:
	return level_data.start_pos

func get_checkpoint_pos() -> Vector2:
	return progress.checkpoint_pos if progress != null else level_data.start_pos

func goal_platform() -> PlatformRect:
	for plat in platforms:
		if plat.is_goal:
			return plat
	return null

func _on_reached_goal() -> void:
	state = State.WON

## Full restart to the start (R). Distinct from the automatic checkpoint respawn that
## happens on a grip-fail fall — see ProgressTracker.
func reset_run() -> void:
	state = State.PLAYING
	EventBus.run_reset.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"):
		reset_run()
	elif event.is_action_pressed("debug_toggle"):
		debug_draw = not debug_draw

# --- input map (defined here so the project has no fragile hand-authored bindings) ---
func _setup_input_map() -> void:
	_add_key("pump_left", KEY_A)
	_add_key("pump_right", KEY_D)
	_add_key("reel_in", KEY_W)
	_add_key("reel_out", KEY_S)
	_add_key("release", KEY_SPACE)
	_add_key("reset", KEY_R)
	_add_key("debug_toggle", KEY_F3)
	_add_key("pause", KEY_ESCAPE)
	_add_mouse("throw", MOUSE_BUTTON_LEFT)

func _add_key(action: StringName, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)

func _add_mouse(action: StringName, button: MouseButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
