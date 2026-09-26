class_name Crafting
extends RefCounted
## Profession XP + recipe execution. Kindle: every item has limited Kindle points; each craft spends
## a random amount within a shown range (outcome decided before any animation — welfare rule).

static func prof_xp_to_next(level: int) -> int:
	return int(40 * pow(1.12, level - 1))

static func gain_xp(ch: CharacterData, prof: String, amount: int) -> void:
	if not ch.professions.has(prof):
		ch.professions[prof] = {"level": 1, "xp": 0}
	var p: Dictionary = ch.professions[prof]
	p.xp = int(p.xp) + amount
	var maxl = int(Content.get_rec("professions", prof).get("max_level", 50))
	while int(p.level) < maxl and int(p.xp) >= prof_xp_to_next(int(p.level)):
		p.xp = int(p.xp) - prof_xp_to_next(int(p.level))
		p.level = int(p.level) + 1
		Events.profession_level_up.emit(prof, int(p.level))

static func prof_level(ch: CharacterData, prof: String) -> int:
	return int(ch.professions.get(prof, {"level": 1}).level)

## Kindle cost range shrinks with profession level (skill matters).
static func kindle_cost_range(ch: CharacterData, recipe: Dictionary) -> Vector2i:
	var lvl = prof_level(ch, recipe.profession)
	var base = {"kindle_upgrade": Vector2i(2, 6), "kindle_reroll": Vector2i(3, 7), "kindle_add": Vector2i(5, 10)}.get(recipe.kind, Vector2i(0, 0))
	var reduce = int(lvl / 10)
	return Vector2i(max(1, base.x - reduce), max(1, base.y - reduce))

const ITEM_KINDS := ["kindle_upgrade", "kindle_reroll", "kindle_add", "add_socket", "upgrade_item", "reroll_implicit",
	"unsocket", "reroll_values", "remove_affix", "seal_affix", "reroll_all", "imprint_power", "make_greater", "restore_kindle"]
const AFFIX_KINDS := ["kindle_upgrade", "kindle_reroll", "remove_affix", "seal_affix", "make_greater"]
const ARMOR_SLOTS := ["head", "chest", "hands", "legs", "feet", "belt", "off_hand"]
const JEWELRY_SLOTS := ["ring", "amulet", "charm"]

