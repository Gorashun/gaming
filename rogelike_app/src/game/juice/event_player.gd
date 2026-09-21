class_name EventPlayer
extends Node
## Spelar upp [member ResolveResult.events] som en ÖVERLAPPANDE TIDSLINJE.
##
## DECISIONS 2026-09-21: "Uppspelaren byggs som överlappande tidslinje, inte
## FIFO-kö. Naiv summering ger 3,1 s per runda, taket är 2,5 s."
## UI_GUIDE §5.8 formulerar samma sak som arkitekturregel: [i]ett kedjesteg
## består av överlappande delhändelser, inte av en kö.[/i]
##
## [b]Modellen: tre banor.[/b] Varje event får en starttid ur en markör som
## flyttas olika mycket beroende på bana:
##
## [br]• [b]CHAIN[/b] – kedjans slag (tärning aktiveras, skada, död fiende).
##   Överlappar föregående med [constant CHAIN_OVERLAP] (40 %), dvs. markören
##   flyttas bara 60 % av längden. Det är exakt åtgärden UI_GUIDE §5.8 föreskriver.
## [br]• [b]BEAT[/b] – skiljetecken (combo, kåk, rundans början och slut, död).
##   Får hela sin längd och överlappar inget: de ska landa som punkter.
## [br]• [b]SIDE[/b] – sidokanaler (Charge, Ward, överflöd, statusar, strike).
##   Flyttar inte markören alls, utan spelas parallellt med en stagger på
##   [constant SIDE_STAGGER_MS] (UI_GUIDE §5.4: "60 ms stagger", §5.8:
##   "charge_stored körs parallellt med round_end").
##
## Överstiger totalen [constant BUDGET_MS] komprimeras hela tidslinjen linjärt
## (UI_GUIDE §5: "Allt däröver komprimeras automatiskt"). Budgeten är alltså ett
## tak, inte ett mål – men modellen ovan ska klara en normal 6-tärningsrunda
## [b]utan[/b] komprimering, och det är vad [code]tests/test_event_player.gd[/code]
## asserterar.
##
## [b]Uppspelningen ändrar aldrig utfallet[/b] (UI_GUIDE §5.9). Sanningen är
## [member ResolveResult.state_after]; den här klassen rör bara presentation.
## [method apply_all] finns för att kunna visa mellanlägen och för att bevisa i
## test att snabbspolning ger samma slutläge.

## Tak per runda i ms (UI_GUIDE §5).
const BUDGET_MS: int = 2500
## Andel av föregående CHAIN-events längd som nästa får överlappa.
const CHAIN_OVERLAP: float = 0.4
## Stagger mellan parallella sidokanalsevent.
const SIDE_STAGGER_MS: int = 60
## Används när ett event saknar ms_hint.
const MS_HINT_FALLBACK: int = 120
## Tidsfaktor för resterande steg vid första tappet (UI_GUIDE §5.9: 35 %).
const FAST_FORWARD_FACTOR: float = 0.35

enum Lane {
	CHAIN,
	BEAT,
	SIDE,
}

## Bana per eventtyp. Allt som inte står här hamnar i [constant Lane.SIDE]:
## okända event ska aldrig kunna spräcka budgeten.
const LANES: Dictionary = {
	"die_activated": Lane.CHAIN,
	"slot_modifier": Lane.CHAIN,
	"damage_dealt": Lane.CHAIN,
	"enemy_killed": Lane.CHAIN,
	"status_ticked": Lane.CHAIN,
	"enemy_attacks": Lane.CHAIN,
	"enemy_thorns": Lane.CHAIN,
	"heal": Lane.CHAIN,
	"die_stolen": Lane.CHAIN,
	"die_returned": Lane.CHAIN,

	"round_start": Lane.BEAT,
	"combo_formed": Lane.BEAT,
	"house_bonus": Lane.BEAT,
	"die_cracked": Lane.BEAT,
	"enemy_special": Lane.BEAT,
	"player_died": Lane.BEAT,
	"combat_won": Lane.BEAT,
	"round_end": Lane.BEAT,
}

## Kedjetempo (UI_GUIDE §2.10). Lugn 1,25 · Normal 1,0 · Snabb 0,6 · Blixt 0,35.
@export var speed_scale: float = 1.0

## Ett event ska ritas nu. [param duration] är dess längd i sekunder (0 vid skip).
signal event_started(event: Dictionary, duration: float)
## Hela tidslinjen är slut.
signal finished()

var _timeline: Array[Dictionary] = []
var _cursor: int = 0
var _elapsed_ms: float = 0.0
var _total_ms: float = 0.0
var _rate: float = 1.0
var _playing: bool = false


func _ready() -> void:
	set_process(false)


func is_playing() -> bool:
	return _playing


