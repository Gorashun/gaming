extends ScreenBase
## Crafting stations: Smith · Alchemist · Jeweler · Runecarver · Cauldron (tabs; opens on the NPC's tab).
## Left: recipes (requirements with have/need). Middle: item picker + item card (pick the affix).
## Right: operation panel — Kindle bar with the cost RANGE shown up front, exact outcome range,
## gold/material costs, Forge (hold 0.4 s, 0.8 s for Epic+). Upgrade +0…+15 with cost & stat preview
## (never fails). Results count up to the rolled value — never against a "max roll" target line.

var ch: CharacterData
var _prof = "smith"
var _recipe: Dictionary = {}
var _item = null
var _affix = 0
var _mode = ""               # "upgrade" | ""
var _tabs: HBoxContainer
var _lvl_box: HBoxContainer
var _recipes: VBoxContainer
var _picker: GridContainer
var _card: VBoxContainer
var _ops: VBoxContainer

const PROFS := [["smith", "anvil", "Smith"], ["alchemist", "potion", "Alchemist"], ["jeweler", "gem", "Jeweler"], ["runecarver", "spark", "Runecarver"], ["cauldron", "cauldron", "Cauldron"]]
const ITEM_KINDS := ["kindle_upgrade", "kindle_reroll", "kindle_add", "add_socket", "upgrade_item", "reroll_implicit", "unsocket", "reroll_values",
	"remove_affix", "seal_affix", "reroll_all", "imprint_power", "make_greater", "restore_kindle"]
const AFFIX_KINDS := ["kindle_upgrade", "kindle_reroll", "reroll_values", "remove_affix", "seal_affix", "make_greater"]
const BUILTIN := ["kindle_upgrade", "kindle_reroll", "kindle_add", "add_socket", "forge", "forge_unique", "upgrade_item"]
const KIND_ICON := {"kindle_upgrade": "upgrade", "kindle_reroll": "roll", "kindle_add": "plus", "add_socket": "gem", "forge": "anvil", "forge_unique": "crown",
	"forge_named": "sun", "upgrade_item": "upgrade", "brew": "potion", "transmute": "roll", "combine": "gem", "cauldron": "cauldron", "unsocket": "gem",
	"reroll_values": "roll", "remove_affix": "minus", "seal_affix": "lock", "reroll_all": "roll", "imprint_power": "trophy", "make_greater": "star",
	"restore_kindle": "fire", "reroll_implicit": "roll", "gem_convert": "gem"}

func _ready() -> void:
	ch = Game.character
	if screen_id == "":
		screen_id = "crafting"
	_prof = _initial_prof()
	if str(ctx.get("mode", "")) == "upgrade":
		_mode = "upgrade"
		_item = _find_uid(str(ctx.get("uid", "")))
	build("Crafting", "anvil", false)
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
	top.add_child(UiTheme.spacer(0, 0, true))
	_lvl_box = HBoxContainer.new()
	_lvl_box.add_theme_constant_override("separation", 8)
	top.add_child(_lvl_box)
	var cols = HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 12)
	v.add_child(cols)
	_recipes = _column(cols, 320)
	var mid = _column(cols, 0)
	mid.get_parent().get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(UiTheme.label("Choose an item", 18, UiTheme.MUTED, true))
	_picker = GridContainer.new()
	_picker.columns = 5
	_picker.add_theme_constant_override("h_separation", 6)
	_picker.add_theme_constant_override("v_separation", 6)
	mid.add_child(_picker)
	_card = VBoxContainer.new()
	_card.add_theme_constant_override("separation", 4)
	mid.add_child(_card)
	_ops = _column(cols, 400)
	refresh()

func _column(parent: Control, w: float) -> VBoxContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.07, 0.055, 0.1, 0.95), Color(0.3, 0.24, 0.18), 14, 2))
	if w > 0:
		p.custom_minimum_size = Vector2(w, 0)
	parent.add_child(p)
	var sc = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	var v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	sc.add_child(v)
	return v

func _initial_prof() -> String:
	if ctx.has("tab"):
		return str(ctx.tab)
	var npc = str(ctx.get("npc", ""))
	if npc != "":
		var role = str(Content.get_rec("npcs", npc).get("role", ""))
		if role != "":
			return role
	var l = str(ctx.get("label", "")).to_lower()
	for p in PROFS:
		if l.contains(p[0]) or l.contains(str(p[2]).to_lower()):
			return p[0]
	return "smith"