## "" when the recipe can be crafted. opts: {affix_index, slot, gem, to_gem, power}.
static func can_craft(ch: CharacterData, recipe: Dictionary, item, opts := {}) -> String:
	if prof_level(ch, recipe.profession) < int(recipe.get("level", 1)) and str(recipe.profession) != "cauldron":
		return "Requires %s level %d" % [Content.get_rec("professions", recipe.profession).get("name", ""), recipe.level]
	if not ch.has_materials(recipe.get("cost", {})):
		return "Missing materials"
	if ch.gold < int(recipe.get("gold", 0)):
		return "Not enough gold"
	var kind = str(recipe.kind)
	if ITEM_KINDS.has(kind):
		if item == null or not (item is Dictionary) or item.is_empty():
			return "Choose an item"
		if item.get("placeholder", false):
			return "This item can't be changed"
	if AFFIX_KINDS.has(kind) and (item.get("affixes", []).is_empty()):
		return "Item has no affixes"
	var ai = int(opts.get("affix_index", 0))
	match kind:
		"kindle_upgrade", "kindle_reroll", "kindle_add":
			if int(item.get("kindle", 0)) < kindle_cost_range(ch, recipe).x:
				return "Not enough Kindle left"
			if kind == "kindle_add" and not (item.rarity in ["magic", "rare", "epic"]):
				return "Only Magic, Rare or Epic"
			if kind == "kindle_add" and item.affixes.size() >= Items.max_affixes(item.rarity):
				return "Affix slots full"
			if kind == "kindle_reroll" and _affix(item, ai).get("sealed", false):
				return "That affix is sealed"
		"add_socket":
			if not (item.slot in ["main_hand", "chest", "off_hand"]) or item.sockets.size() >= 3:
				return "Cannot add a socket"
		"upgrade_item":
			return Upgrade.can_upgrade(ch, item)
		"reroll_implicit":
			if item.get("implicit", {}).is_empty():
				return "No base stats to reforge"
		"unsocket":
			if item.get("sockets", []).filter(func(g): return g != "").is_empty():
				return "No gem to remove"
		"remove_affix":
			if _affix(item, ai).get("sealed", false):
				return "That affix is sealed"
		"seal_affix":
			if item.affixes.any(func(a): return a.get("sealed", false)):
				return "Only one sealed affix per item"
		"make_greater":
			if item.get("greater_made", false):
				return "Already brightened once"
			if _affix(item, ai).get("greater", false):
				return "Already greater"
		"restore_kindle":
			if item.get("kindle_restored", false):
				return "Already rekindled once"
		"imprint_power":
			if Items.rarity_index(item.rarity) < Items.rarity_index("legendary") or item.has("unique") or item.has("named"):
				return "Only Legendary items"
			var pw = str(opts.get("power", ""))
			if pw == "" or not Codex.has("power:" + pw):
				return "Choose a power from your Codex"
			var prec = Content.get_rec("powers", pw)
			if not prec.get("slots", []).is_empty() and not prec.slots.has(item.slot):
				return "That power doesn't fit this item"
		"gem_convert":
			var g = Content.get_rec("materials", str(opts.get("gem", "")))
			var t = Content.get_rec("materials", str(opts.get("to_gem", "")))
			if g.is_empty() or t.is_empty() or not ch.has_materials({g.id: 1}):
				return "Choose a gem"
			if int(g.get("grade", 2)) != int(t.get("grade", 2)) or str(g.get("category", "gem")) != str(t.get("category", "gem")):
				return "Same grade only"
		"forge_named":
			if Content.get_rec("named", str(recipe.get("named", ""))).is_empty():
				return "Unknown recipe"
		"cauldron":
			if not ch.recipes_known.has(recipe.id) and not recipe.get("discovery", false):
				return "Unknown recipe"
	return ""

static func _affix(item: Dictionary, i: int) -> Dictionary:
	var a: Array = item.get("affixes", [])
	return a[clampi(i, 0, a.size() - 1)] if not a.is_empty() else {}

