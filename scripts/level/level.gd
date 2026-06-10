class_name Level
extends Node3D
## The level as a SCENE: platforms are PlatformView nodes placed directly in level.tscn —
## move and resize them in the editor. A "Start" node marks the spawn point. At runtime this
## reads the placed platforms into the simulation's platform list + start position and hands
## them to GameDirector. Presentation + level data; no per-frame logic.

func _ready() -> void:
	var rects: Array[PlatformRect] = []
	var index := 0
	for child in get_children():
		var platform := child as PlatformView
		if platform != null:
			rects.append(platform.make_rect(index))
			index += 1
	var start_pos := Vector2(0.0, 1.0)
	var start_node := get_node_or_null(^"Start") as Node3D
	if start_node != null:
		start_pos = Vector2(start_node.position.x, start_node.position.y)
	GameDirector.set_level(rects, start_pos)
