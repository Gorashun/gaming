class_name ChainReceipt
extends RefCounted
## Kvittot: händelseloggen läst som ett [b]räknestycke[/b].
## docs/design/COMBAT_READABILITY.md §2 och TOWN_AND_ONBOARDING §B.3.
##
## [b]Normativ princip:[/b] kedjan ska gå att räkna efter för hand. Kan en
## spelare inte peka på skärmen och säga "2 plus 10 plus 10 plus 6 plus 12 blir
## 40, minus rustning blir 28" har förhandsvisningen misslyckats.
##
## [b]Ren funktion, inga Node-beroenden, ingen prosa.[/b] [method build] tar
## [code]ResolveResult.events[/code] in och returnerar siffror, id:n och
## [i]orsakskoder[/i]. Översättningen till text sker i [CombatScreen]; det är
## därför hela kvittot går att testa headless (tests/test_chain_receipt.gd).
##
## Inget event tolkas om och ingen regel räknas om: varje tal här kommer
## ordagrant ur loggen. Resolvern är oförändrad (COMBAT_READABILITY, grundtes).

# --- Orsakskoder för slotens "varför"-rad (§2.4) ----------------------------
const WHY_NONE: String = ""
## Ett par/triss där [code]args[0][/code] är den andra slotens nummer (1-index).
const WHY_PAIR_WITH: String = "PAIR_WITH"
## MIRROR/COPY_LEFT kopierade slot [code]args[0][/code] (1-index).
const WHY_COPY_OF: String = "COPY_OF"
## MIRROR på slot 1 — ingen vänstergranne.
const WHY_NO_LEFT: String = "NO_LEFT"
## MIRROR med tom/blockerad vänstergranne.
const WHY_LEFT_EMPTY: String = "LEFT_EMPTY"
## ANVIL slog till: [code]args[0][/code] var 5 eller mer.
const WHY_ANVIL_OK: String = "ANVIL_OK"
## ANVIL misslyckades — [b]ska synas[/b] (§2.4: annars lärs tröskeln aldrig).
const WHY_ANVIL_LOW: String = "ANVIL_LOW"
## FIRE-sloten sätter brand.
const WHY_BURN: String = "BURN"
## VOID-sloten ger Ward i stället för skada.
const WHY_TO_WARD: String = "TO_WARD"
## CHARGE-sloten bankar i stället för att slå.
const WHY_TO_CHARGE: String = "TO_CHARGE"
## Laddningen lades på den här sloten, [code]args[0][/code] ögon.
const WHY_CHARGE_PLUS: String = "CHARGE_PLUS"

# --- Slotens utfall ---------------------------------------------------------
const OUT_EMPTY: String = "EMPTY"
const OUT_BLOCKED: String = "BLOCKED"
const OUT_DAMAGE: String = "DAMAGE"
const OUT_WARD: String = "WARD"
const OUT_CHARGE: String = "CHARGE"
## Slog, men allt åts av rustning eller det fanns inget kvar att slå på.
const OUT_FIZZLE: String = "FIZZLE"


