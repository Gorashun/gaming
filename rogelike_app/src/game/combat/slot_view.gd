class_name SlotView
extends Control
## En av brädets fem slots. UI_GUIDE §2.4 och §2.9: 64×76 dp visuellt,
## 72×84 dp träffyta, färg [b]och[/b] ramstil [b]och[/b] ikon [b]och[/b] ord –
## en färgblind spelare ska kunna skilja alla fem typer utan att se färgen.
##
## Sloten visar tre saker samtidigt, vilket är hela poängen med förhandsvisningen
## (GAME_DESIGN §6): vad sloten gör, vilken tärning som ligger i, och vad kedjan
## kommer att räkna ut för just den här sloten (effektivt värde + multiplikator).
##
## Pixelgrafik: lägg slot-ramen i [method art_root]; etiketterna ovanför och
## under är krit-UI och ska ligga kvar i [code]ChalkUI[/code]-lagret.

signal tapped(slot_index: int)
## Spelaren släppte en tärning här (drag-and-drop, UI_GUIDE §4.1).
signal die_dropped(slot_index: int, die_index: int)

var slot_index: int = -1

var _slot: Slot = null
var _die: Die = null
var _panel: Panel = null
var _art: Control = null
var _type_label: Label = null
var _die_label: Label = null
var _preview_label: Label = null
var _multiplier_label: Label = null
var _index_label: Label = null
var _highlight: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(Tokens.dp(Tokens.SLOT_WIDTH), Tokens.dp(Tokens.SLOT_HEIGHT + 20))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP

	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	_art = Control.new()
	_art.name = "Art"
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)

	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_1))
	add_child(column)

	_type_label = _make_label(Tokens.TYPE_CAPTION, Tokens.CHALK_300)
	column.add_child(_type_label)

	_die_label = _make_label(Tokens.TYPE_TITLE, Tokens.CHALK_100)
	_die_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_die_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	column.add_child(_die_label)

	_preview_label = _make_label(Tokens.TYPE_LABEL, Tokens.SEM_DAMAGE)
	column.add_child(_preview_label)

	_multiplier_label = _make_label(Tokens.TYPE_LABEL, Tokens.SEM_CHARGE)
	column.add_child(_multiplier_label)

	_index_label = _make_label(Tokens.TYPE_CAPTION, Tokens.CHALK_500)
	column.add_child(_index_label)


static func _make_label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", Tokens.dpi(font_size))
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func art_root() -> Control:
	return _art


func bind(index: int, slot: Slot, die: Die) -> void:
	slot_index = index
	_slot = slot
	_die = die
	_index_label.text = "SLOT %d" % (index + 1)
	_type_label.text = "%s %s" % [Tokens.slot_icon(slot.type), Tokens.slot_label(slot.type)]
	_type_label.add_theme_color_override("font_color", Tokens.slot_color(slot.type))

	if slot.blocked:
		_die_label.text = "GRIPEN"
		_die_label.add_theme_color_override("font_color", Tokens.SEM_BLOOD)
	elif die != null:
		var face: Face = die.showing_face()
		_die_label.text = str(face.value) if face != null else "?"
		_die_label.add_theme_color_override("font_color", Tokens.BONE_DIE)
	else:
		_die_label.text = "TOM"
		_die_label.add_theme_color_override("font_color", Tokens.CHALK_500)

	_apply_style()


## Vad kedjan räknar ut för sloten just nu. Kommer från en riktig
## [method Resolver.resolve] på en kopia – förhandsvisningen ÄR utfallet.
func set_preview(effective_value: int, multiplier: int, occupied: bool) -> void:
	if not occupied:
		_preview_label.text = ""
		_multiplier_label.text = ""
		return
	_preview_label.text = "= %d" % effective_value
	if multiplier > 1:
		_multiplier_label.text = "×%d" % multiplier
		_multiplier_label.add_theme_color_override("font_color", Tokens.multiplier_color(multiplier))
		_multiplier_label.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_LABEL))
	else:
		_multiplier_label.text = ""


## Pulserar konturen när en tärning bärs runt (UI_GUIDE §4.1.2).
func set_highlight(value: bool) -> void:
	if _highlight == value:
		return
	_highlight = value
	_apply_style()


func _apply_style() -> void:
	if _slot == null:
		return
	var color: Color = Tokens.slot_color(_slot.type)
	var width: float = float(Tokens.slot_style(_slot.type)["width"])
	if _slot.blocked:
		color = Tokens.SURFACE_LINE
	elif _highlight:
		color = Tokens.SEM_CHARGE
		width = Tokens.STROKE_HEAVY
	var style: StyleBoxFlat = Tokens.box(color, true, width, Tokens.RADIUS_BUTTON)
	style.bg_color = Tokens.SURFACE_SLATE if _slot.blocked else Tokens.SURFACE_RAISED
	_panel.add_theme_stylebox_override("panel", style)
	modulate.a = 0.45 if _slot.blocked else 1.0


func accepts_dice() -> bool:
	return _slot != null and not _slot.blocked


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			tapped.emit(slot_index)
			accept_event()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return accepts_dice() and data is Dictionary and (data as Dictionary).has("die_index")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	die_dropped.emit(slot_index, int((data as Dictionary)["die_index"]))
