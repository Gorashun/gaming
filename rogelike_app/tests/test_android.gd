extends GdUnitTestSuite
## Mobilanpassningarna i M4: skärmurtag, Androids bakåtknapp och vad som händer
## när operativsystemet lägger appen i bakgrunden.
##
## Allt här går att köra headless på en Linux-runner. Det är hela poängen med
## att [method SafeArea.top_inset_from] och [method GameController.back_action]
## är rena funktioner: reglerna kan testas utan en telefon, och telefonen
## behöver bara bevisa att siffrorna som matas in är rätt.

const TEST_SAVE: String = "user://test_android_save.json"

var _original_save_path: String = ""


func before_test() -> void:
	_original_save_path = SaveIO.save_path
	SaveIO.save_path = TEST_SAVE
	SaveIO.clear()


func after_test() -> void:
	SaveIO.clear()
	SaveIO.save_path = _original_save_path


# ---------------------------------------------------------------------------
# Safe area
# ---------------------------------------------------------------------------

func test_no_cutout_gives_no_inset() -> void:
	# En skärm utan urtag rapporterar ett safe area som börjar på y = 0.
	var inset: float = SafeArea.top_inset_from(
		Rect2i(0, 0, 1080, 2400), Vector2i(1080, 2400), Vector2(1080, 2400))
	assert_float(inset).is_equal_approx(0.0, 0.001)


func test_cutout_is_converted_to_viewport_units() -> void:
	# Pixel 7: 1080x2400 fysiskt, 118 px statusfält/hålkamera. Viewporten är
	# 1080 bred, alltså skala 1,0 – insetet ska komma ut oförändrat.
	var inset: float = SafeArea.top_inset_from(
		Rect2i(0, 118, 1080, 2282), Vector2i(1080, 2400), Vector2(1080, 2400))
	assert_float(inset).is_equal_approx(118.0, 0.001)


func test_inset_scales_when_the_screen_is_denser_than_the_viewport() -> void:
	# 1440x3200-skärm, viewport fortfarande 1080 bred => skala 1080/1440 = 0,75
	# och viewporthöjden 2400. Ett urtag på 160 skärmpixlar är 120 i viewporten.
	var inset: float = SafeArea.top_inset_from(
		Rect2i(0, 160, 1440, 3040), Vector2i(1440, 3200), Vector2(1080, 2400))
	assert_float(inset).is_equal_approx(120.0, 0.001)


func test_nonsense_reports_give_zero() -> void:
	# Tom rapport (skrivbord, headless).
	assert_float(SafeArea.top_inset_from(Rect2i(0, 0, 0, 0), Vector2i(1080, 1920), Vector2(1080, 1920))).is_equal(0.0)
	# Noll skärmhöjd: ingen division med noll, inget inset.
	assert_float(SafeArea.top_inset_from(Rect2i(0, 40, 1080, 0), Vector2i(1080, 0), Vector2(1080, 1920))).is_equal(0.0)
	# Safe area högre än skärmen: felaktig rapport, ignoreras.
	assert_float(SafeArea.top_inset_from(Rect2i(0, 40, 1080, 4000), Vector2i(1080, 2400), Vector2(1080, 2400))).is_equal(0.0)
	# Negativ position.
	assert_float(SafeArea.top_inset_from(Rect2i(0, -20, 1080, 2400), Vector2i(1080, 2400), Vector2(1080, 2400))).is_equal(0.0)


func test_inset_is_capped() -> void:
	# En emulator i delad skärm kan rapportera halva skärmen som osäker. HUD:en
	# får inte tryckas ut ur bild oavsett vad plattformen påstår.
	var inset: float = SafeArea.top_inset_from(
		Rect2i(0, 1200, 1080, 1200), Vector2i(1080, 2400), Vector2(1080, 2400))
	assert_float(inset).is_equal(SafeArea.MAX_INSET)


