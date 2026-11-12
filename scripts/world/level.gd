extends Node3D
## Everything the acts share: the player and camera, the cast, triggers,
## Planogram scraps, hazards, the dialogue commands, Dot following along,
## death and respawn. An act (act1.gd, act2.gd) fills in the hooks:
##
##   _setup()          checkpoints, shots, dialogue file, camera limits
##   _build_world()    geometry (through `store`)
##   _spawn_cast()     actors
##   _build_triggers() story triggers
##   _apply_state()    put the world in the state the save describes
##   _begin()          the first thing that happens (intro or a fade in)
##   _tick(dt)         per-frame extras
##   _cam_zone()       camera distance for where the player is
##   _on_respawn()     reset whatever chases the player
##   _ev_<name>()      events the dialogue calls with `~ event <name>`

const Store = preload("res://scripts/world/store.gd")
const Cam = preload("res://scripts/world/cam.gd")
const Player = preload("res://scripts/actors/player.gd")
const Actor = preload("res://scripts/actors/actor.gd")
const Narc = preload("res://scripts/actors/narc.gd")
const Giant = preload("res://scripts/actors/giant.gd")
const Runner = preload("res://scripts/dialogue/dlg_runner.gd")
const DialogueBox = preload("res://scripts/ui/dialogue_box.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const PauseMenu = preload("res://scripts/ui/pause.gd")
const Meshes = preload("res://scripts/gfx/meshes.gd")
const Mats = preload("res://scripts/gfx/mats.gd")
const FaceTex = preload("res://scripts/gfx/face_tex.gd")
const Cast = preload("res://scripts/dialogue/cast.gd")
const Scraps = preload("res://scripts/world/scraps.gd")

const DEATH := {
	"splat": ["SCRAMBLED.", ["Somewhere, a raccoon is very happy.", "That's gonna stain.", "Rest in pieces.", "You had one job: don't fall."]],
	"cracked": ["CRACKED.", ["Three strikes. Yolk's out.", "Shell shock.", "Should've walked."]],
	"shrunk": ["SHRUNK.", ["Straight to the Dumpster. Do not pass the Lanes.", "The Narc sends its regards.", "Cleanup on aisle you."]],
	"snapped": ["SNAPPED.", ["The cheese was a lie.", "That trap was for something with a spine.", "Peanut butter. Classic."]],
	"baled": ["BALED.", ["You're cardboard now.", "Flat-packed.", "Reduce, reuse, regret."]],
	"late": ["TOO LATE.", ["They were already Discontinued. Now they're recycled.", "Pickle Fizz has left the building.", "One cube. Three flavors."]],
	"stomped": ["STOMPED.", ["Size eleven. Wide.", "He didn't even notice.", "Check his sole for you later."]],
}

# --- what an act sets in _setup() ---------------------------------------------
var act := 1
var act_name := "ACT ONE"
var dlg_file := ""
var checkpoints := {}          ## id -> Vector3
var shots := {}                ## id -> [camera position, look-at]
var cam_min_x := -6.0
var cam_max_x := 146.0
var dot_barks: Array = []

var start_checkpoint := "start"
var store: Store
var cam: Camera3D
var player: CharacterBody3D
var actors := {}
var runner: Node
var ui: CanvasLayer
var hud: CanvasLayer
var pause_menu: CanvasLayer
var env: Environment
var sun: DirectionalLight3D
var triggers: Array = []
var hide_zones: Array[Rect2] = []
var hazards: Array = []        ## {rect, reason, on: Callable}
var scraps := {}               ## this act's scraps (see scraps.gd)
var scrap_nodes := {}
var dot_follow := false
var auto_face := true          ## dialogue turns speakers toward each other (off in staged shots)
var _trail: Array[Vector3] = []
var _trail_t := 0.0
var _dot_bark_t := 25.0
var _dying := false
var _interact_target: Node3D = null
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _trace_t := 0.0
var _hitstops := 0
var _lamps_low: Array[Light3D] = []    ## see _lamp_sets()
var _lamps_high: Array[Light3D] = []


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	_rng.randomize()
	_setup()
	scraps = Scraps.for_act(act)
	_environment()
	store = Store.new(self)
	_build_world()
	store.flush()
	_spawn_player()
	_spawn_cast()
	_build_triggers()
	_build_scraps()
	_build_ui()
	_apply_state()
	print("act %d built in %d ms" % [act, Time.get_ticks_msec() - t0])
	if Game.dev.has("nolights"):
		for n in find_children("*", "OmniLight3D", true, false):
			n.visible = false
		for n in find_children("*", "SpotLight3D", true, false):
			n.visible = false
	if Game.dev.has("dlg"):
		hud.set_black(false)
		await get_tree().process_frame
		runner.run(Game.dev.dlg)
	else:
		_begin()


# --- hooks --------------------------------------------------------------------

func _setup() -> void:
	pass


func _build_world() -> void:
	pass


func _spawn_cast() -> void:
	pass


func _build_triggers() -> void:
	pass


func _apply_state() -> void:
	pass


func _begin() -> void:
	hud.fade(false, 0.6)


func _tick(_dt: float) -> void:
	pass


func _cam_zone() -> float:
	return 0.0


func _on_respawn() -> void:
	pass


## Is this a moment for a chat with Dot? (Not while something is chasing you.)
func _companion_ok() -> bool:
	return true


# --- environment ---------------------------------------------------------------------

func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025, 0.03, 0.045)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.48, 0.66)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.09)
	env.fog_density = 0.006
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = Color(0.78, 0.84, 1.0)
	sun.light_energy = 0.5
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 45.0
	sun.shadow_blur = 1.5
	sun.shadow_opacity = 0.65
	add_child(sun)
	sun.look_at_from_position(Vector3(-8, 50, 9), Vector3(0, 0, 0))
	Game.tune(env, sun)
	Game.graphics_changed.connect(func():
		Game.tune(env, sun)
		_apply_lamp_sets())


