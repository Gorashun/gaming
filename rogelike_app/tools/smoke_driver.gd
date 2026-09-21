extends Node
## Rökprovets drivrutin. Spelar en hel run på våning 1 genom det RIKTIGA UI:t.
##
## [b]Varför den ligger i en egen fil:[/b] [code]tools/smoke_play.gd[/code] körs
## med [code]-s[/code] och kompileras därmed INNAN motorn registrerat
## autoloadarna. Allt som den filen typar mot kompileras samtidigt, och en
## skärm som nämner [code]Juice[/code] fäller då hela bygget med
## "Identifier not found: Juice". Drivrutinen laddas i stället på första
## bildrutan, när [code]/root/Juice[/code] och [code]/root/Settings[/code] finns.

const DEFAULT_MAX_SECONDS: float = 180.0
## Hur länge en enskild kedjeuppspelning får ta innan vi kallar det ett fel.
const PLAYBACK_TIMEOUT_MS: int = 15000
const MAIN_SCENE: String = "res://src/game/main.tscn"


var args: Dictionary = {}
## Autoloaden [code]Juice[/code], hämtad via sökväg (se _run).
var juice: Node = null

var _shots_dir: String = ""
var _shot_index: int = 0
var _taken: Dictionary = {}
var _errors: PackedStringArray = PackedStringArray()
## Bildrutetider (ms) samlade MEDAN en kedja spelas upp. Det är den enda stund
## spelet gör något tungt, och därför den enda som är värd att mäta.
var _frame_ms: PackedFloat32Array = PackedFloat32Array()
## Samma mätning MELLAN kedjorna. Jämförelsen är hela poängen: en kedja som
## kostar lika mycket som en stillastående skärm är inte kedjan som är dyr.
var _idle_ms: PackedFloat32Array = PackedFloat32Array()
var _last_frame_us: int = 0
var _last_idle_us: int = 0
var _controller: Node = null

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

	# Inställningarna ligger i user:// och överlever mellan körningar. Rökprovet
	# ska mäta ETT läge, inte det som råkade stå kvar från förra gången.
	var settings: Node = get_node_or_null("/root/Settings")
	if settings != null:
		settings.set("config_path", "user://smoke_settings.cfg")
		settings.call("reset_to_defaults", false)
		if locale != "":
			settings.set("locale", locale)
		if bool(args.get("reduced-motion", false)):
			settings.set("reduced_motion", true)
		settings.call("apply")

	print("PIPWRECK smoke play")
	print("  locale=%s (fallback %s)" % [
		TranslationServer.get_locale(),
		ProjectSettings.get_setting("internationalization/locale/fallback", "en"),
	])
	print("  seed=%d  policy=%s  shots=%s  display=%s  reduced_motion=%s" % [
		seed_value,
		String(args.get("policy", "lookahead")),
		_shots_dir if _shots_dir != "" else "(none)",
		DisplayServer.get_name(),
		str(bool(args.get("reduced-motion", false))),
	])
	if _shots_dir != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_shots_dir))

	# Autoloads kan inte nås som identifierare här: ett -s-skript kompileras
	# INNAN autoloadarna registreras, och "Juice" finns då inte i det globala
	# namnrummet. Noden finns däremot när Driver är i trädet.
	juice = get_node_or_null("/root/Juice")
	if juice == null:
		_fail("the Juice autoload is missing")
	else:
		juice.log_calls = true
	Haptics.log_calls = true

	# Ren start. Sparfilen ligger i user:// och överlever mellan körningar.
	SaveIO.clear()

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
	_controller = controller
	await _frames(3)
	await _play_title(controller)

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
			GameController.SCREEN_TITLE:
				await _play_title(controller)
			GameController.SCREEN_MARCH:
				await _play_march(screen as MarchScreen)
			GameController.SCREEN_COMBAT:
				var combat: CombatScreen = screen as CombatScreen
				if combat.is_intro_active():
					# Bossintron äger skärmen i högst 1,2 s och räknas som
					# "resolving", så den måste fångas HÄR och inte i _play_round.
					await _frames(4)
					await _shot("05_boss_intro")
					await _frames(1)
					continue
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

