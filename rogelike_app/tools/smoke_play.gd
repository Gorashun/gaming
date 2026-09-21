extends SceneTree
## Headless/xvfb-rökprov: spelar en hel run på våning 1 med Lookahead-policyn,
## tar skärmdumpar och avslutar med exit code 0 om allt gick igenom.
##
## Körs med:
## [codeblock]
## xvfb-run -a -s "-screen 0 1080x1920x24" "$GODOT_BIN" --resolution 1080x1920 \
##   --audio-driver Dummy -s tools/smoke_play.gd -- --pipwreck-seed=7 \
##   --shots=res://docs/screenshots/m1_5
##
## # Bara logiken, utan fönster och utan skärmdumpar:
## "$GODOT_BIN" --headless -s tools/smoke_play.gd -- --pipwreck-seed=7
## [/codeblock]
##
## Flaggor:
##   --pipwreck-seed=N  seed för runnen (läses även av GameController)
##   --shots=DIR        katalog för skärmdumpar (tom = inga skärmdumpar)
##   --locale=xx        tvingar språk (t.ex. sv). Tomt = projektets standard.
##   --max-seconds=N    säkerhetsstopp (standard 180)
##
## Scriptet rör aldrig [Resolver] eller [Rng] direkt annat än genom
## [method Policy.lookahead]: det går samma väg genom UI som en spelare gör, och
## hittar därför fel som ett rent logiktest inte kan hitta.
##
## [b]Varför drivrutinen är en Node och inte [method _initialize]:[/b] awaits som
## återupptas ur SceneTree-initieringen ligger utanför motorns normala
## trädtraversering. En [Node] i trädet ger samma kod ett stabilt läge att
## återuppta i.

const MAIN_SCENE: String = "res://src/game/main.tscn"
const DEFAULT_MAX_SECONDS: float = 180.0
## Hur länge en enskild kedjeuppspelning får ta innan vi kallar det ett fel.
const PLAYBACK_TIMEOUT_MS: int = 15000


func _initialize() -> void:
	var driver: Driver = Driver.new()
	driver.name = "SmokeDriver"
	driver.args = _parse_args()
	root.add_child(driver)


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


