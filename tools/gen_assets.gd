extends Node
## One-time build tool: synthesises the procedural SFX into real .wav assets (so audio is
## asset-based, played by authored AudioStreamPlayer nodes) and prints the directional-light
## transforms so they can be authored exactly in main.tscn. Run once:
##   godot --headless --path . res://tools/gen_assets.tscn
## Not part of the shipped game.

const MIX_RATE: int = 22050
const DIR: String = "res://assets/audio"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	# name, f0, f1, dur, vol, noise
	_save("rope_attach", _tone(640.0, 200.0, 0.18, 0.55, 0.0))
	_save("rope_wrap", _tone(1500.0, 1250.0, 0.05, 0.4, 0.0))
	_save("land", _tone(150.0, 70.0, 0.22, 0.7, 0.5))
	_save("grip_critical", _tone(900.0, 900.0, 0.16, 0.35, 0.0))
	_save("fell", _tone(320.0, 70.0, 0.40, 0.6, 0.25))
	_save("whoosh", _tone(420.0, 520.0, 0.30, 0.5, 1.0))
	_save("goal", _arpeggio())
	_print_light("Sun", Vector3(-52, -38, 0))
	_print_light("Fill", Vector3(-18, 135, 0))
	print("gen_assets done")
	get_tree().quit()

func _save(sfx_name: String, samples: PackedFloat32Array) -> void:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	wav.save_to_wav("%s/%s.wav" % [DIR, sfx_name])

func _tone(f0: float, f1: float, dur: float, vol: float, noise: float) -> PackedFloat32Array:
	var n := int(dur * float(MIX_RATE))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		var freq: float = lerpf(f0, f1, t)
		phase += TAU * freq / float(MIX_RATE)
		var env := 1.0 - t
		var s := sin(phase) * (1.0 - noise) + (randf() * 2.0 - 1.0) * noise
		buf[i] = s * env * vol
	return buf

func _arpeggio() -> PackedFloat32Array:
	var notes := [523.25, 659.25, 783.99, 1046.5]   # C5 E5 G5 C6
	var out := PackedFloat32Array()
	for f in notes:
		out.append_array(_tone(f, f, 0.16, 0.4, 0.0))
	return out

func _print_light(light_name: String, euler_deg: Vector3) -> void:
	var b := Basis.from_euler(Vector3(deg_to_rad(euler_deg.x), deg_to_rad(euler_deg.y), deg_to_rad(euler_deg.z)))
	print("%s transform = Transform3D(%f, %f, %f, %f, %f, %f, %f, %f, %f, 0, 0, 0)" % [
		light_name, b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z])
