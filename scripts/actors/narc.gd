extends Node3D
## The Narc: the store's floor-scanning robot. It patrols back and forth and
## sweeps the floor ahead with its scanner. Anything on the floor that isn't
## floor gets reported ("Cleanup on aisle four"). Stay off the floor, or out
## of the beam, or under something.

const Meshes = preload("res://scripts/gfx/meshes.gd")
const Mats = preload("res://scripts/gfx/mats.gd")

const RANGE := 11.0
const NOTICE := 0.45          ## seconds in the beam before it's sure

signal spotted(x: float)

var id := "narc"
var x_min := 0.0
var x_max := 10.0
var spd := 2.7
var dir := 1.0
var state := "patrol"         ## patrol | pause | alert | off
var player: Node3D
var suspicion := 0.0
var _t := 0.0
var _beep_t := 1.0
var _turn := 1.0
var _cone: MeshInstance3D
var _cone_mat: StandardMaterial3D
var _lens_mat: StandardMaterial3D
var _scan_light: SpotLight3D
var _pupils: Array[Node3D] = []
var _pupil_v := Vector2.ZERO
var _pupil_p := Vector2.ZERO
var _last_x := 0.0
var _vx := 0.0
var _talk_t := 0.0
var _body: Node3D
var _scanner: Node3D


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	var dark := Mats.solid(Color(0.2, 0.21, 0.24), 0.5)
	var shell := Mats.skin(Color(0.84, 0.86, 0.88), 0.35)
	var blue := Mats.solid(Color(0.16, 0.45, 0.92), 0.4)
	var black := Mats.solid(Color(0.05, 0.05, 0.06), 0.5)
	_m(Meshes.rounded_box(Vector3(6.4, 1.8, 4.0), 0.5, 2), dark, Vector3(0, 1.25, 0))
	_m(Meshes.rounded_box(Vector3(6.6, 0.42, 4.2), 0.2, 2), Mats.solid(Color(1.0, 0.78, 0.1), 0.5), Vector3(0, 0.85, 0))
	for wx in [-2.4, 2.4]:
		for wz in [-1.7, 1.7]:
			_m(Meshes.cyl(0.55, 0.55, 0.5, 16), black, Vector3(wx, 0.55, wz), Vector3(PI * 0.5, 0, 0))
	_m(Meshes.rounded_box(Vector3(4.6, 16.0, 3.4), 0.9, 3), shell, Vector3(0, 9.9, -0.2))
	_m(Meshes.rounded_box(Vector3(4.66, 0.7, 3.46), 0.3, 2), blue, Vector3(0, 4.6, -0.2))
	_m(Meshes.rounded_box(Vector3(4.66, 0.3, 3.46), 0.12, 2), blue, Vector3(0, 5.3, -0.2))
	# googly eyes on the camera side
	var white := Mats.solid(Color(0.98, 0.98, 0.96), 0.15)
	for ex in [-1.05, 1.05]:
		var e := _m(Meshes.sphere(1.05, 20, 12), white, Vector3(ex, 12.6, 1.25))
		e.scale = Vector3(1, 1, 0.45)
		var p := Node3D.new()
		p.position = Vector3(ex, 12.6, 1.62)
		_body.add_child(p)
		var pm := MeshInstance3D.new()
		pm.mesh = Meshes.sphere(0.5, 14, 8)
		pm.scale = Vector3(1, 1, 0.4)
		pm.material_override = black
		p.add_child(pm)
		_pupils.append(p)
	var t := Label3D.new()
	t.text = "HI! I KEEP\nYOU SAFE!"
	t.font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	t.font_size = 96
	t.pixel_size = 0.0075
	t.modulate = Color(0.16, 0.45, 0.92)
	t.position = Vector3(0, 8.7, 1.52)
	_body.add_child(t)
	# scanner lens + beam (mirrored to face the travel direction)
	_scanner = Node3D.new()
	add_child(_scanner)
	_lens_mat = Mats.glow(Color(0.35, 0.75, 1.0), 3.0).duplicate()
	var lens := _m(Meshes.rounded_box(Vector3(0.3, 0.5, 2.4), 0.12, 2), _lens_mat, Vector3(3.25, 1.5, 0))
	lens.name = "Lens"
	lens.reparent(_scanner)
	_cone_mat = Mats.beam(Color(0.3, 0.65, 1.0, 0.16))
	_cone = MeshInstance3D.new()
	var cone_mesh := Meshes.cyl(2.6, 0.18, RANGE - 3.0, 20)
	cone_mesh.cap_top = false
	cone_mesh.cap_bottom = false
	_cone.mesh = cone_mesh
	_cone.material_override = _cone_mat
	# lay the cone along +x from the lens, tilted down onto the floor
	_cone.rotation = Vector3(0, 0, PI * 0.5 + 0.1)
	_cone.position = Vector3(3.3 + (RANGE - 3.0) * 0.5, 1.0, 0.9)
	_cone.scale = Vector3(1, 1, 0.55)
	_scanner.add_child(_cone)
	_scan_light = SpotLight3D.new()
	_scan_light.light_color = Color(0.4, 0.75, 1.0)
	_scan_light.light_energy = 3.0
	_scan_light.spot_range = RANGE + 2.0
	_scan_light.spot_angle = 18.0
	_scan_light.position = Vector3(3.3, 1.6, 0.6)
	_scan_light.rotation = Vector3(0, -PI * 0.5, 0)
	_scan_light.rotate_object_local(Vector3.RIGHT, -0.12)
	_scanner.add_child(_scan_light)
	_last_x = global_position.x


