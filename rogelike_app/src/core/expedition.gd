class_name Expedition
extends RefCounted
## "All styrka är dödlig." Hjältens väg ner och upp igen. PROGRESSION_REDESIGN
## §3.4, DECISIONS 2026-09-23.
##
## [codeblock]
## UTRUSTAT GEAR ÄR DITT DIREKT – men osäkrat.
## TRAPPAN är en BANK: skicka upp valfritt antal föremål. Säkra för alltid,
##   men de bärs inte resten av runnen.
## VINST → allt du bär säkras.
## DÖD → allt osäkrat går förlorat, OCH hjälten dör permanent.
##   UTOM: Kistan räddar N föremål (N = nivå 0..3, + MARROWS_TARP, + annonsen).
## [/codeblock]
##
## [b]Ägandet under en run:[/b] rostrets post är hjälten [i]som hen gick ner[/i].
## Runnen bär en kopia ([member RunState.hero]) med allt osäkrat. Vinst skriver
## tillbaka kopian; död begraver posten. En run som överges (ny run från titeln,
## "Reset save") rör inte rostret alls – hjälten står kvar i tavernan med det hen
## hade när hen gick ner, och det som hittades i den övergivna runnen är borta.
##
## Allt här är ren logik utan Node-beroenden och utan slump.


## Förbereder runnen: räknar upp run-numret, lyfter hjälten till kurvans
## nivågolv, och lägger en osäkrad kopia av hjälten och hens plagg på runnen.
## Returnerar [code]{hero_id, level_ups}[/code].
static func begin(meta: Meta, run: RunState, seed_value: int, body_variant: String = "a") -> Dictionary:
	meta.runs_started += 1
	var hero: Hero = meta.ensure_hero(seed_value, body_variant)
	var level_ups: int = hero.raise_to_level(Progression.level_floor(meta.runs_started))
	hero.runs += 1
	var carried: Hero = hero.copy()
	carried.set_all_secured(false)
	run.hero = carried
	run.pack = []
	run.meta["hero_id"] = hero.id
	if run.combat != null:
		run.combat = GearRules.sync_combat(run.combat, carried)
	return {"hero_id": hero.id, "level_ups": level_ups}


## Trappbanken: skickar föremålen på [param indices] (index i
## [method RunState.carried_items]) upp med kärran. De tas av hjälten och ur
## packningen och läggs säkrade i banken. Returnerar det som skickades.
static func bank(meta: Meta, run: RunState, indices: Array) -> Array[Item]:
	var carried: Array[Item] = run.carried_items()
	var chosen: Array[Item] = []
	for raw: Variant in indices:
		var index: int = int(raw)
		if index >= 0 and index < carried.size() and not chosen.has(carried[index]):
			chosen.append(carried[index])
	for item: Item in chosen:
		_remove_carried(run, item)
	meta.bank.deposit(chosen)
	if run.combat != null and run.hero != null:
		run.combat = GearRules.sync_combat(run.combat, run.hero)
	return chosen


static func _remove_carried(run: RunState, item: Item) -> void:
	if run.hero != null and run.hero.equipped(item.slot) == item:
		run.hero.unequip(item.slot)
		return
	run.pack.erase(item)


## Hur många föremål Marrow får rädda. [param ad_bonus] är räddningsannonsens
## extra plats (0 eller 1) – frivillig, aldrig ett avbrott (DECISIONS 2026-09-22).
static func rescue_capacity(meta: Meta, run: RunState, ad_bonus: int = 0) -> int:
	return GearRules.rescue_slots(meta.building_level(Buildings.CHEST), run.hero) + maxi(0, ad_bonus)


## Döden. Föremålen på [param rescued] (index i [method RunState.carried_items],
## högst [method rescue_capacity] stycken) läggs i Kistan; resten går förlorat.
## Hjälten begravs. Returnerar [code]{rescued, lost, hero_name, capacity}[/code]
## med föremåls-id:n, för dödsskärmen och testerna.
static func die(meta: Meta, run: RunState, rescued: Array, killed_by: String, ad_bonus: int = 0) -> Dictionary:
	var carried: Array[Item] = run.carried_items()
	var capacity: int = rescue_capacity(meta, run, ad_bonus)
	var kept: Array[Item] = []
	for raw: Variant in rescued:
		var index: int = int(raw)
		if kept.size() >= capacity:
			break
		if index >= 0 and index < carried.size() and not kept.has(carried[index]):
			kept.append(carried[index])
	meta.chest.store(kept)
	var lost: Array[String] = []
	var kept_ids: Array[String] = []
	for item: Item in carried:
		if kept.has(item):
			kept_ids.append(item.id)
		else:
			lost.append(item.id)
	var hero_id: String = String(run.meta.get("hero_id", run.hero.id if run.hero != null else ""))
	var hero_name: String = run.hero.name if run.hero != null else ""
	meta.roster.bury(hero_id, killed_by, meta.runs_started)
	run.pack = []
	return {"rescued": kept_ids, "lost": lost, "hero_name": hero_name, "capacity": capacity}


