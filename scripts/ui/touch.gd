extends CanvasLayer
## On-screen touch controls: a stick (or two arrow buttons) to move, and
## JUMP, TALK, WHISTLE and pause buttons. They press the same input actions
## the keyboard and gamepad do, so the rest of the game can't tell them apart.
##
## Every control can be dragged somewhere else and resized, from Settings →
## Touch controls → Customize (touch_editor.gd). The layout is saved with the
## settings as each control's distance from the two nearest screen edges, so
## it stays under your thumbs on any shape of screen.
##
## Settings it reads: "touch" (0 = while you're using the touchscreen,
## 1 = always, 2 = never), "touch_move" (Move), "touch_opacity",
## "touch_vibrate" and "touch_layout" (id -> {x, y, r, b, s}).
##
## A finger that lands on a control belongs to it until it lifts. Any other
## finger works as the mouse: this turns it into mouse clicks and drags, for
## the menus, the dialogue box and the Talk bubbles. (Godot's own version of
## that only ever follows the first finger, which is usually on the stick, so
## it's switched off in project.godot.) One finger at a time is the mouse.

const Kit = preload("res://scripts/ui/ui_kit.gd")
const TouchEditor = preload("res://scripts/ui/touch_editor.gd")

enum Move { FLOAT, FIXED, ARROWS }
const MOVE_NAMES := ["Stick that follows your thumb", "Stick that stays put", "Arrow buttons"]

## r: radius at size 1 (for "move", the stick's base)
const CONTROLS := {
	"move": {"name": "Move", "r": 112.0, "action": "", "label": ""},
	"jump": {"name": "Jump", "r": 86.0, "action": "jump", "label": "JUMP"},
	"talk": {"name": "Talk", "r": 66.0, "action": "interact", "label": "TALK"},
	"call": {"name": "Whistle for Dot", "r": 62.0, "action": "call", "label": "WHISTLE"},
	"pause": {"name": "Pause", "r": 40.0, "action": "pause", "label": ""},
}
const HIT_ORDER := ["pause", "jump", "talk", "call", "move"]
const DRAW_ORDER := ["move", "call", "talk", "jump", "pause"]

## Where they start: px from the left edge (or the right, r) and from the top
## (or the bottom, b), and the size.
const DEFAULTS := {
	"move": {"x": 250.0, "y": 215.0, "r": false, "b": true, "s": 1.0},
	"jump": {"x": 175.0, "y": 185.0, "r": true, "b": true, "s": 1.0},
	"talk": {"x": 385.0, "y": 118.0, "r": true, "b": true, "s": 1.0},
	"call": {"x": 310.0, "y": 352.0, "r": true, "b": true, "s": 1.0},
	"pause": {"x": 262.0, "y": 72.0, "r": true, "b": false, "s": 1.0},
}
const MIN_SIZE := 0.6
const MAX_SIZE := 1.6
const DEFAULT_OPACITY := 0.7

const INK := Color(0.05, 0.05, 0.07)
const GOLD := Color(1.0, 0.8, 0.3)
const CREAM := Color(0.98, 0.94, 0.85)
const GLAZE := Color(0.96, 0.45, 0.62)

var _canvas: Control            ## draws the controls during play
var _edit_layer: CanvasLayer
var _editor: TouchEditor = null
var _fingers := {}              ## touch index -> control id ("" once its control went away)
var _held := {}                 ## action -> how many fingers hold it
var _stick_finger := -1
var _stick_base := Vector2.ZERO
var _knob := Vector2.ZERO       ## the knob's offset from the base
var _move := 0.0                ## -1..1, as last pressed
var _alpha := {}                ## id -> 0..1: controls fade in and out
var _want := {}                 ## id -> shown (and pressable) right now
var _ctx := {}                  ## what the level allows, from its touch_context()
var _pointer := -1              ## the finger that is being the mouse
var _pointer_at := Vector2.ZERO
var _pill: StyleBoxFlat
var _t := 0.0


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(func(): draw_controls(_canvas, false, ""))
	_canvas.visible = false
	add_child(_canvas)
	_edit_layer = CanvasLayer.new()
	_edit_layer.layer = 60
	add_child(_edit_layer)
	_pill = StyleBoxFlat.new()
	_pill.anti_aliasing = true
	for id in CONTROLS:
		_alpha[id] = 0.0
		_want[id] = false


