extends ScreenBase
## Waypoints: town + unlocked zones, difficulty tier selection.

var ch: CharacterData

func _ready() -> void:
	ch = Game.character
	build("World Map")
	var v = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 10)
	body.add_child(v)
	var tiers = HBoxContainer.new()
	tiers.add_theme_constant_override("separation", 8)
	v.add_child(UiTheme.label("Difficulty", 20, UiTheme.MUTED, true))
	v.add_child(tiers)
	var diffs = Content.all("difficulties")
	diffs.sort_custom(func(a, b): return int(a.order) < int(b.order))
	for d in diffs:
		var unlocked = ch.unlocked_tiers.has(d.id)
		var b = UiTheme.button(d.name if unlocked else "🔒 " + d.name, func():
			ch.difficulty = d.id
			Events.difficulty_changed.emit(d.id)
			close()
			session.travel(ch.current_act_town()), 18, Vector2(150, 60))
		b.disabled = not unlocked
		if ch.difficulty == d.id:
			b.add_theme_stylebox_override("normal", UiTheme.panel_style(Color(0.3, 0.2, 0.1), UiTheme.EMBER, 12, 3))
		tiers.add_child(b)
	var tier_rec = Content.get_rec("difficulties", ch.difficulty)
	v.add_child(UiTheme.label(tier_rec.get("desc", ""), 18, UiTheme.MUTED))
	for a in Content.all("acts"):
		v.add_child(UiTheme.label(a.name, 26, UiTheme.GOLD, true))
		var row = HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 10)
		row.add_theme_constant_override("v_separation", 10)
		v.add_child(row)
		var zones: Array = [a.town] + a.zones
		for zid in zones:
			var z = Content.get_rec("zones", zid)
			var known = ch.waypoints.has(zid) or zid == a.town or zid == a.zones[0]
			var b = UiTheme.button(z.get("name", zid) if known else "???", func():
				close()
				session.travel(zid), 18, Vector2(220, 64))
			b.disabled = not known
			row.add_child(b)
