class_name Rng
extends RefCounted
## Seedad slumpkälla för hela simuleringen.
##
## All slump i [code]src/core/[/code] går genom en [Rng]-instans. Samma seed ger
## exakt samma run, vilket är förutsättningen för dagliga utmaningar,
## buggrapporter ("kör seed 12345") och deterministiska tester.
##
## Tillståndet kan sparas med [method state] och återställas med [method restore],
## så att en autosave kan återuppta exakt samma slumpsekvens mitt i en run.
##
## Regel: rendering och UI får ALDRIG dra ur denna Rng. Visuell slump (partiklar,
## skakning) använder en egen, osparad källa.

## Fast intern strömväxel så att [method fork] ger stabila delströmmar.
const _FORK_MIX: int = 0x2545F4914F6CDD1D

var _rng: RandomNumberGenerator
var _seed: int


func _init(seed_value: int = 0) -> void:
	_rng = RandomNumberGenerator.new()
	_seed = seed_value
	_rng.seed = seed_value


## Seeden som strömmen startade från. Ändras bara av [method reset].
func get_seed() -> int:
	return _seed


## Startar om strömmen från sin ursprungliga seed.
func reset() -> void:
	_rng.seed = _seed


## Heltal i det STÄNGDA intervallet [param lo]..[param hi] (båda inklusive).
## Om [param hi] < [param lo] byts gränserna, så anroparen aldrig får en tyst nolla.
func next_int(lo: int, hi: int) -> int:
	if hi < lo:
		var tmp: int = lo
		lo = hi
		hi = tmp
	return _rng.randi_range(lo, hi)


## Flyttal i det halvöppna intervallet [param lo]..[param hi].
func next_float(lo: float = 0.0, hi: float = 1.0) -> float:
	return _rng.randf_range(lo, hi)


## Sant med sannolikheten [param probability] (0.0–1.0).
func chance(probability: float) -> bool:
	if probability <= 0.0:
		return false
	if probability >= 1.0:
		return true
	return _rng.randf() < probability


## Ett slumpat element ur [param array]. Returnerar [code]null[/code] för tom array.
func pick(array: Array) -> Variant:
	if array.is_empty():
		return null
	return array[next_int(0, array.size() - 1)]


## Viktad dragning. [param weights] måste ha samma längd som [param items].
## Vikter <= 0 kan aldrig dras. Om summan av vikterna är <= 0 faller vi tillbaka
## på likformig dragning, så att en felkonfigurerad pool aldrig kraschar en run.
func weighted_pick(items: Array, weights: Array) -> Variant:
	if items.is_empty():
		return null
	if weights.size() != items.size():
		push_error("Rng.weighted_pick: items (%d) och weights (%d) har olika längd" % [items.size(), weights.size()])
		return pick(items)

	var total: float = 0.0
	for w: Variant in weights:
		var value: float = float(w)
		if value > 0.0:
			total += value
	if total <= 0.0:
		return pick(items)

	var roll: float = _rng.randf() * total
	var acc: float = 0.0
	for i: int in range(items.size()):
		var value: float = float(weights[i])
		if value <= 0.0:
			continue
		acc += value
		if roll < acc:
			return items[i]
	# Flyttalsavrundning kan lämna oss precis på kanten: ta sista positiva vikten.
	for i: int in range(items.size() - 1, -1, -1):
		if float(weights[i]) > 0.0:
			return items[i]
	return items[items.size() - 1]


## Drar [param count] UNIKA index ur en viktad pool, utan återläggning.
## Returnerar en Array med de dragna elementen (kortare än [param count] om poolen är liten).
func weighted_sample(items: Array, weights: Array, count: int) -> Array:
	var remaining_items: Array = items.duplicate()
	var remaining_weights: Array = weights.duplicate()
	var result: Array = []
	while result.size() < count and not remaining_items.is_empty():
		var chosen: Variant = weighted_pick(remaining_items, remaining_weights)
		var index: int = remaining_items.find(chosen)
		if index < 0:
			break
		result.append(remaining_items[index])
		remaining_items.remove_at(index)
		remaining_weights.remove_at(index)
	return result


## Deterministisk Fisher-Yates på plats. Godots [method Array.shuffle] använder
## den globala slumpen och får inte användas i core.
func shuffle(array: Array) -> void:
	for i: int in range(array.size() - 1, 0, -1):
		var j: int = next_int(0, i)
		var tmp: Variant = array[i]
		array[i] = array[j]
		array[j] = tmp


## En härledd delström. Två forks med olika [param label] är oberoende av varandra,
## och att dra ur en fork påverkar inte föräldern. Används för att t.ex. hålla
## belöningsgenerering isolerad från stridsslumpen.
func fork(label: String) -> Rng:
	var mixed: int = _seed ^ (hash(label) * _FORK_MIX)
	return Rng.new(mixed)


## Serialiserbart ögonblicksbild av strömmen.
## Seed och state lagras som String eftersom JSON-tal är float64 och skulle
## tappa precision för 64-bitars värden.
func state() -> Dictionary:
	return {
		"seed": str(_seed),
		"state": str(_rng.state),
	}


## Återställer en ström sparad med [method state]. Efter detta ger nästa dragning
## exakt samma värde som vid spartillfället.
func restore(snapshot: Dictionary) -> void:
	if snapshot.has("seed"):
		_seed = int(str(snapshot["seed"]))
		_rng.seed = _seed
	if snapshot.has("state"):
		_rng.state = int(str(snapshot["state"]))


## Bekvämlighet: skapar en ny Rng direkt ur en sparad ögonblicksbild.
static func from_state(snapshot: Dictionary) -> Rng:
	var rng: Rng = Rng.new(0)
	rng.restore(snapshot)
	return rng
