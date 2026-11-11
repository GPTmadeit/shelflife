extends Node3D
## A procedurally built food character: a body, a face (eyes, lids, brows,
## mouth) and noodle limbs, all animated procedurally. The rig faces +Z (the
## camera) at rest; its origin is where its feet touch the ground.

const Meshes = preload("res://scripts/gfx/meshes.gd")
const Mats = preload("res://scripts/gfx/mats.gd")
const FaceTex = preload("res://scripts/gfx/face_tex.gd")

## brow: degrees (positive = inner ends down / cross), raise: in eye radii,
## lid: 0 open .. 1 closed, m/mt: mouth at rest / mid-syllable.
const EMO := {
	"neutral": {"brow": 0.0, "raise": 0.0, "lid": 0.14, "m": "smile_soft", "mt": "open_small", "eye": 1.0, "pupil": 1.0},
	"happy": {"brow": -8.0, "raise": 0.3, "lid": 0.06, "m": "smile", "mt": "grin", "eye": 1.0, "pupil": 1.0},
	"excited": {"brow": -12.0, "raise": 0.5, "lid": 0.0, "m": "grin", "mt": "o_big", "eye": 1.12, "pupil": 1.05},
	"sad": {"brow": -24.0, "raise": 0.15, "lid": 0.32, "m": "frown", "mt": "frown_open", "eye": 1.0, "pupil": 1.0},
	"angry": {"brow": 26.0, "raise": -0.2, "lid": 0.3, "m": "teeth", "mt": "shout", "eye": 1.0, "pupil": 0.9},
	"shock": {"brow": -10.0, "raise": 0.7, "lid": 0.0, "m": "o", "mt": "o_big", "eye": 1.22, "pupil": 0.72},
	"scared": {"brow": -26.0, "raise": 0.45, "lid": 0.0, "m": "wavy", "mt": "o", "eye": 1.15, "pupil": 0.68},
	"worried": {"brow": -20.0, "raise": 0.25, "lid": 0.1, "m": "wavy", "mt": "open_small", "eye": 1.04, "pupil": 0.92},
	"smug": {"brow": 10.0, "raise": 0.0, "lid": 0.46, "m": "smirk", "mt": "smirk_open", "eye": 1.0, "pupil": 1.0, "asym": 0.45},
	"sly": {"brow": 14.0, "raise": 0.05, "lid": 0.36, "m": "smirk", "mt": "grin", "eye": 1.0, "pupil": 1.0, "asym": 0.3},
	"deadpan": {"brow": 3.0, "raise": -0.05, "lid": 0.47, "m": "flat", "mt": "open_small", "eye": 1.0, "pupil": 0.95},
	"tired": {"brow": -6.0, "raise": -0.05, "lid": 0.56, "m": "flat", "mt": "open_small", "eye": 1.0, "pupil": 1.0},
	"pious": {"brow": -12.0, "raise": 0.35, "lid": 1.0, "m": "smile", "mt": "open", "eye": 1.0, "pupil": 1.0},
	"disgust": {"brow": 18.0, "raise": -0.1, "lid": 0.36, "m": "frown", "mt": "teeth", "eye": 0.95, "pupil": 0.9},
	"dazed": {"brow": -6.0, "raise": 0.1, "lid": 0.42, "m": "wavy", "mt": "o", "eye": 1.0, "pupil": 0.8},
	"determined": {"brow": 16.0, "raise": -0.1, "lid": 0.22, "m": "flat", "mt": "open", "eye": 1.0, "pupil": 1.0},
}

var spec := {}
var kind := "egg"
var h := 1.0                       ## body height
var simple := false                ## background extras: no lids, brows or limbs
var leg_len := 0.0
var body_pivot: Node3D             ## squash, hops, emotes
var body: Node3D                   ## the body meshes and the face
var face: Node3D
var eyes: Array[Node3D] = []
var aims: Array[Node3D] = []
var pupils: Array[Node3D] = []
var lids: Array[Node3D] = []
var brows: Array[Node3D] = []
var mouth: MeshInstance3D
var mouth_mat: StandardMaterial3D
var arms: Array[Node3D] = []
var legs: Array[Node3D] = []
var extras: Array[Node3D] = []     ## parts that hide in product mode (halo, ...)

var emotion := "neutral"
var talking := false
var speed := 0.0                   ## 0..1 walking speed (set by the owner)
var grounded := true
var vy := 0.0
var facing := 0.0                  ## target yaw, radians
var look := Vector2.ZERO           ## pupil direction, -1..1
var look_target: Node3D = null
var product := false               ## frozen like a product on the shelf (a human is near)
var cracks := 0

