extends ScreenBase
## Deeds (achievements): category rail, tiered progress (Spark · Glow · Flame · Beacon · Lantern),
## reward previews (titles, cosmetics, small stats), completed state, Deed points total + milestones.
## Never timed, never sold (welfare).

var ch: CharacterData
var _cat = ""
var _rail: VBoxContainer
var _list: VBoxContainer
var _pts: Label
var _tiers_txt: Array = ["Spark", "Glow", "Flame", "Beacon", "Lantern"]
var _cats: Dictionary = {}

const TIER_COL := ["#c89a6a", "#dfe6ee", "#ffcf4a", "#8fd0ff", "#ff9a40"]

func _ready() -> void:
	ch = Game.character
	if screen_id == "":
		screen_id = "deeds"
	var meta = Content.get_rec("deeds_text", "deed_tiers")
	if meta.has("tier_names"):
		_tiers_txt = meta.tier_names
	_cats = meta.get("categories", {})
	build("Deeds", "medal", true)
	var pp = UiTheme.pill("star", "", UiTheme.GOLD, 24)
	_pts = pp.find_child("Value", true, false)
	pp.name = "DeedPts"
	var h = HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 12)
	body.add_child(h)
	var lc = VBoxContainer.new()
	lc.add_theme_constant_override("separation", 8)
	h.add_child(lc)
	lc.add_child(pp)
	var rs = ScrollContainer.new()
	rs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rs.custom_minimum_size = Vector2(230, 0)
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lc.add_child(rs)
	_rail = VBoxContainer.new()
	_rail.add_theme_constant_override("separation", 6)
	rs.add_child(_rail)
	var sc = ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	sc.add_child(_list)
	refresh()

func _text(d: Dictionary) -> Dictionary:
	return Content.get_rec("deeds_text", str(d.get("text_ref", d.get("id", ""))))

func refresh() -> void:
	var entries: Array = UiTheme.api_call("Deeds", "list", [ch], [])
	var pts = int(UiTheme.chf(ch, "deed_points", 0))
	if pts == 0:
		for e in entries:
			var tiers: Array = e.deed.get("tiers", [])
			for i in int(e.get("tier", 0)):
				if i < tiers.size():
					pts += int(tiers[i].get("points", 0))
	_pts.text = "%d Deed points" % pts
	var cats = []
	for e in entries:
		var c = str(e.deed.get("category", "other"))
		if not cats.has(c):
			cats.append(c)
	if _cat == "" and cats.size() > 0:
		_cat = cats[0]
	ScreenBase.clear(_rail)
	for c in cats:
		var done = 0
		var tot = 0
		for e in entries:
			if str(e.deed.get("category", "")) == c:
				tot += 1
				if e.get("done", false):
					done += 1
		var cid = str(c)
		var b = UiTheme.button("%s  %d/%d" % [_cats.get(cid, cid.capitalize()), done, tot], func():
			_cat = cid
			refresh(), 16, Vector2(220, 60))
		if cid == _cat:
			b.add_theme_stylebox_override("normal", UiTheme.panel_style(Color(0.3, 0.18, 0.08, 0.95), UiTheme.EMBER, 12, 3))
		_rail.add_child(b)
	ScreenBase.clear(_list)
	var shown = entries.filter(func(e): return str(e.deed.get("category", "")) == _cat)
	shown.sort_custom(func(a, b): return (1 if a.done else 0) < (1 if b.done else 0))
	for e in shown:
		_list.add_child(_deed_card(e))
	if shown.is_empty():
		_list.add_child(UiTheme.label("Play on — deeds appear as you go!", 20, UiTheme.MUTED))

