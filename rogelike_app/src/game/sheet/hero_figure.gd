class_name HeroFigure
extends Node2D
## Spelfiguren (Smeden). Paperdoll enligt [code]assets/sprites/hero/PAPERDOLL.md[/code]
## och DECISIONS 2026-09-21: [b]ett [Sprite2D] per lager, en [AnimationPlayer]
## på föräldern, en enda [member frame_index] som sanningskälla.[/b]
##
## Alternativen (flera [AnimatedSprite2D], shadermask, [Skeleton2D]) desynkar,
## kan inte ändra silhuetten respektive förstör pixelrutnätet. Här hoppar ett
## nytt lager in på exakt samma frame mitt i en gångcykel, utan städning.
##
## [b]Rutnätskontrakt[/b] (PAPERDOLL §1): 48×48-cell, [constant HFRAMES]×
## [constant VFRAMES], samma origo i alla lager, arket är 384×192 px.
## [code]tests/test_art.gd[/code] fäller bygget om ett ark bryter det.
##
## [b]Frames[/b] (PAPERDOLL §4), [code]frame_index = rad * 8 + kolumn[/code]:
## [codeblock]
## rad 0  idle    4 frames, 0,16 s/frame, loop
## rad 1  walk    8 frames, 0,08 s/frame, loop
## rad 2  attack  6 frames, 0,06 s/frame, kontakt på frame_index 19
## rad 3  hit     4 frames, 0,08 s/frame
## [/codeblock]

## Lagerordning bakifrån och fram (PAPERDOLL §2). Barnordningen ÄR z-ordningen.
## [code]hair[/code] tillkom i M2.5 med könsvalet och ligger [b]under alla
## gear-lager[/b] (DECISIONS 2026-09-21: utrustningen är kroppsoberoende och
## passar båda varianterna, så en hjälm ska kunna täcka håret).
const LAYERS: Array[StringName] = [
	&"cape", &"legs", &"body", &"hair", &"torso", &"head", &"helm", &"offhand", &"weapon", &"fx",
]
const HFRAMES: int = 8
const VFRAMES: int = 4
const CELL_SIZE: int = 48
## Heltalsskala, UI_GUIDE §8.3. 48 px-cell × 4 = 192 px hög figur.
const ART_SCALE: int = Art.WORLD_SCALE
## Fotlinjen ligger på y = 44 i cellen (PAPERDOLL §1), origo i mitten (y = 24).
## Avstånd från nodens position ned till golvet, i skärmpixlar.
const FOOT_OFFSET: int = (44 - CELL_SIZE / 2) * ART_SCALE

## Animationerna som [method _build_animations] lägger i spelaren.
const ANIM_IDLE: StringName = &"idle"
const ANIM_WALK: StringName = &"walk"
const ANIM_ATTACK: StringName = &"attack"
const ANIM_HIT: StringName = &"hit"

## rad, antal authorade frames, sekunder per frame, loop.
const ANIMATIONS: Dictionary = {
	ANIM_IDLE: {"row": 0, "frames": 4, "step": 0.16, "loop": true},
	ANIM_WALK: {"row": 1, "frames": 8, "step": 0.08, "loop": true},
	ANIM_ATTACK: {"row": 2, "frames": 6, "step": 0.06, "loop": false},
	ANIM_HIT: {"row": 3, "frames": 4, "step": 0.08, "loop": false},
}

## Attacken har kontakt på frame 3 (PAPERDOLL §4), t = 0,18 s.
signal attack_contact()

## Enda sanningskällan för vilken frame alla lager visar.
var frame_index: int = 0:
	set(value):
		frame_index = value
		for sprite: Sprite2D in _sprites.values():
			sprite.frame = value

var _sprites: Dictionary = {}
var _player: AnimationPlayer = null
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
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2(ART_SCALE, ART_SCALE)
		sprite.visible = false
		add_child(sprite)
		_sprites[layer_name] = sprite
	_build_placeholder()

	_player = AnimationPlayer.new()
	_player.name = "AnimationPlayer"
	add_child(_player)
	_build_animations()


