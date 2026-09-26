extends ScreenBase
## Trader (GDD v2.3: basic supplies only): Buy (potions, Homeward Wick charges, pet treats, mount feed,
## Common starter gear) · Sell (tap a bag item, Epic+ hold-to-confirm) · Buyback (this visit).
## No random goods, no timers, no premium currency.

var ch: CharacterData
var _vendor = ""
var _tab = "buy"
var _list: Control
var _tabs: HBoxContainer
static var _buyback: Array = []

func _ready() -> void:
	ch = Game.character
	if screen_id == "":
		screen_id = "vendor"
	_vendor = _find_vendor()
	build("Trader", "vendor", false)
	right_box.add_child(gold_pill())
	var v = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 8)
	body.add_child(v)
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	top.add_child(_tabs)
	var nb = VBoxContainer.new()
	nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nb)
	npc_banner(nb)
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.08, 0.065, 0.11, 0.95), UiTheme.PANEL_EDGE, 14, 2))
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(p)
	var sc = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	var holder = VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(holder)
	_list = holder
	refresh()

func _find_vendor() -> String:
	if ctx.has("vendor"):
		return str(ctx.vendor)
	var npc = str(npc_rec().get("id", ""))
	for r in Content.all("vendors"):
		if npc != "" and str(r.get("npc", "")) == npc:
			return r.id
	var town = str(Game.world.zone.get("id", "")) if Game.world else ch.current_act_town()
	for r in Content.all("vendors"):
		if str(r.get("town", "")) == town:
			return r.id
	var all = Content.all("vendors")
	return all[0].id if all.size() > 0 else ""

func refresh() -> void:
	update_gold_pill()
	ScreenBase.clear(_tabs)
	for t in [["buy", "vendor", "Buy"], ["sell", "sell", "Sell"], ["buyback", "undo", "Buyback"]]:
		var id: String = t[0]
		var b = UiTheme.icon_button(t[1], t[2], func():
			_tab = id
			refresh(), Vector2(160, 68), UiTheme.GOLD if id == _tab else UiTheme.MUTED, true, 20)
		if id == _tab:
			b.add_theme_stylebox_override("normal", UiTheme.panel_style(Color(0.3, 0.18, 0.08, 0.95), UiTheme.EMBER, 12, 3))
		_tabs.add_child(b)
	ScreenBase.clear(_list)
	match _tab:
		"buy":
			_buy_tab()
		"sell":
			_sell_tab()
		"buyback":
			_buyback_tab()

func _entry_info(e: Dictionary) -> Array:
	## [icon, name, desc, colour]
	var kind = str(e.get("kind", "consumable"))
	var id = str(e.get("id", ""))
	if kind == "item_base":
		var b = Content.get_rec("item_bases", id)
		var t = str(b.get("type", b.get("slot", "")))
		return [t if UiTheme.has_icon(t) else str(b.get("slot", "unknown")), str(b.get("name", id)), "Common %s" % b.get("type_name", ""), UiTheme.rarity_color("common")]
	if kind == "material":
		var m = Content.get_rec("materials", id)
		return [id if UiTheme.has_icon(id) else "material", str(m.get("name", id)), str(m.get("desc", "")), Color(m.get("color", "#cccccc"))]
	var c = Content.get_rec("consumables", id)
	var ck = str(c.get("kind", id))
	var icon = {"potion": "potion", "elixir": "potion", "wick_charge": "hearth", "hearth_charge": "hearth", "pet_treat": "treat", "mount_feed": "mounts"}.get(ck, "potion" if id.begins_with("potion") or id.begins_with("elixir") else ("hearth" if id.contains("hearth") or id.contains("wick") else ("treat" if id.contains("treat") else ("mounts" if id.contains("mount") else "spark"))))
	var col = Color("#ff5a6a") if icon == "potion" and not id.begins_with("elixir") else (UiTheme.EMBER if icon == "hearth" else Color("#ffcf80"))
	if id.begins_with("elixir"):
		col = Color("#b58cff")
	return [icon, str(c.get("name", e.get("name", id.replace("_", " ").capitalize()))), str(c.get("desc", "")), col]

