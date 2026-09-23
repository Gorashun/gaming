class_name Content
extends RefCounted
## M1-innehåll enligt docs/GAME_DESIGN.md §4. Ren data, inga Node-beroenden.
##
## Allt här är fritt tuningbart av run-simulatorn (GAME_DESIGN §4.8): HP,
## attackvärden, armor, thorns, magnitude och vikter. Reglerna som konsumerar
## datan ligger i src/core/ och är låsta.

# --- §4.2 Sidkatalog -------------------------------------------------------

## De åtta smidbara sidorna. Nyckel = face-id.
const FORGEABLE_FACES: Dictionary = {
	"POISON_DROP": {"name": "Venom Drop", "value": 2, "effect": Rules.FaceEffectKind.APPLY_POISON, "magnitude": 2, "rarity": Rules.Rarity.COMMON},
	"EMBER": {"name": "Ember", "value": 3, "effect": Rules.FaceEffectKind.APPLY_BURN, "magnitude": 2, "rarity": Rules.Rarity.COMMON},
	"HOLLOW": {"name": "Hollow Face", "value": 0, "effect": Rules.FaceEffectKind.REFUND_REROLL, "magnitude": 1, "rarity": Rules.Rarity.COMMON},
	"SNOWBALL": {"name": "Snowball", "value": 1, "effect": Rules.FaceEffectKind.GROW, "magnitude": 1, "rarity": Rules.Rarity.UNCOMMON},
	"VAMP_FANG": {"name": "Vampire Fang", "value": 3, "effect": Rules.FaceEffectKind.LIFESTEAL, "magnitude": 50, "rarity": Rules.Rarity.UNCOMMON},
	"TWIN_EYE": {"name": "Twin Eye", "value": 0, "effect": Rules.FaceEffectKind.COPY_LEFT, "magnitude": 0, "rarity": Rules.Rarity.UNCOMMON},
	"HAMMER_FACE": {"name": "Forge Hammer", "value": 4, "effect": Rules.FaceEffectKind.ANVIL_SELF, "magnitude": 0, "rarity": Rules.Rarity.RARE},
	"LEAD_SIX": {"name": "Lead Six", "value": 6, "effect": Rules.FaceEffectKind.LOCKED, "magnitude": 0, "rarity": Rules.Rarity.RARE},
}

# --- §4.6 Reliker (regelkrokar) -----------------------------------------------
# [b]M6: reliker är inte längre en belöning.[/b] De sex relikerna blev gear
# (se [constant GEAR], samma id:n) och kategorin RELIC utgick ur belöningspoolen
# (DECISIONS 2026-09-23). Tabellen står kvar som [i]regelkatalog[/i]: resolverns
# krokar (BLOOD_PRICE, DOMINO …) heter fortfarande så, character sheetet ritar
# fortfarande klassreliken, och en v3-sparfil migreras via den.

const RELICS: Dictionary = {
	"BLOOD_PRICE": {"name": "Blood Price", "rarity": Rules.Rarity.COMMON},
	"BROKEN_SCALE": {"name": "Broken Scale", "rarity": Rules.Rarity.UNCOMMON},
	"OCTOPUS": {"name": "The Octopus", "rarity": Rules.Rarity.UNCOMMON},
	"ECHO_MIRROR": {"name": "Echo Mirror", "rarity": Rules.Rarity.RARE},
	"CHEAT_CUBE": {"name": "Cheat Cube", "rarity": Rules.Rarity.RARE},
	"DOMINO": {"name": "The Domino", "rarity": Rules.Rarity.RARE},
}

# --- CORRIDOR_DESIGN §4.2: relik → utrustningsslot -------------------------
# [b]Presentationsdata, inte en regel.[/b] Den ligger i src/data/ och aldrig i
# src/core/ av exakt det skäl §4.2 anger: core vet inte vad en axel är. Ingen
# funktion i src/core/ läser tabellen; den finns för character sheetet.

const SLOT_HEAD: String = "HEAD"
const SLOT_CHEST: String = "CHEST"
const SLOT_HANDS: String = "HANDS"
const SLOT_WEAPON: String = "WEAPON"
const SLOT_LEGS: String = "LEGS"
const SLOT_BACK: String = "BACK"
const SLOT_AMULET: String = "AMULET"

