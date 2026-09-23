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


## [b]Ändrat i M6 (motivering):[/b] garanti 4 krävde "minst en RELIC". Reliker
## blev gear och RELIC lämnade poolen (DECISIONS 2026-09-23), så garantin gäller
## nu ett föremål – när ett droppat föremål finns bland kandidaterna.
func test_after_boss_everything_is_uncommon_or_better_and_includes_gear() -> void:
	var pool: Array[Dictionary] = _pool()
	pool.append(Rewards.gear_option(Content.make_item("DOMINO"), {"slot": "WEAPON", "to_pack": false}))
	for seed_value: int in range(200):
		var options: Array[Dictionary] = Rewards.generate(pool, Rng.new(seed_value), 0)
		var has_gear: bool = false
		for option: Dictionary in options:
			assert_int(int(option["rarity"])).is_greater_equal(Rules.Rarity.UNCOMMON)
			if String(option["category"]) == Rewards.CATEGORY_GEAR:
				has_gear = true
		assert_bool(has_gear).is_true()


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


## [b]Ändrat i M6 (motivering):[/b] poolen hade tre kategorier. RELIC utgick
## (reliker blev gear som droppar, DECISIONS 2026-09-23); poolen har nu sidor och
## slot-byten, och inte en enda relik.
func test_content_pool_covers_faces_and_slot_swaps_and_no_relics() -> void:
	var categories: Dictionary = {}
	for entry: Dictionary in _pool():
		categories[String(entry["category"])] = true
	assert_int(categories.size()).is_equal(2)
	assert_bool(categories.has(Rewards.CATEGORY_FORGE_FACE)).is_true()
	assert_bool(categories.has(Rewards.CATEGORY_SLOT_SWAP)).is_true()
	assert_bool(categories.has(Rewards.CATEGORY_RELIC)).is_false()


func test_drops_take_at_most_two_cards_and_never_the_last_face() -> void:
	var drops: Array[Dictionary] = []
	for id: String in ["SCRAP_CAP", "SLAG_PLATE", "DOMINO"]:
		drops.append(Rewards.gear_option(Content.make_item(id), {"slot": "HEAD", "to_pack": true}))
	for seed_value: int in range(100):
		var options: Array[Dictionary] = Rewards.with_drops(
			Rewards.generate(_pool(), Rng.new(seed_value), 1), drops)
		assert_int(options.size()).is_equal(Rewards.OPTION_COUNT)
		var gear: int = 0
		var faces: int = 0
		for option: Dictionary in options:
			if String(option["category"]) == Rewards.CATEGORY_GEAR:
				gear += 1
			if String(option["category"]) == Rewards.CATEGORY_FORGE_FACE:
				faces += 1
		assert_int(gear).is_equal(Rewards.MAX_GEAR_OPTIONS)
		assert_int(faces).is_greater_equal(1)
		# Sällsyntast först: DOMINO (rare) ska alltid vara med.
		var ids: Array = []
		for option: Dictionary in options:
			ids.append(String(option["id"]))
		assert_bool(ids.has("GEAR_DOMINO")).is_true()


func _count_rare(floor_index: int, iterations: int) -> int:
	var count: int = 0
	for seed_value: int in range(iterations):
		for option: Dictionary in Rewards.generate(_pool(), Rng.new(seed_value), floor_index):
			if int(option["rarity"]) == Rules.Rarity.RARE:
				count += 1
	return count
