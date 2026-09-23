extends GdUnitTestSuite
## Gear-modellen (M6 steg 1): katalogen, läsbarhetslagarna, hjälten, rostret,
## Kistan, banken och sparfilerna. PROGRESSION_REDESIGN §3–§4.

const TEST_PATH: String = "user://test_gear_save.json"
const TEST_META_PATH: String = "user://test_gear_meta.json"

var _save_path: String = ""
var _meta_path: String = ""


func before_test() -> void:
	_save_path = SaveIO.save_path
	_meta_path = SaveIO.meta_path
	SaveIO.save_path = TEST_PATH
	SaveIO.meta_path = TEST_META_PATH
	SaveIO.clear()
	SaveIO.clear_meta()


func after_test() -> void:
	SaveIO.clear()
	SaveIO.clear_meta()
	SaveIO.save_path = _save_path
	SaveIO.meta_path = _meta_path


# --- Katalogen ---------------------------------------------------------------

func test_all_22_items_from_the_design_exist_plus_the_six_relics() -> void:
	for id: String in Content.GEAR_CATALOGUE_22:
		assert_bool(Content.GEAR.has(id)).override_failure_message("%s saknas" % id).is_true()
	for id: String in Content.RELICS:
		assert_bool(Content.GEAR.has(id)).override_failure_message(
			"reliken %s blev inte gear" % id).is_true()
	assert_int(Content.GEAR.size()).is_equal(22 + Content.RELICS.size())


func test_converted_relics_hang_in_the_slot_the_sheet_already_used() -> void:
	for id: String in Content.RELICS:
		assert_str(Content.make_item(id).slot).is_equal(Content.relic_slot(id))
		assert_int(Content.make_item(id).rarity).is_equal(int((Content.RELICS[id] as Dictionary)["rarity"]))


func test_every_item_has_a_real_slot_known_effects_and_a_drop_source() -> void:
	var sources: Array = ["RUST_RAT", "SLAG_MOTH", "THORN_IMP", "PIP_THIEF", "IRON_TICK",
		"GRAVE_HAND", "SLAGJAW", Content.SOURCE_ELITE, Content.SOURCE_ALTAR]
	for id: String in Content.GEAR:
		var item: Item = Content.make_item(id)
		assert_bool(Content.SHEET_SLOTS.has(item.slot)).override_failure_message(
			"%s hänger i en slot som inte finns: %s" % [id, item.slot]).is_true()
		assert_bool(item.effects.is_empty()).is_false()
		for effect: Dictionary in item.effects:
			assert_bool(GearRules.KNOWN_KINDS.has(String(effect["kind"]))).override_failure_message(
				"%s har en okänd effekttyp %s" % [id, effect["kind"]]).is_true()
		var item_sources: Array = (Content.GEAR[id] as Dictionary)["sources"] as Array
		assert_bool(item_sources.is_empty()).is_false()
		for source: Variant in item_sources:
			assert_bool(sources.has(String(source))).override_failure_message(
				"%s droppar från okänd källa %s" % [id, source]).is_true()


## Läsbarhetslag 2 (§3.2): högst en ren stat-effekt, och bara på COMMON.
func test_stat_effects_only_on_common_and_at_most_one() -> void:
	for id: String in Content.GEAR:
		assert_bool(GearRules.violates_stat_law(Content.make_item(id))).override_failure_message(
			"%s bryter läsbarhetslag 2" % id).is_false()
	var bad: Item = Content.make_item("TALLOW_HOOD")
	bad.effects.append({"kind": GearRules.MAX_HP, "amount": 5})
	assert_bool(GearRules.violates_stat_law(bad)).is_true()


func test_the_ui_contract_fields_are_derived_from_the_id() -> void:
	var item: Item = Content.make_item("PIPSIGHT_LENS")
	assert_str(item.icon_id).is_equal("gear.PIPSIGHT_LENS")
	assert_str(item.name_key).is_equal("GEAR_PIPSIGHT_LENS")
	assert_str(item.effect_summary_key).is_equal("GEAR_PIPSIGHT_LENS_DESC")
	assert_int(item.rarity).is_equal(Rules.Rarity.RARE)


