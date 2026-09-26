extends ScreenBase
## Curio Cart (masked peddler, GDD v2.3 #29): mystery offers by category, priced in EARNED Hushmarks
## (never purchasable). Buy → instant reveal card at the TRUE rarity from the first frame: no reels,
## no spinning, no near-miss, no "almost". A short sparkle only. Equip / Keep.

var ch: CharacterData
var _grid: GridContainer
var _marks: Label

func _ready() -> void:
	ch = Game.character
	if screen_id == "":
		screen_id = "curio"
	build("Curio Cart", "vendor", false)
	var cur = str(UiTheme.api_call("Merchants", "curio_currency", [], "hushmark"))
	var mp = UiTheme.pill(cur if UiTheme.has_icon(cur) else "portal", "", Color("#c9a0ff"), 30)
	_marks = mp.find_child("Value", true, false)
	right_box.add_child(mp)
	var v = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 8)
	body.add_child(v)
	npc_banner(v)
	v.add_child(UiTheme.label("Earn Hushmarks by sealing Hushfalls. Each curio is rolled like a monster drop — you see its true rarity at once.", 17, UiTheme.MUTED))
	var sc = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	sc.add_child(_grid)
	refresh()

func _cur() -> String:
	return str(UiTheme.api_call("Merchants", "curio_currency", [], "hushmark"))

func refresh() -> void:
	var have = int(ch.materials.get(_cur(), 0))
	_marks.text = "%d Hushmarks" % have
	ScreenBase.clear(_grid)
	var offers: Array = UiTheme.api_call("Merchants", "curio_offers", [ch], Content.all("curio_offers"))
	for o in offers:
		var cat: Dictionary = o.get("category", {})
		var key = str(cat.get("weapon_type", cat.get("type", cat.get("slot", "unknown"))))
		if key.begins_with("ring"):
			key = "ring"
		var price = int(o.get("price_hushmarks", 1))
		var can = have >= price
		var b = Button.new()
		b.custom_minimum_size = Vector2(222, 170)
		var col = Color("#c9a0ff")
		b.add_theme_stylebox_override("normal", UiTheme.card_style(col if can else UiTheme.LOCKED))
		b.add_theme_stylebox_override("hover", UiTheme.card_style(col, true))
		var vb = VBoxContainer.new()
		vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vb.offset_top = 8
		vb.offset_bottom = -8
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 4)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(vb)
		var ic = Control.new()
		ic.custom_minimum_size = Vector2(80, 80)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tex = UiTheme.icon(key if UiTheme.has_icon(key) else "unknown")
		ic.draw.connect(func():
			ic.draw_circle(Vector2(40, 40), 38, Color(0.15, 0.08, 0.25, 0.9))
			ic.draw_texture_rect(tex, Rect2(Vector2(12, 12), Vector2(56, 56)), false, Color(col, 0.9))
			ic.draw_string(UiTheme.font_heading(), Vector2(56, 76), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UiTheme.GOLD))
		vb.add_child(ic)
		var nl = UiTheme.label(str(o.get("name", "Mystery")), 18, UiTheme.TEXT, true)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.clip_text = true
		vb.add_child(nl)
		var pp = UiTheme.pill(_cur() if UiTheme.has_icon(_cur()) else "portal", str(price), col, 18)
		pp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if not can:
			(pp.find_child("Value", true, false) as Label).add_theme_color_override("font_color", UiTheme.BAD)
		vb.add_child(pp)
		var oid = str(o.id)
		b.pressed.connect(func():
			if not can:
				UiTheme.deny(b)
				flash_msg("Not enough Hushmarks", UiTheme.MUTED, "portal")
				return
			_buy(oid))
		UiTheme.juice(b)
		_grid.add_child(b)

func _buy(oid: String) -> void:
	var res = sess_call("curio_buy", [oid], null)
	if res == null:
		res = UiTheme.api_call("Merchants", "curio_buy", [ch, oid], {"ok": false, "message": "The cart is closed"})
	if not res.get("ok", false):
		flash_msg(str(res.get("message", "")), UiTheme.BAD, "lock")
		return
	refresh()
	_reveal(res.get("item", {}))

## Instant reveal: true rarity colour, emblem and name from frame 1. One short sparkle.
func _reveal(it: Dictionary) -> void:
	if it.is_empty():
		return
	var col = UiTheme.rarity_color(it.rarity)
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var p = PanelContainer.new()
	var st = UiTheme.panel_style(Color(col.darkened(0.88), 0.99), col, 20, 4)
	st.shadow_color = Color(col, 0.5)
	st.shadow_size = 20
	p.add_theme_stylebox_override("panel", st)
	dim.add_child(p)
	UiTheme.place(p, 0.5, 0.5, -280, -220, 560, 440)
	var v = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var rl = UiTheme.label(UiTheme.rarity_name(it.rarity), 30, col, true)
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(rl)
	var tile = ItemSlot.new()
	tile.setup(it, "", 120)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var d = InventoryOps.upgrade_delta(ch, it)
	tile.set_upgrade(d)
	v.add_child(tile)
	var nl = UiTheme.label(str(it.name), 26, col.lightened(0.3), true)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nl)
	if absf(d) >= 1:
		var pl = UiTheme.label("Power %+d %s" % [int(d), "▲" if d > 0 else "▼"], 22, UiTheme.GOOD if d > 0 else UiTheme.BAD, true)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(pl)
	var h = HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	var eq = UiTheme.icon_button("check", "Equip", func():
		for i in ch.inventory.size():
			if ch.inventory[i] and str(ch.inventory[i].get("uid", "")) == str(it.get("uid", "?")):
				if InventoryOps.equip_from_bag(ch, i):
					flash_msg("Equipped!", col, "check")
					if Game.world and Game.world.player:
						Game.world.player.sync_from_character()
						if Game.world.player.has_method("refresh_gear"):
							Game.world.player.refresh_gear()
				break
		dim.queue_free(), Vector2(190, 80), UiTheme.GOOD, true, 22)
	eq.disabled = not InventoryOps.can_equip(ch, it)
	h.add_child(eq)
	h.add_child(UiTheme.button("Keep", func(): dim.queue_free(), 22, Vector2(160, 80)))
	# one short sparkle (no reel, no build-up)
	var sp = CPUParticles2D.new()
	sp.position = Vector2(280, 150)
	sp.one_shot = true
	sp.explosiveness = 1.0
	sp.amount = 24
	sp.lifetime = 0.6
	sp.spread = 180
	sp.initial_velocity_min = 120
	sp.initial_velocity_max = 220
	sp.gravity = Vector2(0, 120)
	sp.scale_amount_min = 3
	sp.scale_amount_max = 5
	sp.color = col.lightened(0.4)
	sp.emitting = true
	p.add_child(sp)
	Sfx.play("drop_" + str(it.rarity), -2.0, 0.0)