func _buy_tab() -> void:
	var stock: Array = UiTheme.api_call("Merchants", "stock", [_vendor], [])
	if stock.is_empty():
		_list.add_child(UiTheme.label("Nothing for sale here yet.", 20, UiTheme.MUTED))
		return
	var g = GridContainer.new()
	g.columns = 3 + (1 if get_viewport_rect().size.x > 1400 else 0)
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	_list.add_child(g)
	for i in stock.size():
		var e: Dictionary = stock[i]
		var info = _entry_info(e)
		var price = int(e.get("price_gold", 0))
		var b = Button.new()
		b.custom_minimum_size = Vector2(372, 100)
		b.add_theme_stylebox_override("normal", UiTheme.card_style(info[3]))
		b.add_theme_stylebox_override("hover", UiTheme.card_style(info[3], true))
		var h = HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 10
		h.offset_right = -10
		h.add_theme_constant_override("separation", 10)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(h)
		h.add_child(UiTheme.icon_rect(info[0], 50, info[3]))
		var v = VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(v)
		var nl = UiTheme.label(info[1], 16, UiTheme.TEXT, true)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.max_lines_visible = 2
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.custom_minimum_size = Vector2(170, 0)
		v.add_child(nl)
		var dl = UiTheme.label(info[2], 14, UiTheme.MUTED)
		dl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		dl.custom_minimum_size = Vector2(170, 0)
		b.tooltip_text = "%s — %s" % [info[1], info[2]]
		v.add_child(dl)
		var pp = UiTheme.pill("gold", "Free" if price == 0 else UiTheme.fmt_num(price), UiTheme.COIN, 18)
		if ch.gold < price:
			(pp.find_child("Value", true, false) as Label).add_theme_color_override("font_color", UiTheme.BAD)
		h.add_child(pp)
		var idx = i
		b.pressed.connect(func(): _buy(idx, b))
		UiTheme.juice(b)
		g.add_child(b)

func _buy(i: int, b: Control) -> void:
	var res = sess_call("vendor_buy", [_vendor, i], null)
	if res == null:
		res = UiTheme.api_call("Merchants", "buy", [ch, _vendor, i], {"ok": false, "message": "Not for sale"})
	if res.get("ok", false):
		Sfx.play("gold", -4.0)
		flash_msg(str(res.get("message", "Bought!")), UiTheme.GOLD, "check")
	else:
		UiTheme.deny(b)
		flash_msg(str(res.get("message", "")), UiTheme.BAD, "lock")
	refresh()

func _sell_tab() -> void:
	_list.add_child(UiTheme.label("Tap an item to sell it. Locked items are safe.", 17, UiTheme.MUTED))
	var g = GridContainer.new()
	g.columns = 10
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	_list.add_child(g)
	for i in ch.inventory.size():
		var it = ch.inventory[i]
		var cell = VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		var b = ItemSlot.new()
		b.setup(it, "", 80)
		cell.add_child(b)
		if it:
			var l = UiTheme.label(UiTheme.fmt_num(InventoryOps.sell_value(it)), 15, UiTheme.COIN)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(l)
			var idx = i
			b.pressed.connect(func(): _sell(idx))
		g.add_child(cell)

func _sell(i: int) -> void:
	var it = ch.inventory[i]
	if it == null:
		return
	if it.get("locked", false):
		flash_msg("That item is locked", UiTheme.MUTED, "lock")
		return
	if Items.rarity_index(it.rarity) >= 3:
		_confirm_sell(i)
		return
	_do_sell(i)

func _do_sell(i: int) -> void:
	var it = ch.inventory[i]
	var v = int(UiTheme.api_call("Merchants", "sell", [ch, i])) if UiTheme.api_has("Merchants", "sell") else InventoryOps.sell(ch, i)
	if v > 0:
		_buyback.push_front([it, v])
		if _buyback.size() > 12:
			_buyback.pop_back()
		Sfx.play("gold", -4.0)
		flash_msg("+%s gold" % UiTheme.fmt_num(v), UiTheme.COIN, "gold")
	refresh()

func _confirm_sell(i: int) -> void:
	var it = ch.inventory[i]
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.08, 0.06, 0.1, 0.99), UiTheme.rarity_color(it.rarity), 18, 3))
	dim.add_child(p)
	UiTheme.place(p, 0.5, 0.5, -300, -130, 600, 260)
	var v = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var l = UiTheme.label("Sell %s?" % it.name, 24, UiTheme.rarity_color(it.rarity), true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	var h = HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	h.add_child(UiTheme.button("Keep it", func(): dim.queue_free(), 22, Vector2(200, 80)))
	h.add_child(UiTheme.hold_button("Sell %s" % UiTheme.fmt_num(InventoryOps.sell_value(it)), 0.8, func():
		dim.queue_free()
		_do_sell(i), Vector2(240, 80), UiTheme.COIN, "gold"))

func _buyback_tab() -> void:
	if _buyback.is_empty():
		_list.add_child(UiTheme.label("Things you sell this visit can be bought back here.", 19, UiTheme.MUTED))
		return
	for k in _buyback.size():
		var pair = _buyback[k]
		var it: Dictionary = pair[0]
		var h = HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		var t = ItemSlot.new()
		t.setup(it, "", 72)
		h.add_child(t)
		var n = UiTheme.label(str(it.name), 20, UiTheme.rarity_color(it.rarity), true)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		var ki = k
		h.add_child(UiTheme.icon_button("undo", "Buy back %s" % UiTheme.fmt_num(pair[1]), func():
			if ch.gold < int(pair[1]):
				flash_msg("Not enough gold", UiTheme.BAD, "gold")
				return
			if not ch.add_item(it):
				flash_msg("Bag is full", UiTheme.BAD, "bag")
				return
			ch.gold -= int(pair[1])
			Events.gold_changed.emit(ch.gold)
			_buyback.remove_at(ki)
			refresh(), Vector2(230, 72), UiTheme.GOLD, true, 18))
		_list.add_child(h)
