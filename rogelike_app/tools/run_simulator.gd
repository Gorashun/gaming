extends SceneTree
## Headless balanssimulator. GAME_DESIGN §5.
##
## Körs med:
##   godot --headless -s tools/run_simulator.gd -- --battles=1000
##   godot --headless -s tools/run_simulator.gd -- --runs=500 --json=out.json
##
## Flaggor:
##   --battles=N   antal seedade enskilda strider per policy (standard 1000)
##   --runs=N      antal seedade hela runs per policy (standard 0 = av)
##   --room=N      vilket rum striderna hämtas från (standard 1)
##   --width=N     lookahead-policyns sökbredd (standard Policy.DEFAULT_WIDTH)
##   --seed=N      basseed (standard 1)
##   --json=PATH   skriv även statistiken som JSON för regressionsjämförelse
##   --careers=N   M6: N seedade "karriärer" – tutorial + --career-runs runs med
##                 gear, droppar, trappbank, död/Kistan och staden emellan
##                 ([Career]). Rapporterar droppar per run, sällsynthets-
##                 fördelning och kickar per minut (PROGRESSION_REDESIGN §5).
##   --career-runs=N  runs per karriär (standard 10)
##   --career-policy=P  lookahead | greedy | mixed (standard mixed: en vanlig
##                 spelare, planerar varannan runda – lookahead vinner våning 1
##                 nästan alltid och visar därför aldrig döden och Kistan)
##
## M0-kravet: 1 000 strider på under 5 sekunder.

const MAX_ROUNDS: int = 30
const POLICIES: Array[String] = ["greedy", "lookahead"]


func _initialize() -> void:
	var args: Dictionary = _parse_args()
	var battles: int = int(args.get("battles", 1000))
	var runs: int = int(args.get("runs", 0))
	var room: int = int(args.get("room", 1))
	var width: int = int(args.get("width", Policy.DEFAULT_WIDTH))
	var base_seed: int = int(args.get("seed", 1))
	var careers: int = int(args.get("careers", 0))
	var career_runs: int = int(args.get("career-runs", 10))
	var career_policy: String = String(args.get("career-policy", "mixed"))

	var report: Dictionary = {
		"godot": Engine.get_version_info()["string"],
		"battles_per_policy": battles,
		"runs_per_policy": runs,
		"room": room,
		"lookahead_width": width,
		"base_seed": base_seed,
		"policies": {},
	}

	print("PIPWRECK run simulator")
	print("  seed=%d  battles/policy=%d  runs/policy=%d  room=%d  lookahead width=%d" % [base_seed, battles, runs, room, width])
	print("")

	for policy: String in POLICIES:
		var stats: Dictionary = {}
		var started: int = Time.get_ticks_usec()
		if battles > 0:
			stats = _simulate_battles(policy, battles, room, base_seed, width)
		if runs > 0:
			stats["run"] = _simulate_runs(policy, runs, base_seed, width)
		stats["elapsed_ms"] = float(Time.get_ticks_usec() - started) / 1000.0
		report["policies"][policy] = stats
		_print_policy(policy, stats)

	_print_verdict(report)

	if careers > 0:
		report["careers"] = _simulate_careers(careers, career_runs, base_seed, width, career_policy)

	if args.has("json"):
		var file: FileAccess = FileAccess.open(String(args["json"]), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "  "))
			file.close()
			print("Wrote %s" % args["json"])

	quit(0)


