class_name Loot
extends RefCounted
## Kill → drops. Pure function of (monster, difficulty, character). Pity counters live on the character.

## Returns { items:[...], gold:int, materials:{id:count} }
## `fallback_cfg` is used when config/loot.kinds has no entry for `kind` (new sources tolerate missing data).
static func roll_kill(monster: Dictionary, monster_level: int, ch: CharacterData, tier: Dictionary, kind := "normal", fallback_cfg := {}) -> Dictionary:
	var out = {"items": [], "gold": 0, "materials": {}}
	var kind_cfg: Dictionary = Content.get_rec("config", "loot").get("kinds", {}).get(kind, fallback_cfg)
	var drop_chance = float(kind_cfg.get("item_chance", 0.18)) * float(monster.get("loot_mult", 1.0))
	var min_items = int(kind_cfg.get("min_items", 0))
	var max_items = int(kind_cfg.get("max_items", 1))
	var n = min_items
	for i in range(min_items, max_items):
		if Rng.chance("loot", drop_chance):
			n += 1
	var ctx = rarity_context(ch, tier, monster_level, kind_cfg)
	for i in n:
		var rarity = Items.roll_rarity(ctx)
		rarity = _apply_pity(ch, rarity, monster_level)
		var smart = Rng.chance("loot", float(Content.cfg("loot", "smart_loot", 0.75)))
		var item = Items.generate(monster_level, rarity, ch.class_id if smart else "")
		if not item.is_empty():
			out.items.append(item)
	# Uniques from boss tables
	for u in monster.get("uniques", []):
		if Rng.chance("loot", float(u.get("chance", 0.025)) * float(tier.get("unique_mult", 1.0))):
			var it = Items.from_unique(u.id, monster_level)
			if not it.is_empty():
				out.items.append(it)
	# Gold
	var gold_chance = float(kind_cfg.get("gold_chance", 0.35))
	if Rng.chance("loot", gold_chance):
		var g = (4.0 + monster_level * 1.6) * Rng.range_on("loot", 0.6, 1.6) * float(kind_cfg.get("gold_mult", 1.0))
		g *= 1.0 + ch.stats.total("gold_find") / 100.0
		out.gold = int(g * float(tier.get("gold_mult", 1.0)))
	# Materials
	var mat_mult = 1.0 + ch.stats.total("material_find") / 100.0
	for m in monster.get("materials", []) + tier.get("materials", []) + kind_cfg.get("materials", []) + global_materials(kind):
		if Rng.chance("loot", float(m.get("chance", 0.1)) * mat_mult):
			out.materials[m.id] = int(out.materials.get(m.id, 0)) + Rng.int_on("loot", int(m.get("min", 1)), int(m.get("max", 1)))
	return out

## Rarity roll context shared by monster drops, chests and the Curio Cart (identical odds everywhere).
static func rarity_context(ch: CharacterData, tier: Dictionary, monster_level: int, kind_cfg := {}) -> Dictionary:
	return {
		"magic_find": ch.stats.total("magic_find") + float(tier.get("magic_find", 0)),
		"monster_level": monster_level,
		"tier_bonus": tier.get("rarity_bonus", {}),
		"source_bonus": kind_cfg.get("rarity_bonus", {}),
		"min_rank": int(kind_cfg.get("min_rank", 0)),
	}

## One item rolled exactly like a monster drop (rarity + pity), optionally restricted to a slot/type.
static func roll_item(ch: CharacterData, tier: Dictionary, ilvl: int, kind := "normal", slot := "", type_id := "") -> Dictionary:
	var kind_cfg: Dictionary = Content.get_rec("config", "loot").get("kinds", {}).get(kind, {})
	var rarity = Items.roll_rarity(rarity_context(ch, tier, ilvl, kind_cfg))
	rarity = _apply_pity(ch, rarity, ilvl)
	return Items.generate(ilvl, rarity, ch.class_id, "", slot, "loot", type_id)

## Materials that can drop from any source kind, e.g. Hushmarks (Curio Cart currency).
## config/loot.global_materials: [{id, chance, min, max, kinds:{kind: chance}}]. Default: Hushmarks
## from elites/bosses/events when a "hushmark" material exists.
static func global_materials(kind: String) -> Array:
	var list = Content.cfg("loot", "global_materials", null)
	if list == null:
		if not Content.has_rec("materials", "hushmark"):
			return []
		list = [{"id": "hushmark", "chance": 0.01, "min": 1, "max": 1,
			"kinds": {"champion": 0.25, "rare": 0.45, "boss": 1.0, "magpie": 1.0, "hushfall_cache": 1.0, "chest_gold": 0.5}}]
	var out = []
	for m in list:
		if not Content.has_rec("materials", str(m.get("id", ""))):
			continue
		var e: Dictionary = m.duplicate()
		var kinds: Dictionary = m.get("kinds", {})
		if kinds.has(kind):
			e.chance = float(kinds[kind])
			if kind in ["boss", "hushfall_cache", "magpie"]:
				e.max = max(int(e.get("max", 1)), 3)
		out.append(e)
	return out

## Visible bad-luck protection: counters measured in play-seconds since the last drop of that rank.
static func _apply_pity(ch: CharacterData, rarity: String, monster_level: int) -> String:
	var rank = Items.rarity_index(rarity)
	var result = rarity
	for r in Content.all("rarities"):
		var pity_s = float(r.get("pity_seconds", 0))
		if pity_s <= 0 or int(r.get("min_monster_level", 0)) > monster_level:
			continue
		var since = (ch.play_seconds - float(ch.pity.get(r.id, 0.0))) * pity_speed(ch)
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
	var r = Content.get_rec("rarities", rarity_id)
	var pity_s = float(r.get("pity_seconds", 0))
	if pity_s <= 0:
		return 0.0
	return clampf((ch.play_seconds - float(ch.pity.get(rarity_id, 0.0))) * pity_speed(ch) / pity_s, 0.0, 1.0)

## "Lucky" pets etc. make the visible pity meter fill faster (still counts active play only).
static func pity_speed(ch: CharacterData) -> float:
	return 1.0 + max(0.0, ch.stats.get_stat("pity_speed_pct")) / 100.0
