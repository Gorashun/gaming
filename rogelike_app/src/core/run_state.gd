class_name RunState
extends RefCounted
## Hela runnen som ren data. Detta objekt ÄR autosaven: [method to_dict] går rakt
## in i en JSON-fil och [method from_dict] återupptar samma run, inklusive
## slumpströmmens exakta position.

## Höjs när sparformatet ändras på ett sätt som kräver migrering.
##
## [b]2 (M5):[/b] runnen spelas i korridoren och [code]meta.corridor[/code] bär
## kartans tillstånd (rutan, vinkeln, besökta rutor, fällans status). En fil
## från version 1 beskriver en marsch som inte finns längre och kan inte
## översättas – [method SaveIO.migrate] kasserar den, och spelaren hamnar i
## staden i stället för i en halv run.
##
## [b]3 (M5.8):[/b] även tutorialvåning 0 sparas. [code]meta.tutorial_room[/code]
## är rumsindexet i källaren, eller -1 för en riktig run, och
## [code]meta.tutorial_loot_open[/code] säger om korten på golvet är loot-valet.
## En fil från version 2 är per definition en riktig run och migreras med
## [code]tutorial_room = -1[/code] – ingen run går förlorad.
const SAVE_VERSION: int = 3

var version: int = SAVE_VERSION
## Synlig i pausmenyn (GAME_DESIGN §6.10) och nyckeln till dagliga utmaningar.
var seed_value: int = 0
## Ögonblicksbild av slumpströmmen ([method Rng.state]).
var rng_state: Dictionary = {}

var floor_index: int = 1
var room_index: int = 1
## Den pågående striden, eller null mellan rum.
var combat: CombatState = null
## Fritt utrymme för meta-progression och klassval, t.ex. {"class": "SMITH"}.
var meta: Dictionary = {}


## Ny run med Smedens startuppsättning.
static func new_run(p_seed: int) -> RunState:
	var run: RunState = RunState.new()
	run.seed_value = p_seed
	run.rng_state = Rng.new(p_seed).state()
	run.combat = Content.smith_state()
	run.meta = {"class": "SMITH"}
	return run


## Läser tillbaka slumpströmmen. Anropas efter en laddning.
func make_rng() -> Rng:
	if rng_state.is_empty():
		return Rng.new(seed_value)
	return Rng.from_state(rng_state)


## Skriver ner strömmens nuvarande position inför en autosave.
func store_rng(rng: Rng) -> void:
	rng_state = rng.state()


func is_run_over() -> bool:
	return combat != null and combat.player_hp <= 0


func to_dict() -> Dictionary:
	return {
		"version": version,
		"seed_value": str(seed_value),
		"rng_state": rng_state.duplicate(true),
		"floor_index": floor_index,
		"room_index": room_index,
		"combat": combat.to_dict() if combat != null else {},
		"meta": meta.duplicate(true),
	}


static func from_dict(data: Dictionary) -> RunState:
	var run: RunState = RunState.new()
	run.version = int(data.get("version", SAVE_VERSION))
	run.seed_value = int(str(data.get("seed_value", "0")))
	run.rng_state = (data.get("rng_state", {}) as Dictionary).duplicate(true)
	run.floor_index = int(data.get("floor_index", 1))
	run.room_index = int(data.get("room_index", 1))
	var combat_data: Dictionary = data.get("combat", {}) as Dictionary
	run.combat = CombatState.from_dict(combat_data) if not combat_data.is_empty() else null
	run.meta = (data.get("meta", {}) as Dictionary).duplicate(true)
	return run
