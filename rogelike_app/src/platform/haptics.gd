class_name Haptics
extends RefCounted
## Haptik per UI_GUIDE §5. M1-stubb: loggar men vibrerar inte.
##
## Skälet att den finns redan nu är att anropsställena ska sitta rätt i
## tidslinjen (UI_GUIDE §5.1–5.7 anger haptiknivå per event). När Android-
## implementationen kommer i M2 byts bara kroppen i [method pulse] ut.
##
## UI_GUIDE §6.4: haptik ska kunna stängas av helt eller sättas till "endast vid
## kritiska händelser". [member level_floor] är den knappen.

enum Level {
	NONE,
	LIGHT, ## 10 ms. Tärning lyfts, placeras, aktiveras.
	MEDIUM, ## 20 ms. Träff, totalen landar.
	HEAVY, ## 30–60 ms. Fiende dör, tärning spricker.
}

## Varaktighet i ms per nivå (UI_GUIDE §5).
const DURATION_MS: Dictionary = {
	Level.NONE: 0,
	Level.LIGHT: 10,
	Level.MEDIUM: 20,
	Level.HEAVY: 30,
}

## false = helt tyst. UI_GUIDE §6.4.
static var enabled: bool = true
## Allt under den här nivån ignoreras ("endast vid kritiska händelser" = HEAVY).
static var level_floor: int = Level.LIGHT
## Sätts av tester och av smoke-scriptet för att kunna asserta anropen.
static var log_calls: bool = false
static var calls: Array[Dictionary] = []


static func pulse(level: int) -> void:
	if not enabled or level < level_floor or level == Level.NONE:
		return
	var duration: int = int(DURATION_MS.get(level, 0))
	if log_calls:
		calls.append({"level": level, "ms": duration})
	# M2: Input.vibrate_handheld(duration) på Android/iOS. Stubb i M1 så att
	# headless-körningar och desktop inte får en meningslös varning per event.


static func reset_log() -> void:
	calls.clear()
