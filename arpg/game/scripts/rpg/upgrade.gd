class_name Upgrade
extends RefCounted
## Item upgrading +0…+15 at the Smith (GDD v2.1 #17). Costs gold + materials, rising steeply.
## Success is guaranteed (welfare: no fail/break) and the full cost is shown before committing.
## Data: config/upgrade {max, stat_per_level_pct, gold[], materials[{mat: count}], ilvl_cost_scale}.
## Each step boosts base damage/armour by stat_per_level_pct and implicit/affix values by
## affix_per_level_pct (falls back to stat_per_level_pct).

static func cfg() -> Dictionary:
	return Content.get_rec("config", "upgrade")

static func max_level() -> int:
	return int(cfg().get("max", 15))

static func pct_per_level() -> float:
	return float(cfg().get("stat_per_level_pct", 5.0))

static func level_of(item: Dictionary) -> int:
	return int(item.get("upgrade", 0))

## Multiplier applied to base numbers and affixes for an upgrade level.
static func mult_for(level: int) -> float:
	return 1.0 + pct_per_level() * level / 100.0

static func item_mult(item: Dictionary) -> float:
	return mult_for(level_of(item))

## Affix/implicit multiplier (config affix_per_level_pct, else stat_per_level_pct).
static func affix_mult(item: Dictionary) -> float:
	return 1.0 + float(cfg().get("affix_per_level_pct", pct_per_level())) * level_of(item) / 100.0

## Cost of the next step (+level → +level+1): {gold:int, materials:{id:count}}. Empty at max.
static func cost(item: Dictionary) -> Dictionary:
	var lvl = level_of(item)
	if lvl >= max_level():
		return {}
	var c = cfg()
	var ilvl_scale = 1.0 + int(item.get("ilvl", 1)) * float(c.get("gold_ilvl_mult", c.get("ilvl_cost_scale", 0.03)))
	var gold = 0
	var golds: Array = c.get("gold", [])
	if lvl < golds.size():
		gold = int(round(float(golds[lvl]) * ilvl_scale))
	else:
		gold = int(round(40.0 * pow(1.45, lvl) * ilvl_scale))
	var mats = {}
	var mat_list: Array = c.get("materials", [])
	if lvl < mat_list.size() and mat_list[lvl] is Dictionary:
		for k in mat_list[lvl]:
			mats[k] = int(mat_list[lvl][k])
	else:
		mats = _default_materials(lvl)
	# Only ask for materials that exist in the loaded content
	for k in mats.keys():
		if not Content.has_rec("materials", k):
			mats.erase(k)
	return {"gold": gold, "materials": mats}

static func _default_materials(lvl: int) -> Dictionary:
	if lvl < 5:
		return {"soot": 2 + lvl}
	if lvl < 10:
		return {"soot": 4 + lvl, "wickthread": lvl - 3}
	var m = {"wickthread": 3 + lvl - 10, "dusk_essence": lvl - 8}
	if lvl >= 14:
		m["ember_heart"] = 1
	return m

## "" when the upgrade can be done, else a player-facing reason.
static func can_upgrade(ch: CharacterData, item: Dictionary) -> String:
	if item.is_empty() or item.get("placeholder", false):
		return "Choose an item"
	if level_of(item) >= max_level():
		return "Fully upgraded"
	var c = cost(item)
	if ch.gold < int(c.gold):
		return "Not enough gold"
	if not ch.has_materials(c.materials):
		return "Missing materials"
	return ""

## Full preview for the UI: cost, before/after stats and deltas. Nothing is changed.
## { ok:bool, reason, from, to, cost:{gold, materials}, stats_before, stats_after, deltas:{stat: d},
##   dmg_before:[min,max], dmg_after:[min,max], armor_before, armor_after }
static func preview(ch: CharacterData, item: Dictionary) -> Dictionary:
	var lvl = level_of(item)
	var out = {"from": lvl, "to": min(lvl + 1, max_level()), "cost": cost(item), "reason": can_upgrade(ch, item) if ch else ""}
	out.ok = out.reason == ""
	var after = item.duplicate(true)
	after.upgrade = out.to
	var sb = Items.item_stats(item)
	var sa = Items.item_stats(after)
	out.stats_before = sb
	out.stats_after = sa
	var d = {}
	for k in sa:
		var diff = float(sa[k]) - float(sb.get(k, 0.0))
		if absf(diff) > 0.0001:
			d[k] = diff
	out.deltas = d
	if item.has("dmg_min"):
		out.dmg_before = Items.weapon_damage(item)
		out.dmg_after = Items.weapon_damage(after)
	if item.has("armor"):
		out.armor_before = float(sb.get("armor", 0.0))
		out.armor_after = float(sa.get("armor", 0.0))
	return out

## Performs one upgrade step. Never fails once can_upgrade() passes. Returns {ok, message, item}.
static func upgrade(ch: CharacterData, item: Dictionary) -> Dictionary:
	var err = can_upgrade(ch, item)
	if err != "":
		return {"ok": false, "message": err}
	var c = cost(item)
	ch.gold -= int(c.gold)
	ch.spend_materials(c.materials)
	item.upgrade = level_of(item) + 1
	item.name = Items.upgraded_name(item)
	Crafting.gain_xp(ch, "smith", 4 + item.upgrade * 2)
	ch.track("upgrades")
	if int(item.upgrade) >= max_level():
		ch.track("items_at_plus15")
	ch.recalc()
	Events.item_upgraded.emit(item)
	Events.gold_changed.emit(ch.gold)
	return {"ok": true, "message": "Upgraded to +%d!" % item.upgrade, "item": item}

## Total gold + materials already invested (for UI / future salvage refunds).
static func invested(item: Dictionary) -> Dictionary:
	var gold = 0
	var mats = {}
	var probe = item.duplicate()
	for l in level_of(item):
		probe.upgrade = l
		var c = cost(probe)
		gold += int(c.get("gold", 0))
		for k in c.get("materials", {}):
			mats[k] = int(mats.get(k, 0)) + int(c.materials[k])
	return {"gold": gold, "materials": mats}
