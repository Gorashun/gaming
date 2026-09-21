class_name ResolveResult
extends RefCounted
## Returvärdet från [method Resolver.resolve]: händelseloggen som UI spelar upp,
## plus det nya tillståndet. GAME_DESIGN.md §2.2.

## Array of Dictionary. Varje event har kuvertet {t, seq, ms_hint}.
var events: Array[Dictionary] = []
var state_after: CombatState = null


func _init(p_events: Array[Dictionary] = [], p_state: CombatState = null) -> void:
	events = p_events
	state_after = p_state


## Loggen som JSON-sträng. Används av test_preview_equals_applied och av
## determinismtester som jämför två körningar byte för byte.
func events_json() -> String:
	return JSON.stringify(events)


## Alla event av en viss typ.
func events_of(t: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in events:
		if String(event.get("t", "")) == t:
			result.append(event)
	return result


func has_event(t: String) -> bool:
	for event: Dictionary in events:
		if String(event.get("t", "")) == t:
			return true
	return false


func count_of(t: String) -> int:
	return events_of(t).size()
