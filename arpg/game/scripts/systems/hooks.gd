class_name Hooks
extends RefCounted
## Behaviour hooks named by data (passives[].hook incl. capstones/pacts, powers[].hook) with params.
## Stats on those records always apply through CharacterData.recalc; hooks add behaviour.
## Implemented: crit_gain_resource, low_life_buff, bonus_vs_status, chain_bonus_jumps, dodge_next_crit,
## aoe_repeat_chance, quake_stun_bonus, minion_death_burst, block_casts, holy_area_leaves_zone,
## zone_expire_burst, spin_every_n_casts, zone_minion_bonus, move_zone. Unknown hooks are ignored (stats still work).

## {hook: params} for the hero right now (ranked passives, pact, equipped item powers).
static func active(ch: CharacterData) -> Dictionary:
	var out = {}
	for pid in ch.passive_ranks:
		if int(ch.passive_ranks[pid]) > 0:
			_add(out, Content.get_rec("passives", pid))
	if ch.pact != "":
		_add(out, Content.get_rec("passives", ch.pact))
	for slot in ch.equipment:
		var it = ch.equipment[slot]
		if it is Dictionary and str(it.get("power", "")) != "":
			_add(out, Content.get_rec("powers", str(it.power)))
	return out

static func _add(out: Dictionary, rec: Dictionary) -> void:
	var h = str(rec.get("hook", ""))
	if h != "":
		var p = rec.get("params", {})
		out[h] = p if p is Dictionary else {}

static func has(ch: CharacterData, hook: String) -> bool:
	return ch.hooks.has(hook)

static func param(ch: CharacterData, hook: String, key: String, default):
	return ch.hooks.get(hook, {}).get(key, default)
