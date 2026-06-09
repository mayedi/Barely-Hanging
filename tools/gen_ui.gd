extends Node
## One-time build tool: generates the polished menu Theme (resources/ui/menu_theme.tres) and
## the vignette overlay (assets/ui/menu_bg.png). Warm "dawn" palette to match the game. Run:
##   godot --headless --path . res://tools/gen_ui.tscn
## Not part of the shipped game.

# --- palette -----------------------------------------------------------------
const BG_PANEL := Color(0.09, 0.08, 0.11, 0.96)
const BG_INNER := Color(0.13, 0.115, 0.15, 0.98)
const BORDER := Color(0.96, 0.74, 0.45, 0.22)
const BTN_NORMAL := Color(0.18, 0.16, 0.20, 0.0)     # transparent: list-style buttons
const BTN_HOVER := Color(0.26, 0.22, 0.27, 0.85)
const BTN_PRESSED := Color(0.14, 0.12, 0.16, 0.9)
const ACCENT := Color(0.97, 0.74, 0.42)
const ACCENT_SOFT := Color(0.98, 0.85, 0.62)
const TEXT := Color(0.93, 0.91, 0.87)
const TEXT_MUTED := Color(0.62, 0.60, 0.58)
const TRACK := Color(0.22, 0.20, 0.24, 1.0)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://resources/ui"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui"))
	ResourceSaver.save(_build_theme(), "res://resources/ui/menu_theme.tres")
	_vignette(640, 360).save_png("res://assets/ui/menu_bg.png")
	print("ui assets done")
	get_tree().quit()

# --- theme -------------------------------------------------------------------
func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18

	# Buttons (Resume / Options / Exit / Back) — clean list style with an accent on hover.
	t.set_stylebox("normal", "Button", _flat(BTN_NORMAL, 10, 0, BORDER, 12, 22))
	t.set_stylebox("hover", "Button", _flat(BTN_HOVER, 10, 0, BORDER, 12, 22))
	t.set_stylebox("pressed", "Button", _flat(BTN_PRESSED, 10, 0, BORDER, 12, 22))
	t.set_stylebox("focus", "Button", _empty())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT_SOFT)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_font_size("font_size", "Button", 21)

	# OptionButton dropdowns — boxed look so they read as inputs.
	t.set_stylebox("normal", "OptionButton", _flat(BG_INNER, 8, 1, BORDER, 8, 14))
	t.set_stylebox("hover", "OptionButton", _flat(BTN_HOVER, 8, 1, ACCENT * Color(1, 1, 1, 0.5), 8, 14))
	t.set_stylebox("pressed", "OptionButton", _flat(BTN_PRESSED, 8, 1, BORDER, 8, 14))
	t.set_stylebox("focus", "OptionButton", _empty())
	t.set_color("font_color", "OptionButton", TEXT)
	t.set_color("font_hover_color", "OptionButton", ACCENT_SOFT)
	t.set_font_size("font_size", "OptionButton", 18)

	# Dropdown popup.
	t.set_stylebox("panel", "PopupMenu", _flat(Color(0.11, 0.10, 0.13, 0.99), 8, 1, BORDER, 8, 10))
	t.set_stylebox("hover", "PopupMenu", _flat(BTN_HOVER, 6, 0, BORDER, 6, 10))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", ACCENT_SOFT)
	t.set_constant("v_separation", "PopupMenu", 6)
	t.set_font_size("font_size", "PopupMenu", 18)

	# Panels.
	var panel := _flat(BG_PANEL, 18, 1, BORDER, 0, 0)
	panel.shadow_size = 26
	panel.shadow_color = Color(0, 0, 0, 0.45)
	panel.shadow_offset = Vector2(0, 10)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	# Sliders (master volume) — accent fill on a dark track.
	var track := _flat(TRACK, 4, 0, BORDER, 0, 0)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", _flat(ACCENT, 4, 0, BORDER, 0, 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", _flat(ACCENT_SOFT, 4, 0, BORDER, 0, 0))
	var grab := _circle_tex(11, ACCENT_SOFT)
	t.set_icon("grabber", "HSlider", grab)
	t.set_icon("grabber_highlight", "HSlider", _circle_tex(12, Color(1, 1, 1)))
	t.set_icon("grabber_disabled", "HSlider", grab)

	# Labels.
	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Label", 18)

	# Container spacing.
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 16)
	return t

# --- stylebox helpers --------------------------------------------------------
func _flat(bg: Color, radius: int, border_w: int, border_col: Color, pad_v: int, pad_h: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border_w > 0:
		s.set_border_width_all(border_w)
		s.border_color = border_col
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	return s

func _empty() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()

func _circle_tex(radius_px: int, color: Color) -> ImageTexture:
	var size := radius_px * 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(radius_px, radius_px)
	for y in size:
		for x in size:
			var a := clampf(float(radius_px) - Vector2(x + 0.5, y + 0.5).distance_to(c), 0.0, 1.0)
			if a > 0.0:
				img.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * a))
	return ImageTexture.create_from_image(img)

# --- vignette overlay --------------------------------------------------------
func _vignette(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var center := Vector2(w, h) * 0.5
	var maxd := center.length()
	var col := Color(0.04, 0.03, 0.05)
	for y in h:
		for x in w:
			var d := Vector2(x, y).distance_to(center) / maxd
			var a := lerpf(0.52, 0.88, smoothstep(0.0, 1.0, d))
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return img
