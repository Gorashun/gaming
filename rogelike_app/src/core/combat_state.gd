class_name CombatState
extends RefCounted
## Hela striden som ren data. GAME_DESIGN.md §2.1.
##
## [method Resolver.resolve] arbetar alltid på en djup kopia av detta objekt och
## returnerar ett nytt [CombatState]. Ingen metod här drar slump.

var board: Board = null
var dice: Array[Die] = []
## Längd SLOT_COUNT. placement[i] = index i [member dice], eller -1 för tom slot.
## Lagras i staten så att en sparfil kan återge en halvfärdig placering.
var placement: PackedInt32Array = PackedInt32Array()
## Ordnad front→bak. Index 0 är den främsta fienden.
var enemies: Array[Enemy] = []
var player_hp: int = 60
var player_max_hp: int = 60
## Absorberar fiendeskada denna runda. Nollställs vid round_end.
var ward: int = 0
## 0..CHARGE_CAP. Överlever mellan rundor, nollställs vid stridens slut.
var charge: int = 0
var rerolls_left: int = 1
## 1-indexerad.
var round_number: int = 1
var relics: Array[Relic] = []
## die_id som är stulna just nu och därför inte kan placeras.
var stolen: Array[String] = []
## Ackumulerad skada mot fiender under hela striden, för combat_won-eventet.
var total_damage: int = 0
## Sätts av resolve() när spelaren dör. UI ska då avsluta runnen.
var player_dead: bool = false
## M6: det hjälten bär just nu, plus hjältens quirk som ett slotlöst
## pseudo-föremål. Resolvern läser effekterna härifrån ([GearRules]); listan
## skrivs bara av [method GearRules.sync_combat], aldrig av resolve().
var gear: Array[Item] = []
## Omkast per strid ([code]COMBAT_REROLL[/code]) som ännu inte använts. De
## ingår i [member rerolls_left] och förbrukas efter rundans egna omkast.
var combat_rerolls: int = 0
## Fiender dödade hittills i striden ([code]DAMAGE_PER_KILL[/code]).
var kills: int = 0


func _init() -> void:
	board = Board.smith_board()
	placement = empty_placement()


## En placement-array helt utan tärningar.
static func empty_placement(slot_count: int = Rules.SLOT_COUNT) -> PackedInt32Array:
	var p: PackedInt32Array = PackedInt32Array()
	p.resize(slot_count)
	p.fill(-1)
	return p


func die_index(id: String) -> int:
	for i: int in range(dice.size()):
		if dice[i].id == id:
			return i
	return -1


## Främsta levande fienden, eller null om alla är döda.
func front_enemy() -> Enemy:
	for enemy: Enemy in enemies:
		if enemy.is_alive():
			return enemy
	return null


func enemies_alive() -> int:
	var count: int = 0
	for enemy: Enemy in enemies:
		if enemy.is_alive():
			count += 1
	return count


func is_won() -> bool:
	return enemies_alive() == 0


## Index i [member dice] för tärningar som inte ligger i någon slot och inte är
## stulna. Detta är den NORMATIVA definitionen av "oanvänd" (GAME_DESIGN §2.3 P5).
func unplaced_die_indices(p: PackedInt32Array) -> Array[int]:
	var placed: Dictionary = {}
	for i: int in range(p.size()):
		if p[i] >= 0:
			placed[p[i]] = true
	var result: Array[int] = []
	for i: int in range(dice.size()):
		if placed.has(i):
			continue
		if stolen.has(dice[i].id):
			continue
		result.append(i)
	return result


## Djup kopia. Allt resolve() rör är en kopia, aldrig anroparens objekt.
func copy() -> CombatState:
	var other: CombatState = CombatState.new()
	other.board = board.copy()
	var copied_dice: Array[Die] = []
	for die: Die in dice:
		copied_dice.append(die.copy())
	other.dice = copied_dice
	other.placement = placement.duplicate()
	var copied_enemies: Array[Enemy] = []
	for enemy: Enemy in enemies:
		copied_enemies.append(enemy.copy())
	other.enemies = copied_enemies
	var copied_relics: Array[Relic] = []
	for relic: Relic in relics:
		copied_relics.append(relic.copy())
	other.relics = copied_relics
	other.player_hp = player_hp
	other.player_max_hp = player_max_hp
	other.ward = ward
	other.charge = charge
	other.rerolls_left = rerolls_left
	other.round_number = round_number
	other.stolen = stolen.duplicate()
	other.total_damage = total_damage
	other.player_dead = player_dead
	# Grunt med flit: föremålen är oföränderliga inom en strid (bara
	# [method GearRules.sync_combat] byter listan, och då mot nya objekt).
	# resolve() kopierar staten per förhandsvisning, och lookahead-policyn gör
	# det hundratals gånger per runda.
	other.gear = gear.duplicate()
	other.combat_rerolls = combat_rerolls
	other.kills = kills
	return other


func to_dict() -> Dictionary:
	var dice_data: Array = []
	for die: Die in dice:
		dice_data.append(die.to_dict())
	var enemy_data: Array = []
	for enemy: Enemy in enemies:
		enemy_data.append(enemy.to_dict())
	var relic_data: Array = []
	for relic: Relic in relics:
		relic_data.append(relic.to_dict())
	return {
		"board": board.to_dict(),
		"dice": dice_data,
		"placement": Array(placement),
		"enemies": enemy_data,
		"relics": relic_data,
		"player_hp": player_hp,
		"player_max_hp": player_max_hp,
		"ward": ward,
		"charge": charge,
		"rerolls_left": rerolls_left,
		"round_number": round_number,
		"stolen": stolen.duplicate(),
		"total_damage": total_damage,
		"player_dead": player_dead,
		"gear": Item.list_to_dicts(gear),
		"combat_rerolls": combat_rerolls,
		"kills": kills,
	}


static func from_dict(data: Dictionary) -> CombatState:
	var state: CombatState = CombatState.new()
	state.board = Board.from_dict(data.get("board", {}) as Dictionary)

	var dice: Array[Die] = []
	for entry: Variant in data.get("dice", []) as Array:
		dice.append(Die.from_dict(entry as Dictionary))
	state.dice = dice

	var placement: PackedInt32Array = PackedInt32Array()
	for value: Variant in data.get("placement", []) as Array:
		placement.append(int(value))
	state.placement = placement if placement.size() > 0 else empty_placement()

	var enemies: Array[Enemy] = []
	for entry: Variant in data.get("enemies", []) as Array:
		enemies.append(Enemy.from_dict(entry as Dictionary))
	state.enemies = enemies

	var relics: Array[Relic] = []
	for entry: Variant in data.get("relics", []) as Array:
		relics.append(Relic.from_dict(entry as Dictionary))
	state.relics = relics

	state.player_hp = int(data.get("player_hp", 60))
	state.player_max_hp = int(data.get("player_max_hp", 60))
	state.ward = int(data.get("ward", 0))
	state.charge = int(data.get("charge", 0))
	state.rerolls_left = int(data.get("rerolls_left", 1))
	state.round_number = int(data.get("round_number", 1))
	var stolen: Array[String] = []
	for entry: Variant in data.get("stolen", []) as Array:
		stolen.append(String(entry))
	state.stolen = stolen
	state.total_damage = int(data.get("total_damage", 0))
	state.player_dead = bool(data.get("player_dead", false))
	state.gear = Item.list_from_dicts(data.get("gear", []))
	state.combat_rerolls = int(data.get("combat_rerolls", 0))
	state.kills = int(data.get("kills", 0))
	return state
