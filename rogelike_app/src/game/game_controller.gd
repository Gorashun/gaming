class_name GameController
extends Node
## Äger runnen och byter skärm. Enda noden som rör [SaveIO].
##
## [b]Ansvarsgräns:[/b] controllern innehåller ingen regel. Möten, Andrum,
## belöningstabellens våningsnyckel och nodgrafen ligger i [RunFlow],
## [RunGraph] och [Rewards]; controllern bestämmer bara vilken skärm som visas
## och när det autosparas.
##
## [b]Autosave[/b] (GAME_DESIGN §1): efter varje [code]round_end[/code] och efter
## varje belöningsval. Sparfilen skrivs alltid vid en rundgräns, aldrig mitt i en
## kedja, så att en återupptagen run börjar på ett kast som redan är draget och
## synligt. Slumpströmmens position sparas med, vilket gör återupptagningen
## byte-identisk med en run som aldrig kraschade.

const SCREEN_TITLE: String = "TITLE"
const SCREEN_MARCH: String = "MARCH"
const SCREEN_COMBAT: String = "COMBAT"
const SCREEN_REWARD: String = "REWARD"
const SCREEN_GAMEOVER: String = "GAMEOVER"
## Staden (M2.5). Tillfällig menyversion, se [TownScreen].
const SCREEN_TOWN: String = "TOWN"
## Kroppsvalet vid första start (M2.5).
const SCREEN_SMITH: String = "SMITH"

const SCENE_PATHS: Dictionary = {
	SCREEN_TITLE: "res://src/game/title/title_screen.tscn",
	SCREEN_MARCH: "res://src/game/march/march_screen.tscn",
	SCREEN_COMBAT: "res://src/game/combat/combat_screen.tscn",
	SCREEN_REWARD: "res://src/game/reward/reward_screen.tscn",
	SCREEN_GAMEOVER: "res://src/game/gameover/gameover_screen.tscn",
	SCREEN_TOWN: "res://src/game/town/town_screen.tscn",
	SCREEN_SMITH: "res://src/game/smith/choose_smith_screen.tscn",
}

## M1 spelar bara våning 1 (GAME_DESIGN §1: "M1 använder bara våning 1").
const M1_FLOOR: int = 1
## Inställningsmodalen. Ligger ovanpå skärmen, inte i stället för den.
const SETTINGS_SCENE: String = "res://src/game/settings/settings_screen.tscn"

## Skärmen har bytts. Smoke-scriptet lyssnar på den här.
signal screen_changed(screen_name: String)
## En runda är resolvad och autosparad.
signal round_autosaved(round_number: int, chain_damage: int)
## Runnen är slut. [param won] är false vid död.
signal run_over(won: bool, summary: Dictionary)

@onready var _world_root: Node2D = $World/WorldRoot
@onready var _screen_root: Control = $ChalkUI/UiRoot/ScreenRoot
@onready var _modal_root: Control = $ChalkUI/UiRoot/ModalRoot

var run: RunState = null
var graph: RunGraph = null
var rng: Rng = null
## Profilen mellan runs: Pips, Kodex, kritstreck, [Reveal]. Laddas en gång vid
## start och skrivs vid varje förändring.
var meta: Meta = null

## Tutorialvåningens rumsindex, eller -1 när vi spelar en riktig run.
var _tutorial_room: int = -1
## "Första gången"-nycklar runden visat, betalas ut vid runnens slut.
var _run_firsts: Array[String] = []
## Vad staden ska säga när spelaren kommer tillbaka (Marrows replik, Pips).
var _arrival: Dictionary = {}

var _screen: GameScreen = null
var _screen_name: String = ""
var _node_id: String = ""
var _rooms_cleared: int = 0
var _best_chain: int = 0
var _taken_ids: Array = []
var _run_won: bool = false
## Vad som dödade spelaren, ur [code]player_died.killed_by[/code]. Död-skärmen
## ska kunna svara på frågan "vad var det som tog mig" (UI_GUIDE §3).
var _killed_by: String = ""
var _settings_modal: Control = null


