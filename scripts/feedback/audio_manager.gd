extends Node
## Autoload "AudioManager" (a scene: audio_manager.tscn). Maps EventBus events to SFX
## (spec §9.1). The sounds are real .wav ASSETS played by authored AudioStreamPlayer child
## nodes — no runtime synthesis. It subscribes in _ready and reacts; it knows nothing about
## game logic and logic never calls it directly. (The .wav files were baked once by
## tools/gen_assets.gd from the prototype's procedural tones.)

var _config: GameConfig
var _whoosh_cd: float = 0.0

@onready var _attach: AudioStreamPlayer = $RopeAttach
@onready var _wrap: AudioStreamPlayer = $RopeWrap
@onready var _land: AudioStreamPlayer = $Land
@onready var _critical: AudioStreamPlayer = $GripCritical
@onready var _fell: AudioStreamPlayer = $Fell
@onready var _goal: AudioStreamPlayer = $Goal
@onready var _whoosh: AudioStreamPlayer = $Whoosh

func _ready() -> void:
	_config = GameDirector.config
	EventBus.rope_attached.connect(_on_attached)
	EventBus.rope_wrapped.connect(_on_wrapped)
	EventBus.player_landed.connect(_on_landed)
	EventBus.grip_critical.connect(_on_critical)
	EventBus.player_fell.connect(_on_fell)
	EventBus.reached_goal.connect(_on_goal)
	EventBus.fast_motion.connect(_on_fast_motion)

func _process(delta: float) -> void:
	if _whoosh_cd > 0.0:
		_whoosh_cd -= delta

func _on_attached(_at: Vector2, _index: int) -> void:
	_attach.play()

func _on_wrapped(_corner: Vector2) -> void:
	_wrap.play()

func _on_critical() -> void:
	_critical.play()

func _on_fell() -> void:
	_fell.play()

func _on_goal() -> void:
	_goal.play()

func _on_landed(_at: Vector2, impact: float) -> void:
	_land.volume_db = linear_to_db(clampf(0.3 + impact * 0.05, 0.3, 1.0))
	_land.play()

func _on_fast_motion(_at: Vector2, speed: float) -> void:
	if _whoosh_cd > 0.0:
		return
	_whoosh_cd = _config.whoosh_cooldown
	_whoosh.volume_db = linear_to_db(clampf((speed - _config.trail_speed) * 0.04, 0.15, 0.6))
	_whoosh.play()
