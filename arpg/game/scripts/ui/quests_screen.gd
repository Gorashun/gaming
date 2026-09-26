extends ScreenBase
## Quest journal + NPC dialogue: Story (main quest chapters, objectives with progress) · Side quests
## (progress, rewards, abandon) · and, when opened by an NPC, a dialogue panel with that NPC's offers
## (text, reward icons, Accept) and ready quests (Claim rewards).

var ch: CharacterData
var _tab = "story"
var _tabs: HBoxContainer
var _list: VBoxContainer

func _ready() -> void:
	ch = Game.character
	if screen_id == "":
		screen_id = "quests"
	if _npc_id() != "" and (_offers().size() > 0 or _ready_list().size() > 0):
		_tab = "npc"
	elif ctx.has("tab"):
		_tab = str(ctx.tab)
	build("Quests", "quests", true)
	var v = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 8)
	body.add_child(v)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	v.add_child(_tabs)
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.08, 0.065, 0.11, 0.95), UiTheme.PANEL_EDGE, 14, 2))
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(p)
	var sc = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	sc.add_child(_list)
	refresh()

func _npc_id() -> String:
	return str(npc_rec().get("id", ""))

func _offers() -> Array:
	return UiTheme.api_call("Quests", "available_for", [ch, _npc_id()], [])

func _ready_list() -> Array:
	return UiTheme.api_call("Quests", "ready_for", [ch, _npc_id()], [])

static func mq_text(chapter: Dictionary) -> Dictionary:
	return Content.get_rec("main_quest_text", str(chapter.get("text_ref", chapter.get("id", ""))))

static func objective_text(chapter: Dictionary, idx: int) -> String:
	var objs: Array = chapter.get("objectives", [])
	if idx < 0 or idx >= objs.size():
		return ""
	var o: Dictionary = objs[idx]
	if o.has("text"):
		return str(o.text)
	var t: Array = mq_text(chapter).get("objectives", [])
	if idx < t.size() and t[idx] is Dictionary and t[idx].has("text"):
		return str(t[idx].text)
	var target = str(o.get("target", ""))
	var nm = str(Content.get_rec("zones", target).get("name", Content.get_rec("npcs", target).get("name", Content.get_rec("monsters", target).get("name", target.replace("_", " ")))))
	return "%s %s" % [str(o.get("type", "")).capitalize(), nm]

func refresh() -> void:
	ScreenBase.clear(_tabs)
	var tabs = [["story", "star", "Story"], ["side", "quests", "Side quests"]]
	if _npc_id() != "":
		tabs.push_front(["npc", "talk", str(npc_rec().get("name", "Talk"))])
	for t in tabs:
		var id: String = t[0]
		var b = UiTheme.icon_button(t[1], t[2], func():
			_tab = id
			refresh(), Vector2(0, 68), UiTheme.GOLD if id == _tab else UiTheme.MUTED, true, 19)
		b.custom_minimum_size = Vector2(220, 68)
		if id == _tab:
			b.add_theme_stylebox_override("normal", UiTheme.panel_style(Color(0.3, 0.18, 0.08, 0.95), UiTheme.EMBER, 12, 3))
		_tabs.add_child(b)
	ScreenBase.clear(_list)
	match _tab:
		"npc":
			_npc_panel()
		"story":
			_story()
		_:
			_side()

func _rewards_row(r: Dictionary) -> HFlowContainer:
	var row = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	if r.has("gold"):
		row.add_child(UiTheme.pill("gold", UiTheme.fmt_num(int(r.gold)), UiTheme.COIN, 17))
	if r.has("xp") or r.has("xp_levels"):
		row.add_child(UiTheme.pill("xp", "XP" if not r.has("xp") else UiTheme.fmt_num(int(r.xp)), UiTheme.XP, 17))
	if r.has("item_rarity"):
		row.add_child(UiTheme.pill("bag", UiTheme.rarity_name(str(r.item_rarity)), UiTheme.rarity_color(str(r.item_rarity)), 17))
	if r.has("pet"):
		row.add_child(UiTheme.pill("pets", str(Content.get_rec("pets", str(r.pet)).get("name", "Pet")), Color("#ffb3de"), 17))
	if r.has("mount"):
		row.add_child(UiTheme.pill("mounts", str(Content.get_rec("mounts", str(r.mount)).get("name", "Mount")), Color("#d9b27a"), 17))
	if r.has("skill_points"):
		row.add_child(UiTheme.pill("skills", "+%d" % int(r.skill_points), UiTheme.XP, 17))
	if r.has("recipe"):
		row.add_child(UiTheme.pill("anvil", "Recipe", UiTheme.GOLD, 17))
	return row

