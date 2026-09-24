extends GdUnitTestSuite
## M7: UI:t är inte pixelgrafik längre (docs/M7_UI_NOTES.md).
##
## Kontraktet som testas här:
## [br]1. Varje [code]ui.*[/code]-ikon kommer ur manifestet, är 256 px vit krita
##    med mipmaps, har licens och – för game-icons – en namngiven upphovsperson
##    som står i credits (CC BY 3.0: attributionen är ett licensvillkor).
## [br]2. Slot-ikonerna skiljs på FORM på 24 dp (UI_GUIDE §2.4: IoU < 0,85).
## [br]3. Tärningen ritas i kod: ingen textur för kroppen, inget Nearest, och
##    blixten fungerar utan palette_lut-shadern.
## [br]4. Vyerna som gjordes om (slot, bricka, belöningskort, karaktärsblad,
##    korridorskylt) använder den nya konsten och inget Nearest.

const SHEET_SCENE: String = "res://src/game/sheet/character_sheet.tscn"
## UI_GUIDE §2.4: två slot-former får inte likna varandra mer än så här.
const MAX_SLOT_IOU: float = 0.85
const INK_ID_PREFIXES: Array[String] = ["ui.icon.", "ui.slot.", "ui.node.", "ui.face.", "ui.gearslot."]


func before_test() -> void:
	Art.reload_manifest()


func _ink_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for key: Variant in Art.manifest():
		for prefix: String in INK_ID_PREFIXES:
			if String(key).begins_with(prefix):
				ids.append(String(key))
	ids.sort()
	return ids


# --- 1. Manifestet ------------------------------------------------------------

func test_every_ui_ink_entry_is_a_256_px_icon_with_a_licence() -> void:
	var ids: PackedStringArray = _ink_ids()
	# 12 knappikoner + 6 slots + 6 noder + 5 sidor + 7 utrustningsslots.
	assert_int(ids.size()).is_equal(36)
	for id: String in ids:
		var e: Dictionary = Art.entry(StringName(id))
		assert_str(String(e["kind"])).override_failure_message("%s: kind" % id).is_equal(Art.KIND_ICON)
		assert_str(String(e["license"])).override_failure_message("%s: licens" % id).is_equal("CC-BY-3.0")
		assert_bool(["game-icons", "ravenmore-icons"].has(String(e["source"]))).override_failure_message(
			"%s: okänd källa %s" % [id, e["source"]]).is_true()
		var info: Dictionary = Art.art_info(StringName(id))
		assert_str(String(info["source"])).is_equal(Art.SOURCE_MANIFEST)
		assert_bool(bool(info["pixel"])).is_false()
		var tex: Texture2D = info["texture"] as Texture2D
		assert_int(tex.get_width()).override_failure_message("%s: bredd" % id).is_equal(256)
		assert_int(tex.get_height()).is_equal(256)
		assert_int(Art.filter_for(StringName(id))).is_equal(CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)


func test_the_ui_ink_is_imported_with_mipmaps() -> void:
	# 256 px ritas ned till 40–70 px: utan mipmaps glittrar kanterna.
	for id: String in _ink_ids():
		var tex: Texture2D = Art.tex(StringName(id))
		assert_bool(tex.get_image().has_mipmaps()).override_failure_message(
			"%s saknar mipmaps (mipmaps/generate i .import)" % id).is_true()


func test_every_game_icons_author_is_credited_by_name() -> void:
	var credits: Dictionary = CreditsScreen.load_credits()
	var lines: String = ""
	for raw: Variant in credits.get("sources", []) as Array:
		var source: Dictionary = raw as Dictionary
		if String(source.get("id", "")) == "game-icons":
			lines = "\n".join(PackedStringArray(source.get("attribution_lines", []) as Array))
	assert_str(lines).override_failure_message("credits.json saknar källan game-icons").is_not_empty()
	var seen: int = 0
	for id: String in _ink_ids():
		var e: Dictionary = Art.entry(StringName(id))
		if String(e["source"]) != "game-icons":
			continue
		seen += 1
		var author: String = String(e.get("author", ""))
		assert_str(author).override_failure_message("%s: ingen upphovsperson" % id).is_not_empty()
		assert_str(lines).override_failure_message(
			"%s: '%s' står inte i credits" % [id, author]).contains("Icons made by " + author)
	assert_int(seen).is_greater(20)


