class_name DieView
extends Control
## En tärning i brickan (tumzonen). UI_GUIDE §2.9: 64 dp visuellt, 72 dp träffyta.
##
## M1 ritar tärningen som en [ColorRect] med värdet i klartext. [b]Bytesplatsen
## för pixelgrafik är noden [code]Art[/code][/b]: lägg en [Sprite2D]-baserad
## tärning där (research 04 §3: kropp + glyph + palett-LUT + spricka) och ta bort
## [member _value_label]. Storlek, träffyta, drag-and-drop och markeringslogik
## ligger i den här klassen och behöver inte röras.
##
## Interaktion (UI_GUIDE §4.1 och §4.2, båda alltid aktiva):
## [br]• Drag: [method _get_drag_data] lämnar över [code]{die_index}[/code].
## [br]• Tapp: [signal tapped] – skärmen markerar tärningen och nästa tapp på en
##   slot placerar den. Aldrig dubbeltapp-krav.

## Spelaren tappade tärningen.
signal tapped(die_index: int)

var die_index: int = -1
var _die: Die = null
var _placed_in_slot: int = -1
var _selected: bool = false
var _locked: bool = false
var _stolen: bool = false

var _panel: Panel = null
var _art: DieArt = null
var _value_label: Label = null
var _effect_label: Label = null
var _state_label: Label = null


func _init() -> void:
	# Minsta bredd, inte önskad bredd: sex tärningar ska rymmas på 360 dp
	# (UI_GUIDE §8 mätte 49,7 dp på den smalaste målskärmen). Bredden fördelas
	# sedan av HBoxContainer via SIZE_EXPAND_FILL.
	custom_minimum_size = Vector2(Tokens.dp(Tokens.DIE_MIN_WIDTH), Tokens.dp(Tokens.DIE_SIZE + 8))
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	# Pixeltärningen: kropp + glyph + palett-LUT + spricka (DieArt).
	_art = DieArt.new()
	_art.name = "Art"
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_art)

	_value_label = Label.new()
	_value_label.name = "Value"
	_value_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value_label.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_TITLE))
	_value_label.add_theme_color_override("font_color", Tokens.BONE_PIP)
	_value_label.clip_text = true
	_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_value_label)

	_effect_label = Label.new()
	_effect_label.name = "Effect"
	_effect_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_effect_label.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_CAPTION))
	_effect_label.add_theme_color_override("font_color", Tokens.BONE_PIP)
	_effect_label.clip_text = true
	_effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_effect_label)

	_state_label = Label.new()
	_state_label.name = "State"
	# PRESET_BOTTOM_WIDE ger en rect med höjd 0 vid underkanten, så texten ritas
	# NEDANFÖR tärningen. GROW_DIRECTION_BEGIN låter den växa uppåt i stället.
	_state_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_state_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_state_label.custom_minimum_size = Vector2(0.0, Tokens.dp(Tokens.TYPE_CAPTION + 4))
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state_label.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_CAPTION))
	_state_label.add_theme_color_override("font_color", Tokens.CHALK_500)
	_state_label.clip_text = true
	_state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_state_label)


## Den komponerade pixeltärningen. Sedan M1.5 ritar den riktiga sprites;
## [member _value_label] är kvar som reserv för när en textur saknas.
func art_root() -> Control:
	return _art


## Aktiveringspuls på den RIKTIGA tärningssprajten (UI_GUIDE §5.1), inte på
## en platshållarruta. Faller tillbaka på en skalpuls om konsten inte ritas.
func pulse_art(duration: float = Tokens.MOTION_BASE) -> void:
	if _art != null and _art.is_drawing():
		_art.flash(0.75, duration)
	Juice.pulse(self, 1.14, duration)


func bind(index: int, die: Die, placed_in_slot: int, stolen: bool) -> void:
	die_index = index
	_die = die
	_placed_in_slot = placed_in_slot
	_stolen = stolen
	var face: Face = die.showing_face() if die != null else null
	_locked = face != null and face.effect == Rules.FaceEffectKind.LOCKED
	_refresh(face)


func set_selected(value: bool) -> void:
	if _selected == value:
		return
	_selected = value
	_refresh(_die.showing_face() if _die != null else null)
	if value:
		Juice.pulse(self, 1.12, Tokens.MOTION_SNAP)


func is_placed() -> bool:
	return _placed_in_slot >= 0


func is_available() -> bool:
	return not _stolen and _placed_in_slot < 0