# ---------------------------------------------------------------------------
# Enskilda strider
# ---------------------------------------------------------------------------
func _simulate_battles(policy: String, count: int, room: int, base_seed: int, width: int) -> Dictionary:
	var wins: int = 0
	var rounds_total: int = 0
	var rounds_with_combo: int = 0
	var rounds_with_overflow: int = 0
	var rounds_with_charge: int = 0
	var house_bonuses: int = 0
	var explosive_battles: int = 0
	var hp_left_total: int = 0

	for i: int in range(count):
		var battle: Dictionary = _simulate_battle(base_seed + i, policy, room, width)
		if bool(battle["won"]):
			wins += 1
		hp_left_total += maxi(0, int((battle["state"] as CombatState).player_hp))
		rounds_total += int(battle["rounds"])
		rounds_with_combo += int(battle["rounds_with_combo"])
		rounds_with_overflow += int(battle["rounds_with_overflow"])
		rounds_with_charge += int(battle["rounds_with_charge"])
		house_bonuses += int(battle["house_bonuses"])
		if bool(battle["explosive"]):
			explosive_battles += 1

	return {
		"battles": count,
		"win_rate": _ratio(wins, count),
		"rounds_per_battle": _ratio(rounds_total, count),
		"combo_round_rate": _ratio(rounds_with_combo, rounds_total),
		"overflow_round_rate": _ratio(rounds_with_overflow, rounds_total),
		"charge_applied_round_rate": _ratio(rounds_with_charge, rounds_total),
		"house_bonus_per_battle": _ratio(house_bonuses, count),
		"explosion_rate": _ratio(explosive_battles, count),
		"hp_left_avg": _ratio(hp_left_total, count),
	}


func _simulate_battle(seed_value: int, policy: String, room: int, width: int) -> Dictionary:
	var rng: Rng = Rng.new(seed_value)
	var state: CombatState = Content.smith_state()
	state.enemies = Content.encounter(room, rng.next_int(0, 1))
	state = Resolver.begin_combat(state, rng)
	return _play_combat(state, rng, policy, width)


## Spelar en strid till slut och returnerar dess statistik.
func _play_combat(state: CombatState, rng: Rng, policy: String, width: int) -> Dictionary:
	var rounds: int = 0
	var rounds_with_combo: int = 0
	var rounds_with_overflow: int = 0
	var rounds_with_charge: int = 0
	var house_bonuses: int = 0
	var round_damage: Array[int] = []
	var won: bool = false
	var died: bool = false

	while rounds < MAX_ROUNDS:
		var placement: PackedInt32Array = _choose(state, policy, width)
		var result: ResolveResult = Resolver.resolve(state, placement)
		rounds += 1

		var damage: int = 0
		var had_combo: bool = false
		var had_overflow: bool = false
		var had_charge: bool = false
		for event: Dictionary in result.events:
			match String(event.get("t", "")):
				"damage_dealt":
					damage += int(event["amount"])
					if int(event["overflow"]) > 0:
						had_overflow = true
				"status_ticked":
					damage += int(event["amount"])
				"combo_formed":
					had_combo = true
				"house_bonus":
					house_bonuses += 1
				"charge_applied":
					if int(event["amount"]) > 0:
						had_charge = true
		round_damage.append(damage)
		if had_combo:
			rounds_with_combo += 1
		if had_overflow:
			rounds_with_overflow += 1
		if had_charge:
			rounds_with_charge += 1

		state = result.state_after
		if state.player_dead:
			died = true
			break
		if state.is_won():
			won = true
			break
		state = Resolver.advance(state, rng)

	return {
		"won": won,
		"died": died,
		"rounds": rounds,
		"rounds_with_combo": rounds_with_combo,
		"rounds_with_overflow": rounds_with_overflow,
		"rounds_with_charge": rounds_with_charge,
		"house_bonuses": house_bonuses,
		"explosive": _is_explosive(round_damage),
		"state": state,
	}


## Explosionsfrekvens (§5): fanns en runda som gjorde >= 3× stridens median?
func _is_explosive(round_damage: Array[int]) -> bool:
	if round_damage.size() < 2:
		return false
	var sorted: Array[int] = round_damage.duplicate()
	sorted.sort()
	var median: int = sorted[sorted.size() / 2]
	if median <= 0:
		return false
	return sorted[sorted.size() - 1] >= median * 3


