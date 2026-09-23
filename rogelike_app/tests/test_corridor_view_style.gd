extends GdUnitTestSuite
## Stilskiktet (M6 spår A steg 3, ART_DIRECTION_V2 steg 0): bakat ljus,
## vinjett, damm, narrator och de två renderingsbuggarna. Headless ritar inget,
## men hörnfärger, noder, shaders och texturernas pixlar är data.

const VIEW_SCENE: String = "res://src/game/corridor/corridor_view.tscn"


func _map(seed_value: int = 7) -> CorridorMap:
	var rng: Rng = Rng.new(seed_value)
	var graph: RunGraph = RunGraph.generate_floor(1, rng)
	return CorridorMap.build(graph, rng.fork("corridor"), false)


func _view(reduced: bool = false) -> CorridorView:
	var scene: PackedScene = load(VIEW_SCENE) as PackedScene
	var view: CorridorView = auto_free(scene.instantiate()) as CorridorView
	view.reduced_motion = reduced
	add_child(view)
	view.size = Vector2(1080.0, 1920.0)
	view.setup(_map(), {"hp": 74, "max_hp": 100, "room": 1, "pips": 12})
	return view


# --- Ljuset ----------------------------------------------------------------

func test_the_light_is_warm_near_a_torch_and_cold_far_from_it() -> void:
	var torch: Vector3 = Vector3(0.0, 2.0, 0.0)
	var near: Color = CorridorLight.bake(Vector3(0.5, 1.5, 0.0), PackedVector3Array([torch]))
	var far: Color = CorridorLight.bake(Vector3(20.0, 1.5, 0.0), PackedVector3Array([torch]))
	# Varm nära: rött över blått. Kall långt bort: blått över rött.
	assert_float(near.r).is_greater(near.b)
	assert_float(far.b).is_greater(far.r)
	assert_float(near.r).is_greater(far.r)
	# Avståndsfalloff: halvvägs är svagare än nära.
	var mid: Color = CorridorLight.bake(Vector3(3.0, 1.5, 0.0), PackedVector3Array([torch]))
	assert_float(mid.r).is_between(far.r, near.r)


func test_the_hand_torch_falls_off_with_distance() -> void:
	assert_float(CorridorLight.hand(1.0).r).is_greater(CorridorLight.hand(4.0).r)
	assert_float(CorridorLight.hand(CorridorLight.HAND_RANGE_M + 1.0).r).is_equal(0.0)


func test_the_mesh_carries_baked_vertex_colours_and_the_ceiling_is_darkest() -> void:
	var built: Dictionary = CorridorMesh.build(_map())
	var mesh: ArrayMesh = built["mesh"]
	var floor_colors: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var ceiling_colors: PackedColorArray = mesh.surface_get_arrays(1)[Mesh.ARRAY_COLOR]
	assert_int(floor_colors.size()).is_greater(0)
	assert_float(_mean(ceiling_colors)).is_less(_mean(floor_colors))
	# Inte platt: facklorna ger variation i golvets ljus.
	var lo: float = 9.0
	var hi: float = 0.0
	for c: Color in floor_colors:
		lo = minf(lo, c.r)
		hi = maxf(hi, c.r)
	assert_float(hi - lo).is_greater(0.2)
	assert_int((built["lights"] as PackedVector3Array).size()).is_greater(0)


func _mean(colors: PackedColorArray) -> float:
	var total: float = 0.0
	for c: Color in colors:
		total += c.r + c.g + c.b
	return total / maxf(1.0, float(colors.size()))


func test_every_surface_uses_the_lit_shader_and_painted_art_is_linear() -> void:
	var mesh: ArrayMesh = CorridorMesh.build(_map())["mesh"]
	for i: int in range(mesh.get_surface_count()):
		var mat: ShaderMaterial = mesh.surface_get_material(i) as ShaderMaterial
		assert_object(mat).is_not_null()
		var path: String = mat.shader.resource_path
		assert_bool(path.begins_with("res://src/game/shaders/corridor_surface")).is_true()
	for surface: String in [CorridorMesh.SURFACE_WALL, CorridorMesh.SURFACE_FLOOR, CorridorMesh.SURFACE_CEILING]:
		var id: StringName = CorridorMesh.TEXTURES[surface]
		var mat: ShaderMaterial = CorridorMesh.tile_material(surface)
		var expected: String = CorridorMesh.SHADER_PIXEL if Art.is_pixel(id) else CorridorMesh.SHADER_PAINTED
		assert_str(mat.shader.resource_path).is_equal(expected)


