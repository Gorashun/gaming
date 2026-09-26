extends ScreenBase
## Skill tree: 3 branch columns (glowing paths between nodes, capstone at the bottom of each branch),
## rank pips, lock + level for locked nodes, "Recommended" glow on the next suggested node, synergy
## rings on skills that share a tag/element with the selected one.
## Detail panel: 3 numbers max (power, cost, cooldown), + rank, bar placement, behaviour modifiers
## (rank 2 / 4 choice cards), Skill Mastery (rank, XP bar, cost, Upgrade, milestones 5/10/15/20).
## Header: points, Recommended toggle, respec (free until 20), loadouts 1–3.

var ch: CharacterData
var _tree: Control
var _paths: Control
var _detail: VBoxContainer
var _bar: HBoxContainer
var _pts_lbl: Label
var _sel = ""
var _nodes = {}          # skill id -> Button
var _assign_slot = -1
var _recommend = true
var _bursts: Control

func _ready() -> void:
	ch = Game.character
	if screen_id == "":
		screen_id = "skills"
	_recommend = bool(Settings.get_value("skills_recommended", true))
	build("Skills", "skills", true)
	var h = HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 14)
	body.add_child(h)
	var left = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	h.add_child(left)
	var tools = HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	left.add_child(tools)
	var pp = UiTheme.pill("plus", "", UiTheme.XP, 22)
	_pts_lbl = pp.find_child("Value", true, false)
	tools.add_child(pp)
	tools.add_child(UiTheme.spacer(0, 0, true))
	var rec_b = UiTheme.icon_button("check" if _recommend else "star", "Guide", func(): pass, Vector2(120, 60), UiTheme.GOLD if _recommend else UiTheme.MUTED, true, 18)
	rec_b.tooltip_text = "Show the recommended next skill"
	rec_b.pressed.connect(func():
		_recommend = not _recommend
		Settings.set_value("skills_recommended", _recommend)
		(rec_b.find_child("Icon", true, false) as TextureRect).texture = UiTheme.icon("check" if _recommend else "star")
		(rec_b.find_child("Icon", true, false) as TextureRect).modulate = UiTheme.GOLD if _recommend else UiTheme.MUTED
		refresh())
	tools.add_child(rec_b)
	if UiTheme.api_has("Builds", "respec_skills"):
		var cost = int(UiTheme.api_call("Builds", "respec_cost", [ch], 0))
		tools.add_child(UiTheme.hold_button("Reset" if cost == 0 else "Reset %s" % UiTheme.fmt_num(cost), 0.8, _respec, Vector2(150, 60), Color("#9aa0b8"), "undo"))
	if UiTheme.api_has("Builds", "save_loadout"):
		for i in 3:
			tools.add_child(_loadout_button(i))
	var tree_panel = PanelContainer.new()
	tree_panel.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.05, 0.04, 0.08, 0.9), Color(0.3, 0.24, 0.18), 16, 2))
	tree_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(tree_panel)
	var sc = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tree_panel.add_child(sc)
	_tree = Control.new()
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_tree)
	_paths = Control.new()
	_paths.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paths.draw.connect(_draw_paths)
	_tree.add_child(_paths)
	_bursts = Control.new()
	_bursts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tree.add_child(_bursts)
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 8)
	_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(_bar)
	var dp = PanelContainer.new()
	dp.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.07, 0.055, 0.1, 0.96), UiTheme.PANEL_EDGE, 16, 2))
	dp.custom_minimum_size = Vector2(440, 0)
	h.add_child(dp)
	var dsc = ScrollContainer.new()
	dsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dp.add_child(dsc)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 8)
	dsc.add_child(_detail)
	_sel = _recommended() if _recommended() != "" else (ch.skill_bar[0] if ch.skill_bar[0] != "" else "")
	if ctx.has("sel"):
		_sel = str(ctx.sel)
	refresh()

func _skills() -> Array:
	var out = Content.where("skills", "class", ch.class_id).filter(func(s): return s.id != ch.cls().get("basic_attack", ""))
	out.sort_custom(func(a, b): return int(a.get("unlock_level", 1)) < int(b.get("unlock_level", 1)))
	return out

func _branches() -> Array:
	var order = []
	for s in _skills():
		var b = str(s.get("branch", "core"))
		if not order.has(b):
			order.append(b)
	return order

