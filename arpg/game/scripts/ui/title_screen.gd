extends Control
## Title flow: animated title with the five heroes as live 3D previews on pedestals →
## continue list (class / level / tier) or New Hero → class cards (role icon, difficulty stars) →
## name → Last Flame (locked until the story is finished once, or unlocked by a parent) → Simple mode.

var main: Node
var page = "home"
var _class = "lanternbearer"
var _name_edit: LineEdit
var _hardcore = false
var _simple = false
var _preview: HeroPreview
var _layer: Control
var _cards = {}
var _desc_box: VBoxContainer
var _embers: CPUParticles2D
var _title_box: Control
var _overlay: Control

const ORDER := ["lanternbearer", "bellstriker", "stargazer", "stitcher", "roofrunner"]
## UI-side role data (content may override with classes[].role / .role_name / .difficulty).
const ROLE := {"lanternbearer": ["tank", "Guardian", 1], "bellstriker": ["berserker", "Berserker", 1],
	"stargazer": ["caster", "Star mage", 2], "stitcher": ["summoner", "Doll maker", 3], "roofrunner": ["assassin", "Trickster", 3]}
const NAMES := ["Ember", "Wisp", "Tallow", "Pip", "Moth", "Cinder", "Bramble", "Nettle", "Sprig", "Flick", "Hazel", "Quill", "Rook", "Tansy"]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.theme()
	_build_background()
	_preview = HeroPreview.new()
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview.camera_distance = 9.6
	_preview.camera_height = 2.3
	_preview.look_height = 1.25
	_preview.fov = 34.0
	add_child(_preview)
	var classes = _class_ids()
	for i in classes.size():
		var x = (i - (classes.size() - 1) / 2.0) * 1.9
		var a = _preview.add_hero(classes[i], null, x)
		_preview.heroes[i].root.position.z = -absf(i - (classes.size() - 1) / 2.0) * 0.55
		a.rotation.y = deg_to_rad(-x * 6.0)
	_preview.hero_tapped.connect(func(i):
		if page == "create":
			_select(_class_ids()[i])
		else:
			_preview.cheer(i))
	_layer = Control.new()
	_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)
	Sfx.play_music("title")
	if main and main.get("args") and main.args.get("title-page", "") == "create":
		_show_create()
	else:
		_show_home()

func _class_ids() -> Array:
	var out = []
	for id in ORDER:
		if Content.has_rec("classes", id):
			out.append(id)
	for c in Content.all("classes"):
		if not out.has(c.id) and not c.get("hidden", false):
			out.append(c.id)
	return out

func _build_background() -> void:
	var bg = TextureRect.new()
	var g = Gradient.new()
	g.set_color(0, Color("#2a1c24"))
	g.set_color(1, Color("#050409"))
	var gt = GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.62)
	gt.fill_to = Vector2(1.1, 0.0)
	gt.width = 256
	gt.height = 256
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# Warm floor glow where the heroes stand
	var glow = TextureRect.new()
	var g2 = Gradient.new()
	g2.set_color(0, Color(1.0, 0.6, 0.25, 0.28))
	g2.set_color(1, Color(1.0, 0.5, 0.2, 0.0))
	var gt2 = GradientTexture2D.new()
	gt2.gradient = g2
	gt2.fill = GradientTexture2D.FILL_RADIAL
	gt2.fill_from = Vector2(0.5, 0.5)
	gt2.fill_to = Vector2(0.5, 0.0)
	glow.texture = gt2
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)
	glow.anchor_left = 0.0
	glow.anchor_right = 1.0
	glow.anchor_top = 0.45
	glow.anchor_bottom = 1.0
	# Rising embers
	_embers = CPUParticles2D.new()
	_embers.amount = 36
	_embers.lifetime = 7.0
	_embers.preprocess = 7.0
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_embers.emission_rect_extents = Vector2(900, 10)
	_embers.direction = Vector2(0, -1)
	_embers.spread = 20
	_embers.gravity = Vector2(0, -6)
	_embers.initial_velocity_min = 18
	_embers.initial_velocity_max = 50
	_embers.scale_amount_min = 1.5
	_embers.scale_amount_max = 4.0
	var cr = Gradient.new()
	cr.set_color(0, Color(1, 0.75, 0.35, 0.0))
	cr.add_point(0.2, Color(1, 0.7, 0.3, 0.9))
	cr.set_color(cr.get_point_count() - 1, Color(1, 0.4, 0.1, 0.0))
	_embers.color_ramp = cr
	add_child(_embers)
	resized.connect(func(): _embers.position = Vector2(size.x * 0.5, size.y + 10))
	_embers.position = Vector2(get_viewport_rect().size.x * 0.5, get_viewport_rect().size.y + 10)

