extends ScreenBase
## World map: acts as rows of waypoint tiles (town / zone / boss), you-are-here marker, fast-travel
## fee (free to towns), story locks; Homeward Wick button with cooldown + bound town; difficulty tier.

var ch: CharacterData
var _list: VBoxContainer

func _ready() -> void:
	ch = Game.character
	if screen_id == "":
		screen_id = "map"
	build("Map", "map", true)
	var v = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 8)
	body.add_child(v)
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	_hearth_card(top)
	top.add_child(UiTheme.spacer(0, 0, true))
	var tiers = HBoxContainer.new()
	tiers.add_theme_constant_override("separation", 6)
	top.add_child(tiers)
	var diffs = Content.all("difficulties")
	diffs.sort_custom(func(a, b): return int(a.order) < int(b.order))
	for d in diffs.slice(0, 5):
		var unlocked = ch.unlocked_tiers.has(d.id)
		var did = str(d.id)
		var b = UiTheme.icon_button("skull_soft" if unlocked else "lock", str(d.name), func():
			if did == ch.difficulty:
				return
			ch.difficulty = did
			Events.difficulty_changed.emit(did)
			close()
			session.travel(ch.current_act_town()), Vector2(0, 76), UiTheme.EMBER if ch.difficulty == did else (UiTheme.MUTED if unlocked else UiTheme.LOCKED), true, 16)
		b.custom_minimum_size = Vector2(130, 76)
		b.disabled = not unlocked
		b.tooltip_text = str(d.get("desc", ""))
		if ch.difficulty == did:
			b.add_theme_stylebox_override("normal", UiTheme.panel_style(Color(0.3, 0.12, 0.06, 0.95), UiTheme.EMBER, 12, 3))
		tiers.add_child(b)
	var sc = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	sc.add_child(_list)
	_build_acts()

func _hearth_card(parent: Control) -> void:
	var left = float(UiTheme.api_call("Travel", "hearth_cooldown_left", [ch], 0.0))
	var bound = str(UiTheme.chf(ch, "bound_town", ""))
	if bound == "":
		bound = ch.current_act_town()
	var in_town = Game.world != null and bool(Game.world.get("is_town"))
	var b = UiTheme.icon_button("hearth", "Homeward Wick", func():
		close()
		sess_call("hearth", [], null), Vector2(250, 76), UiTheme.EMBER, true, 18)
	b.disabled = in_town or str(UiTheme.api_call("Travel", "can_hearth", [ch], "x")) != ""
	b.tooltip_text = "Return to %s (3 s, then %s cooldown of play)" % [Content.get_rec("zones", bound).get("name", ""), UiTheme.fmt_time(float(UiTheme.api_call("Travel", "cfg", [], {}).get("hearth_cooldown_s", 300)))]
	parent.add_child(b)
	var info = VBoxContainer.new()
	info.add_theme_constant_override("separation", -2)
	parent.add_child(info)
	info.add_child(UiTheme.label("Home: %s" % Content.get_rec("zones", bound).get("name", "?"), 17, UiTheme.TEXT))
	var charges = int(UiTheme.chf(ch, "wick_charges", 0))
	var st = "Ready" if left <= 0 else "Rekindles in " + UiTheme.fmt_time(left)
	if charges > 0:
		st += " · %d spare wick%s" % [charges, "s" if charges > 1 else ""]
	info.add_child(UiTheme.label(st, 16, UiTheme.GOOD if left <= 0 else UiTheme.MUTED))

func _build_acts() -> void:
	var here = str(Game.world.zone.get("id", "")) if Game.world else ""
	for a in Content.all("acts"):
		var act_lock = str(UiTheme.api_call("MainQuest", "act_locked", [ch, a.id], ""))
		var zones: Array = [a.town] + a.zones
		var any_known = false
		for zid in zones:
			if ch.waypoints.has(zid):
				any_known = true
		if not any_known and act_lock != "":
			var l = HBoxContainer.new()
			l.add_theme_constant_override("separation", 8)
			l.add_child(UiTheme.icon_rect("lock", 30, UiTheme.LOCKED))
			l.add_child(UiTheme.label("%s — %s" % [a.name, act_lock], 19, UiTheme.MUTED, true))
			_list.add_child(l)
			continue
		_list.add_child(UiTheme.label(str(a.name), 24, UiTheme.GOLD, true))
		var row = HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 8)
		row.add_theme_constant_override("v_separation", 8)
		_list.add_child(row)
		for i in zones.size():
			row.add_child(_zone_tile(str(zones[i]), here, i == zones.size() - 1))

func _zone_tile(zid: String, here: String, last: bool) -> Control:
	var z = Content.get_rec("zones", zid)
	var known = ch.waypoints.has(zid)
	var lock = str(UiTheme.api_call("MainQuest", "zone_locked", [ch, zid], ""))
	var is_town = bool(z.get("town", false))
	var is_boss = str(z.get("boss", "")) != ""
	var fee = int(UiTheme.api_call("Travel", "fee", [ch, zid], 0))
	var can = str(UiTheme.api_call("Travel", "can_fast_travel", [ch, zid], "" if known else "Not discovered")) == "" and lock == ""
	var col = UiTheme.GOLD if is_town else (Color("#ff8a6a") if is_boss else Color("#8fd0ff"))
	var b = Button.new()
	b.custom_minimum_size = Vector2(228, 110)
	var cur = zid == here
	b.add_theme_stylebox_override("normal", UiTheme.card_style(col if known else UiTheme.LOCKED, cur))
	b.add_theme_stylebox_override("hover", UiTheme.card_style(col, true))
	b.add_theme_stylebox_override("disabled", UiTheme.card_style(UiTheme.LOCKED, false))
	var v = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 6
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	h.add_child(UiTheme.icon_rect("lock" if lock != "" else ("hearth" if is_town else ("skull_soft" if is_boss else "waypoint")), 40, col if known else UiTheme.LOCKED))
	var nm = UiTheme.label(str(z.get("name", zid)) if known else "???", 17, UiTheme.TEXT if known else UiTheme.MUTED, true)
	nm.clip_text = true
	nm.custom_minimum_size = Vector2(160, 0)
	h.add_child(nm)
	var sub = HBoxContainer.new()
	sub.add_theme_constant_override("separation", 6)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sub)
	if cur:
		sub.add_child(UiTheme.pill("pin", "You are here", UiTheme.EMBER, 15))
	elif lock != "":
		var ll = UiTheme.label(lock, 14, UiTheme.MUTED)
		ll.clip_text = true
		ll.custom_minimum_size = Vector2(190, 0)
		sub.add_child(ll)
	elif known:
		sub.add_child(UiTheme.pill("gold", "Free" if fee == 0 else UiTheme.fmt_num(fee), UiTheme.COIN, 15))
		sub.add_child(UiTheme.label("Lv %d" % int(z.get("level", 1)), 15, UiTheme.MUTED))
	b.disabled = cur or not can
	b.pressed.connect(func():
		if ch.gold < fee:
			flash_msg("Not enough gold", UiTheme.BAD, "gold")
			return
		close()
		if session and session.has_method("fast_travel"):
			session.fast_travel(zid)
		else:
			session.travel(zid))
	UiTheme.juice(b)
	return b
