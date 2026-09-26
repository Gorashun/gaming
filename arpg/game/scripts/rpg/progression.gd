class_name Progression
extends RefCounted
## XP curve and point grants. Parameters live in content config "progression".

static func xp_to_next(level: int) -> int:
	var c: Dictionary = Content.get_rec("config", "progression")
	var base: float = c.get("xp_base", 120.0)
	var growth: float = c.get("xp_growth", 1.075)
	var post60: float = c.get("xp_growth_post60", 1.018)
	var lin: float = c.get("xp_linear", 40.0)
	var xp: float
	if level < 60:
		xp = base * pow(growth, level - 1) + lin * level
	else:
		xp = (base * pow(growth, 59) + lin * 60) * pow(post60, level - 60) + lin * 4.0 * (level - 60)
	return int(round(xp))

static func max_level() -> int:
	return int(Content.cfg("progression", "max_level", 200))

static func skill_points_for_level(level: int) -> int:
	return 1 if level <= 60 else 0

static func star_points_for_level(level: int) -> int:
	return 2 if level > 60 else 0

## Monster XP scaled by level difference (no XP farming of grey monsters).
static func monster_xp(base_xp: float, monster_level: int, player_level: int, tier_mult: float) -> int:
	var diff := monster_level - player_level
	var f := 1.0
	if diff < -5:
		f = max(0.1, 1.0 + (diff + 5) * 0.1)
	elif diff > 0:
		f = 1.0 + min(diff, 5) * 0.05
	var lvl_scale := 1.0 + monster_level * 0.35
	return int(max(1.0, round(base_xp * lvl_scale * f * tier_mult)))