## Hela kvittot för en runda.
##
## [param events] är [code]ResolveResult.events[/code], [param enemies] är
## fiendelistan [b]som den såg ut när rundan började[/b] (samma ordning som
## panelerna), [param board] behövs för slot-typernas orsaksrader.
static func build(events: Array[Dictionary], enemies: Array[Enemy], board: Board) -> Dictionary:
	var slot_count: int = board.size() if board != null else Rules.SLOT_COUNT
	var slots: Array[Dictionary] = _empty_slots(slot_count, board)
	var lines: Array[Dictionary] = []
	var arcs: Array[Dictionary] = []
	var routes: Array[Dictionary] = _empty_routes(enemies)

	# Levande HP per fiendeindex. Samma "första levande med detta id"-regel som
	# resolvern och EventPlayer.target_index använder; rum 1 är fyra RUST_RAT
	# med identiskt id och utan den regeln dräneras fel stapel.
	var hp: PackedInt32Array = PackedInt32Array()
	hp.resize(enemies.size())
	for i: int in range(enemies.size()):
		hp[i] = enemies[i].hp

	var raw: int = 0
	var damage: int = 0
	var armor_blocked: int = 0
	var hits: int = 0
	var uniform_armor: int = -1
	var ward: int = 0
	var charge_banked: int = 0
	var charge_unplaced: int = 0
	var charge_pool: int = 0
	var wasted: int = 0
	var status_tick: int = 0
	var incoming_player: int = 0
	var ward_used: int = 0
	var player_hp_after: int = -1
	var player_died: bool = false
	var killed_by: String = ""
	var combat_won: bool = false
	var last_slot: int = -1

	for event: Dictionary in events:
		var kind: String = String(event.get("t", ""))
		var event_slot: int = int(event.get("slot", -1))
		var slot: Dictionary = _slot(slots, event_slot)
		match kind:
			"die_activated":
				if not slot.is_empty():
					slot["occupied"] = true
					slot["base"] = int(event.get("base_value", 0))
					slot["face_id"] = String(event.get("face_id", ""))
					slot["die_id"] = String(event.get("die_id", ""))
			"charge_applied":
				if not slot.is_empty():
					slot["charge_bonus"] = int(event.get("amount", 0))
					_why(slot, WHY_CHARGE_PLUS, [int(event.get("amount", 0))], false)
			"slot_modifier":
				_on_modifier(slots, event, false)
			"slot_modifier_failed":
				_on_modifier(slots, event, true)
			"value_pass_done":
				var values: Array = event.get("values", []) as Array
				var occupied: Array = event.get("occupied", []) as Array
				for i: int in range(mini(slots.size(), values.size())):
					slots[i]["value"] = int(values[i])
					if i < occupied.size():
						slots[i]["occupied"] = bool(occupied[i])
			"combo_formed":
				var group: Array = (event.get("slots", []) as Array).duplicate()
				arcs.append({
					"slots": group,
					"multiplier": int(event.get("multiplier", 1)),
					"kind": String(event.get("kind", "")),
					"value": int(event.get("value", 0)),
					"outer": false,
				})
				for entry: Variant in group:
					var member: Dictionary = _slot(slots, int(entry))
					if member.is_empty():
						continue
					member["multiplier"] = int(event.get("multiplier", 1))
					member["combo_kind"] = String(event.get("kind", ""))
					_why(member, WHY_PAIR_WITH, [_partner(group, int(entry)) + 1], false)
			"house_bonus":
				var after: Array = event.get("multipliers_after", []) as Array
				for i: int in range(mini(slots.size(), after.size())):
					slots[i]["multiplier"] = int(after[i])
				var covered: Array = []
				for group: Variant in event.get("groups", []) as Array:
					for entry: Variant in group as Array:
						covered.append(int(entry))
				arcs.append({
					"slots": covered,
					"multiplier": int(event.get("factor", 2)),
					"kind": "HOUSE",
					"value": 0,
					"outer": true,
				})
			"strike":
				if not slot.is_empty():
					slot["amount"] = int(event.get("amount", 0))
					slot["multiplier"] = int(event.get("multiplier", slot.get("multiplier", 1)))
					if int(slot["type"]) == Rules.SlotType.CHARGE:
						charge_banked += int(event.get("amount", 0))
				raw += int(event.get("amount", 0))
				last_slot = event_slot
			"relic_triggered":
				# DOMINO upprepar en slot utan ett eget strike-event. Utan den här
				# raden går kvittots addition inte ihop för den reliken.
				if String(event.get("relic", "")) == Resolver.RELIC_DOMINO:
					var detail: Dictionary = event.get("detail", {}) as Dictionary
					var extra: int = int(detail.get("amount", 0))
					raw += extra
					var repeat: Dictionary = _slot(slots, int(detail.get("repeat_slot", -1)))
					if not repeat.is_empty() and int(repeat["type"]) == Rules.SlotType.CHARGE:
						charge_banked += extra
					last_slot = int(detail.get("repeat_slot", last_slot))
			"damage_dealt":
				var target_id: String = String(event.get("target", ""))
				var target: int = _front_index(enemies, hp, target_id)
				var dealt: int = int(event.get("amount", 0))
				var blocked: int = int(event.get("blocked", 0))
				var overflow: int = int(event.get("overflow", 0))
				var before: int = hp[target] if target >= 0 else 0
				var continuation: bool = not lines.is_empty() \
					and int((lines[lines.size() - 1] as Dictionary)["slot"]) == event_slot
				if target >= 0:
					hp[target] = int(event.get("target_hp_after", before))
					var route: Dictionary = routes[target]
					route["damage"] = int(route["damage"]) + dealt
					route["hits"] = int(route["hits"]) + 1
					if continuation:
						route["overflow"] = int(route["overflow"]) + dealt
				damage += dealt
				armor_blocked += blocked
				hits += 1
				if uniform_armor == -1:
					uniform_armor = blocked
				elif uniform_armor != blocked:
					uniform_armor = -2
				lines.append({
					"slot": event_slot,
					"is_overflow": continuation,
					"incoming": blocked + dealt + overflow,
					"blocked": blocked,
					"dealt": dealt,
					"overflow": overflow,
					"target": target,
					"target_id": target_id,
					"hp_before": before,
					"hp_after": int(event.get("target_hp_after", before)),
					"killed": false,
					"statuses": [] as Array,
				})
				if not slot.is_empty() and dealt > 0:
					slot["outcome"] = OUT_DAMAGE
			"status_applied":
				if not lines.is_empty():
					var line: Dictionary = lines[lines.size() - 1]
					(line["statuses"] as Array).append({
						"status": String(event.get("status", "")),
						"stacks": int(event.get("stacks", 0)),
					})
			"enemy_killed":
				for i: int in range(lines.size() - 1, -1, -1):
					var line: Dictionary = lines[i]
					if int(line["slot"]) == event_slot and String(line["target_id"]) == String(event.get("target", "")):
						line["killed"] = true
						break
				var dead: int = _dead_index(enemies, hp, String(event.get("target", "")), routes)
				if dead >= 0:
					(routes[dead] as Dictionary)["killed"] = true
			"ward_gained":
				ward += int(event.get("amount", 0))
				if not slot.is_empty():
					slot["outcome"] = OUT_WARD
					_why(slot, WHY_TO_WARD, [], false)
			"charge_stored":
				var source: String = String(event.get("source", ""))
				charge_pool = int(event.get("pool_after", charge_pool))
				if source == "UNPLACED_DIE":
					charge_unplaced += int(event.get("amount", 0))
				elif source == "CHARGE_SLOT":
					var banking: Dictionary = _slot(slots, last_slot)
					if not banking.is_empty():
						banking["outcome"] = OUT_CHARGE
						_why(banking, WHY_TO_CHARGE, [], false)
			"overflow_wasted":
				wasted += int(event.get("amount", 0))
			"status_ticked":
				status_tick += int(event.get("amount", 0))
				var ticked: int = _front_index(enemies, hp, String(event.get("target", "")))
				if ticked >= 0:
					hp[ticked] = int(event.get("target_hp_after", hp[ticked]))
			"enemy_attacks":
				incoming_player += int(event.get("amount", 0))
				ward_used += int(event.get("ward_used", 0))
				player_hp_after = int(event.get("player_hp_after", player_hp_after))
			"enemy_thorns", "player_damaged":
				incoming_player += int(event.get("amount", 0))
				player_hp_after = int(event.get("player_hp_after", player_hp_after))
			"player_died":
				player_died = true
				killed_by = String(event.get("killed_by", ""))
			"combat_won":
				combat_won = true

	# Slots som fick ett värde men varken skada, Ward eller Charge fizzlade.
	for slot: Dictionary in slots:
		if bool(slot["occupied"]) and String(slot["outcome"]) == OUT_EMPTY:
			slot["outcome"] = OUT_FIZZLE
		_late_why(slot)

	return {
		"slots": slots,
		"lines": lines,
		"arcs": arcs,
		"routes": routes,
		"raw": raw,
		"damage": damage,
		"armor": armor_blocked,
		"hits": hits,
		"armor_per_hit": uniform_armor if uniform_armor >= 0 else -1,
		"ward": ward,
		"charge": charge_banked,
		"charge_unplaced": charge_unplaced,
		"charge_pool": charge_pool,
		"wasted": wasted,
		"status_tick": status_tick,
		"incoming": incoming_player,
		"ward_used": ward_used,
		"player_hp_after": player_hp_after,
		"player_died": player_died,
		"killed_by": killed_by,
		"won": combat_won,
	}


