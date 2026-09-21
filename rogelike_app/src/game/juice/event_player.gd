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

## Tak för KEDJAN (P0–P3) i ms. Normativt ur UI_GUIDE §5: "en kedja på 6
## tärningar ... Tak: 2,5 s". Budgettabellen i §5.8 räknar just kedjan och tar
## inte med fiendens svar.
const BUDGET_MS: int = 2500
## Tak för hela rundan, dvs. kedjan plus fiendepassets svar (P4) och round_end.
## [b]Dev-tolkning, inte spec:[/b] §5 sätter inget tak för P4. 2 500 + 700 ms
## kommer från §5.3:s egen komprimeringsregel ("hela överflödet stannar under
## 700 ms") använd som ram för fiendesvaret. Behöver ett UI-godkännande.
const ROUND_BUDGET_MS: int = 3200
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
	"damage_dealt": Lane.CHAIN,
	"enemy_killed": Lane.CHAIN,
	"status_ticked": Lane.CHAIN,
	"enemy_attacks": Lane.CHAIN,
	"enemy_thorns": Lane.CHAIN,
	"heal": Lane.CHAIN,
	"die_stolen": Lane.CHAIN,
	"die_returned": Lane.CHAIN,

	# slot_modifier ritas PÅ sloten medan dess tärning aktiveras (UI_GUIDE §5.1:
	# "slotens underline ritas vänster→höger i slotens färg"). Den är alltså
	# samtidig med die_activated, inte ett eget kedjesteg efter den.
	"slot_modifier": Lane.SIDE,

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
## Spelar uppspelaren själv ljud, haptik, hit-stop och skärmskak?
## Stängs av i tester som bara vill mäta tidslinjen.
@export var feedback_enabled: bool = true

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
## Kedjesteget, nollställs varje runda. Driver den globala tonhöjdsregeln.
var _step_index: int = 0
## Har spelaren tappat för att snabbspola? Då slås hit-stops av och haptiken
## slås ihop till ett enda [code]MEDIUM[/code] i slutet (UI_GUIDE §5.9).
var _fast: bool = false
var _skipped_haptic: bool = false
## Överflödsspårning: sloten för föregående damage_dealt och hoppets nummer.
var _last_damage_slot: int = -1
var _hop: int = 0


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
	_step_index = 0
	_fast = false
	_skipped_haptic = false
	_last_damage_slot = -1
	_hop = 0
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
		_fast = true
	else:
		skip_to_end()


## Applicerar alla återstående event omedelbart och avslutar.
## Loggen är komplett även här (ARCHITECTURE: "snabbspolning = samma logg med
## ms_hint = 0"), så slutläget blir identiskt.
func skip_to_end() -> void:
	if not _playing:
		return
	_fast = true
	while _cursor < _timeline.size():
		var step: Dictionary = _timeline[_cursor]
		_cursor += 1
		_fire(step["event"] as Dictionary, 0.0)
	_finish()


func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed_ms += delta * 1000.0 * _rate
	while _cursor < _timeline.size() and float(_timeline[_cursor]["start_ms"]) <= _elapsed_ms:
		var step: Dictionary = _timeline[_cursor]
		_cursor += 1
		_fire(step["event"] as Dictionary, float(step["dur_ms"]) / 1000.0)
	if _cursor >= _timeline.size() and _elapsed_ms >= _total_ms:
		_finish()


## Ett event i tidslinjen: först ljud/haptik/hit-stop/skak (som inte behöver
## känna till en enda nod), sedan signalen som ritar det visuella.
func _fire(event: Dictionary, duration: float) -> void:
	_play_feedback(event)
	event_started.emit(event, duration)


func _finish() -> void:
	_playing = false
	set_process(false)
	if _skipped_haptic and feedback_enabled:
		# §5.9: "haptik slås ihop till ett enda medium vid slutet".
		Juice.haptic(Haptics.Level.MEDIUM)
	finished.emit()


