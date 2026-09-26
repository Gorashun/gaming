extends Node
## Named, seedable RNG streams. Every random decision goes through a stream so
## results are reproducible (tests, bug reports) and a future server can own them.

var _streams: Dictionary = {}
var master_seed: int = 0

func _ready() -> void:
	reseed(int(Time.get_unix_time_from_system()))

func reseed(seed_value: int) -> void:
	master_seed = seed_value
	_streams.clear()

func stream(name: String) -> RandomNumberGenerator:
	if not _streams.has(name):
		var r = RandomNumberGenerator.new()
		r.seed = hash(str(master_seed) + ":" + name)
		_streams[name] = r
	return _streams[name]

func randf_on(name: String) -> float:
	return stream(name).randf()

func range_on(name: String, a: float, b: float) -> float:
	return stream(name).randf_range(a, b)

func int_on(name: String, a: int, b: int) -> int:
	return stream(name).randi_range(a, b)

func chance(name: String, p: float) -> bool:
	return stream(name).randf() < p

## Weighted pick from an Array of Dictionaries with a numeric weight key.
func weighted(name: String, entries: Array, weight_key := "weight"):
	var total = 0.0
	for e in entries:
		total += float(e.get(weight_key, 1.0))
	if total <= 0.0:
		return null
	var roll = stream(name).randf() * total
	for e in entries:
		roll -= float(e.get(weight_key, 1.0))
		if roll <= 0.0:
			return e
	return entries[-1]
