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

# --- §4.6 Reliker ----------------------------------------------------------

const RELICS: Dictionary = {
	"BLOOD_PRICE": {"name": "Blood Price", "rarity": Rules.Rarity.COMMON},
	"BROKEN_SCALE": {"name": "Broken Scale", "rarity": Rules.Rarity.UNCOMMON},
	"OCTOPUS": {"name": "The Octopus", "rarity": Rules.Rarity.UNCOMMON},
	"ECHO_MIRROR": {"name": "Echo Mirror", "rarity": Rules.Rarity.RARE},
	"CHEAT_CUBE": {"name": "Cheat Cube", "rarity": Rules.Rarity.RARE},
	"DOMINO": {"name": "The Domino", "rarity": Rules.Rarity.RARE},
}

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


## Hela belöningspoolen som Rewards.generate() drar ur.
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
	for id: String in RELICS:
		var r: Dictionary = RELICS[id]
		pool.append({
			"id": "RELIC_%s" % id,
			"category": Rewards.CATEGORY_RELIC,
			"name": String(r["name"]),
			"name_key": relic_key(id),
			"rarity": int(r["rarity"]),
			"data": {"relic_id": id},
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


# --- §A.3 Skrotmarknaden ---------------------------------------------------

## Poolposter som [b]inte[/b] ingår i en färsk spelares belöningspool utan måste
## köpas loss på Skrotmarknaden. TOWN_AND_ONBOARDING §A.3: startpoolen ska vara
## liten från början och växa i paket som byter spelstil, inte droppa enstaka
## skräp ("awkward middle"-varningen i research/01 §A).
##
## Notera att detta [b]aldrig[/b] är en siffra: varje post är ett id som läggs
## till i [method Content.reward_pool]. Ingen +HP, ingen +skada.
const LOCKED_BY_DEFAULT: Array[String] = [
	"FORGE_SNOWBALL",
	"FORGE_VAMP_FANG",
	"FORGE_TWIN_EYE",
	"FORGE_HAMMER_FACE",
	"FORGE_LEAD_SIX",
	"RELIC_OCTOPUS",
	"RELIC_ECHO_MIRROR",
	"RELIC_CHEAT_CUBE",
	"RELIC_DOMINO",
	"SWAP_FIRE",
	"SWAP_ANVIL",
	"SWAP_MIRROR",
]


## Marknadens hyllor: exakt de poolposter som ligger bakom [Meta.pips].
## Priset kommer ur [constant Meta.PRICE] och är fast – ingen rabatt, ingen
## pity-timer, inget som ändrar sig när spelaren tittar bort.
static func market_catalogue() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in reward_pool():
		if LOCKED_BY_DEFAULT.has(String(entry.get("id", ""))):
			result.append(entry)
	return result


## Poolen en spelare faktiskt drar ur, givet vad som köpts loss.
static func unlocked_pool(unlocked: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in reward_pool():
		var id: String = String(entry.get("id", ""))
		if LOCKED_BY_DEFAULT.has(id) and not unlocked.has(id):
			continue
		result.append(entry)
	return result


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
