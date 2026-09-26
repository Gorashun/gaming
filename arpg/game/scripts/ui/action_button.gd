class_name ActionButton
extends Control
## Round skill button: vector icon tinted in the skill colour, cooldown sweep + seconds,
## resource-cost tint (blue when you lack resource), press scale, aim nub while dragging,
## "mastery ready" sparkle, charges counter (potion).

var key = ""
var skill = ""
var _bg: Panel
var _icon: TextureRect
var _cd: Label
var _sweep: TextureProgressBar
var _aim: Panel
var _badge: Label
var _size = 112.0
var _base_col = Color(0.12, 0.09, 0.16, 0.9)
var _col = Color.WHITE
var _ready_flash = 0.0
var _was_cd = false

## Legacy glyphs (kept for older callers); icons come from res://assets/ui/icons/<skill.icon>.png.
const GLYPHS := {"sword": "⚔", "shield": "⛨", "__potion": "♥", "__dodge": "»"}

func setup(k: String, s: String, sz: float) -> void:
	key = k
	_size = sz
	custom_minimum_size = Vector2(sz, sz)
	size = Vector2(sz, sz)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = Vector2(sz, sz) * 0.5
	_bg = Panel.new()
	_bg.size = Vector2(sz, sz)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var pad = sz * (0.22 if k != "attack" else 0.25)
	_icon.position = Vector2(pad, pad)
	_icon.size = Vector2(sz - pad * 2, sz - pad * 2)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_sweep = TextureProgressBar.new()
	_sweep.fill_mode = TextureProgressBar.FILL_COUNTER_CLOCKWISE
	_sweep.texture_progress = _disc_tex(int(sz))
	_sweep.tint_progress = Color(0.02, 0.0, 0.05, 0.62)
	_sweep.size = Vector2(sz, sz)
	_sweep.max_value = 1.0
	_sweep.step = 0.001
	_sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sweep)
	_cd = Label.new()
	_cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cd.size = Vector2(sz, sz)
	_cd.add_theme_font_override("font", UiTheme.font_body())
	_cd.add_theme_font_size_override("font_size", int(sz * 0.3))
	_cd.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_cd.add_theme_constant_override("outline_size", 8)
	add_child(_cd)
	_badge = Label.new()
	_badge.add_theme_font_override("font", UiTheme.font_body())
	_badge.add_theme_font_size_override("font_size", int(max(20, sz * 0.24)))
	_badge.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_badge.add_theme_constant_override("outline_size", 6)
	_badge.position = Vector2(sz * 0.62, sz * 0.62)
	_badge.size = Vector2(sz * 0.4, sz * 0.36)
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_badge)
	_aim = Panel.new()
	_aim.size = Vector2(22, 22)
	_aim.visible = false
	var st = StyleBoxFlat.new()
	st.bg_color = Color(1, 0.8, 0.4, 0.95)
	st.set_corner_radius_all(11)
	st.border_color = Color(0.2, 0.08, 0)
	st.set_border_width_all(2)
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
			img.set_pixel(x, y, Color(1, 1, 1, clampf(r - 3 - dist, 0.0, 1.0)))
	var t = ImageTexture.create_from_image(img)
	_disc_cache[d] = t
	return t

static func icon_name_for(s: String) -> String:
	if s == "__potion":
		return "potion"
	if s == "__dodge":
		return "dodge"
	if s == "":
		return ""
	var rec = Content.get_rec("skills", s)
	var n = str(rec.get("icon", ""))
	return n if UiTheme.has_icon(n) else "spark"

static func color_for(s: String) -> Color:
	if s == "__potion":
		return Color("#ff5a6a")
	if s == "__dodge":
		return Color("#c0c8ff")
	if s == "":
		return Color(0.4, 0.4, 0.45)
	return Color(Content.get_rec("skills", s).get("color", "#ffd98a"))

