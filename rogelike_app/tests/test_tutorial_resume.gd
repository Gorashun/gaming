extends GdUnitTestSuite
## Källaren är återupptagbar (M5.8). ARCHITECTURE, "M5.8: källaren är
## återupptagbar".
##
## [b]Varför det här testet finns:[/b] på en telefon spelas våning 0 i ett svep.
## I en webbläsare är en omladdning gratis, och fram till M5.8 startade den om
## Grundstigen på rum 0.1 – spelaren såg aldrig torget. Testet driver den
## riktiga [GameController]n, inte en kopia av dess logik, eftersom buggen låg i
## ordningen mellan autosave, rumsbyte och slumpström.

const MAIN_SCENE: String = "res://src/game/main.tscn"
const TEST_SAVE: String = "user://test_tutorial_save.json"
const TEST_META: String = "user://test_tutorial_meta.json"

var _save_path: String = ""
var _meta_path: String = ""
var _variant: String = ""


func before_test() -> void:
	_save_path = SaveIO.save_path
	_meta_path = SaveIO.meta_path
	SaveIO.save_path = TEST_SAVE
	SaveIO.meta_path = TEST_META
	SaveIO.clear()
	SaveIO.clear_meta()
	# Utan kroppsval går boot() till smedjan i stället för titeln.
	_variant = Settings.smith_variant
	Settings.set_value(&"smith_variant", Art.SMITH_VARIANT_DEFAULT)


func after_test() -> void:
	SaveIO.clear()
	SaveIO.clear_meta()
	SaveIO.save_path = _save_path
	SaveIO.meta_path = _meta_path
	Settings.set_value(&"smith_variant", _variant)


## En monterad [GameController] som står på titelskärmen. [method _show] är
## uppskjuten, så skärmen byggs först efter en bildruta – och den behövs inte
## för något testet gör.
func _controller() -> GameController:
	var scene: PackedScene = load(MAIN_SCENE) as PackedScene
	var root: GameController = auto_free(scene.instantiate()) as GameController
	add_child(root)
	return root


## Går in i källarens rum [param index] samma väg som korridoren gör det:
## kammarens nod-id.
func _walk_to(controller: GameController, index: int) -> void:
	for step: int in range(index + 1):
		controller._enter_tutorial_room(String(Tutorial.node_for(step)["id"]))


func _dice_signature(state: CombatState) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for die: Die in state.dice:
		parts.append(str(die.showing_face().value))
	return "-".join(parts)


# ---------------------------------------------------------------------------
# 1. Spara mitt i rum 0.4, ladda, samma rum och samma tärningar
# ---------------------------------------------------------------------------

func test_the_basement_writes_a_save_file_at_all() -> void:
	var controller: GameController = _controller()
	controller.start_tutorial()
	assert_bool(SaveIO.has_save()).override_failure_message(
		"källaren måste autospara, annars kan CONTINUE aldrig leda tillbaka hit"
	).is_true()
	assert_int(int(SaveIO.load_dict().get("meta", {}).get("tutorial_room", -1))).is_equal(0)


func test_a_reload_in_room_four_resumes_in_room_four_with_the_same_dice() -> void:
	var controller: GameController = _controller()
	controller.start_tutorial()
	_walk_to(controller, 3)  # rum 0.4
	assert_int(controller.tutorial_room()).is_equal(3)
	var before: String = _dice_signature(controller.run.combat)
	var hp_before: int = controller.run.combat.player_hp

	# Omladdningen: en ny process, en ny controller, samma fil på disk.
	var reloaded: GameController = _controller()
	assert_bool(reloaded.resume_run()).override_failure_message(
		"sparfilen från källaren måste gå att återuppta").is_true()
	assert_int(reloaded.tutorial_room()).is_equal(3)
	assert_str(_dice_signature(reloaded.run.combat)).override_failure_message(
		"rum 0.4 måste visa exakt sina tärningar efter en omladdning").is_equal(before)
	assert_str(_dice_signature(reloaded.run.combat)).is_equal("3-3-5-5-1")
	assert_int(reloaded.run.combat.player_hp).is_equal(hp_before)
	assert_int(reloaded.run.combat.enemies[0].armor).is_equal(3)