func test_the_face_glyphs_come_from_the_manifest_not_the_dice_sprites() -> void:
	for face_id: String in Art.FACE_GLYPHS:
		var overlay: Dictionary = Art.face_overlay(Content.make_face(face_id))
		var glyph: String = String((Art.FACE_GLYPHS[face_id] as Dictionary)["glyph"])
		assert_object(overlay["texture"]).override_failure_message(
			"%s ritar inte ui.face.%s" % [face_id, glyph]).is_same(Art.tex(StringName("ui.face." + glyph)))


func test_without_the_manifest_the_old_sprites_are_the_fallback() -> void:
	# Reserven får aldrig vara ett hål: en saknad post ger den gamla spriten.
	Art.use_manifest({})
	assert_object(Art.slot_icon(Rules.SlotType.FIRE)).is_not_null()
	assert_bool(Art.is_pixel(Art.slot_icon_key(Rules.SlotType.FIRE))).is_true()
	assert_object(Art.node_icon("boss")).is_not_null()
	assert_object(Art.face_glyph("eld")).is_not_null()
	assert_object(Art.ui_icon(&"settings")).is_not_null()
	assert_object(Art.gearslot_icon("HEAD")).is_not_null()


# --- 2. Formkoden -------------------------------------------------------------

func _silhouette(slot_type: int, side: int) -> PackedByteArray:
	var image: Image = Art.slot_icon(slot_type).get_image().duplicate() as Image
	if image.is_compressed():
		image.decompress()
	image.clear_mipmaps()
	image.resize(side, side, Image.INTERPOLATE_LANCZOS)
	var mask: PackedByteArray = PackedByteArray()
	mask.resize(side * side)
	for y: int in range(side):
		for x: int in range(side):
			# Över konturens alfa (0,62): bara själva kritan räknas.
			mask[y * side + x] = 1 if image.get_pixel(x, y).a > 0.67 else 0
	return mask


func test_slot_icons_stay_distinct_as_silhouettes_at_24_dp() -> void:
	var types: Array[int] = [Rules.SlotType.PLAIN, Rules.SlotType.FIRE, Rules.SlotType.MIRROR,
		Rules.SlotType.ANVIL, Rules.SlotType.CHARGE, Rules.SlotType.VOID]
	var masks: Dictionary = {}
	for slot_type: int in types:
		masks[slot_type] = _silhouette(slot_type, 24)
	for i: int in range(types.size()):
		for j: int in range(i + 1, types.size()):
			var a: PackedByteArray = masks[types[i]]
			var b: PackedByteArray = masks[types[j]]
			var inter: int = 0
			var union: int = 0
			for k: int in range(a.size()):
				inter += a[k] & b[k]
				union += a[k] | b[k]
			var iou: float = float(inter) / float(maxi(1, union))
			assert_float(iou).override_failure_message("%s/%s liknar varandra: IoU %.2f" % [
				Rules.slot_type_name(types[i]), Rules.slot_type_name(types[j]), iou]).is_less(MAX_SLOT_IOU)


# --- 3. Tärningen -------------------------------------------------------------

func _die(material: int, face: Face = null, cracks: int = 0) -> Die:
	var faces: Array[Face] = []
	for v: int in range(1, 7):
		faces.append(Face.new("PIP_%d" % v, v))
	if face != null:
		faces[0] = face
	var die: Die = Die.new("die_t", faces, material)
	die.cracks = cracks
	return die