# ---------------------------------------------------------------------------
# Hela runs (våning 1: fyra rum, boss sist)
# ---------------------------------------------------------------------------
func _simulate_runs(policy: String, count: int, base_seed: int, width: int) -> Dictionary:
	var wins: int = 0
	var rooms_cleared: int = 0
	for i: int in range(count):
		var outcome: Dictionary = _simulate_run(base_seed + 100000 + i, policy, width)
		if bool(outcome["won"]):
			wins += 1
		rooms_cleared += int(outcome["rooms_cleared"])
	return {
		"runs": count,
		"win_rate": _ratio(wins, count),
		"rooms_cleared_avg": _ratio(rooms_cleared, count),
	}


func _simulate_run(seed_value: int, policy: String, width: int) -> Dictionary:
	var rng: Rng = Rng.new(seed_value)
	var state: CombatState = Content.smith_state()
	var rooms_cleared: int = 0
	var pool: Array[Dictionary] = Content.reward_pool()
	var owned: Dictionary = {}

	for room: int in range(1, Content.rooms_per_floor() + 1):
		state.enemies = Content.encounter(room, rng.next_int(0, 1))
		state = Resolver.begin_combat(state, rng)
		var outcome: Dictionary = _play_combat(state, rng, policy, width)
		state = Resolver.end_combat(outcome["state"])
		if not bool(outcome["won"]):
			return {"won": false, "rooms_cleared": rooms_cleared}
		rooms_cleared += 1
		# Andrum (GAME_DESIGN §1): laker efter varje vunnen COMBAT, inte efter boss.
		if room != Content.rooms_per_floor():
			state.player_hp = mini(state.player_max_hp, state.player_hp + Rules.BREATHER_HEAL)

		var floor_key: int = 0 if room == Content.rooms_per_floor() else 1
		var available: Array[Dictionary] = []
		for entry: Dictionary in pool:
			if not owned.has(String(entry["id"])):
				available.append(entry)
		var options: Array[Dictionary] = Rewards.generate(available, rng, floor_key)
		if not options.is_empty():
			var choice: Dictionary = options[rng.next_int(0, options.size() - 1)] as Dictionary
			owned[String(choice["id"])] = true
			_apply_reward(state, choice, rng)

	return {"won": true, "rooms_cleared": rooms_cleared}


## Enkel automatisk tillämpning av en belöning. Policyn för VILKET val som är
## bäst är M3-arbete; här räcker det att builden faktiskt förändras.
func _apply_reward(state: CombatState, choice: Dictionary, rng: Rng) -> void:
	var data: Dictionary = choice.get("data", {}) as Dictionary
	match String(choice.get("category", "")):
		Rewards.CATEGORY_FORGE_FACE:
			var die: Die = state.dice[rng.next_int(0, state.dice.size() - 1)]
			# Smid om den lägsta sidan: det är alltid rätt drag för en bot.
			var lowest: int = 0
			for i: int in range(die.faces.size()):
				if die.faces[i].value < die.faces[lowest].value:
					lowest = i
			die.reforge(lowest, Content.make_face(String(data.get("face_id", ""))))
		Rewards.CATEGORY_RELIC:
			state.relics.append(Content.make_relic(String(data.get("relic_id", ""))))
		Rewards.CATEGORY_SLOT_SWAP:
			var slot: Slot = state.board.slots[rng.next_int(0, state.board.size() - 1)]
			slot.type = int(data.get("slot_type", slot.type))


