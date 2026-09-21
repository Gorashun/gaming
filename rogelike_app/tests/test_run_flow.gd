extends GdUnitTestSuite
## Run-loopens regler utanför striden: rumsstart, Andrum, belöningsnyckel,
## belöningstillämpning, omkast och meta-poäng. GAME_DESIGN §1, §4.5 och §4.7.


func _node(room_in_floor: int, kind: String = RunGraph.KIND_COMBAT, variant: int = 0) -> Dictionary:
	return {
		"room_in_floor": room_in_floor,
		"room": room_in_floor,
		"floor": 1,
		"kind": kind,
		"variant": variant,
	}


# --- RunFlow ---------------------------------------------------------------

func test_start_room_pulls_the_encounter_and_rolls_before_confirmation() -> void:
	var state: CombatState = RunFlow.start_room(Content.smith_state(), _node(2), Rng.new(3))
	assert_int(state.enemies.size()).is_equal(Content.encounter(2, 0).size())
	assert_int(state.round_number).is_equal(1)
	# GAME_DESIGN §6.5: varje levande fiende har en synlig intent redan nu.
	for enemy: Enemy in state.enemies:
		assert_object(enemy.intent).is_not_null()


func test_start_room_is_deterministic_for_a_seed() -> void:
	var a: CombatState = RunFlow.start_room(Content.smith_state(), _node(1), Rng.new(77))
	var b: CombatState = RunFlow.start_room(Content.smith_state(), _node(1), Rng.new(77))
	assert_str(JSON.stringify(a.to_dict())).is_equal(JSON.stringify(b.to_dict()))


func test_start_room_does_not_mutate_its_input() -> void:
	var original: CombatState = Content.smith_state()
	var before: String = JSON.stringify(original.to_dict())
	RunFlow.start_room(original, _node(1), Rng.new(1))
	assert_str(JSON.stringify(original.to_dict())).is_equal(before)


func test_the_branch_variants_give_different_encounters() -> void:
	var a: CombatState = RunFlow.start_room(Content.smith_state(), _node(3, RunGraph.KIND_COMBAT, 0), Rng.new(1))
	var b: CombatState = RunFlow.start_room(Content.smith_state(), _node(3, RunGraph.KIND_COMBAT, 1), Rng.new(1))
	var ids_a: PackedStringArray = PackedStringArray()
	var ids_b: PackedStringArray = PackedStringArray()
	for enemy: Enemy in a.enemies:
		ids_a.append(enemy.id)
	for enemy: Enemy in b.enemies:
		ids_b.append(enemy.id)
	assert_str(",".join(ids_a)).is_not_equal(",".join(ids_b))


func test_breather_heals_after_a_normal_room() -> void:
	var state: CombatState = Content.smith_state()
	state.player_hp = 40
	var after: CombatState = RunFlow.finish_room(state, _node(2))
	assert_int(after.player_hp).is_equal(40 + Rules.BREATHER_HEAL)


func test_breather_never_exceeds_max_hp() -> void:
	var state: CombatState = Content.smith_state()
	state.player_hp = state.player_max_hp - 2
	assert_int(RunFlow.finish_room(state, _node(1)).player_hp).is_equal(state.player_max_hp)


func test_the_boss_room_gives_no_breather() -> void:
	# GAME_DESIGN §1: "efter varje vunnen COMBAT (ej BOSS)".
	var state: CombatState = Content.smith_state()
	state.player_hp = 40
	assert_int(RunFlow.finish_room(state, _node(4, RunGraph.KIND_BOSS)).player_hp).is_equal(40)
	assert_bool(RunFlow.grants_breather(_node(4, RunGraph.KIND_BOSS))).is_false()
	assert_bool(RunFlow.grants_breather(_node(3))).is_true()


func test_finish_room_resets_grown_and_cracked_faces() -> void:
	var state: CombatState = Content.smith_state()
	var face: Face = state.dice[0].mutable_face(0)
	face.value = 9
	face.id = "CRACKED"
	var after: CombatState = RunFlow.finish_room(state, _node(1))
	assert_int(after.dice[0].faces[0].value).is_equal(after.dice[0].faces[0].base_value)
	assert_str(after.dice[0].faces[0].id).is_not_equal("CRACKED")


func test_reward_floor_key_is_zero_after_the_boss() -> void:
	assert_int(RunFlow.reward_floor_key(_node(4, RunGraph.KIND_BOSS))).is_equal(0)
	assert_int(RunFlow.reward_floor_key(_node(2))).is_equal(1)


func test_available_pool_drops_what_the_player_already_took() -> void:
	var pool: Array[Dictionary] = Content.reward_pool()
	var taken: Array = [String(pool[0]["id"]), String(pool[3]["id"])]
	var available: Array[Dictionary] = RunFlow.available_pool(pool, taken)
	assert_int(available.size()).is_equal(pool.size() - 2)
	for entry: Dictionary in available:
		assert_bool(taken.has(String(entry["id"]))).is_false()


# --- RewardApply -----------------------------------------------------------

