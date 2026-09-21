extends Node2D
## Marschens innehåll i [code]World[/code]-lagret: tre parallaxlager, en
## golvremsa och [HeroFigure].
##
## Hastigheterna är normativa (UI_GUIDE §10.2): fjärran 0,15 · mitt 0,45 ·
## golv 1,00 · förgrund 1,20. Förgrunden ligger [b]framför[/b] figuren och är
## mörk, så att figuren poppar. Marschhastigheten är 40 konstpixlar/s, dvs.
## 160 px/s vid ×4, vilket ger ~4 s mellan två noder.
##
## Lagren kaklas med [constant TILES] kopior och wrappas på exakt en kakelbredd;
## [code]motion_mirroring[/code] i [ParallaxBackground] gör samma sak, men den
## noden kan inte ligga i en delad [CanvasLayer] utan att ta över scroll-offset
## för hela lagret – och stridsskärmen ligger i samma lager.
##
## Allt kvantiseras mot [constant Art.WORLD_SCALE]: en parallaxremsa på
## bråkdelspositioner får pixelkanterna att krypa, vilket syns mest just under
## sidoscroll (research 04 §5).

## Baslinje i px/s vid marschtempo: 40 konstpixlar/s × ART_SCALE.
const BASE_SPEED: float = 40.0 * float(Art.WORLD_SCALE)
## Antal kopior per lager, så att wrap aldrig syns.
const TILES: int = 3
## Figuren står på skärmens 38 %-linje (UI_GUIDE §10.2): vänster om mitten, så
## att spelaren ser mer av vad som kommer än av vad som passerat.
const HERO_X_FRACTION: float = 0.38
## Bandets höjd som andel av skärmhöjden (UI_GUIDE §10.1: 268/640 dp).
const BAND_FRACTION: float = 0.42
## Antal kakelrader i golvet. Fler rader ger bara mer mörkt golv.
const FLOOR_ROWS: int = 2

var hero: HeroFigure = null

## [{node, speed, width}] – en post per rullande lager.
var _layers: Array[Dictionary] = []
var _scrolling: bool = false
var _strip_center: Vector2 = Vector2.ZERO
var _strip_height: float = 0.0
var _floor_y: float = 0.0


func _ready() -> void:
	set_process(true)


## [param strip_center] och [param strip_height] kommer från krit-UI:ts remsa,
## så att världen alltid hamnar i rätt band på skärmen.
func build(strip_center: Vector2, strip_width: float, strip_height: float) -> void:
	for child: Node in get_children():
		child.queue_free()
	_layers.clear()
	_strip_center = strip_center
	# Remsan är ett Control med SIZE_EXPAND_FILL och äter all ledig höjd när
	# vägvalsknapparna inte finns. Bandet kapas därför till UI_GUIDE §10.1:s
	# proportion (268 av 640 dp ≈ 42 % av skärmen) och centreras i remsan.
	_strip_height = minf(strip_height, float(ProjectSettings.get_setting(
		"display/window/size/viewport_height", 1920)) * BAND_FRACTION)

	var top: float = strip_center.y - _strip_height * 0.5
	# Golvlinjen ligger på 62 % av bandet: tillräckligt lågt för att figuren ska
	# ha mark under sig, tillräckligt högt för att förgrunden ska få plats.
	_floor_y = top + _strip_height * 0.62

	var far: Dictionary = Art.PARALLAX[0]
	var mid: Dictionary = Art.PARALLAX[1]
	var near: Dictionary = Art.PARALLAX[2]

	_add_strip(far, _floor_y, strip_width, 0)
	_add_strip(mid, _floor_y, strip_width, 1)
	_add_floor(strip_width, 2)

	hero = HeroFigure.new()
	hero.name = "Hero"
	hero.z_index = 3
	add_child(hero)
	hero.stand_on(strip_center.x - strip_width * (0.5 - HERO_X_FRACTION), _floor_y)

	# Förgrunden sveper förbi FRAMFÖR figuren (UI_GUIDE §10.2).
	_add_strip(near, _floor_y + _strip_height * 0.22, strip_width, 4)


## Ett kaklat parallaxlager. [param bottom_y] är lagrets underkant, så att alla
## lager delar horisont i stället för att hänga i luften.
func _add_strip(spec: Dictionary, bottom_y: float, strip_width: float, z: int) -> void:
	var texture: Texture2D = Art.texture(String(spec["file"]))
	if texture == null:
		return
	var art_scale: int = Art.WORLD_SCALE
	var tile_width: float = float(texture.get_width() * art_scale)
	var tile_height: float = float(texture.get_height() * art_scale)

	var layer: Node2D = Node2D.new()
	layer.name = "Parallax_%d" % z
	layer.z_index = z
	add_child(layer)

	var copies: int = maxi(TILES, int(ceil(strip_width / tile_width)) + 2)
	for i: int in range(copies):
		var sprite: Sprite2D = Art.pixel_sprite(texture, art_scale)
		sprite.centered = false
		sprite.position = Art.snap(
			Vector2(_strip_center.x - strip_width * 0.5 + tile_width * float(i), bottom_y - tile_height),
			art_scale,
		)
		layer.add_child(sprite)

	_layers.append({"node": layer, "speed": float(spec["speed"]), "width": tile_width, "offset": 0.0, "scale": art_scale})


## Golvet: en rad 32×32-kakel som figuren går på, hastighet 1,00.
func _add_floor(strip_width: float, z: int) -> void:
	var texture: Texture2D = Art.texture(Art.FLOOR_TILE)
	if texture == null:
		return
	var art_scale: int = Art.WORLD_SCALE
	var tile: float = float(texture.get_width() * art_scale)

	var layer: Node2D = Node2D.new()
	layer.name = "Floor"
	layer.z_index = z
	add_child(layer)

	var columns: int = int(ceil(strip_width / tile)) + 2
	var rows: int = FLOOR_ROWS
	for row: int in range(rows):
		for column: int in range(columns):
			var sprite: Sprite2D = Art.pixel_sprite(texture, art_scale)
			sprite.centered = false
			sprite.position = Art.snap(
				Vector2(
					_strip_center.x - strip_width * 0.5 + tile * float(column),
					_floor_y + tile * float(row),
				),
				art_scale,
			)
			layer.add_child(sprite)

	_layers.append({"node": layer, "speed": 1.0, "width": tile, "offset": 0.0, "scale": art_scale})


func floor_y() -> float:
	return _floor_y


func set_marching(value: bool) -> void:
	_scrolling = value
	if hero != null:
		hero.set_walking(value)


func _process(delta: float) -> void:
	if not _scrolling:
		return
	for entry: Dictionary in _layers:
		_scroll(entry, delta)


## Scrollpositionen hålls som en float och [b]kvantiseras vid ritning[/b].
## Skrivs positionen direkt kryper pixelkanterna: en remsa som står på x = 12,4
## rastreras annorlunda än samma remsa på x = 12,6 (research 04 §5).
func _scroll(entry: Dictionary, delta: float) -> void:
	var layer: Node2D = entry["node"] as Node2D
	var width: float = float(entry["width"])
	if layer == null or width <= 0.0:
		return
	# Wrap på exakt en kakelbredd: mönstret upprepar sig och hoppet syns inte.
	var offset: float = fmod(float(entry["offset"]) + float(entry["speed"]) * BASE_SPEED * delta, width)
	entry["offset"] = offset
	var step: float = float(maxi(1, int(entry["scale"])))
	layer.position.x = -floor(offset / step) * step
