extends GdUnitTestSuite
## Tutorialvåning 0, THE SHALLOW CUT (src/data/tutorial.gd).
##
## [b]Grinden:[/b] hela våningen spelas igenom headless av en enkel policy, och
## varje rum måste (1) gå att vinna, (2) tända rätt [Reveal]-flagga och (3)
## faktiskt lära ut det rummet påstår sig lära ut – vilket kontrolleras mot
## händelseloggen, inte mot en kommentar.
##
## Att kunna köra hela lärkurvan utan UI är hela poängen med lagerregeln: går
## rum 0.6 inte att klara upptäcks det här, inte av en spelare.

## Tak per rum. Långt över det rimliga; går ett rum över detta är det trasigt.
const MAX_ROUNDS: int = 40


## Spelar ett rum med [method Policy.lookahead] och returnerar loggen från
## samtliga rundor plus sluttillståndet.
func _play_room(index: int, carried: CombatState, rng: Rng) -> Dictionary:
	var state: CombatState = Tutorial.prepare_room(carried, index, rng)
	var all_events: Array[Dictionary] = []
	var rounds: int = 0
	while rounds < MAX_ROUNDS:
		rounds += 1
		var placement: PackedInt32Array = Policy.lookahead(state)
		var result: ResolveResult = Resolver.resolve(state, placement)
		all_events.append_array(result.events)
		state = result.state_after
		if state.is_won():
			break
		if state.player_dead:
			# Träningshjulen: i våning 0 kan man inte dö (§B.2).
			state.player_dead = false
			state.player_hp = Tutorial.REVIVE_HP
		state = Resolver.advance(state, rng)
		Tutorial.force_dice(state, index)
		Tutorial.apply_intents(state, index)
	return {"state": state, "events": all_events, "rounds": rounds}


func test_the_whole_first_floor_can_be_played_through_headless() -> void:
	var rng: Rng = Rng.new(2026)
	var reveal: Reveal = Reveal.none()
	var carried: CombatState = Content.smith_state()
	for index: int in range(Tutorial.room_count()):
		var expected: Array[String] = Tutorial.reveal_flags(index)
		var fresh: Array[String] = Tutorial.apply_reveal(reveal, index)
		assert_array(fresh).override_failure_message(
			"rum %s tände inte exakt sina flaggor" % String(Tutorial.room(index)["id"])
		).is_equal(expected)
		for flag: String in expected:
			assert_bool(reveal.has(flag)).override_failure_message(
				"rum %s satte inte %s" % [String(Tutorial.room(index)["id"]), flag]).is_true()

		var played: Dictionary = _play_room(index, carried, rng)
		var state: CombatState = played["state"] as CombatState
		assert_bool(state.is_won()).override_failure_message(
			"rum %s gick inte att vinna på %d rundor" % [
				String(Tutorial.room(index)["id"]), int(played["rounds"])]).is_true()
		carried = Resolver.end_combat(state)

	assert_bool(reveal.is_complete()).override_failure_message(
		"efter sju rum ska allt vara avslöjat; saknas: %s" % str(reveal.to_dict())).is_true()


func test_every_room_has_the_board_dice_and_tip_the_document_specifies() -> void:
	assert_int(Tutorial.room_count()).is_equal(Tutorial.ROOM_COUNT)
	var expected_dice: Array = [3, 3, 4, 5, 5, 6, 6]
	var expected_slots: Array = [3, 3, 4, 5, 5, 5, 5]
	for index: int in range(Tutorial.room_count()):
		var data: Dictionary = Tutorial.room(index)
		assert_int((data["dice"] as Array).size()).override_failure_message(
			"rum %s ska ha %d tärningar" % [String(data["id"]), int(expected_dice[index])]
		).is_equal(int(expected_dice[index]))
		assert_int((data["board"] as Array).size()).override_failure_message(
			"rum %s ska ha %d slots" % [String(data["id"]), int(expected_slots[index])]
		).is_equal(int(expected_slots[index]))
		var tip: Dictionary = Tutorial.tip_for(index)
		assert_str(String(tip["key"])).is_not_empty()
		assert_str(String(tip["en"])).is_not_empty()