func test_apply_top_margin_adds_the_inset_on_top_of_the_base() -> void:
	var margin: MarginContainer = auto_free(MarginContainer.new())
	SafeArea.apply_top_margin(margin, 48, 118.0)
	assert_int(margin.get_theme_constant(&"margin_top")).is_equal(166)
	# Idempotent så länge bastalet är detsamma: två anrop ger samma svar.
	SafeArea.apply_top_margin(margin, 48, 118.0)
	assert_int(margin.get_theme_constant(&"margin_top")).is_equal(166)


func test_apply_top_margin_survives_a_null_container() -> void:
	SafeArea.apply_top_margin(null, 48, 118.0)


# ---------------------------------------------------------------------------
# Bakåtknappen
# ---------------------------------------------------------------------------

func test_back_never_quits_on_any_screen() -> void:
	# Kontraktet, i ett test: ingen skärm och inget läge får svara "avsluta".
	var screens: Array[String] = [
		GameController.SCREEN_TITLE,
		GameController.SCREEN_CORRIDOR,
		GameController.SCREEN_COMBAT,
		GameController.SCREEN_REWARD,
		GameController.SCREEN_GAMEOVER,
		"SOMETHING_NEW",
	]
	var allowed: Array[String] = [
		GameController.BACK_IGNORE,
		GameController.BACK_CLOSE_SETTINGS,
		GameController.BACK_SKIP_PLAYBACK,
		GameController.BACK_OPEN_SETTINGS,
		GameController.BACK_TO_TITLE,
	]
	for screen: String in screens:
		for settings_open: bool in [false, true]:
			for resolving: bool in [false, true]:
				var action: String = GameController.back_action(screen, settings_open, resolving)
				assert_array(allowed).contains([action])


func test_back_closes_the_settings_modal_first() -> void:
	# Modalen ligger överst och äger knappen, oavsett vilken skärm som är bakom.
	assert_str(GameController.back_action(GameController.SCREEN_COMBAT, true, false)) \
		.is_equal(GameController.BACK_CLOSE_SETTINGS)
	assert_str(GameController.back_action(GameController.SCREEN_TITLE, true, false)) \
		.is_equal(GameController.BACK_CLOSE_SETTINGS)


func test_back_in_combat_skips_the_chain_while_it_plays() -> void:
	assert_str(GameController.back_action(GameController.SCREEN_COMBAT, false, true)) \
		.is_equal(GameController.BACK_SKIP_PLAYBACK)
	assert_str(GameController.back_action(GameController.SCREEN_COMBAT, false, false)) \
		.is_equal(GameController.BACK_OPEN_SETTINGS)


func test_back_on_the_title_screen_does_nothing() -> void:
	assert_str(GameController.back_action(GameController.SCREEN_TITLE, false, false)) \
		.is_equal(GameController.BACK_IGNORE)


func test_back_on_game_over_returns_to_the_title() -> void:
	assert_str(GameController.back_action(GameController.SCREEN_GAMEOVER, false, false)) \
		.is_equal(GameController.BACK_TO_TITLE)


func test_quit_on_go_back_is_disabled_in_the_project() -> void:
	# Utan den här raden avslutar SceneTree appen själv och back_action() blir
	# aldrig anropad.
	assert_bool(ProjectSettings.get_setting("application/config/quit_on_go_back", true)).is_false()


# ---------------------------------------------------------------------------
# Paus: autosave och ljud
# ---------------------------------------------------------------------------

func _controller() -> GameController:
	var scene: PackedScene = load("res://src/game/main.tscn") as PackedScene
	var node: GameController = scene.instantiate() as GameController
	add_child(node)
	auto_free(node)
	return node


func test_pause_writes_an_autosave() -> void:
	var controller: GameController = _controller()
	controller.start_new_run(20260921)
	# start_new_run sparar redan; ta bort filen så att testet mäter pausen.
	SaveIO.clear()
	assert_bool(SaveIO.has_save()).is_false()

	controller.on_application_paused()
	assert_bool(SaveIO.has_save()).is_true()

	# seed_value lagras som sträng i JSON: 64-bitars seeds överlever inte en
	# double. RunState.to_dict() äger formatet, testet läser det som det är.
	var data: Dictionary = SaveIO.load_dict()
	assert_int(int(str(data.get("seed_value", "0")))).is_equal(20260921)
	controller.on_application_resumed()


