extends GdUnitTestSuite
## Typsnitten i [code]assets/fonts/[/code] och löftet att ingen spelartext
## hänger på en systemfont.
##
## [b]Buggen testet finns för[/b] (docs/BACKLOG.md, webbverifieringen
## 2026-09-22): projektet hade ingen egen font. Godot ritade allt med sin
## inbyggda och hämtade tecken den saknade – [code]◀ ▲ ▶ ◫ ⚙[/code] – ur
## [b]systemfonten[/b] via TextServerns OS-fallback. Det fungerade på Linux och
## Android. Webbexporten har ingen systemfont: där blev samma tecken tomma
## rutor. Skillnaden syns mellan [code]docs/screenshots/m5/gl_02_junction.png[/code]
## och [code]docs/screenshots/web_verify/corridor.png[/code].
##
## Fixen är tvådelad och testet bevakar båda delarna:
## [br]1. Fyra OFL-filer ligger i [code]assets/fonts/[/code] och
##    [code]ui_regular.tres[/code] är projektets standardfont. Tre av dem är
##    orörda originalfiler; symbolfallbacken är en Modified Version där bara de
##    vertikala metrikerna skalats om (tools/make_symbol_font.py).
## [br]2. [b]Varje tecken spelet kan rita finns i en buntad font.[/b] Det som
##    ingen av dem har (kugghjul, svärd, ångra-pil, riktningspilar) ritas som
##    16×16-sprite i stället, aldrig som text.
##
## Testet läser samma källor som spelet: CSV:n, [Tokens]:s tabeller och
## [Art]:s reservglyfer. En ny rad med en oritbar symbol fäller bygget samma
## sekund den committas.

const CSV_PATH: String = "res://assets/i18n/translations.csv"
const FONT_FILES: Array[String] = [
	"res://assets/fonts/familjen_grotesk_variable.ttf",
	"res://assets/fonts/anton_regular.ttf",
	"res://assets/fonts/caveat_brush_regular.ttf",
	"res://assets/fonts/pipwreck_symbols.ttf",
]
const LICENSE_FILES: Array[String] = [
	"res://assets/fonts/OFL-familjen_grotesk.txt",
	"res://assets/fonts/OFL-anton.txt",
	"res://assets/fonts/OFL-caveat_brush.txt",
	"res://assets/fonts/OFL-pipwreck_symbols.txt",
]
## Tecken som INGEN buntad font har. De fick aldrig stå i spelartext igen – de
## är exakt de som blev tofu på web. Motsvarande 16×16-sprites finns i
## [constant Art.UI_ICONS].
const BANNED: Array[String] = ["⚙", "⚔", "↩", "↳", "↻", "①", "卌", "⛭", "↔"]


# --- 1. Filerna finns och är projektets font -------------------------------

func test_every_bundled_font_loads() -> void:
	for path: String in FONT_FILES:
		var font: Font = ResourceLoader.load(path) as Font
		assert_object(font).override_failure_message(
			"fontfilen %s gick inte att ladda" % path).is_not_null()


func test_every_bundled_font_ships_its_ofl_licence() -> void:
	for path: String in LICENSE_FILES:
		assert_bool(FileAccess.file_exists(path)).override_failure_message(
			"OFL-texten %s saknas – en buntad font utan licensfil får inte gå i en build" % path
		).is_true()


func test_the_project_default_font_is_familjen_grotesk() -> void:
	var setting: String = String(ProjectSettings.get_setting("gui/theme/custom_font", ""))
	assert_str(setting).override_failure_message(
		"gui/theme/custom_font pekar på '%s', inte på UI-fonten" % setting
	).is_equal(Tokens.FONT_UI_PATH)
	assert_object(ThemeDB.get_fallback_font()).is_not_null()


func test_the_ui_font_carries_the_symbol_fallback() -> void:
	var font: Font = Tokens.font_ui()
	assert_object(font).is_not_null()
	assert_int(font.fallbacks.size()).override_failure_message(
		"ui_regular.tres har ingen fallback – formkoderna i §2.3–2.5 blir tofu"
	).is_greater(0)


## [b]Regressionen som fällde M5.5-layouten:[/b] Godot storlekssätter en [Label]
## ur [method Font.get_height], som är [b]maximum[/b] över hela fallbackkedjan.
## Noto Sans Symbols 2 deklarerar en 1,70 em radlåda mot Familjen Grotesks 1,25
## em, och orörd gjorde den varje etikett 36 % högre – stridsskärmen växte 127 px
## förbi tumzonen. [code]tools/make_symbol_font.py[/code] skalar om metrikerna;
## det här testet är varför skriptet finns.
func test_the_symbol_fallback_does_not_inflate_the_line_box() -> void:
	var ui: Font = Tokens.font_ui()
	var base: Font = ResourceLoader.load(
		"res://assets/fonts/familjen_grotesk_variable.ttf") as Font
	assert_object(base).is_not_null()
	for token: int in [Tokens.TYPE_CAPTION, Tokens.TYPE_BODY, Tokens.TYPE_TITLE, Tokens.TYPE_DISPLAY_XL]:
		var size: int = Tokens.dpi(token)
		assert_float(ui.get_height(size)).override_failure_message(
			"UI-fonten är %.0f px hög i %d px men Familjen Grotesk ensam är %.0f – fallbacken blåser upp layouten"
			% [ui.get_height(size), size, base.get_height(size)]
		).is_less_equal(base.get_height(size) + 1.0)


