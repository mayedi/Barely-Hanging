class_name RopeView
extends Node3D
## Draws the rope as a thin camera-facing ribbon through its hinge polyline, plus a marker
## at the far end (the hook tip / anchor). The nodes + materials are AUTHORED in
## rope_view.tscn; only the ribbon geometry is rebuilt each frame here (it is genuinely
## dynamic — it follows the live hinge positions). Used both for the in-flight hook line
## and the attached rope. Presentation only: the player feeds it world-space points.

const FORE_Z: float = 0.18      ## sit in front of platforms (front faces at z=0)
const HALF_WIDTH: float = 0.07

@onready var _ribbon: MeshInstance3D = $Ribbon
@onready var _tip: MeshInstance3D = $Tip

var _im: ImmediateMesh

func _ready() -> void:
	_im = _ribbon.mesh
	clear()

## `points` is player-first: [player, hinge.., far_end]. Builds a quad strip in the XY
## plane (camera-facing) so the rope reads at a visible width from the distant camera.
func set_rope(points: PackedVector2Array) -> void:
	_im.clear_surfaces()
	if points.size() < 2:
		clear()
		return
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var seg := b - a
		if seg.length() < 0.0001:
			continue
		var nrm := Vector2(-seg.y, seg.x).normalized() * HALF_WIDTH
		var a0 := Vector3(a.x + nrm.x, a.y + nrm.y, FORE_Z)
		var a1 := Vector3(a.x - nrm.x, a.y - nrm.y, FORE_Z)
		var b0 := Vector3(b.x + nrm.x, b.y + nrm.y, FORE_Z)
		var b1 := Vector3(b.x - nrm.x, b.y - nrm.y, FORE_Z)
		_im.surface_add_vertex(a0)
		_im.surface_add_vertex(b0)
		_im.surface_add_vertex(b1)
		_im.surface_add_vertex(a0)
		_im.surface_add_vertex(b1)
		_im.surface_add_vertex(a1)
	_im.surface_end()
	_ribbon.visible = true
	var tip := points[points.size() - 1]
	_tip.position = Vector3(tip.x, tip.y, FORE_Z)
	_tip.visible = true

func clear() -> void:
	_im.clear_surfaces()
	_ribbon.visible = false
	_tip.visible = false
