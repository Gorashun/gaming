extends Node
## Rökprovets drivrutin. Spelar hela slingan genom det RIKTIGA UI:t.
##
## [b]M6-slingan:[/b] kroppsval → Grundstigen → staden → run 1 (lookahead, med
## trappbanken före bossen) → staden (Kistan byggs) → run 2 (policy "none": dör
## deterministiskt) → Marrow och Kistan-valet (med räddningsannonsens stub) →
## staden med en ny hjälte i tavernan → run 3 → staden. Rökprovet fäller om
## den döda hjälten inte hamnar på Gravlunden eller om rostret blir tomt.
##
## [b]Varför den ligger i en egen fil:[/b] [code]tools/smoke_play.gd[/code] körs
## med [code]-s[/code] och kompileras därmed INNAN motorn registrerat
## autoloadarna. Allt som den filen typar mot kompileras samtidigt, och en
## skärm som nämner [code]Juice[/code] fäller då hela bygget med
## "Identifier not found: Juice". Drivrutinen laddas i stället på första
## bildrutan, när [code]/root/Juice[/code] och [code]/root/Settings[/code] finns.

const DEFAULT_MAX_SECONDS: float = 420.0
## Vilken run som spelas med policy "none" (dör alltid) för att bevisa döden,
## Kistan och permadöden.
const DEATH_RUN: int = 2
## Staden besöks efter Grundstigen och efter varje run.
const TOWN_VISITS_TO_FINISH: int = 4
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
## Antal gånger staden visats. Första gången är efter Grundstigen, andra efter
## runnen – och båda ska dumpas.
var _town_visits: int = 0
## Vilken titelknapp rökprovet trycker på. Sätts när titeln lästs.
var _title_action: String = "tutorial"
## Runs som påbörjats i Gropen (inte källaren).
var _runs_started: int = 0
## Hjälten som gick ner i dödsrunnen, för permadödskontrollen.
var _doomed_hero: String = ""
## Slingan är sluten (staden besökt andra gången). Avslutar rökprovet.
var _done: bool = false

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

	# Ren start. Sparfilen OCH profilen ligger i user:// och överlever mellan
	# körningar; rökprovet ska spela en förstagångsspelares väg in i spelet:
	# kroppsval → Grundstigen → staden → en run → staden.
	SaveIO.clear()
	SaveIO.meta_path = "user://smoke_meta.json"
	SaveIO.clear_meta()
	if settings != null:
		settings.call("set_value", &"smith_variant", "", false)

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
	var rooms_seen: Dictionary = {}
	var running: bool = true

	while running and not _done:
		if Time.get_ticks_msec() - started_ms > int(max_seconds * 1000.0):
			_fail("time limit %.0f s reached on screen %s" % [max_seconds, controller.current_screen_name()])
			break
		var screen: GameScreen = controller.current_screen()
		if screen == null:
			await _frames(1)
			continue

		# Character sheetet är en modal och kan ligga över vilken skärm som helst.
		# Den öppnas automatiskt efter runnens första belöning (§4.4).
		if controller.sheet_open():
			await _play_sheet(controller)
			continue
		if controller.bank_picker() != null:
			await _play_bank(controller)
			continue

		match controller.current_screen_name():
			GameController.SCREEN_SMITH:
				await _play_smith(screen as ChooseSmithScreen)
			GameController.SCREEN_TOWN:
				await _play_town(screen as TownScreen)
			GameController.SCREEN_TITLE:
				await _play_title(controller)
			GameController.SCREEN_CORRIDOR:
				var fight: CombatScreen = controller.current_combat()
				if fight != null:
					if not await _play_combat(controller, fight, rooms_seen):
						running = false
					continue
				if not await _play_corridor(controller):
					running = false
			GameController.SCREEN_COMBAT:
				var combat: CombatScreen = controller.current_combat()
				if combat == null:
					await _frames(1)
					continue
				if not await _play_combat(controller, combat, rooms_seen):
					running = false
			GameController.SCREEN_REWARD:
				await _play_reward(screen as RewardScreen)
			GameController.SCREEN_GAMEOVER:
				await _report(screen as GameOverScreen, _rounds, rooms_seen.size())
				# Knappen leder till staden, inte till en ny run: "en run till"
				# är ett tapp DÄRIFRÅN (§A.4 regel 2). Vi följer med tillbaka
				# så att hela slingan bevisas i ett svep.
				var over: GameOverScreen = screen as GameOverScreen
				if is_instance_valid(over) and over.rescue_picker() != null:
					await _play_rescue(controller, over)
				elif is_instance_valid(over):
					over.play_again()
				await _frames(2)
			_:
				await _frames(1)

	_finish()

