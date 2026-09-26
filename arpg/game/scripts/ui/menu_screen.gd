extends ScreenBase
## ☰ Menu hub (pause): every screen is one tap from here (≤ 2 taps from the HUD).
## Big icon tiles, then Resume / Return to town / Save & rest. No timers, the game is paused.

const TILES := [
	["character", "hero", "Hero"], ["inventory", "bag", "Bag"], ["skills", "skills", "Skills"], ["starmap", "starmap", "Stars"],
	["quests", "quests", "Quests"], ["codex", "book", "Codex"], ["deeds", "medal", "Deeds"], ["pets", "pets", "Pets"],
	["mounts", "mounts", "Mounts"], ["wardrobe", "hanger", "Wardrobe"], ["map", "map", "Map"], ["settings", "settings", "Settings"]]

func _ready() -> void:
	if screen_id == "":
		screen_id = "menu"
	build("Paused", "menu", true)
	var h = HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 24)
	body.add_child(h)
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(grid)
	var ch = Game.character
	for t in TILES:
		var id: String = t[0]
		var b = UiTheme.icon_button(t[1], t[2], func(): goto(id), Vector2(176, 150), UiTheme.GOLD, false, 22)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var badge = ""
		if id == "skills" and ch and ch.skill_points > 0:
			badge = str(ch.skill_points)
		if id == "starmap" and ch and ch.star_points > 0:
			badge = str(ch.star_points)
		if badge != "":
			var bl = UiTheme.label(badge, 20, Color.WHITE, true)
			var bp = PanelContainer.new()
			var bs = UiTheme.panel_style(UiTheme.EMBER.darkened(0.2), UiTheme.GOLD, 16, 2)
			bs.content_margin_top = 0
			bs.content_margin_bottom = 0
			bs.content_margin_left = 8
			bs.content_margin_right = 8
			bp.add_theme_stylebox_override("panel", bs)
			bp.add_child(bl)
			bp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(bp)
			UiTheme.place(bp, 1.0, 0.0, -48, 6, 42, 32)
		grid.add_child(b)
	var right = VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.custom_minimum_size = Vector2(320, 0)
	h.add_child(right)
	if ch:
		var who = card("", Color(ch.cls().get("color", "#ffd27a")))
		who.add_child(UiTheme.label(ch.name, 28, Color(ch.cls().get("color", "#ffd27a")).lightened(0.2), true))
		var tier = Content.get_rec("difficulties", ch.difficulty).get("name", "")
		who.add_child(UiTheme.label("Level %d %s · %s" % [ch.level, ch.cls().get("name", ""), tier], 18, UiTheme.MUTED))
		who.add_child(UiTheme.label("Played %s" % UiTheme.fmt_time(ch.play_seconds), 18, UiTheme.MUTED))
		right.add_child(ScreenBase.card_panel(who))
	var resume = UiTheme.icon_button("next", "Resume", close, Vector2(320, 84), UiTheme.GOOD, true, 24)
	resume.add_theme_stylebox_override("normal", UiTheme.panel_style(Color(0.08, 0.22, 0.1, 0.97), UiTheme.GOOD, 14, 3))
	right.add_child(resume)
	if session and Game.world and not Game.world.get("is_town"):
		right.add_child(UiTheme.icon_button("hearth", "Return to town", func():
			close()
			session.travel(Game.character.current_act_town()), Vector2(320, 76), UiTheme.EMBER, true, 20))
	right.add_child(UiTheme.icon_button("rest", "Save & rest", func():
		Game.save_character()
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main.tscn"), Vector2(320, 76), UiTheme.XP, true, 20))
	right.add_child(UiTheme.icon_button("credits", "Credits & licenses", func(): goto("credits"), Vector2(320, 68), UiTheme.MUTED, true, 18))
	right.add_child(UiTheme.label("Your progress is always saved.", 17, UiTheme.MUTED))
