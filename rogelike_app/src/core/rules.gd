class_name Rules
extends RefCounted
## Normativa konstanter och uppräkningar ur docs/GAME_DESIGN.md §2.1.
##
## Att ändra något här är ett DESIGNBESLUT. Fasordningen P0–P5, definitionerna
## av angränsande/identisk/oanvänd, multiplikatortabellen, HOUSE-regeln,
## överflödsalgoritmen och slot-typernas regler är LÅSTA (GAME_DESIGN §4.8) och
## kräver en rad i docs/DECISIONS.md. HP, attackvärden, armor, thorns och
## CHARGE_CAP är fritt tuningbara av run-simulatorn.

enum DieMaterial {
	IRON,
	BONE,
	GLASS,
}

enum SlotType {
	PLAIN,
	FIRE,
	MIRROR,
	ANVIL,
	CHARGE,
	VOID,
}

enum ComboKind {
	NONE,
	PAIR,
	TRIPLE,
	QUAD,
	PENTA,
}

enum IntentKind {
	ATTACK,
	BLOCK,
	SPECIAL,
}

enum FaceEffectKind {
	NONE,
	COPY_LEFT, ## P1: värdet blir vänstergrannens effektiva värde.
	ANVIL_SELF, ## P1: dubblar om effektivt värde >= ANVIL_THRESHOLD.
	LOCKED, ## Roll-fas: tärningen kan inte kastas om.
	APPLY_POISON, ## P3.
	APPLY_BURN, ## P3.
	LIFESTEAL, ## P3.
	GROW, ## P5: ökar permanent (strid) om tärningen var oplacerad.
	REFUND_REROLL, ## Roll-fas: +1 omkast denna runda.
}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	## M6: bara gear. Belöningspoolens vikttabeller har tre kolumner och ger
	## därför EPIC vikt 0 – en sida eller ett slot-byte kan aldrig bli episk.
	EPIC,
}

## Antal slots på brädet. Slot i har alltid index == i.
const SLOT_COUNT: int = 5
## Antal sidor per tärning.
const FACE_COUNT: int = 6

const CHARGE_CAP: int = 20
const ANVIL_THRESHOLD: int = 5
const MULT_PAIR: int = 2
const MULT_TRIPLE: int = 4
const MULT_QUAD: int = 8
const MULT_PENTA: int = 16
const HOUSE_FACTOR: int = 2
## Spilld skada delas med detta och blir Charge.
const OVERFLOW_TO_CHARGE: int = 2
const BREATHER_HEAL: int = 10
## Tak på hur mycket LIFESTEAL kan läka per slot.
const LIFESTEAL_CAP: int = 8
## Högsta värde en sida kan växa till via GROW / ANVIL_BLESSING.
const MAX_FACE_VALUE: int = 9

## Multiplikator per gruppstorlek. Index = gruppstorlek.
const GROUP_MULTIPLIER: Array[int] = [1, 1, MULT_PAIR, MULT_TRIPLE, MULT_QUAD, MULT_PENTA]


static func combo_kind_for_size(size: int) -> int:
	match size:
		2:
			return ComboKind.PAIR
		3:
			return ComboKind.TRIPLE
		4:
			return ComboKind.QUAD
		5:
			return ComboKind.PENTA
	return ComboKind.NONE


static func combo_kind_name(kind: int) -> String:
	match kind:
		ComboKind.PAIR:
			return "PAIR"
		ComboKind.TRIPLE:
			return "TRIPLE"
		ComboKind.QUAD:
			return "QUAD"
		ComboKind.PENTA:
			return "PENTA"
	return "NONE"


static func multiplier_for_size(size: int) -> int:
	if size < 0 or size >= GROUP_MULTIPLIER.size():
		return 1
	return GROUP_MULTIPLIER[size]


static func slot_type_name(t: int) -> String:
	match t:
		SlotType.PLAIN:
			return "PLAIN"
		SlotType.FIRE:
			return "FIRE"
		SlotType.MIRROR:
			return "MIRROR"
		SlotType.ANVIL:
			return "ANVIL"
		SlotType.CHARGE:
			return "CHARGE"
		SlotType.VOID:
			return "VOID"
	return "UNKNOWN"


static func intent_kind_name(k: int) -> String:
	match k:
		IntentKind.ATTACK:
			return "ATTACK"
		IntentKind.BLOCK:
			return "BLOCK"
		IntentKind.SPECIAL:
			return "SPECIAL"
	return "UNKNOWN"


static func rarity_name(r: int) -> String:
	match r:
		Rarity.COMMON:
			return "common"
		Rarity.UNCOMMON:
			return "uncommon"
		Rarity.RARE:
			return "rare"
		Rarity.EPIC:
			return "epic"
	return "unknown"