# --- when they show ---------------------------------------------------------------

## The player wants touch controls: always, never, or while they're touching.
func enabled() -> bool:
	match int(Game.settings.get("touch", 0)):
		1:
			return true
		2:
			return false
	return Game.last_device == "touch"


## The controls for playing (not just pause) are on screen.
func showing() -> bool:
	return bool(_want.get("jump", false))


func editing() -> bool:
	return _editor != null


func move_mode() -> int:
	return clampi(int(Game.settings.get("touch_move", Move.FLOAT)), 0, 2)


func _context() -> Dictionary:
	var lvl: Node = Game.current
	if lvl == null or not is_instance_valid(lvl) or not lvl.has_method("touch_context"):
		return {}
	return lvl.touch_context()


func _process(dt: float) -> void:
	_t += dt
	_ctx = _context()
	var on := not _ctx.is_empty() and enabled() and _editor == null
	var play: bool = on and bool(_ctx.get("play", false))
	_want["move"] = play
	_want["jump"] = play
	_want["talk"] = play
	_want["call"] = play and bool(_ctx.get("call", false))
	_want["pause"] = on and bool(_ctx.get("pause", false))
	var any := false
	for id in CONTROLS:
		if not _want[id]:
			_let_go(id)
		_alpha[id] = move_toward(float(_alpha[id]), 1.0 if _want[id] else 0.0, dt * 7.0)
		any = any or _alpha[id] > 0.0
	_canvas.visible = any
	if any:
		_canvas.queue_redraw()


# --- input ---------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			Game.last_device = "touch"
			if _editor == null and _down(st.index, st.position):
				get_viewport().set_input_as_handled()
			elif _pointer == -1:
				_pointer = st.index
				_mouse_button(st.position, true, st.double_tap)
		elif _fingers.has(st.index):
			_release_finger(st.index)
			_fingers.erase(st.index)
			get_viewport().set_input_as_handled()
		elif st.index == _pointer:
			_pointer = -1
			_mouse_button(st.position, false)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _fingers.has(sd.index):
			if _fingers[sd.index] == "move" and sd.index == _stick_finger:
				_steer(sd.position)
			get_viewport().set_input_as_handled()
		elif sd.index == _pointer:
			_mouse_motion(sd.position, sd.relative, sd.velocity)


# The made-up mouse events go in at window coordinates, like real ones; the
# touches arrive here already in the game's own 1600x900-ish coordinates.

func _mouse_button(pos: Vector2, pressed: bool, double := false) -> void:
	_pointer_at = pos
	var mb := InputEventMouseButton.new()
	mb.device = InputEvent.DEVICE_ID_EMULATION
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = pressed
	mb.double_click = double
	mb.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	var at := get_viewport().get_final_transform() * pos
	mb.position = at
	mb.global_position = at
	Input.parse_input_event(mb)


func _mouse_motion(pos: Vector2, rel: Vector2, vel: Vector2) -> void:
	_pointer_at = pos
	var mm := InputEventMouseMotion.new()
	mm.device = InputEvent.DEVICE_ID_EMULATION
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	var xf := get_viewport().get_final_transform()
	var at := xf * pos
	mm.position = at
	mm.global_position = at
	mm.relative = xf.basis_xform(rel)
	mm.velocity = xf.basis_xform(vel)
	Input.parse_input_event(mm)


## Which control is under this point right now ("" for none).
func hit(pos: Vector2) -> String:
	var bubble: Variant = _ctx.get("bubble")
	if bubble is Rect2 and (bubble as Rect2).grow(10.0).has_point(pos):
		return ""   # the Talk bubble over someone's head: a tap there is a click
	for id in HIT_ORDER:
		if not _want.get(id, false):
			continue
		if id == "move":
			if _on_move(pos):
				return id
		elif pos.distance_to(center(id)) <= radius(id) * 1.15:
			return id
	return ""


