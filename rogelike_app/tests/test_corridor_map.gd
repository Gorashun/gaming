extends GdUnitTestSuite
## Korridorkartan: determinism, alltid väg till bossen, max tre val, ingenting
## bakom spelaren, stegbudget och sparfils-rundtur.
## CORRIDOR_DESIGN §2–§3, research 05 §2.

const FLOORS_PER_RUN: int = 3
## CORRIDOR_DESIGN §8.1: stegbudgeten är stoppregeln för M5.
const MIN_STEPS_PER_RUN: int = 40
const MAX_STEPS_PER_RUN: int = 70


func _map(seed_value: int, floor_index: int = 1, allow_fate: bool = false) -> CorridorMap:
	var rng: Rng = Rng.new(seed_value)
	var graph: RunGraph = RunGraph.generate_floor(floor_index, rng)
	return CorridorMap.build(graph, rng.fork("corridor"), allow_fate)


## Går våningen till bossen. [param greedy_side] tar återvändsgränden när den
## erbjuds, vilket är det dyraste fallet i stegbudgeten.
func _walk(map: CorridorMap, greedy_side: bool = false) -> Dictionary:
	var guard: int = 0
	var junctions: int = 0
	var max_actions: int = 0
	while not map.is_finished():
		guard += 1
		assert_int(guard).override_failure_message("kartan tog aldrig slut").is_less(200)
		if map.pending_trap_key != "":
			map.resolve_trap(0)
			continue
		var actions: Dictionary = map.available_actions()
		max_actions = maxi(max_actions, actions.size())
		if actions.is_empty():
			break
		if actions.size() > 1:
			junctions += 1
		var pick: String = ""
		if greedy_side and actions.has(CorridorMap.ACTION_FORWARD) and actions.size() > 1:
			pick = CorridorMap.ACTION_FORWARD
		elif actions.has(CorridorMap.ACTION_LEFT):
			pick = CorridorMap.ACTION_LEFT
		elif actions.has(CorridorMap.ACTION_FORWARD):
			pick = CorridorMap.ACTION_FORWARD
		else:
			pick = CorridorMap.ACTION_RIGHT
		map.apply(pick)
	return {"steps": map.steps_taken, "junctions": junctions, "max_actions": max_actions}


func test_same_seed_gives_an_identical_map() -> void:
	for seed_value: int in range(40):
		var a: CorridorMap = _map(seed_value)
		var b: CorridorMap = _map(seed_value)
		assert_str(JSON.stringify(a.to_dict())).override_failure_message(
			"seed %d gav två olika kartor" % seed_value).is_equal(JSON.stringify(b.to_dict()))


func test_different_seeds_do_not_all_collapse_to_one_shape() -> void:
	var shapes: Dictionary = {}
	for seed_value: int in range(40):
		shapes[JSON.stringify(_map(seed_value).to_dict())] = true
	assert_int(shapes.size()).is_greater(3)


func test_every_floor_has_a_walkable_path_to_the_boss() -> void:
	for seed_value: int in range(40):
		for floor_index: int in range(1, FLOORS_PER_RUN + 1):
			var map: CorridorMap = _map(seed_value, floor_index)
			_walk(map)
			assert_bool(map.is_finished()).override_failure_message(
				"seed %d våning %d nådde aldrig bossen" % [seed_value, floor_index]).is_true()
			assert_bool(bool(map.current_cell()["boss"])).is_true()


func test_a_junction_never_offers_more_than_three_choices() -> void:
	for seed_value: int in range(40):
		var stats: Dictionary = _walk(_map(seed_value))
		assert_int(int(stats["max_actions"])).override_failure_message(
			"seed %d gav fler än tre val" % seed_value).is_less_equal(3)


func test_a_junction_with_one_choice_is_a_corridor_and_says_forward() -> void:
	# §2.3 regel 1. Ett hörn får kosta tid, aldrig en extra tapp.
	for seed_value: int in range(20):
		var map: CorridorMap = _map(seed_value)
		var guard: int = 0
		while not map.is_finished() and guard < 200:
			guard += 1
			if map.pending_trap_key != "":
				map.resolve_trap(0)
				continue
			var actions: Dictionary = map.available_actions()
			if actions.is_empty():
				break
			if actions.size() == 1:
				assert_bool(actions.has(CorridorMap.ACTION_FORWARD)).override_failure_message(
					"ensamt val låg inte på FORWARD (seed %d)" % seed_value).is_true()
			map.apply(actions.keys()[0] as String)


