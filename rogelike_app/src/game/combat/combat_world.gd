extends Node2D
## Stridens innehåll i [code]World[/code]-lagret: bakgrundsband, golv, Smeden
## och en [EnemyActor] per fiende.
##
## Positionerna kommer från krit-UI:ts fiendepaneler ([method
## EnemyPanel.anchor_point]) och från hjältens plats i samma rad. Båda
## [CanvasLayer]-lagren delar samma 1080×1920-koordinatrymd, så en sprite hamnar
## exakt bakom sin panel utan att någon av dem behöver känna till den andras
## layout.
##
## Bandet (parallax + golvkakel) byggs först när krit-UI:t har gjort sin layout,
## eftersom det är fiendezonens rect som avgör var horisonten ligger. Till dess
## finns inga noder alls – tomt är bättre än fel placerat.

var hero: HeroFigure = null

var _actors: Dictionary = {}
var _backdrop: Node2D = null
var _band: Rect2 = Rect2()
var _floor_y: float = 0.0


## Bygger om hela uppsättningen. Anropas när ett rum börjar.
func build(enemies: Array[Enemy], radius: float) -> void:
	for child: Node in get_children():
		child.queue_free()
	_actors.clear()
	_backdrop = null
	hero = null
	for i: int in range(enemies.size()):
		var enemy: Enemy = enemies[i]
		var actor: EnemyActor = EnemyActor.new()
		actor.name = "Enemy_%s_%d" % [enemy.id, i]
		actor.z_index = 2
		add_child(actor)
		actor.build(enemy.id, i, radius)
		actor.set_alive(enemy.is_alive())
		_actors[_key(enemy.id, i)] = actor


## Bandet bakom fienderna: två parallaxremsor i silhuett och ett golv av
## 32×32-kakel. [param rect] är fiendezonens rect i krit-UI:t och
## [param floor_y] den linje som både Smeden och fienderna står på.
func set_band(rect: Rect2, floor_y: float, relics: Array = []) -> void:
	_band = rect
	_floor_y = floor_y

	if _backdrop != null and is_instance_valid(_backdrop):
		_backdrop.queue_free()
	_backdrop = Node2D.new()
	_backdrop.name = "Backdrop"
	_backdrop.z_index = -1
	add_child(_backdrop)
	move_child(_backdrop, 0)

	_add_strip(Art.PARALLAX[0], _floor_y, -2)
	_add_strip(Art.PARALLAX[1], _floor_y, -1)
	_add_floor()

	if hero == null:
		hero = HeroFigure.new()
		hero.name = "Hero"
		hero.z_index = 3
		add_child(hero)
	hero.apply_relics(relics)


## Placerar Smeden på bandets golvlinje, i [param point]:s kolumn.
func place_hero(point: Vector2) -> void:
	if hero == null:
		return
	hero.stand_on(point.x, _floor_y)


func _add_strip(spec: Dictionary, bottom_y: float, z: int) -> void:
	var texture: Texture2D = Art.texture(String(spec["file"]))
	if texture == null or _backdrop == null:
		return
	var art_scale: int = Art.WORLD_SCALE
	var tile_width: float = float(texture.get_width() * art_scale)
	var tile_height: float = float(texture.get_height() * art_scale)
	var copies: int = int(ceil(_band.size.x / tile_width)) + 1
	for i: int in range(copies):
		var sprite: Sprite2D = Art.pixel_sprite(texture, art_scale)
		sprite.centered = false
		sprite.z_index = z
		# Fjärran lagret dimmas, annars konkurrerar det med fiendesilhuetterna
		# om uppmärksamheten (UI_GUIDE §8.1: pixlar är substantiv, inte brus).
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.45 if z < -1 else 0.7)
		sprite.position = Art.snap(
			Vector2(_band.position.x + tile_width * float(i), bottom_y - tile_height),
			art_scale,
		)
		_backdrop.add_child(sprite)


func _add_floor() -> void:
	var texture: Texture2D = Art.texture(Art.FLOOR_TILE)
	if texture == null or _backdrop == null:
		return
	var art_scale: int = Art.WORLD_SCALE
	var tile: float = float(texture.get_width() * art_scale)
	var columns: int = int(ceil(_band.size.x / tile)) + 1
	for column: int in range(columns):
		var sprite: Sprite2D = Art.pixel_sprite(texture, art_scale)
		sprite.centered = false
		sprite.z_index = 0
		sprite.position = Art.snap(
			Vector2(_band.position.x + tile * float(column), _floor_y),
			art_scale,
		)
		_backdrop.add_child(sprite)


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


## Placerar en fiende så att den står på bandets golvlinje i panelens kolumn.
func place(index: int, enemy_id: String, point: Vector2) -> void:
	var actor: EnemyActor = actor_at(index, enemy_id)
	if actor == null:
		return
	var y: float = point.y
	if _floor_y > 0.0:
		# Fotlinjen: halva cellen ovanför golvet, så att en 48 px-boss och en
		# 32 px-råtta står på samma mark i stället för att sväva olika mycket.
		y = _floor_y - float(Art.enemy_cell(enemy_id) * Art.WORLD_SCALE) * 0.5
	actor.place_at(Vector2(point.x, y))


static func _key(enemy_id: String, index: int) -> String:
	return "%s#%d" % [enemy_id, index]
