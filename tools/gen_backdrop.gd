extends Node
## One-time build tool: paints the layered parallax backdrop art (hazy mountain ranges +
## cloud bands, a dawn-above-the-clouds theme) into assets/backdrop/*.png. These become the
## textures on the authored quads in backdrop.tscn. Run once:
##   godot --headless --path . res://tools/gen_backdrop.tscn
## Not part of the shipped game.

const DIR: String = "res://assets/backdrop"
const W: int = 1536
const H: int = 640

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	# Far -> near: hazier/lighter (closer to the sky) in the distance, darker up close.
	_save(_mountains(0.52, 0.30, 0.0015, 11, Color(0.66, 0.6, 0.72), Color(0.56, 0.52, 0.66)), "bg_far")
	_save(_mountains(0.70, 0.40, 0.0021, 27, Color(0.45, 0.43, 0.58), Color(0.32, 0.31, 0.46)), "bg_mid")
	_save(_mountains(0.90, 0.52, 0.0029, 43, Color(0.27, 0.26, 0.4), Color(0.15, 0.15, 0.26)), "bg_near")
	_save(_clouds(Color(1.0, 0.86, 0.74), 7), "bg_clouds")
	print("backdrop done")
	get_tree().quit()

func _save(img: Image, sfx_name: String) -> void:
	img.save_png("%s/%s.png" % [DIR, sfx_name])

## A hazy mountain-range silhouette: transparent above the ridge, filled (with a vertical
## haze gradient) below. `base_frac`/`amp_frac` set the ridge band; lower frequency = wider
## peaks. col_top is the hazy ridge colour, col_bot the darker base.
func _mountains(base_frac: float, amp_frac: float, freq: float, seed: int, col_top: Color, col_bot: Color) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 5
	n.frequency = freq
	n.seed = seed
	for x in W:
		var nv := 0.5 + 0.5 * n.get_noise_2d(float(x), 0.0)
		nv = pow(nv, 1.25)   # sharpen peaks slightly
		var ridge := clampi(int(float(H) * (base_frac - amp_frac * nv)), 1, H - 1)
		for y in range(ridge, H):
			var t := float(y - ridge) / float(maxi(1, H - ridge))
			var col := col_top.lerp(col_bot, t)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0))
		# Soft 3px anti-aliased ridge edge.
		for e in 3:
			var yy := ridge - 1 - e
			if yy >= 0:
				img.set_pixel(x, yy, Color(col_top.r, col_top.g, col_top.b, (1.0 - float(e + 1) / 4.0) * 0.55))
	return img

## Soft cloud band centred vertically: FBM noise stretched horizontally, faded into a band.
func _clouds(col: Color, seed: int) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 4
	n.frequency = 0.0035
	n.seed = seed
	for x in W:
		for y in H:
			var v := 0.5 + 0.5 * n.get_noise_2d(float(x), float(y) * 2.4)
			var yc := float(y) / float(H)
			var band := 1.0 - smoothstep(0.0, 0.5, absf(yc - 0.45) * 2.0)
			var a := smoothstep(0.5, 0.82, v) * band
			if a > 0.01:
				img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return img
