extends Node2D
## Marschens innehåll i [code]World[/code]-lagret: två parallaxlager i silhuett,
## en golvremsa och [HeroFigure].
##
## Research 04 §6: vi lånar Darkest Dungeons korridor som pacing-verktyg,
## Loop Heros "ingen joystick" och Kingdom: Two Crowns silhuettdjup. Figuren går
## alltid åt höger och spelaren har noll rörelseinput – en tumme räcker.
##
## Lagren är [Polygon2D] i M1. Byts de mot [Sprite2D] med
## [code]motion_mirroring[/code]-kaklade texturer behöver den här filen bara
## byta ut [method _build_layer]; hastigheterna och wrap-logiken stannar.

## Parallaxhastighet per lager (research 04 §6: 0,15 / 0,45 / 1,2).
const FAR_SPEED: float = 0.15
const MID_SPEED: float = 0.45
const FLOOR_SPEED: float = 1.2
## Baseline i px/s vid marschtempo.
const BASE_SPEED: float = 260.0
## Antal kopior per lager, så att wrap aldrig syns.
const TILES: int = 3

var hero: HeroFigure = null

var _far: Node2D = null
var _mid: Node2D = null
var _floor: Node2D = null
var _tile_width: float = 0.0
var _scrolling: bool = false
var _strip_center: Vector2 = Vector2.ZERO
var _strip_height: float = 0.0


func _ready() -> void:
	set_process(true)


## [param strip_center] och [param strip_height] kommer från krit-UI:ts remsa,
## så att världen alltid hamnar i rätt band på skärmen.
func build(strip_center: Vector2, strip_width: float, strip_height: float) -> void:
	for child: Node in get_children():
		child.queue_free()
	_strip_center = strip_center
	_strip_height = strip_height
	_tile_width = strip_width

	_far = _build_layer(strip_width, strip_height * 0.55, Tokens.SURFACE_RAISED, 5, 0.0)
	_mid = _build_layer(strip_width, strip_height * 0.38, Tokens.SURFACE_LINE, 7, strip_height * 0.1)
	_floor = _build_floor(strip_width, strip_height)

	hero = HeroFigure.new()
	hero.name = "Hero"
	add_child(hero)
	hero.position = _strip_center + Vector2(-strip_width * 0.18, strip_height * 0.22)


func _build_layer(width: float, height: float, color: Color, teeth: int, y_offset: float) -> Node2D:
	var layer: Node2D = Node2D.new()
	layer.name = "Parallax_%d" % teeth
	add_child(layer)
	for tile: int in range(TILES):
		var silhouette: Polygon2D = Polygon2D.new()
		silhouette.color = color
		var points: PackedVector2Array = PackedVector2Array()
		var base_y: float = _strip_center.y + _strip_height * 0.5 + y_offset
		points.append(Vector2(0.0, base_y))
		var step: float = width / float(teeth)
		for i: int in range(teeth + 1):
			var x: float = step * float(i)
			var peak: float = height * (0.45 + 0.55 * absf(sin(float(i) * 1.7 + float(teeth))))
			points.append(Vector2(x, base_y - peak))
		points.append(Vector2(width, base_y))
		silhouette.polygon = points
		silhouette.position = Vector2(_strip_center.x - width * 0.5 + width * float(tile), 0.0)
		layer.add_child(silhouette)
	return layer


func _build_floor(width: float, height: float) -> Node2D:
	var layer: Node2D = Node2D.new()
	layer.name = "Floor"
	add_child(layer)
	var base_y: float = _strip_center.y + height * 0.42
	for tile: int in range(TILES):
		for slab: int in range(6):
			var slab_polygon: Polygon2D = Polygon2D.new()
			slab_polygon.color = Tokens.SURFACE_LINE if slab % 2 == 0 else Tokens.SURFACE_RAISED
			var slab_width: float = width / 6.0
			var x: float = width * float(tile) + slab_width * float(slab)
			slab_polygon.polygon = PackedVector2Array([
				Vector2(x, base_y),
				Vector2(x + slab_width - Tokens.dp(2), base_y),
				Vector2(x + slab_width - Tokens.dp(2), base_y + Tokens.dp(10)),
				Vector2(x, base_y + Tokens.dp(10)),
			])
			layer.add_child(slab_polygon)
	layer.position = Vector2(_strip_center.x - width * 0.5, 0.0)
	return layer


func set_marching(value: bool) -> void:
	_scrolling = value
	if hero != null:
		hero.set_walking(value)


func _process(delta: float) -> void:
	if not _scrolling or _tile_width <= 0.0:
		return
	_scroll(_far, FAR_SPEED * BASE_SPEED * delta)
	_scroll(_mid, MID_SPEED * BASE_SPEED * delta)
	_scroll(_floor, FLOOR_SPEED * BASE_SPEED * delta)


func _scroll(layer: Node2D, amount: float) -> void:
	if layer == null:
		return
	layer.position.x -= amount
	# Wrap på exakt en kakelbredd: mönstret upprepar sig och hoppet syns inte.
	if layer.position.x <= -_tile_width:
		layer.position.x += _tile_width