func _clear() -> void:
	for c in _layer.get_children():
		c.queue_free()

func _big_title(parent: Control, size := 92) -> void:
	var t = UiTheme.label("WICKWRIGHT", size, UiTheme.GOLD, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_outline_color", Color("#3a1400"))
	t.add_theme_constant_override("outline_size", 16)
	t.add_theme_color_override("font_shadow_color", Color(1.0, 0.55, 0.15, 0.55))
	t.add_theme_constant_override("shadow_outline_size", 28)
	t.add_theme_constant_override("shadow_offset_x", 0)
	t.add_theme_constant_override("shadow_offset_y", 0)
	parent.add_child(t)
	var s = UiTheme.label("Carry the Light", 30, UiTheme.EMBER, true)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(s)
	# gentle breathing glow
	var tw = t.create_tween().set_loops()
	tw.tween_property(t, "modulate", Color(1.12, 1.05, 0.95), 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(t, "modulate", Color(1, 1, 1), 1.6).set_trans(Tween.TRANS_SINE)

# ------------------------------------------------------------------ home
func _show_home() -> void:
	page = "home"
	_clear()
	_preview.set_focus(-1, false)
	_preview.offset_top = 150
	_preview.offset_bottom = 0
	_preview.offset_right = -440 if Game.list_saves().size() > 0 else 0
	_preview.camera_distance = 11.5
	_preview.look_height = 1.1
	_preview.camera_height = 2.3
	_preview.fov = 34.0
	_preview._update_camera()
	var top = VBoxContainer.new()
	top.add_theme_constant_override("separation", -6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(top)
	UiTheme.place(top, 0.5, 0.0, -420, 18, 840, 150)
	_big_title(top)
	# Continue list (right) or first-time call to action
	var saves = Game.list_saves()
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.05, 0.04, 0.08, 0.86), UiTheme.PANEL_EDGE, 18, 2))
	_layer.add_child(panel)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var shown = saves.slice(0, 3)
	if shown.size() > 0:
		v.add_child(UiTheme.label("Continue", 24, UiTheme.GOLD, true))
		for d in shown:
			v.add_child(_save_card(d))
	var nb = UiTheme.icon_button("plus", "New Hero", _show_create, Vector2(420, 84), UiTheme.GOLD, true, 28)
	nb.add_theme_stylebox_override("normal", UiTheme.panel_style(Color(0.32, 0.16, 0.05, 0.96), UiTheme.EMBER, 16, 3))
	nb.add_theme_stylebox_override("hover", UiTheme.panel_style(Color(0.42, 0.22, 0.07, 0.98), UiTheme.GOLD, 16, 3))
	v.add_child(nb)
	var h = 84 + 44 + shown.size() * 96 + 40
	UiTheme.place(panel, 1.0, 1.0, -480, -h - 40, 452, h)
	# Settings / credits (left-bottom)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_layer.add_child(row)
	UiTheme.place(row, 0.0, 1.0, 32, -128, 330, 96)
	row.add_child(UiTheme.icon_button("settings", "Settings", func(): _open_overlay("settings"), Vector2(104, 96), UiTheme.GOLD))
	row.add_child(UiTheme.icon_button("credits", "Credits", func(): _open_overlay("credits"), Vector2(104, 96), UiTheme.GOLD))
	row.add_child(UiTheme.icon_button("trophy", "Embers", func(): _open_overlay("hall"), Vector2(104, 96), UiTheme.GOLD))
	var ver = UiTheme.label("Build %s · offline · no ads" % (str(ProjectSettings.get_setting("application/config/version", "")) if str(ProjectSettings.get_setting("application/config/version", "")) != "" else "0.1"), 14, Color(UiTheme.MUTED, 0.7))
	_layer.add_child(ver)
	UiTheme.place(ver, 0.0, 1.0, 34, -30, 400, 22)
	# Heroes greet
	for i in _preview.heroes.size():
		var tw = create_tween()
		tw.tween_interval(0.4 + i * 0.25)
		tw.tween_callback(func(): _preview.cheer(i))

