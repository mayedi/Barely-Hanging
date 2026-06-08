class_name AimPreview
extends Node3D
## Renders the throw preview (spec §6.1): a dotted arc following the hook's exact future
## path and a reticle on the first surface it would contact. Presentation only — the
## ThrowController feeds it world-space points. Dots use one MultiMesh = one draw call.
##
## Drawn at a small +z so the preview sits in front of the platforms (whose front faces
## are at z=0).

const MAX_DOTS: int = 96
const FORE_Z: float = 0.2

var _mm: MultiMeshInstance3D
var _reticle: MeshInstance3D
var _reticle_mat: StandardMaterial3D

func _ready() -> void:
	_build_dots()
	_build_reticle()
	clear()

func _build_dots() -> void:
	_mm = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var dot := SphereMesh.new()
	dot.radius = 0.13
	dot.height = 0.26
	dot.radial_segments = 6
	dot.rings = 3
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.95, 0.96, 0.98, 0.85)
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dot.material = dmat
	mm.mesh = dot
	mm.instance_count = MAX_DOTS
	mm.visible_instance_count = 0
	_mm.multimesh = mm
	add_child(_mm)

func _build_reticle() -> void:
	_reticle = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.42
	ring.outer_radius = 0.6
	ring.rings = 16
	ring.ring_segments = 8
	_reticle.mesh = ring
	_reticle.rotation_degrees = Vector3(90.0, 0.0, 0.0)   # lay the ring in the XY plane, facing the camera
	_reticle_mat = StandardMaterial3D.new()
	_reticle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_reticle_mat.emission_enabled = true
	_reticle.material_override = _reticle_mat
	add_child(_reticle)

func show_arc(points: PackedVector2Array, contact: Vector2, has_contact: bool, above: bool) -> void:
	var mm := _mm.multimesh
	var n := mini(points.size(), MAX_DOTS)
	mm.visible_instance_count = n
	for i in n:
		var p := points[i]
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(p.x, p.y, FORE_Z)))
	if has_contact:
		_reticle.visible = true
		_reticle.position = Vector3(contact.x, contact.y, FORE_Z)
		var col := Color(0.2, 0.92, 0.82) if above else Color(0.96, 0.7, 0.22)
		_reticle_mat.albedo_color = col
		_reticle_mat.emission = col
	else:
		_reticle.visible = false

func clear() -> void:
	_mm.multimesh.visible_instance_count = 0
	_reticle.visible = false
