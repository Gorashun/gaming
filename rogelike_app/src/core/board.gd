class_name Board
extends RefCounted
## Brädet: exakt [constant Rules.SLOT_COUNT] slots där slots[i].index == i.

var slots: Array[Slot] = []


func _init(p_slots: Array[Slot] = []) -> void:
	slots = p_slots.duplicate()


## Bygger ett bräde ur en lista slot-typer, t.ex.
## [code]Board.from_types([Rules.SlotType.PLAIN, ...])[/code].
static func from_types(types: Array) -> Board:
	var slots: Array[Slot] = []
	for i: int in range(types.size()):
		slots.append(Slot.new(i, int(types[i])))
	return Board.new(slots)


## Smedens startbräde (GAME_DESIGN §4.1): PLAIN, PLAIN, MIRROR, FIRE, ANVIL.
static func smith_board() -> Board:
	return Board.from_types([
		Rules.SlotType.PLAIN,
		Rules.SlotType.PLAIN,
		Rules.SlotType.MIRROR,
		Rules.SlotType.FIRE,
		Rules.SlotType.ANVIL,
	])


func size() -> int:
	return slots.size()


func slot_at(index: int) -> Slot:
	if index < 0 or index >= slots.size():
		return null
	return slots[index]


func copy() -> Board:
	var copied: Array[Slot] = []
	for slot: Slot in slots:
		copied.append(slot.copy())
	return Board.new(copied)


func to_dict() -> Dictionary:
	var slot_data: Array = []
	for slot: Slot in slots:
		slot_data.append(slot.to_dict())
	return {"slots": slot_data}


static func from_dict(data: Dictionary) -> Board:
	var slots: Array[Slot] = []
	for entry: Variant in data.get("slots", []) as Array:
		slots.append(Slot.from_dict(entry as Dictionary))
	return Board.new(slots)
