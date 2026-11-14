extends Node
## Global state: settings, story flags, save data, input map and screen flow.

const Version = preload("res://scripts/core/version.gd")
const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.cfg"

var main: Node = null          ## the Main node (scenes/main.tscn); screens live under it
var current: Node = null       ## the active screen (title or a level)
var flags := {}                ## story flags, name -> true
var visited := {}              ## dialogue nodes seen, id -> true
var scraps := {}               ## Planogram scraps collected, id -> true
var checkpoint := "start"
var stats := {}                ## "act1" -> {time, cracks, deaths}: shown on the end-of-act card
var act := 1                   ## which act the checkpoint belongs to
var settings := {
	"master": 0.9, "music": 0.7, "sfx": 0.85, "voice": 0.75,
	"fullscreen": false, "shake": true, "text_speed": 1.0, "quality": 2, "updates": true,
	# touch controls (see scripts/ui/touch.gd): 0 = while you use the touchscreen, 1 = always, 2 = never
	"touch": 0, "touch_move": 0, "touch_opacity": 0.7, "touch_vibrate": true, "touch_layout": {},
}
var last_device := "kb"        ## "kb", "pad" or "touch": picks the button names in prompts
var dev := {}                  ## parsed developer arguments (see boot.gd)
var busy := false              ## a conversation or cutscene is running
var _last_bark := -100.0
var _back_at := -1000


## One speech bubble at a time, store-wide.
func bark_ok() -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_bark < 3.5:
		return false
	_last_bark = now
	return true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_setup_input()
	if mobile():
		last_device = "touch"
		Engine.max_fps = 60   # phones at 90 or 120 Hz would draw twice the frames for nothing
	load_settings()
	apply_settings()


## A phone or tablet.
func mobile() -> bool:
	return OS.has_feature("mobile")


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		last_device = "pad"
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		last_device = "pad"
	elif event is InputEventScreenTouch:
		last_device = "touch"
	elif (event is InputEventKey and event.keycode != KEY_BACK) or (event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION):
		last_device = "kb"   # (Android's Back button and the clicks made up from touches don't count)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# one press of Back arrives twice (and as a Back key too): act on it once
		var now := Time.get_ticks_msec()
		if now - _back_at > 300:
			_back_at = now
			back()
	elif what == NOTIFICATION_APPLICATION_PAUSED and mobile():
		# a call, the home button: stop the clock on whatever's chasing Baker
		if current != null and is_instance_valid(current) and current.has_method("auto_pause"):
			current.auto_pause()


## Android's back button (or gesture): out of whatever's open, one step at a time.
func back() -> void:
	if Touch.back():
		return
	if current != null and is_instance_valid(current) and current.has_method("go_back"):
		current.go_back()


# --- screens ----------------------------------------------------------------

func switch_to(node: Node) -> void:
	get_tree().paused = false
	if current != null and is_instance_valid(current):
		current.queue_free()
	current = node
	main.add_child(node)


func go_title() -> void:
	switch_to(load("res://scripts/ui/title.gd").new())


const ACTS := {1: "Act One: Unplanned", 2: "Act Two: Discontinued"}


func start_level(cp: String) -> void:
	var lvl: Node = load("res://scripts/world/act%d.gd" % act).new()
	lvl.set("start_checkpoint", cp)
	switch_to(lvl)


## Starts an act from its beginning, keeping flags and scraps.
func start_act(n: int) -> void:
	act = n
	checkpoint = "start"
	if n >= 2:
		# Act Two opens with Dot at Baker's side, however you got here
		set_flag("dot_joined")
	save_game()
	start_level("start")


func new_game() -> void:
	flags = {}
	visited = {}
	scraps = {}
	stats = {}
	checkpoint = "start"
	act = 1
	start_level("start")


## Replays an act from the title screen. Scraps stay; that act's story resets.
func replay_act(n: int) -> void:
	load_game()
	for k in flags.keys():
		if (n == 1 and not k.begins_with("a2_") and not k.ends_with("_done")) or (n == 2 and k.begins_with("a2_")):
			flags.erase(k)
	for k in visited.keys():
		if k.begins_with("a2_") == (n == 2):
			visited.erase(k)
	stats.erase("act%d" % n)
	start_act(n)


func continue_game() -> void:
	if load_game():
		start_level(checkpoint)
	else:
		new_game()


# --- flags ------------------------------------------------------------------

func flag(name: String) -> bool:
	return flags.get(name, false) == true


func set_flag(name: String, on := true) -> void:
	if on:
		flags[name] = true
	else:
		flags.erase(name)


## Adds to one of an act's counters ("time", "cracks", "deaths").
func count(act_no: int, what: String, by := 1.0) -> void:
	var k := "act%d" % act_no
	if not stats.has(k) or typeof(stats[k]) != TYPE_DICTIONARY:
		stats[k] = {}
	stats[k][what] = float(stats[k].get(what, 0.0)) + by


# --- save -------------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var d := {
		"version": Version.VERSION, "act": act, "checkpoint": checkpoint, "flags": flags,
		"visited": visited, "scraps": scraps, "stats": stats, "time": Time.get_unix_time_from_system(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d, "\t"))
		f.close()


func load_game() -> bool:
	if not has_save():
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(d) != TYPE_DICTIONARY:
		return false
	checkpoint = str(d.get("checkpoint", "start"))
	act = clampi(int(d.get("act", 1)), 1, ACTS.size())
	flags = _dict(d.get("flags", {}))
	visited = _dict(d.get("visited", {}))
	scraps = _dict(d.get("scraps", {}))
	stats = _dict(d.get("stats", {}))
	return true


