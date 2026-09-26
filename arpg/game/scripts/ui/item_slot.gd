class_name ItemSlot
extends Button
## One item tile. Rarity is always colour + frame + emblem shape (colour-blind safe):
##   frame: tinted gradient tile, border in rarity colour (double border for Legendary+),
##   emblem: rarity shape (◻ ● ◆ ⬢ ★ flame crown sun) top-left,
##   icon: rendered 3D prop (weapons) or vector slot icon tinted by rarity,
##   badges: ▲/▼ power vs equipped, new-dot, lock, +N upgrade level, empty-slot silhouette.

var item = null
var slot_name = ""
var selected = false:
	set(v):
		selected = v
		queue_redraw()
var delta = 0.0
var is_new = false
var dim = false
var _size = 88.0
var _icon: TextureRect
var _overlay: Control
var _col = Color(0.3, 0.28, 0.35)
var _model = ""

func setup(it, slot := "", size := 88.0) -> void:
	item = it
	slot_name = slot
	_size = size
	custom_minimum_size = Vector2(size, size)
	focus_mode = Control.FOCUS_NONE
	for s in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(s, StyleBoxEmpty.new())
	text = ""
	_col = UiTheme.rarity_color(it.rarity) if it else Color(0.3, 0.28, 0.35)
	if _icon == null:
		_icon = TextureRect.new()
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_icon)
		_overlay = Control.new()
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay.draw.connect(_draw_overlay)
		add_child(_overlay)
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pad = size * 0.14
	_icon.offset_left = pad
	_icon.offset_top = pad
	_icon.offset_right = -pad
	_icon.offset_bottom = -pad
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_refresh_icon()
	UiTheme.juice(self)
	queue_redraw()

func _refresh_icon() -> void:
	if item:
		var t = ItemIcons.texture_for(item)
		_model = ItemIcons.model_for(item)
		if t == null:
			t = UiTheme.icon(ItemIcons.glyph_for(item))
			_icon.modulate = Color(_col.lightened(0.2), 0.55)
			var studio = ItemIcons.instance()
			if not studio.icon_ready.is_connected(_on_icon_ready):
				studio.icon_ready.connect(_on_icon_ready)
		else:
			_icon.modulate = Color.WHITE if _model != "" else _col.lightened(0.25)
		_icon.texture = t
	else:
		var g = slot_name.trim_suffix("1").trim_suffix("2")
		_icon.texture = UiTheme.icon(g) if slot_name != "" and UiTheme.has_icon(g) else null
		_icon.modulate = Color(0.5, 0.47, 0.56, 0.35)
	if dim:
		_icon.modulate.a *= 0.45

func _on_icon_ready(key: String) -> void:
	if key == _model and is_instance_valid(self):
		_refresh_icon()

func set_upgrade(d: float) -> void:
	delta = d
	queue_redraw()
	if _overlay:
		_overlay.queue_redraw()

func _draw() -> void:
	var r = Rect2(Vector2.ZERO, size)
	var rank = Items.rarity_index(item.rarity) if item else -1
	var bg = StyleBoxFlat.new()
	bg.set_corner_radius_all(int(_size * 0.14) if rank != 0 else 4)
	bg.bg_color = _col.darkened(0.8) if item else Color(0.07, 0.06, 0.1, 0.95)
	bg.bg_color.a = 0.97
	bg.border_color = _col if item else Color(0.28, 0.25, 0.32)
	bg.set_border_width_all(3 if rank >= 2 else 2)
	if selected:
		bg.border_color = Color.WHITE
		bg.set_border_width_all(4)
		bg.shadow_color = Color(_col, 0.8)
		bg.shadow_size = 10
	elif rank >= 3:
		bg.shadow_color = Color(_col, 0.35)
		bg.shadow_size = 5
	bg.anti_aliasing = true
	draw_style_box(bg, r)
	if item:
		# inner glow (radial feel with two insets)
		var g1 = StyleBoxFlat.new()
		g1.bg_color = Color(_col, 0.10 + 0.04 * rank)
		g1.set_corner_radius_all(int(_size * 0.3))
		draw_style_box(g1, r.grow(-_size * 0.14))
		if rank >= 4:
			var inner = StyleBoxFlat.new()
			inner.draw_center = false
			inner.border_color = Color(_col.lightened(0.5), 0.8) if rank != 5 else Color(1, 1, 1, 0.9)
			inner.set_border_width_all(2)
			inner.set_corner_radius_all(int(_size * 0.1))
			draw_style_box(inner, r.grow(-6))

func _draw_overlay() -> void:
	if item == null:
		return
	var s = _size
	var rank = Items.rarity_index(item.rarity)
	# Rarity emblem (shape) top-left
	if rank >= 1:
		var er = Rect2(Vector2(4, 4), Vector2(s * 0.26, s * 0.26))
		UiTheme.draw_shape(_overlay, UiTheme.rarity_shape(item.rarity), er, _col.lightened(0.1), Color(0.05, 0.02, 0.06), 2.0)
	# Upgrade level "+N"
	var up = int(item.get("upgrade", 0))
	var font = UiTheme.font_body()
	if up > 0:
		var txt = "+%d" % up
		var fsz = int(s * 0.2)
		var pos = Vector2(s - 6 - font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x, fsz + 2)
		_overlay.draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, 5, Color(0, 0, 0, 0.9))
		_overlay.draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, UiTheme.GOLD)
	# Compare arrow bottom-right: ▲ green / ▼ red (shape + colour)
	if absf(delta) >= 1.0:
		var c = Vector2(s - s * 0.17, s - s * 0.17)
		var k = s * 0.13
		var pts: PackedVector2Array
		var col: Color
		if delta > 0:
			pts = PackedVector2Array([c + Vector2(0, -k), c + Vector2(k, k * 0.7), c + Vector2(-k, k * 0.7)])
			col = UiTheme.GOOD
		else:
			pts = PackedVector2Array([c + Vector2(0, k), c + Vector2(k, -k * 0.7), c + Vector2(-k, -k * 0.7)])
			col = UiTheme.BAD
		_overlay.draw_colored_polygon(pts, col)
		var cl = pts.duplicate()
		cl.append(pts[0])
		_overlay.draw_polyline(cl, Color(0, 0, 0, 0.9), 2.0, true)
	# Lock bottom-left
	if item.get("locked", false):
		_overlay.draw_texture_rect(UiTheme.icon("lock"), Rect2(Vector2(4, s - s * 0.3), Vector2(s * 0.26, s * 0.26)), false, UiTheme.GOLD)
	# New dot top-right
	if is_new or item.get("new", false):
		_overlay.draw_circle(Vector2(s - 10, 10), 7, UiTheme.EMBER)
		_overlay.draw_arc(Vector2(s - 10, 10), 7, 0, TAU, 16, Color(0.1, 0.02, 0), 2.0, true)