## De sju slotsen i den ordning de ritas runt figuren (DECISIONS 2026-09-21,
## mockupen design/mockup_character_sheet.html): fyra till vänster, tre till
## höger med "CHANGE LOOK" under.
const SHEET_SLOTS: Array[String] = [
	SLOT_HEAD, SLOT_AMULET, SLOT_CHEST, SLOT_BACK,
	SLOT_WEAPON, SLOT_HANDS, SLOT_LEGS,
]

## CORRIDOR_DESIGN §4.2, ordagrant, med ett tillägg: designen listar
## [code]SLOT_SPARE[/code] ("en riggad tärning i en bältespung") medan DECISIONS
## låste sju slots utan reservplats. Bältespungen ritas därför på [b]ryggen[/b] –
## samma bild, en plats som finns. Se docs/ARCHITECTURE.md.
const RELIC_SLOTS: Dictionary = {
	"ECHO_MIRROR": SLOT_HEAD,
	"BLOOD_PRICE": SLOT_CHEST,
	"OCTOPUS": SLOT_HANDS,
	"DOMINO": SLOT_WEAPON,
	"BROKEN_SCALE": SLOT_AMULET,
	"CHEAT_CUBE": SLOT_BACK,
}


## Sloten en relik hänger i, eller tom sträng. [code]ANVIL_BLESSING[/code] är
## klassreliken och har ingen slot: den är ett brännmärke på underarmen (§4.1).
static func relic_slot(relic_id: String) -> String:
	return String(RELIC_SLOTS.get(relic_id, ""))


## Översättningsnyckeln för en slotetikett. Nycklarna fanns redan i M2.5:s CSV.
static func sheet_slot_key(slot: String) -> String:
	return "SMITH_SLOT_%s" % slot


# --- M6: Gear (PROGRESSION_REDESIGN §3.5) ------------------------------------
# 22 föremål ur §3.5 plus de sex relikerna, omgjorda till gear i den slot
# [constant RELIC_SLOTS] redan hängde dem på (DECISIONS 2026-09-23: reliker →
# gear). Effekternas regler står i [GearRules]; här är bara data.
#
# [b]Läsbarhetslag 2 (§3.2):[/b] högst en ren stat-effekt per föremål, och bara
# på COMMON. [code]tests/test_gear.gd[/code] fäller bygget annars.
#
# [code]sources[/code] är dropkällorna: fiende-id, eller ELITE / ALTAR.
# [code]per_level[/code] är hur mycket effekten växer per smedjenivå.

