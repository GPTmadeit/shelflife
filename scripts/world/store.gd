extends RefCounted
## Level construction kit: platforms (collision + visuals), shelves full of
## products (batched into MultiMeshes), signs and lights.

const Meshes = preload("res://scripts/gfx/meshes.gd")
const Mats = preload("res://scripts/gfx/mats.gd")

const LANE := 3.0   ## collision depth across the player's plane (z = 0)

var root: Node3D
var section := "main"        ## products are batched per section (lights cull per object)
var font: Font
var font_ui: Font
var _batches := {}           # "kind:part" -> {mesh, mat, xf: [], col: []}
var _parts := {}             # kind -> [[mesh, Transform3D, role, rough, metal], ...]
var _rng := RandomNumberGenerator.new()


func _init(r: Node3D) -> void:
	root = r
	font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	font_ui = load("res://assets/fonts/Nunito.ttf")
	_rng.seed = 4242
	_define_products()


# --- solids -------------------------------------------------------------------

func mesh(m: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else root).add_child(mi)
	return mi


func box(center: Vector3, size: Vector3, mat: Material, radius := 0.0) -> MeshInstance3D:
	var m: Mesh = Meshes.rounded_box(size, radius, 2) if radius > 0.0 else Meshes.box(size)
	return mesh(m, mat, center)


## Invisible collision box (meta: "cushion", "hide", ...).
func collider(center: Vector3, size: Vector3, meta := {}) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = center
	for k in meta:
		body.set_meta(k, meta[k])
	root.add_child(body)
	return body


## A walkable slab in the play plane: x0..x1, top surface at `top`.
func platform(x0: float, x1: float, top: float, thick: float, mat: Material, z0 := -2.4, z1 := 0.9, radius := 0.0, meta := {}) -> MeshInstance3D:
	var size := Vector3(x1 - x0, thick, z1 - z0)
	var c := Vector3((x0 + x1) * 0.5, top - thick * 0.5, (z0 + z1) * 0.5)
	var mi: MeshInstance3D = null
	if mat != null:
		mi = box(c, size, mat, radius)
	solid_lane(x0, x1, top - thick, top, meta)
	return mi


## Collision only, across the play lane.
func solid_lane(x0: float, x1: float, y0: float, y1: float, meta := {}) -> StaticBody3D:
	return collider(Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, 0.0), Vector3(x1 - x0, y1 - y0, LANE), meta)


func label(text: String, pos: Vector3, height: float, col: Color, outline := 0, outline_col := Color.BLACK, billboard := false, f: Font = null) -> Label3D:
	var t := Label3D.new()
	t.text = text
	t.font = f if f != null else font
	t.font_size = 96
	t.pixel_size = height / 96.0
	t.modulate = col
	t.outline_size = outline
	t.outline_modulate = outline_col
	t.position = pos
	t.double_sided = false
	if billboard:
		t.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(t)
	return t


func omni(pos: Vector3, col: Color, energy: float, rng: float, shadow := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.2
	l.shadow_enabled = shadow
	root.add_child(l)
	return l


func spot(pos: Vector3, target: Vector3, col: Color, energy: float, rng: float, angle: float, shadow := false) -> SpotLight3D:
	var l := SpotLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.spot_range = rng
	l.spot_angle = angle
	l.spot_attenuation = 0.8
	l.shadow_enabled = shadow
	root.add_child(l)
	l.look_at_from_position(pos, target, Vector3.FORWARD if absf((target - pos).normalized().y) > 0.99 else Vector3.UP)
	return l


# --- products -------------------------------------------------------------------

func _t(pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot).scaled(scl), pos)