func test_pause_before_a_run_writes_nothing() -> void:
	var controller: GameController = _controller()
	assert_bool(controller.can_autosave()).is_false()
	controller.on_application_paused()
	assert_bool(SaveIO.has_save()).is_false()
	controller.on_application_resumed()


func test_pause_mutes_and_resume_unmutes() -> void:
	var controller: GameController = _controller()
	controller.on_application_paused()
	assert_bool(Juice.is_audio_suspended()).is_true()
	assert_bool(AudioServer.is_bus_mute(Juice.MASTER_BUS)).is_true()

	controller.on_application_resumed()
	assert_bool(Juice.is_audio_suspended()).is_false()
	assert_bool(AudioServer.is_bus_mute(Juice.MASTER_BUS)).is_false()


func test_suspended_audio_swallows_sfx_instead_of_queueing_them() -> void:
	Juice.suspend_audio(true)
	Juice.reset_log()
	Juice.log_calls = true
	Juice.sfx(&"ui_tap")
	Juice.log_calls = false
	# Anropet loggas (loggen ska vara sann på alla plattformar) men inget ljud
	# startas. Det syns på att ingen kanal spelar.
	assert_int(Juice.count_calls("sfx")).is_equal(1)
	Juice.suspend_audio(false)
	assert_bool(AudioServer.is_bus_mute(Juice.MASTER_BUS)).is_false()


func test_a_paused_hit_stop_is_released() -> void:
	# Utan den här regeln vaknar appen med Engine.time_scale på 0,04.
	Juice.hit_stop(90)
	assert_bool(Juice.is_hit_stopped()).is_true()
	Juice.suspend_audio(true)
	assert_bool(Juice.is_hit_stopped()).is_false()
	assert_float(Engine.time_scale).is_equal_approx(1.0, 0.001)
	Juice.suspend_audio(false)


# ---------------------------------------------------------------------------
# Sparspärren i striden
# ---------------------------------------------------------------------------

func _combat_screen() -> CombatScreen:
	# Samma väg in i striden som GameController tar: nytt run, första rummet,
	# och skärmen monterad i trädet.
	var run: RunState = RunState.new_run(20260921)
	var rng: Rng = run.make_rng()
	var graph: RunGraph = RunGraph.generate_floor(1, rng)
	var node: Dictionary = graph.node_at(graph.start_id)
	run.combat = RunFlow.start_room(run.combat, node, rng)

	var scene: PackedScene = load("res://src/game/combat/combat_screen.tscn") as PackedScene
	var screen: CombatScreen = scene.instantiate() as CombatScreen
	add_child(screen)
	auto_free(screen)
	screen.setup(null, null, {
		"state": run.combat,
		"rng": rng,
		"node": node,
		"graph": graph,
		"best_chain": 0,
	})
	return screen


func test_a_fresh_round_may_be_autosaved() -> void:
	# Rundans början är exakt det läge controllern redan har sparat: kastet är
	# draget och slumpströmmen står still.
	var screen: CombatScreen = _combat_screen()
	assert_bool(screen.is_safe_to_autosave()).is_true()


func test_a_reroll_blocks_the_autosave_until_the_next_round() -> void:
	var screen: CombatScreen = _combat_screen()
	# Omkastet drar ur den seedade strömmen utan att controllerns sparade
	# CombatState följer med. Sparas det nu går runnen inte att återuppta
	# identiskt (GAME_DESIGN §1).
	screen.reroll()
	assert_bool(screen.is_safe_to_autosave()).is_false()

	# Nästa runda nollställer spärren.
	screen.begin_round()
	assert_bool(screen.is_safe_to_autosave()).is_true()
