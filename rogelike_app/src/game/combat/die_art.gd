class_name DieArt
extends Control
## En komponerad tärning: kropp + glyph + glaskant + spricka.
##
## [b]Komposition, inte färdiga bilder[/b] (assets/sprites/README.md §3):
## 3 material × 15 sidmotiv vore ~90 sprites. Här är det fyra staplade
## [Sprite2D] och 25 filer. Materialet är en 16×1-LUT på gråskalekroppen,
## sidan är en overlay. En ny smidbar sida i M2 kostar [b]en[/b] glyph-PNG.
##
## [codeblock]
## z 0  Body   die_body_gray.png   palette_lut.gdshader + lut_<material>.png
## z 1  Glyph  pips_<0-6>.png eller glyph_<namn>.png, modulate = semantisk token
## z 2  Rim    glass_highlight.png   endast GLASS
## z 3  Crack  crack_<1-3>.png       endast sprucken
## [/codeblock]
##
## Noden lever [b]inuti krit-UI:t[/b] (tumzonen är ett [Control]), som ärver
## Linear-filter. Varje sprite sätter därför Nearest själv, och skalan låses
## till ett heltal av [method Art.fit_scale] – annars kryper pixelrutnätet.

## Konstens cellstorlek. Kontrakt mot assets/sprites/dice/*.
const CELL: int = 32

var _root: Node2D = null
var _body: Sprite2D = null
var _glyph: Sprite2D = null
var _rim: Sprite2D = null
var _crack: Sprite2D = null
var _material: ShaderMaterial = null
var _art_scale: int = 1
## Sant när kompositionen faktiskt hittade sina texturer. Är den falsk ska
## anroparen behålla sin [Label]-platshållare.
var _ready_to_draw: bool = false
## Sant när sidan ritas som pips, dvs. värdet går att läsa ur konsten.
var _shows_pips: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_root = Node2D.new()
	_root.name = "Die"
	add_child(_root)

	_body = Art.pixel_sprite()
	_body.name = "Body"
	_body.z_index = 0
	_root.add_child(_body)

	_glyph = Art.pixel_sprite()
	_glyph.name = "Glyph"
	_glyph.z_index = 1
	_root.add_child(_glyph)

	_rim = Art.pixel_sprite()
	_rim.name = "Rim"
	_rim.z_index = 2
	_rim.visible = false
	_root.add_child(_rim)

	_crack = Art.pixel_sprite()
	_crack.name = "Crack"
	_crack.z_index = 3
	_crack.visible = false
	_root.add_child(_crack)

	resized.connect(_layout)


## Binder tärningen. [param variant_seed] väljer sprickmönster och är visuell
## slump – den drar aldrig ur den seedade [Rng]-strömmen.
func show_die(die: Die, variant_seed: int = 0) -> void:
	var die_material: int = die.material if die != null else Rules.DieMaterial.IRON
	var body: Texture2D = Art.die_body(die_material)
	_ready_to_draw = body != null
	if not _ready_to_draw:
		visible = false
		return
	visible = true
	_body.texture = body

	var face: Face = die.showing_face() if die != null else null
	var overlay: Dictionary = Art.face_overlay(face)
	_glyph.texture = overlay["texture"] as Texture2D
	_glyph.visible = _glyph.texture != null
	_glyph.modulate = _token(String(overlay["color_token"]))
	_shows_pips = bool(overlay["is_pips"])

	var is_glass: bool = die != null and die.material == Rules.DieMaterial.GLASS
	_rim.texture = Art.texture(Art.GLASS_RIM)
	_rim.visible = is_glass and _rim.texture != null

	var cracked: bool = die != null and die.cracks > 0
	_crack.texture = Art.crack(variant_seed) if cracked else null
	_crack.visible = cracked and _crack.texture != null

	_layout()


## Sant när sidan ritas som pips. Anroparen kan då dölja sin siffra: ögonen
## bär värdet. Glyph-sidor (gift, eld, blod, tomrum) bär det inte.
func shows_value() -> bool:
	return _ready_to_draw and _shows_pips


func is_drawing() -> bool:
	return _ready_to_draw


## Aktiveringspuls: hela tärningen lerpas mot vitt via palette_lut-shaderns
## [code]flash[/code]-uniform. [member modulate] duger inte – den multiplicerar,
## så en mörk järnkropp skulle bara bli ljusare grå.
##
## Materialet sätts PÅ för blixtens längd och tas bort igen (se noten vid
## [constant Art.DIE_BODIES]).
func flash(amount: float = 0.85, duration: float = 0.18) -> void:
	if not _ready_to_draw:
		return
	if _material == null:
		_material = Art.flash_material()
	if _material == null:
		return
	_material.set_shader_parameter("flash", amount)
	_body.material = _material
	_glyph.material = _material
	var tween: Tween = create_tween()
	tween.tween_method(_set_flash, amount, 0.0, duration)
	tween.tween_callback(_clear_flash)


func _set_flash(value: float) -> void:
	if _material != null:
		_material.set_shader_parameter("flash", value)


func _clear_flash() -> void:
	_body.material = null
	_glyph.material = null


func _layout() -> void:
	_art_scale = Art.fit_scale(size, CELL)
	_root.scale = Vector2(_art_scale, _art_scale)
	_root.position = Art.snap(size * 0.5, _art_scale)


static func _token(name: String) -> Color:
	match name:
		"NONE":
			return Color.WHITE
		"SEM_POISON":
			return Tokens.SEM_POISON
		"SEM_FIRE":
			return Tokens.SEM_FIRE
		"SEM_BLOOD":
			return Tokens.SEM_BLOOD
		"SEM_SHIELD":
			return Tokens.SEM_SHIELD
	return Tokens.BONE_PIP
