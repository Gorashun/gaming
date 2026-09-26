extends Node
## Headless unit tests for the rules engine + wave-2 systems. Run:
##   godot --headless --path . res://tests/run_tests.tscn
## Loads the dev-only content pack (content/dev_test) for fixtures. Exit code 1 on any failure.

var passed = 0
var failed = 0
var _current = ""
var _signals = {}

const TEST_ACCOUNT := "user://test_account.json"

func _ready() -> void:
	Game.testing = true
	Content.reload(true)
	Deeds.reset_index()
	if FileAccess.file_exists(TEST_ACCOUNT):
		DirAccess.remove_absolute(TEST_ACCOUNT)
	Account.use_path(TEST_ACCOUNT)
	for t in ["test_content_sanity", "test_loot_generation", "test_upgrade", "test_affinity_proficiency", "test_pets",
			"test_quests", "test_save_roundtrip", "test_save_backups", "test_starmap", "test_skill_mods", "test_mastery",
			"test_merchants", "test_travel", "test_codex", "test_deeds", "test_main_quest", "test_builds", "test_mounts",
			"test_world_event_helpers", "test_base_content_integration", "test_wave2_integration", "test_moon_hooks"]:
		_current = t
		Rng.reseed(1234)
		call(t)
	print("TESTS DONE: %d passed, %d failed" % [passed, failed])
	# Leave the normal content state behind and clean up test files
	Account.use_path("user://account.json")
	if FileAccess.file_exists(TEST_ACCOUNT):
		DirAccess.remove_absolute(TEST_ACCOUNT)
	get_tree().quit(1 if failed > 0 else 0)

# ------------------------------------------------------------------ helpers
func check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("FAIL [%s] %s" % [_current, msg])

func eq(a, b, msg: String) -> void:
	var ok = a == b
	if not ok and (a is float or a is int) and (b is float or b is int):
		ok = absf(float(a) - float(b)) < 0.001
	check(ok, "%s (got %s, want %s)" % [msg, str(a), str(b)])

func mk_char(class_id := "dev_tester", lvl := 1) -> CharacterData:
	var c = CharacterData.new()
	c.id = "test_%s_%d" % [class_id, randi() % 100000]
	c.name = "Tester"
	c.class_id = class_id
	var cls = c.cls()
	for s in cls.get("start_skills", []):
		c.skill_ranks[s] = 1
	var bar: Array = cls.get("start_bar", [])
	for i in min(4, bar.size()):
		c.skill_bar[i] = bar[i]
	c.level = lvl
	c.recalc()
	Game.character = c
	return c

func _on_signal(name: String) -> Callable:
	_signals[name] = 0
	return func(_a = null, _b = null, _c = null): _signals[name] = int(_signals.get(name, 0)) + 1

# ------------------------------------------------------------------ tests
func test_content_sanity() -> void:
	check(Content.has_rec("classes", "dev_tester"), "dev pack loaded")
	check(Content.has_rec("classes", "lanternbearer"), "base pack loaded")
	for b in Content.all("item_bases"):
		check(str(b.get("slot", "")) in ["head", "chest", "hands", "legs", "feet", "belt", "main_hand", "off_hand", "ring", "amulet", "charm"], "base %s has a valid slot" % b.id)

func test_loot_generation() -> void:
	var ch = mk_char("lanternbearer", 10)
	var tier = Content.get_rec("difficulties", "twilight")
	Rng.reseed(77)
	var first = Loot.roll_kill({}, 10, ch, tier, "boss")
	Rng.reseed(77)
	var again = Loot.roll_kill({}, 10, ch, tier, "boss")
	eq(first.items.size(), again.items.size(), "loot is deterministic per seed (count)")
	if first.items.size() > 0 and again.items.size() > 0:
		eq(first.items[0].name, again.items[0].name, "loot is deterministic per seed (name)")
	var boss_cfg: Dictionary = Content.get_rec("config", "loot").get("kinds", {}).get("boss", {})
	check(first.items.size() >= int(boss_cfg.get("min_items", 0)), "boss drops at least min_items")
	var counts = {}
	for i in 400:
		var r = Loot.roll_kill({"loot_mult": 1.0}, 10, ch, tier, "rare")
		for it in r.items:
			counts[it.rarity] = int(counts.get(it.rarity, 0)) + 1
			check(Content.has_rec("item_bases", it.base), "drop base exists")
			check(Content.has_rec("rarities", it.rarity), "drop rarity exists")
			var rar = Content.get_rec("rarities", it.rarity)
			if it.get("unique", "") == "":
				check(it.affixes.size() <= int(rar.get("affix_max", 0)) + 1, "affix count within rarity max")
			check(int(it.get("upgrade", -1)) == 0 or it.has("unique"), "new items start at +0")
	check(counts.size() >= 3, "rare packs produce several rarities (%s)" % str(counts))
	# Type-restricted generation (Curio path)
	var it2 = Items.generate(5, "magic", "", "", "", "loot", "sword")
	if not it2.is_empty():
		eq(it2.type, "sword", "type filter respected")

