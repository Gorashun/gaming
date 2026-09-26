class_name SkillMods
extends RefCounted
## Skill behaviour modifiers (GDD v2 #7): each skill offers `modifiers` tiers at rank 2 and 4, one
## option picked per tier. Choices live in CharacterData.skill_mods{skill_id: [option ids]}.
## `resolve()` returns the skill record as it should execute for this character: modifier patches,
## Skill Mastery bonuses/milestones and a "_skill" stamp on every effect (for mastery XP attribution).
##
## Patch format (option.patch / milestone.patch), keys:
##   "cooldown": 4            top-level set;   "cooldown": "*0.8" multiply;  "cost": "+5" add
##   "0": {"radius": 3.5}     merge into effects[0] (values may also use "*x"/"+x")
##   "effects.1.count": 3     path set into effects[1]
##   "effects+": {...}|[...]  append effect(s)

static func tiers(skill: Dictionary) -> Array:
	var t = skill.get("modifiers", [])
	return t if t is Array else []

static func find_option(skill: Dictionary, option_id: String) -> Dictionary:
	for tier in tiers(skill):
		for o in tier.get("options", []):
			if str(o.get("id", "")) == option_id:
				return {"tier": tier, "option": o}
	return {}

static func chosen_options(ch: CharacterData, skill_id: String) -> Array:
	var out = []
	var skill = Content.get_rec("skills", skill_id)
	var rank = int(ch.skill_ranks.get(skill_id, 0))
	for oid in ch.skill_mods.get(skill_id, []):
		var f = find_option(skill, str(oid))
		if not f.is_empty() and rank >= int(f.tier.get("rank", 2)):
			out.append(f.option)
	return out

## UI helper: [{rank, unlocked:bool, chosen:String, options:[...]}]
static func available(ch: CharacterData, skill_id: String) -> Array:
	var skill = Content.get_rec("skills", skill_id)
	var rank = int(ch.skill_ranks.get(skill_id, 0))
	var chosen: Array = ch.skill_mods.get(skill_id, [])
	var out = []
	for tier in tiers(skill):
		var pick = ""
		for o in tier.get("options", []):
			if chosen.has(o.get("id", "")):
				pick = o.id
		out.append({"rank": int(tier.get("rank", 2)), "unlocked": rank >= int(tier.get("rank", 2)), "chosen": pick, "options": tier.get("options", [])})
	return out

## Pick (or swap) the option of its tier. Returns {ok, message}.
static func choose(ch: CharacterData, skill_id: String, option_id: String) -> Dictionary:
	var skill = Content.get_rec("skills", skill_id)
	if skill.is_empty():
		return {"ok": false, "message": "Unknown skill"}
	var f = find_option(skill, option_id)
	if f.is_empty():
		return {"ok": false, "message": "Unknown modifier"}
	var need = int(f.tier.get("rank", 2))
	if int(ch.skill_ranks.get(skill_id, 0)) < need:
		return {"ok": false, "message": "Requires rank %d" % need}
	var list: Array = ch.skill_mods.get(skill_id, []).duplicate()
	for o in f.tier.get("options", []):
		list.erase(o.get("id", ""))
	list.append(option_id)
	ch.skill_mods[skill_id] = list
	ch.recalc()
	return {"ok": true, "message": "%s: %s" % [skill.get("name", skill_id), f.option.get("name", option_id)]}

## The skill as executed by this character (deep copy; never mutates content).
static func resolve(ch: CharacterData, skill_id: String) -> Dictionary:
	var base = Content.get_rec("skills", skill_id)
	if base.is_empty():
		return base
	var s: Dictionary = base.duplicate(true)
	if ch:
		for opt in chosen_options(ch, skill_id):
			apply_patch(s, opt.get("patch", {}))
			apply_patch(s, {"effects+": opt.get("add_effects", [])})
		SkillMastery.apply_to_skill(ch, s)
	for e in s.get("effects", []):
		if e is Dictionary:
			e["_skill"] = skill_id
	return s

static func apply_patch(s: Dictionary, patch) -> void:
	if not (patch is Dictionary):
		return
	if not s.has("effects") or not (s.effects is Array):
		s["effects"] = []
	for k in patch:
		var key = str(k)
		var v = patch[k]
		if key == "effects+":
			if v is Array:
				for e in v:
					s.effects.append(e.duplicate(true) if e is Dictionary else e)
			elif v is Dictionary:
				s.effects.append(v.duplicate(true))
		elif key.is_valid_int():
			var i = int(key)
			if i >= 0 and i < s.effects.size() and v is Dictionary and s.effects[i] is Dictionary:
				for kk in v:
					s.effects[i][kk] = _op(s.effects[i].get(kk), v[kk])
		elif key.begins_with("effects."):
			var parts = key.split(".")
			if parts.size() >= 3 and parts[1].is_valid_int():
				var i = int(parts[1])
				if i >= 0 and i < s.effects.size() and s.effects[i] is Dictionary:
					var target: Dictionary = s.effects[i]
					for pi in range(2, parts.size() - 1):
						if not (target.get(parts[pi]) is Dictionary):
							target[parts[pi]] = {}
						target = target[parts[pi]]
					target[parts[-1]] = _op(target.get(parts[-1]), v)
		else:
			s[key] = _op(s.get(key), v)

## "*1.2" multiplies, "+3"/"-3" adds (on numeric current values); anything else replaces.
static func _op(current, v):
	if v is String and v.length() > 1 and (v[0] == "*" or v[0] == "+" or (v[0] == "-" and v.substr(1).is_valid_float())):
		var num = v.substr(1)
		if num.is_valid_float():
			var cur = float(current) if (current is float or current is int) else (1.0 if v[0] == "*" else 0.0)
			if v[0] == "*":
				return cur * float(num)
			return cur + float(num) * (-1.0 if v[0] == "-" else 1.0)
	if v is Dictionary or v is Array:
		return v.duplicate(true)
	return v
