class_name UiTheme
extends RefCounted
## Shared look & feel: fonts (OFL, variable → FontVariation), palette, rarity language (colour + shape),
## procedural icon set (res://assets/ui/icons, tintable masks), button juice, hold-to-confirm, safe area.
## Rule from UI_UX.md: icon first, number second, word last.

const GOLD := Color("#ffd98a")
const EMBER := Color("#ff9a40")
const INK := Color("#0c0a12")
const PANEL := Color(0.07, 0.06, 0.1, 0.94)
const PANEL_2 := Color(0.11, 0.09, 0.15, 0.96)
const PANEL_EDGE := Color("#6b5a3a")
const TEXT := Color("#efe6d2")
const MUTED := Color("#a49cb0")
const LIFE := Color("#e0463b")
const THREAT := Color("#ff2b2b")
const GOOD := Color("#5dff8a")
const BAD := Color("#ff6060")
const XP := Color("#b58cff")
const COIN := Color("#ffcf4a")
const LOCKED := Color(0.42, 0.4, 0.46)

const HEADING_FONT := "res://assets/fonts/Cinzel/Cinzel[wght].ttf"
const BODY_FONT := "res://assets/fonts/Nunito/Nunito[wght].ttf"
const EASY_FONT := "res://assets/fonts/Andika/Andika-Bold.ttf"
const ICON_DIR := "res://assets/ui/icons/"

## Colour-blind safe rarity palette (Okabe–Ito based). Shapes stay the same in every mode.
const CB_RARITY := {"common": "#c8c8c8", "magic": "#56b4e9", "rare": "#f0e442", "epic": "#cc79a7", "legendary": "#e69f00",
	"mythic": "#ff5a36", "unique": "#2fd0a0", "named": "#ffffff"}
const RARITY_SHAPE := {"common": "square", "magic": "rounded", "rare": "diamond", "epic": "hexagon", "legendary": "star",
	"mythic": "flame", "unique": "crown", "named": "sun"}

## stat id → icon name (fallback: "spark")
const STAT_ICON := {"life": "life", "life_pct": "life", "vitality": "vitality", "might": "might", "agility": "agility", "wisdom": "wisdom",
	"armor": "armor", "armor_pct": "armor", "block": "block", "dodge": "dodge", "resist_all": "resist", "fire_resist": "fire", "cold_resist": "cold",
	"crit_chance": "crit", "crit_damage": "crit", "damage_pct": "damage", "attack_speed_pct": "attack_speed", "cdr_pct": "cooldown",
	"move_speed_pct": "speed", "magic_find": "magic_find", "gold_find": "gold", "xp_pct": "xp", "life_on_hit": "life_regen", "life_regen": "life_regen",
	"resource_max": "resource", "resource_regen": "resource", "area_pct": "area", "fire_pct": "fire", "cold_pct": "cold", "lightning_pct": "lightning",
	"holy_pct": "holy", "poison_pct": "poison", "minion_damage_pct": "summoner", "thorns": "shield", "pickup_radius": "hand", "material_find": "soot"}

static var _heading: Font
static var _body: Font
static var _theme: Theme
static var _icons := {}
static var _theme_sig := ""

# ------------------------------------------------------------------ fonts
static func _variable(path: String, weight: int) -> Font:
	if not ResourceLoader.exists(path):
		return null
	var ff: Font = load(path)
	var fv = FontVariation.new()
	fv.base_font = ff
	var ts = TextServerManager.get_primary_interface()
	fv.variation_opentype = {ts.name_to_tag("wght"): weight}
	return fv

static func font_heading() -> Font:
	if _heading == null:
		_heading = _variable(HEADING_FONT, 700)
		if _heading == null:
			_heading = ThemeDB.fallback_font
	return _heading

static func font_body() -> Font:
	if _body == null:
		if bool(Settings.get_value("easy_read_font", false)) and ResourceLoader.exists(EASY_FONT):
			_body = load(EASY_FONT)
		else:
			_body = _variable(BODY_FONT, 750)
		if _body == null:
			_body = ThemeDB.fallback_font
	return _body