func _define_products() -> void:
	var white := "fixed:f2f1ea"
	var silver := "fixed:c9ccd2"
	var gold := "fixed:d6a640"
	var cup_prof := PackedVector2Array([Vector2(0, 0), Vector2(0.33, 0), Vector2(0.35, 0.03), Vector2(0.46, 1.04), Vector2(0.5, 1.06), Vector2(0.5, 1.12), Vector2(0, 1.12)])
	var tub_prof := PackedVector2Array([Vector2(0, 0), Vector2(0.72, 0), Vector2(0.75, 0.04), Vector2(0.86, 0.95), Vector2(0, 0.95)])
	var bottle_prof := PackedVector2Array([Vector2(0, 0), Vector2(0.5, 0), Vector2(0.52, 0.05), Vector2(0.52, 2.0), Vector2(0.44, 2.3), Vector2(0.2, 2.6), Vector2(0.17, 3.0), Vector2(0, 3.0)])
	var jar_prof := PackedVector2Array([Vector2(0, 0), Vector2(0.6, 0), Vector2(0.65, 0.08), Vector2(0.65, 1.3), Vector2(0.55, 1.45), Vector2(0, 1.45)])
	var cake_prof := PackedVector2Array([Vector2(0, 0), Vector2(1.6, 0), Vector2(1.6, 1.0), Vector2(1.55, 1.06), Vector2(0, 1.06)])
	_parts = {
		"jug": [
			[Meshes.rounded_box(Vector3(1.8, 2.3, 1.6), 0.4, 2), _t(Vector3(0, 1.15, 0)), white, 0.35, 0.0],
			[Meshes.cyl(0.24, 0.3, 0.45), _t(Vector3(0, 2.45, 0)), white, 0.35, 0.0],
			[Meshes.cyl(0.29, 0.29, 0.2), _t(Vector3(0, 2.75, 0)), "accent", 0.4, 0.0],
			[Meshes.rounded_box(Vector3(1.83, 0.9, 1.63), 0.38, 2), _t(Vector3(0, 1.0, 0)), "main", 0.6, 0.0]],
		"carton": [
			[Meshes.box(Vector3(1.45, 2.4, 1.45)), _t(Vector3(0, 1.2, 0)), "main", 0.7, 0.0],
			[Meshes.prism(Vector3(1.45, 0.55, 1.45)), _t(Vector3(0, 2.675, 0), Vector3(0, PI * 0.5, 0)), "main", 0.7, 0.0],
			[Meshes.box(Vector3(1.47, 1.1, 1.47)), _t(Vector3(0, 1.25, 0)), "accent", 0.7, 0.0]],
		"cup": [
			[Meshes.lathe(cup_prof, 16), _t(Vector3.ZERO), "main", 0.45, 0.0],
			[Meshes.cyl(0.5, 0.5, 0.03, 16), _t(Vector3(0, 1.13, 0)), silver, 0.3, 0.8]],
		"tub": [
			[Meshes.lathe(tub_prof, 18), _t(Vector3.ZERO), white, 0.5, 0.0],
			[Meshes.cyl(0.9, 0.9, 0.14, 18), _t(Vector3(0, 0.99, 0)), "accent", 0.5, 0.0],
			[Meshes.lathe(PackedVector2Array([Vector2(0.79, 0.3), Vector2(0.84, 0.75)]), 18), _t(Vector3.ZERO), "main", 0.6, 0.0]],
		"box": [
			[Meshes.rounded_box(Vector3(1.6, 0.7, 0.95), 0.05, 1), _t(Vector3(0, 0.35, 0)), "main", 0.6, 0.0],
			[Meshes.box(Vector3(1.62, 0.22, 0.97)), _t(Vector3(0, 0.4, 0)), "accent", 0.6, 0.0]],
		"eggbox": [
			[Meshes.rounded_box(Vector3(3.6, 1.25, 1.9), 0.22, 2), _t(Vector3(0, 0.625, 0)), "main", 0.9, 0.0],
			[Meshes.box(Vector3(3.62, 0.08, 1.92)), _t(Vector3(0, 0.62, 0)), "accent", 0.9, 0.0],
			[Meshes.box(Vector3(1.4, 0.5, 0.02)), _t(Vector3(0, 0.95, 0.96)), "accent", 0.7, 0.0]],
		"can": [
			[Meshes.cyl(0.55, 0.55, 1.5, 16), _t(Vector3(0, 0.75, 0)), silver, 0.3, 0.85],
			[Meshes.cyl(0.565, 0.565, 1.25, 16), _t(Vector3(0, 0.75, 0)), "main", 0.6, 0.0]],
		"tallcan": [
			[Meshes.cyl(0.42, 0.42, 2.3, 16), _t(Vector3(0, 1.15, 0)), "main", 0.35, 0.3],
			[Meshes.cyl(0.36, 0.42, 0.5, 16), _t(Vector3(0, 2.55, 0)), "accent", 0.4, 0.0]],
		"bag": [
			[Meshes.rounded_box(Vector3(1.7, 2.2, 0.55), 0.24, 2), _t(Vector3(0, 1.1, 0)), "main", 0.35, 0.0],
			[Meshes.rounded_box(Vector3(1.0, 0.8, 0.58), 0.15, 2), _t(Vector3(0, 0.9, 0.0)), "accent", 0.2, 0.0]],
		"bottle": [
			[Meshes.lathe(bottle_prof, 16), _t(Vector3.ZERO), "main", 0.1, 0.0],
			[Meshes.cyl(0.53, 0.53, 0.9, 16), _t(Vector3(0, 1.1, 0)), "accent", 0.6, 0.0],
			[Meshes.cyl(0.2, 0.2, 0.3, 12), _t(Vector3(0, 3.1, 0)), gold, 0.3, 0.8]],
		"jar": [
			[Meshes.lathe(jar_prof, 16), _t(Vector3.ZERO), "main", 0.15, 0.0],
			[Meshes.cyl(0.6, 0.6, 0.25, 16), _t(Vector3(0, 1.55, 0)), "accent", 0.4, 0.4]],
		"cereal": [
			[Meshes.box(Vector3(2.4, 3.4, 0.8)), _t(Vector3(0, 1.7, 0)), "main", 0.7, 0.0],
			[Meshes.box(Vector3(1.6, 1.4, 0.82)), _t(Vector3(0, 2.0, 0)), "accent", 0.7, 0.0]],
		"soda": [
			[Meshes.box(Vector3(3.4, 1.6, 2.2)), _t(Vector3(0, 0.8, 0)), "main", 0.6, 0.0],
			[Meshes.box(Vector3(3.42, 0.5, 2.22)), _t(Vector3(0, 0.9, 0)), "accent", 0.6, 0.0]],
		"chips": [
			[Meshes.rounded_box(Vector3(2.0, 2.8, 0.9), 0.4, 2), _t(Vector3(0, 1.4, 0)), "main", 0.25, 0.4],
			[Meshes.rounded_box(Vector3(1.2, 0.9, 0.93), 0.2, 2), _t(Vector3(0, 1.6, 0)), "accent", 0.3, 0.0]],
		"loaf": [
			[Meshes.rounded_box(Vector3(3.2, 1.5, 1.8), 0.6, 3), _t(Vector3(0, 0.75, 0)), "main", 0.8, 0.0],
			[Meshes.rounded_box(Vector3(2.9, 0.5, 1.6), 0.24, 2), _t(Vector3(0, 1.3, 0)), "accent", 0.8, 0.0]],
		"baguette": [
			[Meshes.capsule(0.35, 4.2), _t(Vector3(0, 0.35, 0), Vector3(0, 0, PI * 0.5)), "main", 0.8, 0.0]],
		"cake": [
			[Meshes.lathe(cake_prof, 24), _t(Vector3.ZERO), "main", 0.5, 0.0],
			[Meshes.cyl(1.64, 1.64, 0.14, 24), _t(Vector3(0, 0.99, 0)), "accent", 0.35, 0.0]],
		"tag": [
			[Meshes.box(Vector3(0.9, 0.36, 0.04)), _t(Vector3(0, 0.18, 0)), "main", 0.6, 0.0]],
		"crate": [
			[Meshes.box(Vector3(2.6, 2.2, 2.6)), _t(Vector3(0, 1.1, 0)), "main", 0.6, 0.0]],
	}


