class_name DieView
extends Control
## En plats i tärningsbrickan. UI_GUIDE §2.9 och [b]COMBAT_READABILITY §4[/b].
##
## [b]M2.5: brickan är en sann modell av verkligheten.[/b] Diagnosen i §1.5 var
## att samma tärning låg synlig både i sloten och i brickan, med etiketten
## [code]IN 3[/code] som läses som "om 3 rundor". Nu gäller en tillståndsmaskin
## där [b]platsen är tom när tärningen ligger på brädet[/b]:
##
## [codeblock]
## READY     full tärning, full opacitet        (ingen etikett – värdet syns)
## SELECTED  lyft 6 dp, gyllene kontur          "TAP A SLOT"
## PLACED    tom sockel: streckad ram, uppåtpil "SLOT 4"
## LOCKED    tärning + kedjeglyf                "LOCKED"
## STOLEN    trasig sockel, ingen silhuett      "STOLEN"
## CRACKED   tärning + spricka, värdet 0        "CRACKED"
## [/codeblock]
##
## Interaktion (UI_GUIDE §4.1/§4.2, båda alltid aktiva): drag lämnar över
## [code]{die_index}[/code]; tapp markerar, och tapp på en tom sockel tar
## tillbaka tärningen till brickan (§4: "tapp på sockeln är i dag odefinierat").

## Spelaren tappade platsen.
signal tapped(die_index: int)

const STATE_READY: int = 0
const STATE_SELECTED: int = 1
const STATE_PLACED: int = 2
const STATE_LOCKED: int = 3
const STATE_STOLEN: int = 4
const STATE_CRACKED: int = 5

## Lyftet på en vald tärning, i dp (§4).
const SELECT_LIFT: int = 6
## Spöksilhuettens opacitet i en tom sockel (§9: "die_body_*.png med 16 % alpha").
const GHOST_ALPHA: float = 0.16

var die_index: int = -1
var _die: Die = null
var _placed_in_slot: int = -1
var _selected: bool = false
var _locked: bool = false
var _stolen: bool = false
var _tray_ext: bool = true

var _panel: Panel = null
var _art: DieArt = null
var _arrow: Label = null
var _value_label: Label = null
var _effect_label: Label = null
var _state_label: Label = null


func _init() -> void:
	# Minsta bredd, inte önskad bredd: sex tärningar ska rymmas på 360 dp
	# (UI_GUIDE §8 mätte 49,7 dp på den smalaste målskärmen).
	custom_minimum_size = Vector2(Tokens.dp(Tokens.DIE_MIN_WIDTH), Tokens.dp(Tokens.DIE_MIN_WIDTH))
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	_art = DieArt.new()
	_art.name = "Art"
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_art)

	# Uppåtpilen i den tomma sockeln. En ren glyf, ingen sprite behövs (§9).
	_arrow = Label.new()
	_arrow.name = "Arrow"
	_arrow.text = "↑"
	_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_arrow.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_TITLE))
	_arrow.add_theme_color_override("font_color", Tokens.CHALK_500)
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.visible = false
	add_child(_arrow)
	_arrow.set_anchors_preset(Control.PRESET_FULL_RECT)

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
	_state_label.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_CAPTION - 2))
	_state_label.add_theme_color_override("font_color", Tokens.CHALK_500)
	_state_label.clip_text = true
	_state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_state_label)


func art_root() -> Control:
	return _art


## Aktiveringspuls på den RIKTIGA tärningssprajten (UI_GUIDE §5.1).
func pulse_art(duration: float = Tokens.MOTION_BASE) -> void:
	if _art != null and _art.is_drawing():
		_art.flash(0.75, duration)
	Juice.pulse(self, 1.14, duration)


## Brickans utökade tillstånd (tomma socklar med slotnummer) döljs tills
## [code]tray_ext[/code] avslöjats; dessförinnan ligger tärningen kvar synlig
## som i M2, vilket är enklare att förstå i rum 0.1.
func set_tray_extended(value: bool) -> void:
	_tray_ext = value


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


## Tillståndet som en av [code]STATE_*[/code]. Ren funktion av fälten, så att
## tillståndsmaskinen i §4 går att testa utan en scen.
func state() -> int:
	if _stolen:
		return STATE_STOLEN
	if _placed_in_slot >= 0:
		return STATE_PLACED
	if _die != null and _die.showing_face() != null and _die.showing_face().id == Resolver.CRACKED_FACE_ID:
		return STATE_CRACKED
	if _locked:
		return STATE_LOCKED
	if _selected:
		return STATE_SELECTED
	return STATE_READY


