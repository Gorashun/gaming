class_name Hud
extends Control
## In-game HUD per UI_UX.md §2, inside the safe area (min 24 px, cut-outs respected):
##  top-left   portrait (tap → Hero) + level badge, life / resource / XP (4 sub-ticks, rested glow),
##             gold, buffs, pet portrait, mount + Homeward Wick quick buttons, quest tracker, pickup feed
##  top-centre boss bar (name, phase pips, damage trail), objective/zone toast, Hushfall event tracker
##  top-right  minimap (tap → Map), ☰ menu hub, Bag, Lantern meter (visible pity)
##  bottom     thumb controls (TouchControls), context interact button, channel bar
## Golden-moment card queued until no enemy within 12 m for 1.5 s. Simple mode auto-spends points.

var player: Player
var session: Node
var touch: TouchControls
var _root: Control                 # safe-area inset root
var _portrait: Button
var _lvl: Label
var _life: ProgressBar
var _life_trail: ProgressBar
var _life_lbl: Label
var _res: ProgressBar
var _res_lbl: Label
var _xp: Control
var _gold: Label
var _gold_shown = 0.0
var _buffs: HBoxContainer
var _pet_btn: Button
var _mount_btn: Button
var _hearth_btn: Button
var _hearth_sweep: TextureProgressBar
var _skill_chip: Button
var _zone: Label
var _boss_box: PanelContainer
var _boss_bar: ProgressBar
var _boss_trail: ProgressBar
var _boss_name: Label
var _boss_pips: HBoxContainer
var _feed: VBoxContainer
var _quests: VBoxContainer
var _event_box: PanelContainer
var _event_name: Label
var _event_bar: ProgressBar
var _event_id = ""
var _edge_arrow: Control
var _minimap: Minimap
var _lantern: Button
var _lantern_fill: ProgressBar
var _interact: Button
var _interact_icon: TextureRect
var _interact_lbl: Label
var _channel: ProgressBar
var _golden_queue = []
var _golden_open = false
var _calm_t = 0.0
var _boss_phases = 1
var _tick_flash = 0.0
var _last_sub = -1
var _slow_t = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.theme()
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	_build()
	Events.health_changed.connect(_on_health)
	Events.resource_changed.connect(_on_resource)
	# Object-bound callables (not lambdas) so the global signals drop this HUD when it is freed on travel
	Events.xp_gained.connect(_update_xp.unbind(1))
	Events.level_up.connect(_on_level_up)
	Events.toast.connect(toast)
	Events.boss_spawned.connect(_on_boss)
	Events.boss_defeated.connect(_hide_boss.unbind(1))
	Events.golden_moment.connect(_queue_golden)
	Events.item_picked_up.connect(_on_pickup)
	_connect_opt("boss_phase", func(_b, ph): _on_boss_phase(ph))
	_connect_opt("skill_mastery_ready", func(sid): toast("%s can be mastered!" % Content.get_rec("skills", sid).get("name", "A skill"), UiTheme.GOLD, "skills"))
	_connect_opt("skill_mastery_up", func(sid, r): toast("%s mastery %d!" % [Content.get_rec("skills", sid).get("name", ""), r], UiTheme.GOLD, "star"))
	_connect_opt("proficiency_up", func(t, l): toast("%s proficiency %d" % [str(t).capitalize(), l], Color("#ffcf80"), t if UiTheme.has_icon(t) else "sword"))
	_connect_opt("pet_acquired", func(pid): toast("New pet: %s!" % _pet_name(pid), Color("#ffb3de"), "pets"))
	_connect_opt("pet_level_up", func(pid, l): toast("%s reached level %d" % [_pet_name(pid), l], Color("#ffb3de"), "paw"))
	_connect_opt("mount_changed", func(_m): _refresh_quick())
	_connect_opt("channel_progress", _on_channel)
	_connect_opt("quest_accepted", func(_q): _refresh_quests())
	_connect_opt("quest_updated", func(_q, _p, _c): _refresh_quests())
	_connect_opt("quest_ready", func(qid): _refresh_quests(); toast("Quest ready: " + str(Content.get_rec("quests", qid).get("name", "")), UiTheme.GOLD, "quests"))
	_connect_opt("quest_completed", func(_q): _refresh_quests())
	_connect_opt("world_event_started", _on_event_started)
	_connect_opt("world_event_stage", _on_event_stage)
	_connect_opt("world_event_completed", _on_event_completed)
	_connect_opt("codex_updated", func(_e): toast("Codex of Light updated", Color("#ffe39a"), "trophy"))
	_connect_opt("story_dialogue", _on_story)
	_connect_opt("main_quest_updated", func(_c, _o, _p, _n): _refresh_quests())
	_connect_opt("main_quest_chapter_completed", func(cid): _refresh_quests(); _banner("Chapter complete!", UiTheme.GOLD))
	_connect_opt("deed_tier_completed", _on_deed)
	_connect_opt("item_upgraded", func(it): toast("%s is now +%d" % [it.get("name", "Item"), int(it.get("upgrade", 0))], UiTheme.GOLD, "upgrade"))

func _connect_opt(sig: String, cb: Callable) -> void:
	if Events.has_signal(sig):
		Events.connect(sig, cb)

func _apply_safe_area() -> void:
	var ins = UiTheme.safe_insets(get_viewport())
	_root.offset_left = ins.x
	_root.offset_top = ins.y
	_root.offset_right = -ins.z
	_root.offset_bottom = -ins.w

func _block(c: Control) -> void:
	c.add_to_group("hud_blocker")

func _round_style(col: Color, bg := Color(0.08, 0.06, 0.11, 0.9), border := 3) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = col
	s.set_border_width_all(border)
	s.set_corner_radius_all(60)
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 4
	s.anti_aliasing = true
	return s

func _round_button(icon_name: String, sz: float, col: Color, cb: Callable) -> Button:
	var b = Button.new()
	b.custom_minimum_size = Vector2(sz, sz)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _round_style(col))
	b.add_theme_stylebox_override("hover", _round_style(col.lightened(0.3)))
	b.add_theme_stylebox_override("pressed", _round_style(UiTheme.EMBER))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ic = UiTheme.icon_rect(icon_name, sz * 0.58, col.lightened(0.2))
	ic.name = "Icon"
	UiTheme.place(ic, 0, 0, sz * 0.21, sz * 0.21, sz * 0.58, sz * 0.58)
	b.add_child(ic)
	b.pressed.connect(func():
		Sfx.play("ui_click", -6.0, 0.02)
		cb.call())
	UiTheme.juice(b)
	_block(b)
	return b

