extends GdUnitTestSuite
## Uppspelarens tidslinje: budgeten i UI_GUIDE §5 (tak 2 500 ms för en runda med
## sex tärningar) och löftet i §5.9 att snabbspolning aldrig ändrar utfallet.


## En representativ runda: sex tärningar i handen, fem placerade, ett par, en
## dödad fiende och ett överflödshopp. Samma form som UI_GUIDE §5.8 budgeterar.
func _six_dice_round() -> ResolveResult:
	var built: Dictionary = CombatFixture.build(
		[Rules.SlotType.PLAIN, Rules.SlotType.PLAIN, Rules.SlotType.MIRROR, Rules.SlotType.FIRE, Rules.SlotType.ANVIL],
		[4, 4, 0, 3, 6],
		[5],
		[
			CombatFixture.dummy_enemy("RUST_RAT", 28, 2),
			CombatFixture.dummy_enemy("SLAG_MOTH", 34, 1),
			CombatFixture.dummy_enemy("IRON_TICK", 46, 6),
		],
	)
	return Resolver.resolve(built["state"] as CombatState, built["placement"] as PackedInt32Array)


func _full_round_with_enemy_turn() -> ResolveResult:
	var state: CombatState = Content.smith_state()
	state.enemies = Content.encounter(2, 0)
	state = Resolver.begin_combat(state, Rng.new(31))
	return Resolver.resolve(state, Policy.lookahead(state))


func test_the_six_dice_round_fits_the_budget_without_compression() -> void:
	# Utan komprimering: beviset att överlappsmodellen i sig håller budgeten.
	# Klarar den inte det är komprimeringen en gömma, inte en säkerhetsventil.
	var result: ResolveResult = _six_dice_round()
	var timeline: Array[Dictionary] = EventPlayer.build_timeline(result.events, 1.0, false)
	var chain: int = EventPlayer.chain_ms(timeline)
	assert_int(chain).override_failure_message(
		"okomprimerad kedja blev %d ms, taket är %d ms" % [chain, EventPlayer.BUDGET_MS]
	).is_less(EventPlayer.BUDGET_MS)
	assert_int(EventPlayer.total_ms(timeline)).is_less_equal(EventPlayer.ROUND_BUDGET_MS)


func test_a_naive_fifo_queue_would_break_the_budget() -> void:
	# DECISIONS 2026-09-21: "Naiv summering ger 3,1 s per runda, taket är 2,5 s."
	# Testet finns för att överlappet inte ska kunna optimeras bort av misstag.
	var result: ResolveResult = _six_dice_round()
	var naive: int = 0
	for event: Dictionary in result.events:
		naive += int(event.get("ms_hint", EventPlayer.MS_HINT_FALLBACK))
	var overlapped: int = EventPlayer.total_ms(EventPlayer.build_timeline(result.events, 1.0, false))
	assert_int(naive).is_greater(EventPlayer.BUDGET_MS)
	assert_int(overlapped).is_less(naive)
	# Halva tiden eller bättre: annars är överlappet kosmetiskt.
	assert_int(overlapped).is_less(naive / 2 + naive / 4)


func test_any_round_is_capped_at_the_budget_by_compression() -> void:
	# Även en runda med tre fiendeturer och kåk ska landa under taket.
	for seed_value: int in range(20):
		var state: CombatState = Content.smith_state()
		state.enemies = Content.encounter(3, seed_value % 2)
		state = Resolver.begin_combat(state, Rng.new(seed_value))
		var result: ResolveResult = Resolver.resolve(state, Policy.lookahead(state))
		var timeline: Array[Dictionary] = EventPlayer.build_timeline(result.events)
		var total: int = EventPlayer.total_ms(timeline)
		assert_int(total).override_failure_message(
			"seed %d gav %d ms totalt" % [seed_value, total]).is_less_equal(EventPlayer.ROUND_BUDGET_MS)
		assert_int(EventPlayer.chain_ms(timeline)).override_failure_message(
			"seed %d gav en kedja på %d ms" % [seed_value, EventPlayer.chain_ms(timeline)]
		).is_less_equal(EventPlayer.BUDGET_MS)


func test_every_event_gets_exactly_one_timeline_step_in_order() -> void:
	# "Loggen är komplett": UI får aldrig tappa ett event (ARCHITECTURE).
	var result: ResolveResult = _full_round_with_enemy_turn()
	var timeline: Array[Dictionary] = EventPlayer.build_timeline(result.events)
	assert_int(timeline.size()).is_equal(result.events.size())
	for i: int in range(timeline.size()):
		assert_int(int(timeline[i]["seq"])).is_equal(int(result.events[i]["seq"]))


