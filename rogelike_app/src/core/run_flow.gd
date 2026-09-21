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