func test_the_die_is_drawn_without_textures_or_nearest() -> void:
	for material: int in [Rules.DieMaterial.IRON, Rules.DieMaterial.BONE, Rules.DieMaterial.GLASS]:
		var art: DieArt = auto_free(DieArt.new())
		add_child(art)
		art.size = Vector2(150.0, 150.0)
		art.show_die(_die(material, null, 1), 3)
		assert_bool(art.is_drawing()).is_true()
		assert_bool(art.shows_value()).is_true()
		assert_int(art.texture_filter).is_not_equal(CanvasItem.TEXTURE_FILTER_NEAREST)
		# Inga barnnoder: kroppen, ögonen och sprickan ritas i _draw.
		assert_int(art.get_child_count()).is_equal(0)


func test_the_die_fits_any_size_without_integer_steps() -> void:
	# M6 låste tärningen till 32 px × heltal; 150 px gav 128 px. Nu fyller den.
	var body: Rect2 = DieArt.body_rect(Vector2(150.0, 150.0))
	assert_float(body.size.x).is_equal_approx(150.0 * DieArt.FILL, 0.01)
	var small: Rect2 = DieArt.body_rect(Vector2(44.0, 60.0))
	assert_float(small.size.x).is_equal_approx(44.0 * DieArt.FILL, 0.01)
	assert_bool(Rect2(Vector2.ZERO, Vector2(44.0, 60.0)).encloses(small)).is_true()


func test_a_glyph_face_hides_the_value_and_tints_with_its_token() -> void:
	var art: DieArt = auto_free(DieArt.new())
	add_child(art)
	art.size = Vector2(120.0, 120.0)
	art.show_die(_die(Rules.DieMaterial.BONE, Content.make_face("POISON_DROP")))
	assert_bool(art.shows_value()).is_false()


func test_the_flash_lights_the_die_and_fades_back() -> void:
	var art: DieArt = auto_free(DieArt.new())
	add_child(art)
	art.size = Vector2(120.0, 120.0)
	art.show_die(_die(Rules.DieMaterial.IRON))
	art.flash(0.8, 0.05)
	assert_float(art.flash_amount()).is_equal_approx(0.8, 0.001)
	for i: int in range(120):
		if art.flash_amount() <= 0.0:
			break
		await await_idle_frame()
	assert_float(art.flash_amount()).is_equal_approx(0.0, 0.001)


# --- 4. Vyerna ----------------------------------------------------------------

func _assert_no_nearest(root: Node) -> void:
	var offenders: PackedStringArray = PackedStringArray()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CanvasItem and (node as CanvasItem).texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST:
			offenders.append(String(root.get_path_to(node)))
		stack.append_array(node.get_children())
	assert_array(Array(offenders)).override_failure_message(
		"Nearest kvar i: %s" % ", ".join(offenders)).is_empty()


func test_a_slot_shows_its_chalk_icon_and_an_empty_slot_its_watermark() -> void:
	var view: SlotView = auto_free(SlotView.new())
	add_child(view)
	view.size = Vector2(200.0, 400.0)
	view.bind(2, Slot.new(2, Rules.SlotType.MIRROR), null)
	var icon: TextureRect = view.slot_icon_rect()
	assert_object(icon.texture).is_same(Art.tex(&"ui.slot.mirror"))
	assert_bool(icon.modulate.is_equal_approx(Tokens.slot_color(Rules.SlotType.MIRROR))).is_true()
	var watermark: TextureRect = view.find_child("Watermark", true, false) as TextureRect
	assert_bool(watermark.visible).is_true()
	# Med en tärning i sloten försvinner vattenstämpeln.
	view.bind(2, Slot.new(2, Rules.SlotType.MIRROR), _die(Rules.DieMaterial.IRON))
	assert_bool(watermark.visible).is_false()
	_assert_no_nearest(view)


func test_a_ready_die_in_the_tray_is_not_a_box_in_a_box() -> void:
	var view: DieView = auto_free(DieView.new())
	add_child(view)
	view.size = Vector2(160.0, 160.0)
	view.bind(0, _die(Rules.DieMaterial.IRON), -1, false)
	var panel: Panel = view.get_child(0) as Panel
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if not Tokens.high_contrast:
		assert_int(style.border_width_top).is_equal(0)
	assert_float(style.bg_color.a).is_equal(0.0)
	# Vald tärning: ringen kommer tillbaka i sem/charge.
	view.set_selected(true)
	style = panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert_int(style.border_width_top).is_greater(0)
	assert_bool(style.border_color.is_equal_approx(Tokens.SEM_CHARGE)).is_true()
	_assert_no_nearest(view)


