class_name Creature
extends Node3D
## "Fluffy One-Eye" — an original charming creature (spec §7). Built entirely in code:
## a round fuzzy body (MultiMesh fur for one draw call), one big tracking eye, and two
## little feet. Presentation only: it reads sim state via react() and never affects it.
## The cute look against a punishing climb is the game's hook (spec §14).

const BODY_R: float = 0.5
const FUR_COUNT: int = 320
const EYE_DIR: Vector3 = Vector3(0, 0, 1)        ## eye faces the camera (+Z)
const EYE_PATCH_COS: float = 0.80                ## leave a fur-free cap ~37° around the eye
const BODY_COLOR: Color = Color(0.94, 0.51, 0.18)  ## ~#f0822e warm orange

var _eye_root: Node3D
var _gaze: Node3D
var _gaze_base: Vector3 = Vector3.ZERO

func _ready() -> void:
	_build_body()
	_build_fur()
	_build_eye()
	_build_feet()

# --- construction ------------------------------------------------------------
func _build_body() -> void:
	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = BODY_R
	sphere.height = BODY_R * 2.0
	body.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BODY_COLOR
	mat.roughness = 0.95
	body.material_override = mat
	add_child(body)

## ~300 cone "tufts" on an even fibonacci-sphere distribution, each pointing outward,
## skipping a cap where the eye goes. One MultiMesh = one draw call (spec §7).
func _build_fur() -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.055
	cone.height = 0.17
	cone.radial_segments = 5
	cone.rings = 1
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(1, 1, 1)
	fmat.vertex_color_use_as_albedo = true   # per-instance colour modulates albedo
	fmat.roughness = 0.95
	cone.material = fmat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cone

	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var golden := PI * (3.0 - sqrt(5.0))
	for i in FUR_COUNT:
		var y := 1.0 - 2.0 * (float(i) + 0.5) / float(FUR_COUNT)
		var r := sqrt(maxf(0.0, 1.0 - y * y))
		var theta := golden * float(i)
		var dir := Vector3(r * cos(theta), y, r * sin(theta))
		if dir.dot(EYE_DIR) > EYE_PATCH_COS:
			continue
		transforms.append(Transform3D(_basis_from_up(dir), dir * (BODY_R * 0.95)))
		var tint := 0.88 + 0.24 * fmod(float(i) * 0.61803398, 1.0)
		colors.append(Color(BODY_COLOR.r * tint, BODY_COLOR.g * tint, BODY_COLOR.b * tint))

	mm.instance_count = transforms.size()
	for j in transforms.size():
		mm.set_instance_transform(j, transforms[j])
		mm.set_instance_color(j, colors[j])

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)

## One big eye in the bare patch: a stationary cream eyeball plus a gaze group (iris,
## pupil, glint) that shifts toward the movement direction so it feels alive.
func _build_eye() -> void:
	_eye_root = Node3D.new()
	_eye_root.position = Vector3(0.0, 0.06, 0.42)
	add_child(_eye_root)

	var eyeball := MeshInstance3D.new()
	var es := SphereMesh.new()
	es.radius = 0.27
	es.height = 0.54
	eyeball.mesh = es
	eyeball.material_override = _flat(Color(0.96, 0.93, 0.85), 0.4)
	_eye_root.add_child(eyeball)

	_gaze = Node3D.new()
	_eye_root.add_child(_gaze)
	_gaze_base = _gaze.position

	var iris := MeshInstance3D.new()
	var iss := SphereMesh.new()
	iss.radius = 0.14
	iss.height = 0.28
	iris.mesh = iss
	iris.scale = Vector3(1.0, 1.0, 0.5)
	iris.position = Vector3(0.0, 0.0, 0.21)
	iris.material_override = _flat(Color(0.12, 0.61, 0.56), 0.3)   # ~#1f9b8e teal
	_gaze.add_child(iris)

	var pupil := MeshInstance3D.new()
	var ps := SphereMesh.new()
	ps.radius = 0.07
	ps.height = 0.14
	pupil.mesh = ps
	pupil.scale = Vector3(1.0, 1.0, 0.5)
	pupil.position = Vector3(0.0, 0.0, 0.25)
	pupil.material_override = _flat(Color(0.02, 0.02, 0.03), 0.2)
	_gaze.add_child(pupil)

	var glint := MeshInstance3D.new()
	var gs := SphereMesh.new()
	gs.radius = 0.032
	gs.height = 0.064
	glint.mesh = gs
	glint.position = Vector3(0.06, 0.07, 0.27)
	var gm := _flat(Color(1, 1, 1), 0.0)
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glint.material_override = gm
	_gaze.add_child(glint)

func _build_feet() -> void:
	for sign_x in [-1.0, 1.0]:
		var foot := MeshInstance3D.new()
		var fs := SphereMesh.new()
		fs.radius = 0.16
		fs.height = 0.32
		foot.mesh = fs
		foot.scale = Vector3(1.0, 0.45, 1.2)
		foot.position = Vector3(0.22 * sign_x, -0.48, 0.12)
		foot.material_override = _flat(Color(0.6, 0.32, 0.1), 0.9)
		add_child(foot)

# --- reactions (fed by the player from sim state, spec §9.3) ------------------
func react(vel: Vector2) -> void:
	var speed := vel.length()
	# Lean into horizontal motion.
	rotation.z = -clampf(vel.x * 0.018, -0.5, 0.5)
	# Squash/stretch with vertical speed.
	var s := clampf(absf(vel.y) * 0.010, 0.0, 0.28)
	scale = Vector3(1.0 - 0.5 * s, 1.0 + s, 1.0 - 0.5 * s)
	# Eye widens at high speed.
	var ew := 1.0 + clampf(speed * 0.008, 0.0, 0.22)
	_eye_root.scale = Vector3(ew, ew, 1.0)
	# Gaze tracks the movement direction.
	if speed > 0.4:
		var d := vel / speed
		_gaze.position = _gaze_base + Vector3(d.x, d.y, 0.0) * 0.08
	else:
		_gaze.position = _gaze.position.lerp(_gaze_base, 0.2)

# --- helpers -----------------------------------------------------------------
func _flat(col: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	return m

## A basis rotating local +Y onto `dir` (so a cone's tip points outward).
func _basis_from_up(dir: Vector3) -> Basis:
	var dp := dir.dot(Vector3.UP)
	if dp > 0.9999:
		return Basis()
	if dp < -0.9999:
		return Basis(Vector3(1, 0, 0), PI)
	return Basis(Quaternion(Vector3.UP, dir))