# ---------------------------------------------------------------------------
# Feedback-spec (UI_GUIDE §5)
# ---------------------------------------------------------------------------
#
# UI_GUIDE §12 skulle bära en exakt juice-tidslinje från UI-agenten. Den är inte
# levererad när det här skrivs (§12 innehåller fortfarande skisser och
# verifiering), så tabellen nedan är §5.1–5.7 plus PM:s M2-brief, och den är
# skriven som EN ren funktion för att kunna bytas mot §12 utan att röra något
# anropsställe.

## Ljudnamn. Filerna ligger i [code]assets/sfx/<namn>.wav[/code] och laddas lat
## av [code]Juice[/code]; ett namn utan fil är tyst och räknas, aldrig en krasch.
const SFX_DIE_ACTIVATE: StringName = &"die_activate"
const SFX_COMBO_PAIR: StringName = &"combo_pair"
const SFX_COMBO_TRIPLE: StringName = &"combo_triple"
const SFX_COMBO_HOUSE: StringName = &"combo_house"
const SFX_DAMAGE_HIT: StringName = &"damage_hit"
const SFX_DAMAGE_OVERFLOW: StringName = &"damage_overflow"
const SFX_CHARGE_STORE: StringName = &"charge_store"
const SFX_ENEMY_KILLED: StringName = &"enemy_killed"
const SFX_DIE_CRACKED: StringName = &"die_cracked"
const SFX_ENEMY_ATTACK: StringName = &"enemy_attack"
const SFX_PLAYER_HURT: StringName = &"player_hurt"
const SFX_ROUND_END: StringName = &"round_end"
## UI-tryck. Registret har ingen egen cue för Ward, läkning eller rekord, så de
## lånar en befintlig med egen tonhöjd (assets/sfx/README.md §2 listar 17 filer;
## en cue utan rad i den tabellen är inte levererad och ska inte uppfinnas här).
const SFX_UI_TAP: StringName = &"ui_tap"

## Mixnivåer, assets/sfx/README.md §2. Filerna är normaliserade till −3 dBFS och
## balansen görs i motorn, relativt [code]damage_hit[/code] = 0 dB.
const MIX_DB: Dictionary = {
	SFX_DIE_ACTIVATE: -4.0,
	SFX_COMBO_PAIR: -2.0,
	SFX_COMBO_TRIPLE: -1.0,
	SFX_COMBO_HOUSE: 0.0,
	SFX_DAMAGE_HIT: 0.0,
	SFX_DAMAGE_OVERFLOW: -1.0,
	SFX_CHARGE_STORE: -9.0,
	SFX_ENEMY_KILLED: 1.0,
	SFX_DIE_CRACKED: 2.0,
	SFX_ENEMY_ATTACK: -1.0,
	SFX_PLAYER_HURT: -1.0,
	SFX_ROUND_END: -3.0,
	SFX_UI_TAP: -14.0,
}


## Mixnivån för en cue, 0 dB för en som saknar rad.
static func mix_db(sound: StringName) -> float:
	return float(MIX_DB.get(sound, 0.0))

## Halvtonssteget som ett överflödshopp lägger på (UI_GUIDE §5.3).
const OVERFLOW_SEMITONES: float = 2.0
## Speglar [code]Juice.HIT_STOP_MAX_MS[/code]. Kopian finns för att
## [method hit_stop_ms] ska vara en ren statisk funktion som går att köra utan
## att autoloaden finns (tester av tidslinjen startar inget ljud).
const HIT_STOP_CAP_MS: int = 90
## Kedjesteget når taket efter en oktav. PM:s M2-brief: [code]min(step, 12)[/code].
const PITCH_STEP_CAP: int = 12
## Skärmskak per combo-storlek i dp (UI_GUIDE §5.2: 2 / 4 / 7).
const COMBO_SHAKE: Dictionary = {2: 2.0, 4: 4.0, 8: 7.0, 16: 7.0}
## Hit-stop per combo-storlek. PM:s M2-brief: "kort hit-stop på ×4+", alltså
## ingen på ×2 (UI_GUIDE §5.2 ville ha 40 ms där; en frysning på varje par gör
## kedjan hackig när Smedens MIRROR ger par nästan varje runda).
const COMBO_HIT_STOP: Dictionary = {2: 0, 4: 70, 8: 110, 16: 150}
## Skadans skak: [code]amount / DAMAGE_SHAKE_DIVISOR[/code], mellan golv och tak.
const DAMAGE_SHAKE_DIVISOR: float = 8.0
const DAMAGE_SHAKE_MIN: float = 1.5
const DAMAGE_SHAKE_MAX: float = 7.0

