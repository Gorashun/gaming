extends CollectionScreen
## Mounts / Stablemaster: collection with speed, set active, buy (gold + quest requirement shown).

func _ready() -> void:
	if screen_id == "":
		screen_id = "mounts"
	setup_collection("Mounts", "mounts")

func _table() -> String:
	return "mounts"

func records() -> Array:
	return Content.all("mounts")

func owned(id: String) -> bool:
	return (UiTheme.chf(ch, "mounts_owned", []) as Array).has(id)

func active_id() -> String:
	return str(UiTheme.chf(ch, "active_mount", ""))

func tile_icon() -> String:
	return "mounts"

func tile_sub(r: Dictionary) -> String:
	return "+%d%% speed" % int(r.get("speed_pct", 0))

func fill_info(r: Dictionary, box: VBoxContainer) -> void:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(UiTheme.icon_rect("speed", 32, UiTheme.GOLD))
	h.add_child(UiTheme.label("+%d%% move speed" % int(r.get("speed_pct", 0)), 20, UiTheme.TEXT))
	box.add_child(h)
	box.add_child(UiTheme.label("You hop off when you attack or get hit.", 16, UiTheme.MUTED))
	if r.id != active_id():
		actions_box().add_child(UiTheme.icon_button("check", "Ride this one", func():
			var res = sess_call("set_active_mount", [r.id], null)
			if res == null:
				UiTheme.api_call("Mounts", "set_active", [ch, r.id], false)
			refresh(), Vector2(230, 80), UiTheme.GOOD, true, 20))
	else:
		actions_box().add_child(UiTheme.pill("check", "Your mount", UiTheme.GOOD, 20))

func fill_locked(r: Dictionary, box: VBoxContainer) -> void:
	var cost = int(r.get("cost_gold", 0))
	var req = str(r.get("requires", ""))
	var req_ok = req == "" or (ch.quests.get("done", []) as Array).has(req)
	if req != "":
		var q = Content.get_rec("quests", req)
		box.add_child(UiTheme.pill("check" if req_ok else "quests", str(q.get("name", req)), UiTheme.GOOD if req_ok else UiTheme.MUTED, 17))
	if cost > 0:
		var b = UiTheme.icon_button("gold", "Buy %s" % UiTheme.fmt_num(cost), func():
			var res = sess_call("buy_mount", [r.id], null)
			if res == null:
				res = UiTheme.api_call("Mounts", "buy", [ch, r.id], {"ok": false, "message": "The Stablemaster is away"})
			flash_msg(str(res.get("message", "")), UiTheme.GOLD if res.get("ok", false) else UiTheme.BAD, "mounts")
			update_gold_pill()
			refresh(), Vector2(230, 80), UiTheme.COIN, true, 20)
		b.disabled = not req_ok or ch.gold < cost
		actions_box().add_child(b)
