class_name Merchants
extends RefCounted
## Town merchants (GDD v2.3 #28, basic supplies only) and the Curio Cart (#29).
## `vendors`: {id, name, npc, stock:[{kind: "item_base"|"material"|"consumable", id, price_gold, count}]}
## Consumables: potion (+1 ch.potions), wick_charge (skip one hearth cooldown), pet_treat (+pet XP),
##   mount_feed (faster mount for a while). config/merchants {max_potions}.
## `curio_offers`: {id, name, category{slot|type}, price_hushmarks, min_level}. Curio items are rolled
## through Loot.roll_item — the SAME rarity weights, magic find, tier bonus, item level and pity as a
## monster drop. The result is decided instantly (welfare: no reels, no near-miss, no timers).

const CONSUMABLES := ["potion", "wick_charge", "pet_treat", "mount_feed"]

static func vendor(id: String) -> Dictionary:
	return Content.get_rec("vendors", id)

static func stock(vendor_id: String) -> Array:
	return vendor(vendor_id).get("stock", [])

static func _entry(vendor_id: String, entry) -> Dictionary:
	var s = stock(vendor_id)
	if entry is int or (entry is float):
		var i = int(entry)
		return s[i] if i >= 0 and i < s.size() else {}
	for e in s:
		if str(e.get("id", "")) == str(entry):
			return e
	return {}

## Buy one stock entry (by index or id). Returns {ok, message, item}.
static func buy(ch: CharacterData, vendor_id: String, entry) -> Dictionary:
	var e = _entry(vendor_id, entry)
	if e.is_empty():
		return {"ok": false, "message": "Not for sale"}
	var price = int(e.get("price_gold", 0))
	if ch.gold < price:
		return {"ok": false, "message": "Not enough gold"}
	var kind = str(e.get("kind", "consumable"))
	var id = str(e.get("id", ""))
	var n = max(1, int(e.get("count", 1)))
	var out = {"ok": true, "message": "", "item": {}}
	match kind:
		"item_base":
			var il = ch.level if str(e.get("ilvl", "")) == "player_level" else max(1, min(ch.level, int(Content.get_rec("item_bases", id).get("min_ilvl", 1)) + 2))
			var it = Items.generate(il, str(e.get("rarity", "common")), "", id, "", "craft")
			if it.is_empty():
				return {"ok": false, "message": "Not for sale"}
			if ch.first_free_slot() < 0:
				return {"ok": false, "message": "Bag full"}
			ch.add_item(it)
			out.item = it
			out.message = "Bought %s" % it.name
		"material":
			if not Content.has_rec("materials", id):
				return {"ok": false, "message": "Not for sale"}
			ch.add_material(id, n)
			out.message = "Bought %d %s" % [n, Content.get_rec("materials", id).get("name", id)]
		_:
			var err = _use_consumable(ch, id, n)
			if err != "":
				return {"ok": false, "message": err}
			out.message = "Bought %s" % e.get("name", id.capitalize().replace("_", " "))
	ch.gold -= price
	Events.gold_changed.emit(ch.gold)
	Events.inventory_changed.emit()
	return out

## Consumables: `consumables` table {id, kind (potion|elixir|hearth|pet_treat|mount_feed|key), effect{}},
## or the built-in ids potion / wick_charge / pet_treat / mount_feed.
static func _use_consumable(ch: CharacterData, id: String, n: int) -> String:
	var c = Content.get_rec("consumables", id)
	if not c.is_empty():
		return use_consumable_rec(ch, c, n)
	match id:
		"potion":
			var mx = int(Content.cfg("merchants", "max_potions", 10))
			if ch.potions >= mx:
				return "Potion belt full"
			ch.potions = min(mx, ch.potions + n)
		"wick_charge":
			ch.wick_charges += n
		"pet_treat":
			if not Pets.feed_treat(ch):
				return "You have no companion"
		"mount_feed":
			if ch.active_mount == "":
				return "You have no mount"
			Mounts.feed(ch)
		_:
			return "Not for sale"
	return ""

