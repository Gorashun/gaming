class_name Forge
extends RefCounted
## Smedjan i staden. TOWN_AND_ONBOARDING §A.2 och DECISIONS 2026-09-21.
##
## [b]Två operationer, och bara två:[/b]
## [br]1. [method swap_faces] – byt plats på två sidor på en startärning.
## [br]2. [method reorder_slots] – ordna om brädets slot-typer inbördes.
##
## [b]Aldrig tillägg.[/b] Smedjan får inte lägga till kraft, och det är inte
## fromhet: kan man välja startsidor fritt väljer alla samma tre efter tjugo
## runs, och run-till-run-variationen kollapsar (§A.2). Att ordna om slot-typer
## är däremot en enorm spelstilsknapp utan en enda extra siffra –
## [code][MIRROR, PLAIN, PLAIN, ANVIL, PLAIN][/code] spelar helt annorlunda än
## standardbrädet, för Spegeln på slot 0 fizzlar (GAME_DESIGN §2.3).
##
## Invarianten som gör det sant är testbar och testas: [b]multimängden av sidor
## respektive slot-typer är oförändrad[/b] efter varje operation.

## Smedjans laddning som ren data, sparad i [member Meta.loadout]:
## [codeblock]
## {"face_swaps": [[die_index, face_a, face_b], …], "slot_order": [2,0,1,3,4]}
## [/codeblock]
const KEY_FACE_SWAPS: String = "face_swaps"
const KEY_SLOT_ORDER: String = "slot_order"


## Byter plats på två sidor. Returnerar en [b]ny[/b] tärning; indata muteras
## aldrig, av samma skäl som [method Resolver.resolve] inte gör det.
## Ogiltiga index ger en oförändrad kopia.
static func swap_faces(die: Die, a: int, b: int) -> Die:
	var result: Die = die.deep_copy()
	if a == b or a < 0 or b < 0 or a >= result.faces.size() or b >= result.faces.size():
		return result
	var keep: Face = result.faces[a]
	result.faces[a] = result.faces[b]
	result.faces[b] = keep
	return result


## Ordnar om brädet. [param order] är en [b]permutation[/b]: den nya sloten
## [code]i[/code] får typen från gamla sloten [code]order[i][/code]. Är
## [param order] inte en permutation returneras brädet oförändrat – smedjan får
## aldrig kunna duplicera en AMBOSS genom en trasig sparfil.
static func reorder_slots(board: Board, order: PackedInt32Array) -> Board:
	var result: Board = board.copy()
	if not is_permutation(order, board.size()):
		return result
	var types: Array[int] = []
	for slot: Slot in board.slots:
		types.append(slot.type)
	for i: int in range(result.size()):
		result.slots[i].type = types[order[i]]
		result.slots[i].index = i
	return result


## Sant när [param order] är exakt talen 0..size-1, var och en en gång.
static func is_permutation(order: PackedInt32Array, size: int) -> bool:
	if order.size() != size:
		return false
	var seen: Dictionary = {}
	for value: int in order:
		if value < 0 or value >= size or seen.has(value):
			return false
		seen[value] = true
	return true


## Ordningen som inte ändrar något. Smedjans utgångsläge.
static func identity_order(size: int) -> PackedInt32Array:
	var order: PackedInt32Array = PackedInt32Array()
	order.resize(size)
	for i: int in range(size):
		order[i] = i
	return order


## Flyttar sloten på [param from_index] till [param to_index] och skjuter
## resten ett steg. Det är gesten "dra en slot i sidled" uttryckt som data, och
## den är per definition en permutation.
static func move(order: PackedInt32Array, from_index: int, to_index: int) -> PackedInt32Array:
	var result: Array[int] = []
	for value: int in order:
		result.append(value)
	if from_index < 0 or from_index >= result.size():
		return order.duplicate()
	var moved: int = result[from_index]
	result.remove_at(from_index)
	result.insert(clampi(to_index, 0, result.size()), moved)
	return PackedInt32Array(result)


## Lägger smedjans laddning på ett färskt [CombatState] inför nästa run.
## Returnerar en kopia; en ogiltig laddning ger ett oförändrat tillstånd.
static func apply_loadout(state: CombatState, loadout: Dictionary) -> CombatState:
	var result: CombatState = state.copy()
	for entry: Variant in loadout.get(KEY_FACE_SWAPS, []) as Array:
		var swap: Array = entry as Array
		if swap.size() < 3:
			continue
		var die_index: int = int(swap[0])
		if die_index < 0 or die_index >= result.dice.size():
			continue
		result.dice[die_index] = swap_faces(result.dice[die_index], int(swap[1]), int(swap[2]))
	var raw_order: Array = loadout.get(KEY_SLOT_ORDER, []) as Array
	if not raw_order.is_empty():
		var order: PackedInt32Array = PackedInt32Array()
		for value: Variant in raw_order:
			order.append(int(value))
		result.board = reorder_slots(result.board, order)
	return result


## Sidornas värden i sorterad ordning – multimängden som [b]aldrig[/b] får
## ändras av smedjan. Används av testet och av en framtida validering av en
## sparfil som kommer utifrån.
static func face_signature(die: Die) -> PackedInt32Array:
	var values: Array[int] = []
	for face: Face in die.faces:
		values.append(face.value)
	values.sort()
	return PackedInt32Array(values)


static func slot_signature(board: Board) -> PackedInt32Array:
	var types: Array[int] = []
	for slot: Slot in board.slots:
		types.append(slot.type)
	types.sort()
	return PackedInt32Array(types)