func _unlocked(prof: String) -> bool:
	var rec = Content.get_rec("professions", prof)
	var act = str(rec.get("unlock_act", "act1"))
	var order = int(Content.get_rec("acts", act).get("order", 1))
	var cur = int(Content.get_rec("acts", ch.current_act).get("order", 1))
	return order <= cur or ch.professions.has(prof) and int(ch.professions[prof].get("level", 1)) > 1 or prof == _initial_prof()

func _find_uid(uid: String):
	if uid == "":
		return null
	for it in ch.inventory:
		if it and str(it.get("uid", "")) == uid:
			return it
	for s in ch.equipment:
		var it2 = ch.equipment[s]
		if it2 and str(it2.get("uid", "")) == uid:
			return it2
	return null

func refresh() -> void:
	title_label.text = str(Content.get_rec("professions", _prof).get("name", _prof.capitalize()))
	update_gold_pill()
	ScreenBase.clear(_tabs)
	for p in PROFS:
		var id: String = p[0]
		if not Content.has_rec("professions", id) and id != "smith":
			continue
		var un = _unlocked(id)
		var b = UiTheme.icon_button(p[1] if un else "lock", p[2], func():
			if not un:
				flash_msg("Unlocks in %s" % Content.get_rec("acts", str(Content.get_rec("professions", id).get("unlock_act", ""))).get("name", "a later act"), UiTheme.MUTED, "lock")
				return
			_prof = id
			_recipe = {}
			_mode = ""
			refresh(), Vector2(150, 64), UiTheme.GOLD if id == _prof else (UiTheme.MUTED if un else UiTheme.LOCKED), true, 17)
		if id == _prof:
			b.add_theme_stylebox_override("normal", UiTheme.panel_style(Color(0.3, 0.18, 0.08, 0.95), UiTheme.EMBER, 14, 3))
		_tabs.add_child(b)
	ScreenBase.clear(_lvl_box)
	var pl = Crafting.prof_level(ch, _prof)
	var pd: Dictionary = ch.professions.get(_prof, {"level": 1, "xp": 0})
	_lvl_box.add_child(UiTheme.label("Lv %d" % pl, 22, UiTheme.GOLD, true))
	var bar = UiTheme.progress_bar(UiTheme.GOLD, 14)
	bar.custom_minimum_size = Vector2(150, 14)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.value = clampf(float(pd.get("xp", 0)) / max(1.0, float(Crafting.prof_xp_to_next(pl))), 0.0, 1.0)
	_lvl_box.add_child(bar)
	if _prof == "cauldron":
		_cauldron()
		return
	_list_recipes()
	_list_items()
	_show_card()
	_show_ops()

# ------------------------------------------------------------------ recipes
func _recipe_list() -> Array:
	var out = []
	if _prof == "smith" and UiTheme.api_has("Upgrade", "preview"):
		out.append({"id": "__upgrade", "name": "Upgrade (+1)", "kind": "upgrade_item", "profession": "smith", "level": 1, "desc": "Raise an item's Upgrade level (+0…+15). Never fails."})
	for r in Content.where("recipes", "profession", _prof):
		if r.get("kind", "") == "upgrade_item":
			continue
		if r.get("known_from_start", false) or ch.recipes_known.has(r.id):
			out.append(r)
	return out

func _supported(r: Dictionary) -> bool:
	var k = str(r.get("kind", ""))
	if k == "upgrade_item":
		return UiTheme.api_has("Upgrade", "upgrade")
	if BUILTIN.has(k):
		return true
	var sup = UiTheme.api_call("Crafting", "supports_kind", [k], null)
	return sup == true

