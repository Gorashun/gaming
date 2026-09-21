extends GdUnitTestSuite
## Autosave: roundtrip, versionsfält och – viktigast – att en trasig fil ger en
## ny run i stället för en krasch. GAME_DESIGN §1.

const TEST_PATH: String = "user://test_save.json"

var _original_path: String = ""


func before_test() -> void:
	_original_path = SaveIO.save_path
	SaveIO.save_path = TEST_PATH
	SaveIO.clear()


func after_test() -> void:
	SaveIO.clear()
	SaveIO.save_path = _original_path


func _run(seed_value: int = 4242) -> RunState:
	var run: RunState = RunState.new_run(seed_value)
	var rng: Rng = run.make_rng()
	run.combat = RunFlow.start_room(run.combat, {"room_in_floor": 1, "variant": 0}, rng)
	run.store_rng(rng)
	return run


func _write_raw(text: String) -> void:
	var file: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_has_save_is_false_before_anything_is_written() -> void:
	assert_bool(SaveIO.has_save()).is_false()
	assert_object(SaveIO.load_run()).is_null()


func test_roundtrip_preserves_the_run() -> void:
	var run: RunState = _run()
	assert_bool(SaveIO.save_run(run)).is_true()
	assert_bool(SaveIO.has_save()).is_true()

	var loaded: RunState = SaveIO.load_run()
	assert_object(loaded).is_not_null()
	assert_int(loaded.seed_value).is_equal(run.seed_value)
	assert_int(loaded.floor_index).is_equal(run.floor_index)
	assert_int(loaded.room_index).is_equal(run.room_index)
	assert_str(JSON.stringify(loaded.combat.to_dict())).is_equal(JSON.stringify(run.combat.to_dict()))


func test_roundtrip_preserves_the_rng_position() -> void:
	# Utan detta fortsätter en återupptagen run på ett annat tärningskast, och
	# hela determinismlöftet (GAME_DESIGN §6.10) är brutet.
	var run: RunState = _run(99)
	var rng: Rng = run.make_rng()
	var expected: Array[int] = []
	for i: int in range(5):
		expected.append(rng.next_int(0, 1000))

	SaveIO.save_run(run)
	var loaded_rng: Rng = SaveIO.load_run().make_rng()
	var actual: Array[int] = []
	for i: int in range(5):
		actual.append(loaded_rng.next_int(0, 1000))
	assert_array(actual).is_equal(expected)


func test_the_version_field_is_written_and_is_current() -> void:
	SaveIO.save_run(_run())
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH)) as Dictionary
	assert_bool(raw.has("version")).is_true()
	assert_int(int(raw["version"])).is_equal(RunState.SAVE_VERSION)


func test_extra_data_lands_in_meta() -> void:
	SaveIO.save_run(_run(), {"node_id": "f1r2", "rooms_cleared": 2, "best_chain": 87})
	var loaded: RunState = SaveIO.load_run()
	assert_str(String(loaded.meta["node_id"])).is_equal("f1r2")
	assert_int(int(loaded.meta["rooms_cleared"])).is_equal(2)
	assert_int(int(loaded.meta["best_chain"])).is_equal(87)
	# Klassen som RunState.new_run satte ska inte ha skrivits över.
	assert_str(String(loaded.meta["class"])).is_equal("SMITH")


func test_a_run_graph_survives_the_save_file() -> void:
	var graph: RunGraph = RunGraph.generate_floor(1, Rng.new(12))
	SaveIO.save_run(_run(), {"graph": graph.to_dict(), "node_id": graph.start_id})
	var loaded: RunState = SaveIO.load_run()
	var restored: RunGraph = RunGraph.from_dict(loaded.meta["graph"] as Dictionary)
	assert_int(restored.nodes.size()).is_equal(graph.nodes.size())
	assert_bool(restored.reaches_boss(restored.start_id)).is_true()


func test_corrupt_json_gives_a_new_run_instead_of_a_crash() -> void:
	_write_raw("{ detta är inte json ][")
	assert_dict(SaveIO.load_dict()).is_empty()
	assert_object(SaveIO.load_run()).is_null()


func test_truncated_file_gives_a_new_run_instead_of_a_crash() -> void:
	# Precis vad som händer när OS:et dödar appen mitt i en skrivning.
	SaveIO.save_run(_run())
	var text: String = FileAccess.get_file_as_string(TEST_PATH)
	_write_raw(text.substr(0, text.length() / 2))
	assert_object(SaveIO.load_run()).is_null()


func test_empty_file_gives_a_new_run() -> void:
	_write_raw("")
	assert_object(SaveIO.load_run()).is_null()


func test_json_that_is_not_an_object_gives_a_new_run() -> void:
	_write_raw("[1, 2, 3]")
	assert_object(SaveIO.load_run()).is_null()


func test_a_save_without_the_required_fields_gives_a_new_run() -> void:
	_write_raw('{"hello": "world"}')
	assert_object(SaveIO.load_run()).is_null()


func test_a_future_version_is_refused_rather_than_misread() -> void:
	SaveIO.save_run(_run())
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH)) as Dictionary
	raw["version"] = RunState.SAVE_VERSION + 1
	_write_raw(JSON.stringify(raw))
	assert_object(SaveIO.load_run()).is_null()


func test_version_zero_is_refused() -> void:
	SaveIO.save_run(_run())
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH)) as Dictionary
	raw["version"] = 0
	_write_raw(JSON.stringify(raw))
	assert_object(SaveIO.load_run()).is_null()


func test_a_failed_write_does_not_destroy_the_previous_save() -> void:
	# Skrivningen går via en temporärfil och byter namn sist. En kvarlämnad
	# temporärfil får aldrig räknas som sparfilen.
	SaveIO.save_run(_run(7))
	_write_raw_to(TEST_PATH + SaveIO.TEMP_SUFFIX, "halvskriven sopa")
	var loaded: RunState = SaveIO.load_run()
	assert_object(loaded).is_not_null()
	assert_int(loaded.seed_value).is_equal(7)


func test_clear_removes_both_the_save_and_the_temp_file() -> void:
	SaveIO.save_run(_run())
	_write_raw_to(TEST_PATH + SaveIO.TEMP_SUFFIX, "skräp")
	SaveIO.clear()
	assert_bool(SaveIO.has_save()).is_false()
	assert_bool(FileAccess.file_exists(TEST_PATH + SaveIO.TEMP_SUFFIX)).is_false()


func test_saving_null_is_refused_without_crashing() -> void:
	assert_bool(SaveIO.save_run(null)).is_false()


func _write_raw_to(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
