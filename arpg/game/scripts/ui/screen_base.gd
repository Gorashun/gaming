class_name ScreenBase
extends Control
## Full-screen modal panel. Pauses gameplay while open (welfare: safe pause, no timers in menus).
## Layout: [Back] Title ........ [hub tabs: icon-only, active one is titled]   (top bar, 88 px)
##         body (fills the rest). Back is always top-left; Android back / Esc map to it.

signal closed

## Context handed to the next screen that opens (e.g. {"npc": "smith_hollow", "tab": "jeweler"}).
static var context: Dictionary = {}

const HUB_TABS := [
	["character", "hero", "Hero"], ["inventory", "bag", "Bag"], ["skills", "skills", "Skills"], ["starmap", "starmap", "Stars"],
	["quests", "quests", "Quests"], ["codex", "book", "Codex"], ["pets", "pets", "Pets"], ["mounts", "mounts", "Mounts"],
	["map", "map", "Map"], ["menu", "menu", "Menu"]]

var body: Control
var title_label: Label
var top_bar: HBoxContainer
var right_box: HBoxContainer
var session: Node
var screen_id = ""
var ctx: Dictionary = {}
var _panel: PanelContainer
var _msg_box: VBoxContainer

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	ctx = context
	context = {}

## Open any screen by name (res://scripts/ui/<name>_screen.gd). Mirrors Session.open_screen so new
## screens work even before the session's own map knows them.
static func open(sess: Node, which: String, context_in := {}) -> Control:
	if sess == null:
		return null
	var path = "res://scripts/ui/%s_screen.gd" % which
	if not ResourceLoader.exists(path):
		Events.toast.emit("Coming soon", UiTheme.MUTED)
		return null
	context = context_in
	var prev = sess.get("screen")
	if prev and is_instance_valid(prev):
		_retire(prev)
	var s: Control = load(path).new()
	s.set("session", sess)
	s.set("screen_id", which)
	var layer: Node = sess.get("ui_layer")
	if layer == null:
		layer = sess
	layer.add_child(s)
	sess.set("screen", s)
	sess.get_tree().paused = true
	if s.has_signal("closed"):
		s.closed.connect(func():
			var tree = sess.get_tree()
			if tree == null:
				return
			var cur = sess.get("screen")
			if cur == null or cur == s or not is_instance_valid(cur):
				tree.paused = false
			var w = sess.get("world")
			if w and is_instance_valid(w) and w.get("player"):
				w.player.sync_from_character()
			Game.save_character())
	Sfx.play("ui_open", -8.0)
	return s

## Hide now, free a few frames later: a screen with 3D previews freed in the same frame it was built
## makes the GL renderer report 'Parameter "material" is null'.
static func _retire(c: Node) -> void:
	if c is CanvasItem:
		(c as CanvasItem).visible = false
	c.process_mode = Node.PROCESS_MODE_DISABLED
	if c.has_signal("closed"):
		for con in c.closed.get_connections():
			c.closed.disconnect(con.callable)
	c.get_tree().create_timer(0.25, true, false, true).timeout.connect(func():
		if is_instance_valid(c):
			c.queue_free())

func goto(which: String, context_in := {}) -> void:
	## Switch to another screen (hub tabs). Keeps the game paused.
	if which == screen_id:
		return
	var sess = session
	var me = self
	if sess:
		sess.set("screen", null)
	ScreenBase.open(sess, which, context_in)
	_retire(me)

