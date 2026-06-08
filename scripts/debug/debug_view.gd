class_name DebugView
extends Node3D
## Visual debug overlay (spec §6.3, §13) — toggle with F3 (GameDirector.debug_draw). The
## nodes (line mesh + material, CanvasLayer + Label) are AUTHORED in debug_view.tscn; this
## script only draws the live hinge polyline, the active-length circle and the velocity
## vector into the ImmediateMesh, and writes the text. A dev tool — it reads the player via
## get_debug(). Essential for debugging corner-wrapping, the highest-risk system.

const CIRCLE_SEGMENTS: int = 48
const CROSS: float = 0.25
const FORE_Z: float = 0.25
const VEL_SCALE: float = 0.12

@onready var _mesh: MeshInstance3D = $Lines
@onready var _label: Label = $Overlay/Label

var _player: Player = null
var _im: ImmediateMesh

func _ready() -> void:
	_im = _mesh.mesh
	_set_visible(false)

func setup(player: Player) -> void:
	_player = player

func _process(_delta: float) -> void:
	var on := GameDirector.debug_draw
	_set_visible(on)
	if not on or _player == null:
		return
	_draw(_player.get_debug())

func _set_visible(v: bool) -> void:
	_mesh.visible = v
	_label.visible = v

func _draw(info: Dictionary) -> void:
	var hinges: PackedVector2Array = info["hinges"]
	var pos: Vector2 = info["pos"]
	var vel: Vector2 = info["vel"]
	_im.clear_surfaces()
	_im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(1, hinges.size()):
		_cross(hinges[i], Color(1.0, 0.85, 0.2))
	if info["has_rope"] and hinges.size() >= 2:
		_circle(hinges[1], info["active_len"], Color(0.2, 0.85, 1.0))
	_line(pos, pos + vel * VEL_SCALE, Color(1.0, 0.3, 0.85))
	_im.surface_end()

	var state := "GROUNDED" if info["grounded"] else "AIRBORNE"
	var rope_line := "rope: %d hinges   active=%.2f" % [info["hinge_count"], info["active_len"]] \
		if info["has_rope"] else "rope: none"
	_label.text = "DEBUG (F3)\nstate: %s   aiming: %s\nspeed: %.1f   grip: %.2f\n%s" % [
		state, str(info["aiming"]), vel.length(), info["grip"], rope_line]

# --- primitive helpers (PRIMITIVE_LINES) -------------------------------------
func _line(a: Vector2, b: Vector2, col: Color) -> void:
	_im.surface_set_color(col)
	_im.surface_add_vertex(Vector3(a.x, a.y, FORE_Z))
	_im.surface_set_color(col)
	_im.surface_add_vertex(Vector3(b.x, b.y, FORE_Z))

func _cross(p: Vector2, col: Color) -> void:
	_line(p - Vector2(CROSS, 0.0), p + Vector2(CROSS, 0.0), col)
	_line(p - Vector2(0.0, CROSS), p + Vector2(0.0, CROSS), col)

func _circle(c: Vector2, r: float, col: Color) -> void:
	for i in CIRCLE_SEGMENTS:
		var a0 := TAU * float(i) / float(CIRCLE_SEGMENTS)
		var a1 := TAU * float(i + 1) / float(CIRCLE_SEGMENTS)
		_line(c + Vector2(cos(a0), sin(a0)) * r, c + Vector2(cos(a1), sin(a1)) * r, col)
