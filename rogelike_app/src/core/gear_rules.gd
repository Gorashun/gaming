class_name GearRules
extends RefCounted
## Gear-effekternas regler. PROGRESSION_REDESIGN §3.2 (läsbarhetslagarna) och
## DECISIONS 2026-09-23.
##
## [b]Tre lagar, normativa:[/b]
## [br]1. Effekten syns i förhandsvisningen. Allt som ändrar en runda sker i
##    [method Resolver.resolve] och emitterar [code]gear_triggered[/code]; allt som
##    ändrar stridens start ([code]START_CHARGE[/code], omkast, en sjunde tärning)
##    sker i [method Resolver.begin_combat] och syns på rundan före första
##    bekräftelsen – och som [code]gear_triggered[/code] i runda 1:s kvitto.
## [br]2. Högst en ren stat-effekt per föremål, och bara på COMMON
##    ([constant STAT_KINDS], [method violates_stat_law]).
## [br]3. All gear-styrka är dödlig: den sitter på en hjälte i en run
##    ([member RunState.hero]) och riskeras varje gång.
##
## Den här filen är ren: inga Node-beroenden, ingen RNG.

# --- Effekttyper -------------------------------------------------------------
# Stat-effekter (lag 2: bara på COMMON, högst en per föremål).
const MAX_HP: String = "MAX_HP"
const COMBAT_REROLL: String = "COMBAT_REROLL"
const PLAYER_ARMOR: String = "PLAYER_ARMOR"
const WARD_ON_ROUND_START: String = "WARD_ON_ROUND_START"
# Regel-effekter.
const FIRST_ROUND_REROLL: String = "FIRST_ROUND_REROLL"
const PIP_BONUS: String = "PIP_BONUS"
const WARD_RETAIN: String = "WARD_RETAIN"
const CHARGE_IF_UNHURT: String = "CHARGE_IF_UNHURT"
const ANVIL_THRESHOLD: String = "ANVIL_THRESHOLD"
const LEFTMOST_BONUS: String = "LEFTMOST_BONUS"
const ARMOR_PIERCE_SLOT: String = "ARMOR_PIERCE_SLOT"
const ARMOR_PIERCE_BIGGEST: String = "ARMOR_PIERCE_BIGGEST"
const CHARGE_ON_KILL: String = "CHARGE_ON_KILL"
const OVERFLOW_IGNORES_ARMOR: String = "OVERFLOW_IGNORES_ARMOR"
const START_CHARGE: String = "START_CHARGE"
const FIRST_ROUND_EXTRA_DIE: String = "FIRST_ROUND_EXTRA_DIE"
const UNPLACED_CHARGE_BONUS: String = "UNPLACED_CHARGE_BONUS"
const CHARGE_CAP: String = "CHARGE_CAP"
const RESCUE_BONUS: String = "RESCUE_BONUS"
const DAMAGE_PER_KILL: String = "DAMAGE_PER_KILL"
const HOUSE_TWO_PAIR: String = "HOUSE_TWO_PAIR"
const EXTRA_SLOT: String = "EXTRA_SLOT"
## En omgjord relik: [code]{"kind": "RULE", "rule": "DOMINO"}[/code]. Resolverns
## gamla krok utlöses som om reliken låg i [member CombatState.relics].
const RULE: String = "RULE"
# Bara quirks.
const SLOT_BONUS: String = "SLOT_BONUS"
const CHARGE_PER_ROUND: String = "CHARGE_PER_ROUND"
const CHARGE_CAP_DELTA: String = "CHARGE_CAP_DELTA"

const STAT_KINDS: Array[String] = [MAX_HP, COMBAT_REROLL, PLAYER_ARMOR, WARD_ON_ROUND_START]

