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
var _art: Control = null
var _value_label: Label = null
var _effect_label: Label = null
var _state_label: Label = null


func _init() -> void:
	custom_minimum_size = Vector2(Tokens.dp(Tokens.DIE_HIT), Tokens.dp(Tokens.DIE_HIT + 14))
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	# Plats för pixelsprite. Tom i M1.
	_art = Control.new()
	_art.name = "Art"
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)

	_value_label = Label.new()
	_value_label.name = "Value"
	_value_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value_label.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_TITLE))
	_value_label.add_theme_color_override("font_color", Tokens.BONE_PIP)
	_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_value_label)

	_effect_label = Label.new()
	_effect_label.name = "Effect"
	_effect_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_effect_label.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_CAPTION))
	_effect_label.add_theme_color_override("font_color", Tokens.BONE_PIP)
	_effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_effect_label)

	_state_label = Label.new()
	_state_label.name = "State"
	_state_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state_label.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_CAPTION))
	_state_label.add_theme_color_override("font_color", Tokens.CHALK_500)
	_state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_state_label)


## Noden där en pixeltärning ska läggas in. Tom i M1.
func art_root() -> Control:
	return _art


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
	if face == null:
		_value_label.text = "–"
		_effect_label.text = ""
		_state_label.text = "SAKNAS"
		_panel.add_theme_stylebox_override("panel", Tokens.box(Tokens.SURFACE_LINE, true, Tokens.STROKE_HAIR, Tokens.RADIUS_DIE))
		return

	_value_label.text = str(face.value)
	_effect_label.text = _effect_glyph(face)
	_effect_label.add_theme_color_override("font_color", _effect_color(face))

	var body: Color = Tokens.BONE_DIE
	var border: Color = Tokens.CHALK_300
	if _stolen:
		_state_label.text = "STULEN"
		body = Tokens.SURFACE_LINE
		border = Tokens.SEM_BLOOD
	elif _placed_in_slot >= 0:
		_state_label.text = "PL. %d" % (_placed_in_slot + 1)
		body = Tokens.SURFACE_RAISED
		border = Tokens.CHALK_500
	elif _locked:
		_state_label.text = "LÅST"
		border = Tokens.SEM_CHARGE
	else:
		_state_label.text = "DRA →"

	if _selected:
		border = Tokens.SEM_CHARGE

	var style: StyleBoxFlat = Tokens.box(border, true, Tokens.STROKE_BOLD if _selected else Tokens.STROKE_REG, Tokens.RADIUS_DIE)
	style.bg_color = body
	_panel.add_theme_stylebox_override("panel", style)

	var pip_color: Color = Tokens.BONE_PIP if body == Tokens.BONE_DIE else Tokens.CHALK_500
	_value_label.add_theme_color_override("font_color", pip_color)
	_value_label.modulate.a = 0.45 if _placed_in_slot >= 0 or _stolen else 1.0


static func _effect_glyph(face: Face) -> String:
	match face.effect:
		Rules.FaceEffectKind.APPLY_POISON:
			return "⬬ gift"
		Rules.FaceEffectKind.APPLY_BURN:
			return "▲ brand"
		Rules.FaceEffectKind.LIFESTEAL:
			return "✚ sug"
		Rules.FaceEffectKind.COPY_LEFT:
			return "❖ kopia"
		Rules.FaceEffectKind.ANVIL_SELF:
			return "⬣ dubbel"
		Rules.FaceEffectKind.GROW:
			return "↑ växer"
		Rules.FaceEffectKind.REFUND_REROLL:
			return "↻ omkast"
		Rules.FaceEffectKind.LOCKED:
			return "⬤ låst"
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
