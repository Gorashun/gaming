extends ScreenBase
## Bag: paper doll (12 slot tiles) around the live 3D hero, 40-cell grid (8×5) with rarity frames,
## ▲/▼ power arrows, new-dots and locks; material bag strip; tools: Best gear (Undo), Sort,
## Salvage-all (rarity ceiling, Epic needs hold), loot-filter shortcut.
## Tap = compare sheet (item vs equipped, every stat with sign + arrow + colour). Double-tap = equip.
## Long-press = lock/unlock.

var ch: CharacterData
var _preview: HeroPreview
var _doll_left: VBoxContainer
var _doll_right: VBoxContainer
var _bag: GridContainer
var _mats: HFlowContainer
var _power: Label
var _sheet: Control
var _filter_btn: Button
var _undo: Dictionary = {}
var _last_tap = {"i": -99, "t": 0.0}
var _press = {"i": -1, "t": 0.0}

static var _seen := {}   # uid -> true (for new-dots)

const LEFT_SLOTS := ["head", "amulet", "chest", "hands", "belt", "legs"]
const RIGHT_SLOTS := ["main_hand", "off_hand", "ring1", "ring2", "feet", "charm"]
const FILTERS := ["Show all", "Hide Common", "Rare & up", "Epic & up"]

func _ready() -> void:
	ch = Game.character
	if screen_id == "":
		screen_id = "inventory"
	build("Bag", "bag", true)
	var h = HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 14)
	body.add_child(h)
	# --- paper doll
	var doll = HBoxContainer.new()
	doll.add_theme_constant_override("separation", 6)
	h.add_child(doll)
	_doll_left = VBoxContainer.new()
	_doll_left.add_theme_constant_override("separation", 6)
	doll.add_child(_doll_left)
	var mid = Control.new()
	mid.custom_minimum_size = Vector2(250, 0)
	doll.add_child(mid)
	var glow = Panel.new()
	glow.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.1, 0.07, 0.12, 0.8), Color(0.35, 0.27, 0.18), 18, 2))
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(glow)
	_preview = HeroPreview.new()
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview.camera_distance = 7.8
	_preview.camera_height = 1.7
	_preview.look_height = 1.05
	_preview.fov = 32
	mid.add_child(_preview)
	_preview.add_hero(ch.class_id, ch, 0.0)
	_power = UiTheme.label("", 22, UiTheme.GOLD, true)
	_power.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_power.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_power.offset_top = 8
	_power.offset_bottom = 40
	mid.add_child(_power)
	var hint = UiTheme.label("drag to turn", 15, Color(UiTheme.MUTED, 0.7))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -28
	hint.offset_bottom = -6
	mid.add_child(hint)
	_doll_right = VBoxContainer.new()
	_doll_right.add_theme_constant_override("separation", 6)
	doll.add_child(_doll_right)
	# --- bag
	var bagcol = VBoxContainer.new()
	bagcol.add_theme_constant_override("separation", 8)
	bagcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(bagcol)
	var tools = HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	bagcol.add_child(tools)
	tools.add_child(UiTheme.icon_button("best", "Best gear", _best, Vector2(150, 64), UiTheme.GOLD, true, 18))
	tools.add_child(UiTheme.icon_button("sort", "Sort", func():
		InventoryOps.compact(ch)
		refresh(), Vector2(110, 64), UiTheme.GOLD, true, 18))
	tools.add_child(UiTheme.icon_button("salvage", "Salvage…", _salvage_menu, Vector2(150, 64), UiTheme.GOLD, true, 18))
	_filter_btn = UiTheme.icon_button("filter", "Show all", _cycle_filter, Vector2(200, 64), UiTheme.GOLD, true, 16)
	tools.add_child(_filter_btn)
	tools.add_child(UiTheme.spacer(0, 0, true))
	tools.add_child(gold_pill())
	var sc = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bagcol.add_child(sc)
	_bag = GridContainer.new()
	_bag.columns = 8
	_bag.add_theme_constant_override("h_separation", 6)
	_bag.add_theme_constant_override("v_separation", 6)
	sc.add_child(_bag)
	# Material bag: wraps into rows inside a short scroll box (never cut, never crowds the grid)
	var msc = ScrollContainer.new()
	msc.custom_minimum_size = Vector2(0, 70)
	msc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bagcol.add_child(msc)
	_mats = HFlowContainer.new()
	_mats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mats.add_theme_constant_override("h_separation", 5)
	_mats.add_theme_constant_override("v_separation", 4)
	msc.add_child(_mats)
	refresh()

