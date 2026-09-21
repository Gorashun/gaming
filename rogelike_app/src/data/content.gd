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
