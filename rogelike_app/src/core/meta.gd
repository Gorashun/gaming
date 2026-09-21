class_name Meta
extends RefCounted
## Profilen mellan runs: Pips, Kodex, kritstreck, upplåsningar, smedjans
## laddning och [Reveal]-flaggorna. TOWN_AND_ONBOARDING §A.3.
##
## [b]Den heliga regeln för metan[/b] (§A.3): [i]aldrig[/i] en statsiffra. Ingen
## `+HP`, ingen `+skada`, ingen `+omkast`, ingen `+startcharge`. Upplåsning är
## variation, inte makt. Det är därför [member unlocked] bara innehåller
## [b]id:n som läggs till i belöningspoolen[/b] – aldrig ett tal som adderas
## till något.
##
## Ligger i [code]user://meta.json[/code], separat från [code]save.json[/code]:
## en run som tar slut, eller en sparfil som nollställs, får aldrig sudda
## kritväggen. Samma trasig-fil-kontrakt som [SaveIO]: en oläsbar profil ger en
## färsk profil, aldrig en krasch.

const SAVE_VERSION: int = 1

## Fast prislista (§A.3). Tre varutyper, inga rabatter, ingen pity-timer.
const PRICE: Dictionary = {
	Rewards.CATEGORY_FORGE_FACE: 5,
	Rewards.CATEGORY_RELIC: 8,
	Rewards.CATEGORY_SLOT_SWAP: 10,
}

## Intjäning (§A.3). "Första gången"-bonusarna gör att en spektakulär förlust
## betalar bättre än en trist överlevnad – vi belönar att spelaren försökte.
const PIPS_PER_ROOM: int = 1
const PIPS_BOSS: int = 3
const PIPS_WIN: int = 5
const FIRST_TIME_BONUS: Dictionary = {
	"QUAD": 2,
	"PENTA": 3,
	"HOUSE": 2,
	"TRIPLE_KILL": 2,
}

var version: int = SAVE_VERSION
## Enda valutan (§A.3: "En valuta. Inte två.").
var pips: int = 0
## Ett kritstreck per död, suddas av en vunnen run (§A.1).
var tally: int = 0
var deaths: int = 0
var wins: int = 0
var runs: int = 0
var best_chain: int = 0
var best_score: int = 0
## Tutorialvåning 0 spelas exakt en gång (§B.2).
var tutorial_done: bool = false
var reveal: Reveal = Reveal.none()
## Belöningspool-id:n som köpts loss på Skrotmarknaden.
var unlocked: Array[String] = []
## Fiender spelaren mött, och combo-typer spelaren sett. Kodexens innehåll.
var seen_enemies: Array[String] = []
var seen_combos: Array[String] = []
## Engångsbonusar som redan betalats ut.
var claimed_firsts: Array[String] = []
## Smedjans laddning inför nästa run, se [Forge].
var loadout: Dictionary = {}
## Index i [constant Content.DEATH_LINES] som Marrow redan sagt (aldrig samma
## två gånger i rad, §A.1).
var last_death_line: int = -1


## En färsk profil för en spelare som aldrig startat spelet.
static func fresh() -> Meta:
	return Meta.new()


## Profilen för någon som hoppat över tutorialen: allt avslöjat, staden öppen.
static func skipped_tutorial() -> Meta:
	var meta: Meta = Meta.new()
	meta.tutorial_done = true
	meta.reveal = Reveal.all_on()
	return meta


# --- Pips ------------------------------------------------------------------

## Vad en avslutad run betalar. Ren funktion; [param firsts] är de
## engångsnycklar runden [b]visade[/b], filtrering mot redan uttagna sker i
## [method award_run].
static func pips_for_run(rooms_cleared: int, boss_killed: bool, won: bool, firsts: Array) -> int:
	var total: int = maxi(0, rooms_cleared) * PIPS_PER_ROOM
	if boss_killed:
		total += PIPS_BOSS
	if won:
		total += PIPS_WIN
	for key: Variant in firsts:
		total += int(FIRST_TIME_BONUS.get(String(key), 0))
	return total


## Betalar ut runden och bokför den. Returnerar en sammanställning som
## dödsskärmen kan visa rad för rad.
func award_run(rooms_cleared: int, boss_killed: bool, won: bool, firsts: Array,
		chain: int = 0, score: int = 0) -> Dictionary:
	var fresh_firsts: Array[String] = []
	for key: Variant in firsts:
		var name: String = String(key)
		if FIRST_TIME_BONUS.has(name) and not claimed_firsts.has(name):
			claimed_firsts.append(name)
			fresh_firsts.append(name)
	var earned: int = pips_for_run(rooms_cleared, boss_killed, won, fresh_firsts)
	pips += earned
	runs += 1
	best_chain = maxi(best_chain, chain)
	best_score = maxi(best_score, score)
	if won:
		wins += 1
		# Kommer du upp suddar du ditt eget streck med tummen (§A.1).
		tally = maxi(0, tally - 1)
	else:
		deaths += 1
		tally += 1
	return {
		"earned": earned,
		"firsts": fresh_firsts,
		"pips": pips,
		"tally": tally,
	}