# ------------------------------------------------------------------ build
func _build() -> void:
	# --- Portrait + vitals (top-left)
	_portrait = _round_button("hero", 96, UiTheme.GOLD, func(): _open("character"))
	_root.add_child(_portrait)
	UiTheme.place(_portrait, 0, 0, 0, 0, 96, 96)
	var badge = PanelContainer.new()
	var bs = _round_style(UiTheme.GOLD, Color(0.25, 0.12, 0.02, 0.98), 2)
	bs.content_margin_left = 6
	bs.content_margin_right = 6
	badge.add_theme_stylebox_override("panel", bs)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.add_child(badge)
	UiTheme.place(badge, 1.0, 1.0, -40, -34, 44, 34)
	_lvl = UiTheme.label("1", 20, UiTheme.GOLD)
	_lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(_lvl)
	var bars = VBoxContainer.new()
	bars.add_theme_constant_override("separation", 5)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bars)
	UiTheme.place(bars, 0, 0, 104, 6, 316, 90)
	var lrow = HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 4)
	lrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.add_child(lrow)
	lrow.add_child(UiTheme.icon_rect("life", 30, UiTheme.LIFE))
	var lstack = Control.new()
	lstack.custom_minimum_size = Vector2(0, 28)
	lstack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lstack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lrow.add_child(lstack)
	_life_trail = UiTheme.progress_bar(Color(1, 0.95, 0.85, 0.85), 28)
	_life_trail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lstack.add_child(_life_trail)
	_life = UiTheme.progress_bar(UiTheme.LIFE, 28, Color(0, 0, 0, 0))
	_life.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lstack.add_child(_life)
	_life_lbl = UiTheme.label("", 17)
	_life_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_life_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_life_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lstack.add_child(_life_lbl)
	var rrow = HBoxContainer.new()
	rrow.add_theme_constant_override("separation", 4)
	rrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.add_child(rrow)
	var ri = UiTheme.icon_rect("resource", 26, Color("#8fd0ff"))
	ri.name = "ResIcon"
	rrow.add_child(ri)
	_res = UiTheme.progress_bar(Color("#ffd27a"), 18)
	_res.custom_minimum_size = Vector2(250, 18)
	_res.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rrow.add_child(_res)
	_res_lbl = UiTheme.label("", 14)
	_res_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_res_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_res_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_res.add_child(_res_lbl)
	_xp = Control.new()
	_xp.custom_minimum_size = Vector2(280, 12)
	_xp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp.draw.connect(_draw_xp)
	var xrow = HBoxContainer.new()
	xrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xrow.add_theme_constant_override("separation", 4)
	bars.add_child(xrow)
	xrow.add_child(UiTheme.icon_rect("xp", 22, UiTheme.XP))
	xrow.add_child(_xp)
	# Row 2: gold, buffs
	var row2 = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(row2)
	UiTheme.place(row2, 0, 0, 0, 104, 300, 40)
	var gp = UiTheme.pill("gold", "0", UiTheme.COIN, 20)
	_gold = gp.find_child("Value", true, false)
	row2.add_child(gp)
	_buffs = HBoxContainer.new()
	_buffs.add_theme_constant_override("separation", 4)
	_buffs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row2.add_child(_buffs)
	# Skill-point chip next to the portrait (only when points are waiting)
	_skill_chip = _round_button("plus", 44, UiTheme.XP, func(): _open("skills"))
	_root.add_child(_skill_chip)
	UiTheme.place(_skill_chip, 0, 0, 0, 58, 44, 44)
	_skill_chip.visible = false
	# Quick buttons: pet, mount, Homeward Wick
	var quick = HBoxContainer.new()
	quick.add_theme_constant_override("separation", 10)
	quick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(quick)
	UiTheme.place(quick, 0, 0, 432, 0, 290, 84)
	_mount_btn = _round_button("mounts", 80, Color("#d9b27a"), _toggle_mount)
	_mount_btn.tooltip_text = "Mount"
	quick.add_child(_mount_btn)
	_hearth_btn = _round_button("hearth", 80, UiTheme.EMBER, _use_hearth)
	_hearth_btn.tooltip_text = "Homeward Wick"
	_hearth_sweep = TextureProgressBar.new()
	_hearth_sweep.fill_mode = TextureProgressBar.FILL_COUNTER_CLOCKWISE
	_hearth_sweep.texture_progress = _disc(80)
	_hearth_sweep.tint_progress = Color(0, 0, 0, 0.6)
	_hearth_sweep.max_value = 1.0
	_hearth_sweep.step = 0.001
	_hearth_sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hearth_sweep.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hearth_btn.add_child(_hearth_sweep)
	quick.add_child(_hearth_btn)
	_pet_btn = _round_button("paw", 64, Color("#ffb3de"), func(): _open("pets"))
	_pet_btn.tooltip_text = "Pet"
	quick.add_child(_pet_btn)
	# Quest tracker + pickup feed (left, under the vitals)
	_quests = VBoxContainer.new()
	_quests.add_theme_constant_override("separation", 2)
	_root.add_child(_quests)
	UiTheme.place(_quests, 0, 0, 0, 150, 330, 100)
	_quests.gui_input.connect(func(e):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			_open("quests"))
	_block(_quests)
	_feed = VBoxContainer.new()
	_feed.add_theme_constant_override("separation", 4)
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_feed)
	UiTheme.place(_feed, 0, 0, 0, 258, 440, 190)
	# --- Top centre: boss bar, zone toast, event tracker
	_boss_box = PanelContainer.new()
	var bst = UiTheme.panel_style(Color(0.06, 0.02, 0.03, 0.88), Color("#8a3a30"), 12, 2)
	bst.content_margin_top = 4
	bst.content_margin_bottom = 6
	_boss_box.add_theme_stylebox_override("panel", bst)
	_boss_box.visible = false
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_boss_box)
	UiTheme.place(_boss_box, 0.5, 0.0, -300, 100, 600, 72)
	var bv = VBoxContainer.new()
	bv.add_theme_constant_override("separation", 2)
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.add_child(bv)
	var bh = HBoxContainer.new()
	bh.add_theme_constant_override("separation", 8)
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	bh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bv.add_child(bh)
	bh.add_child(UiTheme.icon_rect("skull_soft", 26, Color("#ff9a7a")))
	_boss_name = UiTheme.label("", 22, Color("#ffb09a"), true)
	bh.add_child(_boss_name)
	_boss_pips = HBoxContainer.new()
	_boss_pips.add_theme_constant_override("separation", 3)
	_boss_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bh.add_child(_boss_pips)
	var bstack = Control.new()
	bstack.custom_minimum_size = Vector2(0, 22)
	bstack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bv.add_child(bstack)
	_boss_trail = UiTheme.progress_bar(Color(1, 0.9, 0.8, 0.9), 22)
	_boss_trail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bstack.add_child(_boss_trail)
	_boss_bar = UiTheme.progress_bar(Color("#c0303a"), 22, Color(0, 0, 0, 0))
	_boss_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bstack.add_child(_boss_bar)
	_zone = UiTheme.label("", 30, UiTheme.GOLD, true)
	_zone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone.add_theme_constant_override("outline_size", 8)
	_root.add_child(_zone)
	UiTheme.place(_zone, 0.5, 0.0, -260, 178, 520, 44)
	_event_box = PanelContainer.new()
	_event_box.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.07, 0.04, 0.12, 0.9), Color("#a878ff"), 12, 2))
	_event_box.visible = false
	_event_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_event_box)
	UiTheme.place(_event_box, 0.5, 0.0, -190, 226, 380, 64)
	var ev = VBoxContainer.new()
	ev.add_theme_constant_override("separation", 2)
	ev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_event_box.add_child(ev)
	var eh = HBoxContainer.new()
	eh.add_theme_constant_override("separation", 6)
	eh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ev.add_child(eh)
	eh.add_child(UiTheme.icon_rect("portal", 24, Color("#c9a0ff")))
	_event_name = UiTheme.label("", 20, Color("#e0ccff"), true)
	eh.add_child(_event_name)
	_event_bar = UiTheme.progress_bar(Color("#a878ff"), 12)
	ev.add_child(_event_bar)
	_edge_arrow = Control.new()
	_edge_arrow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_edge_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge_arrow.draw.connect(_draw_edge_arrow)
	add_child(_edge_arrow)
	# --- Top right: minimap, ☰, Bag, Lantern meter
	var menu_b = _round_button("menu", 88, UiTheme.GOLD, func(): _open("menu"))
	menu_b.tooltip_text = "Menu"
	_root.add_child(menu_b)
	UiTheme.place(menu_b, 1.0, 0.0, -88, 0, 88, 88)
	var bag_b = _round_button("bag", 88, UiTheme.GOLD, func(): _open("inventory"))
	bag_b.tooltip_text = "Bag"
	bag_b.name = "BagButton"
	_root.add_child(bag_b)
	UiTheme.place(bag_b, 1.0, 0.0, -88, 96, 88, 88)
	_minimap = Minimap.new()
	_minimap.tapped.connect(func(): _open("map"))
	_root.add_child(_minimap)
	UiTheme.place(_minimap, 1.0, 0.0, -88 - 10 - 190, 0, 190, 190)
	_block(_minimap)
	_lantern = Button.new()
	_lantern.focus_mode = Control.FOCUS_NONE
	for s in ["normal", "hover", "pressed", "focus"]:
		_lantern.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	_root.add_child(_lantern)
	UiTheme.place(_lantern, 1.0, 0.0, -86, 192, 84, 92)
	_block(_lantern)
	_lantern_fill = ProgressBar.new()
	_lantern_fill.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	_lantern_fill.show_percentage = false
	_lantern_fill.max_value = 1.0
	_lantern_fill.step = 0.001
	var lf = StyleBoxFlat.new()
	lf.bg_color = Color("#ff8a1f")
	lf.set_corner_radius_all(6)
	var lb = StyleBoxFlat.new()
	lb.bg_color = Color(0.1, 0.05, 0.02, 0.85)
	lb.set_corner_radius_all(6)
	_lantern_fill.add_theme_stylebox_override("fill", lf)
	_lantern_fill.add_theme_stylebox_override("background", lb)
	_lantern_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lantern.add_child(_lantern_fill)
	UiTheme.place(_lantern_fill, 0.5, 0.0, -17, 30, 34, 46)
	var lic = UiTheme.icon_rect("lantern", 84, Color(1, 0.85, 0.6))
	lic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lic.self_modulate = Color(1, 1, 1, 0.9)
	_lantern.add_child(lic)
	_lantern.pressed.connect(_lantern_tip)
	# --- Controls
	touch = TouchControls.new()
	_root.add_child(touch)
	# Interact (context icon + word), placed left of the thumb arc (mirrored when left-handed)
	_interact = Button.new()
	_interact.focus_mode = Control.FOCUS_NONE
	_interact.add_theme_stylebox_override("normal", _round_style(UiTheme.GOLD, Color(0.2, 0.13, 0.05, 0.94), 4))
	_interact.add_theme_stylebox_override("hover", _round_style(Color.WHITE, Color(0.28, 0.18, 0.07, 0.96), 4))
	_interact.add_theme_stylebox_override("pressed", _round_style(UiTheme.EMBER, Color(0.12, 0.08, 0.04, 0.96), 4))
	_interact.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_interact_icon = UiTheme.icon_rect("hand", 58, UiTheme.GOLD)
	_interact_icon.position = Vector2(23, 16)
	_interact_icon.size = Vector2(58, 58)
	_interact.add_child(_interact_icon)
	_interact_lbl = UiTheme.label("", 20, UiTheme.TEXT, true)
	_interact_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact_lbl.add_theme_font_size_override("font_size", UiTheme.fs(16))
	_interact_lbl.position = Vector2(-48, 74)
	_interact_lbl.size = Vector2(200, 26)
	_interact.add_child(_interact_lbl)
	_interact.pressed.connect(_do_interact)
	UiTheme.juice(_interact)
	_interact.visible = false
	_root.add_child(_interact)
	_block(_interact)
	_place_interact()
	# Channel bar (Homeward Wick etc.)
	_channel = UiTheme.progress_bar(UiTheme.EMBER, 18)
	_channel.visible = false
	_root.add_child(_channel)
	UiTheme.place(_channel, 0.5, 0.62, -160, 0, 320, 18)

