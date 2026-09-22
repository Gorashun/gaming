extends GdUnitTestSuite
## Felsökningsflaggan [code]--pipwreck-start=town|corridor|sheet[/code].
##
## [method GameController.parse_start_target] är en ren funktion just för att
## den ska gå att testa headless: den rör varken motorn, profilen eller en
## skärm. Startflödet den styr testas i rökprovet och i webbverifieringen.


func test_no_flag_gives_empty_target() -> void:
	assert_str(GameController.parse_start_target(PackedStringArray())).is_equal("")
	assert_str(GameController.parse_start_target(
		PackedStringArray(["--pipwreck-seed=7"]))).is_equal("")


func test_each_target_is_parsed() -> void:
	assert_str(GameController.parse_start_target(
		PackedStringArray(["--pipwreck-start=town"]))).is_equal(GameController.START_TOWN)
	assert_str(GameController.parse_start_target(
		PackedStringArray(["--pipwreck-start=corridor"]))).is_equal(GameController.START_CORRIDOR)
	assert_str(GameController.parse_start_target(
		PackedStringArray(["--pipwreck-start=sheet"]))).is_equal(GameController.START_SHEET)
	assert_str(GameController.parse_start_target(
		PackedStringArray(["--pipwreck-start=tutorial"]))).is_equal(GameController.START_TUTORIAL)


func test_target_is_case_and_space_insensitive() -> void:
	assert_str(GameController.parse_start_target(
		PackedStringArray(["--pipwreck-start= Corridor "]))).is_equal(GameController.START_CORRIDOR)


func test_unknown_target_is_ignored() -> void:
	# En felstavad flagga får aldrig fälla starten – spelet ska starta normalt.
	assert_str(GameController.parse_start_target(
		PackedStringArray(["--pipwreck-start=dungeon"]))).is_equal("")
	assert_str(GameController.parse_start_target(
		PackedStringArray(["--pipwreck-start="]))).is_equal("")


func test_flag_coexists_with_seed_and_last_wins() -> void:
	var args: PackedStringArray = PackedStringArray([
		"--pipwreck-seed=7", "--pipwreck-start=town", "--pipwreck-start=corridor"])
	assert_str(GameController.parse_start_target(args)).is_equal(GameController.START_CORRIDOR)


func test_prefix_must_match_exactly() -> void:
	assert_str(GameController.parse_start_target(
		PackedStringArray(["--pipwreck-startcorridor"]))).is_equal("")
	assert_str(GameController.parse_start_target(
		PackedStringArray(["pipwreck-start=corridor"]))).is_equal("")
