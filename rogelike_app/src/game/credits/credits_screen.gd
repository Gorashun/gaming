class_name CreditsScreen
extends Control
## Credits (M6 spår A steg 5). Nås från inställningarna, offline, utan konto.
##
## [b]Innehållet är data, inte kod.[/b] Konstens källor läses ur
## [code]assets/credits.json[/code] (asset-agentens fil): en rubrik per
## [code]sections[/code]-post och under den varje källa med sina
## [code]attribution_lines[/code] [b]ordagrant[/b] – för CC BY 3.0 är raderna ett
## licensvillkor, inte en artighet, och de översätts därför aldrig.
## Fonternas OFL-notiser står i [constant FONT_NOTICES]; den fullständiga
## licenstexten läses ur [code]assets/fonts/OFL-*.txt[/code] när filen finns.
##
## Skärmen är en modal ovanpå inställningarna, av samma skäl som de är en modal:
## den ska gå att öppna mitt i en run utan att något bakom den rivs.

signal closed()

const CREDITS_PATH: String = "res://assets/credits.json"
const KEY_TITLE: String = "CREDITS_TITLE"
const KEY_FONTS: String = "CREDITS_FONTS"
const KEY_FONTS_NOTE: String = "CREDITS_FONTS_NOTE"
const KEY_CLOSE: String = "SETTINGS_CLOSE"
const OFL_NAME: String = "SIL Open Font License, Version 1.1"
const OFL_URL: String = "https://openfontlicense.org"

## De fyra buntade fonterna (docs/ARCHITECTURE.md, "Typsnitt och symboler").
## Copyrightraden är ordagrant första raden i respektive OFL-fil.
const FONT_NOTICES: Array[Dictionary] = [
	{"name": "Anton", "license_file": "res://assets/fonts/OFL-anton.txt",
		"copyright": "Copyright 2020 The Anton Project Authors (https://github.com/googlefonts/AntonFont.git)"},
	{"name": "Caveat Brush", "license_file": "res://assets/fonts/OFL-caveat_brush.txt",
		"copyright": "Copyright 2015 Google Inc. All Rights Reserved."},
	{"name": "Familjen Grotesk", "license_file": "res://assets/fonts/OFL-familjen_grotesk.txt",
		"copyright": "Copyright 2021 The Familjen Grotesk Project Authors (https://github.com/Familjen-Sthlm/Familjen-Grotesk)"},
	{"name": "Noto Sans Symbols 2 (subset as pipwreck_symbols)", "license_file": "res://assets/fonts/OFL-pipwreck_symbols.txt",
		"copyright": "Copyright 2022 The Noto Project Authors (https://github.com/notofonts/symbols)"},
]

var _text: RichTextLabel = null
var _title: Label = null
var _close_button: Button = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	refresh()


func _build() -> void:
	var scrim: ColorRect = ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = Color(CorridorView.FOG_COLOR, 1.0)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Tokens.dpi(Tokens.SCREEN_MARGIN))
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_3))
	margin.add_child(column)

	_title = Label.new()
	_title.name = "Title"
	Tokens.apply_type(_title, Tokens.TYPE_DISPLAY_L)
	_title.add_theme_color_override("font_color", Tokens.CHALK_100)
	_title.clip_text = true
	column.add_child(_title)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_text = RichTextLabel.new()
	_text.name = "Text"
	_text.fit_content = true
	_text.scroll_active = false
	_text.bbcode_enabled = false
	_text.selection_enabled = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.mouse_filter = Control.MOUSE_FILTER_PASS
	_text.add_theme_color_override("default_color", Tokens.CHALK_300)
	_text.add_theme_font_size_override("normal_font_size", Tokens.dpi(Tokens.TYPE_CAPTION))
	scroll.add_child(_text)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.custom_minimum_size = Vector2(0.0, Tokens.dp(Tokens.BUTTON_PRIMARY_HEIGHT))
	_close_button.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_HEADING))
	var primary: StyleBoxFlat = Tokens.box(Tokens.CHALK_100, true, Tokens.STROKE_REG)
	primary.bg_color = Tokens.CHALK_100
	for state_name: String in ["normal", "hover", "pressed", "focus"]:
		_close_button.add_theme_stylebox_override(state_name, primary)
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		_close_button.add_theme_color_override(color_name, Tokens.SURFACE_PIT)
	_close_button.pressed.connect(close)
	column.add_child(_close_button)


## Läser credits-filen. JSON är en importerad resurs i Godot 4 och följer med i
## exporten; FileAccess är reserven för en fil som ännu inte importerats.
static func load_credits(path: String = CREDITS_PATH) -> Dictionary:
	if ResourceLoader.exists(path):
		var res: JSON = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as JSON
		if res != null and res.data is Dictionary:
			return res.data as Dictionary
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			return parsed as Dictionary
	push_warning("CreditsScreen: %s saknas eller är trasig – visar bara fonterna" % path)
	return {}