## Right-centre, under the minimap and left of the Bag/Lantern column: always above the thumb arc
## (arc top ≈ 305 px from the bottom at any aspect ratio). Mirrored layouts keep it here too because
## the right side is then free of buttons.
func _place_interact() -> void:
	var big = float(Settings.get_value("button_scale", 1.0)) > 1.02
	var lh = bool(Settings.get_value("left_handed", false))
	if big and not lh:
		# Large buttons push the arc up to the minimap: use the top of the (empty) joystick zone instead.
		UiTheme.place(_interact, 0.0, 0.0, 344, 150, 104, 104)
	else:
		UiTheme.place(_interact, 1.0, 0.0, -300, 198, 104, 104)
	# Lantern meter: under the Bag, or next to the quick buttons when large buttons need the space
	if big and not lh:
		UiTheme.place(_lantern, 0.0, 0.0, 740, 0, 84, 92)
	else:
		UiTheme.place(_lantern, 1.0, 0.0, -86, 192, 84, 92)
	# Pickup feed / toasts sit on the side opposite the thumb arc
	if bool(Settings.get_value("left_handed", false)):
		UiTheme.place(_quests, 1.0, 0.0, -340, 312, 330, 100)
		UiTheme.place(_feed, 1.0, 0.0, -440, 420, 440, 190)
	else:
		UiTheme.place(_quests, 0, 0, 0, 150, 330, 100)
		UiTheme.place(_feed, 0, 0, 0, 258, 440, 190)

