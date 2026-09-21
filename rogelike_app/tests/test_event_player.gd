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


# ---------------------------------------------------------------------------
# Feedback-specen (UI_GUIDE §5 + assets/sfx/README.md §2–3)
# ---------------------------------------------------------------------------

func test_every_chain_step_raises_the_pitch_one_semitone() -> void:
	var previous: float = 0.0
	for step: int in range(6):
		var fb: Dictionary = EventPlayer.feedback({"t": "die_activated"}, step)
		assert_str(String(fb["sfx"])).is_equal("die_activate")
		var pitch: float = float(fb["pitch"])
		assert_float(pitch).is_equal_approx(pow(2.0, float(step) / 12.0), 0.0001)
		assert_float(pitch).is_greater(previous)
		previous = pitch


func test_the_pitch_is_capped_at_twelve_steps() -> void:
	# PM:s M2-brief: pow(2, min(step, 12) / 12). Utan tak låter en lång kedja
	# med tre combos som en telefonsignal (assets/sfx/README.md §3.1).
	assert_float(float(EventPlayer.feedback({"t": "die_activated"}, 12)["pitch"])).is_equal_approx(2.0, 0.0001)
	assert_float(float(EventPlayer.feedback({"t": "die_activated"}, 99)["pitch"])).is_equal_approx(2.0, 0.0001)


func test_a_combo_picks_its_cue_and_its_haptic_by_multiplier() -> void:
	var pair: Dictionary = EventPlayer.feedback({"t": "combo_formed", "multiplier": 2}, 0)
	var triple: Dictionary = EventPlayer.feedback({"t": "combo_formed", "multiplier": 4}, 0)
	var house: Dictionary = EventPlayer.feedback({"t": "combo_formed", "multiplier": 8}, 0)
	assert_str(String(pair["sfx"])).is_equal("combo_pair")
	assert_str(String(triple["sfx"])).is_equal("combo_triple")
	assert_str(String(house["sfx"])).is_equal("combo_house")
	assert_int(int(pair["haptic"])).is_equal(Haptics.Level.MEDIUM)
	assert_int(int(house["haptic"])).is_equal(Haptics.Level.HEAVY)
	# Tonhöjden hoppar extra per combo (UI_GUIDE §5: bonus 2 / 4 / 7).
	assert_float(float(triple["pitch"])).is_greater(float(pair["pitch"]))
	assert_float(float(house["pitch"])).is_greater(float(triple["pitch"]))


func test_only_four_and_up_gets_a_hit_stop() -> void:
	# PM:s M2-brief: "kort hit-stop på ×4+". Ett par bildas nästan varje runda
	# med Smedens MIRROR; en frysning där skulle göra kedjan hackig.
	assert_int(int(EventPlayer.feedback({"t": "combo_formed", "multiplier": 2}, 0)["hit_stop_ms"])).is_equal(0)
	assert_int(int(EventPlayer.feedback({"t": "combo_formed", "multiplier": 4}, 0)["hit_stop_ms"])).is_greater(0)
	assert_int(int(EventPlayer.feedback({"t": "combo_formed", "multiplier": 8}, 0)["hit_stop_ms"])).is_greater(0)


func test_a_bigger_hit_sounds_heavier_and_shakes_harder() -> void:
	var small: Dictionary = EventPlayer.feedback({"t": "damage_dealt", "amount": 6}, 0)
	var big: Dictionary = EventPlayer.feedback({"t": "damage_dealt", "amount": 90}, 0)
	assert_float(float(big["pitch"])).is_less(float(small["pitch"]))
	assert_float(float(big["shake"])).is_greater(float(small["shake"]))
	# Skaket har ett tak: en kedja på 300 ska inte kasta ut skärmen ur fönstret.
	var huge: Dictionary = EventPlayer.feedback({"t": "damage_dealt", "amount": 300}, 0)
	assert_float(float(huge["shake"])).is_equal(EventPlayer.DAMAGE_SHAKE_MAX)
	assert_float(float(huge["pitch"])).is_greater_equal(0.65)


