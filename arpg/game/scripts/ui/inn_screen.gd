extends ScreenBase
## Innkeeper: bind your Homeward Wick here, see its cooldown, portal back to where you left off,
## and a calm "good place to rest" stopping point (welfare: natural stopping point, no timers).

func _ready() -> void:
	if screen_id == "":
		screen_id = "inn"
	var ch = Game.character
	build("Inn", "hearth", false)
	var v = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 14)
	body.add_child(v)
	npc_banner(v)
	var here = str(Game.world.zone.get("id", "")) if Game.world else ""
	var bound = str(UiTheme.chf(ch, "bound_town", ""))
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	h.add_child(UiTheme.icon_rect("hearth", 96, UiTheme.EMBER))
	var iv = VBoxContainer.new()
	h.add_child(iv)
	iv.add_child(UiTheme.label("Homeward Wick", 28, UiTheme.GOLD, true))
	iv.add_child(UiTheme.label("Bound to: %s" % Content.get_rec("zones", bound if bound != "" else ch.current_act_town()).get("name", "?"), 20, UiTheme.TEXT))
	var left = float(UiTheme.api_call("Travel", "hearth_cooldown_left", [ch], 0.0))
	iv.add_child(UiTheme.label("Ready!" if left <= 0 else "Rekindles in %s of play" % UiTheme.fmt_time(left), 18, UiTheme.GOOD if left <= 0 else UiTheme.MUTED))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var bb = UiTheme.icon_button("pin", "Bind here", func():
		sess_call("bind_town", [here], null)
		goto_self(), Vector2(260, 88), UiTheme.GOLD, true, 22)
	bb.disabled = bound == here
	row.add_child(bb)
	var rp = UiTheme.chf(ch, "return_portal", {})
	if rp is Dictionary and not rp.is_empty():
		row.add_child(UiTheme.icon_button("portal", "Back to %s" % Content.get_rec("zones", str(rp.get("zone", ""))).get("name", "the wilds"), func():
			close()
			sess_call("portal_back", [], null), Vector2(360, 88), Color("#8fd0ff"), true, 20))
	v.add_child(UiTheme.label("A good place to rest your wick. Your progress is saved.", 20, UiTheme.MUTED))

func goto_self() -> void:
	var s = session
	queue_free()
	ScreenBase.open(s, "inn", ctx)
