extends ScreenBase
## Stash keeper: bag (left) ⇄ stash tabs (right). Tap an item to move it across.
## Tabs: Stash pages (40 each) · Mailbox (Legendary+ overflow, never lost) · Materials (material bag).

var ch: CharacterData
var _tab = "stash"
var _page = 0
var _bag: GridContainer
var _right: VBoxContainer
var _tabs: HBoxContainer

const PAGE := 40

func _ready() -> void:
	ch = Game.character
	if screen_id == "":
		screen_id = "stash"
	build("Stash", "stash", false)
	right_box.add_child(gold_pill())
	if _mail().size() > 0:
		_tab = "mail"
	var h = HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 16)
	body.add_child(h)
	var left = card("Bag", UiTheme.GOLD)
	ScreenBase.card_panel(left).size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_child(ScreenBase.card_panel(left))
	_bag = GridContainer.new()
	_bag.columns = 8
	_bag.add_theme_constant_override("h_separation", 5)
	_bag.add_theme_constant_override("v_separation", 5)
	left.add_child(_bag)
	npc_banner(left)
	var rc = VBoxContainer.new()
	rc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rc.add_theme_constant_override("separation", 8)
	h.add_child(rc)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	rc.add_child(_tabs)
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.08, 0.065, 0.11, 0.95), UiTheme.PANEL_EDGE, 14, 2))
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rc.add_child(p)
	var sc = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	_right = VBoxContainer.new()
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_right)
	refresh()

func _mail() -> Array:
	var m = UiTheme.chf(ch, "mailbox", null)
	return m if m is Array else []

func refresh() -> void:
	ScreenBase.clear(_bag)
	for i in ch.inventory.size():
		var it = ch.inventory[i]
		var b = ItemSlot.new()
		b.setup(it, "", 62)
		var idx = i
		b.pressed.connect(func(): _to_stash(idx))
		_bag.add_child(b)
	ScreenBase.clear(_tabs)
	var pages = max(1, int(ceil((ch.stash.size() + 1) / float(PAGE))))
	for pg in pages:
		var pi = pg
		var sel = _tab == "stash" and _page == pg
		var b = UiTheme.icon_button("stash", str(pg + 1), func():
			_tab = "stash"
			_page = pi
			refresh(), Vector2(96, 64), UiTheme.GOLD if sel else UiTheme.MUTED, true, 20)
		if sel:
			b.add_theme_stylebox_override("normal", UiTheme.panel_style(Color(0.3, 0.18, 0.08, 0.95), UiTheme.EMBER, 12, 3))
		_tabs.add_child(b)
	var mail = _mail()
	var mb = UiTheme.icon_button("mail", "Mailbox %d" % mail.size() if mail.size() > 0 else "Mailbox", func():
		_tab = "mail"
		refresh(), Vector2(170, 64), UiTheme.GOLD if _tab == "mail" else UiTheme.MUTED, true, 18)
	if _tab == "mail":
		mb.add_theme_stylebox_override("normal", UiTheme.panel_style(Color(0.3, 0.18, 0.08, 0.95), UiTheme.EMBER, 12, 3))
	_tabs.add_child(mb)
	var mt = UiTheme.icon_button("soot", "Materials", func():
		_tab = "mats"
		refresh(), Vector2(170, 64), UiTheme.GOLD if _tab == "mats" else UiTheme.MUTED, true, 18)
	if _tab == "mats":
		mt.add_theme_stylebox_override("normal", UiTheme.panel_style(Color(0.3, 0.18, 0.08, 0.95), UiTheme.EMBER, 12, 3))
	_tabs.add_child(mt)
	ScreenBase.clear(_right)
	match _tab:
		"stash":
			_right.add_child(UiTheme.label("Tap an item to move it between your bag and your stash.", 16, UiTheme.MUTED))
			var g = GridContainer.new()
			g.columns = 7 + 3 * (1 if get_viewport_rect().size.x > 1400 else 0)
			g.add_theme_constant_override("h_separation", 6)
			g.add_theme_constant_override("v_separation", 6)
			_right.add_child(g)
			for i in PAGE:
				var si = _page * PAGE + i
				var it = ch.stash[si] if si < ch.stash.size() else null
				var b = ItemSlot.new()
				b.setup(it, "", 70)
				if it:
					b.pressed.connect(func(): _from_stash(si))
				g.add_child(b)
		"mail":
			_right.add_child(UiTheme.wrap_label("When your bag is full, Legendary and better items wait here. They are never lost.", 17, UiTheme.MUTED, 500))
			if mail.is_empty():
				_right.add_child(UiTheme.label("No mail right now.", 20, UiTheme.TEXT))
			for i in mail.size():
				var it = mail[i]
				var h = HBoxContainer.new()
				h.add_theme_constant_override("separation", 10)
				var t = ItemSlot.new()
				t.setup(it, "", 72)
				h.add_child(t)
				var n = UiTheme.label(str(it.get("name", "")), 20, UiTheme.rarity_color(str(it.get("rarity", "common"))), true)
				n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				h.add_child(n)
				var mi = i
				h.add_child(UiTheme.icon_button("bag", "Take", func():
					if ch.add_item(mail[mi]):
						mail.remove_at(mi)
						refresh()
					else:
						flash_msg("Bag is full", UiTheme.BAD, "bag"), Vector2(130, 72), UiTheme.GOLD, true, 18))
				_right.add_child(h)
		"mats":
			var g2 = GridContainer.new()
			g2.columns = 3
			g2.add_theme_constant_override("h_separation", 8)
			g2.add_theme_constant_override("v_separation", 8)
			_right.add_child(g2)
			var mats = ch.materials.keys()
			mats.sort_custom(func(a, b): return int(Content.get_rec("materials", a).get("tier", 0)) < int(Content.get_rec("materials", b).get("tier", 0)))
			for m in mats:
				if int(ch.materials[m]) <= 0:
					continue
				var rec = Content.get_rec("materials", m)
				var p = UiTheme.pill(m if UiTheme.has_icon(m) else ("gem" if rec.get("gem", false) else "material"), "%s  %s" % [UiTheme.fmt_num(int(ch.materials[m])), rec.get("name", m)], Color(rec.get("color", "#cccccc")), 18)
				p.tooltip_text = str(rec.get("desc", ""))
				g2.add_child(p)

func _to_stash(i: int) -> void:
	var it = ch.inventory[i]
	if it == null:
		return
	var slot = -1
	for k in ch.stash.size():
		if ch.stash[k] == null:
			slot = k
			break
	if slot >= 0:
		ch.stash[slot] = it
	else:
		ch.stash.append(it)
	ch.inventory[i] = null
	Sfx.play("pickup", -8.0)
	refresh()

func _from_stash(si: int) -> void:
	var it = ch.stash[si]
	if it == null:
		return
	if not ch.add_item(it):
		flash_msg("Bag is full", UiTheme.BAD, "bag")
		return
	ch.stash[si] = null
	while ch.stash.size() > 0 and ch.stash[-1] == null:
		ch.stash.pop_back()
	Sfx.play("pickup", -8.0)
	refresh()