func shake(amount: float) -> void:
	if cam != null:
		cam.shake(amount)


## Two ways to light the same place: `high` as designed, and `low`, fewer
## lamps doing the same job for Low quality. Every lamp that reaches a mesh
## draws it again, which is most of the frame on old integrated graphics.
func _lamp_sets(low: Array, high: Array) -> void:
	for l in low:
		_lamps_low.append(l)
	for l in high:
		_lamps_high.append(l)
	_apply_lamp_sets()


func _apply_lamp_sets() -> void:
	var low := Game.quality() == 0
	for l in _lamps_low:
		l.visible = low
	for l in _lamps_high:
		l.visible = not low


func _floor_mat(tint := Color.WHITE) -> StandardMaterial3D:
	var m := Mats.textured(FaceTex.floor_tiles(), 0.28, Vector3(0.1, 0.1, 0.1), tint)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.metallic_specular = 0.6
	return m


func _talker(pos: Vector3, text: String, col: Color) -> void:
	store.box(pos, Vector3(1.8, 0.8, 0.05), Mats.solid(col, 0.6))
	var t: Label3D = store.label(text, pos + Vector3(0, 0, 0.04), 0.42, Color(1, 1, 1))
	t.outline_size = 0


# --- cast -----------------------------------------------------------------------------------

func _spawn_player() -> void:
	player = Player.new()
	player.name = "Baker"
	player.level = self
	add_child(player)
	var cp: Vector3 = checkpoints.get(start_checkpoint, checkpoints.start)
	if Game.dev.has("at"):
		cp = Game.dev.at
	player.global_position = cp
	player.cracked.connect(_on_crack)
	player.died.connect(_on_died)
	actors["baker"] = player
	cam = Cam.new()
	add_child(cam)
	cam.follow(player)
	cam.min_x = cam_min_x
	cam.max_x = cam_max_x
	cam.min_y = 2.6
	cam.snap()


func _add_actor(id: String, pos: Vector3, talk := "", barks: Array = [], extra := {}, count := 1) -> Node3D:
	var a: Node3D = Actor.make(id, extra, count)
	add_child(a)
	a.global_position = pos
	a.talk_node = talk
	a.barks = barks
	a.player = player
	actors[id] = a
	return a


func actor(id: String) -> Node:
	return actors.get(id)


