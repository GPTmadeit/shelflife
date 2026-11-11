extends Node
## Developer hooks driven by command-line flags (see boot.gd): screenshots,
## scripted input, frame-rate logging.

var _t := 0.0
var _shot := ""
var _shot_t := 0.0
var _burst_n := 0
var _burst_step := 0.0
var _burst_done := 0
var _frames := 0
var _acts: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var d: Dictionary = Game.dev
	if d.has("shot"):
		_shot = d.shot
		_shot_t = d.shot_t
		_burst_n = d.get("burst_n", 0)
		_burst_step = d.get("burst_step", 0.0)
	_acts = d.get("act", [])


func _process(dt: float) -> void:
	_t += dt
	_frames += 1
	for a in _acts:
		if not a.down and _t >= a.t0 and _t < a.t1:
			_send(a.name, true)
			a.down = true
		elif a.down and _t >= a.t1:
			_send(a.name, false)
			a.down = false
			a.t0 = INF
	if _shot != "":
		if _burst_n > 0 and _burst_done < _burst_n:
			var at := _shot_t - (_burst_n - _burst_done) * _burst_step
			if _t >= at:
				_save(_shot.get_basename() + "_%02d.png" % _burst_done)
				_burst_done += 1
		if _t >= _shot_t:
			_save(_shot)
			print("shot saved ", _shot)
			_shot = ""
			_finish()
	if Game.dev.has("quit") and _t >= float(Game.dev.quit):
		_finish()


## Real input events, so _input() handlers (dialogue, menus) see them too.
func _send(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


func _save(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)


func _finish() -> void:
	if Game.dev.has("fps") or Game.dev.has("shot"):
		print("avg fps %.1f over %.1fs (%d frames)" % [_frames / maxf(_t, 0.001), _t, _frames])
	get_tree().quit()
