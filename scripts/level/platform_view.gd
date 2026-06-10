@tool
class_name PlatformView
extends Node3D
## A platform you place and size DIRECTLY in the level scene (editable in the editor thanks
## to @tool). The node's position (x, y) is the platform centre on the play plane; `size` is
## its width/height; `platform_type` sets its gameplay role. At runtime, level.gd reads these
## into the simulation's PlatformRect. Visuals are one uniform standard slab — the type only
## affects gameplay (ground / checkpoint / goal), not the look.

enum PlatformType { LEDGE, GROUND, CHECKPOINT, GOAL }

const DEPTH: float = 3.0   ## z-thickness, render only — the sim treats platforms as 2D

@export var size: Vector2 = Vector2(12.0, 2.4):
	set(value):
		size = value
		_refresh()
@export var platform_type: PlatformType = PlatformType.LEDGE

func _ready() -> void:
	var mesh := get_node_or_null(^"Mesh") as MeshInstance3D
	if mesh != null and not (mesh.mesh is BoxMesh):
		mesh.mesh = BoxMesh.new()   # unique per instance, so sizing one never affects another
	_refresh()

## Update the slab mesh to the current size. Editor-safe (no autoloads, guards unready nodes).
func _refresh() -> void:
	var mesh := get_node_or_null(^"Mesh") as MeshInstance3D
	if mesh == null or not (mesh.mesh is BoxMesh):
		return
	(mesh.mesh as BoxMesh).size = Vector3(maxf(0.4, size.x), maxf(0.4, size.y), DEPTH)
	# Extend the depth backward so the front face sits at z=0 (player/rope render in front).
	mesh.position = Vector3(0.0, 0.0, -DEPTH * 0.5)

## Build the sim's collision/data rect from this node's placed transform + size + type.
func make_rect(index: int) -> PlatformRect:
	var rect := PlatformRect.new(Vector2(position.x, position.y), size, index)
	rect.is_ground = platform_type == PlatformType.GROUND
	rect.is_checkpoint = platform_type == PlatformType.CHECKPOINT
	rect.is_goal = platform_type == PlatformType.GOAL
	return rect