func test_nothing_is_ever_behind_the_player() -> void:
	# §3.4: rörelsen är framåtriktad. En knapp får aldrig leda till rutan man
	# just lämnade, och aldrig till en ruta man redan varit i.
	for seed_value: int in range(40):
		var map: CorridorMap = _map(seed_value)
		var guard: int = 0
		while not map.is_finished() and guard < 200:
			guard += 1
			if map.pending_trap_key != "":
				map.resolve_trap(0)
				continue
			var previous: String = map.current_cell()["key"]
			var actions: Dictionary = map.available_actions()
			if actions.is_empty():
				break
			var backtracking: bool = bool(map.to_dict()["backtracking"])
			for action: Variant in actions:
				var target: String = String((actions[action] as Dictionary)["cell"])
				assert_str(target).override_failure_message(
					"seed %d erbjöd rutan man stod på" % seed_value).is_not_equal(previous)
				if not backtracking:
					assert_bool(bool((map.cells[target] as Dictionary)["visited"])).override_failure_message(
						"seed %d erbjöd en redan besökt ruta utan att vara på väg ut ur en gränd" % seed_value).is_false()
			map.apply(actions.keys()[0] as String)


func test_a_run_stays_inside_the_step_budget() -> void:
	# CORRIDOR_DESIGN §1.2: korridortiden är ≤ 90 s av en 15-minutersrun.
	for seed_value: int in range(40):
		for greedy: bool in [false, true]:
			var total: int = 0
			for floor_index: int in range(1, FLOORS_PER_RUN + 1):
				total += int(_walk(_map(seed_value, floor_index), greedy)["steps"])
			assert_int(total).override_failure_message(
				"seed %d (gränder=%s) gav %d steg" % [seed_value, greedy, total]
			).is_between(MIN_STEPS_PER_RUN, MAX_STEPS_PER_RUN)


func test_the_dead_end_costs_four_steps_and_turns_you_around() -> void:
	# §2.3 regel 4: rakt fram och tillbaka kostar 4 steg och ingenting annat.
	var found: int = 0
	for seed_value: int in range(60):
		var direct: int = int(_walk(_map(seed_value), false)["steps"])
		var detour: int = int(_walk(_map(seed_value), true)["steps"])
		if detour == direct:
			continue
		found += 1
		assert_int(detour - direct).override_failure_message(
			"seed %d: gränden kostade %d steg" % [seed_value, detour - direct]).is_equal(4)
	assert_int(found).override_failure_message("ingen seed gav en återvändsgränd").is_greater(0)


func test_the_dead_end_yields_a_treasure_and_a_turn_around() -> void:
	for seed_value: int in range(60):
		var map: CorridorMap = _map(seed_value)
		var types: Array[String] = []
		var guard: int = 0
		while not map.is_finished() and guard < 200:
			guard += 1
			if map.pending_trap_key != "":
				map.resolve_trap(0)
				continue
			var actions: Dictionary = map.available_actions()
			if actions.is_empty():
				break
			var pick: String = CorridorMap.ACTION_FORWARD if (
				actions.size() > 1 and actions.has(CorridorMap.ACTION_FORWARD)) else actions.keys()[0]
			map.apply(pick)
			for event: Dictionary in map.events_since_last():
				types.append(String(event["type"]))
		if not types.has(CorridorMap.EVENT_TREASURE):
			continue
		assert_bool(types.has(CorridorMap.EVENT_TURN_AROUND)).override_failure_message(
			"seed %d gav en skatt utan att vända spelaren" % seed_value).is_true()
		return
	fail("ingen seed gav en skatt i en återvändsgränd")


func test_exactly_one_unknown_sign_per_floor() -> void:
	# §2.3 regel 3. Mer än ett "?" och skyltarna slutar betyda något.
	for seed_value: int in range(40):
		var map: CorridorMap = _map(seed_value)
		var unknown: int = 0
		for key: String in map.tiles():
			var signs: Dictionary = (map.cells[key] as Dictionary).get("signs", {}) as Dictionary
			for slot: Variant in signs:
				if String(signs[slot]) == CorridorMap.SIGN_UNKNOWN:
					unknown += 1
		assert_int(unknown).override_failure_message(
			"seed %d gav %d frågetecken" % [seed_value, unknown]).is_equal(1)


func test_every_sign_key_is_a_known_key() -> void:
	for seed_value: int in range(20):
		var map: CorridorMap = _map(seed_value, 1, true)
		for key: String in map.tiles():
			var cell: Dictionary = map.cells[key]
			var signs: Dictionary = cell.get("signs", {}) as Dictionary
			for slot: Variant in signs:
				assert_bool(CorridorMap.SIGN_KEYS.has(String(signs[slot]))).override_failure_message(
					"okänd skyltnyckel %s" % signs[slot]).is_true()