## Vinsten: allt hjälten bär säkras och följer med upp, packningen går till
## banken (den kan inte bäras), hjälten får sin XP. [param rooms_cleared] och
## [param bosses] ger XP enligt §4.2. Returnerar [code]{xp, level_ups, banked}[/code].
static func win(meta: Meta, run: RunState, rooms_cleared: int, bosses: int) -> Dictionary:
	meta.bosses_killed += maxi(0, bosses)
	if run.hero == null:
		return {"xp": 0, "level_ups": 0, "banked": 0}
	var hero: Hero = run.hero.copy()
	hero.set_all_secured(true)
	var xp: int = Hero.xp_for_run(rooms_cleared, bosses, true)
	var level_ups: int = hero.add_xp(xp)
	var banked: int = run.pack.size()
	meta.bank.deposit(run.pack)
	run.pack = []
	var hero_id: String = String(run.meta.get("hero_id", hero.id))
	if hero.id == "":
		hero.id = hero_id
	if not meta.roster.replace(hero):
		# En migrerad v3-run bar en hjälte utan id: hen tar rostrets aktiva plats.
		var active: Hero = meta.roster.active()
		if active != null:
			hero.id = active.id
			hero.name = active.name if hero.name == "" else hero.name
			hero.quirk = active.quirk if hero.quirk == "" else hero.quirk
			meta.roster.replace(hero)
		else:
			meta.roster.add(hero)
	for item: Item in hero.equipped_items():
		meta.note_found(item.id)
	return {"xp": xp, "level_ups": level_ups, "banked": banked}


## Tavernan efter en död: finns ingen levande hjälte rekryteras en, och hen tar
## på sig det bästa Kistan har i de slots hen har låst upp (§3.4: "ny hjälte med
## gear ur Kistan"). Returnerar hjälten.
static func recruit_replacement(meta: Meta, seed_value: int, body_variant: String = "a") -> Hero:
	var hero: Hero = meta.roster.active()
	if hero != null:
		return hero
	hero = meta.ensure_hero(seed_value, body_variant)
	equip_best_from_chest(meta, hero)
	return hero


## Tar på det sällsyntaste Kistan har i varje ledig, upplåst slot.
static func equip_best_from_chest(meta: Meta, hero: Hero) -> int:
	var equipped: int = 0
	for slot: String in hero.unlocked_slots():
		if hero.equipped(slot) != null:
			continue
		var best: int = -1
		for i: int in range(meta.chest.items.size()):
			var item: Item = meta.chest.items[i]
			if item.slot != slot:
				continue
			if best < 0 or item.rarity > meta.chest.items[best].rarity:
				best = i
		if best >= 0:
			hero.equip(meta.chest.take(best))
			equipped += 1
	return equipped


## Staden: tar på ett föremål ur Kistan ([code]"chest"[/code]) eller banken
## ([code]"bank"[/code]). Det som satt där går till banken. Returnerar false om
## sloten är låst eller indexet fel – och då har ingenting flyttats.
static func equip_from_storage(meta: Meta, hero: Hero, storage: String, index: int) -> bool:
	if hero == null:
		return false
	var items: Array[Item] = meta.chest.items if storage == "chest" else meta.bank.items
	if index < 0 or index >= items.size() or not hero.is_slot_unlocked(items[index].slot):
		return false
	var item: Item = meta.chest.take(index) if storage == "chest" else meta.bank.take(index)
	var previous: Item = hero.equip(item)
	if previous != null:
		meta.bank.deposit([previous])
	return true


## Staden: tar av ett plagg och lägger det i banken.
static func unequip_to_bank(meta: Meta, hero: Hero, slot: String) -> bool:
	if hero == null:
		return false
	var item: Item = hero.unequip(slot)
	if item == null:
		return false
	meta.bank.deposit([item])
	return true
