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

static func can_craft(ch: CharacterData, recipe: Dictionary, item) -> String:
	if prof_level(ch, recipe.profession) < int(recipe.get("level", 1)):
		return "Requires %s level %d" % [Content.get_rec("professions", recipe.profession).get("name", ""), recipe.level]
	if not ch.has_materials(recipe.get("cost", {})):
		return "Missing materials"
	if ch.gold < int(recipe.get("gold", 0)):
		return "Not enough gold"
	match recipe.kind:
		"kindle_upgrade", "kindle_reroll", "kindle_add":
			if item == null:
				return "Choose an item"
			if int(item.get("kindle", 0)) < kindle_cost_range(ch, recipe).x:
				return "Not enough Kindle left"
			if item.affixes.is_empty() and recipe.kind != "kindle_add":
				return "Item has no affixes"
			if recipe.kind == "kindle_add" and not (item.rarity in ["magic", "rare", "epic"]):
				return "Only Magic, Rare or Epic"
			if recipe.kind == "kindle_add" and item.affixes.size() >= int(Content.get_rec("rarities", item.rarity).get("affix_max", 0)) + 1:
				return "Affix slots full"
		"add_socket":
			if item == null:
				return "Choose an item"
			if not (item.slot in ["main_hand", "chest", "off_hand"]) or item.sockets.size() >= 3:
				return "Cannot add a socket"
	return ""

## Performs the craft. affix_index is used by upgrade/reroll. Returns {ok, message, item}.
static func craft(ch: CharacterData, recipe: Dictionary, item, affix_index := 0) -> Dictionary:
	var err = can_craft(ch, recipe, item)
	if err != "":
		return {"ok": false, "message": err}
	ch.spend_materials(recipe.get("cost", {}))
	ch.gold -= int(recipe.get("gold", 0))
	var msg = ""
	var result = item
	match recipe.kind:
		"kindle_upgrade", "kindle_reroll", "kindle_add":
			var r = kindle_cost_range(ch, recipe)
			var cost = Rng.int_on("craft", r.x, r.y)
			item.kindle = max(0, int(item.kindle) - cost)
			if recipe.kind == "kindle_upgrade":
				var a: Dictionary = item.affixes[clampi(affix_index, 0, item.affixes.size() - 1)]
				var gain = absf(float(a.value)) * Rng.range_on("craft", 0.08, 0.2) + 1.0
				a.value = snappedf(float(a.value) + gain, 0.1) if float(a.value) < 10 else round(float(a.value) + gain)
				msg = "Empowered! (-%d Kindle)" % cost
			elif recipe.kind == "kindle_reroll":
				var idx = clampi(affix_index, 0, item.affixes.size() - 1)
				item.affixes.remove_at(idx)
				var pool = Items.affix_pool(item)
				if pool.size() > 0:
					item.affixes.insert(idx, Items.roll_affix(Rng.weighted("craft", pool), int(item.ilvl), false, "craft"))
				msg = "Reforged! (-%d Kindle)" % cost
			else:
				var pool = Items.affix_pool(item)
				if pool.size() > 0:
					item.affixes.append(Items.roll_affix(Rng.weighted("craft", pool), int(item.ilvl), false, "craft"))
				msg = "Imbued! (-%d Kindle)" % cost
		"add_socket":
			item.sockets.append("")
			msg = "Socket added!"
		"forge":
			result = Items.generate(ch.level, recipe.rarity, ch.class_id, "", "", "craft")
			if not ch.add_item(result):
				ch.stash.append(result)
			msg = "Forged %s!" % result.name
		"forge_unique":
			result = Items.from_unique(recipe.unique, ch.level, "craft")
			if not ch.add_item(result):
				ch.stash.append(result)
			msg = "Forged %s!" % result.name
	gain_xp(ch, recipe.profession, int(recipe.get("xp", 10)))
	ch.track("crafts")
	ch.recalc()
	Events.craft_completed.emit({"recipe": recipe.id, "item": result})
	return {"ok": true, "message": msg, "item": result}