const GEAR: Dictionary = {
	"SCRAP_CAP": {"name": "Scrap Cap", "slot": SLOT_HEAD, "rarity": Rules.Rarity.COMMON,
		"effects": [{"kind": "MAX_HP", "amount": 6, "per_level": 3}], "sources": ["RUST_RAT"]},
	"TALLOW_HOOD": {"name": "Tallow Hood", "slot": SLOT_HEAD, "rarity": Rules.Rarity.UNCOMMON,
		"effects": [{"kind": "FIRST_ROUND_REROLL", "amount": 1}], "sources": ["SLAG_MOTH"]},
	"PIPSIGHT_LENS": {"name": "Pipsight Lens", "slot": SLOT_HEAD, "rarity": Rules.Rarity.RARE,
		"effects": [{"kind": "PIP_BONUS", "face_value": 1, "amount": 1}], "sources": ["PIP_THIEF"]},
	"SLAG_PLATE": {"name": "Slag Plate", "slot": SLOT_CHEST, "rarity": Rules.Rarity.COMMON,
		"effects": [{"kind": "PLAYER_ARMOR", "amount": 2, "per_level": 1}], "sources": ["IRON_TICK"]},
	"TICK_CARAPACE": {"name": "Tick Carapace", "slot": SLOT_CHEST, "rarity": Rules.Rarity.UNCOMMON,
		"effects": [{"kind": "WARD_RETAIN", "percent": 50}], "sources": ["IRON_TICK", "ELITE"]},
	"KILN_VEST": {"name": "Kiln Vest", "slot": SLOT_CHEST, "rarity": Rules.Rarity.RARE,
		"effects": [{"kind": "CHARGE_IF_UNHURT", "amount": 4, "per_level": 1}], "sources": ["ALTAR"]},
	"GRIP_WRAPS": {"name": "Grip Wraps", "slot": SLOT_HANDS, "rarity": Rules.Rarity.COMMON,
		"effects": [{"kind": "COMBAT_REROLL", "amount": 1}], "sources": ["RUST_RAT"]},
	"TONG_GLOVES": {"name": "Tong Gloves", "slot": SLOT_HANDS, "rarity": Rules.Rarity.UNCOMMON,
		"effects": [{"kind": "ANVIL_THRESHOLD", "value": 4}], "sources": ["GRAVE_HAND"]},
	"THIEFS_MITTS": {"name": "Thief's Mitts", "slot": SLOT_HANDS, "rarity": Rules.Rarity.RARE,
		"effects": [{"kind": "LEFTMOST_BONUS", "amount": 2, "per_level": 1}], "sources": ["PIP_THIEF", "ELITE"]},
	"CHIPPED_HAMMER": {"name": "Chipped Hammer", "slot": SLOT_WEAPON, "rarity": Rules.Rarity.COMMON,
		"effects": [{"kind": "ARMOR_PIERCE_SLOT", "slot": 4, "amount": 2, "per_level": 1}], "sources": ["RUST_RAT"]},
	"SPIKE_MAUL": {"name": "Spike Maul", "slot": SLOT_WEAPON, "rarity": Rules.Rarity.UNCOMMON,
		"effects": [{"kind": "ARMOR_PIERCE_BIGGEST", "amount": 3, "per_level": 1}], "sources": ["THORN_IMP"]},
	"MOTH_EDGE": {"name": "Moth Edge", "slot": SLOT_WEAPON, "rarity": Rules.Rarity.UNCOMMON,
		"effects": [{"kind": "CHARGE_ON_KILL", "amount": 3, "per_level": 1}], "sources": ["SLAG_MOTH"]},
	"SLAGJAW_TOOTH": {"name": "Slagjaw's Tooth", "slot": SLOT_WEAPON, "rarity": Rules.Rarity.EPIC,
		"effects": [{"kind": "OVERFLOW_IGNORES_ARMOR"}], "sources": ["SLAGJAW"]},
	"RUST_GREAVES": {"name": "Rust Greaves", "slot": SLOT_LEGS, "rarity": Rules.Rarity.COMMON,
		"effects": [{"kind": "WARD_ON_ROUND_START", "amount": 2, "per_level": 1}], "sources": ["RUST_RAT"]},
	"CART_BOOTS": {"name": "Cart Boots", "slot": SLOT_LEGS, "rarity": Rules.Rarity.UNCOMMON,
		"effects": [{"kind": "START_CHARGE", "amount": 5, "per_level": 2}], "sources": ["GRAVE_HAND"]},
	"PIT_STRIDERS": {"name": "Pit Striders", "slot": SLOT_LEGS, "rarity": Rules.Rarity.RARE,
		"effects": [{"kind": "FIRST_ROUND_EXTRA_DIE", "amount": 1}], "sources": ["SLAGJAW"]},
	"DICE_POUCH": {"name": "Dice Pouch", "slot": SLOT_BACK, "rarity": Rules.Rarity.COMMON,
		"effects": [{"kind": "UNPLACED_CHARGE_BONUS", "amount": 1}], "sources": ["SLAG_MOTH"]},
	"CHALK_SATCHEL": {"name": "Chalk Satchel", "slot": SLOT_BACK, "rarity": Rules.Rarity.UNCOMMON,
		"effects": [{"kind": "CHARGE_CAP", "value": 32}], "sources": ["ALTAR"]},
	"MARROWS_TARP": {"name": "Marrow's Tarp", "slot": SLOT_BACK, "rarity": Rules.Rarity.RARE,
		"effects": [{"kind": "RESCUE_BONUS", "amount": 1}], "sources": ["GRAVE_HAND", "ELITE"]},
	"BONE_TALLY": {"name": "Bone Tally", "slot": SLOT_AMULET, "rarity": Rules.Rarity.COMMON,
		"effects": [{"kind": "DAMAGE_PER_KILL", "amount": 1}], "sources": ["THORN_IMP"]},
	"TWIN_PIP": {"name": "Twin Pip", "slot": SLOT_AMULET, "rarity": Rules.Rarity.RARE,
		"effects": [{"kind": "HOUSE_TWO_PAIR"}], "sources": ["SLAGJAW"]},
	"SIXTH_SEAT": {"name": "Sixth Seat", "slot": SLOT_AMULET, "rarity": Rules.Rarity.EPIC,
		"effects": [{"kind": "EXTRA_SLOT", "amount": 1}], "sources": ["SLAGJAW"]},
	# De sex relikerna, i sina RELIC_SLOTS-platser. Regeln är resolverns krok.
	"BLOOD_PRICE": {"name": "Blood Price", "slot": SLOT_CHEST, "rarity": Rules.Rarity.COMMON,
		"effects": [{"kind": "RULE", "rule": "BLOOD_PRICE"}], "sources": ["THORN_IMP"]},
	"BROKEN_SCALE": {"name": "Broken Scale", "slot": SLOT_AMULET, "rarity": Rules.Rarity.UNCOMMON,
		"effects": [{"kind": "RULE", "rule": "BROKEN_SCALE"}], "sources": ["IRON_TICK"]},
	"OCTOPUS": {"name": "The Octopus", "slot": SLOT_HANDS, "rarity": Rules.Rarity.UNCOMMON,
		"effects": [{"kind": "RULE", "rule": "OCTOPUS"}], "sources": ["PIP_THIEF"]},
	"ECHO_MIRROR": {"name": "Echo Mirror", "slot": SLOT_HEAD, "rarity": Rules.Rarity.RARE,
		"effects": [{"kind": "RULE", "rule": "ECHO_MIRROR"}], "sources": ["ALTAR"]},
	"CHEAT_CUBE": {"name": "Cheat Cube", "slot": SLOT_BACK, "rarity": Rules.Rarity.RARE,
		"effects": [{"kind": "RULE", "rule": "CHEAT_CUBE"}], "sources": ["ALTAR"]},
	"DOMINO": {"name": "The Domino", "slot": SLOT_WEAPON, "rarity": Rules.Rarity.RARE,
		"effects": [{"kind": "RULE", "rule": "DOMINO"}], "sources": ["SLAGJAW", "ELITE"]},
}

