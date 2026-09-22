extends GdUnitTestSuite
## M5-integrationen: korridoren som skärm, striden i de nedre 55 %, fällans pris,
## character sheetets slots och torget.
##
## Allt här går att köra headless. 3D:n ritas inte, men geometri,
## [method Camera3D.unproject_position] och layouten är ren matematik – det är
## samma resonemang som i [code]tests/test_corridor_view.gd[/code].

const CORRIDOR_SCENE: String = "res://src/game/corridor/corridor_screen.tscn"
const SHEET_SCENE: String = "res://src/game/sheet/character_sheet.tscn"
const TOWN_SCENE: String = "res://src/game/town/town_screen.tscn"


func _map(seed_value: int = 7) -> CorridorMap:
	var rng: Rng = Rng.new(seed_value)
	var graph: RunGraph = RunGraph.generate_floor(1, rng)
	return CorridorMap.build(graph, rng.fork("corridor"))


func _corridor(map: CorridorMap) -> CorridorScreen:
	var scene: PackedScene = load(CORRIDOR_SCENE) as PackedScene
	var screen: CorridorScreen = auto_free(scene.instantiate()) as CorridorScreen
	add_child(screen)
	screen.size = Vector2(1080.0, 1920.0)
	screen.setup(null, null, {"map": map, "hp": 100, "max_hp": 100, "room": 1, "pips": 5})
	return screen


# ---------------------------------------------------------------------------
# Fällans pris (CORRIDOR_DESIGN §2.6, RunFlow)
# ---------------------------------------------------------------------------

func test_a_trap_that_costs_hp_takes_exactly_what_it_said() -> void:
	var state: CombatState = Content.smith_state()
	state.player_hp = 40
	var after: CombatState = RunFlow.pay_trap(state,
		{"id": "PUSH_THROUGH", "cost": RunFlow.TRAP_COST_HP, "amount": 5}, Rng.new(1))
	assert_int(after.player_hp).is_equal(35)
	# Muterar inte indata – samma kontrakt som resolvern.
	assert_int(state.player_hp).is_equal(40)


func test_a_trap_never_kills() -> void:
	# §2.6 regel 3: fällan är ett val mellan två priser, inte ett kast om runnen.
	var state: CombatState = Content.smith_state()
	state.player_hp = 3
	var after: CombatState = RunFlow.pay_trap(state,
		{"id": "RUN_ACROSS", "cost": RunFlow.TRAP_COST_HP, "amount": 8}, Rng.new(1))
	assert_int(after.player_hp).is_equal(RunFlow.TRAP_HP_FLOOR)
	assert_bool(after.player_hp > 0).is_true()


func test_a_cracked_face_costs_one_upward_face_and_nothing_else() -> void:
	var state: CombatState = Content.smith_state()
	var before: int = _cracked_faces(state)
	var after: CombatState = RunFlow.pay_trap(state,
		{"id": "CUT_FREE", "cost": RunFlow.TRAP_COST_CRACK, "amount": 1}, Rng.new(3))
	assert_int(_cracked_faces(after)).is_equal(before + 1)
	assert_int(after.player_hp).is_equal(state.player_hp)
	assert_int(after.dice.size()).is_equal(state.dice.size())


func test_the_same_seed_cracks_the_same_die() -> void:
	var option: Dictionary = {"id": "CUT_FREE", "cost": RunFlow.TRAP_COST_CRACK, "amount": 1}
	var a: CombatState = RunFlow.pay_trap(Content.smith_state(), option, Rng.new(11))
	var b: CombatState = RunFlow.pay_trap(Content.smith_state(), option, Rng.new(11))
	assert_str(_crack_signature(a)).is_equal(_crack_signature(b))


func _cracked_faces(state: CombatState) -> int:
	var count: int = 0
	for die: Die in state.dice:
		for face: Face in die.faces:
			if face.id == Resolver.CRACKED_FACE_ID:
				count += 1
	return count


func _crack_signature(state: CombatState) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for die: Die in state.dice:
		parts.append("%s:%d" % [die.id, die.cracks])
	return ",".join(parts)


# ---------------------------------------------------------------------------
# Relik → utrustningsslot (CORRIDOR_DESIGN §4.2)
# ---------------------------------------------------------------------------

func test_every_relic_in_the_pool_hangs_somewhere_on_the_figure() -> void:
	for id: String in Content.RELICS:
		var slot: String = Content.relic_slot(id)
		assert_str(slot).override_failure_message(
			"reliken %s saknar slot i CORRIDOR_DESIGN §4.2-tabellen" % id).is_not_empty()
		assert_bool(Content.SHEET_SLOTS.has(slot)).override_failure_message(
			"%s pekar på sloten %s som inte ritas" % [id, slot]).is_true()