func _rank(id: String) -> int:
	return int(ch.skill_ranks.get(id, 0))

func _can_rank(s: Dictionary) -> bool:
	return ch.skill_points > 0 and ch.level >= int(s.get("unlock_level", 1)) and _rank(s.id) < int(s.get("max_rank", 5))

func _recommended() -> String:
	var path: Array = ch.cls().get("recommended_path", [])
	for id in path:
		var s = Content.get_rec("skills", str(id))
		if not s.is_empty() and _can_rank(s):
			return s.id
	var best = ""
	var best_r = 99
	for s in _skills():
		if _can_rank(s):
			var r = _rank(s.id) - (2 if ch.skill_bar.has(s.id) else 0)
			if r < best_r:
				best_r = r
				best = s.id
	return best

func _is_capstone(s: Dictionary, branch_list: Array) -> bool:
	if s.has("capstone"):
		return bool(s.capstone)
	return branch_list.size() >= 2 and branch_list[-1].id == s.id

func refresh() -> void:
	_pts_lbl.text = "%d point%s" % [ch.skill_points, "" if ch.skill_points == 1 else "s"]
	for n in _nodes.values():
		n.queue_free()
	_nodes.clear()
	var branches = _branches()
	var rec = _recommended() if _recommend else ""
	var col_w = 230.0
	var row_h = 150.0
	var max_rows = 1
	var sel_rec = Content.get_rec("skills", _sel)
	for bi in branches.size():
		var list = _skills().filter(func(s): return str(s.get("branch", "core")) == branches[bi])
		max_rows = max(max_rows, list.size())
		for ri in list.size():
			var s: Dictionary = list[ri]
			var n = _node(s, s.id == rec, _is_capstone(s, list), _synergy(sel_rec, s))
			_tree.add_child(n)
			n.position = Vector2(bi * col_w + (col_w - 104) * 0.5, 54 + ri * row_h)
			n.set_meta("branch", bi)
			_nodes[s.id] = n
	# Branch headers
	for c in _tree.get_children():
		if c.has_meta("header"):
			c.queue_free()
	for bi in branches.size():
		var first = _skills().filter(func(s): return str(s.get("branch", "core")) == branches[bi])
		var col = Color(first[0].get("color", "#ffd98a")) if first.size() > 0 else UiTheme.GOLD
		var l = UiTheme.label(str(branches[bi]).capitalize(), 22, col, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = Vector2(bi * col_w, 10)
		l.size = Vector2(col_w, 30)
		l.set_meta("header", true)
		_tree.add_child(l)
	_tree.custom_minimum_size = Vector2(branches.size() * col_w, 54 + max_rows * row_h)
	_paths.size = _tree.custom_minimum_size
	_bursts.size = _tree.custom_minimum_size
	_paths.queue_redraw()
	_refresh_bar()
	_show_detail()

func _synergy(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or a.id == b.id:
		return false
	if a.get("element", "") != "" and a.get("element", "") == b.get("element", "") and a.get("element", "") != "physical":
		return true
	for t in a.get("tags", []):
		if t != "basic" and b.get("tags", []).has(t):
			return true
	var syn: Array = a.get("synergy", [])
	return syn.has(b.id)

func _node(s: Dictionary, recommended: bool, capstone: bool, synergy: bool) -> Button:
	var col = Color(s.get("color", "#ffd98a"))
	var r = _rank(s.id)
	var locked = ch.level < int(s.get("unlock_level", 1))
	var b = Button.new()
	b.custom_minimum_size = Vector2(104, 104)
	b.size = Vector2(104, 104)
	b.focus_mode = Control.FOCUS_NONE
	var st = StyleBoxFlat.new()
	st.bg_color = col.darkened(0.82) if r > 0 else Color(0.08, 0.07, 0.1)
	st.border_color = col if r > 0 else (col.darkened(0.45) if not locked else UiTheme.LOCKED)
	st.set_border_width_all(5 if (s.id == _sel or capstone) else 3)
	st.set_corner_radius_all(52 if not capstone else 20)
	st.anti_aliasing = true
	if s.id == _sel:
		st.border_color = Color.WHITE
		st.shadow_color = Color(col, 0.7)
		st.shadow_size = 14
	elif recommended:
		st.shadow_color = Color(UiTheme.GOLD, 0.8)
		st.shadow_size = 16
	elif synergy:
		st.shadow_color = Color("#9cffb0", 0.6)
		st.shadow_size = 10
	for k in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, st)
	var ic = UiTheme.icon_rect(ActionButton.icon_name_for(s.id), 64, col.lightened(0.25) if not locked else UiTheme.LOCKED)
	UiTheme.place(ic, 0, 0, 20, 16, 64, 64)
	b.add_child(ic)
	if locked:
		var lk = UiTheme.icon_rect("lock", 30, UiTheme.MUTED)
		UiTheme.place(lk, 1.0, 0.0, -30, -4, 30, 30)
		b.add_child(lk)
		var ll = UiTheme.label("Lv %d" % int(s.get("unlock_level", 1)), 16, UiTheme.MUTED)
		ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UiTheme.place(ll, 0.5, 1.0, -40, -26, 80, 24)
		b.add_child(ll)
	# rank pips under the node
	var pips = Control.new()
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mr = int(s.get("max_rank", 5))
	UiTheme.place(pips, 0.5, 1.0, -60, 6, 120, 16)
	pips.draw.connect(func():
		var w = 120.0 / mr
		for i in mr:
			var c = Vector2(w * i + w * 0.5, 8)
			pips.draw_circle(c, 6.5, Color(0, 0, 0, 0.8))
			pips.draw_circle(c, 5, col if i < r else Color(0.25, 0.22, 0.3)))
	b.add_child(pips)
	if capstone:
		var cap = UiTheme.icon_rect("crown", 28, UiTheme.GOLD)
		UiTheme.place(cap, 0.0, 0.0, -6, -8, 28, 28)
		b.add_child(cap)
	if ch.skill_bar.has(s.id):
		var sl = UiTheme.label(str(ch.skill_bar.find(s.id) + 1), 18, Color.WHITE)
		var sp = PanelContainer.new()
		var ss = UiTheme.panel_style(col.darkened(0.3), Color.WHITE, 12, 2)
		ss.content_margin_left = 7
		ss.content_margin_right = 7
		ss.content_margin_top = 0
		ss.content_margin_bottom = 0
		sp.add_theme_stylebox_override("panel", ss)
		sp.add_child(sl)
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiTheme.place(sp, 1.0, 1.0, -26, -30, 28, 28)
		b.add_child(sp)
	var mp = UiTheme.api_call("SkillMastery", "xp_progress", [ch, s.id], {})
	if mp is Dictionary and bool(mp.get("ready", false)):
		var spk = UiTheme.icon_rect("spark", 30, UiTheme.GOLD)
		UiTheme.place(spk, 1.0, 0.0, -24, -8, 30, 30)
		b.add_child(spk)
	b.pressed.connect(func():
		Sfx.play("ui_click", -6.0)
		if _assign_slot >= 0 and r > 0:
			_place(s.id, _assign_slot)
			return
		_sel = s.id
		refresh())
	UiTheme.juice(b)
	return b

func _draw_paths() -> void:
	var branches = _branches()
	for bi in branches.size():
		var list = _skills().filter(func(s): return str(s.get("branch", "core")) == branches[bi])
		for i in range(1, list.size()):
			var a: Button = _nodes.get(list[i - 1].id)
			var b: Button = _nodes.get(list[i].id)
			if a == null or b == null:
				continue
			var pa = a.position + Vector2(52, 104 + 28)
			var pb = b.position + Vector2(52, -4)
			var lit = _rank(list[i - 1].id) > 0
			var col = Color(list[i - 1].get("color", "#ffd98a"))
			_paths.draw_line(pa, pb, Color(0, 0, 0, 0.7), 12.0, true)
			_paths.draw_line(pa, pb, Color(col, 0.95) if lit else Color(0.3, 0.27, 0.34), 6.0, true)
			if lit:
				_paths.draw_line(pa, pb, Color(1, 1, 1, 0.5), 2.0, true)

func _refresh_bar() -> void:
	ScreenBase.clear(_bar)
	_bar.add_child(UiTheme.label("Bar", 18, UiTheme.MUTED, true))
	var basic = str(ch.cls().get("basic_attack", ""))
	var bb = ActionButton.new()
	bb.setup("attack", basic, 76)
	bb.custom_minimum_size = Vector2(76, 76)
	_bar.add_child(bb)
	for i in 4:
		var slot_i = i
		var holder = Button.new()
		holder.custom_minimum_size = Vector2(84, 84)
		holder.focus_mode = Control.FOCUS_NONE
		var sel = _assign_slot == i
		var st = StyleBoxFlat.new()
		st.bg_color = Color(0, 0, 0, 0)
		st.border_color = UiTheme.GOLD if sel else Color(0, 0, 0, 0)
		st.set_border_width_all(3)
		st.set_corner_radius_all(42)
		for k in ["normal", "hover", "pressed", "focus"]:
			holder.add_theme_stylebox_override(k, st)
		var ab = ActionButton.new()
		ab.setup("skill%d" % i, ch.skill_bar[i], 76)
		ab.position = Vector2(4, 4)
		holder.add_child(ab)
		holder.pressed.connect(func():
			if _sel != "" and _rank(_sel) > 0 and _assign_slot < 0:
				_place(_sel, slot_i)
			else:
				_assign_slot = -1 if _assign_slot == slot_i else slot_i
				_refresh_bar()
				if _assign_slot >= 0:
					flash_msg("Now tap a learned skill", UiTheme.GOLD, "skills"))
		UiTheme.juice(holder)
		_bar.add_child(holder)

func _place(id: String, slot: int) -> void:
	for j in 4:
		if ch.skill_bar[j] == id:
			ch.skill_bar[j] = ""
	ch.skill_bar[slot] = id
	_assign_slot = -1
	Sfx.play("equip", -6.0)
	_notify_bar()
	refresh()

# ------------------------------------------------------------------ detail panel
func _show_detail() -> void:
	ScreenBase.clear(_detail)
	var s = Content.get_rec("skills", _sel)
	if s.is_empty():
		_detail.add_child(UiTheme.wrap_label("Tap a skill to see it.", 20, UiTheme.MUTED, 380))
		return
	var col = Color(s.get("color", "#ffd98a"))
	var r = _rank(s.id)
	var mr = int(s.get("max_rank", 5))
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_detail.add_child(head)
	var ab = ActionButton.new()
	ab.setup("skill0", s.id, 88)
	ab.custom_minimum_size = Vector2(88, 88)
	head.add_child(ab)
	var hv = VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	var nm = UiTheme.label(str(s.get("name", s.id)), 28, col.lightened(0.25), true)
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.custom_minimum_size = Vector2(280, 0)
	hv.add_child(nm)
	hv.add_child(UiTheme.label("Rank %d / %d" % [r, mr] if r > 0 else "Unlocks at level %d" % int(s.get("unlock_level", 1)), 18, UiTheme.MUTED))
	var tags = HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", 6)
	hv.add_child(tags)
	var tl = s.get("tags", []).duplicate()
	if s.get("element", "") != "":
		tl.push_front(s.element)
	for t in tl:
		var e = str(t)
		tags.add_child(UiTheme.pill(e if UiTheme.has_icon(e) else "spark", e.capitalize(), col, 15))
	# 3 numbers max
	var nums = HBoxContainer.new()
	nums.add_theme_constant_override("separation", 8)
	_detail.add_child(nums)
	var mult = 0.0
	for e in s.get("effects", []):
		mult = max(mult, float(e.get("mult", 0.0)))
	if mult > 0:
		nums.add_child(_num("damage", "%d%%" % int(round(mult * 100 * (1.0 + 0.1 * max(0, r - 1)))), "Power", UiTheme.EMBER))
	nums.add_child(_num("resource", str(int(s.get("cost", 0))), str(ch.cls().get("resource_name", "Cost")), Color(ch.cls().get("color", "#8fd0ff"))))
	nums.add_child(_num("cooldown", "%ss" % str(s.get("cooldown", 0)), "Cooldown", Color("#a8c0d8")))
	_detail.add_child(UiTheme.wrap_label(str(s.get("desc", "")), 19, UiTheme.TEXT, 390))
	# Actions: + rank, place on bar
	var acts = HBoxContainer.new()
	acts.add_theme_constant_override("separation", 8)
	_detail.add_child(acts)
	var up = UiTheme.icon_button("plus", "Learn" if r == 0 else "Rank up", func(): _rank_up(s), Vector2(190, 84), UiTheme.GOOD, true, 22)
	up.disabled = not _can_rank(s)
	if not up.disabled:
		up.add_theme_stylebox_override("normal", UiTheme.panel_style(Color(0.08, 0.22, 0.1, 0.97), UiTheme.GOOD, 14, 3))
	acts.add_child(up)
	if r > 0:
		for i in 4:
			var si = i
			var pb = UiTheme.button(str(i + 1), func(): _place(s.id, si), 22, Vector2(52, 84))
			if ch.skill_bar[i] == s.id:
				pb.add_theme_stylebox_override("normal", UiTheme.panel_style(col.darkened(0.6), col, 12, 3))
			acts.add_child(pb)
	if not _can_rank(s) and r < mr:
		var why = "No skill points" if ch.skill_points <= 0 else ("Reach level %d" % int(s.get("unlock_level", 1)) if ch.level < int(s.get("unlock_level", 1)) else "")
		if why != "":
			_detail.add_child(UiTheme.label(why, 17, UiTheme.MUTED))
	_modifiers(s)
	_mastery(s)

func _num(icon_name: String, v: String, word: String, col: Color) -> Control:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(col.darkened(0.85), 0.9), col.darkened(0.35), 12, 2))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	h.add_child(UiTheme.icon_rect(icon_name, 32, col))
	var v2 = VBoxContainer.new()
	v2.add_theme_constant_override("separation", -4)
	h.add_child(v2)
	v2.add_child(UiTheme.label(v, 22, UiTheme.TEXT))
	v2.add_child(UiTheme.label(word, 14, UiTheme.MUTED))
	return p