## Alla effekttyper resolvern eller run-flödet känner. Ett föremål med en okänd
## typ fäller [code]tests/test_gear.gd[/code].
const KNOWN_KINDS: Array[String] = [
	MAX_HP, COMBAT_REROLL, PLAYER_ARMOR, WARD_ON_ROUND_START, FIRST_ROUND_REROLL,
	PIP_BONUS, WARD_RETAIN, CHARGE_IF_UNHURT, ANVIL_THRESHOLD, LEFTMOST_BONUS,
	ARMOR_PIERCE_SLOT, ARMOR_PIERCE_BIGGEST, CHARGE_ON_KILL, OVERFLOW_IGNORES_ARMOR,
	START_CHARGE, FIRST_ROUND_EXTRA_DIE, UNPLACED_CHARGE_BONUS, CHARGE_CAP,
	RESCUE_BONUS, DAMAGE_PER_KILL, HOUSE_TWO_PAIR, EXTRA_SLOT, RULE,
	SLOT_BONUS, CHARGE_PER_ROUND, CHARGE_CAP_DELTA,
]

## Tärningen [code]PIT_STRIDERS[/code] lägger till i stridens första runda.
const EXTRA_DIE_ID: String = "die_striders"
## Brädets bas utan [code]EXTRA_SLOT[/code].
const BASE_SLOTS: int = Rules.SLOT_COUNT


## Lag 2 (§3.2). Sant om [param item] bryter mot den.
static func violates_stat_law(item: Item) -> bool:
	var stats: int = 0
	for effect: Dictionary in item.effects:
		if STAT_KINDS.has(String(effect.get("kind", ""))):
			stats += 1
	if stats == 0:
		return false
	return stats > 1 or item.rarity != Rules.Rarity.COMMON


## Effekterna i [param items] grupperade per typ. Varje post:
## [code]{item, name_key, effect, level}[/code]. Resolverns [code]Context[/code]
## bygger detta en gång per resolution.
static func index_effects(items: Array[Item]) -> Dictionary:
	var out: Dictionary = {}
	for item: Item in items:
		for effect: Dictionary in item.effects:
			var kind: String = String(effect.get("kind", ""))
			if not out.has(kind):
				out[kind] = [] as Array
			(out[kind] as Array).append({"item": item, "effect": effect})
	return out


## Summan av [param field] för alla effekter av typen [param kind].
static func total(items: Array[Item], kind: String, field: String = "amount") -> int:
	var sum: int = 0
	for item: Item in items:
		for effect: Dictionary in item.effects:
			if String(effect.get("kind", "")) == kind:
				sum += item.effect_value(effect, field)
	return sum


## Sant om någon effekt i [param items] är en omgjord relik med regeln [param rule].
static func has_rule(items: Array[Item], rule: String) -> bool:
	for item: Item in items:
		for effect: Dictionary in item.effects:
			if String(effect.get("kind", "")) == RULE and String(effect.get("rule", "")) == rule:
				return true
	return false


## Föremålet som bär regeln, eller null.
static func item_with_rule(items: Array[Item], rule: String) -> Item:
	for item: Item in items:
		for effect: Dictionary in item.effects:
			if String(effect.get("kind", "")) == RULE and String(effect.get("rule", "")) == rule:
				return item
	return null


## Charge-taket med gear och quirk inräknade. Aldrig under 1.
static func charge_cap(items: Array[Item]) -> int:
	var cap: int = Rules.CHARGE_CAP
	for item: Item in items:
		for effect: Dictionary in item.effects:
			if String(effect.get("kind", "")) == CHARGE_CAP:
				cap = maxi(cap, item.effect_value(effect, "value"))
	cap += total(items, CHARGE_CAP_DELTA)
	return maxi(1, cap)


## Amboss-tröskeln med gear inräknat (lägsta vinner). [code]TONG_GLOVES[/code].
static func anvil_threshold(items: Array[Item]) -> int:
	var threshold: int = Rules.ANVIL_THRESHOLD
	for item: Item in items:
		for effect: Dictionary in item.effects:
			if String(effect.get("kind", "")) == ANVIL_THRESHOLD:
				threshold = mini(threshold, item.effect_value(effect, "value"))
	return maxi(1, threshold)


## Antal slots brädet ska ha med [param items].
static func board_size(items: Array[Item]) -> int:
	return BASE_SLOTS + maxi(0, total(items, EXTRA_SLOT))


# ---------------------------------------------------------------------------
# Hjälte ↔ strid
# ---------------------------------------------------------------------------