## Performs the craft. Outcome is decided here, before any UI animation (welfare).
## opts: {affix_index, slot (for "choose_*" forges), gem, to_gem, power}. Returns {ok, message, item}.
static func craft(ch: CharacterData, recipe: Dictionary, item, opts = {}) -> Dictionary:
	if not (opts is Dictionary):
		opts = {"affix_index": int(opts)}   # legacy: craft(ch, recipe, item, affix_index)
	var err = can_craft(ch, recipe, item, opts)
	if err != "":
		return {"ok": false, "message": err}
	var kind = str(recipe.kind)
	if kind == "upgrade_item":
		var ur = Upgrade.upgrade(ch, item)
		if ur.ok:
			gain_xp(ch, recipe.profession, int(recipe.get("xp", 8)))
			Events.craft_completed.emit({"recipe": recipe.id, "item": item})
		return ur
	ch.spend_materials(recipe.get("cost", {}))
	ch.gold -= int(recipe.get("gold", 0))
	var msg = ""
	var result = item
	var ai = int(opts.get("affix_index", 0))
	match kind:
		"kindle_upgrade", "kindle_reroll", "kindle_add":
			var r = kindle_cost_range(ch, recipe)
			var cost = Rng.int_on("craft", r.x, r.y)
			item.kindle = max(0, int(item.kindle) - cost)
			ch.track("kindle_spent", cost)
			if kind == "kindle_upgrade":
				var a: Dictionary = _affix(item, ai)
				var gain = absf(float(a.value)) * Rng.range_on("craft", 0.08, 0.2) + 1.0
				a.value = snappedf(float(a.value) + gain, 0.1) if float(a.value) < 10 else round(float(a.value) + gain)
				msg = "Empowered! (-%d Kindle)" % cost
			elif kind == "kindle_reroll":
				var idx = clampi(ai, 0, item.affixes.size() - 1)
				item.affixes.remove_at(idx)
				var pool = Items.affix_pool(item)
				if pool.size() > 0:
					item.affixes.insert(idx, Items.roll_affix(Rng.weighted("craft", Items.weighted_pool(pool, item)).a, int(item.ilvl), false, "craft"))
				msg = "Reforged! (-%d Kindle)" % cost
			else:
				var pool = Items.affix_pool(item)
				if pool.size() > 0:
					item.affixes.append(Items.roll_affix(Rng.weighted("craft", Items.weighted_pool(pool, item)).a, int(item.ilvl), false, "craft"))
				msg = "Imbued! (-%d Kindle)" % cost
		"add_socket":
			item.sockets.append("")
			msg = "Socket added!"
		"forge":
			var slot = str(recipe.get("slot", opts.get("slot", "")))
			if slot == "choose_armor":
				slot = str(opts.get("slot", ARMOR_SLOTS[Rng.int_on("craft", 0, ARMOR_SLOTS.size() - 1)]))
			elif slot == "choose_jewelry":
				slot = str(opts.get("slot", JEWELRY_SLOTS[Rng.int_on("craft", 0, JEWELRY_SLOTS.size() - 1)]))
			var type_id = ""
			if slot == "main_hand":
				type_id = _favoured_type(ch)
			result = Items.generate(ch.level, recipe.rarity, ch.class_id, "", slot if slot != "ring1" else "ring", "craft", type_id)
			if result.is_empty():
				result = Items.generate(ch.level, recipe.rarity, ch.class_id, "", slot, "craft")
			_store(ch, result)
			msg = "Forged %s!" % result.get("name", "")
		"forge_unique":
			result = Items.from_unique(recipe.unique, ch.level, "craft")
			_store(ch, result)
			msg = "Forged %s!" % result.name
		"forge_named":
			result = forge_named(str(recipe.named), ch.level)
			_store(ch, result)
			Codex.record(result)
			ch.track("named_forged")
			msg = "%s is born!" % result.name
		"brew", "transmute", "combine", "cauldron":
			for id in recipe.get("output", {}):
				var n = int(recipe.output[id])
				var c = Content.get_rec("consumables", id)
				if not c.is_empty():
					Merchants.use_consumable_rec(ch, c, n)
				else:
					ch.add_material(id, n)
			if kind == "cauldron" and not ch.recipes_known.has(recipe.id):
				ch.recipes_known.append(recipe.id)
				ch.discoveries.append(recipe.id)
				ch.track("cauldron_discoveries")
			msg = "Made %s!" % ", ".join(recipe.get("output", {}).keys().map(func(k): return str(Content.get_rec("materials", k).get("name", Content.get_rec("consumables", k).get("name", k)))))
		"reroll_implicit":
			var base = Content.get_rec("item_bases", item.base)
			for stat in base.get("implicit", {}):
				var rv: Array = base.implicit[stat]
				item.implicit[stat] = snappedf(Rng.range_on("craft", rv[0], rv[1]), 0.1)
			msg = "Base stats reforged!"
		"unsocket":
			for i in item.sockets.size():
				if item.sockets[i] != "":
					ch.add_material(item.sockets[i], 1)
					msg = "%s returned" % Content.get_rec("materials", item.sockets[i]).get("name", item.sockets[i])
					item.sockets[i] = ""
					break
		"reroll_values", "reroll_all":
			for i in item.affixes.size():
				var a: Dictionary = item.affixes[i]
				if a.get("sealed", false) or str(a.get("id", "")).begins_with("u_"):
					continue
				if kind == "reroll_values":
					var rec = Content.get_rec("affixes", a.id)
					if not rec.is_empty():
						var na = Items.roll_affix(rec, int(item.ilvl), a.get("greater", false), "craft")
						a.value = na.value
				else:
					var pool = Items.affix_pool({"affixes": item.affixes.filter(func(x): return x != a), "slot": item.slot, "type": item.get("type", ""), "ilvl": item.ilvl, "class_hint": item.get("class_hint", "")})
					if pool.size() > 0:
						item.affixes[i] = Items.roll_affix(Rng.weighted("craft", Items.weighted_pool(pool, item)).a, int(item.ilvl), a.get("greater", false), "craft")
			msg = "The runes shift!"
		"remove_affix":
			item.affixes.remove_at(clampi(ai, 0, item.affixes.size() - 1))
			msg = "Affix unravelled."
		"seal_affix":
			_affix(item, ai)["sealed"] = true
			msg = "Affix sealed."
		"make_greater":
			var a: Dictionary = _affix(item, ai)
			a.greater = true
			a.value = round(float(a.value) * 1.5) if absf(float(a.value)) >= 10 else snappedf(float(a.value) * 1.5, 0.1)
			item.greater_made = true
			msg = "✦ Brightened!"
		"restore_kindle":
			item.kindle = min(int(item.kindle_max), int(item.kindle) + int(recipe.get("amount", 5)))
			item.kindle_restored = true
			msg = "Kindle restored."
		"imprint_power":
			item.power = str(opts.power)
			msg = "Power imprinted: %s" % Content.get_rec("powers", item.power).get("name", item.power)
		"gem_convert":
			ch.spend_materials({str(opts.gem): 1})
			ch.add_material(str(opts.to_gem), 1)
			msg = "Recut into %s" % Content.get_rec("materials", str(opts.to_gem)).get("name", opts.to_gem)
	gain_xp(ch, recipe.profession, int(recipe.get("xp", 10)))
	ch.track("crafts")
	ch.recalc()
	Events.craft_completed.emit({"recipe": recipe.id, "item": result})
	return {"ok": true, "message": msg, "item": result}

