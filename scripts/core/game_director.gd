extends Node
## Autoload "GameDirector" — owns the high-level run lifecycle and is the single source of
## truth for the active config and platform rects (spec §5.2).
##
## The platform list and start position now come from the LEVEL SCENE (level.tscn calls
## set_level in its _ready, before the player simulates) rather than a data resource, so the
## level is edited by placing nodes in the editor. GameDirector just holds what the scene
## hands it, owns run state (PLAYING / WON), handles reset, and the dread ProgressTracker.

enum State { PLAYING, WON }

const PHYSICS_TICKS := 120

@export var config: GameConfig = preload("res://resources/default_config.tres")

var state: State = State.PLAYING
var platforms: Array[PlatformRect] = []
var progress: ProgressTracker
var debug_draw: bool = false

var _start_pos: Vector2 = Vector2(0, 1)

func _ready() -> void:
	Engine.physics_ticks_per_second = PHYSICS_TICKS
	_setup_input_map()
	EventBus.reached_goal.connect(_on_reached_goal)

## Called by the level scene (level.gd) at load with the platforms it contains.
func set_level(rects: Array[PlatformRect], start_pos: Vector2) -> void:
	platforms = rects
	_start_pos = start_pos
	progress = ProgressTracker.new(platforms, config, start_pos)

func get_start_pos() -> Vector2:
	return _start_pos

func get_checkpoint_pos() -> Vector2:
	return progress.checkpoint_pos if progress != null else _start_pos

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