func test_the_driving_lanes_never_go_backwards() -> void:
	# CHAIN och BEAT utgör tidslinjens ryggrad och måste vara monotona.
	# SIDE-event får däremot ligga en stagger FÖRE nästa kedjesteg – det är
	# själva poängen med en parallell sidokanal – och uppspelaren fyrar dem
	# ändå i loggordning, så ordningen bevaras.
	var result: ResolveResult = _full_round_with_enemy_turn()
	var previous: float = -1.0
	for step: Dictionary in EventPlayer.build_timeline(result.events):
		if int(step["lane"]) == EventPlayer.Lane.SIDE:
			continue
		assert_float(float(step["start_ms"])).is_greater_equal(previous)
		previous = float(step["start_ms"])


func test_the_player_fires_events_in_log_order_even_when_a_side_event_starts_early() -> void:
	var events: Array[Dictionary] = [
		{"t": "die_activated", "seq": 0, "ms_hint": 220},
		{"t": "charge_stored", "seq": 1, "ms_hint": 160},
		{"t": "die_activated", "seq": 2, "ms_hint": 220},
	]
	var timeline: Array[Dictionary] = EventPlayer.build_timeline(events, 1.0, false)
	for i: int in range(timeline.size()):
		assert_int(int(timeline[i]["seq"])).is_equal(i)


func test_chain_events_actually_overlap() -> void:
	var result: ResolveResult = _six_dice_round()
	var timeline: Array[Dictionary] = EventPlayer.build_timeline(result.events, 1.0, false)
	var overlaps: int = 0
	for i: int in range(1, timeline.size()):
		if int(timeline[i]["lane"]) != EventPlayer.Lane.CHAIN:
			continue
		if int(timeline[i - 1]["lane"]) != EventPlayer.Lane.CHAIN:
			continue
		var previous_end: float = float(timeline[i - 1]["start_ms"]) + float(timeline[i - 1]["dur_ms"])
		if float(timeline[i]["start_ms"]) < previous_end:
			overlaps += 1
	assert_int(overlaps).is_greater(0)


func test_side_channel_events_do_not_push_the_timeline() -> void:
	# UI_GUIDE §5.8: "charge_stored körs parallellt med round_end".
	var events: Array[Dictionary] = [
		{"t": "round_start", "seq": 0, "ms_hint": 120},
		{"t": "charge_stored", "seq": 1, "ms_hint": 160},
		{"t": "charge_stored", "seq": 2, "ms_hint": 160},
		{"t": "round_end", "seq": 3, "ms_hint": 120},
	]
	var timeline: Array[Dictionary] = EventPlayer.build_timeline(events, 1.0, false)
	assert_float(float(timeline[1]["start_ms"])).is_equal(120.0)
	assert_float(float(timeline[2]["start_ms"])).is_equal(120.0 + float(EventPlayer.SIDE_STAGGER_MS))
	# round_end börjar där round_start slutade, inte efter de två sidokanalerna.
	assert_float(float(timeline[3]["start_ms"])).is_equal(120.0)


func test_speed_zero_collapses_the_timeline_to_nothing() -> void:
	var result: ResolveResult = _six_dice_round()
	var timeline: Array[Dictionary] = EventPlayer.build_timeline(result.events, 0.0)
	assert_int(EventPlayer.total_ms(timeline)).is_equal(0)
	assert_int(timeline.size()).is_equal(result.events.size())


func test_slower_speed_gives_a_longer_uncompressed_timeline() -> void:
	var result: ResolveResult = _six_dice_round()
	var quick: int = EventPlayer.total_ms(EventPlayer.build_timeline(result.events, 0.6, false))
	var calm: int = EventPlayer.total_ms(EventPlayer.build_timeline(result.events, 1.25, false))
	assert_int(calm).is_greater(quick)


# ---------------------------------------------------------------------------
# Snabbspolning ger samma slutstate
# ---------------------------------------------------------------------------

