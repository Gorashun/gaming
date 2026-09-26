class_name CollectionScreen
extends ScreenBase
## Shared layout for Pets / Mounts: collection grid (owned in colour, locked as dark silhouettes with a
## "where from" hint) on the left, live 3D preview + details + actions on the right.

var ch: CharacterData
var _grid: GridContainer
var _preview: HeroPreview
var _info: VBoxContainer
var _count: Label
var _sel = ""

# --- hooks (override)
func records() -> Array: return []
func owned(_id: String) -> bool: return false
func active_id() -> String: return ""
func tile_icon() -> String: return "paw"
func tile_sub(_r: Dictionary) -> String: return ""
func tile_progress(_r: Dictionary) -> float: return -1.0
func fill_info(_r: Dictionary, _box: VBoxContainer) -> void: pass
func source_hint(r: Dictionary) -> String:
	var src = str(r.get("source", ""))
	var ref = str(r.get("source_ref", r.get("requires", "")))
	var q = Content.get_rec("quests", ref)
	if not q.is_empty():
		return "Quest: " + str(q.get("name", ref))
	var ev = Content.get_rec("events", ref)
	if not ev.is_empty():
		return "Event: " + str(ev.get("name", ref))
	return {"drop": "Found on adventures", "event": "A surprise event", "quest": "From a quest", "craft": "Crafted", "vendor": "Sold in town", "deed": "A Deed reward"}.get(src, "Keep exploring!")

func setup_collection(title: String, icon_name: String) -> void:
	ch = Game.character
	build(title, icon_name, true)
	var h = HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 14)
	body.add_child(h)
	var left = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	_count = UiTheme.label("", 20, UiTheme.MUTED, true)
	left.add_child(_count)
	var sc = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(sc)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	sc.add_child(_grid)
	var right = VBoxContainer.new()
	right.custom_minimum_size = Vector2(430, 0)
	right.add_theme_constant_override("separation", 8)
	h.add_child(right)
	var stage = Control.new()
	stage.custom_minimum_size = Vector2(430, 230)
	right.add_child(stage)
	var bg = Panel.new()
	bg.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.1, 0.07, 0.12, 0.85), Color(0.35, 0.27, 0.18), 16, 2))
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(bg)
	_preview = HeroPreview.new()
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview.camera_distance = 4.2
	_preview.camera_height = 1.4
	_preview.look_height = 0.5
	stage.add_child(_preview)
	var sc2 = ScrollContainer.new()
	sc2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(sc2)
	_info = VBoxContainer.new()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_theme_constant_override("separation", 6)
	sc2.add_child(_info)
	_sel = active_id()
	if _sel == "":
		for r in records():
			if owned(r.id):
				_sel = r.id
				break
	if _sel == "" and records().size() > 0:
		_sel = records()[0].id
	refresh()

func refresh() -> void:
	ScreenBase.clear(_grid)
	var n_owned = 0
	var recs = records()
	for r in recs:
		var own = owned(r.id)
		if own:
			n_owned += 1
		_grid.add_child(_tile(r, own))
	_count.text = "Collected %d / %d" % [n_owned, recs.size()]
	_show(Content.get_rec(_table(), _sel))

func _table() -> String:
	return "pets"

func _tile(r: Dictionary, own: bool) -> Button:
	var rar = str(r.get("rarity", "common"))
	var col = UiTheme.rarity_color(rar) if own else UiTheme.LOCKED
	var tint = Color(r.get("tint", "#ffffff")) if own else Color(0.12, 0.1, 0.15)
	var b = Button.new()
	b.custom_minimum_size = Vector2(128, 150)
	var sel = r.id == _sel
	b.add_theme_stylebox_override("normal", UiTheme.card_style(col, sel))
	b.add_theme_stylebox_override("hover", UiTheme.card_style(col, true))
	var v = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_top = 8
	v.offset_left = 6
	v.offset_right = -6
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var ic = UiTheme.icon_rect(tile_icon() if own else "unknown", 58, tint.lightened(0.35) if own else Color(0.25, 0.22, 0.3))
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var nm = UiTheme.label(str(r.get("name", r.id)) if own else "???", 16, UiTheme.TEXT if own else UiTheme.MUTED, true)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.clip_text = true
	nm.custom_minimum_size = Vector2(110, 0)
	v.add_child(nm)
	var sub = UiTheme.label(tile_sub(r) if own else "", 14, UiTheme.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var pr = tile_progress(r)
	if own and pr >= 0.0:
		var bar = UiTheme.progress_bar(col, 8)
		bar.value = pr
		v.add_child(bar)
	if own and r.id == active_id():
		var ck = UiTheme.icon_rect("check", 28, UiTheme.GOOD)
		UiTheme.place(ck, 1.0, 0.0, -32, 4, 28, 28)
		b.add_child(ck)
	var emb = Control.new()
	emb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shape = UiTheme.rarity_shape(rar)
	emb.draw.connect(func(): UiTheme.draw_shape(emb, shape, Rect2(Vector2.ZERO, Vector2(22, 22)), col, Color(0, 0, 0, 0.9), 2.0))
	UiTheme.place(emb, 0, 0, 6, 6, 22, 22)
	b.add_child(emb)
	b.pressed.connect(func():
		_sel = r.id
		refresh())
	UiTheme.juice(b)
	return b

func _show(r: Dictionary) -> void:
	ScreenBase.clear(_info)
	_preview.clear_all()
	if r.is_empty():
		_info.add_child(UiTheme.label("Nothing here yet.", 20, UiTheme.MUTED))
		return
	var own = owned(r.id)
	var rar = str(r.get("rarity", "common"))
	var col = UiTheme.rarity_color(rar)
	var model = str(r.get("model", ""))
	var tint = Color(r.get("tint", "#ffffff")) if own else Color(0.05, 0.05, 0.07)
	var a = _preview.add_model(model, float(r.get("scale", 1.0)), tint, col if own else UiTheme.LOCKED, r.get("attachments", []))
	var sc = float(r.get("scale", 1.0))
	_preview.camera_distance = clampf(3.0 + sc * 3.2, 2.2, 9.0)
	_preview.look_height = clampf(sc * 0.9, 0.3, 1.6)
	_preview._update_camera()
	a.rotation.y = deg_to_rad(25)
	var nm = UiTheme.label(str(r.get("name", r.id)) if own else "Not found yet", 26, col.lightened(0.2) if own else UiTheme.MUTED, true)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_child(nm)
	if own:
		_info.add_child(UiTheme.label(UiTheme.rarity_name(rar), 17, col))
		_info.add_child(UiTheme.wrap_label(str(r.get("desc", "")), 17, UiTheme.MUTED, 400))
		fill_info(r, _info)
	else:
		var h = HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.add_child(UiTheme.icon_rect("map", 32, UiTheme.GOLD))
		h.add_child(UiTheme.wrap_label(source_hint(r), 19, UiTheme.TEXT, 340))
		_info.add_child(h)
		fill_locked(r, _info)

func fill_locked(_r: Dictionary, _box: VBoxContainer) -> void:
	pass