func _ready() -> void:
	# Skärmskaket flyttar BÅDA lagren: pixelvärlden och kritan ska skaka
	# tillsammans, annars glider fienden ifrån sin HP-bar.
	Juice.register_shake_layer($World)
	Juice.register_shake_layer($ChalkUI)
	meta = SaveIO.load_meta()
	boot()


## Startordningen (M2.5): kroppsval → titel → tutorial → staden → run → staden.
##
## Kroppsvalet ligger [b]först[/b] och inte i en inställningsmeny: figuren syns
## i varje strid, och att välja den är det första beslut spelet ber om
## (DECISIONS 2026-09-21).
func boot() -> void:
	# Språket sätts FÖRE första skärmen. Godot väljer annars OS-språket, och
	# en svensk telefon fick svenska utan att någon valt det
	# (DECISIONS 2026-09-21). Engelska är källspråket; svenska är ett val.
	TranslationServer.set_locale(Settings.effective_locale())
	if Settings.smith_variant == "":
		show_smith_choice()
		return
	show_title()


func show_smith_choice() -> void:
	_show(SCREEN_SMITH, {"variant": Settings.smith_variant}, {"chosen": _on_smith_chosen})


func _on_smith_chosen(_variant: String) -> void:
	show_title()


# ---------------------------------------------------------------------------
# Androids livscykel (M4, docs/ANDROID.md §6)
# ---------------------------------------------------------------------------

## Bakåtknappens svar per skärm. Sträng i stället för enum så att den går att
## logga och jämföra i ett test utan att dra in hela controllern.
const BACK_IGNORE: String = "ignore"
const BACK_CLOSE_SETTINGS: String = "close_settings"
const BACK_SKIP_PLAYBACK: String = "skip_playback"
const BACK_OPEN_SETTINGS: String = "open_settings"
const BACK_TO_TITLE: String = "to_title"


## [b]Ren funktion.[/b] Vad Androids bakåtknapp ska göra.
##
## [b]Regeln som inte får brytas:[/b] ingen gren returnerar "avsluta". Godots
## [code]application/config/quit_on_go_back[/code] är avstängd i project.godot
## just därför – standardbeteendet är att appen tyst stänger sig mitt i en run,
## vilket är det värsta en mobilapp kan göra med ett obekräftat val.
##
## [param screen_name] är en av [code]SCREEN_*[/code]. [param settings_open]
## och [param resolving] är skärmens läge.
static func back_action(screen_name: String, settings_open: bool, resolving: bool) -> String:
	# Modalen ligger överst och äger därför bakåtknappen.
	if settings_open:
		return BACK_CLOSE_SETTINGS
	match screen_name:
		SCREEN_COMBAT:
			# Mitt i kedjan betyder bakåt samma sak som en tapp på skärmen:
			# hoppa till slutet. Att öppna en modal ovanpå en pågående
			# uppspelning skulle frysa juicen bakom ett halvgenomskinligt lager.
			return BACK_SKIP_PLAYBACK if resolving else BACK_OPEN_SETTINGS
		SCREEN_MARCH, SCREEN_REWARD:
			# Det finns inget "tillbaka" i en roguelike-marsch. Pausmenyn är
			# det ärliga svaret: den har språk, ljud och nollställning.
			return BACK_OPEN_SETTINGS
		SCREEN_GAMEOVER:
			return BACK_TO_TITLE
		_:
			# Titeln är rotskärmen. Bakåt därifrån gör ingenting alls.
			return BACK_IGNORE


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			handle_back_request()
		NOTIFICATION_APPLICATION_PAUSED:
			# Android kan döda processen utan ett andra varsel. Allt som ska
			# överleva måste ligga på disk när den här returnerar.
			on_application_paused()
		NOTIFICATION_APPLICATION_RESUMED:
			on_application_resumed()


