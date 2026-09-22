class_name DirectionButtons
extends Control
## Tumzonens tre knappar (UI_GUIDE §17.4).
##
## Tre regler därifrån, alla normativa:
## [br]1. **Alltid på samma plats** i båda lägena. En knapp som flyttar sig är
##    värre än en som är grå.
## [br]2. Mitten (FORWARD) är 35 % bredare – den trycks tio gånger oftare.
## [br]3. Ogiltig riktning dimmas till 38 % men försvinner aldrig.
##
## Underetiketten upprepar skyltens ord, så valet går att göra utan att titta
## upp på skyltarna vid korsningen.

signal direction_pressed(action: String)

const HEIGHT_DP: int = 64
const CENTER_WIDTH_FACTOR: float = 1.35
const DISABLED_ALPHA: float = 0.38

## Glyferna är formkod, inte dekoration: en färgblind spelare ska kunna skilja
## de tre knapparna på form allena (UI_GUIDE §2.4-principen, tillämpad).
const GLYPHS: Dictionary = {
	CorridorMap.ACTION_LEFT: "◀",
	CorridorMap.ACTION_FORWARD: "▲",
	CorridorMap.ACTION_RIGHT: "▶",
}
const LABEL_KEYS: Dictionary = {
	CorridorMap.ACTION_LEFT: ["CORRIDOR_LEFT", "LEFT"],
	CorridorMap.ACTION_FORWARD: ["CORRIDOR_FORWARD", "FORWARD"],
	CorridorMap.ACTION_RIGHT: ["CORRIDOR_RIGHT", "RIGHT"],
}
## Skyltnyckel → knappens underetikett. Samma ord som på skylten (§2.3).
const SIGN_LABELS: Dictionary = {
	CorridorMap.SIGN_FIGHT: ["CORRIDOR_SIGN_FIGHT", "fight"],
	CorridorMap.SIGN_ELITE: ["CORRIDOR_SIGN_ELITE", "elite"],
	CorridorMap.SIGN_REST: ["CORRIDOR_SIGN_REST", "rest"],
	CorridorMap.SIGN_MARKET: ["CORRIDOR_SIGN_MARKET", "market"],
	CorridorMap.SIGN_FATE: ["CORRIDOR_SIGN_FATE", "fate roll"],
	CorridorMap.SIGN_UNKNOWN: ["CORRIDOR_SIGN_UNKNOWN", "unknown"],
	CorridorMap.SIGN_BOSS: ["CORRIDOR_SIGN_BOSS", "boss"],
	CorridorMap.SIGN_STAIRS: ["CORRIDOR_SIGN_STAIRS", "stairs up"],
}

var _buttons: Dictionary = {}
var _subtitles: Dictionary = {}
var _row: HBoxContainer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()


func _build() -> void:
	if _row != null:
		return
	_row = HBoxContainer.new()
	_row.name = "Row"
	_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	_row.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))
	add_child(_row)
	for action: String in [CorridorMap.ACTION_LEFT, CorridorMap.ACTION_FORWARD, CorridorMap.ACTION_RIGHT]:
		_row.add_child(_make_button(action))
	custom_minimum_size = Vector2(0.0, Tokens.dp(HEIGHT_DP))


func _make_button(action: String) -> Button:
	var button: Button = Button.new()
	button.name = action.capitalize()
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_stretch_ratio = CENTER_WIDTH_FACTOR if action == CorridorMap.ACTION_FORWARD else 1.0
	button.custom_minimum_size = Vector2(0.0, Tokens.dp(HEIGHT_DP))
	var style: StyleBoxFlat = Tokens.box(Tokens.SURFACE_LINE, true, Tokens.STROKE_REG)
	style.bg_color = Tokens.SURFACE_RAISED
	for state: String in ["normal", "hover", "focus"]:
		button.add_theme_stylebox_override(state, style)
	var pressed_style: StyleBoxFlat = Tokens.box(Tokens.CHALK_300, true, Tokens.STROKE_REG)
	pressed_style.bg_color = Tokens.SURFACE_SLATE
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("disabled", style)
	button.pressed.connect(func() -> void: direction_pressed.emit(action))

	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	button.add_child(column)

	var title: Label = Label.new()
	title.name = "Title"
	title.text = "%s %s" % [GLYPHS[action], Tokens.translate_or(LABEL_KEYS[action][0], LABEL_KEYS[action][1])]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_LABEL))
	title.add_theme_color_override("font_color", Tokens.CHALK_100)
	column.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.name = "Subtitle"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_CAPTION))
	subtitle.add_theme_color_override("font_color", Tokens.CHALK_500)
	subtitle.clip_text = true
	column.add_child(subtitle)

	_buttons[action] = button
	_subtitles[action] = subtitle
	return button


## Speglar [method CorridorMap.available_actions]. Ogiltiga riktningar dimmas,
## aldrig göms.
func set_actions(actions: Dictionary) -> void:
	_build()
	for action: Variant in _buttons:
		var button: Button = _buttons[action]
		var subtitle: Label = _subtitles[action]
		var info: Dictionary = actions.get(action, {}) as Dictionary
		var available: bool = not info.is_empty()
		button.disabled = not available
		button.modulate = Color(1.0, 1.0, 1.0, 1.0 if available else DISABLED_ALPHA)
		subtitle.text = sign_label(String(info.get("sign", ""))) if available else ""


func set_all_disabled(disabled: bool) -> void:
	_build()
	for action: Variant in _buttons:
		(_buttons[action] as Button).disabled = disabled


static func sign_label(sign_key: String) -> String:
	if not SIGN_LABELS.has(sign_key):
		return ""
	var row: Array = SIGN_LABELS[sign_key]
	return Tokens.translate_or(String(row[0]), String(row[1]))
