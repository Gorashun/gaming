extends SceneTree
## Rökprov för korridoren: går våning 1 från startrutan till bossdörren med en
## enkel policy, dumpar de fem bilder PM bad om och skriver ut de två siffror
## som är M5:s stoppregel (CORRIDOR_DESIGN §8.1).
##
## [codeblock]
## xvfb-run -a -s "-screen 0 1080x1920x24" "$GODOT_BIN" --resolution 1080x1920 \
##   --rendering-driver vulkan --audio-driver Dummy -s tools/smoke_corridor.gd -- \
##   --pipwreck-seed=7 --shots=res://docs/screenshots/m5
## [/codeblock]
##
## Flaggor:
##   --pipwreck-seed=N   seed för våningen
##   --shots=DIR         katalog för skärmdumpar (tom = inga)
##   --tag=NAME          prefix på filnamnen, t.ex. renderarens namn
##   --max-seconds=N     säkerhetsstopp (standard 120)
##   --reduced-motion    kör med omedelbar vy
##   --allow-fate        bygg ödeskastets dörr i sidogrenen (M3-innehåll)
##   --speed=F           tempofaktor, 0.5 = Blixt
##
## [b]Stoppregeln:[/b] korridortiden per run ≤ 90 s och max 3 steg utan
## händelse. Båda skrivs ut, båda fäller körningen om de spricker.

const VIEW_SCENE: String = "res://src/game/corridor/corridor_view.tscn"
const DEFAULT_MAX_SECONDS: float = 120.0
## Korridortiden mäts på EN våning här; budgeten gäller hela runnen (tre).
const FLOORS_PER_RUN: int = 3
const CORRIDOR_BUDGET_MS: float = 90000.0
const MAX_QUIET_STEPS: int = 3

var _args: Dictionary = {}
var _shots_dir: String = ""
var _tag: String = ""
var _shot_index: int = 0
var _taken: Dictionary = {}
var _errors: PackedStringArray = PackedStringArray()
var _frame_ms: PackedFloat32Array = PackedFloat32Array()
var _last_frame_us: int = 0


func _initialize() -> void:
	_args = _parse_args()
	process_frame.connect(_boot, CONNECT_ONE_SHOT)


func _parse_args() -> Dictionary:
	var parsed: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var body: String = arg.substr(2)
		var equals: int = body.find("=")
		if equals < 0:
			parsed[body] = true
		else:
			parsed[body.substr(0, equals)] = body.substr(equals + 1)
	return parsed


func _boot() -> void:
	await _run()


