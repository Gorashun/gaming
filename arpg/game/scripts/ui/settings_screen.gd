extends ScreenBase
## Settings: Play · Controls · Sound · Access · Parents (behind a parental gate).
## Accessibility per UI_UX §9, parental controls per PLAYER_WELFARE §5 (reminder opt-in, daily limit,
## hide Last Flame / leaderboards, purchase lock placeholder — ON by default).

var _tab = "play"
var _rows: VBoxContainer
var _rail: VBoxContainer
var _gate_ok = false
var _gate_answer = 0

const TABS := [["play", "star", "Play"], ["controls", "hand", "Controls"], ["sound", "sound", "Sound"], ["access", "eye", "Access"], ["parents", "parent", "Parents"]]
const FILTERS := ["Show all", "Hide Common", "Hide Magic-", "Rare+ only"]

func _ready() -> void:
	if screen_id == "":
		screen_id = "settings"
	build("Settings", "settings", session != null)
	var h = HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 16)
	body.add_child(h)
	_rail = VBoxContainer.new()
	_rail.add_theme_constant_override("separation", 8)
	h.add_child(_rail)
	var sc = ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(sc)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 10)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_rows)
	if ctx.has("tab"):
		_tab = str(ctx.tab)
	_show()

func _show() -> void:
	ScreenBase.clear(_rail)
	for t in TABS:
		var id: String = t[0]
		var b = UiTheme.icon_button(t[1], t[2], func():
			_tab = id
			_show(), Vector2(190, 80), UiTheme.GOLD if id == _tab else UiTheme.MUTED, true, 20)
		if id == _tab:
			b.add_theme_stylebox_override("normal", UiTheme.panel_style(Color(0.3, 0.18, 0.08, 0.95), UiTheme.EMBER, 14, 3))
		_rail.add_child(b)
	ScreenBase.clear(_rows)
	match _tab:
		"play":
			_toggle("star", "Simple mode", "Auto-attack, auto-equip clear upgrades (with Undo), auto-spend points", "simple_mode", false)
			_toggle("sword", "Auto-attack", "Attack the nearest enemy while you stand still", "auto_attack", false)
			_toggle("hand", "Auto-pickup items", "Walk over items to pick them up", "auto_pickup", true)
			_toggle("mounts", "Auto-mount", "Get back on your mount after a fight", "auto_mount", true)
			_choice("filter", "Loot filter", "Legendary and better are always shown", "loot_filter", FILTERS, 0)
			_toggle("crit", "Damage numbers", "", "damage_numbers", true)
			_toggle("crit", "Only show crits", "Fewer numbers on screen", "crit_numbers_only", false)
		"controls":
			_choice("hand", "Control scheme", "Stick: floating joystick. Tap: tap to move and attack (one hand)", "control_scheme", ["Stick", "Tap"], "stick", ["stick", "tap"])
			_toggle("mirror", "Left-handed", "Swap the joystick and the buttons", "left_handed", false)
			_toggle("pin", "Fixed joystick", "The stick stays in one place", "joystick_fixed", false)
			_slider("plus", "Button size", "button_scale", 0.8, 1.3, 1.0)
			_toggle("shake", "Hold to toggle", "Held buttons become tap on / tap off", "hold_toggle", false)
		"sound":
			_slider("music", "Music", "music_volume", 0.0, 1.0, 0.7)
			_slider("sound", "Effects", "sfx_volume", 0.0, 1.0, 0.9)
			_slider("shake", "Vibration", "haptics", 0.0, 1.0, 0.6)
		"access":
			_slider("text_size", "Text size", "text_scale", 1.0, 2.0, 1.0, true)
			_toggle("text_size", "Easy-read font", "Andika: letters that are easy to tell apart", "easy_read_font", false, true)
			_toggle("contrast", "High contrast", "Solid panels and thicker outlines", "high_contrast", false, true)
			_toggle("eye", "Colour-blind colours", "Rarity also always shows its shape", "colorblind_mode", false, true)
			_slider("shake", "Screen shake", "screen_shake", 0.0, 1.0, 1.0)
			_toggle("rest", "Reduced motion", "No slow-motion or zoom punches", "reduced_motion", false)
			_toggle("flame", "Fewer flashes", "Softer full-screen flashes", "flash_reduction", false)
			_toggle("talk", "Read aloud", "Item names and quest text are read out", "read_aloud", false)
			_preview_rarities()
		"parents":
			if not _gate_ok:
				_gate()
			else:
				_parents()

func _row(icon_name: String, title: String, desc: String) -> HBoxContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.09, 0.07, 0.12, 0.9), Color(0.3, 0.25, 0.2), 12, 1))
	_rows.add_child(p)
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	h.add_child(UiTheme.icon_rect(icon_name, 44, UiTheme.GOLD))
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UiTheme.label(title, 22, UiTheme.TEXT, true))
	if desc != "":
		var d = UiTheme.label(desc, 16, UiTheme.MUTED)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(d)
	return h

func _apply_setting(key: String, v, rebuild_theme := false) -> void:
	Settings.set_value(key, v)
	if rebuild_theme:
		UiTheme.invalidate()
		theme = UiTheme.theme()
	if key in ["left_handed", "button_scale"] and session and session.get("hud") and session.hud.touch:
		session.hud.touch.layout()
		if session.hud.has_method("_place_interact"):
			session.hud._place_interact()
	if key == "simple_mode" and v:
		Settings.set_value("auto_attack", true)

