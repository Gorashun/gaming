class_name SlotView
extends PanelContainer
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

## Slot-ikonens cellstorlek (assets/sprites/ui/slot_*.png).
const ICON_CELL: int = 16

var _slot: Slot = null
var _die: Die = null
## Heltalsskala för tärningen i sloten. 32 px × 3 = 96 px.
const DIE_SCALE_IN_SLOT: int = 3

var _art: Control = null
var _icon: Sprite2D = null
var _die_art: DieArt = null
var _type_label: Label = null
var _die_label: Label = null
var _preview_label: Label = null
var _index_label: Label = null
var _highlight: bool = false


func _init() -> void:
	# Som i DieView: minsta bredd = träffytans krav (48 dp), resten fördelas.
	# PanelContainer: minsta höjd följer etiketterna, så raden kan aldrig
	# svämma ut över tumzonen.
	custom_minimum_size = Vector2(Tokens.dp(Tokens.TOUCH_MIN), Tokens.dp(Tokens.TOUCH_MIN))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_1))
	add_child(column)

	# Slot-ikonen ligger ÖVERST i kolumnen, inte som överlägg: formkoden i
	# UI_GUIDE §2.4 ska läsas tillsammans med ordet, inte bakom det.
	_art = Control.new()
	_art.name = "Art"
	_art.custom_minimum_size = Vector2(0.0, float(ICON_CELL * Art.ICON_SCALE))
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_art)

	_icon = Art.pixel_sprite(null, Art.ICON_SCALE)
	_icon.name = "SlotIcon"
	_art.add_child(_icon)
	_art.resized.connect(_layout_icon)

	_type_label = _make_label(Tokens.TYPE_CAPTION, Tokens.CHALK_300)
	column.add_child(_type_label)

	# Den placerade tärningen ritas som riktig pixeltärning i sloten, precis som
	# i mockupen: kedjan ska gå att läsa på brädet utan att titta ned i brickan.
	_die_art = DieArt.new()
	_die_art.name = "DieArt"
	_die_art.custom_minimum_size = Vector2(0.0, float(DieArt.CELL * DIE_SCALE_IN_SLOT))
	_die_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_die_art.visible = false
	column.add_child(_die_art)

	_die_label = _make_label(Tokens.TYPE_HEADING, Tokens.CHALK_100)
	_die_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_die_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	column.add_child(_die_label)

	# Värde och multiplikator på SAMMA rad: fem slots plus tumzon ryms annars
	# inte på 640 dp höjd.
	_preview_label = _make_label(Tokens.TYPE_LABEL, Tokens.SEM_DAMAGE)
	column.add_child(_preview_label)

	_index_label = _make_label(Tokens.TYPE_CAPTION, Tokens.CHALK_500)
	column.add_child(_index_label)


static func _make_label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", Tokens.dpi(font_size))
	label.add_theme_color_override("font_color", color)
	# clip_text: utan detta blir etikettens textbredd containerns minsta bredd,
	# och fem slots med texten "AMBOSS" tvingar raden bredare än skärmen.
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Noden som bär slot-ikonen (assets/sprites/ui/slot_<typ>.png).
func art_root() -> Control:
	return _art


func _layout_icon() -> void:
	if _icon == null or _art == null:
		return
	_icon.position = Art.snap(_art.size * 0.5, Art.ICON_SCALE)


func bind(index: int, slot: Slot, die: Die) -> void:
	slot_index = index
	_slot = slot
	_die = die
	_index_label.text = "%d" % (index + 1)
	_type_label.text = Tokens.slot_label(slot.type)
	_icon.texture = Art.slot_icon(slot.type)
	_icon.modulate = Tokens.slot_color(slot.type)
	_icon.visible = _icon.texture != null
	# Saknas ikonen faller typraden tillbaka på reservglyphen ur UI_GUIDE §2.4,
	# så formkoden aldrig försvinner helt.
	if _icon.texture == null:
		_type_label.text = "%s %s" % [Tokens.slot_icon(slot.type), Tokens.slot_label(slot.type)]
	_layout_icon()
	_type_label.add_theme_color_override("font_color", Tokens.slot_color(slot.type))

	_die_art.visible = false
	if slot.blocked:
		_die_label.visible = true
		_die_label.text = tr("SLOT_STATE_GRABBED")
		_die_label.add_theme_color_override("font_color", Tokens.SEM_BLOOD)
	elif die != null:
		_die_art.show_die(die, hash(die.id))
		_die_art.visible = _die_art.is_drawing()
		var face: Face = die.showing_face()
		# Siffran står kvar när konsten inte bär värdet (glyph-sidor) eller när
		# texturen saknas helt – sloten får aldrig bli tom och oläslig.
		_die_label.visible = not _die_art.shows_value()
		_die_label.text = str(face.value) if face != null else "?"
		_die_label.add_theme_color_override("font_color", Tokens.BONE_DIE)
	else:
		_die_label.visible = true
		_die_label.text = tr("SLOT_STATE_EMPTY")
		_die_label.add_theme_color_override("font_color", Tokens.CHALK_500)

	_apply_style()


## Vad kedjan räknar ut för sloten just nu. Kommer från en riktig
## [method Resolver.resolve] på en kopia – förhandsvisningen ÄR utfallet.
func set_preview(effective_value: int, multiplier: int, occupied: bool) -> void:
	if not occupied:
		_preview_label.text = ""
		return
	if multiplier > 1:
		_preview_label.text = "%d ×%d" % [effective_value, multiplier]
		_preview_label.add_theme_color_override("font_color", Tokens.multiplier_color(multiplier))
	else:
		_preview_label.text = "= %d" % effective_value
		_preview_label.add_theme_color_override("font_color", Tokens.SEM_DAMAGE)


## Aktiveringspulsen i kedjan (UI_GUIDE §5.1). Blixten läggs på den RIKTIGA
## tärningssprajten via palette_lut-shadern; ramen pulsar med.
func pulse_die(duration: float = Tokens.MOTION_BASE) -> void:
	if _die_art != null and _die_art.visible:
		_die_art.flash(0.8, duration)
	Juice.pulse(self, 1.18, duration)


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
	add_theme_stylebox_override("panel", style)
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
