class_name Face
extends RefCounted
## En sida på en tärning. Sidor är permanenta items: smid om en 1:a till en
## giftdroppe och tärningen blir en annan build (PROPOSAL §3, regel 4).

enum Kind {
	PIP, ## Vanlig siffersida. [member pips] är antalet ögon.
	POISON, ## Ger gift istället för direkt skada.
	SHIELD, ## Ger block till spelaren.
	WILD, ## Räknas som vilket värde som helst vid par/triss/kåk.
	BLANK, ## Inga ögon. Fyller en slot utan att bidra.
}

## Stabilt data-id, t.ex. "pip_3" eller "poison_drop".
var id: String = ""
## Visningsnamn i UI.
var label: String = ""
var kind: int = Kind.PIP
## Antal ögon. Grundvalutan i kedjan.
var pips: int = 0
## Fria taggar för relik-/synergivillkor, t.ex. ["iron", "starter"].
var tags: Array[String] = []


func _init(p_id: String = "", p_pips: int = 0, p_kind: int = Kind.PIP, p_label: String = "") -> void:
	id = p_id
	pips = p_pips
	kind = p_kind
	label = p_label if p_label != "" else p_id


## Sidans värde för par/triss/kåk-jämförelser. WILD matchar allt och hanteras
## separat av resolvern, därför får den ett eget sentinel-värde.
func match_value() -> int:
	if kind == Kind.WILD:
		return -1
	return pips


func has_tag(tag: String) -> bool:
	return tags.has(tag)


func duplicate_face() -> Face:
	var copy: Face = Face.new(id, pips, kind, label)
	copy.tags = tags.duplicate()
	return copy


func to_dict() -> Dictionary:
	return {
		"id": id,
		"label": label,
		"kind": int(kind),
		"pips": pips,
		"tags": tags.duplicate(),
	}


static func from_dict(data: Dictionary) -> Face:
	var face: Face = Face.new(
		String(data.get("id", "")),
		int(data.get("pips", 0)),
		int(data.get("kind", Kind.PIP)),
		String(data.get("label", "")),
	)
	var tags: Array[String] = []
	for tag: Variant in data.get("tags", []) as Array:
		tags.append(String(tag))
	face.tags = tags
	return face
