extends GdUnitTestSuite
## Profilen mellan runs (src/core/meta.gd) och Chalkrims ekonomi.
##
## [b]Den heliga regeln för metan[/b] (TOWN_AND_ONBOARDING §A.3): aldrig en
## statsiffra. Det testet står först, för det är det enda felet som inte går att
## upptäcka i efterhand — bryter vi det blir vi Archero och CLAUDE.md säger nej.

const TEST_META_PATH: String = "user://test_meta.json"

var _previous_path: String = ""


func before_test() -> void:
	_previous_path = SaveIO.meta_path
	SaveIO.meta_path = TEST_META_PATH
	SaveIO.clear_meta()


func after_test() -> void:
	SaveIO.clear_meta()
	SaveIO.meta_path = _previous_path


# --- Den heliga regeln -----------------------------------------------------

func test_the_market_only_ever_sells_pool_entries() -> void:
	for entry: Dictionary in Content.market_catalogue():
		var category: String = String(entry.get("category", ""))
		assert_bool(Meta.PRICE.has(category)).override_failure_message(
			"%s har en kategori som inte har ett pris" % entry.get("id", "")).is_true()
		var data: Dictionary = entry.get("data", {}) as Dictionary
		for key: Variant in data:
			assert_bool(["face_id", "relic_id", "slot_type"].has(String(key))).override_failure_message(
				"marknadsvaran %s bär fältet '%s' – metan får ALDRIG sälja en siffra" % [
					entry.get("id", ""), key]).is_true()


func test_buying_grows_the_pool_and_never_the_numbers() -> void:
	var meta: Meta = Meta.fresh()
	var before: Array[Dictionary] = Content.unlocked_pool(meta.unlocked)
	meta.pips = 100
	var entry: Dictionary = Content.market_catalogue()[0]
	assert_bool(meta.buy(entry)).is_true()
	var after: Array[Dictionary] = Content.unlocked_pool(meta.unlocked)
	assert_int(after.size()).override_failure_message(
		"köpet ska lägga till exakt en poolpost").is_equal(before.size() + 1)
	# Ett köp rör inte Smedens startuppsättning.
	var state: CombatState = Content.smith_state()
	assert_int(state.player_max_hp).is_equal(100)
	assert_int(state.rerolls_left).is_equal(1)
	assert_int(state.board.size()).is_equal(Rules.SLOT_COUNT)


func test_you_cannot_buy_twice_or_on_credit() -> void:
	var meta: Meta = Meta.fresh()
	var entry: Dictionary = Content.market_catalogue()[0]
	assert_bool(meta.can_afford(entry)).override_failure_message(
		"noll pips ska inte räcka").is_false()
	assert_bool(meta.buy(entry)).is_false()
	assert_int(meta.pips).is_equal(0)

	meta.pips = Meta.price_of(entry)
	assert_bool(meta.buy(entry)).is_true()
	assert_int(meta.pips).is_equal(0)
	assert_bool(meta.buy(entry)).override_failure_message(
		"samma vara ska inte gå att köpa två gånger").is_false()


# --- Intjäning -------------------------------------------------------------

func test_a_lost_run_always_pays_something() -> void:
	# StS-modellen (§A.3): förlust betalar alltid, annars är döden ren straff.
	assert_int(Meta.pips_for_run(3, false, false, [])).is_greater(0)
	assert_int(Meta.pips_for_run(0, false, false, [])).is_equal(0)


func test_a_spectacular_loss_beats_a_dull_survival() -> void:
	var dull: int = Meta.pips_for_run(3, false, false, [])
	var spectacular: int = Meta.pips_for_run(3, false, false, ["QUAD", "HOUSE"])
	assert_int(spectacular).override_failure_message(
		"vi ska belöna att spelaren försökte något").is_greater(dull)


func test_a_win_pays_more_than_a_loss_with_the_same_rooms() -> void:
	assert_int(Meta.pips_for_run(4, true, true, [])).is_greater(
		Meta.pips_for_run(4, false, false, []))


func test_first_time_bonuses_are_paid_exactly_once() -> void:
	var meta: Meta = Meta.fresh()
	var first: Dictionary = meta.award_run(1, false, false, ["QUAD"])
	var second: Dictionary = meta.award_run(1, false, false, ["QUAD"])
	assert_int(int(first["earned"])).is_greater(int(second["earned"]))
	assert_array(first["firsts"] as Array).is_equal(["QUAD"])
	assert_array(second["firsts"] as Array).is_empty()


# --- Kritstrecken ----------------------------------------------------------

