extends GdUnitTestSuite
## Smedjan (src/core/forge.gd). DECISIONS 2026-09-21: smedjan i staden får
## [b]byta[/b] och [b]ordna om[/b], aldrig lägga till.
##
## Hela testet är en enda invariant uttryckt på tre sätt: multimängden av sidor
## och slot-typer är densamma före och efter. Håller den kan smedjan inte bli
## en uppgraderingsmeny av misstag.


func _die() -> Die:
	return Die.standard("die_0", Rules.DieMaterial.IRON)


func test_swapping_faces_keeps_every_face() -> void:
	var before: Die = _die()
	var after: Die = Forge.swap_faces(before, 0, 5)
	assert_array(Array(Forge.face_signature(after))).override_failure_message(
		"smedjan får aldrig ändra vilka sidor tärningen har").is_equal(
		Array(Forge.face_signature(before)))
	assert_int(after.faces[0].value).is_equal(6)
	assert_int(after.faces[5].value).is_equal(1)


func test_swapping_twice_is_the_original() -> void:
	var before: Die = _die()
	var twice: Die = Forge.swap_faces(Forge.swap_faces(before, 1, 4), 1, 4)
	for i: int in range(before.faces.size()):
		assert_int(twice.faces[i].value).is_equal(before.faces[i].value)


func test_swapping_does_not_touch_the_input() -> void:
	var before: Die = _die()
	Forge.swap_faces(before, 0, 5)
	assert_int(before.faces[0].value).override_failure_message(
		"indata muterades – samma kontrakt som Resolver.resolve").is_equal(1)


func test_an_invalid_index_changes_nothing() -> void:
	var before: Die = _die()
	for pair: Array in [[0, 9], [-1, 2], [3, 3]]:
		var after: Die = Forge.swap_faces(before, int(pair[0]), int(pair[1]))
		for i: int in range(before.faces.size()):
			assert_int(after.faces[i].value).is_equal(before.faces[i].value)


func test_reordering_slots_keeps_every_slot_type() -> void:
	var board: Board = Board.smith_board()
	var order: PackedInt32Array = PackedInt32Array([2, 0, 1, 4, 3])
	var after: Board = Forge.reorder_slots(board, order)
	assert_array(Array(Forge.slot_signature(after))).override_failure_message(
		"omordningen ändrade brädets typer – det vore ett tillägg").is_equal(
		Array(Forge.slot_signature(board)))
	assert_int(after.slots[0].type).is_equal(Rules.SlotType.MIRROR)
	assert_int(after.slots[1].type).is_equal(Rules.SlotType.PLAIN)
	assert_int(after.slots[3].type).is_equal(Rules.SlotType.ANVIL)
	assert_int(after.slots[4].type).is_equal(Rules.SlotType.FIRE)
	for i: int in range(after.size()):
		assert_int(after.slots[i].index).override_failure_message(
			"slots[i].index måste vara i (Board-kontraktet)").is_equal(i)


func test_a_non_permutation_is_rejected() -> void:
	var board: Board = Board.smith_board()
	# Duplicerad AMBOSS, för kort, och ett index utanför brädet.
	for bad: PackedInt32Array in [
		PackedInt32Array([4, 4, 0, 1, 2]),
		PackedInt32Array([0, 1, 2]),
		PackedInt32Array([0, 1, 2, 3, 9]),
	]:
		assert_bool(Forge.is_permutation(bad, board.size())).is_false()
		var after: Board = Forge.reorder_slots(board, bad)
		assert_array(Array(Forge.slot_signature(after))).is_equal(
			Array(Forge.slot_signature(board)))
		assert_int(after.slots[2].type).override_failure_message(
			"en ogiltig ordning ska lämna brädet exakt som det var").is_equal(
			board.slots[2].type)


func test_move_is_always_a_permutation() -> void:
	var order: PackedInt32Array = Forge.identity_order(5)
	for from_index: int in range(5):
		for to_index: int in range(5):
			var moved: PackedInt32Array = Forge.move(order, from_index, to_index)
			assert_bool(Forge.is_permutation(moved, 5)).override_failure_message(
				"move(%d → %d) gav ingen permutation: %s" % [from_index, to_index, moved]).is_true()
	assert_array(Array(Forge.move(order, 4, 0))).is_equal([4, 0, 1, 2, 3])


func test_a_loadout_survives_a_round_trip_into_the_next_run() -> void:
	var state: CombatState = Content.smith_state()
	var loadout: Dictionary = {
		Forge.KEY_FACE_SWAPS: [[0, 0, 5], [1, 2, 3]],
		Forge.KEY_SLOT_ORDER: [2, 0, 1, 3, 4],
	}
	var after: CombatState = Forge.apply_loadout(state, loadout)
	assert_int(after.dice[0].faces[0].value).is_equal(6)
	assert_int(after.dice[1].faces[2].value).is_equal(4)
	assert_int(after.board.slots[0].type).is_equal(Rules.SlotType.MIRROR)
	assert_array(Array(Forge.slot_signature(after.board))).is_equal(
		Array(Forge.slot_signature(state.board)))
	assert_array(Array(Forge.face_signature(after.dice[0]))).is_equal(
		Array(Forge.face_signature(state.dice[0])))
	# Indata orört.
	assert_int(state.dice[0].faces[0].value).is_equal(1)
	assert_int(state.board.slots[0].type).is_equal(Rules.SlotType.PLAIN)


func test_an_empty_loadout_changes_nothing() -> void:
	var state: CombatState = Content.smith_state()
	var after: CombatState = Forge.apply_loadout(state, {})
	for i: int in range(state.board.size()):
		assert_int(after.board.slots[i].type).is_equal(state.board.slots[i].type)
	for i: int in range(state.dice.size()):
		assert_array(Array(Forge.face_signature(after.dice[i]))).is_equal(
			Array(Forge.face_signature(state.dice[i])))


## Den viktigaste följden av omordningen: Spegeln på slot 0 fizzlar. Det är
## repet spelaren ska kunna hänga sig i (§A.2), och det ska gå att bevisa.
func test_a_mirror_moved_to_slot_one_fizzles() -> void:
	var state: CombatState = Content.smith_state()
	state.enemies = Content.encounter(1)
	state = Forge.apply_loadout(state, {Forge.KEY_SLOT_ORDER: [2, 0, 1, 3, 4]})
	for i: int in range(state.dice.size()):
		state.dice[i].showing = 3
	var result: ResolveResult = Resolver.resolve(state, PackedInt32Array([0, 1, 2, 3, 4]))
	var failed: Array[Dictionary] = result.events_of("slot_modifier_failed")
	var reasons: PackedStringArray = PackedStringArray()
	for event: Dictionary in failed:
		reasons.append(String(event.get("reason", "")))
	assert_bool(reasons.has("NO_LEFT_NEIGHBOUR")).override_failure_message(
		"Spegeln på slot 0 ska sakna vänstergranne").is_true()