func test_the_forced_dice_are_exactly_what_the_room_asks_for() -> void:
	var rng: Rng = Rng.new(99)
	var carried: CombatState = Content.smith_state()
	for index: int in range(Tutorial.room_count()):
		var state: CombatState = Tutorial.prepare_room(carried, index, rng)
		var wanted: Array = Tutorial.room(index)["dice"] as Array
		assert_int(state.dice.size()).is_equal(wanted.size())
		for i: int in range(wanted.size()):
			assert_int(state.dice[i].showing_face().value).override_failure_message(
				"rum %s tärning %d visar %d, inte %d" % [
					String(Tutorial.room(index)["id"]), i,
					state.dice[i].showing_face().value, int(wanted[i])]
			).is_equal(int(wanted[i]))


## Rum 0.1: "det enda misstaget som är möjligt är att inte göra någonting."
## Dummyn får inte slå första rundan.
func test_the_dummy_is_silent_on_the_first_round() -> void:
	var state: CombatState = Tutorial.prepare_room(Content.smith_state(), 0, Rng.new(1))
	assert_int(state.enemies[0].intent.value).override_failure_message(
		"dummyn ska ha ATTACK 0 första rundan").is_equal(0)
	var result: ResolveResult = Resolver.resolve(state, PackedInt32Array([0, 1, 2]))
	for event: Dictionary in result.events_of("enemy_attacks"):
		assert_int(int(event.get("amount", 0))).override_failure_message(
			"dummyn slog första rundan").is_equal(0)


## Rum 0.2: framfienden har 3 HP. Vilken tärning som helst dödar den, och
## överskottet MÅSTE gå vidare. Lärdomen kommer av handling, inte av text.
func test_room_two_forces_an_overflow() -> void:
	var state: CombatState = Tutorial.prepare_room(Content.smith_state(), 1, Rng.new(1))
	var result: ResolveResult = Resolver.resolve(state, PackedInt32Array([0, 1, 2]))
	var receipt: Dictionary = ChainReceipt.build(result.events, state.enemies, state.board)
	var spilled: bool = false
	for entry: Variant in receipt["lines"] as Array:
		if bool((entry as Dictionary)["is_overflow"]):
			spilled = true
	assert_bool(spilled).override_failure_message(
		"rum 0.2 måste tvinga fram överflödet utan att säga det").is_true()


## Rum 0.3: paret är enda vägen. Fyra tärningar utan par ≤ 13 skada, med paret
## 23; fienden har 24 HP och slår för 8.
func test_room_three_makes_the_pair_the_only_way() -> void:
	var state: CombatState = Tutorial.prepare_room(Content.smith_state(), 2, Rng.new(1))
	var paired: ResolveResult = Resolver.resolve(state, PackedInt32Array([0, 1, 2, 3]))
	var combos: Array[Dictionary] = paired.events_of("combo_formed")
	assert_int(combos.size()).override_failure_message(
		"5 och 5 bredvid varandra ska ge ett par").is_equal(1)
	assert_int(int(combos[0].get("multiplier", 1))).is_equal(2)

	# Samma tärningar, paret brutet av en trea emellan.
	var broken: ResolveResult = Resolver.resolve(state, PackedInt32Array([0, 2, 1, 3]))
	assert_int(ChainReceipt.total_damage(broken.events)).override_failure_message(
		"utan paret ska skadan vara MINDRE – annars straffas spelaren inte"
	).is_less(ChainReceipt.total_damage(paired.events))


## Rum 0.4: "1 − 3 = 0 är ett slag som gör INGENTING. Det är första gången
## spelaren ser en nolla, och kvittot förklarar varför."
func test_room_four_shows_a_zero_line() -> void:
	var state: CombatState = Tutorial.prepare_room(Content.smith_state(), 3, Rng.new(1))
	var result: ResolveResult = Resolver.resolve(state, PackedInt32Array([4, 0, 1, 2, 3]))
	var receipt: Dictionary = ChainReceipt.build(result.events, state.enemies, state.board)
	assert_int(state.enemies[0].armor).is_equal(3)
	# Rustningsraden faller tillbaka på sin korta form här: en 1:a blockas med
	# 1, inte med 3, så avdraget är inte likformigt (§2.1b).
	assert_int(int(receipt["armor_per_hit"])).override_failure_message(
		"ojämnt avdrag ska rapporteras som -1, inte gissas").is_equal(-1)
	var zero_rows: int = 0
	for entry: Variant in receipt["lines"] as Array:
		if int((entry as Dictionary)["dealt"]) == 0:
			zero_rows += 1
	assert_int(zero_rows).override_failure_message(
		"en 1:a mot rustning 3 ska ge en synlig nollrad").is_greater(0)