func _ready() -> void:
	# Kroppsvarianten är en inställning och inte rundata: den ska överleva att
	# en run tar slut och att sparfilen nollställs (DECISIONS 2026-09-21).
	var settings: Node = Engine.get_main_loop().get("root").get_node_or_null("Settings") if Engine.get_main_loop() != null else null
	if settings != null:
		variant = Art.smith_variant(String(settings.get("smith_variant")))
	equip_default_gear()
	play(ANIM_IDLE)


# --- Riggen ----------------------------------------------------------------

## Varje animation har exakt ETT spår: ett Value-spår på
## [member frame_index] med [code]UPDATE_DISCRETE[/code]. Interpolation mellan
## heltalsframes är meningslös och skulle ge halva poser (PAPERDOLL §4).
func _build_animations() -> void:
	var library: AnimationLibrary = AnimationLibrary.new()
	for anim_name: StringName in ANIMATIONS:
		var spec: Dictionary = ANIMATIONS[anim_name]
		var count: int = int(spec["frames"])
		var step: float = float(spec["step"])
		var animation: Animation = Animation.new()
		animation.length = step * float(count)
		animation.loop_mode = Animation.LOOP_LINEAR if bool(spec["loop"]) else Animation.LOOP_NONE
		var track: int = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, ".:frame_index")
		animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
		for i: int in range(count):
			animation.track_insert_key(track, step * float(i), int(spec["row"]) * HFRAMES + i)
		library.add_animation(anim_name, animation)
	_player.add_animation_library(&"", library)
	_player.animation_finished.connect(_on_animation_finished)


func play(anim_name: StringName) -> void:
	if _player == null or not _player.has_animation(anim_name):
		return
	if _player.current_animation == String(anim_name) and _player.is_playing():
		return
	_player.play(anim_name)


## Blixt-tempo (0,35×) ska komprimera figuren lika mycket som siffrorna
## (PAPERDOLL §4, "Tidsbudget mot kedjan").
func set_chain_speed(chain_speed: float) -> void:
	if _player != null and chain_speed > 0.0:
		_player.speed_scale = 1.0 / chain_speed


## Slår mot en fiende. [signal attack_contact] kommer 0,18 s in, samtidigt som
## [code]damage_dealt[/code] landar i kedjan (UI_GUIDE §5.3).
func strike() -> void:
	if _player == null or not _player.has_animation(ANIM_ATTACK):
		return
	play(ANIM_ATTACK)
	var contact: SceneTreeTimer = get_tree().create_timer(0.18) if is_inside_tree() else null
	if contact != null:
		contact.timeout.connect(func() -> void: attack_contact.emit())


func stagger() -> void:
	play(ANIM_HIT)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == ANIM_ATTACK or anim_name == ANIM_HIT:
		play(ANIM_WALK if _walking else ANIM_IDLE)


# --- Utrustning och reliker ------------------------------------------------

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


## Vald kroppsvariant, "a" eller "b" ([member Settings.smith_variant]).
var variant: String = Art.SMITH_VARIANT_DEFAULT


## Byter kroppsvariant. Bara [code]body[/code] och [code]hair[/code] berörs –
## alla gear-lager är kroppsoberoende (PAPERDOLL §1: samma 48×48-rutnät, samma
## origo), vilket är hela skälet till att två varianter kostar två PNG:er och
## inte en andra garderob.
func set_variant(value: String) -> void:
	variant = Art.smith_variant(value)
	for layer_name: StringName in Art.SMITH_BODY_LAYERS:
		equip(layer_name, Art.smith_layer(layer_name, variant))


## Smedens grunduppsättning: kropp, hår, glödkappa, järnhjälm och smideshammare.
## [b]Utrustning har företräde framför reliker på samma lager[/b] (PAPERDOLL §3):
## ett vapenbyte får aldrig döljas av en relik.
func equip_default_gear() -> void:
	for layer_name: StringName in Art.HERO_LAYERS:
		equip(layer_name, Art.texture(String(Art.HERO_LAYERS[layer_name])))
	set_variant(variant)