func test_a_death_adds_a_mark_and_a_win_rubs_one_out() -> void:
	var meta: Meta = Meta.fresh()
	meta.award_run(2, false, false, [])
	meta.award_run(2, false, false, [])
	assert_int(meta.tally).is_equal(2)
	assert_int(meta.deaths).is_equal(2)
	meta.award_run(4, true, true, [])
	assert_int(meta.tally).override_failure_message(
		"kommer du upp suddar du ditt eget streck med tummen").is_equal(1)
	assert_int(meta.wins).is_equal(1)
	assert_int(meta.runs).is_equal(3)


func test_the_tally_never_goes_negative() -> void:
	var meta: Meta = Meta.fresh()
	for i: int in range(3):
		meta.award_run(4, true, true, [])
	assert_int(meta.tally).is_equal(0)


# --- Kodex -----------------------------------------------------------------

func test_the_codex_logs_each_thing_once() -> void:
	var meta: Meta = Meta.fresh()
	assert_bool(meta.see_enemy("RUST_RAT")).is_true()
	assert_bool(meta.see_enemy("RUST_RAT")).is_false()
	assert_bool(meta.see_combo("PAIR")).is_true()
	assert_bool(meta.see_combo("NONE")).override_failure_message(
		"NONE är inte en kedja och hör inte i Kodexen").is_false()
	assert_int(meta.seen_enemies.size()).is_equal(1)
	assert_int(meta.seen_combos.size()).is_equal(1)


# --- Marrow ----------------------------------------------------------------

func test_marrow_names_the_cause_of_death() -> void:
	var line: Dictionary = Content.death_line_for("SLAGJAW", -1, 0)
	assert_str(String(line["en"])).override_failure_message(
		"repliken ska namnge dödsorsaken").contains("Slagjaw")


func test_marrow_never_repeats_himself_twice_in_a_row() -> void:
	var previous: int = -1
	for run_index: int in range(12):
		var line: Dictionary = Content.death_line_for("", previous, run_index)
		assert_int(int(line["index"])).override_failure_message(
			"Marrow upprepade sig direkt (run %d)" % run_index).is_not_equal(previous)
		previous = int(line["index"])


func test_an_unknown_killer_still_gets_a_line() -> void:
	var line: Dictionary = Content.death_line_for("SOMETHING_NEW", -1, 3)
	assert_str(String(line["key"])).is_not_empty()
	assert_str(String(line["en"])).is_not_empty()


# --- Sparfilen -------------------------------------------------------------

func test_the_profile_survives_a_round_trip() -> void:
	var meta: Meta = Meta.fresh()
	meta.pips = 17
	meta.tutorial_done = true
	meta.reveal.reveal_flag("armor")
	meta.unlocked.append("RELIC_DOMINO")
	meta.loadout = {Forge.KEY_SLOT_ORDER: [2, 0, 1, 3, 4]}
	assert_bool(SaveIO.save_meta(meta)).is_true()

	var loaded: Meta = SaveIO.load_meta()
	assert_int(loaded.pips).is_equal(17)
	assert_bool(loaded.tutorial_done).is_true()
	assert_bool(loaded.reveal.has("armor")).is_true()
	assert_bool(loaded.reveal.has("anvil")).is_false()
	assert_array(loaded.unlocked).is_equal(["RELIC_DOMINO"])
	assert_array(loaded.loadout[Forge.KEY_SLOT_ORDER] as Array).override_failure_message(
		"JSON gör heltal till float; laddningen måste tvättas").is_equal([2, 0, 1, 3, 4])


func test_a_broken_profile_gives_a_fresh_one_not_a_crash() -> void:
	var file: FileAccess = FileAccess.open(TEST_META_PATH, FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()
	var loaded: Meta = SaveIO.load_meta()
	assert_object(loaded).override_failure_message(
		"en trasig profil får aldrig ge null").is_not_null()
	assert_int(loaded.pips).is_equal(0)
	assert_bool(loaded.tutorial_done).is_false()


func test_a_future_profile_version_is_refused_politely() -> void:
	var data: Dictionary = Meta.fresh().to_dict()
	data["version"] = Meta.SAVE_VERSION + 1
	data["pips"] = 999
	var file: FileAccess = FileAccess.open(TEST_META_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	assert_int(SaveIO.load_meta().pips).is_equal(0)


## Profilen och runnen är skilda filer med flit: "Reset save" och en run som tar
## slut får inte sudda kritväggen (§A.1).
func test_clearing_the_run_does_not_clear_the_profile() -> void:
	var meta: Meta = Meta.fresh()
	meta.pips = 42
	SaveIO.save_meta(meta)
	SaveIO.clear()
	assert_int(SaveIO.load_meta().pips).override_failure_message(
		"SaveIO.clear() tog med sig profilen").is_equal(42)
