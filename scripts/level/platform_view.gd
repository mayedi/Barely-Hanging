class_name PlatformView
extends MeshInstance3D
## The visual for one platform. For now EVERY platform is the same basic standard slab —
## there are no visual variants. The script just sizes the (scene-local) box from the
## PlatformRect and applies the one standard material; the sim never reads this node.
##
## platform_view.tscn still contains the (hidden) checkpoint-marker and goal-beacon child
## nodes, and the type materials still exist as resources, so visual variants can be
## re-enabled later without rebuilding anything — but they are intentionally unused now.

const DEPTH: float = 2.4   ## z-thickness, render only — the sim treats platforms as 2D
const MAT_STANDARD: StandardMaterial3D = preload("res://resources/materials/platform_standard.tres")

func setup(rect: PlatformRect) -> void:
	# Extend the depth BACKWARD so the front face sits at z=0 (player/rope render in front).
	(mesh as BoxMesh).size = Vector3(rect.half.x * 2.0, rect.half.y * 2.0, DEPTH)
	position = Vector3(rect.center.x, rect.center.y, -DEPTH * 0.5)
	material_override = MAT_STANDARD
