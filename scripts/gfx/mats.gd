extends RefCounted
## Shared materials, cached by their parameters so identical looks batch.

static var _cache := {}


static func _key(parts: Array) -> String:
	return ",".join(parts.map(func(p): return str(p)))


static func solid(c: Color, rough := 0.6, metal := 0.0, spec := 0.5) -> StandardMaterial3D:
	var k := _key(["s", c.to_html(), rough, metal, spec])
	if _cache.has(k):
		return _cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	m.metallic_specular = spec
	_cache[k] = m
	return m


## Character skin: soft, slightly glossy, with a rim so silhouettes read in the dark.
static func skin(c: Color, rough := 0.5) -> StandardMaterial3D:
	var k := _key(["k", c.to_html(), rough])
	if _cache.has(k):
		return _cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic_specular = 0.45
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.6
	_cache[k] = m
	return m


static func glow(c: Color, energy := 2.0) -> StandardMaterial3D:
	var k := _key(["g", c.to_html(), energy])
	if _cache.has(k):
		return _cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	_cache[k] = m
	return m


static func flat(c: Color) -> StandardMaterial3D:
	var k := _key(["f", c.to_html()])
	if _cache.has(k):
		return _cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cache[k] = m
	return m


## Additive light beams (the Narc's scanner cone).
static func beam(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return m


static func glass(c: Color, rough := 0.05) -> StandardMaterial3D:
	var k := _key(["gl", c.to_html(), rough])
	if _cache.has(k):
		return _cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic_specular = 0.9
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_BACK
	_cache[k] = m
	return m


## Vertex/instance colour as albedo (MultiMesh products, merged props).
static func vcol(rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	var k := _key(["v", rough, metal])
	if _cache.has(k):
		return _cache[k]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	m.metallic = metal
	_cache[k] = m
	return m


static func textured(tex: Texture2D, rough := 0.6, uv_scale := Vector3.ONE, tint := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = tint
	m.roughness = rough
	m.uv1_scale = uv_scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## A decal-ish material for faces and stickers drawn into textures.
static func decal(tex: Texture2D, shaded := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.7
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if not shaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.render_priority = 1
	return m