func _tile_size() -> float:
	# 8 columns must fit the space left of the doll; ≥ 72 px (hit area incl. gap ≈ 78)
	var w = get_viewport_rect().size.x - 48 - 32 - 14 - (78 * 2 + 12 + 250)
	return clampf(floor((w - 7 * 6) / 8.0), 64.0, 96.0)

func refresh() -> void:
	var ts = 78.0
	for box in [_doll_left, _doll_right]:
		ScreenBase.clear(box)
	for s in LEFT_SLOTS + RIGHT_SLOTS:
		var b = ItemSlot.new()
		b.setup(ch.equipment.get(s), s, ts)
		b.tooltip_text = s.capitalize()
		b.pressed.connect(func(): _open_sheet(-1, s))
		(_doll_left if LEFT_SLOTS.has(s) else _doll_right).add_child(b)
	ScreenBase.clear(_bag)
	var bs = _tile_size()
	for i in ch.inventory.size():
		var it = ch.inventory[i]
		var b = ItemSlot.new()
		if it:
			b.is_new = not _seen.has(str(it.get("uid", "")))
		b.setup(it, "", bs)
		if it:
			b.set_upgrade(InventoryOps.upgrade_delta(ch, it))
		var idx = i
		b.button_down.connect(func(): _press.i = idx; _press.t = Time.get_ticks_msec() / 1000.0)
		b.button_up.connect(func():
			if _press.i == idx and Time.get_ticks_msec() / 1000.0 - _press.t > 0.55 and ch.inventory[idx]:
				_press.i = -1
				_toggle_lock(ch.inventory[idx]))
		b.pressed.connect(func(): _tap_bag(idx))
		_bag.add_child(b)
	ScreenBase.clear(_mats)
	var mats = ch.materials.keys()
	mats.sort_custom(func(a, b): return int(Content.get_rec("materials", a).get("tier", 0)) < int(Content.get_rec("materials", b).get("tier", 0)))
	for m in mats:
		if int(ch.materials[m]) <= 0:
			continue
		var rec = Content.get_rec("materials", m)
		var p = UiTheme.pill(m if UiTheme.has_icon(m) else ("gem" if rec.get("gem", false) else "material"), str(int(ch.materials[m])), Color(rec.get("color", "#cccccc")), 15)
		p.tooltip_text = str(rec.get("name", m))
		p.mouse_filter = Control.MOUSE_FILTER_PASS
		_mats.add_child(p)
	if _mats.get_child_count() == 0:
		_mats.add_child(UiTheme.label("Materials from salvage appear here.", 17, UiTheme.MUTED))
	var total = 0.0
	for s in ch.equipment:
		if ch.equipment[s]:
			total += Items.score(ch.equipment[s], ch.class_id)
	_power.text = "Power %s" % UiTheme.fmt_num(total)
	(_filter_btn.find_child("Text", true, false) as Label).text = FILTERS[clampi(int(Settings.get_value("loot_filter", 0)), 0, 3)]
	update_gold_pill()
	if _preview.heroes.size() > 0:
		_preview.apply_gear(0, ch)

func _tap_bag(i: int) -> void:
	var it = ch.inventory[i]
	if it == null:
		return
	var now = Time.get_ticks_msec() / 1000.0
	if _last_tap.i == i and now - _last_tap.t < 0.35:
		_last_tap.i = -99
		_close_sheet()
		_equip(i)
		return
	_last_tap.i = i
	_last_tap.t = now
	_seen[str(it.get("uid", ""))] = true
	_open_sheet(i, "")

func _toggle_lock(it: Dictionary) -> void:
	it["locked"] = not it.get("locked", false)
	flash_msg("Locked" if it.locked else "Unlocked", UiTheme.GOLD, "lock" if it.locked else "unlock")
	refresh()

func _equip(i: int) -> void:
	var it = ch.inventory[i]
	if it == null:
		return
	if not InventoryOps.can_equip(ch, it):
		flash_msg("Needs level %d" % int(it.get("level_req", 1)), UiTheme.BAD, "lock")
		return
	InventoryOps.equip_from_bag(ch, i)
	_after_change()
	flash_msg("Equipped " + str(it.name), UiTheme.rarity_color(it.rarity), "check")
	_preview.cheer(0)

# ------------------------------------------------------------------ compare sheet
func _close_sheet() -> void:
	if _sheet and is_instance_valid(_sheet):
		_sheet.queue_free()
	_sheet = null

