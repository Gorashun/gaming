extends GdUnitTestSuite
## Juice-motorn: tonhöjdsregeln, poolerna, hit-stoppens tak och att
## tillgänglighetsinställningarna faktiskt stänger av det de säger.
##
## Ljudfilerna levereras av UI-agenten parallellt. Testerna får därför ALDRIG
## kräva att en WAV finns – de kräver tvärtom att ett saknat ljud är tyst,
## räknat och ofarligt.

var _saved: Dictionary = {}


func before_test() -> void:
	_saved = Settings.to_dict()
	Juice.reset_log()
	Juice.log_calls = true
	Haptics.reset_log()


func after_test() -> void:
	Juice.log_calls = false
	Juice.reset_log()
	for key: String in _saved:
		Settings.set_value(StringName(key), _saved[key], false)


# --- Tonhöjd ---------------------------------------------------------------

func test_the_chain_pitch_rises_one_semitone_per_step() -> void:
	# UI_GUIDE §5: pow(2, step / 12). Steg 12 = exakt en oktav.
	assert_float(Juice.chain_pitch(0)).is_equal_approx(1.0, 0.0001)
	assert_float(Juice.chain_pitch(1)).is_equal_approx(pow(2.0, 1.0 / 12.0), 0.0001)
	assert_float(Juice.chain_pitch(12)).is_equal_approx(2.0, 0.0001)


func test_the_chain_pitch_is_capped_at_one_octave() -> void:
	assert_float(Juice.chain_pitch(40)).is_equal_approx(2.0, 0.0001)
	assert_float(Juice.chain_pitch(5, 8)).is_less_equal(2.0)


func test_a_combo_jumps_extra_semitones() -> void:
	assert_float(Juice.chain_pitch(0, 2)).is_greater(Juice.chain_pitch(0, 1))
	assert_float(Juice.chain_pitch(0, 4)).is_greater(Juice.chain_pitch(0, 2))
	assert_float(Juice.chain_pitch(0, 8)).is_greater(Juice.chain_pitch(0, 4))


# --- Ljud ------------------------------------------------------------------

func test_a_missing_sound_is_silent_counted_and_harmless() -> void:
	Juice.reset_sfx_cache()
	Juice.sfx(&"definitely_not_a_real_sound_m2", 1.0)
	assert_int(Juice.sfx_missing).is_equal(1)
	assert_bool(Juice.missing_sfx.has("definitely_not_a_real_sound_m2")).is_true()
	# Andra anropet ska INTE räknas igen: uppslaget cachas, annars får en kedja
	# sex varningar per saknat ljud.
	Juice.sfx(&"definitely_not_a_real_sound_m2", 1.2)
	assert_int(Juice.sfx_missing).is_equal(1)
	assert_int(Juice.count_calls("sfx")).is_equal(2)


func test_the_voice_pool_has_eight_channels_and_is_never_exceeded() -> void:
	assert_int(Juice.VOICES).is_equal(8)
	var voices: int = 0
	for child: Node in Juice.get_children():
		if child is AudioStreamPlayer:
			voices += 1
	assert_int(voices).is_equal(Juice.VOICES)
	# Tjugo ljud i rad får inte skapa en nod till.
	for i: int in range(20):
		Juice.sfx(&"die_activate", 1.0)
	var after: int = 0
	for child: Node in Juice.get_children():
		if child is AudioStreamPlayer:
			after += 1
	assert_int(after).is_equal(Juice.VOICES)


func test_zero_volume_still_logs_the_call() -> void:
	# Spelet ska vara fullt spelbart ljudlöst (UI_GUIDE §6.4), och loggen är det
	# rökprovet mäter kedjan med – den får inte tystna med volymen.
	Settings.set_value(&"sfx_volume", 0, false)
	Juice.sfx(&"die_activate", 1.0)
	assert_int(Juice.count_calls("sfx")).is_equal(1)


# --- Haptik ----------------------------------------------------------------

func test_haptics_off_means_no_call_at_all() -> void:
	Settings.set_value(&"haptics", false, false)
	Haptics.log_calls = true
	Juice.haptic(Haptics.Level.HEAVY)
	assert_int(Juice.count_calls("haptic")).is_equal(0)
	assert_array(Haptics.calls).is_empty()
	Haptics.log_calls = false


func test_the_haptic_levels_are_distinguishable() -> void:
	# En HEAVY som känns som en MEDIUM lär inte ut något.
	assert_int(Haptics.duration_ms(Haptics.Level.LIGHT)).is_equal(15)
	assert_int(Haptics.duration_ms(Haptics.Level.MEDIUM)).is_equal(30)
	assert_int(Haptics.duration_ms(Haptics.Level.HEAVY)).is_equal(60)


func test_critical_only_mode_drops_the_light_taps() -> void:
	Settings.set_value(&"haptics", true, false)
	Haptics.level_floor = Haptics.Level.HEAVY
	assert_bool(Haptics.allows(Haptics.Level.LIGHT)).is_false()
	assert_bool(Haptics.allows(Haptics.Level.HEAVY)).is_true()
	Haptics.level_floor = Haptics.Level.LIGHT


# --- Hit-stop --------------------------------------------------------------

func test_hit_stop_is_capped_and_never_stacked() -> void:
	Settings.set_value(&"reduced_motion", false, false)
	Juice.hit_stop(5000)
	assert_bool(Juice.is_hit_stopped()).is_true()
	assert_int(int(Juice.calls[0]["ms"])).is_equal(Juice.HIT_STOP_MAX_MS)
	# Andra anropet under pågående stopp ignoreras helt.
	Juice.hit_stop(90)
	assert_int(Juice.count_calls("hit_stop")).is_equal(1)
	Juice._end_hit_stop()
	assert_float(Engine.time_scale).is_equal(1.0)


func test_reduced_motion_halves_the_hit_stop() -> void:
	Settings.set_value(&"reduced_motion", true, false)
	Juice.hit_stop(90)
	assert_int(int(Juice.calls[0]["ms"])).is_equal(45)
	Juice._end_hit_stop()


# --- Reducerad rörelse -----------------------------------------------------

func test_reduced_motion_turns_the_screen_shake_off_completely() -> void:
	Settings.set_value(&"reduced_motion", true, false)
	var layer: CanvasLayer = auto_free(CanvasLayer.new())
	add_child(layer)
	Juice.register_shake_layer(layer)
	Juice.shake(8.0, 200)
	assert_vector(layer.offset).is_equal(Vector2.ZERO)
	Juice.clear_shake_layers()


func test_the_number_pop_pool_is_reused_and_never_grows() -> void:
	var before: int = _pop_count()
	for i: int in range(Juice.POP_POOL * 3):
		Juice.number_pop(null, str(i), Tokens.SEM_DAMAGE, Vector2(100.0, 100.0))
	assert_int(_pop_count()).is_equal(before)
	assert_int(before).is_equal(Juice.POP_POOL)


func _pop_count() -> int:
	var fx: Node = Juice.get_node_or_null("JuiceFx")
	if fx == null:
		return 0
	var total: int = 0
	for child: Node in fx.get_children():
		if child is Label:
			total += 1
	return total