## Startar uppspelningen. Returnerar tidslinjens totala längd i ms.
func play(events: Array[Dictionary]) -> int:
	_timeline = build_timeline(events, speed_scale)
	_total_ms = float(total_ms(_timeline))
	_cursor = 0
	_elapsed_ms = 0.0
	_rate = 1.0
	_playing = true
	set_process(true)
	if _timeline.is_empty():
		_finish()
	return int(_total_ms)


## Ett tapp under uppspelning (UI_GUIDE §5.9). Första tappet kör resten på 35 %
## av längden, andra tappet hoppar direkt till slutläget.
func nudge() -> void:
	if not _playing:
		return
	if is_equal_approx(_rate, 1.0):
		_rate = 1.0 / FAST_FORWARD_FACTOR
	else:
		skip_to_end()


## Applicerar alla återstående event omedelbart och avslutar.
## Loggen är komplett även här (ARCHITECTURE: "snabbspolning = samma logg med
## ms_hint = 0"), så slutläget blir identiskt.
func skip_to_end() -> void:
	if not _playing:
		return
	while _cursor < _timeline.size():
		var step: Dictionary = _timeline[_cursor]
		_cursor += 1
		event_started.emit(step["event"] as Dictionary, 0.0)
	_finish()


func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed_ms += delta * 1000.0 * _rate
	while _cursor < _timeline.size() and float(_timeline[_cursor]["start_ms"]) <= _elapsed_ms:
		var step: Dictionary = _timeline[_cursor]
		_cursor += 1
		event_started.emit(step["event"] as Dictionary, float(step["dur_ms"]) / 1000.0)
	if _cursor >= _timeline.size() and _elapsed_ms >= _total_ms:
		_finish()


func _finish() -> void:
	_playing = false
	set_process(false)
	finished.emit()


# ---------------------------------------------------------------------------
# Ren, testbar tidslinje
# ---------------------------------------------------------------------------

static func lane_of(event_type: String) -> int:
	return int(LANES.get(event_type, Lane.SIDE))


## Bygger tidslinjen. Ren funktion: samma [param events] och [param speed] ger
## exakt samma array.
## [br][param speed] 0,0 ger en tidslinje där allt ligger på 0 ms (skip).
## [br][param compress] false stänger av budgetkomprimeringen, vilket testet
## använder för att bevisa att överlappsmodellen själv håller sig under taket.
static func build_timeline(events: Array[Dictionary], speed: float = 1.0, compress: bool = true) -> Array[Dictionary]:
	var timeline: Array[Dictionary] = []
	var cursor: float = 0.0
	var side_offset: float = 0.0

	for i: int in range(events.size()):
		var event: Dictionary = events[i]
		var event_type: String = String(event.get("t", ""))
		var duration: float = float(int(event.get("ms_hint", MS_HINT_FALLBACK))) * maxf(0.0, speed)
		var lane: int = lane_of(event_type)
		var start: float = cursor

		match lane:
			Lane.CHAIN:
				side_offset = 0.0
				cursor += duration * (1.0 - CHAIN_OVERLAP)
			Lane.BEAT:
				side_offset = 0.0
				cursor += duration
			_:
				start = cursor + side_offset
				side_offset += float(SIDE_STAGGER_MS) * maxf(0.0, speed)

		timeline.append({
			"seq": int(event.get("seq", i)),
			"t": event_type,
			"lane": lane,
			"start_ms": start,
			"dur_ms": duration,
			"event": event,
		})

	if compress:
		timeline = _compress(timeline, float(BUDGET_MS))
	return timeline


## Linjär komprimering till [param budget] (UI_GUIDE §5.9). Rör inte ordningen
## och tappar aldrig ett event – bara tiden.
static func _compress(timeline: Array[Dictionary], budget: float) -> Array[Dictionary]:
	var total: float = float(total_ms(timeline))
	if total <= budget or total <= 0.0:
		return timeline
	var factor: float = budget / total
	for step: Dictionary in timeline:
		step["start_ms"] = float(step["start_ms"]) * factor
		step["dur_ms"] = float(step["dur_ms"]) * factor
		step["compressed"] = true
	return timeline


## Tidslinjens längd: sista ögonblicket något fortfarande spelas.
static func total_ms(timeline: Array[Dictionary]) -> int:
	var last: float = 0.0
	for step: Dictionary in timeline:
		last = maxf(last, float(step["start_ms"]) + float(step["dur_ms"]))
	return int(ceil(last))


# ---------------------------------------------------------------------------
# Vy-tillståndet som uppspelningen animerar fram
# ---------------------------------------------------------------------------

