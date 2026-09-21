extends GdUnitTestSuite
## Renhet, determinism, eventlogg-invarianter och kantfall.
## Motsvarar testsviten som GAME_DESIGN §6 kräver före M1.

const PLAIN := Rules.SlotType.PLAIN
const FIRE := Rules.SlotType.FIRE
const MIRROR := Rules.SlotType.MIRROR
const ANVIL := Rules.SlotType.ANVIL
const VOID := Rules.SlotType.VOID
const CHARGE := Rules.SlotType.CHARGE
const DEFAULT_BOARD: Array = [PLAIN, PLAIN, MIRROR, FIRE, ANVIL]


func _fixture(board: Array = DEFAULT_BOARD, slots: Array = [3, 3, 1, 2, 5], unplaced: Array = [4], enemies: Array = []) -> Dictionary:
	if enemies.is_empty():
		enemies = [CombatFixture.dummy_enemy("DUMMY", 500)]
	return CombatFixture.build(board, slots, unplaced, enemies)


# -- Renhet och determinism (GAME_DESIGN §6.1–6.3) ---------------------------

func test_resolve_is_deterministic() -> void:
	var fixture: Dictionary = _fixture()
	var first: String = Resolver.resolve(fixture["state"], fixture["placement"]).events_json()
	for i: int in range(100):
		assert_str(Resolver.resolve(fixture["state"], fixture["placement"]).events_json()).is_equal(first)


func test_preview_equals_applied() -> void:
	# Förhandsvisningen ÄR utfallet: samma argument måste ge identisk logg.
	var fixture: Dictionary = _fixture()
	var preview: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	var applied: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	assert_str(applied.events_json()).is_equal(preview.events_json())
	assert_str(JSON.stringify(applied.state_after.to_dict())).is_equal(JSON.stringify(preview.state_after.to_dict()))


func test_resolve_does_not_mutate_input() -> void:
	var fixture: Dictionary = _fixture()
	var state: CombatState = fixture["state"]
	state.charge = 5
	var before: String = JSON.stringify(state.to_dict())
	Resolver.resolve(state, fixture["placement"])
	assert_str(JSON.stringify(state.to_dict())).is_equal(before)


func test_resolve_takes_no_rng() -> void:
	# Signaturen har bara två parametrar. Finns ingen RNG kan ingen dold slump
	# smyga in i en redan bekräftad runda.
	var found: bool = false
	for method: Dictionary in Resolver.new().get_script().get_script_method_list():
		if String(method["name"]) == "resolve":
			found = true
			assert_int((method["args"] as Array).size()).is_equal(2)
			for arg: Dictionary in method["args"] as Array:
				assert_str(String(arg["class_name"])).is_not_equal("Rng")
	assert_bool(found).is_true()


# -- Eventlogg-invarianter (GAME_DESIGN §3) ----------------------------------

func test_events_seq_is_contiguous() -> void:
	var fixture: Dictionary = _fixture()
	var result: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	assert_int(result.events.size()).is_greater(0)
	for i: int in range(result.events.size()):
		assert_int(int(result.events[i]["seq"])).is_equal(i)


func test_every_event_has_the_envelope() -> void:
	var fixture: Dictionary = _fixture()
	for event: Dictionary in Resolver.resolve(fixture["state"], fixture["placement"]).events:
		assert_bool(event.has("t")).is_true()
		assert_bool(event.has("seq")).is_true()
		assert_bool(event.has("ms_hint")).is_true()
		assert_str(String(event["t"])).is_not_empty()


func test_round_start_is_first_and_round_end_is_last() -> void:
	var fixture: Dictionary = _fixture()
	var events: Array[Dictionary] = Resolver.resolve(fixture["state"], fixture["placement"]).events
	assert_str(String(events[0]["t"])).is_equal("round_start")
	assert_str(String(events[events.size() - 1]["t"])).is_equal("round_end")


func test_value_pass_done_separates_the_phases() -> void:
	var fixture: Dictionary = _fixture()
	var events: Array[Dictionary] = Resolver.resolve(fixture["state"], fixture["placement"]).events
	var value_done: int = _index_of(events, "value_pass_done")
	assert_int(value_done).is_greater(0)
	assert_int(_last_index_of(events, "die_activated")).is_less(value_done)
	assert_int(_last_index_of(events, "slot_modifier")).is_less(value_done)
	var first_combo: int = _index_of(events, "combo_formed")
	if first_combo >= 0:
		assert_int(first_combo).is_greater(value_done)