func test_no_two_relics_share_a_slot() -> void:
	# §4.2: "det finns exakt en plats per relik". Delar två samma slot döljer
	# den ena den andra och "byt relik → syns direkt" faller.
	var taken: Dictionary = {}
	for id: String in Content.RELICS:
		var slot: String = Content.relic_slot(id)
		assert_bool(taken.has(slot)).override_failure_message(
			"%s och %s delar sloten %s" % [id, String(taken.get(slot, "")), slot]).is_false()
		taken[slot] = id


func test_the_class_relic_has_no_slot() -> void:
	# ANVIL_BLESSING är ett brännmärke på underarmen, inte utrustning (§4.1).
	assert_str(Content.relic_slot("ANVIL_BLESSING")).is_empty()


# ---------------------------------------------------------------------------
# Korridorskärmen: striden i de nedre 55 %
# ---------------------------------------------------------------------------

func test_the_corridor_screen_starts_at_full_height_with_the_thumb_zone_visible() -> void:
	var screen: CorridorScreen = _corridor(_map())
	await await_millis(40)
	var box: SubViewportContainer = screen.view().get_node("ViewportBox")
	assert_float(screen.view().split_ratio).is_equal_approx(CorridorView.SPLIT_EXPLORE, 0.001)
	assert_float(box.size.y).is_less(1920.0)
	assert_bool(screen.get_node("CombatHost").visible).is_false()


func test_mounting_a_fight_shrinks_the_corridor_and_fills_the_rest() -> void:
	var map: CorridorMap = _map()
	var screen: CorridorScreen = _corridor(map)
	screen.view().set_reduced_motion(true)
	var state: CombatState = Content.smith_state()
	state = RunFlow.start_room(state, {"room_in_floor": 1, "variant": 0}, Rng.new(5))
	var combat: CombatScreen = screen.mount_combat({
		"state": state, "rng": Rng.new(5), "node": {"room": 1, "floor": 1, "kind": "COMBAT"},
		"reveal": Reveal.all_on(), "tutorial_room": -1, "best_chain": 0,
	}, {})
	assert_object(combat).is_not_null()
	await await_millis(60)

	assert_bool(combat.in_corridor).is_true()
	var host: Control = screen.get_node("CombatHost")
	assert_bool(host.visible).is_true()
	# Korridoren har lämnat plats, och stridsskärmen börjar exakt där den slutar.
	assert_float(screen.view().split_ratio).is_less_equal(CorridorView.SPLIT_COMBAT + 0.001)
	assert_float(screen.view().split_ratio).is_greater_equal(CorridorView.SPLIT_COMBAT_MIN - 0.001)
	assert_float(host.get_global_rect().position.y).is_equal_approx(
		screen.view().split_height(), 1.0)


func test_the_fight_in_the_corridor_never_clips_the_thumb_zone() -> void:
	# COMBAT_READABILITY §8: räknestycket behåller full höjd, arenan betalar,
	# tumzonen aldrig. I korridoren ÄR arenan korridorbilden.
	var screen: CorridorScreen = _corridor(_map())
	screen.view().set_reduced_motion(true)
	var state: CombatState = Content.smith_state()
	state = RunFlow.start_room(state, {"room_in_floor": 1, "variant": 0}, Rng.new(5))
	var combat: CombatScreen = screen.mount_combat({
		"state": state, "rng": Rng.new(5), "node": {"room": 1, "floor": 1, "kind": "COMBAT"},
		"reveal": Reveal.all_on(), "tutorial_room": -1, "best_chain": 0,
	}, {})
	# Full placering ⇒ kvittot får sina sex leveransrader, alltså värsta fallet.
	var placement: PackedInt32Array = Policy.lookahead(combat.state)
	for slot: int in range(placement.size()):
		if placement[slot] >= 0:
			combat.place(placement[slot], slot)
	await await_millis(120)

	var host: Control = screen.get_node("CombatHost")
	assert_float(combat.required_height()).override_failure_message(
		"stridsskärmen behöver %.0f px men har %.0f" % [combat.required_height(), host.size.y]
	).is_less_equal(host.size.y + 1.0)
	var actions: Control = combat.get_node("Margin/Column/Actions")
	assert_float(actions.get_global_rect().end.y).override_failure_message(
		"knappraden hamnade utanför skärmen").is_less_equal(1921.0)


