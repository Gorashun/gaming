extends ScreenBase
## Hero screen: live 3D hero with equipped weapon props (drag to turn), name/title/level,
## stat sheet in Offense / Defense / Utility tabs (icon · name · value), weapon proficiency bars,
## class affinity hints, and a pets & mounts summary.

var ch: CharacterData
var _preview: HeroPreview
var _tab = "offense"
var _sheet: VBoxContainer
var _tabs: HBoxContainer

const OFFENSE := ["might", "agility", "wisdom", "damage_pct", "crit_chance", "crit_damage", "attack_speed_pct", "cast_speed_pct", "cdr_pct",
	"area_pct", "melee_damage_pct", "projectile_damage_pct", "area_damage_pct", "minion_damage_pct", "physical_pct", "fire_pct", "cold_pct",
	"lightning_pct", "holy_pct", "shadow_pct", "projectiles", "pierce", "summon_count"]
const DEFENSE := ["life", "vitality", "armor", "block", "dodge", "damage_reduction", "resist_all", "resist_fire", "resist_cold", "resist_lightning",
	"resist_shadow", "life_regen", "life_on_hit", "thorns"]
const UTILITY := ["resource_max", "resource_regen", "move_speed_pct", "magic_find", "gold_find", "xp_pct", "pickup_radius", "material_find"]
const ALWAYS := ["might", "agility", "wisdom", "crit_chance", "life", "armor", "resist_all", "magic_find", "gold_find", "move_speed_pct", "resource_max"]

func _ready() -> void:
	ch = Game.character
	if screen_id == "":
		screen_id = "character"
	build("Hero", "hero", true)
	var h = HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 16)
	body.add_child(h)
	# --- left: 3D hero + identity + companions
	var left = VBoxContainer.new()
	left.custom_minimum_size = Vector2(380, 0)
	left.add_theme_constant_override("separation", 8)
	h.add_child(left)
	var col = Color(ch.cls().get("color", "#ffd27a"))
	var stage = Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(stage)
	var bgp = Panel.new()
	bgp.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(col.darkened(0.88), 0.9), col.darkened(0.4), 18, 2))
	bgp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bgp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(bgp)
	_preview = HeroPreview.new()
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview.camera_distance = 7.2
	_preview.camera_height = 1.8
	_preview.look_height = 1.15
	stage.add_child(_preview)
	_preview.add_hero(ch.class_id, ch, 0.0)
	var id = VBoxContainer.new()
	id.add_theme_constant_override("separation", -4)
	id.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	id.offset_top = 8
	id.offset_bottom = 90
	id.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(id)
	var nm = UiTheme.label(ch.name, 30, col.lightened(0.3), true)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	id.add_child(nm)
	var title = _title_text()
	if title != "":
		var tl = UiTheme.label(title, 18, UiTheme.GOLD)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		id.add_child(tl)
	var sub = UiTheme.label("Level %d %s" % [ch.level, ch.cls().get("name", "")], 18, UiTheme.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	id.add_child(sub)
	if ch.hardcore:
		var hc = UiTheme.label("Last Flame", 18, UiTheme.EMBER, true)
		hc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		id.add_child(hc)
	left.add_child(_companions())
	# --- right: tabs + sheet, proficiency, affinities
	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	h.add_child(right)
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	right.add_child(top)
	top.add_child(_big_stat("life", UiTheme.fmt_num(ch.max_life()), "Life", UiTheme.LIFE))
	top.add_child(_big_stat("damage", _dps_text(), "Damage / s", UiTheme.EMBER))
	top.add_child(_big_stat("armor", UiTheme.fmt_num(ch.stats.total("armor")), "Armor", Color("#a8c0d8")))
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	right.add_child(_tabs)
	var cols = HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 14)
	right.add_child(cols)
	var sc = ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(sc)
	_sheet = VBoxContainer.new()
	_sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet.add_theme_constant_override("separation", 4)
	sc.add_child(_sheet)
	var sc2 = ScrollContainer.new()
	sc2.custom_minimum_size = Vector2(330, 0)
	sc2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(sc2)
	var prof = VBoxContainer.new()
	prof.add_theme_constant_override("separation", 6)
	prof.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc2.add_child(prof)
	_proficiency(prof)
	_show_tab()

