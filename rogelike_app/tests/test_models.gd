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
	var enemy: Enemy = Content.make_enemy("IRON_TICK")
	enemy.hp = 11
	enemy.burn = 3
	enemy.poison = 2
	enemy.intent = Intent.new(Rules.IntentKind.SPECIAL, 0, "Griper slot 3")
	enemy.intent.payload = {"slot": 3}
	var back: Enemy = Enemy.from_dict(_roundtrip(enemy.to_dict()))
	assert_int(back.hp).is_equal(11)
	assert_int(back.max_hp).is_equal(28)
	assert_int(back.armor).is_equal(2)
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
	copy.dice[0].faces[0].value = 99
	copy.board.slots[0].blocked = true
	assert_int(state.enemies[0].hp).is_equal(14)
	assert_int(state.dice[0].faces[0].value).is_equal(1)
	assert_bool(state.board.slots[0].blocked).is_false()


func test_unplaced_die_indices_ignores_placed_and_stolen() -> void:
	var state: CombatState = Content.smith_state()
	state.stolen = ["die_5"]
	var placement: PackedInt32Array = PackedInt32Array([0, -1, 2, -1, -1])
	assert_array(state.unplaced_die_indices(placement)).is_equal([1, 3, 4])
