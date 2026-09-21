extends GdUnitTestSuite
## Tester för den seedade slumpkällan. Determinism är förutsättningen för
## dagliga utmaningar, buggrapporter och alla andra tester i sviten.


func test_same_seed_gives_same_sequence() -> void:
	var a: Rng = Rng.new(4711)
	var b: Rng = Rng.new(4711)
	for i: int in range(200):
		assert_int(a.next_int(1, 6)).is_equal(b.next_int(1, 6))


func test_different_seed_gives_different_sequence() -> void:
	var a: Rng = Rng.new(1)
	var b: Rng = Rng.new(2)
	var same: int = 0
	for i: int in range(100):
		if a.next_int(1, 1000) == b.next_int(1, 1000):
			same += 1
	assert_int(same).is_less(50)


func test_next_int_is_inclusive_and_in_range() -> void:
	var rng: Rng = Rng.new(99)
	var seen: Dictionary = {}
	for i: int in range(500):
		var v: int = rng.next_int(1, 6)
		assert_bool(v >= 1 and v <= 6).is_true()
		seen[v] = true
	assert_int(seen.size()).is_equal(6)


func test_next_int_swaps_reversed_bounds() -> void:
	var rng: Rng = Rng.new(7)
	for i: int in range(50):
		var v: int = rng.next_int(6, 1)
		assert_bool(v >= 1 and v <= 6).is_true()


func test_state_and_restore_resume_exact_sequence() -> void:
	var rng: Rng = Rng.new(12345)
	for i: int in range(17):
		rng.next_int(0, 99)
	var snapshot: Dictionary = rng.state()

	var expected: Array[int] = []
	for i: int in range(25):
		expected.append(rng.next_int(0, 99))

	rng.restore(snapshot)
	var actual: Array[int] = []
	for i: int in range(25):
		actual.append(rng.next_int(0, 99))
	assert_array(actual).is_equal(expected)


func test_from_state_rebuilds_an_equivalent_stream() -> void:
	var rng: Rng = Rng.new(2026)
	for i: int in range(9):
		rng.next_float()
	var snapshot: Dictionary = rng.state()
	var clone: Rng = Rng.from_state(snapshot)
	assert_int(clone.get_seed()).is_equal(2026)
	for i: int in range(20):
		assert_int(clone.next_int(0, 1000)).is_equal(rng.next_int(0, 1000))


func test_state_survives_a_json_roundtrip() -> void:
	# Seed och state lagras som String just för att JSON-tal är float64.
	var rng: Rng = Rng.new(9223372036854775807)
	for i: int in range(5):
		rng.next_int(0, 10)
	var snapshot: Dictionary = rng.state()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(snapshot)) as Dictionary
	var restored: Rng = Rng.from_state(parsed)
	for i: int in range(20):
		assert_int(restored.next_int(0, 10000)).is_equal(rng.next_int(0, 10000))


func test_reset_restarts_from_the_original_seed() -> void:
	var rng: Rng = Rng.new(555)
	var first: Array[int] = []
	for i: int in range(10):
		first.append(rng.next_int(0, 99))
	rng.reset()
	var second: Array[int] = []
	for i: int in range(10):
		second.append(rng.next_int(0, 99))
	assert_array(second).is_equal(first)


func test_pick_returns_null_for_empty_array() -> void:
	assert_object(Rng.new(1).pick([])).is_null()


func test_weighted_pick_never_picks_zero_weight() -> void:
	var rng: Rng = Rng.new(31337)
	for i: int in range(500):
		assert_str(String(rng.weighted_pick(["a", "b", "c"], [1.0, 0.0, 1.0]))).is_not_equal("b")


func test_weighted_pick_respects_weights_roughly() -> void:
	var rng: Rng = Rng.new(8)
	var counts: Dictionary = {"a": 0, "b": 0}
	for i: int in range(4000):
		counts[String(rng.weighted_pick(["a", "b"], [9.0, 1.0]))] += 1
	# Förväntat 3600/400. Generösa gränser så testet inte blir flakigt.
	assert_int(int(counts["a"])).is_greater(3300)
	assert_int(int(counts["b"])).is_less(700)


func test_weighted_pick_falls_back_to_uniform_when_all_weights_are_zero() -> void:
	var rng: Rng = Rng.new(3)
	var value: Variant = rng.weighted_pick(["a", "b"], [0.0, 0.0])
	assert_bool(value == "a" or value == "b").is_true()


func test_weighted_sample_returns_unique_items() -> void:
	var rng: Rng = Rng.new(17)
	var items: Array = ["a", "b", "c", "d", "e"]
	var sample: Array = rng.weighted_sample(items, [1.0, 1.0, 1.0, 1.0, 1.0], 3)
	assert_int(sample.size()).is_equal(3)
	assert_int(_unique_count(sample)).is_equal(3)


func test_weighted_sample_is_capped_by_pool_size() -> void:
	var rng: Rng = Rng.new(17)
	assert_int(rng.weighted_sample(["a", "b"], [1.0, 1.0], 5).size()).is_equal(2)


func test_shuffle_is_deterministic_and_keeps_all_elements() -> void:
	var a: Array = [1, 2, 3, 4, 5, 6, 7, 8]
	var b: Array = a.duplicate()
	Rng.new(42).shuffle(a)
	Rng.new(42).shuffle(b)
	assert_array(a).is_equal(b)
	a.sort()
	assert_array(a).is_equal([1, 2, 3, 4, 5, 6, 7, 8])


func test_fork_is_stable_and_independent_of_the_parent() -> void:
	var parent: Rng = Rng.new(100)
	var first: Array[int] = []
	for i: int in range(10):
		first.append(parent.fork("rewards").next_int(0, 999))
	for i: int in range(50):
		parent.next_int(0, 10)  # Dra ur föräldern.
	var second: Array[int] = []
	for i: int in range(10):
		second.append(parent.fork("rewards").next_int(0, 999))
	assert_array(second).is_equal(first)
	assert_int(parent.fork("combat").get_seed()).is_not_equal(parent.fork("rewards").get_seed())


func _unique_count(values: Array) -> int:
	var seen: Dictionary = {}
	for value: Variant in values:
		seen[value] = true
	return seen.size()