static var _discs := {}
func _disc(d: int) -> Texture2D:
	if _discs.has(d):
		return _discs[d]
	var img = Image.create(d, d, false, Image.FORMAT_RGBA8)
	var r = d * 0.5
	for y in d:
		for x in d:
			img.set_pixel(x, y, Color(1, 1, 1, clampf(r - 3 - Vector2(x + 0.5 - r, y + 0.5 - r).length(), 0.0, 1.0)))
	_discs[d] = ImageTexture.create_from_image(img)
	return _discs[d]

func setup(p: Player, s: Node) -> void:
	player = p
	session = s
	touch.setup(p)
	_place_interact()
	var col = Color(p.ch.cls().get("color", "#ffd27a"))
	(_res.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = col
	(_res.get_theme_stylebox("fill") as StyleBoxFlat).border_color = col.lightened(0.35)
	var ri: TextureRect = find_child("ResIcon", true, false)
	if ri:
		ri.modulate = col
	var role = str(p.ch.cls().get("role_icon", {"lanternbearer": "tank", "bellstriker": "berserker", "stargazer": "caster", "stitcher": "summoner", "roofrunner": "assassin"}.get(p.ch.class_id, "hero")))
	var pic: TextureRect = _portrait.find_child("Icon", true, false)
	pic.texture = UiTheme.icon(role)
	pic.modulate = col
	_portrait.add_theme_stylebox_override("normal", _round_style(col, Color(col.darkened(0.8), 0.95), 4))
	if p.ch.hardcore:
		_portrait.add_theme_stylebox_override("normal", _round_style(UiTheme.GOLD, Color(0.3, 0.12, 0.02, 0.95), 5))
	var zname = str(Game.world.zone.get("name", "")) if Game.world else ""
	_zone.text = zname
	_zone.modulate.a = 0.0
	var t = create_tween()
	t.tween_property(_zone, "modulate:a", 1.0, 0.6)
	t.tween_interval(3.0)
	t.tween_property(_zone, "modulate:a", 0.0, 1.0)
	_minimap.setup(Game.world)
	# Current-target ring + direction arrow + skill area preview (aim-free combat)
	var tm = TargetMarker.new()
	tm.name = "TargetMarker"
	tm.add_to_group("target_marker")
	Game.world.add_child(tm)
	tm.setup(p, col)
	tree_exiting.connect(func():
		if is_instance_valid(tm):
			tm.queue_free())
	_on_health(p.life, p.max_life)
	_life_trail.value = _life.value
	_on_resource(p.resource, p.ch.max_resource())
	_update_xp()
	_gold_shown = p.ch.gold
	_gold.text = UiTheme.fmt_num(p.ch.gold)
	_refresh_quick()
	_refresh_quests()

# ------------------------------------------------------------------ per frame
func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or Game.world == null:
		return
	var ch = player.ch
	# Interact button: context icon
	var it = Game.world.nearest_interactable()
	var d = Game.world.nearest_drop()
	if it:
		_interact_lbl.text = str(it.get("label", "Use"))
		_interact_icon.texture = UiTheme.icon(_context_icon(it))
		_interact.visible = true
	elif d and (not bool(Settings.get_value("auto_pickup", true)) or player.ch.first_free_slot() < 0 or d.get("item") is Dictionary and not d.item.is_empty() and Items.rarity_index(str(d.item.get("rarity", "common"))) < int(Settings.get_value("loot_filter", 0))):
		_interact_lbl.text = "Pick up"
		_interact_icon.texture = UiTheme.icon("hand")
		_interact.visible = true
	else:
		_interact.visible = false
	# Trails (damage taken / boss damage) ease toward the real value
	_life_trail.value = move_toward(_life_trail.value, _life.value, delta * 0.35) if _life_trail.value > _life.value else _life.value
	if _boss_box.visible:
		var b = Game.world.boss
		if b and is_instance_valid(b) and b.alive:
			_boss_bar.value = b.life / max(1.0, b.max_life)
		_boss_trail.value = move_toward(_boss_trail.value, _boss_bar.value, delta * 0.25) if _boss_trail.value > _boss_bar.value else _boss_bar.value
	# Gold counts up/down (number tween)
	if absf(_gold_shown - ch.gold) > 0.5:
		_gold_shown = move_toward(_gold_shown, ch.gold, max(1.0, absf(ch.gold - _gold_shown) * delta * 6.0))
		_gold.text = UiTheme.fmt_num(_gold_shown)
	_tick_flash = max(0.0, _tick_flash - delta)
	if _tick_flash > 0.0:
		_xp.queue_redraw()
	# Golden moment waits for calm: no enemy within 12 m for 1.5 s
	var calm = Game.world.monsters_near(player.global_position, 12.0).filter(func(m): return m is Monster and m.alive and str(m.faction) == "monster" and str(m.get("kind")) != "minion").is_empty() if Game.world.has_method("monsters_near") else true
	_calm_t = _calm_t + delta if calm else 0.0
	if not _golden_open and _golden_queue.size() > 0 and _calm_t >= 1.5:
		_show_golden(_golden_queue.pop_front())
	_slow_t -= delta
	if _slow_t <= 0.0:
		_slow_t = 0.25
		_slow_update()
	if _event_id != "":
		_edge_arrow.queue_redraw()

func _slow_update() -> void:
	var ch = player.ch
	_lantern_fill.value = Loot.pity_progress(ch, "legendary")
	_skill_chip.visible = ch.skill_points > 0 and not bool(Settings.get_value("simple_mode", false))
	# Homeward Wick cooldown sweep
	var left = float(UiTheme.api_call("Travel", "hearth_cooldown_left", [ch], 0.0))
	var total = float(UiTheme.api_call("Travel", "cfg", [], {}).get("hearth_cooldown_s", 300.0)) if UiTheme.api_has("Travel", "cfg") else 300.0
	_hearth_sweep.value = clampf(left / max(1.0, total), 0.0, 1.0) if ch.wick_charges <= 0 else 0.0
	_refresh_buffs()
	_refresh_quick()
	_poll_event()

func _context_icon(it: Dictionary) -> String:
	if it.has("icon"):
		return str(it.icon)
	var l = str(it.get("label", "")).to_lower()
	for pair in [["open", "chest_open"], ["leave", "portal"], ["waypoint", "waypoint"], ["portal", "portal"], ["smith", "anvil"], ["stash", "stash"],
			["trader", "vendor"], ["vendor", "vendor"], ["alchem", "potion"], ["jewel", "gem"], ["rune", "spark"], ["cauldron", "cauldron"],
			["stable", "mounts"], ["pet", "pets"], ["inn", "hearth"], ["curio", "vendor"], ["talk", "talk"], ["read", "quests"]]:
		if l.contains(pair[0]):
			return pair[1]
	return "talk" if it.has("npc") or it.has("npc_id") else "hand"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E, KEY_F: _do_interact()
			KEY_I, KEY_B: _open("inventory")
			KEY_C: _open("character")
			KEY_K: _open("skills")
			KEY_M: _open("map")
			KEY_P: _open("pets")
			KEY_L: _open("quests")
			KEY_H: _use_hearth()
			KEY_R: _toggle_mount()
			KEY_ESCAPE: _open("menu")

func _open(which: String, ctx := {}) -> void:
	if session == null or get_tree().paused:
		return
	ScreenBase.open(session, which, ctx)

func _do_interact() -> void:
	var it = Game.world.nearest_interactable()
	if it:
		# Hand the interactable to the screen that may open (crafting tab by NPC, dialogue, vendor id)
		ScreenBase.context = {"interactable": it, "label": str(it.get("label", "")), "npc": str(it.get("npc", it.get("npc_id", ""))),
			"station": it.get("station", {}), "screen": str(it.get("screen", ""))}
		it.action.call()
		if it.get("once", false):
			Game.world.interactables.erase(it)
		return
	var d = Game.world.nearest_drop()
	if d:
		Game.world.pickup(d)

func _toggle_mount() -> void:
	if player and player.has_method("toggle_mount"):
		if player.ch.active_mount == "":
			toast("Visit the Stablemaster for a mount", UiTheme.MUTED, "mounts")
			return
		player.toggle_mount()
		_refresh_quick()

func _use_hearth() -> void:
	if player == null:
		return
	var why = str(UiTheme.api_call("Travel", "can_hearth", [player.ch], ""))
	if why != "":
		toast(why, UiTheme.MUTED, "hearth")
		UiTheme.deny(_hearth_btn)
		return
	for m in ["use_hearth", "hearth", "start_hearth", "homeward_wick"]:
		if session and session.has_method(m):
			session.call(m)
			return
	toast("Homeward Wick: coming soon", UiTheme.MUTED, "hearth")

func _refresh_quick() -> void:
	if player == null:
		return
	var ch = player.ch
	_mount_btn.visible = str(UiTheme.chf(ch, "active_mount", "")) != "" or (UiTheme.chf(ch, "mounts_owned", []) as Array).size() > 0
	var mounted = bool(player.get("mounted")) if player.get("mounted") != null else false
	(_mount_btn.find_child("Icon", true, false) as TextureRect).modulate = UiTheme.GOLD if mounted else Color("#d9b27a")
	_mount_btn.add_theme_stylebox_override("normal", _round_style(UiTheme.GOLD if mounted else Color("#d9b27a"), Color(0.3, 0.2, 0.05, 0.95) if mounted else Color(0.08, 0.06, 0.11, 0.9)))
	var pet = str(UiTheme.chf(ch, "active_pet", ""))
	_pet_btn.visible = pet != ""
	if pet != "":
		var prec = Content.get_rec("pets", pet)
		var tint = Color(prec.get("tint", "#ffb3de")) if prec.has("tint") else Color("#ffb3de")
		(_pet_btn.find_child("Icon", true, false) as TextureRect).modulate = tint
		_pet_btn.tooltip_text = str(prec.get("name", "Pet"))
	_hearth_btn.visible = UiTheme.api_has("Travel", "can_hearth")

func _refresh_buffs() -> void:
	for c in _buffs.get_children():
		c.queue_free()
	var now = player.time_now()
	var icons = {"haste": ["speed", UiTheme.GOOD], "unstoppable": ["shield", UiTheme.GOLD], "slow": ["cold", Color("#8fd0ff")],
		"stun": ["star", UiTheme.BAD], "freeze": ["cold", Color("#bfe8ff")], "shield": ["aegis", UiTheme.GOLD], "rested": ["rest", UiTheme.XP],
		"blessing": ["holy", UiTheme.GOLD], "might": ["might", UiTheme.EMBER], "fury": ["berserker", UiTheme.EMBER]}
	var n = 0
	for id in player.status:
		var st: Dictionary = player.status[id]
		if float(st.get("until", 0)) <= now or n >= 5:
			continue
		n += 1
		var spec = icons.get(id, ["spark", UiTheme.TEXT])
		var box = Control.new()
		box.custom_minimum_size = Vector2(36, 36)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bg = Panel.new()
		bg.add_theme_stylebox_override("panel", _round_style(spec[1], Color(0.05, 0.04, 0.07, 0.85), 2))
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(bg)
		var ic = UiTheme.icon_rect(spec[0], 26, spec[1])
		ic.position = Vector2(5, 5)
		ic.size = Vector2(26, 26)
		box.add_child(ic)
		_buffs.add_child(box)
	if player.ch.rested_xp > 0 and n < 5:
		var r = UiTheme.icon_rect("rest", 30, UiTheme.XP)
		r.tooltip_text = "Well rested: bonus XP"
		_buffs.add_child(r)

func _refresh_quests() -> void:
	if player == null:
		return
	for c in _quests.get_children():
		c.queue_free()
	var active: Array = UiTheme.api_call("Quests", "active_list", [player.ch], [])
	var mq: Dictionary = UiTheme.api_call("MainQuest", "tracker", [player.ch], {})
	_quests.visible = not active.is_empty() or not mq.is_empty()
	var shown = 0
	if not mq.is_empty():
		var chap = Content.get_rec("main_quest", str(mq.get("chapter", "")))
		var ob: Dictionary = mq.get("objective", {})
		var txt = load("res://scripts/ui/quests_screen.gd").objective_text(chap, int(mq.get("index", 0)))
		if int(ob.get("count", 1)) > 1:
			txt += "  %d/%d" % [int(ob.get("progress", 0)), int(ob.count)]
		var mh = HBoxContainer.new()
		mh.add_theme_constant_override("separation", 6)
		mh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mh.add_child(UiTheme.icon_rect("star", 26, UiTheme.EMBER))
		var ml = UiTheme.label(txt, 19, Color("#ffd9a0"))
		ml.clip_text = true
		ml.custom_minimum_size = Vector2(290, 0)
		mh.add_child(ml)
		_quests.add_child(mh)
		shown = 1
	for q in active:
		if shown >= 3:
			break
		shown += 1
		var qd: Dictionary = q.get("quest", q) if q is Dictionary else Content.get_rec("quests", str(q))
		var qid = str(qd.get("id", ""))
		var rec = Content.get_rec("quests", qid)
		var prog = int(UiTheme.api_call("Quests", "progress", [player.ch, qid], 0))
		var cnt = int(UiTheme.api_call("Quests", "count", [rec], int(rec.get("count", 1))))
		var ready = str(UiTheme.api_call("Quests", "state", [player.ch, qid], "")) == "ready" or prog >= cnt
		var h = HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(UiTheme.icon_rect("check" if ready else _quest_icon(str(rec.get("type", ""))), 24, UiTheme.GOOD if ready else UiTheme.GOLD))
		var l = UiTheme.label("%s  %d/%d" % [rec.get("name", qid), min(prog, cnt), cnt], 18, UiTheme.GOOD if ready else UiTheme.TEXT)
		l.clip_text = true
		l.custom_minimum_size = Vector2(290, 0)
		h.add_child(l)
		_quests.add_child(h)

func _quest_icon(t: String) -> String:
	return {"kill": "sword", "collect": "bag", "explore": "map", "boss": "skull_soft", "talk": "talk"}.get(t, "quests")

func _pet_name(pid: String) -> String:
	return str(Content.get_rec("pets", pid).get("name", "Pet"))

# ------------------------------------------------------------------ vitals
func _on_health(cur: float, mx: float) -> void:
	var v = cur / max(1.0, mx)
	_life.value = v
	_life_lbl.text = "%d / %d" % [int(cur), int(mx)] if not bool(Settings.get_value("simple_mode", false)) else ""
	var f = _life.get_theme_stylebox("fill") as StyleBoxFlat
	f.bg_color = UiTheme.LIFE if v > 0.3 else UiTheme.LIFE.lerp(Color("#ff8080"), 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01))

