class_name Main
extends Node3D
## Composition root (spec §5.1: "root: spawns level, player, camera, hud"). It builds the
## world dressing (sky, lighting, fog) in code and wires the scene's gameplay nodes to
## one another. Cross-system feedback still flows through EventBus; this only performs the
## one-time reference hand-off that a composition root is meant to do.

func _ready() -> void:
	_build_environment()
	_build_lights()
	_wire()
	_maybe_capture()   # dev-only: `--shot[=path]` on the command line, no effect in normal play

# --- dev screenshot hook (verification only) ---------------------------------
func _maybe_capture() -> void:
	var path := ""
	for arg in OS.get_cmdline_args():
		if arg == "--shot":
			path = "res://_shot.png"
		elif arg.begins_with("--shot="):
			path = arg.substr("--shot=".length())
	if path == "":
		return
	await get_tree().create_timer(1.3).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	get_tree().quit()

# --- one-time wiring ---------------------------------------------------------
func _wire() -> void:
	var player := get_node_or_null("Player") as Player
	var camera := get_node_or_null("GameCamera") as GameCamera
	var rope_view := get_node_or_null("RopeView") as RopeView
	var aim_preview := get_node_or_null("AimPreview") as AimPreview
	var debug_view := get_node_or_null("DebugView") as DebugView
	var level := get_node_or_null("Level") as Level
	if player != null:
		player.setup(camera, rope_view, aim_preview)
	if camera != null and player != null:
		camera.setup(player)
	if debug_view != null and player != null:
		debug_view.setup(player)
	if level != null and player != null:
		level.set_player(player)

# --- world dressing ----------------------------------------------------------
func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.07, 0.10, 0.19)
	sky_mat.sky_horizon_color = Color(0.42, 0.40, 0.48)
	sky_mat.ground_horizon_color = Color(0.28, 0.27, 0.31)
	sky_mat.ground_bottom_color = Color(0.10, 0.11, 0.14)
	sky_mat.sky_energy_multiplier = 1.0

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Light fog only — the camera sits ~69u back (low FOV), so heavy depth fog would wash
	# the foreground. Distant shapes recede mainly via the manual depth-tint in level.gd.
	env.fog_enabled = true
	env.fog_light_color = Color(0.30, 0.36, 0.50)
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.1
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.1

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)

func _build_lights() -> void:
	# Key light. No shadows (spec §12 milestone 2) — flat, readable side-view lighting.
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.shadow_enabled = false
	add_child(sun)

	# Cool fill from the opposite side to keep shaded faces from going black.
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation_degrees = Vector3(-18.0, 135.0, 0.0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.66, 0.76, 1.0)
	fill.shadow_enabled = false
	add_child(fill)
