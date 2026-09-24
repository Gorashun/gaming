extends GdUnitTestSuite
## Stilskiktets UI-del (M6 spår A steg 3): UI-bruset ned, skadesiffran i 88 dp
## Anton och bossbannerns textkollision (research 06 §1, 25_boss_intro.png).

const SCENE: String = "res://src/game/combat/combat_screen.tscn"


func after_test() -> void:
	Settings.reduced_motion = false


func _screen(state: CombatState, node: Dictionary, tutorial_room: int = -1) -> CombatScreen:
	var packed: PackedScene = ResourceLoader.load(SCENE) as PackedScene
	var screen: CombatScreen = auto_free(packed.instantiate()) as CombatScreen
	var chips: EnemyChips = auto_free(EnemyChips.new())
	add_child(chips)
	chips.size = Vector2(1080.0, 864.0)
	screen.readout_host = chips
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.size = Vector2(1080.0, 1920.0)
	screen.setup(null, null, {
		"state": state,
		"rng": Rng.new(7),
		"node": node,
		"reveal": Reveal.all_on(),
		"tutorial_room": tutorial_room,
		"best_chain": 0,
	})
	return screen


func _boss_state() -> CombatState:
	var state: CombatState = Content.smith_state()
	state.enemies = Content.encounter(4)
	return Resolver.begin_combat(state, Rng.new(7))


# --- Slots utan lådor, bara tärningarna upphöjda ---------------------------

func test_a_slot_is_an_underline_not_a_box() -> void:
	var style: StyleBoxFlat = SlotView.underline_style(Tokens.SEM_FIRE, Tokens.STROKE_BOLD, Color(0, 0, 0, 0), false)
	assert_int(style.border_width_left).is_equal(0)
	assert_int(style.border_width_right).is_equal(0)
	assert_int(style.border_width_top).is_equal(0)
	assert_int(style.border_width_bottom).is_greater(0)
	assert_float(style.bg_color.a).is_equal(0.0)


func test_only_the_dice_are_raised() -> void:
	var state: CombatState = Content.smith_state()
	state.enemies = Content.encounter(1)
	state = Resolver.begin_combat(state, Rng.new(7))
	var screen: CombatScreen = _screen(state, {"room": 1, "kind": RunGraph.KIND_COMBAT})
	await await_idle_frame()
	for slot: Node in screen.get_node("Margin/Column/SlotRow").get_children():
		var slot_style: StyleBoxFlat = (slot as Control).get_theme_stylebox("panel") as StyleBoxFlat
		assert_int(slot_style.shadow_size).is_equal(0)
	var raised: int = 0
	for die: Node in screen.get_node("Margin/Column/Tray").get_children():
		# M7: en ritad tärning (DieArt) bär sin egen skugga – brickan runt den
		# är ingen låda längre.
		var drawn: bool = false
		for child: Node in die.get_children():
			if child is DieArt and (child as DieArt).is_drawing() and (child as DieArt).visible:
				drawn = true
		if drawn:
			raised += 1
			continue
		for child: Node in die.find_children("*", "Panel", true, false):
			var style: StyleBoxFlat = (child as Panel).get_theme_stylebox("panel") as StyleBoxFlat
			if style != null and style.shadow_size > 0:
				raised += 1
				break
	assert_int(raised).is_greater_equal(1)


# --- Skadesiffran ------------------------------------------------------------

func test_the_damage_number_is_88_dp_anton_with_a_black_stroke_and_a_tilt() -> void:
	var host: Control = auto_free(Control.new())
	add_child(host)
	var label: Label = Juice.damage_pop(host, "16", Tokens.CHALK_100, Vector2(540, 400))
	assert_object(label).is_not_null()
	assert_int(label.get_theme_font_size("font_size")).is_equal(Tokens.dpi(Juice.DAMAGE_POP_DP))
	assert_object(label.get_theme_font("font")).is_same(Tokens.font_display())
	assert_int(label.get_theme_constant("outline_size")).is_equal(Tokens.dpi(Juice.DAMAGE_POP_OUTLINE_DP))
	assert_float(label.rotation).is_equal_approx(deg_to_rad(Juice.DAMAGE_POP_TILT_DEG), 0.001)
	# Poolen återanvänds: nästa vanliga pop får inte ärva lutning eller kontur.
	for i: int in range(Juice.POP_POOL):
		var plain: Label = Juice.number_pop(host, "+1", Tokens.SEM_HEAL, Vector2(100, 100), Tokens.TYPE_TITLE)
		assert_float(plain.rotation).is_equal(0.0)
		assert_int(plain.get_theme_constant("outline_size")).is_equal(Tokens.dpi(Juice.POP_OUTLINE_DP))


# --- Bossbannern -------------------------------------------------------------

func test_the_boss_name_never_sits_on_top_of_other_text() -> void:
	var screen: CombatScreen = _screen(_boss_state(), {"room": 4, "kind": RunGraph.KIND_BOSS})
	await await_idle_frame()
	assert_bool(screen.is_intro_active()).is_true()
	var fx: Control = screen.get_node("FxLayer")
	var band: PanelContainer = fx.get_node("BossBand") as PanelContainer
	var scrim: ColorRect = fx.get_node("BossScrim") as ColorRect
	# Bandet har en helt ogenomskinlig botten och scrimmen täcker nästan allt.
	assert_float((band.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a).is_equal(1.0)
	assert_float(scrim.color.a).is_greater_equal(0.9)
	# Över tärningskonstens z-lager (DieArt: pips 1, glas 2, spricka 3).
	assert_int(scrim.z_index).is_greater(3)
	assert_int(band.z_index).is_greater(scrim.z_index)
	# Namnet ryms på skärmens bredd.
	var name_label: Label = band.get_node("BossName") as Label
	var font: Font = name_label.get_theme_font("font")
	var text_width: float = font.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		name_label.get_theme_font_size("font_size")).x
	assert_float(text_width).is_less_equal(band.size.x)
	screen.skip_boss_intro()
	await await_idle_frame()
	assert_object(fx.get_node_or_null("BossBand")).is_null()


func test_the_tutorial_tip_hides_under_the_boss_intro_and_comes_back() -> void:
	var room: int = Tutorial.room_count() - 1
	var state: CombatState = Content.smith_state()
	state.enemies = Tutorial.enemies_for(room)
	state = Resolver.begin_combat(state, Rng.new(7))
	var screen: CombatScreen = _screen(state, {"room": room, "kind": RunGraph.KIND_BOSS}, room)
	await await_idle_frame()
	var tip: Label = screen.find_child("TutorialTip", true, false) as Label
	if tip == null:
		return
	assert_bool(screen.is_intro_active()).is_true()
	assert_bool(tip.visible).override_failure_message(
		"tutorialtipset syns genom bossnamnet").is_false()
	screen.skip_boss_intro()
	await await_idle_frame()
	assert_bool(tip.visible).is_true()
