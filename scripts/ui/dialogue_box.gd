extends CanvasLayer
## The conversation box: name tag, typewriter text with voice blips, choice
## menus, and the PA banner for announcements from The Voice.

const Kit = preload("res://scripts/ui/ui_kit.gd")
const Cast = preload("res://scripts/dialogue/cast.gd")

signal advanced
signal picked

var _root: Control
var _panel: PanelContainer
var _style: StyleBoxFlat
var _tag: PanelContainer
var _tag_style: StyleBoxFlat
var _tag_label: Label
var _text: RichTextLabel
var _arrow: Label
var _choices: VBoxContainer
var _pa: PanelContainer
var _pa_text: RichTextLabel
var _pa_head: Label
var _pa_name := ""
var _typing := false
var _skip := false
var _waiting := false
var _choosing := false
var _pick := 0
var _t := 0.0
var _held := false        ## the advance button went down on a line and is still down
var _hold_t := 0.0
var _ff_t := 0.0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	# main panel
	_panel = PanelContainer.new()
	_style = Kit.panel(Color(0.055, 0.05, 0.07, 0.94), 24, 4, Color(1, 0.8, 0.3), 36)
	_style.content_margin_top = 30
	_style.content_margin_bottom = 26
	_panel.add_theme_stylebox_override("panel", _style)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -600
	_panel.offset_right = 600
	_panel.offset_top = -250
	_panel.offset_bottom = -30
	_root.add_child(_panel)
	var v := VBoxContainer.new()
	_panel.add_child(v)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = false
	_text.scroll_active = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_override("normal_font", Kit.body_font(700))
	_text.add_theme_font_override("italics_font", Kit.italic_font(700))
	_text.add_theme_font_override("bold_font", Kit.body_font(900))
	_text.add_theme_font_size_override("normal_font_size", 33)
	_text.add_theme_font_size_override("italics_font_size", 33)
	_text.add_theme_font_size_override("bold_font_size", 33)
	_text.add_theme_color_override("default_color", Color(0.97, 0.95, 0.9))
	_text.add_theme_constant_override("line_separation", 4)
	v.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 6)
	_choices.visible = false
	v.add_child(_choices)
	_arrow = Kit.label("▼", 26, Color(1, 0.85, 0.35), Kit.body_font(900))
	_arrow.anchor_left = 0.5
	_arrow.anchor_right = 0.5
	_arrow.anchor_top = 1.0
	_arrow.anchor_bottom = 1.0
	_arrow.offset_left = 548
	_arrow.offset_top = -82
	_arrow.visible = false
	_root.add_child(_arrow)
	# name tag (sits on the panel's top edge)
	_tag = PanelContainer.new()
	_tag_style = Kit.panel(Color(1, 0.8, 0.3), 12, 0, Color.WHITE, 18)
	_tag_style.content_margin_top = 4
	_tag_style.content_margin_bottom = 2
	_tag.add_theme_stylebox_override("panel", _tag_style)
	_tag_label = Kit.label("BAKER", 30, Color(0.08, 0.06, 0.06), Kit.title_font())
	_tag.add_child(_tag_label)
	_tag.anchor_left = 0.5
	_tag.anchor_right = 0.5
	_tag.anchor_top = 1.0
	_tag.anchor_bottom = 1.0
	_tag.offset_left = -570
	_tag.offset_right = -570
	_tag.offset_top = -274
	_tag.offset_bottom = -274
	_tag.grow_horizontal = Control.GROW_DIRECTION_END
	_tag.grow_vertical = Control.GROW_DIRECTION_END
	_root.add_child(_tag)
	# PA banner
	_pa = PanelContainer.new()
	var ps := Kit.panel(Color(0.12, 0.1, 0.05, 0.93), 18, 3, Color(1.0, 0.86, 0.4), 30)
	_pa.add_theme_stylebox_override("panel", ps)
	_pa.anchor_left = 0.5
	_pa.anchor_right = 0.5
	_pa.offset_left = -560
	_pa.offset_right = 560
	_pa.offset_top = 36
	_pa.offset_bottom = 190
	_root.add_child(_pa)
	var pv := VBoxContainer.new()
	_pa.add_child(pv)
	_pa_head = Kit.label("THE VOICE", 24, Color(1.0, 0.86, 0.4), Kit.title_font())
	_pa_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(_pa_head)
	_pa_text = RichTextLabel.new()
	_pa_text.bbcode_enabled = true
	_pa_text.fit_content = true
	_pa_text.scroll_active = false
	_pa_text.add_theme_font_override("normal_font", Kit.italic_font(700))
	_pa_text.add_theme_font_size_override("normal_font_size", 31)
	_pa_text.add_theme_color_override("default_color", Color(1.0, 0.95, 0.82))
	pv.add_child(_pa_text)
	close()


func close() -> void:
	_panel.visible = false
	_tag.visible = false
	_pa.visible = false
	_choices.visible = false
	_arrow.visible = false


func is_open() -> bool:
	return _panel.visible or _pa.visible


func _process(dt: float) -> void:
	_t += dt
	if _arrow.visible:
		_arrow.offset_top = -82 + sin(_t * 6.0) * 4.0
	# Keep the button held to fast-forward: lines fill in at once and move on.
	# (Only a press that started on a line counts, so a held jump can't do it.)
	if _held and Input.is_action_pressed("advance") and not _choosing:
		_hold_t += dt
		if _hold_t > 0.45:
			_ff_t -= dt
			if _typing:
				_skip = true
			elif _waiting and _ff_t <= 0.0:
				_ff_t = 0.11
				_waiting = false
				advanced.emit()
	else:
		_held = false
		_hold_t = 0.0
		_ff_t = 0.0