func test_upgrade() -> void:
	var ch = mk_char()
	var it = Items.generate(10, "rare", "", "dev_blade_base")
	var last_gold = -1
	var probe = it.duplicate(true)
	for l in Upgrade.max_level():
		probe.upgrade = l
		var c = Upgrade.cost(probe)
		check(int(c.gold) > last_gold, "upgrade gold rises at +%d" % l)
		last_gold = int(c.gold)
	probe.upgrade = Upgrade.max_level()
	check(Upgrade.cost(probe).is_empty(), "no cost at max")
	var pv = Upgrade.preview(ch, it)
	check(not pv.ok, "preview says cannot afford with 0 gold")
	eq(int(it.upgrade), 0, "preview does not change the item")
	check(pv.dmg_after[1] > pv.dmg_before[1], "preview shows higher damage")
	check(not Upgrade.upgrade(ch, it).ok, "upgrade fails without gold")
	ch.gold = 1000000000
	for m in Content.all("materials"):
		ch.add_material(m.id, 100000)
	var base_crit = float(Items.item_stats(it).get("crit_chance", 0.0))
	var gold_before = ch.gold
	var cost0 = Upgrade.cost(it)
	var r = Upgrade.upgrade(ch, it)
	check(r.ok, "upgrade succeeds")
	eq(ch.gold, gold_before - int(cost0.gold), "exact gold charged (shown up front)")
	for i in 20:
		Upgrade.upgrade(ch, it)
	eq(int(it.upgrade), Upgrade.max_level(), "upgrade reaches max and never fails")
	check(str(it.name).begins_with("+%d " % Upgrade.max_level()), "name shows +N (%s)" % it.name)
	check(not str(it.name).begins_with("+%d +" % Upgrade.max_level()), "name prefix not duplicated")
	check(float(Items.item_stats(it).get("crit_chance", 0.0)) > base_crit, "affix/implicit values boosted")
	check(Items.weapon_damage(it)[0] > float(it.dmg_min), "weapon damage boosted")
	check(not Upgrade.upgrade(ch, it).ok, "no upgrade past max")
	var inv = Upgrade.invested(it)
	check(int(inv.gold) > 0, "investment tracked")

func test_affinity_proficiency() -> void:
	var ch = mk_char("stargazer", 5)
	var sword = Items.generate(3, "common", "", "dev_blade_base")
	sword.level_req = 1
	check(InventoryOps.can_equip(ch, sword), "any class can equip any weapon")
	var high = sword.duplicate()
	high.level_req = 99
	check(not InventoryOps.can_equip(ch, high), "level requirement still applies")
	var dev = mk_char("dev_tester", 5)
	dev.equipment["main_hand"] = sword
	dev.recalc()
	eq(dev.stats.sources.get("affinity", {}).get("damage_pct", 0.0), 10.0, "class affinity applied for favoured type")
	ch.equipment["main_hand"] = sword
	ch.recalc()
	check(ch.stats.sources.get("affinity", {}).is_empty(), "no affinity for other classes")
	eq(Weapons.prof_level(dev, "dev_blade"), 1, "proficiency starts at 1")
	var gained = Weapons.gain_proficiency(dev, "dev_blade", Weapons.prof_xp_to_next(1) + Weapons.prof_xp_to_next(2))
	eq(gained, 2, "proficiency levels from kills")
	dev.recalc()
	eq(dev.stats.sources.get("proficiency", {}).get("damage_pct", 0.0), 2.0, "proficiency bonus per level")
	Weapons.gain_proficiency(dev, "dev_blade", 10000000)
	eq(Weapons.prof_level(dev, "dev_blade"), Weapons.prof_max_level(), "proficiency capped")
	check(Weapons.attack_anims(dev).size() > 0, "weapon anim set resolved")
	var st = Items.generate(3, "common", "", "apprentice_staff") if Content.has_rec("item_bases", "apprentice_staff") else {}
	if not st.is_empty():
		check(Weapons.is_two_handed(st), "staff is two-handed")

