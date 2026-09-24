class_name DieArt
extends Control
## En tärning, ritad i kod. [b]M7[/b] (docs/M7_UI_NOTES.md): inga pixelsprites,
## ingen heltalsskala, inget Nearest. Tärningen ritas i vilken storlek som
## helst och är lika skarp i en 44 dp belöningsruta som i en 58 dp tumzon.
##
## [b]Uppbyggnad[/b], bakifrån och fram, allt i [method _draw]:
## [codeblock]
## 1  Skugga      två mjuka rundade lager under tärningen (den är TUNG)
## 2  Kant        hela kroppen i materialets mörka mellanton: framsidans tjocklek
## 3  Ovansida    rundad kvadrat med vertikal gradient ljus → mellan (materialet)
## 4  Glans       kantljus uppe till vänster; glas får ett diagonalt sken till
## 5  Kontur      mörk, kantutjämnad linje runt allt – kritstreck mot skiffer
## 6  Sida        pips (ritade cirklar med insänkt skugga) ELLER glyph (256 px
##                krita ur manifestet, ui.face.*, tintad med sin token)
## 7  Spricka     ritade sicksacklinjer, variant seedad per tärning
## 8  Blixt       allt lerpas mot vitt medan [method flash] pågår
## [/codeblock]
##
## [b]Materialets färgspråk[/b] är de gamla LUT:arnas fem steg
## (assets/sprites/dice/lut_*.png, UI_GUIDE §9.2): järn kall grå och tung, ben
## varm elfenben ([code]bone/die[/code]), glas iskall cyan med ljus kant.
## [br][b]Blixten[/b] ersätter palette_lut-shaderns [code]flash[/code]-uniform
## med samma signatur ([method flash]); juice-lagret anropar bara den metoden.

## Minsta sida i px som en slot reserverar för tärningen (samma 64 px som
## M6:s [code]CELL * 2[/code], så att stridens höjdbudget inte flyttar sig).
const MIN_SIDE: float = 64.0
## Tärningens sida som andel av den kortaste sidan i rektangeln. Resten är
## luft för skuggan.
const FILL: float = 0.84
## Hörnradie som andel av sidan.
const CORNER: float = 0.22
## Framsidans synliga tjocklek som andel av sidan: vi ser tärningen snett
## ovanifrån, så den har en undersida.
const DEPTH: float = 0.09
## Pipsens radie och avstånd från mitten, som andel av ovansidans sida.
const PIP_RADIUS: float = 0.086
const PIP_SPREAD: float = 0.27
## Glyphens sida som andel av ovansidans sida.
const GLYPH_FILL: float = 0.66
## Segment per rundat hörn.
const CORNER_STEPS: int = 6

## Fem steg per material, mörkt → ljust. Ur lut_<material>.png.
const PALETTES: Dictionary = {
	Rules.DieMaterial.IRON: ["#12161A", "#2C353F", "#4A5663", "#7A8896", "#B8C4CE"],
	Rules.DieMaterial.BONE: ["#3A3327", "#6B5F4A", "#A2937A", "#CFC3A8", "#E8E0CF"],
	Rules.DieMaterial.GLASS: ["#12262E", "#24515F", "#3E8DA3", "#6ED2F5", "#C9F0FC"],
}

## Pipsens lägen i ett 3×3-rutnät (−1, 0, 1), vanlig tärningsuppställning.
const PIP_LAYOUT: Dictionary = {
	1: [Vector2(0, 0)],
	2: [Vector2(1, -1), Vector2(-1, 1)],
	3: [Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1)],
	4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
	6: [Vector2(-1, -1), Vector2(-1, 0), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 0), Vector2(1, 1)],
}

var _material: int = Rules.DieMaterial.IRON
var _pips: int = -1
var _glyph: Texture2D = null
var _glyph_tint: Color = Color.WHITE
var _cracked: bool = false
var _crack_seed: int = 0
var _flash: float = 0.0
var _flash_tween: Tween = null
## Sant när en tärning är bunden. Anroparen behåller annars sin platshållare.
var _ready_to_draw: bool = false
## Sant när sidan ritas som pips, dvs. värdet går att läsa ur konsten.
var _shows_pips: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Glyphen är 256 px krita som ritas ned till ~40 px: mipmaps, inte Nearest.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	resized.connect(queue_redraw)