## Kör bakåtknappens beslut. Returnerar vad som gjordes, för rökprov och test.
func handle_back_request() -> String:
	var combat: CombatScreen = _screen as CombatScreen
	var action: String = back_action(_screen_name, settings_open(), combat != null and combat.is_resolving())
	match action:
		BACK_CLOSE_SETTINGS:
			if _settings_modal != null and is_instance_valid(_settings_modal) and _settings_modal.has_method("close"):
				_settings_modal.call("close")
		BACK_SKIP_PLAYBACK:
			combat.skip_playback()
		BACK_OPEN_SETTINGS:
			open_settings()
		BACK_TO_TITLE:
			show_title()
	return action


## Appen går i bakgrunden: spara och tysta ljudet.
##
## Sparningen hoppas över mitt i en runda (se [method can_autosave]). Det är
## inte lathet: ett sparfilsskrivande mitt i en kedja skulle lägga en
## slumpström som redan rullat vidare bredvid ett stridsläge från rundans
## början, och den runnen skulle inte gå att återuppta identiskt.
func on_application_paused() -> void:
	if can_autosave():
		_autosave()
	Juice.suspend_audio(true)


func on_application_resumed() -> void:
	Juice.suspend_audio(false)


## Får sparfilen skrivas just nu? Allt utom en påbörjad stridsrunda.
func can_autosave() -> bool:
	if run == null or graph == null:
		return false
	if _screen_name != SCREEN_COMBAT:
		return true
	var combat: CombatScreen = _screen as CombatScreen
	return combat == null or combat.is_safe_to_autosave()


## Titelskärmen. Alltid först, även med en tvingad seed: rökprovet och en
## spelare ska gå exakt samma väg in i spelet.
func show_title() -> void:
	_show(SCREEN_TITLE, {
		"has_save": SaveIO.has_save(),
		"tutorial_done": meta.tutorial_done,
	}, {"title_action": _on_title_action})


func _on_title_action(action: String) -> void:
	match action:
		"continue":
			if resume_run():
				return
		"tutorial":
			start_tutorial()
			return
		"skip_tutorial":
			# Hoppbar från titeln och från inställningarna (§B.2). En spelare
			# som hoppar över har per definition allt avslöjat.
			meta.tutorial_done = true
			meta.reveal = Reveal.all_on()
			SaveIO.save_meta(meta)
			show_town()
			return
		"town":
			show_town()
			return
	SaveIO.clear()
	start_new_run(next_seed())


## Seeden nästa run ska köras med. [code]--pipwreck-seed=N[/code] tvingar en
## känd run; annars är den färsk.
func next_seed() -> int:
	var forced: int = _cmdline_seed()
	return forced if forced != 0 else _fresh_seed()


# ---------------------------------------------------------------------------
# Staden (M2.5)
# ---------------------------------------------------------------------------

## Staden är navet mellan runs. Död/vinst-skärmens knapp leder hit, och
## [code]GO DOWN[/code] ligger i tumzonen så att "en run till" är ett tapp.
func show_town() -> void:
	_tutorial_room = -1
	var arrival: Dictionary = _arrival.duplicate()
	_arrival = {}
	_show(SCREEN_TOWN, {
		"meta": meta,
		"seed": next_seed(),
		"arrival": arrival,
	}, {"go_down": _on_go_down})


func _on_go_down(seed_value: int) -> void:
	SaveIO.clear()
	start_new_run(seed_value)


# ---------------------------------------------------------------------------
# Tutorialvåning 0 (M2.5)
# ---------------------------------------------------------------------------

## Startar Grundstigen. Sju rum, spelas exakt en gång (TOWN_AND_ONBOARDING §B.2).
func start_tutorial() -> void:
	run = RunState.new_run(0)
	rng = run.make_rng()
	graph = RunGraph.generate_floor(M1_FLOOR, rng)
	_rooms_cleared = 0
	_best_chain = 0
	_taken_ids = []
	_run_won = false
	_killed_by = ""
	run.floor_index = 0
	_tutorial_room = 0
	run.combat = Tutorial.prepare_room(run.combat, 0, rng)
	Tutorial.apply_reveal(meta.reveal, 0)
	SaveIO.save_meta(meta)
	_show_tutorial_room()


