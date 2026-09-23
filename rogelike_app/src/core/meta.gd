class_name Meta
extends RefCounted
## Profilen mellan runs: Pips, Kodex, kritstreck, smedjans laddning,
## [Reveal]-flaggorna – och från M6 rostret, Kistan, banken och byggnaderna.
## TOWN_AND_ONBOARDING §A.3 och PROGRESSION_REDESIGN §4.
##
## [b]Metans regel efter M6[/b] (DECISIONS 2026-09-23, §6): [i]aldrig köpbar
## permanent styrka[/i]. Pips köper byggnader, uppgraderingar och gear – men all
## gear-styrka bärs av en hjälte och riskeras varje run, och hjältens nivå tjänas
## in och dör med hjälten. Poolposter säljs inte längre.
##
## Ligger i [code]user://meta.json[/code], separat från [code]save.json[/code]:
## en run som tar slut, eller en sparfil som nollställs, får aldrig sudda
## kritväggen. Samma trasig-fil-kontrakt som [SaveIO]: en oläsbar profil ger en
## färsk profil, aldrig en krasch.

## [b]2 (M6):[/b] roster, Kistan, banken, byggnadsnivåer, marknadens rotation och
## progressionsräknare. En v1-profil migreras i [method from_dict]: köpta
## poolposter betalas tillbaka i Pips (de köper ingenting längre), och rostret
## fylls på med en hjälte första gången staden eller Gropen behöver en.
const SAVE_VERSION: int = 2

## M1–M5:s prislista för poolposter. [b]Används bara för att betala tillbaka en
## v1-profils köp[/b] – marknaden säljer gear sedan M6 ([method buy_offer]).
const LEGACY_POOL_PRICE: Dictionary = {
	Rewards.CATEGORY_FORGE_FACE: 5,
	Rewards.CATEGORY_RELIC: 8,
	Rewards.CATEGORY_SLOT_SWAP: 10,
}

## Intjäning (§A.3). "Första gången"-bonusarna gör att en spektakulär förlust
## betalar bättre än en trist överlevnad – vi belönar att spelaren försökte.
const PIPS_PER_ROOM: int = 1
const PIPS_BOSS: int = 3
const PIPS_WIN: int = 5
const FIRST_TIME_BONUS: Dictionary = {
	"QUAD": 2,
	"PENTA": 3,
	"HOUSE": 2,
	"TRIPLE_KILL": 2,
}

var version: int = SAVE_VERSION
## Enda valutan (§A.3: "En valuta. Inte två.").
var pips: int = 0
## Ett kritstreck per död, suddas av en vunnen run (§A.1).
var tally: int = 0
var deaths: int = 0
var wins: int = 0
var runs: int = 0
var best_chain: int = 0
var best_score: int = 0
## Tutorialvåning 0 spelas exakt en gång (§B.2).
var tutorial_done: bool = false
var reveal: Reveal = Reveal.none()
## M1–M5: poolposter som köpts loss. Tomt efter migreringen till v2 (köpen
## betalades tillbaka); fältet läses bara för att kunna migrera.
var unlocked: Array[String] = []
## Fiender spelaren mött, och combo-typer spelaren sett. Kodexens innehåll.
var seen_enemies: Array[String] = []
var seen_combos: Array[String] = []
## Engångsbonusar som redan betalats ut.
var claimed_firsts: Array[String] = []
## Smedjans laddning inför nästa run, se [Forge].
var loadout: Dictionary = {}
## Index i [constant Content.DEATH_LINES] som Marrow redan sagt (aldrig samma
## två gånger i rad, §A.1).
var last_death_line: int = -1

# --- M6: progression -------------------------------------------------------
var roster: Roster = Roster.new()
## Kistan: föremål räddade vid död, i staden.
var chest: Chest = Chest.new()
## Trappbanken: föremål skickade upp med kärran.
var bank: Bank = Bank.new()
## Byggnad → nivå 0..3 ([Buildings]).
var buildings: Dictionary = {}
## Marknadens hyllor: [code]{item: {...}, price: int}[/code]. Roteras seedat
## efter varje run ([Market]).
var market_stock: Array[Dictionary] = []
## Hur många gånger marknaden roterats. Seedar nästa rotation.
var market_rotation: int = 0
## Gear-id:n spelaren någonsin hållit i. Kritväggens samling ("17 / 22", §4.3).
var found_gear: Array[String] = []
## Progressionskurvans räknare (§5). Bokförs av [Progression].
var drops_total: int = 0
var drops_by_rarity: Array[int] = [0, 0, 0, 0]
var bosses_killed: int = 0
## Runs som påbörjats i Gropen (inte källaren). Styr kurvans garantier.
var runs_started: int = 0


