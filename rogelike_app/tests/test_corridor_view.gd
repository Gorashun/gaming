extends GdUnitTestSuite
## Korridorvyn utan att rendera: geometrin, splitarna, knapparna och
## ankarmatematiken. [code]godot --headless[/code] ritar ingenting, men
## [ArrayMesh]-topologin och [method Camera3D.unproject_position] är ren
## matematik och går därför att asserta här (research 05 §7).

const VIEW_SCENE: String = "res://src/game/corridor/corridor_view.tscn"


func _map(seed_value: int = 7, allow_fate: bool = false) -> CorridorMap:
	var rng: Rng = Rng.new(seed_value)
	var graph: RunGraph = RunGraph.generate_floor(1, rng)
	return CorridorMap.build(graph, rng.fork("corridor"), allow_fate)


func _view(map: CorridorMap) -> CorridorView:
	var scene: PackedScene = load(VIEW_SCENE) as PackedScene
	var view: CorridorView = auto_free(scene.instantiate()) as CorridorView
	add_child(view)
	view.size = Vector2(1080.0, 1920.0)
	view.setup(map, {"hp": 74, "max_hp": 100, "room": 1, "pips": 12})
	return view


# --- Geometrin -------------------------------------------------------------

func test_the_floor_becomes_one_mesh_with_three_surfaces() -> void:
	var built: Dictionary = CorridorMesh.build(_map())
	var mesh: ArrayMesh = built["mesh"]
	# Golv, tak och vägg. En yta per textur: mipmaps på en atlas blöder.
	assert_int(mesh.get_surface_count()).is_equal(3)
	for i: int in range(mesh.get_surface_count()):
		assert_object(mesh.surface_get_material(i)).is_not_null()
		assert_int(mesh.surface_get_array_len(i)).is_greater(0)


func test_a_wall_quad_is_emitted_exactly_where_the_map_is_closed() -> void:
	var map: CorridorMap = _map()
	var closed: int = 0
	for key: String in map.tiles():
		var at: Vector2i = CorridorMap.key_to_vec(key)
		for facing: int in range(4):
			if not map.is_open(at, facing):
				closed += 1
	var built: Dictionary = CorridorMesh.build(map)
	var mesh: ArrayMesh = built["mesh"]
	# Index, inte hörn: SurfaceTool.index() slår ihop identiska hörn, och
	# grannrutornas golvkanter ÄR identiska eftersom UV:n räknas ur
	# världskoordinaten. Indexantalet är däremot stabilt: sex per kvad.
	assert_int(_indices(mesh, 2)).override_failure_message(
		"väggkvaderna stämmer inte med kartans stängda sidor").is_equal(closed * 6)
	for surface: int in [0, 1]:
		assert_int(_indices(mesh, surface)).is_equal(map.tiles().size() * 6)


func _indices(mesh: ArrayMesh, surface: int) -> int:
	return (mesh.surface_get_arrays(surface)[ArrayMesh.ARRAY_INDEX] as PackedInt32Array).size()


func test_the_boss_door_hangs_between_the_door_cell_and_the_boss() -> void:
	var map: CorridorMap = _map()
	var doors: Array = CorridorMesh.build(map)["doors"]
	assert_int(doors.size()).is_equal(1)
	var door: Dictionary = doors[0]
	var at: Vector2i = door["tile"]
	assert_str(String((map.cells[CorridorMap.cell_key(at)] as Dictionary)["kind"])).is_equal(
		CorridorMap.KIND_BOSS_DOOR)
	var beyond: Vector2i = at + CorridorMap.DIRS[int(door["facing"])]
	assert_bool(bool((map.cells[CorridorMap.cell_key(beyond)] as Dictionary)["boss"])).is_true()


func test_every_junction_sign_faces_the_player_who_arrives() -> void:
	# UI_GUIDE §17.2: en skylt i själva mynningen syns inte förrän man redan
	# vänt sig dit, och då är valet gjort.
	for seed_value: int in range(12):
		var map: CorridorMap = _map(seed_value)
		var signs: Array = CorridorMesh.build(map)["signs"]
		assert_int(signs.size()).is_greater_equal(2)
		var facings: Dictionary = {}
		for spec: Dictionary in signs:
			facings[int(spec["facing"])] = true
			assert_bool(CorridorMap.SIGN_KEYS.has(String(spec["key"]))).is_true()
		assert_int(facings.size()).override_failure_message(
			"skyltarna vid samma korsning pekar åt olika håll").is_equal(1)


