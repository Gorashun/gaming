class_name Enemy
extends RefCounted
## En fiende i kön. Kedjan slår alltid den främsta levande fienden; överskott
## rullar vidare till nästa (PROPOSAL §3, regel 2).

var id: String = ""
var display_name: String = ""
var max_hp: int = 10
var hp: int = 10
## Platt reduktion per träff. Kan aldrig ta en träff under 0.
var armor: int = 0
## Skada fienden avser att göra nästa runda. Visas i UI före bekräftelse.
var intent: int = 0
var tags: Array[String] = []


func _init(p_id: String = "", p_max_hp: int = 10, p_armor: int = 0, p_name: String = "") -> void:
	id = p_id
	max_hp = p_max_hp
	hp = p_max_hp
	armor = p_armor
	display_name = p_name if p_name != "" else p_id


func is_alive() -> bool:
	return hp > 0


## Applicerar [param amount] skada efter rustning och returnerar ÖVERSKOTTET,
## dvs. skada som inte behövdes för att döda fienden. Överskottet är det som
## rullar vidare till nästa fiende.
func take_damage(amount: int) -> int:
	var effective: int = maxi(0, amount - armor)
	if effective <= 0:
		return 0
	var absorbed: int = mini(effective, hp)
	hp -= absorbed
	return effective - absorbed


func duplicate_enemy() -> Enemy:
	var copy: Enemy = Enemy.new(id, max_hp, armor, display_name)
	copy.hp = hp
	copy.intent = intent
	copy.tags = tags.duplicate()
	return copy


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"max_hp": max_hp,
		"hp": hp,
		"armor": armor,
		"intent": intent,
		"tags": tags.duplicate(),
	}


static func from_dict(data: Dictionary) -> Enemy:
	var enemy: Enemy = Enemy.new(
		String(data.get("id", "")),
		int(data.get("max_hp", 10)),
		int(data.get("armor", 0)),
		String(data.get("display_name", "")),
	)
	enemy.hp = int(data.get("hp", enemy.max_hp))
	enemy.intent = int(data.get("intent", 0))
	var tags: Array[String] = []
	for tag: Variant in data.get("tags", []) as Array:
		tags.append(String(tag))
	enemy.tags = tags
	return enemy
