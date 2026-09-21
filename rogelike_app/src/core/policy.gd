class_name Policy
extends RefCounted
## Scriptade spelarpolicyer för run-simulatorn (GAME_DESIGN §5).
##
## Två policyer krävs och skillnaden mellan dem är projektets viktigaste
## balansmått: om [method greedy] vinner lika ofta som [method lookahead] är
## placeringen meningslös och vi har byggt Luck be a Landlord. Stoppregel.
##
## Båda är rena funktioner av tillståndet: ingen RNG, inga sidoeffekter.

## Vikter för lookahead-poängen: skada + 0.5 × bankad Charge + 1.0 × Ward.
const CHARGE_WEIGHT: float = 0.5
const WARD_WEIGHT: float = 1.0
## Hur många fulla permutationer som provas per runda som standard.
const DEFAULT_WIDTH: int = 8


## GOLVET. Slänger de fem högsta tärningarna i slot 0–4, störst först.
## Ignorerar slot-typer, combos, Charge och Ward helt.
static func greedy(state: CombatState) -> PackedInt32Array:
	var slot_count: int = state.board.size()
	var order: Array[int] = _dice_by_value_desc(state)
	var placement: PackedInt32Array = CombatState.empty_placement(slot_count)
	var next: int = 0
	for i: int in range(slot_count):
		if state.board.slots[i].blocked:
			continue
		if next >= order.size():
			break
		placement[i] = order[next]
		next += 1
	return placement


## TAKET. Provar ett begränsat antal placeringar med [method Resolver.resolve]
## och väljer den med högst skada + 0.5 × Charge + 1.0 × Ward. Provar även
## placeringar med tomma slots, eftersom att banka Charge ibland är rätt drag.
static func lookahead(state: CombatState, width: int = DEFAULT_WIDTH) -> PackedInt32Array:
	var best: PackedInt32Array = greedy(state)
	var best_score: float = -1.0
	for candidate: PackedInt32Array in candidates(state, width):
		var score: float = evaluate(state, candidate)
		if score > best_score:
			best_score = score
			best = candidate
	return best


## Poängen för en placering. Exponerad så att balanstester kan använda den.
static func evaluate(state: CombatState, placement: PackedInt32Array) -> float:
	var result: ResolveResult = Resolver.resolve(state, placement)
	var damage: int = 0
	for event: Dictionary in result.events:
		var t: String = String(event.get("t", ""))
		if t == "damage_dealt" or t == "status_ticked":
			damage += int(event.get("amount", 0))
	var ward: int = 0
	for event: Dictionary in result.events_of("ward_gained"):
		ward = maxi(ward, int(event.get("ward_total", 0)))
	var charge_gain: int = result.state_after.charge - state.charge
	var score: float = float(damage) + CHARGE_WEIGHT * float(charge_gain) + WARD_WEIGHT * float(ward)
	# Att dö är alltid sämst, oavsett hur mycket skada draget gjorde.
	if result.state_after.player_dead:
		return -1000.0
	return score


## Den begränsade kandidatmängden: [param width] jämnt fördelade permutationer
## av "välj [code]slot_count[/code] tärningar av [code]dice.size()[/code]",
## plus varianter där en slot lämnas tom.
static func candidates(state: CombatState, width: int = DEFAULT_WIDTH) -> Array[PackedInt32Array]:
	var slot_count: int = state.board.size()
	var available: Array[int] = []
	for i: int in range(state.dice.size()):
		if not state.stolen.has(state.dice[i].id):
			available.append(i)

	var total: int = _permutation_count(available.size(), slot_count)
	var result: Array[PackedInt32Array] = []
	if total <= 0:
		result.append(CombatState.empty_placement(slot_count))
		return result

	var samples: int = mini(width, total)
	var stride: int = maxi(1, total / samples)
	for s: int in range(samples):
		var placement: PackedInt32Array = _nth_placement(available, slot_count, (s * stride) % total)
		_unblock(state, placement)
		result.append(placement)
		# Varianter som bankar Charge i stället för att slå med allt.
		if s % 8 == 0:
			for empty_slot: int in range(slot_count):
				var variant: PackedInt32Array = placement.duplicate()
				variant[empty_slot] = -1
				result.append(variant)
	result.append(CombatState.empty_placement(slot_count))
	return result


## Nollar de slots som är blockerade: en blockerad slot kan inte ta emot en tärning.
static func _unblock(state: CombatState, placement: PackedInt32Array) -> void:
	for i: int in range(placement.size()):
		if state.board.slots[i].blocked:
			placement[i] = -1


static func _dice_by_value_desc(state: CombatState) -> Array[int]:
	var order: Array[int] = []
	for i: int in range(state.dice.size()):
		if not state.stolen.has(state.dice[i].id):
			order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var va: int = state.dice[a].showing_face().value
		var vb: int = state.dice[b].showing_face().value
		if va == vb:
			return a < b
		return va > vb)
	return order


static func _permutation_count(pool_size: int, take: int) -> int:
	if pool_size <= 0 or take <= 0:
		return 0
	var total: int = 1
	for i: int in range(mini(take, pool_size)):
		total *= pool_size - i
	return total


## Placering nummer [param index] i ett blandat radix-system. Ger en unik
## permutation för varje index i [code]0..total-1[/code], utan att bygga listan.
static func _nth_placement(available: Array[int], slot_count: int, index: int) -> PackedInt32Array:
	var pool: Array[int] = available.duplicate()
	var placement: PackedInt32Array = CombatState.empty_placement(slot_count)
	var rest: int = index
	for i: int in range(slot_count):
		if pool.is_empty():
			break
		var pick: int = rest % pool.size()
		rest /= pool.size()
		placement[i] = pool[pick]
		pool.remove_at(pick)
	return placement