func _option(id: String) -> Dictionary:
	for entry: Dictionary in Content.reward_pool():
		if String(entry["id"]) == id:
			return entry
	return {}


func test_forge_face_targets_the_lowest_face_deterministically() -> void:
	var state: CombatState = Content.smith_state()
	var option: Dictionary = _option("FORGE_POISON_DROP")
	var target: Dictionary = RewardApply.default_target(state, option)
	assert_int(int(target["die_index"])).is_equal(0)
	assert_int(int(target["face_index"])).is_equal(0)
	assert_str(JSON.stringify(RewardApply.default_target(state, option))).is_equal(JSON.stringify(target))


func test_forge_face_replaces_exactly_one_face() -> void:
	var state: CombatState = Content.smith_state()
	var option: Dictionary = _option("FORGE_POISON_DROP")
	var after: CombatState = RewardApply.apply(state, option)
	assert_str(after.dice[0].faces[0].id).is_equal("POISON_DROP")
	assert_int(after.dice[0].faces[0].effect).is_equal(Rules.FaceEffectKind.APPLY_POISON)
	for i: int in range(1, Rules.FACE_COUNT):
		assert_str(after.dice[0].faces[i].id).is_equal(state.dice[0].faces[i].id)


func test_applying_a_reward_does_not_mutate_the_input_state() -> void:
	var state: CombatState = Content.smith_state()
	var before: String = JSON.stringify(state.to_dict())
	RewardApply.apply(state, _option("FORGE_POISON_DROP"))
	RewardApply.apply(state, _option("RELIC_DOMINO"))
	RewardApply.apply(state, _option("SWAP_VOID"))
	assert_str(JSON.stringify(state.to_dict())).is_equal(before)


func test_relic_is_added_once() -> void:
	var state: CombatState = Content.smith_state()
	var option: Dictionary = _option("RELIC_DOMINO")
	var after: CombatState = RewardApply.apply(RewardApply.apply(state, option), option)
	var count: int = 0
	for relic: Relic in after.relics:
		if relic.id == "DOMINO":
			count += 1
	assert_int(count).is_equal(1)


func test_slot_swap_prefers_the_leftmost_plain_slot() -> void:
	# Smedens bräde är [PLAIN, PLAIN, MIRROR, FIRE, ANVIL].
	var state: CombatState = Content.smith_state()
	var after: CombatState = RewardApply.apply(state, _option("SWAP_VOID"))
	assert_int(after.board.slots[0].type).is_equal(Rules.SlotType.VOID)
	assert_int(after.board.slots[1].type).is_equal(Rules.SlotType.PLAIN)
	assert_int(after.board.slots[2].type).is_equal(Rules.SlotType.MIRROR)


func test_every_reward_in_the_pool_can_be_described_and_applied() -> void:
	var state: CombatState = Content.smith_state()
	for option: Dictionary in Content.reward_pool():
		var target: Dictionary = RewardApply.default_target(state, option)
		var text: String = RewardApply.describe(state, option, target)
		assert_str(text).override_failure_message(
			"belöningen %s saknar beskrivning" % String(option["id"])).is_not_empty()
		var after: CombatState = RewardApply.apply(state, option, target)
		assert_object(after).is_not_null()


func test_the_description_names_the_die_and_the_replaced_value() -> void:
	var state: CombatState = Content.smith_state()
	var option: Dictionary = _option("FORGE_HAMMER_FACE")
	var text: String = RewardApply.describe(state, option, RewardApply.default_target(state, option))
	# Källspråket är engelska (CLAUDE.md); CSV:n är laddad i testkörningen, så
	# det som kommer ut är den engelska raden, inte nyckeln.
	assert_str(text).contains("Die 1")
	assert_str(text).contains("Forge Hammer")


# --- Reroll ----------------------------------------------------------------

func test_reroll_costs_one_and_only_rerolls_free_dice() -> void:
	var state: CombatState = RunFlow.start_room(Content.smith_state(), _node(1), Rng.new(4))
	var placement: PackedInt32Array = CombatState.empty_placement()
	placement[0] = 2
	var before_showing: int = state.dice[2].showing
	var after: CombatState = Reroll.apply(state, placement, Rng.new(9))
	assert_int(after.rerolls_left).is_equal(state.rerolls_left - 1)
	assert_int(after.dice[2].showing).override_failure_message(
		"en placerad tärning kastades om").is_equal(before_showing)


func test_reroll_is_refused_without_rerolls_left() -> void:
	var state: CombatState = RunFlow.start_room(Content.smith_state(), _node(1), Rng.new(4))
	state.rerolls_left = 0
	var after: CombatState = Reroll.apply(state, CombatState.empty_placement(), Rng.new(1))
	assert_int(after.rerolls_left).is_equal(0)
	assert_str(JSON.stringify(after.to_dict())).is_equal(JSON.stringify(state.to_dict()))