func _list_recipes() -> void:
	ScreenBase.clear(_recipes)
	if _mode == "upgrade" and _recipe.is_empty():
		for r in _recipe_list():
			if r.kind == "upgrade_item":
				_recipe = r
	for r in _recipe_list():
		var sel = r.id == _recipe.get("id", "")
		var sup = _supported(r)
		var need_lvl = int(r.get("level", 1))
		var ok_lvl = Crafting.prof_level(ch, _prof) >= need_lvl
		var b = Button.new()
		b.custom_minimum_size = Vector2(0, 76)
		b.add_theme_stylebox_override("normal", UiTheme.card_style(UiTheme.GOLD if sup and ok_lvl else UiTheme.LOCKED, sel))
		b.add_theme_stylebox_override("hover", UiTheme.card_style(UiTheme.GOLD, true))
		var h = HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 8
		h.offset_right = -8
		h.add_theme_constant_override("separation", 8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(h)
		h.add_child(UiTheme.icon_rect(KIND_ICON.get(str(r.kind), "anvil") if ok_lvl else "lock", 42, UiTheme.GOLD if ok_lvl and sup else UiTheme.LOCKED))
		var v = VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(v)
		var nl = UiTheme.label(str(r.get("name", r.id)), 19, UiTheme.TEXT if ok_lvl else UiTheme.MUTED, true)
		nl.clip_text = true
		nl.custom_minimum_size = Vector2(200, 0)
		v.add_child(nl)
		var sub = ""
		if not ok_lvl:
			sub = "Needs %s Lv %d" % [Content.get_rec("professions", _prof).get("name", ""), need_lvl]
		elif not sup:
			sub = "Coming soon"
		else:
			sub = "%s gold" % UiTheme.fmt_num(int(r.get("gold", 0))) if int(r.get("gold", 0)) > 0 else ""
		v.add_child(UiTheme.label(sub, 15, UiTheme.MUTED))
		var mats = HBoxContainer.new()
		mats.add_theme_constant_override("separation", 2)
		mats.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for m in r.get("cost", {}):
			var have = int(ch.materials.get(m, 0))
			var need = int(r.cost[m])
			var mc = Color(Content.get_rec("materials", m).get("color", "#cccccc"))
			var ic = UiTheme.icon_rect(m if UiTheme.has_icon(m) else "material", 24, mc if have >= need else Color(mc, 0.35))
			ic.tooltip_text = "%s %d/%d" % [Content.get_rec("materials", m).get("name", m), have, need]
			mats.add_child(ic)
		h.add_child(mats)
		b.pressed.connect(func():
			_recipe = r
			_mode = "upgrade" if r.kind == "upgrade_item" else ""
			_affix = 0
			if not _item_valid(_item):
				_item = null
			refresh())
		UiTheme.juice(b)
		_recipes.add_child(b)
	if _recipes.get_child_count() == 0:
		_recipes.add_child(UiTheme.wrap_label("No recipes yet. Find recipe pages on your adventures!", 18, UiTheme.MUTED, 280))

func _needs_item() -> bool:
	return ITEM_KINDS.has(str(_recipe.get("kind", ""))) or _mode == "upgrade"

func _item_valid(it) -> bool:
	if it == null or _recipe.is_empty():
		return it != null and _mode == "upgrade"
	var k = str(_recipe.get("kind", ""))
	var slots: Array = _recipe.get("slots", [])
	if slots.size() > 0 and not (slots.has(str(it.get("slot", ""))) or slots.has(str(it.get("type", "")))):
		return false
	if k == "upgrade_item":
		return true
	if k in ["kindle_upgrade", "kindle_reroll", "reroll_values"]:
		return (it.get("affixes", []) as Array).size() > 0
	if k == "kindle_add":
		return it.rarity in ["magic", "rare", "epic"]
	if k == "add_socket":
		return str(it.get("slot", "")) in ["main_hand", "chest", "off_hand", "head"]
	return true

func _list_items() -> void:
	ScreenBase.clear(_picker)
	if not _needs_item():
		_picker.get_parent().get_child(0).text = "Makes a new item" if not _recipe.is_empty() else "Choose a recipe"
		return
	_picker.get_parent().get_child(0).text = "Choose an item"
	var items = []
	for s in Items.SLOTS:
		var it = ch.equipment.get(s)
		if it and _item_valid(it):
			items.append([it, true])
	for it in ch.inventory:
		if it and _item_valid(it):
			items.append([it, false])
	for pair in items.slice(0, 20):
		var it: Dictionary = pair[0]
		var b = ItemSlot.new()
		b.setup(it, "", 72)
		b.selected = _item == it
		if pair[1]:
			b.tooltip_text = "Equipped"
			var e = UiTheme.icon_rect("hero", 20, UiTheme.GOLD)
			UiTheme.place(e, 0.0, 1.0, 4, -22, 20, 20)
			b.add_child(e)
		b.pressed.connect(func():
			_item = it
			_affix = 0
			refresh())
		_picker.add_child(b)
	if items.is_empty():
		_picker.add_child(UiTheme.wrap_label("No item fits this recipe.", 18, UiTheme.MUTED, 300))

func _show_card() -> void:
	ScreenBase.clear(_card)
	if _item == null or not _needs_item():
		return
	var it: Dictionary = _item
	var col = UiTheme.rarity_color(it.rarity)
	var up = int(it.get("upgrade", 0))
	_card.add_child(UiTheme.separator())
	var nm = UiTheme.label(str(it.name) + (" +%d" % up if up > 0 else ""), 22, col.lightened(0.2), true)
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.custom_minimum_size = Vector2(300, 0)
	_card.add_child(nm)
	var pick = AFFIX_KINDS.has(str(_recipe.get("kind", "")))
	if pick:
		_card.add_child(UiTheme.label("Tap the line to change:", 16, UiTheme.MUTED))
	var affs: Array = it.get("affixes", [])
	for i in affs.size():
		var a = affs[i]
		var txt = Items.stat_label(a.stat, float(a.value)) + ("  ✦" if a.get("greater", false) else "")
		if pick:
			var idx = i
			var b = UiTheme.icon_button(UiTheme.stat_icon(a.stat), txt, func():
				_affix = idx
				refresh(), Vector2(0, 52), UiTheme.GOLD if idx == _affix else Color(0.7, 0.8, 1.0), true, 17)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			if idx == _affix:
				b.add_theme_stylebox_override("normal", UiTheme.panel_style(Color(0.3, 0.2, 0.06, 0.95), UiTheme.GOLD, 12, 3))
			_card.add_child(b)
		else:
			var h = HBoxContainer.new()
			h.add_theme_constant_override("separation", 6)
			h.add_child(UiTheme.icon_rect(UiTheme.stat_icon(a.stat), 24, Color(0.7, 0.8, 1.0)))
			h.add_child(UiTheme.label(txt, 17, Color(0.8, 0.86, 1.0)))
			_card.add_child(h)

# ------------------------------------------------------------------ operation panel
func _show_ops() -> void:
	ScreenBase.clear(_ops)
	if _recipe.is_empty():
		_ops.add_child(UiTheme.label("How it works", 22, UiTheme.GOLD, true))
		_ops.add_child(UiTheme.wrap_label("1. Pick a recipe on the left.\n2. Pick an item.\n3. See the cost and the result BEFORE you craft.\n4. Hold the button to craft.", 19, UiTheme.TEXT, 360))
		return
	_ops.add_child(UiTheme.label(str(_recipe.get("name", "")), 24, UiTheme.GOLD, true))
	_ops.add_child(UiTheme.wrap_label(str(_recipe.get("desc", "")), 17, UiTheme.MUTED, 360))
	if _mode == "upgrade":
		_upgrade_ops()
		return
	var k = str(_recipe.get("kind", ""))
	if k.begins_with("kindle_") and _item:
		_kindle_preview(k)
	if not _supported(_recipe):
		_ops.add_child(UiTheme.label("This craft arrives soon.", 18, UiTheme.MUTED))
		return
	_costs(_recipe.get("cost", {}), int(_recipe.get("gold", 0)))
	var err = Crafting.can_craft(ch, _recipe, _item) if (not _needs_item() or _item) else "Choose an item"
	var epic = _item != null and Items.rarity_index(_item.rarity) >= 3
	var b = UiTheme.hold_button("Craft", 0.8 if epic else 0.4, _do_craft, Vector2(360, 96), UiTheme.EMBER, "hammer")
	b.disabled = err != ""
	_ops.add_child(b)
	if err != "":
		_ops.add_child(UiTheme.label(err, 18, UiTheme.BAD))

func _kindle_preview(k: String) -> void:
	var it: Dictionary = _item
	var r = Crafting.kindle_cost_range(ch, _recipe)
	var kin = int(it.get("kindle", 0))
	var kmax = max(1, int(it.get("kindle_max", 1)))
	_ops.add_child(UiTheme.label("Kindle %d / %d" % [kin, kmax], 18, Color(1.0, 0.75, 0.4), true))
	var bar = Control.new()
	bar.custom_minimum_size = Vector2(360, 30)
	bar.draw.connect(func():
		var w = bar.size.x
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.05, 0.02)
		sb.set_corner_radius_all(8)
		bar.draw_style_box(sb, Rect2(Vector2(0, 6), Vector2(w, 18)))
		var fw = w * kin / float(kmax)
		var sf = StyleBoxFlat.new()
		sf.bg_color = Color("#ff9a40")
		sf.set_corner_radius_all(8)
		if fw > 2:
			bar.draw_style_box(sf, Rect2(Vector2(0, 6), Vector2(fw, 18)))
		# bracket: the part this craft may use (min..max)
		var x1 = w * max(0, kin - r.y) / float(kmax)
		var x0 = w * max(0, kin - r.x) / float(kmax)
		bar.draw_rect(Rect2(Vector2(x1, 6), Vector2(fw - x1, 18)), Color(1, 1, 1, 0.25))
		bar.draw_line(Vector2(x1, 0), Vector2(x1, 30), Color.WHITE, 2)
		bar.draw_line(Vector2(x0, 0), Vector2(x0, 30), Color.WHITE, 2)
		bar.draw_line(Vector2(x1, 2), Vector2(x0, 2), Color.WHITE, 2))
	_ops.add_child(bar)
	_ops.add_child(UiTheme.label("This craft uses %d–%d Kindle" % [r.x, r.y], 18, UiTheme.TEXT))
	var affs: Array = it.get("affixes", [])
	match k:
		"kindle_upgrade":
			if affs.size() > 0:
				var a = affs[clampi(_affix, 0, affs.size() - 1)]
				var v = float(a.value)
				var lo = v + absf(v) * 0.08 + 1.0
				var hi = v + absf(v) * 0.2 + 1.0
				_ops.add_child(_outcome(UiTheme.stat_icon(a.stat), "%s → %s … %s" % [_fmt(v), _fmt(lo), _fmt(hi)]))
		"kindle_reroll":
			_ops.add_child(_outcome("roll", "The chosen line becomes a new random line"))
		"kindle_add":
			_ops.add_child(_outcome("plus", "Adds one new random line"))

