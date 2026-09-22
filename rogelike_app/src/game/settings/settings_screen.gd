class_name SettingsScreen
extends Control
## Inställningar. Ligger som en MODAL ovanpå den skärm som är igång, inte som
## ett eget steg i skärmflödet.
##
## [b]Varför modal:[/b] den ska gå att öppna mitt i en runda (UI_GUIDE §6.4:
## ljud och haptik ska kunna stängas av när de stör, alltså just då de stör).
## Ett skärmbyte skulle riva stridsskärmen och kasta bort spelarens placering;
## en modal lämnar rundan orörd bakom sig.
##
## [b]Text:[/b] CLAUDE.md kräver engelska i källan via [code]tr()[/code] och
## svenska i CSV:n. Nycklarna nedan finns ännu INTE i
## [code]assets/i18n/translations.csv[/code] – den filen ligger under
## [code]assets/[/code] och ägs av UI-agenten, och dev får inte röra den i M2.
## Därför går varje sträng via [method Tokens.translate_or] med sin engelska
## källsträng som reserv: så fort raderna läggs in blir skärmen tvåspråkig utan
## en kodändring, och tills dess visas engelska i stället för en rå nyckel.
## Listan på nycklar som saknas står i ARCHITECTURE.md.

## Modalen är stängd.
signal closed()

const KEY_TITLE: String = "SETTINGS_TITLE"
const LOCALES: Array[String] = ["en", "sv"]
const LOCALE_NAMES: Array[String] = ["English", "Svenska"]

var _rows: VBoxContainer = null
var _panel: PanelContainer = null
var _title: Label = null
var _close_button: Button = null
var _reset_button: Button = null
var _reset_armed: bool = false
var _language_buttons: Array[Button] = []
var _volume_label: Label = null
## Byggda rader som ska få ny text när språket byts live.
var _retexters: Array[Callable] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_refresh_text()


func _build() -> void:
	var scrim: ColorRect = ColorRect.new()
	scrim.color = Tokens.SURFACE_SCRIM
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Tokens.dpi(Tokens.SCREEN_MARGIN))
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", Tokens.box(Tokens.SURFACE_LINE, true, Tokens.STROKE_REG))
	ChalkFx.apply(_panel, ChalkFx.PANEL)
	margin.add_child(_panel)

	var inner: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		inner.add_theme_constant_override("margin_" + side, Tokens.dpi(Tokens.SPACE_4))
	_panel.add_child(inner)

	_rows = VBoxContainer.new()
	# Centrerat: modalen fyller skärmen, men raderna ska ligga i tumzonen och
	# inte klistrade mot toppen (UI_GUIDE §2.9).
	_rows.alignment = BoxContainer.ALIGNMENT_CENTER
	_rows.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_3))
	inner.add_child(_rows)

	_title = Label.new()
	Tokens.apply_type(_title, Tokens.TYPE_TITLE)
	_title.add_theme_color_override("font_color", Tokens.CHALK_100)
	_title.clip_text = true
	ChalkFx.apply(_title, ChalkFx.DISPLAY)
	_rows.add_child(_title)

	_build_language_row()
	_build_volume_row()
	_build_toggle_row("SETTINGS_HAPTICS", "Haptics", &"haptics")
	_build_toggle_row("SETTINGS_REDUCED_MOTION", "Reduced motion", &"reduced_motion")
	_build_toggle_row("SETTINGS_HIGH_CONTRAST", "High contrast", &"high_contrast")
	_build_reset_row()

	_close_button = Button.new()
	_close_button.custom_minimum_size = Vector2(0.0, Tokens.dp(Tokens.BUTTON_PRIMARY_HEIGHT))
	_close_button.clip_text = true
	_close_button.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_HEADING))
	var primary: StyleBoxFlat = Tokens.box(Tokens.CHALK_100, true, Tokens.STROKE_REG)
	primary.bg_color = Tokens.CHALK_100
	for state_name: String in ["normal", "hover", "pressed", "focus"]:
		_close_button.add_theme_stylebox_override(state_name, primary)
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		_close_button.add_theme_color_override(color_name, Tokens.SURFACE_PIT)
	ChalkFx.apply(_close_button, ChalkFx.BUTTON)
	_close_button.pressed.connect(close)
	_rows.add_child(_close_button)


## En rubrikrad med en etikett till vänster och kontroller till höger.
func _row(label_key: String, fallback: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))
	var label: Label = Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_BODY_L))
	label.add_theme_color_override("font_color", Tokens.CHALK_300)
	row.add_child(label)
	_retexters.append(func() -> void: label.text = Tokens.translate_or(label_key, fallback))
	_rows.add_child(row)
	return row


func _build_language_row() -> void:
	var row: HBoxContainer = _row("SETTINGS_LANGUAGE", "Language")
	for i: int in range(LOCALES.size()):
		var button: Button = Button.new()
		button.text = LOCALE_NAMES[i]
		# Språknamnen är AVSIKTLIGT oöversatta: en spelare som hamnat i fel
		# språk måste kunna hitta sitt eget i listan (UI_GUIDE §6.3-andan).
		_style_small(button)
		var locale: String = LOCALES[i]
		button.pressed.connect(func() -> void: _set_locale(locale))
		row.add_child(button)
		_language_buttons.append(button)