## Binder tärningen. [param variant_seed] väljer sprickmönster och är visuell
## slump – den drar aldrig ur den seedade [Rng]-strömmen (en lokal
## [RandomNumberGenerator] i [method crack_paths]).
func show_die(die: Die, variant_seed: int = 0) -> void:
	_ready_to_draw = true
	visible = true
	_material = die.material if die != null else Rules.DieMaterial.IRON
	var face: Face = die.showing_face() if die != null else null
	var overlay: Dictionary = Art.face_overlay(face)
	_glyph = overlay["texture"] as Texture2D
	_glyph_tint = _token(String(overlay["color_token"]))
	_pips = int(overlay.get("pips", -1))
	_shows_pips = bool(overlay["is_pips"])
	_cracked = die != null and die.cracks > 0
	_crack_seed = variant_seed
	queue_redraw()


## Sant när sidan ritas som pips. Anroparen kan då dölja sin siffra: ögonen
## bär värdet. Glyph-sidor (gift, eld, blod, tomrum) bär det inte.
func shows_value() -> bool:
	return _ready_to_draw and _shows_pips


func is_drawing() -> bool:
	return _ready_to_draw


## Aktiveringspuls: hela tärningen lerpas mot vitt och tillbaka.
## [member modulate] duger inte – den multiplicerar, så en mörk järnkropp
## skulle bara bli ljusare grå.
func flash(amount: float = 0.85, duration: float = 0.18) -> void:
	if not _ready_to_draw:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_set_flash(amount)
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash, amount, 0.0, duration)


func flash_amount() -> float:
	return _flash


func _set_flash(value: float) -> void:
	_flash = clampf(value, 0.0, 1.0)
	queue_redraw()


# --- Geometri (statisk, så att testerna kan läsa den utan en skärm) ----------

## Materialets fem steg som färger. Okänt material ritas som järn.
static func palette(die_material: int) -> Array[Color]:
	var raw: Array = PALETTES.get(die_material, PALETTES[Rules.DieMaterial.IRON]) as Array
	var colors: Array[Color] = []
	for hex: Variant in raw:
		colors.append(Color(String(hex)))
	# Ben är tärningens standardläsning och följer temats token (hög kontrast
	# gör den vit).
	if die_material == Rules.DieMaterial.BONE:
		colors[4] = Tokens.BONE_DIE
	return colors


## Tärningens kvadrat (kroppen inklusive undersidan) i en ruta av [param box].
static func body_rect(box: Vector2) -> Rect2:
	var side: float = maxf(4.0, minf(box.x, box.y) * FILL)
	# Lite ovanför mitten: skuggan under tar resten.
	var origin: Vector2 = (box - Vector2(side, side)) * 0.5 - Vector2(0.0, side * 0.03)
	return Rect2(origin, Vector2(side, side))


## Ovansidan: kroppen minus undersidans tjocklek.
static func top_rect(body: Rect2) -> Rect2:
	return Rect2(body.position, Vector2(body.size.x, body.size.y * (1.0 - DEPTH)))


## Pipsens mittpunkter för [param count] ögon på ovansidan [param top].
static func pip_centers(count: int, top: Rect2) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	# Ovansidan är lite lägre än bred (undersidan syns), så rutnätet följer den.
	var spread: Vector2 = top.size * PIP_SPREAD
	for raw: Variant in PIP_LAYOUT.get(count, []) as Array:
		var cell: Vector2 = raw as Vector2
		out.append(top.get_center() + cell * spread)
	return out


