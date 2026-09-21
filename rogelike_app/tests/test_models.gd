extends GdUnitTestSuite
## to_dict()/from_dict()-roundtrips. Sparfilen är JSON, så testerna går alltid
## via JSON.stringify/parse_string – annars skulle en icke-serialiserbar typ
## kunna smyga in utan att synas.


func _roundtrip(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data)) as Dictionary


func test_face_roundtrip() -> void:
	var face: Face = Face.new("POISON_DROP", 2, Rules.FaceEffectKind.APPLY_POISON, 2)
	face.value = 5  # GROW har ändrat värdet, base_value ska bevaras.
	var back: Face = Face.from_dict(_roundtrip(face.to_dict()))
	assert_str(back.id).is_equal("POISON_DROP")
	assert_int(back.value).is_equal(5)
	assert_int(back.base_value).is_equal(2)
	assert_int(back.effect).is_equal(Rules.FaceEffectKind.APPLY_POISON)
	assert_int(back.magnitude).is_equal(2)


func test_die_roundtrip() -> void:
	var die: Die = Die.standard("die_3", Rules.DieMaterial.GLASS)
	die.showing = 4
	die.cracks = 1
	var back: Die = Die.from_dict(_roundtrip(die.to_dict()))
	assert_str(back.id).is_equal("die_3")
	assert_int(back.material).is_equal(Rules.DieMaterial.GLASS)
	assert_int(back.integrity).is_equal(3)
	assert_int(back.cracks).is_equal(1)
	assert_int(back.showing).is_equal(4)
	assert_int(back.faces.size()).is_equal(6)
	assert_int(back.showing_face().value).is_equal(5)


func test_slot_and_board_roundtrip() -> void:
	var board: Board = Board.smith_board()
	board.slots[3].blocked = true
	var back: Board = Board.from_dict(_roundtrip(board.to_dict()))
	assert_int(back.size()).is_equal(Rules.SLOT_COUNT)
	assert_int(back.slots[2].type).is_equal(Rules.SlotType.MIRROR)
	assert_int(back.slots[4].type).is_equal(Rules.SlotType.ANVIL)
	assert_bool(back.slots[3].blocked).is_true()
	for i: int in range(back.size()):
		assert_int(back.slots[i].index).is_equal(i)


func test_enemy_roundtrip_keeps_status_and_intent() -> void:
	# Balanssiffrorna är tuningbara (GAME_DESIGN §4.8); testet läser dem ur
	# Content i stället för att binda sig till en viss version av dem.
	var enemy: Enemy = Content.make_enemy("IRON_TICK")
	var template: Enemy = Content.make_enemy("IRON_TICK")
	enemy.hp = 11
	enemy.burn = 3
	enemy.poison = 2
	enemy.intent = Intent.new(Rules.IntentKind.SPECIAL, 0, "Griper slot 3")
	enemy.intent.payload = {"slot": 3}
	var back: Enemy = Enemy.from_dict(_roundtrip(enemy.to_dict()))
	assert_int(back.hp).is_equal(11)
	assert_int(back.max_hp).is_equal(template.max_hp)
	assert_int(back.armor).is_equal(template.armor)
	assert_int(back.burn).is_equal(3)
	assert_int(back.poison).is_equal(2)
	assert_int(back.intent.kind).is_equal(Rules.IntentKind.SPECIAL)
	assert_int(int(back.intent.payload["slot"])).is_equal(3)


func test_relic_roundtrip() -> void:
	var relic: Relic = Content.make_relic("ECHO_MIRROR")
	var back: Relic = Relic.from_dict(_roundtrip(relic.to_dict()))
	assert_str(back.id).is_equal("ECHO_MIRROR")
	assert_int(back.rarity).is_equal(Rules.Rarity.RARE)


