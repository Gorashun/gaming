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

const SCENE_PATHS: Dictionary = {
	SCREEN_TITLE: "res://src/game/title/title_screen.tscn",
	SCREEN_MARCH: "res://src/game/march/march_screen.tscn",
	SCREEN_COMBAT: "res://src/game/combat/combat_screen.tscn",
	SCREEN_REWARD: "res://src/game/reward/reward_screen.tscn",
	SCREEN_GAMEOVER: "res://src/game/gameover/gameover_screen.tscn",
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
	_show(SCREEN_TITLE, {"has_save": SaveIO.has_save()}, {"title_action": _on_title_action})


func _on_title_action(action: String) -> void:
	if action == "continue" and resume_run():
		return
	var forced_seed: int = _cmdline_seed()
	if forced_seed != 0:
		SaveIO.clear()
		start_new_run(forced_seed)
		return
	SaveIO.clear()
	start_new_run(_fresh_seed())


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
	run = RunState.new_run(seed_value)
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
			# "EN RUN TILL" startar direkt, utan omvägen över titeln: den
			# knappen ÄR beslutet (UI_GUIDE §3).
			SaveIO.clear()
			start_new_run(_fresh_seed())
		SCREEN_TITLE:
			pass
		SCREEN_COMBAT:
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
		"best_chain": _best_chain,
	}, {
		"round_finished": _on_round_finished,
		"combat_finished": _on_combat_finished,
	})


func _show_reward() -> void:
	var node: Dictionary = graph.node_at(_node_id)
	var pool: Array[Dictionary] = RunFlow.available_pool(Content.reward_pool(), _taken_ids)
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
	_show(SCREEN_GAMEOVER, summary)
	run_over.emit(_run_won, summary)


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
		if String(event.get("t", "")) == "player_died":
			_killed_by = String(event.get("killed_by", ""))
	_autosave(SCREEN_COMBAT)
	round_autosaved.emit(state.round_number, chain)


func _on_combat_finished(won: bool, state: CombatState) -> void:
	run.combat = state
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