## What the save says without loading it: {act, checkpoint, flags} or {}.
func peek_save() -> Dictionary:
	if not has_save():
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	return d if typeof(d) == TYPE_DICTIONARY else {}


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _dict(v) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}


# --- settings ---------------------------------------------------------------

func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		settings.quality = _default_quality()
		return
	for k in settings.keys():
		settings[k] = cf.get_value("settings", k, settings[k])


## Phones and old Intel integrated graphics get Low; other integrated GPUs Medium.
func _default_quality() -> int:
	if mobile():
		return 0
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	if gpu.contains("hd graphics") or gpu.contains("gma") or gpu.contains("llvmpipe"):
		return 0
	if gpu.contains("intel") or gpu.contains("uhd") or gpu.contains("mali") or gpu.contains("adreno"):
		return 1
	return 2


func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in settings.keys():
		cf.set_value("settings", k, settings[k])
	cf.save(SETTINGS_PATH)


func apply_settings() -> void:
	_bus_volume("Master", settings.master)
	_bus_volume("Music", settings.music)
	_bus_volume("SFX", settings.sfx)
	_bus_volume("Ambience", settings.sfx)
	_bus_volume("Voice", settings.voice)
	apply_graphics()
	if dev.has("shot") or mobile():
		return  # screenshots keep the window they were given; phones are always full screen
	var fs: bool = settings.fullscreen
	var mode := DisplayServer.window_get_mode()
	var is_fs := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fs and not is_fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fs and is_fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


signal graphics_changed


## 2 = high (shadows, MSAA, glow), 1 = medium (no MSAA), 0 = low (no shadows,
## no glow, 3D drawn at 70% and scaled up).
func quality() -> int:
	if dev.has("quality"):
		return int(dev.quality)
	return int(settings.get("quality", 2))


func apply_graphics() -> void:
	var q := quality()
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_2X if q >= 2 else Viewport.MSAA_DISABLED
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	var s := 1.0 if q >= 1 else 0.75
	if mobile():
		# phone screens are dense: the 3D is drawn at most this many lines tall
		var lines: float = [720.0, 900.0, 1080.0][clampi(q, 0, 2)]
		s = minf(s, lines / maxf(float(get_window().size.y), 1.0))
	vp.scaling_3d_scale = clampf(s, 0.4, 1.0)
	graphics_changed.emit()


## Sets up an environment and key light for the current quality.
func tune(env: Environment, key: DirectionalLight3D) -> void:
	var q := quality()
	if env != null:
		env.glow_enabled = q >= 1 and not dev.has("noglow")
	if key != null:
		key.shadow_enabled = q >= 1 and not dev.has("noshadow")


func _bus_volume(bus: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(i, linear <= 0.001)


func _setup_buses() -> void:
	for bus in ["Music", "SFX", "Ambience", "Voice"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")


# --- input ------------------------------------------------------------------

func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _pad(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	return e


func _axis(axis: JoyAxis, dir: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = dir
	return e


func _bind(action: String, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.35)
	for e in events:
		InputMap.action_add_event(action, e)


func _setup_input() -> void:
	_bind("move_left", [_key(KEY_A), _key(KEY_LEFT), _pad(JOY_BUTTON_DPAD_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_bind("move_right", [_key(KEY_D), _key(KEY_RIGHT), _pad(JOY_BUTTON_DPAD_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_bind("jump", [_key(KEY_SPACE), _key(KEY_W), _key(KEY_UP), _pad(JOY_BUTTON_A)])
	_bind("interact", [_key(KEY_E), _key(KEY_ENTER), _key(KEY_KP_ENTER), _pad(JOY_BUTTON_X)])
	_bind("advance", [_key(KEY_SPACE), _key(KEY_E), _key(KEY_ENTER), _key(KEY_KP_ENTER), _pad(JOY_BUTTON_A), _pad(JOY_BUTTON_X)])
	_bind("pause", [_key(KEY_ESCAPE), _key(KEY_P), _pad(JOY_BUTTON_START)])
	_bind("call", [_key(KEY_Q), _key(KEY_F), _pad(JOY_BUTTON_Y)])


## Button glyph for an action, matching the device the player last touched
## (on a touchscreen, the name on the on-screen button).
func glyph(action: String) -> String:
	var pad := last_device == "pad"
	if last_device == "touch":
		match action:
			"interact":
				return "TALK"
			"jump":
				return "JUMP"
			"advance":
				return "Tap"
			"pause":
				return "Pause"
			"call":
				return "WHISTLE"
	match action:
		"interact":
			return "X" if pad else "E"
		"jump":
			return "A" if pad else "Space"
		"advance":
			return "A" if pad else "Space"
		"pause":
			return "Start" if pad else "Esc"
		"call":
			return "Y" if pad else "Q"
	return action


## An action and what it does, for hints: "Q  whistle" with a keyboard,
## "Y  whistle" with a gamepad, just "WHISTLE" (the button's name) on a touchscreen.
func cue(action: String, verb: String) -> String:
	if last_device == "touch":
		return glyph(action)
	return "%s  %s" % [glyph(action), verb]


## A short buzz, on phones (Settings → Touch controls → Customize → Vibrate).
func buzz(ms: int, strength := 0.5) -> void:
	if last_device == "touch" and mobile() and bool(settings.get("touch_vibrate", true)):
		Input.vibrate_handheld(ms, strength)