func test_all_combos_come_before_all_strikes() -> void:
	var fixture: Dictionary = _fixture([PLAIN, PLAIN, PLAIN, PLAIN, PLAIN], [3, 3, 3, 4, 4], [])
	var events: Array[Dictionary] = Resolver.resolve(fixture["state"], fixture["placement"]).events
	assert_int(_last_index_of(events, "combo_formed")).is_less(_index_of(events, "strike"))


func test_no_events_after_player_died() -> void:
	var killer: Enemy = CombatFixture.dummy_enemy("KILLER", 500)
	killer.intent = Intent.new(Rules.IntentKind.ATTACK, 999)
	var fixture: Dictionary = _fixture(DEFAULT_BOARD, [3, 3, 1, 2, 5], [4], [killer])
	var result: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	var events: Array[Dictionary] = result.events
	assert_str(String(events[events.size() - 1]["t"])).is_equal("player_died")
	assert_int(result.count_of("player_died")).is_equal(1)
	assert_bool(result.has_event("round_end")).is_false()
	assert_bool(result.state_after.player_dead).is_true()


func test_thorns_can_kill_the_player_mid_chain() -> void:
	var imp: Enemy = CombatFixture.dummy_enemy("THORN_IMP", 500, 0, 50)
	var fixture: Dictionary = CombatFixture.build([PLAIN, PLAIN, PLAIN, PLAIN, PLAIN], [3, 3, 3, 3, 3], [], [imp])
	var state: CombatState = fixture["state"]
	state.player_hp = 60
	var result: ResolveResult = Resolver.resolve(state, fixture["placement"])
	var events: Array[Dictionary] = result.events
	assert_str(String(events[events.size() - 1]["t"])).is_equal("player_died")
	assert_bool(result.has_event("enemy_turn_start")).is_false()


func test_total_damage_matches_the_event_log() -> void:
	var enemy: Enemy = CombatFixture.dummy_enemy("DUMMY", 500)
	var fixture: Dictionary = _fixture(DEFAULT_BOARD, [3, 3, 1, 2, 5], [4], [enemy])
	var result: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	assert_int(CombatFixture.total_damage(result)).is_equal(result.state_after.total_damage)


# -- Kantfall i §2 -----------------------------------------------------------

func test_empty_placement_is_allowed_and_banks_every_die() -> void:
	# GAME_DESIGN §7 fråga 4: att bekräfta med tomma slots är hela poängen med
	# Charge-banken och måste fungera.
	var fixture: Dictionary = CombatFixture.build(
		DEFAULT_BOARD, [null, null, null, null, null], [1, 2, 3, 4, 5, 6],
		[CombatFixture.dummy_enemy("DUMMY", 100)])
	var result: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	assert_int(result.count_of("slot_empty")).is_equal(5)
	assert_int(result.count_of("damage_dealt")).is_equal(0)
	assert_int(result.state_after.charge).is_equal(Rules.CHARGE_CAP)  # 21 ögon, cap 20


func test_charge_is_held_when_no_slot_is_occupied() -> void:
	var fixture: Dictionary = CombatFixture.build(
		DEFAULT_BOARD, [null, null, null, null, null], [2],
		[CombatFixture.dummy_enemy("DUMMY", 100)])
	var state: CombatState = fixture["state"]
	state.charge = 6
	var result: ResolveResult = Resolver.resolve(state, fixture["placement"])
	assert_int(int(result.events_of("charge_held")[0]["amount"])).is_equal(6)
	assert_int(result.state_after.charge).is_equal(8)  # 6 kvar + oplacerad 2:a


func test_charge_lands_on_leftmost_occupied_slot_not_slot_zero() -> void:
	var fixture: Dictionary = CombatFixture.build(
		DEFAULT_BOARD, [null, null, null, 4, null], [],
		[CombatFixture.dummy_enemy("DUMMY", 100)])
	var state: CombatState = fixture["state"]
	state.charge = 5
	var result: ResolveResult = Resolver.resolve(state, fixture["placement"])
	assert_int(int(result.events_of("charge_applied")[0]["slot"])).is_equal(3)
	assert_array(result.events_of("value_pass_done")[0]["values"]).is_equal([0, 0, 0, 9, 0])


