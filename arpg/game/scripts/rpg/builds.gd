class_name Builds
extends RefCounted
## Skill respec + saved build loadouts (research player_wants #8/#9).
## config/respec {free_until_level: 20, gold_per_level: 5}: free up to the level, then cheap gold.
## Mastery is never refunded or lost. Loadouts (max 3) store skill ranks, bar, modifiers and gear uids.

const MAX_LOADOUTS := 3

static func _free_rank(ch: CharacterData, skill_id: String) -> int:
	## Ranks granted for free at creation (start skills / basic attack) are not refunded.
	var cls = ch.cls()
	if skill_id == cls.get("basic_attack", "") or cls.get("start_skills", []).has(skill_id):
		return 1
	return 0

static func spent_points(ranks: Dictionary, ch: CharacterData, passives := {}) -> int:
	var n = 0
	for sid in ranks:
		n += max(0, int(ranks[sid]) - _free_rank(ch, sid))
	for pid in passives:
		n += int(passives[pid])
	return n

static func respec_cost(ch: CharacterData) -> int:
	var c = Content.get_rec("config", "respec")
	if ch.level <= int(c.get("free_until_level", 20)):
		return 0
	return int(c.get("gold_per_level", 5)) * ch.level

## Refunds all skill + passive points. Returns {ok, message, refunded, cost}.
static func respec_skills(ch: CharacterData) -> Dictionary:
	var cost = respec_cost(ch)
	if ch.gold < cost:
		return {"ok": false, "message": "Not enough gold", "cost": cost}
	var refund = spent_points(ch.skill_ranks, ch, ch.passive_ranks)
	ch.gold -= cost
	var ranks = {}
	for sid in ch.skill_ranks:
		var f = _free_rank(ch, sid)
		if f > 0:
			ranks[sid] = f
	ch.skill_ranks = ranks
	ch.passive_ranks = {}
	ch.skill_points += refund
	for i in ch.skill_bar.size():
		if ch.skill_bar[i] != "" and not ranks.has(ch.skill_bar[i]):
			ch.skill_bar[i] = ""
	ch.recalc()
	return {"ok": true, "message": "Skills reset: %d points returned" % refund, "refunded": refund, "cost": cost}

static func save_loadout(ch: CharacterData, slot: int, label := "") -> Dictionary:
	if slot < 0 or slot >= MAX_LOADOUTS:
		return {"ok": false, "message": "Invalid loadout"}
	while ch.loadouts.size() < MAX_LOADOUTS:
		ch.loadouts.append({})
	var gear = {}
	for s in ch.equipment:
		var it = ch.equipment[s]
		if it is Dictionary and it.has("uid"):
			gear[s] = it.uid
	ch.loadouts[slot] = {"name": label if label != "" else "Build %d" % (slot + 1), "skill_ranks": ch.skill_ranks.duplicate(),
		"passive_ranks": ch.passive_ranks.duplicate(), "skill_bar": ch.skill_bar.duplicate(),
		"skill_mods": ch.skill_mods.duplicate(true), "gear": gear}
	return {"ok": true, "message": "Saved %s" % ch.loadouts[slot].name}

static func load_loadout(ch: CharacterData, slot: int) -> Dictionary:
	if slot < 0 or slot >= ch.loadouts.size() or not (ch.loadouts[slot] is Dictionary) or ch.loadouts[slot].is_empty():
		return {"ok": false, "message": "Empty loadout"}
	var lo: Dictionary = ch.loadouts[slot]
	var available = ch.skill_points + spent_points(ch.skill_ranks, ch, ch.passive_ranks)
	var need = spent_points(lo.get("skill_ranks", {}), ch, lo.get("passive_ranks", {}))
	if need > available:
		return {"ok": false, "message": "Not enough skill points for this build"}
	var ranks = {}
	for sid in lo.get("skill_ranks", {}):
		ranks[sid] = int(lo.skill_ranks[sid])
	ch.skill_ranks = ranks
	ch.passive_ranks = lo.get("passive_ranks", {}).duplicate()
	ch.skill_points = available - need
	var bar: Array = lo.get("skill_bar", ["", "", "", ""]).duplicate()
	while bar.size() < 4:
		bar.append("")
	ch.skill_bar = bar
	ch.skill_mods = lo.get("skill_mods", {}).duplicate(true)
	var gear: Dictionary = lo.get("gear", {})
	for s in gear:
		var cur = ch.equipment.get(s)
		if cur is Dictionary and cur.get("uid", "") == gear[s]:
			continue
		for i in ch.inventory.size():
			var it = ch.inventory[i]
			if it is Dictionary and it.get("uid", "") == gear[s] and InventoryOps.can_equip(ch, it):
				ch.inventory[i] = cur
				ch.equipment[s] = it
				break
	ch.recalc()
	return {"ok": true, "message": "Loaded %s" % lo.get("name", "build")}
