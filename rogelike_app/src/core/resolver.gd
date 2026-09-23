class_name Resolver
extends RefCounted
## Stridsresolvern. Implementerar docs/GAME_DESIGN.md §2 (fasordning P0–P5) och
## §3 (händelselogg-format) rakt av.
##
## [b]Helig regel (GAME_DESIGN §6):[/b] [method resolve] tar ingen RNG, har inte
## tillgång till en, och muterar aldrig sitt indata. Samma [param state] och
## [param placement] ger byte-identisk händelselogg. All slump som behövs för
## NÄSTA runda dras i [method advance], som körs innan spelaren bekräftar.
##
## [b]Tolkningar där specen var tyst eller tvetydig[/b] (rapporterade till PM,
## ändra bara via docs/DECISIONS.md):
## [br]1. [code]MIRROR[/code]/[code]COPY_LEFT[/code]: specens pseudokod emitterar
##    både [code]slot_modifier_failed[/code] och [code]slot_modifier[/code] när
##    vänstergrannen saknas. Vi emitterar ENDAST [code]slot_modifier_failed[/code]
##    i det fallet (reason NO_LEFT_NEIGHBOUR för slot 0, LEFT_NEIGHBOUR_EMPTY när
##    grannen är tom/blockerad) och endast [code]slot_modifier[/code] när ett
##    verkligt värde kopierades. Värdet blir [code]0 + bonus[/code] som i §2.4
##    exempel 2.
## [br]2. [code]HOUSE[/code] kräver enligt §2.4 exempel 5 en grupp av storlek 3
##    och en av storlek 2. Vi testar "minst en grupp >= 3 OCH en ANNAN grupp >= 2".
##    På ett 5-slots bräde är detta identiskt med den strikta läsningen.
## [br]3. [code]BLOOD_PRICE[/code] kan döda spelaren. Specen säger inget; vi
##    emitterar [code]player_died[/code] och avbryter, så att invariant 3
##    ("inga event efter player_died") alltid håller.
## [br]4. [code]DOMINO[/code]-upprepningen går genom samma slot-typshantering som
##    ett vanligt slag, så en [code]VOID[/code]-granne ger Ward och en
##    [code]CHARGE[/code]-granne ger Charge i stället för skada.
## [br]5. [code]CRACK_BITE[/code]: specen säger "för resten av runden" men §7 fråga
##    2 kontrasterar rundbaserat mot run-permanent. Vi låter sprickan gälla
##    resten av STRIDEN och återställa vid [method end_combat]. Behöver PM-beslut.
## [br]6. [code]GRAB[/code]-blockeringen gäller exakt en runda: P5 nollställer alla
##    [code]blocked[/code]-flaggor innan nya specials körs.
## [br]7. Dödas en fiende med specialen [code]STEAL[/code] återlämnas alla
##    tärningar den stulit omedelbart ([code]die_returned[/code]).
##
## [b]M6: gear-effekter[/b] ([GearRules], PROGRESSION_REDESIGN §3.2). Varje effekt
## som ändrar rundan emitterar [code]gear_triggered{item, name_key, effect,
## detail}[/code] [i]innan[/i] eventet den påverkar, så att kvittot kan skriva
## "Ögonlinsen: +1 på 1:or" på rätt rad. Ingen effekt drar slump; allt syns i
## förhandsvisningen. Utan gear är loggen byte-identisk med M5:s. Tolkningar:
## [br]8. [code]THIEFS_MITTS[/code] ("första tärningen du placerar") läses som
##    vänstraste besatta slot – resolvern ser en placering, inte en ordning.
## [br]9. [code]PLAYER_ARMOR[/code] dras efter Ward, per attack.
## [br]10. [code]DAMAGE_PER_KILL[/code] räknar dödade i striden [i]så här långt[/i],
##    även tidigare i samma kedja, och läggs på slagets belopp före rustning.
## [br]11. [code]WARD_RETAIN[/code] behåller floor(ward × procent / 100) över
##    [code]round_end[/code]; [code]round_start.ward_in[/code] visar det.

## Händelsetypernas rekommenderade uppspelningstid i ms (GAME_DESIGN §3).
const MS_HINTS: Dictionary = {
	"die_activated": 220,
	"slot_modifier": 260,
	"combo_formed": 320,
	"house_bonus": 420,
	"strike": 180,
	"damage_dealt": 300,
	"enemy_killed": 380,
	"charge_stored": 160,
	"enemy_attacks": 320,
}
const MS_HINT_DEFAULT: int = 120

const RELIC_BLOOD_PRICE: String = "BLOOD_PRICE"
const RELIC_BROKEN_SCALE: String = "BROKEN_SCALE"
const RELIC_OCTOPUS: String = "OCTOPUS"
const RELIC_ECHO_MIRROR: String = "ECHO_MIRROR"
const RELIC_CHEAT_CUBE: String = "CHEAT_CUBE"
const RELIC_DOMINO: String = "DOMINO"
const RELIC_ANVIL_BLESSING: String = "ANVIL_BLESSING"

const BLOOD_PRICE_HP_COST: int = 4
const BLOOD_PRICE_FACTOR: int = 2
const FIRE_BURN_STACKS: int = 2
const DRAIN_CHARGE_AMOUNT: int = 3
const CRACKED_FACE_ID: String = "CRACKED"


