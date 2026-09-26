extends ScreenBase
## Pause menu + settings (accessibility & parental).

func _ready() -> void:
	build("Paused")
	var v = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 10)
	body.add_child(v)
	var cols = HBoxContainer.new()
	cols.add_theme_constant_override("separation", 40)
	v.add_child(cols)
	var left = VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	cols.add_child(left)
	left.add_child(UiTheme.button("Resume", close, 24, Vector2(300, 70)))
	left.add_child(UiTheme.button("Return to town", func():
		close()
		session.travel(Game.character.current_act_town()), 24, Vector2(300, 70)))
	left.add_child(UiTheme.button("Save & quit to title", func():
		Game.save_character()
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main.tscn"), 24, Vector2(300, 70)))
	left.add_child(UiTheme.button("Credits & licenses", func(): session.open_screen("credits"), 20, Vector2(300, 60)))
	var right = VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	cols.add_child(right)
	right.add_child(UiTheme.label("Settings", 24, UiTheme.GOLD, true))
	_slider(right, "Music volume", "music_volume", 0, 1)
	_slider(right, "Effects volume", "sfx_volume", 0, 1)
	_slider(right, "Screen shake", "screen_shake", 0, 1.5)
	_check(right, "Simple mode (auto-attack, auto-equip, auto-spend)", "simple_mode")
	_check(right, "Auto-attack", "auto_attack")
	_check(right, "Damage numbers", "damage_numbers")
	_check(right, "Auto-pickup items", "auto_pickup", true)
	var lf = HBoxContainer.new()
	right.add_child(lf)
	lf.add_child(UiTheme.label("Loot filter  ", 18))
	var opt = OptionButton.new()
	for s in ["Show all", "Hide Common", "Hide Magic & below", "Rare+ only"]:
		opt.add_item(s)
	opt.selected = int(Settings.get_value("loot_filter", 0))
	opt.item_selected.connect(func(i): Settings.set_value("loot_filter", i))
	lf.add_child(opt)
	right.add_child(UiTheme.label("Build %s" % ProjectSettings.get_setting("application/config/version", "0.1.0"), 14, UiTheme.MUTED))

func _slider(parent: Control, label: String, key: String, lo: float, hi: float) -> void:
	var h = HBoxContainer.new()
	parent.add_child(h)
	var l = UiTheme.label(label, 18)
	l.custom_minimum_size = Vector2(200, 0)
	h.add_child(l)
	var s = HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.custom_minimum_size = Vector2(260, 40)
	s.value = float(Settings.get_value(key, 1.0))
	s.value_changed.connect(func(v): Settings.set_value(key, v))
	h.add_child(s)

func _check(parent: Control, label: String, key: String, default := false) -> void:
	var c = CheckButton.new()
	c.text = label
	c.button_pressed = bool(Settings.get_value(key, default))
	c.add_theme_font_size_override("font_size", 18)
	c.toggled.connect(func(on): Settings.set_value(key, on))
	parent.add_child(c)