## Any control, shown or not (the editor).
func hit_any(pos: Vector2) -> String:
	for id in HIT_ORDER:
		if id == "move" and move_mode() == Move.ARROWS:
			if arrows_rect().grow(16.0).has_point(pos):
				return id
		elif pos.distance_to(center(id)) <= radius(id) * 1.1 + 8.0:
			return id
	return ""


func _on_move(pos: Vector2) -> bool:
	var c := center("move")
	match move_mode():
		Move.FLOAT:
			# anywhere on the stick's own half of the screen, below the top bar
			var vp := view_size()
			return (pos.x < vp.x * 0.5) == (c.x < vp.x * 0.5) and pos.y > vp.y * 0.28
		Move.ARROWS:
			return arrows_rect().grow(20.0).has_point(pos)
	return pos.distance_to(c) <= radius("move") * 1.4


func _down(i: int, pos: Vector2) -> bool:
	var id := hit(pos)
	if id == "":
		return false
	_fingers[i] = id
	if id == "move":
		if _stick_finger != -1:
			_fingers[i] = ""   # a second thumb on the stick does nothing
			return true
		_stick_finger = i
		if move_mode() == Move.FLOAT:
			_stick_base = _clamp_base(pos)
		else:
			_stick_base = center("move")
		_steer(pos)
	else:
		_press(str(CONTROLS[id].action))
		Game.buzz(12, 0.35)
	return true


func _steer(pos: Vector2) -> void:
	var mode := move_mode()
	if mode == Move.ARROWS:
		var dx := pos.x - center("move").x
		var dead := 10.0 * size_of("move")
		_set_move(-1.0 if dx < -dead else (1.0 if dx > dead else 0.0))
		return
	var r := radius("move")
	var d := pos - _stick_base
	if mode == Move.FLOAT and d.length() > r:
		# the base trails a thumb that runs past the edge, so turning back is quick
		_stick_base = _clamp_base(_stick_base + d - d.limit_length(r))
		d = pos - _stick_base
	_knob = d.limit_length(r)
	var x := _knob.x / r
	# a small dead zone in the middle, then full speed from about 80% out
	var k := clampf((absf(x) - 0.18) / 0.6, 0.0, 1.0)
	_set_move(signf(x) * k)


func _clamp_base(p: Vector2) -> Vector2:
	var r := radius("move")
	var vp := view_size()
	return Vector2(clampf(p.x, r + 8.0, maxf(r + 8.0, vp.x - r - 8.0)), clampf(p.y, r + 8.0, maxf(r + 8.0, vp.y - r - 8.0)))


func _set_move(v: float) -> void:
	if is_equal_approx(v, _move):
		return
	_move = v
	if v < 0.0:
		Input.action_press("move_left", -v)
	else:
		Input.action_release("move_left")
	if v > 0.0:
		Input.action_press("move_right", v)
	else:
		Input.action_release("move_right")


func _press(action: String) -> void:
	_held[action] = int(_held.get(action, 0)) + 1
	if _held[action] == 1:
		_send(action, true)


func _release(action: String) -> void:
	if not _held.has(action):
		return
	_held[action] = int(_held[action]) - 1
	if _held[action] <= 0:
		_held.erase(action)
		_send(action, false)


