extends GdUnitTestSuite
## Staden efter M6 (steg 5): tavernan, byggnaderna, förråden – och att GO DOWN
## fortfarande ligger i tumzonen när Marrow har mycket att säga (§A.4 regel 1).

const TOWN_SCENE: String = "res://src/game/town/town_screen.tscn"
const TEST_META_PATH: String = "user://test_town_m6_meta.json"

var _meta_path: String = ""


func before_test() -> void:
	_meta_path = SaveIO.meta_path
	SaveIO.meta_path = TEST_META_PATH
	SaveIO.clear_meta()


func after_test() -> void:
	SaveIO.clear_meta()
	SaveIO.meta_path = _meta_path


func _town(meta: Meta, arrival: Dictionary = {}) -> TownScreen:
	var scene: PackedScene = load(TOWN_SCENE) as PackedScene
	var town: TownScreen = auto_free(scene.instantiate()) as TownScreen
	add_child(town)
	town.size = Vector2(1080.0, 1920.0)
	town.setup(null, null, {"meta": meta, "seed": 7, "arrival": arrival})
	return town


func _veteran() -> Meta:
	var meta: Meta = Meta.skipped_tutorial()
	meta.runs = 3
	meta.ensure_hero(7)
	return meta


func test_go_down_stays_on_screen_after_a_death_with_the_tavern_open() -> void:
	var meta: Meta = _veteran()
	var town: TownScreen = _town(meta, {
		"killed_by": "RUST_RAT", "seed": 7, "pips_earned": 4,
		"fallen": "Dunstan", "rescued": 1, "lost": 2,
	})
	town.open_place(TownScreen.PLACE_TAVERN)
	await await_millis(80)
	var go_down: Button = town.get_node("Margin/Column/GoDownButton")
	assert_bool(go_down.visible).is_true()
	assert_float(go_down.get_global_rect().end.y).override_failure_message(
		"GO DOWN klipps av skärmkanten (%s)" % str(go_down.get_global_rect())).is_less_equal(1921.0)
	assert_float(go_down.get_global_rect().position.y).is_greater(1920.0 * 0.58)


func test_the_tavern_lists_the_roster_and_can_recruit_and_choose() -> void:
	var meta: Meta = _veteran()
	meta.buildings[Buildings.TAVERN] = 1
	var town: TownScreen = _town(meta)
	town.open_place(TownScreen.PLACE_TAVERN)
	await await_millis(40)
	assert_str(town.current_place()).is_equal(TownScreen.PLACE_TAVERN)
	town.recruit()
	assert_int(meta.roster.size()).is_equal(2)
	town.select_hero(1)
	assert_int(meta.roster.active_index).is_equal(1)
	town.recruit()
	assert_int(meta.roster.size()).override_failure_message(
		"tavernan nivå 1 har två platser").is_equal(2)


func test_the_tavern_dresses_the_active_hero_from_the_bank() -> void:
	var meta: Meta = _veteran()
	meta.bank.deposit([Content.make_item("CHIPPED_HAMMER")])
	var town: TownScreen = _town(meta)
	town.wear_item("bank", 0)
	assert_str(meta.roster.active().equipped("WEAPON").id).is_equal("CHIPPED_HAMMER")
	assert_int(meta.bank.items.size()).is_equal(0)


func test_buildings_are_bought_from_the_town_and_saved() -> void:
	var meta: Meta = _veteran()
	meta.pips = 10
	var town: TownScreen = _town(meta)
	town.open_place(TownScreen.PLACE_FORGE)
	town.buy_building(Buildings.CHEST)
	assert_int(meta.building_level(Buildings.CHEST)).is_equal(1)
	assert_int(SaveIO.load_meta().building_level(Buildings.CHEST)).is_equal(1)


func test_the_wall_no_longer_shows_the_meta_score() -> void:
	var meta: Meta = _veteran()
	meta.best_score = 4242
	var town: TownScreen = _town(meta)
	town.open_place(TownScreen.PLACE_WALL)
	await await_millis(40)
	var texts: PackedStringArray = PackedStringArray()
	for label: Node in town.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	assert_bool(" ".join(texts).contains("4242")).override_failure_message(
		"MetaScore ska bort ur UI:t (PROGRESSION_REDESIGN §6)").is_false()