## Hela credits-texten som rader, i visningsordning: [code][{kind, text}][/code]
## där kind är [code]"section"[/code], [code]"name"[/code], [code]"line"[/code]
## eller [code]"gap"[/code]. Ren funktion, så testerna kan läsa den utan skärm.
static func build_lines(credits: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var sources: Array = credits.get("sources", []) as Array
	var sections: Array = credits.get("sections", []) as Array
	var placed: Dictionary = {}
	for raw_section: Variant in sections:
		var section: Dictionary = raw_section as Dictionary
		var section_id: String = String(section.get("id", ""))
		var members: Array = []
		for raw_source: Variant in sources:
			var source: Dictionary = raw_source as Dictionary
			if String(source.get("section", "")) == section_id:
				members.append(source)
		if members.is_empty():
			continue
		out.append({"kind": "section", "text": String(section.get("title", section_id))})
		for source: Variant in members:
			_append_source(out, source as Dictionary)
			placed[String((source as Dictionary).get("id", ""))] = true
	# En källa utan känd sektion får aldrig tappas bort: den står sist.
	var orphans: Array = []
	for raw_source: Variant in sources:
		var source: Dictionary = raw_source as Dictionary
		if not placed.has(String(source.get("id", ""))):
			orphans.append(source)
	if not orphans.is_empty():
		out.append({"kind": "section", "text": "ART"})
		for source: Variant in orphans:
			_append_source(out, source as Dictionary)
	return out


static func _append_source(out: Array[Dictionary], source: Dictionary) -> void:
	out.append({"kind": "name", "text": String(source.get("name", source.get("id", "")))})
	var lines: Array = source.get("attribution_lines", []) as Array
	if lines.is_empty():
		var fallback: String = "%s · %s" % [String(source.get("author", "")), String(source.get("license", ""))]
		out.append({"kind": "line", "text": fallback})
	for line: Variant in lines:
		out.append({"kind": "line", "text": String(line)})
	out.append({"kind": "gap", "text": ""})


## Fontnotiserna: namn, copyright, licensens namn och adress, och den fulla
## OFL-texten när filen går att läsa.
static func font_lines(include_full_text: bool = true) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for notice: Dictionary in FONT_NOTICES:
		out.append({"kind": "name", "text": String(notice["name"])})
		out.append({"kind": "line", "text": String(notice["copyright"])})
		out.append({"kind": "line", "text": "Licensed under the %s. %s" % [OFL_NAME, OFL_URL]})
		out.append({"kind": "gap", "text": ""})
	if include_full_text:
		var path: String = String(FONT_NOTICES[0]["license_file"])
		# Licenstexten är densamma för alla fyra; copyrightraderna ovan är
		# det som skiljer. Filen följer med i exporten bara om export-
		# filtret tar med den (docs/M6_A_NOTES.md), så den är ett tillägg.
		if FileAccess.file_exists(path):
			var full: String = FileAccess.get_file_as_string(path)
			var dash: int = full.find("-----")
			if dash >= 0:
				out.append({"kind": "line", "text": full.substr(dash).strip_edges()})
	return out


func refresh() -> void:
	_title.text = Tokens.translate_or(KEY_TITLE, "CREDITS")
	_close_button.text = Tokens.translate_or(KEY_CLOSE, "CLOSE")
	_text.clear()
	var lines: Array[Dictionary] = build_lines(load_credits())
	lines.append({"kind": "section", "text": Tokens.translate_or(KEY_FONTS, "FONTS")})
	lines.append({"kind": "line", "text": Tokens.translate_or(KEY_FONTS_NOTE,
		"All four typefaces are licensed under the SIL Open Font License 1.1.")})
	lines.append({"kind": "gap", "text": ""})
	lines.append_array(font_lines())
	for line: Dictionary in lines:
		_write(line)


func _write(line: Dictionary) -> void:
	var text: String = String(line["text"])
	match String(line["kind"]):
		"section":
			_text.push_font(Tokens.font_display())
			_text.push_font_size(Tokens.dpi(Tokens.TYPE_HEADING))
			_text.push_color(Tokens.SEM_CHARGE)
			_text.add_text(text)
			_text.pop()
			_text.pop()
			_text.pop()
			_text.newline()
		"name":
			_text.push_font(Tokens.font_ui_bold())
			_text.push_font_size(Tokens.dpi(Tokens.TYPE_BODY))
			_text.push_color(Tokens.CHALK_100)
			_text.add_text(text)
			_text.pop()
			_text.pop()
			_text.pop()
			_text.newline()
		"gap":
			_text.newline()
		_:
			_text.add_text(text)
			_text.newline()


## Texten som visas, utan formatering. För tester och rökprovet.
func shown_text() -> String:
	return _text.get_parsed_text() if _text != null else ""


func close() -> void:
	Juice.ui_tap(0.9)
	closed.emit()
	queue_free()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		close()