## De 22 föremålen ur §3.5, i tabellens ordning. Kritväggens samling räknar dem.
const GEAR_CATALOGUE_22: Array[String] = [
	"SCRAP_CAP", "TALLOW_HOOD", "PIPSIGHT_LENS", "SLAG_PLATE", "TICK_CARAPACE",
	"KILN_VEST", "GRIP_WRAPS", "TONG_GLOVES", "THIEFS_MITTS", "CHIPPED_HAMMER",
	"SPIKE_MAUL", "MOTH_EDGE", "SLAGJAW_TOOTH", "RUST_GREAVES", "CART_BOOTS",
	"PIT_STRIDERS", "DICE_POUCH", "CHALK_SATCHEL", "MARROWS_TARP", "BONE_TALLY",
	"TWIN_PIP", "SIXTH_SEAT",
]

## Dropkällor som inte är fiender.
const SOURCE_ELITE: String = "ELITE"
const SOURCE_ALTAR: String = "ALTAR"


static func gear_key(id: String) -> String:
	return "GEAR_%s" % id


static func gear_desc_key(id: String) -> String:
	return "GEAR_%s_DESC" % id


## Ett färskt föremål ur katalogen, nivå 0, säkrat. Okänt id ger null.
static func make_item(id: String) -> Item:
	if not GEAR.has(id):
		return null
	var d: Dictionary = GEAR[id]
	var item: Item = Item.new(id, String(d["slot"]), int(d["rarity"]))
	item.display_name = String(d["name"])
	# De omgjorda relikerna har sina ikoner under relic.<ID> i art-manifestet.
	if RELICS.has(id):
		item.icon_id = "relic.%s" % id
	var effects: Array[Dictionary] = []
	for raw: Variant in d["effects"] as Array:
		effects.append((raw as Dictionary).duplicate(true))
	item.effects = effects
	return item