func _on_resource(cur: float, mx: float) -> void:
	_res.value = cur / max(1.0, mx)
	_res_lbl.text = "%d" % int(cur)

func _update_xp() -> void:
	if player == null:
		return
	var ch = player.ch
	_lvl.text = str(ch.level)
	var frac = float(ch.xp) / max(1.0, Progression.xp_to_next(ch.level))
	var sub = int(frac * 4.0)
	if _last_sub >= 0 and sub > _last_sub:
		_tick_flash = 0.2
		Sfx.play("ui_tick", -10.0)
	_last_sub = sub
	_xp.set_meta("v", frac)
	_xp.set_meta("rested", clampf(float(ch.rested_xp) / max(1.0, Progression.xp_to_next(ch.level)), 0.0, 1.0 - frac))
	_xp.queue_redraw()

func _draw_xp() -> void:
	var r = Rect2(Vector2.ZERO, _xp.size)
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.03, 0.07, 0.9)
	bg.set_corner_radius_all(5)
	bg.border_color = Color(0, 0, 0, 0.8)
	bg.set_border_width_all(2)
	_xp.draw_style_box(bg, r)
	var v = float(_xp.get_meta("v", 0.0))
	var rested = float(_xp.get_meta("rested", 0.0))
	if rested > 0:
		_xp.draw_rect(Rect2(Vector2(r.size.x * v, 2), Vector2(r.size.x * rested, r.size.y - 4)), Color(UiTheme.XP, 0.3))
	var f = StyleBoxFlat.new()
	f.bg_color = UiTheme.XP
	f.set_corner_radius_all(5)
	if v > 0.01:
		_xp.draw_style_box(f, Rect2(Vector2.ZERO, Vector2(r.size.x * v, r.size.y)))
	for i in range(1, 4):
		var x = r.size.x * i / 4.0
		var lit = v >= i / 4.0
		var col = Color(1, 1, 1, 0.9) if lit else Color(1, 1, 1, 0.3)
		if lit and _tick_flash > 0.0 and int(v * 4) == i:
			col = UiTheme.GOLD
		_xp.draw_line(Vector2(x, -2), Vector2(x, r.size.y + 2), col, 2.0)