func _modifiers(s: Dictionary) -> void:
	var tiers: Array = UiTheme.api_call("SkillMods", "available", [ch, s.id], [])
	if tiers.is_empty():
		return
	_detail.add_child(UiTheme.separator())
	_detail.add_child(UiTheme.label("Choose how it works", 22, UiTheme.GOLD, true))
	for t in tiers:
		var unlocked = bool(t.get("unlocked", false))
		_detail.add_child(UiTheme.label("Rank %d%s" % [int(t.get("rank", 2)), "" if unlocked else "  (locked)"], 17, UiTheme.MUTED if not unlocked else UiTheme.TEXT))
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_detail.add_child(row)
		for o in t.get("options", []):
			var chosen = str(t.get("chosen", "")) == str(o.get("id", ""))
			var oid = str(o.get("id", ""))
			var b = Button.new()
			b.custom_minimum_size = Vector2(130, 150)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.disabled = not unlocked
			var col = Color(s.get("color", "#ffd98a"))
			b.add_theme_stylebox_override("normal", UiTheme.card_style(col if unlocked else UiTheme.LOCKED, chosen))
			b.add_theme_stylebox_override("hover", UiTheme.card_style(col, true))
			b.add_theme_stylebox_override("disabled", UiTheme.card_style(UiTheme.LOCKED, false))
			var v = VBoxContainer.new()
			v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			v.offset_left = 6
			v.offset_right = -6
			v.offset_top = 6
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_theme_constant_override("separation", 2)
			b.add_child(v)
			var ic = str(o.get("icon", ActionButton.icon_name_for(s.id)))
			var ir = UiTheme.icon_rect(ic if UiTheme.has_icon(ic) else "spark", 36, col if unlocked else UiTheme.LOCKED)
			ir.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			v.add_child(ir)
			var on = UiTheme.label(str(o.get("name", oid)), 17, UiTheme.TEXT if unlocked else UiTheme.MUTED, true)
			on.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			on.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(on)
			var od = UiTheme.label(str(o.get("desc", "")), 13, UiTheme.MUTED)
			od.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			od.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			od.custom_minimum_size = Vector2(118, 0)
			b.tooltip_text = str(o.get("name", "")) + ": " + str(o.get("desc", ""))
			v.add_child(od)
			if chosen:
				var ck = UiTheme.icon_rect("check", 26, UiTheme.GOOD)
				UiTheme.place(ck, 1.0, 0.0, -30, 4, 26, 26)
				b.add_child(ck)
			b.pressed.connect(func():
				var res = UiTheme.api_call("SkillMods", "choose", [ch, s.id, oid], {"ok": false, "message": "Not available"})
				flash_msg(str(res.get("message", "")), UiTheme.GOLD if res.get("ok", false) else UiTheme.BAD, "check" if res.get("ok", false) else "lock")
				if res.get("ok", false):
					Sfx.play("skill_up", -4.0)
				refresh())
			UiTheme.juice(b)
			row.add_child(b)

