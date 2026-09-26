extends ScreenBase
## Brightness (starmap, levels 61–200): pannable/zoomable node graph (drag, pinch or wheel 0.6–2.0×,
## double-tap recentres). Lit stars gold, stars you can light now glow, locked stars are dim outlines.
## Constellations show "3/7" badges; tap a star → side sheet (stats, Light it, constellation bonus).
## Respec is free.

var ch: CharacterData
var _canvas: Control
var _sheet: VBoxContainer
var _pts: Label
var _zoom = 0.8
var _pan = Vector2.ZERO
var _sel = ""
var _nodes: Array = []
var _cons: Array = []
var _allocatable: Array = []
var _drag = false
var _moved = 0.0
var _last_tap = 0.0
var _touches = {}
var _pinch_d = 0.0

func _ready() -> void:
	ch = Game.character
	if screen_id == "":
		screen_id = "starmap"
	build("Brightness", "starmap", true)
	var pp = UiTheme.pill("star", "", UiTheme.GOLD, 24)
	_pts = pp.find_child("Value", true, false)
	right_box.add_child(pp)
	right_box.move_child(pp, 0)
	for n in Content.all("starmap"):
		if str(n.get("kind", "star")) == "constellation":
			_cons.append(n)
		elif str(n.get("class", "")) in ["", ch.class_id]:
			_nodes.append(n)
	var h = HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 12)
	body.add_child(h)
	var frame = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.02, 0.02, 0.06, 1.0), Color(0.25, 0.22, 0.4), 16, 2))
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(frame)
	_canvas = Control.new()
	_canvas.clip_contents = true
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_map)
	_canvas.gui_input.connect(_input_map)
	frame.add_child(_canvas)
	var side = PanelContainer.new()
	side.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.07, 0.055, 0.1, 0.96), UiTheme.PANEL_EDGE, 16, 2))
	side.custom_minimum_size = Vector2(380, 0)
	h.add_child(side)
	var sc = ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(sc)
	_sheet = VBoxContainer.new()
	_sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet.add_theme_constant_override("separation", 8)
	sc.add_child(_sheet)
	_recentre()
	refresh()

func _center_world() -> Vector2:
	if ch.stars.size() > 0:
		var n = Content.get_rec("starmap", str(ch.stars[-1]))
		if n.has("pos"):
			return Vector2(n.pos[0], n.pos[1])
	return Vector2(1000, 1000)

func _recentre() -> void:
	_pan = -_center_world()

func refresh() -> void:
	_allocatable = UiTheme.api_call("Starmap", "allocatable", [ch], [])
	_pts.text = "%d star point%s" % [ch.star_points, "" if ch.star_points == 1 else "s"]
	_canvas.queue_redraw()
	_show_sheet()

func _to_screen(p: Vector2) -> Vector2:
	return _canvas.size * 0.5 + (p + _pan) * _zoom

