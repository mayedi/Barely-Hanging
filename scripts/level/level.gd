class_name Level
extends Node3D
## Builds the visible world from data (spec §5.5). It instances a PlatformView for each
## of GameDirector's platform rects and scatters dim parallax boxes behind the play
## plane. It is presentation only: the simulation queries GameDirector.platforms, never
## these nodes, so visuals and physics can never drift apart.

const PlatformViewScene: PackedScene = preload("res://scenes/level/platform_view.tscn")
const PULSE_HZ: float = 1.6
const PULSE_REACH: float = 12.0    ## only hint at platforms within a plausible swing above
const PARALLAX_SEED: int = 1337
const PARALLAX_COUNT: int = 20
const PARALLAX_Z_NEAR: float = -30.0
const PARALLAX_Z_FAR: float = -85.0
const PARALLAX_NEAR_COLOR: Color = Color(0.13, 0.15, 0.21)   ## cool dark, closest layer
const PARALLAX_FAR_COLOR: Color = Color(0.33, 0.37, 0.47)    ## fades toward the sky haze

var _views: Array[PlatformView] = []
var _player: Node = null
var _time: float = 0.0

func _ready() -> void:
	_build_platforms()
	_build_parallax()

## Composition root hands in the player so the orientation pulse can hint the nearest
## platform above. Continuous, so a direct reference (not an event) is the honest fit.
func set_player(player: Node) -> void:
	_player = player

func _build_platforms() -> void:
	for rect in GameDirector.platforms:
		var view: PlatformView = PlatformViewScene.instantiate()
		add_child(view)
		view.setup(rect)
		_views.append(view)

func _process(delta: float) -> void:
	if _player == null:
		return
	_time += delta
	var pulse := sin(_time * TAU * PULSE_HZ) * 0.5 + 0.5
	var here := _player.get_pos() as Vector2
	var best := _nearest_above(here)
	for i in _views.size():
		_views[i].set_highlight(pulse if i == best else 0.0)

## Index of the nearest platform whose top is above the player and within reach, or -1.
func _nearest_above(here: Vector2) -> int:
	var best := -1
	var best_dy := PULSE_REACH
	for plat: PlatformRect in GameDirector.platforms:
		if plat.is_ground:
			continue
		var top := plat.center.y + plat.half.y
		var dy := top - here.y
		if dy > 0.6 and dy < best_dy:
			best_dy = dy
			best = plat.index
	return best

## Distant boxes at z < 0. Under the low-FOV perspective camera they parallax against
## the play plane automatically, giving depth and a sense of a tall world.
func _build_parallax() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = PARALLAX_SEED
	var holder := Node3D.new()
	holder.name = "Parallax"
	add_child(holder)
	for i in PARALLAX_COUNT:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var w := rng.randf_range(4.0, 10.0)
		bm.size = Vector3(w, w * rng.randf_range(0.8, 2.2), 3.0)
		b.mesh = bm
		var z := rng.randf_range(PARALLAX_Z_NEAR, PARALLAX_Z_FAR)
		b.position = Vector3(
			rng.randf_range(-48.0, 48.0),
			rng.randf_range(-12.0, 54.0),
			z)
		# Manual depth cue: blend toward the sky haze with distance so far boxes melt into
		# the background instead of competing with the foreground. Self-lit (unshaded) so
		# the directional lights can't brighten them back up.
		var t := clampf((z - PARALLAX_Z_NEAR) / (PARALLAX_Z_FAR - PARALLAX_Z_NEAR), 0.0, 1.0)
		var m := StandardMaterial3D.new()
		m.albedo_color = PARALLAX_NEAR_COLOR.lerp(PARALLAX_FAR_COLOR, t)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		b.material_override = m
		holder.add_child(b)
