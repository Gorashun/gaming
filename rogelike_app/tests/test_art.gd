extends GdUnitTestSuite
## Spriteregistret mot assets. [Art] är enda stället i [code]src/game/[/code] som
## känner ett filnamn; det här testet är kontraktet mellan den filen och
## [code]assets/sprites/[/code].
##
## Varför ett test och inte "det syns ju i spelet": ett felaktigt rutnät ger
## [b]inte[/b] ett fel, det ger en halv fiende eller en tom ruta. PAPERDOLL.md §1
## säger uttryckligen "bryts kontraktet ska importen fallera, inte se konstig ut".
## Det här är den fallerandet.
##
## Testet påstår ingenting om hur sprites ser ut – bara att de finns, har rätt
## rutnät och att varje innehålls-id i [Content] har en bild.

# --- Fiender ---------------------------------------------------------------

func test_every_enemy_sheet_matches_its_declared_grid() -> void:
	for enemy_id: String in Art.ENEMIES:
		var entry: Dictionary = Art.ENEMIES[enemy_id]
		var sheet: Texture2D = Art.texture(String(entry["file"]))
		assert_object(sheet).override_failure_message(
			"fiendearket %s saknas" % String(entry["file"])).is_not_null()
		var cell: int = int(entry["cell"])
		var frames: int = int(entry["frames"])
		assert_int(sheet.get_width()).override_failure_message(
			"%s: bredden %d är inte %d frames × %d px" % [enemy_id, sheet.get_width(), frames, cell]
		).is_equal(cell * frames)
		assert_int(sheet.get_height()).override_failure_message(
			"%s: höjden %d är inte cellstorleken %d" % [enemy_id, sheet.get_height(), cell]
		).is_equal(cell)


func test_the_boss_is_a_48_px_cell_and_the_rest_are_32() -> void:
	assert_int(Art.enemy_cell("SLAGJAW")).is_equal(48)
	for enemy_id: String in Art.ENEMIES:
		if enemy_id == "SLAGJAW":
			continue
		assert_int(Art.enemy_cell(enemy_id)).override_failure_message(
			"%s ska vara 32×32" % enemy_id).is_equal(32)


func test_every_enemy_on_floor_one_has_a_sprite() -> void:
	var missing: PackedStringArray = PackedStringArray()
	for room: int in range(1, Content.rooms_per_floor() + 1):
		for variant: int in [0, 1]:
			for enemy: Enemy in Content.encounter(room, variant):
				if not Art.ENEMIES.has(enemy.id):
					missing.append("rum %d: %s" % [room, enemy.id])
	assert_array(Array(missing)).override_failure_message(
		"fiender utan sprite: %s" % ", ".join(missing)).is_empty()


func test_enemy_frames_slice_the_sheet_into_an_idle_loop() -> void:
	var frames: SpriteFrames = Art.enemy_frames("RUST_RAT")
	assert_object(frames).is_not_null()
	assert_int(frames.get_frame_count(&"default")).is_equal(4)
	assert_bool(frames.get_animation_loop(&"default")).is_true()
	var first: Texture2D = frames.get_frame_texture(&"default", 0)
	assert_int(first.get_width()).is_equal(32)
	assert_int(first.get_height()).is_equal(32)


func test_enemy_frames_are_cached_per_id() -> void:
	# Rum 1 är fyra Rostråttor. Skär vi atlasen fyra gånger betalar vi den
	# kostnaden i varje rumsbyte, för ingenting.
	assert_object(Art.enemy_frames("RUST_RAT")).is_same(Art.enemy_frames("RUST_RAT"))


# --- Paperdoll -------------------------------------------------------------