## En färsk profil för en spelare som aldrig startat spelet.
static func fresh() -> Meta:
	return Meta.new()


## Profilen för någon som hoppat över tutorialen: allt avslöjat, staden öppen.
static func skipped_tutorial() -> Meta:
	var meta: Meta = Meta.new()
	meta.tutorial_done = true
	meta.reveal = Reveal.all_on()
	return meta


# --- Pips ------------------------------------------------------------------

## Vad en avslutad run betalar. Ren funktion; [param firsts] är de
## engångsnycklar runden [b]visade[/b], filtrering mot redan uttagna sker i
## [method award_run].
static func pips_for_run(rooms_cleared: int, boss_killed: bool, won: bool, firsts: Array) -> int:
	var total: int = maxi(0, rooms_cleared) * PIPS_PER_ROOM
	if boss_killed:
		total += PIPS_BOSS
	if won:
		total += PIPS_WIN
	for key: Variant in firsts:
		total += int(FIRST_TIME_BONUS.get(String(key), 0))
	return total


## Betalar ut runden och bokför den. Returnerar en sammanställning som
## dödsskärmen kan visa rad för rad.
func award_run(rooms_cleared: int, boss_killed: bool, won: bool, firsts: Array,
		chain: int = 0, score: int = 0) -> Dictionary:
	var fresh_firsts: Array[String] = []
	for key: Variant in firsts:
		var name: String = String(key)
		if FIRST_TIME_BONUS.has(name) and not claimed_firsts.has(name):
			claimed_firsts.append(name)
			fresh_firsts.append(name)
	var earned: int = pips_for_run(rooms_cleared, boss_killed, won, fresh_firsts)
	pips += earned
	runs += 1
	best_chain = maxi(best_chain, chain)
	best_score = maxi(best_score, score)
	if won:
		wins += 1
		# Kommer du upp suddar du ditt eget streck med tummen (§A.1).
		tally = maxi(0, tally - 1)
	else:
		deaths += 1
		tally += 1
	return {
		"earned": earned,
		"firsts": fresh_firsts,
		"pips": pips,
		"tally": tally,
	}


# --- Byggnader och marknad (M6) --------------------------------------------

func building_level(building: String) -> int:
	return Buildings.level_of(buildings, building)


## Bygger nästa nivå. Returnerar false – och ändrar ingenting – om byggnaden är
## fullt utbyggd eller Pips inte räcker.
func buy_building(building: String) -> bool:
	var price: int = Buildings.next_price(buildings, building)
	if price <= 0 or pips < price:
		return false
	pips -= price
	buildings[building] = building_level(building) + 1
	return true


func can_buy_building(building: String) -> bool:
	var price: int = Buildings.next_price(buildings, building)
	return price > 0 and pips >= price


## Köper hyllplats [param index]. Föremålet hamnar i banken (säkrat, i staden)
## och hyllan töms. Returnerar föremålet, eller null om köpet inte går igenom.
func buy_offer(index: int) -> Item:
	if index < 0 or index >= market_stock.size():
		return null
	var offer: Dictionary = market_stock[index]
	var price: int = int(offer.get("price", 0))
	if price <= 0 or pips < price:
		return null
	var item: Item = Item.from_dict(offer.get("item", {}) as Dictionary)
	pips -= price
	market_stock.remove_at(index)
	bank.deposit([item])
	note_found(item.id)
	return item


func can_buy_offer(index: int) -> bool:
	if index < 0 or index >= market_stock.size():
		return false
	var price: int = int(market_stock[index].get("price", 0))
	return price > 0 and pips >= price