func _on_level_up(lvl: int) -> void:
	_update_xp()
	var banner = UiTheme.label("LEVEL %d" % lvl, 64, UiTheme.GOLD, true)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_color_override("font_outline_color", Color(0.3, 0.1, 0))
	banner.add_theme_constant_override("outline_size", 14)
	add_child(banner)
	UiTheme.place(banner, 0.5, 0.5, -300, -210, 600, 90)
	banner.pivot_offset = Vector2(300, 45)
	banner.scale = Vector2(0.4, 0.4)
	var t = create_tween()
	t.tween_property(banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(1.2)
	t.tween_property(banner, "modulate:a", 0.0, 0.6)
	t.tween_callback(banner.queue_free)
	var lt = _portrait.create_tween()
	_portrait.pivot_offset = Vector2(48, 48)
	lt.tween_property(_portrait, "scale", Vector2(1.18, 1.18), 0.12)
	lt.tween_property(_portrait, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	if player.ch.skill_points > 0 and not bool(Settings.get_value("simple_mode", false)):
		toast("+1 skill point!", UiTheme.XP, "skills")

# ------------------------------------------------------------------ boss
func _on_boss(b: Node) -> void:
	_boss_box.visible = true
	_boss_name.text = str(b.get("display_name"))
	_boss_bar.value = 1.0
	_boss_trail.value = 1.0
	var rec: Dictionary = b.get("rec") if b.get("rec") is Dictionary else {}
	_boss_phases = 1 + (rec.get("phases", []) as Array).size()
	for c in _boss_pips.get_children():
		c.queue_free()
	for i in _boss_phases:
		var pip = Panel.new()
		pip.custom_minimum_size = Vector2(14, 14)
		pip.add_theme_stylebox_override("panel", _round_style(Color("#ffb09a"), Color("#c0303a") if i == 0 else Color(0.1, 0.02, 0.03), 2))
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_boss_pips.add_child(pip)
	_boss_pips.visible = _boss_phases > 1
	_boss_box.modulate.a = 0.0
	create_tween().tween_property(_boss_box, "modulate:a", 1.0, 0.4)

func _on_boss_phase(ph: int) -> void:
	var i = 0
	for c in _boss_pips.get_children():
		(c as Panel).add_theme_stylebox_override("panel", _round_style(Color("#ffb09a"), Color("#c0303a") if i <= ph else Color(0.1, 0.02, 0.03), 2))
		i += 1
	toast("The boss grows stronger!", Color("#ff9a7a"), "skull_soft")

func _hide_boss() -> void:
	var t = create_tween()
	t.tween_property(_boss_box, "modulate:a", 0.0, 0.6)
	t.tween_callback(func(): _boss_box.visible = false)

# ------------------------------------------------------------------ Hushfall world events
func _on_event_started(eid: String) -> void:
	_event_id = eid
	var rec = Content.get_rec("world_events", eid)
	if rec.is_empty():
		rec = Content.get_rec("events", eid)
	_event_name.text = str(rec.get("name", "Hushfall"))
	_event_bar.value = 0.0
	_event_box.visible = true
	_event_box.modulate.a = 0.0
	create_tween().tween_property(_event_box, "modulate:a", 1.0, 0.3)

func _on_event_stage(eid: String, stage: int, total: int) -> void:
	if _event_id == "":
		_on_event_started(eid)
	_event_bar.value = float(stage) / max(1.0, float(total))
	var rec = Content.get_rec("world_events", eid)
	_event_name.text = "%s  %d/%d" % [rec.get("name", "Hushfall"), stage, total]

func _on_event_completed(_eid: String) -> void:
	_event_id = ""
	_event_bar.value = 1.0
	_minimap.event_marker = null
	var t = create_tween()
	t.tween_interval(0.6)
	t.tween_property(_event_box, "modulate:a", 0.0, 0.5)
	t.tween_callback(func(): _event_box.visible = false)
	var banner = UiTheme.label("Hushfall sealed!", 56, Color("#e0ccff"), true)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.3))
	banner.add_theme_constant_override("outline_size", 14)
	add_child(banner)
	UiTheme.place(banner, 0.5, 0.5, -350, -190, 700, 80)
	banner.pivot_offset = Vector2(350, 40)
	banner.scale = Vector2(0.5, 0.5)
	var bt = create_tween()
	bt.tween_property(banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bt.tween_interval(1.6)
	bt.tween_property(banner, "modulate:a", 0.0, 0.6)
	bt.tween_callback(banner.queue_free)
	Sfx.play("level_up", -4.0)

func _poll_event() -> void:
	var w = Game.world
	var we = w.get("world_events") if w else null
	if we == null or not is_instance_valid(we) or not we.has_method("status"):
		return
	var st: Dictionary = we.status()
	if st.is_empty() or str(st.get("state", "")) in ["", "idle", "done", "failed", "closed"]:
		if _event_id != "" and str(st.get("state", "")) != "done":
			_event_id = ""
			_event_box.visible = false
			_minimap.event_marker = null
		return
	if _event_id == "":
		_on_event_started(str(st.get("id", "")))
	_event_name.text = "%s  %d/%d" % [st.get("name", "Hushfall"), int(st.get("stage", 0)), int(st.get("total", 1))]
	_event_bar.value = float(st.get("stage", 0)) / max(1.0, float(st.get("total", 1)))

func _banner(text: String, col: Color) -> void:
	var banner = UiTheme.label(text, 52, col, true)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_color_override("font_outline_color", Color(0.2, 0.08, 0))
	banner.add_theme_constant_override("outline_size", 14)
	add_child(banner)
	UiTheme.place(banner, 0.5, 0.5, -400, -190, 800, 80)
	banner.pivot_offset = Vector2(400, 40)
	banner.scale = Vector2(0.5, 0.5)
	var bt = create_tween()
	bt.tween_property(banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bt.tween_interval(1.6)
	bt.tween_property(banner, "modulate:a", 0.0, 0.6)
	bt.tween_callback(banner.queue_free)

func _on_deed(did: String, tier: int) -> void:
	var t = Content.get_rec("deeds_text", Content.get_rec("deeds", did).get("text_ref", did))
	var names: Array = Content.get_rec("deeds_text", "deed_tiers").get("tier_names", ["Spark", "Glow", "Flame", "Beacon", "Lantern"])
	toast("Deed: %s — %s" % [t.get("name", did), names[clampi(tier - 1, 0, names.size() - 1)]], UiTheme.GOLD, "star")
	Sfx.play("deed", -4.0)

# ------------------------------------------------------------------ story dialogue (bottom sheet)
var _story_lines: Array = []
var _story_box: PanelContainer
var _story_i = 0

func _on_story(lines: Array) -> void:
	_story_lines = lines
	_story_i = 0
	if _story_box == null:
		_story_box = PanelContainer.new()
		_story_box.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.05, 0.04, 0.08, 0.96), UiTheme.GOLD, 18, 3))
		_story_box.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(_story_box)
		UiTheme.place(_story_box, 0.5, 1.0, -520, -250, 1040, 220)
		_story_box.gui_input.connect(func(e):
			if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
				_story_next())
	_story_box.visible = true
	_story_show()