func test_combat_state_roundtrip_is_byte_identical() -> void:
	var state: CombatState = Content.smith_state()
	state.enemies = Content.encounter(2)
	state.charge = 7
	state.ward = 3
	state.round_number = 4
	state.placement = PackedInt32Array([2, -1, 0, 4, -1])
	state.stolen = ["die_1"]
	var json: String = JSON.stringify(state.to_dict())
	var back: CombatState = CombatState.from_dict(JSON.parse_string(json) as Dictionary)
	assert_str(JSON.stringify(back.to_dict())).is_equal(json)
	assert_array(Array(back.placement)).is_equal([2, -1, 0, 4, -1])


func test_run_state_roundtrip_resumes_the_rng_stream() -> void:
	var run: RunState = RunState.new_run(20260921)
	var rng: Rng = run.make_rng()
	for i: int in range(13):
		rng.next_int(0, 99)
	run.store_rng(rng)
	run.floor_index = 2
	run.room_index = 3

	var json: String = JSON.stringify(run.to_dict())
	var back: RunState = RunState.from_dict(JSON.parse_string(json) as Dictionary)
	assert_int(back.seed_value).is_equal(20260921)
	assert_int(back.floor_index).is_equal(2)
	assert_int(back.room_index).is_equal(3)
	assert_str(JSON.stringify(back.to_dict())).is_equal(json)

	# Samma ström fortsätter exakt där den var.
	var resumed: Rng = back.make_rng()
	for i: int in range(30):
		assert_int(resumed.next_int(0, 9999)).is_equal(rng.next_int(0, 9999))


func test_combat_state_copy_is_deep() -> void:
	var state: CombatState = Content.smith_state()
	state.enemies = Content.encounter(1)
	var copy: CombatState = state.copy()
	copy.enemies[0].hp = 1
	copy.board.slots[0].blocked = true
	copy.placement[0] = 3
	copy.relics.clear()
	assert_int(state.enemies[0].hp).is_equal(Content.make_enemy("RUST_RAT").hp)
	assert_bool(state.board.slots[0].blocked).is_false()
	assert_int(state.placement[0]).is_equal(-1)
	assert_int(state.relics.size()).is_equal(1)


func test_die_copy_uses_copy_on_write_faces() -> void:
	# Sidorna delas tills mutable_face() anropas. Det halverar kostnaden för
	# CombatState.copy() i simulatorn, men kräver att alla muteringar går
	# genom mutable_face().
	var original: Die = Die.standard("die_0")
	var copy: Die = original.copy()
	copy.faces[0] = Face.new("REPLACED", 9)
	assert_str(original.faces[0].id).is_equal("PIP_1")

	var fresh: Face = copy.mutable_face(2)
	fresh.value = 99
	assert_int(original.faces[2].value).is_equal(3)


func test_die_deep_copy_isolates_every_face() -> void:
	var original: Die = Die.standard("die_0")
	var copy: Die = original.deep_copy()
	copy.faces[1].value = 42
	assert_int(original.faces[1].value).is_equal(2)


func test_resolve_never_mutates_input_faces_via_grow() -> void:
	var snowball: Face = Face.new("SNOWBALL", 1, Rules.FaceEffectKind.GROW, 1)
	var fixture: Dictionary = CombatFixture.build(
		[Rules.SlotType.PLAIN, Rules.SlotType.PLAIN, Rules.SlotType.PLAIN, Rules.SlotType.PLAIN, Rules.SlotType.PLAIN],
		[null, null, null, null, null], [snowball],
		[CombatFixture.dummy_enemy("DUMMY", 100)])
	var state: CombatState = fixture["state"]
	var before: String = JSON.stringify(state.to_dict())
	var result: ResolveResult = Resolver.resolve(state, fixture["placement"])
	assert_int(result.state_after.dice[0].showing_face().value).is_equal(2)
	assert_str(JSON.stringify(state.to_dict())).is_equal(before)


func test_unplaced_die_indices_ignores_placed_and_stolen() -> void:
	var state: CombatState = Content.smith_state()
	state.stolen = ["die_5"]
	var placement: PackedInt32Array = PackedInt32Array([0, -1, 2, -1, -1])
	assert_array(state.unplaced_die_indices(placement)).is_equal([1, 3, 4])