func set_skill(s: String) -> void:
	skill = s
	_col = color_for(s)
	var st = StyleBoxFlat.new()
	st.bg_color = _base_col if s != "" else Color(0.08, 0.07, 0.1, 0.55)
	st.border_color = _col if s != "" else Color(0.35, 0.33, 0.4, 0.6)
	st.set_border_width_all(5 if key == "attack" else 4)
	st.set_corner_radius_all(int(_size / 2))
	st.shadow_color = Color(_col, 0.4) if s != "" else Color(0, 0, 0, 0.3)
	st.shadow_size = 8
	st.anti_aliasing = true
	if UiTheme.high_contrast():
		st.bg_color = Color(0, 0, 0, 0.95)
		st.set_border_width_all(6)
	_bg.add_theme_stylebox_override("panel", st)
	var ic = icon_name_for(s)
	_icon.texture = UiTheme.icon(ic) if ic != "" else UiTheme.icon("plus")
	_icon.modulate = _col.lightened(0.3) if s != "" else Color(0.5, 0.48, 0.56, 0.45)

func update_state(p: Player) -> void:
	if skill == "" or p == null:
		_sweep.value = 0
		_cd.text = ""
		_badge.text = ""
		return
	if skill == "__potion":
		_badge.text = str(p.ch.potions)
		var ready = p.ch.potions > 0
		var left_p = max(0.0, float(p.get("potion_ready_at")) - p.time_now()) if p.get("potion_ready_at") != null else 0.0
		_sweep.value = clampf(left_p / 1.0, 0.0, 1.0)
		modulate = Color(1, 1, 1, 1) if ready else Color(0.5, 0.5, 0.5, 0.8)
		return
	var left = p.cooldown_left(skill)
	var total = 2.0 if skill == "__dodge" else p.cooldown_total(Content.get_rec("skills", skill))
	_sweep.value = left / total if total > 0 else 0.0
	_cd.text = ("%.1f" % left) if left > 0.05 and left < 10 else (str(int(left)) if left >= 10 else "")
	# Ready pop: brief scale-up when a cooldown finishes
	if _was_cd and left <= 0.0:
		_ready_flash = 0.25
		var t = create_tween()
		t.tween_property(self, "scale", Vector2(1.08, 1.08), 0.08)
		t.tween_property(self, "scale", Vector2.ONE, 0.12)
	_was_cd = left > 0.0
	if skill != "__dodge":
		var cost = float(Content.get_rec("skills", skill).get("cost", 0))
		modulate = Color(1, 1, 1, 1) if p.resource >= cost else Color(0.55, 0.62, 1.0, 0.85)
		# mastery ready → sparkle badge (checked twice a second)
		_ready_flash -= 0.016
		if Engine.get_process_frames() % 30 != 0:
			return
		var mp = UiTheme.api_call("SkillMastery", "xp_progress", [p.ch, skill], {})
		_badge.text = "✦" if (mp is Dictionary and bool(mp.get("ready", false)) and bool(mp.get("can_upgrade", false))) else ""
		_badge.add_theme_color_override("font_color", UiTheme.GOLD)

func set_pressed_look(on: bool) -> void:
	pivot_offset = Vector2(_size, _size) * 0.5
	var t = create_tween()
	t.tween_property(self, "scale", Vector2.ONE * (0.9 if on else 1.0), 0.06 if on else 0.09)
	if on:
		UiTheme.haptic(10)
	_aim.visible = false

func show_aim(v: Vector2) -> void:
	_aim.visible = v.length() > 0.1
	_aim.position = Vector2(_size, _size) * 0.5 + v.limit_length(1.0) * _size * 0.6 - Vector2(11, 11)

func shake() -> void:
	var t = create_tween()
	var p = position
	t.tween_property(self, "position", p + Vector2(4, 0), 0.03)
	t.tween_property(self, "position", p - Vector2(4, 0), 0.05)
	t.tween_property(self, "position", p + Vector2(3, 0), 0.04)
	t.tween_property(self, "position", p, 0.04)
