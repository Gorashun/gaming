class_name Hud
extends Control
## In-game HUD: life/resource, XP, zone name, boss bar, toasts, interact button, menu buttons, golden moment.

var player: Player
var _life: ProgressBar
var _life_lbl: Label
var _res: ProgressBar
var _res_lbl: Label
var _xp: ProgressBar
var _lvl: Label
var _zone: Label
var _boss_box: Control
var _boss_bar: ProgressBar
var _boss_name: Label
var _toasts: VBoxContainer
var _interact: Button
var _pity: ProgressBar
var _gold: Label
var _golden_queue = []
var _golden_open = false
var _combat_timer = 0.0
var touch: TouchControls
var session: Node

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.theme()
	_build()
	Events.health_changed.connect(_on_health)
	Events.resource_changed.connect(_on_resource)
	Events.xp_gained.connect(func(_x): _update_xp())
	Events.level_up.connect(_on_level_up)
	Events.toast.connect(toast)
	Events.boss_spawned.connect(_on_boss)
	Events.boss_defeated.connect(func(_b): _boss_box.visible = false)
	Events.golden_moment.connect(func(it): _golden_queue.append(it))
	Events.gold_changed.connect(func(g): _gold.text = "● %d" % g)
	Events.actor_damaged.connect(func(t, _a, _c, _e):
		if t == player or t is Monster:
			_combat_timer = 2.0)

func _bar(col: Color, bg: Color, h: float) -> ProgressBar:
	var b = ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, h)
	var f = StyleBoxFlat.new()
	f.bg_color = col
	f.set_corner_radius_all(int(h / 2))
	var g = StyleBoxFlat.new()
	g.bg_color = bg
	g.set_corner_radius_all(int(h / 2))
	g.border_color = Color(0, 0, 0, 0.7)
	g.set_border_width_all(2)
	b.add_theme_stylebox_override("fill", f)
	b.add_theme_stylebox_override("background", g)
	b.max_value = 1.0
	b.step = 0.001
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

func _build() -> void:
	# Top-left vitals
	var vit = VBoxContainer.new()
	vit.position = Vector2(24, 18)
	vit.custom_minimum_size = Vector2(360, 0)
	vit.add_theme_constant_override("separation", 6)
	add_child(vit)
	var row = HBoxContainer.new()
	vit.add_child(row)
	_lvl = UiTheme.label("1", 30, UiTheme.GOLD, true)
	_lvl.custom_minimum_size = Vector2(54, 0)
	_lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_lvl)
	var bars = VBoxContainer.new()
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars.add_theme_constant_override("separation", 4)
	row.add_child(bars)
	_life = _bar(UiTheme.LIFE, Color(0.15, 0.04, 0.05, 0.85), 26)
	bars.add_child(_life)
	_life_lbl = UiTheme.label("", 16)
	_life_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_life_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_life_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_life.add_child(_life_lbl)
	_res = _bar(Color("#ffd27a"), Color(0.1, 0.08, 0.04, 0.85), 16)
	bars.add_child(_res)
	_res_lbl = UiTheme.label("", 12)
	_res_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_res_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_res.add_child(_res_lbl)
	var r2 = HBoxContainer.new()
	vit.add_child(r2)
	_gold = UiTheme.label("● 0", 18, Color(1, 0.85, 0.3))
	r2.add_child(_gold)
	var sp = Control.new()
	sp.custom_minimum_size = Vector2(16, 0)
	r2.add_child(sp)
	var pl = UiTheme.label("Lantern", 14, Color("#ff8a1f"))
	r2.add_child(pl)
	_pity = _bar(Color("#ff8a1f"), Color(0.1, 0.06, 0.02, 0.7), 10)
	_pity.custom_minimum_size = Vector2(110, 10)
	_pity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pity.tooltip_text = "Lantern meter: fills as you play. When full, your next drop is Legendary."
	r2.add_child(_pity)
	# Zone name (top centre)
	_zone = UiTheme.label("", 26, UiTheme.GOLD, true)
	_zone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_zone)
	UiTheme.place(_zone, 0.5, 0.0, -300, 14, 600, 40)
	# Boss bar
	_boss_box = VBoxContainer.new()
	_boss_box.visible = false
	add_child(_boss_box)
	UiTheme.place(_boss_box, 0.5, 0.0, -320, 60, 640, 60)
	_boss_name = UiTheme.label("", 24, Color("#ff9a6a"), true)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(_boss_name)
	_boss_bar = _bar(Color("#c0303a"), Color(0.1, 0.02, 0.03, 0.9), 22)
	_boss_box.add_child(_boss_bar)
	# Menu buttons (top right)
	var menu = HBoxContainer.new()
	menu.add_theme_constant_override("separation", 10)
	menu.alignment = BoxContainer.ALIGNMENT_END
	add_child(menu)
	UiTheme.place(menu, 1.0, 0.0, -500, 16, 480, 64)
	for spec in [["Bag", "inventory"], ["Hero", "character"], ["Skills", "skills"], ["Map", "map"], ["☰", "menu"]]:
		var b = UiTheme.button(spec[0], func(): session.open_screen(spec[1]), 18, Vector2(82, 64))
		menu.add_child(b)
	# XP bar bottom
	_xp = _bar(Color("#b58cff"), Color(0.05, 0.03, 0.08, 0.8), 8)
	add_child(_xp)
	_xp.anchor_left = 0.0
	_xp.anchor_right = 1.0
	_xp.anchor_top = 1.0
	_xp.anchor_bottom = 1.0
	_xp.offset_top = -12
	_xp.offset_bottom = -4
	_xp.offset_left = 24
	_xp.offset_right = -24
	# Toasts (left middle)
	_toasts = VBoxContainer.new()
	_toasts.position = Vector2(24, 170)
	_toasts.custom_minimum_size = Vector2(420, 0)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)
	# Controls
	touch = TouchControls.new()
	add_child(touch)
	# Interact button (centre-right)
	_interact = UiTheme.button("Open", func(): _do_interact(), 24, Vector2(170, 70))
	_interact.visible = false
	add_child(_interact)
	UiTheme.place(_interact, 0.5, 0.5, 60, 50, 190, 70)

