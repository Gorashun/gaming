class_name HeroFigure
extends Node2D
## Spelfiguren i marschen. Paperdoll enligt research 04 §2 och DECISIONS
## 2026-09-21: [b]ett [Sprite2D] per lager, en [AnimationPlayer] på föräldern,
## en enda [member frame_index] som sanningskälla.[/b]
##
## Skälet att strukturen finns redan i M1 trots att lagren är tomma: alternativen
## (flera [AnimatedSprite2D], shadermask, [Skeleton2D]) desynkar, kan inte ändra
## silhuetten respektive förstör pixelrutnätet. Att byta till någon av dem senare
## är en omskrivning; att fylla på det här är en texturtilldelning.
##
## [b]UI-agentens kontrakt:[/b] alla lagerark delar cellstorlek
## [constant CELL_SIZE], samma [constant HFRAMES]×[constant VFRAMES] och samma
## frame-ordning. Anropa [method equip] – lagret hoppar då in på rätt frame och
## desynkar aldrig, inte ens mitt i en gångcykel.

const LAYERS: Array[StringName] = [&"cape", &"body", &"armor", &"head", &"offhand", &"weapon", &"fx"]
const HFRAMES: int = 8
const VFRAMES: int = 4
const CELL_SIZE: int = 48
## Heltalsskala, research 04 §5. 48 px-cell × 4 = 192 px hög figur.
const ART_SCALE: int = 4

## Enda sanningskällan för vilken frame alla lager visar.
var frame_index: int = 0:
	set(value):
		frame_index = value
		for sprite: Sprite2D in _sprites.values():
			sprite.frame = value

var _sprites: Dictionary = {}
var _placeholder: Node2D = null
var _placeholder_arm: Polygon2D = null
var _placeholder_tool: Polygon2D = null
var _walk_time: float = 0.0
var _walking: bool = false


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for layer_name: StringName in LAYERS:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = String(layer_name)
		sprite.hframes = HFRAMES
		sprite.vframes = VFRAMES
		sprite.centered = true
		sprite.scale = Vector2(ART_SCALE, ART_SCALE)
		sprite.visible = false
		add_child(sprite)
		_sprites[layer_name] = sprite
	_build_placeholder()


## Platshållaren är medvetet byggd av samma delar som paperdoll-lagren, så att
## det syns direkt om ett lager saknas när sprajterna kommer.
func _build_placeholder() -> void:
	_placeholder = Node2D.new()
	_placeholder.name = "Placeholder"
	add_child(_placeholder)

	var height: float = float(CELL_SIZE * ART_SCALE) * 0.8
	var width: float = height * 0.36

	var torso: Polygon2D = Polygon2D.new()
	torso.name = "PlaceholderBody"
	torso.color = Tokens.CHALK_100
	torso.polygon = PackedVector2Array([
		Vector2(-width * 0.5, -height * 0.45),
		Vector2(width * 0.5, -height * 0.45),
		Vector2(width * 0.42, height * 0.5),
		Vector2(-width * 0.42, height * 0.5),
	])
	_placeholder.add_child(torso)

	var head: Polygon2D = Polygon2D.new()
	head.name = "PlaceholderHead"
	head.color = Tokens.BONE_DIE
	var head_radius: float = width * 0.42
	var head_points: PackedVector2Array = PackedVector2Array()
	for i: int in range(8):
		var angle: float = TAU * float(i) / 8.0
		head_points.append(Vector2(cos(angle), sin(angle)) * head_radius + Vector2(0.0, -height * 0.62))
	head.polygon = head_points
	_placeholder.add_child(head)

	_placeholder_arm = Polygon2D.new()
	_placeholder_arm.name = "PlaceholderArm"
	_placeholder_arm.color = Tokens.CHALK_300
	_placeholder_arm.polygon = PackedVector2Array([
		Vector2(0.0, -height * 0.3),
		Vector2(width * 0.7, -height * 0.1),
		Vector2(width * 0.55, height * 0.02),
		Vector2(-width * 0.05, -height * 0.18),
	])
	_placeholder.add_child(_placeholder_arm)

	# "Utrustningslager": syns som en egen form så att det är uppenbart var
	# weapon-spriten hamnar.
	_placeholder_tool = Polygon2D.new()
	_placeholder_tool.name = "PlaceholderWeapon"
	_placeholder_tool.color = Tokens.SEM_CHARGE
	_placeholder_tool.polygon = PackedVector2Array([
		Vector2(width * 0.6, -height * 0.24),
		Vector2(width * 1.1, -height * 0.16),
		Vector2(width * 1.1, -height * 0.02),
		Vector2(width * 0.6, -height * 0.1),
	])
	_placeholder.add_child(_placeholder_tool)


## Utrustningsbyte. Lagret hoppar direkt in på rätt frame – ingen desync.
func equip(layer_name: StringName, texture: Texture2D) -> void:
	var sprite: Sprite2D = _sprites.get(layer_name, null) as Sprite2D
	if sprite == null:
		push_warning("HeroFigure: okänt lager %s" % layer_name)
		return
	sprite.texture = texture
	sprite.visible = texture != null
	sprite.frame = frame_index
	_placeholder.visible = not has_any_texture()


func has_any_texture() -> bool:
	for sprite: Sprite2D in _sprites.values():
		if sprite.texture != null:
			return true
	return false


func set_walking(value: bool) -> void:
	_walking = value


func _process(delta: float) -> void:
	if not _walking:
		return
	_walk_time += delta
	# Gångcykeln blir frame 0–7 på body-raden när sprajterna finns; tills dess
	# animeras platshållaren med samma takt så att tajmingen redan är rätt.
	frame_index = int(_walk_time * 12.0) % HFRAMES
	if _placeholder != null and _placeholder.visible:
		_placeholder.position.y = sin(_walk_time * 12.0) * Tokens.dp(3)
		_placeholder_arm.rotation = sin(_walk_time * 12.0) * 0.18
		_placeholder_tool.rotation = sin(_walk_time * 12.0) * 0.18
