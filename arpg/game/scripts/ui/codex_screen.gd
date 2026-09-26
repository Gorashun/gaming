extends ScreenBase
## Codex of Light (account-wide): every Legendary power, Unique and Named item ever found by any hero.
## Found entries shine in their rarity colour with best roll; unfound ones are silhouettes ("?").

var _tab = "power"
var _tabs: HBoxContainer
var _grid: GridContainer
var _count: Label

func _ready() -> void:
	if screen_id == "":
		screen_id = "codex"
	build("Codex of Light", "trophy", true)
	var v = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 8)
	body.add_child(v)
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	top.add_child(_tabs)
	top.add_child(UiTheme.spacer(0, 0, true))
	_count = UiTheme.label("", 20, UiTheme.GOLD, true)
	top.add_child(_count)
	v.add_child(UiTheme.label("Shared by all your heroes. Finding a better one upgrades the entry.", 16, UiTheme.MUTED))
	var sc = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	sc.add_child(_grid)
	refresh()

func refresh() -> void:
	ScreenBase.clear(_tabs)
	for t in [["power", "star", "Powers", "powers", "legendary"], ["unique", "crown", "Uniques", "uniques", "unique"], ["named", "sun", "Named", "named", "named"]]:
		var id: String = t[0]
		var b = UiTheme.icon_button(t[1], t[2], func():
			_tab = id
			refresh(), Vector2(170, 64), UiTheme.rarity_color(t[4]) if id == _tab else UiTheme.MUTED, true, 19)
		if id == _tab:
			b.add_theme_stylebox_override("normal", UiTheme.panel_style(Color(0.3, 0.18, 0.08, 0.95), UiTheme.EMBER, 12, 3))
		_tabs.add_child(b)
	var found = {}
	for e in UiTheme.api_call("Codex", "list", [], []):
		found[str(e.get("id", ""))] = e
	ScreenBase.clear(_grid)
	var table = {"power": "powers", "unique": "uniques", "named": "named"}[_tab]
	var rar = {"power": "legendary", "unique": "unique", "named": "named"}[_tab]
	var col = UiTheme.rarity_color(rar)
	var n = 0
	var recs = Content.all(table)
	for r in recs:
		var e = found.get("%s:%s" % [_tab, r.id])
		if e != null:
			n += 1
		_grid.add_child(_entry(r, e, col, rar))
	_count.text = "%d / %d found" % [n, recs.size()]

func _entry(r: Dictionary, e, col: Color, rar: String) -> Control:
	var p = PanelContainer.new()
	p.custom_minimum_size = Vector2(286, 130)
	p.add_theme_stylebox_override("panel", UiTheme.card_style(col if e != null else UiTheme.LOCKED, false))
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	var emb = Control.new()
	emb.custom_minimum_size = Vector2(48, 48)
	emb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var shape = UiTheme.rarity_shape(rar)
	var c2 = col if e != null else Color(0.2, 0.18, 0.24)
	emb.draw.connect(func(): UiTheme.draw_shape(emb, shape, Rect2(Vector2.ZERO, emb.size), c2, Color(0, 0, 0, 0.9), 2.0))
	h.add_child(emb)
	var v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	if e == null:
		v.add_child(UiTheme.label("? ? ?", 20, UiTheme.MUTED, true))
		v.add_child(UiTheme.label("Not found yet", 15, UiTheme.MUTED))
		return p
	var nl = UiTheme.label(str(r.get("name", r.id)), 18, col.lightened(0.2), true)
	nl.clip_text = true
	nl.custom_minimum_size = Vector2(200, 0)
	v.add_child(nl)
	var d = UiTheme.label(str(r.get("desc", r.get("flavor", ""))), 14, UiTheme.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.max_lines_visible = 3
	d.custom_minimum_size = Vector2(200, 0)
	v.add_child(d)
	v.add_child(UiTheme.label("Best: iLvl %d · found %d×" % [int(e.get("ilvl", 1)), int(e.get("count", 1))], 14, UiTheme.GOLD))
	return p