func _fmt(v: float) -> String:
	return str(int(round(v))) if absf(v) >= 10 else "%.1f" % v

func _outcome(icon_name: String, text: String) -> Control:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.08, 0.14, 0.08, 0.9), UiTheme.GOOD.darkened(0.3), 12, 2))
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	h.add_child(UiTheme.icon_rect(icon_name, 30, UiTheme.GOOD))
	var l = UiTheme.label(text, 18, UiTheme.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	return p

func _costs(mats: Dictionary, gold: int) -> void:
	var row = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	_ops.add_child(row)
	if gold > 0:
		var gp = UiTheme.pill("gold", "%s/%s" % [UiTheme.fmt_num(ch.gold), UiTheme.fmt_num(gold)], UiTheme.COIN, 18)
		(gp.find_child("Value", true, false) as Label).add_theme_color_override("font_color", UiTheme.GOOD if ch.gold >= gold else UiTheme.BAD)
		row.add_child(gp)
	for m in mats:
		var have = int(ch.materials.get(m, 0))
		var need = int(mats[m])
		var rec = Content.get_rec("materials", m)
		var p = UiTheme.pill(m if UiTheme.has_icon(m) else "material", "%d/%d" % [have, need], Color(rec.get("color", "#cccccc")), 18)
		p.tooltip_text = str(rec.get("name", m)) + ("" if have >= need else " — found: " + str(rec.get("source", rec.get("desc", ""))))
		(p.find_child("Value", true, false) as Label).add_theme_color_override("font_color", UiTheme.GOOD if have >= need else UiTheme.BAD)
		row.add_child(p)

func _upgrade_ops() -> void:
	if _item == null:
		_ops.add_child(UiTheme.label("Pick an item to upgrade.", 18, UiTheme.MUTED))
		return
	var pv: Dictionary = UiTheme.api_call("Upgrade", "preview", [ch, _item], {})
	var lvl = int(UiTheme.api_call("Upgrade", "level_of", [_item], 0))
	var mx = int(UiTheme.api_call("Upgrade", "max_level", [], 15))
	# pips +0..+15
	var pips = Control.new()
	pips.custom_minimum_size = Vector2(360, 26)
	pips.draw.connect(func():
		var w = pips.size.x / mx
		for i in mx:
			var c = Vector2(w * i + w * 0.5, 13)
			var lit = i < lvl
			var nxt = i == lvl
			pips.draw_circle(c, 9, Color(0, 0, 0, 0.8))
			pips.draw_circle(c, 7, UiTheme.GOLD if lit else (UiTheme.GOOD if nxt else Color(0.25, 0.22, 0.3)))
			if (i + 1) % 5 == 0:
				pips.draw_arc(c, 11, 0, TAU, 16, UiTheme.EMBER, 2.0, true))
	_ops.add_child(pips)
	if lvl >= mx:
		_ops.add_child(UiTheme.label("Fully kindled! (+%d)" % mx, 22, UiTheme.GOLD, true))
		return
	_ops.add_child(UiTheme.label("+%d  →  +%d" % [lvl, lvl + 1], 30, UiTheme.GOLD, true))
	var deltas: Dictionary = pv.get("deltas", {})
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_ops.add_child(box)
	if pv.has("dmg_before") and pv.has("dmg_after") and pv.dmg_before is Array and pv.dmg_before.size() == 2:
		box.add_child(_delta_row("damage", "%d–%d" % [pv.dmg_before[0], pv.dmg_before[1]], "%d–%d" % [pv.dmg_after[0], pv.dmg_after[1]]))
	if pv.has("armor_before") and float(pv.get("armor_before", 0)) > 0:
		box.add_child(_delta_row("armor", _fmt(float(pv.armor_before)), _fmt(float(pv.armor_after))))
	var sb: Dictionary = pv.get("stats_before", {})
	var sa: Dictionary = pv.get("stats_after", {})
	var n = 0
	for k in deltas:
		if n >= 5 or k == "armor":
			continue
		n += 1
		box.add_child(_delta_row(UiTheme.stat_icon(k), Items.stat_label(k, float(sb.get(k, 0))), _fmt(float(sa.get(k, 0)))))
	var cost: Dictionary = pv.get("cost", UiTheme.api_call("Upgrade", "cost", [_item], {}))
	_costs(cost.get("materials", {}), int(cost.get("gold", 0)))
	_ops.add_child(UiTheme.label("Always succeeds — nothing can break.", 16, UiTheme.GOOD))
	var reason = str(UiTheme.api_call("Upgrade", "can_upgrade", [ch, _item], "Not available"))
	var epic = Items.rarity_index(_item.rarity) >= 3
	var b = UiTheme.hold_button("Upgrade", 0.8 if epic else 0.4, _do_upgrade, Vector2(360, 96), UiTheme.GOLD, "upgrade")
	b.disabled = reason != ""
	_ops.add_child(b)
	if reason != "":
		_ops.add_child(UiTheme.label(reason, 18, UiTheme.BAD))

func _delta_row(icon_name: String, before: String, after: String) -> Control:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(UiTheme.icon_rect(icon_name, 24, UiTheme.GOLD))
	var l = UiTheme.label(before, 17, UiTheme.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	h.add_child(l)
	h.add_child(UiTheme.label("→ " + after + " ▲", 18, UiTheme.GOOD))
	return h

# ------------------------------------------------------------------ actions
func _do_upgrade() -> void:
	var before = int(_item.get("upgrade", 0))
	var res = UiTheme.api_call("Upgrade", "upgrade", [ch, _item], {"ok": false, "message": "Not available"})
	if res.get("ok", false):
		Sfx.play("craft_success")
		_after_craft()
		_result_card(str(res.get("message", "Upgraded!")), "upgrade", float(before), float(before + 1), "+")
	else:
		flash_msg(str(res.get("message", "")), UiTheme.BAD, "lock")

func _do_craft() -> void:
	var it = _item
	var old_v = 0.0
	var aff_i = _affix
	if it and (it.get("affixes", []) as Array).size() > 0:
		old_v = float(it.affixes[clampi(aff_i, 0, it.affixes.size() - 1)].value)
	var res = Crafting.craft(ch, _recipe, it, aff_i)
	if not res.get("ok", false):
		flash_msg(str(res.get("message", "")), UiTheme.BAD, "lock")
		return
	Sfx.play("craft_success")
	_after_craft()
	var new_v = old_v
	if it and _recipe.kind == "kindle_upgrade":
		new_v = float(it.affixes[clampi(aff_i, 0, it.affixes.size() - 1)].value)
		_result_card(str(res.get("message", "")), UiTheme.stat_icon(it.affixes[aff_i].stat), old_v, new_v, "")
	else:
		var made = res.get("item")
		_result_card(str(res.get("message", "Done!")), "anvil", 0, 0, "", made if made is Dictionary and made != it else null)

func _after_craft() -> void:
	ch.recalc()
	if Game.world and Game.world.player:
		Game.world.player.sync_from_character()
	Events.inventory_changed.emit()
	refresh()

## Result: hammer shake → flash → the value counts up to the rolled result (no max-roll target shown).
func _result_card(msg: String, icon_name: String, from_v: float, to_v: float, prefix: String, new_item = null) -> void:
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.1, 0.07, 0.04, 0.98), UiTheme.GOLD, 18, 3))
	dim.add_child(p)
	UiTheme.place(p, 0.5, 0.5, -260, -170, 520, 340)
	var v = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var hammer = UiTheme.icon_rect("hammer", 90, UiTheme.GOLD)
	hammer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(hammer)
	var big = UiTheme.label("", 44, UiTheme.GOLD)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(big)
	if new_item is Dictionary:
		var tile = ItemSlot.new()
		tile.setup(new_item, "", 96)
		tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(tile)
		var nl = UiTheme.label(str(new_item.get("name", "")), 24, UiTheme.rarity_color(new_item.rarity), true)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nl)
	var ml = UiTheme.label(msg, 20, UiTheme.TEXT)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ml)
	var ok = UiTheme.button("Nice!", func(): dim.queue_free(), 24, Vector2(200, 76))
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ok)
	var t = create_tween()
	hammer.pivot_offset = Vector2(45, 45)
	t.tween_property(hammer, "rotation", -0.5, 0.08)
	t.tween_property(hammer, "rotation", 0.3, 0.08)
	t.tween_property(hammer, "rotation", 0.0, 0.14)
	t.tween_property(dim, "color", Color(1, 0.9, 0.6, 0.6), 0.05)
	t.tween_property(dim, "color", Color(0, 0, 0, 0.6), 0.2)
	if to_v != from_v:
		t.tween_method(func(x): big.text = prefix + _fmt(x), from_v, to_v, 0.6).set_ease(Tween.EASE_OUT)
	UiTheme.haptic(25, 0.7)