# --- Buggarna ----------------------------------------------------------------

## Research 06 §1: "röda scanlines i taket". Orsaken var två helt röda
## pixelrader i ceiling_stone.png, upprepade två gånger per ruta. Oavsett vilken
## textur taket får (manifest eller reserv) får ingen rad vara en röd linje.
func test_the_ceiling_texture_has_no_red_scanline_rows() -> void:
	var texture: Texture2D = CorridorMesh.surface_texture(CorridorMesh.SURFACE_CEILING)
	assert_object(texture).is_not_null()
	# duplicate(): i headless returnerar dummy-renderaren den LAGRADE bilden,
	# och clear_mipmaps() nedan tog annars bort mipmaparna ur cachen.
	var image: Image = texture.get_image().duplicate() as Image
	if image.is_compressed():
		image.decompress()
	image.clear_mipmaps()
	var w: int = image.get_width()
	var step: int = maxi(1, w / 128)
	for y: int in range(image.get_height()):
		var red: int = 0
		var samples: int = 0
		for x: int in range(0, w, step):
			var c: Color = image.get_pixel(x, y)
			samples += 1
			if c.r > c.g + 0.15 and c.r > c.b + 0.15:
				red += 1
		assert_float(float(red) / float(samples)).override_failure_message(
			"takets rad %d är en röd linje (%d av %d pixlar)" % [y, red, samples]).is_less(0.5)


# --- Vinjett, damm, narrator ------------------------------------------------

func test_the_vignette_sits_over_the_3d_and_under_the_hud() -> void:
	var view: CorridorView = _view()
	var vignette: ColorRect = view.get_node("Vignette") as ColorRect
	var box: Control = view.get_node("ViewportBox")
	var hud: Control = view.get_node("Hud")
	assert_int(vignette.get_index()).is_greater(box.get_index())
	assert_int(vignette.get_index()).is_less(hud.get_index())
	assert_int(vignette.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_str((vignette.material as ShaderMaterial).shader.resource_path).is_equal(CorridorView.VIGNETTE_SHADER)
	await await_idle_frame()
	# Följer korridorrutan, även i stridssplitten.
	view.show_combat_split()
	await await_idle_frame()
	assert_float(vignette.size.y).is_equal_approx(view.split_height(), 1.0)


func test_dust_is_sparse_and_off_with_reduced_motion() -> void:
	var view: CorridorView = _view(false)
	var dust: GPUParticles2D = view.get_node("Motes/Dust") as GPUParticles2D
	assert_int(dust.amount).is_less_equal(32)
	assert_bool(dust.emitting).is_true()
	view.set_reduced_motion(true)
	assert_bool(dust.emitting).is_false()
	assert_bool(dust.visible).is_false()


func test_the_narrator_speaks_in_caveat_brush() -> void:
	var view: CorridorView = _view(true)
	view.narrate("encounter", "room-1")
	var label: Label = view.get_node("Narrator") as Label
	assert_str(label.text).is_not_empty()
	var font: Font = label.get_theme_font("font")
	assert_object(font).is_same(Tokens.font_scrawl())
	# Samma salt, samma rad: ingen slump ur den seedade strömmen.
	var first: String = label.text
	view.narrate("encounter", "room-1")
	assert_str(label.text).is_equal(first)


func test_every_narrator_line_has_an_english_source() -> void:
	for kind: Variant in CorridorView.NARRATOR_LINES:
		for line: Variant in CorridorView.NARRATOR_LINES[kind] as Array:
			var pair: Array = line as Array
			assert_str(String(pair[0])).starts_with("NARRATOR_")
			assert_str(String(pair[1])).is_not_empty()


func test_the_encounter_is_lit_by_the_corridor() -> void:
	var view: CorridorView = _view(true)
	view.set_next_enemies(["RUST_RAT", "RUST_RAT"])
	view.restore_encounter()
	var tint: Color = view.enemy_battler(0).material().get_shader_parameter(&"light_tint")
	assert_bool(tint.is_equal_approx(Color.WHITE)).is_false()
