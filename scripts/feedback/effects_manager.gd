extends Node
## Autoload "EffectsManager" — turns EventBus events into particles, hitstop and the motion
## trail (spec §5.2, §9.2). The visuals are AUTHORED scenes (scenes/fx/*.tscn); this only
## instantiates them at the right place/time. It never reads game logic and logic never
## calls it. Being an autoload under /root, its Node3D children render in the main world.

const AttachBurst: PackedScene = preload("res://scenes/fx/attach_burst.tscn")
const LandDust: PackedScene = preload("res://scenes/fx/land_dust.tscn")
const TrailGhost: PackedScene = preload("res://scenes/fx/trail_ghost.tscn")

var _config: GameConfig
var _hitstop: float = 0.0
var _trail_cd: float = 0.0

func _ready() -> void:
	_config = GameDirector.config
	EventBus.rope_attached.connect(_on_attached)
	EventBus.player_landed.connect(_on_landed)
	EventBus.fast_motion.connect(_on_fast_motion)

func _physics_process(delta: float) -> void:
	# Hitstop is measured in sim time and ticked exactly once per physics frame here; the
	# player polls is_hitstopped() and skips integration while it is active.
	if _hitstop > 0.0:
		_hitstop -= delta
	if _trail_cd > 0.0:
		_trail_cd -= delta

## True while the catch-freeze is active. Rendering continues; only the sim pauses.
func is_hitstopped() -> bool:
	return _hitstop > 0.0

func _on_attached(at: Vector2, _index: int) -> void:
	_hitstop = _config.hitstop_on_attach
	_spawn_burst(AttachBurst, _to3(at))

func _on_landed(at: Vector2, _impact: float) -> void:
	_spawn_burst(LandDust, _to3(at))

func _on_fast_motion(at: Vector2, _speed: float) -> void:
	if _trail_cd > 0.0:
		return
	_trail_cd = _config.trail_cooldown
	var ghost: Node3D = TrailGhost.instantiate()
	add_child(ghost)
	ghost.global_position = _to3(at)

func _spawn_burst(scene: PackedScene, pos: Vector3) -> void:
	var p: CPUParticles3D = scene.instantiate()
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.6).timeout.connect(p.queue_free)

func _to3(v: Vector2) -> Vector3:
	return Vector3(v.x, v.y, 0.3)   # slightly forward so effects sit in front of platforms
