extends CanvasLayer
## HUD (spec §10). The whole Control tree is AUTHORED in hud.tscn (editable in the editor);
## this script only listens to EventBus and updates values/colours/visibility. It never
## reads sim internals beyond what signals carry. Coaching prompts fade out for good once
## learned (flags persist across resets).

const BAR_W: float = 280.0
const PAD: float = 3.0
const FILL_W: float = BAR_W - 2.0 * PAD
const LAND_HIGH: float = 3.0   ## metres above start that counts as "landed high" for coaching

var _config: GameConfig
var _start_y: float = 0.0

@onready var _grip_fill: ColorRect = $GripBg/GripFill
@onready var _grip_state: Label = $GripState
@onready var _power_bg: ColorRect = $PowerBg
@onready var _power_fill: ColorRect = $PowerBg/PowerFill
@onready var _power_label: Label = $PowerLabel
@onready var _height_label: Label = $Height
@onready var _prompt_label: Label = $Prompt
@onready var _win_root: Control = $WinRoot

# Coaching: learned flags persist across resets so a hint never reappears once mastered.
var _learned_throw: bool = false
var _learned_pump: bool = false
var _learned_land: bool = false
var _attached: bool = false

func _ready() -> void:
	_config = GameDirector.config
	_start_y = GameDirector.get_start_pos().y
	_connect()
	_update_grip(1.0)
	_refresh_prompt()

func _connect() -> void:
	EventBus.grip_changed.connect(_update_grip)
	EventBus.aim_updated.connect(_on_aim)
	EventBus.height_changed.connect(_on_height)
	EventBus.rope_fired.connect(_on_rope_fired)
	EventBus.rope_attached.connect(_on_attached)
	EventBus.player_pumped.connect(_on_pumped)
	EventBus.player_landed.connect(_on_landed)
	EventBus.rope_dropped.connect(_on_rope_gone)
	EventBus.player_fell.connect(_on_rope_gone)
	EventBus.reached_goal.connect(_on_goal)
	EventBus.run_reset.connect(_on_reset)

func _update_grip(value: float) -> void:
	_grip_fill.size.x = FILL_W * value
	var col: Color
	var state: String
	if value <= _config.grip_critical:
		col = Color(0.9, 0.25, 0.2)
		state = "CRITICAL"
	elif value <= _config.grip_warn:
		col = Color(0.95, 0.7, 0.2)
		state = "STRAINING"
	else:
		col = Color(0.3, 0.82, 0.45)
		state = "STEADY"
	_grip_fill.color = col
	_grip_state.text = "GRIP · %s" % state
	_grip_state.add_theme_color_override("font_color", col)

func _on_aim(active: bool, power: float) -> void:
	_power_bg.visible = active
	_power_label.visible = active
	if active:
		_power_fill.size.x = FILL_W * power

func _on_height(metres: float) -> void:
	_height_label.text = "%d m" % int(roundf(metres))

func _on_rope_fired(_from: Vector2, _dir: Vector2, _power: float) -> void:
	_learned_throw = true
	_refresh_prompt()

func _on_attached(_at: Vector2, _index: int) -> void:
	_attached = true
	_refresh_prompt()

func _on_pumped() -> void:
	_learned_pump = true
	_refresh_prompt()

func _on_landed(at: Vector2, _impact: float) -> void:
	if at.y > _start_y + LAND_HIGH:
		_learned_land = true
	_refresh_prompt()

func _on_rope_gone() -> void:
	_attached = false
	_refresh_prompt()

func _on_goal() -> void:
	_win_root.visible = true
	_prompt_label.text = ""

func _on_reset() -> void:
	_attached = false
	_win_root.visible = false
	_update_grip(1.0)
	_height_label.text = "0 m"
	_refresh_prompt()

func _refresh_prompt() -> void:
	if not _learned_throw:
		_prompt_label.text = "Aim at a platform above and release — the rope grabs wherever it lands"
	elif _attached and not _learned_pump:
		_prompt_label.text = "Press A / D to pump — build your swing higher"
	elif _attached and _learned_pump and not _learned_land:
		_prompt_label.text = "Swing up, then press Space to release and land on a platform"
	else:
		_prompt_label.text = ""
