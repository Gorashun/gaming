class_name Item
extends RefCounted
## Ett gear-föremål: droppar, syns, bärs och kan tappas.
## docs/design/PROGRESSION_REDESIGN.md §3 och DECISIONS 2026-09-23.
##
## [b]Reliker blev gear.[/b] Ett föremål bär en lista [member effects] som
## resolvern och run-flödet läser som [i]regler[/i] (§3.2), aldrig som dold
## statistik: varje effekt som påverkar en runda emitterar
## [code]gear_triggered[/code] och syns i kvittot.
##
## [b]Gränssnitt mot UI-lagret[/b] (dev A bygger character sheetet mot detta):
## [member icon_id] matchar art-manifestets [code]gear.<ID>[/code],
## [member name_key] och [member effect_summary_key] är översättningsnycklar,
## [member rarity] är en [enum Rules.Rarity].
##
## Ren data, inga Node-beroenden. En effekt är en [Dictionary]:
## [codeblock]
## {"kind": "PIP_BONUS", "face_value": 1, "amount": 1, "per_level": 0}
## [/codeblock]
## Typerna och deras regler står i [GearRules].

## Högsta nivå smedjan kan höja ett föremål till (§4.1).
const MAX_LEVEL: int = 3

var id: String = ""
## En av [constant Content.SHEET_SLOTS]: HEAD, CHEST, HANDS, WEAPON, LEGS, BACK,
## AMULET. Tom sträng för en quirk (den bärs inte, den [i]är[/i] hjälten).
var slot: String = ""
## En av [enum Rules.Rarity].
var rarity: int = Rules.Rarity.COMMON
## 0..[constant MAX_LEVEL]. Smedjan höjer den; effekter med [code]per_level[/code]
## växer med den.
var level: int = 0
var effects: Array[Dictionary] = []
## Art-manifestets nyckel, [code]gear.<ID>[/code].
var icon_id: String = ""
## Översättningsnyckel för namnet, [code]GEAR_<ID>[/code].
var name_key: String = ""
## Översättningsnyckel för effekten i en rad, [code]GEAR_<ID>_DESC[/code].
var effect_summary_key: String = ""
## Engelskt källnamn, reservtext när en nyckel saknas.
var display_name: String = ""
## [code]false[/code] så länge föremålet riskeras i en pågående run. Allt en
## hjälte bär ner i Gropen är osäkrat; det säkras av trappbanken, Kistan eller
## en vunnen run (§3.4).
var secured: bool = true


func _init(p_id: String = "", p_slot: String = "", p_rarity: int = Rules.Rarity.COMMON) -> void:
	id = p_id
	slot = p_slot
	rarity = p_rarity
	icon_id = "gear.%s" % p_id
	name_key = "GEAR_%s" % p_id
	effect_summary_key = "GEAR_%s_DESC" % p_id
	display_name = p_id


## Effektens verkliga storlek, med nivån inräknad. [param field] är fältet som
## skalas (oftast [code]amount[/code]).
func effect_value(effect: Dictionary, field: String = "amount") -> int:
	return int(effect.get(field, 0)) + level * int(effect.get("per_level", 0))


func has_effect(kind: String) -> bool:
	for effect: Dictionary in effects:
		if String(effect.get("kind", "")) == kind:
			return true
	return false


## Första effekten av typen [param kind], eller en tom [Dictionary].
func effect_of(kind: String) -> Dictionary:
	for effect: Dictionary in effects:
		if String(effect.get("kind", "")) == kind:
			return effect
	return {}


func is_quirk() -> bool:
	return slot == ""


func copy() -> Item:
	var other: Item = Item.new(id, slot, rarity)
	other.level = level
	var copied: Array[Dictionary] = []
	for effect: Dictionary in effects:
		copied.append(effect.duplicate(true))
	other.effects = copied
	other.icon_id = icon_id
	other.name_key = name_key
	other.effect_summary_key = effect_summary_key
	other.display_name = display_name
	other.secured = secured
	return other


func to_dict() -> Dictionary:
	var effect_data: Array = []
	for effect: Dictionary in effects:
		effect_data.append(effect.duplicate(true))
	return {
		"id": id,
		"slot": slot,
		"rarity": rarity,
		"level": level,
		"effects": effect_data,
		"icon_id": icon_id,
		"name_key": name_key,
		"effect_summary_key": effect_summary_key,
		"display_name": display_name,
		"secured": secured,
	}


## JSON gör om heltal till float; effekternas tal tvättas tillbaka här av samma
## skäl som i [method RunState.from_dict].
static func from_dict(data: Dictionary) -> Item:
	var item: Item = Item.new(
		String(data.get("id", "")),
		String(data.get("slot", "")),
		int(data.get("rarity", Rules.Rarity.COMMON)),
	)
	item.level = clampi(int(data.get("level", 0)), 0, MAX_LEVEL)
	var effects: Array[Dictionary] = []
	for raw: Variant in data.get("effects", []) as Array:
		effects.append(_wash_effect(raw as Dictionary))
	item.effects = effects
	item.icon_id = String(data.get("icon_id", item.icon_id))
	item.name_key = String(data.get("name_key", item.name_key))
	item.effect_summary_key = String(data.get("effect_summary_key", item.effect_summary_key))
	item.display_name = String(data.get("display_name", item.id))
	item.secured = bool(data.get("secured", true))
	return item


static func _wash_effect(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in raw:
		var value: Variant = raw[key]
		if value is float:
			out[String(key)] = int(value)
		else:
			out[String(key)] = value
	return out


## Serialiserar en lista föremål.
static func list_to_dicts(items: Array) -> Array:
	var out: Array = []
	for item: Variant in items:
		if item is Item:
			out.append((item as Item).to_dict())
	return out


static func list_from_dicts(raw: Variant) -> Array[Item]:
	var out: Array[Item] = []
	if not (raw is Array):
		return out
	for entry: Variant in raw as Array:
		if entry is Dictionary:
			out.append(Item.from_dict(entry as Dictionary))
	return out


static func copy_list(items: Array) -> Array[Item]:
	var out: Array[Item] = []
	for item: Variant in items:
		if item is Item:
			out.append((item as Item).copy())
	return out
