extends CanvasLayer
## Pause + Options menu (Escape). Pauses the SceneTree and presents Resume / Options / Exit,
## with Options split into Video / Sound / Controls categories. The whole layer is
## PROCESS_MODE_ALWAYS so it runs and receives input while the game is paused. Transitions
## (fade + scale) and button pops keep it fluid. Values are applied & persisted via Settings.

const ACCENT: Color = Color(0.97, 0.74, 0.42)
const TEXT: Color = Color(0.93, 0.91, 0.87)

@onready var _root: Control = $Root
@onready var _dim: TextureRect = $Root/Dim
@onready var _main_page: Control = $Root/MainPage
@onready var _main_panel: Control = $Root/MainPage/Center/MainPanel
@onready var _options_page: Control = $Root/OptionsPage
@onready var _options_panel: Control = $Root/OptionsPage/Center/OptionsPanel

@onready var _resume_btn: Button = $Root/MainPage/Center/MainPanel/Margin/VBox/ResumeBtn
@onready var _options_btn: Button = $Root/MainPage/Center/MainPanel/Margin/VBox/OptionsBtn
@onready var _exit_btn: Button = $Root/MainPage/Center/MainPanel/Margin/VBox/ExitBtn

@onready var _video_btn: Button = $Root/OptionsPage/Center/OptionsPanel/Margin/VBox/Body/Categories/VideoBtn
@onready var _sound_btn: Button = $Root/OptionsPage/Center/OptionsPanel/Margin/VBox/Body/Categories/SoundBtn
@onready var _controls_btn: Button = $Root/OptionsPage/Center/OptionsPanel/Margin/VBox/Body/Categories/ControlsBtn
@onready var _back_btn: Button = $Root/OptionsPage/Center/OptionsPanel/Margin/VBox/BackBtn

@onready var _content := $Root/OptionsPage/Center/OptionsPanel/Margin/VBox/Body/Content
@onready var _video_content: Control = _content.get_node("VideoContent")
@onready var _sound_content: Control = _content.get_node("SoundContent")
@onready var _controls_content: Control = _content.get_node("ControlsContent")

@onready var _display_mode: OptionButton = _video_content.get_node("ModeRow/DisplayMode")
@onready var _resolution: OptionButton = _video_content.get_node("ResRow/Resolution")
@onready var _volume: HSlider = _sound_content.get_node("VolRow/VolBox/Volume")
@onready var _volume_value: Label = _sound_content.get_node("VolRow/VolBox/VolumeValue")

var _open: bool = false
var _on_options: bool = false
var _category_buttons: Array[Button] = []
var _category_contents: Array[Control] = []
var _hud: CanvasLayer = null

func _ready() -> void:
	_root.visible = false
	_hud = get_parent().get_node_or_null("HUD") as CanvasLayer
	_category_buttons = [_video_btn, _sound_btn, _controls_btn]
	_category_contents = [_video_content, _sound_content, _controls_content]
	_populate_video()
	_populate_sound()
	_connect()
	_select_category(0)
	_maybe_preview()

## Dev-only: `--menu` / `--menu-options` shows the menu (without pausing) so it can be
## screenshotted. No effect in normal play.
func _maybe_preview() -> void:
	var args := OS.get_cmdline_args()
	var options := args.has("--menu-options") or args.has("--menu-sound") or args.has("--menu-controls")
	if not (args.has("--menu") or options):
		return
	_root.visible = true
	_dim.modulate.a = 1.0
	if _hud != null:
		_hud.visible = false
	if options:
		_on_options = true
		_main_page.visible = false
		_options_page.visible = true
		_options_page.modulate.a = 1.0
		_select_category(2 if args.has("--menu-controls") else (1 if args.has("--menu-sound") else 0))

func _connect() -> void:
	_resume_btn.pressed.connect(close)
	_options_btn.pressed.connect(_show_options)
	_exit_btn.pressed.connect(func() -> void: get_tree().quit())
	_back_btn.pressed.connect(_show_main)
	for i in _category_buttons.size():
		_category_buttons[i].pressed.connect(_select_category.bind(i))
	_display_mode.item_selected.connect(_on_display_mode)
	_resolution.item_selected.connect(Settings.set_resolution)
	_volume.value_changed.connect(_on_volume)

# --- options population -------------------------------------------------------
func _populate_video() -> void:
	_display_mode.add_item("Windowed")
	_display_mode.add_item("Fullscreen")
	_display_mode.select(1 if Settings.fullscreen else 0)
	for label in Settings.RESOLUTION_LABELS:
		_resolution.add_item(label)
	_resolution.select(Settings.resolution_index)
	_resolution.disabled = Settings.fullscreen

func _populate_sound() -> void:
	_volume.min_value = 0.0
	_volume.max_value = 1.0
	_volume.step = 0.05
	_volume.value = Settings.master_volume
	_update_volume_label(Settings.master_volume)

# --- option callbacks ---------------------------------------------------------
func _on_display_mode(index: int) -> void:
	Settings.set_fullscreen(index == 1)
	_resolution.disabled = Settings.fullscreen

func _on_volume(value: float) -> void:
	Settings.set_volume(value)
	_update_volume_label(value)

func _update_volume_label(value: float) -> void:
	_volume_value.text = "%d%%" % roundi(value * 100.0)

# --- category switching -------------------------------------------------------
func _select_category(index: int) -> void:
	for i in _category_buttons.size():
		var on := i == index
		_category_contents[i].visible = on
		_category_buttons[i].add_theme_color_override("font_color", ACCENT if on else TEXT)

# --- open / close / page transitions -----------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if not _open:
			open()
		elif _on_options:
			_show_main()
		else:
			close()
		get_viewport().set_input_as_handled()

func open() -> void:
	if _open:
		return
	_open = true
	_on_options = false
	get_tree().paused = true
	if _hud != null:
		_hud.visible = false
	_root.visible = true
	_main_page.visible = true
	_main_page.modulate.a = 1.0
	_options_page.visible = false
	_dim.modulate.a = 0.0
	_pop_in(_main_panel)
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_dim, "modulate:a", 1.0, 0.18)
	_resume_btn.grab_focus()

func close() -> void:
	if not _open:
		return
	_open = false
	var panel: Control = _options_panel if _on_options else _main_panel
	var page: Control = _options_page if _on_options else _main_page
	var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_dim, "modulate:a", 0.0, 0.14)
	tw.tween_property(page, "modulate:a", 0.0, 0.14)
	tw.tween_property(panel, "scale", Vector2(0.95, 0.95), 0.14)
	await tw.finished
	_root.visible = false
	if _hud != null:
		_hud.visible = true
	get_tree().paused = false

func _show_options() -> void:
	_on_options = true
	_fade_swap(_main_page, _options_page, _options_panel)

func _show_main() -> void:
	_on_options = false
	_fade_swap(_options_page, _main_page, _main_panel)

func _fade_swap(from_page: Control, to_page: Control, to_panel: Control) -> void:
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(from_page, "modulate:a", 0.0, 0.1)
	tw.tween_callback(func() -> void:
		from_page.visible = false
		to_page.visible = true
		to_page.modulate.a = 0.0)
	_pop_in(to_panel)
	tw.tween_property(to_page, "modulate:a", 1.0, 0.14)

func _pop_in(panel: Control) -> void:
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.94, 0.94)
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.24)
