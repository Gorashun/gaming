extends GdUnitTestSuite
## Art-manifestet (M6 spår A steg 1, DECISIONS 2026-09-23: "byte = byt fil").
##
## Två sorters tester. De första injicerar ett manifest med [method Art.use_manifest]
## och prövar uppslagsordningen: manifest → alias → gammal sprite → platshållare.
## De sista läser det riktiga [code]assets/art/manifest.json[/code] om det finns
## och fäller bygget på en trasig post – en post som pekar på en fil som inte
## finns ska bli en röd rad här, inte en tyst platshållare i spelet.

const GONE: String = "res://assets/art/enemy/__does_not_exist__.png"
## En fil som garanterat finns och som manifestet får peka på i testerna.
## Den ligger inte under assets/art/, så den används bara där valideringen inte
## körs.
const REAL_PNG: String = "res://assets/sprites/enemies/rust_rat.png"


func after_test() -> void:
	# Manifestet är statiskt; ett test som injicerat ett eget får aldrig läcka
	# in i nästa svit.
	Art.reload_manifest()


func _entry(file: String, kind: String = Art.KIND_BATTLER, extra: Dictionary = {}) -> Dictionary:
	var e: Dictionary = {"file": file, "kind": kind, "size": [64, 96], "pivot": "bottom",
		"frames": 1, "source": "test", "license": "CC0"}
	e.merge(extra, true)
	return e


# --- Uppslagsordningen -----------------------------------------------------

func test_a_missing_file_falls_back_to_the_old_sprite_without_an_error() -> void:
	Art.use_manifest({"enemy.RUST_RAT": _entry(GONE)})
	var info: Dictionary = Art.art_info(&"enemy.RUST_RAT")
	assert_object(info["texture"]).is_not_null()
	assert_str(String(info["source"])).is_equal(Art.SOURCE_LEGACY)
	# Den gamla spriten är pixelkonst och ska ritas med Nearest.
	assert_bool(bool(info["pixel"])).is_true()


func test_an_unknown_enemy_with_a_missing_file_gets_the_placeholder() -> void:
	Art.use_manifest({"enemy.NOBODY_EVER": _entry(GONE)})
	var info: Dictionary = Art.art_info(&"enemy.NOBODY_EVER")
	assert_object(info["texture"]).is_not_null()
	assert_str(String(info["source"])).is_equal(Art.SOURCE_PLACEHOLDER)


func test_the_manifest_placeholder_wins_over_the_generated_one() -> void:
	Art.use_manifest({"enemy.placeholder": _entry(REAL_PNG)})
	var info: Dictionary = Art.art_info(&"enemy.SOMETHING_NEW")
	assert_str(String(info["source"])).is_equal(Art.SOURCE_PLACEHOLDER)
	assert_object(info["texture"]).is_same(Art.tex(&"enemy.placeholder"))


func test_an_enemy_or_icon_is_never_null_even_with_no_manifest_at_all() -> void:
	Art.use_manifest({})
	for id: StringName in [&"enemy.X", &"gear.X", &"relic.X", &"slot.x", &"node.x", &"icon.placeholder"]:
		assert_object(Art.tex(id)).override_failure_message("%s blev null" % id).is_not_null()


func test_frames_and_panels_may_be_null_so_the_caller_draws_a_stylebox() -> void:
	Art.use_manifest({})
	assert_object(Art.tex(&"ui.frame.panel")).is_null()
	assert_object(Art.rarity_frame("rare")).is_null()


func test_a_manifest_entry_that_loads_is_used_as_is_with_its_size_and_pivot() -> void:
	Art.use_manifest({"enemy.RUST_RAT": _entry(REAL_PNG, Art.KIND_BATTLER, {"size": [128, 64], "pivot": "center"})})
	var info: Dictionary = Art.art_info(&"enemy.RUST_RAT")
	assert_str(String(info["source"])).is_equal(Art.SOURCE_MANIFEST)
	assert_vector(info["size"] as Vector2).is_equal(Vector2(128, 64))
	assert_str(String(info["pivot"])).is_equal("center")
	# Målad konst: Linear, inte Nearest, om inte manifestet säger pixel: true.
	assert_bool(bool(info["pixel"])).is_false()
	assert_int(Art.filter_for(&"enemy.RUST_RAT")).is_equal(CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)


func test_pixel_true_in_the_manifest_asks_for_nearest() -> void:
	Art.use_manifest({"enemy.RUST_RAT": _entry(REAL_PNG, Art.KIND_BATTLER, {"pixel": true})})
	assert_int(Art.filter_for(&"enemy.RUST_RAT")).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)


func test_painted_battlers_get_mipmaps() -> void:
	Art.use_manifest({"enemy.RUST_RAT": _entry(REAL_PNG)})
	var texture: Texture2D = Art.tex(&"enemy.RUST_RAT")
	assert_bool(texture.get_image().has_mipmaps()).is_true()


func test_tutorial_enemies_borrow_the_manifest_art_of_their_alias() -> void:
	Art.use_manifest({"enemy.RUST_RAT": _entry(REAL_PNG)})
	assert_object(Art.tex(&"enemy.RUST_MITE")).is_same(Art.tex(&"enemy.RUST_RAT"))