## Intern arbetsyta för en enda resolution. Håller loggen, seq-räknaren och den
## muterbara kopian av tillståndet, så att inga globala variabler behövs.
class Context:
	extends RefCounted

	var state: CombatState
	var placement: PackedInt32Array
	var events: Array[Dictionary] = []
	var seq: int = 0
	## Sätts när player_died emitterats. Inga fler event får läggas till.
	var aborted: bool = false

	var bonus: Array[int] = []
	var values: Array[int] = []
	var occupied: Array[bool] = []
	var multiplier: Array[int] = []
	## amount per slot efter P3, för DOMINO.
	var amounts: Array[int] = []
	var groups: Array = []
	## M6: gear-effekter per typ ([method GearRules.index_effects]) och
	## omgjorda reliker (regel-id → föremål).
	var fx: Dictionary = {}
	var rule_items: Dictionary = {}
	var charge_cap: int = Rules.CHARGE_CAP
	var anvil_threshold: int = Rules.ANVIL_THRESHOLD
	## Skada spelaren tagit denna runda (KILN_VEST).
	var damage_taken: int = 0
	## Sloten vars slag är rundans största (SPIKE_MAUL), eller -1.
	var biggest_slot: int = -1

	func _init(p_state: CombatState, p_placement: PackedInt32Array) -> void:
		state = p_state
		placement = p_placement
		if not p_state.gear.is_empty():
			fx = GearRules.index_effects(p_state.gear)
			for entry: Variant in fx.get(GearRules.RULE, []) as Array:
				var rule: String = String(((entry as Dictionary)["effect"] as Dictionary).get("rule", ""))
				rule_items[rule] = (entry as Dictionary)["item"]
			charge_cap = GearRules.charge_cap(p_state.gear)
			anvil_threshold = GearRules.anvil_threshold(p_state.gear)
		var n: int = p_state.board.size()
		bonus.resize(n)
		values.resize(n)
		occupied.resize(n)
		multiplier.resize(n)
		amounts.resize(n)
		for i: int in range(n):
			bonus[i] = 0
			values[i] = 0
			occupied[i] = false
			multiplier[i] = 1
			amounts[i] = 0

	func emit(t: String, fields: Dictionary = {}) -> void:
		if aborted:
			return
		var event: Dictionary = {
			"t": t,
			"seq": seq,
			"ms_hint": int(MS_HINTS.get(t, MS_HINT_DEFAULT)),
		}
		# merge() är ett enda motoranrop; en GDScript-loop här kostade mätbart
		# i run-simulatorn, som gör hundratusentals emit per körning.
		event.merge(fields)
		events.append(event)
		seq += 1

	func has_relic(id: String) -> bool:
		return rule_items.has(id) or Relic.has_relic(state.relics, id)

	func has_fx(kind: String) -> bool:
		return fx.has(kind)

	func fx_of(kind: String) -> Array:
		return fx.get(kind, []) as Array

	## Emitterar [code]gear_triggered[/code] för ett indexerat effekt-uppslag.
	func gear(entry: Dictionary, detail: Dictionary) -> void:
		var item: Item = entry["item"] as Item
		emit("gear_triggered", {
			"item": item.id,
			"name_key": item.name_key,
			"effect": String((entry["effect"] as Dictionary).get("kind", "")),
			"detail": detail,
		})

	## [code]relic_triggered[/code]-fälten, med föremålet när regeln bärs som gear.
	func relic_fields(id: String, detail: Dictionary) -> Dictionary:
		var fields: Dictionary = {"relic": id, "detail": detail}
		if rule_items.has(id):
			var item: Item = rule_items[id] as Item
			fields["item"] = item.id
			fields["name_key"] = item.name_key
		return fields


## Resolvar en runda. Ren funktion: ingen RNG, inga sidoeffekter på [param state].
static func resolve(state: CombatState, placement: PackedInt32Array) -> ResolveResult:
	var working: CombatState = state.copy()
	var normalized: PackedInt32Array = _normalize_placement(placement, working.board.size())
	working.placement = normalized.duplicate()

	var ctx: Context = Context.new(working, normalized)
	_phase_round_start(ctx)
	if not ctx.aborted:
		_phase_value_pass(ctx)
	if not ctx.aborted:
		_phase_combo_pass(ctx)
	if not ctx.aborted:
		_phase_strike_pass(ctx)
	if not ctx.aborted:
		_phase_enemy_pass(ctx)
	if not ctx.aborted:
		_phase_round_end(ctx)
	return ResolveResult.new(ctx.events, ctx.state)


static func _normalize_placement(placement: PackedInt32Array, slot_count: int) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	result.resize(slot_count)
	for i: int in range(slot_count):
		result[i] = placement[i] if i < placement.size() else -1
	return result


# ---------------------------------------------------------------------------
# P0 – ROUND_START
# ---------------------------------------------------------------------------
static func _phase_round_start(ctx: Context) -> void:
	var state: CombatState = ctx.state
	var round_fields: Dictionary = {
		"round": state.round_number,
		"charge_in": state.charge,
		"player_hp": state.player_hp,
	}
	if state.ward > 0:
		round_fields["ward_in"] = state.ward
	ctx.emit("round_start", round_fields)
	if not ctx.fx.is_empty():
		_gear_round_start(ctx)
	_apply_charge_bonus(ctx)
	if not ctx.fx.is_empty():
		_gear_slot_bonuses(ctx)


static func _apply_charge_bonus(ctx: Context) -> void:
	var state: CombatState = ctx.state
	if state.charge <= 0:
		return
	# Vänstraste BESATTA slot, inte slot 0: spelaren ska aldrig förlora sin bank
	# på en teknikalitet (GAME_DESIGN §2.3 P0, [BESLUT v1]).
	var target: int = -1
	for i: int in range(state.board.size()):
		if ctx.placement[i] != -1 and not state.board.slots[i].blocked:
			target = i
			break
	if target < 0:
		ctx.emit("charge_held", {"amount": state.charge})
		return
	ctx.bonus[target] = state.charge
	ctx.emit("charge_applied", {"slot": target, "amount": state.charge})
	state.charge = 0


## Stridens passiva gear (runda 1) och rundans Ward-tillskott. Passiva effekter
## ändrar ingenting här – de verkade redan i [method begin_combat] eller i
## [method GearRules.sync_combat] – men de ska synas i kvittot (§3.2 lag 1).
const _PASSIVE_KINDS: Array[String] = [
	GearRules.MAX_HP, GearRules.COMBAT_REROLL, GearRules.FIRST_ROUND_REROLL,
	GearRules.START_CHARGE, GearRules.FIRST_ROUND_EXTRA_DIE, GearRules.EXTRA_SLOT,
	GearRules.CHARGE_CAP, GearRules.CHARGE_CAP_DELTA, GearRules.RESCUE_BONUS,
]


static func _gear_round_start(ctx: Context) -> void:
	var state: CombatState = ctx.state
	if state.round_number == 1:
		for kind: String in _PASSIVE_KINDS:
			for entry: Variant in ctx.fx_of(kind):
				var e: Dictionary = entry as Dictionary
				var item: Item = e["item"] as Item
				var effect: Dictionary = e["effect"] as Dictionary
				var detail: Dictionary = {"passive": true, "amount": item.effect_value(effect)}
				if kind == GearRules.CHARGE_CAP or kind == GearRules.CHARGE_CAP_DELTA:
					detail["cap"] = ctx.charge_cap
				ctx.gear(e, detail)
	for entry: Variant in ctx.fx_of(GearRules.WARD_ON_ROUND_START):
		var e: Dictionary = entry as Dictionary
		var amount: int = (e["item"] as Item).effect_value(e["effect"] as Dictionary)
		if amount <= 0:
			continue
		state.ward += amount
		ctx.gear(e, {"amount": amount, "ward_total": state.ward})
		# slot -1: Ward som inte kom ur ett slag. Kvittots RÅ-summa räknar den inte.
		ctx.emit("ward_gained", {"slot": -1, "amount": amount, "ward_total": state.ward, "source": "GEAR"})


## Vänstraste besatta slot, eller -1.
static func _leftmost_occupied(ctx: Context) -> int:
	for i: int in range(ctx.state.board.size()):
		if ctx.placement[i] != -1 and not ctx.state.board.slots[i].blocked:
			return i
	return -1


