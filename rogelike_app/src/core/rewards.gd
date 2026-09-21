class_name Rewards
extends RefCounted
## Belöningsvalet efter varje vunnet rum. GAME_DESIGN.md §4.7.
##
## Alltid tre alternativ, alltid olika id, alltid seedat. Dragningen sker i
## [method Resolver.advance]-fasen, dvs. innan spelaren bekräftar något, och
## resultatet är synligt. Ingen pity-timer och ingen dold uppräkning: vikterna
## är konstanta och kan visas för spelaren.
##
## En pool-post är ren data så att den kan ligga som JSON i src/data/:
## [codeblock]
## {"id": "POISON_DROP", "category": "FORGE_FACE", "rarity": Rules.Rarity.COMMON,
##  "name": "Giftdroppe", "data": {...}}
## [/codeblock]

const OPTION_COUNT: int = 3

const CATEGORY_FORGE_FACE: String = "FORGE_FACE"
const CATEGORY_RELIC: String = "RELIC"
const CATEGORY_SLOT_SWAP: String = "SLOT_SWAP"

## Kategorivikter (GAME_DESIGN §4.7).
const CATEGORY_WEIGHTS: Dictionary = {
	CATEGORY_FORGE_FACE: 50.0,
	CATEGORY_RELIC: 30.0,
	CATEGORY_SLOT_SWAP: 20.0,
}

## Sällsynthetsvikter per våning. Nyckel 0 = "efter boss".
const RARITY_WEIGHTS_BY_FLOOR: Dictionary = {
	1: [70.0, 25.0, 5.0],
	2: [55.0, 33.0, 12.0],
	3: [40.0, 40.0, 20.0],
	0: [0.0, 60.0, 40.0],
}


## Vikttabellen för en våning. [param floor_index] 0 betyder "efter boss".
static func rarity_weights(floor_index: int) -> Array:
	if RARITY_WEIGHTS_BY_FLOOR.has(floor_index):
		return RARITY_WEIGHTS_BY_FLOOR[floor_index] as Array
	return RARITY_WEIGHTS_BY_FLOOR[3] as Array


## Effektiv vikt för en post: kategorivikt × sällsynthetsvikt.
static func entry_weight(entry: Dictionary, weights: Array) -> float:
	var rarity: int = int(entry.get("rarity", Rules.Rarity.COMMON))
	var rarity_weight: float = float(weights[rarity]) if rarity < weights.size() else 0.0
	var category_weight: float = float(CATEGORY_WEIGHTS.get(String(entry.get("category", "")), 1.0))
	return rarity_weight * category_weight


## Drar tre alternativ utan återläggning och tillämpar garantierna i §4.7.
## [param floor_index] 0 = efter boss.
static func generate(pool: Array, rng: Rng, floor_index: int = 1, count: int = OPTION_COUNT) -> Array[Dictionary]:
	var weights: Array = rarity_weights(floor_index)
	var after_boss: bool = floor_index == 0

	var candidates: Array = []
	var seen: Dictionary = {}
	for raw: Variant in pool:
		var entry: Dictionary = raw as Dictionary
		var id: String = String(entry.get("id", ""))
		if id == "" or seen.has(id):
			continue
		# Garanti 4: efter boss är allt under uncommon uteslutet redan i poolen.
		if after_boss and int(entry.get("rarity", Rules.Rarity.COMMON)) < Rules.Rarity.UNCOMMON:
			continue
		seen[id] = true
		candidates.append(entry)

	var options: Array[Dictionary] = _draw(candidates, weights, rng, count)

	# Garanti 1: minst ett FORGE_FACE (gäller inte efter boss, där garanti 4
	# i stället kräver minst en RELIC).
	if not after_boss:
		options = _ensure_category(options, candidates, weights, rng, CATEGORY_FORGE_FACE)
	else:
		options = _ensure_category(options, candidates, weights, rng, CATEGORY_RELIC)

	# Garanti 2: från våning 2 måste minst ett alternativ vara >= uncommon.
	if floor_index >= 2 and not _has_min_rarity(options, Rules.Rarity.UNCOMMON):
		options = _upgrade_worst(options, candidates, weights, rng)

	return options


static func _draw(candidates: Array, weights: Array, rng: Rng, count: int) -> Array[Dictionary]:
	var remaining: Array = candidates.duplicate()
	var remaining_weights: Array = []
	for entry: Variant in remaining:
		remaining_weights.append(entry_weight(entry as Dictionary, weights))

	var options: Array[Dictionary] = []
	while options.size() < count and not remaining.is_empty():
		var chosen: Variant = rng.weighted_pick(remaining, remaining_weights)
		var index: int = remaining.find(chosen)
		if index < 0:
			break
		options.append((remaining[index] as Dictionary).duplicate(true))
		remaining.remove_at(index)
		remaining_weights.remove_at(index)
	return options


static func _has_category(options: Array[Dictionary], category: String) -> bool:
	for option: Dictionary in options:
		if String(option.get("category", "")) == category:
			return true
	return false


static func _has_min_rarity(options: Array[Dictionary], min_rarity: int) -> bool:
	for option: Dictionary in options:
		if int(option.get("rarity", Rules.Rarity.COMMON)) >= min_rarity:
			return true
	return false


static func _ids(options: Array[Dictionary]) -> Dictionary:
	var ids: Dictionary = {}
	for option: Dictionary in options:
		ids[String(option.get("id", ""))] = true
	return ids


## Byter ut det sista alternativet mot ett ur [param category] om kategorin saknas.
static func _ensure_category(options: Array[Dictionary], candidates: Array, weights: Array, rng: Rng, category: String) -> Array[Dictionary]:
	if options.is_empty() or _has_category(options, category):
		return options
	var chosen_ids: Dictionary = _ids(options)
	var subset: Array = []
	var subset_weights: Array = []
	for raw: Variant in candidates:
		var entry: Dictionary = raw as Dictionary
		if String(entry.get("category", "")) != category:
			continue
		if chosen_ids.has(String(entry.get("id", ""))):
			continue
		subset.append(entry)
		subset_weights.append(entry_weight(entry, weights))
	if subset.is_empty():
		return options
	var replacement: Variant = rng.weighted_pick(subset, subset_weights)
	options[options.size() - 1] = (replacement as Dictionary).duplicate(true)
	return options


## Rullar om det sämsta alternativet en gång ur uncommon-poolen (garanti 2).
static func _upgrade_worst(options: Array[Dictionary], candidates: Array, weights: Array, rng: Rng) -> Array[Dictionary]:
	if options.is_empty():
		return options
	var worst: int = 0
	for i: int in range(options.size()):
		if int(options[i].get("rarity", 0)) < int(options[worst].get("rarity", 0)):
			worst = i
	var chosen_ids: Dictionary = _ids(options)
	var subset: Array = []
	var subset_weights: Array = []
	for raw: Variant in candidates:
		var entry: Dictionary = raw as Dictionary
		if int(entry.get("rarity", Rules.Rarity.COMMON)) != Rules.Rarity.UNCOMMON:
			continue
		if chosen_ids.has(String(entry.get("id", ""))):
			continue
		subset.append(entry)
		subset_weights.append(entry_weight(entry, weights))
	if subset.is_empty():
		return options
	var replacement: Variant = rng.weighted_pick(subset, subset_weights)
	options[worst] = (replacement as Dictionary).duplicate(true)
	return options
