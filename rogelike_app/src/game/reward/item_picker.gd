class_name ItemPicker
extends PanelContainer
## Kritpanelen där spelaren väljer föremål ur det hen bär: trappbanken ("skicka
## upp med kärran") och Marrows räddning vid död (Kistan). PROGRESSION_REDESIGN
## §3.4.
##
## [b]Panelen äger ingen regel.[/b] Den visar föremål och ett tak, och skickar
## tillbaka index. [Expedition] bestämmer vad som banas eller räddas. Enkel
## torg-panelstil (M6 steg 4); dev A snyggar senare (docs/M6_B_NOTES.md).

signal confirmed(indices: Array)
## Sekundärknappen: "behåll allt" vid trappan, räddningsannonsen vid död.
signal secondary_pressed()

var _title: Label = null
var _body: Label = null
var _list: VBoxContainer = null
var _confirm: Button = null
var _secondary: Button = null
var _items: Array[Item] = []
var _selected: Array[int] = []
var _max_select: int = 0
var _confirm_format: Array = ["", ""]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box: StyleBoxFlat = Tokens.box(Tokens.CHALK_300, true, Tokens.STROKE_REG, Tokens.RADIUS_CARD)
	box.bg_color = Color(Tokens.SURFACE_PIT, 0.96)
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

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0.0, Tokens.dp(96))
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_1))
	scroll.add_child(_list)

	_secondary = _button(Tokens.CHALK_300)
	_secondary.pressed.connect(func() -> void: secondary_pressed.emit())
	column.add_child(_secondary)
	_confirm = _button(Tokens.CHALK_100)
	_confirm.pressed.connect(confirm)
	column.add_child(_confirm)


static func _label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", Tokens.dpi(font_size))
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
	return label


static func _button(color: Color) -> Button:
	var button: Button = Button.new()
	button.clip_text = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0.0, Tokens.dp(Tokens.BUTTON_SECONDARY_HEIGHT))
	button.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_LABEL))
	button.add_theme_color_override("font_color", color)
	var style: StyleBoxFlat = Tokens.box(Tokens.SURFACE_LINE, true, Tokens.STROKE_REG)
	style.bg_color = Tokens.SURFACE_RAISED
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, style)
	return button


## [param confirm_format] är [code][nyckel, engelsk källsträng][/code] med ett
## [code]%d[/code] för antalet valda. [param secondary] är [code][nyckel, en][/code]
## eller tom för ingen sekundärknapp.
func open(title: Array, body: String, items: Array[Item], max_select: int,
		confirm_format: Array, secondary: Array = []) -> void:
	_title.text = Tokens.translate_or(String(title[0]), String(title[1]))
	_body.text = body
	_body.visible = body != ""
	_items = items
	_selected.clear()
	_max_select = maxi(0, max_select)
	_confirm_format = confirm_format
	_secondary.visible = secondary.size() >= 2
	if _secondary.visible:
		_secondary.text = Tokens.translate_or(String(secondary[0]), String(secondary[1]))
	_rebuild()
	visible = true


func set_max(max_select: int) -> void:
	_max_select = maxi(0, max_select)
	while _selected.size() > _max_select:
		_selected.pop_back()
	_rebuild()


func set_secondary_enabled(enabled: bool) -> void:
	_secondary.disabled = not enabled


func max_select() -> int:
	return _max_select


func item_count() -> int:
	return _items.size()


func selected() -> Array[int]:
	return _selected.duplicate()


## Väljer eller avväljer rad [param index]. Rökprovet och testerna använder den.
func toggle(index: int) -> void:
	if index < 0 or index >= _items.size():
		return
	if _selected.has(index):
		_selected.erase(index)
	elif _selected.size() < _max_select:
		_selected.append(index)
	_rebuild()


func confirm() -> void:
	Juice.ui_tap(1.05)
	Juice.haptic(Haptics.Level.MEDIUM)
	visible = false
	confirmed.emit(_selected.duplicate())


func _rebuild() -> void:
	for child: Node in _list.get_children():
		child.queue_free()
	for i: int in range(_items.size()):
		var item: Item = _items[i]
		var row: Button = _button(Tokens.rarity_color(item.rarity))
		row.name = "Item%d" % i
		row.toggle_mode = true
		row.button_pressed = _selected.has(i)
		row.custom_minimum_size = Vector2(0.0, Tokens.dp(Tokens.TOUCH_MIN))
		row.text = "%s %s — %s" % [
			"[x]" if _selected.has(i) else "[ ]",
			Tokens.translate_or(item.name_key, item.display_name),
			Tokens.translate_or(item.effect_summary_key, ""),
		]
		row.pressed.connect(toggle.bind(i))
		_list.add_child(row)
	_confirm.text = Tokens.translate_or(String(_confirm_format[0]), String(_confirm_format[1])) % _selected.size()
