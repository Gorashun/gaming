class_name InventoryOps
extends RefCounted
## Pure inventory/equipment operations on a CharacterData.

const TWO_HANDED := ["axe2h", "staff"]   # legacy; use Weapons.is_two_handed()
const SALVAGE := {"common": {"soot": [1, 2]}, "magic": {"soot": [2, 4]}, "rare": {"wickthread": [1, 2], "soot": [1, 3]},
	"epic": {"dusk_essence": [1, 2], "wickthread": [1, 2]}, "legendary": {"ember_heart": [1, 1], "dusk_essence": [1, 2]},
	"mythic": {"ember_heart": [2, 3]}, "unique": {"dusk_essence": [2, 3]}, "named": {"ember_heart": [3, 4]}}

static func target_slot(ch: CharacterData, item: Dictionary) -> String:
	var s: String = item.slot
	if s == "ring":
		if ch.equipment.get("ring1") == null:
			return "ring1"
		if ch.equipment.get("ring2") == null:
			return "ring2"
		# replace the weaker ring
		return "ring1" if Items.score(ch.equipment.ring1, ch.class_id) <= Items.score(ch.equipment.ring2, ch.class_id) else "ring2"
	return s

## Any class can equip any weapon/armour (GDD v2.1 #19). `item_bases.classes` is only a smart-loot hint.
static func can_equip(ch: CharacterData, item: Dictionary) -> bool:
	if item.get("placeholder", false):
		return false
	return int(item.get("level_req", 1)) <= ch.level

static func equip_from_bag(ch: CharacterData, index: int) -> bool:
	var item = ch.inventory[index]
	if item == null or not can_equip(ch, item):
		return false
	var slot = target_slot(ch, item)
	var old = ch.equipment.get(slot)
	ch.inventory[index] = old
	ch.equipment[slot] = item
	if slot == "main_hand" and Weapons.is_two_handed(item) and ch.equipment.get("off_hand"):
		var off = ch.equipment.off_hand
		ch.equipment.erase("off_hand")
		if not ch.add_item(off):
			ch.stash.append(off)
	if slot == "off_hand":
		var mh = ch.equipment.get("main_hand")
		if mh and Weapons.is_two_handed(mh):
			ch.equipment.erase("main_hand")
			if not ch.add_item(mh):
				ch.stash.append(mh)
	ch.recalc()
	return true

static func unequip(ch: CharacterData, slot: String) -> bool:
	var it = ch.equipment.get(slot)
	if it == null:
		return false
	if not ch.add_item(it):
		return false
	ch.equipment.erase(slot)
	ch.recalc()
	return true

## Score difference vs what's equipped in the relevant slot (for green/red arrows).
static func upgrade_delta(ch: CharacterData, item: Dictionary) -> float:
	if not can_equip(ch, item):
		return 0.0
	var slot = target_slot(ch, item)
	var cur = ch.equipment.get(slot)
	var cs = Items.score(cur, ch.class_id) if cur else 0.0
	return Items.score(item, ch.class_id) - cs

static func salvage_yield(item: Dictionary, stream := "craft") -> Dictionary:
	var out = {}
	var tbl: Dictionary = SALVAGE.get(item.rarity, {})
	for m in tbl:
		out[m] = Rng.int_on(stream, int(tbl[m][0]), int(tbl[m][1]))
	for g in item.get("sockets", []):
		if g != "":
			out[g] = int(out.get(g, 0)) + 1
	return out

static func salvage(ch: CharacterData, index: int) -> Dictionary:
	var item = ch.inventory[index]
	if item == null or item.get("locked", false):
		return {}
	var y = salvage_yield(item)
	for m in y:
		ch.add_material(m, y[m])
	ch.inventory[index] = null
	ch.track("salvages")
	Crafting.gain_xp(ch, "smith", 2 + Items.rarity_index(item.rarity) * 3)
	return y

static func sell_value(item: Dictionary) -> int:
	return int((5 + int(item.ilvl) * 2) * pow(2.2, Items.rarity_index(item.rarity)) * (1.0 + 0.1 * int(item.get("upgrade", 0))))

static func sell(ch: CharacterData, index: int) -> int:
	var item = ch.inventory[index]
	if item == null or item.get("locked", false):
		return 0
	var v = sell_value(item)
	ch.gold += v
	ch.inventory[index] = null
	return v

static func best_gear(ch: CharacterData) -> int:
	var changes = 0
	var improved = true
	var guard = 0
	while improved and guard < 30:
		guard += 1
		improved = false
		for i in ch.inventory.size():
			var it = ch.inventory[i]
			if it and upgrade_delta(ch, it) > 1.0:
				if equip_from_bag(ch, i):
					changes += 1
					improved = true
	return changes

static func compact(ch: CharacterData) -> void:
	var items = ch.inventory.filter(func(x): return x != null)
	items.sort_custom(func(a, b): return Items.rarity_index(a.rarity) > Items.rarity_index(b.rarity))
	for i in ch.inventory.size():
		ch.inventory[i] = items[i] if i < items.size() else null