func test_the_chips_replace_the_enemy_panels_and_carry_the_same_numbers() -> void:
	var screen: CorridorScreen = _corridor(_map())
	screen.view().set_reduced_motion(true)
	var state: CombatState = Content.smith_state()
	state = RunFlow.start_room(state, {"room_in_floor": 1, "variant": 0}, Rng.new(5))
	var combat: CombatScreen = screen.mount_combat({
		"state": state, "rng": Rng.new(5), "node": {"room": 1, "floor": 1, "kind": "COMBAT"},
		"reveal": Reveal.all_on(), "tutorial_room": -1, "best_chain": 0,
	}, {})
	await await_millis(60)

	var chips: Array[EnemyChip] = screen.chips().chips()
	assert_int(chips.size()).is_equal(state.enemies.size())
	# Fiendezonen är tom: ingen fiende ritas två gånger (COMBAT_READABILITY §8).
	assert_bool(combat.get_node("Margin/Column/EnemyZone").visible).is_false()
	for i: int in range(chips.size()):
		assert_str(chips[i].enemy_id).is_equal(state.enemies[i].id)
		assert_str(chips[i].detail()).contains(
			EnemyReadout.display_name_of(state.enemies[i], chips[i].ordinal))


func test_the_prompt_asks_with_both_price_tags_before_the_tap() -> void:
	# §2.6: en fälla får aldrig visa kostnaden efteråt.
	var screen: CorridorScreen = _corridor(_map())
	screen.show_trap(CorridorMap.TRAPS[0])
	await await_millis(20)
	var prompt: CorridorPrompt = screen.prompt()
	assert_bool(prompt.visible).is_true()
	assert_int(prompt.option_count()).is_equal(2)
	for i: int in range(2):
		var label: String = (prompt.find_child("Option%d" % i, true, false) as Button).text
		assert_str(label).override_failure_message(
			"alternativ %d saknar prislapp: '%s'" % [i, label]).contains("·")
	# Panelen tar bara sin egen höjd och lämnar korridoren synlig.
	assert_float(prompt.get_global_rect().size.y).is_less(900.0)


func test_answering_a_trap_reports_the_index_and_closes_the_panel() -> void:
	var screen: CorridorScreen = _corridor(_map())
	var seen: Array[int] = []
	screen.trap_answered.connect(func(index: int) -> void: seen.append(index))
	screen.show_trap(CorridorMap.TRAPS[0])
	await await_millis(20)
	screen.prompt().press(1)
	assert_array(seen).is_equal([1])
	assert_bool(screen.prompt().visible).is_false()


func test_the_reward_sits_in_the_room_and_leaves_the_corridor_visible() -> void:
	var screen: CorridorScreen = _corridor(_map())
	var state: CombatState = Content.smith_state()
	var options: Array[Dictionary] = Rewards.generate(Content.reward_pool(), Rng.new(4), 1)
	var chosen: Array[Dictionary] = []
	screen.reward_chosen.connect(func(option: Dictionary, _t: Dictionary) -> void:
		chosen.append(option))
	screen.show_reward(state, options, true)
	await await_millis(40)

	var reward: CorridorReward = screen.reward()
	assert_bool(reward.visible).is_true()
	assert_int(reward.option_count()).is_equal(3)
	var cards: VBoxContainer = reward.get_node("Margin/Column/Cards")
	assert_float(cards.get_global_rect().size.y).override_failure_message(
		"korten fyller hela skärmen – då är det en skärm, inte ett altare (§3.5)"
	).is_less(1700.0)
	reward.choose(0)
	assert_int(chosen.size()).is_equal(1)
	assert_bool(reward.visible).is_false()


# ---------------------------------------------------------------------------
# Character sheet (CORRIDOR_DESIGN §4)
# ---------------------------------------------------------------------------

func _sheet(in_town: bool) -> CharacterSheet:
	var scene: PackedScene = load(SHEET_SCENE) as PackedScene
	var sheet: CharacterSheet = auto_free(scene.instantiate()) as CharacterSheet
	add_child(sheet)
	sheet.size = Vector2(1080.0, 1920.0)
	sheet.open_for({
		"state": Content.smith_state(),
		"meta": Meta.fresh(),
		"in_town": in_town,
		"room": 2,
		"seed": 7,
	})
	return sheet


func test_the_sheet_draws_all_seven_slots_and_all_six_dice() -> void:
	var sheet: CharacterSheet = _sheet(true)
	await await_millis(40)
	for slot: Variant in Content.SHEET_SLOTS:
		var button: Button = sheet.slot_button(String(slot))
		assert_object(button).override_failure_message(
			"sloten %s ritas inte" % String(slot)).is_not_null()
		assert_bool(button.visible).is_true()
	assert_int(Content.SHEET_SLOTS.size()).is_equal(7)
	var dice: HBoxContainer = sheet.get_node("Margin/Column/Footer/Dice")
	assert_int(dice.get_child_count()).is_equal(Content.smith_state().dice.size())


