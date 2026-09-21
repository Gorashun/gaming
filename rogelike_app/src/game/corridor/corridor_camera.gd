class_name CorridorCamera
extends Camera3D
## Kameran är den enda rörliga noden i korridoren.
##
## [b]Tre regler, alla tre om åksjuka[/b] (research 05 §7, Grimrock-trådens
## "classic mode"-begäran):
## [br]1. Steg 180 ms, vridning 160 ms, [constant Tween.TRANS_SINE]. Inget mer.
## [br]2. [b]Ingen head-bob och ingen kameraskak, någonsin.[/b] Träffskaket
##    läggs på fiendens billboard, aldrig här.
## [br]3. Reducerad rörelse ⇒ omedelbar vy. Tidslinjen ändras inte, bara
##    interpolationen (DECISIONS 2026-09-21).
##
## Vinkeln är [b]absolut[/b]: [method turn_to] tar en total vinkel i radianer,
## aldrig ett delta. En wrappad vinkel får [Tween] att ta kortaste vägen och
## snurra åt fel håll vid 270° → 0°.

const STEP_MS: int = 180
const TURN_MS: int = 160
## Halvvarvet ur en återvändsgränd. Två vridningar i följd skulle kosta 320 ms
## och kännas som en paus; ett enda svep på 260 ms läser som "du vänder dig om".
const TURN_AROUND_MS: int = 260
## UI_GUIDE §17.1: normativt. Utan KEEP_WIDTH byter bildutsnittet karaktär när
## splitten ändras och samma korridor ser ut som två olika platser.
const FOV_DEGREES: float = 75.0

signal move_finished()

var reduced_motion: bool = false
## Tempoinställningen (Lugn/Normal/Snabb/Blixt). 0,5 halverar stegtiden.
var speed_scale: float = 1.0

var _tween: Tween = null


func _ready() -> void:
	fov = FOV_DEGREES
	keep_aspect = Camera3D.KEEP_WIDTH
	current = true
	# En förstapersonskorridor har inget att visa bortom dimman; att klippa där
	# sparar hela våningen bakom spelaren utan att något syns försvinna.
	near = 0.05
	far = 40.0


## Placerar kameran utan animation. Används vid inladdning och av
## [code]--reduced-motion[/code].
func place(at: Vector3, yaw: float) -> void:
	_kill()
	position = at
	rotation = Vector3(0.0, yaw, 0.0)


func step_to(at: Vector3) -> void:
	_animate("position", at, STEP_MS)


func turn_to(yaw: float) -> void:
	_animate("rotation:y", yaw, TURN_MS)


func turn_around_to(yaw: float) -> void:
	_animate("rotation:y", yaw, TURN_AROUND_MS)


func is_busy() -> bool:
	return _tween != null and _tween.is_running()


func _animate(property: String, value: Variant, duration_ms: int) -> void:
	_kill()
	if reduced_motion:
		set_indexed(property, value)
		# [b]Deferrat med flit.[/b] Anroparen gör [code]turn_to()[/code] och
		# sedan [code]await move_finished[/code]; en synkron emit här hinner
		# före awaiten och uppspelningen låser sig i reducerat rörelse-läge.
		move_finished.emit.call_deferred()
		return
	var seconds: float = float(duration_ms) / 1000.0 * maxf(speed_scale, 0.05)
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, property, value, seconds)
	_tween.finished.connect(func() -> void: move_finished.emit(), CONNECT_ONE_SHOT)


func _kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