func _refresh(face: Face) -> void:
	if _art != null:
		# Sprickvarianten seedas på tärningens id: samma tärning har samma
		# spricka hela runnen, men ingen slump dras ur Rng-strömmen.
		_art.show_die(_die, hash(_die.id) if _die != null else 0)
		_art.visible = _die != null
	if face == null:
		_value_label.text = "–"
		_effect_label.text = ""
		_state_label.text = tr("DIE_MISSING")
		_panel.add_theme_stylebox_override("panel", Tokens.box(Tokens.SURFACE_LINE, true, Tokens.STROKE_HAIR, Tokens.RADIUS_DIE))
		return

	_value_label.text = str(face.value)
	# Ritas sidan som ögon bär konsten värdet och siffran vore dubbelt. Ritas
	# den som glyph (gift, eld, blod, tomrum) står värdet i stället i
	# effektraden, precis som i mockupen ("GIFT 2").
	var art_has_value: bool = _art != null and _art.shows_value()
	_value_label.visible = not art_has_value
	_effect_label.text = _effect_label_text(face, not art_has_value)
	_effect_label.add_theme_color_override("font_color", _effect_color(face))

	var body: Color = Tokens.BONE_DIE
	var border: Color = Tokens.CHALK_300
	if _stolen:
		_state_label.text = tr("DIE_STOLEN")
		body = Tokens.SURFACE_LINE
		border = Tokens.SEM_BLOOD
	elif _placed_in_slot >= 0:
		_state_label.text = tr("DIE_IN_SLOT") % (_placed_in_slot + 1)
		body = Tokens.SURFACE_RAISED
		border = Tokens.CHALK_500
	elif _locked:
		_state_label.text = tr("DIE_LOCKED")
		border = Tokens.SEM_CHARGE
	else:
		_state_label.text = tr("DIE_DRAG_HINT")

	if _selected:
		border = Tokens.SEM_CHARGE

	var style: StyleBoxFlat = Tokens.box(border, true, Tokens.STROKE_BOLD if _selected else Tokens.STROKE_REG, Tokens.RADIUS_DIE)
	# Ritar DieArt tärningen är panelen bara en ram: en benvit botten bakom en
	# pixeltärning gör silhuetten otydlig (UI_GUIDE §11 punkt 7).
	style.bg_color = Tokens.SURFACE_SLATE if (_art != null and _art.is_drawing()) else body
	_panel.add_theme_stylebox_override("panel", style)

	var pip_color: Color = Tokens.BONE_PIP if body == Tokens.BONE_DIE else Tokens.CHALK_500
	_value_label.add_theme_color_override("font_color", pip_color)
	_value_label.modulate.a = 0.45 if _placed_in_slot >= 0 or _stolen else 1.0
	if _art != null:
		_art.modulate.a = 0.5 if _placed_in_slot >= 0 or _stolen else 1.0


## Effektraden ovanför tärningen. [param include_value] lägger till sidans
## värde när konsten inte visar det själv.
static func _effect_label_text(face: Face, include_value: bool) -> String:
	var text: String = _effect_glyph(face)
	if not include_value:
		return text
	if text == "":
		return str(face.value)
	return "%s %d" % [text, face.value]


static func _effect_glyph(face: Face) -> String:
	match face.effect:
		Rules.FaceEffectKind.APPLY_POISON:
			return Tokens.translate("FACE_EFFECT_POISON")
		Rules.FaceEffectKind.APPLY_BURN:
			return Tokens.translate("FACE_EFFECT_BURN")
		Rules.FaceEffectKind.LIFESTEAL:
			return Tokens.translate("FACE_EFFECT_LIFESTEAL")
		Rules.FaceEffectKind.COPY_LEFT:
			return Tokens.translate("FACE_EFFECT_COPY_LEFT")
		Rules.FaceEffectKind.ANVIL_SELF:
			return Tokens.translate("FACE_EFFECT_ANVIL")
		Rules.FaceEffectKind.GROW:
			return Tokens.translate("FACE_EFFECT_GROW")
		Rules.FaceEffectKind.REFUND_REROLL:
			return Tokens.translate("FACE_EFFECT_REFUND")
		Rules.FaceEffectKind.LOCKED:
			return Tokens.translate("FACE_EFFECT_LOCKED")
	return ""


static func _effect_color(face: Face) -> Color:
	match face.effect:
		Rules.FaceEffectKind.APPLY_POISON:
			return Tokens.SEM_POISON
		Rules.FaceEffectKind.APPLY_BURN:
			return Tokens.SEM_FIRE
		Rules.FaceEffectKind.LIFESTEAL:
			return Tokens.SEM_HEAL
		Rules.FaceEffectKind.COPY_LEFT:
			return Tokens.SEM_FROST
		Rules.FaceEffectKind.ANVIL_SELF:
			return Tokens.SEM_SHIELD
	return Tokens.CHALK_500


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			tapped.emit(die_index)
			accept_event()


# --- Drag (UI_GUIDE §4.1) --------------------------------------------------

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not is_available():
		return null
	Juice.haptic(Haptics.Level.LIGHT)
	Juice.sfx("die_lift", 1.0)

	var preview: Panel = Panel.new()
	preview.custom_minimum_size = size
	preview.size = size
	var style: StyleBoxFlat = Tokens.box(Tokens.SEM_CHARGE, true, Tokens.STROKE_BOLD, Tokens.RADIUS_DIE)
	style.bg_color = Tokens.BONE_DIE
	preview.add_theme_stylebox_override("panel", style)
	var label: Label = Label.new()
	label.text = _value_label.text
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_TITLE))
	label.add_theme_color_override("font_color", Tokens.BONE_PIP)
	preview.add_child(label)

	# UI_GUIDE §4.1.3: tärningen följer fingret med 4 dp offset uppåt.
	var wrapper: Control = Control.new()
	wrapper.add_child(preview)
	preview.position = -size * 0.5 - Vector2(0.0, Tokens.dp(4))
	set_drag_preview(wrapper)
	return {"die_index": die_index}
