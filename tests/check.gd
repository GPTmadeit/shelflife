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
	var act = load("res://scripts/world/act1.gd")
	var nodes: Dictionary = Parser.parse(FileAccess.get_file_as_string("res://dialogue/act1.dlg"))
	for p in Parser.validate(nodes):
		print("DLG ", p)
		ok = false
	var src := FileAccess.get_file_as_string("res://scripts/world/act1.gd")
	for id in nodes.keys():
		for e in nodes[id]:
			if e.t == "cmd":
				if not e.name in KNOWN_CMDS:
					print("DLG line %d: unknown command '%s'" % [e.line, e.name])
					ok = false
				if e.name == "event" and src.find("func _ev_%s(" % e.args[0]) < 0:
					print("DLG line %d: no event _ev_%s" % [e.line, e.args[0]])
					ok = false
				if e.name == "shot" and src.find('"%s":' % e.args[0]) < 0:
					print("DLG line %d: no shot '%s'" % [e.line, e.args[0]])
					ok = false
			if e.t == "line" and not Cast.CAST.has(e.who):
				print("DLG line %d: unknown speaker '%s'" % [e.line, e.who])
				ok = false
			if e.t == "line" and e.emo != "" and not load("res://scripts/actors/food_rig.gd").EMO.has(e.emo):
				print("DLG line %d: unknown emotion '%s'" % [e.line, e.emo])
				ok = false
	print("dialogue nodes: ", nodes.size())
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