func _save_card(d: Dictionary) -> Control:
	var cls = Content.get_rec("classes", str(d.get("class_id", "")))
	var col = Color(cls.get("color", "#ffd27a"))
	var dead = bool(d.get("dead", false))
	var b = Button.new()
	b.custom_minimum_size = Vector2(420, 86)
	b.add_theme_stylebox_override("normal", UiTheme.card_style(col))
	b.add_theme_stylebox_override("hover", UiTheme.card_style(col, true))
	b.add_theme_stylebox_override("pressed", UiTheme.card_style(col, true))
	b.disabled = dead
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 12
	h.offset_right = -12
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var role = _role(str(d.get("class_id", "")))
	h.add_child(UiTheme.icon_rect(role[0], 58, col if not dead else UiTheme.LOCKED))
	var v = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", -2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var nm = UiTheme.label(str(d.get("name", "?")), 26, UiTheme.TEXT, true)
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(nm)
	var tier = Content.get_rec("difficulties", str(d.get("difficulty", "twilight"))).get("name", "Twilight")
	v.add_child(UiTheme.label("Lv %d %s · %s" % [int(d.get("level", 1)), cls.get("name", ""), tier], 18, UiTheme.MUTED))
	if bool(d.get("hardcore", false)):
		h.add_child(UiTheme.icon_rect("hardcore", 40, UiTheme.EMBER if not dead else UiTheme.LOCKED))
	var lvl = UiTheme.label(str(int(d.get("level", 1))), 34, UiTheme.GOLD)
	h.add_child(lvl)
	UiTheme.juice(b)
	b.pressed.connect(func():
		Sfx.play("ui_click", -6.0)
		var ch = Game.load_character(str(d.id))
		if ch and not ch.dead:
			main.play_character(ch))
	return b

func _role(class_id: String) -> Array:
	var c = Content.get_rec("classes", class_id)
	var r: Array = ROLE.get(class_id, ["hero", "Hero", 2])
	return [str(c.get("role_icon", r[0])), str(c.get("role_name", r[1])), int(c.get("difficulty", r[2]))]

# ------------------------------------------------------------------ create
func _show_create() -> void:
	page = "create"
	_clear()
	_cards.clear()
	_preview.offset_top = 0
	_preview.offset_bottom = -280
	_preview.offset_right = 0
	_preview.camera_distance = 8.4
	_preview.look_height = 1.0
	_preview.camera_height = 2.0
	_preview.fov = 36.0
	_preview._update_camera()
	var back = UiTheme.icon_button("back", "", _show_home, Vector2(96, 84), UiTheme.GOLD)
	_layer.add_child(back)
	UiTheme.place(back, 0.0, 0.0, 28, 24, 96, 84)
	var t = UiTheme.label("Choose your Wickbearer", 38, UiTheme.GOLD, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layer.add_child(t)
	UiTheme.place(t, 0.5, 0.0, -400, 30, 800, 56)
	# Class cards row
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_layer.add_child(row)
	UiTheme.place(row, 0.5, 1.0, -620, -272, 1240, 118)
	for id in _class_ids():
		var c = _class_card(id)
		row.add_child(c)
		_cards[id] = c
	# Bottom bar: description | name | Last Flame | Simple | Begin
	var bar = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	_layer.add_child(bar)
	UiTheme.place(bar, 0.5, 1.0, -620, -142, 1240, 118)
	_desc_box = VBoxContainer.new()
	_desc_box.custom_minimum_size = Vector2(430, 0)
	_desc_box.add_theme_constant_override("separation", 2)
	var dp = PanelContainer.new()
	dp.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.05, 0.04, 0.08, 0.9), UiTheme.PANEL_EDGE, 14, 2))
	dp.add_child(_desc_box)
	dp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(dp)
	var mid = VBoxContainer.new()
	mid.add_theme_constant_override("separation", 6)
	bar.add_child(mid)
	var nrow = HBoxContainer.new()
	nrow.add_theme_constant_override("separation", 6)
	mid.add_child(nrow)
	_name_edit = LineEdit.new()
	_name_edit.text = NAMES.pick_random()
	_name_edit.custom_minimum_size = Vector2(250, 58)
	_name_edit.max_length = 16
	_name_edit.placeholder_text = "Hero name"
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	nrow.add_child(_name_edit)
	nrow.add_child(UiTheme.icon_button("spark", "", func(): _name_edit.text = NAMES.pick_random(), Vector2(62, 58), UiTheme.GOLD))
	var toggles = HBoxContainer.new()
	toggles.add_theme_constant_override("separation", 6)
	mid.add_child(toggles)
	toggles.add_child(_toggle_simple())
	var hc = _toggle_hardcore()
	if hc:
		toggles.add_child(hc)
	var begin = UiTheme.icon_button("next", "Begin", _begin, Vector2(210, 118), UiTheme.GOLD, false, 26)
	begin.add_theme_stylebox_override("normal", UiTheme.panel_style(Color(0.34, 0.17, 0.05, 0.97), UiTheme.EMBER, 16, 3))
	begin.add_theme_stylebox_override("hover", UiTheme.panel_style(Color(0.44, 0.22, 0.07, 0.98), UiTheme.GOLD, 16, 3))
	bar.add_child(begin)
	_select(_class, false)

