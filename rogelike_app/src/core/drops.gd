class_name Drops
extends RefCounted
## Dropptabeller och sällsynthetsceremoni. PROGRESSION_REDESIGN §3.3.
##
## [b]Slumpen är isolerad.[/b] Ett rums droppar dras ur
## [code]rng.fork("drops:<nod>")[/code] – en delström som bara beror på runnens
## seed och rummets id. Stridens kast, intents och belöningskorten drar ur
## huvudströmmen precis som i M5, och en omladdning mitt i belöningsvalet ger
## exakt samma droppar igen. Allt dras [i]innan[/i] korten visas (GAME_DESIGN §6.4).
##
## [b]Ceremonin[/b] är data: [method ceremony] ger ett [code]item_dropped[/code]-
## event per föremål med sällsynthet och rekommenderad längd (200–900 ms).
## UI-lagret kopplar färg och ljud (dev A); core bestämmer bara vad som hände.

const SOURCE_ELITE: String = "ELITE"
const SOURCE_ALTAR: String = "ALTAR"
const SOURCE_BOSS: String = "SLAGJAW"

## §3.3-tabellen, tunad mot §5 i simulatorn (M6-passet, docs/M6_B_NOTES.md §5).
## [code]chance[/code] = droppchans, [code]floor[/code] = lägsta sällsynthet,
## [code]up[/code] = chans att gå ett steg upp från golvet, [code]epic[/code] =
## chans till episkt (bara där det är tillåtet).
##
## [b]Avvikelser från §3.3:[/b] vanliga fiender 12 → 20 %, tåligare 22 → 35 %
## (kickar per minut låg på 0,82 mot målet 0,9–1,1 med §3.3:s siffror), och bossen droppar
## UNCOMMON med 60 % RARE i stället för alltid RARE: i M6 slutar nästan varje
## run med en fälld boss, och "alltid rare" gav 1,0 sällsynthetsögonblick per
## run mot målet 0,6. Den första bossen droppar fortfarande alltid ett unikt
## boss-plagg (RARE), se [method roll_source].
const TABLE: Dictionary = {
	"RUST_RAT": {"chance": 0.20, "floor": Rules.Rarity.COMMON, "up": 0.0},
	"SLAG_MOTH": {"chance": 0.20, "floor": Rules.Rarity.COMMON, "up": 0.0},
	"THORN_IMP": {"chance": 0.35, "floor": Rules.Rarity.COMMON, "up": 0.25},
	"PIP_THIEF": {"chance": 0.35, "floor": Rules.Rarity.COMMON, "up": 0.25},
	"IRON_TICK": {"chance": 0.35, "floor": Rules.Rarity.COMMON, "up": 0.25},
	"GRAVE_HAND": {"chance": 0.35, "floor": Rules.Rarity.COMMON, "up": 0.25},
	SOURCE_ELITE: {"chance": 1.0, "floor": Rules.Rarity.UNCOMMON, "up": 0.0},
	SOURCE_ALTAR: {"chance": 1.0, "floor": Rules.Rarity.UNCOMMON, "up": 0.20},
	SOURCE_BOSS: {"chance": 1.0, "floor": Rules.Rarity.UNCOMMON, "up": 0.60, "epic": 0.15},
}

## Ceremonins längd per sällsynthet (§3.3: 200–900 ms).
const CEREMONY_MS: Array[int] = [200, 350, 600, 900]
## §3.3: "EPIC … Max 2 gånger per run."
const MAX_EPICS_PER_RUN: int = 2


## Rullningens sammanhang. Ren data, så att simulatorn och controllern bygger
## den på samma sätt:
## [codeblock]
## {floor: int, epic_allowed: bool, epics_this_run: int,
##  exclude: Array[String]   # id:n som redan bärs i runnen – inga dubbletter
##  found: Array[String]     # profilens samling, för "unikt boss-plagg"
##  first_boss: bool         # ingen boss fälld tidigare (§3.3 garantin)
##  min_rarity: int          # progressionskurvans garanti för rummet, -1 = ingen
## }
## [/codeblock]
static func context(floor_index: int, epic_allowed: bool, exclude: Array = [], found: Array = [],
		first_boss: bool = false, epics_this_run: int = 0, min_rarity: int = -1) -> Dictionary:
	return {
		"floor": floor_index,
		"epic_allowed": epic_allowed,
		"epics_this_run": epics_this_run,
		"exclude": exclude.duplicate(),
		"found": found.duplicate(),
		"first_boss": first_boss,
		"min_rarity": min_rarity,
	}


## Delströmmen för ett rums droppar.
static func stream(rng: Rng, node_id: String) -> Rng:
	return rng.fork("drops:%s" % node_id)


