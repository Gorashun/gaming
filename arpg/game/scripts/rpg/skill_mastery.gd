class_name SkillMastery
extends RefCounted
## Skill Mastery (GDD v2.2 #25). Every skill earns usage XP from hits and kills it makes. A mastery
## rank unlocks only when the XP threshold is reached AND gold + materials are paid (never fails).
## Data:
##   config/skill_mastery {max_rank, xp_base, xp_growth, xp_per_hit, xp_per_kill,
##                         costs:[{rank_from, rank_to, gold, materials{}}]}
##   skills[].mastery {per_rank | bonuses_per_rank {stat | damage_pct/_mult | cooldown_pct/_mult | area_pct/_mult},
##                     milestones:[{rank, stats{}, patch{}}]}
## Per-rank multipliers are fractions: damage_mult 0.03 = +3 % effect damage per rank, area_mult
## likewise; cooldown_mult 0.02 = 2 % shorter cooldown per rank (sign ignored, always a reduction).
## Other keys are character stats (source "mastery"). Mastery is never refunded or lost.
## Character: skill_xp{skill_id: xp toward next rank}, skill_mastery{skill_id: rank}.

const DEFAULT_BONUS := {"damage_pct": 3.0}
## Per-rank keys that modify the skill itself (fractions *_mult or percents *_pct); others are stats.
const SKILL_KEYS := ["damage_mult", "cooldown_mult", "area_mult", "damage_pct", "cooldown_pct", "area_pct"]

## skills[].mastery.per_rank | bonuses_per_rank, else config/skill_mastery.per_rank_default.
static func per_rank(m: Dictionary) -> Dictionary:
	var b = m.get("per_rank", m.get("bonuses_per_rank", null))
	if b is Dictionary:
		return b
	var d = cfg().get("per_rank_default", DEFAULT_BONUS)
	return d if d is Dictionary else DEFAULT_BONUS

static func cfg() -> Dictionary:
	return Content.get_rec("config", "skill_mastery")

static func max_rank() -> int:
	return int(cfg().get("max_rank", 20))

static func rank(ch: CharacterData, skill_id: String) -> int:
	return int(ch.skill_mastery.get(skill_id, 0))

static func xp_for_next(r: int) -> int:
	var c = cfg()
	return int(round(float(c.get("xp_base", 60.0)) * pow(float(c.get("xp_growth", 1.35)), r)))

static func mastery_rec(skill_id: String) -> Dictionary:
	var m = Content.get_rec("skills", skill_id).get("mastery", {})
	return m if m is Dictionary else {}

## Cost of going from rank r to r+1: {gold, materials}.
static func cost_for(r: int) -> Dictionary:
	for e in cfg().get("costs", []):
		if int(e.get("rank_from", 0)) <= r and r < int(e.get("rank_to", int(e.get("rank_from", 0)) + 1)):
			var mats = {}
			for k in e.get("materials", {}):
				if Content.has_rec("materials", k):
					mats[k] = int(e.materials[k])
			return {"gold": int(e.get("gold", 0)), "materials": mats}
	var m = {}
	if r < 5:
		m = {"soot": 2 + r * 2}
	elif r < 10:
		m = {"soot": 6 + r, "wickthread": r - 3}
	elif r < 15:
		m = {"wickthread": r, "dusk_essence": r - 8}
	else:
		m = {"dusk_essence": r - 5, "ember_heart": r - 13}
	for k in m.keys():
		if not Content.has_rec("materials", k):
			m.erase(k)
	return {"gold": int(round(50.0 * pow(1.6, r))), "materials": m}

## UI/API: {rank, max_rank, xp, next_xp, ready (xp reached), can_upgrade, cost, reason}
static func xp_progress(ch: CharacterData, skill_id: String) -> Dictionary:
	var r = rank(ch, skill_id)
	var xp = int(ch.skill_xp.get(skill_id, 0))
	var at_max = r >= max_rank()
	var need = xp_for_next(r)
	var c = {} if at_max else cost_for(r)
	var reason = ""
	if at_max:
		reason = "Mastered"
	elif xp < need:
		reason = "Keep using this skill"
	elif ch.gold < int(c.gold):
		reason = "Not enough gold"
	elif not ch.has_materials(c.materials):
		reason = "Missing materials"
	return {"rank": r, "max_rank": max_rank(), "xp": xp, "next_xp": need, "ready": not at_max and xp >= need,
		"can_upgrade": reason == "", "cost": c, "reason": reason}

