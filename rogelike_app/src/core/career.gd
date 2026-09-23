class_name Career
extends RefCounted
## Headless spelare för hela runs [i]med progression[/i]: gear, droppar,
## trappbanken, död och Kistan, staden mellan runs. Används av
## [code]tools/run_simulator.gd --careers[/code] och av progressionskurvans test.
##
## [b]Samma regler som spelet, inte en modell av dem.[/b] Varje steg går genom
## samma funktioner som [GameController] anropar: [method Expedition.begin],
## [method RunFlow.start_room], [method Drops.roll_room], [method Rewards.with_drops],
## [method RewardApply.apply_to_run], [method Expedition.die] / [method Expedition.win].
## Det enda som är modell är [b]tiden[/b] (för kickar per minut) och
## [b]boten[/b] som väljer kort och köper byggnader.
##
## [b]Policyer:[/b] [code]lookahead[/code] (taket), [code]greedy[/code] (golvet)
## och [code]mixed[/code] – en "vanlig spelare" som planerar varannan runda. Myntet
## dras ur en egen delström ([code]fork("bot")[/code]) så att boten aldrig flyttar
## spelets slumpström.
##
## [b]Kick[/b] (PROGRESSION_REDESIGN §5): loot-drop, belöningsval, nivåhöjning,
## upplåsning (byggnad), sällsynthetsögonblick (rare+) och räddningsscen.

## Tidsmodellen. GAME_DESIGN §1: en runda ≈ 30 s; belöningsvalet ≈ 8 s;
## korridoren ≈ 15 s per våning (DECISIONS 2026-09-21, uppmätt i rökprovet);
## trappbanken och Marrows räddning ≈ 10 s.
const SECONDS_PER_ROUND: float = 30.0
const SECONDS_PER_REWARD: float = 8.0
const SECONDS_CORRIDOR: float = 15.0
const SECONDS_PROMPT: float = 10.0
const MAX_ROUNDS: int = 30
## Byggnaderna boten köper, i den ordning en förstagångsspelare troligen gör.
const BUY_ORDER: Array[String] = [Buildings.CHEST, Buildings.TAVERN, Buildings.FORGE, Buildings.MARKET]


## Spelar tutorialens garanti (run 0): hjälte nummer ett och ett COMMON-plagg på
## kroppen. Resten av källaren är pedagogik och simuleras inte.
static func tutorial(meta: Meta, seed_value: int) -> Dictionary:
	var hero: Hero = meta.ensure_hero(seed_value)
	var gift: Item = Content.make_item(Progression.TUTORIAL_GIFT)
	hero.equip(gift)
	Progression.note_drops(meta, [gift])
	meta.tutorial_done = true
	meta.runs = maxi(meta.runs, 1)
	meta.pips += Meta.PIPS_WIN
	return {"kicks": 2, "drops": 1}