# face layout, set by the body builders
var _surf: Callable
var _face_y := 0.6
var _eye_dx := 0.15
var _eye_r := 0.11
var _mouth_y := 0.36
var _mouth_w := 0.34
var _shoulder_y := 0.42
var _shoulder_dx := 0.36
var _hip_dx := 0.13
var _lid_color := Color.WHITE
var _profile := PackedVector2Array()
var _er := 0.1

# animation state
var _emo: Dictionary = EMO.neutral
var _brow := 0.0
var _raise := 0.0
var _lid := 0.14
var _eye := 1.0
var _pupil := 1.0
var _blink_t := 2.0
var _blink := 0.0
var _mouth_t := 0.0
var _mouth_tex := ""
var _phase := 0.0
var _squash := 0.0
var _squash_v := 0.0
var _time := 0.0
var _gesture_t := 0.0
var _arm_goal := [Vector2.ZERO, Vector2.ZERO]
var _glance_t := 1.0
var _glance := Vector2.ZERO
var _face_amt := 1.0
var _emote_tween: Tween
var _crack_nodes: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()


func build(s: Dictionary) -> void:
	spec = s
	kind = s.get("kind", "egg")
	h = s.get("h", 1.0)
	simple = s.get("simple", false)
	_rng.seed = hash(s.get("name", kind)) + randi() % 1000
	_blink_t = _rng.randf_range(0.5, 4.0)
	body_pivot = Node3D.new()
	body_pivot.name = "Pivot"
	add_child(body_pivot)
	body = Node3D.new()
	body.name = "Body"
	body_pivot.add_child(body)
	match kind:
		"egg": _build_egg()
		"cup": _build_cup()
		"jug": _build_jug()
		"bottle": _build_bottle()
		"can": _build_can()
		"donut": _build_donut()
		"boule": _build_boule()
		"roll": _build_roll()
		_: _build_egg()
	body.position.y = leg_len
	if not s.get("faceless", false):
		_build_face()
	if not simple:
		_build_limbs()
	set_emotion(s.get("emotion", "neutral"))


# --- bodies -------------------------------------------------------------------

