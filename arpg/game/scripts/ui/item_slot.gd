class_name ItemSlot
extends Button
## A square item cell: rarity frame colour + shape glyph, type glyph, upgrade arrow.

var item = null
var slot_name = ""

const TYPE_GLYPH := {"sword": "⚔", "axe": "⚒", "axe2h": "⚒", "staff": "⚚", "wand": "✧", "dagger": "†", "crossbow": "➶", "shield": "⛨", "tome": "▤",
	"quiver": "➹", "head": "⛑", "chest": "▣", "hands": "✋", "legs": "▥", "feet": "⏏", "belt": "═", "ring": "○", "amulet": "◎", "charm": "✿"}
const SHAPE_GLYPH := {"common": "", "magic": "●", "rare": "◆", "epic": "⬢", "legendary": "★", "mythic": "♦", "unique": "♛", "named": "☀"}

func setup(it, slot := "", size := 88.0) -> void:
	item = it
	slot_name = slot
	custom_minimum_size = Vector2(size, size)
	clip_text = true
	var col = Color(0.3, 0.28, 0.35)
	var bg = Color(0.08, 0.07, 0.11, 0.95)
	if it:
		col = Items.rarity_color(it.rarity)
		bg = col.darkened(0.82)
		bg.a = 0.95
	var st = UiTheme.panel_style(bg, col, 10, 3 if it and Items.rarity_index(it.rarity) >= 2 else 2)
	st.content_margin_left = 2
	st.content_margin_right = 2
	add_theme_stylebox_override("normal", st)
	var sth = st.duplicate()
	sth.border_color = col.lightened(0.4)
	add_theme_stylebox_override("hover", sth)
	add_theme_stylebox_override("pressed", sth)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	add_theme_font_size_override("font_size", int(size * 0.38))
	if it:
		text = TYPE_GLYPH.get(it.get("type", ""), "?")
		add_theme_color_override("font_color", col.lightened(0.3))
		var sh = Label.new()
		sh.text = SHAPE_GLYPH.get(it.rarity, "")
		sh.add_theme_font_size_override("font_size", int(size * 0.2))
		sh.add_theme_color_override("font_color", col)
		sh.position = Vector2(5, 1)
		add_child(sh)
	else:
		text = TYPE_GLYPH.get(slot.trim_suffix("1").trim_suffix("2").replace("main_hand", "sword").replace("off_hand", "shield"), "") if slot != "" else ""
		add_theme_color_override("font_color", Color(0.35, 0.33, 0.4))

func set_upgrade(delta: float) -> void:
	if item == null or absf(delta) < 1.0:
		return
	var a = Label.new()
	a.text = "▲" if delta > 0 else "▼"
	a.add_theme_color_override("font_color", Color("#4dff7a") if delta > 0 else Color("#ff5a5a"))
	a.add_theme_font_size_override("font_size", 18)
	a.position = Vector2(custom_minimum_size.x - 22, custom_minimum_size.y - 26)
	add_child(a)