static func font_numbers() -> Font:
	return font_body()

## Call after changing text/contrast/font settings: next theme() call rebuilds.
static func invalidate() -> void:
	_theme = null
	_body = null
	_heading = null

static func text_scale() -> float:
	return clampf(float(Settings.get_value("text_scale", 1.0)), 1.0, 2.0)

static func fs(size: int) -> int:
	## Font size scaled by the text-size setting (dampened for large headings so layouts hold).
	var s = text_scale()
	if size >= 34:
		s = 1.0 + (s - 1.0) * 0.4
	return int(round(size * s))

static func high_contrast() -> bool:
	return bool(Settings.get_value("high_contrast", false))

# ------------------------------------------------------------------ rarity
static func rarity_color(rarity_id: String) -> Color:
	var mode = Settings.get_value("colorblind_mode", false)
	if (mode is bool and mode) or (mode is String and mode != "" and mode != "off"):
		return Color(CB_RARITY.get(rarity_id, "#c8c8c8"))
	return Items.rarity_color(rarity_id)

static func rarity_shape(rarity_id: String) -> String:
	return str(Content.get_rec("rarities", rarity_id).get("shape", RARITY_SHAPE.get(rarity_id, "square")))

static func rarity_name(rarity_id: String) -> String:
	return str(Content.get_rec("rarities", rarity_id).get("name", rarity_id.capitalize()))

## Polygon (unit square 0..1) for a rarity emblem shape.
static func shape_points(shape: String, n_sun := 12) -> PackedVector2Array:
	var pts = PackedVector2Array()
	match shape:
		"square":
			pts = PackedVector2Array([Vector2(0.1, 0.1), Vector2(0.9, 0.1), Vector2(0.9, 0.9), Vector2(0.1, 0.9)])
		"rounded":
			for i in 24:
				var a = TAU * i / 24.0
				pts.append(Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * 0.42)
		"diamond":
			pts = PackedVector2Array([Vector2(0.5, 0.02), Vector2(0.98, 0.5), Vector2(0.5, 0.98), Vector2(0.02, 0.5)])
		"hexagon":
			for i in 6:
				var a = TAU * i / 6.0 - PI / 2
				pts.append(Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * 0.48)
		"star":
			for i in 10:
				var a = TAU * i / 10.0 - PI / 2
				var r = 0.5 if i % 2 == 0 else 0.22
				pts.append(Vector2(0.5, 0.54) + Vector2(cos(a), sin(a)) * r)
		"flame":
			pts = PackedVector2Array([Vector2(0.5, 0.0), Vector2(0.68, 0.28), Vector2(0.86, 0.5), Vector2(0.82, 0.78), Vector2(0.5, 1.0),
				Vector2(0.18, 0.78), Vector2(0.14, 0.52), Vector2(0.3, 0.34), Vector2(0.4, 0.5)])
		"crown":
			pts = PackedVector2Array([Vector2(0.04, 0.22), Vector2(0.28, 0.48), Vector2(0.5, 0.1), Vector2(0.72, 0.48), Vector2(0.96, 0.22),
				Vector2(0.86, 0.9), Vector2(0.14, 0.9)])
		"sun":
			for i in n_sun * 2:
				var a = TAU * i / (n_sun * 2.0)
				var r = 0.5 if i % 2 == 0 else 0.34
				pts.append(Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * r)
		_:
			return shape_points("square")
	return pts

## Draw a rarity emblem into a CanvasItem at rect (outline + fill).
static func draw_shape(ci: CanvasItem, shape: String, rect: Rect2, fill: Color, outline := Color(0, 0, 0, 0.85), width := 2.0) -> void:
	var pts = PackedVector2Array()
	for p in shape_points(shape):
		pts.append(rect.position + p * rect.size)
	ci.draw_colored_polygon(pts, fill)
	var closed = pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, outline, width, true)

# ------------------------------------------------------------------ icons
static func icon(name: String) -> Texture2D:
	if _icons.has(name):
		return _icons[name]
	var p = ICON_DIR + name + ".png"
	var t: Texture2D = null
	if ResourceLoader.exists(p):
		t = load(p)
	elif name != "unknown":
		t = icon("unknown")
	_icons[name] = t
	return t

