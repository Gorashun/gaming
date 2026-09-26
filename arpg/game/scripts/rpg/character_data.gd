class_name CharacterData
extends RefCounted
## Everything persistent about one hero. Serializes to a Dictionary (save file / future server).

const SAVE_VERSION := 2

var id = ""
var name = "Hero"
var class_id = "lanternbearer"
var hardcore = false
var dead = false
var level = 1
var xp = 0
var gold = 0
var skill_points = 0
var star_points = 0
var skill_ranks = {}        # skill_id -> rank
var passive_ranks = {}      # passive_id -> rank
var stars = []              # starmap node ids
var pact = ""
var equipment = {}          # slot -> item
var inventory = []          # Array of items (null allowed = empty)
var stash = []
var materials = {}          # material_id -> count
var professions = {}        # profession_id -> {level, xp}
var recipes_known = []
var discoveries = []        # cauldron discoveries / secrets found
var skill_bar = ["", "", "", ""]
var potions = 3
var difficulty = "twilight"
var unlocked_tiers = ["twilight"]
var progress = {}           # tier -> {act_id: {zones_cleared:[], boss:bool}}
var current_act = "act1"
var waypoints = []
var pity = {}
var play_seconds = 0.0
var rested_xp = 0.0
var last_played_unix = 0
var created_unix = 0
var stats_tracking = {}     # kills, deaths, legendaries found, etc.
# --- v2 (wave 2 systems) ---
var proficiency = {}        # weapon_type -> {level, xp}
var pets_owned = {}         # pet_id -> {level, xp}
var active_pet = ""
var pet_state = {}          # dig_kills, ferry_ready_at, ferry_back_at (play-seconds)
var mounts_owned = []
var active_mount = ""
var mount_fed_until = 0.0   # play-seconds
var bound_town = ""
var hearth_ready_at = 0.0   # play-seconds (pauses when not playing — welfare)
var wick_charges = 0        # consumable: skip the hearth cooldown once
var return_portal = {}      # {zone, seed, pos:[x,z], tier} — "portal back" from town
var quests = {"active": {}, "done": []}
var skill_mods = {}         # skill_id -> [option ids]
var skill_xp = {}           # skill_id -> mastery xp toward next rank
var skill_mastery = {}      # skill_id -> mastery rank
var loadouts = []           # up to 3 saved builds: {name, skill_ranks, skill_bar, skill_mods, gear:{slot: uid}}
var main_quest = {}         # {chapter, objective, progress, done:[chapter ids]}
var deeds = {}              # deed_id -> tiers reached
var titles = []
var title = ""
var cosmetics_owned = {}    # slot -> [values]
var cosmetics = {}          # slot -> equipped value (cape_tint, aura, name_frame, pet_hat, mount_tint)
## Deed counters (alias of stats_tracking, which is what the save stores).
var counters: Dictionary:
	get:
		return stats_tracking

var stats = StatBlock.new()

func _init() -> void:
	inventory.resize(40)

func current_act_town() -> String:
	return Content.get_rec("acts", current_act).get("town", "a1_town")

func cls() -> Dictionary:
	return Content.get_rec("classes", class_id)

