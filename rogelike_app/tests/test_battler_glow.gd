extends GdUnitTestSuite
## M7: shades har inbakat kantljus och ett glödlager. Manifestets
## [code]baked_rim[/code] stänger av shaderns kantljus, [code]emissive[/code]
## adderas efter ljuset och pulserar (inte vid reducerad rörelse). Konst utan
## fälten (Pipoya, Ækashics) ska se ut exakt som förut.

const REAL_PNG: String = "res://assets/sprites/enemies/rust_rat.png"
const GLOW_PNG: String = "res://assets/sprites/enemies/iron_tick.png"


func after_test() -> void:
	Art.reload_manifest()


func _entry(extra: Dictionary = {}) -> Dictionary:
	var e: Dictionary = {"file": REAL_PNG, "kind": "battler", "size": [128, 64],
		"pivot": "bottom", "frames": 1, "license": "CC0"}
	e.merge(extra, true)
	return e


func _battler(enemy_id: String) -> EnemyBattler:
	var battler: EnemyBattler = auto_free(EnemyBattler.new())
	battler.setup(enemy_id)
	add_child(battler)
	return battler


func test_plain_art_keeps_the_shader_rim_and_has_no_glow() -> void:
	Art.use_manifest({"enemy.RUST_RAT": _entry()})
	var battler: EnemyBattler = _battler("RUST_RAT")
	var mat: ShaderMaterial = battler.material()
	assert_bool(battler.baked_rim).is_false()
	assert_bool(battler.has_emissive).is_false()
	# Inga överskrivna parametrar: shaderns standardvärden gäller.
	assert_object(mat.get_shader_parameter(&"rim_strength")).is_null()
	assert_object(mat.get_shader_parameter(&"emissive_strength")).is_null()


func test_baked_rim_turns_the_shader_rim_off() -> void:
	Art.use_manifest({"enemy.RUST_RAT": _entry({"baked_rim": true})})
	var battler: EnemyBattler = _battler("RUST_RAT")
	assert_bool(battler.baked_rim).is_true()
	assert_float(float(battler.material().get_shader_parameter(&"rim_strength"))).is_equal(0.0)


func test_emissive_layer_is_bound_and_pulses_unless_reduced_motion() -> void:
	Art.use_manifest({"enemy.RUST_RAT": _entry({"emissive": GLOW_PNG})})
	var battler: EnemyBattler = _battler("RUST_RAT")
	var mat: ShaderMaterial = battler.material()
	assert_bool(battler.has_emissive).is_true()
	assert_object(mat.get_shader_parameter(&"emissive_tex")).is_not_null()
	assert_float(float(mat.get_shader_parameter(&"emissive_strength"))).is_equal(EnemyBattler.EMISSIVE_STRENGTH)
	battler.start_idle(0.3, false)
	assert_float(float(mat.get_shader_parameter(&"emissive_pulse"))).is_equal(EnemyBattler.EMISSIVE_PULSE)
	battler.start_idle(0.3, true)
	assert_float(float(mat.get_shader_parameter(&"emissive_pulse"))).is_equal(0.0)


func test_missing_emissive_file_means_no_glow_and_a_validation_error() -> void:
	var data: Dictionary = {"enemy.RUST_RAT": _entry({"emissive": "res://assets/art/enemy/NOPE_emissive.png"})}
	Art.use_manifest(data)
	var battler: EnemyBattler = _battler("RUST_RAT")
	assert_bool(battler.has_emissive).is_false()
	assert_str(" ".join(Art.validate_manifest(data))).contains("NOPE_emissive.png")


func test_the_shipped_shades_carry_baked_rim_and_glow() -> void:
	Art.reload_manifest()
	for enemy_id: String in ["RUST_RAT", "SLAG_MOTH", "THORN_IMP", "PIP_THIEF", "IRON_TICK",
			"GRAVE_HAND", "CHALK_DUMMY", "SLAGJAW"]:
		var info: Dictionary = Art.art_info(StringName("enemy." + enemy_id))
		assert_bool(bool(info.get("baked_rim", false))).override_failure_message(enemy_id).is_true()
		var glow: Texture2D = info.get("emissive", null) as Texture2D
		assert_object(glow).override_failure_message(enemy_id).is_not_null()
		var tex: Texture2D = info["texture"] as Texture2D
		# Pixelparet: glödlagret måste ha exakt samma storlek som bilden.
		assert_vector(Vector2(glow.get_width(), glow.get_height())).override_failure_message(enemy_id) \
			.is_equal(Vector2(tex.get_width(), tex.get_height()))
	assert_array(Art.validate_manifest()).is_empty()
