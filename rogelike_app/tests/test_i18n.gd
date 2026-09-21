extends GdUnitTestSuite
## Översättningsregistret. CLAUDE.md: [b]all spelartext är engelska i källan och
## går via [code]tr()[/code][[/b]; svenskan är en rad i
## [code]assets/i18n/translations.csv[/code], aldrig en hårdkodad sträng.
##
## Testet är en regelvakt, inte en textgranskning. Det gör tre saker:
## [br]1. CSV:n är välformad – rätt rubrik, tre kolumner, inga dubbletter, och
##    [b]både en och sv ifyllda[/b] på varje rad. En tom svensk cell skulle bli
##    en engelsk sträng mitt i ett svenskt UI, vilket ingen upptäcker förrän en
##    spelare gör det.
## [br]2. Varje nyckel som källkoden faktiskt slår upp finns i CSV:n. Filerna
##    skannas med [RegEx], så en ny [code]tr("FOO")[/code] utan CSV-rad fäller
##    bygget samma sekund den committas.
## [br]3. Varje innehålls-id i [Content] har en nyckel. Innehåll läggs till som
##    data och får aldrig glida ifrån översättningen.

const CSV_PATH: String = "res://assets/i18n/translations.csv"
## Kolumnordningen i CSV:n. "keys" är Godots obligatoriska rubrik för
## csv_translation-importen.
const COLUMNS: Array[String] = ["keys", "en", "sv"]
## Katalogerna som skannas efter nyckeluppslag.
const SOURCE_DIRS: Array[String] = ["res://src/game", "res://src/data", "res://src/core"]
## Fångar tr("KEY"), Tokens.translate("KEY"), TranslationServer.translate("KEY")
## och reward_apply._t("KEY"). Bara literala nycklar – dynamiska nycklar
## (tr(Content.enemy_key(id))) täcks i stället av innehållstestet nedan.
const KEY_PATTERN: String = "\\b(?:tr|translate|_t)\\(\\s*\"([A-Z][A-Z0-9_]*)\"\\s*\\)"


# --- 1. CSV:ns form --------------------------------------------------------

func test_the_csv_has_the_expected_header() -> void:
	var rows: Array[PackedStringArray] = _read_csv()
	assert_int(rows.size()).override_failure_message(
		"%s är tom eller saknas" % CSV_PATH).is_greater(1)
	assert_array(Array(rows[0])).is_equal(COLUMNS)


func test_every_row_has_both_english_and_swedish() -> void:
	var rows: Array[PackedStringArray] = _read_csv()
	for i: int in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		assert_int(row.size()).override_failure_message(
			"rad %d har %d kolumner, inte %d: %s" % [i + 1, row.size(), COLUMNS.size(), ", ".join(row)]
		).is_equal(COLUMNS.size())
		for column: int in range(COLUMNS.size()):
			assert_str(row[column].strip_edges()).override_failure_message(
				"rad %d (%s) har tom kolumn %s" % [i + 1, row[0], COLUMNS[column]]
			).is_not_empty()


func test_no_key_appears_twice() -> void:
	var seen: Dictionary = {}
	var duplicates: PackedStringArray = PackedStringArray()
	var rows: Array[PackedStringArray] = _read_csv()
	for i: int in range(1, rows.size()):
		var key: String = rows[i][0]
		if seen.has(key):
			duplicates.append(key)
		seen[key] = true
	assert_array(Array(duplicates)).override_failure_message(
		"dubblerade nycklar: %s" % ", ".join(duplicates)).is_empty()


# --- 2. Koden slår bara upp nycklar som finns ------------------------------

func test_every_key_used_in_the_source_exists_in_the_csv() -> void:
	var table: Dictionary = _csv_table()
	var used: Dictionary = _keys_used_in_source()
	assert_int(used.size()).override_failure_message(
		"regexen hittade inga nycklar alls – skanningen är trasig, inte koden"
	).is_greater(40)

	var missing: PackedStringArray = PackedStringArray()
	for key: String in used:
		if not table.has(key):
			missing.append("%s (%s)" % [key, String(used[key])])
	missing.sort()
	assert_array(Array(missing)).override_failure_message(
		"nycklar som koden slår upp men som saknas i %s:\n  %s" % [CSV_PATH, "\n  ".join(missing)]
	).is_empty()


