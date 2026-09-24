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
		var rows: int = int(entry.get("rows", 1))
		assert_int(sheet.get_height()).override_failure_message(
			"%s: höjden %d är inte %d rader × %d px" % [enemy_id, sheet.get_height(), rows, cell]
		).is_equal(cell * rows)


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


func test_every_enemy_has_a_death_animation_that_does_not_loop() -> void:
	# M2: rad 1 i arket. Korridorens billboard spelar den automatiskt,
	# så en fiende utan rad 1 skulle tyst falla tillbaka på M1:s uttoning.
	for enemy_id: String in Art.ENEMIES:
		var frames: SpriteFrames = Art.enemy_frames(enemy_id)
		assert_bool(frames.has_animation(&"death")).override_failure_message(
			"%s saknar dödsanimation" % enemy_id).is_true()
		assert_int(frames.get_frame_count(&"death")).override_failure_message(
			"%s har fel antal dödsframes" % enemy_id).is_equal(3)
		assert_bool(frames.get_animation_loop(&"death")).override_failure_message(
			"%s loopar sin död" % enemy_id).is_false()
		# Döden måste rymmas i enemy_killed-budgeten (UI_GUIDE §5.5: 360 ms).
		var length_ms: float = 3.0 / frames.get_animation_speed(&"death") * 1000.0
		assert_float(length_ms).override_failure_message(
			"%s dör på %.0f ms, budgeten är 360" % [enemy_id, length_ms]).is_less_equal(360.0)


func test_the_death_row_is_cut_from_the_second_row_of_the_sheet() -> void:
	var frames: SpriteFrames = Art.enemy_frames("SLAGJAW")
	var slice: AtlasTexture = frames.get_frame_texture(&"death", 0) as AtlasTexture
	assert_object(slice).is_not_null()
	assert_float(slice.region.position.y).is_equal(48.0)


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


## M2.5: kroppen och håret finns i två varianter (DECISIONS 2026-09-21).
## Båda måste ligga på samma 48×48-rutnät som garderoben, annars sitter en
## hjälm på fel höjd så fort spelaren byter kropp.
func test_both_smith_variants_share_the_paperdoll_grid() -> void:
	for variant: String in Art.SMITH_VARIANTS:
		for layer_name: StringName in Art.SMITH_BODY_LAYERS:
			var sheet: Texture2D = Art.smith_layer(layer_name, variant)
			assert_object(sheet).override_failure_message(
				"hero/smith_%s_%s.png saknas" % [layer_name, variant]).is_not_null()
			assert_int(sheet.get_width()).override_failure_message(
				"smith_%s_%s: bredden är %d, inte 8 × 48" % [layer_name, variant, sheet.get_width()]
			).is_equal(HeroFigure.CELL_SIZE * HeroFigure.HFRAMES)
			assert_int(sheet.get_height()).override_failure_message(
				"smith_%s_%s: höjden är %d, inte 4 × 48" % [layer_name, variant, sheet.get_height()]
			).is_equal(HeroFigure.CELL_SIZE * HeroFigure.VFRAMES)


func test_an_unknown_variant_falls_back_instead_of_crashing() -> void:
	assert_str(Art.smith_variant("zz")).is_equal(Art.SMITH_VARIANT_DEFAULT)
	assert_str(Art.smith_variant("")).is_equal(Art.SMITH_VARIANT_DEFAULT)
	assert_object(Art.smith_layer(&"body", "zz")).is_not_null()


## Briefen: saknas en ikon ska det bli platshållare + varning, aldrig en krasch.
func test_every_ui_icon_resolves_or_has_a_glyph() -> void:
	for icon_name: StringName in Art.UI_ICONS:
		var texture: Texture2D = Art.ui_icon(icon_name)
		if texture == null:
			assert_str(Art.ui_icon_glyph(icon_name)).override_failure_message(
				"ikonen %s saknar både PNG och reservglyf" % icon_name).is_not_empty()
			continue
		# M7: ikonen är 256 px krita ur manifestet, inte en 16×16-sprite.
		var info: Dictionary = Art.art_info(StringName(Art.UI_ICON_PREFIX + String(icon_name)))
		assert_str(String(info["source"])).override_failure_message(
			"%s ritas ur %s, inte ur manifestet" % [icon_name, info["source"]]).is_equal(Art.SOURCE_MANIFEST)
		assert_int(texture.get_width()).override_failure_message(
			"%s: 256 px förväntas, fick %d px" % [icon_name, texture.get_width()]).is_equal(256)