## Smedjans uppgradering: höjer [param item] en nivå om byggnaden tillåter och
## Pips räcker. Föremålet muteras på plats (det ligger i staden, säkrat).
func upgrade_item(item: Item) -> bool:
	if not Buildings.forge_can_upgrade(buildings, item):
		return false
	var price: int = Buildings.upgrade_price(item)
	if price <= 0 or pips < price:
		return false
	pips -= price
	item.level += 1
	return true


func note_found(item_id: String) -> bool:
	if item_id == "" or found_gear.has(item_id):
		return false
	found_gear.append(item_id)
	return true


# --- Rostret (M6) ----------------------------------------------------------

## Rostrets aktiva hjälte. Finns ingen rekryteras hjälte nummer ett – med
## samma seed samma namn, så en buggrapport ser samma person.
func ensure_hero(seed_value: int, body_variant: String = "a") -> Hero:
	var hero: Hero = roster.active()
	if hero != null:
		return hero
	var rng: Rng = Rng.new(seed_value).fork("recruit_%d" % roster.next_id)
	hero = Content.recruit_hero(rng, taken_names(), body_variant, Buildings.recruit_level(buildings))
	roster.add(hero, Buildings.tavern_capacity(buildings))
	return roster.active()


## Rekryterar en hjälte till i tavernan om det finns plats. Returnerar hjälten
## eller null.
func recruit(seed_value: int, body_variant: String = "a") -> Hero:
	if roster.is_full(Buildings.tavern_capacity(buildings)):
		return null
	var rng: Rng = Rng.new(seed_value).fork("recruit_%d" % roster.next_id)
	var hero: Hero = Content.recruit_hero(rng, taken_names(), body_variant, Buildings.recruit_level(buildings))
	if not roster.add(hero, Buildings.tavern_capacity(buildings)):
		return null
	return hero


## Namn i rostret och på Gravlunden. Nya rekryter undviker dem.
func taken_names() -> Array[String]:
	var out: Array[String] = []
	for hero: Hero in roster.heroes:
		out.append(hero.name)
	for entry: Dictionary in roster.fallen:
		out.append(String(entry.get("name", "")))
	return out


# --- Kodex -----------------------------------------------------------------

func see_enemy(id: String) -> bool:
	if id == "" or seen_enemies.has(id):
		return false
	seen_enemies.append(id)
	return true


func see_combo(kind: String) -> bool:
	if kind == "" or kind == "NONE" or seen_combos.has(kind):
		return false
	seen_combos.append(kind)
	return true


# --- Serialisering ---------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"version": version,
		"pips": pips,
		"tally": tally,
		"deaths": deaths,
		"wins": wins,
		"runs": runs,
		"best_chain": best_chain,
		"best_score": best_score,
		"tutorial_done": tutorial_done,
		"reveal": reveal.to_dict(),
		"unlocked": unlocked.duplicate(),
		"seen_enemies": seen_enemies.duplicate(),
		"seen_combos": seen_combos.duplicate(),
		"claimed_firsts": claimed_firsts.duplicate(),
		"loadout": loadout.duplicate(true),
		"last_death_line": last_death_line,
		"roster": roster.to_dict(),
		"chest": chest.to_dict(),
		"bank": bank.to_dict(),
		"buildings": buildings.duplicate(),
		"market_stock": _stock_to_array(market_stock),
		"market_rotation": market_rotation,
		"found_gear": found_gear.duplicate(),
		"drops_total": drops_total,
		"drops_by_rarity": drops_by_rarity.duplicate(),
		"bosses_killed": bosses_killed,
		"runs_started": runs_started,
	}