# --- 3. Innehållet har nycklar ---------------------------------------------

func test_every_content_id_has_a_translation_key() -> void:
	var table: Dictionary = _csv_table()
	var expected: PackedStringArray = PackedStringArray()
	for id: String in Content.FORGEABLE_FACES:
		expected.append(Content.face_key(id))
	for id: String in Content.RELICS:
		expected.append(Content.relic_key(id))
	for id: String in Content.SLOT_SWAPS:
		expected.append(Content.slot_swap_key(id))
	for id: String in Content.CLASSES:
		expected.append(Content.class_key(id))
	for id: String in ["RUST_RAT", "SLAG_MOTH", "THORN_IMP", "PIP_THIEF", "IRON_TICK", "GRAVE_HAND", "SLAGJAW"]:
		expected.append(Content.enemy_key(id))
	# Smedens startrelik ligger inte i RELICS-poolen men visas i brickan.
	expected.append(Content.relic_key("ANVIL_BLESSING"))

	var missing: PackedStringArray = PackedStringArray()
	for key: String in expected:
		if not table.has(key):
			missing.append(key)
	assert_array(Array(missing)).override_failure_message(
		"innehålls-id utan CSV-rad: %s" % ", ".join(missing)).is_empty()


func test_every_slot_type_and_rarity_has_a_key() -> void:
	var table: Dictionary = _csv_table()
	for slot_type: int in [Rules.SlotType.PLAIN, Rules.SlotType.FIRE, Rules.SlotType.MIRROR,
			Rules.SlotType.ANVIL, Rules.SlotType.CHARGE, Rules.SlotType.VOID]:
		var key: String = "SLOT_%s" % Rules.slot_type_name(slot_type)
		assert_bool(table.has(key)).override_failure_message(
			"slot-nyckeln %s saknas" % key).is_true()
	for rarity: int in [Rules.Rarity.COMMON, Rules.Rarity.UNCOMMON, Rules.Rarity.RARE]:
		var key: String = "RARITY_%s" % Rules.rarity_name(rarity).to_upper()
		assert_bool(table.has(key)).override_failure_message(
			"rarity-nyckeln %s saknas" % key).is_true()


# --- 4. Uppslagningen fungerar i motorn ------------------------------------

func test_the_translations_are_registered_and_resolve_in_both_locales() -> void:
	var before: String = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	assert_str(String(TranslationServer.translate("ENEMY_RUST_RAT"))).is_equal("Rust Rat")
	TranslationServer.set_locale("sv")
	assert_str(String(TranslationServer.translate("ENEMY_RUST_RAT"))).is_equal("Rostråtta")
	TranslationServer.set_locale(before)


func test_the_fallback_locale_is_english() -> void:
	var fallback: String = String(ProjectSettings.get_setting("internationalization/locale/fallback", ""))
	assert_str(fallback).is_equal("en")


# --- Hjälpare --------------------------------------------------------------

func _read_csv() -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		return rows
	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		if line.size() == 1 and line[0].strip_edges() == "":
			continue
		rows.append(line)
	file.close()
	return rows


func _csv_table() -> Dictionary:
	var table: Dictionary = {}
	var rows: Array[PackedStringArray] = _read_csv()
	for i: int in range(1, rows.size()):
		table[rows[i][0]] = rows[i]
	return table


## Nyckel → första filen som använder den, så att felmeddelandet pekar ut var.
func _keys_used_in_source() -> Dictionary:
	var regex: RegEx = RegEx.new()
	regex.compile(KEY_PATTERN)
	var found: Dictionary = {}
	for dir_path: String in SOURCE_DIRS:
		for path: String in _gd_files(dir_path):
			var file: FileAccess = FileAccess.open(path, FileAccess.READ)
			if file == null:
				continue
			var text: String = file.get_as_text()
			file.close()
			for match_result: RegExMatch in regex.search_all(text):
				var key: String = match_result.get_string(1)
				if not found.has(key):
					found[key] = path
	return found


func _gd_files(dir_path: String) -> PackedStringArray:
	var files: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return files
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full: String = "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			files.append_array(_gd_files(full))
		elif entry.ends_with(".gd"):
			files.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return files
