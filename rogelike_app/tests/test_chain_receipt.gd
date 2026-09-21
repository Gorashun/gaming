extends GdUnitTestSuite
## Kvittot (docs/design/COMBAT_READABILITY.md §2).
##
## Testet bevakar den enda egenskap som gör kvittot värt att ha:
## [b]additionen går ihop, och den går ihop med förhandsvisningens total.[/b]
## Ljuger kvittot en enda gång slutar spelaren räkna, och då är spelet slump
## igen (TOWN_AND_ONBOARDING §B.1 punkt 1).

## Referensfallet ur COMBAT_READABILITY §2: brädet [PLAIN, PLAIN, MIRROR, FIRE,
## ANVIL], placeringen 2 · 5 · x · 6 · 6 mot fyra Rostråttor.
func _reference_state() -> CombatState:
	var state: CombatState = Content.smith_state()
	state.enemies = Content.encounter(1)
	var values: Array[int] = [2, 5, 1, 6, 6, 4]
	for i: int in range(values.size()):
		state.dice[i].showing = values[i] - 1
	for enemy: Enemy in state.enemies:
		enemy.intent = Intent.new(Rules.IntentKind.ATTACK, 3)
	return state


func test_the_reference_case_reads_exactly_as_the_document() -> void:
	var state: CombatState = _reference_state()
	var placement: PackedInt32Array = PackedInt32Array([0, 1, 2, 3, 4])
	var result: ResolveResult = Resolver.resolve(state, placement)
	var receipt: Dictionary = ChainReceipt.build(result.events, state.enemies, state.board)

	var amounts: Array[int] = []
	for slot: Dictionary in receipt["slots"] as Array[Dictionary]:
		amounts.append(int(slot["amount"]))
	assert_array(amounts).override_failure_message(
		"meningen ska vara 2 + 10 + 10 + 6 + 12").is_equal([2, 10, 10, 6, 12])
	assert_int(int(receipt["raw"])).is_equal(40)
	assert_int(int(receipt["armor"])).is_equal(12)
	assert_int(int(receipt["hits"])).is_equal(6)
	assert_int(int(receipt["armor_per_hit"])).is_equal(2)
	assert_int(int(receipt["damage"])).is_equal(28)
	assert_bool(ChainReceipt.balances(receipt)).is_true()


func test_the_delivery_lines_name_a_numbered_enemy_and_a_death() -> void:
	var state: CombatState = _reference_state()
	var result: ResolveResult = Resolver.resolve(state, PackedInt32Array([0, 1, 2, 3, 4]))
	var receipt: Dictionary = ChainReceipt.build(result.events, state.enemies, state.board)
	var lines: Array = receipt["lines"] as Array

	assert_int(lines.size()).override_failure_message(
		"en rad per skadeinstans, inga hopslagningar").is_equal(6)
	var first: Dictionary = lines[0] as Dictionary
	assert_int(int(first["incoming"])).is_equal(2)
	assert_int(int(first["blocked"])).is_equal(2)
	assert_int(int(first["dealt"])).is_equal(0)
	assert_bool(bool(first["is_overflow"])).is_false()

	var killed: int = 0
	var overflow_rows: int = 0
	for entry: Variant in lines:
		var line: Dictionary = entry as Dictionary
		if bool(line["killed"]):
			killed += 1
		if bool(line["is_overflow"]):
			overflow_rows += 1
	assert_int(killed).override_failure_message("Rostråtta 1 ska dö i raden").is_equal(1)
	assert_int(overflow_rows).override_failure_message("spillet ska vara en egen rad").is_equal(1)

	var ordinals: PackedInt32Array = ChainReceipt.ordinals(state.enemies)
	assert_int(ordinals[0]).is_equal(1)
	assert_int(ordinals[3]).is_equal(4)


func test_the_arc_carries_its_reason() -> void:
	var state: CombatState = _reference_state()
	var result: ResolveResult = Resolver.resolve(state, PackedInt32Array([0, 1, 2, 3, 4]))
	var receipt: Dictionary = ChainReceipt.build(result.events, state.enemies, state.board)
	var arcs: Array = receipt["arcs"] as Array
	assert_int(arcs.size()).is_equal(1)
	var arc: Dictionary = arcs[0] as Dictionary
	assert_array(arc["slots"] as Array).is_equal([1, 2])
	assert_int(int(arc["multiplier"])).is_equal(2)
	assert_str(String(arc["kind"])).is_equal("PAIR")
	assert_int(int(arc["value"])).override_failure_message(
		"bågen måste bära VARFÖR: det gemensamma värdet").is_equal(5)


func test_every_slot_says_why() -> void:
	var state: CombatState = _reference_state()
	var result: ResolveResult = Resolver.resolve(state, PackedInt32Array([0, 1, 2, 3, 4]))
	var slots: Array = (ChainReceipt.build(result.events, state.enemies, state.board))["slots"] as Array
	assert_str(String((slots[1] as Dictionary)["why"])).is_equal(ChainReceipt.WHY_PAIR_WITH)
	assert_str(String((slots[2] as Dictionary)["why"])).is_equal(ChainReceipt.WHY_COPY_OF)
	assert_array((slots[2] as Dictionary)["why_args"] as Array).override_failure_message(
		"spegeln kopierar slot 2 (1-indexerat)").is_equal([2])
	assert_str(String((slots[3] as Dictionary)["why"])).is_equal(ChainReceipt.WHY_BURN)
	assert_str(String((slots[4] as Dictionary)["why"])).is_equal(ChainReceipt.WHY_ANVIL_OK)