# ------------------------------------------------------------------ cauldron
func _cauldron() -> void:
	ScreenBase.clear(_recipes)
	ScreenBase.clear(_picker)
	ScreenBase.clear(_card)
	ScreenBase.clear(_ops)
	_recipes.add_child(UiTheme.label("Journal", 22, UiTheme.GOLD, true))
	for r in Content.where("recipes", "profession", "cauldron"):
		var known = ch.discoveries.has("cauldron:" + str(r.id)) or ch.recipes_known.has(r.id)
		var h = HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.add_child(UiTheme.icon_rect("cauldron" if known else "unknown", 36, UiTheme.GOLD if known else UiTheme.LOCKED))
		h.add_child(UiTheme.label(str(r.get("name", "?")) if known else "? ? ?", 19, UiTheme.TEXT if known else UiTheme.MUTED))
		_recipes.add_child(h)
	_picker.get_parent().get_child(0).text = "Drop up to 3 things in the pot"
	var pot = Control.new()
	pot.custom_minimum_size = Vector2(360, 300)
	_card.add_child(pot)
	var ci = UiTheme.icon_rect("cauldron", 180, Color("#8a7ab0"))
	UiTheme.place(ci, 0.5, 0.5, -90, -60, 180, 180)
	pot.add_child(ci)
	for i in 3:
		var a = -PI / 2 + (i - 1) * 0.9
		var s = ItemSlot.new()
		s.setup(null, "", 80)
		UiTheme.place(s, 0.5, 0.5, cos(a) * 140 - 40, sin(a) * 110 - 40, 80, 80)
		pot.add_child(s)
	_ops.add_child(UiTheme.label("The Cauldron", 24, UiTheme.GOLD, true))
	_ops.add_child(UiTheme.wrap_label("Mix items and materials to discover secret recipes. The Cauldron never destroys anything — if nothing happens, you get it all back.", 18, UiTheme.TEXT, 360))
	var stir = UiTheme.hold_button("Stir", 0.4, func():
		var res = UiTheme.api_call("Crafting", "cauldron_stir", [ch, []], null)
		flash_msg("Nothing happened… yet" if res == null else str(res.get("message", "")), UiTheme.MUTED, "cauldron"), Vector2(360, 96), Color("#a878ff"), "cauldron")
	stir.disabled = not UiTheme.api_has("Crafting", "cauldron_stir")
	_ops.add_child(stir)
	if stir.disabled:
		_ops.add_child(UiTheme.label("The Cauldron wakes up in Act V.", 17, UiTheme.MUTED))