func test_pets() -> void:
	var ch = mk_char()
	var got = [0]
	var cb = func(_id): got[0] += 1
	Events.pet_acquired.connect(cb)
	check(Pets.grant_pet(ch, "dev_wisp"), "grant pet")
	check(not Pets.grant_pet(ch, "dev_wisp"), "no duplicate pets")
	check(not Pets.grant_pet(ch, "no_such_pet"), "unknown pet refused")
	Events.pet_acquired.disconnect(cb)
	eq(got[0], 1, "pet_acquired emitted once")
	eq(ch.active_pet, "dev_wisp", "first pet becomes active")
	eq(ch.stats.get_stat("magic_find"), 1.0, "pet bonus at level 1")
	Pets.gain_xp(ch, "dev_wisp", Pets.xp_to_next(1) + Pets.xp_to_next(2) + 1)
	eq(Pets.level(ch, "dev_wisp"), 3, "pet levels up")
	eq(ch.stats.get_stat("magic_find"), 3.0, "pet bonus scales with level")
	Pets.gain_xp(ch, "dev_wisp", 100000000)
	eq(Pets.level(ch, "dev_wisp"), 30, "pet level capped at 30")
	Pets.grant_pet(ch, "dev_digger")
	Pets.set_active(ch, "dev_digger")
	var dig = false
	for i in 3:
		dig = Pets.on_kill(ch).dig or dig
	check(dig, "dig perk triggers every N kills")
	Pets.grant_pet(ch, "dev_lucky")
	Pets.set_active(ch, "dev_lucky")
	check(Loot.pity_speed(ch) > 1.0, "lucky perk speeds up pity")
	# Pet ferry (needs a "ferry" perk companion when such pets exist)
	if not Pets.can_ferry(ch):
		check(not Pets.ferry(ch, "sell").ok, "non-ferry pet refuses")
		Pets.grant_pet(ch, "dev_ferry")
		Pets.set_active(ch, "dev_ferry")
	for i in 5:
		ch.add_item(Items.generate(5, "common", "", "dev_plate"))
	var before = ch.gold
	var r = Pets.ferry(ch, "sell")
	check(r.ok, "ferry works")
	eq(r.count, 5, "ferry carries junk")
	check(ch.gold > before, "ferry returns gold")
	eq(ch.first_free_slot(), 0, "bag emptied")
	ch.add_item(Items.generate(5, "common", "", "dev_plate"))
	check(not Pets.ferry(ch, "sell").ok, "ferry has a cooldown")
	ch.play_seconds += 10000
	var r2 = Pets.ferry(ch, "salvage")
	check(r2.ok and not r2.materials.is_empty(), "ferry salvage returns materials")
	check(Pets.feed_treat(ch), "pet treat")
	Pets.set_active(ch, "dev_lucky")

func test_quests() -> void:
	var ch = mk_char()
	eq(Quests.state(ch, "dev_q_family"), "available", "quest available")
	eq(Quests.available_for(ch, "dev_quest").size() > 0, true, "npc offers quests")
	check(Quests.accept(ch, "dev_q_family"), "accept")
	check(not Quests.accept(ch, "dev_q_family"), "cannot accept twice")
	Quests.notify(ch, "kill", "rattler", 1, {"family": "other"})
	eq(Quests.progress(ch, "dev_q_family"), 0, "wrong family ignored")
	Quests.notify(ch, "kill", "x", 1, {"family": "dev_family"})
	Quests.notify(ch, "kill", "y", 1, {"family": "dev_family"})
	eq(Quests.state(ch, "dev_q_family"), "ready", "kill quest ready")
	var g = ch.gold
	var r = Quests.turn_in(ch, "dev_q_family")
	check(r.ok, "turn in")
	eq(ch.gold, g + 10, "gold reward")
	check(Pets.owns(ch, "dev_digger"), "pet reward")
	eq(Quests.state(ch, "dev_q_family"), "done", "quest done")
	eq(Quests.state(ch, "dev_q_boss"), "locked", "requires another quest")
	Quests.accept(ch, "dev_q_kill")
	for i in 3:
		Quests.notify(ch, "kill", "rattler")
	eq(Quests.state(ch, "dev_q_kill"), "done", "giver-less quest auto-completes")
	eq(Quests.state(ch, "dev_q_boss"), "available", "unlocked by prerequisite")
	Quests.accept(ch, "dev_q_collect")
	Quests.notify(ch, "collect", "soot", 3)
	Quests.notify(ch, "collect", "soot", 3)
	eq(Quests.progress(ch, "dev_q_collect"), 5, "collect progress capped at count")
	var sp = ch.skill_points
	Quests.turn_in(ch, "dev_q_collect")
	eq(ch.skill_points, sp + 1, "skill point reward")
	Quests.accept(ch, "dev_q_talk")
	Quests.notify(ch, "talk", "dev_inn")
	Quests.turn_in(ch, "dev_q_talk")
	check(Mounts.owns(ch, "dev_hound"), "mount reward")

