class_name EnemyActor
extends Node2D
## Fiendens kropp i [code]World[/code]-lagret (Nearest-filter, research 04 §5).
##
## M1 ritar en kritsilhuett som [Polygon2D] (UI_GUIDE §1 A: "Fiender är
## kritsilhuetter: en hukande kontur, ett par vita ögonprickar, ingen inre
## detalj"). Barnnoden [code]Sprite[/code] är tom och ligger över polygonen.
##
## [b]Bytesplats för UI-agenten:[/b] sätt en textur på [member sprite], sätt
## [member silhouette].visible = false. Position, skala och skak sköts här och
## behöver inte röras. Skalan hålls på heltal ([constant ART_SCALE]) eftersom
## icke-heltalsskala får pixelrutnätet att krypa under sidoscroll.

## Heltalsskala för 32 px-konst på 1080 px bredd (research 04 §5).
const ART_SCALE: int = 5

var enemy_id: String = ""
var silhouette: Polygon2D = null
var sprite: Sprite2D = null
var _alive: bool = true
var _base_position: Vector2 = Vector2.ZERO


func _init() -> void:
	silhouette = Polygon2D.new()
	silhouette.name = "Silhouette"
	silhouette.color = Tokens.CHALK_100
	add_child(silhouette)

	sprite = Sprite2D.new()
	sprite.name = "Sprite"
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(ART_SCALE, ART_SCALE)
	add_child(sprite)


## [param seed_index] gör silhuetten olika per fiende utan att röra [Rng]:
## detta är visuell slump och får aldrig dra ur den seedade strömmen
## (ARCHITECTURE: "Rendering och UI får aldrig dra ur den här strömmen").
func build(p_enemy_id: String, seed_index: int, radius: float) -> void:
	enemy_id = p_enemy_id
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


func place_at(point: Vector2) -> void:
	# Kvantisera till ART_SCALE så pixelrutnätet inte kryper (research 04 §5).
	_base_position = Vector2(
		float(int(point.x) / ART_SCALE * ART_SCALE),
		float(int(point.y) / ART_SCALE * ART_SCALE),
	)
	position = _base_position


func set_alive(value: bool) -> void:
	_alive = value
	modulate.a = 1.0 if value else 0.18


func hit_reaction() -> void:
	if not _alive:
		return
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", _base_position + Vector2(Tokens.dp(6), 0.0), 0.05)
	tween.tween_property(self, "position", _base_position, 0.08)


func death_reaction() -> void:
	set_alive(false)
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.15, 0.7), 0.1)
	tween.tween_property(self, "scale", Vector2(0.4, 0.4), 0.26)