func _deed_card(e: Dictionary) -> Control:
	var d: Dictionary = e.deed
	var t = _text(d)
	var tier = int(e.get("tier", 0))
	var tiers: Array = d.get("tiers", [])
	var done = bool(e.get("done", false))
	var col = Color(TIER_COL[clampi(tier - 1, 0, 4)]) if tier > 0 else UiTheme.MUTED
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.card_style(col if tier > 0 else Color(0.4, 0.36, 0.3), done))
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var medal = Control.new()
	medal.custom_minimum_size = Vector2(64, 64)
	medal.draw.connect(func():
		medal.draw_circle(Vector2(32, 32), 30, Color(0, 0, 0, 0.8))
		medal.draw_circle(Vector2(32, 32), 26, col.darkened(0.2) if tier > 0 else Color(0.2, 0.18, 0.24))
		medal.draw_texture_rect(UiTheme.icon("check" if done else "star"), Rect2(Vector2(14, 14), Vector2(36, 36)), false, Color(1, 1, 1, 0.9) if tier > 0 else Color(0.4, 0.38, 0.45)))
	h.add_child(medal)
	var v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 3)
	h.add_child(v)
	var nm = str(t.get("name", d.get("name", d.id))) + ("  —  " + str(_tiers_txt[clampi(tier - 1, 0, _tiers_txt.size() - 1)]) if tier > 0 else "")
	v.add_child(UiTheme.label(nm, 21, UiTheme.TEXT, true))
	var goal = int(e.get("next_goal", 0))
	var val = int(e.get("value", 0))
	var desc = str(t.get("desc", d.get("desc", ""))).replace("{n}", UiTheme.fmt_num(goal))
	v.add_child(UiTheme.label(desc if not done else "Complete!", 16, UiTheme.MUTED if not done else UiTheme.GOOD))
	if not done and goal > 0:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		v.add_child(row)
		var bar = UiTheme.progress_bar(UiTheme.GOLD, 12)
		bar.value = clampf(float(val) / goal, 0.0, 1.0)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		row.add_child(UiTheme.label("%s / %s" % [UiTheme.fmt_num(val), UiTheme.fmt_num(goal)], 16, UiTheme.GOLD))
	# tier pips
	var pips = HBoxContainer.new()
	pips.add_theme_constant_override("separation", 4)
	h.add_child(pips)
	for i in tiers.size():
		var pc = Control.new()
		pc.custom_minimum_size = Vector2(22, 22)
		var lit = i < tier
		var tc = Color(TIER_COL[clampi(i, 0, 4)])
		pc.draw.connect(func():
			pc.draw_circle(Vector2(11, 11), 10, Color(0, 0, 0, 0.8))
			pc.draw_circle(Vector2(11, 11), 8, tc if lit else Color(0.22, 0.2, 0.26)))
		pc.tooltip_text = str(_tiers_txt[clampi(i, 0, _tiers_txt.size() - 1)])
		pips.add_child(pc)
	# next reward preview
	var nxt: Dictionary = tiers[tier].get("reward", {}) if tier < tiers.size() else {}
	if not nxt.is_empty():
		var rw = VBoxContainer.new()
		rw.custom_minimum_size = Vector2(170, 0)
		h.add_child(rw)
		if nxt.has("title"):
			rw.add_child(UiTheme.pill("crown", "“%s”" % nxt.title, UiTheme.GOLD, 15))
		if nxt.has("cosmetic"):
			rw.add_child(UiTheme.pill("hero", "Cosmetic", Color("#ffb3de"), 15))
		if nxt.has("skill_points"):
			rw.add_child(UiTheme.pill("skills", "+%d point" % int(nxt.skill_points), UiTheme.XP, 15))
		if nxt.has("gold"):
			rw.add_child(UiTheme.pill("gold", UiTheme.fmt_num(int(nxt.gold)), UiTheme.COIN, 15))
		if nxt.has("stats"):
			for k in nxt.stats:
				rw.add_child(UiTheme.pill(UiTheme.stat_icon(k), Items.stat_label(k, float(nxt.stats[k])), UiTheme.GOOD, 15))
	return p