func _toggle(icon_name: String, title: String, desc: String, key: String, def: bool, theme_key := false) -> void:
	var h = _row(icon_name, title, desc)
	var on = bool(Settings.get_value(key, def)) if not (Settings.get_value(key, def) is String) else Settings.get_value(key, def) != ""
	var b = Button.new()
	b.custom_minimum_size = Vector2(140, 72)
	b.text = "ON" if on else "OFF"
	b.add_theme_font_size_override("font_size", UiTheme.fs(22))
	b.add_theme_stylebox_override("normal", UiTheme.panel_style(Color(0.1, 0.3, 0.12, 0.95) if on else Color(0.14, 0.12, 0.16, 0.95), UiTheme.GOOD if on else Color(0.4, 0.38, 0.44), 36, 3))
	UiTheme.juice(b)
	b.pressed.connect(func():
		Sfx.play("ui_click", -6.0)
		_apply_setting(key, not on, theme_key)
		_show())
	h.add_child(b)

func _choice(icon_name: String, title: String, desc: String, key: String, labels: Array, def, values := []) -> void:
	var h = _row(icon_name, title, desc)
	var cur = Settings.get_value(key, def)
	for i in labels.size():
		var val = values[i] if values.size() > 0 else i
		var sel = str(cur) == str(val)
		var b = UiTheme.button(labels[i], func():
			_apply_setting(key, val)
			_show(), 18, Vector2(120, 64))
		if sel:
			b.add_theme_stylebox_override("normal", UiTheme.panel_style(Color(0.3, 0.18, 0.08, 0.95), UiTheme.EMBER, 12, 3))
		h.add_child(b)

func _slider(icon_name: String, title: String, key: String, lo: float, hi: float, def: float, theme_key := false) -> void:
	var h = _row(icon_name, title, "")
	var s = HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.custom_minimum_size = Vector2(360, 64)
	s.value = float(Settings.get_value(key, def))
	var l = UiTheme.label("%d%%" % int(s.value * 100), 22, UiTheme.GOLD, true)
	l.custom_minimum_size = Vector2(80, 0)
	s.value_changed.connect(func(v):
		l.text = "%d%%" % int(v * 100)
		Settings.set_value(key, v))
	if theme_key:
		s.drag_ended.connect(func(_c):
			UiTheme.invalidate()
			theme = UiTheme.theme()
			_show())
	h.add_child(s)
	h.add_child(l)

func _preview_rarities() -> void:
	var h = _row("gem", "Rarity preview", "Colour + shape: readable with any colour setting")
	for r in ["common", "magic", "rare", "epic", "legendary", "mythic", "unique", "named"]:
		var c = Control.new()
		c.custom_minimum_size = Vector2(40, 40)
		var shape = UiTheme.rarity_shape(r)
		var col = UiTheme.rarity_color(r)
		c.draw.connect(func(): UiTheme.draw_shape(c, shape, Rect2(Vector2.ZERO, c.size), col, Color(0, 0, 0, 0.9), 2.0))
		c.tooltip_text = UiTheme.rarity_name(r)
		h.add_child(c)

# ------------------------------------------------------------------ parental gate & controls
func _gate() -> void:
	var a = randi_range(6, 9)
	var b = randi_range(6, 9)
	_gate_answer = a * b
	var h = _row("parent", "For grown-ups", "Answer to open the parent settings: what is %d × %d ?" % [a, b])
	var opts = [_gate_answer, _gate_answer + a, _gate_answer - b, _gate_answer + 10]
	opts.shuffle()
	for o in opts:
		h.add_child(UiTheme.button(str(o), func():
			if o == _gate_answer:
				_gate_ok = true
			else:
				flash_msg("Not quite — ask a grown-up", UiTheme.MUTED, "parent")
			_show(), 24, Vector2(100, 72)))

func _parents() -> void:
	var h = _row("lock", "Purchase lock", "Always on: every purchase needs this gate and the store's own confirmation.")
	var lk = UiTheme.label("ON", 22, UiTheme.GOOD, true)
	h.add_child(lk)
	_choice("clock", "Play-time reminder", "A friendly card at the next safe moment (never during a boss)", "parent_reminder_min", ["Off", "30m", "45m", "60m", "90m"], 0, [0, 30, 45, 60, 90])
	_choice("rest", "Daily limit", "Finishes the fight, saves, then says goodbye", "parent_daily_limit_min", ["Off", "1h", "2h", "3h"], 0, [0, 60, 120, 180])
	_toggle("hardcore", "Hide Last Flame", "Removes the one-life mode from new heroes", "parent_hide_hardcore", false)
	_toggle("unlock", "Allow Last Flame now", "Skip the finish-the-story-first rule", "parent_allow_hardcore", false)
	_toggle("trophy", "Hide leaderboards", "Also turns off any future online features", "parent_hide_leaderboards", false)
	_toggle("flame", "Fewer flashes & shakes", "", "flash_reduction", false)
	var info = _row("info", "Privacy", "No accounts, no ads, no chat, no data leaves this device.")
	info.add_child(UiTheme.icon_rect("check", 40, UiTheme.GOOD))