func _mastery(s: Dictionary) -> void:
	var mp = UiTheme.api_call("SkillMastery", "xp_progress", [ch, s.id], null)
	if not (mp is Dictionary):
		return
	_detail.add_child(UiTheme.separator())
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	_detail.add_child(head)
	head.add_child(UiTheme.icon_rect("star", 30, UiTheme.GOLD))
	var rk = int(mp.get("rank", 0))
	var mx = int(mp.get("max_rank", 20))
	var hl = UiTheme.label("Mastery %d / %d" % [rk, mx], 22, UiTheme.GOLD, true)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hl)
	var bar = UiTheme.progress_bar(UiTheme.GOLD if bool(mp.get("ready", false)) else Color("#c79a4a"), 16)
	bar.value = 1.0 if rk >= mx else clampf(float(mp.get("xp", 0)) / max(1.0, float(mp.get("next_xp", 1))), 0.0, 1.0)
	_detail.add_child(bar)
	if rk < mx:
		_detail.add_child(UiTheme.label("%s / %s mastery XP · use the skill to grow it" % [UiTheme.fmt_num(float(mp.get("xp", 0))), UiTheme.fmt_num(float(mp.get("next_xp", 0)))], 15, UiTheme.MUTED))
		var cost: Dictionary = mp.get("cost", {})
		var ch_row = HFlowContainer.new()
		ch_row.add_theme_constant_override("h_separation", 6)
		_detail.add_child(ch_row)
		if cost.has("gold"):
			ch_row.add_child(_cost_pill("gold", int(cost.gold), ch.gold, UiTheme.COIN))
		for m in cost.get("materials", {}):
			var rec = Content.get_rec("materials", m)
			ch_row.add_child(_cost_pill(m if UiTheme.has_icon(m) else "material", int(cost.materials[m]), int(ch.materials.get(m, 0)), Color(rec.get("color", "#cccccc"))))
		var ub = UiTheme.icon_button("upgrade", "Master", func():
			var res = UiTheme.api_call("SkillMastery", "upgrade", [ch, s.id], {"ok": false, "message": "Not available"})
			if res.get("ok", false):
				_celebrate(s.id)
			flash_msg(str(res.get("message", "")), UiTheme.GOLD if res.get("ok", false) else UiTheme.BAD, "star")
			refresh(), Vector2(200, 80), UiTheme.GOLD, true, 22)
		ub.disabled = not bool(mp.get("can_upgrade", false))
		if not ub.disabled:
			ub.add_theme_stylebox_override("normal", UiTheme.panel_style(Color(0.32, 0.2, 0.04, 0.97), UiTheme.GOLD, 14, 3))
		var urow = HBoxContainer.new()
		urow.add_theme_constant_override("separation", 8)
		_detail.add_child(urow)
		urow.add_child(ub)
		if str(mp.get("reason", "")) != "":
			var rl = UiTheme.label(str(mp.reason), 16, UiTheme.MUTED)
			rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			urow.add_child(rl)
	# Milestones 5/10/15/20
	var mrec = UiTheme.api_call("SkillMastery", "mastery_rec", [s.id], {})
	var ms_data: Array = mrec.get("milestones", []) if mrec is Dictionary else []
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_detail.add_child(row)
	for m in [5, 10, 15, 20]:
		var reached = rk >= m
		var desc = ""
		for md in ms_data:
			if int(md.get("rank", 0)) == m:
				desc = str(md.get("desc", md.get("name", "")))
		var p = PanelContainer.new()
		p.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.2, 0.14, 0.04, 0.9) if reached else Color(0.08, 0.07, 0.1, 0.9), UiTheme.GOLD if reached else Color(0.3, 0.28, 0.32), 10, 2))
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.tooltip_text = desc if desc != "" else "Mastery %d: a stronger %s" % [m, s.get("name", "")]
		var v = VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		p.add_child(v)
		var ir = UiTheme.icon_rect("star" if reached else "lock", 24, UiTheme.GOLD if reached else UiTheme.MUTED)
		ir.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ir)
		var l = UiTheme.label(str(m), 18, UiTheme.GOLD if reached else UiTheme.MUTED)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		row.add_child(p)