func _open_sheet(bag_i: int, slot: String) -> void:
	_close_sheet()
	var it = ch.inventory[bag_i] if bag_i >= 0 else ch.equipment.get(slot)
	if it == null:
		return
	_sheet = Control.new()
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_sheet)
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			_close_sheet())
	_sheet.add_child(dim)
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.06, 0.05, 0.09, 0.99), UiTheme.rarity_color(it.rarity), 20, 3))
	_sheet.add_child(panel)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -600
	panel.offset_right = 600
	panel.offset_top = -470
	panel.offset_bottom = -20
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var cols = HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	var cur = null
	if bag_i >= 0:
		cur = ch.equipment.get(InventoryOps.target_slot(ch, it))
	cols.add_child(_item_card(it, cur, bag_i >= 0))
	if bag_i >= 0:
		if cur:
			cols.add_child(_item_card(cur, null, false, "Equipped"))
		else:
			var e = UiTheme.label("Nothing equipped here —\nany item is an upgrade!", 22, UiTheme.GOOD)
			e.custom_minimum_size = Vector2(540, 0)
			e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			e.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			cols.add_child(e)
	var acts = HBoxContainer.new()
	acts.add_theme_constant_override("separation", 10)
	v.add_child(acts)
	if bag_i >= 0:
		var can = InventoryOps.can_equip(ch, it)
		var eq = UiTheme.icon_button("check", "Equip", func():
			_close_sheet()
			_equip(bag_i), Vector2(180, 88), UiTheme.GOOD, true, 24)
		eq.add_theme_stylebox_override("normal", UiTheme.panel_style(Color(0.08, 0.22, 0.1, 0.97), UiTheme.GOOD, 14, 3))
		eq.disabled = not can
		acts.add_child(eq)
		var hold = 0.8 if Items.rarity_index(it.rarity) >= 3 else 0.0
		var sv = UiTheme.hold_button("Salvage", hold, func():
			if it.get("locked", false):
				flash_msg("Unlock it first", UiTheme.MUTED, "lock")
				return
			var y = InventoryOps.salvage(ch, bag_i)
			_close_sheet()
			flash_msg("Salvaged: " + _fmt_mats(y), Color(0.85, 0.85, 0.95), "salvage")
			_after_change(), Vector2(190, 88), Color("#9aa0b8"), "salvage")
		acts.add_child(sv)
		acts.add_child(UiTheme.icon_button("sell", "Sell %s" % UiTheme.fmt_num(InventoryOps.sell_value(it)), func():
			if it.get("locked", false):
				flash_msg("Unlock it first", UiTheme.MUTED, "lock")
				return
			InventoryOps.sell(ch, bag_i)
			Events.gold_changed.emit(ch.gold)
			Sfx.play("gold", -4.0)
			_close_sheet()
			_after_change(), Vector2(170, 88), UiTheme.COIN, true, 20))
	else:
		acts.add_child(UiTheme.icon_button("back", "Unequip", func():
			if InventoryOps.unequip(ch, slot):
				_close_sheet()
				_after_change()
			else:
				flash_msg("Bag is full", UiTheme.BAD, "bag"), Vector2(180, 88), UiTheme.GOLD, true, 22))
	acts.add_child(UiTheme.icon_button("lock" if not it.get("locked", false) else "unlock", "Unlock" if it.get("locked", false) else "Lock", func():
		_toggle_lock(it)
		_open_sheet(bag_i, slot), Vector2(150, 88), UiTheme.GOLD, true, 20))
	if UiTheme.api_has("Upgrade", "preview") and int(UiTheme.api_call("Upgrade", "level_of", [it], 0)) < int(UiTheme.api_call("Upgrade", "max_level", [], 15)):
		acts.add_child(UiTheme.icon_button("upgrade", "Upgrade", func():
			goto("crafting", {"tab": "smith", "mode": "upgrade", "uid": str(it.get("uid", ""))}), Vector2(170, 88), UiTheme.GOLD, true, 20))
	acts.add_child(UiTheme.spacer(0, 0, true))
	acts.add_child(UiTheme.icon_button("close", "", _close_sheet, Vector2(88, 88), UiTheme.MUTED))
	panel.position.y += 60
	panel.modulate.a = 0.0
	var tw = panel.create_tween().set_parallel()
	tw.tween_property(panel, "position:y", panel.position.y - 60, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.12)

