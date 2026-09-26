extends CollectionScreen
## Pets: collection (locked silhouettes), level bars 1–30, bonuses, perk, tricks at 5/15/30,
## set active, feed a treat, send the pet to town with junk (ferry).

func _ready() -> void:
	if screen_id == "":
		screen_id = "pets"
	setup_collection("Pets", "pets")

func records() -> Array:
	return Content.all("pets")

func owned(id: String) -> bool:
	return (UiTheme.chf(ch, "pets_owned", {}) as Dictionary).has(id)

func active_id() -> String:
	return str(UiTheme.chf(ch, "active_pet", ""))

func tile_icon() -> String:
	return "paw"

func _lvl(id: String) -> int:
	return int(UiTheme.api_call("Pets", "level", [ch, id], int(ch.pets_owned.get(id, {}).get("level", 1))))

func tile_sub(r: Dictionary) -> String:
	return "Lv %d" % _lvl(r.id)

func tile_progress(r: Dictionary) -> float:
	var l = _lvl(r.id)
	var mx = int(r.get("max_level", 30))
	if l >= mx:
		return 1.0
	var xp = float(ch.pets_owned.get(r.id, {}).get("xp", 0))
	return clampf(xp / max(1.0, float(UiTheme.api_call("Pets", "xp_to_next", [l], 100))), 0.0, 1.0)

func fill_info(r: Dictionary, box: VBoxContainer) -> void:
	var l = _lvl(r.id)
	var mx = int(r.get("max_level", 30))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	row.add_child(UiTheme.label("Level %d / %d" % [l, mx], 20, UiTheme.GOLD, true))
	var bar = UiTheme.progress_bar(UiTheme.GOLD, 12)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.value = tile_progress(r)
	row.add_child(bar)
	var bpl: Dictionary = r.get("bonuses_per_level", {})
	for k in bpl:
		var h = HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.add_child(UiTheme.icon_rect(UiTheme.stat_icon(k), 28, UiTheme.GOLD))
		h.add_child(UiTheme.label(Items.stat_label(k, float(bpl[k]) * l), 18, Color(0.8, 0.86, 1.0)))
		box.add_child(h)
	var perk = str(r.get("perk", ""))
	if perk != "":
		var pd = {"fetch": "Fetches loot for you", "dig": "Sometimes digs up treasure", "glow": "Lights the way", "lucky": "Brings good luck"}.get(perk, perk.capitalize())
		var h2 = HBoxContainer.new()
		h2.add_theme_constant_override("separation", 8)
		h2.add_child(UiTheme.icon_rect("star", 28, Color("#ffb3de")))
		h2.add_child(UiTheme.label(pd, 18, Color("#ffb3de")))
		box.add_child(h2)
	var tricks: Array = r.get("tricks", [])
	if tricks.size() > 0:
		var tr = HBoxContainer.new()
		tr.add_theme_constant_override("separation", 6)
		box.add_child(tr)
		for t in tricks:
			var got = l >= int(t.get("level", 0))
			tr.add_child(UiTheme.pill("check" if got else "lock", "%d: %s" % [int(t.get("level", 0)), str(t.get("trick", "")).replace("_", " ")], UiTheme.GOOD if got else UiTheme.MUTED, 15))
	var acts = actions_box()
	if r.id != active_id():
		acts.add_child(UiTheme.icon_button("check", "Take along", func():
			var res = sess_call("set_active_pet", [r.id], null)
			if res == null:
				UiTheme.api_call("Pets", "set_active", [ch, r.id], false)
			refresh(), Vector2(200, 76), UiTheme.GOOD, true, 20))
	else:
		acts.add_child(UiTheme.icon_button("treat", "Treat", func():
			var ok = UiTheme.api_call("Pets", "feed_treat", [ch], false)
			flash_msg("Yum! +XP" if ok else "Buy treats from the Trader", UiTheme.GOLD if ok else UiTheme.MUTED, "treat")
			refresh(), Vector2(150, 76), Color("#ffcf80"), true, 20))
		var fs: Dictionary = UiTheme.api_call("Pets", "ferry_status", [ch], {})
		if not fs.is_empty():
			var fb = UiTheme.icon_button("bag", "Junk to town", func():
				var res = sess_call("pet_ferry", ["sell"], null)
				if res == null:
					res = UiTheme.api_call("Pets", "ferry", [ch, "sell"], {"ok": false, "message": ""})
				flash_msg(str(res.get("message", "")), UiTheme.GOLD if res.get("ok", false) else UiTheme.MUTED, "pets")
				update_gold_pill()
				refresh(), Vector2(260, 76), UiTheme.GOLD, true, 17)
			fb.disabled = not bool(fs.get("ready", false))
			if fb.disabled and float(fs.get("cooldown_left", 0)) > 0:
				fb.tooltip_text = "Resting: " + UiTheme.fmt_time(float(fs.cooldown_left))
			acts.add_child(fb)
