extends GdUnitTestSuite
## Progressiv avslöjning (src/core/reveal.gd).
##
## Två regler bevakas, och båda är lätta att bryta av misstag:
## [br]1. Ett element som inte lärts ut är [b]frånvarande[/b], inte nedtonat.
## [br]2. Ett element får bara döljas när det är [b]tomt eller overksamt[/b].
##    UI ljuger aldrig om spelets tillstånd — en laddningsmätare som står på 7
##    måste synas även för en spelare som inte fått lektionen än.


func test_a_fresh_reveal_hides_everything_and_a_finished_one_hides_nothing() -> void:
	var fresh: Reveal = Reveal.none()
	for flag: String in Reveal.FLAGS:
		assert_bool(fresh.has(flag)).override_failure_message(
			"%s ska vara av från start" % flag).is_false()
	assert_bool(fresh.is_complete()).is_false()

	var done: Reveal = Reveal.all_on()
	for flag: String in Reveal.FLAGS:
		assert_bool(done.has(flag)).is_true()
	assert_bool(done.is_complete()).override_failure_message(
		"en färdig spelare har alla flaggor på").is_true()


func test_revealing_twice_only_counts_once() -> void:
	var reveal: Reveal = Reveal.none()
	assert_bool(reveal.reveal_flag("armor")).is_true()
	assert_bool(reveal.reveal_flag("armor")).override_failure_message(
		"andra gången är ingen nyhet och ska inte animera").is_false()


func test_an_unknown_flag_is_shown_rather_than_hidden() -> void:
	# Fail-safe: en felstavad flagga får aldrig dölja ett element för alltid.
	assert_bool(Reveal.none().has("banan")).is_true()


# --- Regel 2: UI ljuger aldrig ---------------------------------------------

func test_a_charge_meter_with_a_value_cannot_be_hidden() -> void:
	var empty: Dictionary = {"charge": 0, "slot_types": [Rules.SlotType.PLAIN]}
	var loaded: Dictionary = {"charge": 7, "slot_types": [Rules.SlotType.PLAIN]}
	assert_bool(Reveal.may_hide("charge", empty)).is_true()
	assert_bool(Reveal.may_hide("charge", loaded)).override_failure_message(
		"laddning 7 måste synas även före lektionen").is_false()
	assert_bool(Reveal.none().shows("charge", loaded)).is_true()
	assert_bool(Reveal.none().shows("charge", empty)).is_false()


func test_a_charge_slot_on_the_board_forces_the_meter_out() -> void:
	var facts: Dictionary = {"charge": 0, "slot_types": [Rules.SlotType.PLAIN, Rules.SlotType.CHARGE]}
	assert_bool(Reveal.may_hide("charge", facts)).override_failure_message(
		"en CHARGE-slot gör mätaren verksam, alltså synlig").is_false()


func test_armor_is_shown_as_soon_as_an_enemy_has_any() -> void:
	assert_bool(Reveal.may_hide("armor", {"max_armor": 0})).is_true()
	assert_bool(Reveal.may_hide("armor", {"max_armor": 2})).is_false()


func test_the_reroll_button_is_hidden_only_when_there_are_no_rerolls() -> void:
	assert_bool(Reveal.may_hide("reroll", {"rerolls_left": 0})).is_true()
	assert_bool(Reveal.may_hide("reroll", {"rerolls_left": 1})).is_false()


func test_slot_rules_are_hidden_only_on_an_all_plain_board() -> void:
	var plain: Dictionary = {"slot_types": [Rules.SlotType.PLAIN, Rules.SlotType.PLAIN]}
	var mixed: Dictionary = {"slot_types": [Rules.SlotType.PLAIN, Rules.SlotType.MIRROR]}
	assert_bool(Reveal.may_hide("slot_types", plain)).is_true()
	assert_bool(Reveal.may_hide("slot_types", mixed)).override_failure_message(
		"en MIRROR på brädet utan regelrad är exakt problemet i §1.4").is_false()


func test_mirror_and_anvil_follow_the_board() -> void:
	var board: Dictionary = {"slot_types": [Rules.SlotType.MIRROR, Rules.SlotType.ANVIL]}
	assert_bool(Reveal.may_hide("mirror", board)).is_false()
	assert_bool(Reveal.may_hide("anvil", board)).is_false()
	var plain: Dictionary = {"slot_types": [Rules.SlotType.PLAIN]}
	assert_bool(Reveal.may_hide("mirror", plain)).is_true()
	assert_bool(Reveal.may_hide("anvil", plain)).is_true()


func test_a_reveal_survives_a_save_and_a_load() -> void:
	var reveal: Reveal = Reveal.none()
	reveal.reveal_flag("overflow")
	reveal.reveal_flag("armor")
	var restored: Reveal = Reveal.from_dict(reveal.to_dict())
	assert_bool(restored.has("overflow")).is_true()
	assert_bool(restored.has("armor")).is_true()
	assert_bool(restored.has("anvil")).is_false()
	assert_dict(restored.to_dict()).is_equal(reveal.to_dict())