func _cost_pill(icon_name: String, need: int, have: int, col: Color) -> Control:
	var p = UiTheme.pill(icon_name, "%s/%s" % [UiTheme.fmt_num(have), UiTheme.fmt_num(need)], col, 17)
	(p.find_child("Value", true, false) as Label).add_theme_color_override("font_color", UiTheme.GOOD if have >= need else UiTheme.BAD)
	return p

# ------------------------------------------------------------------ actions
func _rank_up(s: Dictionary) -> void:
	if not _can_rank(s):
		return
	var was = _rank(s.id)
	ch.skill_points -= 1
	ch.skill_ranks[s.id] = was + 1
	ch.recalc()
	if was == 0:
		_auto_place(s.id)
	_celebrate(s.id)
	var tiers: Array = UiTheme.api_call("SkillMods", "available", [ch, s.id], [])
	for t in tiers:
		if int(t.get("rank", 0)) == was + 1:
			flash_msg("New choice unlocked — pick how it works!", UiTheme.GOLD, "star")
	refresh()

func _celebrate(id: String) -> void:
	Sfx.play("skill_up")
	UiTheme.haptic(20, 0.6)
	var n: Button = _nodes.get(id)
	if n == null:
		return
	var c = n.position + Vector2(52, 52)
	var col = Color(Content.get_rec("skills", id).get("color", "#ffd98a"))
	var p = CPUParticles2D.new()
	p.position = c
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 28
	p.lifetime = 0.7
	p.spread = 180
	p.initial_velocity_min = 120
	p.initial_velocity_max = 260
	p.gravity = Vector2(0, 200)
	p.scale_amount_min = 3
	p.scale_amount_max = 6
	p.color = col.lightened(0.3)
	_bursts.add_child(p)
	var ring = Control.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.position = c
	var state = {"r": 40.0, "a": 1.0}
	ring.draw.connect(func(): ring.draw_arc(Vector2.ZERO, state.r, 0, TAU, 40, Color(col, state.a), 5.0, true))
	_bursts.add_child(ring)
	var t = ring.create_tween()
	t.tween_method(func(v):
		state.r = 40.0 + v * 60.0
		state.a = 1.0 - v
		ring.queue_redraw(), 0.0, 1.0, 0.45)
	t.tween_callback(ring.queue_free)
	var t2 = get_tree().create_timer(1.0, true)
	t2.timeout.connect(p.queue_free)