func _refresh(face: Face) -> void:
	var current: int = state()
	var socket: bool = current == STATE_PLACED and _tray_ext

	if _art != null:
		# Sprickvarianten seedas på tärningens id: samma tärning har samma
		# spricka hela runnen, men ingen slump dras ur Rng-strömmen.
		_art.show_die(_die, hash(_die.id) if _die != null else 0)
		_art.visible = _die != null and not (socket and not _art.is_drawing())
	_arrow.visible = socket

	if face == null:
		_value_label.text = "–"
		_effect_label.text = ""
		_state_label.text = tr("DIE_MISSING")
		_panel.add_theme_stylebox_override("panel", Tokens.box(Tokens.SURFACE_LINE, true, Tokens.STROKE_HAIR, Tokens.RADIUS_DIE))
		return

	_value_label.text = str(face.value)
	# Ritas sidan som ögon bär konsten värdet och siffran vore dubbelt. Ritas
	# den som glyph (gift, eld, blod, tomrum) står värdet i effektraden.
	var art_has_value: bool = _art != null and _art.shows_value()
	_value_label.visible = not art_has_value and not socket
	_effect_label.text = _effect_label_text(face, not art_has_value)
	_effect_label.add_theme_color_override("font_color", _effect_color(face))
	_effect_label.visible = not socket

	var body: Color = Tokens.BONE_DIE
	var border: Color = Tokens.CHALK_300
	var width: float = Tokens.STROKE_REG
	match current:
		STATE_STOLEN:
			_state_label.text = Tokens.translate_or("COMBAT_TRAY_STOLEN", "STOLEN")
			body = Tokens.SURFACE_LINE
			border = Tokens.SEM_BLOOD
		STATE_PLACED:
			# Tom sockel med SLOTNUMMER: "den här tärningen ligger på slot 4".
			_state_label.text = Tokens.translate_or("COMBAT_TRAY_PLACED", "SLOT %d") % (_placed_in_slot + 1) \
				if _tray_ext else tr("DIE_IN_SLOT") % (_placed_in_slot + 1)
			body = Tokens.SURFACE_SLATE
			border = Tokens.SURFACE_LINE
		STATE_LOCKED:
			_state_label.text = Tokens.translate_or("COMBAT_TRAY_LOCKED", "LOCKED")
			border = Tokens.SEM_CHARGE
		STATE_CRACKED:
			_state_label.text = Tokens.translate_or("COMBAT_TRAY_CRACKED", "CRACKED")
			border = Tokens.SEM_BLOOD
		STATE_SELECTED:
			_state_label.text = Tokens.translate_or("COMBAT_TRAY_SELECTED", "TAP A SLOT")
			border = Tokens.SEM_CHARGE
			width = Tokens.STROKE_BOLD
		_:
			# READY bär ingen etikett alls: värdet läses på tärningen (§4).
			_state_label.text = ""

	var style: StyleBoxFlat = Tokens.box(border, true, width, Tokens.RADIUS_DIE)
	style.bg_color = Tokens.SURFACE_SLATE if (_art != null and _art.is_drawing()) else body
	if socket:
		style.bg_color = Tokens.SURFACE_PIT
	_panel.add_theme_stylebox_override("panel", style)

	var pip_color: Color = Tokens.BONE_PIP if body == Tokens.BONE_DIE else Tokens.CHALK_500
	_value_label.add_theme_color_override("font_color", pip_color)
	_value_label.modulate.a = 0.45 if current == STATE_PLACED or _stolen else 1.0
	if _art != null:
		# Spöksilhuett i sockeln, full tärning annars.
		_art.modulate.a = GHOST_ALPHA if socket else (0.5 if current == STATE_PLACED or _stolen else 1.0)

	# SELECTED lyfts 6 dp. Reducerad rörelse lyfter också – det är ett statiskt
	# offset, inte en animation, och tillståndet måste synas (UI_GUIDE §6.1).
	position.y = -Tokens.dp(SELECT_LIFT) if current == STATE_SELECTED else 0.0


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
	Juice.ui_tap(1.1)

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