func _story_show() -> void:
	ScreenBase.clear(_story_box)
	if _story_i >= _story_lines.size():
		_story_box.visible = false
		return
	var ln: Dictionary = _story_lines[_story_i]
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_story_box.add_child(h)
	var sp = str(ln.get("speaker", ""))
	var port = PanelContainer.new()
	port.add_theme_stylebox_override("panel", _round_style(UiTheme.GOLD, Color(0.2, 0.13, 0.05, 0.95), 3))
	port.mouse_filter = Control.MOUSE_FILTER_IGNORE
	port.add_child(UiTheme.icon_rect("hero" if sp == "You" else str(ln.get("portrait", "talk")) if UiTheme.has_icon(str(ln.get("portrait", ""))) else ("hero" if sp == "You" else "talk"), 96, UiTheme.GOLD))
	h.add_child(port)
	var v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	v.add_child(UiTheme.label(sp, 24, UiTheme.GOLD, true))
	var tl = UiTheme.label(str(ln.get("text", "")), 22, UiTheme.TEXT)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.visible_ratio = 0.0
	v.add_child(tl)
	create_tween().tween_property(tl, "visible_ratio", 1.0, clampf(tl.text.length() * 0.02, 0.2, 1.2))
	var right = VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_END
	h.add_child(right)
	right.add_child(UiTheme.label("%d/%d  tap ›" % [_story_i + 1, _story_lines.size()], 16, UiTheme.MUTED))
	right.add_child(UiTheme.button("Skip", func():
		_story_i = _story_lines.size()
		_story_show(), 18, Vector2(110, 60)))

func _story_next() -> void:
	_story_i += 1
	_story_show()

