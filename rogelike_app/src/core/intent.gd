class_name Intent
extends RefCounted
## Fiendens avsikt nästa runda. ALLTID synlig före bekräftelse (GAME_DESIGN §6.5).
## Väljs av [method Resolver.advance] innan rundan, aldrig efter.

## En av [enum Rules.IntentKind].
var kind: int = Rules.IntentKind.ATTACK
var value: int = 0
## UI-text, t.ex. "Griper slot 3".
var note: String = ""
## Valfri nyttolast för SPECIAL, t.ex. {"slot": 3} för GRAB.
var payload: Dictionary = {}


func _init(p_kind: int = Rules.IntentKind.ATTACK, p_value: int = 0, p_note: String = "") -> void:
	kind = p_kind
	value = p_value
	note = p_note


func copy() -> Intent:
	var other: Intent = Intent.new(kind, value, note)
	other.payload = payload.duplicate(true)
	return other


func to_dict() -> Dictionary:
	return {
		"kind": kind,
		"kind_name": Rules.intent_kind_name(kind),
		"value": value,
		"note": note,
		"payload": payload.duplicate(true),
	}


static func from_dict(data: Dictionary) -> Intent:
	var intent: Intent = Intent.new(
		int(data.get("kind", Rules.IntentKind.ATTACK)),
		int(data.get("value", 0)),
		String(data.get("note", "")),
	)
	intent.payload = (data.get("payload", {}) as Dictionary).duplicate(true)
	return intent