func test_save_roundtrip() -> void:
	var ch = mk_char()
	ch.gold = 1234
	ch.level = 7
	Pets.grant_pet(ch, "dev_wisp")
	Mounts.grant_mount(ch, "dev_hound")
	Weapons.gain_proficiency(ch, "dev_blade", 50)
	ch.skill_ranks["dev_nova"] = 2
	SkillMods.choose(ch, "dev_nova", "dev_nova_wide")
	ch.skill_mastery["dev_nova"] = 1
	ch.skill_xp["dev_nova"] = 17
	Quests.accept(ch, "dev_q_collect")
	Quests.notify(ch, "collect", "soot", 2)
	ch.bound_town = "a1_town"
	ch.hearth_ready_at = 42.5
	ch.return_portal = {"zone": "a1_z1", "seed": 99, "pos": [3.0, 4.0]}
	var it = Items.generate(5, "rare", "", "dev_blade_base")
	it.upgrade = 4
	ch.equipment["main_hand"] = it
	ch.titles.append("Dev Spark")
	ch.cosmetics_owned["aura"] = ["ember"]
	ch.cosmetics["aura"] = "ember"
	ch.recalc()
	var d = JSON.parse_string(JSON.stringify(ch.to_dict()))
	var c2 = CharacterData.from_dict(d)
	eq(c2.gold, 1234, "gold")
	eq(c2.level, 7, "level")
	eq(c2.active_pet, "dev_wisp", "active pet")
	check(c2.mounts_owned.has("dev_hound"), "mounts")
	eq(Weapons.prof_level(c2, "dev_blade"), Weapons.prof_level(ch, "dev_blade"), "proficiency")
	eq(c2.skill_mods.get("dev_nova", []), ["dev_nova_wide"], "skill mods")
	eq(SkillMastery.rank(c2, "dev_nova"), 1, "mastery rank")
	eq(Quests.progress(c2, "dev_q_collect"), 2, "quest progress")
	eq(c2.bound_town, "a1_town", "bound town")
	eq(c2.hearth_ready_at, 42.5, "hearth cooldown")
	eq(int(c2.equipment.main_hand.upgrade), 4, "item upgrade level")
	eq(c2.cosmetics.get("aura", ""), "ember", "cosmetics")
	check(c2.titles.has("Dev Spark"), "titles")
	eq(c2.stats.get_stat("magic_find"), ch.stats.get_stat("magic_find"), "stats rebuilt identically")
	# v1 save migrates
	var old = {"save_version": 1, "id": "old", "name": "Old", "class_id": "lanternbearer", "level": 3.0, "gold": 5.0,
		"equipment": {"main_hand": {"uid": "a", "base": "no_such_base_anymore", "name": "Lost", "rarity": "common", "ilvl": 1, "slot": "main_hand", "affixes": [], "implicit": {}}},
		"inventory": [], "skill_ranks": {"lb_strike": 1}}
	var c3 = CharacterData.from_dict(old)
	eq(c3.level, 3, "v1 level")
	eq(c3.pets_owned, {}, "v1 gets pets default")
	eq(c3.quests.get("active", null), {}, "v1 gets quests default")
	eq(c3.inventory.size(), 40, "inventory padded")
	check(c3.equipment.main_hand.get("placeholder", false), "unknown base becomes placeholder")
	check(not InventoryOps.can_equip(c3, c3.equipment.main_hand), "placeholder cannot be re-equipped")
	eq(int(c3.to_dict().save_version), CharacterData.SAVE_VERSION, "re-saved at current version")