func _show_tutorial_room() -> void:
	var node: Dictionary = Tutorial.node_for(_tutorial_room)
	_node_id = String(node["id"])
	run.room_index = int(node["room"])
	_show(SCREEN_COMBAT, {
		"state": run.combat,
		"rng": rng,
		"node": node,
		"reveal": meta.reveal,
		"tutorial_room": _tutorial_room,
		"best_chain": _best_chain,
	}, {
		"round_finished": _on_round_finished,
		"combat_finished": _on_combat_finished,
	})


func _advance_tutorial(state: CombatState) -> void:
	run.combat = Resolver.end_combat(state)
	_rooms_cleared += 1
	var reward: Dictionary = Tutorial.reward_for(_tutorial_room)
	_tutorial_room += 1
	if _tutorial_room >= Tutorial.room_count():
		_finish_tutorial()
		return
	Tutorial.apply_reveal(meta.reveal, _tutorial_room)
	SaveIO.save_meta(meta)
	run.combat = Tutorial.prepare_room(run.combat, _tutorial_room, rng)
	if reward.is_empty():
		_show_tutorial_room()
		return
	_show(SCREEN_REWARD, {
		"state": run.combat,
		"options": [reward],
		"node": Tutorial.node_for(_tutorial_room - 1),
		"breather": false,
	})


func _finish_tutorial() -> void:
	# En färdig spelare har alla flaggor på. Rummen sätter dem en och en, men
	# hoppar spelaren ur mitt i ska hen ändå inte hamna i ett halvt UI.
	meta.tutorial_done = true
	meta.reveal = Reveal.all_on()
	# §A.3: "Efter run 1 (tutorialrunen): staden öppnar. Marknad + Kritvägg."
	# Grundstigen räknas alltså som runnen som låser upp staden, och den betalar
	# som en vinst – men lägger INGET kritstreck: ingen dog där uppe.
	meta.runs = maxi(meta.runs, 1)
	meta.pips += Meta.PIPS_WIN
	SaveIO.save_meta(meta)
	_tutorial_room = -1
	show_town()


# ---------------------------------------------------------------------------
# Inställningar som modal
# ---------------------------------------------------------------------------

## Öppnar inställningarna OVANPÅ den skärm som är igång. Rundan, placeringen och
## uppspelningen står kvar orörda bakom modalen.
func open_settings() -> void:
	if _settings_modal != null and is_instance_valid(_settings_modal):
		return
	var packed: PackedScene = ResourceLoader.load(SETTINGS_SCENE) as PackedScene
	if packed == null:
		push_error("GameController: kunde inte ladda %s" % SETTINGS_SCENE)
		return
	_settings_modal = packed.instantiate() as Control
	if _settings_modal == null:
		return
	_modal_root.add_child(_settings_modal)
	_settings_modal.connect("closed", _on_settings_closed)


func settings_open() -> bool:
	return _settings_modal != null and is_instance_valid(_settings_modal)


func _on_settings_closed() -> void:
	_settings_modal = null
	# Sparfilen kan ha nollställts i modalen ("Reset save"). Står vi på
	# titelskärmen ska CONTINUE försvinna direkt, annars ljuger knappen.
	# Villkoret jämför mot vad titeln BYGGDES med: att bygga om den varje gång
	# modalen stängs skulle frigöra skärmen under fötterna på den som öppnade
	# modalen (rökprovet fastnade på exakt det).
	var title: TitleScreen = _screen as TitleScreen
	if _screen_name == SCREEN_TITLE and title != null and title.has_save() != SaveIO.has_save():
		show_title()


# ---------------------------------------------------------------------------
# Runnens livscykel
# ---------------------------------------------------------------------------

func start_new_run(seed_value: int) -> void:
	_tutorial_room = -1
	_run_firsts = []
	run = RunState.new_run(seed_value)
	# Smedjans laddning ligger i profilen och läggs på det färska tillståndet.
	# Byte och omordning, aldrig tillägg – [Forge] garanterar det.
	run.combat = Forge.apply_loadout(run.combat, meta.loadout)
	rng = run.make_rng()
	graph = RunGraph.generate_floor(M1_FLOOR, rng)
	_node_id = graph.start_id
	_rooms_cleared = 0
	_best_chain = 0
	_taken_ids = []
	_run_won = false
	_killed_by = ""
	run.floor_index = M1_FLOOR
	run.room_index = int(graph.node_at(_node_id).get("room", 1))
	_autosave()
	_show_march([_node_id])


