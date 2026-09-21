class_name Reveal
extends RefCounted
## Progressiv avslöjning: vilka UI-element som finns på skärmen.
##
## [b]Normativ regel[/b] (TOWN_AND_ONBOARDING §B.2): ett element som ännu inte
## lärts ut är [b]frånvarande[/b], inte nedtonat. "En nedtonad knapp är en fråga;
## en frånvarande knapp är ingen fråga alls."
##
## [b]Regel nummer två[/b] (COMBAT_READABILITY §7): ett element får bara döljas
## när det är [i]tomt eller overksamt i tillståndet[/i]. UI ljuger aldrig om
## spelets tillstånd. Den kontrollen ligger i [method may_hide], som tar
## tillståndets siffror in och svarar ja/nej — så att regeln går att testa utan
## en enda Control-nod.
##
## Modellen ligger i core och sparas i [Meta] (profilen), inte i [RunState]:
## flaggorna ska överleva att en run tar slut. En färdig spelare har alla på.

## Flaggornas namn. Ordningen är lärkurvans ordning (§B.1) och används av
## tutorialen för att sätta rätt flagga per rum.
const FLAGS: Array[String] = [
	"overflow",
	"slot_types",
	"armor",
	"charge",
	"mirror",
	"reroll",
	"anvil",
	"tray_ext",
]

## Tärningar som inte placeras blir Charge. Döljer laddningsmätaren.
var charge: bool = false
## Omkast-knappen.
var reroll: bool = false
## Slot-typernas regelrad och typnamn utöver PLAIN.
var slot_types: bool = false
## Överflödspilen och leveransremsan.
var overflow: bool = false
## Rustningsraden i kvittot och rustningen på fiendekortet.
var armor: bool = false
## Spegelns kopieringspil och halvgenomskinliga tärning.
var mirror: bool = false
## Ambossens tröskeltext.
var anvil: bool = false
## Brickans utökade tillstånd: tomma socklar med slotnummer och "n kvar".
var tray_ext: bool = false


## Alla flaggor på. En spelare som gjort tutorialen, eller hoppat över den.
static func all_on() -> Reveal:
	var reveal: Reveal = Reveal.new()
	for flag: String in FLAGS:
		reveal.set(flag, true)
	return reveal


## Inget avslöjat. Tutorialrum 0.1 börjar här.
static func none() -> Reveal:
	return Reveal.new()


func has(flag: String) -> bool:
	if not FLAGS.has(flag):
		push_warning("Reveal: okänd flagga %s" % flag)
		return true
	return bool(get(flag))


## Sätter en flagga. Returnerar true om den faktiskt ändrades, så att UI kan
## spela kritstreck-animationen bara första gången (§B.2: "spelaren ser att
## skärmen växte").
func reveal_flag(flag: String) -> bool:
	if not FLAGS.has(flag) or bool(get(flag)):
		return false
	set(flag, true)
	return true


func is_complete() -> bool:
	for flag: String in FLAGS:
		if not bool(get(flag)):
			return false
	return true


## [b]Får elementet bakom [param flag] döljas just nu?[/b] COMBAT_READABILITY §7:
## bara när det är tomt eller overksamt. En laddningsmätare på 7 måste synas
## även för en spelare som inte fått lektionen än — annars ljuger skärmen.
##
## [param facts] är de tal som avgör saken, så att funktionen är ren:
## [code]{charge, ward, rerolls_left, slot_types: Array[int]}[/code].
static func may_hide(flag: String, facts: Dictionary) -> bool:
	var types: Array = facts.get("slot_types", []) as Array
	match flag:
		"charge":
			return int(facts.get("charge", 0)) == 0 and not types.has(Rules.SlotType.CHARGE)
		"reroll":
			return int(facts.get("rerolls_left", 0)) <= 0
		"armor":
			return int(facts.get("max_armor", 0)) <= 0
		"mirror":
			return not types.has(Rules.SlotType.MIRROR)
		"anvil":
			return not types.has(Rules.SlotType.ANVIL)
		"slot_types":
			for value: Variant in types:
				if int(value) != Rules.SlotType.PLAIN:
					return false
			return true
	# overflow och tray_ext är ren presentation av något som alltid är sant;
	# de får döljas fritt under lärkurvan.
	return true


## Sant när elementet ska ritas: antingen är det avslöjat, eller så vore det en
## lögn att dölja det. [b]Enda vägen in från UI.[/b]
func shows(flag: String, facts: Dictionary = {}) -> bool:
	return has(flag) or not may_hide(flag, facts)


func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for flag: String in FLAGS:
		out[flag] = bool(get(flag))
	return out


static func from_dict(data: Dictionary) -> Reveal:
	var reveal: Reveal = Reveal.new()
	for flag: String in FLAGS:
		reveal.set(flag, bool(data.get(flag, false)))
	return reveal


func copy() -> Reveal:
	return from_dict(to_dict())