## JSON gör om heltal till float; allt tvättas med [code]int()[/code] här, av
## samma skäl som i [method RunState.from_dict].
static func from_dict(data: Dictionary) -> Meta:
	var meta: Meta = Meta.new()
	meta.version = int(data.get("version", SAVE_VERSION))
	meta.pips = int(data.get("pips", 0))
	meta.tally = int(data.get("tally", 0))
	meta.deaths = int(data.get("deaths", 0))
	meta.wins = int(data.get("wins", 0))
	meta.runs = int(data.get("runs", 0))
	meta.best_chain = int(data.get("best_chain", 0))
	meta.best_score = int(data.get("best_score", 0))
	meta.tutorial_done = bool(data.get("tutorial_done", false))
	meta.reveal = Reveal.from_dict(data.get("reveal", {}) as Dictionary)
	meta.unlocked = _strings(data.get("unlocked", []))
	meta.seen_enemies = _strings(data.get("seen_enemies", []))
	meta.seen_combos = _strings(data.get("seen_combos", []))
	meta.claimed_firsts = _strings(data.get("claimed_firsts", []))
	meta.loadout = _wash_loadout(data.get("loadout", {}) as Dictionary)
	meta.last_death_line = int(data.get("last_death_line", -1))
	meta.roster = Roster.from_dict(data.get("roster", {}) as Dictionary)
	meta.chest = Chest.from_dict(data.get("chest", {}) as Dictionary)
	meta.bank = Bank.from_dict(data.get("bank", {}) as Dictionary)
	var raw_buildings: Dictionary = data.get("buildings", {}) as Dictionary
	for building: String in Buildings.ALL:
		if raw_buildings.has(building):
			meta.buildings[building] = clampi(int(raw_buildings[building]), 0, Buildings.MAX_LEVEL)
	for raw: Variant in data.get("market_stock", []) as Array:
		var offer: Dictionary = raw as Dictionary
		meta.market_stock.append({
			"item": (offer.get("item", {}) as Dictionary).duplicate(true),
			"price": int(offer.get("price", 0)),
		})
	meta.market_rotation = int(data.get("market_rotation", 0))
	meta.found_gear = _strings(data.get("found_gear", []))
	var by_rarity: Array = data.get("drops_by_rarity", []) as Array
	for i: int in range(mini(by_rarity.size(), meta.drops_by_rarity.size())):
		meta.drops_by_rarity[i] = int(by_rarity[i])
	meta.drops_total = int(data.get("drops_total", 0))
	meta.bosses_killed = int(data.get("bosses_killed", 0))
	meta.runs_started = int(data.get("runs_started", 0))
	if meta.version < 2:
		_migrate_v1(meta)
	return meta


## v1 → v2: poolposterna köper ingenting längre, så köpet betalas tillbaka i
## Pips. En spelare ska aldrig förlora valuta på att vi bytte vad den köper.
## Runs som redan spelats räknas som påbörjade (kurvans garantier läser dem).
static func _migrate_v1(meta: Meta) -> void:
	for id: String in meta.unlocked:
		var category: String = Rewards.CATEGORY_FORGE_FACE
		if id.begins_with("RELIC_"):
			category = Rewards.CATEGORY_RELIC
		elif id.begins_with("SWAP_"):
			category = Rewards.CATEGORY_SLOT_SWAP
		meta.pips += int(LEGACY_POOL_PRICE.get(category, 0))
	meta.unlocked.clear()
	meta.runs_started = maxi(meta.runs_started, maxi(0, meta.runs - 1))
	meta.version = SAVE_VERSION


static func _stock_to_array(stock: Array[Dictionary]) -> Array:
	var out: Array = []
	for offer: Dictionary in stock:
		out.append(offer.duplicate(true))
	return out


## Smedjans laddning är idel heltalsindex, och JSON-tal är float64: utan den
## här tvätten kommer [code][2, 0, 1, 3, 4][/code] tillbaka som
## [code][2.0, 0.0, …][/code] och jämförelser mot en färsk ordning slår fel.
## Samma regel som i [method RunState.from_dict] och [method RunGraph.from_dict].
static func _wash_loadout(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var order: Array = []
	for value: Variant in raw.get(Forge.KEY_SLOT_ORDER, []) as Array:
		order.append(int(value))
	if not order.is_empty():
		out[Forge.KEY_SLOT_ORDER] = order
	var swaps: Array = []
	for entry: Variant in raw.get(Forge.KEY_FACE_SWAPS, []) as Array:
		var swap: Array = []
		for value: Variant in entry as Array:
			swap.append(int(value))
		swaps.append(swap)
	if not swaps.is_empty():
		out[Forge.KEY_FACE_SWAPS] = swaps
	return out


static func _strings(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	for value: Variant in raw as Array:
		out.append(String(value))
	return out
