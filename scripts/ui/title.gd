extends Node3D
## Title screen: a quiet dairy shelf after closing, Baker wide awake, and the
## menu on a shelf price tag.

const Kit = preload("res://scripts/ui/ui_kit.gd")
const Cast = preload("res://scripts/dialogue/cast.gd")
const Store = preload("res://scripts/world/store.gd")
const Meshes = preload("res://scripts/gfx/meshes.gd")
const Mats = preload("res://scripts/gfx/mats.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")
const Version = preload("res://scripts/core/version.gd")

var cam: Camera3D
var baker: Node3D
var _t := 0.0
var _menu: VBoxContainer
var _settings: Control
var _ui: Control
var _first: Button
var _upd_btn: Button
var _upd_label: Label
var _upd_link: LinkButton


func _ready() -> void:
	_scene()
	_build_ui()
	Sfx.music("muzak", -16.0, 2.0)
	Sfx.ambience("hum_fridge", -20.0)


func _scene() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.025, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.48, 0.66)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.04, 0.05, 0.08)
	env.fog_density = 0.02
	we.environment = env
	add_child(we)
	var store: Store = Store.new(self)
	var deck := Mats.solid(Color(0.76, 0.79, 0.83), 0.35, 0.55)
	store.box(Vector3(0, 10.6, -3.1), Vector3(40, 21, 0.4), Mats.solid(Color(0.5, 0.56, 0.63), 0.5, 0.25))
	for y in [0.0, 4.8, 9.6]:
		store.box(Vector3(0, y - 0.15, -1.0), Vector3(40, 0.3, 3.8), deck)
		store.box(Vector3(0, y - 0.44, 0.95), Vector3(40, 0.48, 0.08), Mats.solid(Color(0.86, 0.87, 0.88), 0.5))
		store.box(Vector3(0, y - 0.7, 0.7), Vector3(40, 0.06, 0.14), Mats.glow(Color(0.82, 0.92, 1.0), 2.4))
	var yog := [Color(0.94, 0.42, 0.55), Color(0.36, 0.38, 0.76), Color(0.98, 0.6, 0.32), Color(0.55, 0.78, 0.35)]
	store.row("cup", -14, 14, 4.8, -2.0, 1.05, yog, [Color.WHITE])
	store.row("cup", -14, -4, 4.8, -0.9, 1.05, yog, [Color.WHITE])
	store.row("cup", 6, 14, 4.8, -0.9, 1.05, yog, [Color.WHITE])
	store.row("jug", -14, 14, 9.6, -2.0, 2.05, [Color(0.95, 0.95, 0.97)], [Color(0.85, 0.15, 0.15), Color(0.2, 0.42, 0.9)])
	store.row("eggbox", -14, -4, 0.0, -2.0, 3.8, [Color(0.93, 0.93, 0.9)], [Color(0.55, 0.7, 0.85)])
	store.row("eggbox", 4, 14, 0.0, -2.0, 3.8, [Color(0.93, 0.93, 0.9)], [Color(0.55, 0.7, 0.85)])
	store.flush()
	baker = Cast.make_rig("baker")
	add_child(baker)
	baker.position = Vector3(1.2, 4.8, 0.0)
	baker.set_emotion("worried")
	var gary := Cast.make_rig("gary")
	add_child(gary)
	gary.position = Vector3(3.4, 4.8, -0.9)
	gary.set_emotion("tired")
	for x in [-5.0, 5.0]:
		store.omni(Vector3(x, 6.0, 2.4), Color(0.78, 0.88, 1.0), 1.5, 14.0)
	var key := DirectionalLight3D.new()
	key.light_energy = 0.4
	key.light_color = Color(0.8, 0.85, 1.0)
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 40.0
	add_child(key)
	key.look_at_from_position(Vector3(-8, 20, 14), Vector3.ZERO)
	Game.tune(env, key)
	Game.graphics_changed.connect(func(): Game.tune(env, key))
	cam = Camera3D.new()
	cam.fov = 38.0
	add_child(cam)