## Läser sparfilen och fortsätter. Returnerar false när det inte finns någon
## användbar sparfil – då startar [method _ready] en ny run i stället för att
## krascha. Det är kontraktet i [SaveIO].
func resume_run() -> bool:
	var data: Dictionary = SaveIO.load_dict()
	if data.is_empty():
		return false
	var loaded: RunState = RunState.from_dict(data)
	if loaded == null or loaded.combat == null:
		return false

	run = loaded
	rng = run.make_rng()
	var meta: Dictionary = run.meta
	var graph_data: Dictionary = meta.get("graph", {}) as Dictionary
	if graph_data.is_empty():
		return false
	graph = RunGraph.from_dict(graph_data)
	_node_id = String(meta.get("node_id", graph.start_id))
	if not graph.has_node(_node_id):
		return false
	_rooms_cleared = int(meta.get("rooms_cleared", 0))
	_best_chain = int(meta.get("best_chain", 0))
	_taken_ids = (meta.get("taken_ids", []) as Array).duplicate()
	_run_won = bool(meta.get("run_won", false))

	var phase: String = String(meta.get("phase", SCREEN_MARCH))
	match phase:
		SCREEN_COMBAT:
			# Återupptas vid rundans början: kastet och intents är redan dragna
			# och ligger i det sparade CombatState.
			_show_combat()
		SCREEN_REWARD:
			_show_reward()
		SCREEN_GAMEOVER:
			_show_gameover()
		_:
			_show_march(graph.next_ids(_node_id) if bool(meta.get("node_cleared", false)) else [_node_id])
	return true


func _fresh_seed() -> int:
	# Seedvalet i sig är inte en del av simuleringen och får därför komma
	# utifrån. Allt efter detta går genom Rng (GAME_DESIGN §6.10: seeden visas).
	return abs(int(Time.get_unix_time_from_system() * 1000.0) ^ int(Time.get_ticks_usec()))


## [code]--pipwreck-seed=N[/code] efter [code]--[/code] tvingar en känd run.
## Smoke-testet och buggrapporter använder den.
func _cmdline_seed() -> int:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pipwreck-seed="):
			return int(arg.split("=")[1])
	return 0


# ---------------------------------------------------------------------------
# Skärmbyten
# ---------------------------------------------------------------------------

func current_screen_name() -> String:
	return _screen_name


func current_screen() -> GameScreen:
	return _screen


## Byter skärm. [b]Alltid uppskjutet ett bildrutesteg.[/b]
##
## Skälet är konkret: skärmbytet utlöses av [signal CombatScreen.combat_finished],
## som emitteras inifrån [method EventPlayer._process]. Att då riva ned hela
## stridsscenen och bygga upp belöningsskärmen mitt i motorns process-iteration
## kraschade Godot 4.6 reproducerbart (signal 11 direkt efter rummets sista
## runda). Den gamla skärmen rivs direkt så att ingen kan nå en halvdöd scen,
## bygget sker i nästa bildruta.
func _show(screen_name: String, ctx: Dictionary, connections: Dictionary = {}) -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.teardown()
		_screen.queue_free()
	_screen = null
	_screen_name = ""
	_install_screen.call_deferred(screen_name, ctx, connections)


func _install_screen(screen_name: String, ctx: Dictionary, connections: Dictionary) -> void:
	var path: String = String(SCENE_PATHS.get(screen_name, ""))
	var packed: PackedScene = ResourceLoader.load(path) as PackedScene
	if packed == null:
		push_error("GameController: kunde inte ladda skärmen %s (%s)" % [screen_name, path])
		return
	_screen = packed.instantiate() as GameScreen
	if _screen == null:
		push_error("GameController: %s har inte GameScreen som rot" % path)
		return
	_screen_name = screen_name
	_screen_root.add_child(_screen)
	_screen.screen_done.connect(_on_screen_done.bind(screen_name))
	for signal_name: String in connections:
		_screen.connect(signal_name, connections[signal_name] as Callable)
	_screen.setup(self, _world_root, ctx)
	screen_changed.emit(screen_name)


