extends CanvasLayer
## Pause menu: resume, restart from the last checkpoint, settings, quit.

const Kit = preload("res://scripts/ui/ui_kit.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")
const Scraps = preload("res://scripts/world/scraps.gd")

var level: Node
var _root: Control
var _menu: PanelContainer
var _first: Button
var _scraps: Label
var _settings: Control
var _journal: PanelContainer
var _journal_text: RichTextLabel
var _journal_back: Button
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
	_btn(v, "Read the Planogram scraps", _open_journal)
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
	_build_journal(center)
	_root.visible = false


## Every scrap found so far, to read again.
func _build_journal(center: CenterContainer) -> void:
	_journal = PanelContainer.new()
	_journal.add_theme_stylebox_override("panel", Kit.panel(Color(0.96, 0.93, 0.82, 0.98), 14, 0, Color.WHITE, 40))
	_journal.custom_minimum_size = Vector2(900, 0)
	_journal.visible = false
	center.add_child(_journal)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_journal.add_child(v)
	var head := Kit.label("THE HOLY PLANOGRAM (what's left of it)", 40, Color(0.35, 0.12, 0.08), Kit.title_font())
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	_journal_text = RichTextLabel.new()
	_journal_text.bbcode_enabled = true
	_journal_text.custom_minimum_size = Vector2(820, 520)
	_journal_text.add_theme_font_override("normal_font", Kit.italic_font(600))
	_journal_text.add_theme_font_override("bold_font", Kit.body_font(900))
	_journal_text.add_theme_font_size_override("normal_font_size", 24)
	_journal_text.add_theme_font_size_override("bold_font_size", 22)
	_journal_text.add_theme_color_override("default_color", Color(0.2, 0.15, 0.12))
	v.add_child(_journal_text)
	_journal_back = Kit.button("Back", 30, Color(0.55, 0.2, 0.12))
	_journal_back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_journal_back.add_theme_color_override("font_color", Color(0.3, 0.2, 0.15))
	for c in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		_journal_back.add_theme_color_override(c, Color(0.99, 0.96, 0.88))
	_journal_back.pressed.connect(func():
		Sfx.play("ui_ok", -8.0)
		_close_journal())
	v.add_child(_journal_back)


func _open_journal() -> void:
	var t := ""
	var act := 0
	for id in Scraps.ALL.keys():
		var s: Array = Scraps.ALL[id]
		if s[0] != act:
			act = s[0]
			t += "%s[center][b][color=#8a4a2a]%s[/color][/b][/center]\n" % ["" if t == "" else "\n", Game.ACTS[act].to_upper()]
		if Game.scraps.has(id):
			t += "[b]%s[/b]\n%s\n\n" % [s[2], s[3]]
		else:
			t += "[color=#a09880][b]? ? ?[/b]\nNot found yet.[/color]\n\n"
	_journal_text.text = t
	_journal_text.scroll_to_line(0)
	_menu.visible = false
	_journal.visible = true
	_journal_back.grab_focus()


func _close_journal() -> void:
	_journal.visible = false
	_menu.visible = true
	_first.grab_focus()


func _process(dt: float) -> void:
	if is_open and _journal.visible:
		var bar := _journal_text.get_v_scroll_bar()
		bar.value += Input.get_axis("ui_up", "ui_down") * 700.0 * dt


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
			if _journal.visible:
				_close_journal()
			elif _settings.visible:
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
	_journal.visible = false
	_scraps.text = "Planogram scraps found: %d / %d" % [Game.scraps.size(), Scraps.ALL.size()]
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