## Adds one product. `main`/`accent` colour the "main"/"accent" parts.
func product(kind: String, pos: Vector3, main: Color, accent := Color.WHITE, yaw := 0.0, scl := 1.0) -> void:
	var parts: Array = _parts[kind]
	var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scl), pos)
	for i in parts.size():
		var p: Array = parts[i]
		var key := "%s:%s:%d" % [section, kind, i]
		if not _batches.has(key):
			_batches[key] = {"mesh": p[0], "mat": Mats.vcol(p[3], p[4]), "xf": [], "col": []}
		var role: String = p[2]
		var col := main
		if role == "accent":
			col = accent
		elif role.begins_with("fixed:"):
			col = Color.html(role.substr(6))
		_batches[key].xf.append(xf * p[1])
		_batches[key].col.append(col)


## Fills a shelf row with products from x0 to x1 (left to right).
func row(kind: String, x0: float, x1: float, y: float, z: float, gap: float, palette: Array, accent_palette: Array = [], jitter := 0.06) -> void:
	var x := x0
	while x <= x1 + 0.001:
		var c: Color = palette[_rng.randi() % palette.size()]
		var a: Color = accent_palette[_rng.randi() % accent_palette.size()] if accent_palette.size() > 0 else c.lightened(0.35)
		product(kind, Vector3(x + _rng.randf_range(-jitter, jitter), y, z + _rng.randf_range(-jitter, jitter)), c, a, _rng.randf_range(-0.06, 0.06))
		x += gap


## Builds the MultiMesh nodes. Call once after all products are added.
func flush() -> void:
	for key in _batches.keys():
		var b: Dictionary = _batches[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = b.mesh
		mm.instance_count = b.xf.size()
		for i in b.xf.size():
			mm.set_instance_transform(i, b.xf[i])
			mm.set_instance_color(i, b.col[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = b.mat
		mmi.name = "Products_" + key.replace(":", "_")
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
	_batches.clear()
