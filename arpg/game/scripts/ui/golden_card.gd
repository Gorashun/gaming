class_name GoldenCard
extends Control
## Legendary+ "golden moment" card (UI_UX §10, PLAYER_WELFARE §2):
## the TRUE rarity (colour, emblem, rays) shows from the first frame — no reveal, no near-miss.
## Card slides in 300 ms, item turns on a pedestal, name types on in 400 ms, one highlight stat,
## big Equip + Later. Skippable with one tap anywhere from 500 ms. One card per drop, never chained.

signal done(equip: bool)

var item: Dictionary
var _col: Color
var _rays: Control
var _t = 0.0
var _skippable = false
var _viewer: SubViewportContainer
var _prop: Node3D

func setup(it: Dictionary) -> void:
	item = it

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiTheme.theme()
	_col = UiTheme.rarity_color(item.get("rarity", "legendary"))
	var dim = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.02, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_rays = Control.new()
	_rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.draw.connect(_draw_rays)
	add_child(_rays)
	var card = PanelContainer.new()
	var st = UiTheme.panel_style(Color(_col.darkened(0.88), 0.98), _col, 22, 4)
	st.shadow_color = Color(_col, 0.55)
	st.shadow_size = 26
	card.add_theme_stylebox_override("panel", st)
	add_child(card)
	UiTheme.place(card, 0.5, 0.5, -300, -300, 600, 600)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(v)
	# Rarity header: emblem shape + name (true rarity, frame 1)
	var hdr = HBoxContainer.new()
	hdr.alignment = BoxContainer.ALIGNMENT_CENTER
	hdr.add_theme_constant_override("separation", 10)
	v.add_child(hdr)
	var emb = Control.new()
	emb.custom_minimum_size = Vector2(44, 44)
	var shape = UiTheme.rarity_shape(item.get("rarity", "legendary"))
	emb.draw.connect(func(): UiTheme.draw_shape(emb, shape, Rect2(Vector2.ZERO, emb.size), _col, Color(0.1, 0.03, 0), 2.5))
	hdr.add_child(emb)
	var rl = UiTheme.label(UiTheme.rarity_name(item.get("rarity", "")).to_upper() + "!", 40, _col.lightened(0.15), true)
	rl.add_theme_constant_override("outline_size", 10)
	hdr.add_child(rl)
	# Turning item
	_viewer = _make_viewer()
	v.add_child(_viewer)
	var nm = UiTheme.label(str(item.get("name", "")), 34, _col.lightened(0.35), true)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(540, 0)
	nm.visible_ratio = 0.0
	v.add_child(nm)
	var base = Content.get_rec("item_bases", str(item.get("base", "")))
	var sub = UiTheme.label("%s  ·  item level %d" % [base.get("type_name", str(item.get("slot", "")).capitalize()), int(item.get("ilvl", 1))], 18, UiTheme.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var hl = _highlight()
	if hl != "":
		var hp = PanelContainer.new()
		hp.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.1, 0.06, 0.02, 0.9), _col.darkened(0.3), 12, 2))
		hp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var hl_l = UiTheme.label(hl, 21, Color(1.0, 0.78, 0.4))
		hl_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hl_l.custom_minimum_size = Vector2(500, 0)
		hl_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp.add_child(hl_l)
		v.add_child(hp)
	var ch = Game.character
	if ch:
		var d = InventoryOps.upgrade_delta(ch, item) if InventoryOps.can_equip(ch, item) else 0.0
		if absf(d) >= 1:
			var pl = UiTheme.label(("Power %+d " % int(d)) + ("▲" if d > 0 else "▼"), 24, UiTheme.GOOD if d > 0 else UiTheme.BAD, true)
			pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(pl)
	var btns = HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 18)
	v.add_child(btns)
	var eq = UiTheme.icon_button("check", "Equip", func(): _finish(true), Vector2(210, 88), UiTheme.GOOD, true, 26)
	eq.add_theme_stylebox_override("normal", UiTheme.panel_style(Color(0.1, 0.25, 0.12, 0.97), UiTheme.GOOD, 16, 3))
	btns.add_child(eq)
	btns.add_child(UiTheme.button("Later", func(): _finish(false), 24, Vector2(160, 88)))
	# Slide in 300 ms; name types on 400 ms
	card.pivot_offset = Vector2(300, 300)
	card.position.y += 80
	card.modulate.a = 0.0
	var tw = create_tween().set_parallel()
	tw.tween_property(card, "position:y", card.position.y - 80, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.2)
	var tw2 = create_tween()
	tw2.tween_interval(0.25)
	tw2.tween_property(nm, "visible_ratio", 1.0, 0.4)
	Sfx.play("golden_moment")
	UiTheme.haptic(30, 0.8)