func _title_text() -> String:
	var t = str(UiTheme.chf(ch, "title", ""))
	if t == "":
		var w = UiTheme.chf(ch, "wardrobe", {})
		if w is Dictionary:
			t = str(w.get("title", ""))
	if t != "":
		var rec = Content.get_rec("titles", t)
		return str(rec.get("name", t))
	return ""

func _big_stat(icon_name: String, value: String, word: String, col: Color) -> Control:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(col.darkened(0.85), 0.9), col.darkened(0.3), 14, 2))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	p.add_child(hb)
	hb.add_child(UiTheme.icon_rect(icon_name, 48, col))
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	hb.add_child(v)
	v.add_child(UiTheme.label(value, 30, UiTheme.TEXT))
	v.add_child(UiTheme.label(word, 16, UiTheme.MUTED))
	return p

func _dps_text() -> String:
	var w = ch.weapon()
	var avg = 3.0
	var aps = 1.2
	if not w.is_empty() and w.has("dmg_min"):
		avg = (float(w.dmg_min) + float(w.dmg_max)) * 0.5
		aps = float(w.get("aps", 1.2))
	avg *= 1.0 + ch.stats.total("damage_pct") / 100.0
	var prim = str(ch.cls().get("primary", "might"))
	avg *= 1.0 + ch.stats.total(prim) / 100.0
	aps *= 1.0 + ch.stats.total("attack_speed_pct") / 100.0
	var crit = (5.0 + ch.stats.total("crit_chance")) / 100.0
	var cd = (50.0 + ch.stats.total("crit_damage")) / 100.0
	return UiTheme.fmt_num(avg * aps * (1.0 + crit * cd))

func _show_tab() -> void:
	ScreenBase.clear(_tabs)
	for t in [["offense", "sword", "Offense"], ["defense", "shield", "Defense"], ["utility", "magic_find", "Utility"]]:
		var tid: String = t[0]
		var b = UiTheme.icon_button(t[1], t[2], func():
			_tab = tid
			_show_tab(), Vector2(170, 64), UiTheme.GOLD if tid == _tab else UiTheme.MUTED, true, 20)
		if tid == _tab:
			b.add_theme_stylebox_override("normal", UiTheme.panel_style(Color(0.3, 0.18, 0.08, 0.95), UiTheme.EMBER, 14, 3))
		_tabs.add_child(b)
	ScreenBase.clear(_sheet)
	var keys: Array = {"offense": OFFENSE, "defense": DEFENSE, "utility": UTILITY}[_tab]
	var shown = 0
	for k in keys:
		var v = ch.stats.total(k)
		if k == "crit_chance":
			v += 5.0
		if absf(v) < 0.05 and not ALWAYS.has(k):
			continue
		shown += 1
		_sheet.add_child(_stat_row(k, v))
	if shown == 0:
		_sheet.add_child(UiTheme.label("Find gear to grow these!", 20, UiTheme.MUTED))

static func stat_name(k: String) -> Array:
	## [name, is_percent]
	var fmt = str(Content.get_rec("stats", k).get("format", ""))
	if fmt == "":
		return [k.replace("_pct", "").replace("_", " ").capitalize(), k.ends_with("_pct")]
	var pct = fmt.contains("{v}%")
	var n = fmt.replace("+{v}%", "").replace("+{v}", "").replace("{v}%", "").replace("{v}", "").strip_edges()
	return [n.capitalize() if n == n.to_lower() else n, pct]