func test_fast_forward_reaches_the_same_state_as_a_full_playback() -> void:
	var result: ResolveResult = _full_round_with_enemy_turn()
	var before: CombatState = _state_before(31)

	# Full uppspelning: applicera event för event, i tidslinjeordning.
	var slow: Dictionary = EventPlayer.view_from_state(before)
	for step: Dictionary in EventPlayer.build_timeline(result.events, 1.0):
		EventPlayer.apply_event(slow, step["event"] as Dictionary)

	# Snabbspolning: samma logg med ms_hint = 0, allt på en gång.
	var fast: Dictionary = EventPlayer.view_from_state(before)
	for step: Dictionary in EventPlayer.build_timeline(result.events, 0.0):
		EventPlayer.apply_event(fast, step["event"] as Dictionary)

	assert_str(JSON.stringify(fast)).is_equal(JSON.stringify(slow))


func test_the_played_back_view_matches_state_after() -> void:
	# Uppspelningen får aldrig visa något annat än vad resolvern räknade ut.
	for seed_value: int in range(15):
		var before: CombatState = _state_before(seed_value)
		var result: ResolveResult = Resolver.resolve(before, Policy.lookahead(before))
		var view: Dictionary = EventPlayer.apply_all(EventPlayer.view_from_state(before), result.events)
		var after: CombatState = result.state_after

		assert_int(int(view["player_hp"])).override_failure_message(
			"seed %d: HP i vyn %d, i state_after %d" % [seed_value, int(view["player_hp"]), after.player_hp]
		).is_equal(after.player_hp)
		assert_int(int(view["charge"])).is_equal(after.charge)
		assert_int(int(view["ward"])).is_equal(after.ward)
		var enemies: Array = view["enemies"] as Array
		for i: int in range(after.enemies.size()):
			assert_int(int((enemies[i] as Dictionary)["hp"])).override_failure_message(
				"seed %d: fiende %d har fel HP i vyn" % [seed_value, i]
			).is_equal(after.enemies[i].hp)


func test_duplicate_enemy_ids_drain_the_right_health_bar() -> void:
	# Rum 1 är fyra identiska RUST_RAT. Matchas event på id utan att ta hänsyn
	# till vem som lever dränerar vi fel HP-bar.
	var state: CombatState = Content.smith_state()
	state.enemies = Content.encounter(1, 0)
	state = Resolver.begin_combat(state, Rng.new(5))
	var result: ResolveResult = Resolver.resolve(state, Policy.lookahead(state))
	var view: Dictionary = EventPlayer.apply_all(EventPlayer.view_from_state(state), result.events)
	var enemies: Array = view["enemies"] as Array
	for i: int in range(result.state_after.enemies.size()):
		assert_int(int((enemies[i] as Dictionary)["hp"])).is_equal(result.state_after.enemies[i].hp)


func test_applying_a_prefix_of_the_log_never_overshoots_the_end_state() -> void:
	# Varje mellanläge i uppspelningen ska vara ett giltigt läge, inte ett
	# tillstånd som aldrig existerade.
	var before: CombatState = _state_before(8)
	var result: ResolveResult = Resolver.resolve(before, Policy.lookahead(before))
	for cut: int in range(result.events.size() + 1):
		var prefix: Array[Dictionary] = []
		for i: int in range(cut):
			prefix.append(result.events[i])
		var view: Dictionary = EventPlayer.apply_all(EventPlayer.view_from_state(before), prefix)
		assert_int(int(view["player_hp"])).is_between(0, before.player_max_hp)
		assert_int(int(view["charge"])).is_between(0, Rules.CHARGE_CAP)
		for entry: Variant in view["enemies"] as Array:
			assert_int(int((entry as Dictionary)["hp"])).is_greater_equal(0)


func test_unknown_events_are_side_channel_and_cannot_blow_the_budget() -> void:
	assert_int(EventPlayer.lane_of("something_from_m3")).is_equal(EventPlayer.Lane.SIDE)
	var events: Array[Dictionary] = []
	for i: int in range(50):
		events.append({"t": "something_from_m3", "seq": i, "ms_hint": 120})
	assert_int(EventPlayer.total_ms(EventPlayer.build_timeline(events))).is_less_equal(EventPlayer.ROUND_BUDGET_MS)


func test_an_empty_log_gives_an_empty_timeline() -> void:
	var empty: Array[Dictionary] = []
	assert_array(EventPlayer.build_timeline(empty)).is_empty()
	assert_int(EventPlayer.total_ms(EventPlayer.build_timeline(empty))).is_equal(0)


func _state_before(seed_value: int) -> CombatState:
	var state: CombatState = Content.smith_state()
	state.enemies = Content.encounter(2, 0)
	return Resolver.begin_combat(state, Rng.new(seed_value))