## Vilken spelare rökprovet är. [code]--policy=none[/code] placerar ingenting
## och dör därför garanterat – enda sättet att få en deterministisk
## dödsskärmdump, eftersom Lookahead vinner våning 1 i ~94 % av fallen
## (DECISIONS 2026-09-21, balanspasset).
func _placement_for(combat: CombatScreen) -> PackedInt32Array:
	if _runs_started == DEATH_RUN and int(_controller.get("_tutorial_room")) < 0:
		return CombatState.empty_placement(combat.state.board.size())
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
	_title_action = "tutorial" if not controller.meta.tutorial_done else "town"
	# Alltid NEW RUN: rökprovet ska spela en känd seed från rum 1, och en
	# sparfil som ligger kvar från förra körningen skulle annars göra både
	# körningen och skärmdumparna beroende av vad som hände sist.
	title.press(_title_action)
	await _frames(2)

## Kroppsvalet: dumpa båda porträtten, välj variant B (så att en icke-standard
## variant faktiskt körs genom hela rökprovet) och gå vidare.
func _play_smith(smith: ChooseSmithScreen) -> void:
	await _frames(6)
	if not is_instance_valid(smith):
		return
	await _shot("00a_choose_smith")
	smith.select("b")
	await _frames(2)
	if is_instance_valid(smith):
		smith.confirm_choice()
	await _frames(2)


## Staden. Öppnar varje plats för en skärmdump och går sedan ned – GO DOWN är
## ett tapp, vilket är hela §A.4 regel 2.
func _play_town(town: TownScreen) -> void:
	await _frames(8)
	if not is_instance_valid(town):
		return
	_town_visits += 1
	var names: Array[String] = ["10_town_square", "40_town_after_run", "50_town_after_death", "60_town_after_third_run"]
	await _shot(names[mini(_town_visits - 1, names.size() - 1)])
	var meta: Meta = _controller.meta
	if meta.roster.active() == null:
		_fail("the tavern has nobody to send down (visit %d)" % _town_visits)
	if _town_visits >= TOWN_VISITS_TO_FINISH:
		_done = true
		return
	if _town_visits == 1:
		for place: String in [TownScreen.PLACE_PIT, TownScreen.PLACE_MARKET,
				TownScreen.PLACE_WALL, TownScreen.PLACE_FORGE, TownScreen.PLACE_TAVERN]:
			if not is_instance_valid(town):
				return
			town.open_place(place)
			await _frames(4)
			if is_instance_valid(town) and town.current_place() == place:
				await _shot("11_town_%s" % place.to_lower())
	elif _town_visits == 2:
		# Kistan nivå 1 om Pips räcker (§5 run 2). Räcker de inte bevisar
		# räddningsannonsen ändå valet.
		town.open_place(TownScreen.PLACE_FORGE)
		await _frames(3)
		if is_instance_valid(town) and meta.can_buy_building(Buildings.CHEST):
			town.buy_building(Buildings.CHEST)
			await _frames(3)
			await _shot("41_town_chest_built")
		# Hjälten ska bära något ner i dödsrunnen, annars har Marrow inget att
		# rädda. Tavernan: ta på det första ur banken som sloten tillåter.
		town.open_place(TownScreen.PLACE_TAVERN)
		await _frames(3)
		var hero: Hero = meta.roster.active()
		for i: int in range(meta.bank.items.size()):
			if hero != null and hero.is_slot_unlocked(meta.bank.items[i].slot) and hero.equipped(meta.bank.items[i].slot) == null:
				town.wear_item("bank", i)
				await _frames(3)
				break
		await _shot("42_town_tavern_wearing")
		if hero == null or hero.equipped_items().is_empty():
			_fail("the hero goes down into the death run carrying nothing")
		_doomed_hero = hero.name if hero != null else ""
	elif _town_visits == 3:
		# Permadöd: namnet på Gravlunden, en ny hjälte vid bordet.
		var fallen: Array = []
		for entry: Dictionary in meta.roster.fallen:
			fallen.append(String(entry.get("name", "")))
		if not fallen.has(_doomed_hero):
			_fail("the hero who died (%s) is not among the fallen %s" % [_doomed_hero, str(fallen)])
		var hero: Hero = meta.roster.active()
		if hero == null or hero.name == _doomed_hero:
			_fail("no new hero was recruited after the death")
		else:
			print("  new hero        %s (level %d, wearing %d, chest holds %d)" % [
				hero.name, hero.level, hero.equipped_items().size(), meta.chest.items.size()])
		town.open_place(TownScreen.PLACE_TAVERN)
		await _frames(4)
		await _shot("51_town_tavern_new_hero")
	if not is_instance_valid(town):
		return
	town.close_place()
	await _frames(2)
	if is_instance_valid(town):
		_runs_started += 1
		town.descend()
	await _frames(2)