func test_the_forge_is_read_only_while_the_run_is_in_the_corridor() -> void:
	# §4.1 punkt 3: mitt i en run är brädet i spel, och en omordning utan
	# kostnad vore ett gratis drag.
	var sheet: CharacterSheet = _sheet(false)
	await await_millis(40)
	var order: HBoxContainer = sheet.get_node("Margin/Column/Footer/SlotOrder")
	for i: int in range(order.get_child_count()):
		var move: Button = order.get_child(i).get_node("Move%d" % i)
		assert_bool(move.disabled).override_failure_message(
			"slotknapp %d går att trycka mitt i en run" % i).is_true()
	assert_bool(sheet.get_node("Margin/Column/Footer/GoDownButton").visible).is_false()


func test_the_town_sheet_can_reorder_and_go_down() -> void:
	var sheet: CharacterSheet = _sheet(true)
	await await_millis(40)
	var order: HBoxContainer = sheet.get_node("Margin/Column/Footer/SlotOrder")
	assert_bool((order.get_child(0).get_node("Move0") as Button).disabled).is_false()
	assert_bool(sheet.get_node("Margin/Column/Footer/GoDownButton").visible).is_true()


func test_tapping_a_slot_answers_with_the_same_sentence_as_the_reward_card() -> void:
	var sheet: CharacterSheet = _sheet(true)
	await await_millis(40)
	var relic: Relic = Content.make_relic("DOMINO")
	sheet.state.relics.append(relic)
	sheet.refresh()
	await await_millis(20)
	sheet.slot_button(Content.SLOT_WEAPON).pressed.emit()
	var expected: String = RewardApply.describe(sheet.state, {
		"id": "RELIC_DOMINO", "category": Rewards.CATEGORY_RELIC,
		"name": relic.display_name, "name_key": Content.relic_key("DOMINO"),
		"rarity": relic.rarity, "data": {"relic_id": "DOMINO"},
	}, {})
	assert_str(sheet.detail_text()).is_equal(expected)


# ---------------------------------------------------------------------------
# Torget (CORRIDOR_DESIGN §5.1)
# ---------------------------------------------------------------------------

func test_the_town_square_is_a_room_with_three_lit_mouths() -> void:
	var map: CorridorMap = CorridorMap.town_square()
	assert_int(map.cells.size()).is_equal(
		CorridorMap.TOWN_EXIT_OFFSETS.size() * (CorridorMap.TOWN_DEPTH + 1))
	assert_int(map.facing).is_equal(CorridorMap.FACING_NORTH)
	for i: int in range(3):
		var tile: Vector2i = CorridorMap.town_exit_tile(i)
		var cell: Dictionary = map.cell_at(tile)
		assert_str(String(cell["kind"])).is_equal(CorridorMap.KIND_ALCOVE)
		assert_bool(bool(cell["torch"])).is_true()
	# Geometrin går genom samma byggare som Gropen – noll ny kod (research 05 §6).
	var built: Dictionary = CorridorMesh.build(map)
	assert_int((built["mesh"] as ArrayMesh).get_surface_count()).is_equal(3)
	assert_int((built["torches"] as Array).size()).is_greater_equal(3)


func test_every_mouth_is_tappable_inside_the_picture() -> void:
	var scene: PackedScene = load(TOWN_SCENE) as PackedScene
	var town: TownScreen = auto_free(scene.instantiate()) as TownScreen
	add_child(town)
	town.size = Vector2(1080.0, 1920.0)
	var meta: Meta = Meta.fresh()
	meta.runs = 3
	town.setup(null, null, {"meta": meta, "seed": 7, "arrival": {}})
	await await_millis(80)

	var view: TownView = town.get_node("View")
	for i: int in range(3):
		var anchor: Vector2 = view.exit_anchor(i)
		assert_float(anchor.x).override_failure_message(
			"mynning %d ligger bakom kameran" % i).is_greater(0.0)
		var button: Button = view.place_button(i)
		assert_object(button).is_not_null()
		assert_bool(button.visible).is_true()
		var rect: Rect2 = button.get_global_rect()
		assert_float(rect.position.x).is_greater_equal(-1.0)
		assert_float(rect.end.x).override_failure_message(
			"skylten %d klipps mot skärmkanten" % i).is_less_equal(1081.0)
	# Vänster mynning ligger till vänster om höger. Ordningen är inte kosmetisk:
	# den är hela kartan spelaren bygger i huvudet (§5.1).
	assert_float(view.exit_anchor(0).x).is_less(view.exit_anchor(1).x)
	assert_float(view.exit_anchor(1).x).is_less(view.exit_anchor(2).x)


