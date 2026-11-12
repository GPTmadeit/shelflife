extends CharacterBody3D
## Baker: side-on platforming with fragile-egg falling rules.
##   drop > CRACK_H  -> a crack (three and you're done)
##   drop > SPLAT_H  -> splat
##   cushions (bread, shredded cheese...) bounce you instead.

const Cast = preload("res://scripts/dialogue/cast.gd")
const Meshes = preload("res://scripts/gfx/meshes.gd")
const Mats = preload("res://scripts/gfx/mats.gd")

const SPEED := 5.4
const ACCEL := 42.0
const DECEL := 40.0
const AIR_ACCEL := 24.0
const GRAVITY := 32.0
const JUMP_H := 2.75
const MAX_FALL := 34.0
const CRACK_H := 3.5
const SPLAT_H := 8.6
const JUMP_SHARE := 0.35       ## how much of a jump's own height counts toward a hard landing
const MAX_CRACKS := 3

signal cracked(n: int)
signal died(reason: String)
signal landed(drop: float)

var rig: Node3D
var level: Node
var locked := false
var alive := true
var cracks := 0
var hidden := false            ## set by the level's hide zones
var facing_dir := 1.0
var godmode := false
var _coyote := 0.0
var _buffer := 0.0
var _peak_y := 0.0
var _takeoff_y := 0.0         ## height of the last ground we stood on
var _shadow_mat: StandardMaterial3D
var _shadow_size := Vector3.ONE
var _step_t := 0.0
var _debris: Array[Node3D] = []
var _bot := false             ## dev autopilot: walk right, hop over whatever blocks
var _bot_dir := 1.0
var _bot_stuck := 0.0
var _bot_hold := 0.0


func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.33
	cap.height = 1.12
	cs.shape = cap
	cs.position.y = 0.56
	add_child(cs)
	rig = Cast.make_rig("baker")
	add_child(rig)
	# Baker's shadow stays on the ground below him and shrinks as he rises
	_shadow_mat = Mats.blob(true)
	rig.shadow.material_override = _shadow_mat
	rig.shadow.top_level = true
	rig.shadow_always = true
	rig.shadow.visible = true
	_shadow_size = rig.shadow.scale
	floor_snap_length = 0.25
	floor_max_angle = deg_to_rad(50.0)
	axis_lock_linear_z = true
	godmode = Game.dev.has("godmode")
	_bot = Game.dev.has("bot")
	_peak_y = global_position.y
	_takeoff_y = global_position.y


func _physics_process(dt: float) -> void:
	if not alive:
		return
	var inp := 0.0
	if not locked:
		inp = Input.get_axis("move_left", "move_right")
		if _bot:
			inp = _bot_dir
			_bot_stuck = _bot_stuck + dt if absf(velocity.x) < 0.6 and is_on_floor() else 0.0
			if _bot_stuck > 0.12:
				_buffer = 0.13
				_bot_stuck = -0.3
				_bot_hold = 0.45
			_bot_hold -= dt
	var on_floor := is_on_floor()
	var acc := AIR_ACCEL
	if on_floor:
		acc = ACCEL if absf(inp) > 0.01 else DECEL
	velocity.x = move_toward(velocity.x, inp * SPEED, acc * dt)
	velocity.y = maxf(velocity.y - GRAVITY * dt, -MAX_FALL)
	_coyote = 0.1 if on_floor else _coyote - dt
	if not locked and Input.is_action_just_pressed("jump"):
		_buffer = 0.13
	else:
		_buffer -= dt
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = sqrt(2.0 * GRAVITY * JUMP_H)
		_buffer = 0.0
		_coyote = 0.0
		rig.hop_stretch()
		_puff(3, 0.5)
		Sfx.play("jump", -8.0, randf_range(0.95, 1.08))
	if velocity.y > 0.0 and (locked or not (Input.is_action_pressed("jump") or _bot_hold > 0.0)):
		velocity.y -= GRAVITY * dt * 1.3   # short hop when jump is released
	velocity.z = 0.0
	if on_floor:
		_peak_y = global_position.y
		_takeoff_y = global_position.y
	move_and_slide()
	position.z = 0.0
	var now_floor := is_on_floor()
	if not now_floor:
		_peak_y = maxf(_peak_y, global_position.y)
	elif not on_floor:
		_on_land()
	# animation
	rig.speed = clampf(absf(velocity.x) / SPEED, 0.0, 1.0)
	rig.grounded = is_on_floor()
	rig.vy = velocity.y
	if absf(inp) > 0.1:
		facing_dir = signf(inp)
		rig.face_dir(facing_dir)
	elif not locked and is_on_floor():
		rig.face_dir(facing_dir * 0.35)
	if is_on_floor() and absf(velocity.x) > 1.0:
		_step_t -= dt
		if _step_t <= 0.0:
			_step_t = 0.2
			Sfx.play("step", -14.0, randf_range(0.9, 1.2))