## THIEFS_MITTS och RIGHT_HANDED: ögon på en besatt slot, som Charge.
static func _gear_slot_bonuses(ctx: Context) -> void:
	var state: CombatState = ctx.state
	var leftmost: int = _leftmost_occupied(ctx)
	for entry: Variant in ctx.fx_of(GearRules.LEFTMOST_BONUS):
		var e: Dictionary = entry as Dictionary
		var amount: int = (e["item"] as Item).effect_value(e["effect"] as Dictionary)
		if leftmost < 0 or amount == 0:
			continue
		ctx.bonus[leftmost] += amount
		ctx.gear(e, {"slot": leftmost, "amount": amount})
	for entry: Variant in ctx.fx_of(GearRules.SLOT_BONUS):
		var e: Dictionary = entry as Dictionary
		var effect: Dictionary = e["effect"] as Dictionary
		var slot: int = int(effect.get("slot", -1))
		var amount: int = (e["item"] as Item).effect_value(effect)
		if slot < 0 or slot >= state.board.size() or amount == 0:
			continue
		if ctx.placement[slot] == -1 or state.board.slots[slot].blocked:
			continue
		ctx.bonus[slot] += amount
		ctx.gear(e, {"slot": slot, "amount": amount})


# ---------------------------------------------------------------------------
# P1 – VALUE PASS
# ---------------------------------------------------------------------------
static func _phase_value_pass(ctx: Context) -> void:
	var state: CombatState = ctx.state
	for i: int in range(state.board.size()):
		var slot: Slot = state.board.slots[i]
		if slot.blocked or ctx.placement[i] == -1:
			ctx.values[i] = 0
			ctx.occupied[i] = false
			ctx.emit("slot_empty", {"slot": i, "reason": "BLOCKED" if slot.blocked else "NO_DIE"})
			continue

		ctx.occupied[i] = true
		var die: Die = state.dice[ctx.placement[i]]
		var face: Face = die.showing_face()
		ctx.emit("die_activated", {
			"slot": i,
			"die_id": die.id,
			"face_index": die.showing,
			"base_value": face.value,
			"face_id": face.id,
		})

		var v: int = face.value + ctx.bonus[i]
		if ctx.has_fx(GearRules.PIP_BONUS):
			v = _gear_pip_bonus(ctx, i, face.value, v)

		# Steg 1 – kopiering. Sidan (COPY_LEFT) prövas före sloten (MIRROR);
		# en slot kan bara ha en typ, så högst en av dem kan lyckas ändra v.
		if face.effect == Rules.FaceEffectKind.COPY_LEFT:
			v = _apply_copy_left(ctx, i, "COPY_LEFT", face.value)
		if slot.type == Rules.SlotType.MIRROR:
			v = _apply_copy_left(ctx, i, "MIRROR", face.value)

		# Steg 2 – relik BROKEN_SCALE: udda effektiva värden rundas upp.
		if ctx.has_relic(RELIC_BROKEN_SCALE) and v % 2 != 0:
			v += 1
			ctx.emit("relic_triggered", ctx.relic_fields(RELIC_BROKEN_SCALE, {"slot": i, "value_after": v}))

		# Steg 3 – dubbling. Slot före sida, varje källa prövas EN gång.
		if slot.type == Rules.SlotType.ANVIL:
			v = _apply_anvil(ctx, i, "ANVIL", v)
		if face.effect == Rules.FaceEffectKind.ANVIL_SELF:
			v = _apply_anvil(ctx, i, "ANVIL_SELF", v)

		ctx.values[i] = v

	ctx.emit("value_pass_done", {
		"values": ctx.values.duplicate(),
		"occupied": ctx.occupied.duplicate(),
	})


## PIPSIGHT_LENS och HEAVY_HANDED: sidans egna ögon, före kopiering och dubbling.
static func _gear_pip_bonus(ctx: Context, i: int, face_value: int, v: int) -> int:
	for entry: Variant in ctx.fx_of(GearRules.PIP_BONUS):
		var e: Dictionary = entry as Dictionary
		var effect: Dictionary = e["effect"] as Dictionary
		if int(effect.get("face_value", -1)) != face_value:
			continue
		var amount: int = (e["item"] as Item).effect_value(effect)
		if amount == 0:
			continue
		var after: int = maxi(0, v + amount)
		ctx.gear(e, {"slot": i, "face_value": face_value, "amount": amount,
			"value_before": v, "value_after": after})
		v = after
	return v


static func _apply_copy_left(ctx: Context, i: int, modifier: String, value_before: int) -> int:
	# Vänstergrannens EFFEKTIVA värde, inte dess sida. En spegel som speglar en
	# spegel kedjar därför korrekt eftersom P1 går vänster→höger.
	var source: int = ctx.values[i - 1] if i > 0 else 0
	var result: int = source + ctx.bonus[i]
	if i == 0:
		ctx.emit("slot_modifier_failed", {"slot": i, "modifier": modifier, "reason": "NO_LEFT_NEIGHBOUR"})
		return result
	if not ctx.occupied[i - 1]:
		ctx.emit("slot_modifier_failed", {"slot": i, "modifier": modifier, "reason": "LEFT_NEIGHBOUR_EMPTY"})
		return result
	ctx.emit("slot_modifier", {
		"slot": i,
		"modifier": modifier,
		"value_before": value_before,
		"value_after": result,
	})
	return result


static func _apply_anvil(ctx: Context, i: int, modifier: String, v: int) -> int:
	if v < ctx.anvil_threshold:
		var failed: Dictionary = {"slot": i, "modifier": modifier, "reason": "VALUE_BELOW_5"}
		if ctx.anvil_threshold != Rules.ANVIL_THRESHOLD:
			failed["threshold"] = ctx.anvil_threshold
		ctx.emit("slot_modifier_failed", failed)
		return v
	if v < Rules.ANVIL_THRESHOLD:
		# Bara tånghandskarna gjorde det här möjligt: säg det före dubblingen.
		for entry: Variant in ctx.fx_of(GearRules.ANVIL_THRESHOLD):
			ctx.gear(entry as Dictionary, {"slot": i, "value": v, "threshold": ctx.anvil_threshold})
			break
	var after: int = v * 2
	ctx.emit("slot_modifier", {
		"slot": i,
		"modifier": modifier,
		"value_before": v,
		"value_after": after,
	})
	return after


