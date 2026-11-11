extends CanvasLayer
## In-game overlay: objective, shell meter, interaction prompt, toasts, title
## cards, fades, letterbox bars, death cards and Planogram scrap pop-ups.

const Kit = preload("res://scripts/ui/ui_kit.gd")

signal dismissed

var _root: Control
var _obj: PanelContainer
var _obj_text: Label
var _shell: Control
var _cracks := 0
var _shell_flash := 0.0
var _prompt: PanelContainer
var _prompt_label: Label
var _toast: Label
var _fade: ColorRect
var _bars: Array[ColorRect] = []
var _card: VBoxContainer
var _card_big: Label
var _card_small: Label
var _scrap: PanelContainer
var _scrap_title: Label
var _scrap_text: Label
var _scrap_open := false
var _t := 0.0


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	# letterbox bars
	for i in 2:
		var b := ColorRect.new()
		b.color = Color(0, 0, 0)
		b.anchor_right = 1.0
		if i == 0:
			b.offset_bottom = 0
		else:
			b.anchor_top = 1.0
			b.anchor_bottom = 1.0
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(b)
		_bars.append(b)
	# objective
	_obj = PanelContainer.new()
	var os := Kit.panel(Color(0.05, 0.05, 0.07, 0.78), 14, 0, Color.WHITE, 20)
	_obj.add_theme_stylebox_override("panel", os)
	_obj.offset_left = 28
	_obj.offset_top = 26
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 0)
	_obj.add_child(ov)
	ov.add_child(Kit.label("OBJECTIVE", 18, Color(1.0, 0.8, 0.3), Kit.title_font()))
	_obj_text = Kit.label("", 24, Color(0.96, 0.94, 0.9), Kit.body_font(700))
	_obj_text.custom_minimum_size.x = 260
	_obj_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_obj_text.size.x = 460
	ov.add_child(_obj_text)
	_obj.visible = false
	_root.add_child(_obj)
	# shell meter
	_shell = Control.new()
	_shell.anchor_left = 1.0
	_shell.anchor_right = 1.0
	_shell.offset_left = -190
	_shell.offset_top = 24
	_shell.offset_right = -24
	_shell.offset_bottom = 120
	_shell.draw.connect(_draw_shell)
	_root.add_child(_shell)
	# prompt
	_prompt = PanelContainer.new()
	_prompt.add_theme_stylebox_override("panel", Kit.panel(Color(0.05, 0.05, 0.07, 0.85), 12, 2, Color(1, 0.8, 0.3), 14))
	_prompt_label = Kit.label("", 24, Color(1, 0.97, 0.9), Kit.body_font(800))
	_prompt.add_child(_prompt_label)
	_prompt.visible = false
	_root.add_child(_prompt)
	# toast
	_toast = Kit.label("", 24, Color(1, 0.95, 0.8), Kit.body_font(800), 6)
	_toast.anchor_left = 1.0
	_toast.anchor_right = 1.0
	_toast.anchor_top = 1.0
	_toast.anchor_bottom = 1.0
	_toast.offset_left = -420
	_toast.offset_right = -30
	_toast.offset_top = -64
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_toast.modulate.a = 0.0
	_root.add_child(_toast)
	# title / death card
	_card = VBoxContainer.new()
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.anchor_left = 0.0
	_card.anchor_right = 1.0
	_card.anchor_top = 0.5
	_card.anchor_bottom = 0.5
	_card.offset_top = -120
	_card.offset_bottom = 120
	_card_big = Kit.label("", 120, Color(1, 0.95, 0.85), Kit.title_font(), 22)
	_card_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_small = Kit.label("", 38, Color(1, 0.85, 0.45), Kit.body_font(800), 10)
	_card_small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(_card_big)
	_card.add_child(_card_small)
	_card.modulate.a = 0.0
	_root.add_child(_card)
	# scrap popup
	_scrap = PanelContainer.new()
	var ss := Kit.panel(Color(0.96, 0.93, 0.84), 6, 0, Color.WHITE, 40)
	ss.content_margin_top = 30
	ss.content_margin_bottom = 30
	_scrap.add_theme_stylebox_override("panel", ss)
	_scrap.anchor_left = 0.5
	_scrap.anchor_right = 0.5
	_scrap.anchor_top = 0.5
	_scrap.anchor_bottom = 0.5
	_scrap.offset_left = -430
	_scrap.offset_right = 430
	_scrap.offset_top = -170
	_scrap.offset_bottom = 170
	_scrap.rotation = -0.02
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 14)
	_scrap.add_child(sv)
	_scrap_title = Kit.label("", 30, Color(0.55, 0.12, 0.1), Kit.title_font())
	_scrap_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(_scrap_title)
	_scrap_text = Kit.label("", 30, Color(0.15, 0.12, 0.1), Kit.italic_font(700))
	_scrap_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scrap_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(_scrap_text)
	var hint := Kit.label("", 20, Color(0.45, 0.4, 0.35), Kit.body_font(700))
	hint.name = "Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(hint)
	_scrap.visible = false
	_root.add_child(_scrap)
	# fade on top of everything
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)


func _process(dt: float) -> void:
	_t += dt
	if _shell_flash > 0.0:
		_shell_flash -= dt
		_shell.queue_redraw()


func _input(event: InputEvent) -> void:
	if _scrap_open and (event.is_action_pressed("advance") or event.is_action_pressed("interact") or (event is InputEventMouseButton and event.pressed)):
		get_viewport().set_input_as_handled()
		_scrap_open = false
		dismissed.emit()


