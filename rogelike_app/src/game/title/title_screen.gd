class_name TitleScreen
extends GameScreen
## Titelskärmen. Loggan i krita, och de två enda besluten som finns innan en run:
## fortsätt den du har, eller börja en ny.
##
## UI_GUIDE §3 och research 01 slutsats 5 ("mobil-vinnare är byggda för tummen"):
## knapparna ligger i tumzonen, CONTINUE är primär när det finns en sparfil och
## NEW RUN när det inte gör det. Ingen mellanmeny, ingen "är du säker" – det
## enda destruktiva valet (starta över trots sparfil) är sekundärt och skrivs ut.
##
## Texten går via [method Tokens.translate_or] av samma skäl som
## [SettingsScreen]: nycklarna finns ännu inte i CSV:n, som ligger under
## [code]assets/[/code] och ägs av UI-agenten i M2.

## Spelaren valde något. [code]action[/code] är "continue" eller "new".
signal title_action(action: String)

@onready var _logo: Label = $Margin/Column/Logo
@onready var _tagline: Label = $Margin/Column/Tagline
@onready var _seed_label: Label = $Margin/Column/SeedLabel
@onready var _buttons: VBoxContainer = $Margin/Column/Buttons

var _has_save: bool = false
## Har spelaren gått Grundstigen? Styr om titeln erbjuder tutorialen eller
## staden (TOWN_AND_ONBOARDING §B.2: våning 0 spelas exakt en gång).
var _tutorial_done: bool = false


func enter(ctx: Dictionary) -> void:
	_has_save = bool(ctx.get("has_save", SaveIO.has_save()))
	_tutorial_done = bool(ctx.get("tutorial_done", true))
	_style()
	_build_buttons()


func _style() -> void:
	$Background.color = Tokens.SURFACE_PIT
	for side: String in ["left", "right", "top", "bottom"]:
		$Margin.add_theme_constant_override("margin_" + side, Tokens.dpi(Tokens.SCREEN_MARGIN))
	$Margin/Column.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_6))
	_buttons.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_3))

	_logo.text = "PIPWRECK"
	Tokens.apply_type(_logo, Tokens.TYPE_DISPLAY_XL)
	_logo.add_theme_color_override("font_color", Tokens.CHALK_100)
	_logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_logo.clip_text = true
	# Loggan är kritans visitkort: full profil, inte den dämpade panelprofilen.
	ChalkFx.apply(_logo, ChalkFx.DISPLAY)

	_tagline.text = Tokens.translate_or("TITLE_TAGLINE", "Six dice. Five slots. One chain.")
	_tagline.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_BODY_L))
	_tagline.add_theme_color_override("font_color", Tokens.CHALK_500)
	_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_seed_label.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_CAPTION))
	_seed_label.add_theme_color_override("font_color", Tokens.CHALK_500)
	_seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seed_label.clip_text = true
	_seed_label.text = ""


func _build_buttons() -> void:
	for child: Node in _buttons.get_children():
		child.queue_free()
	if _has_save:
		_add_button(Tokens.translate_or("TITLE_CONTINUE", "CONTINUE"), true, func() -> void: _choose("continue"))
	if not _tutorial_done:
		# Första gången är primärknappen Grundstigen, inte en run. Att hoppa
		# över den är ett eget, utskrivet val – aldrig en gömd inställning.
		_add_button(Tokens.translate_or("TUT_FLOOR_NAME", "THE SHALLOW CUT"),
			not _has_save, func() -> void: _choose("tutorial"))
		_add_button(Tokens.translate_or("TUT_SKIP", "SKIP THE LESSON"),
			false, func() -> void: _choose("skip_tutorial"))
	else:
		_add_button(Tokens.translate_or("TOWN_NAME", "CHALKRIM"),
			not _has_save, func() -> void: _choose("town"))
	_add_button(Tokens.translate_or("TITLE_SETTINGS", "SETTINGS"), false, open_settings)


func _add_button(text: String, primary: bool, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.clip_text = true
	button.custom_minimum_size = Vector2(0.0, Tokens.dp(Tokens.BUTTON_PRIMARY_HEIGHT))
	button.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_HEADING))
	var style: StyleBoxFlat = Tokens.box(Tokens.CHALK_100, true, Tokens.STROKE_REG)
	var label_color: Color = Tokens.CHALK_100
	if primary:
		style.bg_color = Tokens.CHALK_100
		label_color = Tokens.SURFACE_PIT
	for state_name: String in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state_name, style)
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(color_name, label_color)
	ChalkFx.apply(button, ChalkFx.BUTTON)
	button.pressed.connect(action)
	_buttons.add_child(button)
	return button


func _choose(action: String) -> void:
	# Samma kritknack som kedjan använder, en oktav ned: titelskärmen lär ut
	# ljudspråket innan första tärningen ens är kastad (research 01 slutsats 2).
	Juice.ui_tap(1.0)
	Juice.haptic(Haptics.Level.LIGHT)
	title_action.emit(action)


func open_settings() -> void:
	Juice.ui_tap(1.0)
	if controller != null and controller.has_method("open_settings"):
		controller.call("open_settings")


## Rökprovet och testerna trycker på knappar utan mus.
func press(action: String) -> void:
	_choose(action)


func has_save() -> bool:
	return _has_save
