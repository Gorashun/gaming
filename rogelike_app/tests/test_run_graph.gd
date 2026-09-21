extends GdUnitTestSuite
## Nod-grafen för en våning: determinism, alltid väg till boss, minst en
## förgrening. GAME_DESIGN §1 och DECISIONS 2026-09-21 (hybridnavigering).


func _graph(seed_value: int, floor_index: int = 1) -> RunGraph:
	return RunGraph.generate_floor(floor_index, Rng.new(seed_value))


func test_same_seed_gives_an_identical_graph() -> void:
	for seed_value: int in range(50):
		var a: RunGraph = _graph(seed_value)
		var b: RunGraph = _graph(seed_value)
		assert_str(JSON.stringify(a.to_dict())).is_equal(JSON.stringify(b.to_dict()))


func test_floor_one_has_four_rooms_and_five_nodes() -> void:
	var graph: RunGraph = _graph(1)
	# Fyra rum, men rum 3 finns i två varianter ⇒ fem noder.
	assert_int(graph.nodes.size()).is_equal(5)
	var rooms: Dictionary = {}
	for id: String in graph.nodes:
		rooms[int(graph.node_at(id)["room"])] = true
	assert_int(rooms.size()).is_equal(RunGraph.ROOMS_PER_FLOOR)


func test_room_four_is_the_boss_and_nothing_else_is() -> void:
	for seed_value: int in range(30):
		var graph: RunGraph = _graph(seed_value)
		var bosses: int = 0
		for id: String in graph.nodes:
			var node: Dictionary = graph.node_at(id)
			if String(node["kind"]) == RunGraph.KIND_BOSS:
				bosses += 1
				assert_int(int(node["room_in_floor"])).is_equal(RunGraph.ROOMS_PER_FLOOR)
			else:
				assert_int(int(node["room_in_floor"])).is_less(RunGraph.ROOMS_PER_FLOOR)
		assert_int(bosses).is_equal(1)


func test_every_node_reaches_the_boss() -> void:
	# Invarianten som gör en våning spelbar: ingen återvändsgränd, någonsin.
	for seed_value: int in range(50):
		var graph: RunGraph = _graph(seed_value)
		for id: String in graph.nodes:
			assert_bool(graph.reaches_boss(id)).override_failure_message(
				"noden %s (seed %d) når inte bossen" % [id, seed_value]).is_true()


func test_there_is_always_at_least_one_branch() -> void:
	for seed_value: int in range(50):
		var graph: RunGraph = _graph(seed_value)
		var branches: int = 0
		for id: String in graph.nodes:
			if graph.is_branch(id):
				branches += 1
		assert_int(branches).override_failure_message(
			"seed %d gav ingen förgrening" % seed_value).is_greater_equal(1)


func test_the_branch_offers_two_different_encounter_variants() -> void:
	# Poängen med förgreningen är att valet betyder något. Två identiska möten
	# vore en knapp utan funktion.
	for seed_value: int in range(30):
		var graph: RunGraph = _graph(seed_value)
		for id: String in graph.nodes:
			if not graph.is_branch(id):
				continue
			var variants: Array[int] = []
			for next_id: String in graph.next_ids(id):
				variants.append(int(graph.node_at(next_id)["variant"]))
			assert_int(variants.size()).is_equal(2)
			assert_bool(variants[0] != variants[1]).is_true()


func test_the_branch_sits_on_the_room_that_has_two_specified_encounters() -> void:
	# GAME_DESIGN §4.4: bara rum 3 har två möten. Flyttas förgreningen dit
	# innehållet är identiskt blir valet meningslöst.
	var graph: RunGraph = _graph(3)
	for id: String in graph.nodes:
		if graph.is_branch(id):
			for next_id: String in graph.next_ids(id):
				assert_int(int(graph.node_at(next_id)["room_in_floor"])).is_equal(RunGraph.BRANCH_ROOM_IN_FLOOR)


func test_the_start_node_is_room_one_and_has_no_parent() -> void:
	var graph: RunGraph = _graph(11)
	assert_int(int(graph.node_at(graph.start_id)["room_in_floor"])).is_equal(1)
	for id: String in graph.nodes:
		assert_bool(graph.next_ids(id).has(graph.start_id)).is_false()


func test_the_boss_has_no_continuation() -> void:
	var graph: RunGraph = _graph(5)
	assert_array(graph.next_ids(graph.boss_id())).is_empty()


func test_different_seeds_produce_different_branch_orders() -> void:
	var orders: Dictionary = {}
	for seed_value: int in range(40):
		var graph: RunGraph = _graph(seed_value)
		var key: PackedStringArray = PackedStringArray()
		for id: String in graph.ordered_ids():
			key.append("%d" % int(graph.node_at(id)["variant"]))
		orders["".join(key)] = true
	assert_int(orders.size()).is_greater(1)


func test_serialisation_survives_a_json_round_trip() -> void:
	# Grafen ligger i RunState.meta och går därför genom JSON, där heltal blir
	# float. Kommer de inte tillbaka som int går alla jämförelser sönder.
	var graph: RunGraph = _graph(99)
	var text: String = JSON.stringify(graph.to_dict())
	var restored: RunGraph = RunGraph.from_dict(JSON.parse_string(text) as Dictionary)
	assert_str(restored.start_id).is_equal(graph.start_id)
	assert_int(restored.nodes.size()).is_equal(graph.nodes.size())
	for id: String in graph.nodes:
		assert_bool(restored.has_node(id)).is_true()
		assert_int(int(restored.node_at(id)["room"])).is_equal(int(graph.node_at(id)["room"]))
		assert_int(typeof(restored.node_at(id)["room"])).is_equal(TYPE_INT)
		assert_array(restored.next_ids(id)).is_equal(graph.next_ids(id))
	assert_bool(restored.reaches_boss(restored.start_id)).is_true()


func test_higher_floors_offset_the_room_numbers() -> void:
	var floor_two: RunGraph = _graph(1, 2)
	var rooms: Array[int] = []
	for id: String in floor_two.ordered_ids():
		rooms.append(int(floor_two.node_at(id)["room"]))
	assert_int(rooms[0]).is_equal(5)
	assert_int(rooms[rooms.size() - 1]).is_equal(8)