func test_the_trap_is_a_choice_with_two_price_tags_and_never_past_a_fight() -> void:
	# §2.6: två kostnader, aldrig en gratis utväg, aldrig på kanten mot bossen.
	for seed_value: int in range(40):
		var map: CorridorMap = _map(seed_value)
		var traps: int = 0
		for key: String in map.tiles():
			var cell: Dictionary = map.cells[key]
			var trap: Dictionary = cell.get("trap", {}) as Dictionary
			if trap.is_empty():
				continue
			traps += 1
			assert_str(String(cell["kind"])).is_equal(CorridorMap.KIND_CORRIDOR)
			assert_bool(bool(cell["silent_stretch"])).is_false()
			var options: Array = trap["options"] as Array
			assert_int(options.size()).is_equal(2)
			for option: Variant in options:
				assert_int(int((option as Dictionary)["amount"])).is_greater(0)
		assert_int(traps).override_failure_message(
			"seed %d gav %d fällor" % [seed_value, traps]).is_less_equal(1)


func test_a_pending_trap_blocks_every_direction_until_it_is_paid() -> void:
	for seed_value: int in range(40):
		var map: CorridorMap = _map(seed_value)
		var guard: int = 0
		var paid: bool = false
		while not map.is_finished() and guard < 200:
			guard += 1
			if map.pending_trap_key != "":
				assert_dict(map.available_actions()).is_empty()
				assert_bool(map.apply(CorridorMap.ACTION_FORWARD)).is_false()
				var chosen: Dictionary = map.resolve_trap(1)
				assert_str(String(chosen["cost"])).is_equal("cracked_face")
				paid = true
				continue
			var actions: Dictionary = map.available_actions()
			if actions.is_empty():
				break
			map.apply(actions.keys()[0] as String)
		assert_bool(paid).override_failure_message("seed %d hade ingen fälla alls" % seed_value).is_true()


func test_an_autosave_round_trip_keeps_the_map_and_the_position() -> void:
	for seed_value: int in range(20):
		var map: CorridorMap = _map(seed_value)
		for _i: int in range(4):
			if map.pending_trap_key != "":
				map.resolve_trap(0)
				continue
			var actions: Dictionary = map.available_actions()
			if actions.is_empty():
				break
			map.apply(actions.keys()[0] as String)
		# Hela vägen genom JSON: det är så sparfilen faktiskt ser ut.
		var raw: Variant = JSON.parse_string(JSON.stringify(map.to_dict()))
		var restored: CorridorMap = CorridorMap.from_dict(raw as Dictionary)
		assert_str(JSON.stringify(restored.to_dict())).override_failure_message(
			"seed %d överlevde inte en rundtur genom JSON" % seed_value).is_equal(
			JSON.stringify(map.to_dict()))
		assert_dict(restored.available_actions()).is_equal(map.available_actions())
		assert_int(restored.yaw_degrees()).is_equal(map.yaw_degrees())


func test_the_yaw_is_absolute_and_never_wraps() -> void:
	# research 05 §1: en wrappad vinkel får Tween att snurra åt fel håll.
	for seed_value: int in range(20):
		var map: CorridorMap = _map(seed_value)
		var guard: int = 0
		while not map.is_finished() and guard < 200:
			guard += 1
			var before: int = map.yaw_degrees()
			if map.pending_trap_key != "":
				map.resolve_trap(0)
				continue
			var actions: Dictionary = map.available_actions()
			if actions.is_empty():
				break
			map.apply(actions.keys()[0] as String)
			assert_int(absi(map.yaw_degrees() - before)).override_failure_message(
				"ett steg vred kameran %d grader" % absi(map.yaw_degrees() - before)).is_less_equal(180)
			assert_int(posmod(map.yaw_degrees(), 90)).is_equal(0)


func test_the_silent_stretch_is_longer_than_its_neighbours() -> void:
	# §2.4: exakt en kant per våning är avsiktligt händelselös och ett steg längre.
	for seed_value: int in range(20):
		var map: CorridorMap = _map(seed_value)
		var silent: int = 0
		for key: String in map.tiles():
			if bool((map.cells[key] as Dictionary)["silent_stretch"]):
				silent += 1
		assert_int(silent).override_failure_message(
			"seed %d markerade %d tysta sträckor" % [seed_value, silent]).is_equal(1)


func test_the_events_log_is_drained_once() -> void:
	var map: CorridorMap = _map(7)
	assert_array(map.events_since_last()).is_not_empty()
	assert_array(map.events_since_last()).is_empty()