## Item card: tile + name + base line, then each stat line as icon · value · (delta ▲/▼) vs `other`.
func _item_card(it: Dictionary, other, show_delta: bool, header := "") -> Control:
	var col = UiTheme.rarity_color(it.rarity)
	var v = VBoxContainer.new()
	v.custom_minimum_size = Vector2(560, 0)
	v.add_theme_constant_override("separation", 3)
	if header != "":
		v.add_child(UiTheme.label(header, 18, UiTheme.MUTED, true))
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	v.add_child(top)
	var tile = ItemSlot.new()
	tile.setup(it, "", 88)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(tile)
	var tv = VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tv)
	var up = int(it.get("upgrade", 0))
	var nm = UiTheme.label(str(it.name) + (" +%d" % up if up > 0 else ""), 24, col.lightened(0.2), true)
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.custom_minimum_size = Vector2(440, 0)
	tv.add_child(nm)
	var base = Content.get_rec("item_bases", str(it.get("base", "")))
	tv.add_child(UiTheme.label("%s %s · iLvl %d · needs Lv %d" % [UiTheme.rarity_name(it.rarity), base.get("type_name", ""), int(it.get("ilvl", 1)), int(it.get("level_req", 1))], 17, UiTheme.MUTED))
	if show_delta:
		var d = InventoryOps.upgrade_delta(ch, it)
		if absf(d) >= 1.0:
			tv.add_child(UiTheme.label("Power %+d %s" % [int(d), "▲" if d > 0 else "▼"], 24, UiTheme.GOOD if d > 0 else UiTheme.BAD, true))
		elif not InventoryOps.can_equip(ch, it):
			tv.add_child(UiTheme.label("Needs level %d" % int(it.get("level_req", 1)), 20, UiTheme.BAD))
	var sc = ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 220)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var lines = VBoxContainer.new()
	lines.add_theme_constant_override("separation", 2)
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(lines)
	if it.has("dmg_min"):
		var avg = (float(it.dmg_min) + float(it.dmg_max)) * 0.5 * float(it.get("aps", 1.0))
		var oavg = ((float(other.dmg_min) + float(other.dmg_max)) * 0.5 * float(other.get("aps", 1.0))) if (other and other.has("dmg_min")) else 0.0
		_stat_line(lines, "damage", "%d–%d damage · %.2f/s" % [it.dmg_min, it.dmg_max, float(it.get("aps", 1.0))], avg - oavg if (show_delta and other) else 0.0, Color.WHITE)
	var s_new = Items.item_stats(it)
	var s_old = Items.item_stats(other) if other else {}
	var keys = s_new.keys()
	if show_delta and other:
		for k in s_old:
			if not keys.has(k):
				keys.append(k)
	for k in keys:
		var val = float(s_new.get(k, 0.0))
		var d2 = val - float(s_old.get(k, 0.0)) if (show_delta and other) else 0.0
		var txt = Items.stat_label(k, val) if s_new.has(k) else "— " + Items.stat_label(k, 0.0)
		_stat_line(lines, UiTheme.stat_icon(k), txt, d2, Color(0.8, 0.86, 1.0) if s_new.has(k) else UiTheme.MUTED)
	if it.has("power"):
		var p = Content.get_rec("powers", str(it.power))
		var pl = UiTheme.wrap_label("★ " + str(p.get("desc", p.get("name", ""))), 18, Color(1.0, 0.65, 0.25), 520)
		lines.add_child(pl)
	for g in it.get("sockets", []):
		_stat_line(lines, "gem", "Empty socket" if g == "" else str(Content.get_rec("materials", g).get("name", g)), 0.0, Color(0.7, 0.7, 0.75))
	if int(it.get("kindle_max", 0)) > 0:
		_stat_line(lines, "fire", "Kindle %d / %d" % [int(it.kindle), int(it.kindle_max)], 0.0, Color(1.0, 0.75, 0.4))
	for key in ["unique", "named"]:
		if it.has(key):
			var rec = Content.get_rec("uniques" if key == "unique" else "named", str(it[key]))
			if rec.has("flavor"):
				lines.add_child(UiTheme.wrap_label("\"%s\"" % rec.flavor, 17, Color(0.78, 0.68, 0.52), 520))
	return v

func _stat_line(parent: Control, icon_name: String, text: String, delta: float, col: Color) -> void:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(UiTheme.icon_rect(icon_name, 26, col))
	var l = UiTheme.label(text, 19, col)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	h.add_child(l)
	if absf(delta) >= 0.05:
		var dt = ("%+d" % int(round(delta))) if absf(delta) >= 1.0 else ("%+.1f" % delta)
		h.add_child(UiTheme.label(dt + (" ▲" if delta > 0 else " ▼"), 19, UiTheme.GOOD if delta > 0 else UiTheme.BAD, true))
	parent.add_child(h)

# ------------------------------------------------------------------ tools
func _fmt_mats(y: Dictionary) -> String:
	var parts = []
	for k in y:
		parts.append("%d %s" % [y[k], Content.get_rec("materials", k).get("name", k)])
	return ", ".join(parts) if parts.size() > 0 else "nothing"