## §2.4: "slot_modifier_failed SKA synas". Idag visar spelet ingenting när
## Ambossen missar, och då lär sig spelaren aldrig tröskeln.
func test_a_failed_anvil_is_a_visible_reason() -> void:
	var state: CombatState = _reference_state()
	state.dice[4].showing = 2  # en 3:a i Ambossen
	var result: ResolveResult = Resolver.resolve(state, PackedInt32Array([0, 1, 2, 3, 4]))
	var slots: Array = (ChainReceipt.build(result.events, state.enemies, state.board))["slots"] as Array
	var anvil: Dictionary = slots[4] as Dictionary
	assert_str(String(anvil["why"])).is_equal(ChainReceipt.WHY_ANVIL_LOW)
	assert_str(String(anvil.get("modifier_failed", ""))).is_equal("ANVIL")


func test_a_mirror_without_a_left_neighbour_says_so() -> void:
	var state: CombatState = _reference_state()
	state.board = Board.from_types([Rules.SlotType.MIRROR, Rules.SlotType.PLAIN,
		Rules.SlotType.PLAIN, Rules.SlotType.PLAIN, Rules.SlotType.PLAIN])
	var result: ResolveResult = Resolver.resolve(state, PackedInt32Array([0, 1, 2, 3, 4]))
	var slots: Array = (ChainReceipt.build(result.events, state.enemies, state.board))["slots"] as Array
	assert_str(String((slots[0] as Dictionary)["why"])).is_equal(ChainReceipt.WHY_NO_LEFT)


# --- Invarianten över seedade lägen ----------------------------------------

## [b]Grinden.[/b] Femtio seedade lägen: kvittots summa måste vara exakt
## förhandsvisningens total, additionen måste gå ihop, och rustningsraden måste
## vara summan av [code]damage_dealt.blocked[/code] – inte en uppskattning.
func test_fifty_seeded_positions_add_up() -> void:
	for seed_value: int in range(1, 51):
		var rng: Rng = Rng.new(seed_value)
		var state: CombatState = Content.smith_state()
		state.enemies = Content.encounter(1 + (seed_value % 3), seed_value % 2)
		state.charge = seed_value % 7
		state = Resolver.begin_combat(state, rng)
		var placement: PackedInt32Array = Policy.lookahead(state)
		var result: ResolveResult = Resolver.resolve(state, placement)
		var receipt: Dictionary = ChainReceipt.build(result.events, state.enemies, state.board)

		var expected_damage: int = 0
		var expected_blocked: int = 0
		var expected_hits: int = 0
		for event: Dictionary in result.events:
			if String(event.get("t", "")) != "damage_dealt":
				continue
			expected_damage += int(event.get("amount", 0))
			expected_blocked += int(event.get("blocked", 0))
			expected_hits += 1

		assert_int(int(receipt["damage"])).override_failure_message(
			"seed %d: kvittots total skiljer sig från loggen" % seed_value).is_equal(expected_damage)
		assert_int(ChainReceipt.total_damage(result.events)).override_failure_message(
			"seed %d: knappens siffra skiljer sig från kvittot" % seed_value).is_equal(int(receipt["damage"]))
		assert_int(int(receipt["armor"])).override_failure_message(
			"seed %d: rustningsraden stämmer inte med events" % seed_value).is_equal(expected_blocked)
		assert_int(int(receipt["hits"])).override_failure_message(
			"seed %d: fel antal träffar i rustningsraden" % seed_value).is_equal(expected_hits)
		assert_bool(ChainReceipt.balances(receipt)).override_failure_message(
			"seed %d: RÅ %d ≠ skada %d + rustning %d + ward %d + laddning %d + spill %d" % [
				seed_value, int(receipt["raw"]), int(receipt["damage"]), int(receipt["armor"]),
				int(receipt["ward"]), int(receipt["charge"]), int(receipt["wasted"]),
			]).is_true()


## Samma invariant med VOID- och CHARGE-slots på brädet, så att termerna
## "ward" och "laddning" i §2.1b faktiskt prövas.
func test_ward_and_charge_slots_are_accounted_for() -> void:
	for seed_value: int in range(1, 21):
		var rng: Rng = Rng.new(seed_value * 13)
		var state: CombatState = Content.smith_state()
		state.board = Board.from_types([Rules.SlotType.VOID, Rules.SlotType.PLAIN,
			Rules.SlotType.CHARGE, Rules.SlotType.ANVIL, Rules.SlotType.PLAIN])
		state.enemies = Content.encounter(1)
		state = Resolver.begin_combat(state, rng)
		var result: ResolveResult = Resolver.resolve(state, PackedInt32Array([0, 1, 2, 3, 4]))
		var receipt: Dictionary = ChainReceipt.build(result.events, state.enemies, state.board)
		assert_int(int(receipt["ward"])).is_greater(0)
		assert_int(int(receipt["charge"])).is_greater(0)
		assert_bool(ChainReceipt.balances(receipt)).override_failure_message(
			"seed %d: ward/laddning bokförs inte" % seed_value).is_true()