## Ett tomt feedbacksvar. Allt som inte står i [method feedback] blir det här.
const NO_FEEDBACK: Dictionary = {
	"sfx": &"",
	"pitch": 1.0,
	"volume_db": 0.0,
	"haptic": 0,
	"hit_stop_ms": 0,
	"shake": 0.0,
	"shake_ms": 0,
	"extra_sfx": &"",
	"extra_pitch": 1.0,
}


## Ljud, haptik, hit-stop och skak för ETT event. Ren funktion: samma event och
## samma [param step_index] ger samma svar, vilket är det som gör
## tonhöjdsregeln testbar utan ljudkort.
## [param hop] är överflödshoppets nummer: 0 = första målet, 1+ = kedjepilens
## hopp till nästa fiende. Registret säger att [code]damage_overflow[/code]
## ERSÄTTER [code]damage_hit[/code] på ett hopp och stiger +2 halvtoner per hopp.
static func feedback(event: Dictionary, step_index: int = 0, hop: int = 0) -> Dictionary:
	var out: Dictionary = NO_FEEDBACK.duplicate()
	var step: int = mini(maxi(step_index, 0), PITCH_STEP_CAP)
	match String(event.get("t", "")):
		"die_activated":
			out["sfx"] = SFX_DIE_ACTIVATE
			out["pitch"] = pow(2.0, float(step) / 12.0)
			out["haptic"] = Haptics.Level.LIGHT
		"combo_formed":
			var multiplier: int = int(event.get("multiplier", 2))
			out["sfx"] = combo_sfx(multiplier)
			out["pitch"] = pow(2.0, float(mini(step + combo_bonus(multiplier), PITCH_STEP_CAP)) / 12.0)
			out["haptic"] = Haptics.Level.HEAVY if multiplier >= 8 else Haptics.Level.MEDIUM
			out["hit_stop_ms"] = int(COMBO_HIT_STOP.get(multiplier, 110))
			out["shake"] = float(COMBO_SHAKE.get(multiplier, 7.0))
			out["shake_ms"] = 180
		"house_bonus":
			out["sfx"] = SFX_COMBO_HOUSE
			out["pitch"] = 1.5
			out["haptic"] = Haptics.Level.HEAVY
			out["hit_stop_ms"] = 110
			out["shake"] = 7.0
			out["shake_ms"] = 200
		"damage_dealt":
			var amount: int = int(event.get("amount", 0))
			if hop > 0:
				# Hoppet: kedjans ton + 2 halvtoner per hopp (README §3.3).
				out["sfx"] = SFX_DAMAGE_OVERFLOW
				out["pitch"] = minf(2.0, pow(2.0, float(step) / 12.0 + OVERFLOW_SEMITONES * float(hop) / 12.0))
				out["haptic"] = Haptics.Level.LIGHT
			else:
				out["sfx"] = SFX_DAMAGE_HIT
				# §5.3/README §3.2: stora tal låter TYNGRE, inte ljusare. Regeln
				# är oberoende av kedjestegringen – träffen är en konsekvens,
				# inte ett steg.
				out["pitch"] = clampf(1.2 - float(amount) / 200.0, 0.65, 1.2)
				out["haptic"] = Haptics.Level.MEDIUM if amount > 0 else Haptics.Level.LIGHT
			out["shake"] = clampf(float(amount) / DAMAGE_SHAKE_DIVISOR, DAMAGE_SHAKE_MIN, DAMAGE_SHAKE_MAX) if amount > 0 else 0.0
			out["shake_ms"] = 160
		"enemy_killed":
			out["sfx"] = SFX_ENEMY_KILLED
			# §5.5: döden SÄNKS två halvtoner mot kedjans aktuella ton – den är
			# en punkt, inte ännu en höjning.
			out["pitch"] = pow(2.0, float(step - 2) / 12.0)
			out["haptic"] = Haptics.Level.HEAVY
			out["hit_stop_ms"] = 90
			out["shake"] = 5.0
			out["shake_ms"] = 220
		"die_cracked":
			out["sfx"] = SFX_DIE_CRACKED
			# §5.6: ingen pitch-stegring. Kedjans mönster bryts avsiktligt.
			out["pitch"] = 0.7
			out["haptic"] = Haptics.Level.HEAVY
			out["hit_stop_ms"] = 180
			out["shake"] = 8.0
			out["shake_ms"] = 260
		"charge_stored":
			out["sfx"] = SFX_CHARGE_STORE
			out["pitch"] = clampf(1.2 + 0.05 * float(step), 1.0, 2.0)
			# §5.4: −9 dB via MIX_DB, "detta är en sidokanal, inte
			# huvudhändelsen". Ingen haptik: den skulle bli en per oanvänd
			# tärning och är precis den haptikspam §5.4 varnar för.
		"ward_gained":
			# Ingen egen Ward-cue i registret: Charge-klangen en kvint ned.
			out["sfx"] = SFX_CHARGE_STORE
			out["pitch"] = 0.75
		"heal":
			out["sfx"] = SFX_CHARGE_STORE
			out["pitch"] = 1.35
			out["haptic"] = Haptics.Level.LIGHT
		"enemy_attacks":
			var damage: int = int(event.get("amount", 0))
			out["sfx"] = SFX_ENEMY_ATTACK
			out["pitch"] = 1.0
			if damage > 0:
				out["extra_sfx"] = SFX_PLAYER_HURT
				out["haptic"] = Haptics.Level.MEDIUM
				out["shake"] = clampf(float(damage) / 4.0, 2.0, 6.0)
				out["shake_ms"] = 200
		"enemy_thorns", "player_damaged":
			out["sfx"] = SFX_PLAYER_HURT
			out["haptic"] = Haptics.Level.MEDIUM
			out["shake"] = 3.0
			out["shake_ms"] = 160
		"status_ticked":
			out["sfx"] = SFX_DAMAGE_HIT
			out["pitch"] = 1.4
			out["volume_db"] = -6.0  # under träffen: brännskada är inte ett slag
		"round_end":
			out["sfx"] = SFX_ROUND_END
			out["haptic"] = Haptics.Level.MEDIUM
	# Mixen läggs sist och bara på det som inte satt en egen nivå: en sidokanal
	# ska kunna ligga under sin cues normalnivå, aldrig över.
	if float(out["volume_db"]) == 0.0:
		out["volume_db"] = mix_db(out["sfx"] as StringName)
	return out