## Id:n på alla föremål med [param rarity] som [param source] kan droppa.
## Tom [param source] = alla källor.
static func gear_ids(rarity: int, source: String = "") -> Array[String]:
	var out: Array[String] = []
	for id: String in GEAR:
		var d: Dictionary = GEAR[id]
		if int(d["rarity"]) != rarity:
			continue
		if source != "" and not (d["sources"] as Array).has(source):
			continue
		out.append(id)
	return out


## En relik-id ur en v3-sparfil → föremålet den blev. Klassreliken
## (ANVIL_BLESSING) är ingen gear och ger null.
static func item_for_relic(relic_id: String) -> Item:
	if not RELICS.has(relic_id):
		return null
	return make_item(relic_id)


# --- M6: Quirks (PROGRESSION_REDESIGN §4.2) -----------------------------------
# En per hjälte, smak inte bokföring. Effekterna går genom samma regelmotor som
# gear ([GearRules]) och syns därför i kvittot med hjältens quirk som källa.

const QUIRKS: Dictionary = {
	"HEAVY_HANDED": {"name": "Heavy-Handed", "effects": [
		{"kind": "PIP_BONUS", "face_value": 6, "amount": 1},
		{"kind": "PIP_BONUS", "face_value": 1, "amount": -1},
	]},
	"SUPERSTITIOUS": {"name": "Superstitious", "effects": [
		{"kind": "COMBAT_REROLL", "amount": 1},
	]},
	"HOARDER": {"name": "Hoarder", "effects": [
		{"kind": "CHARGE_PER_ROUND", "amount": 2},
		{"kind": "CHARGE_CAP_DELTA", "amount": -5},
	]},
	"RIGHT_HANDED": {"name": "Right-Handed", "effects": [
		{"kind": "SLOT_BONUS", "slot": 4, "amount": 2},
		{"kind": "SLOT_BONUS", "slot": 0, "amount": -1},
	]},
}


static func quirk_key(id: String) -> String:
	return "HERO_QUIRK_%s" % id


## Quirken som ett pseudo-föremål utan slot, så att resolvern och kvittot kan
## behandla den exakt som gear. Okänd eller tom quirk ger null.
static func quirk_item(id: String) -> Item:
	if not QUIRKS.has(id):
		return null
	var d: Dictionary = QUIRKS[id]
	var item: Item = Item.new("QUIRK_%s" % id, "", Rules.Rarity.COMMON)
	item.display_name = String(d["name"])
	item.name_key = quirk_key(id)
	item.effect_summary_key = "%s_DESC" % quirk_key(id)
	item.icon_id = "quirk.%s" % id
	var effects: Array[Dictionary] = []
	for raw: Variant in d["effects"] as Array:
		effects.append((raw as Dictionary).duplicate(true))
	item.effects = effects
	return item


## Namnlistan tavernan rekryterar ur. Egennamn: de översätts inte.
const HERO_NAMES: Array[String] = [
	"Brann", "Hild", "Osk", "Tamsin", "Wren", "Corbin", "Maude", "Pell",
	"Ysolde", "Garrick", "Nell", "Bram", "Isa", "Dunstan", "Fenn", "Ottilie",
	"Rook", "Agna", "Tobiah", "Sefa", "Crane", "Idony", "Mabry", "Ulf",
]


## Ny rekryt. Namnet och quirken är seedade ur [param rng]; [param taken] är
## namn som redan finns i rostret eller på Gravlunden och undviks så länge det
## går.
static func recruit_hero(rng: Rng, taken: Array = [], body_variant: String = "a", level: int = 1) -> Hero:
	var free: Array[String] = []
	for candidate: String in HERO_NAMES:
		if not taken.has(candidate):
			free.append(candidate)
	var names: Array[String] = free if not free.is_empty() else HERO_NAMES
	var hero: Hero = Hero.new("", names[rng.next_int(0, names.size() - 1)])
	var quirk_ids: Array = QUIRKS.keys()
	quirk_ids.sort()
	hero.quirk = String(quirk_ids[rng.next_int(0, quirk_ids.size() - 1)])
	hero.body_variant = body_variant
	hero.level = clampi(level, 1, Hero.MAX_LEVEL)
	hero.xp = Hero.XP_FOR_LEVEL[hero.level]
	return hero


# --- §4.7 SLOT_SWAP-pool ---------------------------------------------------

