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
## Korridoren (M5). Hela våningen: utforskning, strid i de nedre 55 % och
## belöningsvalet på golvet. Ersätter M1:s marsch-remsa.
const SCREEN_CORRIDOR: String = "CORRIDOR"
## Striden. [b]Aldrig en egen skärm sedan M5.5[/b] – striden monteras alltid som
## ett barn i korridoren. Konstanten lever kvar som [b]sparfilens fas[/b]: den
## säger att en återupptagen run ska montera om sin strid på samma ruta.
const SCREEN_COMBAT: String = "COMBAT"
## Belöningen. Visas i korridoren; konstanten är fas i sparfilen och reservväg
## om korridoren av någon anledning inte står framme.
const SCREEN_REWARD: String = "REWARD"
const SCREEN_GAMEOVER: String = "GAMEOVER"
## Staden Chalkrim som förstapersons torg (M5, CORRIDOR_DESIGN §5).
const SCREEN_TOWN: String = "TOWN"
## Kroppsvalet vid första start (M2.5).
const SCREEN_SMITH: String = "SMITH"

const SCENE_PATHS: Dictionary = {
	SCREEN_TITLE: "res://src/game/title/title_screen.tscn",
	SCREEN_CORRIDOR: "res://src/game/corridor/corridor_screen.tscn",
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
## Character sheetet (M5). Modal precis som inställningarna: den ska gå att
## öppna i korridoren utan att kasta bort kamerans plats i rutnätet.
const SHEET_SCENE: String = "res://src/game/sheet/character_sheet.tscn"

## Skärmen har bytts. Smoke-scriptet lyssnar på den här.
signal screen_changed(screen_name: String)
## En runda är resolvad och autosparad.
signal round_autosaved(round_number: int, chain_damage: int)
## Runnen är slut. [param won] är false vid död.
signal run_over(won: bool, summary: Dictionary)

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
## Rummet har ett loot-val kvar att visa när det berättande kortet är taget.
var _tutorial_loot_pending: bool = false
## Korten som ligger på golvet just nu ÄR loot-valet, inte ett berättande kort.
var _tutorial_loot_open: bool = false
## "Första gången"-nycklar runden visat, betalas ut vid runnens slut.
var _run_firsts: Array[String] = []
## Vad staden ska säga när spelaren kommer tillbaka (Marrows replik, Pips).
var _arrival: Dictionary = {}

var _screen: GameScreen = null
var _screen_name: String = ""
## Korridorskärmen medan den står framme. Den lever hela våningen igenom –
## striden monteras i den, inte i stället för den.
var _corridor: CorridorScreen = null
## Stridsskärmen medan en strid pågår. Den är alltid monterad i korridoren.
var _combat: CombatScreen = null
## Våningens korridorkarta. [b]Sparas med runnen[/b] (map_state), så att en
## återupptagen run hamnar på samma ruta med samma vinkel.
var _map: CorridorMap = null
var _corridor_state: Dictionary = {}
## Noder vars möte redan är vunnet. Avgör om rutan man står på ska prima sina
## egna monster eller nästa rums.
var _cleared_nodes: Dictionary = {}
## Character sheetet öppnas automatiskt efter runnens FÖRSTA belöning – en gång
## per run, aldrig en gång per kort (CORRIDOR_DESIGN §4.4).
var _sheet_shown_this_run: bool = false
var _sheet_modal: Control = null
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
	# M5.5: World-lagret är borta. Korridorens 3D ligger i en SubViewport inuti
	# krit-UI:t, så ett enda skaklager flyttar hela bilden – fienden kan inte
	# längre glida ifrån sitt chip, de sitter i samma träd.
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
	var target: String = _cmdline_start()
	if target != "":
		_boot_debug_start(target)
		return
	if Settings.smith_variant == "":
		show_smith_choice()
		return
	show_title()


# ---------------------------------------------------------------------------
# Felsökningsstart: --pipwreck-start=town|corridor|sheet|tutorial
# ---------------------------------------------------------------------------

## Giltiga mål för [code]--pipwreck-start=[/code].
const START_TOWN: String = "town"
const START_CORRIDOR: String = "corridor"
const START_SHEET: String = "sheet"
## Källaren under smedjan, rum 0.1. Nollställer [member Meta.tutorial_done] så
## att Grundstigen går att spela om – det är enda målet som gör det.
const START_TUTORIAL: String = "tutorial"
const START_TARGETS: Array[String] = [START_TOWN, START_CORRIDOR, START_SHEET, START_TUTORIAL]

const START_PREFIX: String = "--pipwreck-start="


## [b]Ren funktion.[/b] Vilket startmål argumenten begär, eller [code]""[/code].
##
## Läses [b]bara[/b] ur användararumenten efter [code]--[/code], precis som
## [code]--pipwreck-seed[/code]: en spelare ska aldrig kunna hamna här av misstag,
## och webbladdaren skickar dem som [code]args: ['--', '--pipwreck-start=…'][/code].
## Sista flaggan vinner, okända värden ignoreras (flaggan får aldrig fälla starten).
static func parse_start_target(args: PackedStringArray) -> String:
	var found: String = ""
	for arg: String in args:
		if not arg.begins_with(START_PREFIX):
			continue
		var value: String = arg.substr(START_PREFIX.length()).strip_edges().to_lower()
		if START_TARGETS.has(value):
			found = value
	return found


func _cmdline_start() -> String:
	return parse_start_target(OS.get_cmdline_user_args())


## Hoppar förbi kroppsval, titel och tutorial och landar direkt i målskärmen.
##
## Kroppsvalet och tutorialen [b]kvitteras[/b] i stället för att kringgås:
## en profil utan variant får standardkroppen och en oklarad tutorial markeras
## som klar med allt avslöjat, exakt som SKIP TUTORIAL gör (§B.2). Annars skulle
## staden och korridoren visas med ett halvt UI.
func _boot_debug_start(target: String) -> void:
	if Settings.smith_variant == "":
		Settings.set_value(&"smith_variant", Art.SMITH_VARIANT_DEFAULT)
	if target == START_TUTORIAL:
		SaveIO.clear()
		start_tutorial()
		return
	if not meta.tutorial_done:
		meta.tutorial_done = true
		meta.reveal = Reveal.all_on()
		meta.runs = maxi(meta.runs, 1)
		SaveIO.save_meta(meta)
	match target:
		START_CORRIDOR:
			SaveIO.clear()
			start_new_run(next_seed())
		START_SHEET:
			# Sheetet är en modal och behöver en run under sig för att ha något
			# att visa. Anropet skjuts upp så att korridoren hinner monteras –
			# [method _show] bygger skärmen först nästa bildruta.
			SaveIO.clear()
			start_new_run(next_seed())
			_open_sheet_deferred.call_deferred()
		_:
			show_town()


func _open_sheet_deferred() -> void:
	open_character_sheet()


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
		SCREEN_COMBAT, SCREEN_CORRIDOR:
			# Mitt i kedjan betyder bakåt samma sak som en tapp på skärmen:
			# hoppa till slutet. Att öppna en modal ovanpå en pågående
			# uppspelning skulle frysa juicen bakom ett halvgenomskinligt lager.
			return BACK_SKIP_PLAYBACK if resolving else BACK_OPEN_SETTINGS
		SCREEN_REWARD:
			# Det finns inget "tillbaka" i en roguelike. Pausmenyn är det
			# ärliga svaret: den har språk, ljud och nollställning.
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
	var combat: CombatScreen = current_combat()
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
	if _combat == null or not is_instance_valid(_combat):
		return true
	return _combat.is_safe_to_autosave()


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
			# Sparfilen är trasig eller från före korridoren (M5). Kontraktet i
			# [SaveIO] är att det aldrig får krascha; kontraktet här är att
			# spelaren hamnar i staden med GO DOWN i tumzonen, inte i en run hen
			# inte bad om.
			SaveIO.clear()
			if meta.tutorial_done:
				show_town()
			else:
				start_tutorial()
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
	_map = null
	_corridor_state = {}
	var arrival: Dictionary = _arrival.duplicate()
	_arrival = {}
	_show(SCREEN_TOWN, {
		"meta": meta,
		"seed": next_seed(),
		"arrival": arrival,
	}, {
		"go_down": _on_go_down,
		"character_sheet_requested": _on_sheet_requested,
		"settings_requested": open_settings,
	})


func _on_go_down(seed_value: int) -> void:
	SaveIO.clear()
	start_new_run(seed_value)


# ---------------------------------------------------------------------------
# Tutorialvåning 0: källaren under smedjan (M5.5, CORRIDOR_DESIGN §5.2)
# ---------------------------------------------------------------------------

## Startar Grundstigen. Sju rum, spelas exakt en gång (TOWN_AND_ONBOARDING §B.2).
##
## [b]M5.5: källaren är en korridor.[/b] Tutorialen hade en egen platt
## stridsskärm fram till dess, och en spelare som bytte från våning 0 till
## våning 1 bytte samtidigt hela spelets utseende. Nu är det en rak korridor med
## sju kammare, två steg emellan, och exakt samma 45/55-strid, samma chip och
## samma kvitto som en riktig run. Det enda som skiljer är innehållet: fasta
## tärningar, tvingade intents, [Reveal]-flaggor per rum och träningshjulen.
func start_tutorial() -> void:
	run = RunState.new_run(0)
	rng = run.make_rng()
	# Grafen är fortfarande våning 1:s: den rörs inte i källaren, men
	# [method build_summary] och autosparningen typar mot den.
	graph = RunGraph.generate_floor(M1_FLOOR, rng)
	_rooms_cleared = 0
	_best_chain = 0
	_taken_ids = []
	_run_won = false
	_killed_by = ""
	_cleared_nodes = {}
	_sheet_shown_this_run = false
	run.floor_index = 0
	_tutorial_room = 0
	_tutorial_loot_pending = false
	_tutorial_loot_open = false
	_map = Tutorial.corridor_map()
	_corridor_state = _map.to_dict()
	_node_id = String(Tutorial.node_for(0)["id"])
	run.room_index = 1
	run.combat = Tutorial.prepare_room(run.combat, 0, rng)
	Tutorial.apply_reveal(meta.reveal, 0)
	SaveIO.save_meta(meta)
	# M5.8: källaren autosparas som vilken våning som helst. Se
	# [method _enter_tutorial_room] för varför.
	_autosave(SCREEN_CORRIDOR)
	_show_corridor()


## Rummet korridoren just klev in i. Kammarens nod-id ÄR rumsindexet
## (se [method Tutorial.room_index_for]), så kartan behöver inte veta att den
## är en tutorial och tutorialen behöver inte veta att den är en karta.
func _enter_tutorial_room(node_id: String) -> void:
	var index: int = Tutorial.room_index_for(node_id)
	if index < 0:
		return
	_tutorial_room = index
	_node_id = node_id
	run.room_index = int(Tutorial.node_for(index)["room"])
	_refresh_corridor_status()
	Tutorial.apply_reveal(meta.reveal, index)
	SaveIO.save_meta(meta)
	if index > 0:
		run.combat = Tutorial.prepare_room(run.combat, index, rng)
	# [b]Rumsgränsen är en rundgräns[/b] (GAME_DESIGN §1), så sparfilen skrivs
	# med kastet redan draget och synligt. Utan den här raden startade en
	# omladdning om källaren på rum 0.1 – billigt på en telefon, vanligt på web.
	_autosave(SCREEN_COMBAT)
	_mount_combat()


## Rummet är klart. Belöningen visas på golvet i korridoren, precis som i en
## riktig run – tutorialens kort är berättande, så valet är alltid ett kort.
##
## [b]Utom efter rum 0.3[/b] (M5.7): där ligger också ett riktigt loot-val, tre
## sidor ur samma pool som en run, och det visas efter det berättande kortet.
func _advance_tutorial(state: CombatState) -> void:
	run.combat = Resolver.end_combat(state)
	_rooms_cleared += 1
	_cleared_nodes[_node_id] = true
	var reward: Dictionary = Tutorial.reward_for(_tutorial_room)
	_tutorial_loot_pending = Tutorial.has_loot(_tutorial_room)
	_tutorial_loot_open = false
	_autosave(SCREEN_REWARD)
	if _corridor == null or not is_instance_valid(_corridor):
		return
	_corridor.unmount_combat()
	_combat = null
	if reward.is_empty():
		_on_corridor_reward_chosen({}, {})
		return
	_corridor.show_reward(run.combat, [reward], false)


## Loot-valet efter rum 0.3. Tre sidor, samma kort och samma ord som senare i
## spelet; det enda källaren bestämmer är rubriken och vilken sida som byts ut
## (se [method Tutorial.loot_target]).
func _show_tutorial_loot() -> void:
	if _corridor == null or not is_instance_valid(_corridor):
		return
	var pool: Array[Dictionary] = RunFlow.available_pool(
		Content.unlocked_pool(meta.unlocked), _taken_ids)
	var options: Array[Dictionary] = Tutorial.loot_options(pool, rng)
	if options.is_empty():
		_on_corridor_reward_chosen({}, {})
		return
	var target: Dictionary = Tutorial.loot_target(run.combat, _tutorial_room)
	var targets: Array = []
	for _option: Dictionary in options:
		targets.append(target)
	_corridor.show_reward(run.combat, options, false, Tutorial.loot_title(), targets)


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
	_tutorial_loot_pending = false
	_tutorial_loot_open = false
	_map = null
	_corridor_state = {}
	# Källaren är slut och spelas aldrig igen: sparfilen ska inte ligga kvar och
	# erbjuda CONTINUE till en våning som inte finns längre.
	SaveIO.clear()
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
	_tutorial_loot_pending = false
	_tutorial_loot_open = false
	_run_firsts = []
	run = RunState.new_run(seed_value)
	# Smedjans laddning ligger i profilen och läggs på det färska tillståndet.
	# Byte och omordning, aldrig tillägg – [Forge] garanterar det.
	run.combat = Forge.apply_loadout(run.combat, meta.loadout)
	rng = run.make_rng()
	graph = RunGraph.generate_floor(M1_FLOOR, rng)
	# [b]Forken är en sparfilsgaranti[/b] (CORRIDOR_DEV_NOTES §4.9): korridorens
	# form får inte röra stridsströmmen, så en seed från före M5 ger fortfarande
	# samma möten och samma kast.
	_map = CorridorMap.build(graph, rng.fork("corridor"))
	_corridor_state = _map.to_dict()
	_node_id = graph.start_id
	_rooms_cleared = 0
	_best_chain = 0
	_taken_ids = []
	_run_won = false
	_killed_by = ""
	_sheet_shown_this_run = false
	_cleared_nodes = {}
	run.floor_index = M1_FLOOR
	run.room_index = int(graph.node_at(_node_id).get("room", 1))
	_autosave(SCREEN_CORRIDOR)
	_show_corridor()


## Läser sparfilen och fortsätter. Returnerar false när det inte finns någon
## användbar sparfil – då går [method _on_title_action] till staden i stället
## för att krascha. Det är kontraktet i [SaveIO].
func resume_run() -> bool:
	var data: Dictionary = SaveIO.load_dict()
	if data.is_empty():
		return false
	var loaded: RunState = RunState.from_dict(data)
	if loaded == null or loaded.combat == null:
		return false

	run = loaded
	rng = run.make_rng()
	var saved: Dictionary = run.meta
	var graph_data: Dictionary = saved.get("graph", {}) as Dictionary
	if graph_data.is_empty():
		return false
	graph = RunGraph.from_dict(graph_data)
	# Källaren (M5.8). Rumsindexet avgör allt annat: kartans kammar-id:n är
	# [code]f0rN[/code] och finns inte i våning 1:s graf, så nodkontrollen nedan
	# gäller bara en riktig run.
	_tutorial_room = int(saved.get("tutorial_room", -1))
	_tutorial_loot_pending = bool(saved.get("tutorial_loot_pending", false))
	_tutorial_loot_open = bool(saved.get("tutorial_loot_open", false))
	_node_id = String(saved.get("node_id", graph.start_id))
	if _tutorial_room >= 0:
		if _tutorial_room >= Tutorial.room_count() or Tutorial.room_index_for(_node_id) < 0:
			return false
	elif not graph.has_node(_node_id):
		return false
	_rooms_cleared = int(saved.get("rooms_cleared", 0))
	_best_chain = int(saved.get("best_chain", 0))
	_taken_ids = (saved.get("taken_ids", []) as Array).duplicate()
	_run_won = bool(saved.get("run_won", false))
	_sheet_shown_this_run = bool(saved.get("sheet_shown", false))
	_cleared_nodes = {}
	for id: Variant in saved.get("cleared_nodes", []) as Array:
		_cleared_nodes[String(id)] = true

	var phase: String = String(saved.get("phase", SCREEN_CORRIDOR))
	if phase == SCREEN_GAMEOVER:
		_show_gameover()
		return true

	# Korridoren ÄR runnen från och med M5. En sparfil utan map_state kan inte
	# återupptas – [method SaveIO.migrate] fäller den redan, men vakten står
	# kvar så att en handredigerad fil inte når [method CorridorMap.from_dict].
	_corridor_state = saved.get("corridor", {}) as Dictionary
	if _corridor_state.is_empty():
		return false
	_map = CorridorMap.from_dict(_corridor_state)
	_show_corridor()
	# Stod spelaren mitt i en strid monteras den på nytt, på samma ruta, med det
	# kast som redan var draget och synligt (GAME_DESIGN §1).
	if phase == SCREEN_COMBAT and run.combat != null \
			and not run.combat.enemies.is_empty() and not run.combat.is_won():
		_mount_combat.call_deferred()
	elif phase == SCREEN_REWARD:
		if _tutorial_room >= 0:
			_resume_tutorial_reward.call_deferred()
		else:
			_show_reward.call_deferred()
	return true


## Lägger tillbaka korten på golvet i källaren efter en omladdning.
##
## Det berättande kortet är ren data och kan ritas om hur många gånger som helst.
## Loot-valet drar ur slumpströmmen, men sparfilen skrevs [b]före[/b] dragningen
## (se [method _on_corridor_reward_chosen]), så samma tre kort kommer tillbaka.
func _resume_tutorial_reward() -> void:
	if _corridor == null or not is_instance_valid(_corridor):
		return
	if _tutorial_loot_open:
		_show_tutorial_loot()
		return
	var reward: Dictionary = Tutorial.reward_for(_tutorial_room)
	if reward.is_empty():
		_on_corridor_reward_chosen({}, {})
		return
	_corridor.show_reward(run.combat, [reward], false)


# ---------------------------------------------------------------------------
# Korridoren (M5)
# ---------------------------------------------------------------------------

## Monterar våningen. Anropas en gång per våning, aldrig per rum: 3D-världen
## byggs om bara när kartan byts.
func _show_corridor() -> void:
	_show(SCREEN_CORRIDOR, {
		"map": _map,
		"hp": run.combat.player_hp,
		"max_hp": run.combat.player_max_hp,
		"room": run.room_index,
		"pips": meta.pips,
		"reduced_motion": Settings.reduced_motion,
	}, {
		"cell_changed": _on_cell_changed,
		"encounter_reached": _on_encounter_reached,
		"trap_choice": _on_trap_choice,
		"trap_answered": _on_trap_answered,
		"treasure_found": _on_treasure_found,
		"treasure_taken": _on_treasure_taken,
		"boss_door_reached": _on_boss_door_reached,
		"door_opened": _on_door_opened,
		"floor_cleared": _on_floor_cleared,
		"stairs_reached": _on_stairs_reached,
		"reward_chosen": _on_corridor_reward_chosen,
		"character_sheet_requested": _on_sheet_requested,
		"settings_requested": open_settings,
	})


## Fienderna måste stå på plats INNAN spelaren ser silhuetten två rutor bort
## (CORRIDOR_DESIGN §3.1 takt 1). Kartan vet vilken nod varje riktning leder
## till; innehållet vet vilka varelser noden bär.
##
## [b]Rutan man står på går före rutan man går mot.[/b] Kliver spelaren in i en
## kammare kommer [code]cell_changed[/code] FÖRE
## [code]encounter_reached[/code] i samma händelselogg; utan den här ordningen
## primades nästa rums monster ovanpå det möte som just skulle börja, och
## spelaren mötte fyra Rostråttor med tre Slaggmalar i bild.
func _prime_enemies() -> void:
	if _corridor == null or not is_instance_valid(_corridor) or _map == null:
		return
	var cell: Dictionary = _map.current_cell()
	var here: String = String(cell.get("node_id", ""))
	if bool(cell.get("encounter", false)) and here != "" and not _cleared_nodes.has(here):
		_set_next_enemies(here)
		return
	for action: Variant in _map.available_actions():
		var info: Dictionary = (_map.available_actions()[action]) as Dictionary
		var node_id: String = String(info.get("leads_to_node", ""))
		if node_id == "":
			node_id = String(info.get("node_id", ""))
		if node_id != "" and _set_next_enemies(node_id):
			return


func _set_next_enemies(node_id: String) -> bool:
	var ids: Array = []
	if _tutorial_room >= 0 or Tutorial.room_index_for(node_id) >= 0:
		# Källaren har handskrivna rum; grafen vet ingenting om dem.
		var index: int = Tutorial.room_index_for(node_id)
		if index < 0:
			return false
		for enemy: Enemy in Tutorial.enemies_for(index):
			ids.append(enemy.id)
		_corridor.view().set_next_enemies(ids)
		return true
	var node: Dictionary = graph.node_at(node_id)
	if node.is_empty():
		return false
	for enemy: Enemy in Content.encounter(int(node["room"]), int(node["variant"])):
		ids.append(enemy.id)
	_corridor.view().set_next_enemies(ids)
	return true


## Autosave-kroken. [b]Ett steg i korridoren är alltid en rundgräns[/b], så
## spärren "aldrig mitt i en kedja" (GAME_DESIGN §1) gäller oförändrat.
func _on_cell_changed(_cell: Dictionary, map_state: Dictionary) -> void:
	_corridor_state = map_state
	_prime_enemies()
	if can_autosave():
		_autosave(SCREEN_CORRIDOR)


func _on_encounter_reached(node_id: String, _enemy_ids: Array) -> void:
	if node_id == "":
		return
	if _tutorial_room >= 0:
		_enter_tutorial_room(node_id)
		return
	if not graph.has_node(node_id):
		return
	_node_id = node_id
	var node: Dictionary = graph.node_at(node_id)
	run.room_index = int(node.get("room", 1))
	# Krit-raden ska säga rätt rum INNAN striden monteras: annars står numret
	# kvar på rummet man just lämnade under hela striden.
	_refresh_corridor_status()
	# Har rummet inte börjat ännu saknar staten fiender; då drar vi mötet och
	# första kastet här (all slump före bekräftelse, GAME_DESIGN §6.4).
	if run.combat.enemies.is_empty() or run.combat.is_won():
		run.combat = RunFlow.start_room(run.combat, node, rng)
	_autosave(SCREEN_COMBAT)
	_mount_combat()


func _mount_combat() -> void:
	if _corridor == null or not is_instance_valid(_corridor):
		return
	_corridor.view().set_steering_enabled(false)
	# En återupptagen strid har aldrig fått sitt EVENT_ENCOUNTER_REACHED, så
	# monstren finns inte i 3D-världen. No-op i den normala vägen.
	_corridor.view().restore_encounter()
	var node: Dictionary = Tutorial.node_for(_tutorial_room) if _tutorial_room >= 0 \
		else graph.node_at(_node_id)
	_combat = _corridor.mount_combat({
		"state": run.combat,
		"rng": rng,
		"node": node,
		"graph": graph,
		"reveal": meta.reveal,
		"tutorial_room": _tutorial_room,
		"best_chain": _best_chain,
	}, {
		"round_finished": _on_round_finished,
		"combat_finished": _on_combat_finished,
	})


func _on_trap_choice(trap: Dictionary) -> void:
	if _corridor != null:
		_corridor.show_trap(trap)


## Korridoren äger ingen regel och drar ingenting själv: priset tas ut i
## [method RunFlow.pay_trap] (CORRIDOR_DEV_NOTES §4.5).
func _on_trap_answered(index: int) -> void:
	var chosen: Dictionary = _corridor.view().resolve_trap(index)
	if not chosen.is_empty():
		run.combat = RunFlow.pay_trap(run.combat, chosen, rng)
	_refresh_corridor_status()
	_corridor.view().set_steering_enabled(true)
	_autosave(SCREEN_CORRIDOR)


func _on_treasure_found(treasure: Dictionary) -> void:
	if _corridor != null:
		_corridor.show_treasure(treasure)


## Altaret: en enda sak, ingen valsituation – belöningen var att du gick dit
## (CORRIDOR_DESIGN §3.5).
func _on_treasure_taken() -> void:
	var cell: Dictionary = _map.current_cell()
	var treasure: Dictionary = cell.get("treasure", {}) as Dictionary
	var amount: int = int(treasure.get("amount", 0))
	match String(treasure.get("id", "")):
		"PIPS":
			meta.pips += amount
			SaveIO.save_meta(meta)
		"CODEX":
			# Kodexen bokförs som en sedd kombination; det är den enda räknaren
			# profilen har för "ett uppslag till" i M5.
			for enemy: Enemy in run.combat.enemies:
				meta.see_enemy(enemy.id)
			SaveIO.save_meta(meta)
		"FORGE_FACE", "RELIC":
			var option: Dictionary = _draw_single_reward(String(treasure["id"]))
			if not option.is_empty():
				run.combat = RewardApply.apply(run.combat, option,
					RewardApply.default_target(run.combat, option))
				_taken_ids.append(String(option.get("id", "")))
	_refresh_corridor_status()
	_corridor.view().set_steering_enabled(true)
	_autosave(SCREEN_CORRIDOR)


## Ett enda alternativ ur poolen, av den kategori altaret lovade. Drar ur samma
## ström som belöningarna: altaret är en belöning, inte en gratislott.
func _draw_single_reward(treasure_id: String) -> Dictionary:
	var category: String = Rewards.CATEGORY_RELIC if treasure_id == "RELIC" else Rewards.CATEGORY_FORGE_FACE
	var pool: Array[Dictionary] = RunFlow.available_pool(
		Content.unlocked_pool(meta.unlocked), _taken_ids)
	var options: Array[Dictionary] = Rewards.generate(pool, rng,
		RunFlow.reward_floor_key(graph.node_at(_node_id)))
	for option: Dictionary in options:
		if String(option.get("category", "")) == category:
			return option
	return options[0] if not options.is_empty() else {}


## Bossdörren. [b]Ett eget tapp[/b], aldrig automatiskt (§3.3).
func _on_boss_door_reached() -> void:
	if _corridor != null:
		_corridor.show_door_prompt()


func _on_door_opened() -> void:
	await _corridor.view().open_door()
	if _corridor != null and is_instance_valid(_corridor):
		_corridor.view().set_steering_enabled(true)


## Våningen är rensad. I M5 finns bara våning 1, så signalen bokförs och vinsten
## avgörs av bossstriden; M3:s trappa ner hakar i här.
func _on_floor_cleared(floor_index: int) -> void:
	run.floor_index = maxi(run.floor_index, floor_index)


## Trappan upp ur källaren (CORRIDOR_DESIGN §5.2 punkt 4). Spelet börjar i
## mörker och det första man gör är att gå upp ur det; staden öppnar här.
func _on_stairs_reached() -> void:
	if _tutorial_room < 0:
		return
	_finish_tutorial()


func _refresh_corridor_status() -> void:
	if _corridor == null or not is_instance_valid(_corridor):
		return
	_corridor.view().set_status(run.combat.player_hp, run.combat.player_max_hp,
		run.room_index, meta.pips)


func _on_corridor_reward_chosen(option: Dictionary, target: Dictionary) -> void:
	# Tutorialens kort är berättande: förändringen ligger i nästa rums data, inte
	# i ett [RewardApply]-anrop. Källaren autosparas inte heller – den spelas en
	# gång och har inget "fortsätt" (§B.2).
	if _tutorial_room >= 0:
		if _tutorial_loot_open:
			# Loot-kortet är det enda i källaren som FAKTISKT ändrar tillståndet.
			_tutorial_loot_open = false
			if not option.is_empty():
				run.combat = RewardApply.apply(run.combat, option, target)
				_taken_ids.append(String(option.get("id", "")))
		elif _tutorial_loot_pending:
			_tutorial_loot_pending = false
			_tutorial_loot_open = true
			# [b]Sparas FÖRE dragningen[/b], inte efter. Slumpströmmens position
			# i filen är då den som [method Tutorial.loot_options] är på väg att
			# dra ur, så en omladdning här lägger exakt samma tre kort på golvet.
			_autosave(SCREEN_REWARD)
			_show_tutorial_loot()
			return
		_autosave(SCREEN_CORRIDOR)
		if _corridor != null and is_instance_valid(_corridor):
			_corridor.view().clear_encounter()
			_refresh_corridor_status()
			_corridor.view().show_explore_split(true)
			_corridor.view().set_steering_enabled(true)
			_prime_enemies()
		return
	if not option.is_empty():
		run.combat = RewardApply.apply(run.combat, option, target)
		_taken_ids.append(String(option.get("id", "")))
	_autosave(SCREEN_CORRIDOR)
	if _corridor == null or not is_instance_valid(_corridor):
		return
	_corridor.view().clear_encounter()
	_refresh_corridor_status()
	_corridor.view().show_explore_split(true)
	_corridor.view().set_steering_enabled(true)
	_prime_enemies()
	# §4.4: en gång per run, efter den FÖRSTA belöningen. Då vill vi att spelaren
	# ser att figuren ändrades; efter det vet hen det.
	if not _sheet_shown_this_run:
		_sheet_shown_this_run = true
		open_character_sheet(String(option.get("id", "")))
	else:
		_corridor.view().set_sheet_badge(true)


func _on_sheet_requested() -> void:
	open_character_sheet()


# ---------------------------------------------------------------------------
# Character sheet (M5)
# ---------------------------------------------------------------------------

## Öppnar character sheetet ovanpå skärmen som är igång. [param highlight_id] är
## belöningen som just togs; dess lager kritas på figuren (§4.3).
func open_character_sheet(highlight_id: String = "") -> void:
	if _sheet_modal != null and is_instance_valid(_sheet_modal):
		return
	var packed: PackedScene = ResourceLoader.load(SHEET_SCENE) as PackedScene
	if packed == null:
		push_error("GameController: kunde inte ladda %s" % SHEET_SCENE)
		return
	var sheet: CharacterSheet = packed.instantiate() as CharacterSheet
	if sheet == null:
		return
	_sheet_modal = sheet
	_modal_root.add_child(sheet)
	sheet.closed.connect(_on_sheet_closed)
	sheet.go_down_pressed.connect(_on_sheet_go_down)
	sheet.open_for({
		"state": run.combat if run != null else null,
		"meta": meta,
		"in_town": _screen_name == SCREEN_TOWN,
		"room": run.room_index if run != null else 0,
		"seed": run.seed_value if run != null else next_seed(),
		"highlight": highlight_id,
	})
	if _corridor != null and is_instance_valid(_corridor):
		_corridor.view().set_sheet_badge(false)


func sheet_open() -> bool:
	return _sheet_modal != null and is_instance_valid(_sheet_modal)


func character_sheet() -> CharacterSheet:
	return _sheet_modal as CharacterSheet


func _on_sheet_closed() -> void:
	_sheet_modal = null


func _on_sheet_go_down(seed_value: int) -> void:
	_sheet_modal = null
	SaveIO.clear()
	start_new_run(seed_value)


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


## Stridsskärmen som är igång, var den än är monterad. Rökprovet och
## bakåtknappen frågar HÄR i stället för att casta [method current_screen]:
## i korridoren är den skärmen [CorridorScreen], och striden är ett barn i den.
func current_combat() -> CombatScreen:
	if _combat != null and is_instance_valid(_combat):
		return _combat
	return null


## Källarens rumsindex, eller -1 i en riktig run. Rökprovet och testerna frågar
## här i stället för att läsa en understruken variabel.
func tutorial_room() -> int:
	return _tutorial_room


func corridor() -> CorridorScreen:
	return _corridor if _corridor != null and is_instance_valid(_corridor) else null


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
	_corridor = null
	_combat = null
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
	_corridor = _screen as CorridorScreen
	if screen_name == SCREEN_COMBAT:
		_combat = _screen as CombatScreen
	_screen_root.add_child(_screen)
	_screen.screen_done.connect(_on_screen_done.bind(screen_name))
	for signal_name: String in connections:
		_screen.connect(signal_name, connections[signal_name] as Callable)
	_screen.setup(self, null, ctx)
	if _corridor != null:
		# Fienderna i nästa kammare ska stå där innan spelaren tar sitt första
		# steg – annars är silhuetten i mörkret tom (§3.1 takt 1).
		_prime_enemies()
	screen_changed.emit(screen_name)


func _on_screen_done(payload: Dictionary, from_screen: String) -> void:
	match from_screen:
		SCREEN_REWARD:
			_on_reward_chosen(payload)
		SCREEN_GAMEOVER:
			# "BACK TO CHALKRIM" leder till staden, där GO DOWN redan ligger i
			# tumzonen: en run till är ett tapp därifrån (§A.4 regel 2).
			SaveIO.clear()
			show_town()
		SCREEN_TITLE, SCREEN_CORRIDOR, SCREEN_COMBAT, SCREEN_TOWN, SCREEN_SMITH:
			pass


## Belöningen [b]i rummet du just vann[/b] (CORRIDOR_DESIGN §3.5): tre kort över
## korridorbilden, inte en egen skärm. Källaren gör likadant sedan M5.5;
## [method _advance_tutorial] skickar sitt enda berättande kort samma väg.
func _show_reward() -> void:
	var node: Dictionary = graph.node_at(_node_id)
	# Poolen är startpoolen PLUS det spelaren köpt loss på Skrotmarknaden.
	# Marknaden lägger till innehåll, aldrig siffror (§A.3).
	var pool: Array[Dictionary] = RunFlow.available_pool(
		Content.unlocked_pool(meta.unlocked), _taken_ids)
	var options: Array[Dictionary] = Rewards.generate(pool, rng, RunFlow.reward_floor_key(node))
	if _corridor == null or not is_instance_valid(_corridor):
		_show(SCREEN_REWARD, {
			"state": run.combat,
			"options": options,
			"node": node,
			"breather": RunFlow.grants_breather(node),
		})
		return
	_corridor.unmount_combat()
	_combat = null
	if options.is_empty():
		# Poolen är slut: gå vidare i stället för att visa ett tomt altare.
		_on_corridor_reward_chosen({}, {})
		return
	_corridor.show_reward(run.combat, options, RunFlow.grants_breather(node))


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


## [b]Alltid uppskjutet en bildruta.[/b] Signalen kommer inifrån
## [method EventPlayer._process] på stridsskärmen, och nästa steg river den
## skärmen. Att göra det mitt i motorns träditeration kraschade Godot 4.6
## reproducerbart (se noten vid [method _show]).
func _on_combat_finished(won: bool, state: CombatState) -> void:
	run.combat = state
	_finish_combat.call_deferred(won, state)


func _finish_combat(won: bool, state: CombatState) -> void:
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
	_cleared_nodes[_node_id] = true
	var node: Dictionary = graph.node_at(_node_id)
	run.combat = RunFlow.finish_room(state, node)

	if RunFlow.is_boss(node):
		# M5 slutar efter våning 1:s boss. GAME_DESIGN §1 fortsätter med
		# FATE_ROLL och våning 2; det är M3-innehåll.
		_run_won = true
		_show_gameover()
		return

	_autosave(SCREEN_REWARD)
	_show_reward()


## Tutorialens belöningsskärm. Korridorens tre kort går via
## [method _on_corridor_reward_chosen] i stället.
func _on_reward_chosen(payload: Dictionary) -> void:
	_on_corridor_reward_chosen(
		payload.get("choice", {}) as Dictionary,
		payload.get("target", {}) as Dictionary)


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
		# map_state: hela korridorkartan, inklusive vilken ruta spelaren står på
		# och åt vilket håll. Utan den går en run inte att återuppta mitt i
		# korridoren (CORRIDOR_DEV_NOTES §4.4) – och det är därför
		# [constant RunState.SAVE_VERSION] är 2.
		"corridor": _corridor_state.duplicate(true),
		"node_id": _node_id,
		"rooms_cleared": _rooms_cleared,
		"best_chain": _best_chain,
		"taken_ids": _taken_ids.duplicate(),
		"run_won": _run_won,
		"sheet_shown": _sheet_shown_this_run,
		"cleared_nodes": _cleared_nodes.keys(),
		# Källaren (M5.8). -1 = riktig run. Rumsindexet räcker: tärningarna,
		# HP:t och Laddningen ligger redan i [member RunState.combat], och
		# Reveal-flaggorna i profilen (user://meta.json).
		"tutorial_room": _tutorial_room,
		"tutorial_loot_pending": _tutorial_loot_pending,
		"tutorial_loot_open": _tutorial_loot_open,
	})