func _after_change() -> void:
	Sfx.play("equip", -4.0)
	if Game.world and Game.world.player:
		Game.world.player.sync_from_character()
		if Game.world.player.has_method("refresh_gear"):
			Game.world.player.refresh_gear()
	Events.inventory_changed.emit()
	Events.equipment_changed.emit()
	refresh()

func _best() -> void:
	_undo = {"equipment": ch.equipment.duplicate(), "inventory": ch.inventory.duplicate()}
	var n = InventoryOps.best_gear(ch)
	_after_change()
	if n > 0:
		_preview.cheer(0)
		_show_undo("Equipped %d upgrade%s" % [n, "s" if n > 1 else ""])
	else:
		flash_msg("You're already wearing your best!", UiTheme.GOLD, "best")

func _show_undo(text: String) -> void:
	var b = UiTheme.icon_button("undo", "Undo", func():
		if _undo.is_empty():
			return
		ch.equipment = _undo.equipment
		ch.inventory = _undo.inventory
		ch.recalc()
		_undo = {}
		_after_change()
		flash_msg("Undone", UiTheme.MUTED, "undo"), Vector2(170, 72), UiTheme.GOLD, true, 20)
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.05, 0.04, 0.07, 0.97), UiTheme.GOLD, 16, 2))
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	h.add_child(UiTheme.icon_rect("best", 40, UiTheme.GOLD))
	h.add_child(UiTheme.label(text, 22, UiTheme.GOLD))
	h.add_child(b)
	add_child(p)
	UiTheme.place(p, 0.5, 1.0, -260, -120, 520, 90)
	var t = p.create_tween()
	t.tween_interval(5.0)
	t.tween_property(p, "modulate:a", 0.0, 0.4)
	t.tween_callback(func():
		p.queue_free()
		_undo = {})

func _cycle_filter() -> void:
	var f = (int(Settings.get_value("loot_filter", 0)) + 1) % FILTERS.size()
	Settings.set_value("loot_filter", f)
	flash_msg("Loot filter: " + FILTERS[f] + " (Legendary+ always shown)", UiTheme.GOLD, "filter")
	refresh()

func _salvage_menu() -> void:
	_close_sheet()
	_sheet = Control.new()
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_sheet)
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			_close_sheet())
	_sheet.add_child(dim)
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.06, 0.05, 0.09, 0.99), UiTheme.GOLD, 18, 3))
	_sheet.add_child(p)
	UiTheme.place(p, 0.5, 0.5, -390, -170, 780, 340)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(UiTheme.label("Salvage everything up to…", 28, UiTheme.GOLD, true))
	v.add_child(UiTheme.label("Locked items and upgrades (▲) are always kept.", 18, UiTheme.MUTED))
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	for r in ["common", "magic", "rare", "epic"]:
		var rank = Items.rarity_index(r)
		var n = _salvage_candidates(rank).size()
		var col = UiTheme.rarity_color(r)
		var b = UiTheme.hold_button("%s (%d)" % [UiTheme.rarity_name(r), n], 0.8 if rank >= 3 else 0.0, func(): _salvage_up_to(rank), Vector2(176, 110), col, "")
		var emb = Control.new()
		emb.custom_minimum_size = Vector2(26, 26)
		emb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shape = UiTheme.rarity_shape(r)
		emb.draw.connect(func(): UiTheme.draw_shape(emb, shape, Rect2(Vector2.ZERO, emb.size), col, Color(0, 0, 0, 0.9), 2.0))
		b.add_child(emb)
		UiTheme.place(emb, 0.0, 0.0, 8, 8, 26, 26)
		b.disabled = n == 0
		h.add_child(b)
	v.add_child(UiTheme.button("Cancel", _close_sheet, 22, Vector2(200, 72)))

func _salvage_candidates(max_rank: int) -> Array:
	var out = []
	for i in ch.inventory.size():
		var it = ch.inventory[i]
		if it and Items.rarity_index(it.rarity) <= max_rank and not it.get("locked", false) and InventoryOps.upgrade_delta(ch, it) <= 1.0:
			out.append(i)
	return out

func _salvage_up_to(max_rank: int) -> void:
	var total = {}
	for i in _salvage_candidates(max_rank):
		var y = InventoryOps.salvage(ch, i)
		for k in y:
			total[k] = int(total.get(k, 0)) + y[k]
	_close_sheet()
	flash_msg("Salvaged: " + _fmt_mats(total), Color(0.85, 0.85, 0.95), "salvage")
	_after_change()

func close() -> void:
	for it in ch.inventory:
		if it:
			_seen[str(it.get("uid", ""))] = true
	super.close()