## Tänder relikernas lager enligt PAPERDOLL §3.
##
## [b]Kollisionsregeln är normativ:[/b] begär två reliker samma lager vinner
## högst rarity; vid lika rarity vinner den som plockades senast. Förloraren
## flyttar till sitt reservlager. Är även det upptaget syns reliken bara i
## relikbrickan – den försvinner aldrig, men figuren blir ingen julgran.
##
## [b]M1.5:[/b] reliklagren är specificerade men inte ritade
## (PAPERDOLL §5). Upplösningen körs ändå, så att kontraktet är testbart; de
## lager som saknar PNG tänds helt enkelt inte.
func apply_relics(relics: Array) -> void:
	var taken: Dictionary = {}
	for layer_name: StringName in Art.SMITH_BODY_LAYERS:
		taken[layer_name] = true  # kroppen och håret är inte gear
	for layer_name: StringName in Art.HERO_LAYERS:
		taken[layer_name] = true  # utrustning vinner alltid

	# Senast plockad sist i listan ⇒ högre rarity först, annars senare index
	# först. Den ordningen gör "vid lika rarity vinner den senaste" till en
	# ren sortering i stället för ett specialfall.
	var ordered: Array = []
	for i: int in range(relics.size()):
		var relic: Relic = relics[i] as Relic
		if relic != null:
			ordered.append({"relic": relic, "index": i})
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra: Relic = a["relic"] as Relic
		var rb: Relic = b["relic"] as Relic
		if ra.rarity != rb.rarity:
			return ra.rarity > rb.rarity
		return int(a["index"]) > int(b["index"]))

	for entry: Dictionary in ordered:
		var relic: Relic = entry["relic"] as Relic
		for layer_name: Variant in Art.RELIC_LAYERS.get(relic.id, []) as Array:
			var layer: StringName = StringName(layer_name)
			# fx stackar hur många sprites som helst; reservkedjan tar aldrig slut.
			if layer != &"fx" and taken.has(layer):
				continue
			var texture: Texture2D = Art.texture("hero/smith_%s_%s.png" % [layer, relic.id.to_lower()])
			if texture == null:
				# Lagret är specificerat men inte ritat: reliken stannar i
				# brickan. Vi markerar ändå lagret som taget, annars skulle
				# nästa relik glida in på en plats som egentligen är upptagen.
				if layer != &"fx":
					taken[layer] = true
				break
			equip(layer, texture)
			if layer != &"fx":
				taken[layer] = true
			break


func has_any_texture() -> bool:
	for sprite: Sprite2D in _sprites.values():
		if sprite.texture != null:
			return true
	return false


## Placerar figuren så att fötterna står på [param floor_y].
func stand_on(x: float, floor_y: float) -> void:
	position = Art.snap(Vector2(x, floor_y - float(FOOT_OFFSET)), ART_SCALE)


func layer_sprite(layer_name: StringName) -> Sprite2D:
	return _sprites.get(layer_name, null) as Sprite2D


func set_walking(value: bool) -> void:
	if _walking == value:
		return
	_walking = value
	play(ANIM_WALK if value else ANIM_IDLE)


# --- Platshållare ----------------------------------------------------------

## Platshållaren är medvetet byggd av samma delar som paperdoll-lagren, så att
## det syns direkt om alla lager saknas när sprajterna kommer.
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


func _process(delta: float) -> void:
	if not _walking or not _placeholder.visible:
		return
	# Bara platshållaren animeras här; riktiga lager drivs av AnimationPlayer.
	_walk_time += delta
	frame_index = int(_walk_time * 12.0) % HFRAMES
	_placeholder.position.y = sin(_walk_time * 12.0) * Tokens.dp(3)
	_placeholder_arm.rotation = sin(_walk_time * 12.0) * 0.18
	_placeholder_tool.rotation = sin(_walk_time * 12.0) * 0.18