static func use_consumable_rec(ch: CharacterData, c: Dictionary, n := 1) -> String:
	var e: Dictionary = c.get("effect", {})
	match str(c.get("kind", "")):
		"potion":
			var mx = int(c.get("stack_max", Content.cfg("merchants", "max_potions", 10)))
			if ch.potions >= mx:
				return "Potion belt full"
			ch.potions = min(mx, ch.potions + n)
			# Keep the strongest potion kind known for use_potion()
			var cur = Content.get_rec("consumables", ch.potion_kind)
			if float(e.get("heal_pct", 0.0)) >= float(cur.get("effect", {}).get("heal_pct", 0.0)):
				ch.potion_kind = str(c.id)
		"elixir":
			ch.buffs["elixir:" + str(c.id)] = {"stats": e.get("stats", {}), "until": ch.play_seconds + float(e.get("duration_s", 1800.0)) * n}
			ch.recalc()
		"hearth":
			ch.wick_charges += n
		"pet_treat":
			if not Pets.feed_treat(ch, int(e.get("pet_xp", -1)) * n):
				return "You have no companion"
		"mount_feed":
			if ch.active_mount == "":
				return "You have no mount"
			ch.mount_fed_until = max(ch.play_seconds, float(ch.mount_fed_until)) + float(e.get("duration_s", 600.0)) * n
		"key":
			ch.add_material(str(c.id), n)
		_:
			return "Not for sale"
	return ""

static func sell(ch: CharacterData, inventory_index: int) -> int:
	var v = InventoryOps.sell(ch, inventory_index)
	if v > 0:
		Events.gold_changed.emit(ch.gold)
		Events.inventory_changed.emit()
	return v

# ------------------------------------------------------------------ Curio Cart
static func curio_offers(ch: CharacterData = null) -> Array:
	var out = []
	for o in Content.all("curio_offers"):
		if ch == null or ch.level >= int(o.get("min_level", 1)):
			out.append(o)
	return out

static func curio_currency() -> String:
	return str(Content.cfg("merchants", "curio_currency", "hushmark"))

static func curio_buy(ch: CharacterData, offer_id: String) -> Dictionary:
	var o = Content.get_rec("curio_offers", offer_id)
	if o.is_empty():
		return {"ok": false, "message": "Unknown offer", "item": {}}
	if ch.level < int(o.get("min_level", 1)):
		return {"ok": false, "message": "Requires level %d" % int(o.min_level), "item": {}}
	var price = int(o.get("price_hushmarks", 1))
	var cur = curio_currency()
	if int(ch.materials.get(cur, 0)) < price:
		return {"ok": false, "message": "Not enough Hushmarks", "item": {}}
	var cat: Dictionary = o.get("category", {})
	if cat.has("material"):
		return _curio_material(ch, o, price, cur)
	var slot = str(cat.get("slot", ""))
	var type_id = str(cat.get("weapon_type", cat.get("type", "")))
	if slot == "ring1" or slot == "ring2":
		slot = "ring"
	# Same path as a monster drop: rarity context + pity, ilvl = character level
	var it = Loot.roll_item(ch, Game.tier() if Game.character == ch else Content.get_rec("difficulties", ch.difficulty), ch.level, "normal", slot, type_id)
	if it.is_empty():
		return {"ok": false, "message": "The cart has nothing of that kind", "item": {}}
	ch.spend_materials({cur: price})
	var msg = "You got %s!" % it.name
	if not ch.add_item(it):
		ch.stash.append(it)
		msg += " (sent to your stash)"
	if Items.rarity_index(it.rarity) >= 4:
		Codex.record(it)
	ch.track("curio_bought")
	Events.inventory_changed.emit()
	return {"ok": true, "item": it, "message": msg}

## Material offers (e.g. {"material": "gem"}): a random material of that kind, grade ≤ level tier.
static func _curio_material(ch: CharacterData, o: Dictionary, price: int, cur: String) -> Dictionary:
	var kind = str(o.category.material)
	var max_tier = 1 + ch.level / 20
	var pool = Content.all("materials").filter(func(m): return (m.get(kind, false) == true or str(m.get("kind", "")) == kind) and int(m.get("tier", 1)) <= max_tier)
	if pool.is_empty():
		return {"ok": false, "message": "The cart has nothing of that kind", "item": {}}
	ch.spend_materials({cur: price})
	var m = pool[Rng.int_on("loot", 0, pool.size() - 1)]
	ch.add_material(m.id, 1)
	ch.track("curio_bought")
	return {"ok": true, "item": {}, "material": m.id, "message": "You got %s!" % m.get("name", m.id)}
