extends ScreenBase
## Hall of Embers: a calm, read-only memorial for Last Flame heroes (welfare §4). No purchases here.

func _ready() -> void:
	if screen_id == "":
		screen_id = "hall"
	build("Hall of Embers", "trophy", false)
	var sc = ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	var g = GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	sc.add_child(g)
	var n = 0
	for d in Game.list_saves():
		if not (bool(d.get("hardcore", false)) and bool(d.get("dead", false))):
			continue
		n += 1
		var cls = Content.get_rec("classes", str(d.get("class_id", "")))
		var col = Color(cls.get("color", "#ffd27a"))
		var p = PanelContainer.new()
		p.custom_minimum_size = Vector2(380, 150)
		p.add_theme_stylebox_override("panel", UiTheme.card_style(UiTheme.EMBER, false))
		var h = HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		p.add_child(h)
		h.add_child(UiTheme.icon_rect("candle", 72, UiTheme.EMBER))
		var v = VBoxContainer.new()
		h.add_child(v)
		v.add_child(UiTheme.label(str(d.get("name", "?")), 26, col.lightened(0.3), true))
		v.add_child(UiTheme.label("Level %d %s" % [int(d.get("level", 1)), cls.get("name", "")], 18, UiTheme.MUTED))
		v.add_child(UiTheme.label("Played %s" % UiTheme.fmt_time(float(d.get("play_seconds", 0))), 16, UiTheme.MUTED))
		v.add_child(UiTheme.label("Their light still glows here.", 16, UiTheme.GOLD))
		g.add_child(p)
	if n == 0:
		var l = UiTheme.wrap_label("The Hall is quiet. Heroes who carried a Last Flame are remembered here, forever.", 22, UiTheme.MUTED, 800)
		g.add_child(l)