func _npc_panel() -> void:
	var n = npc_rec()
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_list.add_child(head)
	var port = PanelContainer.new()
	port.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.2, 0.14, 0.08, 0.95), UiTheme.GOLD, 48, 3))
	port.add_child(UiTheme.icon_rect("talk", 64, UiTheme.GOLD))
	head.add_child(port)
	var hv = VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	hv.add_child(UiTheme.label("%s · %s" % [n.get("name", ""), n.get("title", str(n.get("role", "")).capitalize())], 24, UiTheme.GOLD, true))
	hv.add_child(UiTheme.wrap_label("“%s”" % str(n.get("greeting", "Hello, little light!")), 20, UiTheme.TEXT, 700))
	for q in _ready_list():
		_quest_card(q, "ready")
	for q in _offers():
		_quest_card(q, "offer")
	if _ready_list().is_empty() and _offers().is_empty():
		_list.add_child(UiTheme.label("No new tasks right now. Come back later!", 19, UiTheme.MUTED))

func _quest_card(q: Dictionary, mode: String) -> void:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.card_style(UiTheme.GOOD if mode == "ready" else UiTheme.GOLD, mode == "ready"))
	_list.add_child(p)
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	h.add_child(UiTheme.icon_rect("check" if mode == "ready" else _qicon(str(q.get("type", ""))), 56, UiTheme.GOOD if mode == "ready" else UiTheme.GOLD))
	var v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	h.add_child(v)
	v.add_child(UiTheme.label(str(q.get("name", q.id)), 22, UiTheme.TEXT, true))
	v.add_child(UiTheme.wrap_label(str(q.get("text_done" if mode == "ready" else "text_offer", "")), 18, UiTheme.MUTED, 640))
	v.add_child(_rewards_row(q.get("reward", {})))
	var qid = str(q.id)
	if mode == "ready":
		var b = UiTheme.icon_button("trophy", "Claim", func():
			var res = sess_call("turn_in", [qid], null)
			if res == null:
				res = UiTheme.api_call("Quests", "turn_in", [ch, qid, Game.world], {"ok": false, "message": ""})
			flash_msg(str(res.get("message", "Done!")), UiTheme.GOLD, "trophy")
			Sfx.play("quest_done")
			refresh(), Vector2(180, 88), UiTheme.GOOD, true, 22)
		b.add_theme_stylebox_override("normal", UiTheme.panel_style(Color(0.08, 0.22, 0.1, 0.97), UiTheme.GOOD, 14, 3))
		h.add_child(b)
	else:
		var b2 = UiTheme.icon_button("check", "Accept", func():
			var ok = sess_call("accept", [qid], null)
			if ok == null:
				ok = UiTheme.api_call("Quests", "accept", [ch, qid], false)
			if ok:
				flash_msg("Quest accepted!", UiTheme.GOLD, "quests")
			refresh(), Vector2(180, 88), UiTheme.GOLD, true, 22)
		h.add_child(b2)

func _qicon(t: String) -> String:
	return {"kill": "sword", "rekindle": "sword", "collect": "bag", "explore": "map", "reach": "map", "boss": "skull_soft", "talk": "talk", "escort": "lantern", "solve": "star"}.get(t, "quests")