static func has_icon(name: String) -> bool:
	return ResourceLoader.exists(ICON_DIR + name + ".png")

static func stat_icon(stat: String) -> String:
	if STAT_ICON.has(stat):
		return STAT_ICON[stat]
	for k in ["fire", "cold", "lightning", "holy", "poison", "life", "armor", "crit", "gold", "xp"]:
		if stat.begins_with(k):
			return k
	return "spark"

static func icon_rect(name: String, size := 48.0, tint := Color.WHITE) -> TextureRect:
	var r = TextureRect.new()
	r.texture = icon(name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.modulate = tint
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

# ------------------------------------------------------------------ styles
static func panel_style(bg := PANEL, edge := PANEL_EDGE, radius := 14, border := 3) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	if high_contrast():
		s.bg_color = Color(bg.r * 0.6, bg.g * 0.6, bg.b * 0.6, 1.0)
		border += 1
		edge = edge.lightened(0.25)
	s.border_color = edge
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 6
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.anti_aliasing = true
	return s

static func card_style(accent: Color, selected := false) -> StyleBoxFlat:
	var s = panel_style(Color(accent.darkened(0.86), 0.97), accent.darkened(0.25) if not selected else accent, 14, 4 if selected else 2)
	if selected:
		s.shadow_color = Color(accent, 0.45)
		s.shadow_size = 12
	return s

static func theme() -> Theme:
	var sig = "%s|%s|%s" % [text_scale(), high_contrast(), Settings.get_value("easy_read_font", false)]
	if _theme and sig == _theme_sig:
		return _theme
	_theme_sig = sig
	_body = null
	var t = Theme.new()
	t.default_font = font_body()
	t.default_font_size = fs(22)
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	t.set_constant("outline_size", "Label", 6 if high_contrast() else 4)
	var btn = panel_style(Color(0.16, 0.12, 0.2, 0.96), Color("#8a7448"), 14, 2)
	var btn_h = panel_style(Color(0.22, 0.17, 0.27, 0.98), GOLD, 14, 2)
	var btn_p = panel_style(Color(0.1, 0.08, 0.14, 1.0), EMBER, 14, 3)
	var btn_d = panel_style(Color(0.1, 0.1, 0.12, 0.8), Color(0.3, 0.3, 0.32), 14, 2)
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", btn_h)
	t.set_stylebox("pressed", "Button", btn_p)
	t.set_stylebox("hover_pressed", "Button", btn_p)
	t.set_stylebox("disabled", "Button", btn_d)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", EMBER)
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.52, 0.58))
	t.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.8))
	t.set_constant("outline_size", "Button", 4)
	t.set_font("font", "Button", font_heading())
	t.set_font_size("font_size", "Button", fs(22))
	t.set_stylebox("panel", "Panel", panel_style())
	t.set_stylebox("panel", "PanelContainer", panel_style())
	var le = panel_style(Color(0.05, 0.04, 0.08, 1), Color("#5a4a30"), 10, 2)
	var lef = panel_style(Color(0.05, 0.04, 0.08, 1), GOLD, 10, 2)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", lef)
	t.set_font_size("font_size", "LineEdit", fs(28))
	t.set_color("font_color", "LineEdit", TEXT)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.55, 0.45, 0.3, 0.7)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	var sbt = StyleBoxFlat.new()
	sbt.bg_color = Color(0, 0, 0, 0.25)
	sbt.set_corner_radius_all(6)
	sbt.content_margin_left = 6
	sbt.content_margin_right = 6
	for sc in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sc, sbt)
		t.set_stylebox("grabber", sc, sb)
		t.set_stylebox("grabber_highlight", sc, sb)
		t.set_stylebox("grabber_pressed", sc, sb)
	# Sliders: chunky for thumbs
	var sl = StyleBoxFlat.new()
	sl.bg_color = Color(0.2, 0.16, 0.24)
	sl.set_corner_radius_all(8)
	sl.content_margin_top = 8
	sl.content_margin_bottom = 8
	var slf = sl.duplicate()
	slf.bg_color = EMBER.darkened(0.2)
	t.set_stylebox("slider", "HSlider", sl)
	t.set_stylebox("grabber_area", "HSlider", slf)
	t.set_stylebox("grabber_area_highlight", "HSlider", slf)
	t.set_icon("grabber", "HSlider", _knob_tex(36, GOLD))
	t.set_icon("grabber_highlight", "HSlider", _knob_tex(40, Color.WHITE))
	t.set_font_size("font_size", "CheckButton", fs(22))
	t.set_font_size("font_size", "OptionButton", fs(22))
	t.set_font_size("font_size", "PopupMenu", fs(24))
	t.set_stylebox("panel", "PopupMenu", panel_style(PANEL_2, GOLD, 10, 2))
	t.set_stylebox("panel", "TooltipPanel", panel_style(PANEL_2, GOLD, 8, 2))
	t.set_font_size("font_size", "TooltipLabel", fs(20))
	_theme = t
	return t