func test_a_locked_face_is_never_rerolled() -> void:
	var state: CombatState = RunFlow.start_room(Content.smith_state(), _node(1), Rng.new(4))
	# Blysidan (LEAD_SIX) på alla sex sidor: tärningen kan aldrig kastas om.
	for i: int in range(Rules.FACE_COUNT):
		state.dice[1].reforge(i, Content.make_face("LEAD_SIX"))
	assert_bool(Reroll.can_reroll(state, CombatState.empty_placement(), 1)).is_false()
	assert_bool(Reroll.rerollable_indices(state, CombatState.empty_placement()).has(1)).is_false()


func test_a_stolen_die_is_never_rerolled() -> void:
	var state: CombatState = RunFlow.start_room(Content.smith_state(), _node(1), Rng.new(4))
	state.stolen.append(state.dice[3].id)
	assert_bool(Reroll.can_reroll(state, CombatState.empty_placement(), 3)).is_false()


func test_player_locked_dice_are_kept() -> void:
	var state: CombatState = RunFlow.start_room(Content.smith_state(), _node(1), Rng.new(4))
	var kept: String = state.dice[4].id
	var before: int = state.dice[4].showing
	var after: CombatState = Reroll.apply(state, CombatState.empty_placement(), Rng.new(2), [kept])
	assert_int(after.dice[4].showing).is_equal(before)


func test_refund_reroll_pays_back_when_it_lands() -> void:
	var state: CombatState = RunFlow.start_room(Content.smith_state(), _node(1), Rng.new(4))
	# Ihålig sida på alla sidor av tärning 0 ⇒ kastet ger garanterat tillbaka.
	for i: int in range(Rules.FACE_COUNT):
		state.dice[0].reforge(i, Content.make_face("HOLLOW"))
	state.rerolls_left = 1
	var after: CombatState = Reroll.apply(state, CombatState.empty_placement(), Rng.new(6))
	assert_int(after.rerolls_left).is_equal(1)


func test_reroll_does_not_mutate_the_input() -> void:
	var state: CombatState = RunFlow.start_room(Content.smith_state(), _node(1), Rng.new(4))
	var before: String = JSON.stringify(state.to_dict())
	Reroll.apply(state, CombatState.empty_placement(), Rng.new(8))
	assert_str(JSON.stringify(state.to_dict())).is_equal(before)


func test_reroll_is_deterministic_for_a_seed() -> void:
	var state: CombatState = RunFlow.start_room(Content.smith_state(), _node(1), Rng.new(4))
	var a: CombatState = Reroll.apply(state, CombatState.empty_placement(), Rng.new(21))
	var b: CombatState = Reroll.apply(state, CombatState.empty_placement(), Rng.new(21))
	assert_str(JSON.stringify(a.to_dict())).is_equal(JSON.stringify(b.to_dict()))


# --- MetaScore -------------------------------------------------------------

func test_meta_score_is_zero_for_a_run_that_did_nothing() -> void:
	assert_int(MetaScore.score(0, 0, false, 0)).is_equal(0)


func test_meta_score_is_monotone_in_every_term() -> void:
	var base: int = MetaScore.score(2, 50, false, 30)
	assert_int(MetaScore.score(3, 50, false, 30)).is_greater(base)
	assert_int(MetaScore.score(2, 100, false, 30)).is_greater(base)
	assert_int(MetaScore.score(2, 50, false, 60)).is_greater(base)
	assert_int(MetaScore.score(2, 50, true, 30)).is_greater(base)


func test_meta_score_breakdown_sums_to_the_total() -> void:
	var breakdown: Dictionary = MetaScore.breakdown(4, 102, true, 81)
	var sum: int = int(breakdown["rooms"]) + int(breakdown["chain"]) + int(breakdown["survival"]) + int(breakdown["win"])
	assert_int(sum).is_equal(int(breakdown["total"]))
	assert_int(int(breakdown["total"])).is_equal(MetaScore.score(4, 102, true, 81))


func test_negative_input_cannot_produce_negative_points() -> void:
	assert_int(MetaScore.score(-3, -10, false, -50)).is_equal(0)


func test_chain_damage_counts_direct_and_status_damage() -> void:
	# GAME_DESIGN §3 invariant 6.
	var events: Array[Dictionary] = [
		{"t": "damage_dealt", "seq": 0, "amount": 14},
		{"t": "damage_dealt", "seq": 1, "amount": 20},
		{"t": "status_ticked", "seq": 2, "amount": 3},
		{"t": "charge_stored", "seq": 3, "amount": 99},
		{"t": "enemy_attacks", "seq": 4, "amount": 7},
	]
	assert_int(MetaScore.chain_damage(events)).is_equal(37)


func test_chain_damage_of_a_real_round_matches_the_resolver() -> void:
	var state: CombatState = RunFlow.start_room(Content.smith_state(), _node(1), Rng.new(13))
	var result: ResolveResult = Resolver.resolve(state, Policy.lookahead(state))
	var total: int = 0
	for i: int in range(state.enemies.size()):
		total += state.enemies[i].hp - result.state_after.enemies[i].hp
	assert_int(MetaScore.chain_damage(result.events)).is_equal(total)