func test_an_overflow_hop_replaces_the_hit_cue_and_rises() -> void:
	# assets/sfx/README.md §2: "Ersätter damage_hit på hoppet, staplas inte".
	var first: Dictionary = EventPlayer.feedback({"t": "damage_dealt", "amount": 20, "overflow": 8}, 2, 0)
	var hop: Dictionary = EventPlayer.feedback({"t": "damage_dealt", "amount": 8}, 2, 1)
	var hop2: Dictionary = EventPlayer.feedback({"t": "damage_dealt", "amount": 4}, 2, 2)
	assert_str(String(first["sfx"])).is_equal("damage_hit")
	assert_str(String(hop["sfx"])).is_equal("damage_overflow")
	assert_float(float(hop2["pitch"])).is_greater(float(hop["pitch"]))


func test_death_is_a_full_stop_and_not_another_rise() -> void:
	# UI_GUIDE §5.5: pitch SÄNKS två halvtoner mot kedjans aktuella ton.
	var step: int = 4
	var killed: Dictionary = EventPlayer.feedback({"t": "enemy_killed"}, step)
	var activated: Dictionary = EventPlayer.feedback({"t": "die_activated"}, step)
	assert_float(float(killed["pitch"])).is_less(float(activated["pitch"]))
	assert_int(int(killed["haptic"])).is_equal(Haptics.Level.HEAVY)


func test_a_cracked_die_breaks_the_rising_pattern() -> void:
	# §5.6: ingen tonhöjdsstegring alls, tyngsta haptiken, största skaket.
	var cracked: Dictionary = EventPlayer.feedback({"t": "die_cracked"}, 5)
	assert_float(float(cracked["pitch"])).is_equal(float(EventPlayer.feedback({"t": "die_cracked"}, 0)["pitch"]))
	assert_int(int(cracked["haptic"])).is_equal(Haptics.Level.HEAVY)
	assert_float(float(cracked["shake"])).is_greater(
		float(EventPlayer.feedback({"t": "enemy_killed"}, 0)["shake"]))


func test_the_side_channels_are_mixed_below_the_hits() -> void:
	# §5.4: charge_stored är en sidokanal, inte huvudhändelsen.
	var charge: Dictionary = EventPlayer.feedback({"t": "charge_stored", "amount": 3}, 0)
	var hit: Dictionary = EventPlayer.feedback({"t": "damage_dealt", "amount": 10}, 0)
	assert_float(float(charge["volume_db"])).is_less(float(hit["volume_db"]))
	assert_int(int(charge["haptic"])).is_equal(Haptics.Level.NONE)


func test_every_cue_the_feedback_table_names_exists_as_a_file() -> void:
	# Kontraktet mot assets/sfx/README.md §2. En cue som inte är levererad ska
	# upptäckas här och inte som tystnad i en kedja.
	var events: Array[Dictionary] = [
		{"t": "die_activated"}, {"t": "combo_formed", "multiplier": 2},
		{"t": "combo_formed", "multiplier": 4}, {"t": "combo_formed", "multiplier": 8},
		{"t": "house_bonus"}, {"t": "damage_dealt", "amount": 5},
		{"t": "enemy_killed"}, {"t": "die_cracked"}, {"t": "charge_stored"},
		{"t": "ward_gained"}, {"t": "heal"}, {"t": "enemy_attacks", "amount": 4},
		{"t": "enemy_thorns"}, {"t": "player_damaged"}, {"t": "status_ticked"},
		{"t": "round_end"},
	]
	var missing: PackedStringArray = PackedStringArray()
	for event: Dictionary in events:
		for key: String in ["sfx", "extra_sfx"]:
			var sound: String = String(EventPlayer.feedback(event, 0, 1 if key == "extra_sfx" else 0)[key])
			if sound == "":
				continue
			if not ResourceLoader.exists("%s/%s.wav" % [Juice.SFX_DIR, sound]):
				missing.append("%s → %s" % [String(event["t"]), sound])
	assert_array(Array(missing)).override_failure_message(
		"feedbacktabellen pekar på ljud som inte finns: %s" % ", ".join(missing)).is_empty()


