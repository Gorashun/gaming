class_name Relic
extends RefCounted
## En relik: passiv modifierare som resolvern läser. Reliker ändrar ALDRIG
## slumpen i efterhand – de ändrar siffror, och kedjan visas före bekräftelse.

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	LEGENDARY,
}

var id: String = ""
var display_name: String = ""
var description: String = ""
var rarity: int = Rarity.COMMON
## Nyckel→värde som resolvern slår upp, t.ex. {"flat_damage": 1, "combo_mult": 1.5}.
var effects: Dictionary = {}


func _init(p_id: String = "", p_rarity: int = Rarity.COMMON, p_effects: Dictionary = {}, p_name: String = "") -> void:
	id = p_id
	rarity = p_rarity
	effects = p_effects.duplicate(true)
	display_name = p_name if p_name != "" else p_id


func effect(key: String, fallback: Variant = 0) -> Variant:
	return effects.get(key, fallback)


## Summerar en numerisk effekt över en lista reliker. Ordningen spelar ingen roll
## för summor, vilket håller resolvern oberoende av relikernas sorteringsordning.
static func sum_effect(relics: Array, key: String) -> float:
	var total: float = 0.0
	for relic: Variant in relics:
		if relic is Relic:
			total += float((relic as Relic).effect(key, 0))
	return total


static func rarity_name(r: int) -> String:
	match r:
		Rarity.COMMON:
			return "COMMON"
		Rarity.UNCOMMON:
			return "UNCOMMON"
		Rarity.RARE:
			return "RARE"
		Rarity.LEGENDARY:
			return "LEGENDARY"
	return "UNKNOWN"


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"description": description,
		"rarity": int(rarity),
		"effects": effects.duplicate(true),
	}


static func from_dict(data: Dictionary) -> Relic:
	var relic: Relic = Relic.new(
		String(data.get("id", "")),
		int(data.get("rarity", Rarity.COMMON)),
		data.get("effects", {}) as Dictionary,
		String(data.get("display_name", "")),
	)
	relic.description = String(data.get("description", ""))
	return relic