func _process(_dt: float) -> void:
	_update_shadow()   # every frame, also while a cutscene moves him about


## Lays the blob shadow on whatever is below (a ray down from the feet).
func _update_shadow() -> void:
	var sh: MeshInstance3D = rig.shadow
	if not rig.visible:
		sh.visible = false
		return
	var from := global_position + Vector3(0, 0.3, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -18.0, 0))
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		sh.visible = false
		return
	var height: float = maxf(0.0, global_position.y - hit.position.y)
	var k := clampf(1.0 - height / 9.0, 0.3, 1.0)
	sh.visible = true
	sh.global_position = hit.position + Vector3(0, 0.03, 0)
	sh.global_rotation = Vector3(-PI * 0.5, 0, 0)
	sh.scale = _shadow_size * (0.7 + 0.3 * k)
	_shadow_mat.albedo_color.a = (0.8 if Game.quality() == 0 else 0.4) * (0.4 + 0.6 * k)


func _on_land() -> void:
	var drop := _peak_y - global_position.y
	# How hard it lands: the fall from the ground we left, plus a share of
	# whatever a jump added on top. Walking off a ledge counts in full; a hop
	# off a crate doesn't crack an egg, a leap off a table still does.
	var impact := (_takeoff_y - global_position.y) + JUMP_SHARE * (_peak_y - _takeoff_y)
	_peak_y = global_position.y
	_takeoff_y = global_position.y
	var cushion := false
	for i in get_slide_collision_count():
		var c := get_slide_collision(i).get_collider()
		if c != null and c.has_meta("cushion"):
			cushion = true
	landed.emit(drop)
	if cushion and drop > 0.9:
		velocity.y = clampf(drop * 2.2, 7.0, 13.5)
		rig.land(1.3)
		Sfx.play("bounce", -4.0, randf_range(0.95, 1.1))
		return   # bounces never hurt
	if godmode:
		rig.land(clampf(drop / 3.0, 0.3, 1.2))
		return
	if impact > SPLAT_H:
		die("splat")
	elif impact > CRACK_H:
		crack()
	else:
		rig.land(clampf(drop / 3.0, 0.25, 1.0))
		if drop > 0.6:
			_puff(4 + int(minf(drop, 3.0) * 2.0), 0.6 + drop * 0.25)
			Sfx.play("land", -10.0 + drop * 2.0, randf_range(0.9, 1.1))


func crack() -> void:
	cracks += 1
	rig.set_cracks(cracks)
	rig.land(1.4)
	rig.set_emotion("shock")
	Sfx.play("crack", 0.0, randf_range(0.95, 1.05))
	cracked.emit(cracks)
	if cracks >= MAX_CRACKS:
		die("cracked")
	else:
		get_tree().create_timer(1.2).timeout.connect(func():
			if alive and rig.emotion == "shock":
				rig.set_emotion("neutral"))


func die(reason: String) -> void:
	if not alive:
		return
	alive = false
	velocity = Vector3.ZERO
	if not reason in ["shrunk", "late"]:
		_splat()
		rig.visible = false
	died.emit(reason)


func respawn(pos: Vector3, keep_cracks := 0) -> void:
	for d in _debris:
		if is_instance_valid(d):
			d.queue_free()
	_debris.clear()
	global_position = pos
	velocity = Vector3.ZERO
	cracks = keep_cracks
	rig.set_cracks(cracks)
	rig.visible = true
	rig.set_emotion("neutral")
	rig.position = Vector3.ZERO
	alive = true
	_peak_y = pos.y
	_takeoff_y = pos.y