## Det [CombatState] ska bära för [param hero]: det burna plus quirken.
static func combat_items(hero: Hero) -> Array[Item]:
	var out: Array[Item] = []
	if hero == null:
		return out
	for item: Item in hero.equipped_items():
		out.append(item.copy())
	var quirk: Item = Content.quirk_item(hero.quirk)
	if quirk != null:
		out.append(quirk)
	return out


## Lägger [param hero]:s utrustning på en kopia av [param state]. Anropas när
## runnen börjar och varje gång hjälten byter plagg. Ren funktion.
##
## [b]Max-HP följer med plagget:[/b] skillnaden mellan det gamla och det nya
## [code]MAX_HP[/code]-tillägget läggs på både max och nuvarande HP (aldrig
## under 1). [b]Brädet följer med:[/b] [code]EXTRA_SLOT[/code] lägger till
## PLAIN-slots sist, och tar bara bort slots den själv lagt till.
static func sync_combat(state: CombatState, hero: Hero) -> CombatState:
	var next: CombatState = state.copy()
	var items: Array[Item] = combat_items(hero)
	var hp_before: int = total(state.gear, MAX_HP)
	var hp_after: int = total(items, MAX_HP)
	var delta: int = hp_after - hp_before
	next.gear = items
	if delta != 0:
		next.player_max_hp = maxi(1, next.player_max_hp + delta)
		next.player_hp = clampi(next.player_hp + delta, 1, next.player_max_hp)
	_resize_board(next, board_size(items))
	return next


static func _resize_board(state: CombatState, wanted: int) -> void:
	var size: int = state.board.size()
	if size == wanted:
		return
	if size < wanted:
		for i: int in range(size, wanted):
			state.board.slots.append(Slot.new(i, Rules.SlotType.PLAIN))
	else:
		while state.board.size() > maxi(wanted, BASE_SLOTS):
			state.board.slots.remove_at(state.board.size() - 1)
	var placement: PackedInt32Array = CombatState.empty_placement(state.board.size())
	for i: int in range(mini(placement.size(), state.placement.size())):
		placement[i] = state.placement[i]
	state.placement = placement


## Var ett nytt föremål hamnar om spelaren tar det:
## [code]{slot, to_pack, replaces, replaces_key}[/code]. En låst slot betyder
## packningen; en upptagen slot betyder att det gamla plagget går till packningen.
static func equip_target(hero: Hero, item: Item) -> Dictionary:
	if hero == null or item == null:
		return {"slot": item.slot if item != null else "", "to_pack": true, "replaces": "", "replaces_key": ""}
	if not hero.is_slot_unlocked(item.slot):
		return {"slot": item.slot, "to_pack": true, "replaces": "", "replaces_key": "",
			"unlock_level": Hero.level_for_slot(item.slot)}
	var worn: Item = hero.equipped(item.slot)
	return {
		"slot": item.slot,
		"to_pack": false,
		"replaces": worn.id if worn != null else "",
		"replaces_key": worn.name_key if worn != null else "",
	}


## Tar ett föremål i en run: på kroppen om sloten är öppen (det gamla plagget
## till packningen), annars i packningen. Uppdaterar [code]run.combat[/code].
## Föremålet är osäkrat från och med nu.
static func take_item(run: RunState, item: Item) -> void:
	if run == null or item == null:
		return
	var taken: Item = item.copy()
	taken.secured = false
	if run.hero == null:
		run.pack.append(taken)
		return
	var replaced: Item = run.hero.equip(taken)
	if replaced == taken:
		run.pack.append(taken)
	elif replaced != null:
		replaced.secured = false
		run.pack.append(replaced)
	if run.combat != null:
		run.combat = sync_combat(run.combat, run.hero)


## Hur många föremål som räddas vid död: Kistans nivå plus
## [code]RESCUE_BONUS[/code] på det hjälten bär ([code]MARROWS_TARP[/code]).
## Räddningsannonsen läggs till av anroparen.
static func rescue_slots(chest_level: int, hero: Hero) -> int:
	var bonus: int = 0
	if hero != null:
		bonus = total(hero.equipped_items(), RESCUE_BONUS)
	return Chest.rescue_capacity(chest_level) + bonus
