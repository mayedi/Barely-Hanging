extends MeshInstance3D
## A single motion-trail ghost (spec §9.2). The mesh + (scene-local) translucent material
## are authored in trail_ghost.tscn; this script just fades it out and frees it. Spawned by
## EffectsManager at the creature's position while moving fast.

const FADE_TIME: float = 0.32

func _ready() -> void:
	var mat := material_override as StandardMaterial3D
	var tw := create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, FADE_TIME)
	tw.tween_callback(queue_free)
