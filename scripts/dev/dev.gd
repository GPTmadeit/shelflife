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
var _touches: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var d: Dictionary = Game.dev
	if d.has("shot"):
		_shot = d.shot
		_shot_t = d.shot_t
		_burst_n = d.get("burst_n", 0)
		_burst_step = d.get("burst_step", 0.0)
	_acts = d.get("act", [])
	if d.has("touch-edit"):
		get_tree().create_timer(1.0).timeout.connect(func(): Touch.edit())
	_touches = d.get("touch-act", [])


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
	for i in _touches.size():
		var f: Dictionary = _touches[i]
		if not f.down and _t >= f.t0 and _t < f.t1:
			f.down = true
			f.from = _spot(f.a, Vector2.ZERO)
			f.to = _spot(f.b, f.from) if f.b != "" else f.from
			f.at = f.from
			_touch(i, f.from, true)
		elif f.down and _t >= f.t1:
			f.down = false
			f.t0 = INF
			_touch(i, f.at, false)
		elif f.down and f.to != f.from:
			var p: Vector2 = f.from.lerp(f.to, clampf((_t - f.t0) / 0.2, 0.0, 1.0))
			if p != f.at:
				var xf := get_viewport().get_final_transform()
				var ev := InputEventScreenDrag.new()
				ev.index = 10 + i
				ev.position = xf * p
				ev.relative = xf.basis_xform(p - f.at)
				f.at = p
				Input.parse_input_event(ev)
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


## A spot for --touch-act, in the game's coordinates: "x,y", a touch
## control's name, "bubble" (the Talk bubble over someone), or "+dx,dy" from `from`.
func _spot(s: String, from: Vector2) -> Vector2:
	if Touch.CONTROLS.has(s):
		return Touch.center(s)
	if s == "bubble" and Game.current != null and Game.current.get("hud") != null:
		return (Game.current.hud.prompt_rect() as Rect2).get_center()
	var xy := s.trim_prefix("+").split(",")
	var p := Vector2(float(xy[0]), float(xy[1]) if xy.size() > 1 else 0.0)
	return from + p if s.begins_with("+") else p


## Touches go in at window coordinates, like a real screen's.
func _touch(i: int, at: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 10 + i
	ev.position = get_viewport().get_final_transform() * at
	ev.pressed = pressed
	Input.parse_input_event(ev)
	if Game.dev.has("trace"):
		print("TOUCH %d %s at (%d, %d)" % [i, "down" if pressed else "up", at.x, at.y])


func _save(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)


func _finish() -> void:
	if Game.dev.has("fps") or Game.dev.has("shot"):
		print("avg fps %.1f over %.1fs (%d frames)" % [_frames / maxf(_t, 0.001), _t, _frames])
	get_tree().quit()
