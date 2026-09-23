extends GdUnitTestSuite
## "All styrka är dödlig" (M6 steg 4). PROGRESSION_REDESIGN §3.4: trappbanken,
## döden med Kistan, permadöden och vinsten.


func _run_with(ids: Array, level: int = 5) -> Dictionary:
	var meta: Meta = Meta.fresh()
	var hero: Hero = meta.ensure_hero(1)
	hero.level = level
	for id: Variant in ids:
		hero.equip(Content.make_item(String(id)))
	var run: RunState = RunState.new_run(1)
	Expedition.begin(meta, run, 1)
	return {"meta": meta, "run": run}


func test_going_down_makes_everything_unsecured_and_leaves_the_roster_alone() -> void:
	var setup: Dictionary = _run_with(["SLAG_PLATE", "SCRAP_CAP"])
	var meta: Meta = setup["meta"]
	var run: RunState = setup["run"]
	for item: Item in run.carried_items():
		assert_bool(item.secured).is_false()
	for item: Item in meta.roster.active().equipped_items():
		assert_bool(item.secured).override_failure_message(
			"rostrets post är hjälten som hen gick ner").is_true()
	assert_int(run.combat.player_max_hp).is_equal(106)
	assert_int(meta.runs_started).is_equal(1)


func test_the_stairs_bank_secures_for_good_but_the_hero_stops_wearing_it() -> void:
	var setup: Dictionary = _run_with(["SLAG_PLATE", "SCRAP_CAP"])
	var meta: Meta = setup["meta"]
	var run: RunState = setup["run"]
	# carried_items: SLAG_PLATE (CHEST) kommer före SCRAP_CAP (HEAD) i slotordning.
	var sent: Array[Item] = Expedition.bank(meta, run, [1])
	assert_int(sent.size()).is_equal(1)
	assert_str(sent[0].id).is_equal("SCRAP_CAP")
	assert_int(meta.bank.items.size()).is_equal(1)
	assert_bool(meta.bank.items[0].secured).is_true()
	assert_object(run.hero.equipped("HEAD")).is_null()
	assert_int(run.combat.player_max_hp).override_failure_message(
		"hjälmen bärs inte längre, dess HP ska bort").is_equal(100)


func test_death_without_a_chest_loses_everything_and_buries_the_hero() -> void:
	var setup: Dictionary = _run_with(["SLAG_PLATE", "DOMINO"])
	var meta: Meta = setup["meta"]
	var run: RunState = setup["run"]
	var name: String = run.hero.name
	assert_int(Expedition.rescue_capacity(meta, run)).is_equal(0)
	var result: Dictionary = Expedition.die(meta, run, [0, 1], "SLAGJAW")
	assert_array(result["rescued"] as Array).is_empty()
	assert_int((result["lost"] as Array).size()).is_equal(2)
	assert_int(meta.chest.items.size()).is_equal(0)
	assert_object(meta.roster.active()).is_null()
	assert_str(String(meta.roster.fallen[0]["name"])).is_equal(name)
	assert_str(String(meta.roster.fallen[0]["killed_by"])).is_equal("SLAGJAW")


func test_the_chest_rescues_the_players_choice_up_to_its_level() -> void:
	var setup: Dictionary = _run_with(["SLAG_PLATE", "DOMINO", "SCRAP_CAP"])
	var meta: Meta = setup["meta"]
	var run: RunState = setup["run"]
	meta.buildings[Buildings.CHEST] = 1
	var result: Dictionary = Expedition.die(meta, run, [0, 2], "RUST_RAT")
	assert_array(result["rescued"] as Array).is_equal(["DOMINO"])
	assert_int(meta.chest.items.size()).is_equal(1)
	assert_bool(meta.chest.items[0].secured).is_true()