## Vilken spelare rökprovet är. [code]--policy=none[/code] placerar ingenting
## och dör därför garanterat – enda sättet att få en deterministisk
## dödsskärmdump, eftersom Lookahead vinner våning 1 i ~94 % av fallen
## (DECISIONS 2026-09-21, balanspasset).
func _placement_for(combat: CombatScreen) -> PackedInt32Array:
	match String(args.get("policy", "lookahead")):
		"greedy":
			return Policy.greedy(combat.state)
		"none":
			return CombatState.empty_placement(combat.state.board.size())
	return Policy.lookahead(combat.state)


# --- Skärmdrivning -----------------------------------------------------

## Titelskärmen: skärmdump, ett svep genom inställningarna, sedan in i runnen.
func _play_title(controller: GameController) -> void:
	await _frames(6)
	if controller.current_screen_name() != GameController.SCREEN_TITLE:
		return
	var title: TitleScreen = controller.current_screen() as TitleScreen
	if title == null:
		return
	await _shot("00_title")

	controller.open_settings()
	await _frames(6)
	await _shot("01_settings")
	var modal_root: Node = controller.get_node_or_null("ChalkUI/UiRoot/ModalRoot")
	if modal_root == null:
		_fail("main.tscn has no ChalkUI/UiRoot/ModalRoot")
	elif modal_root.get_child_count() == 0:
		_fail("the settings modal did not open")
	else:
		modal_root.get_child(0).call("close")
	await _frames(3)

	# Titeln kan ha byggts om medan modalen var uppe (sparfilen nollställd).
	title = controller.current_screen() as TitleScreen
	if title == null:
		_fail("the title screen vanished while the settings modal was open")
		return
	# Alltid NEW RUN: rökprovet ska spela en känd seed från rum 1, och en
	# sparfil som ligger kvar från förra körningen skulle annars göra både
	# körningen och skärmdumparna beroende av vad som hände sist.
	title.press("new")
	await _frames(2)

func _play_march(march: MarchScreen) -> void:
	await _frames(8)
	await _shot("02_march")
	if not is_instance_valid(march):
		return
	march.arrive()
	if is_instance_valid(march) and march.option_count() > 1:
		await _frames(4)
		await _shot("02b_march_branch")
		if is_instance_valid(march):
			march.choose(0)
	await _frames(1)

func _play_round(combat: CombatScreen) -> bool:
	var placement: PackedInt32Array = _placement_for(combat)
	for slot: int in range(placement.size()):
		if placement[slot] < 0:
			continue
		if not combat.place(placement[slot], slot):
			_fail("could not place die %d in slot %d" % [placement[slot], slot])
	await _frames(3)
	await _shot("03_combat_before_confirm")

	combat.confirm()
	# Mitt i kedjan, och medvetet SENT i den: number pops och träffblixtar
	# kommer av damage_dealt, som ligger efter de första tärningarna
	# (UI_GUIDE §12.3 rad 6 ligger på 876 ms).
	await _seconds(1.0)
	if is_instance_valid(combat) and combat.is_resolving():
		await _shot("04_combat_mid_chain")

	# is_instance_valid: vinner rummet sin sista runda friar controllern
	# stridsskärmen medan vi väntar. En statiskt typad Node-referens
	# kontrolleras inte av GDScript, så ett anrop på den frigjorda noden
	# ger segfault i stället för ett fel.
	var started_ms: int = Time.get_ticks_msec()
	_last_frame_us = 0
	while is_instance_valid(combat) and combat.is_resolving():
		if Time.get_ticks_msec() - started_ms > PLAYBACK_TIMEOUT_MS:
			_fail("playback never finished (%d ms)" % PLAYBACK_TIMEOUT_MS)
			return false
		# Prestandamätningen sker HÄR och ingen annanstans: under kedjan körs
		# pooler, shaders, partiklar och tweens samtidigt.
		_sample_frame()
		await _frames(1)
	await _frames(1)
	return true

