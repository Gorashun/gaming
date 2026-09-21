extends GdUnitTestSuite
## Inställningarna: standardvärden, roundtrip genom [code]user://[/code] och
## att en trasig fil aldrig kan välta spelet.
##
## Autoloaden [code]Settings[/code] är delad, så varje test pekar om
## [member config_path] till en egen fil under [code]user://[/code] och
## återställer både sökvägen och värdena efteråt.

const TEST_PATH: String = "user://test_settings.cfg"

var _saved: Dictionary = {}
var _saved_path: String = ""


func before_test() -> void:
	_saved = Settings.to_dict()
	_saved_path = Settings.config_path
	Settings.config_path = TEST_PATH
	_remove_file()


func after_test() -> void:
	_remove_file()
	Settings.config_path = _saved_path
	for key: String in _saved:
		Settings.set_value(StringName(key), _saved[key], false)


func _remove_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		var dir: DirAccess = DirAccess.open("user://")
		if dir != null:
			dir.remove(TEST_PATH.get_file())


func test_defaults_are_the_documented_ones() -> void:
	Settings.reset_to_defaults(false)
	assert_int(Settings.sfx_volume).is_equal(80)
	assert_bool(Settings.haptics).is_true()
	assert_bool(Settings.reduced_motion).is_false()
	assert_bool(Settings.high_contrast).is_false()
	# Engelska är standard, [b]inte[/b] enhetens språk (DECISIONS 2026-09-21).
	# Den gamla regeln var tvärtom – tomt betydde "rör inte locale" – och det
	# var just den som lät en svensk telefon starta spelet på svenska.
	assert_str(Settings.locale).is_equal("en")


func test_a_roundtrip_through_the_file_keeps_every_field() -> void:
	Settings.set_value(&"sfx_volume", 37)
	Settings.set_value(&"haptics", false)
	Settings.set_value(&"reduced_motion", true)
	Settings.set_value(&"high_contrast", true)
	Settings.set_value(&"locale", "sv")
	var written: Dictionary = Settings.to_dict()

	Settings.reset_to_defaults(false)
	assert_int(Settings.sfx_volume).is_equal(80)

	assert_bool(Settings.load_settings()).is_true()
	assert_dict(Settings.to_dict()).is_equal(written)


func test_a_missing_file_gives_defaults_and_not_a_crash() -> void:
	Settings.set_value(&"sfx_volume", 11, false)
	assert_bool(Settings.load_settings()).is_false()
	assert_int(Settings.sfx_volume).is_equal(80)


func test_a_corrupt_file_gives_defaults_and_not_a_crash() -> void:
	var file: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("{{{ this is not a ConfigFile ]]]")
	file.close()
	assert_bool(Settings.load_settings()).is_false()
	assert_int(Settings.sfx_volume).is_equal(80)
	assert_bool(Settings.haptics).is_true()


func test_values_are_clamped_and_type_washed() -> void:
	# ConfigFile ger tillbaka Variant: ett heltal som skrivits som float skulle
	# annars smyga in i sfx_volume och ge "80.0 %" i UI:t.
	Settings.set_value(&"sfx_volume", 250.0, false)
	assert_int(Settings.sfx_volume).is_equal(100)
	Settings.set_value(&"sfx_volume", -5, false)
	assert_int(Settings.sfx_volume).is_equal(0)
	assert_float(Settings.sfx_linear()).is_equal(0.0)


func test_haptics_setting_reaches_the_platform_layer() -> void:
	Settings.set_value(&"haptics", false, false)
	assert_bool(Haptics.enabled).is_false()
	assert_bool(Haptics.allows(Haptics.Level.HEAVY)).is_false()
	Settings.set_value(&"haptics", true, false)
	assert_bool(Haptics.allows(Haptics.Level.HEAVY)).is_true()


func test_high_contrast_reaches_the_tokens() -> void:
	Settings.set_value(&"high_contrast", true, false)
	assert_bool(Tokens.high_contrast).is_true()
	# §6.3: alla ramar till stroke/bold.
	var box: StyleBoxFlat = Tokens.box(Tokens.CHALK_100, true, Tokens.STROKE_HAIR)
	assert_int(box.border_width_left).is_greater_equal(int(round(Tokens.dp(Tokens.STROKE_BOLD))))
	Settings.set_value(&"high_contrast", false, false)
	assert_bool(Tokens.high_contrast).is_false()


func test_an_unknown_key_is_ignored() -> void:
	Settings.set_value(&"not_a_setting", 1, false)
	assert_dict(Settings.to_dict()).not_contains_keys(["not_a_setting"])


# --- Språket: engelska är standard, aldrig enhetens ------------------------
# DECISIONS 2026-09-21 (Anders): Godot väljer OS-språket automatiskt, och en
# svensk telefon visade därför svenska utan att någon valt det. Engelska är
# källspråket (CLAUDE.md) och ska gälla tills spelaren själv byter.

func test_the_default_locale_is_english() -> void:
	assert_str(String(Settings.DEFAULTS["locale"])).is_equal(Settings.DEFAULT_LOCALE)
	assert_str(Settings.DEFAULT_LOCALE).is_equal("en")


## Grinden Anders bad om: ingen sparad inställning, enheten står på svenska,
## och spelet ska ändå vara engelskt.
func test_a_swedish_device_without_a_saved_setting_still_shows_english() -> void:
	var before_locale: String = TranslationServer.get_locale()
	var before_path: String = Settings.config_path
	var before_values: Dictionary = Settings.to_dict()

	# Så här ser en svensk telefon ut innan spelet hunnit säga något.
	TranslationServer.set_locale("sv")
	assert_str(String(TranslationServer.translate("TITLE_NEW_RUN"))).override_failure_message(
		"förutsättningen håller inte: sv ger inte den svenska raden").is_equal("NY RUN")

	# Ingen sparad fil: ladda om från en sökväg som inte finns.
	Settings.config_path = "user://test_missing_settings.cfg"
	assert_bool(Settings.load_settings()).is_false()

	assert_str(Settings.effective_locale()).is_equal("en")
	assert_str(String(TranslationServer.translate("TITLE_NEW_RUN"))).override_failure_message(
		"OS-språket slog igenom – spelet ska vara engelskt tills spelaren byter"
	).is_equal("NEW RUN")

	Settings.config_path = before_path
	for key: String in before_values:
		Settings.set_value(StringName(key), before_values[key], false)
	TranslationServer.set_locale(before_locale)


## En tom sträng i en äldre fil får inte betyda "ta enhetens språk".
func test_an_empty_saved_locale_falls_back_to_english() -> void:
	var before: String = Settings.locale
	Settings.set_value(&"locale", "", false)
	assert_str(Settings.effective_locale()).is_equal("en")
	Settings.set_value(&"locale", before, false)


## Väljer spelaren svenska ska den gälla – det är fortfarande ett val.
func test_the_player_can_still_pick_swedish() -> void:
	var before_locale: String = Settings.locale
	var before_engine: String = TranslationServer.get_locale()
	Settings.set_value(&"locale", "sv", false)
	assert_str(Settings.effective_locale()).is_equal("sv")
	assert_str(String(TranslationServer.translate("TITLE_NEW_RUN"))).is_equal("NY RUN")
	Settings.set_value(&"locale", before_locale, false)
	TranslationServer.set_locale(before_engine)