func test_blocked_slot_is_inert_and_breaks_adjacency() -> void:
	var fixture: Dictionary = CombatFixture.build(
		[PLAIN, PLAIN, PLAIN, PLAIN, PLAIN], [3, 3, 3, 3, 3], [],
		[CombatFixture.dummy_enemy("DUMMY", 1000)])
	var state: CombatState = fixture["state"]
	state.board.slots[2].blocked = true
	var result: ResolveResult = Resolver.resolve(state, fixture["placement"])
	assert_str(String(result.events_of("slot_empty")[0]["reason"])).is_equal("BLOCKED")
	assert_int(result.count_of("combo_formed")).is_equal(2)


func test_mirror_with_empty_left_neighbour_copies_zero() -> void:
	var fixture: Dictionary = CombatFixture.build(
		[PLAIN, PLAIN, MIRROR, PLAIN, PLAIN], [null, null, 6, null, null], [],
		[CombatFixture.dummy_enemy("DUMMY", 100)])
	var result: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	var failed: Array[Dictionary] = result.events_of("slot_modifier_failed")
	assert_int(failed.size()).is_equal(1)
	assert_str(String(failed[0]["reason"])).is_equal("LEFT_NEIGHBOUR_EMPTY")
	assert_int(result.count_of("damage_dealt")).is_equal(0)


func test_two_mirrors_in_a_row_chain() -> void:
	var fixture: Dictionary = CombatFixture.build(
		[PLAIN, MIRROR, MIRROR, PLAIN, PLAIN], [4, 1, 1, null, null], [],
		[CombatFixture.dummy_enemy("DUMMY", 1000)])
	var result: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	assert_array(result.events_of("value_pass_done")[0]["values"]).is_equal([4, 4, 4, 0, 0])
	assert_str(String(result.events_of("combo_formed")[0]["kind"])).is_equal("TRIPLE")


func test_anvil_slot_and_anvil_self_face_stack() -> void:
	# En 5:a i ANVIL-slot med HAMMER_FACE-liknande sida: 5 -> 10 -> 20.
	var face: Face = Face.new("HAMMER_FACE", 5, Rules.FaceEffectKind.ANVIL_SELF, 0)
	var fixture: Dictionary = CombatFixture.build(
		[ANVIL, PLAIN, PLAIN, PLAIN, PLAIN], [face, null, null, null, null], [],
		[CombatFixture.dummy_enemy("DUMMY", 1000)])
	var result: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	assert_array(result.events_of("value_pass_done")[0]["values"]).is_equal([20, 0, 0, 0, 0])
	assert_int(result.count_of("slot_modifier")).is_equal(2)


func test_anvil_self_below_threshold_fails_twice() -> void:
	var face: Face = Face.new("HAMMER_FACE", 3, Rules.FaceEffectKind.ANVIL_SELF, 0)
	var fixture: Dictionary = CombatFixture.build(
		[ANVIL, PLAIN, PLAIN, PLAIN, PLAIN], [face, null, null, null, null], [],
		[CombatFixture.dummy_enemy("DUMMY", 1000)])
	var result: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	assert_array(result.events_of("value_pass_done")[0]["values"]).is_equal([3, 0, 0, 0, 0])
	assert_int(result.count_of("slot_modifier_failed")).is_equal(2)


func test_damage_below_armor_stops_the_chain() -> void:
	var wall: Enemy = CombatFixture.dummy_enemy("WALL", 50, 10)
	var fixture: Dictionary = CombatFixture.build(
		[PLAIN, PLAIN, PLAIN, PLAIN, PLAIN], [3, null, null, null, null], [],
		[wall, CombatFixture.dummy_enemy("BEHIND", 10)])
	var result: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	var hit: Dictionary = result.events_of("damage_dealt")[0]
	assert_int(int(hit["amount"])).is_equal(0)
	assert_int(int(hit["blocked"])).is_equal(3)
	assert_int(int(hit["overflow"])).is_equal(0)
	assert_int(result.count_of("damage_dealt")).is_equal(1)
	assert_int(result.state_after.enemies[1].hp).is_equal(10)