## Trappbanken före bossen: skicka upp det första föremålet, behåll resten.
func _play_bank(controller: GameController) -> void:
	await _frames(4)
	var picker: ItemPicker = controller.bank_picker()
	if picker == null:
		return
	await _shot("27_bank_prompt")
	if picker.item_count() <= 0:
		_fail("the bank prompt opened with nothing to send up")
	picker.toggle(0)
	await _frames(2)
	var before: int = controller.meta.bank.items.size()
	var offered: int = picker.item_count()
	# Panelen friges när den svarat: läs allt FÖRE confirm(). En typad
	# referens till en frigjord nod kontrolleras inte och ger segfault.
	picker.confirm()
	picker = null
	await _frames(3)
	if controller.meta.bank.items.size() != before + 1:
		_fail("the bank did not receive the item that was sent up")
	print("  bank            sent 1 of %d up" % offered)


## Striden, var den än står: monterad i korridoren eller ensam i källaren.
func _play_combat(controller: GameController, combat: CombatScreen, rooms_seen: Dictionary) -> bool:
	if combat.is_intro_active():
		# Bossintron äger skärmen i högst 1,2 s och räknas som "resolving", så
		# den måste fångas HÄR och inte i _play_round.
		await _frames(4)
		await _shot("25_boss_intro")
		await _frames(1)
		return true
	if combat.is_resolving():
		await _frames(1)
		return true
	rooms_seen[controller.run.room_index] = true
	_rounds += 1
	return await _play_round(combat)


# --- Korridoren (M5) ---------------------------------------------------

## Hur många steg rökprovet får ta på en våning innan vi kallar det en loop.
const CORRIDOR_STEP_GUARD: int = 140
## CORRIDOR_DESIGN §8.1. Båda siffrorna skrivs ut och båda fäller körningen.
const CORRIDOR_BUDGET_MS: float = 90000.0
const MAX_QUIET_STEPS: int = 3
## Korridortiden mäts på EN våning; budgeten gäller hela runnen (tre våningar).
const FLOORS_PER_RUN: int = 3

var _rounds: int = 0
var _corridor_us: int = 0
var _corridor_steps: int = 0
var _quiet_steps: int = 0
var _corridor_guard: int = 0