func _class_card(id: String) -> Button:
	var c = Content.get_rec("classes", id)
	var col = Color(c.get("color", "#ffd27a"))
	var role = _role(id)
	var b = Button.new()
	b.custom_minimum_size = Vector2(236, 118)
	b.add_theme_stylebox_override("normal", UiTheme.card_style(col))
	b.add_theme_stylebox_override("hover", UiTheme.card_style(col.lightened(0.1)))
	var v = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 6
	v.offset_bottom = -6
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	h.add_child(UiTheme.icon_rect(role[0], 52, col))
	var nv = VBoxContainer.new()
	nv.add_theme_constant_override("separation", -4)
	nv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(nv)
	var nm = UiTheme.label(str(c.get("name", id)), 22, col.lightened(0.3), true)
	nm.clip_text = true
	nm.custom_minimum_size = Vector2(150, 0)
	nv.add_child(nm)
	nv.add_child(UiTheme.label(role[1], 18, UiTheme.MUTED))
	var sr = HBoxContainer.new()
	sr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sr.add_theme_constant_override("separation", 6)
	v.add_child(sr)
	sr.add_child(UiTheme.stars(role[2], 3, 24))
	var res = UiTheme.label(str(c.get("resource_name", "")), 17, col)
	res.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sr.add_child(res)
	UiTheme.juice(b)
	b.pressed.connect(func(): _select(id))
	return b