# --- Skrotmarknaden --------------------------------------------------------

static func price_of(entry: Dictionary) -> int:
	return int(PRICE.get(String(entry.get("category", "")), 0))


func can_afford(entry: Dictionary) -> bool:
	var cost: int = price_of(entry)
	return cost > 0 and pips >= cost and not unlocked.has(String(entry.get("id", "")))


## Köper en post till belöningspoolen. Returnerar false när köpet inte går
## igenom – och då har ingenting ändrats.
func buy(entry: Dictionary) -> bool:
	if not can_afford(entry):
		return false
	pips -= price_of(entry)
	unlocked.append(String(entry.get("id", "")))
	return true


## Belöningspoolen för nästa run: startpoolen plus det som köpts loss.
## [b]Poolen växer, aldrig siffrorna[/b] (§A.3).
func reward_pool(base: Array[Dictionary], locked_by_default: Array[String] = []) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in base:
		var id: String = String(entry.get("id", ""))
		if locked_by_default.has(id) and not unlocked.has(id):
			continue
		result.append(entry)
	return result


# --- Kodex -----------------------------------------------------------------

func see_enemy(id: String) -> bool:
	if id == "" or seen_enemies.has(id):
		return false
	seen_enemies.append(id)
	return true


func see_combo(kind: String) -> bool:
	if kind == "" or kind == "NONE" or seen_combos.has(kind):
		return false
	seen_combos.append(kind)
	return true


# --- Serialisering ---------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"version": version,
		"pips": pips,
		"tally": tally,
		"deaths": deaths,
		"wins": wins,
		"runs": runs,
		"best_chain": best_chain,
		"best_score": best_score,
		"tutorial_done": tutorial_done,
		"reveal": reveal.to_dict(),
		"unlocked": unlocked.duplicate(),
		"seen_enemies": seen_enemies.duplicate(),
		"seen_combos": seen_combos.duplicate(),
		"claimed_firsts": claimed_firsts.duplicate(),
		"loadout": loadout.duplicate(true),
		"last_death_line": last_death_line,
	}


## JSON gör om heltal till float; allt tvättas med [code]int()[/code] här, av
## samma skäl som i [method RunState.from_dict].
static func from_dict(data: Dictionary) -> Meta:
	var meta: Meta = Meta.new()
	meta.version = int(data.get("version", SAVE_VERSION))
	meta.pips = int(data.get("pips", 0))
	meta.tally = int(data.get("tally", 0))
	meta.deaths = int(data.get("deaths", 0))
	meta.wins = int(data.get("wins", 0))
	meta.runs = int(data.get("runs", 0))
	meta.best_chain = int(data.get("best_chain", 0))
	meta.best_score = int(data.get("best_score", 0))
	meta.tutorial_done = bool(data.get("tutorial_done", false))
	meta.reveal = Reveal.from_dict(data.get("reveal", {}) as Dictionary)
	meta.unlocked = _strings(data.get("unlocked", []))
	meta.seen_enemies = _strings(data.get("seen_enemies", []))
	meta.seen_combos = _strings(data.get("seen_combos", []))
	meta.claimed_firsts = _strings(data.get("claimed_firsts", []))
	meta.loadout = _wash_loadout(data.get("loadout", {}) as Dictionary)
	meta.last_death_line = int(data.get("last_death_line", -1))
	return meta


## Smedjans laddning är idel heltalsindex, och JSON-tal är float64: utan den
## här tvätten kommer [code][2, 0, 1, 3, 4][/code] tillbaka som
## [code][2.0, 0.0, …][/code] och jämförelser mot en färsk ordning slår fel.
## Samma regel som i [method RunState.from_dict] och [method RunGraph.from_dict].
static func _wash_loadout(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var order: Array = []
	for value: Variant in raw.get(Forge.KEY_SLOT_ORDER, []) as Array:
		order.append(int(value))
	if not order.is_empty():
		out[Forge.KEY_SLOT_ORDER] = order
	var swaps: Array = []
	for entry: Variant in raw.get(Forge.KEY_FACE_SWAPS, []) as Array:
		var swap: Array = []
		for value: Variant in entry as Array:
			swap.append(int(value))
		swaps.append(swap)
	if not swaps.is_empty():
		out[Forge.KEY_FACE_SWAPS] = swaps
	return out


static func _strings(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	for value: Variant in raw as Array:
		out.append(String(value))
	return out
