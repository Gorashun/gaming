extends GdUnitTestSuite
## Fienderna som målade battlers (M6 spår A steg 2). Headless ritar ingenting,
## men storlek, pivot, formering, sortering och tweens är ren data.

const VIEW_SCENE: String = "res://src/game/corridor/corridor_view.tscn"
const REAL_PNG: String = "res://assets/sprites/enemies/rust_rat.png"


func after_test() -> void:
	Art.reload_manifest()


func _map(seed_value: int = 7) -> CorridorMap:
	var rng: Rng = Rng.new(seed_value)
	var graph: RunGraph = RunGraph.generate_floor(1, rng)
	return CorridorMap.build(graph, rng.fork("corridor"), false)


func _view() -> CorridorView:
	var scene: PackedScene = load(VIEW_SCENE) as PackedScene
	var view: CorridorView = auto_free(scene.instantiate()) as CorridorView
	add_child(view)
	view.size = Vector2(1080.0, 1920.0)
	view.setup(_map(), {"hp": 74, "max_hp": 100, "room": 1, "pips": 12})
	view.set_reduced_motion(true)
	return view


func _battler(enemy_id: String) -> EnemyBattler:
	var battler: EnemyBattler = auto_free(EnemyBattler.new())
	battler.setup(enemy_id)
	add_child(battler)
	return battler


## Väggklocka, inte await_millis: den senare kom tillbaka efter 8 ms i en
## körning och gjorde blixttestet flakigt.
func _wait_ms(ms: int) -> void:
	var until: int = Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _quad(battler: EnemyBattler) -> QuadMesh:
	return (battler.get_node("Body") as MeshInstance3D).mesh as QuadMesh


func test_a_painted_battler_is_one_png_scaled_by_its_manifest_size() -> void:
	Art.use_manifest({"enemy.RUST_RAT": {"file": REAL_PNG, "kind": "battler",
		"size": [300, 600], "pivot": "bottom", "frames": 1, "license": "CC0"}})
	var battler: EnemyBattler = _battler("RUST_RAT")
	assert_str(battler.source).is_equal(Art.SOURCE_MANIFEST)
	assert_bool(battler.is_pixel).is_false()
	var quad: QuadMesh = _quad(battler)
	# Bredden följer PNG:ens proportion, höjden är inpassad i fiendens ruta.
	assert_float(quad.size.x / quad.size.y).is_equal_approx(0.5, 0.001)
	assert_float(quad.size.y).is_equal_approx(EnemyBattler.ENEMY_MAX_M.y, 0.001)
	# Hela bilden, inget ark-rutnät.
	var region: Vector4 = battler.material().get_shader_parameter(&"region")
	assert_vector(region).is_equal(Vector4(0.0, 0.0, 1.0, 1.0))
	# Målad konst: linear + mipmaps.
	assert_str(battler.material().shader.resource_path).is_equal(EnemyBattler.SHADER_PAINTED)


func test_the_feet_stand_on_the_floor() -> void:
	var battler: EnemyBattler = _battler("RUST_RAT")
	var quad: QuadMesh = _quad(battler)
	# Kvadens underkant ligger på nodens origo, och noden står på golvet.
	assert_float(quad.center_offset.y - quad.size.y * 0.5).is_equal_approx(0.0, 0.0001)
	assert_float((battler.get_node("Body") as Node3D).position.y).is_equal_approx(0.0, 0.0001)


func test_pixel_true_or_an_old_sprite_uses_the_nearest_shader() -> void:
	Art.use_manifest({})
	var legacy: EnemyBattler = _battler("RUST_RAT")
	assert_str(legacy.source).is_equal(Art.SOURCE_LEGACY)
	assert_str(legacy.material().shader.resource_path).is_equal(EnemyBattler.SHADER_PIXEL)
	# Det gamla arket samplas som hela atlasen: regionen är ruta 0.
	var region: Vector4 = legacy.material().get_shader_parameter(&"region")
	assert_float(region.z).is_equal_approx(0.25, 0.0001)
	assert_float(region.w).is_equal_approx(0.5, 0.0001)


func test_the_boss_is_drawn_bigger() -> void:
	var boss: EnemyBattler = _battler("SLAGJAW")
	var rat: EnemyBattler = _battler("RUST_RAT")
	assert_bool(boss.is_boss).is_true()
	assert_float(_quad(boss).size.y * _quad(boss).size.x).is_greater(_quad(rat).size.y * _quad(rat).size.x * 1.5)


