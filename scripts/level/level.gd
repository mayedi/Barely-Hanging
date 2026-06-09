class_name Level
extends Node3D
## Builds the playable platforms from data (spec §5.5). Atmospheric depth now comes from the
## authored painted parallax backdrop (backdrop.tscn) rather than scattered boxes. Presentation
## only: the simulation queries GameDirector.platforms, never these nodes.

const PlatformViewScene: PackedScene = preload("res://scenes/level/platform_view.tscn")

var _player: Node = null

func _ready() -> void:
	_build_platforms()

## Composition root hands in the player. Kept for when variant/orientation hints return;
## unused for now (all platforms are plain).
func set_player(player: Node) -> void:
	_player = player

func _build_platforms() -> void:
	for rect in GameDirector.platforms:
		var view: PlatformView = PlatformViewScene.instantiate()
		add_child(view)
		view.setup(rect)
