class_name EnemyBattler
extends Node3D
## En fiende i korridoren: EN målad PNG ur art-manifestet som Y-billboard, med
## kastskugga, andning, träffblixt och fall (M6 spår A steg 2).
##
## [b]Varför en [QuadMesh] och inte en [Sprite3D]:[/b] en [SpriteBase3D] binder
## inte sin textur till ett eget shadermaterial, och billboarden är en
## materialfunktion. Träffblixten ska gå genom paletten
## ([code]battler.gdshaderinc[/code], samma rattar som
## [code]palette_lut.gdshader[/code]), så kroppen är en kvad med den shadern.
## Kastskuggan ÄR en [Sprite3D] – en platt ellips på golvet behöver ingen shader.
##
## [b]Inga ark-rutnät längre.[/b] Manifestet ger [code]size[/code] och
## [code]pivot[/code]; höjden i världen är fast per nivå (vanlig/boss) gånger
## manifestets valfria [code]scale[/code], så fötterna alltid står på golvet och
## ett byte av PNG aldrig ändrar formeringen. En remsa med [code]frames > 1[/code]
## visar ruta 0; idle är tween, inte frame-animation.

## [b]Skalan är fast per pixel, inte per figur[/b]: manifestets PNG:er är
## normaliserade i samma skala (Pipoya-packet ritar en råtta mindre än en
## zombie), så storleksskillnaden i konsten är information och ska synas.
## 256 px målad konst = 1,76 m, samma höjd som M5:s 32 px-sprite (32 × 0,055 m).
const PAINTED_M_PER_PX: float = 1.76 / 256.0
## Gamla pixelark: M5:s värde, så en 32 px-fiende blir 1,76 m och bossen 2,64 m.
const PIXEL_M_PER_PX: float = 0.055
## Referenshöjden (tester och platshållare).
const ENEMY_HEIGHT_M: float = 1.76
## Rutan en vanlig fiende måste rymmas i. 1,9 m bred: två i främre ledet står
## på ±0,75 m i en 3 m gång och får överlappa lite, inte helt.
const ENEMY_MAX_M: Vector2 = Vector2(1.9, 2.4)
const ENEMY_MIN_HEIGHT_M: float = 1.1
## ART_DIRECTION_V2 §4: "Boss ritas 1,6× och bryter ramen medvetet." Bossen får
## vara bredare än gången (3 m) men aldrig högre än taket (3,2 m).
const BOSS_SCALE: float = 1.6
const BOSS_MAX_M: Vector2 = Vector2(3.8, 3.0)
## En flygande varelse (pivot "center") svävar med mitten här.
const HOVER_M: float = 1.05
## Kastskuggan: bredd som andel av kroppen, och hur mörk.
const SHADOW_WIDTH: float = 0.78
const SHADOW_DEPTH: float = 0.30
const SHADOW_ALPHA: float = 0.82

const SHADER_PAINTED: String = "res://src/game/shaders/battler.gdshader"
const SHADER_PIXEL: String = "res://src/game/shaders/battler_pixel.gdshader"

## Andningen: en långsam sinus i höjd och skala. Ingen frame-animation krävs.
const BREATH_SECONDS: float = 2.2
const BREATH_SCALE: float = 0.028
const BOB_M: float = 0.035
const FLASH_MS: int = 90
const DEATH_MS: int = 300
const DEATH_SINK_M: float = 0.3
const DEATH_TILT: float = 1.15
const SHAKE_M: float = 0.08

var enemy_id: String = ""
var height_m: float = ENEMY_HEIGHT_M
var width_m: float = ENEMY_HEIGHT_M
var is_boss: bool = false
var is_pixel: bool = false
var source: String = ""
## Sant från första dödsbildrutan. Vyn räknar tysta rum på den.
var dying: bool = false

## Tweenbara egenskaper. [Tween] kan bara röra namngivna egenskaper, därför
## setters som skriver rakt in i shadern.
var silhouette: float = 0.0:
	set(value):
		silhouette = value
		_param(&"silhouette", value)
var flash: float = 0.0:
	set(value):
		flash = value
		_param(&"flash", value)
