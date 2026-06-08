extends CanvasLayer
## HUD (spec §10). Listens to EventBus and never reads sim internals beyond what signals
## carry. Builds its controls in code for a robust, resolution-independent layout. Shows
## the grip meter, the aiming power meter, the height readout, staged coaching prompts
## (which fade out for good once learned), a controls reference, and the summit panel.

const BAR_W: float = 280.0
const BAR_H: float = 24.0
const PAD: float = 3.0
const LAND_HIGH: float = 3.0   ## metres above start that counts as "landed high" for coaching

var _config: GameConfig
var _start_y: float = 0.0

var _grip_fill: ColorRect
var _grip_state: Label
var _power_root: ColorRect
var _power_fill: ColorRect
var _power_label: Label
var _height_label: Label
var _prompt_label: Label
var _win_root: Control

# Coaching: learned flags persist across resets so a hint never reappears once mastered.
var _learned_throw: bool = false
var _learned_pump: bool = false
var _learned_land: bool = false
var _attached: bool = false

func _ready() -> void:
	_config = GameDirector.config
	_start_y = GameDirector.get_start_pos().y
	_build_grip()
	_build_power()
	_build_height()
	_build_prompt()
	_build_controls()
	_build_win()
	_connect()
	_update_grip(1.0)
	_refresh_prompt()

# --- construction ------------------------------------------------------------
func _build_grip() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	_anchor_bl(bg, 28.0, 28.0, BAR_W, BAR_H)
	add_child(bg)
	_grip_fill = ColorRect.new()
	_grip_fill.position = Vector2(PAD, PAD)
	_grip_fill.size = Vector2(BAR_W - 2.0 * PAD, BAR_H - 2.0 * PAD)
	bg.add_child(_grip_fill)
	_grip_state = Label.new()
	_anchor_bl(_grip_state, 28.0, 28.0 + BAR_H + 4.0, BAR_W, 22.0)
	add_child(_grip_state)

func _build_power() -> void:
	_power_root = ColorRect.new()
	_power_root.color = Color(0, 0, 0, 0.5)
	_anchor_br(_power_root, 28.0, 28.0, BAR_W, BAR_H)
	add_child(_power_root)
	_power_fill = ColorRect.new()
	_power_fill.color = Color(0.2, 0.82, 0.92)
	_power_fill.position = Vector2(PAD, PAD)
	_power_fill.size = Vector2(0.0, BAR_H - 2.0 * PAD)
	_power_root.add_child(_power_fill)
	var label := Label.new()
	label.text = "POWER"
	_anchor_br(label, 28.0, 28.0 + BAR_H + 4.0, BAR_W, 22.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_power_root.visible = false
	add_child(label)
	label.visible = false
	_power_label = label

func _build_height() -> void:
	_height_label = Label.new()
	_anchor_tc(_height_label, 18.0, 220.0, 44.0)
	_height_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_height_label.add_theme_font_size_override("font_size", 34)
	_height_label.text = "0 m"
	add_child(_height_label)

func _build_prompt() -> void:
	_prompt_label = Label.new()
	_anchor_tc(_prompt_label, 74.0, 720.0, 34.0)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	add_child(_prompt_label)

func _build_controls() -> void:
	var label := Label.new()
	label.anchor_left = 0.0
	label.anchor_top = 0.0
	label.offset_left = 24.0
	label.offset_top = 18.0
	label.offset_right = 520.0
	label.offset_bottom = 80.0
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95, 0.8))
	label.text = "aim: mouse   throw: hold/release L-click   pump: A / D\nreel: W / S   release: Space   reset: R"
	add_child(label)

func _build_win() -> void:
	_win_root = Control.new()
	_win_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_win_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_win_root)
	var panel := ColorRect.new()
	panel.color = Color(0.05, 0.06, 0.09, 0.82)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -260.0
	panel.offset_right = 260.0
	panel.offset_top = -90.0
	panel.offset_bottom = 90.0
	_win_root.add_child(panel)
	var title := Label.new()
	title.text = "SUMMIT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.offset_bottom = -30.0
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.98, 0.82, 0.35))
	panel.add_child(title)
	var sub := Label.new()
	sub.text = "press R to climb again"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_FULL_RECT)
	sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub.offset_top = 56.0
	panel.add_child(sub)
	_win_root.visible = false

# --- signals -----------------------------------------------------------------
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
	_grip_fill.size.x = (BAR_W - 2.0 * PAD) * value
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
	_power_root.visible = active
	_power_label.visible = active
	if active:
		_power_fill.size.x = (BAR_W - 2.0 * PAD) * power

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
	_clear_prompt()

func _on_reset() -> void:
	_attached = false
	_win_root.visible = false
	_update_grip(1.0)
	_height_label.text = "0 m"
	_refresh_prompt()

# --- coaching ----------------------------------------------------------------
func _refresh_prompt() -> void:
	if not _learned_throw:
		_prompt_label.text = "Aim at a platform above and release — the rope grabs wherever it lands"
	elif _attached and not _learned_pump:
		_prompt_label.text = "Press A / D to pump — build your swing higher"
	elif _attached and _learned_pump and not _learned_land:
		_prompt_label.text = "Swing up, then press Space to release and land on a platform"
	else:
		_prompt_label.text = ""

func _clear_prompt() -> void:
	_prompt_label.text = ""

# --- layout helpers ----------------------------------------------------------
func _anchor_bl(c: Control, x: float, y_from_bottom: float, w: float, h: float) -> void:
	c.anchor_left = 0.0
	c.anchor_right = 0.0
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = x
	c.offset_right = x + w
	c.offset_top = -(y_from_bottom + h)
	c.offset_bottom = -y_from_bottom

func _anchor_br(c: Control, x: float, y_from_bottom: float, w: float, h: float) -> void:
	c.anchor_left = 1.0
	c.anchor_right = 1.0
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_right = -x
	c.offset_left = -(x + w)
	c.offset_top = -(y_from_bottom + h)
	c.offset_bottom = -y_from_bottom

func _anchor_tc(c: Control, y_from_top: float, w: float, h: float) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.0
	c.anchor_bottom = 0.0
	c.offset_left = -w * 0.5
	c.offset_right = w * 0.5
	c.offset_top = y_from_top
	c.offset_bottom = y_from_top + h
