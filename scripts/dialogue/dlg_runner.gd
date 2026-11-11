extends Node
## Runs dialogue nodes: lines go to the dialogue box, choices become menus,
## commands drive the camera, actors, sound and the level's own events.

const Parser = preload("res://scripts/dialogue/dlg_parser.gd")
const Cast = preload("res://scripts/dialogue/cast.gd")

signal finished(node: String)

var nodes := {}
var level: Node          ## actor(id), exec(cmd, args), on_line(who, speaker), on_dialogue_start/end()
var ui: Node             ## dialogue_box.gd
var hud: Node            ## hud.gd
var running := false
var participants: Array = []
var _queue: Array = []


func load_file(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	nodes = Parser.parse(f.get_as_text())
	for p in Parser.validate(nodes):
		push_warning("dialogue: " + p)


func has(id: String) -> bool:
	return nodes.has(id)


## Runs a node (and whatever it jumps to). Awaitable. If a conversation is
## already running, the node is queued to run after it.
func run(id: String) -> void:
	if not nodes.has(id):
		push_error("dialogue: no node '%s'" % id)
		return
	if running:
		_queue.append(id)
		return
	running = true
	Game.busy = true
	level.on_dialogue_start()
	var cur := id
	while cur != "" and cur != "END":
		if not nodes.has(cur):
			push_error("dialogue: missing node '%s'" % cur)
			break
		Game.visited[cur] = true
		var list: Array = nodes[cur]
		var next := ""
		var i := 0
		while i < list.size():
			var e: Dictionary = list[i]
			if e.t == "choice":
				var opts := []
				while i < list.size() and list[i].t == "choice":
					if cond_ok(list[i].cond):
						opts.append(list[i])
					i += 1
				if opts.is_empty():
					continue
				var pick: int = await ui.choose(opts.map(func(o): return o.text))
				next = opts[pick].target
				break
			i += 1
			if not cond_ok(e.cond):
				continue
			if Game.dev.has("trace"):
				print("dlg %s:%d %s %s" % [cur, e.line, e.t, e.get("name", e.get("who", ""))])
			if e.t == "line":
				await _say(e)
			elif e.t == "goto":
				next = e.target
				break
			elif e.t == "cmd":
				await _cmd(e.name, e.args)
		cur = next
	ui.close()
	for p in participants:
		if is_instance_valid(p):
			p.set_talking(false)
	participants = []
	level.on_dialogue_end()
	running = false
	Game.busy = false
	finished.emit(id)
	if _queue.size() > 0:
		run(_queue.pop_front())


func cond_ok(c: String) -> bool:
	if c == "":
		return true
	for part in c.split("&", false):
		part = part.strip_edges()
		var neg := part.begins_with("!")
		if neg:
			part = part.substr(1)
		var v: bool
		if part.begins_with("seen:"):
			v = Game.visited.has(part.substr(5))
		else:
			v = Game.flag(part)
		if v == neg:
			return false
	return true


func _say(e: Dictionary) -> void:
	var who: String = e.who
	var text: String = e.text
	if who == "pa":
		await ui.pa(text, Cast.info("pa"))
		return
	var sp: Node = level.actor(who)
	if sp != null and not sp.has_method("set_talking"):
		sp = null
	if sp != null and e.emo != "":
		sp.set_emotion(e.emo)
	level.on_line(who, sp)
	if sp != null:
		sp.set_talking(true)
	await ui.say(who, text, sp)
	if sp != null:
		sp.set_talking(false)


func _cmd(name: String, args: Array) -> void:
	match name:
		"wait":
			await get_tree().create_timer(float(args[0])).timeout
		"set":
			for a in args:
				Game.set_flag(a)
		"unset":
			for a in args:
				Game.set_flag(a, false)
		"objective":
			hud.objective(" ".join(args))
		"sfx":
			Sfx.play(args[0], float(args[1]) if args.size() > 1 else 0.0)
		"music":
			if args[0] == "off":
				Sfx.music_stop(float(args[1]) if args.size() > 1 else 1.5)
			elif args[0] == "cut":
				Sfx.music_cut()
			else:
				Sfx.music(args[0], float(args[1]) if args.size() > 1 else -8.0)
		"amb":
			Sfx.ambience(args[0], float(args[1]) if args.size() > 1 else -14.0)
		"amb_off":
			Sfx.ambience_stop(args[0])
		"title":
			await hud.title_card(args[0], args[1] if args.size() > 1 else "")
		"fade":
			await hud.fade(args[0] == "out", float(args[1]) if args.size() > 1 else 0.8)
		"letterbox":
			hud.letterbox(args[0] == "on")
		"emote":
			var sp: Node = level.actor(args[0])
			if sp != null:
				sp.set_emotion(args[1])
		"anim":
			var sp2: Node = level.actor(args[0])
			if sp2 != null:
				sp2.emote(args[1])
		"face":
			var sp3: Node = level.actor(args[0])
			if sp3 != null:
				var tgt: String = args[1]
				if tgt == "left":
					sp3.face_toward(sp3.global_position.x - 10.0)
				elif tgt == "right":
					sp3.face_toward(sp3.global_position.x + 10.0)
				elif tgt == "front":
					sp3.face_toward(sp3.global_position.x)
				else:
					var other: Node = level.actor(tgt)
					if other != null:
						sp3.face_toward(other.global_position.x)
		"bark":
			var sp4: Node = level.actor(args[0])
			if sp4 != null and sp4.has_method("bubble"):
				sp4.bubble(" ".join(args.slice(1)))
		"cam":
			if args.size() == 0 or args[0] == "off":
				participants = []
				level.cam_follow()
			else:
				participants = []
				for a in args:
					var sp5: Node = level.actor(a)
					if sp5 != null:
						participants.append(sp5)
				level.cam_frame(participants)
		_:
			await level.exec(name, args)
