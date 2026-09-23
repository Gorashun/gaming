class_name Progression
extends RefCounted
## Progressionskurvan, run 1–10. PROGRESSION_REDESIGN §5.
##
## [b]Garantier, inte förhoppningar.[/b] Kurvans hållpunkter implementeras som
## regler som alltid håller, oavsett seed och spelare – och resten mäts i
## simulatorn (kickar per minut, droppar per run). Ingen garanti ger köpbar
## styrka; alla verkar genom sådant som ändå dör med hjälten (nivå, gear).
##
## "Run N" = [member Meta.runs_started] under runnen. Tutorialen (våning 0) är
## run 0 och räknas inte.
##
## | Run | Garanti |
## |---|---|
## | 0 | ett COMMON-föremål på kroppen i rum 0.3 ([constant TUTORIAL_GIFT]) |
## | 1 | minst ett UNCOMMON droppar i rum 1 |
## | 3 | hjälten har minst nivå 2 = tre slots |
## | 6+ | har inget RARE någonsin droppat, droppar ett i runnens första rum |
## | 10+ | episka föremål kan droppa (§5: "Första EPIC möjlig") |

const TUTORIAL_GIFT: String = "SLAG_PLATE"
const FIRST_UNCOMMON_RUN: int = 1
const LEVEL_FLOOR_BY_RUN: Dictionary = {3: 2}
const RARE_PITY_RUN: int = 6
const EPIC_RUN: int = 10


static func run_number(meta: Meta) -> int:
	return meta.runs_started


## Epic får aldrig droppa före våning 2 (§3.5) – och i M6, där Gropen har en
## våning, låses den i stället upp av run 10 (§5).
static func epic_allowed(meta: Meta, floor_index: int) -> bool:
	return floor_index >= 2 or run_number(meta) >= EPIC_RUN


## Lägsta nivå hjälten ska ha i run [param run]. Kurvans nivågolv.
static func level_floor(run: int) -> int:
	var floor_level: int = 1
	for key: Variant in LEVEL_FLOOR_BY_RUN:
		if run >= int(key):
			floor_level = maxi(floor_level, int(LEVEL_FLOOR_BY_RUN[key]))
	return floor_level


## Garanterad lägsta sällsynthet för ett rum, eller -1. [param room_in_run] är
## rummets ordning i runnen (1 = första striden).
static func room_min_rarity(meta: Meta, room_in_run: int) -> int:
	if room_in_run != 1:
		return -1
	var run: int = run_number(meta)
	if run >= RARE_PITY_RUN and _ever_dropped(meta, Rules.Rarity.RARE) == 0:
		return Rules.Rarity.RARE
	if run == FIRST_UNCOMMON_RUN and _ever_dropped(meta, Rules.Rarity.UNCOMMON) == 0:
		return Rules.Rarity.UNCOMMON
	return -1


static func _ever_dropped(meta: Meta, min_rarity: int) -> int:
	var total: int = 0
	for rarity: int in range(min_rarity, meta.drops_by_rarity.size()):
		total += meta.drops_by_rarity[rarity]
	return total


## Droppkontexten för ett rum i en pågående run.
static func drop_context(meta: Meta, run: RunState, floor_index: int, room_in_run: int,
		epics_this_run: int = 0) -> Dictionary:
	var carried: Array = []
	if run != null:
		for item: Item in run.carried_items():
			carried.append(item.id)
	return Drops.context(floor_index, epic_allowed(meta, floor_index), carried, meta.found_gear,
		meta.bosses_killed == 0, epics_this_run, room_min_rarity(meta, room_in_run))


## Bokför droppar i profilen: räknare per sällsynthet och samlingen.
static func note_drops(meta: Meta, items: Array) -> void:
	for raw: Variant in items:
		var item: Item = raw as Item
		if item == null:
			continue
		meta.drops_total += 1
		meta.drops_by_rarity[clampi(item.rarity, 0, meta.drops_by_rarity.size() - 1)] += 1
		meta.note_found(item.id)