static func combo_sfx(multiplier: int) -> StringName:
	if multiplier >= 8:
		return SFX_COMBO_HOUSE
	if multiplier >= 4:
		return SFX_COMBO_TRIPLE
	return SFX_COMBO_PAIR


## Extra halvtoner som en combo hoppar (UI_GUIDE §5: 0 / 2 / 4 / 7).
static func combo_bonus(multiplier: int) -> int:
	match multiplier:
		2:
			return 2
		4:
			return 4
		8, 16:
			return 7
	return 0


## Summan av alla hit-stops i en logg. Den tid uppspelningen tar UTÖVER
## tidslinjen, och därmed skillnaden mellan normalt och reducerat rörelse-läge.
static func hit_stop_ms(events: Array[Dictionary], reduced_motion: bool = false) -> int:
	var total: int = 0
	var step: int = 0
	for event: Dictionary in events:
		var stop: int = mini(int(feedback(event, step)["hit_stop_ms"]), HIT_STOP_CAP_MS)
		# Hit-stops staplas aldrig: en ny under en pågående ignoreras (Juice).
		total += stop / 2 if reduced_motion else stop
		if String(event.get("t", "")) == "die_activated":
			step += 1
	return total


## Uppspelningens VÄGGKLOCKA: tidslinjen plus hit-stoppen.
## Reducerat rörelse-läge halverar hit-stoppen (UI_GUIDE §6.1) och ger därför
## en kortare uppspelning med exakt samma eventordning och samma slutläge.
static func wall_ms(events: Array[Dictionary], speed: float = 1.0, reduced_motion: bool = false) -> int:
	return total_ms(build_timeline(events, speed)) + hit_stop_ms(events, reduced_motion)


