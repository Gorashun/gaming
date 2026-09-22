extends GdUnitTestSuite
## Stridsskärmens höjdbudget.
##
## [b]Varför det här testet finns:[/b] en [BoxContainer] som inte får plats
## [i]krymper sina barn under deras minsta storlek[/i] i stället för att klaga.
## Resultatet är inte ett fel i loggen utan ett toppfält som glider ut ovanför
## skärmen och en bekräfta-knapp som hamnar under den – vilket är precis vad som
## hände när kvittot och bågarna lades till i M2.5.
##
## Testet mäter därför summan av radernas minsta höjder mot viewporten, för
## flera rum, och fäller bygget innan en skärmdump hinner se fel.
##
## Prioriteringen när något inte får plats är normativ (COMBAT_READABILITY §8):
## [i]"Räknestycket behåller full höjd – det prioriteras före arenan."[/i]
## Tumzonen betalar aldrig.

const SCENE: String = "res://src/game/combat/combat_screen.tscn"
## Viewportens höjd i px. Samma som project.godot.
const VIEWPORT_HEIGHT: float = 1920.0
## Tumzonen: raderna som ALDRIG får krympas.
const THUMB_ROWS: Array[String] = ["Tray", "Actions"]


## Striden monteras alltid i korridoren (M5.5), och chipslagret ÄR
## fiendeavläsningen. Testet bygger därför samma par som spelet gör: ett
## [EnemyChips] som värd och stridsskärmen under det.
func _screen(state: CombatState, reveal: Reveal) -> CombatScreen:
	var packed: PackedScene = ResourceLoader.load(SCENE) as PackedScene
	var screen: CombatScreen = auto_free(packed.instantiate()) as CombatScreen
	var chips: EnemyChips = auto_free(EnemyChips.new())
	add_child(chips)
	chips.size = Vector2(1080.0, 864.0)
	screen.readout_host = chips
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.size = Vector2(1080.0, VIEWPORT_HEIGHT)
	screen.setup(null, null, {
		"state": state,
		"rng": Rng.new(7),
		"node": {"room": 1, "kind": RunGraph.KIND_COMBAT},
		"reveal": reveal,
		"tutorial_room": -1,
		"best_chain": 0,
	})
	return screen


func _column_minimum(screen: CombatScreen) -> Dictionary:
	var column: VBoxContainer = screen.get_node("Margin/Column") as VBoxContainer
	var rows: Dictionary = {}
	for child: Node in column.get_children():
		var control: Control = child as Control
		if control == null or not control.visible:
			continue
		rows[String(control.name)] = control.get_combined_minimum_size().y
	return {
		"rows": rows,
		"total": column.get_combined_minimum_size().y,
	}


## Marginalen kolumnen har att växa i: viewporten minus skärmens marginaler.
func _available(screen: CombatScreen) -> float:
	var margin: MarginContainer = screen.get_node("Margin") as MarginContainer
	return VIEWPORT_HEIGHT \
		- float(margin.get_theme_constant(&"margin_top")) \
		- float(margin.get_theme_constant(&"margin_bottom"))


func test_the_column_fits_in_a_full_board_room() -> void:
	var state: CombatState = Content.smith_state()
	state.enemies = Content.encounter(1)
	state = Resolver.begin_combat(state, Rng.new(7))
	var screen: CombatScreen = _screen(state, Reveal.all_on())
	for i: int in range(5):
		screen.place(i, i)
	await await_idle_frame()

	var measured: Dictionary = _column_minimum(screen)
	assert_float(float(measured["total"])).override_failure_message(
		"kolumnens minsta höjd är %.0f px men bara %.0f px finns:\n%s" % [
			float(measured["total"]), _available(screen), str(measured["rows"])]
	).is_less_equal(_available(screen))


## Värsta fallet för arenan: fyra fiender med rustning OCH två statusar var.
## Fiendezonen får krympa; kolumnen får inte spricka.
func test_the_column_fits_with_armor_and_statuses_on_every_enemy() -> void:
	var state: CombatState = Content.smith_state()
	state.enemies = Content.encounter(1)
	for enemy: Enemy in state.enemies:
		enemy.armor = 6
		enemy.burn = 4
		enemy.poison = 3
	state = Resolver.begin_combat(state, Rng.new(11))
	var screen: CombatScreen = _screen(state, Reveal.all_on())
	for i: int in range(5):
		screen.place(i, i)
	await await_idle_frame()

	var measured: Dictionary = _column_minimum(screen)
	assert_float(float(measured["total"])).override_failure_message(
		"rustning + brand + gift spräckte kolumnen: %.0f px av %.0f\n%s" % [
			float(measured["total"]), _available(screen), str(measured["rows"])]
	).is_less_equal(_available(screen))


## En nybörjare ser färre element (Reveal), så det fallet är lättare – men det
## får inte vara [i]trasigt[/i] på något annat sätt.
func test_the_column_fits_for_a_brand_new_player() -> void:
	var state: CombatState = Content.smith_state()
	state.board = Board.from_types([Rules.SlotType.PLAIN, Rules.SlotType.PLAIN, Rules.SlotType.PLAIN])
	state.enemies = Tutorial.enemies_for(0)
	state = Resolver.begin_combat(state, Rng.new(3))
	var screen: CombatScreen = _screen(state, Reveal.none())
	await await_idle_frame()

	var measured: Dictionary = _column_minimum(screen)
	assert_float(float(measured["total"])).override_failure_message(
		"tutorialrummet spräckte kolumnen: %.0f px av %.0f\n%s" % [
			float(measured["total"]), _available(screen), str(measured["rows"])]
	).is_less_equal(_available(screen))


## Tumzonen är helig (UI_GUIDE §2.9): brickan och knappraden ska ha exakt sin
## begärda höjd, aldrig en krympt.
func test_the_thumb_zone_is_never_squeezed() -> void:
	var state: CombatState = Content.smith_state()
	state.enemies = Content.encounter(1)
	state = Resolver.begin_combat(state, Rng.new(7))
	var screen: CombatScreen = _screen(state, Reveal.all_on())
	await await_idle_frame()
	var column: VBoxContainer = screen.get_node("Margin/Column") as VBoxContainer
	for row_name: String in THUMB_ROWS:
		var row: Control = column.get_node(row_name) as Control
		assert_float(row.size.y).override_failure_message(
			"%s krympte till %.0f px (minst %.0f px krävs)" % [
				row_name, row.size.y, row.get_combined_minimum_size().y]
		).is_greater_equal(row.get_combined_minimum_size().y)


## Tumzonens knappar måste behålla sin träffyta på 48 dp (UI_GUIDE §2.9).
func test_the_action_buttons_keep_their_touch_target() -> void:
	var state: CombatState = Content.smith_state()
	state.enemies = Content.encounter(1)
	state = Resolver.begin_combat(state, Rng.new(7))
	var screen: CombatScreen = _screen(state, Reveal.all_on())
	await await_idle_frame()
	var actions: HBoxContainer = screen.get_node("Margin/Column/Actions") as HBoxContainer
	for child: Node in actions.get_children():
		var button: Button = child as Button
		if button == null or not button.visible:
			continue
		assert_float(button.size.y).override_failure_message(
			"%s är %.0f px hög, under träffytans %.0f px" % [
				button.name, button.size.y, Tokens.dp(Tokens.TOUCH_MIN)]
		).is_greater_equal(Tokens.dp(Tokens.TOUCH_MIN))
