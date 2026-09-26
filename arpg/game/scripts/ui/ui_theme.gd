class_name UiTheme
extends RefCounted
## Shared look: fonts, colours, panel styles. Fonts are OFL (see docs/legal/THIRD_PARTY.md);
## falls back to the engine default if a font file is missing.

const GOLD := Color("#ffd98a")
const EMBER := Color("#ff9a40")
const INK := Color("#0c0a12")
const PANEL := Color(0.07, 0.06, 0.1, 0.92)
const PANEL_EDGE := Color("#6b5a3a")
const TEXT := Color("#efe6d2")
const MUTED := Color("#9a93a6")
const LIFE := Color("#e0463b")
const THREAT := Color("#ff2b2b")

const HEADING_FONTS := ["res://assets/fonts/cinzel/Cinzel-Bold.ttf", "res://assets/fonts/cinzel/Cinzel-Bold.woff2", "res://assets/fonts/cinzel/cinzel-latin-700-normal.woff2"]
const BODY_FONTS := ["res://assets/fonts/nunito/Nunito-Bold.ttf", "res://assets/fonts/nunito/Nunito-Bold.woff2", "res://assets/fonts/nunito/nunito-latin-700-normal.woff2"]

static var _heading: Font
static var _body: Font
static var _theme: Theme

static func _first(paths: Array) -> Font:
	for p in paths:
		if ResourceLoader.exists(p):
			return load(p)
	return null

static func font_heading() -> Font:
	if _heading == null:
		_heading = _first(HEADING_FONTS)
		if _heading == null:
			_heading = ThemeDB.fallback_font
	return _heading

static func font_body() -> Font:
	if _body == null:
		_body = _first(BODY_FONTS)
		if _body == null:
			_body = ThemeDB.fallback_font
	return _body

static func font_numbers() -> Font:
	return font_body()

static func panel_style(bg := PANEL, edge := PANEL_EDGE, radius := 14, border := 3) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 8
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

static func theme() -> Theme:
	if _theme:
		return _theme
	var t = Theme.new()
	t.default_font = font_body()
	t.default_font_size = 22
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.8))
	t.set_constant("outline_size", "Label", 4)
	var btn = panel_style(Color(0.16, 0.12, 0.2, 0.95), Color("#8a7448"), 12, 2)
	var btn_h = panel_style(Color(0.24, 0.18, 0.28, 0.98), GOLD, 12, 2)
	var btn_p = panel_style(Color(0.1, 0.08, 0.14, 1.0), EMBER, 12, 3)
	var btn_d = panel_style(Color(0.1, 0.1, 0.12, 0.8), Color(0.3, 0.3, 0.3), 12, 2)
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", btn_h)
	t.set_stylebox("pressed", "Button", btn_p)
	t.set_stylebox("disabled", "Button", btn_d)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", EMBER)
	t.set_font("font", "Button", font_heading())
	t.set_font_size("font_size", "Button", 22)
	t.set_stylebox("panel", "Panel", panel_style())
	t.set_stylebox("panel", "PanelContainer", panel_style())
	var le = panel_style(Color(0.05, 0.04, 0.08, 1), Color("#5a4a30"), 8, 2)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le)
	t.set_font_size("font_size", "LineEdit", 26)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.3, 0.25, 0.2, 0.6)
	sb.set_corner_radius_all(6)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxFlat.new())
	t.set_stylebox("grabber", "VScrollBar", sb)
	_theme = t
	return t

static func label(text: String, size := 22, color := TEXT, heading := false) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if heading:
		l.add_theme_font_override("font", font_heading())
	return l

static func button(text: String, cb: Callable, size := 22, min_size := Vector2(160, 64)) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(func():
		Sfx.play("ui_click", -6.0, 0.02)
		cb.call())
	return b

## Anchor a control at (ax, ay) of its parent (0..1) with a pixel rect relative to that anchor point.
static func place(c: Control, ax: float, ay: float, x: float, y: float, w: float, h: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = x
	c.offset_top = y
	c.offset_right = x + w
	c.offset_bottom = y + h