## Spelar feedbacken för ett event. Allt här är nodoberoende; det visuella
## ligger kvar hos skärmen, som vet vilken tärning och vilken fiende det gäller.
func _play_feedback(event: Dictionary) -> void:
	if not feedback_enabled:
		return
	var event_type: String = String(event.get("t", ""))
	if event_type == "damage_dealt":
		# Två skadeevent från SAMMA slot i följd är ett överflödshopp
		# (GAME_DESIGN §2.3 P3: spillet går vidare till nästa levande fiende).
		var slot: int = int(event.get("slot", -1))
		_hop = _hop + 1 if slot == _last_damage_slot else 0
		_last_damage_slot = slot
	var fb: Dictionary = feedback(event, _step_index, _hop)
	if event_type == "die_activated":
		_step_index += 1

	var sound: StringName = fb["sfx"] as StringName
	if sound != &"":
		Juice.sfx(sound, float(fb["pitch"]), float(fb["volume_db"]))
	var extra: StringName = fb["extra_sfx"] as StringName
	if extra != &"":
		Juice.sfx(extra, float(fb["extra_pitch"]), float(fb["volume_db"]))

	var level: int = int(fb["haptic"])
	if level != Haptics.Level.NONE:
		if _fast:
			_skipped_haptic = true
		else:
			Juice.haptic(level)

	if not _fast:
		Juice.hit_stop(int(fb["hit_stop_ms"]))
	if float(fb["shake"]) > 0.0:
		Juice.shake(float(fb["shake"]), int(fb["shake_ms"]))


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
		timeline = _compress(timeline)
	return timeline


## Eventtyper som tillhör fiendepasset (P4) och rundans avslut (P5).
## Allt före det första av dem är "kedjan" i UI_GUIDE §5:s mening.
const AFTER_CHAIN_TYPES: Array[String] = [
	"enemy_turn_start",
	"enemy_attacks",
	"enemy_special",
	"enemy_thorns",
	"status_ticked",
	"round_end",
]


## Kedjans längd: sista ögonblicket något ur P0–P3 fortfarande spelas.
## Det är den siffra UI_GUIDE §5 sätter taket [constant BUDGET_MS] för.
static func chain_ms(timeline: Array[Dictionary]) -> int:
	var last: float = 0.0
	for step: Dictionary in timeline:
		if AFTER_CHAIN_TYPES.has(String(step["t"])):
			break
		last = maxf(last, float(step["start_ms"]) + float(step["dur_ms"]))
	return int(ceil(last))


## Linjär komprimering (UI_GUIDE §5.9: "Allt däröver komprimeras automatiskt").
## Rör inte ordningen och tappar aldrig ett event – bara tiden.
##
## Två tak gäller samtidigt: kedjan (P0–P3) mot [constant BUDGET_MS] och hela
## rundan mot [constant ROUND_BUDGET_MS]. Den hårdaste av dem vinner, och
## faktorn appliceras EN gång på hela tidslinjen så att de relativa
## förhållandena mellan stegen bevaras.
static func _compress(timeline: Array[Dictionary]) -> Array[Dictionary]:
	var total: float = float(total_ms(timeline))
	var chain: float = float(chain_ms(timeline))
	var factor: float = 1.0
	if total > float(ROUND_BUDGET_MS) and total > 0.0:
		factor = minf(factor, float(ROUND_BUDGET_MS) / total)
	if chain > float(BUDGET_MS) and chain > 0.0:
		factor = minf(factor, float(BUDGET_MS) / chain)
	if factor >= 1.0:
		return timeline
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
