extends Node3D
## A human, at food scale: from down here they're a pair of enormous legs, two
## sneakers and, when you're unlucky, a hand. Walks along X.

const Meshes = preload("res://scripts/gfx/meshes.gd")
const Mats = preload("res://scripts/gfx/mats.gd")

const HIP := 14.5

var id := "tyler"
var legs: Array[Node3D] = []
var hand: Node3D
var fingers: Array[Node3D] = []
var held: Node3D = null       ## whatever the hand is carrying
var _phase := 0.0
var _walking := false
var _step_side := 0
var style := {}


func build(s: Dictionary) -> void:
	style = s
	var pants := Mats.skin(s.get("pants", Color(0.22, 0.3, 0.48)), 0.85)
	var shoe := Mats.skin(s.get("shoe", Color(0.9, 0.9, 0.9)), 0.5)
	var sole := Mats.solid(s.get("sole", Color(0.95, 0.95, 0.93)), 0.6)
	var stripe := Mats.solid(s.get("stripe", Color(0.85, 0.2, 0.2)), 0.5)
	for side in [1, -1]:
		var piv := Node3D.new()
		piv.position = Vector3(0, HIP, side * 1.1)
		add_child(piv)
		var leg := MeshInstance3D.new()
		leg.mesh = Meshes.cyl(2.0, 1.35, HIP - 1.2, 18)
		leg.material_override = pants
		leg.position.y = -(HIP - 1.2) * 0.5
		piv.add_child(leg)
		var hem := MeshInstance3D.new()
		hem.mesh = Meshes.cyl(1.45, 1.45, 0.6, 18)
		hem.material_override = pants
		hem.position.y = -(HIP - 1.6)
		piv.add_child(hem)
		var sh := Node3D.new()
		sh.position = Vector3(0.9, -HIP + 0.05, 0)
		piv.add_child(sh)
		var so := MeshInstance3D.new()
		so.mesh = Meshes.rounded_box(Vector3(5.2, 0.55, 2.3), 0.25, 2)
		so.material_override = sole
		so.position.y = 0.28
		sh.add_child(so)
		var up := MeshInstance3D.new()
		up.mesh = Meshes.rounded_box(Vector3(4.7, 1.5, 2.1), 0.65, 3)
		up.material_override = shoe
		up.position = Vector3(-0.15, 1.15, 0)
		sh.add_child(up)
		var st := MeshInstance3D.new()
		st.mesh = Meshes.rounded_box(Vector3(2.4, 0.35, 2.14), 0.15, 2)
		st.material_override = stripe
		st.position = Vector3(-0.3, 1.0, 0)
		st.rotation.z = 0.35
		sh.add_child(st)
		legs.append(piv)
	if s.has("apron"):
		var ap := MeshInstance3D.new()
		ap.mesh = Meshes.rounded_box(Vector3(6.0, 4.0, 0.3), 0.15, 2)
		ap.material_override = Mats.skin(s.apron, 0.8)
		ap.position = Vector3(1.2, HIP + 1.0, 2.2)
		add_child(ap)
	_build_hand(s.get("skin", Color(0.93, 0.74, 0.6)), s.get("sleeve", Color(0.2, 0.45, 0.3)))


func _build_hand(skin_c: Color, sleeve_c: Color) -> void:
	var skin := Mats.skin(skin_c, 0.6)
	hand = Node3D.new()
	hand.name = "Hand"
	hand.visible = false
	add_child(hand)
	# palm faces down, fingers point along -Z (into the shelf / onto the floor)
	var palm := MeshInstance3D.new()
	palm.mesh = Meshes.rounded_box(Vector3(4.0, 1.3, 4.2), 0.6, 3)
	palm.material_override = skin
	hand.add_child(palm)
	for i in 4:
		var f := Node3D.new()
		f.position = Vector3(-1.45 + i * 0.97, -0.1, -2.0)
		hand.add_child(f)
		var fm := MeshInstance3D.new()
		var flen: float = [3.0, 3.5, 3.4, 2.7][i]
		fm.mesh = Meshes.capsule(0.44, flen)
		fm.material_override = skin
		fm.rotation.x = PI * 0.5
		fm.position.z = -flen * 0.45
		f.add_child(fm)
		fingers.append(f)
	var th := Node3D.new()
	th.position = Vector3(2.1, -0.2, -0.6)
	th.rotation = Vector3(0, -0.8, 0)
	hand.add_child(th)
	var tm := MeshInstance3D.new()
	tm.mesh = Meshes.capsule(0.5, 2.8)
	tm.material_override = skin
	tm.rotation.x = PI * 0.5
	tm.position.z = -1.2
	th.add_child(tm)
	fingers.append(th)
	var arm := MeshInstance3D.new()
	arm.mesh = Meshes.cyl(1.55, 1.75, 14.0, 16)
	arm.material_override = skin
	arm.position = Vector3(0, 0.3, 7.5)
	arm.rotation.x = PI * 0.5 - 0.35
	hand.add_child(arm)
	var sleeve := MeshInstance3D.new()
	sleeve.mesh = Meshes.cyl(2.1, 2.1, 10.0, 16)
	sleeve.material_override = Mats.skin(sleeve_c, 0.8)
	sleeve.position = Vector3(0, 2.6, 15.0)
	sleeve.rotation.x = PI * 0.5 - 0.35
	hand.add_child(sleeve)


