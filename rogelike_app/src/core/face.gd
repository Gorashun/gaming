class_name Face
extends RefCounted
## En tärningssida. GAME_DESIGN.md §2.1.
## Sidor är permanenta items inom en run: smid om en 1:a till en Giftdroppe.

## Data-id, t.ex. "PIP_3" eller "POISON_DROP".
var id: String = ""
## Sidans ögonvärde, 0..9.
var value: int = 0
## En av [enum Rules.FaceEffectKind].
var effect: int = Rules.FaceEffectKind.NONE
## Effektens styrka. 0 när [member effect] är NONE.
var magnitude: int = 0
## Originalvärdet, används för att återställa GROW när striden slutar.
var base_value: int = 0


func _init(p_id: String = "", p_value: int = 0, p_effect: int = Rules.FaceEffectKind.NONE, p_magnitude: int = 0) -> void:
	id = p_id
	value = p_value
	base_value = p_value
	effect = p_effect
	magnitude = p_magnitude


## Återställer värdet efter en strid där GROW eller sprickor ändrat det.
func reset_value() -> void:
	value = base_value


func copy() -> Face:
	var other: Face = Face.new(id, value, effect, magnitude)
	other.base_value = base_value
	return other


func to_dict() -> Dictionary:
	return {
		"id": id,
		"value": value,
		"effect": effect,
		"magnitude": magnitude,
		"base_value": base_value,
	}


static func from_dict(data: Dictionary) -> Face:
	var face: Face = Face.new(
		String(data.get("id", "")),
		int(data.get("value", 0)),
		int(data.get("effect", Rules.FaceEffectKind.NONE)),
		int(data.get("magnitude", 0)),
	)
	face.base_value = int(data.get("base_value", face.value))
	return face