func test_the_rescue_ad_and_marrows_tarp_each_add_a_slot() -> void:
	var setup: Dictionary = _run_with(["SLAG_PLATE", "DOMINO", "MARROWS_TARP", "SCRAP_CAP"])
	var meta: Meta = setup["meta"]
	var run: RunState = setup["run"]
	meta.buildings[Buildings.CHEST] = 1
	assert_int(Expedition.rescue_capacity(meta, run)).is_equal(2)
	assert_int(Expedition.rescue_capacity(meta, run, 1)).is_equal(3)
	var result: Dictionary = Expedition.die(meta, run, [0, 1, 2, 3], "RUST_RAT", 1)
	assert_int((result["rescued"] as Array).size()).is_equal(3)


func test_a_new_hero_is_recruited_in_the_tavern_wearing_the_chest() -> void:
	var setup: Dictionary = _run_with(["SLAG_PLATE", "DOMINO"])
	var meta: Meta = setup["meta"]
	var run: RunState = setup["run"]
	meta.buildings[Buildings.CHEST] = 2
	Expedition.die(meta, run, [0, 1], "RUST_RAT")
	var fresh: Hero = Expedition.recruit_replacement(meta, 99)
	assert_object(fresh).is_not_null()
	assert_str(fresh.name).is_not_equal(String(meta.roster.fallen[0]["name"]))
	# Nivå 1 bär WEAPON och CHEST: båda räddade plaggen passar.
	assert_str(fresh.equipped("CHEST").id).is_equal("SLAG_PLATE")
	assert_str(fresh.equipped("WEAPON").id).is_equal("DOMINO")
	assert_int(meta.chest.items.size()).is_equal(0)


func test_a_win_secures_what_is_worn_banks_the_pack_and_pays_xp() -> void:
	var setup: Dictionary = _run_with(["SLAG_PLATE"], 1)
	var meta: Meta = setup["meta"]
	var run: RunState = setup["run"]
	GearRules.take_item(run, Content.make_item("SCRAP_CAP"))  # HEAD är låst: packningen
	var result: Dictionary = Expedition.win(meta, run, 3, 1)
	assert_int(int(result["xp"])).is_equal(3 + 3 + 5)
	assert_int(int(result["level_ups"])).is_equal(1)
	var hero: Hero = meta.roster.active()
	assert_int(hero.level).is_equal(2)
	assert_bool(hero.equipped("CHEST").secured).is_true()
	assert_str(meta.bank.items[0].id).is_equal("SCRAP_CAP")
	assert_int(meta.bosses_killed).is_equal(1)


func test_an_abandoned_run_leaves_the_hero_as_they_went_down() -> void:
	var setup: Dictionary = _run_with(["SLAG_PLATE"])
	var meta: Meta = setup["meta"]
	var run: RunState = setup["run"]
	GearRules.take_item(run, Content.make_item("DOMINO"))
	# Ingen die(), ingen win(): runnen bara försvinner (ny run, "Reset save").
	assert_object(meta.roster.active().equipped("WEAPON")).is_null()
	assert_str(meta.roster.active().equipped("CHEST").id).is_equal("SLAG_PLATE")


func test_storage_can_dress_the_active_hero_and_the_old_piece_goes_to_the_bank() -> void:
	var meta: Meta = Meta.fresh()
	var hero: Hero = meta.ensure_hero(3)
	hero.equip(Content.make_item("SLAG_PLATE"))
	meta.chest.store([Content.make_item("BLOOD_PRICE"), Content.make_item("SCRAP_CAP")])
	assert_bool(Expedition.equip_from_storage(meta, hero, "chest", 1)).override_failure_message(
		"HEAD är låst på nivå 1").is_false()
	assert_bool(Expedition.equip_from_storage(meta, hero, "chest", 0)).is_true()
	assert_str(hero.equipped("CHEST").id).is_equal("BLOOD_PRICE")
	assert_str(meta.bank.items[0].id).is_equal("SLAG_PLATE")
	assert_bool(Expedition.unequip_to_bank(meta, hero, "CHEST")).is_true()
	assert_int(meta.bank.items.size()).is_equal(2)
