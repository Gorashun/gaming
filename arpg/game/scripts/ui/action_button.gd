class_name ActionButton
extends Control
## Round skill button with icon glyph, cooldown sweep, cost dimming and press feedback.

var key = ""
var skill = ""
var _bg: Panel
var _icon: Label
var _cd: Label
var _sweep: TextureProgressBar
var _aim: Panel
var _size = 112.0
var _base_col = Color(0.14, 0.11, 0.18, 0.88)

const GLYPHS := {"sword": "⚔", "shield": "⛨", "dash": "➹", "sun": "☀", "aegis": "✦", "pillar": "✧", "axe": "⚒", "whirl": "✺", "leap": "⤒", "roar": "♫",
	"quake": "≋", "rope": "⥁", "spark": "✶", "comet": "☄", "frost": "❄", "chain": "ϟ", "blink": "☾", "meteor": "☄", "needle": "✎", "doll": "☺",
	"pins": "✱", "bear": "ʕ", "thread": "∞", "mend": "✚", "bolt": "➶", "fan": "⋔", "roll": "↻", "trap": "✹", "smoke": "☁", "rain": "⇊",
	"__potion": "♥", "__dodge": "»"}

func setup(k: String, s: String, sz: float) -> void:
	key = k
	_size = sz
	custom_minimum_size = Vector2(sz, sz)
	size = Vector2(sz, sz)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg = Panel.new()
	_bg.size = Vector2(sz, sz)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_sweep = TextureProgressBar.new()
	_sweep.fill_mode = TextureProgressBar.FILL_COUNTER_CLOCKWISE
	_sweep.texture_progress = _disc_tex(int(sz))
	_sweep.tint_progress = Color(0, 0, 0, 0.6)
	_sweep.size = Vector2(sz, sz)
	_sweep.max_value = 1.0
	_sweep.step = 0.001
	_sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sweep)
	_icon = Label.new()
	_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon.size = Vector2(sz, sz)
	_icon.add_theme_font_size_override("font_size", int(sz * 0.42))
	_icon.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_icon.add_theme_constant_override("outline_size", 8)
	add_child(_icon)
	_cd = Label.new()
	_cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cd.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_cd.size = Vector2(sz, sz * 0.92)
	_cd.add_theme_font_size_override("font_size", int(sz * 0.22))
	_cd.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_cd.add_theme_constant_override("outline_size", 6)
	add_child(_cd)
	_aim = Panel.new()
	_aim.size = Vector2(18, 18)
	_aim.visible = false
	var st = StyleBoxFlat.new()
	st.bg_color = Color(1, 0.8, 0.4, 0.9)
	st.set_corner_radius_all(9)
	_aim.add_theme_stylebox_override("panel", st)
	add_child(_aim)
	set_skill(s)

static var _disc_cache := {}
func _disc_tex(d: int) -> Texture2D:
	if _disc_cache.has(d):
		return _disc_cache[d]
	var img = Image.create(d, d, false, Image.FORMAT_RGBA8)
	var r = d * 0.5
	for y in d:
		for x in d:
			var dist = Vector2(x + 0.5 - r, y + 0.5 - r).length()
			img.set_pixel(x, y, Color(1, 1, 1, clampf(r - dist, 0.0, 1.0)))
	var t = ImageTexture.create_from_image(img)
	_disc_cache[d] = t
	return t

func set_skill(s: String) -> void:
	skill = s
	var rec = Content.get_rec("skills", s) if not s.begins_with("__") else {}
	var col = Color(rec.get("color", "#ffd98a")) if not rec.is_empty() else (Color("#ff5a6a") if s == "__potion" else Color("#c0c8ff"))
	if s == "":
		col = Color(0.4, 0.4, 0.45)
	var st = StyleBoxFlat.new()
	st.bg_color = _base_col
	st.border_color = col
	st.set_border_width_all(4 if key == "attack" else 3)
	st.set_corner_radius_all(int(_size / 2))
	st.shadow_color = Color(col, 0.35)
	st.shadow_size = 6
	_bg.add_theme_stylebox_override("panel", st)
	_icon.text = GLYPHS.get(rec.get("icon", s), "+") if s != "" else ""
	_icon.add_theme_color_override("font_color", col.lightened(0.25))

func update_state(p: Player) -> void:
	if skill == "" or p == null:
		_sweep.value = 0
		_cd.text = ""
		return
	if skill == "__potion":
		_cd.text = str(p.ch.potions)
		modulate = Color(1, 1, 1, 1) if p.ch.potions > 0 else Color(0.5, 0.5, 0.5, 0.8)
		return
	var left = p.cooldown_left(skill)
	var total = 2.0 if skill == "__dodge" else p.cooldown_total(Content.get_rec("skills", skill))
	_sweep.value = left / total if total > 0 else 0.0
	_cd.text = ("%.1f" % left) if left > 0.05 and left < 10 else (str(int(left)) if left >= 10 else "")
	if skill != "__dodge":
		var cost = float(Content.get_rec("skills", skill).get("cost", 0))
		modulate = Color(1, 1, 1, 1) if p.resource >= cost else Color(0.55, 0.6, 1.0, 0.85)

func set_pressed_look(on: bool) -> void:
	scale = Vector2.ONE * (0.9 if on else 1.0)
	pivot_offset = Vector2(_size, _size) * 0.5
	_aim.visible = false

func show_aim(v: Vector2) -> void:
	_aim.visible = v.length() > 0.1
	_aim.position = Vector2(_size, _size) * 0.5 + v.limit_length(1.0) * _size * 0.6 - Vector2(9, 9)

func shake() -> void:
	var t = create_tween()
	var p = position
	t.tween_property(self, "position", p + Vector2(6, 0), 0.04)
	t.tween_property(self, "position", p - Vector2(6, 0), 0.06)
	t.tween_property(self, "position", p, 0.04)
