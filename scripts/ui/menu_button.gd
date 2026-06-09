extends Button
## A subtle scale-pop on hover/press for tactile, fluid-feeling menu buttons. Applied to all
## menu buttons. Runs while the tree is paused (the menu is PROCESS_MODE_ALWAYS).

const HOVER_SCALE: float = 1.05
const PRESS_SCALE: float = 0.96

var _hovered: bool = false
var _tw: Tween

func _ready() -> void:
	_recenter()
	resized.connect(_recenter)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	button_down.connect(_on_down)
	button_up.connect(_on_up)

func _recenter() -> void:
	pivot_offset = size * 0.5

func _on_hover(entered: bool) -> void:
	_hovered = entered
	_scale_to(HOVER_SCALE if entered else 1.0, 0.12, Tween.TRANS_BACK)

func _on_down() -> void:
	_scale_to(PRESS_SCALE, 0.06, Tween.TRANS_QUAD)

func _on_up() -> void:
	_scale_to(HOVER_SCALE if _hovered else 1.0, 0.1, Tween.TRANS_BACK)

func _scale_to(s: float, dur: float, trans: Tween.TransitionType) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(trans)
	_tw.tween_property(self, "scale", Vector2.ONE * s, dur)
