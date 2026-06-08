extends Node
## Autoload "EffectsManager" — turns EventBus events into particles, hitstop and the
## motion trail (spec §5.2, §9.2). It subscribes in _ready and reacts; it never reads
## game logic and logic never calls it. Being an autoload under /root, its Node3D
## children render in the main 3D world, so it can spawn world-space effects directly.

var _config: GameConfig
var _hitstop: float = 0.0
var _trail_cd: float = 0.0

func _ready() -> void:
	_config = GameDirector.config
	EventBus.rope_attached.connect(_on_attached)
	EventBus.player_landed.connect(_on_landed)
	EventBus.fast_motion.connect(_on_fast_motion)

func _physics_process(delta: float) -> void:
	# Hitstop is measured in sim time and ticked exactly once per physics frame here;
	# the player polls is_hitstopped() and skips integration while it is active.
	if _hitstop > 0.0:
		_hitstop -= delta
	if _trail_cd > 0.0:
		_trail_cd -= delta

## True while the catch-freeze is active. Rendering continues; only the sim pauses.
func is_hitstopped() -> bool:
	return _hitstop > 0.0

func _on_attached(at: Vector2, _index: int) -> void:
	_hitstop = _config.hitstop_on_attach
	_burst(_to3(at), Color(0.12, 0.61, 0.56), 20, 6.0, 0.5)   # teal spark at the anchor

func _on_landed(at: Vector2, impact: float) -> void:
	var amount := int(clampf(6.0 + impact * 1.5, 6.0, 40.0))
	_burst(_to3(at), Color(0.72, 0.66, 0.55), amount, 3.0 + impact * 0.2, 0.6)  # dust at the feet

func _on_fast_motion(at: Vector2, _speed: float) -> void:
	if _trail_cd > 0.0:
		return
	_trail_cd = _config.trail_cooldown
	_spawn_ghost(_to3(at))

# --- spawning helpers --------------------------------------------------------
func _burst(pos: Vector3, color: Color, amount: int, speed: float, lifetime: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = maxi(1, amount)
	p.lifetime = lifetime
	p.explosiveness = 0.92
	p.direction = Vector3(0, 1, 0)
	p.spread = 75.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -12.0, 0)
	p.scale_amount_min = 0.07
	p.scale_amount_max = 0.16
	p.color = color
	var dot := SphereMesh.new()
	dot.radius = 0.5
	dot.height = 1.0
	dot.radial_segments = 6
	dot.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot.material = mat
	p.mesh = dot
	add_child(p)
	p.global_position = pos
	p.emitting = true
	_free_later(p, lifetime + 0.6)

func _spawn_ghost(pos: Vector3) -> void:
	var m := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.55
	sph.height = 1.1
	sph.radial_segments = 10
	sph.rings = 6
	m.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.94, 0.51, 0.18, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	add_child(m)
	m.global_position = pos
	var tw := create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.32)
	tw.tween_callback(m.queue_free)

func _free_later(node: Node, seconds: float) -> void:
	get_tree().create_timer(seconds).timeout.connect(node.queue_free)

func _to3(v: Vector2) -> Vector3:
	return Vector3(v.x, v.y, 0.3)   # slightly forward so effects sit in front of platforms