class Driver:
	extends Node

	var args: Dictionary = {}

	var _shots_dir: String = ""
	var _shot_index: int = 0
	var _taken: Dictionary = {}
	var _errors: PackedStringArray = PackedStringArray()

	func _ready() -> void:
		await _run()

	func _run() -> void:
		var seed_value: int = int(args.get("pipwreck-seed", 7))
		_shots_dir = String(args.get("shots", ""))
		var max_seconds: float = float(args.get("max-seconds", DEFAULT_MAX_SECONDS))

		# --locale=sv kör hela rökprovet på svenska. Godot läser också --locale
		# som motorflagga, men bara före "--"; den här raden gör flaggan
		# användbar efter "--" där resten av våra flaggor ligger.
		var locale: String = String(args.get("locale", ""))
		if locale != "":
			TranslationServer.set_locale(locale)

		print("PIPWRECK smoke play")
		print("  locale=%s (fallback %s)" % [
			TranslationServer.get_locale(),
			ProjectSettings.get_setting("internationalization/locale/fallback", "en"),
		])
		print("  seed=%d  shots=%s  display=%s" % [
			seed_value,
			_shots_dir if _shots_dir != "" else "(none)",
			DisplayServer.get_name(),
		])
		if _shots_dir != "":
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_shots_dir))

		Juice.log_calls = true
		Haptics.log_calls = true

		var packed: PackedScene = ResourceLoader.load(MAIN_SCENE) as PackedScene
		if packed == null:
			_fail("could not load %s" % MAIN_SCENE)
			_finish()
			return
		var controller: GameController = packed.instantiate() as GameController
		if controller == null:
			_fail("main.tscn does not have GameController as its root")
			_finish()
			return
		# call_deferred: _ready körs medan roten fortfarande sätter upp sina barn.
		get_tree().root.add_child.call_deferred(controller)
		await _frames(3)

		var started_ms: int = Time.get_ticks_msec()
		var rounds_played: int = 0
		var rooms_seen: Dictionary = {}
		var running: bool = true

		while running:
			if Time.get_ticks_msec() - started_ms > int(max_seconds * 1000.0):
				_fail("time limit %.0f s reached on screen %s" % [max_seconds, controller.current_screen_name()])
				break
			var screen: GameScreen = controller.current_screen()
			if screen == null:
				await _frames(1)
				continue

			match controller.current_screen_name():
				GameController.SCREEN_MARCH:
					await _play_march(screen as MarchScreen)
				GameController.SCREEN_COMBAT:
					var combat: CombatScreen = screen as CombatScreen
					if combat.is_resolving():
						await _frames(1)
						continue
					rounds_played += 1
					rooms_seen[controller.run.room_index] = true
					if not await _play_round(combat):
						running = false
				GameController.SCREEN_REWARD:
					await _play_reward(screen as RewardScreen)
				GameController.SCREEN_GAMEOVER:
					await _report(screen as GameOverScreen, rounds_played, rooms_seen.size())
					running = false
				_:
					await _frames(1)

		_finish()

	# --- Skärmdrivning -----------------------------------------------------

	func _play_march(march: MarchScreen) -> void:
		await _frames(8)
		await _shot("04_march")
		if not is_instance_valid(march):
			return
		march.arrive()
		if is_instance_valid(march) and march.option_count() > 1:
			await _frames(4)
			await _shot("04b_march_branch")
			if is_instance_valid(march):
				march.choose(0)
		await _frames(1)

	func _play_round(combat: CombatScreen) -> bool:
		var placement: PackedInt32Array = Policy.lookahead(combat.state)
		for slot: int in range(placement.size()):
			if placement[slot] < 0:
				continue
			if not combat.place(placement[slot], slot):
				_fail("could not place die %d in slot %d" % [placement[slot], slot])
		await _frames(3)
		await _shot("01_combat_before_confirm")

		combat.confirm()
		# Mitt i kedjan: uppspelningen är igång men inte klar.
		await _seconds(0.5)
		if is_instance_valid(combat) and combat.is_resolving():
			await _shot("02_combat_mid_chain")

		# is_instance_valid: vinner rummet sin sista runda friar controllern
		# stridsskärmen medan vi väntar. En statiskt typad Node-referens
		# kontrolleras inte av GDScript, så ett anrop på den frigjorda noden
		# ger segfault i stället för ett fel.
		var started_ms: int = Time.get_ticks_msec()
		while is_instance_valid(combat) and combat.is_resolving():
			if Time.get_ticks_msec() - started_ms > PLAYBACK_TIMEOUT_MS:
				_fail("playback never finished (%d ms)" % PLAYBACK_TIMEOUT_MS)
				return false
			await _frames(1)
		await _frames(1)
		return true

	func _play_reward(reward: RewardScreen) -> void:
		await _frames(8)
		await _shot("03_reward")
		if not is_instance_valid(reward):
			return
		if reward.option_count() > 0:
			reward.choose(0)
		else:
			_fail("the reward screen got zero options")
		await _frames(1)

	func _report(over: GameOverScreen, rounds_played: int, rooms_seen: int) -> void:
		await _frames(8)
		if not is_instance_valid(over):
			_fail("the gameover screen vanished before it was read")
			return
		var summary: Dictionary = over.summary()
		var won: bool = bool(summary.get("won", false))
		await _shot("05_win" if won else "05_death")
		var score: Dictionary = summary.get("score", {}) as Dictionary
		print("")
		print("Run over: %s" % ("WIN" if won else "DEATH"))
		print("  room reached    %d" % int(summary.get("room_reached", 0)))
		print("  rooms cleared   %d" % int(summary.get("rooms_cleared", 0)))
		print("  best chain      %d" % int(summary.get("best_chain", 0)))
		print("  hp left         %d" % int(summary.get("hp_left", 0)))
		print("  meta score      %d" % int(score.get("total", 0)))
		print("  rounds played   %d" % rounds_played)
		print("  rooms visited   %d" % rooms_seen)
		print("  juice calls     %d   haptic calls %d" % [Juice.calls.size(), Haptics.calls.size()])
		if rounds_played <= 0:
			_fail("no round was played")
		if Juice.calls.is_empty():
			_fail("the event player made no juice calls")

	# --- Hjälpare ----------------------------------------------------------

	func _finish() -> void:
		print("")
		if _errors.is_empty():
			print("SMOKE OK  (%d screenshots)" % _shot_index)
			get_tree().quit(0)
			return
		for message: String in _errors:
			printerr("SMOKE FAIL: %s" % message)
		print("SMOKE FAIL: %d problems" % _errors.size())
		get_tree().quit(1)

	func _fail(message: String) -> void:
		_errors.append(message)

	func _frames(count: int) -> void:
		for i: int in range(count):
			await get_tree().process_frame

	func _seconds(duration: float) -> void:
		var deadline: int = Time.get_ticks_msec() + int(duration * 1000.0)
		while Time.get_ticks_msec() < deadline:
			await get_tree().process_frame

	## Tar en skärmdump. Varje namn tas bara en gång, så en run med femton rundor
	## fyller inte katalogen. Hoppas över i headless, där viewporten inte ritas.
	func _shot(shot_name: String) -> void:
		if _shots_dir == "" or _taken.has(shot_name):
			return
		if DisplayServer.get_name() == "headless":
			return
		_taken[shot_name] = true
		await RenderingServer.frame_post_draw
		var image: Image = get_tree().root.get_texture().get_image()
		if image == null:
			_fail("could not read the viewport for %s" % shot_name)
			return
		var path: String = "%s/%s.png" % [_shots_dir, shot_name]
		var err: Error = image.save_png(path)
		if err != OK:
			_fail("could not write %s (%d)" % [path, err])
			return
		_shot_index += 1
		print("  screenshot %s (%d×%d)" % [path, image.get_width(), image.get_height()])
