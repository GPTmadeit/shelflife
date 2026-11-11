extends CanvasLayer
## Pause menu: resume, restart from the last checkpoint, settings, quit.

const Kit = preload("res://scripts/ui/ui_kit.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")

var level: Node
var _root: Control
var _menu: PanelContainer
var _first: Button
var _scraps: Label
var _settings: Control
var is_open := false


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	_menu = PanelContainer.new()
	_menu.add_theme_stylebox_override("panel", Kit.panel(Color(0.06, 0.06, 0.08, 0.96), 22, 3, Color(1, 0.8, 0.3), 44))
	_menu.custom_minimum_size = Vector2(560, 0)
	center.add_child(_menu)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_menu.add_child(v)
	var head := Kit.label("PAUSED", 56, Color(1, 0.85, 0.4), Kit.title_font())
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	_scraps = Kit.label("", 22, Color(0.8, 0.78, 0.72), Kit.body_font(700))
	_scraps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_scraps)
	_first = _btn(v, "Resume", close)
	_btn(v, "Restart from checkpoint", func():
		close()
		if level != null:
			level.restart_checkpoint())
	_btn(v, "Settings", _open_settings)
	_btn(v, "Quit to title", func():
		close()
		Sfx.stop_all_ambience(0.3)
		Sfx.music_stop(0.3)
		Game.go_title())
	var controls := Kit.label("Move  A/D or ←/→   ·   Jump  Space   ·   Talk  E   ·   Pause  Esc", 18, Color(0.65, 0.63, 0.6), Kit.body_font(600))
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(controls)
	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(func():
		_settings.visible = false
		_menu.visible = true
		_first.grab_focus())
	center.add_child(_settings)
	_root.visible = false


func _btn(v: VBoxContainer, text: String, fn: Callable) -> Button:
	var b := Kit.button(text, 32)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.pressed.connect(func():
		Sfx.play("ui_ok", -8.0)
		fn.call())
	v.add_child(b)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if is_open:
			if _settings.visible:
				_settings.visible = false
				_menu.visible = true
				_first.grab_focus()
			else:
				close()
		else:
			open()


func open() -> void:
	is_open = true
	_root.visible = true
	_menu.visible = true
	_settings.visible = false
	_scraps.text = "Planogram scraps found: %d / 6" % Game.scraps.size()
	get_tree().paused = true
	_first.grab_focus()


func close() -> void:
	is_open = false
	_root.visible = false
	get_tree().paused = false


func _open_settings() -> void:
	_menu.visible = false
	_settings.visible = true
	_settings.focus_first()