# --- 2. Ingen text hänger på en systemfont ---------------------------------

func test_every_character_in_the_translations_has_a_glyph() -> void:
	var font: Font = Tokens.font_ui()
	var missing: PackedStringArray = PackedStringArray()
	for line: String in _csv_lines():
		for i: int in line.length():
			var code: int = line.unicode_at(i)
			if code > 127 and not font.has_char(code):
				var hit: String = "%s (U+%04X)" % [line[i], code]
				if not missing.has(hit):
					missing.append(hit)
	assert_array(Array(missing)).override_failure_message(
		"tecken i translations.csv som ingen buntad font har: %s" % ", ".join(missing)
	).is_empty()


func test_every_fallback_glyph_in_art_has_a_glyph() -> void:
	_assert_drawable(Art.UI_ICON_GLYPHS.values(), "Art.UI_ICON_GLYPHS")


func test_every_slot_and_rarity_mark_has_a_glyph() -> void:
	var marks: Array = []
	for slot_type: Variant in Tokens.SLOT_STYLE_SPEC:
		marks.append((Tokens.SLOT_STYLE_SPEC[slot_type] as Dictionary)["icon"])
	for rarity: Variant in Tokens.RARITY_STYLE_SPEC:
		marks.append((Tokens.RARITY_STYLE_SPEC[rarity] as Dictionary)["mark"])
	marks.append(CombatScreen.HP_MARK)
	marks.append(TownScreen.TALLY_GROUP)
	_assert_drawable(marks, "formkoderna i UI_GUIDE §2.4–2.5")


func test_the_glyphs_that_only_the_system_font_had_are_gone_from_the_source() -> void:
	var font: Font = Tokens.font_ui()
	for glyph: String in BANNED:
		assert_bool(font.has_char(glyph.unicode_at(0))).override_failure_message(
			"%s finns numera i en buntad font – flytta den ur BANNED" % glyph).is_false()
	var offenders: PackedStringArray = PackedStringArray()
	for line: String in _csv_lines():
		for glyph: String in BANNED:
			if line.contains(glyph):
				offenders.append("%s: %s" % [glyph, line.substr(0, 40)])
	assert_array(Array(offenders)).override_failure_message(
		"systemfont-glyfer tillbaka i translations.csv: %s" % ", ".join(offenders)
	).is_empty()


# --- 3. Sprites som ersatte glyferna ---------------------------------------

func test_the_icons_that_replaced_the_glyphs_exist() -> void:
	var missing: PackedStringArray = PackedStringArray()
	for icon_name: StringName in [
		&"arrow_left", &"arrow_forward", &"arrow_right",
		&"sheet", &"settings", &"undo", &"armor", &"attack", &"charge", &"help",
	]:
		if Art.ui_icon(icon_name) == null:
			missing.append(String(icon_name))
	assert_array(Array(missing)).override_failure_message(
		"ikoner som UI:t räknar med saknas: %s" % ", ".join(missing)).is_empty()


func test_the_icons_are_painted_chalk_from_the_manifest() -> void:
	# M7: inga 16×16-pixelsprites i UI:t längre. Varje ikon är 256 px krita ur
	# manifestet och skalas fritt (Lanczos) till sin dp-storlek.
	for icon_name: StringName in Art.UI_ICONS:
		var info: Dictionary = Art.art_info(StringName(Art.UI_ICON_PREFIX + String(icon_name)))
		assert_str(String(info["source"])).override_failure_message(
			"%s kommer inte ur manifestet" % icon_name).is_equal(Art.SOURCE_MANIFEST)
		assert_bool(bool(info["pixel"])).is_false()
		var tex: Texture2D = info["texture"] as Texture2D
		assert_int(tex.get_width()).is_equal(256)
		assert_int(tex.get_height()).is_equal(256)


func test_icon_sizes_follow_dp_without_integer_steps() -> void:
	# M7: ingen heltalsskala. 16 dp → 48 px, 14 dp → 42 px (inte 32).
	assert_int(Art.icon_px(Art.ICON_DP)).is_equal(Tokens.dpi(Art.ICON_DP))
	assert_int(Art.icon_px(14)).is_equal(Tokens.dpi(14))
	assert_int(Art.icon_px(0)).is_equal(1)
	var scaled: Texture2D = Art.scaled_ui_icon(&"settings", 14)
	assert_int(scaled.get_width()).is_equal(Tokens.dpi(14))


# --- Hjälpare --------------------------------------------------------------

func _assert_drawable(values: Array, source: String) -> void:
	var font: Font = Tokens.font_ui()
	var missing: PackedStringArray = PackedStringArray()
	for value: Variant in values:
		var text: String = String(value)
		for i: int in text.length():
			var code: int = text.unicode_at(i)
			if code > 127 and not font.has_char(code):
				missing.append("%s (U+%04X)" % [text[i], code])
	assert_array(Array(missing)).override_failure_message(
		"%s innehåller tecken som ingen buntad font har: %s" % [source, ", ".join(missing)]
	).is_empty()


func _csv_lines() -> PackedStringArray:
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	assert_object(file).override_failure_message("%s saknas" % CSV_PATH).is_not_null()
	var lines: PackedStringArray = PackedStringArray()
	while not file.eof_reached():
		var line: String = file.get_line()
		if line != "":
			lines.append(line)
	file.close()
	return lines