const SLOT_SWAPS: Dictionary = {
	"SWAP_CHARGE": {"name": "Charge Slot", "slot_type": Rules.SlotType.CHARGE, "rarity": Rules.Rarity.COMMON},
	"SWAP_VOID": {"name": "Void Slot", "slot_type": Rules.SlotType.VOID, "rarity": Rules.Rarity.COMMON},
	"SWAP_FIRE": {"name": "Fire Slot", "slot_type": Rules.SlotType.FIRE, "rarity": Rules.Rarity.UNCOMMON},
	"SWAP_ANVIL": {"name": "Anvil Slot", "slot_type": Rules.SlotType.ANVIL, "rarity": Rules.Rarity.UNCOMMON},
	"SWAP_MIRROR": {"name": "Mirror Slot", "slot_type": Rules.SlotType.MIRROR, "rarity": Rules.Rarity.RARE},
}


# --- §4.1 Klasser ----------------------------------------------------------

## Spelbara klasser. M1 har bara Smeden.
const CLASSES: Dictionary = {
	"SMITH": {"name": "The Smith", "relic": "ANVIL_BLESSING"},
}

# --- Översättningsnycklar --------------------------------------------------
# Namnen ovan är KÄLLSPRÅKET (engelska). Det som visas för spelaren slås upp på
# en nyckel som härleds ur id:t, så att en översättning aldrig behöver röra
# innehållet: tr("ENEMY_RUST_RAT") ger "Rust Rat" på en och "Rostråttan" på sv.
# Nycklarna ligger i assets/i18n/translations.csv och verifieras av
# tests/test_i18n.gd.

static func face_key(id: String) -> String:
	return "FACE_%s" % id


static func relic_key(id: String) -> String:
	return "RELIC_%s" % id


static func enemy_key(id: String) -> String:
	return "ENEMY_%s" % id


## SLOT_SWAP-id:na är redan nycklar ("SWAP_CHARGE").
static func slot_swap_key(id: String) -> String:
	return id


static func class_key(id: String) -> String:
	return "CLASS_%s" % id


static func make_face(id: String) -> Face:
	if not FORGEABLE_FACES.has(id):
		return Face.new(id, 0)
	var d: Dictionary = FORGEABLE_FACES[id]
	return Face.new(id, int(d["value"]), int(d["effect"]), int(d["magnitude"]))


static func make_relic(id: String) -> Relic:
	if not RELICS.has(id):
		return Relic.new(id)
	var d: Dictionary = RELICS[id]
	return Relic.new(id, int(d["rarity"]), String(d["name"]))


## Hela belöningspoolen som Rewards.generate() drar ur: sidor och slot-byten.
## [b]Gear ligger inte här[/b] – det droppar från fiender ([Drops]) och läggs in
## bland de tre korten efter striden. RELIC utgick i M6.
static func reward_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for id: String in FORGEABLE_FACES:
		var f: Dictionary = FORGEABLE_FACES[id]
		pool.append({
			"id": "FORGE_%s" % id,
			"category": Rewards.CATEGORY_FORGE_FACE,
			"name": String(f["name"]),
			"name_key": face_key(id),
			"rarity": int(f["rarity"]),
			"data": {"face_id": id},
		})
	for id: String in SLOT_SWAPS:
		var s: Dictionary = SLOT_SWAPS[id]
		pool.append({
			"id": id,
			"category": Rewards.CATEGORY_SLOT_SWAP,
			"name": String(s["name"]),
			"name_key": slot_swap_key(id),
			"rarity": int(s["rarity"]),
			"data": {"slot_type": int(s["slot_type"])},
		})
	return pool


# --- §4.4 Fiender ----------------------------------------------------------