func _m(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	_body.add_child(mi)
	return mi


func _physics_process(dt: float) -> void:
	_t += dt
	match state:
		"patrol":
			global_position.x += dir * spd * dt
			if (dir > 0.0 and global_position.x >= x_max) or (dir < 0.0 and global_position.x <= x_min):
				state = "pause"
				_t = 0.0
			_detect(dt)
		"pause":
			_detect(dt)
			if _t > 1.4:
				dir = -dir
				state = "patrol"
		"alert", "off":
			pass
	# turn to face the travel direction (the body mirrors)
	_turn = move_toward(_turn, dir, dt * 3.0)
	_scanner.scale.x = _turn if absf(_turn) > 0.05 else 0.05 * signf(_turn + 0.0001)
	# beam colour follows suspicion
	var c := Color(0.3, 0.65, 1.0).lerp(Color(1.0, 0.25, 0.15), clampf(suspicion, 0.0, 1.0))
	if state == "alert":
		c = Color(1.0, 0.15, 0.1) if fmod(_t, 0.4) < 0.2 else Color(1.0, 0.45, 0.1)
	_cone_mat.albedo_color = Color(c.r, c.g, c.b, 0.16 + 0.12 * suspicion)
	_lens_mat.emission = c
	_lens_mat.albedo_color = c
	_scan_light.light_color = c
	_cone.visible = state != "off"
	_scan_light.visible = state != "off"
	# googly pupils swing with acceleration
	_vx = (global_position.x - _last_x) / maxf(dt, 0.0001)
	_last_x = global_position.x
	var goal := Vector2(-_vx * 0.09, -0.35)
	if state == "alert" and player != null:
		goal = Vector2(signf(player.global_position.x - global_position.x) * 0.45, -0.4)
	_pupil_v += ((goal - _pupil_p) * 60.0 - _pupil_v * 6.0) * dt
	_pupil_p += _pupil_v * dt
	_pupil_p = _pupil_p.limit_length(0.5)
	for p in _pupils:
		p.position.x = (-1.05 if p == _pupils[0] else 1.05) + _pupil_p.x
		p.position.y = 12.6 + _pupil_p.y
	_beep_t -= dt
	if _beep_t <= 0.0 and state != "off":
		_beep_t = 2.2 if state != "alert" else 0.5
		Sfx.play_at("beep", global_position + Vector3(0, 2, 0), -12.0 if state != "alert" else -4.0)
	if _talk_t > 0.0:
		_talk_t -= dt


func _detect(dt: float) -> void:
	if player == null or not is_instance_valid(player) or Game.dev.has("godmode"):
		suspicion = 0.0
		return
	var dx: float = (player.global_position.x - global_position.x) * dir
	var in_beam := dx > 2.6 and dx < RANGE
	var low: bool = player.global_position.y < 0.6
	var exposed: bool = in_beam and low and not player.hidden and player.alive and not player.locked
	if exposed:
		suspicion += dt / NOTICE
	else:
		suspicion = maxf(0.0, suspicion - dt * 1.5)
	if suspicion >= 1.0:
		suspicion = 1.0
		state = "alert"
		_t = 0.0
		Sfx.play_at("alert", global_position + Vector3(0, 2, 0), 0.0)
		spotted.emit(player.global_position.x)


func resume() -> void:
	suspicion = 0.0
	state = "patrol"


## Back to the far end of the beat, looking away, with a moment of grace.
func reset_far() -> void:
	global_position.x = x_max
	dir = 1.0
	_turn = 1.0
	suspicion = 0.0
	state = "pause"
	_t = -1.5


# --- speaker interface ---------------------------------------------------------------

func set_emotion(_e: String) -> void:
	pass


func talk_pulse() -> void:
	_talk_t = 0.08
	_pupil_v += Vector2(randf_range(-2, 2), randf_range(-2, 2))


func set_talking(_on: bool) -> void:
	pass


func face_toward(_x: float) -> void:
	pass


func emote(_name: String) -> void:
	pass


func head_pos() -> Vector3:
	return global_position + Vector3(0, 6.0, 0)