func _input(event: InputEvent) -> void:
	if _choosing:
		if event is InputEventKey and event.pressed and not event.echo:
			var k: int = event.physical_keycode - KEY_1
			if k >= 0 and k < _choices.get_child_count():
				get_viewport().set_input_as_handled()
				_choose(k)
		return
	if not (_typing or _waiting):
		return
	var press := event.is_action_pressed("advance") and not event.is_echo()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		press = true
	if not press:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("advance"):
		_held = true
		_hold_t = 0.0
	if _typing:
		_skip = true
	elif _waiting:
		_waiting = false
		advanced.emit()


func _speaker_style(who: String) -> Dictionary:
	var info := Cast.info(who)
	var col: Color = info.get("tag", Color(0.9, 0.9, 0.9))
	_style.border_color = col
	_tag_style.bg_color = col
	_tag_label.text = info.get("name", who.to_upper())
	return info


## Shows a line and waits for the player. Awaitable.
func say(who: String, text: String, speaker: Node = null) -> void:
	var info := _speaker_style(who)
	_size_panel(220)
	_panel.visible = true
	_tag.visible = true
	_choices.visible = false
	_text.visible = true
	_text.text = text
	await _type(_text, info.get("voice", "one"), speaker)
	_arrow.visible = true
	_waiting = true
	_auto_advance()
	await advanced
	_arrow.visible = false


## An announcement over the store PA. Awaitable.
func pa(text: String, info: Dictionary) -> void:
	_panel.visible = false
	_tag.visible = false
	_pa_head.text = "♪  %s  ♪" % (_pa_name if _pa_name != "" else info.get("name", "THE VOICE"))
	_pa_text.text = "[center]%s[/center]" % text
	_pa_text.visible_characters = 0
	_pa.visible = true
	_pa.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_pa, "modulate:a", 1.0, 0.25)
	await _type(_pa_text, info.get("voice", "pa"), null)
	_waiting = true
	_auto_advance()
	await advanced
	var tw2 := create_tween()
	tw2.tween_property(_pa, "modulate:a", 0.0, 0.2)
	await tw2.finished
	_pa.visible = false


## A PA announcement that plays over gameplay without waiting for input.
func pa_auto(text: String, secs := 2.6) -> void:
	if is_open():
		return
	_pa_head.text = "♪  THE VOICE  ♪"
	_pa_text.text = "[center]%s[/center]" % text
	_pa_text.visible_characters = -1
	_pa.visible = true
	_pa.modulate.a = 0.0
	Sfx.play("chime", -6.0)
	var tw := create_tween()
	tw.tween_property(_pa, "modulate:a", 1.0, 0.25)
	tw.tween_interval(secs)
	tw.tween_property(_pa, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): _pa.visible = false)
	for k in 10:
		get_tree().create_timer(0.7 + k * 0.09).timeout.connect(Sfx.blip.bind("pa"))


func set_pa_name(n: String) -> void:
	_pa_name = "" if n == "THE VOICE" else n


func _type(rtl: RichTextLabel, voice: String, speaker: Node) -> void:
	rtl.visible_characters = 0
	var plain := rtl.get_parsed_text()
	var n := plain.length()
	var cps: float = 50.0 * float(Game.settings.get("text_speed", 1.0))
	var shown := 0.0
	var pause := 0.0
	var last := 0
	_typing = true
	_skip = false
	if cps > 400.0:
		_skip = true
	while last < n and not _skip:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		if pause > 0.0:
			pause -= dt
			continue
		shown += cps * dt
		var cur := mini(int(shown), n)
		var i := last
		var paused := false
		while i < cur:
			var ch := plain[i]
			if ch != " " and i % 2 == 0:
				Sfx.blip(voice)
				if speaker != null:
					speaker.talk_pulse()
			i += 1
			var nxt := plain[i] if i < n else " "
			if ch in ".!?" and nxt == " ":
				pause = 0.24
				paused = true
				break
			if ch in ",;:—" and nxt == " ":
				pause = 0.09
				paused = true
				break
		last = i
		if paused:
			shown = float(last)   # keep fractional progress unless we stopped for punctuation
		rtl.visible_characters = last
	rtl.visible_characters = -1
	_typing = false
	_skip = false


## Shows a menu of choices (Baker answering). Returns the index. Awaitable.
func choose(options: Array) -> int:
	_speaker_style("baker")
	_panel.visible = true
	_tag.visible = true
	_text.visible = false
	_arrow.visible = false
	_size_panel(maxi(220, 70 + options.size() * 62))
	for c in _choices.get_children():
		c.queue_free()
	for i in options.size():
		var b := Kit.button("%d   %s" % [i + 1, options[i]], 29, Cast.info("baker").tag)
		b.pressed.connect(_choose.bind(i))
		_choices.add_child(b)
	_choices.visible = true
	_choosing = true
	await get_tree().process_frame
	if _choices.get_child_count() > 0:
		(_choices.get_child(0) as Button).grab_focus()
	if Game.dev.has("auto"):
		get_tree().create_timer(0.9).timeout.connect(_choose.bind(0))
	await picked
	_choosing = false
	_choices.visible = false
	_text.visible = true
	return _pick


## Dev: `--auto` reads every line by itself (for automated play-throughs).
func _auto_advance() -> void:
	if not Game.dev.has("auto"):
		return
	await get_tree().create_timer(0.55).timeout
	if _waiting:
		_waiting = false
		advanced.emit()


func _size_panel(h: int) -> void:
	_panel.offset_top = -30 - h
	_tag.offset_top = _panel.offset_top - 24
	_tag.offset_bottom = _tag.offset_top


func _choose(i: int) -> void:
	if not _choosing:
		return
	_pick = i
	_choosing = false
	Sfx.play("ui_ok", -8.0)
	picked.emit()
