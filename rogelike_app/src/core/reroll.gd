class_name Reroll
extends RefCounted
## Roll-fasen: omkast före bekräftelse. GAME_DESIGN §1 och UI_GUIDE §4.5.
##
## [b]Varför den är ny i M1:[/b] M0:s simulator kastade aldrig om, så
## [code]rerolls_left[/code], [code]LOCKED[/code] och [code]REFUND_REROLL[/code]
## fanns som data men hade ingen regel. Reglerna ligger här i stället för i
## [Resolver] eftersom [method Resolver.resolve] per definition inte får se en
## RNG (GAME_DESIGN §6.1) – ett omkast är input-slump, inte utfallsslump, och
## sker alltid [b]före[/b] bekräftelsen.
##
## [b]Tolkningar som behöver en rad i DECISIONS.md:[/b]
## [br]1. [code]REFUND_REROLL[/code] ("roll-fas: +1 omkast denna runda") betalas
##    ut när sidan [i]landar uppåt efter ett omkast[/i]. Den betalas inte ut för
##    rundans första kast, eftersom det skulle ge gratis omkast utan beslut.
## [br]2. En låst tärning ([code]LOCKED[/code]-sida, t.ex. Blysidan) räknas inte
##    som ett misslyckat omkast: den ligger kvar och de andra kastas ändå.

## Sant om tärningen får kastas om just nu.
## [param locked_ids] är tärningar spelaren själv låst (UI_GUIDE §4.5).
static func can_reroll(state: CombatState, placement: PackedInt32Array, die_index: int, locked_ids: Array = []) -> bool:
	if die_index < 0 or die_index >= state.dice.size():
		return false
	var die: Die = state.dice[die_index]
	if state.stolen.has(die.id):
		return false
	if locked_ids.has(die.id):
		return false
	for i: int in range(placement.size()):
		if placement[i] == die_index:
			return false  # Placerade tärningar är åtagna (UI_GUIDE §4.5).
	var face: Face = die.showing_face()
	return face == null or face.effect != Rules.FaceEffectKind.LOCKED


static func rerollable_indices(state: CombatState, placement: PackedInt32Array, locked_ids: Array = []) -> Array[int]:
	var result: Array[int] = []
	for i: int in range(state.dice.size()):
		if can_reroll(state, placement, i, locked_ids):
			result.append(i)
	return result


static func can_afford(state: CombatState) -> bool:
	return state.rerolls_left > 0


## Kastar om alla tillåtna tärningar och returnerar en KOPIA.
## Muterar aldrig indata, av samma skäl som [method Resolver.resolve].
## Returnerar en oförändrad kopia om det inte finns omkast kvar eller inget att
## kasta om, så att anroparen aldrig behöver felhantera.
static func apply(state: CombatState, placement: PackedInt32Array, rng: Rng, locked_ids: Array = []) -> CombatState:
	if not can_afford(state):
		return state.copy()
	var indices: Array[int] = rerollable_indices(state, placement, locked_ids)
	if indices.is_empty():
		return state.copy()

	var next: CombatState = state.copy()
	next.rerolls_left -= 1
	for index: int in indices:
		var die: Die = next.dice[index]
		die.roll(rng)
		var face: Face = die.showing_face()
		if face != null and face.effect == Rules.FaceEffectKind.REFUND_REROLL:
			next.rerolls_left += maxi(1, face.magnitude)
	return next
