class_name Chest
extends RefCounted
## Kistan. PROGRESSION_REDESIGN §3.4 och §4.1.
##
## [b]Kistan räddar N föremål vid död[/b], där N = byggnadens nivå (0 → 1 → 2 →
## 3). Spelaren väljer vilka bland det burna; Marrow presenterar valet. Det som
## räddats ligger kvar här tills en hjälte i staden tar på sig det.
##
## Nivå 0 räddar ingenting – det är avsiktligt och uttalat (§5 run 1: "du
## förlorar allt om du dör"). [code]MARROWS_TARP[/code] och den frivilliga
## räddningsannonsen lägger till platser ovanpå nivån.

const MAX_LEVEL: int = 3

## Räddade föremål, säkrade, i staden.
var items: Array[Item] = []


## Hur många föremål Kistan räddar på [param level].
static func rescue_capacity(level: int) -> int:
	return clampi(level, 0, MAX_LEVEL)


## Lägger räddade föremål i Kistan. De är säkrade från och med nu.
func store(rescued: Array) -> void:
	for raw: Variant in rescued:
		if raw is Item:
			var item: Item = (raw as Item).copy()
			item.secured = true
			items.append(item)


## Tar ut föremålet på [param index], eller null.
func take(index: int) -> Item:
	if index < 0 or index >= items.size():
		return null
	var item: Item = items[index]
	items.remove_at(index)
	return item


func to_dict() -> Dictionary:
	return {"items": Item.list_to_dicts(items)}


static func from_dict(data: Dictionary) -> Chest:
	var chest: Chest = Chest.new()
	chest.items = Item.list_from_dicts(data.get("items", []))
	for item: Item in chest.items:
		item.secured = true
	return chest
