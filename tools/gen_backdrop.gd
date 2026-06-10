extends Node
## One-time build tool: paints high-quality layered parallax backdrop art (a dawn
## "above the clouds" theme) into assets/backdrop/*.png — a glowing sun, detailed mountain
## ranges (lit ridgelines, snow caps, atmospheric haze, rock texture), volumetric clouds and
## a haze gradient. Run once:  godot --headless --path . res://tools/gen_backdrop.tscn

const DIR: String = "res://assets/backdrop"
const W: int = 1600
const H: int = 800

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_save(_sun(720), "bg_sun")
	# Farthest -> nearest: lighter/hazier (atmospheric perspective) in the distance.
	_save(_mountains({
		"base": 0.46, "amp": 0.20, "freq": 0.0011, "seed": 11,
		"ridge": Color(0.80, 0.73, 0.78), "low": Color(0.72, 0.64, 0.74),
		"haze": Color(0.86, 0.74, 0.70), "haze_amt": 0.85,
		"snow_thr": 0.55, "rim": Color(1.0, 0.86, 0.66), "rim_w": 3, "rim_str": 0.30}), "bg_far")
	_save(_mountains({
		"base": 0.60, "amp": 0.30, "freq": 0.0016, "seed": 23,
		"ridge": Color(0.60, 0.55, 0.68), "low": Color(0.44, 0.41, 0.58),
		"haze": Color(0.74, 0.60, 0.60), "haze_amt": 0.7,
		"snow_thr": 0.62, "rim": Color(1.0, 0.82, 0.6), "rim_w": 4, "rim_str": 0.42}), "bg_mid")
	_save(_mountains({
		"base": 0.78, "amp": 0.40, "freq": 0.0023, "seed": 41,
		"ridge": Color(0.40, 0.36, 0.52), "low": Color(0.25, 0.23, 0.39),
		"haze": Color(0.55, 0.44, 0.5), "haze_amt": 0.5,
		"snow_thr": 0.72, "rim": Color(1.0, 0.78, 0.55), "rim_w": 5, "rim_str": 0.5}), "bg_near")
	_save(_mountains({
		"base": 0.94, "amp": 0.5, "freq": 0.003, "seed": 67,
		"ridge": Color(0.22, 0.19, 0.31), "low": Color(0.11, 0.10, 0.19),
		"haze": Color(0.3, 0.24, 0.32), "haze_amt": 0.35,
		"snow_thr": 2.0, "rim": Color(0.95, 0.66, 0.45), "rim_w": 5, "rim_str": 0.55}), "bg_fore")
	_save(_clouds(7, 0.45, 0.42, Color(1.0, 0.88, 0.74), Color(0.62, 0.56, 0.68)), "bg_clouds")
	_save(_clouds(19, 0.6, 0.55, Color(1.0, 0.83, 0.66), Color(0.55, 0.5, 0.64)), "bg_clouds2")
	_save(_dot(64), "bg_dot")
	print("backdrop done")
	get_tree().quit()

func _save(img: Image, sfx_name: String) -> void:
	img.save_png("%s/%s.png" % [DIR, sfx_name])

# --- sun glow ----------------------------------------------------------------
func _sun(size: int) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	var r := float(size) * 0.5
	for y in size:
		for x in size:
			var d := clampf(Vector2(x, y).distance_to(c) / r, 0.0, 1.0)
			var core := pow(1.0 - d, 2.4)            # tight bright core
			var halo := pow(1.0 - d, 1.1) * 0.5      # soft wide halo
			var a := clampf(core + halo, 0.0, 1.0)
			var col := Color(1.0, 0.92, 0.74).lerp(Color(1.0, 0.62, 0.36), d)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return img

# --- mountains ---------------------------------------------------------------
func _mountains(p: Dictionary) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ridge_noise := _fnl(p["freq"], int(p["seed"]), 6)
	var detail := _fnl(0.02, int(p["seed"]) + 100, 3)
	var ridge_col: Color = p["ridge"]
	var low_col: Color = p["low"]
	var haze_col: Color = p["haze"]
	var rim_col: Color = p["rim"]
	var haze_amt: float = p["haze_amt"]
	var rim_w: int = p["rim_w"]
	var rim_str: float = p["rim_str"]
	for x in W:
		var nv := pow(0.5 + 0.5 * ridge_noise.get_noise_2d(float(x), 0.0), 1.25)
		var ridge := clampi(int(float(H) * (p["base"] - p["amp"] * nv)), 2, H - 1)
		# Leave the very bottom rows transparent so texture-wrap can't bleed the opaque base
		# onto the transparent top edge (which showed as faint horizontal lines in the sky).
		for y in range(ridge, H - 3):
			var t := float(y - ridge) / float(maxi(1, H - ridge))
			var col := ridge_col.lerp(low_col, t)
			col = col * (1.0 + detail.get_noise_2d(float(x), float(y)) * 0.07)   # rock texture
			col = col.lerp(haze_col, smoothstep(0.45, 1.0, t) * haze_amt)        # atmospheric base haze
			img.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0))
		for k in rim_w:                                                          # warm sun-catch on the ridge
			var yy := ridge + k
			if yy < H:
				var base := img.get_pixel(x, yy)
				var lit := base.lerp(rim_col, (1.0 - float(k) / float(rim_w)) * rim_str)
				img.set_pixel(x, yy, Color(lit.r, lit.g, lit.b, 1.0))
		for e in 2:                                                             # soft anti-aliased silhouette
			var ya := ridge - 1 - e
			if ya >= 0:
				img.set_pixel(x, ya, Color(ridge_col.r, ridge_col.g, ridge_col.b, (1.0 - float(e + 1) / 3.0) * 0.5))
	return img

# --- volumetric clouds -------------------------------------------------------
## Clouds are sampled on a cylinder in x so the texture tiles seamlessly — letting it drift
## via UV scroll with no visible seam.
func _clouds(seed: int, band_center: float, band_width: float, light_col: Color, shadow_col: Color) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var n := _fnl(0.003, seed, 5)
	var radius := float(W) / TAU
	for x in W:
		var ang := TAU * float(x) / float(W)
		var nx := cos(ang) * radius
		var nz := sin(ang) * radius
		for y in H:
			var d := 0.5 + 0.5 * n.get_noise_3d(nx, float(y) * 2.3, nz)
			var yc := float(y) / float(H)
			var band := 1.0 - smoothstep(0.0, band_width, absf(yc - band_center))
			var a := smoothstep(0.5, 0.74, d) * band
			if a > 0.012:
				var d_up := 0.5 + 0.5 * n.get_noise_3d(nx, float(y - 7) * 2.3, nz)
				var top_lit := clampf((d - d_up) * 9.0 + 0.32, 0.0, 1.0)
				var col := shadow_col.lerp(light_col, top_lit)
				img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return img

## Soft round mote for floating dust particles.
func _dot(size: int) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	var r := float(size) * 0.5
	for y in size:
		for x in size:
			var d := clampf(Vector2(x, y).distance_to(c) / r, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, pow(1.0 - d, 2.2)))
	return img

func _fnl(freq: float, seed: int, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	n.frequency = freq
	n.seed = seed
	return n