func build(title: String, icon_name := "", hub := false) -> void:
	theme = UiTheme.theme()
	var dim = ColorRect.new()
	dim.color = Color(0.01, 0.0, 0.02, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = PanelContainer.new()
	var ps = UiTheme.panel_style(Color(0.055, 0.045, 0.08, 0.97), PANEL_EDGE_COL, 18, 3)
	ps.content_margin_left = 16
	ps.content_margin_right = 16
	ps.content_margin_top = 10
	ps.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", ps)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	top_bar = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)
	top_bar.custom_minimum_size = Vector2(0, 84)
	v.add_child(top_bar)
	var back = UiTheme.icon_button("back", "", close, Vector2(96, 84), UiTheme.GOLD)
	back.tooltip_text = "Back"
	top_bar.add_child(back)
	if icon_name != "" and not hub:
		top_bar.add_child(UiTheme.icon_rect(icon_name, 52, UiTheme.GOLD))
	title_label = UiTheme.label(title, 34, UiTheme.GOLD, true)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.custom_minimum_size = Vector2(150, 0)
	top_bar.add_child(title_label)
	right_box = HBoxContainer.new()
	right_box.add_theme_constant_override("separation", 8)
	right_box.alignment = BoxContainer.ALIGNMENT_END
	top_bar.add_child(right_box)
	if hub:
		_build_tabs()
	v.add_child(UiTheme.separator())
	body = Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(body)
	_msg_box = VBoxContainer.new()
	_msg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg_box.alignment = BoxContainer.ALIGNMENT_END
	add_child(_msg_box)
	UiTheme.place(_msg_box, 0.5, 1.0, -360, -220, 720, 190)

const PANEL_EDGE_COL := Color("#6b5a3a")

func _apply_safe_area() -> void:
	if _panel == null:
		return
	var ins = UiTheme.safe_insets(get_viewport())
	_panel.offset_left = max(16.0, ins.x - 8)
	_panel.offset_top = max(12.0, ins.y - 12)
	_panel.offset_right = -max(16.0, ins.z - 8)
	_panel.offset_bottom = -max(12.0, ins.w - 12)

func _build_tabs() -> void:
	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	right_box.add_child(tabs)
	for t in HUB_TABS:
		var id: String = t[0]
		if id == "starmap" and not _starmap_available():
			continue
		var active = id == screen_id
		var b = UiTheme.icon_button(t[1], "", func(): goto(id), Vector2(84, 84), UiTheme.GOLD if active else Color(0.8, 0.76, 0.86))
		b.tooltip_text = t[2]
		if active:
			var st = UiTheme.panel_style(Color(0.3, 0.18, 0.08, 0.95), UiTheme.EMBER, 14, 3)
			st.shadow_color = Color(UiTheme.EMBER, 0.4)
			st.shadow_size = 10
			b.add_theme_stylebox_override("normal", st)
			b.add_theme_stylebox_override("hover", st)
		else:
			var st2 = UiTheme.panel_style(Color(0.1, 0.08, 0.13, 0.9), Color(0.35, 0.3, 0.25), 14, 2)
			b.add_theme_stylebox_override("normal", st2)
		if _tab_badge(id):
			var dot = Panel.new()
			var ds = StyleBoxFlat.new()
			ds.bg_color = UiTheme.EMBER
			ds.set_corner_radius_all(9)
			ds.border_color = Color(0.1, 0.02, 0)
			ds.set_border_width_all(2)
			dot.add_theme_stylebox_override("panel", ds)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(dot)
			UiTheme.place(dot, 1.0, 0.0, -22, 4, 18, 18)
		tabs.add_child(b)

func _starmap_available() -> bool:
	return Content.all("starmap").size() > 0

func _tab_badge(id: String) -> bool:
	var ch = Game.character
	if ch == null:
		return false
	match id:
		"skills":
			return ch.skill_points > 0
		"starmap":
			return ch.star_points > 0
	return false

## Small in-screen message (the HUD toasts sit under the dim while a screen is open).
func flash_msg(text: String, color := UiTheme.TEXT, icon_name := "") -> void:
	if _msg_box == null:
		Events.toast.emit(text, color)
		return
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.05, 0.04, 0.07, 0.96), color.darkened(0.2), 16, 2))
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	if icon_name != "":
		h.add_child(UiTheme.icon_rect(icon_name, 36, color))
	h.add_child(UiTheme.label(text, 22, color))
	_msg_box.add_child(p)
	if _msg_box.get_child_count() > 3:
		_msg_box.get_child(0).queue_free()
	p.modulate.a = 0.0
	var t = p.create_tween()
	t.tween_property(p, "modulate:a", 1.0, 0.15)
	t.tween_interval(2.2)
	t.tween_property(p, "modulate:a", 0.0, 0.4)
	t.tween_callback(p.queue_free)

## Call a Session facade method when it exists (it syncs the player + saves), else fallback.
func sess_call(method: String, args := [], fallback = null):
	if session and session.has_method(method):
		return session.callv(method, args)
	return fallback

## The NPC that opened this screen (ctx.npc, else session.current_npc), as its `npcs` record.
func npc_rec() -> Dictionary:
	var id = str(ctx.get("npc", ""))
	if id == "" and session and "current_npc" in session:
		id = str(session.current_npc)
	return Content.get_rec("npcs", id)

## A small bottom-left NPC greeting line (portrait icon + name + greeting).
func npc_banner(parent: Control) -> void:
	var n = npc_rec()
	if n.is_empty():
		return
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(UiTheme.icon_rect("talk", 30, UiTheme.GOLD))
	h.add_child(UiTheme.label(str(n.get("name", "")), 18, UiTheme.GOLD, true))
	var g = UiTheme.label("“%s”" % str(n.get("greeting", "")), 16, UiTheme.MUTED)
	g.clip_text = true
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(g)
	parent.add_child(h)

## A titled card panel for screen columns.
func card(title := "", accent := UiTheme.PANEL_EDGE) -> VBoxContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.08, 0.065, 0.11, 0.95), accent.darkened(0.2), 14, 2))
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	if title != "":
		v.add_child(UiTheme.label(title, 22, UiTheme.GOLD, true))
	v.set_meta("panel", p)
	return v

static func card_panel(v: Control) -> Control:
	return v.get_meta("panel") if v.has_meta("panel") else v

func gold_pill() -> PanelContainer:
	var ch = Game.character
	var p = UiTheme.pill("gold", UiTheme.fmt_num(ch.gold if ch else 0), UiTheme.COIN, 24)
	p.name = "GoldPill"
	return p

func update_gold_pill() -> void:
	var p = find_child("GoldPill", true, false)
	if p and Game.character:
		(p.find_child("Value", true, false) as Label).text = UiTheme.fmt_num(Game.character.gold)

func close() -> void:
	Sfx.play("ui_close", -8.0)
	closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree():
		close()

## Clear all children of a container.
static func clear(c: Node) -> void:
	for ch in c.get_children():
		ch.queue_free()
