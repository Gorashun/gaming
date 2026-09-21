class_name CorridorHud
extends Control
## Krit-lagret ovanpå korridoren: HP, rum, Pips, kritstråk och character
## sheet-knappen (UI_GUIDE §17, CORRIDOR_DESIGN §2.7).
##
## [b]Grundregeln från UI_GUIDE §8 gäller oförändrad:[/b] korridoren är
## substantiv (pixlar i 3D), allt spelet SÄGER om den är krita ovanpå. Inget
## tal, ingen etikett och ingen stapel ritas i 3D-lagret.
##
## Kritstråket ritar sig bakom spelaren: ett streck per gången ruta, ett
## kraftigare vid den man står på. Det går inte att zooma, panorera eller rita
## i. Det är en kvittens, inte ett verktyg.

signal character_sheet_pressed()
signal settings_pressed()
## "?" – hjälp-lagret i striden. Knappen bor i krit-raden och inte i
## stridsskärmens toppfält: i korridorsplitten har striden 352 dp, och ett eget
## toppfält där kostar 48 dp som COMBAT_READABILITY §8 hellre ger kvittot.
signal help_pressed()

const HUD_HEIGHT_DP: int = 44
const TRAIL_HEIGHT_DP: int = 16
const HP_BAR_WIDTH_DP: int = 44
## Fler streck än så får inte plats på 360 dp; stråket visar de senaste.
const TRAIL_MAX: int = 26

var _hp_label: Label = null
var _hp_bar: ProgressBar = null
var _room_chip: Label = null
var _pips_label: Label = null
var _trail: HBoxContainer = null
var _trail_label: Label = null
var _sheet_button: Button = null
var _help_button: Button = null
var _sheet_badge: bool = false
var _floor_index: int = 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()


func _build() -> void:
	if _hp_label != null:
		return
	var margin: int = Tokens.dpi(Tokens.SPACE_3)

	var bar: HBoxContainer = HBoxContainer.new()
	bar.name = "Bar"
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = margin
	bar.offset_right = -margin
	bar.offset_bottom = Tokens.dp(HUD_HEIGHT_DP)
	bar.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))
	bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(bar)

	_hp_label = _label("", Tokens.TYPE_BODY, Tokens.SEM_BLOOD)
	bar.add_child(_hp_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.name = "HpBar"
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(Tokens.dp(HP_BAR_WIDTH_DP), Tokens.dp(8))
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track: StyleBoxFlat = Tokens.box(Tokens.SURFACE_LINE, true, Tokens.STROKE_HAIR, Tokens.RADIUS_CHIP)
	track.bg_color = Tokens.SURFACE_PIT
	_hp_bar.add_theme_stylebox_override("background", track)
	var fill: StyleBoxFlat = Tokens.box(Tokens.SEM_BLOOD, true, 0.0, Tokens.RADIUS_CHIP)
	fill.bg_color = Tokens.SEM_BLOOD
	_hp_bar.add_theme_stylebox_override("fill", fill)
	bar.add_child(_hp_bar)

	_room_chip = _label("", Tokens.TYPE_LABEL, Tokens.CHALK_300)
	_room_chip.add_theme_stylebox_override("normal", Tokens.box(Tokens.SURFACE_LINE, true, Tokens.STROKE_HAIR, Tokens.RADIUS_CHIP))
	bar.add_child(_room_chip)

	_pips_label = _label("", Tokens.TYPE_LABEL, Tokens.SEM_CHARGE)
	bar.add_child(_pips_label)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)

	_help_button = _icon_button(Art.ui_icon_glyph(&"help"), Tokens.SEM_CHARGE)
	_help_button.visible = false
	_help_button.pressed.connect(func() -> void: help_pressed.emit())
	bar.add_child(_help_button)

	_sheet_button = _icon_button("◫", Tokens.CHALK_300)
	_sheet_button.pressed.connect(func() -> void: character_sheet_pressed.emit())
	bar.add_child(_sheet_button)

	var settings_button: Button = _icon_button("⚙", Tokens.CHALK_300)
	settings_button.pressed.connect(func() -> void: settings_pressed.emit())
	bar.add_child(settings_button)

	var trail_row: HBoxContainer = HBoxContainer.new()
	trail_row.name = "TrailRow"
	trail_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	trail_row.offset_left = margin
	trail_row.offset_right = -margin
	trail_row.offset_top = Tokens.dp(HUD_HEIGHT_DP)
	trail_row.offset_bottom = Tokens.dp(HUD_HEIGHT_DP + TRAIL_HEIGHT_DP)
	trail_row.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))
	trail_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(trail_row)

	_trail = HBoxContainer.new()
	_trail.name = "Trail"
	_trail.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_1) / 2)
	_trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trail_row.add_child(_trail)

	_trail_label = _label("", Tokens.TYPE_CAPTION, Tokens.CHALK_500)
	trail_row.add_child(_trail_label)


