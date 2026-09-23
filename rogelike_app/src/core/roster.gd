class_name Roster
extends RefCounted
## Hjälterostret. PROGRESSION_REDESIGN §4.2 och DECISIONS 2026-09-23.
##
## [b]Max fyra platser, någonsin[/b] (§2.2: "fyra namn man minns slår 28 man
## sorterar"). Hur många som är öppna avgörs av tavernans nivå, se
## [method Buildings.tavern_capacity]. De döda ligger i [member fallen] – namnet
## går till Gravlunden bredvid Kritväggen (§4.2) och kommer aldrig tillbaka.

const MAX_HEROES: int = 4

var heroes: Array[Hero] = []
## Index i [member heroes] för hjälten som går ner nästa gång.
var active_index: int = 0
## [code]{id, name, level, killed_by, run}[/code] per död hjälte, äldst först.
var fallen: Array[Dictionary] = []
## Räknare för nästa hjälte-id och för namnlistan.
var next_id: int = 1


func active() -> Hero:
	if heroes.is_empty():
		return null
	return heroes[clampi(active_index, 0, heroes.size() - 1)]


func set_active(index: int) -> bool:
	if index < 0 or index >= heroes.size() or not heroes[index].alive:
		return false
	active_index = index
	return true


func find(hero_id: String) -> Hero:
	for hero: Hero in heroes:
		if hero.id == hero_id:
			return hero
	return null


func index_of(hero_id: String) -> int:
	for i: int in range(heroes.size()):
		if heroes[i].id == hero_id:
			return i
	return -1


func size() -> int:
	return heroes.size()


func is_full(capacity: int) -> bool:
	return heroes.size() >= mini(capacity, MAX_HEROES)


## Lägger till en hjälte om det finns en plats. Returnerar false annars.
func add(hero: Hero, capacity: int = MAX_HEROES) -> bool:
	if hero == null or is_full(capacity):
		return false
	if hero.id == "":
		hero.id = "h%d" % next_id
	next_id += 1
	heroes.append(hero)
	if heroes.size() == 1:
		active_index = 0
	return true


## Ersätter posten med samma id (hjälten kom upp ur Gropen). Returnerar false
## om hjälten inte finns i rostret.
func replace(hero: Hero) -> bool:
	var index: int = index_of(hero.id)
	if index < 0:
		return false
	heroes[index] = hero
	return true


## Permadöd. Hjälten tas ur rostret och namnet ristas in i [member fallen].
## Den aktiva platsen flyttas till närmaste levande hjälte.
func bury(hero_id: String, killed_by: String, run_number: int) -> bool:
	var index: int = index_of(hero_id)
	if index < 0:
		return false
	var hero: Hero = heroes[index]
	hero.alive = false
	fallen.append({
		"id": hero.id,
		"name": hero.name,
		"level": hero.level,
		"killed_by": killed_by,
		"run": run_number,
	})
	heroes.remove_at(index)
	if active_index >= heroes.size():
		active_index = maxi(0, heroes.size() - 1)
	elif active_index > index:
		active_index -= 1
	return true


func to_dict() -> Dictionary:
	var hero_data: Array = []
	for hero: Hero in heroes:
		hero_data.append(hero.to_dict())
	var fallen_data: Array = []
	for entry: Dictionary in fallen:
		fallen_data.append(entry.duplicate(true))
	return {
		"heroes": hero_data,
		"active_index": active_index,
		"fallen": fallen_data,
		"next_id": next_id,
	}


static func from_dict(data: Dictionary) -> Roster:
	var roster: Roster = Roster.new()
	for raw: Variant in data.get("heroes", []) as Array:
		if roster.heroes.size() >= MAX_HEROES:
			break
		if raw is Dictionary:
			roster.heroes.append(Hero.from_dict(raw as Dictionary))
	roster.active_index = clampi(int(data.get("active_index", 0)), 0, maxi(0, roster.heroes.size() - 1))
	for raw: Variant in data.get("fallen", []) as Array:
		var entry: Dictionary = (raw as Dictionary).duplicate(true)
		entry["level"] = int(entry.get("level", 1))
		entry["run"] = int(entry.get("run", 0))
		roster.fallen.append(entry)
	roster.next_id = maxi(int(data.get("next_id", 1)), roster.heroes.size() + roster.fallen.size() + 1)
	return roster
