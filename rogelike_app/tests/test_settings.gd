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
	# Tomt språk = "rör inte locale". Annars skulle en ny installation tvinga
	# engelska över en telefon som står på svenska.
	assert_str(Settings.locale).is_empty()


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