## Rum 0.5: "seeden ger inget naturligt par. Spegeln är enda sättet att göra ett."
func test_room_five_has_no_natural_pair_but_a_mirror_makes_one() -> void:
	var state: CombatState = Tutorial.prepare_room(Content.smith_state(), 4, Rng.new(1))
	var values: Array[int] = []
	for die: Die in state.dice:
		assert_bool(values.has(die.showing_face().value)).override_failure_message(
			"rum 0.5 får inte innehålla två lika värden").is_false()
		values.append(die.showing_face().value)

	# Spegeln ligger på slot 2 och kopierar slot 1: det GÖR ett par.
	var result: ResolveResult = Resolver.resolve(state, PackedInt32Array([0, 1, 2, 3, 4]))
	assert_int(result.count_of("combo_formed")).override_failure_message(
		"Spegeln ska tillverka paret").is_equal(1)


## Rum 0.6: "porten har armor 8 och blockar två rundor. Varje enskild tärning
## studsar. Det enda vettiga är att inte placera."
func test_room_six_makes_banking_the_rational_move() -> void:
	var state: CombatState = Tutorial.prepare_room(Content.smith_state(), 5, Rng.new(1))
	assert_int(state.enemies[0].armor).is_equal(8)
	assert_int(state.enemies[0].intent.kind).override_failure_message(
		"porten ska blocka runda 1").is_equal(Rules.IntentKind.BLOCK)
	for die: Die in state.dice:
		assert_int(die.showing_face().value).override_failure_message(
			"varje tärning måste studsa mot rustning 8").is_less(8)

	var banked: ResolveResult = Resolver.resolve(state, CombatState.empty_placement(state.board.size()))
	assert_int(banked.state_after.charge).override_failure_message(
		"att inte placera ska banka laddning").is_greater(0)


## Rum 0.7: fällan. "Första gången spelaren lägger en 6:a i Ambossen bredvid en
## annan 6:a försvinner klammern." Visa fällan innan den smäller.
func test_room_seven_lets_the_anvil_break_the_pair() -> void:
	var state: CombatState = Tutorial.prepare_room(Content.smith_state(), 6, Rng.new(1))
	# Två sexor bredvid varandra i PLAIN-slots: par.
	var kept: ResolveResult = Resolver.resolve(state, PackedInt32Array([0, 1, -1, -1, -1]))
	assert_int(kept.count_of("combo_formed")).is_equal(1)
	# Samma två sexor, men den andra i AMBOSSEN på slot 5: 12 och 6 är inget par.
	var broken: ResolveResult = Resolver.resolve(state, PackedInt32Array([-1, -1, -1, 0, 1]))
	assert_int(broken.count_of("combo_formed")).override_failure_message(
		"12 och 6 är inte ett par").is_equal(0)
	var doubled: Array[Dictionary] = broken.events_of("slot_modifier")
	var anvil_fired: bool = false
	for event: Dictionary in doubled:
		if String(event.get("modifier", "")) == "ANVIL":
			anvil_fired = true
	assert_bool(anvil_fired).is_true()


func test_the_tutorial_rewards_never_change_the_state() -> void:
	# Korten är berättande; förändringen ligger i rumsdatan. Skulle de ändra
	# tillståndet skulle kortet och rummet kunna säga olika saker.
	var before: CombatState = Content.smith_state()
	for index: int in range(Tutorial.room_count()):
		var reward: Dictionary = Tutorial.reward_for(index)
		if reward.is_empty():
			continue
		assert_str(String(reward["category"])).is_equal(Rewards.CATEGORY_TUTORIAL)
		var after: CombatState = RewardApply.apply(before, reward, {})
		assert_int(after.board.size()).is_equal(before.board.size())
		assert_int(after.dice.size()).is_equal(before.dice.size())
		assert_int(after.relics.size()).is_equal(before.relics.size())


# ---------------------------------------------------------------------------
# Loot efter rum 0.3 (M5.7)
# ---------------------------------------------------------------------------