func _process(dt: float) -> void:
	_t += dt
	cam.position = Vector3(-2.6 + sin(_t * 0.15) * 0.8, 7.4 + sin(_t * 0.21) * 0.2, 9.6)
	cam.look_at(Vector3(-1.6, 6.0, -0.5))
	if fmod(_t, 7.0) < dt:
		baker.face_dir([-1.0, 0.0, 1.0][int(_t / 7.0) % 3])
		baker.set_emotion(["worried", "neutral", "deadpan", "worried"][int(_t / 7.0) % 4])


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_ui)
	# a soft dark band down the left so the menu reads over the shelf
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.02, 0.04, 0.88))
	grad.set_color(1, Color(0.02, 0.02, 0.04, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.0, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	shade.texture = gt
	shade.anchor_bottom = 1.0
	shade.offset_right = 900
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(shade)
	# the price-tag logo
	var tag := PanelContainer.new()
	var ts := Kit.panel(Color(1.0, 0.84, 0.18), 16, 0, Color.WHITE, 34)
	ts.content_margin_top = 18
	ts.content_margin_bottom = 18
	tag.add_theme_stylebox_override("panel", ts)
	tag.position = Vector2(110, 90)
	tag.rotation = -0.05
	_ui.add_child(tag)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -6)
	tag.add_child(tv)
	var t1 := Kit.label("SHELF LIFE", 118, Color(0.55, 0.08, 0.08), Kit.title_font())
	tv.add_child(t1)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for i in 46:
		var r := ColorRect.new()
		r.color = Color(0.12, 0.08, 0.06)
		r.custom_minimum_size = Vector2(rng.randi_range(2, 6), 34)
		bar.add_child(r)
	var price := Kit.label("  $13.00", 36, Color(0.12, 0.08, 0.06), Kit.title_font())
	bar.add_child(price)
	tv.add_child(bar)
	var sub := Kit.label("ACT ONE: UNPLANNED", 34, Color(1.0, 0.92, 0.75), Kit.title_font(), 10)
	sub.position = Vector2(130, 330)
	_ui.add_child(sub)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 8)
	_menu.position = Vector2(120, 400)
	_menu.custom_minimum_size = Vector2(430, 0)
	_ui.add_child(_menu)
	if Game.has_save():
		_first = _btn("Continue", Game.continue_game)
	var ng := _btn("New Game", Game.new_game)
	if _first == null:
		_first = ng
	_btn("Settings", _open_settings)
	_upd_btn = _btn("Update", _on_update)
	_upd_btn.visible = false
	_btn("Quit", func(): get_tree().quit())
	var warn := Kit.label("Contains strong language, crude humor and food in mortal peril.", 20, Color(0.75, 0.72, 0.68), Kit.body_font(700), 6)
	warn.anchor_top = 1.0
	warn.anchor_bottom = 1.0
	warn.offset_left = 120
	warn.offset_top = -64
	_ui.add_child(warn)
	# bottom right: update status above, "what's new" link and the version
	_upd_label = Kit.label("", 19, Color(0.82, 0.8, 0.76), Kit.body_font(700), 6)
	_upd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_corner(_upd_label, -100, -66)
	_ui.add_child(_upd_label)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_theme_constant_override("separation", 22)
	_corner(foot, -60, -24)
	_ui.add_child(foot)
	_upd_link = LinkButton.new()
	_upd_link.focus_mode = Control.FOCUS_NONE
	_upd_link.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	_upd_link.add_theme_font_override("font", Kit.body_font(800))
	_upd_link.add_theme_font_size_override("font_size", 19)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_upd_link.add_theme_color_override(c, Color(1.0, 0.84, 0.36))
	_upd_link.pressed.connect(func():
		if Updater.state == Updater.AVAILABLE:
			Updater.open_page()
		else:
			Updater.open_notes())
	foot.add_child(_upd_link)
	foot.add_child(Kit.label("v" + Version.VERSION, 18, Color(0.6, 0.6, 0.62), Kit.body_font(700), 6))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(center)
	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(func():
		_settings.visible = false
		_menu.visible = true
		_first.grab_focus())
	center.add_child(_settings)
	_first.grab_focus.call_deferred()
	Updater.changed.connect(_upd_refresh)
	_upd_refresh()
	Updater.auto_check()


## Anchors a control to the bottom right, spanning most of the width so
## right-aligned text can grow to the left.
func _corner(c: Control, top: float, bottom: float) -> void:
	c.anchor_left = 1.0
	c.anchor_right = 1.0
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = -980
	c.offset_right = -40
	c.offset_top = top
	c.offset_bottom = bottom
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE if c is Label else Control.MOUSE_FILTER_PASS


func _btn(text: String, fn: Callable) -> Button:
	var b := Kit.button(text, 36)
	b.pressed.connect(func():
		Sfx.play("ui_ok", -6.0)
		if text in ["Continue", "New Game"]:
			Sfx.music_stop(0.8)
			Sfx.stop_all_ambience(0.5)
		fn.call())
	_menu.add_child(b)
	return b


func _open_settings() -> void:
	_menu.visible = false
	_settings.visible = true
	_settings.focus_first()


# --- updates ----------------------------------------------------------------

func _on_update() -> void:
	if Updater.state == Updater.AVAILABLE:
		Updater.install()
	elif Updater.state == Updater.DOWNLOADING:
		Updater.cancel()
	elif Updater.state == Updater.FAILED:
		Updater.open_page()


func _upd_refresh() -> void:
	var s: int = Updater.state
	var busy := s == Updater.DOWNLOADING or s == Updater.INSTALLING or s == Updater.RESTARTING
	for b in _menu.get_children():
		if b != _upd_btn:
			(b as Button).disabled = busy
	var show := s == Updater.AVAILABLE or busy or (s == Updater.FAILED and Updater.install_failed)
	if not show and _upd_btn.has_focus():
		_first.grab_focus()
	_upd_btn.visible = show
	_upd_btn.disabled = s == Updater.INSTALLING or s == Updater.RESTARTING
	if s == Updater.AVAILABLE:
		_upd_btn.text = "Update to v%s" % Updater.latest
	elif s == Updater.DOWNLOADING:
		_upd_btn.text = "Cancel update"
	elif s == Updater.FAILED:
		_upd_btn.text = "Open release page"
	else:
		_upd_btn.text = "Updating…"
	if busy and _menu.visible and not _upd_btn.has_focus():
		_upd_btn.grab_focus()
	var text := Updater.message
	if s == Updater.DOWNLOADING:
		text = "Downloading version %s…  %d%%" % [Updater.latest, roundi(Updater.progress * 100.0)]
	elif s == Updater.OFF or s == Updater.IDLE or s == Updater.LATEST:
		text = ""
	if text == "" and Updater.updated_from != "":
		text = "Updated from v%s to v%s." % [Updater.updated_from, Version.VERSION]
	_upd_label.text = text
	_upd_link.visible = s == Updater.AVAILABLE or (Updater.updated_from != "" and not busy)
	_upd_link.text = "What's new in v%s" % (Updater.latest if s == Updater.AVAILABLE else Version.VERSION)