func test_reload_bumps_the_version_and_clears_the_cache() -> void:
	Art.use_manifest({"enemy.RUST_RAT": _entry(REAL_PNG)})
	var before: int = Art.manifest_version
	var painted: Texture2D = Art.tex(&"enemy.RUST_RAT")
	Art.use_manifest({})
	assert_int(Art.manifest_version).is_greater(before)
	assert_object(Art.tex(&"enemy.RUST_RAT")).is_not_same(painted)


func test_gear_icons_accept_ids_with_and_without_prefix() -> void:
	Art.use_manifest({"gear.IRON_HELM": _entry(REAL_PNG, Art.KIND_ICON)})
	assert_object(Art.gear_icon("IRON_HELM")).is_same(Art.gear_icon("gear.IRON_HELM"))
	assert_object(Art.gear_icon("")).is_not_null()
	assert_object(Art.gear_icon("NOT_A_THING")).is_not_null()


# --- Validering ------------------------------------------------------------

func test_validation_catches_every_kind_of_broken_entry() -> void:
	var problems: PackedStringArray = Art.validate_manifest({
		"enemy.A": {"file": GONE, "kind": "battler", "size": [1, 1], "license": "CC0"},
		"enemy.B": {"file": "res://elsewhere.png", "kind": "battler", "size": [1, 1], "license": "CC0"},
		"enemy.C": {"file": GONE, "kind": "sprite", "size": [0, 1], "license": ""},
		"gear.D": {"file": GONE, "kind": "battler", "size": [1, 1], "pivot": "top", "license": "CC0"},
	})
	var text: String = "\n".join(problems)
	assert_str(text).contains("enemy.A: filen")
	assert_str(text).contains("enemy.B:")
	assert_str(text).contains("okänd kind 'sprite'")
	assert_str(text).contains("enemy.C: size")
	assert_str(text).contains("enemy.C: saknar license")
	assert_str(text).contains("gear.D: föremål ska vara kind icon")
	assert_str(text).contains("okänd pivot 'top'")


## Det riktiga manifestet, om asset-agenten levererat det. Saknas filen är
## fallbacken hela kontraktet och testet har inget att säga.
func test_the_shipped_manifest_is_well_formed() -> void:
	Art.reload_manifest()
	if not FileAccess.file_exists(Art.MANIFEST_PATH):
		return
	var problems: PackedStringArray = Art.validate_manifest()
	assert_array(Array(problems)).override_failure_message(
		"assets/art/manifest.json:\n%s" % "\n".join(problems)).is_empty()


## "Alla enemy.<ID> i Content finns eller faller tillbaka." Varje fiende spelet
## kan visa får konst ur manifestet eller en gammal sprite – aldrig
## platshållaren.
func test_every_enemy_in_content_has_real_art_or_a_legacy_sprite() -> void:
	Art.reload_manifest()
	var bad: PackedStringArray = PackedStringArray()
	for enemy_id: String in Art.content_enemy_ids():
		var info: Dictionary = Art.art_info(Art.enemy_art_key(enemy_id))
		if info["texture"] == null or String(info["source"]) == Art.SOURCE_PLACEHOLDER:
			bad.append(enemy_id)
	assert_array(Array(bad)).override_failure_message(
		"fiender utan konst: %s" % ", ".join(bad)).is_empty()


## Omvänt: ett enemy.<ID> i manifestet som inget innehåll använder är nästan
## alltid ett stavfel, och då ritas platshållaren för den riktiga fienden.
func test_every_enemy_in_the_manifest_is_known_content() -> void:
	Art.reload_manifest()
	var known: PackedStringArray = Art.content_enemy_ids()
	var unknown: PackedStringArray = PackedStringArray()
	for key: Variant in Art.manifest():
		var id: String = String(key)
		if id.begins_with("enemy.") and id != String(Art.ID_ENEMY_PLACEHOLDER):
			if not known.has(id.trim_prefix("enemy.")):
				unknown.append(id)
	assert_array(Array(unknown)).override_failure_message(
		"manifestet nämner fiender som inte finns: %s" % ", ".join(unknown)).is_empty()


func test_relics_slots_and_nodes_never_end_on_the_placeholder() -> void:
	Art.reload_manifest()
	for relic_id: String in Content.RELICS:
		assert_str(String(Art.art_info(StringName("relic." + relic_id))["source"])).override_failure_message(
			"reliken %s saknar ikon" % relic_id).is_not_equal(Art.SOURCE_PLACEHOLDER)
	for kind: String in ["combat", "boss", "elite", "forge", "rest", "mystery"]:
		assert_str(String(Art.art_info(StringName("node." + kind))["source"])).is_not_equal(Art.SOURCE_PLACEHOLDER)


func test_the_hero_portraits_resolve_for_both_looks() -> void:
	Art.reload_manifest()
	for variant: String in Art.SMITH_VARIANTS:
		assert_object(Art.smith_portrait(variant)).is_not_null()
