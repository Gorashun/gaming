extends GdUnitTestSuite
## Kroppsvarianterna (DECISIONS 2026-09-21).
##
## [b]Kravet:[/b] båda varianterna ska gå att instansiera med samtliga
## reliklager utan fel. Det är inte en formalitet – hela poängen med beslutet är
## att utrustningen är [i]kroppsoberoende[/i], så att två varianter kostar fyra
## PNG:er och inte två garderober. Går det sönder är det här det märks.


func _figure(variant: String) -> HeroFigure:
	var figure: HeroFigure = auto_free(HeroFigure.new())
	add_child(figure)
	figure.set_variant(variant)
	return figure


func test_both_variants_instantiate_with_every_relic_layer() -> void:
	for variant: String in Art.SMITH_VARIANTS:
		var relics: Array[Relic] = []
		for id: String in Content.RELICS:
			relics.append(Content.make_relic(id))
		relics.append(Content.make_relic("ANVIL_BLESSING"))

		var figure: HeroFigure = _figure(variant)
		figure.equip_default_gear()
		figure.apply_relics(relics)

		assert_str(figure.variant).is_equal(variant)
		assert_bool(figure.has_any_texture()).override_failure_message(
			"variant %s ritade inte ett enda lager" % variant).is_true()
		for layer_name: StringName in HeroFigure.LAYERS:
			assert_object(figure.layer_sprite(layer_name)).override_failure_message(
				"variant %s saknar noden för lagret %s" % [variant, layer_name]).is_not_null()
		# Kroppen och håret måste vara tända, annars står figuren naken bakom
		# sin utrustning.
		for layer_name: StringName in Art.SMITH_BODY_LAYERS:
			var sprite: Sprite2D = figure.layer_sprite(layer_name)
			assert_object(sprite.texture).override_failure_message(
				"variant %s: lagret %s är tomt" % [variant, layer_name]).is_not_null()


func test_switching_variant_only_changes_body_and_hair() -> void:
	var figure: HeroFigure = _figure("a")
	figure.equip_default_gear()
	var gear_before: Dictionary = {}
	for layer_name: StringName in Art.HERO_LAYERS:
		gear_before[layer_name] = figure.layer_sprite(layer_name).texture

	var body_before: Texture2D = figure.layer_sprite(&"body").texture
	figure.set_variant("b")

	for layer_name: StringName in Art.HERO_LAYERS:
		assert_object(figure.layer_sprite(layer_name).texture).override_failure_message(
			"gear-lagret %s ändrades av ett kroppsbyte" % layer_name
		).is_same(gear_before[layer_name])
	assert_object(figure.layer_sprite(&"body").texture).override_failure_message(
		"kroppen byttes inte").is_not_same(body_before)


## Lagerordningen är barnordningen, och håret måste ligga UNDER gear (briefen:
## "under alla gear-lager") men ÖVER kroppen.
func test_hair_sits_between_the_body_and_the_gear() -> void:
	var body: int = HeroFigure.LAYERS.find(&"body")
	var hair: int = HeroFigure.LAYERS.find(&"hair")
	assert_int(hair).override_failure_message("hår-lagret saknas").is_greater(-1)
	assert_int(hair).is_greater(body)
	for layer_name: StringName in [&"torso", &"head", &"helm", &"offhand", &"weapon", &"fx"]:
		assert_int(HeroFigure.LAYERS.find(layer_name)).override_failure_message(
			"%s måste ligga ovanpå håret" % layer_name).is_greater(hair)


func test_the_portrait_frame_builds_for_both_variants() -> void:
	# Porträttet återanvänds i character sheetet; saknas PNG:n ska det bli en
	# platshållare, aldrig en krasch (briefen).
	for variant: String in Art.SMITH_VARIANTS:
		var frame: PanelContainer = auto_free(ChooseSmithScreen.portrait_frame(variant))
		add_child(frame)
		assert_object(frame).is_not_null()
		assert_str(String(frame.get_meta(&"variant"))).is_equal(variant)
		assert_int(frame.get_child_count()).is_greater(0)


func test_settings_only_ever_store_a_valid_variant() -> void:
	var settings: Node = get_node_or_null("/root/Settings")
	assert_object(settings).is_not_null()
	var before: String = String(settings.get("smith_variant"))
	settings.call("set_value", &"smith_variant", "nonsense", false)
	assert_str(String(settings.get("smith_variant"))).is_equal(Art.SMITH_VARIANT_DEFAULT)
	# Tom sträng är giltig och betyder "inte valt ännu" – det är den som utlöser
	# valskärmen vid första start.
	settings.call("set_value", &"smith_variant", "", false)
	assert_str(String(settings.get("smith_variant"))).is_equal("")
	settings.call("set_value", &"smith_variant", before, false)
