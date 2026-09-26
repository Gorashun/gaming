extends ScreenBase
## Bag + equipment + item details with compare and actions.

var ch: CharacterData
var _equip_box: GridContainer
var _bag: GridContainer
var _detail: VBoxContainer
var _selected = -1          # bag index
var _selected_slot = ""     # equipment slot
var _stats_lbl: Label

const EQUIP_ORDER := ["head", "amulet", "chest", "main_hand", "off_hand", "hands", "belt", "legs", "feet", "ring1", "ring2", "charm"]

func _ready() -> void:
	ch = Game.character
	build("Bag")
	var h = HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 18)
	body.add_child(h)
	var left = VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	h.add_child(left)
	left.add_child(UiTheme.label("Equipped", 20, UiTheme.MUTED, true))
	_equip_box = GridContainer.new()
	_equip_box.columns = 3
	_equip_box.add_theme_constant_override("h_separation", 8)
	_equip_box.add_theme_constant_override("v_separation", 8)
	left.add_child(_equip_box)
	_stats_lbl = UiTheme.label("", 16, UiTheme.MUTED)
	left.add_child(_stats_lbl)
	var mid = VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(mid)
	var tools = HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	mid.add_child(tools)
	tools.add_child(UiTheme.button("Best gear", _best, 18, Vector2(140, 56)))
	tools.add_child(UiTheme.button("Sort", func(): InventoryOps.compact(ch); refresh(), 18, Vector2(100, 56)))
	tools.add_child(UiTheme.button("Salvage Common/Magic", _salvage_low, 18, Vector2(250, 56)))
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(scroll)
	_bag = GridContainer.new()
	_bag.columns = 8
	_bag.add_theme_constant_override("h_separation", 6)
	_bag.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_bag)
	var right = PanelContainer.new()
	right.custom_minimum_size = Vector2(380, 0)
	right.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.05, 0.04, 0.07, 0.9), Color(0.3, 0.25, 0.2), 12, 2))
	h.add_child(right)
	var rs = ScrollContainer.new()
	right.add_child(rs)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 4)
	rs.add_child(_detail)
	refresh()

func refresh() -> void:
	for c in _equip_box.get_children():
		c.queue_free()
	for s in EQUIP_ORDER:
		var b = ItemSlot.new()
		b.setup(ch.equipment.get(s), s, 84)
		b.pressed.connect(func(): _select_equipped(s))
		_equip_box.add_child(b)
	for c in _bag.get_children():
		c.queue_free()
	for i in ch.inventory.size():
		var b = ItemSlot.new()
		b.setup(ch.inventory[i], "", 84)
		if ch.inventory[i]:
			b.set_upgrade(InventoryOps.upgrade_delta(ch, ch.inventory[i]))
		var idx = i
		b.pressed.connect(func(): _select_bag(idx))
		_bag.add_child(b)
	var st = ch.stats
	_stats_lbl.text = "Life %d · Armor %d\nCrit %.1f%% · Resist %d%%\nMagic find +%d%%" % [ch.max_life(), st.total("armor"), 5 + st.get_stat("crit_chance"), st.get_stat("resist_all"), st.total("magic_find")]
	_show_detail()

func _select_bag(i: int) -> void:
	_selected = i
	_selected_slot = ""
	_show_detail()

func _select_equipped(s: String) -> void:
	_selected = -1
	_selected_slot = s
	_show_detail()

func _add_lines(it: Dictionary) -> void:
	for line in Items.describe(it):
		var l = UiTheme.label(line[0], 18, line[1])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(340, 0)
		_detail.add_child(l)

func _show_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	var it = null
	if _selected >= 0:
		it = ch.inventory[_selected]
	elif _selected_slot != "":
		it = ch.equipment.get(_selected_slot)
	if it == null:
		_detail.add_child(UiTheme.label("Tap an item to see it.", 18, UiTheme.MUTED))
		return
	_add_lines(it)
	var actions = HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	if _selected >= 0:
		var delta = InventoryOps.upgrade_delta(ch, it)
		if delta != 0.0:
			var d = UiTheme.label(("▲ Upgrade (+%d)" if delta > 0 else "▼ Weaker (%d)") % int(delta), 18, Color("#4dff7a") if delta > 0 else Color("#ff6a6a"))
			_detail.add_child(d)
		var cur = ch.equipment.get(InventoryOps.target_slot(ch, it))
		if cur:
			_detail.add_child(UiTheme.label("— Currently equipped —", 16, UiTheme.MUTED))
			for line in Items.describe(cur).slice(0, 3):
				_detail.add_child(UiTheme.label(line[0], 16, Color(line[1], 0.8)))
		if InventoryOps.can_equip(ch, it):
			actions.add_child(UiTheme.button("Equip", func():
				InventoryOps.equip_from_bag(ch, _selected)
				_after_change(), 20, Vector2(130, 60)))
		else:
			_detail.add_child(UiTheme.label("Cannot equip (level or class)", 16, Color("#ff6a6a")))
		actions.add_child(UiTheme.button("Salvage", func():
			var y = InventoryOps.salvage(ch, _selected)
			Events.toast.emit("Salvaged: " + _fmt_mats(y), Color(0.8, 0.8, 0.9))
			_selected = -1
			_after_change(), 20, Vector2(130, 60)))
		actions.add_child(UiTheme.button("Sell %d" % InventoryOps.sell_value(it), func():
			InventoryOps.sell(ch, _selected)
			Events.gold_changed.emit(ch.gold)
			_selected = -1
			_after_change(), 20, Vector2(130, 60)))
		actions.add_child(UiTheme.button("Unlock" if it.get("locked", false) else "Lock", func():
			it["locked"] = not it.get("locked", false)
			_show_detail(), 20, Vector2(120, 60)))
	else:
		actions.add_child(UiTheme.button("Unequip", func():
			if InventoryOps.unequip(ch, _selected_slot):
				_selected_slot = ""
				_after_change(), 20, Vector2(140, 60)))
	_detail.add_child(actions)

func _fmt_mats(y: Dictionary) -> String:
	var parts = []
	for k in y:
		parts.append("%d %s" % [y[k], Content.get_rec("materials", k).get("name", k)])
	return ", ".join(parts)

func _after_change() -> void:
	Sfx.play("equip", -4.0)
	if Game.world and Game.world.player:
		Game.world.player.sync_from_character()
	Events.inventory_changed.emit()
	Events.equipment_changed.emit()
	refresh()

func _best() -> void:
	var n = InventoryOps.best_gear(ch)
	Events.toast.emit("Equipped %d upgrades" % n if n > 0 else "You're already wearing your best", UiTheme.GOLD)
	_after_change()

func _salvage_low() -> void:
	var total = {}
	for i in ch.inventory.size():
		var it = ch.inventory[i]
		if it and Items.rarity_index(it.rarity) <= 1 and not it.get("locked", false) and InventoryOps.upgrade_delta(ch, it) <= 1.0:
			var y = InventoryOps.salvage(ch, i)
			for k in y:
				total[k] = int(total.get(k, 0)) + y[k]
	if total.size() > 0:
		Events.toast.emit("Salvaged: " + _fmt_mats(total), Color(0.8, 0.8, 0.9))
	_selected = -1
	_after_change()