## En rundad rektangel som polygon (medurs från övre vänstra hörnet).
static func rounded_rect(rect: Rect2, radius: float, steps: int = CORNER_STEPS,
		offset: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var r: float = clampf(radius, 0.0, minf(rect.size.x, rect.size.y) * 0.5)
	var points: PackedVector2Array = PackedVector2Array()
	var corners: Array[Vector2] = [
		rect.position + Vector2(r, r),
		Vector2(rect.end.x - r, rect.position.y + r),
		rect.end - Vector2(r, r),
		Vector2(rect.position.x + r, rect.end.y - r),
	]
	for i: int in range(4):
		var start: float = PI + float(i) * PI * 0.5
		for step: int in range(steps + 1):
			var angle: float = start + float(step) / float(steps) * PI * 0.5
			points.append(corners[i] + Vector2(cos(angle), sin(angle)) * r + offset)
	return points


## Sprickans linjer: 2–3 sicksackar från en kant in mot mitten. Samma
## [param variant_seed] ger samma spricka hela runnen. Koordinaterna är i
## enhetsrutan (0–1) och skalas av anroparen.
static func crack_paths(variant_seed: int) -> Array[PackedVector2Array]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(variant_seed) & 0x7FFFFFFF
	var paths: Array[PackedVector2Array] = []
	var start: Vector2 = Vector2(rng.randf_range(0.18, 0.5), 0.02)
	var trunk: PackedVector2Array = PackedVector2Array([start])
	var point: Vector2 = start
	for i: int in range(5):
		point += Vector2(rng.randf_range(-0.12, 0.14), rng.randf_range(0.1, 0.17))
		trunk.append(Vector2(clampf(point.x, 0.06, 0.94), clampf(point.y, 0.02, 0.94)))
	paths.append(trunk)
	var branch_from: Vector2 = trunk[2 + rng.randi_range(0, 1)]
	var branch: PackedVector2Array = PackedVector2Array([branch_from])
	point = branch_from
	for i: int in range(3):
		point += Vector2(rng.randf_range(0.08, 0.16), rng.randf_range(-0.02, 0.1))
		branch.append(Vector2(clampf(point.x, 0.06, 0.96), clampf(point.y, 0.04, 0.94)))
	paths.append(branch)
	return paths


# --- Ritning -----------------------------------------------------------------

## Färgen efter blixten: lerpad mot vitt med [member _flash].
func _lit(color: Color) -> Color:
	if _flash <= 0.0:
		return color
	return Color(color.lerp(Color.WHITE, _flash), color.a)


func _draw() -> void:
	if not _ready_to_draw or size.x <= 1.0 or size.y <= 1.0:
		return
	var colors: Array[Color] = palette(_material)
	var body: Rect2 = body_rect(size)
	var side: float = body.size.x
	var radius: float = side * CORNER
	var top: Rect2 = top_rect(body)
	var is_glass: bool = _material == Rules.DieMaterial.GLASS
	var hc: bool = Tokens.high_contrast

	# 1. Skugga: två lager, det yttre bredare och svagare. Tärningen ska se
	#    tung ut – den står på bordet, den svävar inte.
	var shadow_offset: Vector2 = Vector2(side * 0.02, side * 0.07)
	draw_colored_polygon(rounded_rect(body.grow(side * 0.05), radius * 1.2, CORNER_STEPS, shadow_offset),
		Color(0.0, 0.0, 0.0, 0.22))
	draw_colored_polygon(rounded_rect(body.grow(side * 0.015), radius, CORNER_STEPS, shadow_offset * 0.6),
		Color(0.0, 0.0, 0.0, 0.45))

	# 2. Kanten: hela kroppen i den mörka mellantonen = framsidans tjocklek.
	var body_poly: PackedVector2Array = rounded_rect(body, radius)
	draw_colored_polygon(body_poly, _lit(colors[1]))

	# 3. Ovansidan med vertikal gradient (per hörn-färg, Gouraud).
	var top_poly: PackedVector2Array = rounded_rect(top, radius)
	var top_colors: PackedColorArray = PackedColorArray()
	var alpha: float = 0.9 if is_glass else 1.0
	for point: Vector2 in top_poly:
		var t: float = clampf((point.y - top.position.y) / maxf(1.0, top.size.y), 0.0, 1.0)
		var shade: Color = colors[4].lerp(colors[3], smoothstep(0.0, 0.55, t)).lerp(colors[2], smoothstep(0.55, 1.0, t) * 0.55)
		shade.a = alpha
		top_colors.append(_lit(shade))
	draw_polygon(top_poly, top_colors)

	# 4. Glans: kantljus längs ovankant och vänsterkant (ljuset uppe till
	#    vänster, samma som ikonernas skuggning). Glas får ett diagonalt sken.
	var rim: float = maxf(1.0, side * 0.03)
	var highlight: Color = Color(colors[4].lerp(Color.WHITE, 0.5), 0.55 if not is_glass else 0.8)
	draw_polyline(_arc_edge(top, radius, true), _lit(highlight), rim, true)
	if is_glass:
		var sheen: PackedVector2Array = PackedVector2Array([
			top.position + Vector2(top.size.x * 0.16, top.size.y * 0.1),
			top.position + Vector2(top.size.x * 0.5, top.size.y * 0.1),
			top.position + Vector2(top.size.x * 0.12, top.size.y * 0.56),
			top.position + Vector2(top.size.x * 0.1, top.size.y * 0.3),
		])
		draw_colored_polygon(sheen, Color(1.0, 1.0, 1.0, 0.16 + 0.3 * _flash))
		draw_polyline(_closed(top_poly), _lit(Color(colors[4], 0.7)), maxf(1.0, side * 0.018), true)

	# 5. Konturen: mörk och kantutjämnad, runt hela kroppen. Döljer också att
	#    draw_polygon inte kantutjämnar.
	var outline: float = maxf(1.0, side * (0.045 if hc else 0.032))
	draw_polyline(_closed(body_poly), Color(colors[0].darkened(0.2), 0.95), outline, true)
	# Skiljelinjen mellan ovansida och framkant.
	var seam_y: float = top.end.y
	draw_line(Vector2(body.position.x + radius * 0.6, seam_y), Vector2(body.end.x - radius * 0.6, seam_y),
		_lit(Color(colors[0], 0.35)), maxf(1.0, side * 0.012), true)

	# 6. Sidan.
	if _shows_pips:
		_draw_pips(top, colors)
	elif _glyph != null:
		# Ingraverad medaljong bakom glyphen: en mörk skål ger en ljus token
		# (sem/shield på järn) samma kontrast som en mörk (sem/fire på ben).
		var inlay_r: float = top.size.x * 0.36
		draw_circle(top.get_center(), inlay_r, _lit(Color(colors[0], 0.34)), true, -1.0, true)
		draw_arc(top.get_center(), inlay_r, deg_to_rad(-10.0), deg_to_rad(110.0), 16,
			_lit(Color(colors[4].lerp(Color.WHITE, 0.3), 0.5)), maxf(1.0, side * 0.014), true)
		var glyph_side: float = top.size.x * GLYPH_FILL
		var glyph_rect: Rect2 = Rect2(top.get_center() - Vector2(glyph_side, glyph_side) * 0.5,
			Vector2(glyph_side, glyph_side))
		draw_texture_rect(_glyph, glyph_rect, false, _lit(_glyph_tint))

	# 7. Sprickan.
	if _cracked:
		_draw_crack(top, colors)


func _draw_pips(top: Rect2, colors: Array[Color]) -> void:
	var pip_color: Color = Tokens.BONE_PIP
	var r: float = top.size.x * PIP_RADIUS
	if _pips == 0:
		# Den spruckna sidan (värde 0): en ihålig ring i stället för ögon.
		draw_arc(top.get_center(), r * 2.0, 0.0, TAU, 32, _lit(Color(pip_color, 0.85)), maxf(1.0, r * 0.55), true)
		return
	var lip: Color = Color(colors[4].lerp(Color.WHITE, 0.35), 0.55)
	for center: Vector2 in pip_centers(_pips, top):
		# Insänkt öga: mörk skål, ljus läpp nere till höger där ljuset faller
		# in, och en hårfin skugga uppe till vänster.
		draw_circle(center, r * 1.08, _lit(Color(colors[1], 0.45)), true, -1.0, true)
		draw_circle(center, r, _lit(pip_color), true, -1.0, true)
		draw_arc(center, r * 0.86, deg_to_rad(-10.0), deg_to_rad(100.0), 10, _lit(lip), maxf(1.0, r * 0.28), true)


func _draw_crack(top: Rect2, colors: Array[Color]) -> void:
	var width: float = maxf(1.0, top.size.x * 0.03)
	for path: PackedVector2Array in crack_paths(_crack_seed):
		var scaled: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in path:
			scaled.append(top.position + point * top.size)
		# Ljus kant först (brottytan fångar ljuset), mörk spricka ovanpå.
		var lit_edge: PackedVector2Array = scaled.duplicate()
		for i: int in range(lit_edge.size()):
			lit_edge[i] += Vector2(width * 0.6, width * 0.6)
		draw_polyline(lit_edge, _lit(Color(colors[4], 0.6)), width * 0.8, true)
		draw_polyline(scaled, Color(colors[0].darkened(0.3), 0.95), width, true)


## Polygonen stängd, för draw_polyline.
static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = points.duplicate()
	if out.size() > 0:
		out.append(out[0])
	return out


## Kanten från nedre vänstra hörnets början, över övre vänstra hörnet, längs
## ovankanten till övre högra hörnet: där ljuset träffar.
static func _arc_edge(rect: Rect2, radius: float, _upper_left: bool) -> PackedVector2Array:
	var inset: Rect2 = rect.grow(-maxf(1.0, rect.size.x * 0.035))
	var r: float = clampf(radius * 0.9, 0.0, minf(inset.size.x, inset.size.y) * 0.5)
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2(inset.position.x, inset.end.y - r * 1.4))
	var corner: Vector2 = inset.position + Vector2(r, r)
	for step: int in range(CORNER_STEPS + 1):
		var angle: float = PI + float(step) / float(CORNER_STEPS) * PI * 0.5
		points.append(corner + Vector2(cos(angle), sin(angle)) * r)
	points.append(Vector2(inset.end.x - r * 1.2, inset.position.y))
	return points


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
		"SEM_FROST":
			return Tokens.SEM_FROST
	return Tokens.BONE_PIP