func test_every_hero_layer_sheet_is_384x192() -> void:
	# PAPERDOLL.md §1: 48×48-cell, hframes 8, vframes 4. Bryts det desynkar
	# lagren mot varandra mitt i en gångcykel.
	for layer_name: StringName in Art.HERO_LAYERS:
		var sheet: Texture2D = Art.texture(String(Art.HERO_LAYERS[layer_name]))
		assert_object(sheet).override_failure_message(
			"lagerarket för %s saknas" % layer_name).is_not_null()
		assert_int(sheet.get_width()).override_failure_message(
			"%s: bredden är %d, inte 8 × 48" % [layer_name, sheet.get_width()]
		).is_equal(HeroFigure.CELL_SIZE * HeroFigure.HFRAMES)
		assert_int(sheet.get_height()).override_failure_message(
			"%s: höjden är %d, inte 4 × 48" % [layer_name, sheet.get_height()]
		).is_equal(HeroFigure.CELL_SIZE * HeroFigure.VFRAMES)


func test_the_alternate_weapon_shares_the_paperdoll_grid() -> void:
	var tongs: Texture2D = Art.texture(Art.HERO_WEAPON_TONGS)
	assert_object(tongs).is_not_null()
	assert_int(tongs.get_width()).is_equal(HeroFigure.CELL_SIZE * HeroFigure.HFRAMES)
	assert_int(tongs.get_height()).is_equal(HeroFigure.CELL_SIZE * HeroFigure.VFRAMES)


func test_every_layer_the_art_registry_names_exists_on_the_figure() -> void:
	var known: Array[StringName] = HeroFigure.LAYERS
	for layer_name: StringName in Art.HERO_LAYERS:
		assert_bool(known.has(layer_name)).override_failure_message(
			"HeroFigure saknar lagret %s" % layer_name).is_true()
	for relic_id: String in Art.RELIC_LAYERS:
		for layer_name: Variant in Art.RELIC_LAYERS[relic_id] as Array:
			assert_bool(known.has(StringName(layer_name))).override_failure_message(
				"reliken %s pekar på lagret %s som inte finns" % [relic_id, layer_name]
			).is_true()


func test_every_relic_in_the_pool_has_a_paperdoll_layer_and_an_icon() -> void:
	for relic_id: String in Content.RELICS:
		assert_bool(Art.RELIC_LAYERS.has(relic_id)).override_failure_message(
			"reliken %s saknar rad i relik→lager-tabellen (PAPERDOLL §3)" % relic_id
		).is_true()
		assert_object(Art.relic_icon(relic_id)).override_failure_message(
			"reliken %s saknar ikon" % relic_id).is_not_null()


# --- Tärningar -------------------------------------------------------------

func test_every_die_material_has_a_body_and_a_lut() -> void:
	for die_material: int in [Rules.DieMaterial.IRON, Rules.DieMaterial.BONE, Rules.DieMaterial.GLASS]:
		var body: Texture2D = Art.die_body(die_material)
		assert_object(body).override_failure_message(
			"materialet %d saknar kropp" % die_material).is_not_null()
		assert_int(body.get_width()).is_equal(DieArt.CELL)
		assert_int(body.get_height()).is_equal(DieArt.CELL)
		assert_object(Art.die_lut(die_material)).override_failure_message(
			"materialet %d saknar LUT" % die_material).is_not_null()


func test_every_forgeable_face_resolves_to_an_overlay() -> void:
	for face_id: String in Content.FORGEABLE_FACES:
		var face: Face = Content.make_face(face_id)
		var overlay: Dictionary = Art.face_overlay(face)
		assert_object(overlay["texture"]).override_failure_message(
			"sidan %s saknar glyph/pips" % face_id).is_not_null()


func test_pip_faces_carry_their_own_colour_and_glyphs_do_not() -> void:
	# Pip-arken är redan tintade i bone/pip; ett modulate ovanpå skulle
	# kvadrera färgen och göra ögonen svarta. Glypherna är vita och SKA tintas.
	var pips: Dictionary = Art.face_overlay(Face.new("PIP_5", 5))
	assert_str(String(pips["color_token"])).is_equal("NONE")
	assert_bool(bool(pips["is_pips"])).is_true()

	var ember: Dictionary = Art.face_overlay(Content.make_face("EMBER"))
	assert_str(String(ember["color_token"])).is_equal("SEM_FIRE")
	assert_bool(bool(ember["is_pips"])).is_false()