## Skalan är fast per pixel: en större figur i konsten är större i korridoren,
## men ingen spränger sin ruta och ingen boss går genom taket.
func test_world_size_keeps_relative_scale_and_fits_the_box() -> void:
	var rat: Vector2 = EnemyBattler.world_size(Vector2(204, 210), false, false)
	var zombie: Vector2 = EnemyBattler.world_size(Vector2(244, 351), false, false)
	assert_float(zombie.y).is_greater(rat.y)
	assert_float(rat.y).is_equal_approx(210.0 * EnemyBattler.PAINTED_M_PER_PX, 0.001)
	var boss: Vector2 = EnemyBattler.world_size(Vector2(1024, 496), false, true)
	assert_float(boss.x).is_less_equal(EnemyBattler.BOSS_MAX_M.x + 0.001)
	assert_float(boss.y).is_less_equal(CorridorMesh.CEIL_M)
	assert_float(boss.x / boss.y).is_equal_approx(1024.0 / 496.0, 0.001)
	# Den gamla 32 px-spriten blir exakt lika stor som i M5.
	assert_float(EnemyBattler.world_size(Vector2(32, 32), true, false).y).is_equal_approx(1.76, 0.001)
	# Ingen fiende blir en prick.
	assert_float(EnemyBattler.world_size(Vector2(40, 20), false, false).y).is_greater_equal(EnemyBattler.ENEMY_MIN_HEIGHT_M - 0.001)


func test_an_enemy_nobody_drew_is_a_placeholder_and_not_a_crash() -> void:
	var battler: EnemyBattler = _battler("NOT_IN_ANY_MANIFEST")
	assert_str(battler.source).is_equal(Art.SOURCE_PLACEHOLDER)
	assert_object(battler.material().get_shader_parameter(&"albedo_tex")).is_not_null()


func test_every_battler_has_a_cast_shadow_on_the_floor() -> void:
	var battler: EnemyBattler = _battler("IRON_TICK")
	var shadow: Sprite3D = battler.get_node("Shadow") as Sprite3D
	assert_object(shadow).is_not_null()
	assert_float(shadow.position.y).is_less(0.05)
	assert_float(shadow.rotation.x).is_equal_approx(-PI * 0.5, 0.001)


func test_the_formation_is_two_plus_two_and_the_front_rank_draws_on_top() -> void:
	var view: CorridorView = _view()
	view.set_next_enemies(["RUST_RAT", "RUST_RAT", "RUST_RAT", "RUST_RAT"])
	view.restore_encounter()
	assert_int(view.enemy_count()).is_equal(4)
	var front: EnemyBattler = view.enemy_battler(0)
	var back: EnemyBattler = view.enemy_battler(2)
	assert_float(back.position.z).is_less(front.position.z)
	assert_int(front.material().render_priority).is_greater(back.material().render_priority)


func test_reveal_clears_the_silhouette() -> void:
	var view: CorridorView = _view()
	view.set_next_enemies(["RUST_RAT", "IRON_TICK"])
	view.restore_encounter()
	for i: int in range(view.enemy_count()):
		assert_float(view.enemy_battler(i).silhouette).is_equal(0.0)


func test_a_hit_flashes_through_the_palette_shader() -> void:
	var battler: EnemyBattler = _battler("RUST_RAT")
	battler.hit(true)
	assert_float(float(battler.material().get_shader_parameter(&"flash"))).is_equal(1.0)
	await _wait_ms(EnemyBattler.FLASH_MS + 80)
	assert_float(float(battler.material().get_shader_parameter(&"flash"))).is_less(0.05)


func test_death_fades_and_falls_and_reduced_motion_skips_the_fall() -> void:
	var battler: EnemyBattler = _battler("RUST_RAT")
	battler.die(false)
	await _wait_ms(EnemyBattler.DEATH_MS + 80)
	assert_float(battler.fade).is_less(0.01)
	assert_float(absf(battler.tilt)).is_greater(0.5)
	var calm: EnemyBattler = _battler("RUST_RAT")
	calm.die(true)
	assert_float(calm.fade).is_equal(0.0)
	assert_float(calm.tilt).is_equal(0.0)


func test_reduced_motion_means_no_breathing() -> void:
	var battler: EnemyBattler = _battler("RUST_RAT")
	battler.start_idle(0.0, true)
	await _wait_ms(300)
	assert_float((battler.get_node("Body") as Node3D).scale.y).is_equal(1.0)


func test_the_chip_anchor_sits_above_the_head() -> void:
	var battler: EnemyBattler = _battler("SLAGJAW")
	assert_float(battler.head_point().y).is_greater(battler.height_m)


func test_a_lone_enemy_stands_in_the_middle_and_three_stand_two_plus_one() -> void:
	assert_float(CorridorView.formation_for(1)[0].x).is_equal(0.0)
	var three: Array[Vector3] = CorridorView.formation_for(3)
	assert_int(three.size()).is_equal(3)
	assert_float(three[2].x).is_equal(0.0)
	assert_float(three[2].z).is_less(three[0].z)
	assert_int(CorridorView.formation_for(4).size()).is_equal(4)