## Precis ett rum lämnar ett riktigt val av tre, och det är rum 0.3 – efter
## paret, medan spelaren fortfarande håller på att lära sig att placeringen
## betyder något.
func test_exactly_room_three_leaves_real_loot() -> void:
	for index: int in range(Tutorial.room_count()):
		assert_bool(Tutorial.has_loot(index)).override_failure_message(
			"rum %s: has_loot() fel" % String(Tutorial.room(index)["id"])
		).is_equal(index == 2)
	var title: Array[String] = Tutorial.loot_title()
	assert_str(title[0]).is_equal("TUT_LOOT_TITLE")
	assert_str(title[1]).is_equal("Loot. Pick one.")


## Korten är samma kort som senare: tre olika sidor ur den vanliga poolen, inte
## tutorialens berättande kategori.
func test_the_loot_is_three_different_faces_from_the_normal_pool() -> void:
	var pool: Array[Dictionary] = Content.reward_pool()
	var options: Array[Dictionary] = Tutorial.loot_options(pool, Rng.new(7))
	assert_int(options.size()).is_equal(Tutorial.LOOT_OPTIONS)
	var ids: Array[String] = []
	for option: Dictionary in options:
		assert_str(String(option["category"])).override_failure_message(
			"loot ska vara sidor, inte %s" % String(option["category"])
		).is_equal(Rewards.CATEGORY_FORGE_FACE)
		assert_bool(ids.has(String(option["id"]))).is_false()
		ids.append(String(option["id"]))

	# Seedat: samma seed ger samma tre kort, annars kan en buggrapport inte
	# återskapas och tutorialen slutar vara en tutorial.
	var again: Array[Dictionary] = Tutorial.loot_options(pool, Rng.new(7))
	for i: int in range(options.size()):
		assert_str(String(again[i]["id"])).is_equal(String(options[i]["id"]))


## [b]Invarianten som gör lootet ofarligt.[/b] Kortet byter en sida på en
## tärning, och rum 0.4–0.7 tvingar upp fasta värden. Väljer vi fel sida finns
## värdet inte längre, [method Tutorial.force_dice] hittar ingen och lektionen
## går sönder utan att något felar. Testet applicerar VARJE alternativ och
## kräver att alla senare rum fortfarande visar exakt sina värden.
func test_taking_any_loot_card_leaves_every_later_room_exactly_as_specified() -> void:
	var pool: Array[Dictionary] = Content.reward_pool()
	var options: Array[Dictionary] = Tutorial.loot_options(pool, Rng.new(7))
	for option: Dictionary in options:
		var carried: CombatState = Tutorial.prepare_room(
			Content.smith_state(), 2, Rng.new(3))
		var target: Dictionary = Tutorial.loot_target(carried, 2)
		assert_bool(target.is_empty()).override_failure_message(
			"loot utan mål vore ett kort som inte gör något").is_false()
		carried = RewardApply.apply(carried, option, target)
		for index: int in range(3, Tutorial.room_count()):
			var state: CombatState = Tutorial.prepare_room(carried, index, Rng.new(3))
			var wanted: Array = Tutorial.room(index)["dice"] as Array
			for i: int in range(wanted.size()):
				assert_int(state.dice[i].showing_face().value).override_failure_message(
					"efter loot '%s' visar rum %s tärning %d %d, inte %d" % [
						String(option["id"]), String(Tutorial.room(index)["id"]), i,
						state.dice[i].showing_face().value, int(wanted[i])]
				).is_equal(int(wanted[i]))
			carried = state


## Rum 0.5 får fortfarande inte ha ett naturligt par efter att lootet tagits –
## det är hela rummets lektion.
func test_room_five_still_has_no_natural_pair_after_the_loot() -> void:
	var pool: Array[Dictionary] = Content.reward_pool()
	for option: Dictionary in Tutorial.loot_options(pool, Rng.new(7)):
		var carried: CombatState = Tutorial.prepare_room(
			Content.smith_state(), 2, Rng.new(3))
		carried = RewardApply.apply(carried, option, Tutorial.loot_target(carried, 2))
		var state: CombatState = Tutorial.prepare_room(carried, 4, Rng.new(3))
		var values: Array[int] = []
		for die: Die in state.dice:
			assert_bool(values.has(die.showing_face().value)).override_failure_message(
				"loot '%s' gav rum 0.5 ett naturligt par" % String(option["id"])).is_false()
			values.append(die.showing_face().value)