## Talet som står på BEKRÄFTA-knappen och överst i kvittot.
##
## [b]Det ska vara samma tal på båda ställena[/b] (§B.3: "Siffran på knappen och
## TOTAL i kvittot måste vara samma tal, alltid"). Definitionen är summan av
## [code]damage_dealt.amount[/code] — kedjans egen skada. Brand- och gifttickar
## i P4 räknas separat i [code]status_tick[/code] och visas som en egen rad, så
## att kvittots addition går ihop.
static func total_damage(events: Array[Dictionary]) -> int:
	var total: int = 0
	for event: Dictionary in events:
		if String(event.get("t", "")) == "damage_dealt":
			total += int(event.get("amount", 0))
	return total


## [b]Kvittots invariant[/b] (§2.1b): allt råvärde tar vägen någonstans.
## [codeblock]
## RÅ = skada + rustning + ward + laddning + spill utan mål
## [/codeblock]
## DOMINO lägger till skada utan ett [code]strike[/code]-event, så relikens
## extra slag räknas in i råvärdet här och inte i meningen ovanför.
static func balances(receipt: Dictionary) -> bool:
	var accounted: int = int(receipt["damage"]) + int(receipt["armor"]) \
		+ int(receipt["ward"]) + int(receipt["charge"]) + int(receipt["wasted"])
	return int(receipt["raw"]) == accounted


