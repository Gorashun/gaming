class_name Board
extends RefCounted
## Brädet: de fem slotsen plus tillstånd som lever mellan rundor
## (Laddning från oanvända ögon).

const DEFAULT_SLOT_COUNT: int = 5

var slots: Array[Slot] = []
## Laddning som sparats från tidigare rundor och läggs på nästa kedja.
var charge: int = 0
## Rundräknare i den pågående striden. 0 = ingen runda resolvad ännu.
var round_index: int = 0


func _init(p_slots: Array[Slot] = []) -> void:
	slots = p_slots.duplicate()


## Standardbräde för vertical slice: Eld, Amboss, Eld, Spegel, Ladda.
static func default_board() -> Board:
	var slots: Array[Slot] = [
		Slot.new(0, Slot.Type.FIRE),
		Slot.new(1, Slot.Type.ANVIL, 2),
		Slot.new(2, Slot.Type.FIRE),
		Slot.new(3, Slot.Type.MIRROR),
		Slot.new(4, Slot.Type.CHARGE),
	]
	return Board.new(slots)


func size() -> int:
	return slots.size()


func slot_at(index: int) -> Slot:
	if index < 0 or index >= slots.size():
		return null
	return slots[index]


## Rensar tärningsplaceringen inför nästa runda. Laddning ligger kvar.
func clear_placement() -> void:
	for slot: Slot in slots:
		slot.die_id = ""


func to_dict() -> Dictionary:
	var slot_data: Array = []
	for slot: Slot in slots:
		slot_data.append(slot.to_dict())
	return {
		"slots": slot_data,
		"charge": charge,
		"round_index": round_index,
	}


static func from_dict(data: Dictionary) -> Board:
	var slots: Array[Slot] = []
	for entry: Variant in data.get("slots", []) as Array:
		slots.append(Slot.from_dict(entry as Dictionary))
	var board: Board = Board.new(slots)
	board.charge = int(data.get("charge", 0))
	board.round_index = int(data.get("round_index", 0))
	return board
