extends GdUnitTestSuite
## Credits (M6 spår A steg 5). CC BY 3.0 kräver att attributionen finns i
## spelet; det här testet är den kravlistan som kod.

const SCENE: String = "res://src/game/credits/credits_screen.tscn"
const SETTINGS_SCENE: String = "res://src/game/settings/settings_screen.tscn"


func _screen() -> CreditsScreen:
	var packed: PackedScene = load(SCENE) as PackedScene
	var screen: CreditsScreen = auto_free(packed.instantiate()) as CreditsScreen
	add_child(screen)
	screen.size = Vector2(1080.0, 1920.0)
	return screen


func test_every_source_in_credits_json_is_shown_word_for_word() -> void:
	var credits: Dictionary = CreditsScreen.load_credits()
	if credits.is_empty():
		return
	var screen: CreditsScreen = _screen()
	var shown: String = screen.shown_text()
	for raw: Variant in credits.get("sources", []) as Array:
		var source: Dictionary = raw as Dictionary
		for line: Variant in source.get("attribution_lines", []) as Array:
			assert_str(shown).override_failure_message(
				"%s: raden '%s' saknas i credits" % [source.get("id", "?"), line]).contains(String(line))


func test_required_attributions_come_first_under_their_section() -> void:
	var lines: Array[Dictionary] = CreditsScreen.build_lines({
		"sections": [{"id": "cc-by", "title": "ART (CC BY)"}, {"id": "cc0", "title": "CC0"}],
		"sources": [
			{"id": "b", "section": "cc0", "name": "B", "attribution_lines": ["b1"]},
			{"id": "a", "section": "cc-by", "name": "A", "attribution_lines": ["a1", "a2"]},
			{"id": "c", "section": "nowhere", "name": "C", "attribution_lines": ["c1"]},
		],
	})
	var texts: PackedStringArray = PackedStringArray()
	for line: Dictionary in lines:
		texts.append(String(line["text"]))
	assert_int(texts.find("ART (CC BY)")).is_less(texts.find("CC0"))
	assert_int(texts.find("a1")).is_less(texts.find("b1"))
	# En källa utan känd sektion tappas aldrig bort.
	assert_bool(texts.has("c1")).is_true()


func test_all_four_fonts_have_their_ofl_notice() -> void:
	var screen: CreditsScreen = _screen()
	var shown: String = screen.shown_text()
	for notice: Dictionary in CreditsScreen.FONT_NOTICES:
		assert_str(shown).contains(String(notice["name"]))
		assert_str(shown).contains(String(notice["copyright"]))
	assert_str(shown).contains(CreditsScreen.OFL_NAME)


## Copyrightraden i koden måste vara ordagrant första raden i fontens egen
## OFL-fil. Byts en font ut fäller det här testet i stället för att credits
## tyst nämner fel upphovsman.
func test_the_font_notices_match_the_shipped_ofl_files() -> void:
	for notice: Dictionary in CreditsScreen.FONT_NOTICES:
		var path: String = String(notice["license_file"])
		assert_bool(FileAccess.file_exists(path)).override_failure_message("%s saknas" % path).is_true()
		var first: String = FileAccess.get_file_as_string(path).split("\n")[0].strip_edges()
		assert_str(first).is_equal(String(notice["copyright"]))
	var dir: DirAccess = DirAccess.open("res://assets/fonts")
	var licences: int = 0
	for file: String in dir.get_files():
		if file.begins_with("OFL-") and file.ends_with(".txt"):
			licences += 1
	assert_int(licences).is_equal(CreditsScreen.FONT_NOTICES.size())


func test_credits_open_from_settings_and_close_back_to_them() -> void:
	var packed: PackedScene = load(SETTINGS_SCENE) as PackedScene
	var settings: Control = auto_free(packed.instantiate()) as Control
	add_child(settings)
	var button: Button = settings.find_child("CreditsButton", true, false) as Button
	assert_object(button).is_not_null()
	button.pressed.emit()
	var credits: CreditsScreen = settings.find_child("CreditsScreen", true, false) as CreditsScreen
	assert_object(credits).is_not_null()
	credits.close()
	await await_idle_frame()
	assert_bool(is_instance_valid(settings)).is_true()
	assert_object(settings.find_child("CreditsScreen", true, false)).is_null()