func _build_volume_row() -> void:
	var row: HBoxContainer = _row("SETTINGS_SOUND", "Sound")
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 5.0
	slider.value = float(Settings.sfx_volume)
	slider.custom_minimum_size = Vector2(Tokens.dp(140), Tokens.dp(Tokens.TOUCH_MIN))
	slider.value_changed.connect(_on_volume_changed)
	row.add_child(slider)

	_volume_label = Label.new()
	_volume_label.custom_minimum_size.x = Tokens.dp(48)
	_volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_volume_label.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_BODY))
	_volume_label.add_theme_color_override("font_color", Tokens.CHALK_100)
	row.add_child(_volume_label)


func _build_toggle_row(label_key: String, fallback: String, key: StringName) -> void:
	var row: HBoxContainer = _row(label_key, fallback)
	var button: Button = Button.new()
	button.toggle_mode = true
	button.button_pressed = bool(Settings.get(String(key)))
	_style_small(button)
	button.custom_minimum_size.x = Tokens.dp(Tokens.TOUCH_MIN + 24)
	button.toggled.connect(func(value: bool) -> void: _on_toggled(key, value))
	row.add_child(button)
	# PÅ/AV står utskrivet på knappen: en färgad toggle utan text är precis den
	# "färg som ensam bärare" UI_GUIDE §6.2 förbjuder.
	_retexters.append(func() -> void:
		button.text = Tokens.translate_or("SETTINGS_ON", "ON") if button.button_pressed \
			else Tokens.translate_or("SETTINGS_OFF", "OFF"))


func _build_reset_row() -> void:
	var row: HBoxContainer = _row("SETTINGS_RESET", "Reset save")
	_reset_button = Button.new()
	_style_small(_reset_button)
	_reset_button.custom_minimum_size.x = Tokens.dp(Tokens.TOUCH_MIN + 60)
	_reset_button.add_theme_color_override("font_color", Tokens.SEM_BLOOD)
	_reset_button.pressed.connect(_on_reset_pressed)
	row.add_child(_reset_button)


static func _style_small(button: Button) -> void:
	button.clip_text = true
	button.custom_minimum_size = Vector2(Tokens.dp(Tokens.TOUCH_MIN + 40), Tokens.dp(Tokens.TOUCH_MIN))
	button.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_LABEL))
	button.add_theme_color_override("font_color", Tokens.CHALK_100)
	button.add_theme_color_override("font_hover_color", Tokens.CHALK_100)
	button.add_theme_color_override("font_pressed_color", Tokens.CHALK_100)
	var style: StyleBoxFlat = Tokens.box(Tokens.SURFACE_LINE, true, Tokens.STROKE_REG)
	for state_name: String in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state_name, style)
	ChalkFx.apply(button, ChalkFx.BUTTON)


# ---------------------------------------------------------------------------
# Handlingar
# ---------------------------------------------------------------------------

func _set_locale(locale: String) -> void:
	Juice.ui_tap(1.0)
	Settings.set_value(&"locale", locale)
	_refresh_text()


func _on_volume_changed(value: float) -> void:
	Settings.set_value(&"sfx_volume", int(value))
	_refresh_text()
	# Hör vad du ställer in: reglaget spelar sitt eget ljud vid den nya nivån.
	Juice.ui_tap(1.0)


func _on_toggled(key: StringName, value: bool) -> void:
	Settings.set_value(key, value)
	if key == &"high_contrast" or key == &"reduced_motion":
		# Båda ändrar hur UI:t RITAS. Modalen byggs om direkt så att bytet syns
		# i samma sekund; resten av skärmarna byggs om när de visas nästa gång.
		_rebuild()
		return
	_refresh_text()
	Juice.ui_tap(1.0)


func _on_reset_pressed() -> void:
	Juice.ui_tap(0.8)
	if not _reset_armed:
		# Bekräftelse utan dialogruta: knappen byter själv till "är du säker".
		# Ett steg, inget modalt lager till (UI_GUIDE §4.6-andan).
		_reset_armed = true
		_refresh_text()
		return
	SaveIO.clear()
	Settings.reset_to_defaults()
	_reset_armed = false
	_rebuild()


func close() -> void:
	Juice.ui_tap(0.9)
	closed.emit()
	queue_free()


func _rebuild() -> void:
	for child: Node in get_children():
		child.queue_free()
	_retexters.clear()
	_language_buttons.clear()
	_reset_button = null
	_volume_label = null
	_build()
	_refresh_text()


## Sätter om alla strängar. Anropas vid språkbyte, vilket är ett LIVE-byte:
## ingen omstart, ingen skärmladdning (PM:s M2-brief).
func _refresh_text() -> void:
	_title.text = Tokens.translate_or(KEY_TITLE, "Settings").to_upper()
	_close_button.text = Tokens.translate_or("SETTINGS_CLOSE", "CLOSE")
	if _volume_label != null:
		_volume_label.text = "%d" % Settings.sfx_volume
	if _reset_button != null:
		_reset_button.text = (
			Tokens.translate_or("SETTINGS_RESET_CONFIRM", "TAP AGAIN")
			if _reset_armed
			else Tokens.translate_or("SETTINGS_RESET_ACTION", "ERASE")
		)
	var current: String = Settings.locale if Settings.locale != "" else TranslationServer.get_locale().substr(0, 2)
	for i: int in range(_language_buttons.size()):
		var active: bool = LOCALES[i] == current
		_language_buttons[i].add_theme_color_override(
			"font_color", Tokens.SEM_CHARGE if active else Tokens.CHALK_500)
	for retexter: Callable in _retexters:
		retexter.call()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		close()