# ---------------------------------------------------------------------------
# P2 – COMBO PASS
# ---------------------------------------------------------------------------
static func _phase_combo_pass(ctx: Context) -> void:
	var n: int = ctx.state.board.size()
	var eligible: Array[bool] = []
	eligible.resize(n)
	for i: int in range(n):
		eligible[i] = ctx.occupied[i] and ctx.values[i] > 0

	# Angränsningsgraf: (i, i+1). OCTOPUS lägger till den virtuella kanten (1,3).
	var edges: Array = []
	for i: int in range(n - 1):
		edges.append([i, i + 1])
	if ctx.has_relic(RELIC_OCTOPUS) and n > 3:
		edges.append([1, 3])

	var parent: Array[int] = []
	parent.resize(n)
	for i: int in range(n):
		parent[i] = i
	for edge: Variant in edges:
		var a: int = int((edge as Array)[0])
		var b: int = int((edge as Array)[1])
		if eligible[a] and eligible[b] and ctx.values[a] == ctx.values[b]:
			_union(parent, a, b)

	var members: Dictionary = {}
	for i: int in range(n):
		if not eligible[i]:
			continue
		var root: int = _find(parent, i)
		if not members.has(root):
			members[root] = [] as Array[int]
		(members[root] as Array[int]).append(i)

	var groups: Array = []
	for root: Variant in members:
		var slots: Array[int] = members[root] as Array[int]
		if slots.size() < 2:
			continue
		slots.sort()
		groups.append({
			"slots": slots,
			"value": ctx.values[slots[0]],
			"size": slots.size(),
			"multiplier": Rules.multiplier_for_size(slots.size()),
		})
	# Insertionssortering på lägsta slotindex. Grupperna är som mest två stycken,
	# och att slippa en lambda per runda syns i simulatorns körtid.
	for i: int in range(1, groups.size()):
		var current: Dictionary = groups[i] as Dictionary
		var key: int = ((current["slots"] as Array[int])[0])
		var j: int = i - 1
		while j >= 0 and int(((groups[j] as Dictionary)["slots"] as Array[int])[0]) > key:
			groups[j + 1] = groups[j]
			j -= 1
		groups[j + 1] = current
	ctx.groups = groups

	for group: Variant in groups:
		var g: Dictionary = group as Dictionary
		ctx.emit("combo_formed", {
			"kind": Rules.combo_kind_name(Rules.combo_kind_for_size(int(g["size"]))),
			"multiplier": int(g["multiplier"]),
			"slots": (g["slots"] as Array[int]).duplicate(),
			"value": int(g["value"]),
		})

	# HOUSE (kåk) på brädnivå: minst en grupp >= 3 och en ANNAN grupp >= 2.
	# M6: TWIN_PIP låter två par räcka. Gear-eventet kommer bara när det var
	# föremålet, och inte grundregeln, som gav kåken.
	var house: bool = _has_house(groups)
	if not house and ctx.has_fx(GearRules.HOUSE_TWO_PAIR) and _pair_count(groups) >= 2:
		house = true
		ctx.gear(ctx.fx_of(GearRules.HOUSE_TWO_PAIR)[0] as Dictionary, {"groups": groups.size()})
	if house:
		for group: Variant in groups:
			(group as Dictionary)["multiplier"] = int((group as Dictionary)["multiplier"]) * Rules.HOUSE_FACTOR
		_write_multipliers(ctx, groups)
		var group_slots: Array = []
		for group: Variant in groups:
			group_slots.append(((group as Dictionary)["slots"] as Array[int]).duplicate())
		ctx.emit("house_bonus", {
			"groups": group_slots,
			"factor": Rules.HOUSE_FACTOR,
			"multipliers_after": ctx.multiplier.duplicate(),
		})

	# BLOOD_PRICE: betalas bara när det lönar sig, dvs. när ett combo finns.
	if ctx.has_relic(RELIC_BLOOD_PRICE) and not groups.is_empty():
		for group: Variant in groups:
			(group as Dictionary)["multiplier"] = int((group as Dictionary)["multiplier"]) * BLOOD_PRICE_FACTOR
		_write_multipliers(ctx, groups)
		ctx.emit("relic_triggered", ctx.relic_fields(RELIC_BLOOD_PRICE,
			{"hp_cost": BLOOD_PRICE_HP_COST, "multipliers_after": ctx.multiplier.duplicate()}))
		ctx.state.player_hp -= BLOOD_PRICE_HP_COST
		ctx.damage_taken += BLOOD_PRICE_HP_COST
		ctx.emit("player_damaged", {
			"amount": BLOOD_PRICE_HP_COST,
			"source": RELIC_BLOOD_PRICE,
			"player_hp_after": ctx.state.player_hp,
		})
		if ctx.state.player_hp <= 0:
			_kill_player(ctx, RELIC_BLOOD_PRICE)
			return

	_write_multipliers(ctx, groups)


static func _pair_count(groups: Array) -> int:
	var count: int = 0
	for group: Variant in groups:
		if int((group as Dictionary)["size"]) >= 2:
			count += 1
	return count


static func _has_house(groups: Array) -> bool:
	var big: int = -1
	for i: int in range(groups.size()):
		if int((groups[i] as Dictionary)["size"]) >= 3:
			big = i
			break
	if big < 0:
		return false
	for i: int in range(groups.size()):
		if i != big and int((groups[i] as Dictionary)["size"]) >= 2:
			return true
	return false


static func _write_multipliers(ctx: Context, groups: Array) -> void:
	for i: int in range(ctx.multiplier.size()):
		ctx.multiplier[i] = 1
	for group: Variant in groups:
		var g: Dictionary = group as Dictionary
		for slot_index: int in (g["slots"] as Array[int]):
			ctx.multiplier[slot_index] = int(g["multiplier"])