## Numreringen av fiender med samma namn: [code]Rostråtta 1 … 4[/code] från
## fronten. Utan den är "8 → Rust Rat 8 → Rust Rat" obegripligt (§2.1c).
static func ordinals(enemies: Array[Enemy]) -> PackedInt32Array:
	var seen: Dictionary = {}
	var counts: Dictionary = {}
	for enemy: Enemy in enemies:
		counts[enemy.id] = int(counts.get(enemy.id, 0)) + 1
	var result: PackedInt32Array = PackedInt32Array()
	result.resize(enemies.size())
	for i: int in range(enemies.size()):
		var id: String = enemies[i].id
		if int(counts[id]) <= 1:
			result[i] = 0  # ensam av sitt slag: ingen siffra behövs
			continue
		seen[id] = int(seen.get(id, 0)) + 1
		result[i] = int(seen[id])
	return result


# --- Interna hjälpare -------------------------------------------------------

static func _empty_slots(count: int, board: Board) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for i: int in range(count):
		var slot: Slot = board.slot_at(i) if board != null else null
		slots.append({
			"slot": i,
			"type": slot.type if slot != null else Rules.SlotType.PLAIN,
			"blocked": slot.blocked if slot != null else false,
			"occupied": false,
			"base": 0,
			"charge_bonus": 0,
			"value": 0,
			"multiplier": 1,
			"amount": 0,
			"combo_kind": "",
			"why": WHY_NONE,
			"why_args": [] as Array,
			"why_locked": false,
			"outcome": OUT_BLOCKED if (slot != null and slot.blocked) else OUT_EMPTY,
			"face_id": "",
			"die_id": "",
		})
	return slots


