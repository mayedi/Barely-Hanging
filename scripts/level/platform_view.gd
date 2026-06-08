class_name PlatformView
extends MeshInstance3D
## The visual mesh for one platform, built from a PlatformRect (spec §5.1). Pure
## presentation: it carries no collision and the simulation never reads it. Colour and
## small markers communicate platform type (ground / ledge / checkpoint / goal) so the
## climb stays legible without changing any physics.

const DEPTH: float = 2.4   ## z-thickness, render only — the sim treats platforms as 2D

var _mat: StandardMaterial3D
var _is_goal: bool = false

func setup(rect: PlatformRect) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(rect.half.x * 2.0, rect.half.y * 2.0, DEPTH)
	mesh = box
	# Extend the depth BACKWARD so the front face sits at z=0. The player and rope live at
	# z>=0 and therefore always render in front of the platforms (spec §4.1 keeps the sim
	# on the z=0 plane; this is a pure render offset).
	position = Vector3(rect.center.x, rect.center.y, -DEPTH * 0.5)

	# Warm stone foreground so platforms read clearly against the cool, hazy background.
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.95
	if rect.is_goal:
		mat.albedo_color = Color(0.96, 0.78, 0.25)
		mat.emission_enabled = true
		mat.emission = Color(0.85, 0.6, 0.15)
		mat.emission_energy_multiplier = 0.5
	elif rect.is_ground:
		mat.albedo_color = Color(0.30, 0.25, 0.22)
	else:
		mat.albedo_color = Color(0.52, 0.43, 0.34)
	material_override = mat
	_mat = mat
	_is_goal = rect.is_goal

	if rect.is_checkpoint and not rect.is_ground:
		_add_checkpoint_marker(rect)
	if rect.is_goal:
		_add_goal_beacon(rect)

## Gentle teal glow used by the orientation pulse (spec §10) — a direction hint only, NOT
## a required target. Skips the goal (already self-lit). amount 0..1.
func set_highlight(amount: float) -> void:
	if _is_goal or _mat == null:
		return
	_mat.emission_enabled = amount > 0.001
	_mat.emission = Color(0.10, 0.70, 0.62)
	_mat.emission_energy_multiplier = amount * 0.7

## A glowing teal strip on top of a checkpoint ledge — reads as "rest here saves you".
func _add_checkpoint_marker(rect: PlatformRect) -> void:
	var strip := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(rect.half.x * 2.0 * 0.85, 0.12, DEPTH * 0.6)
	strip.mesh = b
	strip.position = Vector3(0.0, rect.half.y + 0.06, 0.0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.10, 0.70, 0.62)
	m.emission_enabled = true
	m.emission = Color(0.10, 0.70, 0.62)
	m.emission_energy_multiplier = 1.4
	strip.material_override = m
	add_child(strip)

## A tall translucent pillar of light over the goal so it's visible from far below.
func _add_goal_beacon(rect: PlatformRect) -> void:
	var beacon := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.25
	cyl.bottom_radius = 0.6
	cyl.height = 14.0
	beacon.mesh = cyl
	beacon.position = Vector3(0.0, rect.half.y + 7.0, 0.0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.5, 0.95, 0.85, 0.18)
	m.emission_enabled = true
	m.emission = Color(0.4, 0.95, 0.85)
	m.emission_energy_multiplier = 1.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beacon.material_override = m
	add_child(beacon)