func test_go_down_is_always_in_the_thumb_zone() -> void:
	# §A.4 regel 1, oförändrad efter presentationsbytet.
	var scene: PackedScene = load(TOWN_SCENE) as PackedScene
	var town: TownScreen = auto_free(scene.instantiate()) as TownScreen
	add_child(town)
	town.size = Vector2(1080.0, 1920.0)
	town.setup(null, null, {"meta": Meta.fresh(), "seed": 7, "arrival": {}})
	await await_millis(80)
	var go_down: Button = town.get_node("Margin/Column/GoDownButton")
	assert_bool(go_down.visible).is_true()
	assert_bool(go_down.disabled).is_false()
	assert_float(go_down.get_global_rect().end.y).is_less_equal(1921.0)
	assert_float(go_down.get_global_rect().position.y).override_failure_message(
		"GO DOWN ligger utanför tumzonen").is_greater(1920.0 * 0.58)


# ---------------------------------------------------------------------------
# Tumzonen måste gå att träffa (regression 2026-09-22)
# ---------------------------------------------------------------------------

## Godots träffsökning, förenklad: översta syskonet vinner, och [b]PASS stoppar
## sökningen[/b] precis som STOP – skillnaden är bara att eventet sedan
## bubblar vidare till FÖRÄLDERN, aldrig till syskonen under.
##
## Det var den missuppfattningen som gjorde hela korridoren otryckbar i
## webbexporten: `Chips` och `Overlay` låg överst, täckte hela skärmen och stod
## på PASS. Varje tapp på FORWARD, på HUD:ens knappar och på fällprompten
## hamnade i en tom container.
static func _topmost_hit(node: Control, point: Vector2) -> Control:
	for i: int in range(node.get_child_count() - 1, -1, -1):
		var child: Control = node.get_child(i) as Control
		if child == null or not child.visible:
			continue
		var found: Control = _topmost_hit(child, point)
		if found != null:
			return found
	if node.mouse_filter != Control.MOUSE_FILTER_IGNORE and node.get_global_rect().has_point(point):
		return node
	return null


func test_the_forward_button_is_the_topmost_control_under_the_thumb() -> void:
	var screen: CorridorScreen = _corridor(_map())
	await await_millis(40)
	var forward: Button = screen.view().get_node("Steer/Row/Forward")
	var hit: Control = _topmost_hit(screen, forward.get_global_rect().get_center())
	assert_object(hit).override_failure_message(
		"tappet på FORWARD togs av %s, inte av knappen" % [hit.get_path() if hit != null else "ingenting"]
	).is_same(forward)


static func _buttons_under(node: Node, out: Array[Button]) -> Array[Button]:
	for child: Node in node.get_children():
		var button: Button = child as Button
		if button != null and button.visible and not button.disabled:
			out.append(button)
		_buttons_under(child, out)
	return out


func test_every_visible_corridor_button_is_the_topmost_control_under_the_thumb() -> void:
	# Character sheet, inställningar och de riktningsknappar som är giltiga.
	var screen: CorridorScreen = _corridor(_map())
	await await_millis(40)
	var buttons: Array[Button] = _buttons_under(screen.view(), [] as Array[Button])
	assert_int(buttons.size()).is_greater(2)
	for button: Button in buttons:
		var hit: Control = _topmost_hit(screen, button.get_global_rect().get_center())
		assert_object(hit).override_failure_message(
			"tappet på %s togs av %s" % [button.get_path(), hit.get_path() if hit != null else "ingenting"]
		).is_same(button)


func test_the_full_screen_layers_never_stop_a_tap_themselves() -> void:
	# De här två har inget eget innehåll att trycka på: deras barn (chip,
	# prompt, belöningskort) sätter STOP själva. Står de på PASS eller STOP
	# sväljer de hela korridoren under sig.
	var screen: CorridorScreen = _corridor(_map())
	await await_millis(40)
	for layer_name: String in ["Chips", "Overlay"]:
		assert_int((screen.get_node(layer_name) as Control).mouse_filter).override_failure_message(
			"%s måste vara MOUSE_FILTER_IGNORE" % layer_name
		).is_equal(Control.MOUSE_FILTER_IGNORE)