func test_every_pip_value_zero_to_six_has_an_overlay() -> void:
	for value: int in range(0, 7):
		var overlay: Dictionary = Art.face_overlay(Face.new("PIP_%d" % value, value))
		assert_object(overlay["texture"]).override_failure_message(
			"pips_%d saknas" % value).is_not_null()


func test_all_three_crack_variants_exist_and_wrap() -> void:
	for variant_seed: int in range(0, 6):
		assert_object(Art.crack(variant_seed)).override_failure_message(
			"sprickvariant för seed %d saknas" % variant_seed).is_not_null()
	# posmod: ett negativt hash-värde får aldrig ge crack_0 eller crack_-1.
	assert_object(Art.crack(-7)).is_not_null()


# --- Slots, noder och miljö ------------------------------------------------

func test_every_slot_type_has_an_icon() -> void:
	for slot_type: int in [Rules.SlotType.PLAIN, Rules.SlotType.FIRE, Rules.SlotType.MIRROR,
			Rules.SlotType.ANVIL, Rules.SlotType.CHARGE, Rules.SlotType.VOID]:
		assert_object(Art.slot_icon(slot_type)).override_failure_message(
			"sloten %s saknar ikon" % Rules.slot_type_name(slot_type)).is_not_null()


func test_the_node_kinds_the_march_can_show_have_icons() -> void:
	for kind: String in ["combat", "boss", "elite", "forge", "rest", "mystery"]:
		assert_object(Art.node_icon(kind)).override_failure_message(
			"nodikonen %s saknas" % kind).is_not_null()


func test_the_parallax_strip_matches_ui_guide_speeds() -> void:
	# UI_GUIDE §10.2 är normativ: 0,15 · 0,45 · 1,20.
	var speeds: Array[float] = []
	for spec: Dictionary in Art.PARALLAX:
		var texture: Texture2D = Art.texture(String(spec["file"]))
		assert_object(texture).override_failure_message(
			"parallaxlagret %s saknas" % String(spec["file"])).is_not_null()
		assert_int(texture.get_width()).override_failure_message(
			"%s måste vara 320 px brett för att kakla" % String(spec["file"])).is_equal(320)
		assert_int(texture.get_height()).is_equal(int(spec["height"]))
		speeds.append(float(spec["speed"]))
	assert_array(speeds).is_equal([0.15, 0.45, 1.2])


func test_the_floor_tile_is_a_square_32_px_tile() -> void:
	var tile: Texture2D = Art.texture(Art.FLOOR_TILE)
	assert_object(tile).is_not_null()
	assert_int(tile.get_width()).is_equal(32)
	assert_int(tile.get_height()).is_equal(32)


# --- Heltalsmatematiken ----------------------------------------------------

func test_fit_scale_never_returns_zero_or_a_fraction() -> void:
	assert_int(Art.fit_scale(Vector2(160, 160), 32)).is_equal(5)
	assert_int(Art.fit_scale(Vector2(100, 160), 32)).is_equal(3)
	# Mindre ruta än en cell: hellre för stor tärning än ingen tärning.
	assert_int(Art.fit_scale(Vector2(10, 10), 32)).is_equal(1)
	assert_int(Art.fit_scale(Vector2(1000, 1000), 32)).is_equal(8)


func test_snap_quantises_against_the_art_grid() -> void:
	assert_vector(Art.snap(Vector2(13.7, 27.2), 4)).is_equal(Vector2(12.0, 24.0))
	assert_vector(Art.snap(Vector2(13.7, 27.2), 1)).is_equal(Vector2(13.0, 27.0))
