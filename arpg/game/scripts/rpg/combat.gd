class_name Combat
extends RefCounted
## Damage math. Attackers/defenders are described by StatBlocks + a small context dict so the
## same functions work for players, monsters, minions and (later) remote actors.

const ELEMENTS := ["physical", "fire", "cold", "lightning", "shadow", "holy"]

## Player/minion outgoing hit.
## src: { stats: StatBlock, weapon: Dictionary, level:int }
## skill_mult: e.g. 1.4 for 140% weapon damage
static func roll_player_hit(src: Dictionary, skill_mult: float, element: String, tags: Array, stream := "combat") -> Dictionary:
	var st: StatBlock = src.stats
	var w: Dictionary = src.get("weapon", {})
	var wmin := float(w.get("dmg_min", 2.0 + src.get("level", 1)))
	var wmax := float(w.get("dmg_max", 4.0 + src.get("level", 1) * 1.5))
	var base := Rng.range_on(stream, wmin, wmax) + st.get_stat("damage")
	var inc := st.get_stat("damage_pct") + st.get_stat(element + "_pct")
	for t in tags:
		inc += st.get_stat(str(t) + "_damage_pct")
	var more := (1.0 + st.get_stat("more_damage") / 100.0)
	var primary := st.total(src.get("primary", "might"))
	var dmg := base * skill_mult * (1.0 + primary / 100.0) * (1.0 + inc / 100.0) * more
	var crit_chance := clampf((5.0 + st.get_stat("crit_chance")) / 100.0, 0.0, 0.95)
	var crit := Rng.chance(stream, crit_chance)
	if crit:
		dmg *= 1.5 + st.get_stat("crit_damage") / 100.0
	return {"amount": max(1.0, dmg), "crit": crit, "element": element}

## Monster outgoing hit (level/tier scaled, not gear based).
static func monster_hit(monster_level: int, dmg_mult: float, tier: Dictionary, stream := "combat") -> Dictionary:
	var base := (5.0 + monster_level * 2.6 + pow(monster_level, 1.35) * 0.35) * dmg_mult
	base *= float(tier.get("damage_mult", 1.0))
	base *= Rng.range_on(stream, 0.85, 1.15)
	return {"amount": base, "crit": false}

## Apply defender mitigation. def: { stats: StatBlock, level:int, resist_penalty:float }
static func mitigate(hit: Dictionary, def: Dictionary, attacker_level: int) -> float:
	var st: StatBlock = def.stats
	var amount := float(hit.amount)
	var element: String = hit.get("element", "physical")
	if element == "physical":
		var armor := st.total("armor")
		var k := 50.0 * attacker_level + 150.0
		amount *= 1.0 - clampf(armor / (armor + k), 0.0, 0.85)
	else:
		var res := st.get_stat("resist_all") + st.get_stat("resist_" + element) - float(def.get("resist_penalty", 0.0))
		amount *= 1.0 - clampf(res, -100.0, 75.0) / 100.0
	amount *= 1.0 - clampf(st.get_stat("damage_reduction"), 0.0, 60.0) / 100.0
	# Dodge
	if Rng.chance("combat", clampf(st.get_stat("dodge") / 100.0, 0.0, 0.5)):
		return 0.0
	return max(0.0, amount)

## Monster stats by level and tier.
static func monster_life(base_life_mult: float, monster_level: int, tier: Dictionary) -> float:
	var life := (18.0 + monster_level * 9.0 + pow(monster_level, 1.55) * 0.9) * base_life_mult
	return life * float(tier.get("life_mult", 1.0))
