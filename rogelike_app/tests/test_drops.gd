extends GdUnitTestSuite
## Droppar och ceremoni (M6 steg 3). PROGRESSION_REDESIGN §3.3.


func _ctx(epic_allowed: bool = false, first_boss: bool = false) -> Dictionary:
	return Drops.context(1, epic_allowed, [], [], first_boss)


func _rate(source: String, rolls: int) -> Dictionary:
	var hits: int = 0
	var up: int = 0
	for i: int in range(rolls):
		var item: Item = Drops.roll_source(source, Rng.new(i * 7 + 1), _ctx())
		if item != null:
			hits += 1
			if item.rarity >= Rules.Rarity.UNCOMMON:
				up += 1
	return {"rate": float(hits) / float(rolls), "up": float(up) / maxf(1.0, float(hits))}


func test_the_same_room_drops_the_same_items_for_the_same_seed() -> void:
	var ids: Array = ["THORN_IMP", "IRON_TICK", "RUST_RAT"]
	var a: Array[Item] = Drops.roll_room(ids, Drops.stream(Rng.new(4242), "f1r3a"), _ctx())
	var b: Array[Item] = Drops.roll_room(ids, Drops.stream(Rng.new(4242), "f1r3a"), _ctx())
	assert_str(JSON.stringify(Item.list_to_dicts(a))).is_equal(JSON.stringify(Item.list_to_dicts(b)))


func test_rolling_drops_never_moves_the_combat_stream() -> void:
	var rng: Rng = Rng.new(99)
	var before: Dictionary = rng.state()
	Drops.roll_room(["SLAGJAW"], Drops.stream(rng, "f1r4"), _ctx())
	assert_str(JSON.stringify(rng.state())).is_equal(JSON.stringify(before))


func test_common_enemies_drop_at_the_table_rate_and_only_common() -> void:
	var stats: Dictionary = _rate("RUST_RAT", 4000)
	var chance: float = float((Drops.TABLE["RUST_RAT"] as Dictionary)["chance"])
	assert_float(float(stats["rate"])).is_between(chance - 0.02, chance + 0.02)
	assert_float(float(stats["up"])).is_equal(0.0)


func test_tougher_enemies_drop_more_often_and_a_quarter_uncommon() -> void:
	var stats: Dictionary = _rate("IRON_TICK", 4000)
	var chance: float = float((Drops.TABLE["IRON_TICK"] as Dictionary)["chance"])
	assert_float(chance).is_greater(float((Drops.TABLE["RUST_RAT"] as Dictionary)["chance"]))
	assert_float(float(stats["rate"])).is_between(chance - 0.03, chance + 0.03)
	assert_float(float(stats["up"])).is_between(0.19, 0.31)


func test_the_boss_always_drops_and_epic_only_when_allowed() -> void:
	var epics: int = 0
	var rares: int = 0
	for i: int in range(400):
		var locked: Item = Drops.roll_source("SLAGJAW", Rng.new(i), _ctx(false))
		assert_int(locked.rarity).is_between(Rules.Rarity.UNCOMMON, Rules.Rarity.RARE)
		if locked.rarity == Rules.Rarity.RARE:
			rares += 1
		var open: Item = Drops.roll_source("SLAGJAW", Rng.new(i), _ctx(true))
		assert_int(open.rarity).is_greater_equal(Rules.Rarity.UNCOMMON)
		if open.rarity == Rules.Rarity.EPIC:
			epics += 1
	assert_int(epics).is_between(30, 95)
	assert_int(rares).is_between(200, 280)


func test_the_first_boss_kill_drops_a_rare_boss_item_you_have_never_found() -> void:
	for i: int in range(60):
		var ctx: Dictionary = Drops.context(1, false, [], ["PIT_STRIDERS"], true)
		var item: Item = Drops.roll_source("SLAGJAW", Rng.new(i), ctx)
		assert_int(item.rarity).is_greater_equal(Rules.Rarity.RARE)
		assert_bool((Content.GEAR[item.id]["sources"] as Array).has("SLAGJAW")).is_true()
		assert_str(item.id).is_not_equal("PIT_STRIDERS")