## Spelar en hel run och returnerar dess statistik. Muterar [param meta] precis
## som en riktig run gör.
static func play_run(meta: Meta, seed_value: int, policy: String = "lookahead",
		width: int = Policy.DEFAULT_WIDTH) -> Dictionary:
	var run: RunState = RunState.new_run(seed_value)
	var rng: Rng = run.make_rng()
	var graph: RunGraph = RunGraph.generate_floor(1, rng)
	var map: CorridorMap = CorridorMap.build(graph, rng.fork("corridor"))
	var begun: Dictionary = Expedition.begin(meta, run, seed_value)
	var bot: Rng = rng.fork("bot")

	var stats: Dictionary = {
		"run": meta.runs_started,
		"won": false,
		"rooms_cleared": 0,
		"rounds": 0,
		"drops": 0,
		"drops_by_rarity": [0, 0, 0, 0],
		"rare_moments": 0,
		"rewards": 0,
		"level_ups": int(begun["level_ups"]),
		"unlocks": 0,
		"rescues": 0,
		"banked": 0,
		"hero_level": run.hero.level,
		"slots": run.hero.gear_slots_unlocked(),
		"seconds": SECONDS_CORRIDOR,
		"kicks": int(begun["level_ups"]),
	}
	var epics: Array[int] = [0]
	var pool: Array[Dictionary] = Content.reward_pool()
	var taken: Array = []

	# Altarna i återvändsgränderna: en upptäcktsbenägen bot går in i varje.
	for key: Variant in map.cells:
		var cell: Dictionary = map.cells[key] as Dictionary
		if String((cell.get("treasure", {}) as Dictionary).get("id", "")) == "RELIC":
			var ctx: Dictionary = Progression.drop_context(meta, run, 1, 0, epics[0])
			var altar: Item = Drops.roll_source(Drops.SOURCE_ALTAR, Drops.stream(rng, String(key)), ctx)
			epics[0] = int(ctx["epics_this_run"])
			if altar != null:
				_note_drop(meta, stats, altar)
				GearRules.take_item(run, altar)

	var node_id: String = graph.start_id
	var room_in_run: int = 0
	while node_id != "":
		var node: Dictionary = graph.node_at(node_id)
		room_in_run += 1
		var boss: bool = RunFlow.is_boss(node)
		if boss:
			stats["banked"] = _bank_before_boss(meta, run)
			if int(stats["banked"]) > 0:
				stats["seconds"] = float(stats["seconds"]) + SECONDS_PROMPT
		run.combat = RunFlow.start_room(run.combat, node, rng)
		var enemy_ids: Array = []
		for enemy: Enemy in run.combat.enemies:
			enemy_ids.append(enemy.id)
		var fight: Dictionary = _fight(run.combat, rng, policy, width, bot)
		stats["rounds"] = int(stats["rounds"]) + int(fight["rounds"])
		stats["seconds"] = float(stats["seconds"]) + float(fight["rounds"]) * SECONDS_PER_ROUND
		run.combat = fight["state"] as CombatState
		if not bool(fight["won"]):
			var capacity: int = Expedition.rescue_capacity(meta, run)
			var death: Dictionary = Expedition.die(meta, run, _best_indices(run, capacity),
				String(fight["killed_by"]))
			if not (death["rescued"] as Array).is_empty():
				stats["rescues"] = 1
				stats["kicks"] = int(stats["kicks"]) + 1
				stats["seconds"] = float(stats["seconds"]) + SECONDS_PROMPT
			meta.award_run(int(stats["rooms_cleared"]), false, false, [])
			break
		stats["rooms_cleared"] = int(stats["rooms_cleared"]) + 1
		run.combat = RunFlow.finish_room(run.combat, node)

		var ctx: Dictionary = Progression.drop_context(meta, run, 1, room_in_run, epics[0])
		var drops: Array[Item] = Drops.roll_room(enemy_ids, Drops.stream(rng, node_id), ctx)
		epics[0] = int(ctx["epics_this_run"])
		for item: Item in drops:
			_note_drop(meta, stats, item)

		if boss:
			for item: Item in drops:
				GearRules.take_item(run, item)
			var won: Dictionary = Expedition.win(meta, run, int(stats["rooms_cleared"]) - 1, 1)
			stats["won"] = true
			stats["level_ups"] = int(stats["level_ups"]) + int(won["level_ups"])
			stats["kicks"] = int(stats["kicks"]) + int(won["level_ups"])
			meta.award_run(int(stats["rooms_cleared"]), true, true, [])
			break

		var gear_options: Array[Dictionary] = []
		for item: Item in drops:
			gear_options.append(Rewards.gear_option(item, GearRules.equip_target(run.hero, item)))
		var options: Array[Dictionary] = Rewards.with_drops(
			Rewards.generate(RunFlow.available_pool(pool, taken), rng, RunFlow.reward_floor_key(node)),
			gear_options)
		if not options.is_empty():
			var choice: Dictionary = _choose(run, options, rng)
			RewardApply.apply_to_run(run, choice, RewardApply.default_target(run.combat, choice))
			if String(choice.get("category", "")) != Rewards.CATEGORY_GEAR:
				taken.append(String(choice.get("id", "")))
			stats["rewards"] = int(stats["rewards"]) + 1
			stats["kicks"] = int(stats["kicks"]) + 1
			stats["seconds"] = float(stats["seconds"]) + SECONDS_PER_REWARD
		var next: Array[String] = graph.next_ids(node_id)
		node_id = next[0] if not next.is_empty() else ""

	stats["unlocks"] = _between_runs(meta, seed_value)
	stats["kicks"] = int(stats["kicks"]) + int(stats["unlocks"])
	stats["kicks_per_minute"] = float(stats["kicks"]) / maxf(1.0, float(stats["seconds"]) / 60.0)
	return stats