func _mi(mesh: Mesh, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	(parent if parent != null else body).add_child(m)
	return m


func _lathe_surf(profile: PackedVector2Array, scale := 1.0) -> Callable:
	return func(x: float, y: float) -> float:
		var r: float = Meshes.profile_radius(profile, y) * scale
		return sqrt(maxf(r * r - x * x, 0.0))


func _build_egg() -> void:
	var col: Color = spec.get("color", Color(0.97, 0.94, 0.86))
	var w := h * 0.76
	_profile = Meshes.egg_profile(h, w)
	_mi(Meshes.lathe(_profile, 30), Mats.skin(col, 0.55))
	_surf = _lathe_surf(_profile)
	_lid_color = col
	_face_y = h * 0.6
	_eye_dx = h * 0.155
	_eye_r = h * 0.128
	_mouth_y = h * 0.355
	_mouth_w = h * 0.38
	_shoulder_y = h * 0.42
	_shoulder_dx = Meshes.profile_radius(_profile, _shoulder_y) - 0.02 * h
	_hip_dx = h * 0.13
	leg_len = h * 0.2 if spec.get("legs", false) else 0.0
	if spec.get("feather", false):
		var f := _mi(Meshes.rounded_box(Vector3(0.05, 0.3, 0.012) * h, 0.012 * h, 2), Mats.skin(Color(0.95, 0.9, 0.82), 0.8))
		f.name = "Feather"
		f.position = Vector3(-0.2 * h, 0.86 * h, 0.12 * h)
		f.rotation = Vector3(0.3, 0.2, 0.7)


func _build_cup() -> void:
	var col: Color = spec.get("color", Color(0.93, 0.45, 0.55))
	var band: Color = spec.get("accent", Color(0.98, 0.96, 0.9))
	var rt := 0.47 * h
	var rb := 0.35 * h
	var prof := PackedVector2Array([Vector2(0, 0), Vector2(rb * 0.9, 0), Vector2(rb, 0.03 * h),
		Vector2(rt * 0.97, 0.9 * h), Vector2(rt * 1.07, 0.91 * h), Vector2(rt * 1.07, 0.97 * h),
		Vector2(rt, 0.98 * h), Vector2(0, 0.98 * h)])
	_mi(Meshes.lathe(prof, 28), Mats.skin(col, 0.45))
	var bp := PackedVector2Array()
	for k in 5:
		var y := lerpf(0.2 * h, 0.82 * h, k / 4.0)
		bp.append(Vector2(Meshes.profile_radius(prof, y) * 1.012, y))
	_mi(Meshes.lathe(bp, 28), Mats.skin(band, 0.6))
	var lid := _mi(Meshes.cyl(rt * 1.07, rt * 1.07, 0.025 * h), Mats.solid(Color(0.82, 0.84, 0.88), 0.28, 0.85))
	lid.position.y = 0.99 * h
	var tab := _mi(Meshes.box(Vector3(0.12, 0.012, 0.16) * h), Mats.solid(Color(0.82, 0.84, 0.88), 0.28, 0.85))
	tab.position = Vector3(rt * 0.85, 0.995 * h, rt * 0.75)
	tab.rotation.y = 0.7
	_profile = bp
	_surf = _lathe_surf(prof, 1.016)
	_lid_color = band
	_face_y = 0.63 * h
	_eye_dx = 0.15 * h
	_eye_r = 0.1 * h
	_mouth_y = 0.39 * h
	_mouth_w = 0.3 * h
	_shoulder_y = 0.5 * h
	_shoulder_dx = Meshes.profile_radius(prof, _shoulder_y)
	_hip_dx = 0.12 * h


func _build_jug() -> void:
	var plastic := Color(0.94, 0.94, 0.9)
	var label: Color = spec.get("accent", Color(0.72, 0.6, 0.86))
	var cap: Color = spec.get("color", Color(0.85, 0.35, 0.7))
	var b := _mi(Meshes.rounded_box(Vector3(0.62, 0.74, 0.58) * h, 0.15 * h), Mats.skin(plastic, 0.32))
	b.position.y = 0.37 * h
	var neck := _mi(Meshes.cyl(0.08 * h, 0.1 * h, 0.16 * h), Mats.skin(plastic, 0.32))
	neck.position.y = 0.78 * h
	var c := _mi(Meshes.cyl(0.095 * h, 0.095 * h, 0.065 * h), Mats.skin(cap, 0.4))
	c.position.y = 0.88 * h
	var handle := _mi(Meshes.torus(0.065 * h, 0.11 * h), Mats.skin(plastic, 0.32))
	handle.position = Vector3(0.2 * h, 0.71 * h, -0.12 * h)
	handle.rotation.z = PI * 0.5
	var lb := _mi(Meshes.rounded_box(Vector3(0.632, 0.3, 0.592) * h, 0.12 * h), Mats.skin(label, 0.6))
	lb.position.y = 0.3 * h
	if spec.get("collar", false):
		# a clerical collar around the neck: black band, white tab
		var band := _mi(Meshes.cyl(0.112 * h, 0.118 * h, 0.05 * h), Mats.skin(Color(0.08, 0.08, 0.1), 0.5))
		band.position.y = 0.79 * h
		var tab := _mi(Meshes.box(Vector3(0.06, 0.035, 0.02) * h), Mats.skin(Color(0.98, 0.98, 0.97), 0.4))
		tab.position = Vector3(0, 0.79 * h, 0.118 * h)
	var front := 0.296 * h
	_surf = func(_x: float, _y: float) -> float: return front
	_lid_color = label
	_face_y = 0.37 * h
	_eye_dx = 0.1 * h
	_eye_r = 0.066 * h
	_mouth_y = 0.235 * h
	_mouth_w = 0.17 * h
	_shoulder_y = 0.46 * h
	_shoulder_dx = 0.31 * h
	_hip_dx = 0.15 * h
	if spec.has("label"):
		var t := _label3d(spec.label, 0.045 * h, Color(1, 1, 1))
		t.position = Vector3(0, 0.13 * h, front + 0.004)
		body.add_child(t)


func _build_bottle() -> void:
	var glass: Color = spec.get("color", Color(0.09, 0.24, 0.1))
	var label: Color = spec.get("accent", Color(0.96, 0.91, 0.76))
	var r := 0.125 * h
	var prof := PackedVector2Array([Vector2(0, 0), Vector2(r * 0.95, 0), Vector2(r, 0.012 * h),
		Vector2(r, 0.6 * h), Vector2(r * 0.94, 0.66 * h), Vector2(r * 0.68, 0.74 * h),
		Vector2(r * 0.36, 0.8 * h), Vector2(r * 0.32, 0.9 * h), Vector2(r * 0.38, 0.91 * h),
		Vector2(r * 0.38, 0.93 * h), Vector2(0, 0.93 * h)])
	var gm := Mats.skin(glass, 0.08)
	_mi(Meshes.lathe(prof, 28), gm)
	var lp := PackedVector2Array([Vector2(r * 1.012, 0.16 * h), Vector2(r * 1.012, 0.53 * h)])
	_mi(Meshes.lathe(lp, 28), Mats.skin(label, 0.6))
	var gold := Mats.solid(Color(0.85, 0.66, 0.25), 0.25, 0.9)
	for y in [0.16, 0.53]:
		var tp := PackedVector2Array([Vector2(r * 1.02, (y - 0.008) * h), Vector2(r * 1.02, (y + 0.008) * h)])
		_mi(Meshes.lathe(tp, 28), gold)
	var cap := _mi(Meshes.cyl(r * 0.42, r * 0.42, 0.07 * h), gold)
	cap.position.y = 0.965 * h
	_surf = _lathe_surf(lp, 1.0)
	_surf = func(x: float, _y: float) -> float: return sqrt(maxf(r * r * 1.025 - x * x, 0.0))
	_lid_color = label
	_face_y = 0.42 * h
	_eye_dx = 0.045 * h
	_eye_r = 0.031 * h
	_mouth_y = 0.29 * h
	_mouth_w = 0.075 * h
	_shoulder_y = 0.5 * h
	_shoulder_dx = r
	_hip_dx = r * 0.5
	if spec.get("halo", false):
		var halo := _mi(Meshes.torus(0.07 * h, 0.085 * h, 32, 8), Mats.glow(Color(1.0, 0.82, 0.35), 2.2))
		halo.position.y = 1.06 * h
		halo.rotation.x = 0.25
		extras.append(halo)
	if spec.has("label"):
		var t := _label3d(spec.label, 0.016 * h, Color(0.4, 0.3, 0.12))
		t.position = Vector3(0, 0.2 * h, r * 1.03)
		body.add_child(t)


func _build_can() -> void:
	var label: Color = spec.get("color", Color(0.83, 0.42, 0.16))
	var metal := Mats.solid(Color(0.75, 0.76, 0.78), 0.3, 0.9)
	var r := 0.4 * h
	var prof := PackedVector2Array([Vector2(0, 0), Vector2(r * 0.94, 0), Vector2(r, 0.025 * h),
		Vector2(r, 0.975 * h), Vector2(r * 0.94, h), Vector2(0, h)])
	_mi(Meshes.lathe(prof, 26), metal)
	var lp := PackedVector2Array([Vector2(r * 1.01, 0.08 * h), Vector2(r * 1.01, 0.92 * h)])
	_mi(Meshes.lathe(lp, 26), Mats.skin(label, 0.6))
	body.scale = Vector3(1.04, 1.0, 0.94)
	body.rotation.z = spec.get("tilt", 0.0)
	_surf = func(x: float, _y: float) -> float: return sqrt(maxf(r * r * 1.03 - x * x, 0.0))
	_lid_color = label
	_face_y = 0.6 * h
	_eye_dx = 0.13 * h
	_eye_r = 0.085 * h
	_mouth_y = 0.36 * h
	_mouth_w = 0.24 * h
	_shoulder_y = 0.5 * h
	_shoulder_dx = r
	_hip_dx = 0.15 * h


func _build_donut() -> void:
	var dough: Color = spec.get("color", Color(0.8, 0.52, 0.26))
	var glaze: Color = spec.get("accent", Color(0.97, 0.82, 0.58))
	var outer := 0.5 * h
	var inner := 0.16 * h
	var R := (outer + inner) * 0.5
	var a := (outer - inner) * 0.5
	leg_len = 0.17 * h if spec.get("legs", false) else 0.0
	var cy := outer
	var ring := _mi(Meshes.torus(inner, outer, 32, 16), Mats.skin(dough, 0.85))
	ring.position.y = cy
	ring.rotation.x = PI * 0.5
	var ga := a * 1.06
	var gl := _mi(Meshes.torus(R - ga, R + ga, 32, 14), Mats.skin(glaze, 0.14))
	gl.position = Vector3(0, cy, a * 0.25)
	gl.rotation.x = PI * 0.5
	gl.scale = Vector3(1, 0.72, 1)
	var front := func(x: float, y: float) -> float:
		var rho := Vector2(x, y - cy).length()
		var dz := a * a - (rho - R) * (rho - R)
		var gz := ga * ga - (rho - R) * (rho - R)
		var zb := sqrt(maxf(dz, 0.0))
		var zg := a * 0.25 + 0.72 * sqrt(maxf(gz, 0.0)) if gz > 0.0 else 0.0
		return maxf(zb, zg)
	_surf = front
	_lid_color = glaze
	_face_y = cy + 0.3 * h
	_eye_dx = 0.13 * h
	_eye_r = 0.085 * h
	_mouth_y = cy - 0.31 * h
	_mouth_w = 0.26 * h
	_shoulder_y = cy
	_shoulder_dx = outer - 0.02 * h
	_hip_dx = 0.12 * h
	if spec.get("sticker", false):
		var sp := Vector2(0.25 * h, cy + 0.19 * h)
		var sz: float = front.call(sp.x, sp.y)
		var st := _mi(Meshes.cyl(0.1 * h, 0.1 * h, 0.012 * h, 20), Mats.skin(Color(1.0, 0.83, 0.12), 0.5))
		st.position = Vector3(sp.x, sp.y, sz + 0.004 * h)
		st.rotation.x = PI * 0.5
		var t := _label3d("50%", 0.05 * h, Color(0.15, 0.1, 0.05))
		t.position = Vector3(sp.x, sp.y, sz + 0.014 * h)
		body.add_child(t)


func _build_boule() -> void:
	var crust: Color = spec.get("color", Color(0.74, 0.5, 0.26))
	var w: float = spec.get("w", h * 1.75)
	var prof := Meshes.dome_profile(w, h, 16, 0.1)
	_mi(Meshes.lathe(prof, 30), Mats.skin(crust, 0.85))
	var top := PackedVector2Array()
	for p in prof:
		if p.y >= 0.68 * h:
			top.append(Vector2(p.x * 1.012, p.y + 0.004 * h))
	top.insert(0, Vector2(Meshes.profile_radius(prof, 0.68 * h) * 1.012, 0.68 * h))
	_mi(Meshes.lathe(top, 30), Mats.skin(Color(0.93, 0.87, 0.74), 0.95))
	var score := Mats.solid(Color(0.5, 0.3, 0.13), 0.9)
	for k in 3:
		var pts := PackedVector3Array()
		var zz := (k - 1) * 0.11 * w
		for i in 9:
			var x := lerpf(-0.17, 0.17, i / 8.0) * w
			var rr := Vector2(x, zz).length()
			pts.append(Vector3(x, _dome_height(prof, rr) + 0.005 * h, zz))
		_mi(Meshes.tube(pts, 0.022 * h, 5), score)
	_surf = _lathe_surf(prof, 1.0)
	_lid_color = crust
	_face_y = 0.56 * h
	_eye_dx = 0.1 * w
	_eye_r = 0.09 * h
	_mouth_y = 0.33 * h
	_mouth_w = 0.17 * w
	_shoulder_y = 0.4 * h
	_shoulder_dx = Meshes.profile_radius(prof, _shoulder_y) - 0.02
	_hip_dx = 0.2 * w


## Height of a lathe dome at radius r (the profile shrinks as it rises).
func _dome_height(prof: PackedVector2Array, r: float) -> float:
	for i in range(prof.size() - 1, 0, -1):
		var a := prof[i]
		var b := prof[i - 1]
		if r >= a.x and r <= b.x:
			return lerpf(a.y, b.y, (r - a.x) / maxf(b.x - a.x, 1e-6))
	return prof[prof.size() - 1].y


func _build_roll() -> void:
	var col: Color = spec.get("color", Color(0.86, 0.6, 0.3))
	var w: float = spec.get("w", h * 1.45)
	var prof := Meshes.dome_profile(w, h, 12, 0.18)
	_mi(Meshes.lathe(prof, 24), Mats.skin(col, 0.3))
	_surf = _lathe_surf(prof, 1.0)
	_lid_color = col
	_face_y = 0.55 * h
	_eye_dx = 0.13 * w
	_eye_r = 0.1 * h
	_mouth_y = 0.3 * h
	_mouth_w = 0.24 * w
	_shoulder_y = 0.35 * h
	_shoulder_dx = Meshes.profile_radius(prof, _shoulder_y)
	_hip_dx = 0.2 * w


func _label3d(text: String, size: float, col: Color) -> Label3D:
	var t := Label3D.new()
	t.text = text
	t.font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	t.font_size = 64
	t.pixel_size = size / 64.0
	t.modulate = col
	t.outline_size = 0
	t.double_sided = false
	return t


# --- face and limbs -----------------------------------------------------------

func _build_face() -> void:
	face = Node3D.new()
	face.name = "Face"
	body.add_child(face)
	var er: float = _eye_r * spec.get("eye", 1.0)
	_er = er
	var white := Mats.solid(Color(0.97, 0.97, 0.95), 0.2, 0.0, 0.6)
	var black := Mats.solid(Color(0.035, 0.03, 0.035), 0.1, 0.0, 0.85)
	var brow_col: Color = spec.get("brow", Color(0.2, 0.12, 0.1))
	for side in [-1, 1]:
		var ex: float = side * _eye_dx
		var ez: float = _surf.call(ex, _face_y)
		var root := Node3D.new()
		root.position = Vector3(ex, _face_y, ez - er * 0.42)
		root.rotation.y = atan2(ex, maxf(ez, 0.01)) * 0.7
		face.add_child(root)
		_mi(Meshes.sphere(er, 20, 12), white, root)
		var aim := Node3D.new()
		root.add_child(aim)
		var pupil := _mi(Meshes.sphere(er * 0.5, 14, 8), black, aim)
		pupil.position = Vector3(0, 0, er * 0.79)
		pupil.scale = Vector3(1, 1, 0.55)
		pupils.append(pupil)
		var glint := _mi(Meshes.sphere(er * 0.13, 8, 5), Mats.flat(Color(1, 1, 1)), aim)
		glint.position = Vector3(er * 0.17, er * 0.19, er * 1.02)
		eyes.append(root)
		aims.append(aim)
		if not simple:
			var lp := Node3D.new()
			root.add_child(lp)
			_mi(Meshes.hemi(er * 1.08, 18, 8), Mats.skin(_lid_color, 0.55), lp)
			lids.append(lp)
			var by := _face_y + er * 1.5
			var bx := ex * 1.05
			var brow := _mi(Meshes.rounded_box(Vector3(er * 1.3, er * 0.32, er * 0.32), er * 0.15, 2), Mats.solid(brow_col, 0.7), face)
			brow.position = Vector3(bx, by, _surf.call(bx, by) + er * 0.1)
			brow.rotation.y = root.rotation.y
			brows.append(brow)
	mouth_mat = Mats.decal(FaceTex.mouth("smile_soft"))
	mouth = MeshInstance3D.new()
	mouth.mesh = Meshes.surface_patch(_mouth_w, _mouth_w * 0.75, Vector2(0, _mouth_y), _surf, 0.006 * h, 8, 6)
	mouth.material_override = mouth_mat
	face.add_child(mouth)
	_mouth_tex = "smile_soft"


func _build_limbs() -> void:
	var limb := Mats.solid(spec.get("limb", Color(0.16, 0.13, 0.13)), 0.6)
	var glove := Mats.skin(spec.get("glove", Color(0.97, 0.96, 0.93)), 0.5)
	var shoe := Mats.skin(spec.get("shoe", Color(0.85, 0.2, 0.2)), 0.45)
	# limb sizes are absolute for big characters (cast sets them), else from h
	var t: float = spec.get("limb_t", 0.035 * h)
	if spec.get("arms", true):
		var L: float = spec.get("arm_len", h * 0.3)
		for side in [-1, 1]:
			var piv := Node3D.new()
			piv.position = Vector3(side * _shoulder_dx, _shoulder_y, 0.0)
			body.add_child(piv)
			var arm := _mi(Meshes.capsule(t, L), limb, piv)
			arm.position.y = -L * 0.5
			var hand := _mi(Meshes.sphere(spec.get("hand", h * 0.07), 12, 8), glove, piv)
			hand.position.y = -L
			piv.rotation.z = side * 0.32
			arms.append(piv)
	if leg_len > 0.0:
		for side in [-1, 1]:
			var piv := Node3D.new()
			piv.position = Vector3(side * _hip_dx, leg_len + 0.02 * h, 0.0)
			body_pivot.add_child(piv)
			var leg := _mi(Meshes.capsule(t, leg_len + 0.06 * h), limb, piv)
			leg.position.y = -leg_len * 0.5
			var s := _mi(Meshes.rounded_box(Vector3(0.14, 0.08, 0.21) * h, 0.035 * h, 2), shoe, piv)
			s.position = Vector3(0, -leg_len + 0.02 * h, 0.04 * h)
			legs.append(piv)


# --- control ------------------------------------------------------------------

func set_emotion(name: String) -> void:
	if not EMO.has(name):
		name = "neutral"
	emotion = name
	_emo = EMO[name]


## Opens the mouth for one syllable (called per voice blip).
func talk_pulse() -> void:
	_mouth_t = 0.085


func face_dir(d: float) -> void:
	facing = clampf(d, -1.0, 1.0) * 0.62


func face_toward(x: float) -> void:
	face_dir(signf(x - global_position.x))


## Squash on landing; strength ~ 0..1.5
func land(strength := 1.0) -> void:
	_squash = 0.22 * strength
	_squash_v = 0.0


func hop_stretch() -> void:
	_squash = -0.16
	_squash_v = 0.0


func set_product(on: bool) -> void:
	product = on


func set_cracks(n: int) -> void:
	cracks = n
	while _crack_nodes.size() < n and _crack_nodes.size() < 3:
		var k := _crack_nodes.size()
		var spots := [Vector2(-0.17, 0.74), Vector2(0.2, 0.42), Vector2(-0.05, 0.25)]
		var sp: Vector2 = spots[k] * h
		var m := _mi(Meshes.surface_patch(0.32 * h, 0.32 * h, sp, _surf, 0.004 * h, 6, 6), Mats.decal(FaceTex.crack(31 + k * 7)))
		m.name = "Crack%d" % k
		_crack_nodes.append(m)
	while _crack_nodes.size() > n:
		_crack_nodes.pop_back().queue_free()


func emote(name: String) -> void:
	if _emote_tween:
		_emote_tween.kill()
	body_pivot.position = Vector3.ZERO
	body_pivot.rotation = Vector3.ZERO
	var tw := create_tween()
	_emote_tween = tw
	match name:
		"hop", "gasp", "cheer":
			hop_stretch()
			tw.tween_property(body_pivot, "position:y", 0.32 * h, 0.13).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			tw.tween_property(body_pivot, "position:y", 0.0, 0.16).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			tw.tween_callback(land.bind(0.7))
			if name == "cheer":
				_arm_goal = [Vector2(-2.4, 0.0), Vector2(2.4, 0.0)]
				_gesture_t = 0.6
		"shake":
			for k in 4:
				tw.tween_property(body_pivot, "rotation:z", 0.14 if k % 2 == 0 else -0.14, 0.06)
			tw.tween_property(body_pivot, "rotation:z", 0.0, 0.06)
		"nod":
			for k in 2:
				tw.tween_property(body_pivot, "rotation:x", 0.16, 0.1)
				tw.tween_property(body_pivot, "rotation:x", 0.0, 0.12)
		"shiver":
			for k in 10:
				tw.tween_property(body_pivot, "position:x", 0.025 * h * (1 if k % 2 == 0 else -1), 0.03)
			tw.tween_property(body_pivot, "position:x", 0.0, 0.03)
		"spin":
			tw.tween_property(body_pivot, "rotation:y", TAU, 0.5).set_trans(Tween.TRANS_CUBIC)
			tw.tween_callback(func(): body_pivot.rotation.y = 0.0)
		"faint":
			tw.tween_property(body_pivot, "rotation:z", 1.35, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
			tw.tween_callback(land.bind(0.6))
		"recover":
			body_pivot.rotation.z = 1.35
			tw.tween_property(body_pivot, "rotation:z", 0.0, 0.4).set_trans(Tween.TRANS_BACK)
		"lean":
			tw.tween_property(body_pivot, "rotation:x", 0.22, 0.2)
			tw.tween_interval(0.5)
			tw.tween_property(body_pivot, "rotation:x", 0.0, 0.3)
		"shrug":
			_arm_goal = [Vector2(-1.3, -0.4), Vector2(1.3, -0.4)]
			_gesture_t = 0.7
			tw.tween_interval(0.01)
		"point":
			_arm_goal = [Vector2(-0.3, 0.0), Vector2(1.6, -0.6)]
			_gesture_t = 1.0
			tw.tween_interval(0.01)
		_:
			tw.tween_interval(0.01)


# --- animation ------------------------------------------------------------------

func _process(dt: float) -> void:
	_time += dt
	var k := 1.0 - exp(-dt * 12.0)
	_brow = lerpf(_brow, _emo.brow, k)
	_raise = lerpf(_raise, _emo.raise, k)
	_lid = lerpf(_lid, _emo.lid, k)
	_eye = lerpf(_eye, _emo.eye, k)
	_pupil = lerpf(_pupil, _emo.pupil, k)
	# blinking
	_blink_t -= dt
	if _blink_t <= 0.0:
		_blink = 0.14
		_blink_t = _rng.randf_range(1.8, 5.0)
	var closed := _lid
	if _blink > 0.0:
		_blink -= dt
		closed = 1.0
	if product:
		closed = 1.0
	var lid_rot := deg_to_rad(lerpf(-92.0, 92.0, closed))
	for lp in lids:
		lp.rotation.x = lid_rot
	for e in eyes:
		e.scale = Vector3.ONE * _eye
	# pupils: a target, else idle glances
	var want := look
	if look_target != null and is_instance_valid(look_target):
		var lt := to_local(look_target.global_position + Vector3(0, 0.6, 0))
		var rel := lt - Vector3(0, leg_len + _face_y, 0)
		want = Vector2(clampf(rel.x * 0.35, -1.0, 1.0), clampf(rel.y * 0.35, -1.0, 1.0))
	else:
		_glance_t -= dt
		if _glance_t <= 0.0:
			_glance_t = _rng.randf_range(1.0, 3.5)
			_glance = Vector2(_rng.randf_range(-0.7, 0.7), _rng.randf_range(-0.35, 0.35)) if _rng.randf() < 0.6 else Vector2.ZERO
		want = look + _glance
	for a in aims:
		var r := a.rotation
		r.x = lerpf(r.x, -want.y * 0.42, 1.0 - exp(-dt * 18.0))
		r.y = lerpf(r.y, want.x * 0.5, 1.0 - exp(-dt * 18.0))
		a.rotation = r
	for p in pupils:
		p.scale = Vector3(_pupil, _pupil, 0.55 * _pupil)
		p.position.z = _er * (1.05 - 0.275 * _pupil)
	# brows
	var asym: float = _emo.get("asym", 0.0)
	for i in brows.size():
		var side := -1.0 if i == 0 else 1.0
		brows[i].rotation.z = side * deg_to_rad(_brow)
		var by := _face_y + _eye_r * 1.5 + (_raise + (asym if i == 1 else 0.0)) * _eye_r
		brows[i].position.y = by
	# mouth
	_mouth_t -= dt
	var mt: String = _emo.mt if _mouth_t > 0.0 else _emo.m
	if mt != _mouth_tex and mouth_mat != null:
		_mouth_tex = mt
		mouth_mat.albedo_texture = FaceTex.mouth(mt)
	# facing
	rotation.y = lerp_angle(rotation.y, facing, 1.0 - exp(-dt * 9.0))
	# walk cycle / idle
	var bob := 0.0
	if speed > 0.05 and grounded:
		_phase += dt * (8.0 + speed * 6.0)
		bob = absf(sin(_phase)) * 0.07 * h * speed
		body.rotation.z = sin(_phase) * 0.08 * speed
		for i in legs.size():
			legs[i].rotation.x = sin(_phase + PI * i) * 0.75 * speed
	else:
		bob = sin(_time * 2.2) * 0.008 * h
		body.rotation.z = lerpf(body.rotation.z, 0.0, k)
		for lg in legs:
			lg.rotation.x = lerpf(lg.rotation.x, 0.0, k)
	if talking:
		bob += absf(sin(_time * 11.0)) * 0.012 * h
	body.position.y = leg_len + bob
	# arms: walking swing, talking gestures, or rest
	if talking or _gesture_t > 0.0:
		_gesture_t -= dt
		if talking and _gesture_t <= 0.0:
			_gesture_t = _rng.randf_range(0.35, 0.9)
			for i in 2:
				var side := -1.0 if i == 0 else 1.0
				_arm_goal[i] = Vector2(side * _rng.randf_range(0.2, 1.4), _rng.randf_range(-0.7, 0.2)) if _rng.randf() < 0.65 else Vector2(side * 0.32, 0.0)
	for i in arms.size():
		var side := -1.0 if i == 0 else 1.0
		var goal: Vector2 = _arm_goal[i] if (talking or _gesture_t > 0.0) else Vector2(side * 0.32, 0.0)
		if speed > 0.05 and grounded:
			goal = Vector2(side * 0.4, -sin(_phase + PI * i) * 0.7 * speed)
		if not grounded:
			goal = Vector2(side * 1.9, -0.2)
		arms[i].rotation.z = lerpf(arms[i].rotation.z, goal.x, 1.0 - exp(-dt * 10.0))
		arms[i].rotation.x = lerpf(arms[i].rotation.x, goal.y, 1.0 - exp(-dt * 10.0))
	# squash spring + air stretch
	_squash_v += (-_squash * 230.0 - _squash_v * 15.0) * dt
	_squash += _squash_v * dt
	var air := 0.0
	if not grounded:
		air = clampf(-vy * 0.006, -0.08, 0.1) * -1.0
	var sq := clampf(_squash + air, -0.3, 0.35)
	body_pivot.scale = Vector3(1.0 + sq * 0.55, 1.0 - sq, 1.0 + sq * 0.55)
	# product mode: the face and limbs tuck away
	_face_amt = move_toward(_face_amt, 0.0 if product else 1.0, dt * 4.0)
	var fa := ease(_face_amt, 0.5)
	if face != null:
		face.scale = Vector3.ONE * maxf(fa, 0.001)
		face.visible = _face_amt > 0.01
	for a in arms:
		a.scale = Vector3.ONE * maxf(fa, 0.001)
		a.visible = _face_amt > 0.01
	for x in extras:
		x.visible = _face_amt > 0.5


## Head position in world space (for camera framing and speech bubbles).
func head_pos() -> Vector3:
	return global_position + Vector3(0, leg_len + h, 0)
