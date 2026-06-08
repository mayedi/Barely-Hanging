class_name PlatformView
extends MeshInstance3D
## The visual for one platform. The node tree (box mesh, checkpoint marker, goal beacon)
## and materials are AUTHORED in platform_view.tscn. This script only data-drives the
## template from a PlatformRect: it sizes the (scene-local) box, picks the type material,
## and shows/sizes the marker or beacon. Pure presentation — the sim never reads it.
##
## The box and marker meshes are `resource_local_to_scene`, so each instance gets its own
## copy and sizing one platform never affects another. The type material is duplicated so
## the per-platform orientation highlight can't bleed across platforms.

const DEPTH: float = 2.4   ## z-thickness, render only — the sim treats platforms as 2D

const MAT_GROUND: StandardMaterial3D = preload("res://resources/materials/platform_ground.tres")
const MAT_LEDGE: StandardMaterial3D = preload("res://resources/materials/platform_ledge.tres")
const MAT_GOAL: StandardMaterial3D = preload("res://resources/materials/platform_goal.tres")

@onready var _marker: MeshInstance3D = $CheckpointMarker
@onready var _beacon: MeshInstance3D = $GoalBeacon

var _mat: StandardMaterial3D
var _is_goal: bool = false

func setup(rect: PlatformRect) -> void:
	_is_goal = rect.is_goal
	# Extend the depth BACKWARD so the front face sits at z=0 (player/rope render in front).
	(mesh as BoxMesh).size = Vector3(rect.half.x * 2.0, rect.half.y * 2.0, DEPTH)
	position = Vector3(rect.center.x, rect.center.y, -DEPTH * 0.5)

	_mat = _material_for(rect).duplicate()
	material_override = _mat

	if rect.is_checkpoint and not rect.is_ground:
		_marker.visible = true
		(_marker.mesh as BoxMesh).size = Vector3(rect.half.x * 2.0 * 0.85, 0.12, DEPTH * 0.6)
		_marker.position = Vector3(0.0, rect.half.y + 0.06, 0.0)
	if rect.is_goal:
		_beacon.visible = true
		_beacon.position = Vector3(0.0, rect.half.y + 7.0, 0.0)

func _material_for(rect: PlatformRect) -> StandardMaterial3D:
	if rect.is_goal:
		return MAT_GOAL
	if rect.is_ground:
		return MAT_GROUND
	return MAT_LEDGE

## Gentle teal glow used by the orientation pulse (spec §10) — a direction hint only, NOT
## a required target. Skips the goal (already self-lit). amount 0..1.
func set_highlight(amount: float) -> void:
	if _is_goal or _mat == null:
		return
	_mat.emission_enabled = amount > 0.001
	_mat.emission = Color(0.10, 0.70, 0.62)
	_mat.emission_energy_multiplier = amount * 0.7
