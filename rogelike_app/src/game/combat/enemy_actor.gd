class_name EnemyActor
extends Node2D
## Fiendens kropp i [code]World[/code]-lagret (Nearest-filter, research 04 §5).
##
## Sedan M1.5 är det en riktig [AnimatedSprite2D] med idle-loopen ur
## [code]assets/sprites/enemies/[/code]: fyra frames per fiende, 32×32 utom
## SLAGJAW som är 48×48 (assets/sprites/README.md §1). Kritsilhuetten finns
## kvar som [b]platshållare[/b] och tänds bara om texturen saknas, så att ett
## bortfall syns som en blob i stället för som ett hål.
##
## Skalan är heltal ([constant Art.WORLD_SCALE]) och positionen kvantiseras mot
## den: icke-heltalsskala får pixelrutnätet att krypa under sidoscroll.
##
## [b]Träffblixten[/b] går genom [code]palette_lut.gdshader[/code]:s
## [code]flash[/code]-uniform, inte genom [member modulate]. Skälet är att
## modulate multiplicerar – en mörk fiende blir bara ljusare grå – medan
## flash-parametern lerpar mot vitt och därför alltid syns (UI_GUIDE §5.3).

## Heltalsskala för 32/48 px-konst på 1080 px bredd (UI_GUIDE §8.3).
const ART_SCALE: int = Art.WORLD_SCALE
## Idle-loopens tempo. 4 frames à ~167 ms = ett lugnt andetag.
const IDLE_FPS: float = 6.0

var enemy_id: String = ""
var silhouette: Polygon2D = null
var sprite: AnimatedSprite2D = null

var _material: ShaderMaterial = null
var _alive: bool = true
var _base_position: Vector2 = Vector2.ZERO
var _cell: int = 32


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	silhouette = Polygon2D.new()
	silhouette.name = "Silhouette"
	silhouette.color = Tokens.CHALK_100
	add_child(silhouette)

	sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(ART_SCALE, ART_SCALE)
	sprite.visible = false
	add_child(sprite)


## [param seed_index] gör platshållarsilhuetten olika per fiende utan att röra
## [Rng]: detta är visuell slump och får aldrig dra ur den seedade strömmen
## (ARCHITECTURE: "Rendering och UI får aldrig dra ur den här strömmen").
func build(p_enemy_id: String, seed_index: int, radius: float) -> void:
	enemy_id = p_enemy_id
	_cell = Art.enemy_cell(p_enemy_id)

	var frames: SpriteFrames = Art.enemy_frames(p_enemy_id, IDLE_FPS)
	if frames != null:
		sprite.sprite_frames = frames
		sprite.animation = &"default"
		# Fasförskjutning per position: fyra Rostråttor som andas i takt ser ut
		# som en textur, inte som fyra djur.
		sprite.frame = seed_index % maxi(1, frames.get_frame_count(&"default"))
		sprite.play()
		sprite.visible = true
		silhouette.visible = false
		return

	silhouette.visible = true
	_build_silhouette(p_enemy_id, seed_index, radius)


func _build_silhouette(p_enemy_id: String, seed_index: int, radius: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var corners: int = 7 + (seed_index % 3)
	var wobble: RandomNumberGenerator = RandomNumberGenerator.new()
	wobble.seed = hash(p_enemy_id)
	for i: int in range(corners):
		var angle: float = TAU * float(i) / float(corners) - PI * 0.5
		var r: float = radius * wobble.randf_range(0.72, 1.0)
		points.append(Vector2(cos(angle) * r, sin(angle) * r * 1.15))
	silhouette.polygon = points

	for eye_index: int in range(2):
		var eye: Polygon2D = Polygon2D.new()
		eye.color = Tokens.SURFACE_PIT
		var eye_points: PackedVector2Array = PackedVector2Array()
		var center: Vector2 = Vector2((-1.0 if eye_index == 0 else 1.0) * radius * 0.3, -radius * 0.35)
		for i: int in range(6):
			var angle: float = TAU * float(i) / 6.0
			eye_points.append(center + Vector2(cos(angle), sin(angle)) * radius * 0.11)
		eye.polygon = eye_points
		silhouette.add_child(eye)


## Fotlinjen: sprajten står på golvet i stället för att sväva mitt i sin cell.
func place_at(point: Vector2) -> void:
	_base_position = Art.snap(point, ART_SCALE)
	position = _base_position


func set_alive(value: bool) -> void:
	# Uppspelaren anropar den här per event. Utan vakten skulle den återställa
	# modulate mitt i uttoningen och fienden skulle blinka tillbaka.
	if _alive == value:
		return
	_alive = value
	modulate.a = 1.0 if value else 0.18
	if not value and sprite != null:
		sprite.pause()


func hit_reaction() -> void:
	if not _alive:
		return
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", _base_position + Vector2(Tokens.dp(6), 0.0), 0.05)
	tween.tween_property(self, "position", _base_position, 0.08)
	flash()


## Vitblixt via shaderns flash-uniform (UI_GUIDE §5.3, 140 ms). Materialet
## sätts på för blixtens längd och tas bort igen: palette_lut skriver i GL
## Compatibility ut sitt resultat utan sRGB-konvertering och skulle annars
## mörka ned fienden permanent (se noten vid [constant Art.DIE_BODIES]).
func flash(amount: float = 0.9, duration: float = 0.14) -> void:
	if sprite == null or not sprite.visible:
		return
	if _material == null:
		_material = Art.flash_material()
	if _material == null:
		return
	_material.set_shader_parameter("flash", amount)
	sprite.material = _material
	var tween: Tween = create_tween()
	tween.tween_method(_set_flash, amount, 0.0, duration)
	tween.tween_callback(_clear_flash)


func _set_flash(value: float) -> void:
	if _material != null:
		_material.set_shader_parameter("flash", value)


func _clear_flash() -> void:
	if sprite != null:
		sprite.material = null


## Dödsreaktionen. [b]M1.5-assets har ingen death-frame[/b]
## (assets/sprites/README.md §1: fyra idle-frames per ark), så fienden faller
## ihop och tonar ut. Finns en [code]death[/code]-animation i [SpriteFrames]
## spelas den i stället, utan att något annat behöver ändras.
func death_reaction() -> void:
	set_alive(false)
	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"death"):
		sprite.animation = &"death"
		sprite.play()
		return
	var tween: Tween = create_tween()
	tween.set_parallel(false)
	tween.tween_property(self, "scale", Vector2(1.15, 0.7), 0.1)
	tween.tween_property(self, "scale", Vector2(0.4, 0.4), 0.26)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.26)