static var _knobs := {}
static func _knob_tex(d: int, col: Color) -> Texture2D:
	var key = "%d_%s" % [d, col.to_html()]
	if _knobs.has(key):
		return _knobs[key]
	var img = Image.create(d, d, false, Image.FORMAT_RGBA8)
	var r = d * 0.5
	for y in d:
		for x in d:
			var dist = Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a = clampf(r - dist, 0.0, 1.0)
			var c = col if dist < r - 4 else Color(0.1, 0.06, 0.02)
			img.set_pixel(x, y, Color(c, a))
	var t = ImageTexture.create_from_image(img)
	_knobs[key] = t
	return t

# ------------------------------------------------------------------ widgets
static func label(text: String, size := 22, color := TEXT, heading := false) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", color)
	if heading:
		l.add_theme_font_override("font", font_heading())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func wrap_label(text: String, size := 20, color := TEXT, min_w := 200.0) -> Label:
	var l = label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(min_w, 0)
	return l

static func button(text: String, cb: Callable, size := 22, min_size := Vector2(160, 64)) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", fs(size))
	b.pressed.connect(func():
		Sfx.play("ui_click", -6.0, 0.02)
		cb.call())
	juice(b)
	return b

## Icon-first button: icon on top (or left when `row`), short word under it.
static func icon_button(icon_name: String, text: String, cb: Callable, min_size := Vector2(96, 96), tint := GOLD, row := false, font_size := 18) -> Button:
	var b = Button.new()
	b.custom_minimum_size = min_size
	b.tooltip_text = text
	var box: BoxContainer = HBoxContainer.new() if row else VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8 if row else 0)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 6
	box.offset_right = -6
	box.offset_top = 4
	box.offset_bottom = -4
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	var isz = min(min_size.x, min_size.y) * (0.52 if (text != "" and not row) else 0.62)
	var ir = icon_rect(icon_name, isz, tint)
	ir.name = "Icon"
	box.add_child(ir)
	if text != "":
		var l = label(text, font_size, TEXT, true)
		l.name = "Text"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.clip_text = not row
		if not row:
			l.custom_minimum_size = Vector2(min_size.x - 12, 0)
		box.add_child(l)
	b.pressed.connect(func():
		Sfx.play("ui_click", -6.0, 0.02)
		cb.call())
	juice(b)
	return b

## Press feedback per UI_UX §10: scale 0.94 for 60 ms → 1.0 over 90 ms.
static func juice(b: Control) -> void:
	if not (b is BaseButton):
		return
	var bb: BaseButton = b
	var fix_pivot = func(): bb.pivot_offset = bb.size * 0.5
	bb.resized.connect(fix_pivot)
	bb.button_down.connect(func():
		fix_pivot.call()
		haptic(10)
		var t = bb.create_tween()
		t.tween_property(bb, "scale", Vector2(0.94, 0.94), 0.06))
	bb.button_up.connect(func():
		var t = bb.create_tween()
		t.tween_property(bb, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))

