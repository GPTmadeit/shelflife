extends PanelContainer
## Volume sliders, display, touch and comfort options. Emits `closed` on
## Back, and `customize` when the touch controls should be laid out (the
## screen that owns this panel hides itself and calls Touch.edit()).

const Kit = preload("res://scripts/ui/ui_kit.gd")

signal closed
signal customize

var _first: Control


func _ready() -> void:
	add_theme_stylebox_override("panel", Kit.panel(Color(0.06, 0.06, 0.08, 0.96), 22, 3, Color(1, 0.8, 0.3), 40))
	custom_minimum_size = Vector2(760, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	var head := Kit.label("SETTINGS", 46, Color(1, 0.85, 0.4), Kit.title_font())
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	_first = _slider(v, "Master volume", "master", 0.0, 1.0)
	_slider(v, "Music", "music", 0.0, 1.0)
	_slider(v, "Sound effects", "sfx", 0.0, 1.0)
	_slider(v, "Voices", "voice", 0.0, 1.0)
	_slider(v, "Text speed", "text_speed", 0.5, 2.5)
	_quality(v)
	if not Game.mobile():
		_check(v, "Fullscreen", "fullscreen")
	_touch(v)
	_check(v, "Screen shake", "shake")
	_check(v, "Check for updates", "updates")
	var back := Kit.button("Back", 30)
	back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.pressed.connect(func():
		Game.save_settings()
		Sfx.play("ui_ok", -8.0)
		closed.emit())
	v.add_child(back)


func focus_first() -> void:
	if _first != null:
		_first.grab_focus()


func _row(v: VBoxContainer, text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	var l := Kit.label(text, 27, Color(0.95, 0.93, 0.88), Kit.body_font(700))
	l.custom_minimum_size.x = 280
	h.add_child(l)
	v.add_child(h)
	return h


func _slider(v: VBoxContainer, text: String, key: String, lo: float, hi: float) -> HSlider:
	var h := _row(v, text)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = float(Game.settings.get(key, 1.0))
	s.custom_minimum_size = Vector2(320, 36)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_ALL
	s.value_changed.connect(func(val: float):
		Game.settings[key] = val
		Game.apply_settings()
		if key == "sfx":
			Sfx.play("jump", -6.0))
	h.add_child(s)
	return s


func _quality(v: VBoxContainer) -> void:
	var h := _row(v, "Graphics")
	var o := OptionButton.new()
	o.add_item("Low (fast)", 0)
	o.add_item("Medium", 1)
	o.add_item("High", 2)
	o.selected = clampi(int(Game.settings.get("quality", 1)), 0, 2)
	o.focus_mode = Control.FOCUS_ALL
	o.add_theme_font_override("font", Kit.body_font(700))
	o.add_theme_font_size_override("font_size", 24)
	o.item_selected.connect(func(i: int):
		Game.settings["quality"] = i
		Game.apply_settings()
		Sfx.play("ui_move", -8.0))
	h.add_child(o)


## When the touch controls show, and the way in to moving them about.
func _touch(v: VBoxContainer) -> void:
	var h := _row(v, "Touch controls")
	var o := OptionButton.new()
	o.add_item("Auto", 0)
	o.add_item("On", 1)
	o.add_item("Off", 2)
	o.selected = clampi(int(Game.settings.get("touch", 0)), 0, 2)
	o.focus_mode = Control.FOCUS_ALL
	o.add_theme_font_override("font", Kit.body_font(700))
	o.add_theme_font_size_override("font_size", 24)
	o.item_selected.connect(func(i: int):
		Game.settings["touch"] = i
		Sfx.play("ui_move", -8.0))
	h.add_child(o)
	var b := Kit.button("Customize", 24)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.pressed.connect(func():
		Game.save_settings()
		Sfx.play("ui_ok", -8.0)
		customize.emit())
	h.add_child(b)


func _check(v: VBoxContainer, text: String, key: String) -> void:
	var h := _row(v, text)
	var c := CheckButton.new()
	c.button_pressed = bool(Game.settings.get(key, false))
	c.focus_mode = Control.FOCUS_ALL
	c.toggled.connect(func(on: bool):
		Game.settings[key] = on
		Game.apply_settings()
		Sfx.play("ui_move", -8.0))
	h.add_child(c)