func setup(p: Player, s: Node) -> void:
	player = p
	session = s
	touch.setup(p)
	_zone.text = Game.world.zone.get("name", "")
	_zone.modulate.a = 0.0
	var t = create_tween()
	t.tween_property(_zone, "modulate:a", 1.0, 0.6)
	t.tween_interval(3.0)
	t.tween_property(_zone, "modulate:a", 0.35, 1.0)
	var col = Color(p.ch.cls().get("color", "#ffd27a"))
	(_res.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = col
	_on_health(p.life, p.max_life)
	_on_resource(p.resource, p.ch.max_resource())
	_update_xp()
	_gold.text = "● %d" % p.ch.gold

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or Game.world == null:
		return
	_combat_timer -= delta
	var it = Game.world.nearest_interactable()
	var d = Game.world.nearest_drop()
	if it:
		_interact.text = it.label
		_interact.visible = true
	elif d:
		_interact.text = "Pick up"
		_interact.visible = true
	else:
		_interact.visible = false
	if Game.world.boss and is_instance_valid(Game.world.boss) and Game.world.boss.alive:
		_boss_bar.value = Game.world.boss.life / Game.world.boss.max_life
	_pity.value = Loot.pity_progress(player.ch, "legendary")
	if not _golden_open and _golden_queue.size() > 0 and _combat_timer <= 0.0:
		_show_golden(_golden_queue.pop_front())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E, KEY_F: _do_interact()
			KEY_I, KEY_B: session.open_screen("inventory")
			KEY_C: session.open_screen("character")
			KEY_K: session.open_screen("skills")
			KEY_M: session.open_screen("map")
			KEY_ESCAPE: session.open_screen("menu")

func _do_interact() -> void:
	var it = Game.world.nearest_interactable()
	if it:
		it.action.call()
		if it.get("once", false):
			Game.world.interactables.erase(it)
		return
	var d = Game.world.nearest_drop()
	if d:
		Game.world.pickup(d)

func _on_health(cur: float, mx: float) -> void:
	_life.value = cur / max(1.0, mx)
	_life_lbl.text = "%d / %d" % [int(cur), int(mx)]

func _on_resource(cur: float, mx: float) -> void:
	_res.value = cur / max(1.0, mx)
	_res_lbl.text = "%d" % int(cur)

func _update_xp() -> void:
	if player == null:
		return
	var ch = player.ch
	_lvl.text = str(ch.level)
	_xp.value = float(ch.xp) / max(1.0, Progression.xp_to_next(ch.level))

func _on_level_up(lvl: int) -> void:
	_update_xp()
	var banner = UiTheme.label("LEVEL %d" % lvl, 64, UiTheme.GOLD, true)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_color_override("font_outline_color", Color(0.3, 0.1, 0))
	banner.add_theme_constant_override("outline_size", 12)
	add_child(banner)
	UiTheme.place(banner, 0.5, 0.5, -300, -200, 600, 90)
	banner.pivot_offset = banner.size / 2
	banner.scale = Vector2(0.4, 0.4)
	var t = create_tween()
	t.tween_property(banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(1.2)
	t.tween_property(banner, "modulate:a", 0.0, 0.6)
	t.tween_callback(banner.queue_free)
	var pts = player.ch.skill_points
	if pts > 0:
		toast("+1 skill point — tap Skills", Color("#b58cff"))

func _on_boss(b: Node) -> void:
	_boss_box.visible = true
	_boss_name.text = b.display_name
	_boss_bar.value = 1.0

func toast(text: String, color: Color) -> void:
	var l = UiTheme.label(text, 22, color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	_toasts.add_child(l)
	if _toasts.get_child_count() > 5:
		_toasts.get_child(0).queue_free()
	l.modulate.a = 0.0
	var t = l.create_tween()
	t.tween_property(l, "modulate:a", 1.0, 0.2)
	t.tween_interval(3.0)
	t.tween_property(l, "modulate:a", 0.0, 0.6)
	t.tween_callback(l.queue_free)

## Legendary+ "golden moment": shows the true rarity immediately, one tap to dismiss (welfare rules).
func _show_golden(it: Dictionary) -> void:
	_golden_open = true
	var col = Items.rarity_color(it.rarity)
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.08, 0.05, 0.08, 0.97), col, 18, 4))
	card.custom_minimum_size = Vector2(520, 0)
	dim.add_child(card)
	UiTheme.place(card, 0.5, 0.5, -260, -220, 520, 0)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var hdr = UiTheme.label(Content.get_rec("rarities", it.rarity).get("name", "").to_upper() + "!", 40, col, true)
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hdr)
	for line in Items.describe(it):
		var l = UiTheme.label(line[0], 20, line[1])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	var ok = UiTheme.button("Wonderful!", func():
		dim.queue_free()
		_golden_open = false, 24, Vector2(220, 64))
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ok)
	card.pivot_offset = Vector2(260, 200)
	card.scale = Vector2(0.6, 0.6)
	var t = create_tween()
	t.tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("golden_moment")