static func _store(ch: CharacterData, it: Dictionary) -> void:
	if it.is_empty():
		return
	if not ch.add_item(it):
		ch.stash.append(it)

## The class's best-affinity weapon type (for "weapon of your favoured type" forges).
static func _favoured_type(ch: CharacterData) -> String:
	var best = ""
	var bv = -1.0
	var aff: Dictionary = ch.cls().get("affinities", {})
	for t in aff:
		var v = float(aff[t].get("damage_pct", 0.0))
		if v > bv and Content.all("item_bases").any(func(b): return str(b.get("type", "")) == t and int(b.get("min_ilvl", 1)) <= ch.level):
			bv = v
			best = t
	return best

## Named items: fixed identity from the `named` table (like uniques).
static func forge_named(named_id: String, ilvl: int) -> Dictionary:
	var n = Content.get_rec("named", named_id)
	if n.is_empty():
		return {}
	var item = Items.generate(ilvl, "common", "", str(n.base), "", "craft")
	if item.is_empty():
		return {}
	item.rarity = str(n.get("rarity", "named"))
	item.name = str(n.name)
	item.named = named_id
	item.affixes = []
	for fx in n.get("stats", []):
		var v = Rng.range_on("craft", float(fx.min), float(fx.max))
		item.affixes.append({"id": "u_" + fx.stat, "stat": fx.stat, "value": round(v) if float(fx.max) > 5 else snappedf(v, 0.1), "tier": 1, "tiers": 1, "greater": false, "group": fx.stat})
	if n.has("power"):
		item.power = n.power
	item.kindle_max = int(Content.get_rec("rarities", item.rarity).get("kindle", 10))
	item.kindle = item.kindle_max
	return item
