class_name CorridorPrompt
extends PanelContainer
## Kritpanelen som ställer korridorens frågor: fällans två prislappar,
## bossdörrens enda tapp och altarets "ta den".
##
## [b]Båda prislapparna ritas före tappet[/b] (CORRIDOR_DESIGN §2.6, §6): en
## fälla får aldrig visa kostnaden efteråt. Panelen bär därför alltid hela
## texten på varje knapp, aldrig ett "?" och aldrig en bekräftelsedialog.
##
## Panelen äger ingen regel. Den visar det [CorridorMap] redan bestämt och
## skickar tillbaka ett index; [GameController] drar HP eller spräcker en sida.

signal chosen(index: int)

## Ligger i tumzonen, ovanför riktningsknapparna.
const BOTTOM_DP: int = 96

var _title: Label = null
var _body: Label = null
var _buttons: VBoxContainer = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box: StyleBoxFlat = Tokens.box(Tokens.CHALK_300, true, Tokens.STROKE_REG, Tokens.RADIUS_CARD)
	box.bg_color = Color(Tokens.SURFACE_PIT, 0.94)
	add_theme_stylebox_override("panel", box)

	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Tokens.dpi(Tokens.SPACE_3))
	add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))
	margin.add_child(column)

	_title = _label(Tokens.TYPE_HEADING, Tokens.CHALK_100)
	column.add_child(_title)

	_body = _label(Tokens.TYPE_BODY, Tokens.CHALK_300)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.clip_text = false
	column.add_child(_body)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))
	column.add_child(_buttons)


static func _label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", Tokens.dpi(font_size))
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
	return label


## [param options] är knapparnas etiketter, uppifrån och ner.
func show_prompt(title_text: String, body_text: String, options: PackedStringArray) -> void:
	_title.text = title_text
	_body.text = body_text
	_body.visible = body_text != ""
	for child: Node in _buttons.get_children():
		child.queue_free()
	for i: int in range(options.size()):
		var button: Button = Button.new()
		button.name = "Option%d" % i
		button.text = options[i]
		button.clip_text = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0.0, Tokens.dp(Tokens.BUTTON_PRIMARY_HEIGHT))
		button.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_LABEL))
		button.add_theme_color_override("font_color", Tokens.CHALK_100)
		var style: StyleBoxFlat = Tokens.box(Tokens.SURFACE_LINE, true, Tokens.STROKE_REG)
		style.bg_color = Tokens.SURFACE_RAISED
		for state: String in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, style)
		ChalkFx.apply(button, ChalkFx.BUTTON)
		button.pressed.connect(_pick.bind(i))
		_buttons.add_child(button)
	visible = true


func option_count() -> int:
	return _buttons.get_child_count()


## Trycker ett alternativ utan indata. Rökprovet och testerna använder den.
func press(index: int) -> void:
	_pick(index)


func _pick(index: int) -> void:
	Juice.ui_tap(1.05)
	Juice.haptic(Haptics.Level.MEDIUM)
	visible = false
	chosen.emit(index)