func _send(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


## Presses an action for a moment (the Talk bubble over someone's head).
func tap(action: String) -> void:
	_send(action, true)
	get_tree().create_timer(0.06, true, false, true).timeout.connect(_send.bind(action, false))


func _release_finger(i: int) -> void:
	var id: String = _fingers.get(i, "")
	if id == "move":
		if i == _stick_finger:
			_stick_finger = -1
			_knob = Vector2.ZERO
			_set_move(0.0)
	elif id != "":
		_release(str(CONTROLS[id].action))


## A control went away under a finger: let go of what it held. The finger
## stays down, but does nothing more.
func _let_go(id: String) -> void:
	for i in _fingers.keys():
		if _fingers[i] == id:
			_release_finger(i)
			_fingers[i] = ""


func release_all() -> void:
	for i in _fingers.keys():
		_release_finger(i)
	_fingers.clear()
	for action in _held.keys():
		_send(action, false)
	_held.clear()
	_stick_finger = -1
	_knob = Vector2.ZERO
	_set_move(0.0)
	if _pointer != -1:
		_pointer = -1
		_mouse_button(_pointer_at, false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		release_all()   # fingers lifted while we were away never say so


# --- layout ---------------------------------------------------------------------

func view_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _layout() -> Dictionary:
	var all: Variant = Game.settings.get("touch_layout", {})
	return all if all is Dictionary else {}


func _lay(id: String) -> Dictionary:
	var l: Variant = _layout().get(id)
	if l is Dictionary and (l as Dictionary).has_all(["x", "y", "r", "b", "s"]):
		return l
	return DEFAULTS[id]


func size_of(id: String) -> float:
	return clampf(float(_lay(id).s), MIN_SIZE, MAX_SIZE)


func radius(id: String) -> float:
	return float(CONTROLS[id].r) * size_of(id)


## Half the control's width and height.
func extent(id: String) -> Vector2:
	var r := radius(id)
	if id == "move" and move_mode() == Move.ARROWS:
		return Vector2(r * 1.4, r * 0.62)
	return Vector2(r, r)


func center(id: String) -> Vector2:
	var l := _lay(id)
	var vp := view_size()
	var x: float = (vp.x - float(l.x)) if bool(l.r) else float(l.x)
	var y: float = (vp.y - float(l.y)) if bool(l.b) else float(l.y)
	return _on_screen(id, Vector2(x, y))


func arrows_rect() -> Rect2:
	var e := extent("move")
	return Rect2(center("move") - e, e * 2.0)


func _on_screen(id: String, p: Vector2) -> Vector2:
	var vp := view_size()
	var e := extent(id) + Vector2(6.0, 6.0)
	return Vector2(clampf(p.x, e.x, maxf(e.x, vp.x - e.x)), clampf(p.y, e.y, maxf(e.y, vp.y - e.y)))


## The editor moves (and resizes) a control.
func place(id: String, pos: Vector2, new_size := -1.0) -> void:
	var s := size_of(id) if new_size < 0.0 else clampf(new_size, MIN_SIZE, MAX_SIZE)
	var all := _layout().duplicate(true)
	all[id] = {"x": pos.x, "y": pos.y, "r": false, "b": false, "s": s}
	Game.settings["touch_layout"] = all
	pos = _on_screen(id, pos)
	var vp := view_size()
	var r := pos.x > vp.x * 0.5
	var b := pos.y > vp.y * 0.5
	all[id] = {"x": (vp.x - pos.x) if r else pos.x, "y": (vp.y - pos.y) if b else pos.y, "r": r, "b": b, "s": s}


func resize(id: String, s: float) -> void:
	place(id, center(id), s)


func reset_layout() -> void:
	Game.settings["touch_layout"] = {}


# --- the editor -------------------------------------------------------------------

## Opens the customize screen over whatever is showing. Awaitable.
func edit() -> void:
	if _editor != null:
		return
	release_all()
	_editor = TouchEditor.new()
	_editor.touch = self
	_edit_layer.add_child(_editor)
	await _editor.done
	_editor.queue_free()
	_editor = null
	Game.save_settings()


## The back button: closes the editor if it's open.
func back() -> bool:
	if _editor != null:
		_editor.finish()
		return true
	return false


# --- drawing ----------------------------------------------------------------------

## Draws the controls onto `ci`: the ones in play, or every one of them in
## the editor, with `sel` picked out.
func draw_controls(ci: CanvasItem, edit_mode: bool, sel: String) -> void:
	var op := clampf(float(Game.settings.get("touch_opacity", DEFAULT_OPACITY)), 0.15, 1.0)
	for id in DRAW_ORDER:
		var a: float = 1.0 if edit_mode else float(_alpha[id])
		if a <= 0.0:
			continue
		var k := op * a
		if id == "talk" and not edit_mode and not bool(_ctx.get("talk", false)):
			k *= 0.45   # nobody close enough to talk to
		match id:
			"move":
				_draw_move(ci, k, edit_mode)
			"pause":
				_draw_pause(ci, k)
			_:
				_draw_button(ci, id, k, edit_mode)
		if edit_mode:
			_draw_handle(ci, id, id == sel)


func _draw_button(ci: CanvasItem, id: String, k: float, edit_mode: bool) -> void:
	var c := center(id)
	var r := radius(id)
	var down := not edit_mode and _held.has(str(CONTROLS[id].action))
	if id == "talk" and not edit_mode and not down and bool(_ctx.get("talk", false)):
		# someone to talk to: rings breathe out from the button
		var p := fmod(_t * 1.2, 1.0)
		ci.draw_arc(c, r * (1.0 + 0.4 * p), 0.0, TAU, 56, Color(GOLD, k * (1.0 - p)), 4.0, true)
	ci.draw_circle(c, r, Color(GOLD, 0.92 * k) if down else Color(INK, 0.6 * k), true, -1.0, true)
	ci.draw_arc(c, r - 2.0, 0.0, TAU, 64, Color(GOLD, minf(1.0, 1.2 * k)), 4.0, true)
	var fg := Color(INK, minf(1.0, 1.3 * k)) if down else Color(CREAM, minf(1.0, 1.3 * k))
	var icon := c + Vector2(0, -r * 0.2)
	match id:
		"jump":
			var w := r * 0.3
			ci.draw_polyline(PackedVector2Array([icon + Vector2(-w, w * 0.45), icon + Vector2(0, -w * 0.45), icon + Vector2(w, w * 0.45)]), fg, r * 0.09, true)
		"talk":
			var bw := r * 0.36
			var bh := r * 0.24
			_pill.bg_color = Color(0, 0, 0, 0)
			_pill.set_border_width_all(int(maxf(2.0, r * 0.06)))
			_pill.border_color = fg
			_pill.set_corner_radius_all(int(bh))
			_pill.draw(ci.get_canvas_item(), Rect2(icon - Vector2(bw, bh), Vector2(bw, bh) * 2.0))
			ci.draw_colored_polygon(PackedVector2Array([icon + Vector2(-bw * 0.45, bh - 1.0), icon + Vector2(-bw * 0.75, bh + r * 0.17), icon + Vector2(-bw * 0.05, bh - 1.0)]), fg)
			for j in 3:
				ci.draw_circle(icon + Vector2((j - 1) * bw * 0.45, 0), r * 0.045, fg, true, -1.0, true)
		"call":
			# Dot herself: a glazed ring
			ci.draw_arc(icon, r * 0.2, 0.0, TAU, 32, Color(GLAZE, k) if not down else fg, r * 0.13, true)
	var label: String = CONTROLS[id].label
	var f := Kit.title_font()
	var fs := int(round(r * (0.3 if label.length() <= 4 else 0.25)))
	var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(f, c + Vector2(-tw * 0.5, r * 0.18 + fs * 0.72), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg)


func _draw_pause(ci: CanvasItem, k: float) -> void:
	var c := center("pause")
	var r := radius("pause")
	var down := _held.has("pause")
	ci.draw_circle(c, r, Color(GOLD, 0.9 * k) if down else Color(INK, 0.55 * k), true, -1.0, true)
	ci.draw_arc(c, r - 1.5, 0.0, TAU, 48, Color(GOLD, 0.95 * k), 3.0, true)
	var fg := Color(INK, k) if down else Color(CREAM, k)
	for side in [-1.0, 1.0]:
		ci.draw_rect(Rect2(c + Vector2(side * r * 0.22 - r * 0.1, -r * 0.34), Vector2(r * 0.2, r * 0.68)), fg)


func _draw_move(ci: CanvasItem, k: float, edit_mode: bool) -> void:
	if move_mode() == Move.ARROWS:
		_draw_arrows(ci, k)
		return
	var r := radius("move")
	var active := not edit_mode and _stick_finger != -1
	var base := _stick_base if active else center("move")
	if move_mode() == Move.FLOAT and not active:
		k *= 0.6   # it comes to your thumb, so it waits faintly
	ci.draw_circle(base, r, Color(INK, 0.42 * k), true, -1.0, true)
	ci.draw_arc(base, r - 2.0, 0.0, TAU, 72, Color(GOLD, 0.75 * k), 3.0, true)
	for side in [-1.0, 1.0]:
		var tip := base + Vector2(side * r * 0.8, 0)
		var w := r * 0.14
		var on: bool = (side < 0.0 and _move < -0.01) or (side > 0.0 and _move > 0.01)
		ci.draw_polyline(PackedVector2Array([tip + Vector2(-side * w, -w * 1.2), tip, tip + Vector2(-side * w, w * 1.2)]), Color(GOLD if on else CREAM, (0.95 if on else 0.6) * k), maxf(3.0, r * 0.045), true)
	var kr := r * 0.44
	var kp := base + (_knob if active else Vector2.ZERO)
	ci.draw_circle(kp, kr, Color(CREAM, minf(1.0, 1.25 * k)), true, -1.0, true)
	ci.draw_arc(kp, kr - 1.0, 0.0, TAU, 48, Color(INK, 0.55 * k), 3.0, true)


func _draw_arrows(ci: CanvasItem, k: float) -> void:
	var rect := arrows_rect()
	var gap := 6.0
	var halfw := (rect.size.x - gap) * 0.5
	for side in [-1, 1]:
		var on: bool = (side < 0 and _move < -0.01) or (side > 0 and _move > 0.01)
		var hr := Rect2(Vector2(rect.position.x if side < 0 else rect.position.x + halfw + gap, rect.position.y), Vector2(halfw, rect.size.y))
		_pill.bg_color = Color(GOLD, 0.9 * k) if on else Color(INK, 0.55 * k)
		_pill.set_border_width_all(4)
		_pill.border_color = Color(GOLD, 0.95 * k)
		_pill.set_corner_radius_all(int(rect.size.y * 0.32))
		_pill.draw(ci.get_canvas_item(), hr)
		var c := hr.get_center()
		var w := rect.size.y * 0.22
		var fg := Color(INK, k) if on else Color(CREAM, k)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(side * w, 0), c + Vector2(-side * w * 0.7, -w), c + Vector2(-side * w * 0.7, w)]), fg)