# --- triggers -------------------------------------------------------------------------------

func _trigger(id: String, rect: Rect2, fn: Callable, cond := Callable()) -> void:
	triggers.append({"id": id, "rect": rect, "fn": fn, "cond": cond, "done": false})


func _check_triggers() -> void:
	if Game.busy or not player.alive or not player.is_on_floor():
		return
	var p := Vector2(player.global_position.x, player.global_position.y)
	for t in triggers:
		if t.done:
			continue
		if not t.rect.has_point(p):
			continue
		if t.cond.is_valid() and not t.cond.call():
			continue
		t.done = true
		t.fn.call()
		return


## Something that kills on touch while `on` says so (a trap, a ram, a shoe).
func _hazard(rect: Rect2, reason: String, on := Callable()) -> Dictionary:
	var h := {"rect": rect, "reason": reason, "on": on}
	hazards.append(h)
	return h


func _check_hazards() -> void:
	if not player.alive or player.godmode or Game.busy:
		return
	var p := Vector2(player.global_position.x, player.global_position.y + 0.4)
	for h in hazards:
		if h.rect.has_point(p) and (not h.on.is_valid() or h.on.call()):
			if h.has("hit"):
				h.hit.call()
			player.die(h.reason)
			return


# --- scraps ---------------------------------------------------------------------------------

func _build_scraps() -> void:
	for id in scraps.keys():
		if Game.scraps.has(id):
			continue
		var n := Node3D.new()
		n.position = scraps[id][1] + Vector3(0, 0.75, 0)
		add_child(n)
		var paper := MeshInstance3D.new()
		paper.mesh = Meshes.rounded_box(Vector3(0.75, 0.95, 0.04), 0.06, 1)
		paper.material_override = Mats.glow(Color(1.0, 0.95, 0.75), 1.6)
		n.add_child(paper)
		for k in 3:
			var line := MeshInstance3D.new()
			line.mesh = Meshes.box(Vector3(0.5, 0.05, 0.05))
			line.material_override = Mats.solid(Color(0.3, 0.2, 0.15), 0.8)
			line.position = Vector3(0, 0.2 - k * 0.2, 0.0)
			n.add_child(line)
		scrap_nodes[id] = n


func _update_scraps(dt: float) -> void:
	for id in scrap_nodes.keys():
		var n: Node3D = scrap_nodes[id]
		n.rotation.y += dt * 1.6
		n.position.y = scraps[id][1].y + 0.75 + sin(_t * 2.5) * 0.12
		if player.alive and not Game.busy and player.global_position.distance_to(n.position - Vector3(0, 0.6, 0)) < 1.0:
			scrap_nodes.erase(id)
			n.queue_free()
			Game.scraps[id] = true
			Game.save_game()
			Sfx.play("scrap")
			_show_scrap(id)
			return


func _show_scrap(id: String) -> void:
	Game.busy = true
	player.locked = true
	await hud.scrap(scraps[id][2], scraps[id][3], "Planogram scraps: %d / %d" % [Game.scraps.size(), Scraps.ALL.size()])
	player.locked = false
	Game.busy = false


# --- UI -------------------------------------------------------------------------------------

func _build_ui() -> void:
	hud = Hud.new()
	add_child(hud)
	ui = DialogueBox.new()
	add_child(ui)
	runner = Runner.new()
	runner.level = self
	runner.ui = ui
	runner.hud = hud
	add_child(runner)
	runner.load_file(dlg_file)
	pause_menu = PauseMenu.new()
	pause_menu.level = self
	add_child(pause_menu)
	hud.shell(0)
	hud.set_black(true)


func on_dialogue_start() -> void:
	player.locked = true
	hud.prompt_hide()


func on_dialogue_end() -> void:
	player.locked = false
	cam_follow()
	for id in actors.keys():
		var a: Node = actors[id]
		if a != null and a.has_method("set_emotion") and id != "baker":
			a.set_emotion("neutral")
	player.set_emotion("neutral")