func _label(text: String, size: int, color: Color) -> Label:
	var node: Label = Label.new()
	node.text = text
	# INTE clip_text: den nollar etikettens minimibredd i en HBoxContainer och
	# raden blir en rad osynliga 1 px-etiketter bredvid HP-stapeln.
	node.clip_text = false
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.add_theme_font_size_override("font_size", Tokens.dpi(size))
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


func _icon_button(glyph: String, color: Color) -> Button:
	var button: Button = Button.new()
	button.text = glyph
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(Tokens.dp(34), Tokens.dp(34))
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_BODY))
	button.add_theme_color_override("font_color", color)
	var style: StyleBoxFlat = Tokens.box(Tokens.SURFACE_LINE, true, Tokens.STROKE_HAIR)
	style.bg_color = Color(Tokens.SURFACE_RAISED, 0.85)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, style)
	return button


## HP, rum, våning och Pips. Anropas efter varje steg och efter varje strid.
func set_status(hp: int, max_hp: int, room: int, floor_index: int, pips: int) -> void:
	_build()
	_hp_label.text = "%d/%d" % [hp, max_hp]
	_hp_bar.max_value = maxi(max_hp, 1)
	_hp_bar.value = clampi(hp, 0, maxi(max_hp, 1))
	_room_chip.text = " %s " % Tokens.translate_or("CORRIDOR_ROOM", "ROOM %d") % room
	_pips_label.text = "◉ %d" % pips
	_floor_index = floor_index


## Kritstråket: ett streck per gången ruta. Visar BARA det spelaren sett.
func set_trail(tiles: int, steps: int) -> void:
	_build()
	for child: Node in _trail.get_children():
		child.queue_free()
	var shown: int = mini(tiles, TRAIL_MAX)
	for i: int in range(shown):
		var mark: ColorRect = ColorRect.new()
		var current: bool = i == shown - 1
		mark.color = Tokens.CHALK_100 if current else Tokens.CHALK_300
		mark.custom_minimum_size = Vector2(Tokens.dp(4.5 if current else 3.0), Tokens.dp(1.0 if current else 0.7))
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_trail.add_child(mark)
	_trail_label.text = Tokens.translate_or("CORRIDOR_FLOOR_TILES", "FLOOR %d · %d TILES") % [_floor_index, steps]


## "?" finns bara medan en strid pågår. En knapp som inte gör något är värre än
## ingen knapp (UI_GUIDE §7: ett element som inte lärts ut är frånvarande).
func set_help_visible(value: bool) -> void:
	_build()
	_help_button.visible = value


## Kritringen som säger att något ändrats och inte setts (CORRIDOR_DESIGN §4.4).
func set_sheet_badge(pending: bool) -> void:
	_build()
	if _sheet_badge == pending:
		return
	_sheet_badge = pending
	var style: StyleBoxFlat = Tokens.box(
		Tokens.SEM_CHARGE if pending else Tokens.SURFACE_LINE, true, Tokens.STROKE_HAIR)
	style.bg_color = Color(Tokens.SURFACE_RAISED, 0.85)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		_sheet_button.add_theme_stylebox_override(state, style)
	_sheet_button.add_theme_color_override("font_color",
		Tokens.SEM_CHARGE if pending else Tokens.CHALK_300)
