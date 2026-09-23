extends GdUnitTestSuite
## Gear-effekterna i resolvern (M6 steg 2). En test per effekt, headless och
## seedat. Läsbarhetslag 1 (PROGRESSION_REDESIGN §3.2): varje effekt som ändrar
## rundan syns som ett [code]gear_triggered[/code]-event och som en rad i kvittot.

const PLAIN: int = Rules.SlotType.PLAIN
const ANVIL: int = Rules.SlotType.ANVIL
const VOID: int = Rules.SlotType.VOID
const MIRROR: int = Rules.SlotType.MIRROR


func _gear(state: CombatState, ids: Array) -> void:
	var items: Array[Item] = []
	for id: Variant in ids:
		var item: Item = Content.make_item(String(id))
		if item == null:
			item = Content.quirk_item(String(id))
		items.append(item)
	state.gear = items


func _attacker(id: String, hp: int, attack: int, armor: int = 0) -> Enemy:
	var enemy: Enemy = Enemy.new(id, hp, attack, id)
	enemy.armor = armor
	enemy.intent = Intent.new(Rules.IntentKind.ATTACK, attack)
	return enemy


func _triggers(result: ResolveResult, effect: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event: Dictionary in result.events_of("gear_triggered"):
		if String(event["effect"]) == effect:
			out.append(event)
	return out


func _receipt(state: CombatState, result: ResolveResult) -> Dictionary:
	return ChainReceipt.build(result.events, state.enemies, state.board)


# --- Grundlöften ---------------------------------------------------------------

func test_without_gear_the_log_has_no_gear_events() -> void:
	var fixture: Dictionary = CombatFixture.build([PLAIN, PLAIN, MIRROR, PLAIN, ANVIL],
		[2, 3, 4, 1, 6], [5], [CombatFixture.dummy_enemy("RUST_RAT", 14)])
	var result: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	assert_int(result.count_of("gear_triggered")).is_equal(0)


func test_gear_keeps_resolve_pure_and_the_preview_equal_to_the_outcome() -> void:
	var fixture: Dictionary = CombatFixture.build([PLAIN, PLAIN, MIRROR, PLAIN, ANVIL],
		[1, 3, 4, 1, 6], [5, 2], [_attacker("RUST_RAT", 30, 4, 2), _attacker("IRON_TICK", 40, 5, 6)])
	var state: CombatState = fixture["state"]
	_gear(state, ["PIPSIGHT_LENS", "SLAG_PLATE", "CHIPPED_HAMMER", "BONE_TALLY", "DICE_POUCH", "DOMINO"])
	var before: String = JSON.stringify(state.to_dict())
	var a: ResolveResult = Resolver.resolve(state, fixture["placement"])
	var b: ResolveResult = Resolver.resolve(state, fixture["placement"])
	assert_str(a.events_json()).is_equal(b.events_json())
	assert_str(JSON.stringify(state.to_dict())).is_equal(before)


func test_resolve_with_gear_still_takes_no_rng_and_seq_is_contiguous() -> void:
	var fixture: Dictionary = CombatFixture.build([PLAIN, PLAIN, PLAIN, PLAIN, PLAIN],
		[1, 1, 6, 6, 3], [2], [_attacker("RUST_RAT", 20, 3, 1)])
	var state: CombatState = fixture["state"]
	_gear(state, ["TWIN_PIP", "RUST_GREAVES", "MOTH_EDGE", "HEAVY_HANDED"])
	var result: ResolveResult = Resolver.resolve(state, fixture["placement"])
	for i: int in range(result.events.size()):
		assert_int(int(result.events[i]["seq"])).is_equal(i)
	assert_str(String(result.events[0]["t"])).is_equal("round_start")


# --- En test per effekt ----------------------------------------------------------

func test_pipsight_lens_turns_ones_into_twos_and_says_so() -> void:
	var fixture: Dictionary = CombatFixture.build([PLAIN, PLAIN, PLAIN, PLAIN, PLAIN],
		[1, null, null, null, null], [], [CombatFixture.dummy_enemy("RUST_RAT", 30)])
	var state: CombatState = fixture["state"]
	_gear(state, ["PIPSIGHT_LENS"])
	var result: ResolveResult = Resolver.resolve(state, fixture["placement"])
	assert_array(result.events_of("value_pass_done")[0]["values"]).is_equal([2, 0, 0, 0, 0])
	var fired: Array[Dictionary] = _triggers(result, GearRules.PIP_BONUS)
	assert_int(fired.size()).is_equal(1)
	assert_str(String(fired[0]["item"])).is_equal("PIPSIGHT_LENS")
	var line: Dictionary = (_receipt(state, result)["gear"] as Array)[0]
	assert_str(String(line["name_key"])).is_equal("GEAR_PIPSIGHT_LENS")
	assert_str(String(line["text_key"])).is_equal("GEAR_FX_PIP_BONUS")
	assert_array(line["args"] as Array).is_equal([1, 1])


func test_slag_plate_takes_two_off_every_attack() -> void:
	var fixture: Dictionary = CombatFixture.build([PLAIN, PLAIN, PLAIN, PLAIN, PLAIN],
		[], [], [_attacker("RUST_RAT", 30, 5)])
	var state: CombatState = fixture["state"]
	_gear(state, ["SLAG_PLATE"])
	var result: ResolveResult = Resolver.resolve(state, fixture["placement"])
	var attack: Dictionary = result.events_of("enemy_attacks")[0]
	assert_int(int(attack["amount"])).is_equal(3)
	assert_int(int(attack["armor_used"])).is_equal(2)
	assert_int(result.state_after.player_hp).is_equal(40 - 3)
	assert_int(_triggers(result, GearRules.PLAYER_ARMOR).size()).is_equal(1)


func test_tick_carapace_keeps_half_the_ward() -> void:
	var fixture: Dictionary = CombatFixture.build([VOID, PLAIN, PLAIN, PLAIN, PLAIN],
		[5, null, null, null, null], [], [_attacker("RUST_RAT", 30, 0)])
	var state: CombatState = fixture["state"]
	_gear(state, ["TICK_CARAPACE"])
	var result: ResolveResult = Resolver.resolve(state, fixture["placement"])
	assert_int(result.state_after.ward).is_equal(2)
	assert_int(_triggers(result, GearRules.WARD_RETAIN).size()).is_equal(1)
	var next: ResolveResult = Resolver.resolve(result.state_after, CombatState.empty_placement(5))
	assert_int(int(next.events[0]["ward_in"])).is_equal(2)


func test_kiln_vest_pays_charge_only_for_an_unhurt_round() -> void:
	var calm: Dictionary = CombatFixture.build([PLAIN, PLAIN, PLAIN, PLAIN, PLAIN],
		[], [], [_attacker("RUST_RAT", 30, 0)])
	_gear(calm["state"], ["KILN_VEST"])
	var ok: ResolveResult = Resolver.resolve(calm["state"], calm["placement"])
	assert_int(ok.state_after.charge).is_equal(4)
	var hurt: Dictionary = CombatFixture.build([PLAIN, PLAIN, PLAIN, PLAIN, PLAIN],
		[], [], [_attacker("RUST_RAT", 30, 3)])
	_gear(hurt["state"], ["KILN_VEST"])
	var no: ResolveResult = Resolver.resolve(hurt["state"], hurt["placement"])
	assert_int(no.state_after.charge).is_equal(0)
	assert_int(_triggers(no, GearRules.CHARGE_IF_UNHURT).size()).is_equal(0)


func test_tong_gloves_let_the_anvil_double_a_four() -> void:
	var fixture: Dictionary = CombatFixture.build([PLAIN, PLAIN, PLAIN, PLAIN, ANVIL],
		[null, null, null, null, 4], [], [CombatFixture.dummy_enemy("RUST_RAT", 30)])
	var plain: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	assert_int(int(plain.events_of("value_pass_done")[0]["values"][4])).is_equal(4)
	_gear(fixture["state"], ["TONG_GLOVES"])
	var gloved: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	assert_int(int(gloved.events_of("value_pass_done")[0]["values"][4])).is_equal(8)
	assert_int(_triggers(gloved, GearRules.ANVIL_THRESHOLD).size()).is_equal(1)


func test_thiefs_mitts_add_two_to_the_leftmost_placed_die() -> void:
	var fixture: Dictionary = CombatFixture.build([PLAIN, PLAIN, PLAIN, PLAIN, PLAIN],
		[null, 3, 2, null, null], [], [CombatFixture.dummy_enemy("RUST_RAT", 30)])
	_gear(fixture["state"], ["THIEFS_MITTS"])
	var result: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	assert_array(result.events_of("value_pass_done")[0]["values"]).is_equal([0, 5, 2, 0, 0])
	assert_int(int(_triggers(result, GearRules.LEFTMOST_BONUS)[0]["detail"]["slot"])).is_equal(1)


func test_chipped_hammer_pierces_two_armor_on_slot_five() -> void:
	var fixture: Dictionary = CombatFixture.build([PLAIN, PLAIN, PLAIN, PLAIN, PLAIN],
		[null, null, null, 3, 6], [], [CombatFixture.dummy_enemy("IRON_TICK", 60, 3)])
	_gear(fixture["state"], ["CHIPPED_HAMMER"])
	var result: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	var hits: Array[Dictionary] = result.events_of("damage_dealt")
	assert_int(int(hits[0]["blocked"])).override_failure_message("slot 4 har ingen hammare").is_equal(3)
	assert_int(int(hits[1]["blocked"])).is_equal(1)
	assert_int(int(hits[1]["amount"])).is_equal(5)
	var fired: Array[Dictionary] = _triggers(result, GearRules.ARMOR_PIERCE_SLOT)
	assert_int(int(fired[0]["detail"]["ignored"])).is_equal(2)
	assert_bool(ChainReceipt.balances(_receipt(fixture["state"], result))).is_true()


func test_spike_maul_pierces_only_the_biggest_hit() -> void:
	var fixture: Dictionary = CombatFixture.build([PLAIN, PLAIN, PLAIN, PLAIN, PLAIN],
		[4, null, 6, null, null], [], [CombatFixture.dummy_enemy("IRON_TICK", 60, 3)])
	_gear(fixture["state"], ["SPIKE_MAUL"])
	var result: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	var hits: Array[Dictionary] = result.events_of("damage_dealt")
	assert_int(int(hits[0]["blocked"])).is_equal(3)
	assert_int(int(hits[1]["blocked"])).is_equal(0)
	assert_int(int(_triggers(result, GearRules.ARMOR_PIERCE_BIGGEST)[0]["detail"]["slot"])).is_equal(2)


func test_moth_edge_banks_three_charge_per_kill() -> void:
	var fixture: Dictionary = CombatFixture.build([PLAIN, PLAIN, PLAIN, PLAIN, PLAIN],
		[6, null, null, null, null], [], [CombatFixture.dummy_enemy("RUST_RAT", 4), CombatFixture.dummy_enemy("RUST_RAT", 50)])
	_gear(fixture["state"], ["MOTH_EDGE"])
	var result: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	var gear_charge: int = 0
	for event: Dictionary in result.events_of("charge_stored"):
		if String(event["source"]) == "GEAR":
			gear_charge += int(event["amount"])
	assert_int(gear_charge).is_equal(3)
	assert_int(result.state_after.kills).is_equal(1)


func test_slagjaws_tooth_lets_overflow_ignore_armor() -> void:
	var fixture: Dictionary = CombatFixture.build([PLAIN, PLAIN, PLAIN, PLAIN, PLAIN],
		[9, null, null, null, null], [], [CombatFixture.dummy_enemy("RUST_RAT", 3), CombatFixture.dummy_enemy("IRON_TICK", 50, 4)])
	var plain: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	assert_int(int(plain.events_of("damage_dealt")[1]["amount"])).is_equal(2)
	_gear(fixture["state"], ["SLAGJAW_TOOTH"])
	var tooth: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	assert_int(int(tooth.events_of("damage_dealt")[1]["amount"])).is_equal(6)
	assert_int(int(tooth.events_of("damage_dealt")[1]["blocked"])).is_equal(0)
	assert_int(_triggers(tooth, GearRules.OVERFLOW_IGNORES_ARMOR).size()).is_equal(1)


func test_rust_greaves_add_ward_that_the_receipt_keeps_out_of_the_chain() -> void:
	var fixture: Dictionary = CombatFixture.build([PLAIN, PLAIN, PLAIN, PLAIN, PLAIN],
		[3, null, null, null, null], [], [_attacker("RUST_RAT", 30, 2)])
	_gear(fixture["state"], ["RUST_GREAVES"])
	var result: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	assert_int(int(result.events_of("enemy_attacks")[0]["amount"])).is_equal(0)
	assert_int(int(result.events_of("ward_gained")[0]["slot"])).is_equal(-1)
	var receipt: Dictionary = _receipt(fixture["state"], result)
	assert_bool(ChainReceipt.balances(receipt)).is_true()
	assert_int(int(receipt["ward"])).is_equal(0)


func test_cart_boots_start_the_fight_with_charge_and_round_one_says_so() -> void:
	var state: CombatState = Content.smith_state()
	state.enemies = Content.encounter(1)
	_gear(state, ["CART_BOOTS"])
	var started: CombatState = Resolver.begin_combat(state, Rng.new(4))
	assert_int(started.charge).is_equal(5)
	var result: ResolveResult = Resolver.resolve(started, CombatState.empty_placement(5))
	assert_int(_triggers(result, GearRules.START_CHARGE).size()).is_equal(1)


func test_pit_striders_roll_seven_dice_in_round_one_only() -> void:
	var state: CombatState = Content.smith_state()
	state.enemies = Content.encounter(1)
	_gear(state, ["PIT_STRIDERS"])
	var started: CombatState = Resolver.begin_combat(state, Rng.new(4))
	assert_int(started.dice.size()).is_equal(7)
	var result: ResolveResult = Resolver.resolve(started, CombatState.empty_placement(5))
	var next: CombatState = Resolver.advance(result.state_after, Rng.new(5))
	assert_int(next.dice.size()).is_equal(6)
	assert_int(Resolver.end_combat(started).dice.size()).is_equal(6)


func test_no_gear_draws_the_same_randomness_as_before() -> void:
	# Utan gear får begin_combat inte dra ett enda extra tal: gamla seeds ska ge
	# samma kast (sparfilsgarantin i CORRIDOR_DEV_NOTES §4.9).
	var state: CombatState = Content.smith_state()
	state.enemies = Content.encounter(1)
	var a: CombatState = Resolver.begin_combat(state, Rng.new(99))
	var b: CombatState = Resolver.begin_combat(state.copy(), Rng.new(99))
	assert_str(JSON.stringify(a.to_dict())).is_equal(JSON.stringify(b.to_dict()))
	assert_int(a.rerolls_left).is_equal(state.rerolls_left)


func test_dice_pouch_adds_a_charge_per_unplaced_die() -> void:
	var fixture: Dictionary = CombatFixture.build([PLAIN, PLAIN, PLAIN, PLAIN, PLAIN],
		[], [2, 3], [CombatFixture.dummy_enemy("RUST_RAT", 30)])
	_gear(fixture["state"], ["DICE_POUCH"])
	var result: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	assert_int(result.state_after.charge).is_equal(2 + 3 + 2)


func test_chalk_satchel_raises_the_charge_cap_to_32() -> void:
	var fixture: Dictionary = CombatFixture.build([PLAIN, PLAIN, PLAIN, PLAIN, PLAIN],
		[], [6, 6, 6, 6, 6], [CombatFixture.dummy_enemy("RUST_RAT", 30)])
	var plain: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	assert_int(plain.state_after.charge).is_equal(Rules.CHARGE_CAP)
	_gear(fixture["state"], ["CHALK_SATCHEL"])
	var satchel: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	assert_int(satchel.state_after.charge).is_equal(30)
	assert_int(_triggers(satchel, GearRules.CHARGE_CAP).size()).is_greater_equal(1)


func test_bone_tally_adds_one_per_enemy_already_killed() -> void:
	var fixture: Dictionary = CombatFixture.build([PLAIN, PLAIN, PLAIN, PLAIN, PLAIN],
		[3, null, null, null, null], [], [CombatFixture.dummy_enemy("RUST_RAT", 30)])
	var state: CombatState = fixture["state"]
	state.kills = 2
	_gear(state, ["BONE_TALLY"])
	var result: ResolveResult = Resolver.resolve(state, fixture["placement"])
	assert_int(int(result.events_of("strike")[0]["amount"])).is_equal(5)
	assert_int(int(_triggers(result, GearRules.DAMAGE_PER_KILL)[0]["detail"]["amount"])).is_equal(2)
	assert_bool(ChainReceipt.balances(_receipt(state, result))).is_true()


func test_twin_pip_makes_two_pairs_a_house() -> void:
	var fixture: Dictionary = CombatFixture.build([PLAIN, PLAIN, PLAIN, PLAIN, PLAIN],
		[3, 3, null, 5, 5], [], [CombatFixture.dummy_enemy("RUST_RAT", 300)])
	var plain: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	assert_int(plain.count_of("house_bonus")).is_equal(0)
	_gear(fixture["state"], ["TWIN_PIP"])
	var twin: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	assert_int(twin.count_of("house_bonus")).is_equal(1)
	assert_int(_triggers(twin, GearRules.HOUSE_TWO_PAIR).size()).is_equal(1)
	assert_array(twin.events_of("house_bonus")[0]["multipliers_after"]).is_equal([4, 4, 1, 4, 4])


func test_sixth_seat_gives_the_board_a_sixth_slot_and_takes_it_back() -> void:
	var state: CombatState = Content.smith_state()
	var hero: Hero = Hero.new("h1", "A")
	hero.level = 5
	hero.equip(Content.make_item("SIXTH_SEAT"))
	var worn: CombatState = GearRules.sync_combat(state, hero)
	assert_int(worn.board.size()).is_equal(6)
	assert_int(worn.placement.size()).is_equal(6)
	var enemies: Array[Enemy] = [CombatFixture.dummy_enemy("RUST_RAT", 100)]
	worn.enemies = enemies
	var placement: PackedInt32Array = PackedInt32Array([0, 1, -1, -1, -1, 2])
	var result: ResolveResult = Resolver.resolve(worn, placement)
	assert_int((result.events_of("value_pass_done")[0]["values"] as Array).size()).is_equal(6)
	hero.unequip("AMULET")
	assert_int(GearRules.sync_combat(worn, hero).board.size()).is_equal(5)


func test_scrap_cap_raises_max_hp_while_worn() -> void:
	var state: CombatState = Content.smith_state()
	var hero: Hero = Hero.new("h1", "A")
	hero.level = 2
	hero.equip(Content.make_item("SCRAP_CAP"))
	var worn: CombatState = GearRules.sync_combat(state, hero)
	assert_int(worn.player_max_hp).is_equal(106)
	assert_int(worn.player_hp).is_equal(106)
	hero.unequip("HEAD")
	var bare: CombatState = GearRules.sync_combat(worn, hero)
	assert_int(bare.player_max_hp).is_equal(100)
	assert_int(bare.player_hp).is_equal(100)


func test_grip_wraps_give_one_reroll_for_the_whole_fight() -> void:
	var state: CombatState = Content.smith_state()
	state.enemies = Content.encounter(1)
	_gear(state, ["GRIP_WRAPS"])
	var started: CombatState = Resolver.begin_combat(state, Rng.new(8))
	assert_int(started.rerolls_left).is_equal(2)
	# Rundan använder inget omkast: det extra ligger kvar till nästa runda.
	var kept: CombatState = Resolver.advance(Resolver.resolve(started, CombatState.empty_placement(5)).state_after, Rng.new(9))
	assert_int(kept.rerolls_left).is_equal(2)
	# Rundan använder båda: det extra är slut.
	var spent: CombatState = started.copy()
	spent.rerolls_left = 0
	var after: CombatState = Resolver.advance(Resolver.resolve(spent, CombatState.empty_placement(5)).state_after, Rng.new(9))
	assert_int(after.rerolls_left).is_equal(1)


func test_tallow_hood_adds_a_reroll_to_round_one_only() -> void:
	var state: CombatState = Content.smith_state()
	state.enemies = Content.encounter(1)
	_gear(state, ["TALLOW_HOOD"])
	var started: CombatState = Resolver.begin_combat(state, Rng.new(8))
	assert_int(started.rerolls_left).is_equal(2)
	var next: CombatState = Resolver.advance(Resolver.resolve(started, CombatState.empty_placement(5)).state_after, Rng.new(9))
	assert_int(next.rerolls_left).is_equal(1)


func test_a_converted_relic_fires_its_old_rule_and_names_its_item() -> void:
	var fixture: Dictionary = CombatFixture.build([PLAIN, PLAIN, PLAIN, PLAIN, PLAIN],
		[2, 6, 3, null, null], [], [CombatFixture.dummy_enemy("RUST_RAT", 300)])
	_gear(fixture["state"], ["DOMINO"])
	var result: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	var relic: Array[Dictionary] = result.events_of("relic_triggered")
	assert_int(relic.size()).is_equal(1)
	assert_str(String(relic[0]["item"])).is_equal("DOMINO")
	var receipt: Dictionary = _receipt(fixture["state"], result)
	assert_str(String((receipt["gear"] as Array)[0]["text_key"])).is_equal("GEAR_DOMINO_DESC")
	assert_bool(ChainReceipt.balances(receipt)).is_true()


func test_heavy_handed_quirk_bends_sixes_up_and_ones_down() -> void:
	var fixture: Dictionary = CombatFixture.build([PLAIN, PLAIN, PLAIN, PLAIN, PLAIN],
		[6, null, 1, null, null], [], [CombatFixture.dummy_enemy("RUST_RAT", 300)])
	_gear(fixture["state"], ["HEAVY_HANDED"])
	var result: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	assert_array(result.events_of("value_pass_done")[0]["values"]).is_equal([7, 0, 0, 0, 0])
	assert_str(String(_triggers(result, GearRules.PIP_BONUS)[0]["name_key"])).is_equal("HERO_QUIRK_HEAVY_HANDED")


func test_hoarder_quirk_banks_two_a_round_under_a_lower_cap() -> void:
	var fixture: Dictionary = CombatFixture.build([PLAIN, PLAIN, PLAIN, PLAIN, PLAIN],
		[], [6, 6, 6], [CombatFixture.dummy_enemy("RUST_RAT", 30)])
	_gear(fixture["state"], ["HOARDER"])
	var result: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	assert_int(result.state_after.charge).is_equal(Rules.CHARGE_CAP - 5)
	assert_int(_triggers(result, GearRules.CHARGE_PER_ROUND).size()).is_equal(1)


func test_right_handed_quirk_leans_on_slot_five() -> void:
	var fixture: Dictionary = CombatFixture.build([PLAIN, PLAIN, PLAIN, PLAIN, PLAIN],
		[3, null, null, null, 3], [], [CombatFixture.dummy_enemy("RUST_RAT", 300)])
	_gear(fixture["state"], ["RIGHT_HANDED"])
	var result: ResolveResult = Resolver.resolve(fixture["state"], fixture["placement"])
	assert_array(result.events_of("value_pass_done")[0]["values"]).is_equal([2, 0, 0, 0, 5])


func test_fifty_seeded_positions_with_a_full_kit_still_add_up() -> void:
	var kit: Array = ["PIPSIGHT_LENS", "SLAG_PLATE", "CHIPPED_HAMMER", "MOTH_EDGE", "RUST_GREAVES",
		"DICE_POUCH", "BONE_TALLY", "TWIN_PIP", "TONG_GLOVES", "RIGHT_HANDED"]
	for seed_value: int in range(50):
		var rng: Rng = Rng.new(seed_value)
		var state: CombatState = Content.smith_state()
		state.enemies = Content.encounter(1 + seed_value % 3, seed_value % 2)
		_gear(state, kit)
		state = Resolver.begin_combat(state, rng)
		state.kills = seed_value % 3
		var placement: PackedInt32Array = Policy.lookahead(state)
		var result: ResolveResult = Resolver.resolve(state, placement)
		var receipt: Dictionary = ChainReceipt.build(result.events, state.enemies, state.board)
		assert_bool(ChainReceipt.balances(receipt)).override_failure_message(
			"seed %d: kvittot går inte ihop med gear" % seed_value).is_true()
		assert_str(result.events_json()).is_equal(Resolver.resolve(state, placement).events_json())