## Ett drag i korridoren: svara på en fråga, välj en belöning eller ta ett steg.
func _play_corridor(controller: GameController) -> bool:
	var corridor: CorridorScreen = controller.corridor()
	if corridor == null:
		await _frames(1)
		return true
	var view: CorridorView = corridor.view()
	if view == null or view.map == null:
		await _frames(1)
		return true

	var in_basement: bool = _controller != null and int(_controller.get("_tutorial_room")) >= 0
	if not _taken.has("20_corridor") and not in_basement:
		await _frames(4)
		await _shot("20_corridor")
	if in_basement and not _taken.has("08_basement_corridor"):
		await _frames(4)
		await _shot("08_basement_corridor")

	var reward: CorridorReward = corridor.reward()
	if reward != null and reward.visible:
		await _frames(6)
		await _shot("09_basement_reward" if in_basement else "26_reward_in_corridor")
		if reward.option_count() <= 0:
			_fail("the corridor reward showed zero options")
			return false
		reward.choose(0)
		await _frames(3)
		return true

	var prompt: CorridorPrompt = corridor.prompt()
	if prompt != null and prompt.visible:
		var kind: String = String(prompt.get_meta(&"kind", ""))
		await _frames(4)
		await _shot("2%d_%s_prompt" % [2 if kind == "trap" else 7, kind])
		prompt.press(0)
		await _frames(3)
		return true

	_corridor_guard += 1
	if _corridor_guard > CORRIDOR_STEP_GUARD:
		_fail("the corridor never reached the boss (%d steps)" % _corridor_guard)
		return false

	var actions: Dictionary = view.map.available_actions()
	if actions.is_empty():
		await _frames(1)
		return true
	if actions.size() > 1 and not _taken.has("21_junction"):
		await _frames(3)
		await _shot("21_junction")

	# Källaren går genom samma korridor sedan M5.5, men CORRIDOR_DESIGN §8.1:s
	# budget gäller VÅNING 1. Tutorialens sju korta rum räknas därför inte in –
	# annars mäter siffran två olika saker och slutar betyda något.
	var in_tutorial: bool = _controller != null and int(_controller.get("_tutorial_room")) >= 0
	var started: int = Time.get_ticks_usec()
	await view.step(_corridor_pick(actions))
	if not in_tutorial:
		_corridor_us += Time.get_ticks_usec() - started
		_corridor_steps += 1
		_quiet_steps = maxi(_quiet_steps, view.max_steps_without_event())
	return true


## Policy: alltid mot "fight" om det går. Den värsta vägen i stegbudgeten är
## inte den intressanta här – den mest spelade är.
static func _corridor_pick(actions: Dictionary) -> String:
	for action: String in [CorridorMap.ACTION_LEFT, CorridorMap.ACTION_RIGHT, CorridorMap.ACTION_FORWARD]:
		var info: Dictionary = actions.get(action, {}) as Dictionary
		if String(info.get("sign", "")) == CorridorMap.SIGN_FIGHT:
			return action
	if actions.has(CorridorMap.ACTION_FORWARD):
		return CorridorMap.ACTION_FORWARD
	return String(actions.keys()[0])


func _play_sheet(controller: GameController) -> void:
	await _frames(8)
	var sheet: CharacterSheet = controller.character_sheet()
	if sheet == null:
		return
	await _shot("30_character_sheet_town" if sheet.in_town else "30_character_sheet")
	if is_instance_valid(sheet):
		sheet.close_sheet()
	await _frames(3)

func _play_round(combat: CombatScreen) -> bool:
	# Tutorialens tips och kritpil försvinner vid första handling (§B.2), så
	# rummets skärmdump måste tas INNAN tärningarna placeras.
	var room: int = int(_controller.get("_tutorial_room")) if _controller != null else -1
	if room >= 0:
		await _frames(4)
		await _shot("0%d_tutorial_room_%d" % [room + 1, room + 1])

	var placement: PackedInt32Array = _placement_for(combat)
	for slot: int in range(placement.size()):
		if placement[slot] < 0:
			continue
		if not combat.place(placement[slot], slot):
			_fail("could not place die %d in slot %d" % [placement[slot], slot])
	await _frames(3)
	if room < 0:
		var prefix: String = "23_corridor_combat"
		await _shot("%s_before_confirm" % prefix)
		# Hjälp-lagret: sex callouts samtidigt, allt tänt på en gång (§6).
		if not _taken.has("03b_combat_help"):
			combat.open_help()
			await _frames(6)
			await _shot("03b_combat_help")
			var layer: Node = combat.get_node_or_null("HelpLayer")
			if layer != null:
				layer.call("close")
			await _frames(2)

	combat.confirm()
	# Mitt i kedjan, och medvetet SENT i den: number pops och träffblixtar
	# kommer av damage_dealt, som ligger efter de första tärningarna
	# (UI_GUIDE §12.3 rad 6 ligger på 876 ms).
	await _seconds(1.0)
	if is_instance_valid(combat) and combat.is_resolving():
		await _shot("24_combat_mid_chain")

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