## Adds usage XP (hit/kill by this skill). Emits skill_mastery_ready once when the threshold is crossed.
static func gain(ch: CharacterData, skill_id: String, amount: int) -> void:
	if skill_id == "" or amount <= 0 or not Content.has_rec("skills", skill_id):
		return
	var r = rank(ch, skill_id)
	if r >= max_rank():
		return
	var need = xp_for_next(r)
	var before = int(ch.skill_xp.get(skill_id, 0))
	var after = min(before + amount, need * 3)   # soft cap so a paused upgrade never wastes much
	ch.skill_xp[skill_id] = after
	if before < need and after >= need:
		Events.skill_mastery_ready.emit(skill_id)

static func on_hit(ch: CharacterData, skill_id: String) -> void:
	gain(ch, skill_id, int(cfg().get("xp_per_hit", 1)))

static func on_kill(ch: CharacterData, skill_id: String) -> void:
	gain(ch, skill_id, int(cfg().get("xp_per_kill", 4)))

## Pay and rank up. Returns {ok, message}.
static func upgrade(ch: CharacterData, skill_id: String) -> Dictionary:
	var p = xp_progress(ch, skill_id)
	if not p.can_upgrade:
		return {"ok": false, "message": p.reason}
	ch.gold -= int(p.cost.gold)
	ch.spend_materials(p.cost.materials)
	ch.skill_xp[skill_id] = int(p.xp) - int(p.next_xp)
	ch.skill_mastery[skill_id] = int(p.rank) + 1
	ch.recalc()
	Events.skill_mastery_up.emit(skill_id, int(p.rank) + 1)
	Events.gold_changed.emit(ch.gold)
	var msg = "%s mastery rank %d!" % [Content.get_rec("skills", skill_id).get("name", skill_id), int(p.rank) + 1]
	for ms in mastery_rec(skill_id).get("milestones", []):
		if int(ms.get("rank", 0)) == int(p.rank) + 1:
			msg += " " + str(ms.get("name", "Milestone reached!"))
	return {"ok": true, "message": msg}

## Applies per-rank multipliers and milestone patches to a resolved (copied) skill.
static func apply_to_skill(ch: CharacterData, s: Dictionary) -> void:
	var r = rank(ch, str(s.get("id", "")))
	if r <= 0:
		return
	var m = mastery_rec(str(s.get("id", "")))
	var b = per_rank(m)
	var dmg = 1.0 + (float(b.get("damage_mult", 0.0)) + float(b.get("damage_pct", 0.0)) / 100.0) * r
	var area = 1.0 + (float(b.get("area_mult", 0.0)) + float(b.get("area_pct", 0.0)) / 100.0) * r
	var cdm = clampf(1.0 - (absf(float(b.get("cooldown_mult", 0.0))) + absf(float(b.get("cooldown_pct", 0.0))) / 100.0) * r, 0.25, 1.0)
	if s.has("cooldown"):
		s.cooldown = float(s.cooldown) * cdm
	for e in s.get("effects", []):
		if not (e is Dictionary):
			continue
		if dmg != 1.0:
			e["mult"] = float(e.get("mult", 1.0)) * dmg
		if area != 1.0:
			for k in ["radius", "land_radius", "explode_radius"]:
				if e.has(k):
					e[k] = float(e[k]) * area
	for ms in m.get("milestones", []):
		if int(ms.get("rank", 999)) <= r:
			SkillMods.apply_patch(s, ms.get("patch", {}))

## Character-wide stats from mastery (non-multiplier keys of bonuses_per_rank + milestone stats).
static func stat_bonuses(ch: CharacterData) -> Dictionary:
	var out = {}
	for sid in ch.skill_mastery:
		var r = int(ch.skill_mastery[sid])
		if r <= 0:
			continue
		var m = mastery_rec(sid)
		var b = per_rank(m)
		for k in b:
			if k in SKILL_KEYS:
				continue
			out[k] = float(out.get(k, 0.0)) + float(b[k]) * r
		for ms in m.get("milestones", []):
			if int(ms.get("rank", 999)) <= r:
				for k in ms.get("stats", {}):
					out[k] = float(out.get(k, 0.0)) + float(ms.stats[k])
	return out