func test_every_item_icon_is_in_the_art_manifest() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/manifest.json"))
	assert_bool(raw is Dictionary).is_true()
	var data: Dictionary = raw as Dictionary
	var entries: Variant = data.get("entries", data)
	var ids: Dictionary = {}
	if entries is Dictionary:
		for key: Variant in entries as Dictionary:
			ids[String(key)] = true
	else:
		for entry: Variant in entries as Array:
			ids[String((entry as Dictionary).get("id", ""))] = true
	for id: String in Content.GEAR:
		var icon: String = Content.make_item(id).icon_id
		assert_bool(ids.has(icon)).override_failure_message(
			"%s pekar på %s som inte finns i manifestet" % [id, icon]).is_true()


func test_every_item_and_quirk_has_a_name_and_summary_row() -> void:
	var keys: Dictionary = {}
	var file: FileAccess = FileAccess.open("res://assets/i18n/translations.csv", FileAccess.READ)
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() >= 3 and row[1] != "" and row[2] != "":
			keys[row[0]] = true
	for id: String in Content.GEAR:
		var item: Item = Content.make_item(id)
		assert_bool(keys.has(item.name_key)).override_failure_message("%s saknas" % item.name_key).is_true()
		assert_bool(keys.has(item.effect_summary_key)).override_failure_message(
			"%s saknas" % item.effect_summary_key).is_true()
	for id: String in Content.QUIRKS:
		var quirk: Item = Content.quirk_item(id)
		assert_bool(keys.has(quirk.name_key)).is_true()
		assert_bool(keys.has(quirk.effect_summary_key)).is_true()


func test_the_rarity_mix_has_two_epics() -> void:
	assert_int(Content.gear_ids(Rules.Rarity.EPIC).size()).is_equal(2)
	assert_bool(Content.gear_ids(Rules.Rarity.EPIC).has("SLAGJAW_TOOTH")).is_true()
	assert_bool(Content.gear_ids(Rules.Rarity.EPIC).has("SIXTH_SEAT")).is_true()


func test_an_item_survives_a_json_round_trip() -> void:
	var item: Item = Content.make_item("CHIPPED_HAMMER")
	item.level = 2
	item.secured = false
	var back: Item = Item.from_dict(JSON.parse_string(JSON.stringify(item.to_dict())) as Dictionary)
	assert_str(JSON.stringify(back.to_dict())).is_equal(JSON.stringify(item.to_dict()))
	assert_int(back.effect_value(back.effects[0])).override_failure_message(
		"nivå 2 med per_level 1 ska ge 2 + 2").is_equal(4)
	assert_int(typeof(back.effects[0]["slot"])).is_equal(TYPE_INT)


# --- Hjälten -----------------------------------------------------------------

func test_levels_unlock_two_to_seven_slots() -> void:
	var hero: Hero = Hero.new("h1", "Brann")
	var expected: Array[int] = [2, 3, 4, 6, 7]
	for lvl: int in range(1, 6):
		hero.level = lvl
		assert_int(hero.gear_slots_unlocked()).is_equal(expected[lvl - 1])
	hero.level = 1
	assert_array(hero.unlocked_slots()).is_equal(["WEAPON", "CHEST"])
	assert_int(Hero.level_for_slot("HEAD")).is_equal(2)
	assert_int(Hero.level_for_slot("AMULET")).is_equal(5)


func test_xp_follows_the_design_curve() -> void:
	var hero: Hero = Hero.new("h1", "Brann")
	assert_int(Hero.xp_for_run(3, 1, true)).is_equal(3 + 3 + 5)
	assert_int(hero.add_xp(9)).is_equal(0)
	assert_int(hero.add_xp(1)).is_equal(1)
	assert_int(hero.level).is_equal(2)
	hero.add_xp(1000)
	assert_int(hero.level).is_equal(Hero.MAX_LEVEL)
	assert_int(hero.xp_to_next()).is_equal(0)


func test_a_locked_slot_refuses_and_nothing_is_lost() -> void:
	var hero: Hero = Hero.new("h1", "Brann")
	var cap: Item = Content.make_item("SCRAP_CAP")
	assert_object(hero.equip(cap)).is_same(cap)
	assert_object(hero.equipped("HEAD")).is_null()
	var hammer: Item = Content.make_item("CHIPPED_HAMMER")
	assert_object(hero.equip(hammer)).is_null()
	assert_object(hero.equipped("WEAPON")).is_same(hammer)
	var domino: Item = Content.make_item("DOMINO")
	assert_object(hero.equip(domino)).is_same(hammer)


