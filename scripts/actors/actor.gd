extends Node3D
## A non-player character: one or more food rigs (the Rolls are three), what
## happens when Baker talks to them, and ambient barks.

const Cast = preload("res://scripts/dialogue/cast.gd")

var id := ""
var rigs: Array = []
var talk_node := ""          ## dialogue node started by the interact button
var talk_radius := 2.6
var barks: Array = []        ## lines said in a speech bubble when Baker is near
var bark_radius := 5.5
var bark_cooldown := 7.0
var watch_player := true
var ground_shadow := false   ## lay the blob shadow on the ground below (for one who hops about, like Dot)
var player: Node3D
var _bark_t := 1.5
var _bark_i := 0
var _bubble: Label3D
var _bubble_t := 0.0
var _bubble_lift := 0.45

## Whoever the Talk prompt is over right now (the level sets it): their
## speech bubble moves up to sit above the prompt instead of under it.
static var prompted: Node3D = null
var _walking := false


static func make(actor_id: String, rig_extra := {}, count := 1) -> Node3D:
	var a: Node3D = load("res://scripts/actors/actor.gd").new()
	a.id = actor_id
	a.name = actor_id
	for i in count:
		var r := Cast.make_rig(actor_id, rig_extra)
		a.add_child(r)
		a.rigs.append(r)
	if count > 1:
		var w: float = a.rigs[0].h * 1.35
		for i in count:
			a.rigs[i].position.x = (i - (count - 1) * 0.5) * w
	return a


func rig() -> Node3D:
	return rigs[0]


func _ready() -> void:
	_bubble = Label3D.new()
	_bubble.font = load("res://assets/fonts/Nunito.ttf")
	_bubble.font_size = 44
	_bubble.pixel_size = 0.011
	_bubble.outline_size = 14
	_bubble.outline_modulate = Color(0.05, 0.05, 0.08, 0.95)
	_bubble.modulate = Color(1, 0.98, 0.92)
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.no_depth_test = true
	_bubble.width = 420
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.render_priority = 10
	_bubble.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM   # the text grows upward
	_bubble.visible = false
	add_child(_bubble)


func _process(dt: float) -> void:
	if _bubble_t > 0.0:
		_bubble_t -= dt
		_bubble_lift = move_toward(_bubble_lift, 1.3 if prompted == self else 0.45, dt * 5.0)
		_bubble.global_position = head_pos() + Vector3(0, _bubble_lift, 0)
		if _bubble_t <= 0.0:
			_bubble.visible = false
	if ground_shadow:
		_drop_shadows()
	if player == null or not is_instance_valid(player):
		return
	var d := player.global_position.distance_to(global_position)
	if watch_player and d < 9.0:
		for r in rigs:
			r.look_target = player
	else:
		for r in rigs:
			r.look_target = null
	_bark_t -= dt
	if barks.size() > 0 and _bark_t <= 0.0 and d < bark_radius and not Game.busy:
		_bark_t = bark_cooldown + randf() * 4.0
		if Game.bark_ok():
			bubble(barks[_bark_i % barks.size()])
			_bark_i += 1


func _drop_shadows() -> void:
	var space := get_world_3d().direct_space_state
	for r in rigs:
		var sh: MeshInstance3D = r.shadow
		if sh == null or not sh.visible:
			continue
		var from: Vector3 = r.global_position + Vector3(0, 0.3, 0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -12.0, 0)))
		sh.global_position = (hit.position if not hit.is_empty() else r.global_position) + Vector3(0, 0.03, 0)


func bubble(text: String, dur := 3.2) -> void:
	_bubble.text = text
	_bubble.visible = true
	_bubble_t = dur
	_bubble_lift = 1.3 if prompted == self else 0.45
	_bubble.global_position = head_pos() + Vector3(0, _bubble_lift, 0)
	var voice: String = Cast.info(id).get("voice", "one")
	for k in mini(6, 1 + text.length() / 8):
		get_tree().create_timer(k * 0.07).timeout.connect(func():
			Sfx.blip(voice)
			talk_pulse())


# --- speaker interface -------------------------------------------------------------

func set_emotion(e: String) -> void:
	for r in rigs:
		r.set_emotion(e)


func talk_pulse() -> void:
	if rigs.size() == 1:
		rigs[0].talk_pulse()
	else:
		for r in rigs:
			if randf() < 0.6:
				r.talk_pulse()


func set_talking(on: bool) -> void:
	for r in rigs:
		r.talking = on


func face_toward(x: float) -> void:
	for r in rigs:
		r.face_toward(x)


func face_dir(d: float) -> void:
	for r in rigs:
		r.face_dir(d)


func emote(name: String) -> void:
	for i in rigs.size():
		var r: Node3D = rigs[i]
		if i == 0:
			r.emote(name)
		else:
			get_tree().create_timer(0.06 * i).timeout.connect(r.emote.bind(name))


func set_product(on: bool) -> void:
	for r in rigs:
		r.set_product(on)


func head_pos() -> Vector3:
	var top := 0.0
	for r in rigs:
		top = maxf(top, r.leg_len + r.h)
	return global_position + Vector3(0, top, 0)


## Walks to x (cutscenes). Awaitable.
func walk_to(x: float, spd := 3.2) -> void:
	var dist := absf(x - global_position.x)
	if dist < 0.05:
		return
	face_dir(signf(x - global_position.x))
	for r in rigs:
		r.speed = 0.8
	var tw := create_tween()
	tw.tween_property(self, "global_position:x", x, dist / spd)
	await tw.finished
	for r in rigs:
		r.speed = 0.0


## Hops along an arc to a point (cutscenes). Awaitable.
func hop_to(p: Vector3, height := 1.5, dur := 0.55) -> void:
	var start := global_position
	face_dir(signf(p.x - start.x))
	for r in rigs:
		r.hop_stretch()
		r.grounded = false
	var tw := create_tween()
	tw.tween_method(func(t: float):
		global_position = start.lerp(p, t) + Vector3(0, sin(t * PI) * height, 0), 0.0, 1.0, dur)
	await tw.finished
	for r in rigs:
		r.grounded = true
		r.land(0.8)
