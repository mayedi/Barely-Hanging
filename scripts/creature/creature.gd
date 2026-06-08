class_name Creature
extends Node3D
## "Fluffy One-Eye" (spec §7). The whole creature — body, fur MultiMesh, eye hierarchy and
## feet — is AUTHORED in creature.tscn (editable in the editor). This script only:
##   * populates the fur MultiMesh with an even fibonacci-sphere tuft distribution (a
##     procedural pattern you would never hand-place), leaving a bare patch for the eye,
##   * drives the live reactions (squash, lean, eye-widen, gaze) from sim state.
## Presentation only: it reads sim state via react() and never affects it.

const FUR_COUNT: int = 320
const BODY_R: float = 0.5
const EYE_DIR: Vector3 = Vector3(0, 0, 1)         ## eye faces the camera (+Z)
const EYE_PATCH_COS: float = 0.80                 ## leave a fur-free cap ~37° around the eye
const BODY_COLOR: Color = Color(0.94, 0.51, 0.18) ## matches the authored body material

@onready var _fur: MultiMeshInstance3D = $Fur
@onready var _eye_root: Node3D = $EyeRoot
@onready var _gaze: Node3D = $EyeRoot/Gaze

var _gaze_base: Vector3 = Vector3.ZERO

func _ready() -> void:
	_gaze_base = _gaze.position
	_populate_fur()

## Fill the authored MultiMesh with outward-pointing tufts on a fibonacci sphere.
func _populate_fur() -> void:
	var mm := _fur.multimesh
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

# --- reactions (fed by the player from sim state, spec §9.3) ------------------
func react(vel: Vector2) -> void:
	var speed := vel.length()
	rotation.z = -clampf(vel.x * 0.018, -0.5, 0.5)                       # lean into horizontal motion
	var s := clampf(absf(vel.y) * 0.010, 0.0, 0.28)                     # squash/stretch with vertical speed
	scale = Vector3(1.0 - 0.5 * s, 1.0 + s, 1.0 - 0.5 * s)
	var ew := 1.0 + clampf(speed * 0.008, 0.0, 0.22)                    # eye widens at speed
	_eye_root.scale = Vector3(ew, ew, 1.0)
	if speed > 0.4:                                                     # gaze tracks movement
		var d := vel / speed
		_gaze.position = _gaze_base + Vector3(d.x, d.y, 0.0) * 0.08
	else:
		_gaze.position = _gaze.position.lerp(_gaze_base, 0.2)

## A basis rotating local +Y onto `dir` (so a cone's tip points outward).
func _basis_from_up(dir: Vector3) -> Basis:
	var dp := dir.dot(Vector3.UP)
	if dp > 0.9999:
		return Basis()
	if dp < -0.9999:
		return Basis(Vector3(1, 0, 0), PI)
	return Basis(Quaternion(Vector3.UP, dir))