static func make_enemy(id: String) -> Enemy:
	var enemy: Enemy = null
	match id:
		"RUST_RAT":
			enemy = Enemy.new(id, 28, 3, "Rust Rat")
			enemy.armor = 2
		"SLAG_MOTH":
			enemy = Enemy.new(id, 34, 4, "Slag Moth")
			enemy.armor = 1
			enemy.special = "DRAIN_CHARGE"
		"THORN_IMP":
			enemy = Enemy.new(id, 40, 3, "Thorn Imp")
			enemy.armor = 2
			enemy.thorns = 2
		"PIP_THIEF":
			enemy = Enemy.new(id, 46, 4, "Pip Thief")
			enemy.armor = 1
			enemy.special = "STEAL"
		"IRON_TICK":
			enemy = Enemy.new(id, 46, 5, "Iron Tick")
			enemy.armor = 6
		"GRAVE_HAND":
			enemy = Enemy.new(id, 60, 6, "Grave Hand")
			enemy.armor = 2
			enemy.special = "GRAB"
		"SLAGJAW":
			enemy = Enemy.new(id, 210, 7, "Slagjaw")
			enemy.armor = 3
			enemy.special = "HARDEN"
		_:
			enemy = Enemy.new(id, 10, 1, id)
	return enemy


## Möten på våning 1 (GAME_DESIGN §4.4). Rum 3 har två varianter; [param variant]
## väljs seedat av run-loopen.
static func encounter(room: int, variant: int = 0) -> Array[Enemy]:
	var ids: Array[String] = []
	match room:
		1:
			ids = ["RUST_RAT", "RUST_RAT", "RUST_RAT", "RUST_RAT"]
		2:
			ids = ["IRON_TICK", "SLAG_MOTH", "RUST_RAT"]
		3:
			if variant == 0:
				ids = ["THORN_IMP", "IRON_TICK", "RUST_RAT"]
			else:
				ids = ["PIP_THIEF", "GRAVE_HAND"]
		4:
			ids = ["SLAGJAW"]
		_:
			ids = ["RUST_RAT"]
	var enemies: Array[Enemy] = []
	for id: String in ids:
		enemies.append(make_enemy(id))
	return enemies


static func rooms_per_floor() -> int:
	return 4


# --- §A.3 Belöningspoolen efter M6 ------------------------------------------

## Poolen en spelare drar ur. [b]M6: Pips köper inte längre poolposter[/b]
## (DECISIONS 2026-09-23, PROGRESSION_REDESIGN §6), så hela poolen är öppen från
## första run. Parametern står kvar för att en gammal profils köplista inte
## ska ändra vad som dras.
static func unlocked_pool(_unlocked: Array = []) -> Array[Dictionary]:
	return reward_pool()


## Antal fiender Kodexen kan innehålla. Tutorialvåningens pedagogiska varianter
## räknas inte: Kodexen handlar om Gropen, inte om Grundstigen.
static func codex_enemy_count() -> int:
	return 7


# --- §A.1 Marrows dödsrepliker ---------------------------------------------
# "Marrows dödsrepliker är den viktigaste texten i spelet" (TOWN_AND_ONBOARDING
# §A.1). Regeln: varje replik namnger DÖDSORSAKEN – vi har den redan i
# player_died{killed_by} – och lägger till en rad värld. Aldrig samma två
# gånger i rad.
#
# Källsträngen är engelska (CLAUDE.md); nyckeln får sin svenska rad i
# assets/i18n/translations.csv. Tills raden finns visas den engelska via
# Tokens.translate_or, aldrig en rå nyckel.