func test_an_unknown_event_is_silent_rather_than_wrong() -> void:
	var fb: Dictionary = EventPlayer.feedback({"t": "something_from_m3"}, 3)
	assert_str(String(fb["sfx"])).is_empty()
	assert_int(int(fb["haptic"])).is_equal(Haptics.Level.NONE)
	assert_int(int(fb["hit_stop_ms"])).is_equal(0)


# ---------------------------------------------------------------------------
# Reducerad rörelse (UI_GUIDE §6.1)
# ---------------------------------------------------------------------------

func test_reduced_motion_shortens_the_playback_but_not_the_event_track() -> void:
	# En runda med en ×4 och en död fiende: de två enda händelserna i M2 som
	# lägger hit-stop. En runda utan dem har inget att korta, och testet ska
	# mäta regeln, inte tärningsturen.
	var events: Array[Dictionary] = [
		{"t": "round_start", "seq": 0, "ms_hint": 120},
		{"t": "die_activated", "seq": 1, "ms_hint": 220},
		{"t": "die_activated", "seq": 2, "ms_hint": 220},
		{"t": "combo_formed", "seq": 3, "ms_hint": 340, "multiplier": 4},
		{"t": "damage_dealt", "seq": 4, "ms_hint": 300, "amount": 30},
		{"t": "enemy_killed", "seq": 5, "ms_hint": 380},
		{"t": "round_end", "seq": 6, "ms_hint": 600},
	]
	var normal: int = EventPlayer.wall_ms(events, 1.0, false)
	var reduced: int = EventPlayer.wall_ms(events, 1.0, true)
	# Själva tidslinjen är IDENTISK – §6.1 säger "timing bevaras" – det är
	# hit-stoppen som halveras, och det är därför uppspelningen blir kortare.
	assert_int(EventPlayer.total_ms(EventPlayer.build_timeline(events, 1.0))).is_equal(
		EventPlayer.total_ms(EventPlayer.build_timeline(events, 1.0)))
	assert_int(EventPlayer.hit_stop_ms(events, false)).is_greater(0)
	assert_int(reduced).is_less(normal)


func test_reduced_motion_reaches_the_same_final_state() -> void:
	# Det viktigaste löftet i hela uppspelaren: presentation ändrar aldrig utfall.
	var result: ResolveResult = _full_round_with_enemy_turn()
	var before: CombatState = _state_before(31)
	var normal: Dictionary = EventPlayer.apply_all(EventPlayer.view_from_state(before), result.events)
	var reduced: Dictionary = EventPlayer.apply_all(EventPlayer.view_from_state(before), result.events)
	assert_str(JSON.stringify(reduced)).is_equal(JSON.stringify(normal))


func test_the_hit_stops_fit_inside_the_round_budget() -> void:
	# Hit-stoppen ligger UTANFÖR tidslinjen och kan därför spräcka känslan av
	# budgeten även när tidslinjen håller den. Taket här är dev-satt: en runda
	# får inte kännas som mer än ROUND_BUDGET + 400 ms.
	for seed_value: int in range(10):
		var state: CombatState = Content.smith_state()
		state.enemies = Content.encounter(3, seed_value % 2)
		state = Resolver.begin_combat(state, Rng.new(seed_value))
		var result: ResolveResult = Resolver.resolve(state, Policy.lookahead(state))
		assert_int(EventPlayer.wall_ms(result.events)).override_failure_message(
			"seed %d: uppspelningen tar %d ms inklusive hit-stop" % [seed_value, EventPlayer.wall_ms(result.events)]
		).is_less_equal(EventPlayer.ROUND_BUDGET_MS + 400)