func _on_screen_done(payload: Dictionary, from_screen: String) -> void:
	match from_screen:
		SCREEN_MARCH:
			_node_id = String(payload.get("node_id", _node_id))
			run.room_index = int(graph.node_at(_node_id).get("room", 1))
			_show_combat()
		SCREEN_REWARD:
			_on_reward_chosen(payload)
		SCREEN_GAMEOVER:
			# "BACK TO CHALKRIM" leder till staden, där GO DOWN redan ligger i
			# tumzonen: en run till är ett tapp därifrån (§A.4 regel 2).
			SaveIO.clear()
			show_town()
		SCREEN_TITLE, SCREEN_COMBAT, SCREEN_TOWN, SCREEN_SMITH:
			pass


func _show_march(options: Array) -> void:
	var typed: Array[String] = []
	for value: Variant in options:
		typed.append(String(value))
	if typed.is_empty():
		# Inget kvar att marschera till: våningen är slut.
		_show_gameover()
		return
	_save_phase(SCREEN_MARCH, typed.size() > 1 or typed[0] != _node_id)
	_show(SCREEN_MARCH, {
		"graph": graph,
		"from_id": _node_id,
		"options": typed,
		"rooms_cleared": _rooms_cleared,
	})


func _show_combat() -> void:
	if run.combat == null:
		push_error("GameController: ingen CombatState att strida med")
		return
	var node: Dictionary = graph.node_at(_node_id)
	# Har rummet inte börjat ännu saknar staten fiender; då drar vi mötet och
	# första kastet här (all slump före bekräftelse, GAME_DESIGN §6.4).
	if run.combat.enemies.is_empty() or run.combat.is_won():
		run.combat = RunFlow.start_room(run.combat, node, rng)
		_autosave(SCREEN_COMBAT)
	_show(SCREEN_COMBAT, {
		"state": run.combat,
		"rng": rng,
		"node": node,
		"graph": graph,
		"reveal": meta.reveal,
		"tutorial_room": -1,
		"best_chain": _best_chain,
	}, {
		"round_finished": _on_round_finished,
		"combat_finished": _on_combat_finished,
	})


func _show_reward() -> void:
	var node: Dictionary = graph.node_at(_node_id)
	# Poolen är startpoolen PLUS det spelaren köpt loss på Skrotmarknaden.
	# Marknaden lägger till innehåll, aldrig siffror (§A.3).
	var pool: Array[Dictionary] = RunFlow.available_pool(
		Content.unlocked_pool(meta.unlocked), _taken_ids)
	var options: Array[Dictionary] = Rewards.generate(pool, rng, RunFlow.reward_floor_key(node))
	_show(SCREEN_REWARD, {
		"state": run.combat,
		"options": options,
		"node": node,
		"breather": RunFlow.grants_breather(node),
	})


func _show_gameover() -> void:
	var summary: Dictionary = build_summary()
	_save_phase(SCREEN_GAMEOVER, true)
	summary["award"] = _award_run()
	_show(SCREEN_GAMEOVER, summary)
	run_over.emit(_run_won, summary)


## Betalar ut Pips och sätter kritstrecket (§A.3). Körs [b]en gång per run[/b],
## precis före död/vinst-skärmen, och lämnar över resultatet till staden så att
## Marrow kan säga sin rad med rätt siffra bredvid.
func _award_run() -> Dictionary:
	var boss_killed: bool = _run_won
	var award: Dictionary = meta.award_run(
		_rooms_cleared, boss_killed, _run_won, _run_firsts,
		_best_chain, int((build_summary()["score"] as Dictionary)["total"]))
	SaveIO.save_meta(meta)
	_arrival = {
		"killed_by": _killed_by,
		"won": _run_won,
		"seed": run.seed_value if run != null else 0,
		"pips_earned": int(award["earned"]),
	}
	_run_firsts = []
	return award


