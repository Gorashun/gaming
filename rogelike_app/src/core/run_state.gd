class_name RunState
extends RefCounted
## Hela runnen som ren data. Detta objekt ÄR autosaven: [method to_dict] går rakt
## in i en JSON-fil och [method from_dict] återuppta exakt samma run, inklusive
## slumpströmmens position.

## Höjs när sparformatet ändras på ett sätt som kräver migrering.
const SAVE_VERSION: int = 1

var version: int = SAVE_VERSION
## Runnens seed. Samma seed + samma val = samma run.
var seed_value: int = 0
## Ögonblicksbild av slumpströmmen ([method Rng.state]).
var rng_state: Dictionary = {}

var floor_index: int = 1
var room_index: int = 1
var player_hp: int = 40
var player_max_hp: int = 40
## Ackumulerat block, nollställs vid rundstart.
var block: int = 0

var dice: Array[Die] = []
var board: Board = null
var relics: Array[Relic] = []
var enemies: Array[Enemy] = []
## Fritt utrymme för meta-progression och klassval, t.ex. {"class": "smith"}.
var meta: Dictionary = {}


func _init() -> void:
	board = Board.default_board()


## Skapar en ny run med standarduppsättning. Innehållet ersätts av src/data/
## när M1 lägger in riktiga klasser.
static func new_run(p_seed: int, die_count: int = 6) -> RunState:
	var run: RunState = RunState.new()
	run.seed_value = p_seed
	run.rng_state = Rng.new(p_seed).state()
	var dice: Array[Die] = []
	for i: int in range(die_count):
		dice.append(Die.standard("die_%d" % i))
	run.dice = dice
	return run


func die_by_id(id: String) -> Die:
	for die: Die in dice:
		if die.id == id:
			return die
	return null


## Främsta levande fienden, eller null om striden är vunnen.
func front_enemy() -> Enemy:
	for enemy: Enemy in enemies:
		if enemy.is_alive():
			return enemy
	return null


func is_combat_won() -> bool:
	return front_enemy() == null


func is_run_over() -> bool:
	return player_hp <= 0


## Läser tillbaka slumpströmmen ur runstate. Anropas efter en laddning.
func make_rng() -> Rng:
	if rng_state.is_empty():
		return Rng.new(seed_value)
	return Rng.from_state(rng_state)


## Skriver ner strömmens nuvarande position i runstate inför en autosave.
func store_rng(rng: Rng) -> void:
	rng_state = rng.state()


func to_dict() -> Dictionary:
	var dice_data: Array = []
	for die: Die in dice:
		dice_data.append(die.to_dict())
	var relic_data: Array = []
	for relic: Relic in relics:
		relic_data.append(relic.to_dict())
	var enemy_data: Array = []
	for enemy: Enemy in enemies:
		enemy_data.append(enemy.to_dict())
	return {
		"version": version,
		"seed_value": str(seed_value),
		"rng_state": rng_state.duplicate(true),
		"floor_index": floor_index,
		"room_index": room_index,
		"player_hp": player_hp,
		"player_max_hp": player_max_hp,
		"block": block,
		"dice": dice_data,
		"board": board.to_dict() if board != null else {},
		"relics": relic_data,
		"enemies": enemy_data,
		"meta": meta.duplicate(true),
	}


static func from_dict(data: Dictionary) -> RunState:
	var run: RunState = RunState.new()
	run.version = int(data.get("version", SAVE_VERSION))
	run.seed_value = int(str(data.get("seed_value", "0")))
	run.rng_state = (data.get("rng_state", {}) as Dictionary).duplicate(true)
	run.floor_index = int(data.get("floor_index", 1))
	run.room_index = int(data.get("room_index", 1))
	run.player_hp = int(data.get("player_hp", 40))
	run.player_max_hp = int(data.get("player_max_hp", 40))
	run.block = int(data.get("block", 0))

	var dice: Array[Die] = []
	for entry: Variant in data.get("dice", []) as Array:
		dice.append(Die.from_dict(entry as Dictionary))
	run.dice = dice

	var relics: Array[Relic] = []
	for entry: Variant in data.get("relics", []) as Array:
		relics.append(Relic.from_dict(entry as Dictionary))
	run.relics = relics

	var enemies: Array[Enemy] = []
	for entry: Variant in data.get("enemies", []) as Array:
		enemies.append(Enemy.from_dict(entry as Dictionary))
	run.enemies = enemies

	var board_data: Dictionary = data.get("board", {}) as Dictionary
	run.board = Board.from_dict(board_data) if not board_data.is_empty() else Board.default_board()
	run.meta = (data.get("meta", {}) as Dictionary).duplicate(true)
	return run