func on_line(who: String, sp: Node) -> void:
	if sp == null or not auto_face:
		return
	# the speaker turns to whoever they're talking to
	var listener: Node3D = player if who != "baker" else null
	if who == "baker":
		var best := INF
		for p in runner.participants:
			if p != player and is_instance_valid(p):
				var d: float = absf(p.global_position.x - player.global_position.x)
				if d < best:
					best = d
					listener = p
	if listener != null and sp.has_method("face_toward"):
		sp.face_toward(listener.global_position.x)
		if listener == player or listener is Actor:
			listener.face_toward(sp.global_position.x)
	if runner.participants.is_empty():
		cam_frame([sp, player] if sp != player else [player])


func cam_follow() -> void:
	cam.follow(player)


func cam_frame(nodes: Array) -> void:
	cam.frame(nodes)


# --- level commands for dialogue -------------------------------------------------------------------

func exec(name: String, args: Array) -> void:
	match name:
		"shot":
			var s: Array = shots[args[0]]
			cam.shot(s[0], s[1], args.size() > 1 and args[1] == "instant")
		"walk":
			var who: String = args[0]
			var x := float(args[1])
			if who == "baker":
				await _walk_player(x)
			else:
				var a: Node = actor(who)
				if a != null and a.has_method("walk_to"):
					await a.walk_to(x, float(args[2]) if args.size() > 2 else 3.2)
		"product":
			_product(args[0], args[1] == "on")
		"checkpoint":
			_checkpoint(args[0])
		"hud":
			hud.show_hud(args[0] == "on")
		"pa_name":
			ui.set_pa_name(" ".join(args))
		"event":
			ui.close()   # nobody's talking while things happen
			await call("_ev_" + args[0])
		_:
			push_warning("unknown dialogue command: " + name)
	await get_tree().process_frame


## Freezes a character like a product on the shelf (a human is near).
func _product(who: String, on: bool) -> void:
	if actors.has(who):
		var a: Node = actors[who]
		if a == player:
			player.rig.set_product(on)
		elif a.has_method("set_product"):
			a.set_product(on)


func _walk_player(x: float) -> void:
	var dist := absf(x - player.global_position.x)
	if dist < 0.1:
		return
	player.face_toward(x)
	player.rig.speed = 0.8
	var tw := create_tween()
	tw.tween_property(player, "global_position:x", x, dist / 3.8)
	await tw.finished
	player.rig.speed = 0.0


func _checkpoint(id: String) -> void:
	var changed := Game.checkpoint != id or Game.act != act
	Game.checkpoint = id
	Game.act = act
	Game.save_game()
	if changed and id != "start":
		hud.toast("Checkpoint")
		Sfx.play("checkpoint", -8.0)


func _start_follow() -> void:
	dot_follow = true
	var dot: Node3D = actors.dot
	dot.talk_node = "dot_chat"
	dot.barks = []
	dot.ground_shadow = true
	if not Game.busy:
		dot.global_position = player.global_position + Vector3(-1.6, 0, -0.3)
	_trail.clear()


## A line of green text over a giant's knees.
func _giant_bubble(g: Node3D, text: String, voice := "tyler") -> void:
	var l := Label3D.new()
	l.text = text
	l.font = load("res://assets/fonts/Nunito.ttf")
	l.font_size = 52
	l.pixel_size = 0.016
	l.outline_size = 16
	l.outline_modulate = Color(0.05, 0.05, 0.08)
	l.modulate = Color(0.75, 1.0, 0.8)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	add_child(l)
	l.global_position = g.global_position + Vector3(0, 9.5, 2.0)
	for k in 5:
		get_tree().create_timer(k * 0.08).timeout.connect(Sfx.blip.bind(voice))
	get_tree().create_timer(2.6).timeout.connect(l.queue_free)


