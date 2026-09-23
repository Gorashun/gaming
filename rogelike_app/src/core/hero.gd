class_name Hero
extends RefCounted
## En namngiven hjälte i rostret. PROGRESSION_REDESIGN §4.2.
##
## [b]Nivån är talet som går upp, och det dör med hjälten.[/b] Nivå 1–5 låser
## upp hur många gear-slots hjälten får bära (2 → 7). Inget av det går att köpa;
## det tjänas in med XP per run (§4.2) och förloras vid permadöd.
##
## Gränssnitt mot UI-lagret: [method equipped] tar en slot-sträng ur
## [constant Content.SHEET_SLOTS] och returnerar [Item] eller [code]null[/code].

## XP som krävs för nivå 1..5 (§4.2: nivå 2 vid 10, 3 vid 25, 4 vid 50, 5 vid 90).
const XP_FOR_LEVEL: Array[int] = [0, 0, 10, 25, 50, 90]
const MAX_LEVEL: int = 5
## Antal bärbara slots per nivå (index = nivå). §4.2-tabellen.
const SLOTS_FOR_LEVEL: Array[int] = [0, 2, 3, 4, 6, 7]
## Ordningen slots låses upp i. Nivå 1 bär vapen och bröst.
const SLOT_UNLOCK_ORDER: Array[String] = ["WEAPON", "CHEST", "HEAD", "HANDS", "LEGS", "BACK", "AMULET"]

## XP per run (§4.2): 1 per rensat rum, 3 per boss, 5 för vinst.
const XP_PER_ROOM: int = 1
const XP_PER_BOSS: int = 3
const XP_PER_WIN: int = 5

## Unikt inom profilen ([code]h1[/code], [code]h2[/code] …). Rostret delar ut dem.
var id: String = ""
## Genererat ur [constant Content.HERO_NAMES]. Ett egennamn, översätts inte.
var name: String = ""
## Kroppsvarianten ([code]a[/code]/[code]b[/code]), samma som [code]Art.SMITH_VARIANTS[/code].
var body_variant: String = "a"
var class_id: String = "SMITH"
var level: int = 1
var xp: int = 0
## En quirk-id ur [constant Content.QUIRKS], eller tom sträng.
var quirk: String = ""
var alive: bool = true
## slot → [Item]. Läs med [method equipped]; skriv med [method equip].
var worn: Dictionary = {}
## Antal runs hjälten gått ner i. Visas i tavernan.
var runs: int = 0


func _init(p_id: String = "", p_name: String = "") -> void:
	id = p_id
	name = p_name


## Föremålet i [param slot], eller [code]null[/code].
func equipped(slot: String) -> Item:
	return worn.get(slot, null) as Item


## Antal gear-slots hjälten får bära på sin nivå (2 → 7).
func gear_slots_unlocked() -> int:
	return SLOTS_FOR_LEVEL[clampi(level, 1, MAX_LEVEL)]


func unlocked_slots() -> Array[String]:
	var out: Array[String] = []
	for i: int in range(gear_slots_unlocked()):
		out.append(SLOT_UNLOCK_ORDER[i])
	return out


func is_slot_unlocked(slot: String) -> bool:
	return unlocked_slots().has(slot)


## Nivån en slot låses upp på, eller -1 för en okänd slot.
static func level_for_slot(slot: String) -> int:
	var index: int = SLOT_UNLOCK_ORDER.find(slot)
	if index < 0:
		return -1
	for lvl: int in range(1, MAX_LEVEL + 1):
		if SLOTS_FOR_LEVEL[lvl] > index:
			return lvl
	return MAX_LEVEL


## Tar på [param item]. Returnerar föremålet som byttes ut (eller null).
## En låst slot tar inte emot något: då returneras [param item] själv, och
## anroparen lägger det i packningen. Ingenting förloras någonsin tyst.
func equip(item: Item) -> Item:
	if item == null or not is_slot_unlocked(item.slot):
		return item
	var previous: Item = equipped(item.slot)
	worn[item.slot] = item
	return previous


func unequip(slot: String) -> Item:
	var previous: Item = equipped(slot)
	worn.erase(slot)
	return previous


## Allt hjälten bär, i [constant SLOT_UNLOCK_ORDER]-ordning. Stabil ordning så
## att resolverns effekter och kvittots rader alltid kommer i samma följd.
func equipped_items() -> Array[Item]:
	var out: Array[Item] = []
	for slot: String in SLOT_UNLOCK_ORDER:
		var item: Item = equipped(slot)
		if item != null:
			out.append(item)
	return out


## Lägger till XP och höjer nivån. Returnerar antal nivåer som vanns.
func add_xp(amount: int) -> int:
	if amount <= 0 or not alive:
		return 0
	xp += amount
	var gained: int = 0
	while level < MAX_LEVEL and xp >= XP_FOR_LEVEL[level + 1]:
		level += 1
		gained += 1
	return gained


## Höjer nivån till minst [param min_level] utan att röra XP-räknaren nedåt.
## Används av progressionskurvans garantier (§5).
func raise_to_level(min_level: int) -> int:
	var target: int = clampi(min_level, 1, MAX_LEVEL)
	if level >= target:
		return 0
	var gained: int = target - level
	level = target
	xp = maxi(xp, XP_FOR_LEVEL[target])
	return gained


## XP en run ger (§4.2). Ren funktion.
static func xp_for_run(rooms_cleared: int, bosses_killed: int, won: bool) -> int:
	var total: int = maxi(0, rooms_cleared) * XP_PER_ROOM + maxi(0, bosses_killed) * XP_PER_BOSS
	if won:
		total += XP_PER_WIN
	return total


## XP kvar till nästa nivå, eller 0 på maxnivån.
func xp_to_next() -> int:
	if level >= MAX_LEVEL:
		return 0
	return maxi(0, XP_FOR_LEVEL[level + 1] - xp)


## Markerar alla burna föremål som osäkrade/säkrade.
func set_all_secured(value: bool) -> void:
	for item: Item in equipped_items():
		item.secured = value


func copy() -> Hero:
	var other: Hero = Hero.new(id, name)
	other.body_variant = body_variant
	other.class_id = class_id
	other.level = level
	other.xp = xp
	other.quirk = quirk
	other.alive = alive
	other.runs = runs
	for slot: Variant in worn:
		other.worn[slot] = (worn[slot] as Item).copy()
	return other


func to_dict() -> Dictionary:
	var worn_data: Dictionary = {}
	for slot: Variant in worn:
		worn_data[String(slot)] = (worn[slot] as Item).to_dict()
	return {
		"id": id,
		"name": name,
		"body_variant": body_variant,
		"class_id": class_id,
		"level": level,
		"xp": xp,
		"quirk": quirk,
		"alive": alive,
		"runs": runs,
		"worn": worn_data,
	}


static func from_dict(data: Dictionary) -> Hero:
	var hero: Hero = Hero.new(String(data.get("id", "")), String(data.get("name", "")))
	hero.body_variant = String(data.get("body_variant", "a"))
	hero.class_id = String(data.get("class_id", "SMITH"))
	hero.level = clampi(int(data.get("level", 1)), 1, MAX_LEVEL)
	hero.xp = maxi(0, int(data.get("xp", 0)))
	hero.quirk = String(data.get("quirk", ""))
	hero.alive = bool(data.get("alive", true))
	hero.runs = maxi(0, int(data.get("runs", 0)))
	var raw: Dictionary = data.get("worn", {}) as Dictionary
	for slot: Variant in raw:
		if raw[slot] is Dictionary:
			hero.worn[String(slot)] = Item.from_dict(raw[slot] as Dictionary)
	return hero
