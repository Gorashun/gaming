class_name Loot
extends RefCounted
## Kill → drops. Pure function of (monster, difficulty, character). Pity counters live on the character.

## Returns { items:[...], gold:int, materials:{id:count} }
static func roll_kill(monster: Dictionary, monster_level: int, ch: CharacterData, tier: Dictionary, kind := "normal") -> Dictionary:
	var out := {"items": [], "gold": 0, "materials": {}}
	var kind_cfg: Dictionary = Content.get_rec("config", "loot").get("kinds", {}).get(kind, {})
	var drop_chance := float(kind_cfg.get("item_chance", 0.18)) * float(monster.get("loot_mult", 1.0))
	var min_items := int(kind_cfg.get("min_items", 0))
	var max_items := int(kind_cfg.get("max_items", 1))
	var n := min_items
	for i in range(min_items, max_items):
		if Rng.chance("loot", drop_chance):
			n += 1
	var ctx := {
		"magic_find": ch.stats.total("magic_find") + float(tier.get("magic_find", 0)),
		"monster_level": monster_level,
		"tier_bonus": tier.get("rarity_bonus", {}),
		"source_bonus": kind_cfg.get("rarity_bonus", {}),
		"min_rank": int(kind_cfg.get("min_rank", 0)),
	}
	for i in n:
		var rarity := Items.roll_rarity(ctx)
		rarity = _apply_pity(ch, rarity, monster_level)
		var smart := Rng.chance("loot", float(Content.cfg("loot", "smart_loot", 0.75)))
		var item := Items.generate(monster_level, rarity, ch.class_id if smart else "")
		if not item.is_empty():
			out.items.append(item)
	# Uniques from boss tables
	for u in monster.get("uniques", []):
		if Rng.chance("loot", float(u.get("chance", 0.025)) * float(tier.get("unique_mult", 1.0))):
			var it := Items.from_unique(u.id, monster_level)
			if not it.is_empty():
				out.items.append(it)
	# Gold
	var gold_chance := float(kind_cfg.get("gold_chance", 0.35))
	if Rng.chance("loot", gold_chance):
		var g := (4.0 + monster_level * 1.6) * Rng.range_on("loot", 0.6, 1.6) * float(kind_cfg.get("gold_mult", 1.0))
		g *= 1.0 + ch.stats.total("gold_find") / 100.0
		out.gold = int(g * float(tier.get("gold_mult", 1.0)))
	# Materials
	for m in monster.get("materials", []) + tier.get("materials", []) + kind_cfg.get("materials", []):
		if Rng.chance("loot", float(m.get("chance", 0.1))):
			out.materials[m.id] = int(out.materials.get(m.id, 0)) + Rng.int_on("loot", int(m.get("min", 1)), int(m.get("max", 1)))
	return out

## Visible bad-luck protection: counters measured in play-seconds since the last drop of that rank.
static func _apply_pity(ch: CharacterData, rarity: String, monster_level: int) -> String:
	var rank := Items.rarity_index(rarity)
	var result := rarity
	for r in Content.all("rarities"):
		var pity_s := float(r.get("pity_seconds", 0))
		if pity_s <= 0 or int(r.get("min_monster_level", 0)) > monster_level:
			continue
		var since := ch.play_seconds - float(ch.pity.get(r.id, 0.0))
		if since >= pity_s and int(r.rank) > Items.rarity_index(result):
			result = r.id
	for r in Content.all("rarities"):
		if int(r.rank) <= Items.rarity_index(result) and float(r.get("pity_seconds", 0)) > 0:
			ch.pity[r.id] = ch.play_seconds
	if Items.rarity_index(result) != rank:
		Events.toast.emit("The light favours you!", Items.rarity_color(result))
	return result

## Pity progress 0..1 for UI.
static func pity_progress(ch: CharacterData, rarity_id: String) -> float:
	var r := Content.get_rec("rarities", rarity_id)
	var pity_s := float(r.get("pity_seconds", 0))
	if pity_s <= 0:
		return 0.0
	return clampf((ch.play_seconds - float(ch.pity.get(rarity_id, 0.0))) / pity_s, 0.0, 1.0)