# ---------------------------------------------------------------------------
# M6: karriärer (progression)
# ---------------------------------------------------------------------------
func _simulate_careers(count: int, runs: int, base_seed: int, width: int, policy: String) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var per_run: Array = []
	for i: int in range(runs):
		per_run.append({"drops": 0, "kicks": 0, "seconds": 0.0, "wins": 0, "rare": 0,
			"level": 0, "slots": 0, "rescues": 0})
	var by_rarity: Array[int] = [0, 0, 0, 0]
	var drops: int = 0
	var kicks: int = 0
	var seconds: float = 0.0
	var wins: int = 0
	var rare_moments: int = 0
	var total_runs: int = 0
	for c: int in range(count):
		var career: Array[Dictionary] = Career.play_career(runs, base_seed + c, policy, width)
		for i: int in range(career.size()):
			var r: Dictionary = career[i]
			var row: Dictionary = per_run[i]
			row["drops"] = int(row["drops"]) + int(r["drops"])
			row["kicks"] = int(row["kicks"]) + int(r["kicks"])
			row["seconds"] = float(row["seconds"]) + float(r["seconds"])
			row["wins"] = int(row["wins"]) + (1 if bool(r["won"]) else 0)
			row["rare"] = int(row["rare"]) + int(r["rare_moments"])
			row["level"] = int(row["level"]) + int(r["hero_level"])
			row["slots"] = int(row["slots"]) + int(r["slots"])
			row["rescues"] = int(row["rescues"]) + int(r["rescues"])
			for k: int in range(4):
				by_rarity[k] += int((r["drops_by_rarity"] as Array)[k])
			drops += int(r["drops"])
			kicks += int(r["kicks"])
			seconds += float(r["seconds"])
			rare_moments += int(r["rare_moments"])
			wins += 1 if bool(r["won"]) else 0
			total_runs += 1
	var out: Dictionary = {
		"policy": policy,
		"careers": count,
		"runs_per_career": runs,
		"drops_per_run": _fratio(float(drops), float(total_runs)),
		"rarity_share": [
			_fratio(float(by_rarity[0]), float(drops)), _fratio(float(by_rarity[1]), float(drops)),
			_fratio(float(by_rarity[2]), float(drops)), _fratio(float(by_rarity[3]), float(drops)),
		],
		"rare_moments_per_run": _fratio(float(rare_moments), float(total_runs)),
		"kicks_per_run": _fratio(float(kicks), float(total_runs)),
		"kicks_per_minute": _fratio(float(kicks), seconds / 60.0),
		"minutes_per_run": _fratio(seconds / 60.0, float(total_runs)),
		"win_rate": _fratio(float(wins), float(total_runs)),
		"per_run": [],
		"elapsed_ms": float(Time.get_ticks_usec() - started) / 1000.0,
	}
	print("[CAREERS]  %d careers x %d runs (%s, width %d)" % [count, runs, policy, width])
	print("  drops per run        %.2f" % float(out["drops_per_run"]))
	print("  rarity share         common %.1f %%  uncommon %.1f %%  rare %.1f %%  epic %.1f %%" % [
		float(out["rarity_share"][0]) * 100.0, float(out["rarity_share"][1]) * 100.0,
		float(out["rarity_share"][2]) * 100.0, float(out["rarity_share"][3]) * 100.0])
	print("  rare+ moments/run    %.2f  (target 0.6)" % float(out["rare_moments_per_run"]))
	print("  kicks per run        %.1f" % float(out["kicks_per_run"]))
	print("  kicks per minute     %.2f  (target 0.9-1.1)" % float(out["kicks_per_minute"]))
	print("  minutes per run      %.1f" % float(out["minutes_per_run"]))
	print("  run win rate         %.1f %%" % (float(out["win_rate"]) * 100.0))
	print("  run  drops  kicks/min  wins  rare+  hero lvl  slots  rescues")
	for i: int in range(runs):
		var row: Dictionary = per_run[i]
		var entry: Dictionary = {
			"run": i + 1,
			"drops": _fratio(float(row["drops"]), float(count)),
			"kicks_per_minute": _fratio(float(row["kicks"]), float(row["seconds"]) / 60.0),
			"win_rate": _fratio(float(row["wins"]), float(count)),
			"rare_moments": _fratio(float(row["rare"]), float(count)),
			"hero_level": _fratio(float(row["level"]), float(count)),
			"slots": _fratio(float(row["slots"]), float(count)),
			"rescues": _fratio(float(row["rescues"]), float(count)),
		}
		(out["per_run"] as Array).append(entry)
		print("  %3d  %5.2f  %9.2f  %4.0f%%  %5.2f  %8.2f  %5.2f  %7.2f" % [
			i + 1, float(entry["drops"]), float(entry["kicks_per_minute"]),
			float(entry["win_rate"]) * 100.0, float(entry["rare_moments"]),
			float(entry["hero_level"]), float(entry["slots"]), float(entry["rescues"])])
	print("  elapsed              %.0f ms" % float(out["elapsed_ms"]))
	print("")
	return out


