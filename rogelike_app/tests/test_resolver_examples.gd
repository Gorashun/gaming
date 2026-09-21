extends GdUnitTestSuite
## De åtta räkneexemplen i docs/GAME_DESIGN.md §2.4, ett test per exempel.
## Ändras ett förväntat tal här är det ett designbeslut, inte en buggfix.

const PLAIN := Rules.SlotType.PLAIN
const FIRE := Rules.SlotType.FIRE
const MIRROR := Rules.SlotType.MIRROR
const ANVIL := Rules.SlotType.ANVIL
const VOID := Rules.SlotType.VOID
const CHARGE := Rules.SlotType.CHARGE

## Standardbrädet som §2.4 utgår från om inget annat sägs.
const DEFAULT_BOARD: Array = [PLAIN, PLAIN, MIRROR, FIRE, ANVIL]


func _strike_damage(result: ResolveResult) -> int:
	var total: int = 0
	for event: Dictionary in result.events_of("damage_dealt"):
		total += int(event["amount"])
	return total


func _resolve(board: Array, slots: Array, unplaced: Array, enemies: Array, charge: int = 0) -> ResolveResult:
	var fixture: Dictionary = CombatFixture.build(board, slots, unplaced, enemies)
	var state: CombatState = fixture["state"]
	state.charge = charge
	return Resolver.resolve(state, fixture["placement"])


# -- Exempel 1: baskedja, par via spegel, kill + spill utan mål ---------------
func test_example_1_base_chain_pair_via_mirror() -> void:
	var result: ResolveResult = _resolve(
		DEFAULT_BOARD, [2, 3, 4, 1, 6], [5],
		[CombatFixture.dummy_enemy("RUST_RAT", 14)])

	assert_array(result.events_of("value_pass_done")[0]["values"]).is_equal([2, 3, 3, 1, 12])
	assert_int(result.count_of("combo_formed")).is_equal(1)
	assert_str(String(result.events_of("combo_formed")[0]["kind"])).is_equal("PAIR")
	assert_int(int(result.events_of("combo_formed")[0]["multiplier"])).is_equal(2)
	assert_int(_strike_damage(result)).is_equal(14)
	assert_bool(result.has_event("combat_won")).is_true()
	# Spill 1 ger 0 Charge, spill 12 ger 6, oplacerad 5:a ger 5.
	assert_int(result.state_after.charge).is_equal(11)


# -- Exempel 2: spegel på slot 0 fizzlar -------------------------------------
func test_example_2_mirror_on_slot_zero_fizzles() -> void:
	var result: ResolveResult = _resolve(
		[MIRROR, PLAIN, PLAIN, PLAIN, PLAIN], [5, null, null, null, null], [],
		[CombatFixture.dummy_enemy("RUST_RAT", 14)])

	var failed: Array[Dictionary] = result.events_of("slot_modifier_failed")
	assert_int(failed.size()).is_equal(1)
	assert_str(String(failed[0]["reason"])).is_equal("NO_LEFT_NEIGHBOUR")
	assert_array(result.events_of("value_pass_done")[0]["values"]).is_equal([0, 0, 0, 0, 0])
	assert_int(_strike_damage(result)).is_equal(0)
	assert_int(result.count_of("damage_dealt")).is_equal(0)
	# die_activated emitteras ändå: UI ska visa fizzeln.
	assert_int(result.count_of("die_activated")).is_equal(1)
	assert_int(int(result.events_of("strike")[0]["amount"])).is_equal(0)


# -- Exempel 3: amboss under tröskeln ----------------------------------------
func test_example_3_anvil_below_threshold() -> void:
	var result: ResolveResult = _resolve(
		DEFAULT_BOARD, [null, null, null, null, 4], [],
		[CombatFixture.dummy_enemy("RUST_RAT", 14)])

	assert_int(_strike_damage(result)).is_equal(4)
	var failed: Array[Dictionary] = result.events_of("slot_modifier_failed")
	assert_int(failed.size()).is_equal(1)
	assert_str(String(failed[0]["modifier"])).is_equal("ANVIL")
	assert_str(String(failed[0]["reason"])).is_equal("VALUE_BELOW_5")
	for event: Dictionary in result.events_of("slot_modifier"):
		assert_str(String(event["modifier"])).is_not_equal("ANVIL")


# -- Exempel 4: Charge lyfter över tröskeln, fyrtal, överflödskedja och cap ---
func test_example_4_charge_creates_quad_and_overflow_chain() -> void:
	var tick: Enemy = CombatFixture.dummy_enemy("IRON_TICK", 28, 2)
	var result: ResolveResult = _resolve(
		DEFAULT_BOARD, [2, 5, 3, 5, 3], [6],
		[CombatFixture.dummy_enemy("RUST_RAT", 14), CombatFixture.dummy_enemy("SLAG_MOTH", 20), tick],
		3)

	assert_int(int(result.events_of("charge_applied")[0]["slot"])).is_equal(0)
	assert_int(int(result.events_of("charge_applied")[0]["amount"])).is_equal(3)
	assert_array(result.events_of("value_pass_done")[0]["values"]).is_equal([5, 5, 5, 5, 3])
	assert_str(String(result.events_of("combo_formed")[0]["kind"])).is_equal("QUAD")
	assert_int(int(result.events_of("combo_formed")[0]["multiplier"])).is_equal(8)
	assert_bool(result.has_event("house_bonus")).is_false()
	assert_int(result.state_after.enemies_alive()).is_equal(0)
	assert_int(result.state_after.charge).is_equal(Rules.CHARGE_CAP)
	assert_int(_charge_capped_total(result)).is_equal(7 + 20 + 1 + 6)
	# Rustningen blockerade 2 vid varje av de två träffarna mot IRON_TICK.
	var blocked: int = 0
	for event: Dictionary in result.events_of("damage_dealt"):
		blocked += int(event["blocked"])
	assert_int(blocked).is_equal(4)