func _run() -> void:
	var seed_value: int = int(_args.get("pipwreck-seed", 7))
	_shots_dir = String(_args.get("shots", ""))
	_tag = String(_args.get("tag", ""))
	var max_seconds: float = float(_args.get("max-seconds", DEFAULT_MAX_SECONDS))
	var reduced: bool = bool(_args.get("reduced-motion", false))
	var allow_fate: bool = bool(_args.get("allow-fate", false))
	var speed: float = float(_args.get("speed", 1.0))

	print("PIPWRECK smoke corridor")
	print("  seed=%d  driver=%s  display=%s  shots=%s  reduced_motion=%s  speed=%.2f" % [
		seed_value,
		RenderingServer.get_video_adapter_api_version(),
		DisplayServer.get_name(),
		_shots_dir if _shots_dir != "" else "(none)",
		str(reduced), speed,
	])
	print("  renderer=%s  adapter=%s" % [
		ProjectSettings.get_setting("rendering/renderer/rendering_method", "?"),
		RenderingServer.get_video_adapter_name(),
	])

	var rng: Rng = Rng.new(seed_value)
	var graph: RunGraph = RunGraph.generate_floor(1, rng)
	var map: CorridorMap = CorridorMap.build(graph, rng.fork("corridor"), allow_fate)

	var host: Control = Control.new()
	host.name = "Host"
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)

	var scene: PackedScene = load(VIEW_SCENE) as PackedScene
	if scene == null:
		_fail("kunde inte ladda %s" % VIEW_SCENE)
		return _finish(max_seconds)
	var view: Node = scene.instantiate()
	host.add_child(view)
	view.set("reduced_motion", reduced)
	view.set("speed_scale", speed)
	view.call("set_reduced_motion", reduced)
	view.call("set_speed_scale", speed)
	view.call("setup", map, {"hp": 74, "max_hp": 100, "room": 1, "pips": 12})

	_last_frame_us = Time.get_ticks_usec()
	process_frame.connect(_sample_frame)

	await _settle(4)
	await _shot(view, "01_start")

	var started_us: int = Time.get_ticks_usec()
	var guard: int = 0
	var seen: Dictionary = {}
	var deadline_us: int = started_us + int(max_seconds * 1000000.0)

	while not map.is_finished() and guard < 120:
		guard += 1
		if Time.get_ticks_usec() > deadline_us:
			_fail("säkerhetsstoppet slog till efter %.0f s" % max_seconds)
			break
		if map.pending_trap_key != "":
			var trap: Dictionary = map.pending_trap()
			print("  trap %s: %s" % [trap.get("id", "?"), JSON.stringify(trap.get("options", []))])
			if not seen.has("trap"):
				seen["trap"] = true
				await _shot(view, "04_trap")
			view.call("resolve_trap", 0)
			continue

		var actions: Dictionary = view.get("map").call("available_actions")
		if actions.is_empty():
			break
		if actions.size() > 1 and not seen.has("junction"):
			seen["junction"] = true
			await _settle(2)
			await _shot(view, "02_junction")

		# Fienderna i nästa kammare måste stå där innan spelaren ser dem.
		_prime_enemies(view, map, graph)
		var pick: String = _policy(actions)
		await view.call("step", pick)

		var distance: int = _encounter_distance(map)
		if distance == 2 and not seen.has("far"):
			seen["far"] = true
			await _settle(2)
			await _shot(view, "03_monster_far")
		if distance == 0 and not seen.has("near"):
			seen["near"] = true
			# Striden är 45 % korridor (UI_GUIDE §17.1). Fienderna ska dumpas i
			# DEN splitten – i utforskningssplitten är den vertikala vinkeln
			# nästan 100° och främre ledet hamnar i underkanten.
			view.call("show_combat_split")
			await _settle(3)
			await _shot(view, "05_monster_ahead")
			view.call("show_explore_split")
			# I spelet gör GameController det här när striden är slut.
			view.call("clear_encounter")
			await _settle(2)
		if String(map.current_cell()["kind"]) == CorridorMap.KIND_BOSS_DOOR and not seen.has("door"):
			seen["door"] = true
			await _settle(2)
			await _shot(view, "06_boss_door")

	var elapsed_ms: float = float(Time.get_ticks_usec() - started_us) / 1000.0
	var quiet: int = int(view.call("max_steps_without_event"))
	var run_ms: float = elapsed_ms * float(FLOORS_PER_RUN)

	print("")
	print("  steps on floor 1        : %d" % map.steps_taken)
	print("  corridor time floor 1   : %.0f ms" % elapsed_ms)
	print("  corridor time per run   : %.0f ms (x%d floors, budget %.0f ms)" % [
		run_ms, FLOORS_PER_RUN, CORRIDOR_BUDGET_MS])
	print("  max steps without event : %d (max %d)" % [quiet, MAX_QUIET_STEPS])
	print("  frame time p50/p95/max  : %.2f / %.2f / %.2f ms (%d frames)" % [
		_percentile(50.0), _percentile(95.0), _percentile(100.0), _frame_ms.size()])
	print("  screenshots             : %d" % _shot_index)

	if not seen.has("junction"):
		_fail("nådde aldrig en T-korsning")
	if not seen.has("door"):
		_fail("nådde aldrig bossdörren")
	if run_ms > CORRIDOR_BUDGET_MS:
		_fail("korridortiden %0.f ms per run överskrider %0.f ms" % [run_ms, CORRIDOR_BUDGET_MS])
	if quiet > MAX_QUIET_STEPS:
		_fail("%d steg utan händelse (max %d)" % [quiet, MAX_QUIET_STEPS])
	_finish(max_seconds)


