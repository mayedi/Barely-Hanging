class_name Level
extends Node3D
## Builds the visible world from data (spec §5.5). It instances a PlatformView for each
## of GameDirector's platform rects and scatters dim parallax boxes behind the play
## plane. It is presentation only: the simulation queries GameDirector.platforms, never
## these nodes, so visuals and physics can never drift apart.

const PlatformViewScene: PackedScene = preload("res://scenes/level/platform_view.tscn")
const ParallaxBoxScene: PackedScene = preload("res://scenes/level/parallax_box.tscn")
const PARALLAX_SEED: int = 1337
const PARALLAX_COUNT: int = 20
const PARALLAX_Z_NEAR: float = -30.0
const PARALLAX_Z_FAR: float = -85.0
const PARALLAX_NEAR_COLOR: Color = Color(0.13, 0.15, 0.21)   ## cool dark, closest layer
const PARALLAX_FAR_COLOR: Color = Color(0.33, 0.37, 0.47)    ## fades toward the sky haze

var _player: Node = null

func _ready() -> void:
	_build_platforms()
	_build_parallax()

## Composition root hands in the player. Kept for when variant/orientation hints return;
## unused for now (all platforms are plain).
func set_player(player: Node) -> void:
	_player = player

func _build_platforms() -> void:
	for rect in GameDirector.platforms:
		var view: PlatformView = PlatformViewScene.instantiate()
		add_child(view)
		view.setup(rect)

## Distant boxes at z < 0. Under the low-FOV perspective camera they parallax against
## the play plane automatically, giving depth and a sense of a tall world.
func _build_parallax() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = PARALLAX_SEED
	var holder := Node3D.new()
	holder.name = "Parallax"
	add_child(holder)
	for i in PARALLAX_COUNT:
		# Instance the authored template; only size/position/colour are data-driven (the
		# mesh + material are scene-local, so each box is independent).
		var b: MeshInstance3D = ParallaxBoxScene.instantiate()
		var w := rng.randf_range(4.0, 10.0)
		var z := rng.randf_range(PARALLAX_Z_NEAR, PARALLAX_Z_FAR)
		(b.mesh as BoxMesh).size = Vector3(w, w * rng.randf_range(0.8, 2.2), 3.0)
		b.position = Vector3(rng.randf_range(-48.0, 48.0), rng.randf_range(-12.0, 54.0), z)
		# Depth cue: blend toward the sky haze with distance so far boxes melt into the
		# background instead of competing with the foreground.
		var t := clampf((z - PARALLAX_Z_NEAR) / (PARALLAX_Z_FAR - PARALLAX_Z_NEAR), 0.0, 1.0)
		(b.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color = \
			PARALLAX_NEAR_COLOR.lerp(PARALLAX_FAR_COLOR, t)
		holder.add_child(b)