## The editor's outline round a control, and its name underneath.
func _draw_handle(ci: CanvasItem, id: String, picked: bool) -> void:
	var c := center(id)
	var e := extent(id) + Vector2(12.0, 12.0)
	var col := Color(1.0, 0.85, 0.35) if picked else Color(1, 1, 1, 0.55)
	var w := 4.0 if picked else 2.5
	if id == "move" and move_mode() == Move.ARROWS:
		var rr := Rect2(c - e, e * 2.0)
		ci.draw_rect(rr, col, false, w)
	else:
		var n := 28
		for j in n:
			if j % 2 == 0:
				ci.draw_arc(c, e.x, TAU * j / n, TAU * (j + 1) / n, 4, col, w, true)
	var title: String = CONTROLS[id].name
	if id == "move" and move_mode() == Move.FLOAT:
		title = "Move (comes to your thumb)"
	var f := Kit.body_font(800)
	var fs := 20
	var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var y := c.y + e.y + 24.0
	if y > view_size().y - 6.0:
		y = c.y - e.y - 10.0   # no room underneath: put it on top
	var x := clampf(c.x - tw * 0.5, 6.0, maxf(6.0, view_size().x - tw - 6.0))
	ci.draw_string_outline(f, Vector2(x, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0.03, 0.03, 0.05, 0.9))
	ci.draw_string(f, Vector2(x, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
