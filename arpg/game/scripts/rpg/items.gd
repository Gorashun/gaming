class_name Items
extends RefCounted
## Item generation and description. Items are plain Dictionaries (serializable, network-friendly):
## { uid, base, name, rarity, ilvl, slot, level_req, implicit:{stat:v}, affixes:[{id,stat,value,tier,greater}],
##   dmg_min, dmg_max, armor, aps, power, unique, named, kindle, kindle_max, sockets:[], stack, upgrade:int }

const SLOTS := ["head", "chest", "hands", "legs", "feet", "main_hand", "off_hand", "amulet", "ring1", "ring2", "belt", "charm"]

static var _uid_counter := 0

static func new_uid() -> String:
	_uid_counter += 1
	return "%x%04x" % [Time.get_ticks_usec(), _uid_counter % 65536]

static func rarity_ids() -> Array:
	return Content.all("rarities").map(func(r): return r.id)

static func rarity_index(rarity_id: String) -> int:
	return int(Content.get_rec("rarities", rarity_id).get("rank", 0))

static func rarity_color(rarity_id: String) -> Color:
	return Color(Content.get_rec("rarities", rarity_id).get("color", "#cccccc"))

## Pick a base appropriate for ilvl, optionally biased to a class and slot.
static func pick_base(ilvl: int, class_id := "", slot := "", stream := "loot", type_id := "") -> Dictionary:
	var candidates = []
	for b in Content.all("item_bases"):
		if int(b.get("min_ilvl", 1)) > ilvl:
			continue
		if slot != "" and b.slot != slot:
			continue
		if type_id != "" and str(b.get("type", "")) != type_id:
			continue
		var w = float(b.get("weight", 10))
		var classes: Array = b.get("classes", [])
		if class_id != "" and classes.size() > 0:
			w *= 3.0 if classes.has(class_id) else 0.35
		# Prefer bases close to the item level (better tiers drop deeper)
		var gap: int = ilvl - int(b.get("min_ilvl", 1))
		w *= 1.0 / (1.0 + gap / 40.0)
		candidates.append({"b": b, "weight": w})
	var pick = Rng.weighted(stream, candidates)
	return pick.b if pick else {}

static func roll_rarity(context: Dictionary, stream := "loot") -> String:
	## context: { tier_bonus:{rarity:mult}, magic_find:float, min_rarity, allow:[...]}
	var mf: float = context.get("magic_find", 0.0)
	var mf_eff = mf * 100.0 / (mf + 100.0) if mf > 0 else 0.0   # diminishing returns
	var entries = []
	for r in Content.all("rarities"):
		if not r.get("drops", true):
			continue
		if int(r.get("min_monster_level", 0)) > int(context.get("monster_level", 1)):
			continue
		var w = float(r.get("weight", 0))
		if int(r.rank) >= 1:
			w *= 1.0 + mf_eff / 100.0 * float(r.get("mf_scale", 1.0))
		w *= float(context.get("tier_bonus", {}).get(r.id, 1.0))
		w *= float(context.get("source_bonus", {}).get(r.id, 1.0))
		if int(r.rank) < int(context.get("min_rank", 0)):
			w = 0.0
		entries.append({"id": r.id, "weight": w})
	var pick = Rng.weighted(stream, entries)
	return pick.id if pick else "common"

static func generate(ilvl: int, rarity_id: String, class_id := "", base_id := "", slot := "", stream := "loot", type_id := "") -> Dictionary:
	var base: Dictionary = Content.get_rec("item_bases", base_id) if base_id != "" else pick_base(ilvl, class_id, slot, stream, type_id)
	if base.is_empty():
		return {}
	var rar: Dictionary = Content.get_rec("rarities", rarity_id)
	var item = {
		"uid": new_uid(), "base": base.id, "name": base.name, "rarity": rarity_id, "ilvl": ilvl,
		"slot": base.slot, "type": base.get("type", ""), "level_req": max(1, int(ilvl * 0.9) - 2),
		"implicit": {}, "affixes": [], "sockets": [], "kindle": 0, "kindle_max": 0, "upgrade": 0,
	}
	# Base numbers scale with ilvl within the base's band
	var scale = 1.0 + (ilvl - int(base.get("min_ilvl", 1))) * float(Content.cfg("items", "ilvl_scaling", 0.045))
	if base.has("dmg"):
		item.dmg_min = round(float(base.dmg[0]) * scale)
		item.dmg_max = round(float(base.dmg[1]) * scale)
		item.aps = float(base.get("aps", 1.2))
	if base.has("armor"):
		item.armor = round(float(base.armor) * scale)
	for stat in base.get("implicit", {}):
		var rng_v: Array = base.implicit[stat]
		item.implicit[stat] = snappedf(Rng.range_on(stream, rng_v[0], rng_v[1]) * (1.0 + (scale - 1.0) * 0.5), 0.1)
	# Affixes
	var n_aff = Rng.int_on(stream, int(rar.get("affix_min", 0)), int(rar.get("affix_max", 0)))
	var n_greater = int(rar.get("greater", 0))
	_roll_affixes(item, n_aff, n_greater, stream)
	# Legendary powers
	if rar.get("power", false):
		var powers = Content.all("powers").filter(func(p): return (p.get("slots", []).is_empty() or p.slots.has(item.slot)) and (class_id == "" or p.get("class", "") in ["", class_id]))
		if powers.size() > 0:
			var p = powers[Rng.int_on(stream, 0, powers.size() - 1)]
			item.power = p.id
	item.kindle_max = int(rar.get("kindle", 0)) + Rng.int_on(stream, 0, 8)
	item.kindle = item.kindle_max
	var sockets_max = int(base.get("sockets", 0))
	if sockets_max > 0 and Rng.chance(stream, 0.25 + 0.1 * rarity_index(rarity_id)):
		for i in Rng.int_on(stream, 1, sockets_max):
			item.sockets.append("")
	item.name = make_name(item, stream)
	return item