## Marrow och Kistan: välj ett föremål, ta räddningsannonsen (stub, ingen SDK)
## och välj ett till om det finns, bekräfta.
func _play_rescue(controller: GameController, over: GameOverScreen) -> void:
	var picker: ItemPicker = over.rescue_picker()
	var before_max: int = picker.max_select()
	await _shot("36_death_chest_choice")
	var ads: Array[int] = [0]
	controller.rescue_offer_requested.connect(func() -> void: ads[0] += 1, CONNECT_ONE_SHOT)
	# Annonsknappen: frivillig, en plats till.
	picker.secondary_pressed.emit()
	await _frames(2)
	if ads[0] != 1:
		_fail("rescue_offer_requested was not emitted")
	if picker.max_select() != before_max + 1:
		_fail("the rescue ad did not add a slot (%d -> %d)" % [before_max, picker.max_select()])
	for i: int in range(mini(picker.max_select(), picker.item_count())):
		picker.toggle(i)
	await _frames(2)
	await _shot("37_death_chest_chosen")
	var chosen: int = picker.selected().size()
	var offered: int = picker.item_count()
	var capacity: int = picker.max_select()
	var chest_before: int = controller.meta.chest.items.size()
	# Skärmen byts när valet bekräftats: läs allt FÖRE confirm().
	picker.confirm()
	picker = null
	await _frames(4)
	print("  chest           rescued %d of %d (capacity %d incl. ad)" % [chosen, offered, capacity])
	# Den nya hjälten tar på sig det bästa ur Kistan, så Kistan kan ha färre
	# föremål än som räddades – men inte fler, och inte om inget räddades.
	var worn: int = controller.meta.roster.active().equipped_items().size() if controller.meta.roster.active() != null else 0
	if chosen > 0 and controller.meta.chest.items.size() + worn < chest_before + 1:
		_fail("the rescued items never reached the chest or the new hero")


func _report(over: GameOverScreen, rounds_played: int, rooms_seen: int) -> void:
	await _frames(8)
	if not is_instance_valid(over):
		_fail("the gameover screen vanished before it was read")
		return
	var summary: Dictionary = over.summary()
	var won: bool = bool(summary.get("won", false))
	await _shot("35_win" if won else "35_death")
	var score: Dictionary = summary.get("score", {}) as Dictionary
	print("")
	print("Run over: %s  (run %d)" % ["WIN" if won else "DEATH", _runs_started])
	print("  room reached    %d" % int(summary.get("room_reached", 0)))
	print("  rooms cleared   %d" % int(summary.get("rooms_cleared", 0)))
	print("  best chain      %d" % int(summary.get("best_chain", 0)))
	print("  hp left         %d" % int(summary.get("hp_left", 0)))
	print("  meta score      %d" % int(score.get("total", 0)))
	print("  rounds played   %d" % rounds_played)
	print("  rooms visited   %d" % rooms_seen)
	print("  juice calls     %d   haptic calls %d" % [
		(juice.calls.size() if juice != null else 0), Haptics.calls.size()])
	var hero: Dictionary = summary.get("hero", {}) as Dictionary
	if not hero.is_empty():
		print("  hero            %s level %d%s" % [String(hero.get("name", "")), int(hero.get("level", 1)),
			"  +%d XP, %d secured" % [int(hero.get("xp", 0)), int(hero.get("secured", 0))] if won else ""])
	if _runs_started <= 1:
		_report_corridor()
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

## CORRIDOR_DESIGN §8.1:s två siffror. Båda fäller körningen om de spricker.
func _report_corridor() -> void:
	var floor_ms: float = float(_corridor_us) / 1000.0
	var run_ms: float = floor_ms * float(FLOORS_PER_RUN)
	print("  corridor steps  %d" % _corridor_steps)
	print("  corridor time   %.0f ms on floor 1  →  %.0f ms per run (budget %.0f ms)" % [
		floor_ms, run_ms, CORRIDOR_BUDGET_MS])
	print("  quiet steps     %d (max %d)" % [_quiet_steps, MAX_QUIET_STEPS])
	if _corridor_steps <= 0:
		_fail("no corridor step was taken")
	if run_ms > CORRIDOR_BUDGET_MS:
		_fail("corridor time %.0f ms per run is over the %.0f ms budget" % [run_ms, CORRIDOR_BUDGET_MS])
	if _quiet_steps > MAX_QUIET_STEPS:
		_fail("%d steps without an event (max %d)" % [_quiet_steps, MAX_QUIET_STEPS])


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
