extends GdUnitTestSuite
## Character sheet v2 (M6 spår A steg 4): målat porträtt ur manifestet, gear
## som ikoner i raritetsram, låsta slots och CHANGE LOOK. Gränssnittet mot dev B
## är [code]Hero.equipped(slot)[/code], [code]Item.icon_id[/code] och
## [code]Item.rarity[/code]; utan hjälte läses relikerna som i M5.

const SHEET_SCENE: String = "res://src/game/sheet/character_sheet.tscn"

var _variant_before: String = ""


func before_test() -> void:
	_variant_before = Settings.smith_variant


func after_test() -> void:
	Settings.set_value(&"smith_variant", _variant_before)


func _sheet(ctx: Dictionary) -> CharacterSheet:
	var scene: PackedScene = load(SHEET_SCENE) as PackedScene
	var sheet: CharacterSheet = auto_free(scene.instantiate()) as CharacterSheet
	add_child(sheet)
	sheet.size = Vector2(1080.0, 1920.0)
	var base: Dictionary = {"state": Content.smith_state(), "meta": Meta.fresh(),
		"in_town": true, "room": 2, "seed": 7}
	base.merge(ctx, true)
	sheet.open_for(base)
	return sheet


func _hero(level: int = 5) -> Hero:
	var hero: Hero = Hero.new("H1", "Brannik")
	hero.level = level
	return hero


func test_the_figure_is_the_painted_portrait_from_the_manifest() -> void:
	Settings.set_value(&"smith_variant", "a")
	var sheet: CharacterSheet = _sheet({})
	var portrait: TextureRect = sheet.find_child("Portrait", true, false) as TextureRect
	assert_object(portrait.texture).is_same(Art.tex(&"hero.portrait.a"))
	assert_object(sheet.find_child("Paperdoll", true, false)).is_null()


func test_equipped_gear_is_its_icon_in_its_rarity_frame() -> void:
	var hero: Hero = _hero()
	var item: Item = Item.new("CHIPPED_HAMMER", "WEAPON", Rules.Rarity.RARE)
	item.icon_id = "CHIPPED_HAMMER"
	item.display_name = "Chipped Hammer"
	hero.equip(item)
	var sheet: CharacterSheet = _sheet({"hero": hero})
	var view: Dictionary = sheet.slot_view("WEAPON")
	assert_str(String(view["kind"])).is_equal("gear")
	var button: Button = sheet.slot_button("WEAPON")
	var icon: TextureRect = button.get_node("Box/Icon") as TextureRect
	assert_object(icon.texture).is_same(Art.gear_icon("CHIPPED_HAMMER"))
	var frame: TextureRect = button.get_node("Box/Frame") as TextureRect
	assert_object(frame.texture).is_same(Art.rarity_frame("rare"))
	# Utan ramtextur bär plattan sällsynthetens färg – aldrig ingenting.
	if frame.texture == null:
		var plate: StyleBoxFlat = (button.get_node("Box/Plate") as Panel).get_theme_stylebox("panel") as StyleBoxFlat
		assert_bool(plate.border_color.is_equal_approx(Tokens.rarity_color(Rules.Rarity.RARE))).is_true()


func test_an_empty_slot_shows_its_own_glyph_dimmed() -> void:
	var sheet: CharacterSheet = _sheet({"hero": _hero()})
	var icon: TextureRect = sheet.slot_button("HEAD").get_node("Box/Icon") as TextureRect
	assert_object(icon.texture).is_not_null()
	assert_float(icon.modulate.a).is_less(0.5)


func test_a_locked_slot_says_which_level_unlocks_it() -> void:
	var sheet: CharacterSheet = _sheet({"hero": _hero(1)})
	var view: Dictionary = sheet.slot_view("AMULET")
	assert_bool(bool(view["locked"])).is_true()
	var caption: Label = sheet.slot_button("AMULET").get_node("Caption") as Label
	assert_str(caption.text).contains(str(Hero.level_for_slot("AMULET")))
	sheet.slot_button("AMULET").pressed.emit()
	assert_str(sheet.detail_text()).contains(str(Hero.level_for_slot("AMULET")))


func test_without_a_hero_the_relics_still_fill_their_slots() -> void:
	var state: CombatState = Content.smith_state()
	state.relics.append(Content.make_relic("DOMINO"))
	var sheet: CharacterSheet = _sheet({"state": state})
	var view: Dictionary = sheet.slot_view(Content.SLOT_WEAPON)
	assert_str(String(view["kind"])).is_equal("relic")
	var icon: TextureRect = sheet.slot_button(Content.SLOT_WEAPON).get_node("Box/Icon") as TextureRect
	assert_object(icon.texture).is_same(Art.relic_icon("DOMINO"))


func test_change_look_swaps_the_portrait_and_the_heroes_body() -> void:
	Settings.set_value(&"smith_variant", "a")
	var hero: Hero = _hero()
	hero.body_variant = "a"
	var sheet: CharacterSheet = _sheet({"hero": hero})
	var seen: Array[String] = []
	sheet.look_changed.connect(func(v: String) -> void: seen.append(v))
	sheet.change_look()
	var portrait: TextureRect = sheet.find_child("Portrait", true, false) as TextureRect
	assert_object(portrait.texture).is_same(Art.tex(&"hero.portrait.b"))
	assert_str(hero.body_variant).is_equal("b")
	assert_array(seen).contains_exactly(["b"])


func test_change_look_is_town_only() -> void:
	Settings.set_value(&"smith_variant", "a")
	var sheet: CharacterSheet = _sheet({"in_town": false})
	sheet.change_look()
	assert_str(Settings.smith_variant).is_equal("a")


func test_the_dice_row_is_still_there() -> void:
	var sheet: CharacterSheet = _sheet({})
	var dice: HBoxContainer = sheet.get_node("Margin/Column/Footer/Dice")
	assert_int(dice.get_child_count()).is_equal(Content.smith_state().dice.size())