func test_the_node_looks_like_a_run_graph_node() -> void:
	for index: int in range(Tutorial.room_count()):
		var node: Dictionary = Tutorial.node_for(index)
		assert_int(int(node["floor"])).is_equal(0)
		assert_int(int(node["room"])).is_equal(index + 1)
		assert_bool(RunFlow.is_boss(node)).is_equal(index == Tutorial.room_count() - 1)


# ---------------------------------------------------------------------------
# Källaren under smedjan (M5.5, CORRIDOR_DESIGN §5.2)
# ---------------------------------------------------------------------------

func test_the_basement_is_seven_chambers_on_a_straight_line() -> void:
	var map: CorridorMap = Tutorial.corridor_map()
	assert_int(map.floor_index).is_equal(0)
	var chambers: Array[String] = []
	for key: String in map.tiles():
		var cell: Dictionary = map.cell_at(CorridorMap.key_to_vec(key))
		if String(cell.get("kind", "")) == CorridorMap.KIND_CHAMBER:
			chambers.append(String(cell["node_id"]))
	assert_int(chambers.size()).is_equal(Tutorial.room_count())
	for i: int in range(Tutorial.room_count()):
		assert_str(chambers[i]).is_equal(String(Tutorial.node_for(i)["id"]))
		assert_int(Tutorial.room_index_for(chambers[i])).is_equal(i)
	# §5.2 punkt 2: exakt två steg mellan rummen, och korridoren är helt rak.
	for key: String in map.tiles():
		var at: Vector2i = CorridorMap.key_to_vec(key)
		assert_int(at.x).override_failure_message(
			"källaren svänger vid %s" % key).is_equal(0)


func test_the_basement_ends_in_a_stairway_up_behind_the_boss() -> void:
	var map: CorridorMap = Tutorial.corridor_map()
	var boss: Dictionary = map.boss_cell()
	assert_str(String(boss.get("node_id", ""))).is_equal(
		String(Tutorial.node_for(Tutorial.room_count() - 1)["id"]))
	var last_key: String = map.tiles()[map.tiles().size() - 1]
	var last: Dictionary = map.cell_at(CorridorMap.key_to_vec(last_key))
	assert_str(String(last.get("kind", ""))).is_equal(CorridorMap.KIND_STAIRS)
	assert_str(String(last.get("sign", ""))).is_equal(CorridorMap.SIGN_STAIRS)


func test_walking_the_basement_meets_every_room_in_order_then_the_stairs() -> void:
	# Att gå rakt fram hela vägen ÄR tutorialen: varje FRAM leder till nästa
	# lektion, och den sista leder upp ur gropen (§5.2 punkt 4).
	var map: CorridorMap = Tutorial.corridor_map()
	var met: Array[String] = []
	var stairs: int = 0
	for _step: int in range(64):
		if not map.apply(CorridorMap.ACTION_FORWARD):
			break
		for event: Dictionary in map.events_since_last():
			match String(event["type"]):
				CorridorMap.EVENT_ENCOUNTER_REACHED:
					met.append(String(event["node_id"]))
				CorridorMap.EVENT_STAIRS_UP:
					stairs += 1
	assert_int(met.size()).is_equal(Tutorial.room_count())
	for i: int in range(met.size()):
		assert_str(met[i]).is_equal(String(Tutorial.node_for(i)["id"]))
	assert_int(stairs).is_equal(1)


func test_every_room_points_at_an_anchor_the_combat_screen_still_has() -> void:
	# Kritpilen får aldrig peka på ett element som togs bort med den platta
	# skärmen (M5.5). Listan speglar CombatScreen.pointer_anchors().
	var known: Array[String] = ["charge", "receipt", "enemies", "board", "arcs",
		"tray", "confirm"]
	for index: int in range(Tutorial.room_count()):
		var target: String = String(Tutorial.tip_for(index)["point_at"])
		if target.begins_with("slot_"):
			continue
		assert_bool(known.has(target)).override_failure_message(
			"rum %s pekar på '%s' som inte finns" % [
				String(Tutorial.room(index)["id"]), target]).is_true()