func test_every_sign_key_maps_to_an_icon_that_exists() -> void:
	for key: String in CorridorMap.SIGN_KEYS:
		var icon: Texture2D = Art.node_icon(CorridorView._icon_key(key))
		assert_object(icon).override_failure_message(
			"skyltnyckeln %s saknar nodikon" % key).is_not_null()


func test_the_tile_textures_carry_mipmaps() -> void:
	# research 05 §7: undantaget från "Mipmaps: Off". Nearest utan mipmaps
	# kokar på golv och tak i snedvinkel, 63 steg per run.
	for surface: String in [CorridorMesh.SURFACE_WALL, CorridorMesh.SURFACE_FLOOR,
			CorridorMesh.SURFACE_CEILING]:
		var texture: Texture2D = CorridorMesh.tile_texture(String(CorridorMesh.TEXTURES[surface]))
		assert_object(texture).is_not_null()
		assert_bool(texture.get_image().has_mipmaps()).override_failure_message(
			"%s saknar mipmaps" % surface).is_true()


# --- Vyn -------------------------------------------------------------------

func test_the_view_starts_on_the_first_tile_looking_down_the_corridor() -> void:
	var map: CorridorMap = _map()
	var view: CorridorView = _view(map)
	var camera: Camera3D = view.get_node("ViewportBox/SubViewport/World/Camera")
	assert_float(camera.position.y).is_equal_approx(CorridorMesh.EYE_M, 0.001)
	assert_float(camera.fov).is_equal_approx(CorridorCamera.FOV_DEGREES, 0.001)
	assert_int(camera.keep_aspect).is_equal(Camera3D.KEEP_WIDTH)
	assert_float(camera.rotation.y).is_equal_approx(map.yaw_radians(), 0.001)


func test_the_split_changes_the_height_and_never_the_width() -> void:
	var view: CorridorView = _view(_map())
	var box: SubViewportContainer = view.get_node("ViewportBox")
	view.show_explore_split()
	await await_millis(20)
	var explore: Vector2 = box.size
	view.show_combat_split()
	await await_millis(20)
	var combat: Vector2 = box.size
	assert_float(combat.x).is_equal_approx(explore.x, 0.5)
	assert_float(combat.y).is_less(explore.y)
	assert_float(combat.y).is_equal_approx(1920.0 * CorridorView.SPLIT_COMBAT, 1.0)
	# Uppskalningen är heltal: 540×432 i strid, samma bredd i utforskning.
	assert_int(box.stretch_shrink).is_equal(2)
	assert_int(box.get_node("SubViewport").size.x).is_equal(int(combat.x) / 2)


func test_reduced_motion_places_the_camera_at_once() -> void:
	var map: CorridorMap = _map()
	var view: CorridorView = _view(map)
	view.set_reduced_motion(true)
	var camera: Camera3D = view.get_node("ViewportBox/SubViewport/World/Camera")
	var before: Vector3 = camera.position
	await view.step(CorridorMap.ACTION_FORWARD)
	assert_vector(camera.position).is_not_equal(before)
	assert_float(camera.position.distance_to(CorridorMesh.eye_position(map.position))).is_less(2.0)


func test_walking_the_floor_emits_one_cell_changed_per_step() -> void:
	var map: CorridorMap = _map()
	var view: CorridorView = _view(map)
	view.set_reduced_motion(true)
	var seen: Array[Dictionary] = []
	view.cell_changed.connect(func(cell: Dictionary, _state: Dictionary) -> void: seen.append(cell))
	var guard: int = 0
	while not map.is_finished() and guard < 60:
		guard += 1
		if map.pending_trap_key != "":
			view.resolve_trap(0)
			continue
		var actions: Dictionary = view.map.available_actions()
		if actions.is_empty():
			break
		await view.step(actions.keys()[0] as String)
	assert_bool(map.is_finished()).is_true()
	assert_int(seen.size()).is_equal(map.steps_taken)