## Spelar [param count] runs efter tutorialen från en färsk profil.
static func play_career(count: int, seed_value: int, policy: String = "lookahead",
		width: int = Policy.DEFAULT_WIDTH) -> Array[Dictionary]:
	var meta: Meta = Meta.fresh()
	tutorial(meta, seed_value)
	Market.rotate(meta, seed_value)
	var out: Array[Dictionary] = []
	for i: int in range(count):
		out.append(play_run(meta, seed_value * 1000 + i + 1, policy, width))
	return out


static func _note_drop(meta: Meta, stats: Dictionary, item: Item) -> void:
	Progression.note_drops(meta, [item])
	stats["drops"] = int(stats["drops"]) + 1
	var by_rarity: Array = stats["drops_by_rarity"] as Array
	by_rarity[item.rarity] = int(by_rarity[item.rarity]) + 1
	stats["kicks"] = int(stats["kicks"]) + 1
	if item.rarity >= Rules.Rarity.RARE:
		stats["rare_moments"] = int(stats["rare_moments"]) + 1
		stats["kicks"] = int(stats["kicks"]) + 1


## Andelen rundor [code]mixed[/code]-boten planerar med lookahead.
const MIXED_LOOKAHEAD_SHARE: float = 0.5


static func _fight(state: CombatState, rng: Rng, policy: String, width: int, bot: Rng) -> Dictionary:
	var rounds: int = 0
	var killed_by: String = ""
	while rounds < MAX_ROUNDS:
		var plan: bool = policy == "lookahead" \
			or (policy == "mixed" and bot.next_float() < MIXED_LOOKAHEAD_SHARE)
		var placement: PackedInt32Array = Policy.lookahead(state, width) if plan else Policy.greedy(state)
		var result: ResolveResult = Resolver.resolve(state, placement)
		rounds += 1
		state = result.state_after
		if state.player_dead:
			for event: Dictionary in result.events_of("player_died"):
				killed_by = String(event.get("killed_by", ""))
			return {"won": false, "rounds": rounds, "state": state, "killed_by": killed_by}
		if state.is_won():
			return {"won": true, "rounds": rounds, "state": state, "killed_by": ""}
		state = Resolver.advance(state, rng)
	return {"won": false, "rounds": rounds, "state": state, "killed_by": "TIMEOUT"}


## Boten tar ett föremål som hamnar på kroppen och är bättre än det som sitter
## där; annars ett slumpat kort (samma bot som M1-simulatorn).
static func _choose(run: RunState, options: Array[Dictionary], rng: Rng) -> Dictionary:
	for option: Dictionary in options:
		if String(option.get("category", "")) != Rewards.CATEGORY_GEAR:
			continue
		var target: Dictionary = (option["data"] as Dictionary)["target"] as Dictionary
		if bool(target.get("to_pack", false)):
			continue
		var worn: Item = run.hero.equipped(String(target.get("slot", ""))) if run.hero != null else null
		if worn == null or int(option.get("rarity", 0)) > worn.rarity:
			return option
	return options[rng.next_int(0, options.size() - 1)]


## Före bossen skickar boten upp allt i packningen: det bärs ändå inte.
static func _bank_before_boss(meta: Meta, run: RunState) -> int:
	var worn: int = run.hero.equipped_items().size() if run.hero != null else 0
	var indices: Array = []
	for i: int in range(run.pack.size()):
		indices.append(worn + i)
	return Expedition.bank(meta, run, indices).size()


## Marrows val: det sällsyntaste först.
static func _best_indices(run: RunState, capacity: int) -> Array:
	var carried: Array[Item] = run.carried_items()
	var order: Array = []
	for i: int in range(carried.size()):
		order.append(i)
	order.sort_custom(func(a: Variant, b: Variant) -> bool:
		return carried[int(a)].rarity > carried[int(b)].rarity)
	return order.slice(0, capacity)


## Staden mellan runs: köp byggnader i [constant BUY_ORDER], ersätt en död
## hjälte, rotera marknaden. Returnerar antal upplåsningar (kickar).
static func _between_runs(meta: Meta, seed_value: int) -> int:
	var unlocks: int = 0
	var bought: bool = true
	while bought:
		bought = false
		for building: String in BUY_ORDER:
			if meta.buy_building(building):
				unlocks += 1
				bought = true
				break
	Expedition.recruit_replacement(meta, seed_value)
	Market.rotate(meta, seed_value)
	return unlocks