var fade: float = 1.0:
	set(value):
		fade = value
		_param(&"alpha", value)
		if _shadow != null:
			_shadow.modulate.a = SHADOW_ALPHA * value
var tilt: float = 0.0:
	set(value):
		tilt = value
		_param(&"tilt", value)

var _body: MeshInstance3D = null
var _shadow: Sprite3D = null
var _material: ShaderMaterial = null
var _idle: Tween = null
var _base_y: float = 0.0


## Bygger kroppen och skuggan för [param p_enemy_id]. Anropas en gång, före
## [method Node.add_child] eller direkt efter.
func setup(p_enemy_id: String) -> void:
	enemy_id = p_enemy_id
	name = "Battler_%s" % p_enemy_id
	var info: Dictionary = Art.art_info(Art.enemy_art_key(p_enemy_id))
	var texture: Texture2D = info["texture"] as Texture2D
	var size: Vector2 = info["size"] as Vector2
	if size.x <= 0.0 or size.y <= 0.0:
		size = Vector2(1.0, 1.0)
	source = String(info["source"])
	is_pixel = bool(info["pixel"])
	is_boss = bool(info["boss"]) or Art.BOSS_IDS.has(p_enemy_id)
	var world: Vector2 = world_size(size, is_pixel, is_boss, float(info.get("scale", 1.0)))
	width_m = world.x
	height_m = world.y

	_material = ShaderMaterial.new()
	_material.shader = load(SHADER_PIXEL if is_pixel else SHADER_PAINTED) as Shader
	_material.set_shader_parameter(&"region", frame_region(texture, int(info.get("frames", 1))))
	_material.set_shader_parameter(&"albedo_tex", _base_texture(texture))

	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(width_m, height_m)
	var pivot: String = String(info.get("pivot", "bottom"))
	_base_y = HOVER_M - height_m * 0.5 if pivot == "center" and HOVER_M > height_m * 0.5 else 0.0
	# Kvaden står på sin underkant: skalning i y (andningen) lyfter aldrig fötterna.
	quad.center_offset = Vector3(0.0, height_m * 0.5, 0.0)

	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.mesh = quad
	_body.material_override = _material
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.position.y = _base_y
	add_child(_body)

	_shadow = Sprite3D.new()
	_shadow.name = "Shadow"
	_shadow.texture = Art.shadow_texture()
	_shadow.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_shadow.shaded = false
	_shadow.transparent = true
	_shadow.double_sided = true
	_shadow.no_depth_test = false
	_shadow.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_shadow.rotation.x = -PI * 0.5
	# 1 px = pixel_size m; texturen är 64 × 32.
	_shadow.pixel_size = width_m * SHADOW_WIDTH / 64.0
	_shadow.scale = Vector3(1.0, SHADOW_DEPTH / (width_m * SHADOW_WIDTH * 0.5), 1.0)
	_shadow.position.y = 0.02
	_shadow.modulate = Color(0.0, 0.0, 0.0, SHADOW_ALPHA)
	_shadow.render_priority = 0
	add_child(_shadow)
	set_rank(true)


## Storleken i världen, i meter, för en bild på [param size_px] pixlar.
## Fast skala per pixel, sedan inpassad i nivåns ruta med bibehållen proportion.
## En manifestpost kan justera med [code]scale[/code].
static func world_size(size_px: Vector2, pixel: bool, boss: bool, scale: float = 1.0) -> Vector2:
	var per_px: float = PIXEL_M_PER_PX if pixel else PAINTED_M_PER_PX
	var world: Vector2 = size_px * per_px * clampf(scale, 0.25, 3.0)
	if boss and not pixel:
		world *= BOSS_SCALE
	var box: Vector2 = BOSS_MAX_M if boss else ENEMY_MAX_M
	var fit: float = minf(1.0, minf(box.x / world.x, box.y / world.y))
	world *= fit
	if world.y < ENEMY_MIN_HEIGHT_M:
		world *= ENEMY_MIN_HEIGHT_M / world.y
	return world