func _draw_map() -> void:
	var sz = _canvas.size
	# faint background stars
	for i in 60:
		var x = fposmod(i * 137.5 + _pan.x * 0.1, sz.x)
		var y = fposmod(i * 91.3 + _pan.y * 0.1, sz.y)
		_canvas.draw_circle(Vector2(x, y), 1.2, Color(1, 1, 1, 0.25))
	var owned = {}
	for s in ch.stars:
		owned[str(s)] = true
	var by_id = {}
	for n in _nodes:
		by_id[n.id] = n
	for n in _nodes:
		var a = _to_screen(Vector2(n.pos[0], n.pos[1]))
		for l in n.get("links", []):
			var m = by_id.get(str(l))
			if m == null:
				continue
			var b = _to_screen(Vector2(m.pos[0], m.pos[1]))
			var lit = owned.has(n.id) and owned.has(m.id)
			_canvas.draw_line(a, b, Color(1, 0.85, 0.5, 0.9) if lit else Color(0.5, 0.5, 0.8, 0.25), 3.0 if lit else 1.5, true)
	var r = clampf(7.0 * _zoom, 4.0, 14.0)
	for n in _nodes:
		var p = _to_screen(Vector2(n.pos[0], n.pos[1]))
		if p.x < -20 or p.y < -20 or p.x > sz.x + 20 or p.y > sz.y + 20:
			continue
		var is_owned = owned.has(n.id)
		var can = _allocatable.has(n.id)
		if is_owned:
			_canvas.draw_circle(p, r * 1.8, Color(1, 0.8, 0.4, 0.18))
			_draw_star(p, r * 1.3, UiTheme.GOLD)
		elif can:
			var pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.005)
			_canvas.draw_circle(p, r * (1.6 + pulse * 0.4), Color(0.6, 0.8, 1.0, 0.22))
			_draw_star(p, r * 1.1, Color("#bfe0ff"))
		else:
			_canvas.draw_arc(p, r * 0.8, 0, TAU, 12, Color(0.6, 0.6, 0.8, 0.45), 1.5, true)
		if n.id == _sel:
			_canvas.draw_arc(p, r * 2.2, 0, TAU, 24, Color.WHITE, 2.5, true)
	var font = UiTheme.font_heading()
	if _zoom >= 0.55:
		for c in _cons:
			if not c.has("pos"):
				continue
			var cp = _to_screen(Vector2(c.pos[0], c.pos[1]))
			if cp.x < -100 or cp.y < -40 or cp.x > sz.x + 100 or cp.y > sz.y + 40:
				continue
			var nodes: Array = c.get("nodes", [])
			var got = 0
			for nid in nodes:
				if owned.has(str(nid)):
					got += 1
			var txt = "%s  %d/%d" % [c.get("name", ""), got, nodes.size()]
			var fsz = 15
			var w = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
			var col = UiTheme.GOLD if got == nodes.size() and nodes.size() > 0 else Color(0.75, 0.75, 0.95, 0.85)
			_canvas.draw_string_outline(font, cp + Vector2(-w * 0.5, -22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, 4, Color(0, 0, 0, 0.9))
			_canvas.draw_string(font, cp + Vector2(-w * 0.5, -22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, col)

func _draw_star(p: Vector2, r: float, col: Color) -> void:
	var pts = PackedVector2Array()
	for i in 8:
		var a = TAU * i / 8.0 - PI / 2
		var rr = r if i % 2 == 0 else r * 0.42
		pts.append(p + Vector2(cos(a), sin(a)) * rr)
	_canvas.draw_colored_polygon(pts, col)

func _input_map(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			_zoom_at(1.1, e.position)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			_zoom_at(1 / 1.1, e.position)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_drag = true
				_moved = 0.0
			else:
				_drag = false
				if _moved < 10.0:
					_tap(e.position)
	elif e is InputEventMouseMotion and _drag and _touches.size() < 2:
		_moved += e.relative.length()
		_pan += e.relative / _zoom
		_canvas.queue_redraw()
	elif e is InputEventScreenTouch:
		if e.pressed:
			_touches[e.index] = e.position
		else:
			_touches.erase(e.index)
		_pinch_d = 0.0
	elif e is InputEventScreenDrag:
		_touches[e.index] = e.position
		if _touches.size() >= 2:
			var ps = _touches.values()
			var d = (ps[0] as Vector2).distance_to(ps[1])
			if _pinch_d > 0:
				_zoom_at(d / _pinch_d, ((ps[0] as Vector2) + ps[1]) * 0.5)
			_pinch_d = d
	elif e is InputEventMagnifyGesture:
		_zoom_at(e.factor, e.position)

func _zoom_at(f: float, at: Vector2) -> void:
	var before = (at - _canvas.size * 0.5) / _zoom - _pan
	_zoom = clampf(_zoom * f, 0.6, 2.0)
	_pan = (at - _canvas.size * 0.5) / _zoom - before
	_canvas.queue_redraw()

func _tap(pos: Vector2) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	if now - _last_tap < 0.3:
		_recentre()
		_canvas.queue_redraw()
		return
	_last_tap = now
	var best = ""
	var bd = 26.0
	for n in _nodes:
		var d = _to_screen(Vector2(n.pos[0], n.pos[1])).distance_to(pos)
		if d < bd:
			bd = d
			best = n.id
	if best != "":
		_sel = best
		Sfx.play("ui_click", -6.0)
		refresh()

func _process(_d: float) -> void:
	if _allocatable.size() > 0:
		_canvas.queue_redraw()

func _show_sheet() -> void:
	ScreenBase.clear(_sheet)
	if ch.level < 61 and ch.stars.is_empty():
		_sheet.add_child(UiTheme.icon_rect("starmap", 80, UiTheme.GOLD))
		_sheet.add_child(UiTheme.wrap_label("The stars answer heroes of level 61 and above. Each level then gives 2 star points.", 19, UiTheme.TEXT, 340))
	var n = Content.get_rec("starmap", _sel)
	if n.is_empty():
		_sheet.add_child(UiTheme.wrap_label("Drag to look around, pinch to zoom, double-tap to come back. Tap a star to see it.", 18, UiTheme.MUTED, 340))
	else:
		var owned = ch.stars.has(n.id)
		_sheet.add_child(UiTheme.label(str(n.get("name", n.id)), 24, UiTheme.GOLD if owned else UiTheme.TEXT, true))
		var st: Dictionary = n.get("stats", {})
		for k in st:
			var h = HBoxContainer.new()
			h.add_theme_constant_override("separation", 8)
			h.add_child(UiTheme.icon_rect(UiTheme.stat_icon(k), 28, UiTheme.GOLD))
			h.add_child(UiTheme.label(Items.stat_label(k, float(st[k])), 19, Color(0.8, 0.86, 1.0)))
			_sheet.add_child(h)
		if owned:
			_sheet.add_child(UiTheme.pill("check", "Lit", UiTheme.GOOD, 18))
		else:
			var why = str(UiTheme.api_call("Starmap", "can_allocate", [ch, n.id], "Not available"))
			var b = UiTheme.icon_button("star", "Light it", func():
				var res = sess_call("allocate_star", [n.id], null)
				if res == null:
					res = UiTheme.api_call("Starmap", "allocate", [ch, n.id], {"ok": false, "message": ""})
				if res.get("ok", false):
					Sfx.play("skill_up")
				refresh(), Vector2(340, 84), UiTheme.GOLD, true, 22)
			b.disabled = why != ""
			_sheet.add_child(b)
			if why != "":
				_sheet.add_child(UiTheme.wrap_label(why, 16, UiTheme.MUTED, 340))
		var cid = str(n.get("constellation", ""))
		var c = Content.get_rec("starmap", cid)
		if not c.is_empty():
			_sheet.add_child(UiTheme.separator())
			var nodes: Array = c.get("nodes", [])
			var got = 0
			for nid in nodes:
				if ch.stars.has(nid):
					got += 1
			_sheet.add_child(UiTheme.label("%s  %d/%d" % [c.get("name", ""), got, nodes.size()], 21, UiTheme.GOLD, true))
			var bar = UiTheme.progress_bar(UiTheme.GOLD, 10)
			bar.value = float(got) / max(1, nodes.size())
			_sheet.add_child(bar)
			var bonus: Dictionary = c.get("bonus", {})
			for k in bonus:
				_sheet.add_child(UiTheme.label("Complete: " + Items.stat_label(k, float(bonus[k])), 17, UiTheme.GOOD if got == nodes.size() else UiTheme.MUTED))
	_sheet.add_child(UiTheme.separator())
	var rs = UiTheme.hold_button("Reset stars (free)", 0.8, func():
		var res = sess_call("respec_stars", [], null)
		if res == null:
			UiTheme.api_call("Starmap", "respec", [ch], 0)
		refresh(), Vector2(340, 72), Color("#9aa0b8"), "undo")
	rs.disabled = ch.stars.is_empty()
	_sheet.add_child(rs)