# --- objective / shell / prompt / toast -------------------------------------------

func objective(text: String) -> void:
	var changed := _obj_text.text != text
	_obj_text.text = text
	_obj.visible = text != ""
	_obj.size = Vector2.ZERO
	if changed and text != "":
		Sfx.play("objective", -6.0)
		_obj.modulate = Color(1.6, 1.4, 0.9, 0.0)
		_obj.position.x = -40
		var tw := create_tween()
		tw.tween_property(_obj, "modulate", Color(1, 1, 1, 1), 0.5)
		tw.parallel().tween_property(_obj, "position:x", 28.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func shell(cracks: int) -> void:
	if cracks > _cracks:
		_shell_flash = 0.6
	_cracks = cracks
	_shell.queue_redraw()


func show_hud(on: bool) -> void:
	_shell.visible = on
	_obj.visible = on and _obj_text.text != ""


func _draw_shell() -> void:
	var c := Vector2(132, 46)
	var shake := Vector2.ZERO
	if _shell_flash > 0.0:
		shake = Vector2(sin(_t * 70.0), cos(_t * 53.0)) * 4.0 * _shell_flash
	c += shake
	var pts := PackedVector2Array()
	for i in 40:
		var th := TAU * i / 40.0
		var y := -cos(th)
		var r := sin(th) * (1.0 - 0.13 * y)
		pts.append(c + Vector2(r * 26.0, -y * 34.0))
	var fill := Color(0.98, 0.94, 0.85)
	if _shell_flash > 0.0:
		fill = fill.lerp(Color(1, 0.4, 0.3), _shell_flash)
	_shell.draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	_shell.draw_polyline(pts, Color(0.15, 0.1, 0.08), 3.0, true)
	var lines := [
		[Vector2(-8, -30), Vector2(-2, -18), Vector2(-10, -8), Vector2(-4, 4)],
		[Vector2(14, -14), Vector2(6, -2), Vector2(14, 8), Vector2(8, 20)],
		[Vector2(-18, 8), Vector2(-6, 14), Vector2(-12, 26), Vector2(2, 30)],
	]
	for k in mini(_cracks, 3):
		var pl := PackedVector2Array()
		for p in lines[k]:
			pl.append(c + p)
		_shell.draw_polyline(pl, Color(0.25, 0.12, 0.08), 3.0, true)
	var f := Kit.title_font()
	_shell.draw_string(f, Vector2(4, 56), "SHELL", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.85, 0.4))
	var status: String = ["SOLID", "CRACKED", "VERY CRACKED", "SCRAMBLED"][mini(_cracks, 3)]
	_shell.draw_string(Kit.body_font(800), Vector2(4, 80), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.95, 0.93, 0.88))


func prompt(text: String, screen_pos: Vector2) -> void:
	_prompt_label.text = text
	_prompt.visible = true
	_prompt.size = Vector2.ZERO
	_prompt.position = screen_pos - Vector2(_prompt.size.x * 0.5, _prompt.size.y)


func prompt_hide() -> void:
	_prompt.visible = false


func toast(text: String) -> void:
	_toast.text = text
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)


# --- cinematic bits ------------------------------------------------------------------

func letterbox(on: bool) -> void:
	var h := 86.0 if on else 0.0
	var tw := create_tween()
	tw.tween_property(_bars[0], "offset_bottom", h, 0.6).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(_bars[1], "offset_top", -h, 0.6).set_trans(Tween.TRANS_CUBIC)
	show_hud(not on)


func fade(out: bool, t := 0.8) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0 if out else 0.0, t)
	await tw.finished


func set_black(on: bool) -> void:
	_fade.color.a = 1.0 if on else 0.0


## Big title card. Awaitable.
func title_card(big: String, small := "", hold := 2.6) -> void:
	_card_big.text = big
	_card_small.text = small
	_card_big.add_theme_font_size_override("font_size", 140 if big.length() < 14 else 92)
	_card.modulate.a = 0.0
	_card.scale = Vector2.ONE
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.6)
	tw.tween_interval(hold)
	tw.tween_property(_card, "modulate:a", 0.0, 0.8)
	await tw.finished


## Death card ("SCRAMBLED." / a quip). Awaitable.
func death_card(big: String, small: String) -> void:
	_card_big.text = big
	_card_small.text = small
	_card_big.add_theme_font_size_override("font_size", 130)
	_card.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.3)
	tw.tween_interval(1.8)
	await tw.finished


func hide_card() -> void:
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 0.0, 0.4)


## A scrap of the Planogram: a verse on torn paper. Awaitable.
func scrap(title: String, verse: String, count_text: String) -> void:
	_scrap_title.text = title
	_scrap_text.text = verse
	(_scrap.get_node("VBoxContainer/Hint") if _scrap.has_node("VBoxContainer/Hint") else _scrap.get_child(0).get_child(2)).text = count_text + "   ·   press %s" % Game.glyph("advance")
	_scrap.visible = true
	_scrap.scale = Vector2(0.8, 0.8)
	_scrap.pivot_offset = _scrap.size * 0.5
	var tw := create_tween()
	tw.tween_property(_scrap, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.3).timeout
	_scrap_open = true
	if Game.dev.has("auto"):
		get_tree().create_timer(1.2).timeout.connect(func():
			if _scrap_open:
				_scrap_open = false
				dismissed.emit())
	await dismissed
	_scrap.visible = false
