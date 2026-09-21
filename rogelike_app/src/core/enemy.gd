class_name Enemy
extends RefCounted
## En fiende i kön. GAME_DESIGN.md §2.1 och §4.4.
## Listan är ordnad front→bak; index 0 är den främsta och tar skadan först.

var id: String = ""
var display_name: String = ""
var hp: int = 10
var max_hp: int = 10
## Dras av per damage_dealt-instans.
var armor: int = 0
## Skada tillbaka till spelaren per damage_dealt med dealt > 0.
var thorns: int = 0
## Stacks. Tickar i P4, avtar med 1 per runda.
var burn: int = 0
## Stacks. Tickar i P4, avtar aldrig.
var poison: int = 0
var intent: Intent = null
## Specialens id, t.ex. "DRAIN_CHARGE". "" om ingen.
var special: String = ""
## Attackvärdet som advance() använder när intent väljs.
var attack: int = 0


func _init(p_id: String = "", p_max_hp: int = 10, p_attack: int = 0, p_name: String = "") -> void:
	id = p_id
	max_hp = p_max_hp
	hp = p_max_hp
	attack = p_attack
	display_name = p_name if p_name != "" else p_id
	intent = Intent.new(Rules.IntentKind.ATTACK, p_attack)


func is_alive() -> bool:
	return hp > 0


func copy() -> Enemy:
	var other: Enemy = Enemy.new(id, max_hp, attack, display_name)
	other.hp = hp
	other.armor = armor
	other.thorns = thorns
	other.burn = burn
	other.poison = poison
	other.special = special
	other.intent = intent.copy() if intent != null else null
	return other


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"hp": hp,
		"max_hp": max_hp,
		"armor": armor,
		"thorns": thorns,
		"burn": burn,
		"poison": poison,
		"special": special,
		"attack": attack,
		"intent": intent.to_dict() if intent != null else {},
	}


static func from_dict(data: Dictionary) -> Enemy:
	var enemy: Enemy = Enemy.new(
		String(data.get("id", "")),
		int(data.get("max_hp", 10)),
		int(data.get("attack", 0)),
		String(data.get("display_name", "")),
	)
	enemy.hp = int(data.get("hp", enemy.max_hp))
	enemy.armor = int(data.get("armor", 0))
	enemy.thorns = int(data.get("thorns", 0))
	enemy.burn = int(data.get("burn", 0))
	enemy.poison = int(data.get("poison", 0))
	enemy.special = String(data.get("special", ""))
	var intent_data: Dictionary = data.get("intent", {}) as Dictionary
	enemy.intent = Intent.from_dict(intent_data) if not intent_data.is_empty() else null
	return enemy