## [code]{key, en, killer}[/code]. Tom [code]killer[/code] = passar alla dödar.
const DEATH_LINES: Array[Dictionary] = [
	{"key": "DEATH_LINE_SLAGJAW_01", "killer": "SLAGJAW", "en": "Slagjaw again. It has all the time in the world and you had eleven minutes."},
	{"key": "DEATH_LINE_SLAGJAW_02", "killer": "SLAGJAW", "en": "It hardens when it is bored. You bored it."},
	{"key": "DEATH_LINE_THORN_IMP_01", "killer": "THORN_IMP", "en": "You hit a thorn imp four times. It hit you back four times. That is what four means."},
	{"key": "DEATH_LINE_THORN_IMP_02", "killer": "THORN_IMP", "en": "Little thing. Lot of edges. You knew that going in."},
	{"key": "DEATH_LINE_RUST_RAT_01", "killer": "RUST_RAT", "en": "Rats. Plural. That is usually how it reads on the wall."},
	{"key": "DEATH_LINE_RUST_RAT_02", "killer": "RUST_RAT", "en": "Two armour. Two. And you threw fives at it all day."},
	{"key": "DEATH_LINE_IRON_TICK_01", "killer": "IRON_TICK", "en": "An iron tick does not dodge. It waits for you to run out of arm."},
	{"key": "DEATH_LINE_IRON_TICK_02", "killer": "IRON_TICK", "en": "Six armour eats small hits for a living. You fed it well."},
	{"key": "DEATH_LINE_SLAG_MOTH_01", "killer": "SLAG_MOTH", "en": "The moth drank your bank and then drank you. Tidy work."},
	{"key": "DEATH_LINE_GRAVE_HAND_01", "killer": "GRAVE_HAND", "en": "It held one slot shut and that was the whole argument."},
	{"key": "DEATH_LINE_PIP_THIEF_01", "killer": "PIP_THIEF", "en": "It took a die first. Everything after that was bookkeeping."},
	{"key": "DEATH_LINE_BLOOD_PRICE_01", "killer": "BLOOD_PRICE", "en": "You paid in blood for a multiplier. The multiplier was fine. You were not."},
	{"key": "DEATH_LINE_ANY_01", "killer": "", "en": "Cart's warm. Sit down before you say anything clever."},
	{"key": "DEATH_LINE_ANY_02", "killer": "", "en": "Someone will rub out your mark eventually. Not me."},
	{"key": "DEATH_LINE_ANY_03", "killer": "", "en": "Nobody down there was in a hurry. You were."},
	{"key": "DEATH_LINE_ANY_04", "killer": "", "en": "I have carried better. I have carried worse. Mostly worse."},
	{"key": "DEATH_LINE_ANY_05", "killer": "", "en": "The order was wrong. It is almost always the order."},
	{"key": "DEATH_LINE_ANY_06", "killer": "", "en": "You got further than the last one. The last one is still down there."},
	{"key": "DEATH_LINE_ANY_07", "killer": "", "en": "Chalk's cheap. That is the only kind thing about the wall."},
	{"key": "DEATH_LINE_ANY_08", "killer": "", "en": "Keep the seed. The pit does not change its mind, only you do."},
]


## En replik som passar [param killed_by], aldrig samma som [param avoid_index].
## Returnerar [code]{index, key, en}[/code]. Tom [code]key[/code] betyder att
## katalogen är tom, vilket bara kan hända om någon tömt konstanten.
static func death_line_for(killed_by: String, avoid_index: int = -1, spin: int = 0) -> Dictionary:
	var specific: Array[int] = []
	var generic: Array[int] = []
	for i: int in range(DEATH_LINES.size()):
		var line: Dictionary = DEATH_LINES[i]
		if String(line["killer"]) == killed_by and killed_by != "":
			specific.append(i)
		elif String(line["killer"]) == "":
			generic.append(i)
	var pool: Array[int] = specific if not specific.is_empty() else generic
	if pool.is_empty():
		pool = generic if not generic.is_empty() else [0]
	# Aldrig samma två gånger i rad (§A.1). Finns bara en passande replik får
	# den upprepas – det är bättre än en generisk rad som inte nämner dödsorsaken.
	# [param spin] är runnens seed: variationen blir deterministisk, så en
	# buggrapport med samma seed får samma replik.
	var start: int = posmod(spin, pool.size())
	var pick: int = pool[start]
	for step: int in range(pool.size()):
		var candidate: int = pool[(start + step) % pool.size()]
		if candidate != avoid_index:
			pick = candidate
			break
	var chosen: Dictionary = DEATH_LINES[pick]
	return {"index": pick, "key": String(chosen["key"]), "en": String(chosen["en"])}


# --- §4.1 Klass: Smeden (SMITH) ----------------------------------------------------

## Ett färskt CombatState för Smeden, utan fiender. Anroparen sätter enemies.
static func smith_state() -> CombatState:
	var state: CombatState = CombatState.new()
	state.board = Board.smith_board()
	state.player_max_hp = 100
	state.player_hp = 100
	state.rerolls_left = 1
	var dice: Array[Die] = []
	for i: int in range(6):
		dice.append(Die.standard("die_%d" % i, Rules.DieMaterial.IRON))
	state.dice = dice
	state.relics = [Relic.new("ANVIL_BLESSING", Rules.Rarity.COMMON, "Anvil Blessing")]
	return state
