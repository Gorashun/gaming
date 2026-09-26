extends Node3D
## Billboarded health bar above monsters (only shown after first damage, always for elites/bosses).

var _bg: Sprite3D
var _fg: Sprite3D
var _label: Label3D
var _v = 1.0
var _shown = false
var actor: Node3D

static var _white: ImageTexture

static func white() -> ImageTexture:
	if _white == null:
		var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(img)
	return _white

func setup(m) -> void:
	actor = m
	var h = 2.3 * float(m.rec.get("scale", 1.0)) * (1.25 if m.kind in ["rare", "champion"] else 1.0)
	if m.kind == "boss":
		visible = false   # bosses use the HUD bar
		return
	position.y = h
	_bg = _bar(Color(0.05, 0.03, 0.06, 0.85), 1.0, 0)
	_fg = _bar(Color("#e0463b") if m.kind == "normal" else (Color("#6fb3ff") if m.kind == "champion" else Color("#ffd23f")), 1.0, 1)
	var elite: bool = m.kind in ["rare", "champion"]
	if elite:
		_label = Label3D.new()
		_label.text = m.display_name
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.fixed_size = true
		_label.pixel_size = 0.0011
		_label.font_size = 30
		_label.outline_size = 8
		_label.no_depth_test = true
		_label.modulate = _fg.modulate
		_label.position.y = 0.28
		add_child(_label)
	_shown = elite
	visible = _shown

func _bar(col: Color, width: float, prio: int) -> Sprite3D:
	var s = Sprite3D.new()
	s.texture = white()
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.no_depth_test = true
	s.render_priority = prio
	s.modulate = col
	s.pixel_size = 0.01
	s.scale = Vector3(width * 30.0, 3.0, 1)
	s.centered = true
	add_child(s)
	return s

func set_value(v: float) -> void:
	_v = clampf(v, 0.0, 1.0)
	if _fg == null:
		return
	visible = true
	_fg.scale.x = 30.0 * _v
	_fg.offset.x = -(1.0 - _v) * 2.0 * 0.5 / 1.0 * 0.0
	# keep left-aligned: shift by half the lost width in world units
	_fg.position.x = 0.0
	_fg.centered = true
	_fg.position = Vector3(-(1.0 - _v) * 0.6, 0, 0)
