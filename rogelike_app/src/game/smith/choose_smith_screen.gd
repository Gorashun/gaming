class_name ChooseSmithScreen
extends GameScreen
## Valet av kropp vid första start. DECISIONS 2026-09-21: [i]"Könsval för
## spelarfiguren: två kroppsvarianter av The Smith (samma 48×48-rutnät, alla
## utrustningslager passar båda), väljs vid första start och kan bytas i staden.
## Spelet omtalar figuren könsneutralt ('The Smith')."[/i]
##
## [b]Inga könsord i UI-texten.[/b] Rubriken frågar efter en kropp, inte efter
## ett kön, och alternativen har inga namn – bara två porträtt sida vid sida.
## Det är det enda som är både respektfullt och kort nog för en mobilskärm.
##
## [b]Porträttet är återanvändbart.[/b] [method portrait_frame] bygger samma
## ram som senare ska sitta uppe till vänster på character sheetet i
## first person-vyn (PM 2026-09-21), så att bytet inte kostar en ny komponent.

## Spelaren valde. [param variant] är "a" eller "b".
signal chosen(variant: String)

## Porträttets ruta i dp.
const PORTRAIT_SIZE: int = 132

@onready var _column: VBoxContainer = $Margin/Column

var _selected: String = ""
var _frames: Dictionary = {}


func enter(ctx: Dictionary) -> void:
	_selected = Art.smith_variant(String(ctx.get("variant", Settings.smith_variant)))
	$Background.color = Tokens.SURFACE_PIT
	for side: String in ["left", "right", "top", "bottom"]:
		$Margin.add_theme_constant_override("margin_" + side, Tokens.dpi(Tokens.SCREEN_MARGIN))
	_column.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_6))

	var title: Label = Label.new()
	title.text = Tokens.translate_or("SMITH_CHOOSE_TITLE", "CHOOSE YOUR SMITH")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_DISPLAY_L))
	title.add_theme_color_override("font_color", Tokens.CHALK_100)
	title.clip_text = true
	ChalkFx.apply(title, ChalkFx.DISPLAY)
	_column.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = Tokens.translate_or("SMITH_CHOOSE_SUB", "Looks only. Both swing the same hammer.")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_BODY_L))
	subtitle.add_theme_color_override("font_color", Tokens.CHALK_500)
	_column.add_child(subtitle)

	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_6))
	_column.add_child(row)
	for variant: String in Art.SMITH_VARIANTS:
		var frame: Control = portrait_frame(variant)
		frame.gui_input.connect(_on_portrait_input.bind(variant))
		row.add_child(frame)
		_frames[variant] = frame

	var note: Label = Label.new()
	note.text = Tokens.translate_or("SMITH_CHANGE_LATER", "You can change this whenever you like.")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_BODY))
	note.add_theme_color_override("font_color", Tokens.CHALK_500)
	_column.add_child(note)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column.add_child(spacer)

	var confirm: Button = Button.new()
	confirm.name = "ConfirmButton"
	confirm.text = Tokens.translate_or("SMITH_CHOOSE_CONFIRM", "THAT'S ME")
	confirm.clip_text = true
	confirm.custom_minimum_size = Vector2(0.0, Tokens.dp(Tokens.BUTTON_PRIMARY_HEIGHT + 8))
	confirm.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_TITLE))
	var primary: StyleBoxFlat = Tokens.box(Tokens.CHALK_100, true, Tokens.STROKE_REG)
	primary.bg_color = Tokens.CHALK_100
	for state_name: String in ["normal", "hover", "pressed", "focus"]:
		confirm.add_theme_stylebox_override(state_name, primary)
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		confirm.add_theme_color_override(color_name, Tokens.SURFACE_PIT)
	ChalkFx.apply(confirm, ChalkFx.BUTTON)
	confirm.pressed.connect(confirm_choice)
	_column.add_child(confirm)

	_refresh()


## Porträttrutan för en variant. Publik och statisk-liknande så att den går att
## återanvända i character sheetet: ram + porträttsprite, eller ram + en
## paperdoll-silhuett när PNG:n saknas (briefen: placeholder, aldrig krasch).
static func portrait_frame(variant: String) -> PanelContainer:
	var frame: PanelContainer = PanelContainer.new()
	frame.name = "Portrait_%s" % variant
	frame.custom_minimum_size = Vector2(Tokens.dp(PORTRAIT_SIZE), Tokens.dp(PORTRAIT_SIZE))
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.set_meta(&"variant", variant)

	var art: Control = Control.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(art)

	var texture: Texture2D = Art.smith_portrait(variant)
	if texture != null:
		var rect: TextureRect = TextureRect.new()
		rect.texture = texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# Porträttet är pixelkonst och ligger inuti krit-UI:t, som ärver Linear.
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.add_child(rect)
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		push_warning("Art: hero/smith_portrait_%s.png saknas – ritar platshållare" % variant)
		var label: Label = Label.new()
		label.text = variant.to_upper()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_DISPLAY_L))
		label.add_theme_color_override("font_color", Tokens.CHALK_500)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return frame


func _refresh() -> void:
	for variant: Variant in _frames:
		var frame: PanelContainer = _frames[variant] as PanelContainer
		var picked: bool = String(variant) == _selected
		var style: StyleBoxFlat = Tokens.box(
			Tokens.SEM_CHARGE if picked else Tokens.SURFACE_LINE,
			true,
			Tokens.STROKE_HEAVY if picked else Tokens.STROKE_REG,
			Tokens.RADIUS_CARD)
		frame.add_theme_stylebox_override("panel", style)


func _on_portrait_input(event: InputEvent, variant: String) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		select(variant)


## Väljer en variant utan att bekräfta. Publik så att testet och rökprovet kan
## trycka utan mus.
func select(variant: String) -> void:
	_selected = Art.smith_variant(variant)
	Juice.ui_tap(1.05)
	Juice.haptic(Haptics.Level.LIGHT)
	_refresh()


func selected() -> String:
	return _selected


## Sparar valet i [Settings] – inte i sparfilen: det ska överleva att en run tar
## slut och att sparfilen nollställs.
func confirm_choice() -> void:
	Juice.ui_tap(1.0)
	Juice.haptic(Haptics.Level.MEDIUM)
	Settings.set_value(&"smith_variant", _selected)
	chosen.emit(_selected)
	screen_done.emit({"variant": _selected})