func _story() -> void:
	var st = UiTheme.chf(ch, "main_quest", {})
	var done: Array = st.get("done", []) if st is Dictionary else []
	var cur = str(st.get("chapter", "")) if st is Dictionary else ""
	var chapters: Array = UiTheme.api_call("MainQuest", "chapters", [], Content.all("main_quest"))
	if chapters.is_empty():
		_list.add_child(UiTheme.label("The story begins soon.", 20, UiTheme.MUTED))
		return
	var act = ""
	for c in chapters:
		var is_done = done.has(c.id)
		var is_cur = c.id == cur
		if not is_done and not is_cur:
			continue
		if str(c.get("act", "")) != act:
			act = str(c.get("act", ""))
			_list.add_child(UiTheme.label(str(Content.get_rec("acts", act).get("name", act)), 22, UiTheme.GOLD, true))
		var t = mq_text(c)
		var p = PanelContainer.new()
		p.add_theme_stylebox_override("panel", UiTheme.card_style(UiTheme.EMBER if is_cur else Color(0.4, 0.38, 0.3), is_cur))
		_list.add_child(p)
		var v = VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		p.add_child(v)
		var hh = HBoxContainer.new()
		hh.add_theme_constant_override("separation", 8)
		v.add_child(hh)
		hh.add_child(UiTheme.icon_rect("check" if is_done else "star", 30, UiTheme.GOOD if is_done else UiTheme.GOLD))
		hh.add_child(UiTheme.label(str(t.get("title", c.get("name", c.id))), 22, UiTheme.TEXT if is_cur else UiTheme.MUTED, true))
		if is_cur:
			if t.has("summary"):
				v.add_child(UiTheme.wrap_label(str(t.summary), 17, UiTheme.MUTED, 900))
			var tr: Dictionary = UiTheme.api_call("MainQuest", "tracker", [ch], {})
			var idx = int(tr.get("index", 0))
			var objs: Array = c.get("objectives", [])
			for i in objs.size():
				var oh = HBoxContainer.new()
				oh.add_theme_constant_override("separation", 8)
				var od = i < idx
				var on = i == idx
				oh.add_child(UiTheme.icon_rect("check" if od else _qicon(str(objs[i].get("type", ""))), 26, UiTheme.GOOD if od else (UiTheme.GOLD if on else UiTheme.LOCKED)))
				var txt = objective_text(c, i)
				if on:
					var ob: Dictionary = tr.get("objective", {})
					if int(ob.get("count", 1)) > 1:
						txt += "  %d/%d" % [int(ob.get("progress", 0)), int(ob.count)]
				oh.add_child(UiTheme.label(txt, 19, UiTheme.TEXT if on else (UiTheme.GOOD if od else UiTheme.MUTED)))
				v.add_child(oh)
			v.add_child(_rewards_row(c.get("rewards", c.get("reward", {}))))

func _side() -> void:
	var act: Array = UiTheme.api_call("Quests", "active_list", [ch], [])
	if act.is_empty():
		_list.add_child(UiTheme.wrap_label("No side quests yet. Look for townsfolk with something on their mind!", 20, UiTheme.MUTED, 800))
		return
	for e in act:
		var q: Dictionary = e.get("quest", {})
		var ready = str(e.get("state", "")) == "ready"
		var p = PanelContainer.new()
		p.add_theme_stylebox_override("panel", UiTheme.card_style(UiTheme.GOOD if ready else UiTheme.GOLD, ready))
		_list.add_child(p)
		var h = HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		p.add_child(h)
		h.add_child(UiTheme.icon_rect("check" if ready else _qicon(str(q.get("type", ""))), 48, UiTheme.GOOD if ready else UiTheme.GOLD))
		var v = VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(UiTheme.label(str(q.get("name", "")), 21, UiTheme.TEXT, true))
		var giver = str(Content.get_rec("npcs", str(q.get("giver", ""))).get("name", ""))
		v.add_child(UiTheme.label(("Return to %s" % giver) if ready else str(q.get("text_offer", "")), 16, UiTheme.GOOD if ready else UiTheme.MUTED))
		var bar = UiTheme.progress_bar(UiTheme.GOOD if ready else UiTheme.GOLD, 12)
		bar.value = clampf(float(e.get("progress", 0)) / max(1.0, float(e.get("count", 1))), 0.0, 1.0)
		v.add_child(bar)
		v.add_child(_rewards_row(q.get("reward", {})))
		h.add_child(UiTheme.label("%d/%d" % [min(int(e.get("progress", 0)), int(e.get("count", 1))), int(e.get("count", 1))], 24, UiTheme.GOLD))
		var qid = str(q.get("id", ""))
		h.add_child(UiTheme.hold_button("Drop", 0.8, func():
			UiTheme.api_call("Quests", "abandon", [ch, qid], false)
			refresh(), Vector2(110, 72), Color("#9aa0b8"), ""))