## Rebuild all stat sources from class, level, gear, skills, stars, pact.
func recalc() -> void:
	var c = cls()
	var base: Dictionary = c.get("base_stats", {}).duplicate()
	stats.set_source("class", base)
	var lvl = {}
	for k in c.get("per_level", {}):
		lvl[k] = float(c.per_level[k]) * (level - 1)
	stats.set_source("level", lvl)
	stats.clear_prefix("gear:")
	for slot in equipment:
		var it = equipment[slot]
		if it:
			stats.set_source("gear:" + slot, Items.item_stats(it))
	stats.clear_prefix("passive:")
	for pid in passive_ranks:
		var p = Content.get_rec("passives", pid)
		var s = {}
		for k in p.get("stats", {}):
			s[k] = float(p.stats[k]) * int(passive_ranks[pid])
		stats.set_source("passive:" + pid, s)
	stats.clear_prefix("star:")
	for sid in stars:
		var node = Content.get_rec("starmap", sid)
		stats.set_source("star:" + sid, node.get("stats", {}))
	# Completed constellations
	stats.clear_prefix("constellation:")
	for cons in Content.all("starmap").filter(func(n): return n.get("kind", "") == "constellation"):
		var all_owned = true
		for nid in cons.get("nodes", []):
			if not stars.has(nid):
				all_owned = false
		if all_owned and cons.get("nodes", []).size() > 0:
			stats.set_source("constellation:" + cons.id, cons.get("bonus", {}))
	if pact != "":
		stats.set_source("pact", Content.get_rec("passives", pact).get("stats", {}))
	# Weapon affinity + proficiency, skill modifiers/mastery, pet bonuses
	stats.set_source("affinity", Weapons.affinity_stats(self))
	stats.set_source("proficiency", Weapons.proficiency_stats(self))
	stats.clear_prefix("skillmod:")
	for sid in skill_mods:
		for opt in SkillMods.chosen_options(self, sid):
			if not opt.get("stats", {}).is_empty():
				stats.set_source("skillmod:%s:%s" % [sid, opt.get("id", "")], opt.stats)
	stats.set_source("mastery", SkillMastery.stat_bonuses(self))
	stats.set_source("pet", Pets.stat_bonuses(self))
	stats.set_source("deeds", Deeds.stat_bonuses(self))
	# Primary attribute conversions
	var conv: Dictionary = Content.get_rec("config", "attributes").get("conversions", {})
	var derived = {}
	for attr in conv:
		var amount = stats.total(attr)
		for k in conv[attr]:
			derived[k] = float(derived.get(k, 0.0)) + amount * float(conv[attr][k])
	stats.set_source("derived", derived)

func max_life() -> float:
	return max(1.0, stats.total("life"))

func max_resource() -> float:
	return max(1.0, stats.total("resource_max"))

func weapon() -> Dictionary:
	var w = equipment.get("main_hand")
	return w if w else {}

func add_xp(amount: int) -> int:
	## returns number of levels gained
	var gained = 0
	if rested_xp > 0:
		var bonus: float = min(rested_xp, float(amount))
		rested_xp -= bonus
		amount += int(bonus)
	amount = int(amount * (1.0 + stats.total("xp_pct") / 100.0))
	xp += amount
	while level < Progression.max_level() and xp >= Progression.xp_to_next(level):
		xp -= Progression.xp_to_next(level)
		level += 1
		gained += 1
		skill_points += Progression.skill_points_for_level(level)
		star_points += Progression.star_points_for_level(level)
	if level >= Progression.max_level():
		xp = 0
	if gained > 0:
		recalc()
	return gained

func first_free_slot() -> int:
	for i in inventory.size():
		if inventory[i] == null:
			return i
	return -1

func add_item(item: Dictionary) -> bool:
	var i = first_free_slot()
	if i < 0:
		return false
	inventory[i] = item
	return true

func add_material(id: String, n: int) -> void:
	materials[id] = int(materials.get(id, 0)) + n

func has_materials(cost: Dictionary) -> bool:
	for k in cost:
		if int(materials.get(k, 0)) < int(cost[k]):
			return false
	return true

func spend_materials(cost: Dictionary) -> void:
	for k in cost:
		materials[k] = int(materials.get(k, 0)) - int(cost[k])

## Increments a counter (hero + account) and completes deed tiers (see systems/deeds.gd).
func track(key: String, n := 1) -> void:
	Deeds.add(self, key, n)

