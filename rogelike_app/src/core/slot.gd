class_name Slot
extends RefCounted
## En plats på brädet. Slot-typen avgör vad tärningen i den gör
## (PROPOSAL §3, regel 3). Slots byts via reliker mellan strider.

enum Type {
	VOID, ## Tomrum: sidans ögon räknas inte som skada, de går rakt till Laddning.
	FIRE, ## Eld: rak skada mot aktuell fiende.
	MIRROR, ## Spegel: kopierar värdet från slotten till vänster.
	ANVIL, ## Amboss: +N platt bonus innan multiplikatorer.
	CHARGE, ## Ladda: allt här sparas till nästa runda istället för att slå.
}

var index: int = 0
var type: int = Type.FIRE
## Slot-specifik parameter. För ANVIL = platt bonus, för övriga oanvänd (0).
var power: int = 0
## Tärningens id som ligger här, eller "" om tom. Sätts av placeringssteget.
var die_id: String = ""


func _init(p_index: int = 0, p_type: int = Type.FIRE, p_power: int = 0) -> void:
	index = p_index
	type = p_type
	power = p_power


func is_empty() -> bool:
	return die_id == ""


static func type_name(t: int) -> String:
	match t:
		Type.VOID:
			return "VOID"
		Type.FIRE:
			return "FIRE"
		Type.MIRROR:
			return "MIRROR"
		Type.ANVIL:
			return "ANVIL"
		Type.CHARGE:
			return "CHARGE"
	return "UNKNOWN"


func to_dict() -> Dictionary:
	return {
		"index": index,
		"type": int(type),
		"power": power,
		"die_id": die_id,
	}


static func from_dict(data: Dictionary) -> Slot:
	var slot: Slot = Slot.new(
		int(data.get("index", 0)),
		int(data.get("type", Type.FIRE)),
		int(data.get("power", 0)),
	)
	slot.die_id = String(data.get("die_id", ""))
	return slot