## Vyn UI ritar. Den härleds ur [param state] och uppdateras sedan event för
## event. Alla event bär ABSOLUTA eftervärden ([code]target_hp_after[/code],
## [code]pool_after[/code] …), så vyn efter N event är oberoende av hur snabbt
## de spelades – vilket är precis varför snabbspolning inte kan ändra utfallet.
static func view_from_state(state: CombatState) -> Dictionary:
	var enemies: Array = []
	for enemy: Enemy in state.enemies:
		enemies.append({
			"id": enemy.id,
			"hp": enemy.hp,
			"max_hp": enemy.max_hp,
			"armor": enemy.armor,
			"burn": enemy.burn,
			"poison": enemy.poison,
			"killed": not enemy.is_alive(),
		})
	return {
		"player_hp": state.player_hp,
		"player_max_hp": state.player_max_hp,
		"ward": state.ward,
		"charge": state.charge,
		"enemies": enemies,
		"dead": state.player_dead,
	}


## Index i [code]view.enemies[/code] som ett event med [param id] avser.
##
## [b]Varför det inte räcker att matcha på id:[/b] rum 1 är fyra [code]RUST_RAT[/code]
## med identiskt id (GAME_DESIGN §4.4). Resolvern riktar alltid mot "första
## fienden i enemies[] med hp > 0" (§2.3 P3), så vyn måste använda exakt samma
## regel. Annars dränerar vi fel HP-bar så snart ett rum har dubbletter.
static func target_index(view: Dictionary, id: String) -> int:
	var enemies: Array = view.get("enemies", []) as Array
	var fallback: int = -1
	for i: int in range(enemies.size()):
		var enemy: Dictionary = enemies[i] as Dictionary
		if String(enemy.get("id", "")) != id:
			continue
		if int(enemy.get("hp", 0)) > 0:
			return i
		if fallback < 0:
			fallback = i
	return fallback


static func _enemy_in_view(view: Dictionary, id: String) -> Dictionary:
	var index: int = target_index(view, id)
	if index < 0:
		return {}
	return (view.get("enemies", []) as Array)[index] as Dictionary


## Applicerar ETT event på vyn. Muterar [param view] på plats.
static func apply_event(view: Dictionary, event: Dictionary) -> void:
	var event_type: String = String(event.get("t", ""))
	match event_type:
		"damage_dealt", "status_ticked":
			var enemy: Dictionary = _enemy_in_view(view, String(event.get("target", "")))
			if not enemy.is_empty():
				enemy["hp"] = int(event.get("target_hp_after", enemy.get("hp", 0)))
			if event_type == "status_ticked":
				var status: String = String(event.get("status", "")).to_lower()
				if not enemy.is_empty() and enemy.has(status):
					enemy[status] = int(event.get("stacks_after", 0))
		"status_applied":
			var target: Dictionary = _enemy_in_view(view, String(event.get("target", "")))
			var status_key: String = String(event.get("status", "")).to_lower()
			if not target.is_empty() and target.has(status_key):
				target[status_key] = int(event.get("stacks_after", target.get(status_key, 0)))
		"enemy_killed":
			# HP är redan satt till 0 av det damage_dealt/status_ticked som
			# dödade. Här markeras bara VILKEN av dubbletterna som föll, så att
			# UI kan spela dödsanimationen på rätt silhuett.
			var enemies: Array = view.get("enemies", []) as Array
			var killed_id: String = String(event.get("target", ""))
			for entry: Variant in enemies:
				var candidate: Dictionary = entry as Dictionary
				if String(candidate.get("id", "")) != killed_id:
					continue
				if bool(candidate.get("killed", false)):
					continue
				candidate["hp"] = 0
				candidate["killed"] = true
				break
		"enemy_special":
			var detail: Dictionary = event.get("detail", {}) as Dictionary
			if detail.has("armor_after"):
				var hardened: Dictionary = _enemy_in_view(view, String(event.get("enemy", "")))
				if not hardened.is_empty():
					hardened["armor"] = int(detail["armor_after"])
		"enemy_attacks", "enemy_thorns", "player_damaged":
			view["player_hp"] = int(event.get("player_hp_after", view.get("player_hp", 0)))
			if event_type == "enemy_attacks":
				view["ward"] = maxi(0, int(view.get("ward", 0)) - int(event.get("ward_used", 0)))
		"heal":
			if String(event.get("target", "")) == "player":
				view["player_hp"] = int(event.get("hp_after", view.get("player_hp", 0)))
		"ward_gained":
			view["ward"] = int(event.get("ward_total", view.get("ward", 0)))
		"charge_stored":
			view["charge"] = int(event.get("pool_after", view.get("charge", 0)))
		"charge_applied":
			view["charge"] = 0
		"round_end":
			view["ward"] = 0
			view["charge"] = int(event.get("charge", view.get("charge", 0)))
			view["player_hp"] = int(event.get("player_hp", view.get("player_hp", 0)))
		"player_died":
			view["dead"] = true
			view["player_hp"] = 0


## Applicerar hela loggen. Returnerar samma Dictionary för bekvämlighet.
static func apply_all(view: Dictionary, events: Array[Dictionary]) -> Dictionary:
	for event: Dictionary in events:
		apply_event(view, event)
	return view
