extends Node
## Entry point. Parses developer arguments (everything after `--`) and opens
## the first screen.
##
##   --shot <png> <seconds>   save a screenshot after <seconds> and quit
##   --burst <n> <step>       also save n frames, step seconds apart, before it
##   --cp <checkpoint>        start at a checkpoint (skips the title)
##   --at <x,y>               put Baker here instead of at the checkpoint
##   --level <n>              which act --cp means (default 1)
##   --flags a,b,c            story flags to set first
##   --dlg <node>             start a dialogue node right away (needs --cp)
##   --act a@t0-t1,...        hold input actions between times (seconds)
##   --gallery                character gallery
##   --godmode                no falling damage, the Narc never calls cleanup
##   --fps                    print the average frame rate on quit
##   --quit <seconds>         quit after this long
##   --end-quit               quit when Act One ends (full playthrough tests)
##   --update-url, --update-now, --update-full, --update-log: see updater.gd


func _ready() -> void:
	Game.main = self
	Game.dev = _parse(OS.get_cmdline_user_args())
	if Game.dev.has("shot") or Game.dev.has("fps"):
		# hidden test windows: a compositor-throttled vsync would stall the game
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var dev: Node = load("res://scripts/dev/dev.gd").new()
	dev.name = "Dev"
	add_child(dev)
	Game.apply_settings()
	if Game.dev.has("update-now"):
		Updater.unattended()
	elif Game.dev.has("gallery"):
		Game.switch_to(load("res://scripts/dev/gallery.gd").new())
	elif Game.dev.has("cp"):
		for f in Game.dev.get("flags", []):
			Game.set_flag(f)
		Game.checkpoint = Game.dev.cp
		Game.act = int(Game.dev.get("level", 1))
		if Game.act >= 2:
			Game.set_flag("dot_joined")
		Game.start_level(Game.dev.cp)
	else:
		Game.go_title()


func _parse(args: PackedStringArray) -> Dictionary:
	var d := {}
	var i := 0
	while i < args.size():
		var a := args[i]
		match a:
			"--shot":
				d.shot = args[i + 1]
				d.shot_t = float(args[i + 2])
				i += 2
			"--burst":
				d.burst_n = int(args[i + 1])
				d.burst_step = float(args[i + 2])
				i += 2
			"--cp":
				d.cp = args[i + 1]
				i += 1
			"--flags":
				d.flags = Array(args[i + 1].split(",", false))
				i += 1
			"--dlg":
				d.dlg = args[i + 1]
				i += 1
			"--act":
				d.act = _acts(args[i + 1])
				i += 1
			"--quit":
				d.quit = float(args[i + 1])
				i += 1
			"--at":
				var xy := args[i + 1].split(",")
				d.at = Vector3(float(xy[0]), float(xy[1]) if xy.size() > 1 else 0.0, 0.0)
				i += 1
			"--level":
				d.level = int(args[i + 1])
				i += 1
			"--quality":
				d.quality = int(args[i + 1])
				i += 1
			"--update-url", "--update-log":
				d[a.substr(2)] = args[i + 1]
				i += 1
			"--gallery", "--godmode", "--fps", "--keep":
				d[a.substr(2)] = true
			_:
				if a.begins_with("--"):
					d[a.substr(2)] = true
		i += 1
	return d


## "jump@1.0-1.2,move_right@0.5-3" -> [{name, t0, t1}]
func _acts(s: String) -> Array:
	var out := []
	for part in s.split(",", false):
		var at := part.find("@")
		var name := part.substr(0, at)
		var times := part.substr(at + 1).split("-")
		var t0 := float(times[0])
		var t1 := float(times[1]) if times.size() > 1 else t0 + 0.12
		out.append({"name": name, "t0": t0, "t1": t1, "down": false})
	return out
