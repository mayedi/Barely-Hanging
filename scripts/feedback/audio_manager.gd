extends Node
## Autoload "AudioManager" — maps EventBus events to procedural SFX (spec §9.1).
## It subscribes in _ready and synthesises short tones with AudioStreamGenerator, so
## the MVP ships with sound and no asset pipeline. Samples can replace these later.
## Every generator call is guarded so a headless / audio-less host never crashes.

const MIX_RATE: float = 22050.0
const VOICES: int = 8

var _config: GameConfig
var _voices: Array[AudioStreamPlayer] = []
var _next: int = 0
var _whoosh_cd: float = 0.0

func _ready() -> void:
	_config = GameDirector.config
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = MIX_RATE
		gen.buffer_length = 0.6
		p.stream = gen
		add_child(p)
		_voices.append(p)
	EventBus.rope_attached.connect(_on_attached)
	EventBus.rope_wrapped.connect(_on_wrapped)
	EventBus.player_landed.connect(_on_landed)
	EventBus.grip_critical.connect(_on_grip_critical)
	EventBus.reached_goal.connect(_on_goal)
	EventBus.player_fell.connect(_on_fell)
	EventBus.fast_motion.connect(_on_fast_motion)

func _process(delta: float) -> void:
	if _whoosh_cd > 0.0:
		_whoosh_cd -= delta

func _exit_tree() -> void:
	# Release active generator playbacks cleanly so they don't leak at shutdown.
	for v in _voices:
		v.stop()

# --- event handlers ----------------------------------------------------------
func _on_attached(_at: Vector2, _index: int) -> void:
	_tone(640.0, 200.0, 0.18, 0.45, 0.0)              # twang: pitch drop

func _on_wrapped(_corner: Vector2) -> void:
	_tone(1500.0, 1250.0, 0.05, 0.30, 0.0)            # quick high tick

func _on_landed(_at: Vector2, impact: float) -> void:
	var vol := clampf(0.2 + impact * 0.04, 0.2, 0.6)
	_tone(150.0, 70.0, 0.22, vol, 0.6)                # low thud + noise

func _on_grip_critical() -> void:
	_tone(900.0, 900.0, 0.16, 0.25, 0.0)              # soft warning beep

func _on_fell() -> void:
	_tone(320.0, 70.0, 0.40, 0.5, 0.25)               # descending whump

func _on_goal() -> void:
	var notes := [523.25, 659.25, 783.99, 1046.5]     # C5 E5 G5 C6 arpeggio
	for i in notes.size():
		var freq: float = notes[i]
		_delay(i * 0.12, func() -> void: _tone(freq, freq, 0.16, 0.35, 0.0))

func _on_fast_motion(_at: Vector2, speed: float) -> void:
	if _whoosh_cd > 0.0:
		return
	_whoosh_cd = _config.whoosh_cooldown
	var vol := clampf((speed - _config.trail_speed) * 0.02, 0.08, 0.25)
	_tone(420.0, 520.0, 0.3, vol, 1.0)                # airy wind whoosh (mostly noise)

# --- synthesis ---------------------------------------------------------------
## Play one tone: frequency glides f0->f1 over `dur` s, linear amplitude decay.
## `noise` (0..1) blends in white noise (for thuds / whooshes). All guarded.
func _tone(f0: float, f1: float, dur: float, vol: float, noise: float) -> void:
	var player := _voices[_next]
	_next = (_next + 1) % VOICES
	player.play()
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var frames := int(dur * MIX_RATE)
	var avail := playback.get_frames_available()
	frames = mini(frames, avail)
	if frames <= 0:
		return
	var buf := PackedVector2Array()
	buf.resize(frames)
	var phase := 0.0
	for i in frames:
		var t := float(i) / float(frames)
		var freq: float = lerpf(f0, f1, t)
		phase += TAU * freq / MIX_RATE
		var env := 1.0 - t
		var s := sin(phase) * (1.0 - noise) + (randf() * 2.0 - 1.0) * noise
		s *= env * vol
		buf[i] = Vector2(s, s)
	playback.push_buffer(buf)

func _delay(seconds: float, fn: Callable) -> void:
	if seconds <= 0.0:
		fn.call()
		return
	get_tree().create_timer(seconds).timeout.connect(fn)