func test_overflow_without_a_target_becomes_half_charge() -> void:
	var fixture: Dictionary = CombatFixture.build(
		[PLAIN, PLAIN, PLAIN, PLAIN, PLAIN], [9, null, null, null, null], [],
		[CombatFixture.dummy_enemy("PAPER", 1)])
	var result: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	assert_int(int(result.events_of("overflow_wasted")[0]["amount"])).is_equal(8)
	assert_int(result.state_after.charge).is_equal(4)


func test_void_slot_converts_damage_to_ward() -> void:
	var fixture: Dictionary = CombatFixture.build(
		[VOID, PLAIN, PLAIN, PLAIN, PLAIN], [6, null, null, null, null], [],
		[CombatFixture.dummy_enemy("DUMMY", 100)])
	var result: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	assert_int(int(result.events_of("ward_gained")[0]["amount"])).is_equal(6)
	assert_int(result.count_of("damage_dealt")).is_equal(0)


func test_charge_slot_banks_the_multiplied_amount() -> void:
	var fixture: Dictionary = CombatFixture.build(
		[CHARGE, CHARGE, PLAIN, PLAIN, PLAIN], [4, 4, null, null, null], [],
		[CombatFixture.dummy_enemy("DUMMY", 100)])
	var result: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	assert_int(result.count_of("damage_dealt")).is_equal(0)
	assert_int(result.state_after.charge).is_equal(16)  # 4*2 + 4*2


func test_fire_slot_applies_burn_that_ticks_and_decays() -> void:
	var enemy: Enemy = CombatFixture.dummy_enemy("DUMMY", 100)
	var fixture: Dictionary = CombatFixture.build(
		[FIRE, PLAIN, PLAIN, PLAIN, PLAIN], [3, null, null, null, null], [], [enemy])
	var result: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	assert_int(int(result.events_of("status_applied")[0]["stacks"])).is_equal(2)
	var tick: Dictionary = result.events_of("status_ticked")[0]
	assert_str(String(tick["status"])).is_equal("BURN")
	assert_int(int(tick["amount"])).is_equal(2)
	assert_int(int(tick["stacks_after"])).is_equal(1)
	assert_int(result.state_after.enemies[0].burn).is_equal(1)
	assert_int(result.state_after.enemies[0].hp).is_equal(95)  # 100 - 3 - 2


func test_fire_without_a_hit_applies_no_burn() -> void:
	var fixture: Dictionary = CombatFixture.build(
		[FIRE, PLAIN, PLAIN, PLAIN, PLAIN], [3, null, null, null, null], [],
		[CombatFixture.dummy_enemy("WALL", 50, 10)])
	var result: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	assert_bool(result.has_event("status_applied")).is_false()


func test_poison_does_not_decay_and_never_overflows() -> void:
	var face: Face = Face.new("POISON_DROP", 2, Rules.FaceEffectKind.APPLY_POISON, 2)
	var front: Enemy = CombatFixture.dummy_enemy("FRONT", 4)
	var fixture: Dictionary = CombatFixture.build(
		[PLAIN, PLAIN, PLAIN, PLAIN, PLAIN], [face, null, null, null, null], [],
		[front, CombatFixture.dummy_enemy("BACK", 20)])
	var result: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	assert_int(result.state_after.enemies[0].poison).is_equal(2)
	assert_int(result.state_after.enemies[0].hp).is_equal(0)  # 4 - 2 - 2, tickar inte över
	assert_int(result.state_after.enemies[1].hp).is_equal(20)


func test_unplaced_grow_face_increases_permanently() -> void:
	var snowball: Face = Face.new("SNOWBALL", 1, Rules.FaceEffectKind.GROW, 1)
	var fixture: Dictionary = CombatFixture.build(
		DEFAULT_BOARD, [null, null, null, null, null], [snowball],
		[CombatFixture.dummy_enemy("DUMMY", 100)])
	var result: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	assert_int(int(result.events_of("face_grew")[0]["new_value"])).is_equal(2)
	# Charge lagrades FÖRE växten: 1, inte 2.
	assert_int(result.state_after.charge).is_equal(1)