## Little dust puffs kicked up from the feet.
func _puff(n: int, spread: float) -> void:
	if Game.quality() < 1 and n > 4:
		n = 4
	var mat := Mats.flat(Color(0.86, 0.86, 0.9, 0.5))
	for i in n:
		var m := MeshInstance3D.new()
		m.mesh = Meshes.sphere(0.11, 8, 5)
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		get_parent().add_child(m)
		var side := -1.0 if i % 2 == 0 else 1.0
		m.global_position = global_position + Vector3(side * randf_range(0.1, 0.3), 0.08, randf_range(-0.2, 0.3))
		var to := m.global_position + Vector3(side * randf_range(0.3, 1.0) * spread, randf_range(0.15, 0.5), 0.0)
		var tw := m.create_tween()
		tw.tween_property(m, "global_position", to, 0.38).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.parallel().tween_property(m, "scale", Vector3.ONE * randf_range(1.6, 2.4), 0.2)
		tw.tween_property(m, "scale", Vector3.ONE * 0.01, 0.18)
		tw.tween_callback(m.queue_free)


## Shell shards fly, yolk puddles.
func _splat() -> void:
	Sfx.play("splat")
	var base := global_position
	var shell := Mats.skin(Color(0.97, 0.93, 0.84), 0.6)
	for i in 9:
		var s := MeshInstance3D.new()
		s.mesh = Meshes.hemi(0.18 + randf() * 0.12, 8, 4)
		s.material_override = shell
		get_parent().add_child(s)
		s.global_position = base + Vector3(0, 0.5, 0)
		s.scale = Vector3(1, 0.5, 1)
		var vel := Vector3(randf_range(-4, 4), randf_range(4, 9), randf_range(-1.5, 1.5))
		var tw := s.create_tween()
		var land := base + Vector3(vel.x * 0.35, 0.03, vel.z * 0.35)
		tw.tween_property(s, "global_position", land + Vector3(0, 1.4, 0), 0.22).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(s, "rotation", Vector3(randf() * 6, randf() * 6, randf() * 6), 0.5)
		tw.tween_property(s, "global_position", land, 0.25).set_ease(Tween.EASE_IN)
		_debris.append(s)
	var white := MeshInstance3D.new()
	white.mesh = Meshes.cyl(0.95, 1.05, 0.04, 24)
	white.material_override = Mats.solid(Color(0.95, 0.95, 0.9, 1.0), 0.15)
	get_parent().add_child(white)
	white.global_position = base + Vector3(0, 0.02, 0)
	white.scale = Vector3(0.1, 1, 0.1)
	var yolk := MeshInstance3D.new()
	yolk.mesh = Meshes.sphere(0.42, 16, 8)
	yolk.material_override = Mats.solid(Color(1.0, 0.72, 0.1), 0.15)
	get_parent().add_child(yolk)
	yolk.global_position = base + Vector3(0.1, 0.06, 0.1)
	yolk.scale = Vector3(0.1, 0.05, 0.1)
	var tw2 := white.create_tween()
	tw2.tween_property(white, "scale", Vector3(1.0, 1.0, 0.8), 0.35).set_ease(Tween.EASE_OUT)
	var tw3 := yolk.create_tween()
	tw3.tween_property(yolk, "scale", Vector3(1.0, 0.35, 0.9), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_debris.append(white)
	_debris.append(yolk)


# --- the speaker interface used by dialogue ---------------------------------------

func set_emotion(e: String) -> void:
	rig.set_emotion(e)


func talk_pulse() -> void:
	rig.talk_pulse()


func set_talking(on: bool) -> void:
	rig.talking = on


func face_toward(x: float) -> void:
	var d := signf(x - global_position.x)
	if d != 0.0:
		facing_dir = d
	rig.face_dir(d)


func emote(name: String) -> void:
	rig.emote(name)


func head_pos() -> Vector3:
	return global_position + Vector3(0, 1.15, 0)
