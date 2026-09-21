class_name RunFlow
extends RefCounted
## Reglerna för hur en run rör sig mellan rum. GAME_DESIGN §1.
##
## Detta är spellogik, inte presentation, och ligger därför i core trots att det
## bara är [code]src/game/game_controller.gd[/code] som anropar det idag. Utan
## den här filen skulle Andrums-läkningen och belöningstabellens våningsnyckel
## hamna i UI-lagret, där de varken kan testas eller simuleras.

## Startar ett rum: hämtar mötet ur innehållet och förbereder första rundan.
## All slump (tärningskast, intents, varianter) dras här – före bekräftelse,
## enligt den heliga regeln (GAME_DESIGN §6.4).
static func start_room(state: CombatState, node: Dictionary, rng: Rng) -> CombatState:
	var next: CombatState = state.copy()
	next.enemies = Content.encounter(int(node.get("room_in_floor", 1)), int(node.get("variant", 0)))
	return Resolver.begin_combat(next, rng)


## Avslutar ett vunnet rum: återställer sidor som vuxit/spruckit och betalar ut
## Andrum. GAME_DESIGN §1: "efter varje vunnen COMBAT (ej BOSS) läker spelaren
## BREATHER_HEAL HP automatiskt innan belöningsvalet."
static func finish_room(state: CombatState, node: Dictionary) -> CombatState:
	var next: CombatState = Resolver.end_combat(state)
	if not is_boss(node):
		next.player_hp = mini(next.player_max_hp, next.player_hp + Rules.BREATHER_HEAL)
	return next


## Sant om Andrum ska betalas ut för [param node]. Speglar [method finish_room]
## så att UI kan visa "+10 HP" utan att räkna om regeln.
static func grants_breather(node: Dictionary) -> bool:
	return not is_boss(node)


static func is_boss(node: Dictionary) -> bool:
	return String(node.get("kind", "")) == RunGraph.KIND_BOSS


## Vilken vikttabell belöningen ska dras ur (GAME_DESIGN §4.7).
## 0 betyder "efter boss": allt är minst uncommon och minst en relik garanteras.
static func reward_floor_key(node: Dictionary) -> int:
	if is_boss(node):
		return 0
	return int(node.get("floor", 1))


# --- Korridorens fällor (M5) ------------------------------------------------

## Kostnadsslag i [member CorridorMap.TRAPS]. Korridoren äger ingen regel: den
## säger bara vad priset heter, och den här filen tar ut det.
const TRAP_COST_HP: String = "hp"
const TRAP_COST_CRACK: String = "cracked_face"
## [b]En fälla dödar aldrig.[/b] CORRIDOR_DESIGN §2.6 regel 3 säger att fällan är
## ett val mellan två priser, inte ett tärningskast om runnen. Att gå in i bossen
## skadad ska vara spelarens eget fel; att dö i en korridor mellan två rum, utan
## en enda placering emellan, vore otur – och då är vi Rune Dice.
const TRAP_HP_FLOOR: int = 1


## Betalar en av fällans två prislappar (CORRIDOR_DESIGN §2.6) och returnerar det
## nya tillståndet. [param option] är posten ur [code]trap.options[/code], alltså
## exakt det spelaren läste på knappen innan hen tryckte.
##
## [b]Samma spricka som SLAGJAWs [code]CRACK_BITE[/code]:[/b] den uppåtvända
## sidan byts mot [constant Resolver.CRACKED_FACE_ID] med [member Face.base_value]
## bevarat, och glastärningens [member Die.integrity] sjunker. En annan regel för
## samma ord ("sprucken") vore två sanningar om samma sak.
static func pay_trap(state: CombatState, option: Dictionary, rng: Rng) -> CombatState:
	var next: CombatState = state.copy()
	var amount: int = maxi(0, int(option.get("amount", 0)))
	match String(option.get("cost", "")):
		TRAP_COST_HP:
			next.player_hp = maxi(TRAP_HP_FLOOR, next.player_hp - amount)
		TRAP_COST_CRACK:
			for _i: int in range(amount):
				_crack_one_face(next, rng)
	return next


## Spräcker den uppåtvända sidan på en slumpad hel tärning. Har varenda tärning
## redan en sprucken uppsida händer ingenting – priset finns inte att ta ut, och
## att ta ut det två gånger på samma sida vore att ta betalt utan vara.
static func _crack_one_face(state: CombatState, rng: Rng) -> void:
	var candidates: Array[int] = []
	for i: int in range(state.dice.size()):
		var face: Face = state.dice[i].showing_face()
		if face != null and face.id != Resolver.CRACKED_FACE_ID:
			candidates.append(i)
	if candidates.is_empty():
		return
	var die: Die = state.dice[candidates[rng.next_int(0, candidates.size() - 1)]]
	var face: Face = die.showing_face()
	var cracked: Face = Face.new(Resolver.CRACKED_FACE_ID, 0)
	cracked.base_value = face.base_value
	die.faces[die.showing] = cracked
	die.cracks += 1
	if die.integrity > 0:
		die.integrity -= 1


## Belöningspoolen minus det spelaren redan tagit. Garanti 3 i §4.7 säger att de
## tre alternativen ska ha olika id; att filtrera bort redan tagna id är samma
## princip utsträckt över hela runnen.
static func available_pool(pool: Array[Dictionary], taken_ids: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in pool:
		if taken_ids.has(String(entry.get("id", ""))):
			continue
		result.append(entry)
	return result
