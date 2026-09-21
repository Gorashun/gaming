class_name Relic
extends RefCounted
## En relik. GAME_DESIGN.md §2.1 och §4.6.
## Reliker är rena modifierare som resolvern slår upp på id. De tillför ALDRIG
## slump till en runda som redan bekräftats (GAME_DESIGN §6).

var id: String = ""
## En av [enum Rules.Rarity].
var rarity: int = Rules.Rarity.COMMON
var display_name: String = ""
var description: String = ""


func _init(p_id: String = "", p_rarity: int = Rules.Rarity.COMMON, p_name: String = "") -> void:
	id = p_id
	rarity = p_rarity
	display_name = p_name if p_name != "" else p_id


## Sant om [param relics] innehåller en relik med [param id].
static func has_relic(relics: Array, id: String) -> bool:
	for relic: Variant in relics:
		if relic is Relic and (relic as Relic).id == id:
			return true
	return false


func copy() -> Relic:
	var other: Relic = Relic.new(id, rarity, display_name)
	other.description = description
	return other


func to_dict() -> Dictionary:
	return {
		"id": id,
		"rarity": rarity,
		"display_name": display_name,
		"description": description,
	}


static func from_dict(data: Dictionary) -> Relic:
	var relic: Relic = Relic.new(
		String(data.get("id", "")),
		int(data.get("rarity", Rules.Rarity.COMMON)),
		String(data.get("display_name", "")),
	)
	relic.description = String(data.get("description", ""))
	return relic