func _process(dt: float) -> void:
	if _walking:
		_phase += dt * 5.0
		var s := sin(_phase)
		legs[0].rotation.z = s * 0.32
		legs[1].rotation.z = -s * 0.32
		position.y = absf(cos(_phase)) * 0.35
		var side := 1 if s > 0.0 else 0
		if side != _step_side:
			_step_side = side
			Sfx.play_at("thud", global_position + Vector3(0, 1, 0), -2.0, randf_range(0.85, 1.05))
			var lvl := get_parent()
			if lvl != null and lvl.has_method("shake"):
				lvl.shake(0.35)
	else:
		for l in legs:
			l.rotation.z = lerpf(l.rotation.z, 0.0, 1.0 - exp(-dt * 8.0))
		position.y = lerpf(position.y, 0.0, 1.0 - exp(-dt * 8.0))


## Walks to x. Awaitable.
func walk_to(x: float, spd := 9.0) -> void:
	var dist := absf(x - global_position.x)
	if dist < 0.1:
		return
	var d := signf(x - global_position.x)
	scale.x = d   # toes point the way we walk
	_walking = true
	var tw := create_tween()
	tw.tween_property(self, "global_position:x", x, dist / spd)
	await tw.finished
	_walking = false


## Brings the hand down from above to a point (world space). Awaitable.
func reach(to: Vector3, dur := 0.8, from_front := false) -> void:
	hand.visible = true
	hand.scale = Vector3(1 if scale.x > 0 else -1, 1, 1)
	var start := to + (Vector3(0, 6, 22) if from_front else Vector3(0, 26, 3))
	hand.global_position = start
	hand.rotation = Vector3(0.0 if from_front else -0.9, 0, 0)
	open_hand()
	Sfx.play_at("whoosh", to, -2.0)
	var tw := create_tween()
	tw.tween_property(hand, "global_position", to, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tw.finished


func retract(dur := 0.7, from_front := false) -> void:
	var to := hand.global_position + (Vector3(0, 6, 22) if from_front else Vector3(0, 26, 3))
	Sfx.play_at("whoosh", hand.global_position, -6.0)
	var tw := create_tween()
	tw.tween_property(hand, "global_position", to, dur).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await tw.finished
	hand.visible = false


func close_hand() -> void:
	for f in fingers:
		var tw := create_tween()
		tw.tween_property(f, "rotation:x", -1.1, 0.18)


func open_hand() -> void:
	for f in fingers:
		f.rotation.x = 0.0


## Pats around (a miss). Awaitable.
func pat(width := 3.0) -> void:
	var base := hand.global_position
	var tw := create_tween()
	for k in 3:
		tw.tween_property(hand, "global_position", base + Vector3(width * (1 if k % 2 == 0 else -1), 0.6, 0), 0.22)
		tw.tween_property(hand, "global_position", base, 0.15)
		tw.tween_callback(Sfx.play_at.bind("land", base, -4.0, 0.6))
	await tw.finished


# --- speaker interface ----------------------------------------------------------------

func set_emotion(_e: String) -> void:
	pass


func talk_pulse() -> void:
	pass


func set_talking(_on: bool) -> void:
	pass


func face_toward(_x: float) -> void:
	pass


func emote(_name: String) -> void:
	pass


func head_pos() -> Vector3:
	return global_position + Vector3(0, 9.0, 0)