func test_no_more_than_two_epics_per_run() -> void:
	var ctx: Dictionary = _ctx(true)
	var epics: int = 0
	for i: int in range(200):
		var item: Item = Drops.roll_source("SLAGJAW", Rng.new(i), ctx)
		if item != null and item.rarity == Rules.Rarity.EPIC:
			epics += 1
	assert_int(epics).is_less_equal(Drops.MAX_EPICS_PER_RUN)


func test_a_room_never_drops_something_the_hero_already_carries() -> void:
	var carried: Array = ["DOMINO", "PIT_STRIDERS", "TWIN_PIP"]
	for i: int in range(100):
		var ctx: Dictionary = Drops.context(1, false, carried)
		var drops: Array[Item] = Drops.roll_room(["SLAGJAW"], Rng.new(i), ctx)
		for item: Item in drops:
			assert_bool(carried.has(item.id)).is_false()


func test_a_room_guarantee_adds_one_item_at_the_minimum_rarity() -> void:
	for i: int in range(100):
		var ctx: Dictionary = Drops.context(1, false, [], [], false, 0, Rules.Rarity.UNCOMMON)
		var drops: Array[Item] = Drops.roll_room(["RUST_RAT"], Rng.new(i), ctx)
		var best: int = -1
		for item: Item in drops:
			best = maxi(best, item.rarity)
		assert_int(best).is_greater_equal(Rules.Rarity.UNCOMMON)


func test_every_drop_is_unsecured_until_banked_or_won() -> void:
	var item: Item = Drops.roll_source("SLAGJAW", Rng.new(1), _ctx())
	assert_bool(item.secured).is_false()


func test_the_ceremony_event_carries_rarity_and_a_length_that_grows_with_it() -> void:
	var items: Array = [Content.make_item("SCRAP_CAP"), Content.make_item("TALLOW_HOOD"),
		Content.make_item("DOMINO"), Content.make_item("SIXTH_SEAT")]
	var events: Array[Dictionary] = Drops.ceremony(items, {"SCRAP_CAP": "RUST_RAT"})
	assert_int(events.size()).is_equal(4)
	assert_str(String(events[0]["t"])).is_equal("item_dropped")
	assert_str(String(events[0]["source"])).is_equal("RUST_RAT")
	assert_str(String(events[3]["rarity_name"])).is_equal("epic")
	for i: int in range(1, 4):
		assert_int(int(events[i]["ms_hint"])).is_greater(int(events[i - 1]["ms_hint"]))
	assert_int(int(events[0]["ms_hint"])).is_equal(200)
	assert_int(int(events[3]["ms_hint"])).is_equal(900)


func test_after_a_fight_one_of_three_can_be_the_enemys_drop() -> void:
	var hero: Hero = Hero.new("h1", "A")
	var found_gear_card: bool = false
	for i: int in range(200):
		var drops: Array[Item] = Drops.roll_room(["THORN_IMP", "IRON_TICK", "RUST_RAT"], Rng.new(i), _ctx())
		var gear: Array[Dictionary] = []
		for item: Item in drops:
			gear.append(Rewards.gear_option(item, GearRules.equip_target(hero, item)))
		var options: Array[Dictionary] = Rewards.with_drops(
			Rewards.generate(Content.reward_pool(), Rng.new(i), 1), gear)
		assert_int(options.size()).is_equal(Rewards.OPTION_COUNT)
		for option: Dictionary in options:
			if String(option["category"]) == Rewards.CATEGORY_GEAR:
				found_gear_card = true
				var target: Dictionary = RewardApply.default_target(Content.smith_state(), option)
				assert_bool(target.has("slot")).is_true()
	assert_bool(found_gear_card).is_true()


func test_a_gear_card_describes_where_the_item_goes() -> void:
	var hero: Hero = Hero.new("h1", "A")
	var cap: Item = Content.make_item("SCRAP_CAP")
	var option: Dictionary = Rewards.gear_option(cap, GearRules.equip_target(hero, cap))
	var text: String = RewardApply.describe(Content.smith_state(), option,
		RewardApply.default_target(Content.smith_state(), option))
	assert_str(text).is_not_empty()
	assert_bool(bool(((option["data"] as Dictionary)["target"] as Dictionary)["to_pack"])).override_failure_message(
		"HEAD är låst på nivå 1 – hjälmen ska åka i packningen").is_true()
