extends Node3D
## Dev-only: renders the creature close-up and saves res://_creature.png so its design can
## be verified (in the real game it is intentionally small against the tall climb).

func _ready() -> void:
	var c: Creature = preload("res://scenes/creature/creature.tscn").instantiate()
	add_child(c)
	c.react(Vector2(7.0, -9.0))   # a lively pose: leaning + gazing

	var cam := Camera3D.new()
	cam.position = Vector3(0.35, 0.18, 2.7)
	add_child(cam)
	cam.look_at(Vector3(0, 0, 0.1), Vector3.UP)
	cam.fov = 36.0
	cam.make_current()

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -32, 0)
	key.light_energy = 1.2
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, 150, 0)
	fill.light_energy = 0.45
	fill.light_color = Color(0.7, 0.8, 1.0)
	add_child(fill)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.2, 0.26)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.55)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_creature.png")
	get_tree().quit()