func _auto_place(id: String) -> void:
	for i in 4:
		if ch.skill_bar[i] == "":
			ch.skill_bar[i] = id
			_notify_bar()
			return

func _notify_bar() -> void:
	if session and session.get("hud") and session.hud:
		session.hud.touch.refresh_bar()

func _respec() -> void:
	var res = UiTheme.api_call("Builds", "respec_skills", [ch], {"ok": false, "message": "Not available"})
	flash_msg(str(res.get("message", "")), UiTheme.GOLD if res.get("ok", false) else UiTheme.BAD, "undo")
	_notify_bar()
	update_gold_pill()
	refresh()

func _loadout_button(i: int) -> Button:
	var loads: Array = UiTheme.chf(ch, "loadouts", [])
	var has = i < loads.size() and loads[i] is Dictionary and not loads[i].is_empty()
	var b = UiTheme.button(str(i + 1), func():
		if has:
			var res = UiTheme.api_call("Builds", "load_loadout", [ch, i], {"ok": false, "message": ""})
			flash_msg(str(res.get("message", "Build %d loaded" % (i + 1))), UiTheme.GOLD, "skills")
			_notify_bar()
			refresh()
		else:
			var res2 = UiTheme.api_call("Builds", "save_loadout", [ch, i, "Build %d" % (i + 1)], {"ok": false, "message": ""})
			flash_msg(str(res2.get("message", "Build %d saved" % (i + 1))), UiTheme.GOLD, "check")
			goto_refresh(), 20, Vector2(60, 60))
	b.tooltip_text = ("Load build %d (long-press saves)" if has else "Save this build in slot %d") % (i + 1)
	if has:
		b.add_theme_stylebox_override("normal", UiTheme.panel_style(Color(0.2, 0.14, 0.3, 0.95), UiTheme.XP, 12, 2))
	return b

func goto_refresh() -> void:
	var sess = session
	var sel = _sel
	ScreenBase.open(sess, "skills", {"sel": sel})
	queue_free()