func _stat_row(k: String, v: float) -> Control:
	var p = PanelContainer.new()
	var st = UiTheme.panel_style(Color(0.09, 0.07, 0.12, 0.85), Color(0.25, 0.2, 0.16), 10, 1)
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", st)
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	h.add_child(UiTheme.icon_rect(UiTheme.stat_icon(k), 30, UiTheme.GOLD))
	var sn = stat_name(k)
	var l = UiTheme.label(sn[0], 20, UiTheme.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var txt = ("%.1f" % v if absf(v - round(v)) > 0.05 else str(int(round(v)))) + ("%" if sn[1] else "")
	h.add_child(UiTheme.label(txt, 22, UiTheme.GOLD))
	return p

func _proficiency(parent: VBoxContainer) -> void:
	parent.add_child(UiTheme.label("Weapon skill", 22, UiTheme.GOLD, true))
	var types = []
	for r in Content.all("weapon_types"):
		types.append(str(r.id))
	if types.is_empty():
		types = ["sword", "axe", "axe2h", "mace", "dagger", "staff", "wand", "crossbow", "bow", "spear", "shield", "tome", "quiver"]
	var cur = str(UiTheme.api_call("Weapons", "main_type", [ch], ""))
	var aff: Dictionary = ch.cls().get("affinities", {})
	var prof: Dictionary = UiTheme.chf(ch, "proficiency", {})
	var maxl = int(UiTheme.api_call("Weapons", "prof_max_level", [], 50))
	# Sort: equipped first, then favoured, then by level
	types.sort_custom(func(a, b):
		var sa = (1000 if a == cur else 0) + (500 if aff.has(a) else 0) + int(prof.get(a, {}).get("level", 1))
		var sb = (1000 if b == cur else 0) + (500 if aff.has(b) else 0) + int(prof.get(b, {}).get("level", 1))
		return sa > sb)
	for t in types:
		var lvl = int(UiTheme.api_call("Weapons", "prof_level", [ch, t], int(prof.get(t, {}).get("level", 1))))
		var xp = float(prof.get(t, {}).get("xp", 0))
		var need = float(UiTheme.api_call("Weapons", "prof_xp_to_next", [lvl], 100))
		var row = VBoxContainer.new()
		row.add_theme_constant_override("separation", 1)
		var hh = HBoxContainer.new()
		hh.add_theme_constant_override("separation", 6)
		row.add_child(hh)
		var tc = UiTheme.GOLD if t == cur else (UiTheme.TEXT if aff.has(t) else UiTheme.MUTED)
		hh.add_child(UiTheme.icon_rect(t if UiTheme.has_icon(t) else "sword", 28, tc))
		var nm = str(Content.get_rec("weapon_types", t).get("name", t.replace("axe2h", "great axe").capitalize()))
		var nl = UiTheme.label(nm, 18, tc)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hh.add_child(nl)
		if aff.has(t):
			var a: Dictionary = aff[t]
			var bits = []
			if a.has("damage_pct"):
				bits.append("+%d%% dmg" % int(a.damage_pct))
			if a.has("attack_speed_pct"):
				bits.append("+%d%% speed" % int(a.attack_speed_pct))
			var al = UiTheme.label("♥ " + " ".join(bits), 15, Color("#ffb3de"))
			al.tooltip_text = "Your class loves this weapon"
			hh.add_child(al)
		hh.add_child(UiTheme.label("Lv %d" % lvl, 18, tc))
		var bar = UiTheme.progress_bar(Color("#ffcf80") if t == cur else Color("#8a7448"), 8)
		bar.value = 1.0 if lvl >= maxl else clampf(xp / max(1.0, need), 0.0, 1.0)
		row.add_child(bar)
		parent.add_child(row)
	if aff.is_empty():
		parent.add_child(UiTheme.wrap_label("Any hero can use any weapon. Keep using one to grow its skill!", 16, UiTheme.MUTED, 300))

func _companions() -> Control:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var pet = str(UiTheme.chf(ch, "active_pet", ""))
	var mount = str(UiTheme.chf(ch, "active_mount", ""))
	var pets_n = (UiTheme.chf(ch, "pets_owned", {}) as Dictionary).size()
	var mounts_n = (UiTheme.chf(ch, "mounts_owned", []) as Array).size()
	var pr = Content.get_rec("pets", pet)
	var pl = int(UiTheme.api_call("Pets", "level", [ch, pet], 1)) if pet != "" else 0
	var pb = UiTheme.icon_button("pets", ("%s · Lv %d" % [pr.get("name", "Pet"), pl]) if pet != "" else "Pets (%d)" % pets_n, func(): goto("pets"), Vector2(186, 72), Color("#ffb3de"), true, 16)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(pb)
	var mr = Content.get_rec("mounts", mount)
	var mb = UiTheme.icon_button("mounts", str(mr.get("name", "Mount")) if mount != "" else "Mounts (%d)" % mounts_n, func(): goto("mounts"), Vector2(186, 72), Color("#d9b27a"), true, 16)
	mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(mb)
	return h