## Haptics (research rec. 28): master toggle + intensity in Settings; Android only.
static func haptic(ms: int, strength := 1.0) -> void:
	var k = float(Settings.get_value("haptics", 0.6))
	if k <= 0.01 or not OS.has_feature("mobile"):
		return
	Input.vibrate_handheld(int(ms), clampf(k * strength, 0.05, 1.0))

## Unavailable feedback: shake 3 px × 3 in 180 ms.
static func deny(c: Control) -> void:
	var p = c.position
	var t = c.create_tween()
	for i in 3:
		t.tween_property(c, "position", p + Vector2(3, 0), 0.03)
		t.tween_property(c, "position", p - Vector2(3, 0), 0.03)
	t.tween_property(c, "position", p, 0.02)
	Sfx.play("ui_deny", -6.0)

## Hold-to-confirm button (welfare: Epic+ salvage/crafts). `seconds` = 0 → plain tap.
static func hold_button(text: String, seconds: float, cb: Callable, min_size := Vector2(200, 80), accent := EMBER, icon_name := "") -> Button:
	var b: Button
	if icon_name != "":
		b = Button.new()
		b.custom_minimum_size = min_size
		var hb = HBoxContainer.new()
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.add_theme_constant_override("separation", 8)
		hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(hb)
		hb.add_child(icon_rect(icon_name, min_size.y * 0.5, accent.lightened(0.3)))
		var l = label(text, 22, TEXT, true)
		l.name = "Text"
		hb.add_child(l)
	else:
		b = Button.new()
		b.text = text
		b.custom_minimum_size = min_size
		b.add_theme_font_size_override("font_size", fs(22))
	b.add_theme_stylebox_override("normal", panel_style(accent.darkened(0.75), accent, 14, 3))
	b.add_theme_stylebox_override("hover", panel_style(accent.darkened(0.65), accent.lightened(0.3), 14, 3))
	juice(b)
	if seconds <= 0.0:
		b.pressed.connect(func():
			Sfx.play("ui_click", -6.0, 0.02)
			cb.call())
		return b
	var fill = ColorRect.new()
	fill.color = Color(accent, 0.45)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.anchor_bottom = 1.0
	fill.anchor_right = 0.0
	fill.offset_left = 4
	fill.offset_top = 4
	fill.offset_bottom = -4
	b.add_child(fill)
	b.move_child(fill, 0)
	var hint = label("Hold", 14, Color(accent.lightened(0.4), 0.9))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -60
	hint.offset_top = -24
	hint.offset_right = -10
	hint.offset_bottom = -2
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.add_child(hint)
	var state = {"t": null}
	b.button_down.connect(func():
		if b.disabled:
			return
		if state.t:
			state.t.kill()
		fill.anchor_right = 0.0
		var tw = b.create_tween()
		state.t = tw
		tw.tween_property(fill, "anchor_right", 1.0, seconds)
		tw.tween_callback(func():
			fill.anchor_right = 0.0
			Sfx.play("ui_confirm", -4.0)
			cb.call()))
	b.button_up.connect(func():
		if state.t and state.t.is_valid():
			state.t.kill()
		var tw2 = b.create_tween()
		tw2.tween_property(fill, "anchor_right", 0.0, 0.12))
	return b

## A pill with an icon and a number (currencies, counts).
static func pill(icon_name: String, text: String, tint := COIN, size := 22) -> PanelContainer:
	var p = PanelContainer.new()
	var st = panel_style(Color(0.05, 0.04, 0.07, 0.85), tint.darkened(0.4), 20, 2)
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	st.content_margin_left = 8
	st.content_margin_right = 14
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	h.add_child(icon_rect(icon_name, size + 8, tint))
	var l = label(text, size, TEXT)
	l.name = "Value"
	h.add_child(l)
	return p

