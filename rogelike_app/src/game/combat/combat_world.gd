extends Node2D
## Stridens innehåll i [code]World[/code]-lagret: en [EnemyActor] per fiende.
##
## Positionerna kommer från krit-UI:ts fiendepaneler ([method
## EnemyPanel.anchor_point]). Båda [CanvasLayer]-lagren delar samma
## 1080×1920-koordinatrymd, så en sprite hamnar exakt bakom sin panel utan att
## någon av dem behöver känna till den andras layout.

var _actors: Dictionary = {}


## Bygger om hela uppsättningen. Anropas när ett rum börjar.
func build(enemies: Array[Enemy], radius: float) -> void:
	for child: Node in get_children():
		child.queue_free()
	_actors.clear()
	for i: int in range(enemies.size()):
		var enemy: Enemy = enemies[i]
		var actor: EnemyActor = EnemyActor.new()
		actor.name = "Enemy_%s_%d" % [enemy.id, i]
		add_child(actor)
		actor.build(enemy.id, i, radius)
		actor.set_alive(enemy.is_alive())
		_actors[_key(enemy.id, i)] = actor


func actor_at(index: int, enemy_id: String) -> EnemyActor:
	return _actors.get(_key(enemy_id, index), null) as EnemyActor


## Alla aktörer med ett visst fiende-id. Samma id kan förekomma flera gånger
## (rum 1 är fyra Rostråttor), därför indexeras de på id + position.
func actors_with_id(enemy_id: String) -> Array[EnemyActor]:
	var result: Array[EnemyActor] = []
	for key: String in _actors:
		if key.begins_with(enemy_id + "#"):
			result.append(_actors[key] as EnemyActor)
	return result


func place(index: int, enemy_id: String, point: Vector2) -> void:
	var actor: EnemyActor = actor_at(index, enemy_id)
	if actor != null:
		actor.place_at(point)


static func _key(enemy_id: String, index: int) -> String:
	return "%s#%d" % [enemy_id, index]