func _highlight() -> String:
	if item.has("power"):
		return str(Content.get_rec("powers", str(item.power)).get("desc", ""))
	var affs: Array = item.get("affixes", [])
	if affs.size() > 0:
		var best = affs[0]
		for a in affs:
			if a.get("greater", false):
				best = a
		return Items.stat_label(best.stat, float(best.value))
	return ""

func _make_viewer() -> SubViewportContainer:
	var c = SubViewportContainer.new()
	c.stretch = true
	c.custom_minimum_size = Vector2(560, 210)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp = SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	c.add_child(vp)
	var model = ItemIcons.model_for(item)
	var we = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.65, 0.75)
	we.environment = e
	vp.add_child(we)
	var key = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -30, 0)
	key.light_energy = 1.3
	vp.add_child(key)
	var rim = OmniLight3D.new()
	rim.light_color = _col
	rim.light_energy = 3.0
	rim.omni_range = 4.0
	rim.position = Vector3(0, 0.6, -1.2)
	vp.add_child(rim)
	var cam = Camera3D.new()
	cam.fov = 30
	cam.position = Vector3(0, 0.2, 3.2)
	vp.add_child(cam)
	_prop = Node3D.new()
	vp.add_child(_prop)
	if model != "":
		var n: Node3D = load(model).instantiate()
		_prop.add_child(n)
		var aabb = _aabb(n)
		var s = 1.5 / max(0.01, max(aabb.size.x, max(aabb.size.y, aabb.size.z)))
		n.scale = Vector3.ONE * s
		n.position = -aabb.get_center() * s
		_prop.rotation_degrees = Vector3(0, 0, -30)
	else:
		# Vector icon on a quad for armour/jewellery
		var q = MeshInstance3D.new()
		var qm = QuadMesh.new()
		qm.size = Vector2(1.5, 1.5)
		q.mesh = qm
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = UiTheme.icon(ItemIcons.glyph_for(item))
		m.albedo_color = _col.lightened(0.3)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		q.material_override = m
		_prop.add_child(q)
	return c

func _aabb(n: Node3D) -> AABB:
	var out = AABB()
	var first = true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).mesh == null:
			continue
		var b = (mi as MeshInstance3D).transform * (mi as MeshInstance3D).mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out if not first else AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)

func _process(delta: float) -> void:
	_t += delta
	if _t > 0.5:
		_skippable = true
	if _prop:
		_prop.rotation.y += delta * 1.4
	_rays.queue_redraw()

func _draw_rays() -> void:
	var c = size * 0.5 + Vector2(0, -60)
	var n = 14
	var reduced = bool(Settings.get_value("reduced_motion", false))
	var rot = 0.0 if reduced else _t * 0.35
	var r = size.length()
	for i in n:
		var a = rot + TAU * i / n
		var w = 0.09
		var pts = PackedVector2Array([c, c + Vector2(cos(a - w), sin(a - w)) * r, c + Vector2(cos(a + w), sin(a + w)) * r])
		var cols = PackedColorArray([Color(_col, 0.34), Color(_col, 0.0), Color(_col, 0.0)])
		_rays.draw_polygon(pts, cols)
	_rays.draw_circle(c, 150, Color(_col, 0.12))
	_rays.draw_circle(c, 90, Color(_col.lightened(0.4), 0.12))

func _gui_input(event: InputEvent) -> void:
	if not _skippable:
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_finish(false)
		accept_event()

func _finish(equip: bool) -> void:
	if not is_inside_tree():
		return
	done.emit(equip)
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