static func progress_bar(col: Color, h := 14.0, bg := Color(0.04, 0.03, 0.06, 0.9)) -> ProgressBar:
	var b = ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, h)
	var f = StyleBoxFlat.new()
	f.bg_color = col
	f.set_corner_radius_all(int(h / 2))
	f.border_color = col.lightened(0.35)
	f.border_width_top = 2 if h >= 12 else 1
	var g = StyleBoxFlat.new()
	g.bg_color = bg
	g.set_corner_radius_all(int(h / 2))
	g.border_color = Color(0, 0, 0, 0.8)
	g.set_border_width_all(2)
	b.add_theme_stylebox_override("fill", f)
	b.add_theme_stylebox_override("background", g)
	b.max_value = 1.0
	b.step = 0.001
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

static func stars(n: int, of := 3, size := 22.0, col := GOLD) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in of:
		h.add_child(icon_rect("star", size, col if i < n else Color(0.3, 0.28, 0.34)))
	return h

static func separator(col := Color(1, 0.85, 0.55, 0.18)) -> ColorRect:
	var r = ColorRect.new()
	r.color = col
	r.custom_minimum_size = Vector2(0, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

static func spacer(w := 0.0, h := 0.0, expand := false) -> Control:
	var c = Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c

static func fmt_num(v: float) -> String:
	var a = absf(v)
	if a >= 1000000:
		return "%.1fM" % (v / 1000000.0)
	if a >= 10000:
		return "%.1fk" % (v / 1000.0)
	return str(int(round(v)))

static func fmt_time(sec: float) -> String:
	sec = max(0.0, sec)
	if sec >= 3600:
		return "%dh %02dm" % [int(sec / 3600), int(fmod(sec, 3600) / 60)]
	if sec >= 60:
		return "%dm %02ds" % [int(sec / 60), int(fmod(sec, 60))]
	return "%ds" % int(ceil(sec))

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

## Safe-area insets in canvas (reference) pixels: left, top, right, bottom. Min 24 px each side.
static func safe_insets(vp: Viewport) -> Vector4:
	var minv = 24.0
	var out = Vector4(minv, minv, minv, minv)
	if vp == null:
		return out
	var win_size = Vector2(DisplayServer.window_get_size())
	var safe = DisplayServer.get_display_safe_area()
	var vis = vp.get_visible_rect().size
	if win_size.x <= 0 or safe.size.x <= 0:
		return out
	var k = vis.x / win_size.x
	var screen = Vector2(DisplayServer.screen_get_size())
	if screen.x <= 0 or absf(screen.x - win_size.x) > 4:
		return out   # windowed (desktop): no cutouts
	out.x = max(minv, safe.position.x * k)
	out.y = max(minv, safe.position.y * k)
	out.z = max(minv, (screen.x - safe.end.x) * k)
	out.w = max(minv, (screen.y - safe.end.y) * k)
	return out

# ------------------------------------------------------------------ gameplay API access (defensive)
## Look up a gameplay class by its class_name (e.g. "Pets", "SkillMastery") without a hard dependency,
## so screens work before and after those APIs land.
static var _class_cache := {}
static func api(cls_name: String) -> Script:
	if _class_cache.has(cls_name):
		return _class_cache[cls_name]
	var found: Script = null
	for c in ProjectSettings.get_global_class_list():
		if str(c.get("class", "")) == cls_name:
			var p = str(c.get("path", ""))
			if ResourceLoader.exists(p):
				found = load(p)
			break
	_class_cache[cls_name] = found
	return found

static var _method_cache := {}
static func api_has(cls_name: String, method: String) -> bool:
	var key = cls_name + "." + method
	if _method_cache.has(key):
		return _method_cache[key]
	var s = api(cls_name)
	var ok = false
	if s != null:
		for m in s.get_script_method_list():
			if str(m.get("name", "")) == method:
				ok = true
				break
	_method_cache[key] = ok
	return ok

## Call a static gameplay API; returns `fallback` when the class/method is missing.
static func api_call(cls_name: String, method: String, args := [], fallback = null):
	if not api_has(cls_name, method):
		return fallback
	return api(cls_name).callv(method, args)

## Read a CharacterData field that may not exist yet.
static func chf(ch: Object, field: String, fallback = null):
	if ch == null:
		return fallback
	if field in ch:
		var v = ch.get(field)
		return v if v != null else fallback
	return fallback
