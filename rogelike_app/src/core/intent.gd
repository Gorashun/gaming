class_name Intent
extends RefCounted
## Fiendens avsikt nästa runda. ALLTID synlig före bekräftelse (GAME_DESIGN §6.5).
## Väljs av [method Resolver.advance] innan rundan, aldrig efter.

## En av [enum Rules.IntentKind].
var kind: int = Rules.IntentKind.ATTACK
var value: int = 0
## ÖVERSÄTTNINGSNYCKEL för UI-texten, t.ex. "INTENT_NOTE_GRAB". Core innehåller
## aldrig spelartext (CLAUDE.md): nyckeln slås upp i UI-lagret via tr().
var note: String = ""
## Formatargument till [member note], t.ex. [3] för "Grabs slot %d".
var note_args: Array = []
## Valfri nyttolast för SPECIAL, t.ex. {"slot": 3} för GRAB.
var payload: Dictionary = {}


func _init(p_kind: int = Rules.IntentKind.ATTACK, p_value: int = 0, p_note: String = "") -> void:
	kind = p_kind
	value = p_value
	note = p_note


func copy() -> Intent:
	var other: Intent = Intent.new(kind, value, note)
	other.note_args = note_args.duplicate(true)
	other.payload = payload.duplicate(true)
	return other


func to_dict() -> Dictionary:
	return {
		"kind": kind,
		"kind_name": Rules.intent_kind_name(kind),
		"value": value,
		"note": note,
		"note_args": note_args.duplicate(true),
		"payload": payload.duplicate(true),
	}


static func from_dict(data: Dictionary) -> Intent:
	var intent: Intent = Intent.new(
		int(data.get("kind", Rules.IntentKind.ATTACK)),
		int(data.get("value", 0)),
		String(data.get("note", "")),
	)
	# JSON-tal är float64: ett note_arg som skrevs som 3 kommer tillbaka som 3.0
	# och skulle visas som "Attacks for 3.0". Samma tvätt som RunState.meta gör
	# (ARCHITECTURE: "Heltal blir float där, så allt tvättas med int()").
	var args: Array = []
	for value: Variant in data.get("note_args", []) as Array:
		args.append(int(value) if value is float else value)
	intent.note_args = args
	intent.payload = (data.get("payload", {}) as Dictionary).duplicate(true)
	return intent