static func _empty_routes(enemies: Array[Enemy]) -> Array[Dictionary]:
	var routes: Array[Dictionary] = []
	for i: int in range(enemies.size()):
		routes.append({"damage": 0, "overflow": 0, "hits": 0, "killed": false})
	return routes


static func _slot(slots: Array[Dictionary], index: int) -> Dictionary:
	if index < 0 or index >= slots.size():
		return {}
	return slots[index]


## Sätter slotens orsaksrad. [param locked] vinner över senare, svagare skäl;
## modifieraren (spegel/amboss) är alltid viktigare än kombon, eftersom den
## förklarar varför tärningens egna ögon inte står i räkningen (§B.1 punkt 2).
static func _why(slot: Dictionary, code: String, args: Array, locked: bool) -> void:
	if bool(slot.get("why_locked", false)) and not locked:
		return
	slot["why"] = code
	slot["why_args"] = args
	slot["why_locked"] = locked


## Slot-typens egen förklaring, som bara används när inget starkare skäl finns.
static func _late_why(slot: Dictionary) -> void:
	if String(slot["why"]) != WHY_NONE:
		return
	match int(slot["type"]):
		Rules.SlotType.FIRE:
			if bool(slot["occupied"]):
				_why(slot, WHY_BURN, [Resolver.FIRE_BURN_STACKS], false)
		Rules.SlotType.VOID:
			_why(slot, WHY_TO_WARD, [], false)
		Rules.SlotType.CHARGE:
			_why(slot, WHY_TO_CHARGE, [], false)


static func _on_modifier(slots: Array[Dictionary], event: Dictionary, failed: bool) -> void:
	var index: int = int(event.get("slot", -1))
	var slot: Dictionary = _slot(slots, index)
	if slot.is_empty():
		return
	var modifier: String = String(event.get("modifier", ""))
	if failed:
		match String(event.get("reason", "")):
			"NO_LEFT_NEIGHBOUR":
				_why(slot, WHY_NO_LEFT, [], true)
			"LEFT_NEIGHBOUR_EMPTY":
				_why(slot, WHY_LEFT_EMPTY, [], true)
			"VALUE_BELOW_5":
				_why(slot, WHY_ANVIL_LOW, [Rules.ANVIL_THRESHOLD], true)
		slot["modifier_failed"] = modifier
		return
	if modifier == "MIRROR" or modifier == "COPY_LEFT":
		slot["copies_from"] = index - 1
		_why(slot, WHY_COPY_OF, [index], true)
	else:
		_why(slot, WHY_ANVIL_OK, [int(event.get("value_before", 0)), Rules.ANVIL_THRESHOLD], true)
		slot["doubled"] = true


## Den andra sloten i en grupp, sett från [param index]. Vid fler än två väljs
## närmaste granne, vilket är den spelaren tittar på.
static func _partner(group: Array, index: int) -> int:
	var best: int = index
	var best_distance: int = 1 << 30
	for entry: Variant in group:
		var other: int = int(entry)
		if other == index:
			continue
		var distance: int = absi(other - index)
		if distance < best_distance:
			best_distance = distance
			best = other
	return best


static func _front_index(enemies: Array[Enemy], hp: PackedInt32Array, id: String) -> int:
	var fallback: int = -1
	for i: int in range(enemies.size()):
		if enemies[i].id != id:
			continue
		if hp[i] > 0:
			return i
		if fallback < 0:
			fallback = i
	return fallback


## Den fiende som just dog: första med rätt id som har hp <= 0 och ännu inte
## markerats som dödad i [param routes].
static func _dead_index(enemies: Array[Enemy], hp: PackedInt32Array, id: String, routes: Array[Dictionary]) -> int:
	for i: int in range(enemies.size()):
		if enemies[i].id != id or hp[i] > 0:
			continue
		if bool((routes[i] as Dictionary)["killed"]):
			continue
		return i
	return -1