## Allt död/vinst-skärmen visar. Poängen räknas i [MetaScore], inte här.
func build_summary() -> Dictionary:
	var hp_left: int = run.combat.player_hp if run.combat != null else 0
	var node: Dictionary = graph.node_at(_node_id)
	return {
		"won": _run_won,
		"rooms_cleared": _rooms_cleared,
		"room_reached": int(node.get("room", 1)),
		"best_chain": _best_chain,
		"killed_by": _killed_by,
		"hp_left": maxi(0, hp_left),
		"seed": run.seed_value,
		"score": MetaScore.breakdown(_rooms_cleared, _best_chain, _run_won, maxi(0, hp_left)),
	}


# ---------------------------------------------------------------------------
# Stridens återkopplingar
# ---------------------------------------------------------------------------

func _on_round_finished(state: CombatState, result: ResolveResult) -> void:
	run.combat = state
	var chain: int = MetaScore.chain_damage(result.events)
	_best_chain = maxi(_best_chain, chain)
	for event: Dictionary in result.events:
		match String(event.get("t", "")):
			"player_died":
				_killed_by = String(event.get("killed_by", ""))
			"combo_formed":
				_note_combo(String(event.get("kind", "")))
			"house_bonus":
				_note_combo("HOUSE")
	if _tutorial_room < 0:
		_autosave(SCREEN_COMBAT)
	round_autosaved.emit(state.round_number, chain)


## Kodexen och engångsbonusarna (§A.3). Bokförs per runda, betalas ut i
## [method _award_run] – annars skulle ett omkast kunna betala två gånger.
func _note_combo(kind: String) -> void:
	if kind == "" or kind == "NONE":
		return
	if meta.see_combo(kind):
		_run_firsts.append(kind)
	for enemy: Enemy in run.combat.enemies:
		meta.see_enemy(enemy.id)


func _on_combat_finished(won: bool, state: CombatState) -> void:
	run.combat = state
	if _tutorial_room >= 0:
		# Träningshjulen: i våning 0 kan man inte dö, så "not won" kan bara
		# betyda att rummet är oavslutat. Vi går vidare oavsett.
		_advance_tutorial(state)
		return
	if not won:
		_run_won = false
		_show_gameover()
		return

	_rooms_cleared += 1
	var node: Dictionary = graph.node_at(_node_id)
	run.combat = RunFlow.finish_room(state, node)

	if RunFlow.is_boss(node):
		# M1 slutar efter våning 1:s boss. GAME_DESIGN §1 fortsätter med
		# FATE_ROLL och våning 2; det är M3-innehåll.
		_run_won = true
		_show_gameover()
		return

	_autosave(SCREEN_REWARD)
	_show_reward()


func _on_reward_chosen(payload: Dictionary) -> void:
	if _tutorial_room >= 0:
		# Tutorialens kort är berättande; förändringen ligger i rumsdatan.
		_show_tutorial_room()
		return
	var choice: Dictionary = payload.get("choice", {}) as Dictionary
	if not choice.is_empty():
		run.combat = RewardApply.apply(run.combat, choice, payload.get("target", {}) as Dictionary)
		_taken_ids.append(String(choice.get("id", "")))
	_autosave(SCREEN_MARCH)
	_show_march(graph.next_ids(_node_id))


# ---------------------------------------------------------------------------
# Sparning
# ---------------------------------------------------------------------------

func _save_phase(phase: String, node_cleared: bool) -> void:
	if run == null:
		return
	run.meta["phase"] = phase
	run.meta["node_cleared"] = node_cleared
	_autosave()


func _autosave(phase: String = "") -> void:
	if run == null:
		return
	if phase != "":
		run.meta["phase"] = phase
	run.store_rng(rng)
	SaveIO.save_run(run, {
		"graph": graph.to_dict(),
		"node_id": _node_id,
		"rooms_cleared": _rooms_cleared,
		"best_chain": _best_chain,
		"taken_ids": _taken_ids.duplicate(),
		"run_won": _run_won,
	})
