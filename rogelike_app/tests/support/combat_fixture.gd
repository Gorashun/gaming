class_name CombatFixture
extends RefCounted
## Testhjälp: bygger ett [CombatState] + placement ur kompakta beskrivningar,
## så att räkneexemplen i GAME_DESIGN §2.4 kan skrivas nästan ordagrant.
##
## Tärningarna görs "uniforma": alla sex sidor är identiska. Då spelar
## [member Die.showing] ingen roll och testerna behöver aldrig röra slumpen.

## En tärning där alla sidor är [param face].
static func uniform_die(id: String, face: Face) -> Die:
	var faces: Array[Face] = []
	for i: int in range(Rules.FACE_COUNT):
		faces.append(face.copy())
	var die: Die = Die.new(id, faces, Rules.DieMaterial.IRON)
	die.showing = 0
	return die


## Gör om ett kompakt slot-värde till en [Face].
## int → vanlig sida med det värdet. [Face] → används rakt av.
static func to_face(entry: Variant) -> Face:
	if entry is Face:
		return (entry as Face).copy()
	return Face.new("PIP_%d" % int(entry), int(entry))


## Bygger ett tillstånd. [param slot_entries] har ett värde per slot där
## [code]null[/code] betyder tom slot. [param unplaced] är oplacerade tärningar.
static func build(board_types: Array, slot_entries: Array, unplaced: Array = [], enemies: Array = []) -> Dictionary:
	var state: CombatState = CombatState.new()
	state.board = Board.from_types(board_types)
	state.player_hp = 40
	state.player_max_hp = 40

	var dice: Array[Die] = []
	var placement: PackedInt32Array = CombatState.empty_placement(board_types.size())
	for i: int in range(slot_entries.size()):
		if slot_entries[i] == null:
			continue
		placement[i] = dice.size()
		dice.append(uniform_die("die_s%d" % i, to_face(slot_entries[i])))
	for entry: Variant in unplaced:
		dice.append(uniform_die("die_u%d" % dice.size(), to_face(entry)))

	state.dice = dice
	state.placement = placement

	var typed_enemies: Array[Enemy] = []
	for enemy: Variant in enemies:
		typed_enemies.append(enemy as Enemy)
	state.enemies = typed_enemies

	return {"state": state, "placement": placement}


## En fiende utan intent (attack 0), så att P4 aldrig stör ett P1–P3-test.
static func dummy_enemy(id: String, hp: int, armor: int = 0, thorns: int = 0) -> Enemy:
	var enemy: Enemy = Enemy.new(id, hp, 0, id)
	enemy.armor = armor
	enemy.thorns = thorns
	enemy.intent = Intent.new(Rules.IntentKind.ATTACK, 0)
	return enemy


## Summan av all skada som faktiskt landade på fiender.
static func total_damage(result: ResolveResult) -> int:
	var total: int = 0
	for event: Dictionary in result.events:
		var t: String = String(event.get("t", ""))
		if t == "damage_dealt" or t == "status_ticked":
			total += int(event.get("amount", 0))
	return total
