extends Control
## Settings → Touch controls → Customize. Drag the controls where your
## thumbs want them, tap one to pick it and set its size, and choose how see-
## through they are, how you move and whether they buzz. The panel keeps out
## of the way of whatever you put where it was.

const Kit = preload("res://scripts/ui/ui_kit.gd")

signal done

var touch                      ## the Touch autoload (untyped: it preloads this script)
var _sel := "jump"
var _drag := ""
var _grab := Vector2.ZERO
var _panel: PanelContainer
var _which: Label
var _size: HSlider
var _move: OptionButton
var _syncing := false


func _ready() -> void:
	# (already in the tree here, so the offsets have to be set too, or it keeps its size of nothing)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", Kit.panel(Color(0.06, 0.06, 0.08, 0.95), 20, 3, Color(1, 0.8, 0.3), 30))
	_panel.custom_minimum_size = Vector2(760, 0)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	var head := Kit.label("TOUCH CONTROLS", 38, Color(1, 0.85, 0.4), Kit.title_font())
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var tip := Kit.label("Drag a control to move it. Tap one to pick it, then set its size.", 21, Color(0.85, 0.83, 0.78), Kit.body_font(700))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tip)
	var row := _row(v, "")
	_which = row.get_child(0) as Label
	_size = _slider(row, touch.MIN_SIZE, touch.MAX_SIZE, 1.0, func(x: float):
		if not _syncing:
			touch.resize(_sel, x)
			queue_redraw())
	row = _row(v, "Opacity")
	_slider(row, 0.15, 1.0, float(Game.settings.get("touch_opacity", touch.DEFAULT_OPACITY)), func(x: float):
		Game.settings["touch_opacity"] = x
		queue_redraw())
	row = _row(v, "Move with")
	_move = OptionButton.new()
	for n in touch.MOVE_NAMES:
		_move.add_item(n)
	_move.selected = touch.move_mode()
	_move.focus_mode = Control.FOCUS_ALL
	_move.add_theme_font_override("font", Kit.body_font(700))
	_move.add_theme_font_size_override("font_size", 24)
	_move.item_selected.connect(func(i: int):
		Game.settings["touch_move"] = i
		Sfx.play("ui_move", -8.0)
		_place_panel.call_deferred()
		queue_redraw())
	row.add_child(_move)
	row = _row(v, "Vibrate")
	var buzz := CheckButton.new()
	buzz.button_pressed = bool(Game.settings.get("touch_vibrate", true))
	buzz.focus_mode = Control.FOCUS_ALL
	buzz.toggled.connect(func(on: bool):
		Game.settings["touch_vibrate"] = on
		if on:
			Game.buzz(30, 0.6)
		Sfx.play("ui_move", -8.0))
	row.add_child(buzz)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 16)
	v.add_child(foot)
	var reset := Kit.button("Put them back", 28)
	reset.alignment = HORIZONTAL_ALIGNMENT_CENTER
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(func():
		touch.reset_layout()
		Sfx.play("ui_ok", -8.0)
		_sync()
		_place_panel.call_deferred()
		queue_redraw())
	foot.add_child(reset)
	var ok := Kit.button("Done", 28)
	ok.alignment = HORIZONTAL_ALIGNMENT_CENTER
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(finish)
	foot.add_child(ok)
	_sync()
	_place_panel.call_deferred()
	_size.grab_focus.call_deferred()


func finish() -> void:
	Sfx.play("ui_ok", -8.0)
	done.emit()


func _row(v: VBoxContainer, text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	var l := Kit.label(text, 26, Color(0.95, 0.93, 0.88), Kit.body_font(700))
	l.custom_minimum_size.x = 250
	h.add_child(l)
	v.add_child(h)
	return h


func _slider(h: HBoxContainer, lo: float, hi: float, val: float, fn: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = val
	s.custom_minimum_size = Vector2(420, 40)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_ALL
	s.value_changed.connect(fn)
	h.add_child(s)
	return s


## The panel's size row follows the picked control.
func _sync() -> void:
	_syncing = true
	_which.text = "Size: " + str(touch.CONTROLS[_sel].name).get_slice(" ", 0)
	_size.value = touch.size_of(_sel)
	_move.selected = touch.move_mode()
	_syncing = false


## Middle of the screen if that's clear, else the top, else the bottom.
func _place_panel() -> void:
	var vp: Vector2 = touch.view_size()
	var ps := _panel.get_combined_minimum_size()
	_panel.size = ps
	var x := (vp.x - ps.x) * 0.5
	var best := Vector2(x, (vp.y - ps.y) * 0.5)
	for y in [(vp.y - ps.y) * 0.5, 16.0, vp.y - ps.y - 16.0]:
		var r := Rect2(Vector2(x, y), ps)
		var clear := true
		for id in touch.CONTROLS:
			var e: Vector2 = touch.extent(id)
			if r.intersects(Rect2(touch.center(id) - e, e * 2.0)):
				clear = false
				break
		if clear:
			best = Vector2(x, y)
			break
	_panel.position = best


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		finish()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var id: String = touch.hit_any(event.position)
			if id != "":
				_sel = id
				_drag = id
				_grab = touch.center(id) - event.position
				_panel.modulate.a = 0.3   # see what's under it while you drag
				_sync()
				Sfx.play("ui_move", -10.0)
		elif _drag != "":
			_drag = ""
			_panel.modulate.a = 1.0
			_place_panel()
		accept_event()
		queue_redraw()
	elif event is InputEventMouseMotion and _drag != "":
		touch.place(_drag, event.position + _grab)
		accept_event()
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.03, 0.35))
	touch.draw_controls(self, true, _sel)
