extends RefCounted
## Fonts, styles and small widget helpers shared by every screen.

static var _fonts := {}


static func title_font() -> Font:
	if not _fonts.has("title"):
		_fonts.title = load("res://assets/fonts/LilitaOne-Regular.ttf")
	return _fonts.title


## Nunito at a weight (400..900).
static func body_font(weight := 700) -> Font:
	var k := "body%d" % weight
	if not _fonts.has(k):
		var fv := FontVariation.new()
		fv.base_font = load("res://assets/fonts/Nunito.ttf")
		var ts := TextServerManager.get_primary_interface()
		fv.variation_opentype = {ts.name_to_tag("wght"): weight}
		_fonts[k] = fv
	return _fonts[k]


static func italic_font(weight := 700) -> Font:
	var k := "ital%d" % weight
	if not _fonts.has(k):
		var fv := FontVariation.new()
		fv.base_font = load("res://assets/fonts/Nunito.ttf")
		var ts := TextServerManager.get_primary_interface()
		fv.variation_opentype = {ts.name_to_tag("wght"): weight}
		fv.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)
		_fonts[k] = fv
	return _fonts[k]


static func panel(bg: Color, radius := 18, border := 0, border_col := Color.WHITE, pad := 16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_col
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 10
	s.anti_aliasing = true
	return s


static func label(text: String, size: int, col := Color.WHITE, f: Font = null, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", f if f != null else body_font(700))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.06))
	return l


## A chunky menu button: dark at rest, coloured when focused or hovered.
static func button(text: String, size := 30, accent := Color(1.0, 0.8, 0.25)) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", body_font(800))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color(0.93, 0.92, 0.88))
	b.add_theme_color_override("font_hover_color", Color(0.08, 0.07, 0.09))
	b.add_theme_color_override("font_focus_color", Color(0.08, 0.07, 0.09))
	b.add_theme_color_override("font_pressed_color", Color(0.08, 0.07, 0.09))
	b.add_theme_color_override("font_hover_pressed_color", Color(0.08, 0.07, 0.09))
	var normal := panel(Color(1, 1, 1, 0.06), 14, 0, Color.WHITE, 22)
	normal.shadow_size = 0
	var hot := panel(accent, 14, 0, Color.WHITE, 22)
	hot.shadow_size = 0
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hot)
	b.add_theme_stylebox_override("focus", hot)
	b.add_theme_stylebox_override("pressed", hot)
	b.add_theme_stylebox_override("hover_pressed", hot)
	b.mouse_entered.connect(func(): b.grab_focus())
	b.focus_entered.connect(func(): Sfx.play("ui_move", -10.0))
	return b