func _play_reward(reward: RewardScreen) -> void:
	await _frames(8)
	await _shot("06_reward")
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
	await _shot("07_win" if won else "07_death")
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
	print("  juice calls     %d   haptic calls %d" % [
		(juice.calls.size() if juice != null else 0), Haptics.calls.size()])
	if juice != null:
		var missing: Dictionary = juice.get("missing_sfx") as Dictionary
		print("  sfx loaded      %d" % int(juice.get("sfx_loaded")))
		print("  sfx missing     %d%s" % [
			int(juice.get("sfx_missing")),
			"" if missing.is_empty() else "  (%s)" % ", ".join(PackedStringArray(missing.keys())),
		])
	_report_frame_time()
	if rounds_played <= 0:
		_fail("no round was played")
	if juice != null and juice.calls.is_empty():
		_fail("the event player made no juice calls")

# --- Hjälpare ----------------------------------------------------------

## En bildrutes längd i ms, mätt som väggklocka mellan två på varandra följande
## bildrutor.
##
## [b]Varför inte [code]Performance.TIME_PROCESS[/code], som briefen bad om:[/b]
## den monitorn uppdateras inte per bildruta. Uppmätt i den här miljön ger den
## exakt samma värde 200 bildrutor i rad (156,71 ms på en titelskärm med 67
## noder), medan ett tomt projekt ger 0,06 ms. Siffran duger till en trend över
## sekunder, inte till en p95 över en kedja. Monitorn skrivs ändå ut, så att
## jämförelsen med CI:s historik finns kvar.
func _sample_frame() -> void:
	var now: int = Time.get_ticks_usec()
	if _last_frame_us > 0:
		_frame_ms.append(float(now - _last_frame_us) / 1000.0)
	_last_frame_us = now

## p95 i stället för medel: en kedja som är jämn utom på combo-rutan känns
## hackig, och det är precis det ett medelvärde döljer.
func _report_frame_time() -> void:
	if _frame_ms.is_empty():
		print("  frame time      (no samples)")
		return
	var sorted: Array[float] = []
	for value: float in _frame_ms:
		sorted.append(value)
	sorted.sort()
	var p50: float = sorted[int(sorted.size() * 0.50)]
	var p95: float = sorted[mini(int(sorted.size() * 0.95), sorted.size() - 1)]
	var over: int = 0
	for value: float in sorted:
		if value > 16.6:
			over += 1
	print("  monitor         TIME_PROCESS %.2f ms (updated ~1/s, trend only)" % [
		float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0])
	print("  frame time      p50 %.2f ms  p95 %.2f ms  max %.2f ms  (%d samples in chains)" % [
		p50, p95, sorted[sorted.size() - 1], sorted.size()])
	print("  over 16.6 ms    %d of %d frames (%.1f %%)" % [over, sorted.size(), 100.0 * float(over) / float(sorted.size())])
	if not _idle_ms.is_empty():
		var idle: Array[float] = []
		for value: float in _idle_ms:
			idle.append(value)
		idle.sort()
		print("  idle frames     p50 %.2f ms  p95 %.2f ms  (%d samples outside chains)" % [
			idle[int(idle.size() * 0.5)], idle[mini(int(idle.size() * 0.95), idle.size() - 1)], idle.size()])
	if p95 > 16.6:
		print("  NOTE: p95 over the 16.6 ms budget for 60 fps on this machine")

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
		var now: int = Time.get_ticks_usec()
		if _last_idle_us > 0 and now - _last_idle_us < 1000000:
			_idle_ms.append(float(now - _last_idle_us) / 1000.0)
		_last_idle_us = now

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