func test_the_enemy_anchor_lands_inside_the_corridor_rectangle() -> void:
	# Chipen i krit-lagret hängs på den här punkten. Hamnar den utanför
	# containern är bakre ledet dekor (UI_GUIDE §17.2).
	var map: CorridorMap = _map()
	var view: CorridorView = _view(map)
	view.set_reduced_motion(true)
	view.show_combat_split()
	view.set_next_enemies(["RUST_RAT", "RUST_RAT", "RUST_RAT", "RUST_RAT"])
	await view.step(CorridorMap.ACTION_FORWARD)
	await view.step(CorridorMap.ACTION_FORWARD)
	await await_millis(20)
	var box: SubViewportContainer = view.get_node("ViewportBox")
	var rect: Rect2 = box.get_global_rect()
	var inside: int = 0
	for i: int in range(4):
		var anchor: Vector2 = view.enemy_anchor(i)
		if anchor.x >= 0.0 and rect.has_point(anchor):
			inside += 1
	assert_int(inside).override_failure_message(
		"inget fiendeankare hamnade i korridorrektangeln %s" % rect).is_greater_equal(2)


# --- Knapparna -------------------------------------------------------------

func test_an_invalid_direction_is_dimmed_and_never_hidden() -> void:
	# UI_GUIDE §17.4: en knapp som flyttar sig är värre än en som är grå.
	var steer: DirectionButtons = auto_free(DirectionButtons.new())
	add_child(steer)
	steer.set_actions({CorridorMap.ACTION_FORWARD: {"dir": 0, "sign": CorridorMap.SIGN_FIGHT}})
	for action: String in [CorridorMap.ACTION_LEFT, CorridorMap.ACTION_FORWARD, CorridorMap.ACTION_RIGHT]:
		var button: Button = steer.get_node("Row/%s" % action.capitalize())
		assert_bool(button.visible).is_true()
		assert_bool(button.disabled).is_equal(action != CorridorMap.ACTION_FORWARD)
	var forward: Button = steer.get_node("Row/Forward")
	assert_float(forward.size_flags_stretch_ratio).is_equal_approx(
		DirectionButtons.CENTER_WIDTH_FACTOR, 0.001)
	assert_str(steer.get_node("Row/Forward/Column/Subtitle").text).is_equal(
		DirectionButtons.sign_label(CorridorMap.SIGN_FIGHT))


func test_every_sign_key_has_a_button_label() -> void:
	for key: String in CorridorMap.SIGN_KEYS:
		assert_str(DirectionButtons.sign_label(key)).override_failure_message(
			"skyltnyckeln %s saknar knappetikett" % key).is_not_empty()


func test_the_hud_shows_hp_room_and_the_chalk_trail() -> void:
	var hud: CorridorHud = auto_free(CorridorHud.new())
	add_child(hud)
	hud.set_status(74, 100, 3, 1, 12)
	hud.set_trail(5, 5)
	await await_millis(20)
	var bar: HBoxContainer = hud.get_node("Bar")
	var texts: PackedStringArray = PackedStringArray()
	for child: Node in bar.get_children():
		if child is Label:
			texts.append((child as Label).text)
			# clip_text nollar etikettens minimibredd i en HBoxContainer och
			# raden blir osynlig. Regressionsvakt.
			assert_bool((child as Label).clip_text).is_false()
	assert_bool("74/100" in texts).is_true()
	assert_int(hud.get_node("TrailRow/Trail").get_child_count()).is_equal(5)


# ---------------------------------------------------------------------------
# Återupptagen strid (M5.8)
# ---------------------------------------------------------------------------

## En laddad sparfil får aldrig visa ett stridsbräde mot en tom korridor.
## Monstren spawnas normalt av [constant CorridorMap.EVENT_ENCOUNTER_REACHED],
## och den händelsen kommer inte en andra gång.
func test_a_resumed_fight_puts_the_monsters_back_without_replaying_the_reveal() -> void:
	var view: CorridorView = _view(_map())
	view.set_next_enemies(["RUST_MITE", "RUST_MITE"])
	assert_bool(view.has_encounter()).is_false()

	view.restore_encounter()
	assert_bool(view.has_encounter()).override_failure_message(
		"mötet ska stå framme direkt efter en omladdning").is_true()

	# No-op andra gången: den normala vägen avslöjar mötet själv och får inte
	# störas av den här.
	view.restore_encounter()
	assert_bool(view.has_encounter()).is_true()


func test_restoring_an_encounter_nobody_primed_does_nothing() -> void:
	var view: CorridorView = _view(_map())
	view.restore_encounter()
	assert_bool(view.has_encounter()).is_false()