func test_the_resumed_basement_keeps_the_reveal_flags_the_rooms_turned_on() -> void:
	# Flaggorna ligger i profilen, inte i runnen, och skrivs vid varje rumsbyte.
	# Utan dem återupptas rum 0.4 med ett halvt UI.
	var controller: GameController = _controller()
	controller.start_tutorial()
	_walk_to(controller, 3)

	var reloaded: GameController = _controller()
	assert_bool(reloaded.resume_run()).is_true()
	for index: int in range(4):
		for flag: String in Tutorial.reveal_flags(index):
			assert_bool(reloaded.meta.reveal.has(flag)).override_failure_message(
				"flaggan '%s' från rum %s överlevde inte omladdningen" % [
					flag, String(Tutorial.room(index)["id"])]).is_true()


func test_the_title_offers_continue_after_a_basement_save() -> void:
	# Titeln bygger CONTINUE på SaveIO.has_save(). Det är hela kopplingen: en
	# sparad källare ska erbjuda CONTINUE, inte en omstart på 0.1.
	var controller: GameController = _controller()
	controller.start_tutorial()
	_walk_to(controller, 3)
	var scene: PackedScene = load("res://src/game/title/title_screen.tscn") as PackedScene
	var title: TitleScreen = auto_free(scene.instantiate()) as TitleScreen
	add_child(title)
	title.setup(null, null, {"has_save": SaveIO.has_save(), "tutorial_done": false})
	assert_bool(title.has_save()).is_true()


# ---------------------------------------------------------------------------
# 2. Rum 0.7 klart ⇒ profilen är klar och sparfilen är borta
# ---------------------------------------------------------------------------

func test_finishing_the_basement_marks_the_profile_and_removes_the_save() -> void:
	var controller: GameController = _controller()
	controller.start_tutorial()
	_walk_to(controller, Tutorial.room_count() - 1)
	assert_bool(SaveIO.has_save()).is_true()

	controller._finish_tutorial()
	assert_bool(controller.meta.tutorial_done).is_true()
	assert_bool(SaveIO.has_save()).override_failure_message(
		"efter trappan upp får ingen sparfil ligga kvar och erbjuda källaren igen"
	).is_false()
	assert_int(controller.tutorial_room()).is_equal(-1)
	# Profilen ligger kvar: kritväggen och Pips får aldrig suddas (§A.1).
	assert_bool(SaveIO.has_meta_profile()).is_true()
	assert_bool(SaveIO.load_meta().tutorial_done).is_true()


# ---------------------------------------------------------------------------
# 3. Sparfilsversionen
# ---------------------------------------------------------------------------

func test_a_basement_save_is_written_with_the_current_version() -> void:
	var controller: GameController = _controller()
	controller.start_tutorial()
	var raw: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(TEST_SAVE)) as Dictionary
	assert_int(int(raw["version"])).is_equal(RunState.SAVE_VERSION)
	assert_int(RunState.SAVE_VERSION).override_failure_message(
		"källarens fält kom i version 3").is_greater_equal(3)


func test_a_real_run_still_saves_minus_one_and_resumes_as_a_real_run() -> void:
	# Regressionsvakten åt andra hållet: tutorialfältet får inte smitta en run.
	var controller: GameController = _controller()
	controller.meta.tutorial_done = true
	controller.start_new_run(4242)
	assert_int(int(SaveIO.load_dict().get("meta", {}).get("tutorial_room", 0))).is_equal(-1)

	var reloaded: GameController = _controller()
	assert_bool(reloaded.resume_run()).is_true()
	assert_int(reloaded.tutorial_room()).is_equal(-1)
	assert_int(reloaded.run.seed_value).is_equal(4242)