func _fratio(numerator: float, denominator: float) -> float:
	if denominator <= 0.0:
		return 0.0
	return numerator / denominator


# ---------------------------------------------------------------------------
# Utskrift
# ---------------------------------------------------------------------------
func _choose(state: CombatState, policy: String, width: int) -> PackedInt32Array:
	if policy == "lookahead":
		return Policy.lookahead(state, width)
	return Policy.greedy(state)


func _print_policy(policy: String, stats: Dictionary) -> void:
	print("[%s]" % policy.to_upper())
	if stats.has("battles"):
		print("  battles              %d" % int(stats["battles"]))
		print("  win rate             %.1f %%" % (float(stats["win_rate"]) * 100.0))
		print("  rounds per battle    %.2f" % float(stats["rounds_per_battle"]))
		print("  rounds with combo    %.1f %%" % (float(stats["combo_round_rate"]) * 100.0))
		print("  rounds with overflow %.1f %%" % (float(stats["overflow_round_rate"]) * 100.0))
		print("  rounds using charge  %.1f %%" % (float(stats["charge_applied_round_rate"]) * 100.0))
		print("  house bonus/battle   %.2f" % float(stats["house_bonus_per_battle"]))
		print("  explosion rate       %.1f %%" % (float(stats["explosion_rate"]) * 100.0))
		print("  hp left avg          %.1f" % float(stats.get("hp_left_avg", 0.0)))
	if stats.has("run"):
		var run_stats: Dictionary = stats["run"]
		print("  full runs            %d" % int(run_stats["runs"]))
		print("  run win rate         %.1f %%" % (float(run_stats["win_rate"]) * 100.0))
		print("  rooms cleared avg    %.2f" % float(run_stats["rooms_cleared_avg"]))
	print("  elapsed              %.0f ms" % float(stats["elapsed_ms"]))
	print("")


## Det viktigaste måttet i hela projektet (GAME_DESIGN §5): om lookahead inte
## vinner tydligt mer än greedy är placeringen meningslös.
func _print_verdict(report: Dictionary) -> void:
	var policies: Dictionary = report["policies"]
	if not (policies.has("greedy") and policies.has("lookahead")):
		return
	var greedy_rate: float = _win_rate(policies["greedy"] as Dictionary)
	var lookahead_rate: float = _win_rate(policies["lookahead"] as Dictionary)
	var delta: float = (lookahead_rate - greedy_rate) * 100.0
	report["lookahead_minus_greedy_pp"] = delta
	print("Lookahead minus greedy: %+.1f percentage points (target: >= 10)" % delta)
	if delta < 10.0:
		print("  WARNING: placement may not matter enough (GAME_DESIGN section 5 stop rule)")


## Vinstprocenten för hela runs om de körts, annars för enskilda strider.
func _win_rate(stats: Dictionary) -> float:
	if stats.has("run"):
		return float((stats["run"] as Dictionary).get("win_rate", 0.0))
	return float(stats.get("win_rate", 0.0))


func _ratio(numerator: int, denominator: int) -> float:
	if denominator == 0:
		return 0.0
	return float(numerator) / float(denominator)


func _parse_args() -> Dictionary:
	var parsed: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var body: String = arg.substr(2)
		var split: int = body.find("=")
		if split < 0:
			parsed[body] = true
		else:
			parsed[body.substr(0, split)] = body.substr(split + 1)
	return parsed