static func _find(parent: Array[int], i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


static func _union(parent: Array[int], a: int, b: int) -> void:
	var ra: int = _find(parent, a)
	var rb: int = _find(parent, b)
	if ra == rb:
		return
	if ra < rb:
		parent[rb] = ra
	else:
		parent[ra] = rb


# ---------------------------------------------------------------------------
# P3 – STRIKE PASS
# ---------------------------------------------------------------------------
static func _phase_strike_pass(ctx: Context) -> void:
	var state: CombatState = ctx.state
	if ctx.has_fx(GearRules.ARMOR_PIERCE_BIGGEST):
		ctx.biggest_slot = _biggest_hit_slot(ctx)
	for i: int in range(state.board.size()):
		if ctx.aborted:
			return
		if not ctx.occupied[i]:
			continue
		var amount: int = ctx.values[i] * ctx.multiplier[i]
		if ctx.has_fx(GearRules.DAMAGE_PER_KILL):
			amount += _gear_kill_bonus(ctx, i, amount)
		ctx.amounts[i] = amount
		ctx.emit("strike", {"slot": i, "amount": amount, "multiplier": ctx.multiplier[i]})
		_resolve_strike_amount(ctx, i, amount)

	if not ctx.aborted and ctx.has_relic(RELIC_DOMINO):
		_apply_domino(ctx)


## Rundans största träff: högst [code]värde × multiplikator[/code] bland slots som
## slår (inte VOID/CHARGE), lägst index vid lika. -1 om ingen slår.
static func _biggest_hit_slot(ctx: Context) -> int:
	var best: int = -1
	var best_amount: int = 0
	for i: int in range(ctx.state.board.size()):
		if not ctx.occupied[i]:
			continue
		var type: int = ctx.state.board.slots[i].type
		if type == Rules.SlotType.VOID or type == Rules.SlotType.CHARGE:
			continue
		var amount: int = ctx.values[i] * ctx.multiplier[i]
		if amount > best_amount:
			best_amount = amount
			best = i
	return best


## BONE_TALLY: +N per fiende som redan dött i striden, på slag som gör skada.
static func _gear_kill_bonus(ctx: Context, i: int, amount: int) -> int:
	var state: CombatState = ctx.state
	if state.kills <= 0 or amount <= 0:
		return 0
	var type: int = state.board.slots[i].type
	if type == Rules.SlotType.VOID or type == Rules.SlotType.CHARGE:
		return 0
	var bonus: int = 0
	for entry: Variant in ctx.fx_of(GearRules.DAMAGE_PER_KILL):
		var e: Dictionary = entry as Dictionary
		var extra: int = (e["item"] as Item).effect_value(e["effect"] as Dictionary) * state.kills
		if extra <= 0:
			continue
		bonus += extra
		ctx.gear(e, {"slot": i, "amount": extra, "kills": state.kills})
	return bonus


## Hur mycket rustning slaget från [param slot_index] ignorerar mot första målet.
static func _gear_pierce(ctx: Context, slot_index: int) -> Array:
	var sources: Array = []
	for entry: Variant in ctx.fx_of(GearRules.ARMOR_PIERCE_SLOT):
		var e: Dictionary = entry as Dictionary
		if int((e["effect"] as Dictionary).get("slot", -1)) == slot_index:
			sources.append(e)
	if slot_index == ctx.biggest_slot:
		sources.append_array(ctx.fx_of(GearRules.ARMOR_PIERCE_BIGGEST))
	return sources


## Skickar ett slagbelopp genom sloten: VOID → Ward, CHARGE → Charge, annars skada.
static func _resolve_strike_amount(ctx: Context, i: int, amount: int) -> void:
	var slot: Slot = ctx.state.board.slots[i]
	if slot.type == Rules.SlotType.VOID:
		ctx.state.ward += amount
		ctx.emit("ward_gained", {"slot": i, "amount": amount, "ward_total": ctx.state.ward})
		return
	if slot.type == Rules.SlotType.CHARGE:
		_store_charge(ctx, amount, "CHARGE_SLOT")
		return
	if amount == 0:
		return  # Fizzle. die_activated och strike har redan ritats.
	_apply_damage(ctx, i, amount)


static func _apply_domino(ctx: Context) -> void:
	# Sloten med högst amount, lägst index vid lika.
	var source: int = -1
	for i: int in range(ctx.amounts.size()):
		if not ctx.occupied[i]:
			continue
		if source < 0 or ctx.amounts[i] > ctx.amounts[source]:
			source = i
	if source < 0:
		return
	var repeat: int = source + 1
	if repeat >= ctx.occupied.size() or not ctx.occupied[repeat]:
		return
	var extra: int = int(floor(float(ctx.amounts[repeat]) / 2.0))
	ctx.emit("relic_triggered", ctx.relic_fields(RELIC_DOMINO,
		{"source_slot": source, "repeat_slot": repeat, "amount": extra}))
	if extra > 0:
		_resolve_strike_amount(ctx, repeat, extra)


## Överflödsalgoritmen, GAME_DESIGN §2.3 P3 (normativ).
static func _apply_damage(ctx: Context, slot_index: int, incoming: int) -> void:
	var state: CombatState = ctx.state
	var hop: int = 0
	var pierce_sources: Array = _gear_pierce(ctx, slot_index) if not ctx.fx.is_empty() else []
	while incoming > 0 and not ctx.aborted:
		var target: Enemy = state.front_enemy()
		if target == null:
			ctx.emit("overflow_wasted", {"slot": slot_index, "amount": incoming})
			_store_charge(ctx, incoming / Rules.OVERFLOW_TO_CHARGE, "OVERFLOW")
			return

		var armor: int = target.armor
		if armor > 0 and not ctx.fx.is_empty():
			armor = _gear_armor(ctx, slot_index, target, hop, pierce_sources, incoming)
		hop += 1
		var effective: int = maxi(0, incoming - armor)
		var blocked: int = incoming - effective
		var dealt: int = mini(effective, target.hp)
		target.hp -= dealt
		state.total_damage += dealt
		var overflow: int = effective - dealt

		ctx.emit("damage_dealt", {
			"slot": slot_index,
			"target": target.id,
			"amount": dealt,
			"blocked": blocked,
			"overflow": overflow,
			"target_hp_after": target.hp,
		})

		if dealt > 0:
			_on_hit_effects(ctx, slot_index, target)
			if target.thorns > 0:
				state.player_hp -= target.thorns
				ctx.damage_taken += target.thorns
				ctx.emit("enemy_thorns", {
					"enemy": target.id,
					"amount": target.thorns,
					"player_hp_after": state.player_hp,
				})
				if state.player_hp <= 0:
					_kill_player(ctx, target.id)
					return

		if target.hp <= 0:
			_on_enemy_killed(ctx, target, slot_index)

		incoming = overflow


## Rustningen slaget faktiskt möter, med gear inräknat. Emitterar ett
## [code]gear_triggered[/code] per föremål som tog bort rustning som annars hade
## ätit skada. Genomträngning gäller slagets första mål; SLAGJAW_TOOTH gäller
## överflödet (varje mål efter det första).
static func _gear_armor(ctx: Context, slot_index: int, target: Enemy, hop: int,
		pierce_sources: Array, incoming: int) -> int:
	var armor: int = target.armor
	if hop > 0:
		for entry: Variant in ctx.fx_of(GearRules.OVERFLOW_IGNORES_ARMOR):
			var ignored: int = mini(armor, incoming)
			if ignored > 0:
				ctx.gear(entry as Dictionary, {"slot": slot_index, "target": target.id, "ignored": ignored})
			return 0
		return armor
	for entry: Variant in pierce_sources:
		var e: Dictionary = entry as Dictionary
		var amount: int = (e["item"] as Item).effect_value(e["effect"] as Dictionary)
		var ignored: int = mini(mini(amount, armor), incoming)
		if ignored <= 0:
			continue
		armor -= ignored
		ctx.gear(e, {"slot": slot_index, "target": target.id, "ignored": ignored})
	return armor


static func _on_hit_effects(ctx: Context, slot_index: int, target: Enemy) -> void:
	var state: CombatState = ctx.state
	var slot: Slot = state.board.slots[slot_index]
	if slot.type == Rules.SlotType.FIRE:
		target.burn += FIRE_BURN_STACKS
		ctx.emit("status_applied", {
			"target": target.id,
			"status": "BURN",
			"stacks": FIRE_BURN_STACKS,
			"stacks_after": target.burn,
		})

	var face: Face = state.dice[ctx.placement[slot_index]].showing_face()
	var effect: int = face.effect
	var magnitude: int = face.magnitude
	# ECHO_MIRROR: en MIRROR-slot ärver vänstergrannens sideffekt.
	if slot.type == Rules.SlotType.MIRROR and ctx.has_relic(RELIC_ECHO_MIRROR) and slot_index > 0:
		if ctx.placement[slot_index - 1] >= 0:
			var left_face: Face = state.dice[ctx.placement[slot_index - 1]].showing_face()
			effect = left_face.effect
			magnitude = left_face.magnitude

	match effect:
		Rules.FaceEffectKind.APPLY_POISON:
			target.poison += magnitude
			ctx.emit("status_applied", {
				"target": target.id, "status": "POISON",
				"stacks": magnitude, "stacks_after": target.poison,
			})
		Rules.FaceEffectKind.APPLY_BURN:
			target.burn += magnitude
			ctx.emit("status_applied", {
				"target": target.id, "status": "BURN",
				"stacks": magnitude, "stacks_after": target.burn,
			})
		Rules.FaceEffectKind.LIFESTEAL:
			# dealt finns inte här; vi läser senaste damage_dealt för denna slot.
			var dealt: int = int(ctx.events[ctx.events.size() - 1].get("amount", 0))
			for k: int in range(ctx.events.size() - 1, -1, -1):
				if String(ctx.events[k].get("t", "")) == "damage_dealt":
					dealt = int(ctx.events[k].get("amount", 0))
					break
			var heal: int = mini(dealt * magnitude / 100, Rules.LIFESTEAL_CAP)
			heal = mini(heal, state.player_max_hp - state.player_hp)
			if heal > 0:
				state.player_hp += heal
				ctx.emit("heal", {
					"target": "player", "amount": heal,
					"source": "LIFESTEAL", "hp_after": state.player_hp,
				})


static func _on_enemy_killed(ctx: Context, target: Enemy, slot_index: int) -> void:
	ctx.emit("enemy_killed", {"target": target.id, "slot": slot_index})
	ctx.state.kills += 1
	for entry: Variant in ctx.fx_of(GearRules.CHARGE_ON_KILL):
		var e: Dictionary = entry as Dictionary
		var amount: int = (e["item"] as Item).effect_value(e["effect"] as Dictionary)
		if amount <= 0:
			continue
		ctx.gear(e, {"amount": amount, "target": target.id})
		_store_charge(ctx, amount, "GEAR")
	if target.special == "STEAL" and not ctx.state.stolen.is_empty():
		for die_id: String in ctx.state.stolen.duplicate():
			ctx.emit("die_returned", {"die_id": die_id})
		ctx.state.stolen.clear()


static func _store_charge(ctx: Context, amount: int, source: String) -> void:
	if amount <= 0:
		return
	var before: int = ctx.state.charge
	ctx.state.charge = mini(ctx.charge_cap, before + amount)
	if ctx.state.charge > Rules.CHARGE_CAP and before + amount > Rules.CHARGE_CAP \
			and before < ctx.state.charge:
		# Kritväskan höll det som grundtaket hade kastat.
		for entry: Variant in ctx.fx_of(GearRules.CHARGE_CAP):
			ctx.gear(entry as Dictionary, {"cap": ctx.charge_cap, "pool_after": ctx.state.charge})
			break
	var stored: int = ctx.state.charge - before
	if stored > 0:
		ctx.emit("charge_stored", {
			"amount": stored, "source": source, "pool_after": ctx.state.charge,
		})
	if stored < amount:
		ctx.emit("charge_capped", {"lost": amount - stored})


static func _kill_player(ctx: Context, killed_by: String) -> void:
	ctx.emit("player_died", {"round": ctx.state.round_number, "killed_by": killed_by})
	ctx.state.player_dead = true
	ctx.aborted = true


# ---------------------------------------------------------------------------
# P4 – ENEMY PASS
# ---------------------------------------------------------------------------
static func _phase_enemy_pass(ctx: Context) -> void:
	var state: CombatState = ctx.state
	for enemy: Enemy in state.enemies:
		if ctx.aborted:
			return
		if not enemy.is_alive():
			continue
		var intent: Intent = enemy.intent if enemy.intent != null else Intent.new(Rules.IntentKind.ATTACK, enemy.attack)
		ctx.emit("enemy_turn_start", {"enemy": enemy.id, "intent": intent.to_dict()})

		match intent.kind:
			Rules.IntentKind.ATTACK:
				var raw: int = intent.value
				var ward_used: int = mini(state.ward, raw)
				state.ward -= ward_used
				var taken: int = raw - ward_used
				var attack: Dictionary = {
					"enemy": enemy.id, "raw": raw, "ward_used": ward_used,
				}
				if taken > 0 and ctx.has_fx(GearRules.PLAYER_ARMOR):
					var armor_used: int = 0
					for entry: Variant in ctx.fx_of(GearRules.PLAYER_ARMOR):
						var e: Dictionary = entry as Dictionary
						var block: int = mini(taken, (e["item"] as Item).effect_value(e["effect"] as Dictionary))
						if block <= 0:
							continue
						taken -= block
						armor_used += block
						ctx.gear(e, {"enemy": enemy.id, "blocked": block})
					attack["armor_used"] = armor_used
				state.player_hp -= taken
				ctx.damage_taken += taken
				attack["amount"] = taken
				attack["player_hp_after"] = state.player_hp
				ctx.emit("enemy_attacks", attack)
				if state.player_hp <= 0:
					_kill_player(ctx, enemy.id)
					return
				if enemy.special == "CRACK_BITE" and enemy.hp < enemy.max_hp / 2:
					_crack_bite(ctx, enemy)
			Rules.IntentKind.BLOCK:
				enemy.armor += intent.value
				ctx.emit("enemy_special", {
					"enemy": enemy.id, "special": "HARDEN",
					"detail": {"armor_after": enemy.armor},
				})
			Rules.IntentKind.SPECIAL:
				_enemy_special(ctx, enemy, intent)

	# Statustick, i listordning, efter att alla fiender agerat.
	for enemy: Enemy in state.enemies:
		if ctx.aborted:
			return
		if not enemy.is_alive():
			continue
		if enemy.burn > 0:
			enemy.hp -= enemy.burn  # Burn spiller ALDRIG över till nästa fiende.
			state.total_damage += enemy.burn
			ctx.emit("status_ticked", {
				"target": enemy.id, "status": "BURN", "amount": enemy.burn,
				"target_hp_after": enemy.hp, "stacks_after": enemy.burn - 1,
			})
			enemy.burn -= 1
		if enemy.poison > 0:
			enemy.hp -= enemy.poison  # Poison avtar INTE och spiller aldrig över.
			state.total_damage += enemy.poison
			ctx.emit("status_ticked", {
				"target": enemy.id, "status": "POISON", "amount": enemy.poison,
				"target_hp_after": enemy.hp, "stacks_after": enemy.poison,
			})
		if enemy.hp <= 0:
			_on_enemy_killed(ctx, enemy, -1)


static func _enemy_special(ctx: Context, enemy: Enemy, intent: Intent) -> void:
	match enemy.special:
		"DRAIN_CHARGE":
			var before: int = ctx.state.charge
			ctx.state.charge = maxi(0, before - DRAIN_CHARGE_AMOUNT)
			ctx.emit("enemy_special", {
				"enemy": enemy.id, "special": "DRAIN_CHARGE",
				"detail": {"drained": before - ctx.state.charge, "charge_after": ctx.state.charge},
			})
		_:
			ctx.emit("enemy_special", {
				"enemy": enemy.id, "special": enemy.special,
				"detail": intent.payload.duplicate(true),
			})


## SLAGJAW: spräcker den vänstraste placerade tärningens uppåtvända sida.
static func _crack_bite(ctx: Context, enemy: Enemy) -> void:
	for i: int in range(ctx.placement.size()):
		if ctx.placement[i] < 0:
			continue
		var die: Die = ctx.state.dice[ctx.placement[i]]
		var face: Face = die.showing_face()
		if face == null or face.id == CRACKED_FACE_ID:
			continue
		var cracked: Face = Face.new(CRACKED_FACE_ID, 0)
		cracked.base_value = face.base_value
		die.faces[die.showing] = cracked
		die.cracks += 1
		if die.integrity > 0:
			die.integrity -= 1
		ctx.emit("die_cracked", {
			"die_id": die.id, "face_index": die.showing,
			"cracks_total": die.cracks, "destroyed": die.is_destroyed(),
		})
		if die.is_destroyed():
			ctx.emit("die_destroyed", {"die_id": die.id})
		return


# ---------------------------------------------------------------------------
# P5 – ROUND_END
# ---------------------------------------------------------------------------
static func _phase_round_end(ctx: Context) -> void:
	var state: CombatState = ctx.state
	var unplaced: Array[int] = state.unplaced_die_indices(ctx.placement)

	# 1. Oanvända tärningar blir Charge.
	for index: int in unplaced:
		var face: Face = state.dice[index].showing_face()
		if face != null:
			_store_charge(ctx, face.value, "UNPLACED_DIE")
	if not ctx.fx.is_empty():
		_gear_round_end_charge(ctx, unplaced.size())

	# 2. GROW på oanvända tärningar.
	for index: int in unplaced:
		var die: Die = state.dice[index]
		var face: Face = die.showing_face()
		if face != null and face.effect == Rules.FaceEffectKind.GROW:
			face = die.mutable_face(die.showing)  # copy-on-write, se Die.copy()
			face.value = mini(Rules.MAX_FACE_VALUE, face.value + face.magnitude)
			ctx.emit("face_grew", {
				"die_id": die.id, "face_index": die.showing, "new_value": face.value,
			})

	# ANVIL_BLESSING (Smedens startrelik): +1 på ANVIL-slotens uppåtvända sida
	# efter en runda där ett combo av storlek >= 3 bildades.
	if ctx.has_relic(RELIC_ANVIL_BLESSING) and _largest_group_size(ctx.groups) >= 3:
		for i: int in range(state.board.size()):
			if state.board.slots[i].type != Rules.SlotType.ANVIL or ctx.placement[i] < 0:
				continue
			var die: Die = state.dice[ctx.placement[i]]
			var face: Face = die.showing_face()
			if face == null or face.value >= Rules.MAX_FACE_VALUE:
				continue
			face = die.mutable_face(die.showing)  # copy-on-write, se Die.copy()
			face.value += 1
			ctx.emit("relic_triggered", ctx.relic_fields(RELIC_ANVIL_BLESSING,
				{"slot": i, "die_id": die.id, "new_value": face.value}))
			ctx.emit("face_grew", {
				"die_id": die.id, "face_index": die.showing, "new_value": face.value,
			})
			break

	# 3. Ward nollställs – utom den del TICK_CARAPACE håller kvar.
	var kept: int = 0
	for entry: Variant in ctx.fx_of(GearRules.WARD_RETAIN):
		var e: Dictionary = entry as Dictionary
		var percent: int = (e["item"] as Item).effect_value(e["effect"] as Dictionary, "percent")
		kept = maxi(kept, state.ward * percent / 100)
		if kept > 0:
			ctx.gear(e, {"kept": kept})
	state.ward = kept

	# 4. Rundslutsspecials. Blockeringar från förra rundans GRAB släpps först.
	for slot: Slot in state.board.slots:
		slot.blocked = false
	for enemy: Enemy in state.enemies:
		if not enemy.is_alive() or enemy.intent == null:
			continue
		if enemy.intent.kind != Rules.IntentKind.SPECIAL:
			continue
		match enemy.special:
			"STEAL":
				var die_id: String = String(enemy.intent.payload.get("die_id", ""))
				if die_id != "" and not state.stolen.has(die_id):
					state.stolen.append(die_id)
					ctx.emit("die_stolen", {"die_id": die_id, "by": enemy.id})
			"GRAB":
				var slot_index: int = int(enemy.intent.payload.get("slot", -1))
				if slot_index >= 0 and slot_index < state.board.size():
					state.board.slots[slot_index].blocked = true
					ctx.emit("enemy_special", {
						"enemy": enemy.id, "special": "GRAB",
						"detail": {"slot": slot_index},
					})

	# 5–6. Segern först, sedan rundslutet.
	if state.is_won():
		ctx.emit("combat_won", {"rounds": state.round_number, "total_damage": state.total_damage})
	ctx.emit("round_end", {
		"round": state.round_number,
		"player_hp": state.player_hp,
		"charge": state.charge,
		"enemies_alive": state.enemies_alive(),
	})


## Rundslutets Charge ur gear och quirks: DICE_POUCH, HOARDER, KILN_VEST.
static func _gear_round_end_charge(ctx: Context, unplaced_count: int) -> void:
	if unplaced_count > 0:
		for entry: Variant in ctx.fx_of(GearRules.UNPLACED_CHARGE_BONUS):
			var e: Dictionary = entry as Dictionary
			var amount: int = (e["item"] as Item).effect_value(e["effect"] as Dictionary) * unplaced_count
			if amount <= 0:
				continue
			ctx.gear(e, {"amount": amount, "dice": unplaced_count})
			_store_charge(ctx, amount, "GEAR")
	for entry: Variant in ctx.fx_of(GearRules.CHARGE_PER_ROUND):
		var e: Dictionary = entry as Dictionary
		var amount: int = (e["item"] as Item).effect_value(e["effect"] as Dictionary)
		if amount <= 0:
			continue
		ctx.gear(e, {"amount": amount})
		_store_charge(ctx, amount, "GEAR")
	if ctx.damage_taken == 0:
		for entry: Variant in ctx.fx_of(GearRules.CHARGE_IF_UNHURT):
			var e: Dictionary = entry as Dictionary
			var amount: int = (e["item"] as Item).effect_value(e["effect"] as Dictionary)
			if amount <= 0:
				continue
			ctx.gear(e, {"amount": amount})
			_store_charge(ctx, amount, "GEAR")


static func _largest_group_size(groups: Array) -> int:
	var largest: int = 0
	for group: Variant in groups:
		largest = maxi(largest, int((group as Dictionary)["size"]))
	return largest


# ---------------------------------------------------------------------------
# advance() – ALL slump för nästa runda, dras FÖRE bekräftelsen (GAME_DESIGN §6.4)
# ---------------------------------------------------------------------------

## Förbereder stridens första runda: rullar tärningarna och väljer intents.
##
## [b]M6:[/b] stridens start-gear verkar här, före första kastet och därmed före
## första förhandsvisningen: [code]START_CHARGE[/code], omkast per strid och i
## första rundan, och [code]PIT_STRIDERS[/code] sjunde tärning. Utan gear drar
## funktionen exakt samma slump som i M5.
static func begin_combat(state: CombatState, rng: Rng) -> CombatState:
	var next: CombatState = state.copy()
	next.round_number = 1
	next.ward = 0
	next.charge = 0
	next.total_damage = 0
	next.kills = 0
	next.combat_rerolls = 0
	_remove_extra_die(next)
	if not next.gear.is_empty():
		var cap: int = GearRules.charge_cap(next.gear)
		next.charge = mini(cap, maxi(0, GearRules.total(next.gear, GearRules.START_CHARGE)))
		next.combat_rerolls = maxi(0, GearRules.total(next.gear, GearRules.COMBAT_REROLL))
		next.rerolls_left += next.combat_rerolls \
			+ maxi(0, GearRules.total(next.gear, GearRules.FIRST_ROUND_REROLL))
		for i: int in range(maxi(0, mini(1, GearRules.total(next.gear, GearRules.FIRST_ROUND_EXTRA_DIE)))):
			next.dice.append(Die.standard(GearRules.EXTRA_DIE_ID, Rules.DieMaterial.IRON))
	next.placement = CombatState.empty_placement(next.board.size())
	_roll_dice(next, rng, true)
	_choose_intents(next, rng)
	return next


## Tar bort PIT_STRIDERS sjunde tärning. Den finns bara i stridens första runda.
static func _remove_extra_die(state: CombatState) -> void:
	for i: int in range(state.dice.size() - 1, -1, -1):
		if state.dice[i].id == GearRules.EXTRA_DIE_ID:
			state.dice.remove_at(i)
	state.stolen.erase(GearRules.EXTRA_DIE_ID)


## Förbereder nästa runda efter en resolution.
static func advance(state_after: CombatState, rng: Rng) -> CombatState:
	var next: CombatState = state_after.copy()
	next.round_number += 1
	next.placement = CombatState.empty_placement(next.board.size())
	# Stridens extra omkast förbrukas sist: det som finns kvar av dem är det
	# som finns kvar av rundans omkast, högst så många som fanns.
	next.combat_rerolls = mini(next.combat_rerolls, maxi(0, state_after.rerolls_left))
	next.rerolls_left = 1 + next.combat_rerolls
	_remove_extra_die(next)
	_roll_dice(next, rng, false)
	_choose_intents(next, rng)
	return next


## Återställer sidor som vuxit eller spruckit under striden.
static func end_combat(state: CombatState) -> CombatState:
	var next: CombatState = state.copy()
	next.charge = 0
	next.ward = 0
	next.kills = 0
	next.combat_rerolls = 0
	next.stolen.clear()
	_remove_extra_die(next)
	for die: Die in next.dice:
		for i: int in range(die.faces.size()):
			var face: Face = die.mutable_face(i)  # copy-on-write, se Die.copy()
			if face.id == CRACKED_FACE_ID:
				face.id = "PIP_%d" % face.base_value
			face.reset_value()
	return next


static func _roll_dice(state: CombatState, rng: Rng, first_roll: bool) -> void:
	for die: Die in state.dice:
		if state.stolen.has(die.id):
			continue
		die.roll(rng)
	# CHEAT_CUBE: stridens första kast ger tärning 0–2 samma seedade värde.
	var cheat_cube: bool = Relic.has_relic(state.relics, RELIC_CHEAT_CUBE) \
		or GearRules.has_rule(state.gear, RELIC_CHEAT_CUBE)
	if first_roll and cheat_cube and state.dice.size() >= 3:
		var shared: int = rng.next_int(0, Rules.FACE_COUNT - 1)
		for i: int in range(3):
			state.dice[i].showing = mini(shared, state.dice[i].faces.size() - 1)


static func _choose_intents(state: CombatState, rng: Rng) -> void:
	for enemy: Enemy in state.enemies:
		if not enemy.is_alive():
			continue
		enemy.intent = _intent_for(state, enemy, rng)


static func _intent_for(state: CombatState, enemy: Enemy, rng: Rng) -> Intent:
	match enemy.special:
		"HARDEN":
			if state.round_number % 3 == 0:
				return _noted(Intent.new(Rules.IntentKind.BLOCK, 4, "INTENT_NOTE_HARDEN"), [4])
		"DRAIN_CHARGE":
			if state.charge > 0:
				return _noted(Intent.new(Rules.IntentKind.SPECIAL, DRAIN_CHARGE_AMOUNT, "INTENT_NOTE_DRAIN_CHARGE"), [DRAIN_CHARGE_AMOUNT])
		"STEAL":
			var candidates: Array[int] = state.unplaced_die_indices(CombatState.empty_placement(state.board.size()))
			if not candidates.is_empty():
				var pick: int = int(rng.pick(candidates))
				var intent: Intent = Intent.new(Rules.IntentKind.SPECIAL, 0, "INTENT_NOTE_STEAL")
				intent.payload = {"die_id": state.dice[pick].id}
				return intent
		"GRAB":
			var slot_index: int = rng.next_int(0, state.board.size() - 1)
			var grab: Intent = _noted(Intent.new(Rules.IntentKind.SPECIAL, 0, "INTENT_NOTE_GRAB"), [slot_index + 1])
			grab.payload = {"slot": slot_index}
			return grab
	return _noted(Intent.new(Rules.IntentKind.ATTACK, enemy.attack, "INTENT_NOTE_ATTACK"), [enemy.attack])


## Sätter formatargumenten för [member Intent.note]. Noten är en nyckel, inte
## prosa – core får inte innehålla spelartext (CLAUDE.md).
static func _noted(intent: Intent, args: Array) -> Intent:
	intent.note_args = args
	return intent