func _select(id: String, cheer := true) -> void:
	_class = id
	var ids = _class_ids()
	var idx = ids.find(id)
	_preview.set_focus(idx, true)
	if cheer:
		_preview.cheer(idx)
		Sfx.play("ui_click", -4.0)
	for k in _cards:
		var col = Color(Content.get_rec("classes", k).get("color", "#ffd27a"))
		_cards[k].add_theme_stylebox_override("normal", UiTheme.card_style(col, k == id))
		_cards[k].add_theme_stylebox_override("hover", UiTheme.card_style(col, k == id))
	var c = Content.get_rec("classes", id)
	var col2 = Color(c.get("color", "#ffd27a"))
	ScreenBase.clear(_desc_box)
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	_desc_box.add_child(head)
	head.add_child(UiTheme.label(str(c.get("name", "")), 24, col2, true))
	var tag = UiTheme.label("— " + str(c.get("tagline", "")), 18, UiTheme.MUTED)
	tag.clip_text = true
	tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tag)
	var d = UiTheme.label(str(c.get("desc", "")), 17, UiTheme.TEXT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.max_lines_visible = 3
	d.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_desc_box.add_child(d)

func _toggle_simple() -> Button:
	_simple = bool(Settings.get_value("simple_mode", false))
	var b = UiTheme.icon_button("check" if _simple else "star", "Play it easy", func(): pass, Vector2(160, 52), UiTheme.GOOD if _simple else UiTheme.MUTED, true, 16)
	b.tooltip_text = "Simple mode: auto-attack, auto-equip upgrades (with Undo) and auto-spend points. You can change it any time."
	b.pressed.connect(func():
		_simple = not _simple
		(b.find_child("Icon", true, false) as TextureRect).texture = UiTheme.icon("check" if _simple else "star")
		(b.find_child("Icon", true, false) as TextureRect).modulate = UiTheme.GOOD if _simple else UiTheme.MUTED)
	return b

## Last Flame: hidden by parents, locked until the story is finished once (or unlocked by a parent).
func _toggle_hardcore() -> Button:
	if bool(Settings.get_value("parent_hide_hardcore", false)):
		return null
	var unlocked = _story_done_any() or bool(Settings.get_value("parent_allow_hardcore", false))
	_hardcore = false
	var b = UiTheme.icon_button("lock" if not unlocked else "hardcore", "Last Flame", func(): pass, Vector2(160, 52), UiTheme.LOCKED if not unlocked else UiTheme.MUTED, true, 16)
	if not unlocked:
		b.tooltip_text = "Finish the story once to unlock Last Flame (one life)."
		b.pressed.connect(func():
			UiTheme.deny(b)
			_toast("Finish the story once to unlock Last Flame", UiTheme.EMBER))
		return b
	b.pressed.connect(func():
		if _hardcore:
			_hardcore = false
			(b.find_child("Icon", true, false) as TextureRect).modulate = UiTheme.MUTED
		else:
			_confirm_hardcore(func():
				_hardcore = true
				(b.find_child("Icon", true, false) as TextureRect).modulate = UiTheme.EMBER))
	return b

func _confirm_hardcore(on_yes: Callable) -> void:
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.1, 0.05, 0.04, 0.98), UiTheme.EMBER, 18, 3))
	dim.add_child(p)
	UiTheme.place(p, 0.5, 0.5, -330, -210, 660, 420)
	var v = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var icons = HBoxContainer.new()
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(icons)
	icons.add_child(UiTheme.icon_rect("hardcore", 96, UiTheme.EMBER))
	icons.add_child(UiTheme.icon_rect("trophy", 64, UiTheme.GOLD))
	var t = UiTheme.label("Last Flame: one life", 32, UiTheme.EMBER, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var d = UiTheme.label("If this hero falls, they cannot come back.\nThey will rest in the Hall of Embers — or carry the ember on as a normal hero.", 20)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(d)
	var h = HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	h.add_child(UiTheme.button("Keep it safe", func(): dim.queue_free(), 22, Vector2(220, 80)))
	h.add_child(UiTheme.hold_button("Hold: I'm sure", 1.2, func():
		dim.queue_free()
		on_yes.call(), Vector2(260, 80), UiTheme.EMBER, "hardcore"))

func _begin() -> void:
	var nm = _name_edit.text.strip_edges()
	if nm == "":
		nm = "Wickbearer"
	Settings.set_value("simple_mode", _simple)
	if _simple:
		Settings.set_value("auto_attack", true)
	main.new_character(nm, _class, _hardcore)

func _story_done_any() -> bool:
	for d in Game.list_saves():
		for k in d.get("discoveries", []):
			if str(k).begins_with("story_complete:"):
				return true
	return false

func _toast(text: String, col: Color) -> void:
	var l = UiTheme.label(text, 24, col, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	UiTheme.place(l, 0.5, 0.5, -400, -40, 800, 50)
	var t = l.create_tween()
	t.tween_interval(1.8)
	t.tween_property(l, "modulate:a", 0.0, 0.5)
	t.tween_callback(l.queue_free)

## Settings / credits / Hall of Embers over the title (no session needed).
func _open_overlay(which: String) -> void:
	var path = "res://scripts/ui/%s_screen.gd" % which
	if not ResourceLoader.exists(path):
		_toast("Coming soon", UiTheme.MUTED)
		return
	var s = load(path).new()
	s.set("screen_id", which)
	add_child(s)
	_overlay = s
	if s.has_signal("closed"):
		s.closed.connect(func():
			theme = UiTheme.theme()
			if page == "home":
				_show_home())