## Rullar en källa. Returnerar ett föremål eller null. Muterar [param ctx]:
## det droppade id:t läggs i [code]exclude[/code] och episka räknas.
static func roll_source(source: String, rng: Rng, ctx: Dictionary) -> Item:
	var row: Dictionary = TABLE.get(source, {}) as Dictionary
	if row.is_empty():
		return null
	if rng.next_float() >= float(row["chance"]):
		return null
	var rarity: int = int(row["floor"])
	if float(row.get("up", 0.0)) > 0.0 and rng.next_float() < float(row["up"]):
		rarity = mini(rarity + 1, Rules.Rarity.RARE)
	if float(row.get("epic", 0.0)) > 0.0 and rng.next_float() < float(row["epic"]) and _epic_ok(ctx):
		rarity = Rules.Rarity.EPIC
	var boss_unique: bool = source == SOURCE_BOSS and bool(ctx.get("first_boss", false))
	if boss_unique:
		# §3.3: "Första gången garanterat unikt boss-plagg."
		rarity = maxi(rarity, Rules.Rarity.RARE)
	return _pick(rarity, source, rng, ctx, boss_unique)


## Rullar alla fiender i ett rum, i listordning, och tillämpar rummets
## garanti ([code]min_rarity[/code]): har inget föremål minst den sällsyntheten
## droppat läggs ett till, ur hela katalogen.
## [param sources_out] fylls med föremåls-id → källa, för ceremonin.
static func roll_room(enemy_ids: Array, rng: Rng, ctx: Dictionary, sources_out: Dictionary = {}) -> Array[Item]:
	var out: Array[Item] = []
	for raw: Variant in enemy_ids:
		var item: Item = roll_source(String(raw), rng, ctx)
		if item != null:
			out.append(item)
			sources_out[item.id] = String(raw)
	var min_rarity: int = int(ctx.get("min_rarity", -1))
	if min_rarity >= 0 and not _has_min(out, min_rarity):
		var forced: Item = _pick(min_rarity, "", rng, ctx, false)
		if forced != null:
			out.append(forced)
	return out


static func _has_min(items: Array[Item], rarity: int) -> bool:
	for item: Item in items:
		if item.rarity >= rarity:
			return true
	return false


static func _epic_ok(ctx: Dictionary) -> bool:
	return bool(ctx.get("epic_allowed", false)) \
		and int(ctx.get("epics_this_run", 0)) < MAX_EPICS_PER_RUN


## Väljer ett föremål av [param rarity]: först bland källans egna föremål,
## sedan hela katalogen, sedan ett steg ned. Aldrig ett id som redan bärs.
static func _pick(rarity: int, source: String, rng: Rng, ctx: Dictionary, boss_unique: bool) -> Item:
	var exclude: Array = ctx.get("exclude", []) as Array
	var found: Array = ctx.get("found", []) as Array
	var wanted: int = rarity
	while wanted >= Rules.Rarity.COMMON:
		if wanted == Rules.Rarity.EPIC and not _epic_ok(ctx):
			wanted -= 1
			continue
		var pools: Array = []
		if boss_unique:
			pools.append(_filter(Content.gear_ids(wanted, SOURCE_BOSS), exclude + found))
		if source != "":
			pools.append(_filter(Content.gear_ids(wanted, source), exclude))
		pools.append(_filter(Content.gear_ids(wanted), exclude))
		for pool: Variant in pools:
			var ids: Array[String] = pool as Array[String]
			if ids.is_empty():
				continue
			var id: String = ids[rng.next_int(0, ids.size() - 1)]
			var item: Item = Content.make_item(id)
			item.secured = false
			exclude.append(id)
			ctx["exclude"] = exclude
			if item.rarity == Rules.Rarity.EPIC:
				ctx["epics_this_run"] = int(ctx.get("epics_this_run", 0)) + 1
			return item
		wanted -= 1
	return null


static func _filter(ids: Array[String], exclude: Array) -> Array[String]:
	var out: Array[String] = []
	for id: String in ids:
		if not exclude.has(id):
			out.append(id)
	out.sort()
	return out


## Ceremoni-events, ett per föremål: [code]{t: "item_dropped", item, rarity,
## rarity_name, source, ms_hint}[/code]. Dev A kopplar färg och ljud på
## [code]rarity[/code]; längden följer §3.3.
static func ceremony(items: Array, source_by_id: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw: Variant in items:
		var item: Item = raw as Item
		if item == null:
			continue
		out.append({
			"t": "item_dropped",
			"item": item.id,
			"name_key": item.name_key,
			"icon_id": item.icon_id,
			"rarity": item.rarity,
			"rarity_name": Rules.rarity_name(item.rarity),
			"source": String(source_by_id.get(item.id, "")),
			"ms_hint": CEREMONY_MS[clampi(item.rarity, 0, CEREMONY_MS.size() - 1)],
		})
	return out