func test_a_hero_survives_a_json_round_trip() -> void:
	var hero: Hero = Content.recruit_hero(Rng.new(3), [], "b", 1)
	hero.id = "h7"
	hero.equip(Content.make_item("SLAG_PLATE"))
	hero.add_xp(12)
	var back: Hero = Hero.from_dict(JSON.parse_string(JSON.stringify(hero.to_dict())) as Dictionary)
	assert_str(JSON.stringify(back.to_dict())).is_equal(JSON.stringify(hero.to_dict()))
	assert_str(back.equipped("CHEST").id).is_equal("SLAG_PLATE")
	assert_bool(Content.QUIRKS.has(back.quirk)).is_true()


func test_recruiting_is_seeded_and_avoids_taken_names() -> void:
	var a: Hero = Content.recruit_hero(Rng.new(42), [])
	var b: Hero = Content.recruit_hero(Rng.new(42), [])
	assert_str(a.name).is_equal(b.name)
	assert_str(a.quirk).is_equal(b.quirk)
	var c: Hero = Content.recruit_hero(Rng.new(42), [a.name])
	assert_str(c.name).is_not_equal(a.name)


# --- Rostret -----------------------------------------------------------------

func test_the_roster_holds_at_most_four_and_obeys_the_tavern() -> void:
	var roster: Roster = Roster.new()
	for i: int in range(6):
		roster.add(Hero.new("", "H%d" % i), 99)
	assert_int(roster.size()).is_equal(Roster.MAX_HEROES)
	var small: Roster = Roster.new()
	assert_bool(small.add(Hero.new("", "A"), 1)).is_true()
	assert_bool(small.add(Hero.new("", "B"), 1)).override_failure_message(
		"tavernan nivå 0 har en plats").is_false()


func test_permadeath_moves_the_name_to_the_graveyard() -> void:
	var roster: Roster = Roster.new()
	roster.add(Hero.new("", "A"))
	roster.add(Hero.new("", "B"))
	roster.set_active(1)
	var dead_id: String = roster.active().id
	assert_bool(roster.bury(dead_id, "SLAGJAW", 4)).is_true()
	assert_int(roster.size()).is_equal(1)
	assert_str(roster.active().name).is_equal("A")
	assert_int(roster.fallen.size()).is_equal(1)
	assert_str(String(roster.fallen[0]["name"])).is_equal("B")
	assert_str(String(roster.fallen[0]["killed_by"])).is_equal("SLAGJAW")
	var back: Roster = Roster.from_dict(JSON.parse_string(JSON.stringify(roster.to_dict())) as Dictionary)
	assert_str(JSON.stringify(back.to_dict())).is_equal(JSON.stringify(roster.to_dict()))


# --- Kistan och banken ---------------------------------------------------------

func test_the_chest_rescues_level_many_and_its_contents_are_secured() -> void:
	assert_int(Chest.rescue_capacity(0)).is_equal(0)
	assert_int(Chest.rescue_capacity(2)).is_equal(2)
	assert_int(Chest.rescue_capacity(9)).is_equal(3)
	var chest: Chest = Chest.new()
	var item: Item = Content.make_item("MOTH_EDGE")
	item.secured = false
	chest.store([item])
	assert_bool(chest.items[0].secured).is_true()
	assert_bool(item.secured).override_failure_message("Kistan lagrar en kopia").is_false()


func test_marrows_tarp_adds_a_rescue_slot_only_when_worn() -> void:
	var hero: Hero = Hero.new("h1", "A")
	hero.level = 4
	assert_int(GearRules.rescue_slots(1, hero)).is_equal(1)
	hero.equip(Content.make_item("MARROWS_TARP"))
	assert_int(GearRules.rescue_slots(1, hero)).is_equal(2)


