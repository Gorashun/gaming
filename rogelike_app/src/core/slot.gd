class_name Slot
extends RefCounted
## En plats på brädet. GAME_DESIGN.md §2.1 och §4.3.
## Slot-typens regel avgör vad tärningen i den gör. En blockerad slot behandlas
## EXAKT som en tom slot: inert, deltar inte i combos och bryter angränsning.

var index: int = 0
## En av [enum Rules.SlotType].
var type: int = Rules.SlotType.PLAIN
## Satt av fiendespecialen GRAB. Kan inte ta emot en tärning.
var blocked: bool = false


func _init(p_index: int = 0, p_type: int = Rules.SlotType.PLAIN, p_blocked: bool = false) -> void:
	index = p_index
	type = p_type
	blocked = p_blocked


func copy() -> Slot:
	return Slot.new(index, type, blocked)


func to_dict() -> Dictionary:
	return {"index": index, "type": type, "blocked": blocked}


static func from_dict(data: Dictionary) -> Slot:
	return Slot.new(
		int(data.get("index", 0)),
		int(data.get("type", Rules.SlotType.PLAIN)),
		bool(data.get("blocked", false)),
	)