## The end-of-act cards, then on to the next act (or the title).
func _finish_act(big: String, small: String, next_act: int, teaser: String) -> void:
	print("%s COMPLETE at %.1fs" % [act_name, _t])
	Game.set_flag("act%d_done" % act)
	Game.save_game()
	await hud.fade(true, 1.4)
	Sfx.music_stop(1.0)
	Sfx.stop_all_ambience(1.0)
	ui.close()
	await hud.title_card(big, small, 3.0)
	var found := 0
	for id in scraps.keys():
		if Game.scraps.has(id):
			found += 1
	var st: Dictionary = Game.stats.get("act%d" % act, {})
	var secs := int(st.get("time", 0.0))
	var tally := "Scraps %d / %d   ·   Cracks %d   ·   Scrambled %d   ·   %d:%02d" % [
		found, scraps.size(), int(st.get("cracks", 0)), int(st.get("deaths", 0)), secs / 60, secs % 60]
	await hud.title_card("SHELF LIFE", "%s\n%s" % [teaser, tally], 4.5)
	if Game.dev.has("end-quit"):
		get_tree().quit()
		return
	# the conversation that called us is still unwinding: let it finish first
	Game.busy = false
	if next_act > 0:
		Game.start_act.call_deferred(next_act)
	else:
		Game.go_title.call_deferred()


## The controls, along the bottom of the screen, the first time a save gets to move.
func _ev_controls_hint() -> void:
	if Game.flag("hint_controls"):
		return
	Game.set_flag("hint_controls")
	if Game.last_device == "pad":
		hud.hint("Stick  move        A  jump  (hold it to go higher)        X  talk", 10.0)
	else:
		hud.hint("A / D  move        Space  jump  (hold it to go higher)        E  talk", 10.0)


## Freezes the picture for a few hundredths of a second: a hit you can feel.
func hitstop(secs := 0.08) -> void:
	if not Game.settings.get("shake", true):
		return
	_hitstops += 1
	Engine.time_scale = 0.05
	await get_tree().create_timer(secs, true, false, true).timeout
	_hitstops -= 1
	if _hitstops <= 0:
		Engine.time_scale = 1.0


func _exit_tree() -> void:
	Engine.time_scale = 1.0


# --- crack / death / respawn -------------------------------------------------------------------------

func _on_crack(n: int) -> void:
	if Game.dev.has("trace"):
		print("CRACK %d at (%.1f, %.1f)" % [n, player.global_position.x, player.global_position.y])
	Game.count(act, "cracks")
	hud.shell(n)
	hud.flash(0.28)
	hitstop(0.08)
	shake(0.6)
	if n == 1 and not Game.visited.has("first_crack") and n < Player.MAX_CRACKS and runner.has("first_crack"):
		runner.run("first_crack")


func _on_died(reason: String) -> void:
	if _dying:
		return
	_dying = true
	Game.busy = true
	player.locked = true
	hud.prompt_hide()
	if Game.dev.has("trace"):
		print("DIED %s at (%.1f, %.1f)" % [reason, player.global_position.x, player.global_position.y])
	Game.count(act, "deaths")
	if reason != "late":
		hud.flash(0.4, 0.3)
		hitstop(0.11)
	shake(1.0)
	var d: Array = DEATH.get(reason, DEATH.splat)
	var quips: Array = d[1]
	await get_tree().create_timer(0.9).timeout
	await hud.death_card(d[0], quips[_rng.randi() % quips.size()])
	await hud.fade(true, 0.5)
	hud.hide_card()
	_respawn()
	await get_tree().create_timer(0.3).timeout
	await hud.fade(false, 0.5)
	player.locked = false
	Game.busy = false
	_dying = false


func _respawn() -> void:
	var cp: Vector3 = checkpoints.get(Game.checkpoint, checkpoints.start)
	player.set_physics_process(true)
	player.respawn(cp)
	hud.shell(0)
	cam.snap()
	_on_respawn()
	if dot_follow:
		actors.dot.global_position = cp + Vector3(-1.6, 0, -0.3)
		_trail.clear()


func restart_checkpoint() -> void:
	if _dying or Game.busy:
		return
	_dying = true
	Game.busy = true
	await hud.fade(true, 0.4)
	_respawn()
	await hud.fade(false, 0.4)
	Game.busy = false
	_dying = false


# --- per frame -------------------------------------------------------------------------------------