func test_the_bank_and_chest_survive_the_profile_file() -> void:
	var meta: Meta = Meta.fresh()
	meta.ensure_hero(11, "b")
	meta.bank.deposit([Content.make_item("SPIKE_MAUL")])
	meta.chest.store([Content.make_item("TWIN_PIP")])
	meta.buildings[Buildings.CHEST] = 2
	meta.found_gear.append("TWIN_PIP")
	assert_bool(SaveIO.save_meta(meta)).is_true()
	var loaded: Meta = SaveIO.load_meta()
	assert_str(JSON.stringify(loaded.to_dict().merged({"saved_at": ""}))).is_equal(
		JSON.stringify(meta.to_dict().merged({"saved_at": ""})))
	assert_str(loaded.roster.active().name).is_equal(meta.roster.active().name)
	assert_str(loaded.bank.items[0].id).is_equal("SPIKE_MAUL")
	assert_int(loaded.building_level(Buildings.CHEST)).is_equal(2)


func test_ensure_hero_is_seeded_and_idempotent() -> void:
	var a: Meta = Meta.fresh()
	var b: Meta = Meta.fresh()
	var hero_a: Hero = a.ensure_hero(77)
	var hero_b: Hero = b.ensure_hero(77)
	assert_str(hero_a.name).is_equal(hero_b.name)
	assert_object(a.ensure_hero(1)).is_same(hero_a)
	assert_str(hero_a.id).is_equal("h1")


# --- Sparfilen: version 4 och migreringen från reliker --------------------------

func _v3_save_with_relics(relic_ids: Array) -> Dictionary:
	var run: RunState = RunState.new_run(4242)
	for id: Variant in relic_ids:
		run.combat.relics.append(Content.make_relic(String(id)))
	var rng: Rng = Rng.new(3)
	var graph: RunGraph = RunGraph.generate_floor(1, rng)
	var data: Dictionary = run.to_dict()
	data.erase("hero")
	data.erase("pack")
	(data["combat"] as Dictionary).erase("gear")
	data["version"] = 3
	var meta: Dictionary = data["meta"] as Dictionary
	meta["corridor"] = CorridorMap.build(graph, rng.fork("corridor")).to_dict()
	meta["graph"] = graph.to_dict()
	meta["node_id"] = graph.start_id
	meta["tutorial_room"] = -1
	return data


func test_a_v3_save_turns_relics_into_gear_in_the_right_slot() -> void:
	var data: Dictionary = _v3_save_with_relics(["DOMINO", "OCTOPUS"])
	var file: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var loaded: RunState = SaveIO.load_run()
	assert_object(loaded).is_not_null()
	assert_int(loaded.version).is_equal(RunState.SAVE_VERSION)
	assert_object(loaded.hero).is_not_null()
	assert_str(loaded.hero.equipped("WEAPON").id).is_equal("DOMINO")
	assert_str(loaded.hero.equipped("HANDS").id).is_equal("OCTOPUS")
	assert_bool(loaded.hero.equipped("WEAPON").secured).override_failure_message(
		"det som bärs i en pågående run är osäkrat").is_false()
	# Klassreliken ligger kvar; de omgjorda är borta ur relics och finns i gear.
	var relic_ids: Array = []
	for relic: Relic in loaded.combat.relics:
		relic_ids.append(relic.id)
	assert_array(relic_ids).is_equal(["ANVIL_BLESSING"])
	assert_bool(GearRules.has_rule(loaded.combat.gear, "DOMINO")).is_true()
	assert_bool(GearRules.has_rule(loaded.combat.gear, "OCTOPUS")).is_true()


func test_a_v4_run_round_trips_hero_pack_and_gear() -> void:
	var run: RunState = RunState.new_run(5)
	run.hero = Hero.new("h1", "Brann")
	GearRules.take_item(run, Content.make_item("SCRAP_CAP"))
	GearRules.take_item(run, Content.make_item("SLAG_PLATE"))
	var back: RunState = RunState.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())) as Dictionary)
	assert_str(JSON.stringify(back.to_dict())).is_equal(JSON.stringify(run.to_dict()))
	assert_int(back.pack.size()).is_equal(1)
	assert_str(back.pack[0].id).is_equal("SCRAP_CAP")
	assert_str(back.hero.equipped("CHEST").id).is_equal("SLAG_PLATE")
	assert_int(back.carried_items().size()).is_equal(2)