func test_octopus_relic_adds_the_virtual_edge_one_three() -> void:
	var fixture: Dictionary = CombatFixture.build(
		[PLAIN, PLAIN, PLAIN, PLAIN, PLAIN], [null, 5, 2, 5, null], [],
		[CombatFixture.dummy_enemy("DUMMY", 1000)])
	var state: CombatState = fixture["state"]
	var without: ResolveResult = Resolver.resolve(state, fixture["placement"])
	assert_int(without.count_of("combo_formed")).is_equal(0)

	state.relics = [Content.make_relic("OCTOPUS")]
	var with_relic: ResolveResult = Resolver.resolve(state, fixture["placement"])
	assert_int(with_relic.count_of("combo_formed")).is_equal(1)
	assert_array(with_relic.events_of("combo_formed")[0]["slots"]).is_equal([1, 3])


func test_broken_scale_relic_rounds_odd_values_up() -> void:
	var fixture: Dictionary = CombatFixture.build(
		[PLAIN, PLAIN, PLAIN, PLAIN, PLAIN], [3, 4, null, null, null], [],
		[CombatFixture.dummy_enemy("DUMMY", 1000)])
	var state: CombatState = fixture["state"]
	state.relics = [Content.make_relic("BROKEN_SCALE")]
	var result: ResolveResult = Resolver.resolve(state, fixture["placement"])
	assert_array(result.events_of("value_pass_done")[0]["values"]).is_equal([4, 4, 0, 0, 0])
	assert_str(String(result.events_of("combo_formed")[0]["kind"])).is_equal("PAIR")


func test_blood_price_costs_hp_and_doubles_multipliers() -> void:
	var fixture: Dictionary = CombatFixture.build(
		[PLAIN, PLAIN, PLAIN, PLAIN, PLAIN], [3, 3, null, null, null], [],
		[CombatFixture.dummy_enemy("DUMMY", 1000)])
	var state: CombatState = fixture["state"]
	state.relics = [Content.make_relic("BLOOD_PRICE")]
	var result: ResolveResult = Resolver.resolve(state, fixture["placement"])
	assert_int(int(result.events_of("player_damaged")[0]["amount"])).is_equal(4)
	assert_int(int(result.events_of("strike")[0]["multiplier"])).is_equal(4)  # PAIR x2 x2


func test_blood_price_does_not_trigger_without_a_combo() -> void:
	var fixture: Dictionary = CombatFixture.build(
		[PLAIN, PLAIN, PLAIN, PLAIN, PLAIN], [3, 4, null, null, null], [],
		[CombatFixture.dummy_enemy("DUMMY", 1000)])
	var state: CombatState = fixture["state"]
	state.relics = [Content.make_relic("BLOOD_PRICE")]
	var result: ResolveResult = Resolver.resolve(state, fixture["placement"])
	assert_bool(result.has_event("player_damaged")).is_false()


# -- advance(): all slump dras före rundan -----------------------------------

func test_advance_is_seeded_and_reproducible() -> void:
	var state: CombatState = Content.smith_state()
	state.enemies = Content.encounter(2)
	var a: CombatState = Resolver.begin_combat(state, Rng.new(777))
	var b: CombatState = Resolver.begin_combat(state, Rng.new(777))
	assert_str(JSON.stringify(a.to_dict())).is_equal(JSON.stringify(b.to_dict()))
	var c: CombatState = Resolver.begin_combat(state, Rng.new(778))
	assert_str(JSON.stringify(c.to_dict())).is_not_equal(JSON.stringify(a.to_dict()))


func test_advance_clears_the_placement_and_rolls_every_die() -> void:
	var state: CombatState = Content.smith_state()
	state.enemies = Content.encounter(1)
	var ready: CombatState = Resolver.begin_combat(state, Rng.new(1))
	for value: int in ready.placement:
		assert_int(value).is_equal(-1)
	for enemy: Enemy in ready.enemies:
		assert_object(enemy.intent).is_not_null()


func _index_of(events: Array[Dictionary], t: String) -> int:
	for i: int in range(events.size()):
		if String(events[i]["t"]) == t:
			return i
	return -1


func _last_index_of(events: Array[Dictionary], t: String) -> int:
	for i: int in range(events.size() - 1, -1, -1):
		if String(events[i]["t"]) == t:
			return i
	return -1