func to_dict() -> Dictionary:
	return {
		"save_version": SAVE_VERSION, "id": id, "name": name, "class_id": class_id, "hardcore": hardcore, "dead": dead,
		"level": level, "xp": xp, "gold": gold, "skill_points": skill_points, "star_points": star_points,
		"skill_ranks": skill_ranks, "passive_ranks": passive_ranks, "stars": stars, "pact": pact,
		"equipment": equipment, "inventory": inventory, "stash": stash, "materials": materials,
		"professions": professions, "recipes_known": recipes_known, "discoveries": discoveries,
		"skill_bar": skill_bar, "potions": potions, "difficulty": difficulty, "unlocked_tiers": unlocked_tiers,
		"progress": progress, "current_act": current_act, "waypoints": waypoints, "pity": pity,
		"play_seconds": play_seconds, "rested_xp": rested_xp, "last_played_unix": last_played_unix,
		"created_unix": created_unix, "stats_tracking": stats_tracking,
		"proficiency": proficiency, "pets_owned": pets_owned, "active_pet": active_pet, "pet_state": pet_state,
		"mounts_owned": mounts_owned, "active_mount": active_mount, "mount_fed_until": mount_fed_until,
		"bound_town": bound_town, "hearth_ready_at": hearth_ready_at, "wick_charges": wick_charges,
		"return_portal": return_portal, "quests": quests, "skill_mods": skill_mods, "skill_xp": skill_xp,
		"skill_mastery": skill_mastery, "loadouts": loadouts, "main_quest": main_quest, "deeds": deeds,
		"titles": titles, "title": title, "cosmetics_owned": cosmetics_owned, "cosmetics": cosmetics,
	}

static func from_dict(d: Dictionary) -> CharacterData:
	var c = CharacterData.new()
	d = migrate(d)
	for k in d:
		if k == "save_version":
			continue
		if k in c and k != "stats" and k != "counters" and d[k] != null and typeof(d[k]) == typeof(c.get(k)):
			c.set(k, d[k])
		elif k in c and k != "stats" and d[k] != null and typeof(c.get(k)) in [TYPE_INT, TYPE_FLOAT] and typeof(d[k]) in [TYPE_INT, TYPE_FLOAT]:
			c.set(k, d[k])
	# JSON turns ints into floats; normalise key numerics
	c.level = int(c.level); c.xp = int(c.xp); c.gold = int(c.gold)
	c.skill_points = int(c.skill_points); c.star_points = int(c.star_points); c.potions = int(c.potions)
	if c.inventory.size() < 40:
		c.inventory.resize(40)
	c.recalc()
	return c

static func _mark_placeholder(it: Dictionary) -> void:
	if not Content.has_rec("item_bases", str(it.get("base", ""))):
		it["placeholder"] = true
	elif it.has("placeholder"):
		it.erase("placeholder")

## Upgrades old save dictionaries step by step. Never drops data; new fields get defaults.
static func migrate(d: Dictionary) -> Dictionary:
	var v = int(d.get("save_version", 1))
	if v < 2:
		# v2: proficiency, pets, mounts, travel, quests, skill mods/mastery, item upgrade levels
		for k in ["proficiency", "pets_owned", "pet_state", "skill_mods", "skill_xp", "skill_mastery", "return_portal",
				"main_quest", "deeds", "cosmetics_owned", "cosmetics"]:
			if not (d.get(k) is Dictionary):
				d[k] = {}
		for k in ["mounts_owned", "loadouts", "titles"]:
			if not (d.get(k) is Array):
				d[k] = []
		if not (d.get("quests") is Dictionary):
			d["quests"] = {"active": {}, "done": []}
		for k in ["active_pet", "active_mount", "bound_town", "title"]:
			if not (d.get(k) is String):
				d[k] = ""
		d["hearth_ready_at"] = 0.0
		for slot in d.get("equipment", {}):
			var it = d.equipment[slot]
			if it is Dictionary and not it.has("upgrade"):
				it["upgrade"] = 0
		for it in d.get("inventory", []):
			if it is Dictionary and not it.has("upgrade"):
				it["upgrade"] = 0
		v = 2
	d["save_version"] = v
	return d