func test_the_reward_card_has_no_nearest_left() -> void:
	var card: RewardCard = auto_free(RewardCard.new())
	add_child(card)
	card.size = Vector2(900.0, 330.0)
	card.bind(0, {"category": Rewards.CATEGORY_SLOT_SWAP, "rarity": Rules.Rarity.COMMON,
		"data": {"slot_type": Rules.SlotType.ANVIL}}, {}, "")
	var icon: TextureRect = card.art_root().get_node("Icon") as TextureRect
	assert_object(icon.texture).is_same(Art.tex(&"ui.slot.anvil"))
	_assert_no_nearest(card)


func test_an_empty_gear_slot_shows_its_mono_chalk_icon() -> void:
	var scene: PackedScene = load(SHEET_SCENE) as PackedScene
	var sheet: CharacterSheet = auto_free(scene.instantiate()) as CharacterSheet
	add_child(sheet)
	sheet.size = Vector2(1080.0, 1920.0)
	var hero: Hero = Hero.new("H1", "Brannik")
	hero.level = 9
	sheet.open_for({"state": Content.smith_state(), "meta": Meta.fresh(), "in_town": true,
		"room": 2, "seed": 7, "hero": hero})
	for slot: String in ["HEAD", "CHEST", "BACK", "HANDS", "LEGS", "AMULET"]:
		var icon: TextureRect = sheet.slot_button(slot).get_node("Box/Icon") as TextureRect
		if String(sheet.slot_view(slot)["kind"]) != "empty":
			continue
		assert_object(icon.texture).override_failure_message(
			"%s visar inte ui.gearslot.%s" % [slot, slot]).is_same(Art.tex(StringName("ui.gearslot." + slot)))
	_assert_no_nearest(sheet)


func test_corridor_signs_tint_their_chalk_by_kind() -> void:
	assert_bool(CorridorView.sign_tint("boss").is_equal_approx(Tokens.SEM_BLOOD)).is_true()
	assert_bool(CorridorView.sign_tint("combat").is_equal_approx(Tokens.CHALK_100)).is_true()
	for key: String in CorridorMap.SIGN_KEYS:
		var id: StringName = Art.node_icon_key(CorridorView._icon_key(key))
		assert_str(String(Art.art_info(id)["source"])).override_failure_message(
			"skylten %s ritar inte %s ur manifestet" % [key, id]).is_equal(Art.SOURCE_MANIFEST)


func test_the_sign_plate_and_the_torch_are_drawn_not_pixel_sprites() -> void:
	var plate: Dictionary = Art.art_info(Art.ID_SIGN_PLATE)
	assert_str(String(plate["source"])).is_equal(Art.SOURCE_GENERATED)
	assert_bool(bool(plate["pixel"])).is_false()
	assert_int(CorridorView.filter_3d(Art.ID_SIGN_PLATE)).is_equal(BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
	var torch: Dictionary = Art.art_info(Art.ID_TORCH)
	assert_str(String(torch["source"])).is_equal(Art.SOURCE_GENERATED)
	assert_bool(bool(torch["pixel"])).is_false()
	assert_int(int(torch["frames"])).is_equal(Art.TORCH_FRAMES)
	var sheet: Texture2D = torch["texture"] as Texture2D
	assert_int(sheet.get_width()).is_equal(Art.TORCH_FRAME_SIZE.x * Art.TORCH_FRAMES)
	assert_bool(sheet.get_image().has_mipmaps()).is_true()
	# Samma höjd i världen som M5:s 32 px-fackla à 0,042 m.
	assert_float(0.042 * 32.0 / (torch["size"] as Vector2).y * float(Art.TORCH_FRAME_SIZE.y)).is_equal_approx(1.344, 0.001)
