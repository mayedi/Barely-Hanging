extends Node
## Autoload "Settings" — loads, applies and persists user options (video + audio) to
## user://settings.cfg. Applied on startup before the menu exists; the options UI calls the
## set_* methods, which apply immediately and save.

const PATH: String = "user://settings.cfg"
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]
const RESOLUTION_LABELS: Array[String] = ["1280 × 720   (HD)", "1920 × 1080   (Full HD)"]

var resolution_index: int = 0
var fullscreen: bool = false
var master_volume: float = 0.8   ## linear 0..1

func _ready() -> void:
	_load()
	apply_display()
	apply_volume()

func apply_display() -> void:
	# The editor's embedded game window can't be moved/resized/fullscreened (it logs
	# "Embedded window can't be ..." warnings). Skip the real-window changes there; the
	# choices are still saved and take effect in a standalone / exported build.
	if get_window().is_embedded():
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var res := RESOLUTIONS[clampi(resolution_index, 0, RESOLUTIONS.size() - 1)]
		DisplayServer.window_set_size(res)
		_center_window(res)

func apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, master_volume <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(master_volume, 0.001, 1.0)))

func set_resolution(index: int) -> void:
	resolution_index = clampi(index, 0, RESOLUTIONS.size() - 1)
	apply_display()
	_save()

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply_display()
	_save()

func set_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	apply_volume()
	_save()

func _center_window(res: Vector2i) -> void:
	var screen := DisplayServer.window_get_current_screen()
	var origin := DisplayServer.screen_get_position(screen)
	var screen_size := DisplayServer.screen_get_size(screen)
	DisplayServer.window_set_position(origin + (screen_size - res) / 2)

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "resolution_index", resolution_index)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.save(PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	resolution_index = int(cfg.get_value("video", "resolution_index", 0))
	fullscreen = bool(cfg.get_value("video", "fullscreen", false))
	master_volume = float(cfg.get_value("audio", "master_volume", 0.8))