## Where the active tear is (world may expose world_event_pos() or an "event_pos" meta/property).
func _event_pos():
	var w = Game.world
	if w == null:
		return null
	var we = w.get("world_events")
	if we and is_instance_valid(we) and we.has_method("status"):
		var stt: Dictionary = we.status()
		if stt.get("pos") is Vector3:
			return stt.pos
	if w.has_method("world_event_pos"):
		return w.world_event_pos()
	var p = w.get("world_event_pos")
	if p is Vector3:
		return p
	var st = w.get("world_event")
	if st is Dictionary and st.get("pos") is Vector3:
		return st.pos
	return null

func _draw_edge_arrow() -> void:
	var p = _event_pos()
	_minimap.event_marker = p
	if not (p is Vector3):
		return
	var cam = get_viewport().get_camera_3d()
	if cam == null:
		return
	var vs = get_viewport_rect().size
	var sp = cam.unproject_position(p)
	var behind = cam.is_position_behind(p)
	var margin = 70.0
	var inside = not behind and sp.x > margin and sp.x < vs.x - margin and sp.y > margin and sp.y < vs.y - margin
	var col = Color("#c9a0ff")
	if inside:
		var pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
		_edge_arrow.draw_arc(sp, 34 + pulse * 8, 0, TAU, 32, Color(col, 0.7), 3.0, true)
		return
	var c = vs * 0.5
	var d = (sp - c)
	if behind:
		d = -d
	if d.length() < 1:
		return
	d = d.normalized()
	var ex = (vs.x * 0.5 - margin) / max(0.001, absf(d.x))
	var ey = (vs.y * 0.5 - margin) / max(0.001, absf(d.y))
	var pos = c + d * min(ex, ey)
	var side = Vector2(-d.y, d.x)
	var pts = PackedVector2Array([pos + d * 26, pos - d * 14 + side * 20, pos - d * 6, pos - d * 14 - side * 20])
	_edge_arrow.draw_circle(pos, 34, Color(col, 0.25))
	_edge_arrow.draw_colored_polygon(pts, col)
	_edge_arrow.draw_texture_rect(UiTheme.icon("portal"), Rect2(pos - d * 50 - Vector2(18, 18), Vector2(36, 36)), false, col)

# ------------------------------------------------------------------ channel
func _on_channel(_what: String, t: float) -> void:
	if t < 0.0 or t >= 1.0:
		_channel.visible = false
		return
	_channel.visible = true
	_channel.value = t

# ------------------------------------------------------------------ toasts & pickup feed
func toast(text: String, color: Color, icon_name := "") -> void:
	if icon_name == "":
		icon_name = _guess_icon(text)
	var p = PanelContainer.new()
	var st = UiTheme.panel_style(Color(0.04, 0.03, 0.06, 0.78), Color(color, 0.6), 12, 2)
	st.content_margin_top = 3
	st.content_margin_bottom = 3
	st.content_margin_left = 6
	st.content_margin_right = 12
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	h.add_child(UiTheme.icon_rect(icon_name, 28, color))
	var l = UiTheme.label(text, 19, color)
	l.add_theme_constant_override("outline_size", 5)
	h.add_child(l)
	_push_feed(p)

func _guess_icon(text: String) -> String:
	var t = text.to_lower()
	for pair in [["gold", "gold"], ["level", "xp"], ["salvag", "salvage"], ["bag", "bag"], ["mailbox", "mail"], ["legendary", "star"], ["pet", "pets"],
			["mount", "mounts"], ["quest", "quests"], ["skill", "skills"], ["unlock", "unlock"], ["difficulty", "skull_soft"], ["light", "lantern"],
			["hush", "portal"], ["magpie", "gold"], ["craft", "anvil"], ["wick", "hearth"]]:
		if t.contains(pair[0]):
			return pair[1]
	return "spark"

func _on_pickup(it: Dictionary) -> void:
	var col = UiTheme.rarity_color(str(it.get("rarity", "common")))
	var p = HBoxContainer.new()
	p.add_theme_constant_override("separation", 6)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tile = ItemSlot.new()
	tile.setup(it, "", 40)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(tile)
	var l = UiTheme.label(str(it.get("name", "")), 19, col)
	l.add_theme_constant_override("outline_size", 6)
	p.add_child(l)
	if player and InventoryOps.can_equip(player.ch, it) and InventoryOps.upgrade_delta(player.ch, it) > 1.0:
		p.add_child(UiTheme.label("▲", 20, UiTheme.GOOD))
	_push_feed(p)

func _push_feed(c: Control) -> void:
	_feed.add_child(c)
	while _feed.get_child_count() > 4:
		var old = _feed.get_child(0)
		_feed.remove_child(old)
		old.queue_free()
	c.modulate.a = 0.0
	var t = c.create_tween()
	t.tween_property(c, "modulate:a", 1.0, 0.15)
	t.tween_interval(2.5)
	t.tween_property(c, "modulate:a", 0.0, 0.5)
	t.tween_callback(c.queue_free)

func _lantern_tip() -> void:
	var ch = player.ch
	var r = Content.get_rec("rarities", "legendary")
	var pity_s = float(r.get("pity_seconds", 2700))
	var left = max(0.0, pity_s - (ch.play_seconds - float(ch.pity.get("legendary", 0.0))))
	toast("Legendary guaranteed within %s of play" % UiTheme.fmt_time(left), Color("#ffb04a"), "lantern")

# ------------------------------------------------------------------ golden moment
func _show_golden(it: Dictionary) -> void:
	_golden_open = true
	var card = GoldenCard.new()
	card.setup(it)
	add_child(card)
	card.done.connect(func(equip):
		_golden_open = false
		if equip:
			_equip_found(it))

func _equip_found(it: Dictionary) -> void:
	var ch = player.ch
	var idx = _bag_index(ch, it)
	if idx < 0 and Game.world:
		for d in Game.world.drops:
			if is_instance_valid(d) and d.item is Dictionary and str(d.item.get("uid", "")) == str(it.get("uid", "?")):
				Game.world.pickup(d)
				break
		idx = _bag_index(ch, it)
	if idx >= 0 and InventoryOps.can_equip(ch, ch.inventory[idx]):
		InventoryOps.equip_from_bag(ch, idx)
		player.sync_from_character()
		if player.has_method("refresh_gear"):
			player.refresh_gear()
		Events.equipment_changed.emit()
		toast("Equipped %s" % it.get("name", ""), UiTheme.rarity_color(it.rarity), "check")
		Sfx.play("equip")
	else:
		toast("Can't equip that yet", UiTheme.MUTED)

func _bag_index(ch: CharacterData, it: Dictionary) -> int:
	for i in ch.inventory.size():
		var x = ch.inventory[i]
		if x and str(x.get("uid", "")) == str(it.get("uid", "?")):
			return i
	return -1

func _queue_golden(it: Dictionary) -> void:
	_golden_queue.append(it)
