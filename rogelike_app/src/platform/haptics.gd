class_name Haptics
extends RefCounted
## Haptiknivåer och deras längder. Själva vibrationen utlöses av [code]Juice[/code],
## som är den enda platsen i koden som rör [method Input.vibrate_handheld].
##
## Klassen är kvar som ren datatabell därför att nivån är [b]spec[/b]: UI_GUIDE
## §5.1–5.7 anger en nivå per event, och den tabellen ska gå att läsa och testa
## utan att starta en ljudmotor.
##
## UI_GUIDE §6.4: haptik ska kunna stängas av helt eller sättas till "endast vid
## kritiska händelser". [member enabled] och [member level_floor] är de knapparna;
## [code]Settings.haptics[/code] speglas in i [member enabled].

enum Level {
	NONE,
	LIGHT, ## Tärning lyfts, placeras, aktiveras.
	MEDIUM, ## Träff, totalen landar, combo ×2/×4.
	HEAVY, ## Fiende dör, tärning spricker, combo ×8.
}

## Varaktighet i ms per nivå.
##
## [b]Avvikelse från UI_GUIDE §5 (10/20/30 ms), beslutad i PM:s M2-brief:[/b]
## 15/30/60 ms. Android-vibratorn har en mätbar starttröskel – under ~12 ms
## känner man ingenting genom ett skal – och 30 ms för HEAVY är för nära MEDIUM
## för att läsa som "det där var en död fiende". UI_GUIDE §5.5 anger själv
## "30–60 ms" för HEAVY, så taket är taget därifrån.
const DURATION_MS: Dictionary = {
	Level.NONE: 0,
	Level.LIGHT: 15,
	Level.MEDIUM: 30,
	Level.HEAVY: 60,
}

## false = helt tyst. Speglar [code]Settings.haptics[/code].
static var enabled: bool = true
## Allt under den här nivån ignoreras ("endast vid kritiska händelser" = HEAVY).
static var level_floor: int = Level.LIGHT
## Sätts av tester och av rökprovet för att kunna asserta anropen.
static var log_calls: bool = false
static var calls: Array[Dictionary] = []


static func duration_ms(level: int) -> int:
	return int(DURATION_MS.get(level, 0))


## Ska den här nivån spelas alls? [code]Juice.haptic[/code] frågar först.
static func allows(level: int) -> bool:
	return enabled and level != Level.NONE and level >= level_floor


## Loggar ett faktiskt utfört anrop. Vibrationen görs av [code]Juice[/code].
static func note(level: int) -> void:
	if log_calls:
		calls.append({"level": level, "ms": duration_ms(level)})


static func reset_log() -> void:
	calls.clear()
