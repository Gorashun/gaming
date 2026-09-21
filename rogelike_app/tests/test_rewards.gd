extends GdUnitTestSuite
## Belöningsvalet: tre unika alternativ, seedat, med garantierna i §4.7.


func _pool() -> Array[Dictionary]:
	return Content.reward_pool()


func test_always_returns_three_options() -> void:
	for seed_value: int in range(300):
		var options: Array[Dictionary] = Rewards.generate(_pool(), Rng.new(seed_value), 1)
		assert_int(options.size()).is_equal(Rewards.OPTION_COUNT)


func test_options_are_always_unique() -> void:
	for seed_value: int in range(300):
		var options: Array[Dictionary] = Rewards.generate(_pool(), Rng.new(seed_value), 1)
		var ids: Dictionary = {}
		for option: Dictionary in options:
			ids[String(option["id"])] = true
		assert_int(ids.size()).is_equal(Rewards.OPTION_COUNT)


func test_same_seed_gives_the_same_three_options() -> void:
	var a: Array[Dictionary] = Rewards.generate(_pool(), Rng.new(4242), 2)
	var b: Array[Dictionary] = Rewards.generate(_pool(), Rng.new(4242), 2)
	assert_str(JSON.stringify(a)).is_equal(JSON.stringify(b))


func test_different_seeds_give_different_options() -> void:
	var distinct: Dictionary = {}
	for seed_value: int in range(60):
		distinct[JSON.stringify(Rewards.generate(_pool(), Rng.new(seed_value), 1))] = true
	assert_int(distinct.size()).is_greater(5)


func test_guarantee_one_forge_face_option() -> void:
	for seed_value: int in range(300):
		var options: Array[Dictionary] = Rewards.generate(_pool(), Rng.new(seed_value), 1)
		var found: bool = false
		for option: Dictionary in options:
			if String(option["category"]) == Rewards.CATEGORY_FORGE_FACE:
				found = true
		assert_bool(found).is_true()


func test_guarantee_uncommon_or_better_from_floor_two() -> void:
	for seed_value: int in range(300):
		var options: Array[Dictionary] = Rewards.generate(_pool(), Rng.new(seed_value), 2)
		var best: int = -1
		for option: Dictionary in options:
			best = maxi(best, int(option["rarity"]))
		assert_int(best).is_greater_equal(Rules.Rarity.UNCOMMON)


func test_after_boss_everything_is_uncommon_or_better_and_includes_a_relic() -> void:
	for seed_value: int in range(200):
		var options: Array[Dictionary] = Rewards.generate(_pool(), Rng.new(seed_value), 0)
		var has_relic: bool = false
		for option: Dictionary in options:
			assert_int(int(option["rarity"])).is_greater_equal(Rules.Rarity.UNCOMMON)
			if String(option["category"]) == Rewards.CATEGORY_RELIC:
				has_relic = true
		assert_bool(has_relic).is_true()


func test_rarity_weights_match_the_design_table() -> void:
	assert_array(Rewards.rarity_weights(1)).is_equal([70.0, 25.0, 5.0])
	assert_array(Rewards.rarity_weights(2)).is_equal([55.0, 33.0, 12.0])
	assert_array(Rewards.rarity_weights(3)).is_equal([40.0, 40.0, 20.0])
	assert_array(Rewards.rarity_weights(0)).is_equal([0.0, 60.0, 40.0])


func test_rare_options_are_rarer_on_floor_one_than_on_floor_three() -> void:
	var rare_floor_one: int = _count_rare(1, 400)
	var rare_floor_three: int = _count_rare(3, 400)
	assert_int(rare_floor_three).is_greater(rare_floor_one)


func test_empty_pool_returns_nothing_instead_of_crashing() -> void:
	assert_int(Rewards.generate([], Rng.new(1), 1).size()).is_equal(0)


func test_small_pool_returns_what_it_can() -> void:
	var pool: Array[Dictionary] = [
		{"id": "A", "category": Rewards.CATEGORY_FORGE_FACE, "rarity": Rules.Rarity.COMMON},
		{"id": "B", "category": Rewards.CATEGORY_RELIC, "rarity": Rules.Rarity.COMMON},
	]
	assert_int(Rewards.generate(pool, Rng.new(1), 1).size()).is_equal(2)


func test_duplicate_ids_in_the_pool_are_ignored() -> void:
	var pool: Array[Dictionary] = [
		{"id": "A", "category": Rewards.CATEGORY_FORGE_FACE, "rarity": Rules.Rarity.COMMON},
		{"id": "A", "category": Rewards.CATEGORY_FORGE_FACE, "rarity": Rules.Rarity.COMMON},
		{"id": "B", "category": Rewards.CATEGORY_RELIC, "rarity": Rules.Rarity.COMMON},
	]
	assert_int(Rewards.generate(pool, Rng.new(1), 1).size()).is_equal(2)


func test_content_pool_covers_all_three_categories() -> void:
	var categories: Dictionary = {}
	for entry: Dictionary in _pool():
		categories[String(entry["category"])] = true
	assert_int(categories.size()).is_equal(3)


func _count_rare(floor_index: int, iterations: int) -> int:
	var count: int = 0
	for seed_value: int in range(iterations):
		for option: Dictionary in Rewards.generate(_pool(), Rng.new(seed_value), floor_index):
			if int(option["rarity"]) == Rules.Rarity.RARE:
				count += 1
	return count
