class_name Weapons
extends RefCounted
## Weapon types, class affinities and weapon proficiency (GDD v2.1 #19: any class, any weapon).
## Data: `weapon_types` table, `classes[].affinities`, `config/proficiency`. Everything tolerates
## missing data: unknown types fall back to FALLBACK below (presentation defaults only, no balance).

## Presentation fallback when `weapon_types` has no record for an item type.
const FALLBACK := {
	"sword": {"hand": "main", "attach": "handslot.r", "anim_set": "1h"},
	"axe": {"hand": "main", "attach": "handslot.r", "anim_set": "1h"},
	"mace": {"hand": "main", "attach": "handslot.r", "anim_set": "1h"},
	"dagger": {"hand": "main", "attach": "handslot.r", "anim_set": "1h"},
	"spear": {"hand": "two", "attach": "handslot.r", "anim_set": "2h"},
	"axe2h": {"hand": "two", "attach": "handslot.r", "anim_set": "2h"},
	"staff": {"hand": "two", "attach": "handslot.r", "anim_set": "caster"},
	"wand": {"hand": "main", "attach": "handslot.r", "anim_set": "caster"},
	"crossbow": {"hand": "main", "attach": "handslot.r", "anim_set": "ranged"},
	"bow": {"hand": "two", "attach": "handslot.l", "anim_set": "ranged"},
	"shield": {"hand": "off", "attach": "handslot.l", "anim_set": ""},
	"tome": {"hand": "off", "attach": "handslot.l", "anim_set": ""},
	"quiver": {"hand": "off", "attach": "handslot.l", "anim_set": ""},
	"orb": {"hand": "off", "attach": "handslot.l", "anim_set": ""},
}

## Attack animations per anim set (overridable via config "anim_sets": {set: [anims]}).
const ANIM_SETS := {
	"1h": ["1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Chop"],
	"2h": ["2H_Melee_Attack_Chop", "2H_Melee_Attack_Slice"],
	"ranged": ["1H_Ranged_Shoot"],
	"ranged2h": ["2H_Ranged_Shoot"],
	"caster": ["Spellcast_Shoot"],
	"dual": ["Dualwield_Melee_Attack_Chop", "Dualwield_Melee_Attack_Slice", "Dualwield_Melee_Attack_Stab"],
}

static func type_rec(type_id: String) -> Dictionary:
	var r = Content.get_rec("weapon_types", type_id)
	if not r.is_empty():
		return r
	var fb: Dictionary = FALLBACK.get(type_id, {})
	return fb

static func item_type(item) -> String:
	if not (item is Dictionary) or item.is_empty():
		return ""
	var t = str(item.get("type", ""))
	if t == "":
		t = str(Content.get_rec("item_bases", str(item.get("base", ""))).get("type", ""))
	return t

static func main_type(ch: CharacterData) -> String:
	return item_type(ch.equipment.get("main_hand"))

static func is_two_handed(item) -> bool:
	if not (item is Dictionary) or item.is_empty():
		return false
	var base = Content.get_rec("item_bases", str(item.get("base", "")))
	if base.has("two_handed"):
		return bool(base.two_handed)
	return str(type_rec(item_type(item)).get("hand", "")) == "two"

## Prop model for an equipped item: item_bases.model, else weapon_types.prop.
static func prop_path(item) -> String:
	if not (item is Dictionary) or item.is_empty():
		return ""
	var m = str(Content.get_rec("item_bases", str(item.get("base", ""))).get("model", ""))
	if m == "":
		m = str(type_rec(item_type(item)).get("prop", ""))
	return m

## Attack animation list for the equipped main-hand ([] = keep the skill's own anim).
static func attack_anims(ch: CharacterData) -> Array:
	var t = main_type(ch)
	if t == "":
		return []
	var set_id = str(type_rec(t).get("anim_set", ""))
	if set_id == "ranged" and is_two_handed(ch.equipment.get("main_hand")):
		set_id = "ranged2h"
	var sets: Dictionary = Content.cfg("anim_sets", "sets", {})
	if sets.has(set_id):
		return sets[set_id]
	return ANIM_SETS.get(set_id, [])

## Class affinity bonus for the equipped main-hand type (stat source "affinity").
static func affinity_stats(ch: CharacterData) -> Dictionary:
	var t = main_type(ch)
	if t == "":
		return {}
	var aff: Dictionary = ch.cls().get("affinities", {})
	var out = {}
	var rec = aff.get(t, {})
	if rec is Dictionary:
		for k in rec:
			out[k] = float(rec[k])
	return out

# ------------------------------------------------------------------ proficiency
static func prof_cfg() -> Dictionary:
	return Content.get_rec("config", "proficiency")

static func prof_max_level() -> int:
	return int(prof_cfg().get("max_level", 50))

static func prof_xp_to_next(level: int) -> int:
	var curve: Dictionary = prof_cfg().get("curve", {})
	return int(round(float(curve.get("base", 20.0)) * pow(float(curve.get("growth", 1.12)), level - 1)))

static func prof_level(ch: CharacterData, type_id: String) -> int:
	var p = ch.proficiency.get(type_id)
	return int(p.get("level", 1)) if p is Dictionary else 1

## Adds proficiency XP for a weapon type. Returns levels gained.
static func gain_proficiency(ch: CharacterData, type_id: String, amount := -1) -> int:
	if type_id == "":
		return 0
	if amount < 0:
		amount = int(prof_cfg().get("xp_per_kill", 1))
	if not (ch.proficiency.get(type_id) is Dictionary):
		ch.proficiency[type_id] = {"level": 1, "xp": 0}
	var p: Dictionary = ch.proficiency[type_id]
	var lvl = int(p.get("level", 1))
	var xp = int(p.get("xp", 0)) + amount
	var gained = 0
	while lvl < prof_max_level() and xp >= prof_xp_to_next(lvl):
		xp -= prof_xp_to_next(lvl)
		lvl += 1
		gained += 1
	if lvl >= prof_max_level():
		xp = 0
	p.level = lvl
	p.xp = xp
	if gained > 0:
		Events.proficiency_up.emit(type_id, lvl)
	return gained

## Permanent proficiency bonus for the wielded main-/off-hand types (level 1 = no bonus).
static func proficiency_stats(ch: CharacterData) -> Dictionary:
	var out = {}
	var types = []
	for slot in ["main_hand", "off_hand"]:
		var t = item_type(ch.equipment.get(slot))
		if t != "" and not types.has(t):
			types.append(t)
	for t in types:
		var lvl = prof_level(ch, t) - 1
		if lvl <= 0:
			continue
		var bonus: Dictionary = type_rec(t).get("proficiency_bonus", {})
		for k in bonus:
			out[k] = float(out.get(k, 0.0)) + float(bonus[k]) * lvl
	return out