# -- Exempel 5: HOUSE (kåk) --------------------------------------------------
func test_example_5_house_bonus() -> void:
	var result: ResolveResult = _resolve(
		[PLAIN, PLAIN, MIRROR, PLAIN, PLAIN], [4, 4, 1, 6, 6], [],
		[CombatFixture.dummy_enemy("DUMMY", 1000)])

	assert_int(result.count_of("combo_formed")).is_equal(2)
	assert_int(result.count_of("house_bonus")).is_equal(1)
	assert_array(result.events_of("house_bonus")[0]["multipliers_after"]).is_equal([8, 8, 8, 4, 4])
	assert_int(_strike_damage(result)).is_equal(144)


# -- Exempel 6: ambossen bryter ditt par (fällan) ----------------------------
func test_example_6_anvil_breaks_the_pair() -> void:
	var result: ResolveResult = _resolve(
		DEFAULT_BOARD, [null, null, null, 6, 6], [],
		[CombatFixture.dummy_enemy("DUMMY", 1000)])

	assert_array(result.events_of("value_pass_done")[0]["values"]).is_equal([0, 0, 0, 6, 12])
	assert_int(result.count_of("combo_formed")).is_equal(0)
	assert_int(_strike_damage(result)).is_equal(18)


func test_example_6_counterfactual_plain_slot_keeps_the_pair() -> void:
	var result: ResolveResult = _resolve(
		[PLAIN, PLAIN, MIRROR, FIRE, PLAIN], [null, null, null, 6, 6], [],
		[CombatFixture.dummy_enemy("DUMMY", 1000)])

	assert_int(result.count_of("combo_formed")).is_equal(1)
	assert_int(_strike_damage(result)).is_equal(24)


# -- Exempel 7: tom slot bryter angränsning ----------------------------------
func test_example_7_empty_slot_breaks_adjacency() -> void:
	var result: ResolveResult = _resolve(
		[PLAIN, PLAIN, PLAIN, PLAIN, PLAIN], [3, 3, null, 3, 3], [],
		[CombatFixture.dummy_enemy("DUMMY", 1000)])

	assert_int(result.count_of("combo_formed")).is_equal(2)
	for event: Dictionary in result.events_of("combo_formed"):
		assert_str(String(event["kind"])).is_equal("PAIR")
	assert_bool(result.has_event("house_bonus")).is_false()
	assert_int(_strike_damage(result)).is_equal(24)


func test_example_7_full_penta_for_comparison() -> void:
	var result: ResolveResult = _resolve(
		[PLAIN, PLAIN, PLAIN, PLAIN, PLAIN], [3, 3, 3, 3, 3], [],
		[CombatFixture.dummy_enemy("DUMMY", 1000)])

	assert_str(String(result.events_of("combo_formed")[0]["kind"])).is_equal("PENTA")
	assert_int(_strike_damage(result)).is_equal(240)


# -- Exempel 8: tomrum som sköld + spegelparat värde + fiendesvar ------------
func test_example_8_void_ward_absorbs_the_enemy_turn() -> void:
	var imp: Enemy = CombatFixture.dummy_enemy("THORN_IMP", 22, 0, 3)
	imp.intent = Intent.new(Rules.IntentKind.ATTACK, 2)
	var rat: Enemy = CombatFixture.dummy_enemy("RUST_RAT", 14)
	rat.intent = Intent.new(Rules.IntentKind.ATTACK, 3)

	var result: ResolveResult = _resolve(
		[PLAIN, VOID, MIRROR, PLAIN, ANVIL], [null, 5, 1, null, null], [], [imp, rat])

	assert_array(result.events_of("value_pass_done")[0]["values"]).is_equal([0, 5, 5, 0, 0])
	assert_int(int(result.events_of("ward_gained")[0]["ward_total"])).is_equal(10)
	assert_int(result.count_of("enemy_thorns")).is_equal(1)
	# Spelaren tog exakt 3 skada, allt från thorns. Båda attackerna åts av Ward.
	assert_int(result.state_after.player_hp).is_equal(37)
	for event: Dictionary in result.events_of("enemy_attacks"):
		assert_int(int(event["amount"])).is_equal(0)
	# Ward försvinner vid round_end.
	assert_int(result.state_after.ward).is_equal(0)
	assert_int(int(result.events_of("round_end")[0]["player_hp"])).is_equal(37)


func _charge_capped_total(result: ResolveResult) -> int:
	var total: int = 0
	for event: Dictionary in result.events_of("charge_capped"):
		total += int(event["lost"])
	return total