static func affix_pool(item: Dictionary) -> Array:
	var used = item.affixes.map(func(a): return a.get("group", a.id))
	return Content.all("affixes").filter(func(a):
		return (a.get("slots", []).is_empty() or a.slots.has(item.slot) or a.slots.has(item.type)) \
			and not used.has(a.get("group", a.id)) and int(a.tiers[0].ilvl) <= int(item.ilvl))

static func _roll_affixes(item: Dictionary, count: int, greater: int, stream: String) -> void:
	for i in count:
		var pool = affix_pool(item)
		if pool.is_empty():
			return
		var a = Rng.weighted(stream, pool)
		item.affixes.append(roll_affix(a, int(item.ilvl), i < greater, stream))

static func roll_affix(a: Dictionary, ilvl: int, greater: bool, stream := "loot") -> Dictionary:
	var tiers: Array = a.tiers.filter(func(t): return int(t.ilvl) <= ilvl)
	var tier_idx = tiers.size() - 1
	# Mostly top available tier, sometimes lower
	if tier_idx > 0 and Rng.chance(stream, 0.35):
		tier_idx -= 1
	var t: Dictionary = tiers[tier_idx]
	var v = Rng.range_on(stream, float(t.min), float(t.max))
	if greater:
		v *= 1.5
	var dec = int(a.get("decimals", 0))
	v = snappedf(v, pow(10, -dec)) if dec > 0 else round(v)
	return {"id": a.id, "stat": a.stat, "value": v, "tier": tier_idx + 1, "tiers": tiers.size(), "greater": greater, "group": a.get("group", a.id)}

static func make_name(item: Dictionary, stream := "loot") -> String:
	var base_name: String = Content.get_rec("item_bases", item.base).get("name", "Item")
	match item.rarity:
		"common":
			return base_name
		"magic":
			var pre = ""
			var suf = ""
			for a in item.affixes:
				var rec = Content.get_rec("affixes", a.id)
				if rec.get("kind") == "prefix" and pre == "":
					pre = rec.get("name", "") + " "
				elif rec.get("kind") == "suffix" and suf == "":
					suf = " " + rec.get("name", "")
			return pre + base_name + suf
		_:
			var parts: Dictionary = Content.get_rec("config", "name_parts")
			var a: Array = parts.get("first", ["Grim"])
			var b: Array = parts.get("second", ["Wick"])
			var n: String = a[Rng.int_on(stream, 0, a.size() - 1)] + b[Rng.int_on(stream, 0, b.size() - 1)]
			return n + " " + base_name

static func from_unique(unique_id: String, ilvl: int, stream := "loot") -> Dictionary:
	var u = Content.get_rec("uniques", unique_id)
	if u.is_empty():
		return {}
	var item = generate(ilvl, "common", "", u.base, "", stream)
	item.rarity = u.get("rarity", "unique")
	item.name = u.name
	item.unique = u.id
	item.affixes = []
	for fx in u.get("stats", []):
		var v = Rng.range_on(stream, float(fx.min), float(fx.max))
		item.affixes.append({"id": "u_" + fx.stat, "stat": fx.stat, "value": round(v) if float(fx.max) > 5 else snappedf(v, 0.1), "tier": 1, "tiers": 1, "greater": false, "group": fx.stat})
	if u.has("power"):
		item.power = u.power
	item.kindle_max = int(Content.get_rec("rarities", item.rarity).get("kindle", 10))
	item.kindle = item.kindle_max
	return item