## UV-rektangeln för ruta 0. En [AtlasTexture] (de gamla arken) samplas som
## hela atlasen i en shader, så regionen måste räknas ut här.
static func frame_region(texture: Texture2D, frames: int) -> Vector4:
	if texture is AtlasTexture:
		var atlas: AtlasTexture = texture as AtlasTexture
		var full: Vector2 = Vector2(atlas.atlas.get_width(), atlas.atlas.get_height())
		return Vector4(atlas.region.position.x / full.x, atlas.region.position.y / full.y,
			atlas.region.size.x / full.x, atlas.region.size.y / full.y)
	return Vector4(0.0, 0.0, 1.0 / float(maxi(1, frames)), 1.0)


static func _base_texture(texture: Texture2D) -> Texture2D:
	if texture is AtlasTexture:
		return (texture as AtlasTexture).atlas
	return texture


func _param(param: StringName, value: Variant) -> void:
	if _material != null:
		_material.set_shader_parameter(param, value)


## Främre ledet ritas över det bakre. Genomskinliga ytor sorteras annars på
## nodens mittpunkt, och två billboards bredvid varandra kan byta plats när
## kameran vrider sig en grad.
func set_rank(front: bool) -> void:
	if _material != null:
		_material.render_priority = 2 if front else 1


## Det bakade ljuset vid fötterna (varm fackla nära, kall fyllnad bort).
func set_light(color: Color) -> void:
	_param(&"light_tint", color)


## Toppen av huvudet i världen. Chipet i krit-lagret hänger här.
func head_point() -> Vector3:
	return global_position + Vector3(0.0, _base_y + height_m + 0.22, 0.0)


## Andningen. Fasen sprids per fiende så att fyra Rostråttor inte andas i takt.
## [b]Reducerad rörelse:[/b] ingen andning alls.
func start_idle(phase: float, reduced_motion: bool) -> void:
	stop_idle()
	if reduced_motion or _body == null:
		return
	var half: float = BREATH_SECONDS * 0.5
	_idle = create_tween().set_loops()
	_idle.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle.tween_interval(fposmod(phase, 1.0) * BREATH_SECONDS)
	_idle.tween_property(_body, "scale:y", 1.0 + BREATH_SCALE, half)
	_idle.parallel().tween_property(_body, "position:y", _base_y + BOB_M, half)
	_idle.tween_property(_body, "scale:y", 1.0, half)
	_idle.parallel().tween_property(_body, "position:y", _base_y, half)


func stop_idle() -> void:
	if _idle != null and _idle.is_valid():
		_idle.kill()
	_idle = null
	if _body != null:
		_body.scale = Vector3.ONE
		_body.position.y = _base_y


## Träff: blixt genom paletten och ett ryck i sidled. [b]Aldrig kameran[/b]
## ([CorridorCamera] regel 2). Reducerad rörelse: blixten, inget ryck.
func hit(reduced_motion: bool) -> void:
	flash = 1.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "flash", 0.0, float(FLASH_MS) / 1000.0)
	if reduced_motion:
		return
	var home: float = position.x
	var shake: Tween = create_tween()
	shake.set_trans(Tween.TRANS_SINE)
	shake.tween_property(self, "position:x", home + SHAKE_M, 0.05)
	shake.tween_property(self, "position:x", home - SHAKE_M, 0.06)
	shake.tween_property(self, "position:x", home, 0.05)


## Döden: tona ut och falla omkull runt fötterna, 300 ms (ryms i
## enemy_killed-budgeten på 360 ms, UI_GUIDE §5.5).
func die(reduced_motion: bool) -> void:
	dying = true
	stop_idle()
	if reduced_motion:
		fade = 0.0
		return
	var seconds: float = float(DEATH_MS) / 1000.0
	# Utåt: den vänstra faller åt vänster (positiv tilt lutar toppen åt vänster).
	var side: float = 1.0 if position.x < 0.0 else -1.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "fade", 0.0, seconds)
	tween.tween_property(self, "tilt", DEATH_TILT * side, seconds)
	tween.tween_property(self, "position:y", position.y - DEATH_SINK_M, seconds)


func is_dead_visual() -> bool:
	return fade <= 0.001


func material() -> ShaderMaterial:
	return _material
