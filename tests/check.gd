extends SceneTree
## Headless sanity check: every script compiles, the dialogue parses, every
## jump target exists and every command is one the game knows.
##   godot --headless --path . --script tests/check.gd

const KNOWN_CMDS := ["wait", "set", "unset", "objective", "sfx", "music", "amb", "amb_off", "title",
	"fade", "letterbox", "emote", "anim", "face", "bark", "cam", "shot", "walk", "product",
	"checkpoint", "hud", "pa_name", "event"]


func _initialize() -> void:
	var ok := true
	for path in _scripts("res://scripts"):
		var s: Script = load(path)
		if s == null or not s.can_instantiate():
			print("FAIL script ", path)
			ok = false
	var Parser = load("res://scripts/dialogue/dlg_parser.gd")
	var Cast = load("res://scripts/dialogue/cast.gd")
	var Rig = load("res://scripts/actors/food_rig.gd")
	var base := FileAccess.get_file_as_string("res://scripts/world/level.gd")
	var total := 0
	for act in [1, 2]:
		var nodes: Dictionary = Parser.parse(FileAccess.get_file_as_string("res://dialogue/act%d.dlg" % act))
		total += nodes.size()
		for p in Parser.validate(nodes):
			print("DLG act%d %s" % [act, p])
			ok = false
		var src := base + FileAccess.get_file_as_string("res://scripts/world/act%d.gd" % act)
		for id in nodes.keys():
			for e in nodes[id]:
				var at := "DLG act%d line %d:" % [act, e.line]
				if e.t == "cmd":
					if not e.name in KNOWN_CMDS:
						print("%s unknown command '%s'" % [at, e.name])
						ok = false
					if e.name == "event" and src.find("func _ev_%s(" % e.args[0]) < 0:
						print("%s no event _ev_%s" % [at, e.args[0]])
						ok = false
					if e.name == "shot" and src.find('"%s":' % e.args[0]) < 0:
						print("%s no shot '%s'" % [at, e.args[0]])
						ok = false
					if e.name == "checkpoint" and src.find('"%s": Vector3(' % e.args[0]) < 0:
						print("%s no checkpoint '%s'" % [at, e.args[0]])
						ok = false
					if e.name in ["cam", "walk", "anim", "emote"] and e.args.size() > 0:
						for who in (e.args if e.name == "cam" else [e.args[0]]):
							if who != "off" and not Cast.CAST.has(who):
								print("%s unknown actor '%s'" % [at, who])
								ok = false
				if e.t == "line" and not Cast.CAST.has(e.who):
					print("%s unknown speaker '%s'" % [at, e.who])
					ok = false
				if e.t == "line" and e.emo != "" and not Rig.EMO.has(e.emo):
					print("%s unknown emotion '%s'" % [at, e.emo])
					ok = false
	print("dialogue nodes: ", total)
	print("CHECK OK" if ok else "CHECK FAILED")
	quit(0 if ok else 1)


func _scripts(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_scripts(dir.path_join(sub)))
	return out
