extends Node3D
## Drives the painted parallax backdrop so the layered 2D art reads as a deep 3D world:
##   * each layer tracks the camera's vertical motion by a per-layer factor (distant layers
##     stay near the horizon, near layers scroll past) — this is what sells the depth,
##   * cloud layers drift sideways via UV scroll (the cloud art is seamless in x),
##   * dust emitters follow the camera so motes always drift through the view.
## Presentation only; reads the active camera, affects nothing in the sim.

## factor: 0 = world-fixed (max parallax), 1 = locked to the camera (distant/horizon).
## drift: UV scroll speed for cloud layers (per second).
const LAYERS: Dictionary = {
	"SunGlow": {"factor": 0.95, "drift": 0.0},
	"MountainsFar": {"factor": 0.92, "drift": 0.0},
	"CloudsHigh": {"factor": 0.90, "drift": 0.004},
	"MountainsMid": {"factor": 0.80, "drift": 0.0},
	"CloudsMid": {"factor": 0.74, "drift": 0.009},
	"MountainsNear": {"factor": 0.60, "drift": 0.0},
	"CloudsLow": {"factor": 0.52, "drift": 0.015},
	"MountainsFore": {"factor": 0.38, "drift": 0.0},
	"CloudSeaFar": {"factor": 0.30, "drift": 0.010},
	"CloudSeaNear": {"factor": 0.16, "drift": 0.022},
}

@onready var _dust_far: CPUParticles3D = $DustFar
@onready var _dust_near: CPUParticles3D = $DustNear

var _entries: Array[Dictionary] = []
var _cam: Camera3D = null
var _initial_cam_y: float = 0.0
var _time: float = 0.0

func _ready() -> void:
	for layer_name: String in LAYERS:
		var node := get_node_or_null(NodePath(layer_name)) as MeshInstance3D
		if node == null:
			continue
		var cfg: Dictionary = LAYERS[layer_name]
		_entries.append({
			"node": node,
			"factor": float(cfg["factor"]),
			"base_y": node.position.y,
			"drift": float(cfg["drift"]),
			"mat": node.material_override as StandardMaterial3D,
		})

func _process(delta: float) -> void:
	_time += delta
	if _cam == null:
		_cam = get_viewport().get_camera_3d()
		if _cam == null:
			return
		_initial_cam_y = _cam.global_position.y
	var cy := _cam.global_position.y
	var climb := cy - _initial_cam_y
	for e in _entries:
		var node: MeshInstance3D = e["node"]
		node.position.y = float(e["base_y"]) + climb * float(e["factor"])
		var drift: float = e["drift"]
		if drift != 0.0 and e["mat"] != null:
			var mat: StandardMaterial3D = e["mat"]
			mat.uv1_offset.x = fmod(_time * drift, 1.0)
	# Keep the dust drifting through the current view.
	_dust_far.position.y = cy
	_dust_near.position.y = cy
