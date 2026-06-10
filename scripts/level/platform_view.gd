@tool
class_name PlatformView
extends Node3D
## A clean, solid platform you place and size DIRECTLY in the level scene (editable live in the
## editor thanks to @tool). It renders as a simple grassy-topped stone ledge — the whole slab IS
## the collision the sim uses (top face = where you stand / the rope sticks). No trunks, canopies
## or other clutter: just a platform. The node's (x, y) is its centre; `size` is its width/height.

enum PlatformType { LEDGE, GROUND, CHECKPOINT, GOAL }

const DEPTH: float = 3.0   ## z-thickness, render only — the sim treats platforms as 2D boxes
const MAT_GRASS: Material = preload("res://resources/materials/island_grass.tres")
const MAT_ROCK: Material = preload("res://resources/materials/platform_standard.tres")

@export var size: Vector2 = Vector2(10.0, 2.4):
	set(value):
		size = value
		_refresh()
@export var platform_type: PlatformType = PlatformType.LEDGE

func _ready() -> void:
	_ensure_meshes()
	_refresh()

## Each part gets its own mesh resource so resizing one platform never warps another.
func _ensure_meshes() -> void:
	var body := get_node_or_null(^"Body") as MeshInstance3D
	if body != null and not (body.mesh is BoxMesh):
		body.mesh = BoxMesh.new()
	var cap := get_node_or_null(^"Cap") as MeshInstance3D
	if cap != null and not (cap.mesh is BoxMesh):
		cap.mesh = BoxMesh.new()

## Lay out the slab from the current size. Editor-safe (no autoloads, guards unready nodes).
func _refresh() -> void:
	var body := get_node_or_null(^"Body") as MeshInstance3D
	var cap := get_node_or_null(^"Cap") as MeshInstance3D
	if body == null or cap == null:
		return
	if not (body.mesh is BoxMesh and cap.mesh is BoxMesh):
		return
	var w := maxf(0.4, size.x)
	var h := maxf(0.4, size.y)
	var z := -DEPTH * 0.5
	var cap_h := clampf(h * 0.3, 0.3, 0.9)
	# Rock body fills the slab below the grassy cap.
	(body.mesh as BoxMesh).size = Vector3(w, h - cap_h, DEPTH)
	body.position = Vector3(0.0, -cap_h * 0.5, z)
	body.material_override = MAT_ROCK
	# Grassy cap whose top face is exactly the collision top (where you land).
	(cap.mesh as BoxMesh).size = Vector3(w, cap_h, DEPTH * 1.02)
	cap.position = Vector3(0.0, h * 0.5 - cap_h * 0.5, z)
	cap.material_override = MAT_GRASS

## Build the sim's collision/data rect from this node's placed transform + size + type.
func make_rect(index: int) -> PlatformRect:
	var rect := PlatformRect.new(Vector2(position.x, position.y), size, index)
	rect.is_ground = platform_type == PlatformType.GROUND
	rect.is_checkpoint = platform_type == PlatformType.CHECKPOINT
	rect.is_goal = platform_type == PlatformType.GOAL
	return rect