## Tutorialvåningens fiender lånar ark från våning 1. Varje alias måste peka på
## ett ark som faktiskt finns, annars blir rum 0.1 ett tomt golv.
func test_every_tutorial_enemy_has_a_sprite_sheet() -> void:
	for index: int in range(Tutorial.room_count()):
		for enemy: Enemy in Tutorial.enemies_for(index):
			var art_id: String = Art.enemy_art_id(enemy.id)
			assert_bool(Art.ENEMIES.has(art_id)).override_failure_message(
				"rum %d: %s saknar ark (alias → %s)" % [index, enemy.id, art_id]).is_true()
			assert_object(Art.enemy_frames(enemy.id)).override_failure_message(
				"rum %d: %s gav inga frames" % [index, enemy.id]).is_not_null()


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
		# M2: lagren är ritade. Minst ETT av relikens lager måste finnas som
		# ark, annars syns reliken bara i brickan (M1.5-snittet).
		var drawn: bool = false
		for layer_name: Variant in Art.RELIC_LAYERS[relic_id] as Array:
			if Art.has("hero/smith_%s_%s.png" % [String(layer_name), relic_id.to_lower()]):
				drawn = true
		assert_bool(drawn).override_failure_message(
			"reliken %s har ingen ritad paperdoll-sprite" % relic_id).is_true()


# --- Tärningar -------------------------------------------------------------

func test_every_die_material_has_a_five_step_palette() -> void:
	# M7: tärningen ritas i kod; materialets färgspråk är LUT:arnas fem steg.
	for die_material: int in [Rules.DieMaterial.IRON, Rules.DieMaterial.BONE, Rules.DieMaterial.GLASS]:
		var colors: Array[Color] = DieArt.palette(die_material)
		assert_int(colors.size()).is_equal(5)
		# Mörkt → ljust, annars blir kanten ljusare än ovansidan.
		assert_float(colors[0].get_luminance()).is_less(colors[4].get_luminance())


func test_every_forgeable_face_resolves_to_a_glyph_or_drawn_pips() -> void:
	for face_id: String in Content.FORGEABLE_FACES:
		var face: Face = Content.make_face(face_id)
		var overlay: Dictionary = Art.face_overlay(face)
		var drawable: bool = overlay["texture"] != null or (bool(overlay["is_pips"]) and int(overlay["pips"]) >= 0)
		assert_bool(drawable).override_failure_message(
			"sidan %s saknar glyph/pips" % face_id).is_true()


func test_pips_are_drawn_and_glyphs_are_tinted_chalk() -> void:
	var pips: Dictionary = Art.face_overlay(Face.new("PIP_5", 5))
	assert_bool(bool(pips["is_pips"])).is_true()
	assert_int(int(pips["pips"])).is_equal(5)
	assert_object(pips["texture"]).is_null()

	var ember: Dictionary = Art.face_overlay(Content.make_face("EMBER"))
	assert_str(String(ember["color_token"])).is_equal("SEM_FIRE")
	assert_bool(bool(ember["is_pips"])).is_false()
	assert_object(ember["texture"]).is_same(Art.tex(&"ui.face.eld"))


func test_every_pip_value_zero_to_six_has_a_layout() -> void:
	var top: Rect2 = Rect2(0.0, 0.0, 100.0, 100.0)
	for value: int in range(1, 7):
		assert_int(DieArt.pip_centers(value, top).size()).is_equal(value)
	# 0 är den spruckna sidan: en ring, inga ögon.
	assert_int(int(Art.face_overlay(Face.new("PIP_0", 0))["pips"])).is_equal(0)
	assert_int(DieArt.pip_centers(0, top).size()).is_equal(0)


func test_the_crack_is_seeded_per_die_and_never_touches_the_rng() -> void:
	var a: Array[PackedVector2Array] = DieArt.crack_paths(12345)
	var b: Array[PackedVector2Array] = DieArt.crack_paths(12345)
	assert_int(a.size()).is_greater_equal(2)
	assert_bool(a[0] == b[0]).is_true()
	assert_bool(DieArt.crack_paths(-7)[0] != a[0]).is_true()


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


# --- Heltalsmatematiken (bara den gamla pixelpaperdollen, HeroFigure) ------

func test_snap_quantises_against_the_art_grid() -> void:
	assert_vector(Art.snap(Vector2(13.7, 27.2), 4)).is_equal(Vector2(12.0, 24.0))
	assert_vector(Art.snap(Vector2(13.7, 27.2), 1)).is_equal(Vector2(13.0, 27.0))
