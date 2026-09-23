class_name Buildings
extends RefCounted
## Stadens byggnader och deras nivåer. PROGRESSION_REDESIGN §4.1.
##
## [b]Pips köper byggnader, uppgraderingar och gear – aldrig poolposter[/b]
## (DECISIONS 2026-09-23). Nivåerna ligger i [member Meta.buildings]; den här
## filen är ren tabell och ren funktion, så att staden, simulatorn och testerna
## läser samma siffror. Alla priser är tuningbara (GAME_DESIGN §4.8-andan).

const FORGE: String = "FORGE"
const MARKET: String = "MARKET"
const TAVERN: String = "TAVERN"
const CHEST: String = "CHEST"
const ALL: Array[String] = [CHEST, TAVERN, FORGE, MARKET]

const MAX_LEVEL: int = 3

## Pris för nivå 1, 2, 3 (§4.1-tabellen).
const PRICES: Dictionary = {
	CHEST: [10, 25, 60],
	FORGE: [15, 35, 80],
	TAVERN: [20, 45, 90],
	MARKET: [15, 40, 85],
}

## Tavernans platser per nivå. Nivå 0 = en ensam hjälte (§4.1: nivå 1 ger två).
const TAVERN_CAPACITY: Array[int] = [1, 2, 3, 4]
## Marknadens varor per nivå och högsta sällsynthet i handeln.
const MARKET_WARES: Array[int] = [2, 3, 4, 5]
const MARKET_MAX_RARITY: Array[int] = [
	Rules.Rarity.COMMON, Rules.Rarity.UNCOMMON, Rules.Rarity.RARE, Rules.Rarity.RARE,
]
## Gearpris per sällsynthet på marknaden. Episk säljs aldrig.
const GEAR_PRICE: Array[int] = [6, 12, 24, 0]
## Smedjans uppgradering: kostnad för att gå från nivå n till n+1.
const UPGRADE_PRICE: Array[int] = [5, 10, 15]


static func level_of(levels: Dictionary, building: String) -> int:
	return clampi(int(levels.get(building, 0)), 0, MAX_LEVEL)


## Pris för nästa nivå, eller 0 när byggnaden är fullt utbyggd.
static func next_price(levels: Dictionary, building: String) -> int:
	var level: int = level_of(levels, building)
	if level >= MAX_LEVEL or not PRICES.has(building):
		return 0
	return int((PRICES[building] as Array)[level])


static func tavern_capacity(levels: Dictionary) -> int:
	return mini(Roster.MAX_HEROES, TAVERN_CAPACITY[level_of(levels, TAVERN)])


## Nivån en ny rekryt startar på. Tavernan nivå 3: "rekryter startar på nivå 2".
static func recruit_level(levels: Dictionary) -> int:
	return 2 if level_of(levels, TAVERN) >= 3 else 1


static func chest_rescue(levels: Dictionary) -> int:
	return Chest.rescue_capacity(level_of(levels, CHEST))


static func market_wares(levels: Dictionary) -> int:
	return MARKET_WARES[level_of(levels, MARKET)]


static func market_max_rarity(levels: Dictionary) -> int:
	return MARKET_MAX_RARITY[level_of(levels, MARKET)]


## Högsta nivå smedjan kan höja ett föremål till (§4.1).
static func forge_max_item_level(levels: Dictionary) -> int:
	return level_of(levels, FORGE)


## Kan smedjan över huvud taget röra [param item]? Nivå 2 krävs för rare
## (§4.1), och episka föremål rörs aldrig.
static func forge_can_upgrade(levels: Dictionary, item: Item) -> bool:
	if item == null or item.rarity >= Rules.Rarity.EPIC:
		return false
	if item.level >= mini(Item.MAX_LEVEL, forge_max_item_level(levels)):
		return false
	if item.rarity >= Rules.Rarity.RARE and level_of(levels, FORGE) < 2:
		return false
	return true


static func upgrade_price(item: Item) -> int:
	if item == null or item.level >= UPGRADE_PRICE.size():
		return 0
	return UPGRADE_PRICE[item.level]


static func gear_price(rarity: int) -> int:
	if rarity < 0 or rarity >= GEAR_PRICE.size():
		return 0
	return GEAR_PRICE[rarity]
