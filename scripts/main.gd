class_name Main
extends Node3D
## Composition root (spec §5.1: "root: spawns level, player, camera, hud"). The world
## dressing (sky, lighting, fog) and all child nodes are AUTHORED in main.tscn — this
## script only performs the one-time reference hand-off that a composition root does.
## Cross-system feedback flows through EventBus.

func _ready() -> void:
	_wire()
	_maybe_capture()   # dev-only: `--shot[=path]` on the command line, no effect in normal play

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