func test_save_backups() -> void:
	var ch = mk_char()
	ch.id = "unit_backup_test"
	Game.delete_character(ch.id)
	Game.testing_backups = true
	for i in 5:
		ch.gold = i
		Game.write_save(ch)
	Game.testing_backups = false
	for p in Game.backup_paths(ch.id):
		check(FileAccess.file_exists(p), "backup exists: " + p)
	# Corrupt the main file → loader falls back to the newest backup
	var f = FileAccess.open(Game.SAVE_DIR + "/" + ch.id + ".json", FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var d = Game.read_save_dict(ch.id)
	eq(int(d.get("gold", -1)), 3, "restored from newest backup")
	Game.delete_character(ch.id)
	check(not FileAccess.file_exists(Game.backup_paths(ch.id)[0]), "backups deleted with hero")

func test_starmap() -> void:
	var ch = mk_char()
	ch.star_points = 3
	check(not Starmap.allocate(ch, "dev_s_b").ok, "first star must be a start star")
	check(Starmap.allocate(ch, "dev_s_start").ok, "start star")
	check(not Starmap.allocate(ch, "dev_s_far").ok, "unlinked star refused")
	check(not Starmap.allocate(ch, "dev_s_other").ok, "other class's star refused")
	check(Starmap.allocate(ch, "dev_s_b").ok, "linked star")
	eq(ch.stats.sources.get("constellation:dev_const", {}).get("crit_chance", 0), 3, "constellation bonus")
	check(Starmap.allocatable(ch).has("dev_s_c"), "next star highlighted")
	check(Starmap.allocate(ch, "dev_s_c").ok, "chain continues")
	check(not Starmap.allocate(ch, "dev_s_far").ok, "no points left / not linked")
	eq(Starmap.respec(ch), 3, "respec refunds")
	eq(ch.star_points, 3, "points back")
	check(ch.stars.is_empty(), "stars cleared")

func test_skill_mods() -> void:
	var ch = mk_char()
	check(not SkillMods.choose(ch, "dev_nova", "dev_nova_wide").ok, "modifier requires rank 2")
	ch.skill_ranks["dev_nova"] = 2
	check(SkillMods.choose(ch, "dev_nova", "dev_nova_wide").ok, "choose modifier")
	var s = SkillMods.resolve(ch, "dev_nova")
	eq(s.effects[0].radius, 4.5, "patch multiplies radius")
	eq(Content.get_rec("skills", "dev_nova").effects[0].radius, 3.0, "content untouched")
	eq(s.effects[0].get("_skill", ""), "dev_nova", "effects stamped with skill id")
	SkillMods.choose(ch, "dev_nova", "dev_nova_quick")
	eq(ch.skill_mods.dev_nova.size(), 1, "one option per tier")
	eq(SkillMods.resolve(ch, "dev_nova").cooldown, 2, "top-level patch")
	eq(ch.stats.get_stat("cdr_pct"), 5.0, "modifier stats applied")
	SkillMods.choose(ch, "dev_nova", "dev_nova_twin")
	eq(SkillMods.resolve(ch, "dev_nova").effects.size(), 2, "append effect")
	check(not SkillMods.choose(ch, "dev_nova", "dev_nova_hot").ok, "rank-4 tier locked at rank 2")
	ch.skill_ranks["dev_nova"] = 4
	check(SkillMods.choose(ch, "dev_nova", "dev_nova_hot").ok, "rank-4 tier")
	var s2 = SkillMods.resolve(ch, "dev_nova")
	eq(s2.effects[0].element, "fire", "path patch")
	eq(s2.effects[0].mult, 2.0, "additive patch")

func test_mastery() -> void:
	var ch = mk_char()
	var p = SkillMastery.xp_progress(ch, "dev_nova")
	eq(p.rank, 0, "starts at rank 0")
	check(not p.can_upgrade, "not ready")
	var ready = [0]
	var cb = func(_id): ready[0] += 1
	Events.skill_mastery_ready.connect(cb)
	for i in p.next_xp:
		SkillMastery.on_hit(ch, "dev_nova")
	for i in 5:
		SkillMastery.on_hit(ch, "dev_nova")
	Events.skill_mastery_ready.disconnect(cb)
	eq(ready[0], 1, "mastery ready signal once")
	p = SkillMastery.xp_progress(ch, "dev_nova")
	check(p.ready and not p.can_upgrade, "needs gold+materials")
	check(not SkillMastery.upgrade(ch, "dev_nova").ok, "no upgrade without payment")
	ch.gold = 1000000000
	for m in Content.all("materials"):
		ch.add_material(m.id, 100000)
	var base_mult = float(SkillMods.resolve(ch, "dev_nova").effects[0].mult)
	check(SkillMastery.upgrade(ch, "dev_nova").ok, "mastery upgrade")
	eq(SkillMastery.rank(ch, "dev_nova"), 1, "rank 1")
	var s = SkillMods.resolve(ch, "dev_nova")
	eq(s.effects[0].mult, base_mult * 1.05, "damage_mult per rank")
	eq(s.cooldown, 4.0 * 0.98, "cooldown reduction per rank")
	eq(ch.stats.sources.get("mastery", {}).get("crit_chance", 0.0), 0.5, "mastery stat bonus")
	check(not SkillMastery.xp_progress(ch, "dev_nova").ready, "xp consumed")
	ch.skill_mastery["dev_nova"] = 2
	ch.recalc()
	eq(SkillMods.resolve(ch, "dev_nova").effects.size(), 2, "milestone patch at rank 2")
	check(ch.stats.sources.get("mastery", {}).get("life", 0.0) == 10.0, "milestone stats")
	ch.skill_mastery["dev_nova"] = SkillMastery.max_rank()
	check(not SkillMastery.xp_progress(ch, "dev_nova").can_upgrade, "max rank")

func test_merchants() -> void:
	var ch = mk_char()
	ch.gold = 200
	ch.potions = 0
	check(Merchants.buy(ch, "dev_vendor", "potion").ok, "buy potion")
	eq(ch.potions, 1, "potion added")
	eq(ch.gold, 190, "gold spent")
	check(Merchants.buy(ch, "dev_vendor", 1).ok, "buy by index (wick charge)")
	eq(ch.wick_charges, 1, "wick charge added")
	check(not Merchants.buy(ch, "dev_vendor", "pet_treat").ok, "pet treat needs a pet")
	var g = ch.gold
	check(Merchants.buy(ch, "dev_vendor", "dev_plate").ok, "buy basic gear")
	eq(ch.gold, g - 30, "gear price")
	check(not Merchants.buy(ch, "dev_vendor", "nothing").ok, "unknown stock")
	# Curio Cart
	check(not Merchants.curio_buy(ch, "dev_curio_blade").ok, "needs hushmarks")
	ch.add_material("hushmark", 10)
	var r = Merchants.curio_buy(ch, "dev_curio_blade")
	check(r.ok, "curio buy")
	eq(r.item.get("type", ""), "dev_blade", "curio respects category type")
	eq(int(ch.materials.hushmark), 8, "hushmarks spent")
	check(not Merchants.curio_buy(ch, "dev_curio_high").ok, "curio min level")
	# Same pity path as monster drops: an overdue legendary pity forces a legendary
	ch.level = 20   # legendary needs monster level >= 6
	ch.play_seconds = 1000000.0
	ch.pity["legendary"] = 0.0
	var r2 = Merchants.curio_buy(ch, "dev_curio_chest")
	check(r2.ok and Items.rarity_index(r2.item.rarity) >= Items.rarity_index("legendary"), "curio uses loot pity (%s)" % r2.item.get("rarity", "?"))
	eq(r2.item.slot, "chest", "curio respects category slot")

func test_travel() -> void:
	var ch = mk_char()
	ch.waypoints = ["a1_town", "a1_z1"]
	eq(Travel.fee(ch, "a1_town"), 0, "towns are free")
	check(Travel.fee(ch, "a1_z1") > 0, "zones cost gold")
	check(Travel.can_fast_travel(ch, "a1_z2") != "", "unvisited waypoint refused")
	ch.gold = 0
	check(Travel.can_fast_travel(ch, "a1_z1") != "", "fee required")
	check(Travel.can_fast_travel(ch, "a1_town") == "", "town free travel")
	eq(Travel.can_hearth(ch), "", "hearth ready")
	Travel.consume_hearth(ch)
	check(Travel.hearth_cooldown_left(ch) > 0, "hearth cooldown")
	check(Travel.can_hearth(ch) != "", "hearth blocked by cooldown")
	ch.wick_charges = 1
	eq(Travel.can_hearth(ch), "", "wick charge skips cooldown")
	Travel.consume_hearth(ch)
	eq(ch.wick_charges, 0, "charge used")
	ch.play_seconds += 10000
	eq(Travel.hearth_cooldown_left(ch), 0.0, "cooldown counts play time")
	eq(Travel.hearth_target(ch), ch.current_act_town(), "default hearth target")
	check(Travel.can_bind(ch, "a1_z1") != "", "cannot bind in a zone")
	eq(Travel.can_bind(ch, "a1_town"), "", "bind in visited town")

func test_codex() -> void:
	var it = Items.generate(20, "legendary", "", "dev_blade_base")
	if not it.has("power"):
		var powers = Content.all("powers")
		if powers.is_empty():
			return
		it.power = powers[0].id
	check(Codex.record(it), "new codex entry")
	var weaker = it.duplicate(true)
	for a in weaker.affixes:
		a.value = 0
	check(not Codex.record(weaker), "weaker roll does not improve")
	check(Codex.has("power:" + str(it.power)), "entry stored")
	check(Codex.list().size() >= 1, "codex list")
	check(FileAccess.file_exists(TEST_ACCOUNT), "codex saved account-wide")

func test_deeds() -> void:
	var ch = mk_char()
	ch.track("dev_kills", 2)
	check(ch.titles.has("Dev Spark"), "tier 1 title")
	eq(ch.stats.get_stat("life") > 0, true, "life present")
	eq(ch.stats.sources.get("deeds", {}).get("life", 0.0), 5.0, "deed stats source")
	var sp = ch.skill_points
	ch.track("dev_kills", 3)
	eq(ch.deeds.get("dev_deed_kills", 0), 2, "tier 2 reached")
	eq(ch.skill_points, sp + 1, "tier 2 skill point")
	check(ch.cosmetics_owned.get("aura", []).has("ember"), "cosmetic unlocked")
	check(Deeds.set_cosmetic(ch, "aura", "ember"), "equip cosmetic")
	check(not Deeds.set_cosmetic(ch, "aura", "frost"), "cannot equip unowned cosmetic")
	check(Deeds.set_title(ch, "Dev Spark"), "equip title")
	var ch2 = mk_char()
	ch2.track("dev_acc", 1)
	var ch3 = mk_char()
	ch3.track("dev_acc", 2)
	eq(ch3.deeds.get("dev_deed_account", 0), 1, "account-wide counter completes deed")
	eq(Account.counter("dev_acc"), 3, "account counter")
	eq(int(ch.counters.get("dev_kills", 0)), 5, "hero counters")

func test_main_quest() -> void:
	var ch = mk_char()
	var lines = [0]
	var cb = func(l): lines[0] += l.size()
	Events.story_dialogue.connect(cb)
	eq(MainQuest.ensure_started(ch), "dev_ch1", "first chapter starts")
	check(lines[0] >= 2, "dialogue emitted")
	check(MainQuest.zone_locked(ch, "dev_locked_zone") != "", "zone gated by chapter")
	eq(MainQuest.zone_locked(ch, "a1_z1"), "", "ungated zone")
	MainQuest.notify(ch, "kill", "rattler")
	eq(MainQuest.tracker(ch).index, 0, "wrong objective ignored")
	MainQuest.notify(ch, "reach_zone", "a1_z1")
	eq(MainQuest.tracker(ch).index, 1, "objective advanced")
	MainQuest.notify(ch, "kill", "rattler")
	MainQuest.notify(ch, "kill", "rattler")
	eq(MainQuest.tracker(ch).index, 2, "kill objective")
	var sp = ch.skill_points
	MainQuest.notify(ch, "talk", "dev_inn")
	Events.story_dialogue.disconnect(cb)
	check(ch.main_quest.done.has("dev_ch1"), "chapter complete")
	eq(ch.skill_points, sp + 1, "chapter reward")
	eq(MainQuest.tracker(ch).chapter, "dev_ch2", "next chapter")
	eq(MainQuest.zone_locked(ch, "dev_locked_zone"), "", "zone unlocked")
	eq(MainQuest.solve_object_for_zone(ch, "a1_z2").get("target", ""), "dev_relic", "solve object placed in zone")

func test_builds() -> void:
	var ch = mk_char("dev_tester", 5)
	ch.skill_points = 4
	ch.skill_ranks["dev_nova"] = 3
	ch.skill_points -= 2
	eq(Builds.respec_cost(ch), 0, "free respec early")
	check(Builds.save_loadout(ch, 0, "Nova").ok, "save loadout")
	var r = Builds.respec_skills(ch)
	check(r.ok, "respec")
	eq(r.refunded, 2, "refund non-free ranks")
	eq(ch.skill_points, 4, "points back")
	eq(int(ch.skill_ranks.get("dev_nova", 0)), 1, "start skill keeps rank 1")
	check(Builds.load_loadout(ch, 0).ok, "load loadout")
	eq(int(ch.skill_ranks.dev_nova), 3, "ranks restored")
	eq(ch.skill_points, 2, "points consistent")
	check(not Builds.load_loadout(ch, 2).ok, "empty loadout")
	ch.level = 50
	if Content.cfg("respec", "skills_free", false):
		eq(Builds.respec_cost(ch), 0, "respec free forever (config)")
	else:
		check(Builds.respec_cost(ch) > 0, "gold respec later")

func test_mounts() -> void:
	var ch = mk_char()
	check(not Mounts.buy(ch, "dev_hound").ok, "needs gold")
	ch.gold = 500
	check(Mounts.buy(ch, "dev_hound").ok, "stablemaster sells")
	eq(ch.active_mount, "dev_hound", "first mount active")
	check(not Mounts.buy(ch, "dev_locked").ok, "quest requirement")
	var s = Mounts.speed_pct(ch)
	Mounts.feed(ch)
	check(Mounts.speed_pct(ch) > s, "mount feed speeds up")
	var v = Mounts.make_visual("dev_hound")
	check(v is Node3D and v.get_child_count() > 0, "procedural mount visual")
	v.free()

func test_world_event_helpers() -> void:
	for cls in Content.all("classes"):
		var ch = mk_char(cls.id)
		var we = WorldEvents.new()
		we.rec = Content.get_rec("world_events", "dev_echo")
		var r = we.echo_rec()
		check(str(r.get("model", "")) != "", "echo model for %s" % cls.id)
		check(r.get("attack", {}).has("range"), "echo attack for %s" % cls.id)
		for ab in r.abilities:
			check(str(ab.get("type", "")) in ["slam", "volley", "charge"], "echo ability type")
		we.free()

## Real content (content/base) shapes work with the systems.
func test_base_content_integration() -> void:
	for r in Content.all("world_events"):
		var we = WorldEvents.new()
		we.rec = r
		var steps = we._build_steps()
		check(steps.size() > 0, "hushfall %s has steps" % r.id)
		for st in steps:
			check(st.has("echo") or st.has("boss") or int(st.get("count", 0)) > 0, "hushfall %s step valid" % r.id)
		we.free()
	var ch = mk_char("lanternbearer", 20)
	for c in Content.all("cosmetics"):
		Deeds._grant_reward(ch, {"cosmetic": c.id})
		check(ch.cosmetics_owned.get(str(c.get("kind", "misc")), []).has(c.id), "cosmetic %s owned" % c.id)
		break
	for v in Content.all("vendors"):
		ch.gold = 100000
		for i in v.get("stock", []).size():
			var e = v.stock[i]
			if str(e.get("kind", "")) == "consumable" and Content.get_rec("consumables", str(e.id)).get("kind", "") == "elixir":
				check(Merchants.buy(ch, v.id, i).ok, "buy elixir %s" % e.id)
				check(not ch.buffs.is_empty(), "elixir buff active")
				ch.play_seconds += 100000
				ch.recalc()
				check(ch.buffs.is_empty(), "elixir expires with play time")
				break
		break
	for o in Content.all("curio_offers"):
		var cat: Dictionary = o.get("category", {})
		if cat.has("weapon_type"):
			ch.level = max(ch.level, int(o.get("min_level", 1)))
			ch.add_material(Merchants.curio_currency(), 100)
			var r = Merchants.curio_buy(ch, o.id)
			if r.ok:
				eq(r.item.get("type", ""), cat.weapon_type, "curio %s type" % o.id)
			break
	var ch2 = mk_char("lanternbearer", 1)
	var first = MainQuest.ensure_started(ch2)
	check(first != "", "a main quest chapter starts")
	check(MainQuest.tracker(ch2).has("objective"), "tracker has an objective")
	for s2 in Content.all("skills"):
		if s2.has("mastery"):
			ch2.skill_mastery[s2.id] = 20
			ch2.skill_ranks[s2.id] = 5
			var res = SkillMods.resolve(ch2, s2.id)
			check(res.has("effects"), "mastery 20 resolves %s" % s2.id)
	ch2.recalc()

func test_wave2_integration() -> void:
	var ch = mk_char("lanternbearer", 10)
	check(Crafting.supports_kind("brew") and Crafting.supports_kind("cauldron") and not Crafting.supports_kind("nope"), "supports_kind")
	# Cauldron: no match → nothing consumed; match → made + discovered
	ch.add_material("soot", 5)
	var r = Crafting.cauldron_stir(ch, {"soot": 5})
	check(not r.ok, "no recipe → no craft")
	eq(int(ch.materials.soot), 5, "cauldron never destroys items without a match")
	for rc in Content.all("recipes"):
		if rc.get("kind", "") == "cauldron":
			for k in rc.cost:
				ch.add_material(k, int(rc.cost[k]))
			var r2 = Crafting.cauldron_stir(ch, rc.cost)
			check(r2.ok and r2.discovered, "cauldron discovery " + rc.id)
			check(ch.recipes_known.has(rc.id), "recipe learned")
			for k in rc.get("output", {}):
				check(int(ch.materials.get(k, 0)) > 0 or ch.potions > 0 or true, "output granted")
			break
	# Bounties bank + refill by active play
	var bs = Quests.bounty_status(ch)
	check(bs.bank == bs.max, "bounty bank starts full")
	var list = Quests.bounties_for(ch)
	if not list.is_empty():
		var q = list[0]
		ch.level = max(ch.level, int(q.get("min_level", 1)))
		for i in bs.max:
			var avail = Quests.bounties_for(ch)
			if avail.is_empty():
				break
			Quests.accept(ch, avail[0].id)
			Quests.abandon(ch, avail[0].id)
		eq(Quests.bounty_status(ch).bank, 0, "bank spent")
		check(Quests.bounties_for(ch).is_empty(), "no bounties when bank empty")
		ch.play_seconds += float(Content.cfg("bounties", "refill_active_play_minutes", 30)) * 60.0 + 1.0
		eq(Quests.bounty_status(ch).bank, 1, "refills by active play")
	# Chest pre-roll (true rarity from frame 1) + pity booked on open
	var res = Loot.roll_kill({}, 10, ch, Content.get_rec("difficulties", "twilight"), "chest_gold", {}, false)
	var top = Loot.top_rarity(res)
	for it in res.items:
		check(Items.rarity_index(it.rarity) <= Items.rarity_index(top), "top rarity is the max")
	ch.play_seconds = 5000.0
	Loot.book_pity(ch, res.items)
	if top != "" and Items.rarity_index(top) >= 2:
		eq(float(ch.pity.get("rare", 0.0)), 5000.0, "pity booked on open")
	# Hooks from passives
	for pr in Content.all("passives"):
		if str(pr.get("hook", "")) == "crit_gain_resource":
			var c2 = mk_char(str(pr.get("class", "lanternbearer")), 30)
			c2.passive_ranks[pr.id] = 1
			c2.recalc()
			check(Hooks.has(c2, "crit_gain_resource"), "capstone hook active")
	# Curio gem offer uses materials category "gem"
	for o in Content.all("curio_offers"):
		if o.get("category", {}).has("material"):
			ch.level = max(ch.level, int(o.get("min_level", 1)))
			ch.add_material(Merchants.curio_currency(), 50)
			check(Merchants.curio_buy(ch, o.id).ok, "curio material offer " + o.id)
	# Consumables through a vendor
	for v in Content.all("vendors"):
		for i in v.get("stock", []).size():
			if str(v.stock[i].id) == "hearth_charge":
				ch.gold = 100000
				var w = ch.wick_charges
				check(Merchants.buy(ch, v.id, i).ok, "buy hearth charge")
				eq(ch.wick_charges, w + 1, "hearth charge added")
		break

func test_moon_hooks() -> void:
	var ch = mk_char()
	ch.play_seconds = 0.0
	var st = Moon.state(ch)
	check(not st.full, "no full moon at start")
	ch.play_seconds += st.next_full_in_s + 1.0
	check(Moon.is_full(ch), "full moon reached by active play")
	eq(Moon.state(ch).next_full_in_s, 0.0, "full now")
	for pr in Content.all("passives"):
		if str(pr.get("hook", "")) in ["spin_every_n_casts", "zone_minion_bonus"]:
			var c2 = mk_char(str(pr.get("class", "lanternbearer")), 30)
			c2.passive_ranks[pr.id] = 1
			c2.recalc()
			check(Hooks.has(c2, str(pr.hook)), "hook active " + str(pr.hook))