## Policy: alltid mot "fight" om det går. Den värsta vägen i stegbudgeten är
## inte den intressanta här – den mest spelade är.
func _policy(actions: Dictionary) -> String:
	for action: String in [CorridorMap.ACTION_LEFT, CorridorMap.ACTION_RIGHT, CorridorMap.ACTION_FORWARD]:
		var info: Dictionary = actions.get(action, {}) as Dictionary
		if String(info.get("sign", "")) == CorridorMap.SIGN_FIGHT:
			return action
	if actions.has(CorridorMap.ACTION_FORWARD):
		return CorridorMap.ACTION_FORWARD
	return String(actions.keys()[0])


## Avståndet till nästa kammare med ett möte, eller -1.
func _encounter_distance(map: CorridorMap) -> int:
	if bool(map.current_cell().get("encounter", false)):
		return 0
	var best: int = -1
	for action: Variant in map.available_actions():
		var info: Dictionary = (map.available_actions()[action]) as Dictionary
		if String(info.get("leads_to", "")) != CorridorMap.KIND_CHAMBER:
			continue
		var d: int = int(info.get("distance", -1))
		if best < 0 or (d >= 0 and d < best):
			best = d
	return best


## Lägger fienderna i vyn innan spelaren ser dem. I spelet gör
## [GameController] detta ur [method Content.encounter].
func _prime_enemies(view: Node, map: CorridorMap, graph: RunGraph) -> void:
	var actions: Dictionary = map.available_actions()
	for action: Variant in actions:
		var info: Dictionary = actions[action]
		var node_id: String = String(info.get("leads_to_node", ""))
		if node_id == "":
			node_id = String(info.get("node_id", ""))
		if node_id == "":
			continue
		var node: Dictionary = graph.node_at(node_id)
		if node.is_empty():
			continue
		var ids: Array = []
		for enemy: Enemy in Content.encounter(int(node["room"]), int(node["variant"])):
			ids.append(enemy.id)
		view.call("set_next_enemies", ids)
		return


func _sample_frame() -> void:
	var now: int = Time.get_ticks_usec()
	_frame_ms.append(float(now - _last_frame_us) / 1000.0)
	_last_frame_us = now


func _percentile(p: float) -> float:
	if _frame_ms.is_empty():
		return 0.0
	var sorted: Array = Array(_frame_ms)
	sorted.sort()
	var index: int = clampi(int(round(p / 100.0 * float(sorted.size() - 1))), 0, sorted.size() - 1)
	return float(sorted[index])


func _settle(frames: int) -> void:
	for _i: int in range(frames):
		await process_frame


func _shot(view: Node, name: String) -> void:
	if _shots_dir == "":
		return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null:
		_fail("ingen bild att spara för %s" % name)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_shots_dir))
	var prefix: String = "%s_" % _tag if _tag != "" else ""
	var path: String = "%s/%s%s.png" % [_shots_dir, prefix, name]
	var err: Error = image.save_png(path)
	if err != OK:
		_fail("kunde inte spara %s (%d)" % [path, err])
		return
	_shot_index += 1
	_taken[name] = true
	print("  shot %s" % path)


func _fail(message: String) -> void:
	_errors.append(message)
	printerr("SMOKE FAIL: %s" % message)


func _finish(_max_seconds: float) -> void:
	if _errors.is_empty():
		print("SMOKE OK")
		quit(0)
		return
	printerr("SMOKE FAILED with %d error(s)" % _errors.size())
	quit(1)
