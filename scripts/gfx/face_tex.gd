extends RefCounted
## Mouth shapes and other little drawings, rasterised from distance functions
## into textures once at startup (cached).

const W := 128
const H := 96
const LINE := Color(0.15, 0.05, 0.06)
const INSIDE := Color(0.34, 0.05, 0.08)
const TONGUE := Color(0.93, 0.46, 0.5)
const TEETH := Color(0.98, 0.97, 0.93)

const MOUTHS := ["smile_soft", "smile", "grin", "open", "open_small", "o", "o_big", "flat",
	"frown", "frown_open", "wavy", "smirk", "smirk_open", "shout", "teeth"]

static var _cache := {}


static func mouth(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	var aa := 1.6 / (W * 0.5)
	for y in H:
		for x in W:
			var u := (x + 0.5 - W * 0.5) / (W * 0.5)
			var v := (H * 0.5 - y - 0.5) / (W * 0.5)
			img.set_pixel(x, y, _px(name, Vector2(u, v), aa))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[name] = tex
	return tex


static func _cov(d: float, aa: float) -> float:
	# coverage for a signed distance (negative inside)
	return clampf(0.5 - d / aa, 0.0, 1.0)


static func _over(dst: Color, src: Color, a: float) -> Color:
	var sa := src.a * a
	var out_a := sa + dst.a * (1.0 - sa)
	if out_a <= 0.0001:
		return Color(0, 0, 0, 0)
	var c := (Color(src.r, src.g, src.b) * sa + Color(dst.r, dst.g, dst.b) * dst.a * (1.0 - sa)) / out_a
	return Color(c.r, c.g, c.b, out_a)


## Distance to a circular arc (angles in degrees, counter-clockwise a0 -> a1).
static func _arc(p: Vector2, c: Vector2, r: float, a0: float, a1: float) -> float:
	var d := p - c
	var ang := rad_to_deg(atan2(d.y, d.x))
	var lo := minf(a0, a1)
	var hi := maxf(a0, a1)
	if ang >= lo and ang <= hi:
		return absf(d.length() - r)
	var e0 := c + Vector2(cos(deg_to_rad(a0)), sin(deg_to_rad(a0))) * r
	var e1 := c + Vector2(cos(deg_to_rad(a1)), sin(deg_to_rad(a1))) * r
	return minf(p.distance_to(e0), p.distance_to(e1))


static func _ellipse(p: Vector2, c: Vector2, ab: Vector2) -> float:
	var q := (p - c) / ab
	return (q.length() - 1.0) * minf(ab.x, ab.y)


static func _rrect(p: Vector2, c: Vector2, half: Vector2, r: float) -> float:
	var q := (p - c).abs() - half + Vector2(r, r)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r


static func _stroke(img_c: Color, d: float, width: float, aa: float) -> Color:
	return _over(img_c, LINE, _cov(d - width, aa))


## A filled mouth with tongue and optional teeth bands, outlined.
static func _filled(p: Vector2, sdf: float, aa: float, tongue_c: Vector2, tongue_r: float, teeth_top := -99.0, teeth_bot := 99.0) -> Color:
	var col := Color(0, 0, 0, 0)
	var inside := _cov(sdf, aa)
	if inside > 0.0:
		col = _over(col, INSIDE, inside)
		var t := _cov(p.distance_to(tongue_c) - tongue_r, aa) * inside
		col = _over(col, TONGUE, t)
		if p.y > teeth_top:
			col = _over(col, TEETH, inside * _cov(teeth_top - p.y, aa))
		if p.y < teeth_bot:
			col = _over(col, TEETH, inside * _cov(p.y - teeth_bot, aa))
	col = _over(col, LINE, _cov(absf(sdf) - 0.045, aa))
	return col


static func _px(name: String, p: Vector2, aa: float) -> Color:
	var none := Color(0, 0, 0, 0)
	match name:
		"smile_soft":
			return _stroke(none, _arc(p, Vector2(0, 0.62), 0.8, -125.0, -55.0), 0.06, aa)
		"smile":
			return _stroke(none, _arc(p, Vector2(0, 0.42), 0.6, -152.0, -28.0), 0.065, aa)
		"flat":
			return _stroke(none, _arc(p, Vector2(0, 3.0), 3.04, -97.0, -83.0), 0.06, aa)
		"frown":
			return _stroke(none, _arc(p, Vector2(0, -0.74), 0.66, 52.0, 128.0), 0.065, aa)
		"smirk":
			return _stroke(none, _arc(p, Vector2(0.14, 0.5), 0.6, -128.0, -38.0), 0.06, aa)
		"wavy":
			var x := clampf(p.x, -0.42, 0.42)
			var fy := 0.07 * sin(x * 11.0) - 0.02
			var slope := 0.77 * cos(x * 11.0)
			var d := absf(p.y - fy) / sqrt(1.0 + slope * slope)
			if absf(p.x) > 0.42:
				d = p.distance_to(Vector2(x, fy))
			return _stroke(none, d, 0.055, aa)
		"grin":
			var c := Vector2(0, 0.14)
			var sdf := maxf(p.distance_to(c) - 0.56, p.y - 0.14)
			return _filled(p, sdf, aa, Vector2(0, -0.48), 0.27, 0.02)
		"smirk_open":
			var q := Vector2(p.x, p.y - 0.16 * p.x)
			var sdf2 := maxf(q.distance_to(Vector2(0.04, 0.12)) - 0.5, q.y - 0.12)
			return _filled(p, sdf2, aa, Vector2(0.06, -0.42), 0.24, 0.0 + 0.16 * p.x)
		"open":
			return _filled(p, _ellipse(p, Vector2(0, -0.05), Vector2(0.38, 0.3)), aa, Vector2(0, -0.34), 0.24)
		"open_small":
			return _filled(p, _ellipse(p, Vector2(0, -0.03), Vector2(0.25, 0.17)), aa, Vector2(0, -0.19), 0.14)
		"o":
			return _filled(p, _ellipse(p, Vector2(0, -0.03), Vector2(0.15, 0.19)), aa, Vector2(0, -0.2), 0.1)
		"o_big":
			return _filled(p, _ellipse(p, Vector2(0, -0.08), Vector2(0.3, 0.4)), aa, Vector2(0, -0.44), 0.24)
		"frown_open":
			var c2 := Vector2(0, -0.2)
			var sdf3 := maxf(p.distance_to(c2) - 0.44, -(p.y - -0.2))
			return _filled(p, sdf3, aa, Vector2(0, -0.32), 0.0)
		"shout":
			return _filled(p, _ellipse(p, Vector2(0, -0.08), Vector2(0.44, 0.36)), aa, Vector2(0, -0.4), 0.22, 0.13, -0.33)
		"teeth":
			var sdf4 := _rrect(p, Vector2(0, -0.04), Vector2(0.42, 0.15), 0.08)
			var col := _over(none, TEETH, _cov(sdf4, aa))
			var gaps := minf(minf(absf(p.x + 0.21), absf(p.x)), absf(p.x - 0.21))
			gaps = minf(gaps, absf(p.y + 0.04))
			if sdf4 < 0.0:
				col = _over(col, LINE, _cov(gaps - 0.012, aa))
			col = _over(col, LINE, _cov(absf(sdf4) - 0.04, aa))
			return col
	return none


## Jagged crack lines on a transparent texture (for Baker's shell).
static func crack(seed: int) -> Texture2D:
	var key := "crack%d" % seed
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var segs := []
	var p := Vector2(rng.randf_range(-0.2, 0.2), 0.9)
	var dir := Vector2(rng.randf_range(-0.3, 0.3), -1.0).normalized()
	for i in 9:
		var q := p + dir.rotated(rng.randf_range(-0.7, 0.7)) * rng.randf_range(0.14, 0.24)
		segs.append([p, q, 0.035 * (1.0 - i / 12.0)])
		if i in [2, 5] :
			var br := q + dir.rotated(rng.randf_range(0.9, 1.4) * (1 if rng.randf() < 0.5 else -1)) * 0.22
			segs.append([q, br, 0.022])
		p = q
	var size := 96
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var aa := 1.5 / (size * 0.5)
	for y in size:
		for x in size:
			var u := Vector2((x + 0.5) / (size * 0.5) - 1.0, 1.0 - (y + 0.5) / (size * 0.5))
			var d := 99.0
			var w := 0.03
			for s in segs:
				var dd := Geometry2D.get_closest_point_to_segment(u, s[0], s[1]).distance_to(u)
				if dd < d:
					d = dd
					w = s[2]
			var a := _cov(d - w, aa)
			img.set_pixel(x, y, Color(0.22, 0.13, 0.08, a))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Floor tiles: cream and grey vinyl squares with speckle.
static func floor_tiles() -> Texture2D:
	if _cache.has("floor"):
		return _cache.floor
	var n := 256
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var a := Color(0.86, 0.84, 0.78)
	var b := Color(0.7, 0.72, 0.72)
	for y in n:
		for x in n:
			var tile := ((x / 128) + (y / 128)) % 2
			var c := a if tile == 0 else b
			var grout := mini(mini(x % 128, 127 - x % 128), mini(y % 128, 127 - y % 128))
			if grout < 2:
				c = c.darkened(0.25)
			var s := rng.randf()
			if s > 0.985:
				c = c.darkened(0.18)
			elif s < 0.015:
				c = c.lightened(0.15)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache.floor = tex
	return tex


## Painted cinder blocks for the back hallway.
static func blocks() -> Texture2D:
	if _cache.has("blocks"):
		return _cache.blocks
	var w := 256
	var h := 128
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var base := Color(0.78, 0.8, 0.74)
	for y in h:
		for x in w:
			var row := y / 64
			var xx := (x + (64 if row % 2 == 1 else 0)) % 128
			var yy := y % 64
			var c := base * (0.97 + rng.randf() * 0.05)
			if xx < 3 or yy < 3:
				c = base.darkened(0.22)
			img.set_pixel(x, y, Color(c.r, c.g, c.b))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache.blocks = tex
	return tex
