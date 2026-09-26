class_name StatBlock
extends RefCounted
## Sums stat contributions from named sources (base, level, gear, skills, buffs...).
## Stat naming convention: "<stat>" flat, "<stat>_pct" increased %, "more_<stat>" multiplicative %.

var sources: Dictionary = {}   # source -> { stat: value }
var _cache: Dictionary = {}
var _dirty = true

func set_source(source: String, stats: Dictionary) -> void:
	sources[source] = stats
	_dirty = true

func add_to_source(source: String, stat: String, value: float) -> void:
	if not sources.has(source):
		sources[source] = {}
	sources[source][stat] = float(sources[source].get(stat, 0.0)) + value
	_dirty = true

func remove_source(source: String) -> void:
	if sources.erase(source):
		_dirty = true

func clear_prefix(prefix: String) -> void:
	for k in sources.keys():
		if String(k).begins_with(prefix):
			sources.erase(k)
			_dirty = true

func _rebuild() -> void:
	## "more_*" stats multiply across sources (stored as the combined % bonus); everything else adds.
	_cache.clear()
	var more = {}
	for s in sources.values():
		for stat in s:
			if String(stat).begins_with("more_"):
				more[stat] = float(more.get(stat, 1.0)) * (1.0 + float(s[stat]) / 100.0)
			else:
				_cache[stat] = float(_cache.get(stat, 0.0)) + float(s[stat])
	for stat in more:
		_cache[stat] = (float(more[stat]) - 1.0) * 100.0
	_dirty = false

func get_stat(stat: String, default := 0.0) -> float:
	if _dirty:
		_rebuild()
	return float(_cache.get(stat, default))

## flat * (1 + pct/100) * product(more)
func total(stat: String) -> float:
	return get_stat(stat) * (1.0 + get_stat(stat + "_pct") / 100.0) * (1.0 + get_stat("more_" + stat) / 100.0)

func snapshot() -> Dictionary:
	if _dirty:
		_rebuild()
	return _cache.duplicate()