## Aggregate stat contributions of an item (upgrade level boosts implicits, affixes and armour).
static func item_stats(item: Dictionary) -> Dictionary:
	var s = {}
	var um = Upgrade.item_mult(item)
	for k in item.get("implicit", {}):
		s[k] = float(s.get(k, 0.0)) + float(item.implicit[k]) * um
	for a in item.get("affixes", []):
		s[a.stat] = float(s.get(a.stat, 0.0)) + float(a.value) * um
	for g in item.get("sockets", []):
		if g != "":
			var gem = Content.get_rec("materials", g)
			var slot_kind = "weapon" if item.slot == "main_hand" else ("jewelry" if item.slot in ["amulet", "ring", "ring1", "ring2"] else "armor")
			for k in gem.get("socket", {}).get(slot_kind, {}):
				s[k] = float(s.get(k, 0.0)) + float(gem.socket[slot_kind][k])
	if item.has("armor"):
		s["armor"] = float(s.get("armor", 0.0)) + round(float(item.armor) * um)
	if item.has("power"):
		var p = Content.get_rec("powers", item.power)
		for k in p.get("stats", {}):
			s[k] = float(s.get(k, 0.0)) + float(p.stats[k])
	return s

## Weapon base damage [min, max] including the upgrade level.
static func weapon_damage(item: Dictionary) -> Array:
	if not item.has("dmg_min"):
		return [0.0, 0.0]
	var um = Upgrade.item_mult(item)
	return [round(float(item.dmg_min) * um), round(float(item.dmg_max) * um)]

## Name with the "+N " upgrade prefix (idempotent).
static func upgraded_name(item: Dictionary) -> String:
	var n = str(item.get("name", ""))
	var re = RegEx.create_from_string("^\\+\\d+ ")
	n = re.sub(n, "")
	var lvl = int(item.get("upgrade", 0))
	return ("+%d %s" % [lvl, n]) if lvl > 0 else n

## Rough "power score" for quick compare (green/red arrows).
static func score(item: Dictionary, class_id := "") -> float:
	var weights: Dictionary = Content.get_rec("config", "item_score").get("weights", {})
	var cls = Content.get_rec("classes", class_id)
	var primary: String = cls.get("primary", "might")
	var total = 0.0
	var st = item_stats(item)
	for k in st:
		var w = float(weights.get(k, 0.5))
		if k == primary:
			w = float(weights.get("primary", 2.0))
		total += w * float(st[k])
	if item.has("dmg_min"):
		var wd = weapon_damage(item)
		total += (float(wd[0]) + float(wd[1])) * 0.5 * float(item.get("aps", 1.0)) * 3.0
	if item.has("power"):
		total += 60.0
	return total

static func stat_label(stat: String, value: float) -> String:
	var rec = Content.get_rec("stats", stat)
	var fmt: String = rec.get("format", "+{v} " + stat)
	var v = str(int(value)) if absf(value - round(value)) < 0.05 else ("%.1f" % value)
	return fmt.replace("{v}", v)

static func describe(item: Dictionary) -> Array:
	## Returns lines as [text, Color]
	var lines = []
	var col = rarity_color(item.rarity)
	lines.append([item.name, col])
	var rar_name: String = Content.get_rec("rarities", item.rarity).get("name", item.rarity)
	var base: Dictionary = Content.get_rec("item_bases", item.base)
	lines.append(["%s %s" % [rar_name, base.get("type_name", base.get("type", ""))], col.darkened(0.15)])
	if int(item.get("upgrade", 0)) > 0:
		lines.append(["Upgrade +%d / +%d" % [int(item.upgrade), Upgrade.max_level()], Color(1.0, 0.85, 0.45)])
	if item.has("dmg_min"):
		var wd = weapon_damage(item)
		lines.append(["%d–%d Damage  ·  %.2f attacks/s" % [wd[0], wd[1], item.aps], Color.WHITE])
	if item.has("armor"):
		lines.append(["%d Armor" % round(float(item.armor) * Upgrade.item_mult(item)), Color.WHITE])
	var um = Upgrade.item_mult(item)
	for k in item.get("implicit", {}):
		lines.append([stat_label(k, float(item.implicit[k]) * um), Color(0.8, 0.8, 0.85)])
	for a in item.get("affixes", []):
		var t = stat_label(a.stat, float(a.value) * um)
		if a.get("greater", false):
			t = "✦ " + t
		lines.append([t, Color(0.55, 0.75, 1.0) if not a.get("greater", false) else Color(1.0, 0.8, 0.35)])
	for g in item.get("sockets", []):
		lines.append(["◇ Empty socket" if g == "" else "◆ " + Content.get_rec("materials", g).get("name", g), Color(0.7, 0.7, 0.7)])
	if item.has("power"):
		var p = Content.get_rec("powers", item.power)
		lines.append([p.get("desc", ""), Color(1.0, 0.6, 0.2)])
	if item.has("unique") or item.has("named"):
		var rec = Content.get_rec("uniques" if item.has("unique") else "named", item.get("unique", item.get("named", "")))
		if rec.has("flavor"):
			lines.append(["\"%s\"" % rec.flavor, Color(0.75, 0.65, 0.5)])
	lines.append(["Item level %d  ·  Requires level %d" % [item.ilvl, item.level_req], Color(0.6, 0.6, 0.6)])
	if int(item.get("kindle_max", 0)) > 0:
		lines.append(["Kindle %d/%d" % [item.kindle, item.kindle_max], Color(1.0, 0.75, 0.4)])
	return lines
