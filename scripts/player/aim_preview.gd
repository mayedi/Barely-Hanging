class_name AimPreview
extends Node3D
## Renders the throw preview (spec §6.1): a dotted arc following the hook's exact future
## path and a reticle on the first surface it would contact. The nodes (a MultiMesh of dots
## = one draw call, and the torus reticle) and their materials are AUTHORED in
## aim_preview.tscn; this script only positions the dots and the reticle each aim frame.
##
## Drawn at a small +z so the preview sits in front of the platforms (front faces at z=0).

const FORE_Z: float = 0.2

@onready var _mm: MultiMeshInstance3D = $Dots
@onready var _reticle: MeshInstance3D = $Reticle

var _reticle_mat: StandardMaterial3D

func _ready() -> void:
	_reticle_mat = _reticle.material_override
	clear()

func show_arc(points: PackedVector2Array, contact: Vector2, has_contact: bool, above: bool) -> void:
	var mm := _mm.multimesh
	var n := mini(points.size(), mm.instance_count)
	mm.visible_instance_count = n
	for i in n:
		var p := points[i]
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(p.x, p.y, FORE_Z)))
	if has_contact:
		_reticle.visible = true
		_reticle.position = Vector3(contact.x, contact.y, FORE_Z)
		# Height hint only (teal above / amber below): NOT a validity gate — every hook is legal.
		var col := Color(0.2, 0.92, 0.82) if above else Color(0.96, 0.7, 0.22)
		_reticle_mat.albedo_color = col
		_reticle_mat.emission = col
	else:
		_reticle.visible = false

func clear() -> void:
	_mm.multimesh.visible_instance_count = 0
	_reticle.visible = false