func _process(dt: float) -> void:
	_t += dt
	Game.count(act, "time", dt)
	if Game.dev.has("trace"):
		_trace_t -= dt
		if _trace_t <= 0.0:
			_trace_t = 0.25
			print("t=%.2f pos=(%.2f, %.2f) vel=(%.2f, %.2f) floor=%s busy=%s locked=%s" % [_t, player.global_position.x, player.global_position.y, player.velocity.x, player.velocity.y, player.is_on_floor(), Game.busy, player.locked])
	_check_triggers()
	_check_hazards()
	_update_scraps(dt)
	_update_hide()
	_update_follow(dt)
	_update_prompt()
	if cam.mode == "follow":
		cam.dist_override = _cam_zone()
	_tick(dt)
	if not Game.busy and player.alive and not player.locked and Input.is_action_just_pressed("interact") and _interact_target != null:
		var node: String = _interact_target.get("talk_node")
		if node != "" and runner.has(node):
			runner.run(node)
	if player.alive and player.global_position.y < -5.0:
		player.die("splat")


func _update_hide() -> void:
	var p := Vector2(player.global_position.x, player.global_position.y)
	var hid := false
	for r in hide_zones:
		if r.has_point(p):
			hid = true
	player.hidden = hid


func _update_follow(dt: float) -> void:
	if not dot_follow:
		return
	var dot: Node3D = actors.dot
	_trail_t -= dt
	if _trail_t <= 0.0:
		_trail_t = 0.05
		if _trail.is_empty() or _trail[_trail.size() - 1].distance_to(player.global_position) > 0.08:
			_trail.append(player.global_position)
			if _trail.size() > 80:
				_trail.pop_front()
	var target: Vector3 = player.global_position + Vector3(-1.6 * player.facing_dir, 0, 0)
	if _trail.size() > 14:
		target = _trail[_trail.size() - 14]
	var cur: Vector3 = dot.global_position
	var goal := Vector3(target.x, target.y, -0.3)
	if cur.distance_to(player.global_position) > 18.0:
		dot.global_position = player.global_position + Vector3(-1.6, 0, -0.3)
		return
	var close: bool = absf(cur.x - player.global_position.x) < 1.4 and absf(cur.y - player.global_position.y) < 0.5
	if close:
		goal.x = cur.x
	var nxt := cur.lerp(goal, 1.0 - exp(-dt * 7.0))
	var vx := (nxt.x - cur.x) / maxf(dt, 0.0001)
	dot.global_position = nxt
	var r: Node3D = dot.rigs[0]
	r.speed = clampf(absf(vx) / 5.0, 0.0, 1.0)
	r.grounded = absf(nxt.y - goal.y) < 0.2
	if absf(vx) > 0.4:
		r.face_dir(signf(vx))
	if not Game.busy and dot_barks.size() > 0:
		_dot_bark_t -= dt
		if _dot_bark_t <= 0.0:
			_dot_bark_t = _rng.randf_range(22.0, 34.0)
			dot.bubble(dot_barks[_rng.randi() % dot_barks.size()], 3.6)


func _update_prompt() -> void:
	_interact_target = null
	Actor.prompted = null
	if Game.busy or not player.alive or player.locked:
		hud.prompt_hide()
		return
	var best := 1.0
	var companion: Node3D = null
	for id in actors.keys():
		var a: Node = actors[id]
		if a == player or not (a is Node3D) or not a.visible:
			continue
		var tn = a.get("talk_node")
		if tn == null or tn == "":
			continue
		var d: float = Vector2(a.global_position.x - player.global_position.x, (a.global_position.y - player.global_position.y) * 1.5).length()
		var reach: float = a.get("talk_radius") if a.get("talk_radius") != null else 2.6
		if d >= reach:
			continue
		# Dot tags along everywhere: anyone else in reach gets the button first
		if dot_follow and id == "dot":
			if _companion_ok():
				companion = a
		elif d / reach < best:
			best = d / reach
			_interact_target = a
	if _interact_target == null:
		_interact_target = companion
	if _interact_target == null:
		hud.prompt_hide()
		return
	var hp: Vector3 = _interact_target.head_pos() + Vector3(0, 0.55, 0)
	if cam.is_position_behind(hp):
		hud.prompt_hide()
		return
	var sp := cam.unproject_position(hp)
	Actor.prompted = _interact_target
	hud.prompt("%s  Talk" % Game.glyph("interact"), sp)
