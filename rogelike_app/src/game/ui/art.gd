class_name Art
extends RefCounted
## Enda uppslagsplatsen för pixelgrafiken i [code]assets/sprites/[/code].
##
## Filnamnen står här och ingen annanstans. Byts en sprite ut (utbytesplanen i
## [code]assets/sprites/README.md[/code] när CC0-paketen går att hämta) ändras
## en rad här, inte fem skärmar.
##
## [b]Tre regler som hela pixelpipen vilar på[/b] (research 04 §5, UI_GUIDE §8.3):
## [br]1. [b]Nearest, alltid.[/b] [code]project.godot[/code] sätter
##    [code]default_texture_filter = 0[/code] globalt, men krit-UI:t
##    ([code]ChalkUI[/code]) står på Linear och ärver nedåt. Sprites som ligger
##    [i]inuti[/i] krit-UI:t (tärningsbrickan, slot-ramar, kortikoner) måste
##    därför sätta [constant CanvasItem.TEXTURE_FILTER_NEAREST] själva. Det gör
##    [method pixel_sprite] och [method pixel_texture_rect].
## [br]2. [b]Heltalsskala, alltid.[/b] En 32 px-tärning på 2,5× ger ojämna
##    pixlar. [method fit_scale] räknar därför ut största heltal som får plats.
## [br]3. [b]Heltalspositioner.[/b] [method snap] kvantiserar mot skalan, annars
##    kryper kanterna under marschens sidoscroll.

const SPRITES: String = "res://assets/sprites"
const PALETTE_SHADER: String = "res://src/game/shaders/palette_lut.gdshader"

## 16×16-ikoner i krit-UI:t (COMBAT_READABILITY §9). Varje post är en lista med
## kandidatfilnamn, eftersom UI-agenten levererar dem parallellt och det exakta
## namnet inte är låst. Första filen som finns vinner; finns ingen returneras
## null, anroparen ritar sin glyf-reserv och [method missing_icons] räknar upp.
##
## [b]Regeln:[/b] en saknad ikon ska ge en varning och en reservglyf, aldrig en
## krasch och aldrig ett tomt hål där en regel skulle ha stått.
const UI_ICONS: Dictionary = {
	&"armor": ["ui/icon_armor.png", "ui/armor.png", "ui/shield.png"],
	&"attack": ["ui/icon_attack.png", "ui/attack.png", "ui/sword.png"],
	&"help": ["ui/icon_help.png", "ui/help.png"],
	&"charge": ["ui/icon_charge.png", "ui/charge.png", "ui/slot_charge.png"],
	&"overflow": ["ui/icon_overflow.png", "ui/icon_spill.png", "ui/overflow.png"],
	&"pointer": ["ui/icon_tutorial_pointer.png", "ui/tutorial_pointer.png", "ui/chalk_pointer.png"],
	&"arrow_left": ["ui/icon_arrow_left.png"],
	&"arrow_forward": ["ui/icon_arrow_forward.png"],
	&"arrow_right": ["ui/icon_arrow_right.png"],
	&"sheet": ["ui/icon_sheet.png"],
	&"settings": ["ui/icon_settings.png"],
	&"undo": ["ui/icon_undo.png"],
}

## Reservglyfer när ikonen saknas. Formkoden får aldrig försvinna helt.
##
## [b]Varje tecken här måste finnas i en buntad font[/b] (Familjen Grotesk eller
## symbolfallbacken, se [code]assets/fonts/[/code]). Reservglyfen är sista
## utvägen när PNG:en inte laddas, och en reserv som blir en tom ruta i
## webbexporten är ingen reserv alls. [code]tests/test_fonts.gd[/code] bevakar
## tabellen. Därför står här [code]⮌[/code] och inte [code]↩[/code],
## [code]⯄[/code] och inte [code]⚙[/code], [code]✖[/code] och inte
## [code]⚔[/code]: de tre sistnämnda saknas i båda fonterna.
const UI_ICON_GLYPHS: Dictionary = {
	&"armor": "⛊",
	&"attack": "✖",
	&"help": "?",
	&"charge": "⬤",
	&"overflow": "⮡",
	&"pointer": "➤",
	&"arrow_left": "◀",
	&"arrow_forward": "▲",
	&"arrow_right": "▶",
	&"sheet": "◫",
	&"settings": "⯄",
	&"undo": "⮌",
}

## 16×16-ikonernas nominella storlek i dp. 16 dp × 3 px/dp = 48 px, alltså exakt
## 3× heltalsskala på 1080-viewporten (regel 2 i klassens huvud).
const ICON_DP: int = 16

static var _missing_icons: Dictionary = {}


## En 16×16-ikon ur [constant UI_ICONS], eller null. Varnar en gång per namn.
static func ui_icon(icon_name: StringName) -> Texture2D:
	for candidate: Variant in UI_ICONS.get(icon_name, []) as Array:
		var tex: Texture2D = texture(String(candidate))
		if tex != null:
			return tex
	if not _missing_icons.has(icon_name):
		_missing_icons[icon_name] = true
		push_warning("Art: 16×16-ikonen '%s' saknas i assets/sprites/ui/ – ritar reservglyfen '%s'" % [
			icon_name, UI_ICON_GLYPHS.get(icon_name, "?")])
	return null


static func ui_icon_glyph(icon_name: StringName) -> String:
	return String(UI_ICON_GLYPHS.get(icon_name, ""))


## Ikonens storlek i px: största heltalsskala av 16 px som ryms i
## [param size_dp]. Aldrig en bråkdel – regel 2 i klassens huvud. 16 dp ger
## 48 px (3×), 14 dp ger 32 px (2×).
static func icon_px(size_dp: int = ICON_DP) -> int:
	return 16 * maxi(1, int(floor(Tokens.dp(size_dp) / 16.0)))


## Cache för [method scaled_ui_icon]: [code]"namn@px" → ImageTexture[/code].
static var _scaled_icons: Dictionary = {}


## 16×16-ikonen uppskalad till [param size_dp] med [b]nearest[/b] och
## heltalsfaktor.
##
## [b]Varför en förstorad textur och inte skalning vid ritning:[/b]
## [member Button.icon] ritas i texturens egen storlek, och temakonstanten
## [code]icon_max_width[/code] kan bara krympa. En 16 px-sprite blev därför en
## 16 px-prick mitt i en 102 px-knapp. Med rätt storlek redan i texturen sköter
## [Button] både centreringen (ikon utan text) och radningen bredvid texten
## (ikon + text), och pixlarna sitter på heltal.
static func scaled_ui_icon(icon_name: StringName, size_dp: int = ICON_DP) -> Texture2D:
	var px: int = icon_px(size_dp)
	var key: String = "%s@%d" % [icon_name, px]
	if _scaled_icons.has(key):
		return _scaled_icons[key] as Texture2D
	var tex: Texture2D = ui_icon(icon_name)
	if tex == null:
		return null
	var image: Image = tex.get_image()
	if image == null:
		return tex
	image = image.duplicate() as Image
	image.resize(px, px, Image.INTERPOLATE_NEAREST)
	var scaled: ImageTexture = ImageTexture.create_from_image(image)
	_scaled_icons[key] = scaled
	return scaled


## Sätter [param button]:s ikon till 16×16-spriten [param icon_name].
##
## [b]Varför ikon och inte knapptext:[/b] en symbolglyf i [member Button.text]
## ritas av fonten, och tecknen det gäller fanns bara i systemfonten –
## webbexporten ritade en tom ruta (docs/BACKLOG.md). En sprite ritas likadant
## överallt. Saknas PNG:en faller knappen tillbaka på reservglyfen ur
## [constant UI_ICON_GLYPHS], som alltid finns i en buntad font.
##
## Returnerar [code]true[/code] när spriten användes. Idempotent: anropas den
## igen (sheet-knappens kritring tänds) byts bara färgen.
static func apply_button_icon(button: Button, icon_name: StringName, tint: Color, size_dp: int = ICON_DP) -> bool:
	var tex: Texture2D = scaled_ui_icon(icon_name, size_dp)
	if tex == null:
		button.text = ui_icon_glyph(icon_name)
		button.add_theme_color_override("font_color", tint)
		return false
	button.icon = tex
	button.expand_icon = false
	for state: String in ["normal", "pressed", "hover", "hover_pressed", "focus", "disabled"]:
		button.add_theme_color_override("icon_%s_color" % state, tint)
	return true


## Ikonen som en fristående nod att lägga i en rad bredvid en siffra. Saknas
## PNG:en returneras en [Label] med reservglyfen i stället – aldrig ett hål.
static func icon_rect(icon_name: StringName, tint: Color = Color.WHITE, size_dp: int = ICON_DP) -> Control:
	var px: int = icon_px(size_dp)
	var tex: Texture2D = scaled_ui_icon(icon_name, size_dp)
	if tex == null:
		var label: Label = Label.new()
		label.name = "IconGlyph"
		label.text = ui_icon_glyph(icon_name)
		label.add_theme_font_size_override("font_size", px)
		label.add_theme_color_override("font_color", tint)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return label
	var rect: TextureRect = TextureRect.new()
	rect.name = "Icon"
	rect.texture = tex
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(px, px)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.modulate = tint
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Ikoner som saknades under körningen. Rökprovet skriver ut listan.
static func missing_icons() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for key: Variant in _missing_icons:
		names.append(String(key))
	names.sort()
	return names


# --- Smeden: två kroppsvarianter (DECISIONS 2026-09-21) --------------------

## Giltiga kroppsvarianter. Spelet omtalar figuren könsneutralt ("The Smith");
## varianten är en [b]kroppsform[/b], inte ett könsord i UI-texten.
const SMITH_VARIANTS: Array[String] = ["a", "b"]
const SMITH_VARIANT_DEFAULT: String = "a"


static func smith_variant(value: String) -> String:
	return value if SMITH_VARIANTS.has(value) else SMITH_VARIANT_DEFAULT


## Kropps- och hårlagret för en variant. Faller tillbaka på det variantlösa
## M1.5-arket så att figuren aldrig försvinner innan UI-agenten levererat.
static func smith_layer(layer: StringName, variant: String) -> Texture2D:
	var v: String = smith_variant(variant)
	var tex: Texture2D = texture("hero/smith_%s_%s.png" % [layer, v])
	if tex != null:
		return tex
	return texture("hero/smith_%s.png" % layer)


## Porträttet i könsvalet och (senare) på character sheetet.
static func smith_portrait(variant: String) -> Texture2D:
	return texture("hero/smith_portrait_%s.png" % smith_variant(variant))

## Karaktärer och fiender i World-lagret: 32/48 px-celler × 4 (UI_GUIDE §8.3).
const WORLD_SCALE: int = 4
## 16 px-ikoner (relik, slot, nod) i krit-UI:t.
const ICON_SCALE: int = 4

## Fiendeark. Rad 0 är fyra idle-frames, rad 1 är dödsanimationen
## (assets/sprites/README.md §1, ändrat i M2: [code]hframes = 4, vframes = 2[/code]).
## [code]death[/code] har tre authorade frames; den fjärde kolumnen upprepar
## den sista och skärs därför inte ut.
const ENEMIES: Dictionary = {
	"RUST_RAT": {"file": "enemies/rust_rat.png", "cell": 32, "frames": 4, "rows": 2, "death_frames": 3},
	"SLAG_MOTH": {"file": "enemies/slag_moth.png", "cell": 32, "frames": 4, "rows": 2, "death_frames": 3},
	"THORN_IMP": {"file": "enemies/thorn_imp.png", "cell": 32, "frames": 4, "rows": 2, "death_frames": 3},
	"PIP_THIEF": {"file": "enemies/pip_thief.png", "cell": 32, "frames": 4, "rows": 2, "death_frames": 3},
	"IRON_TICK": {"file": "enemies/iron_tick.png", "cell": 32, "frames": 4, "rows": 2, "death_frames": 3},
	"GRAVE_HAND": {"file": "enemies/grave_hand.png", "cell": 32, "frames": 4, "rows": 2, "death_frames": 3},
	"SLAGJAW": {"file": "enemies/slagjaw.png", "cell": 48, "frames": 4, "rows": 2, "death_frames": 3},
}

## Tutorialvåningens fiender (TOWN_AND_ONBOARDING §B.2) lånar arken från våning
## 1. De är [b]pedagogiska varianter[/b], inte nytt innehåll: en Rust Mite är en
## mindre Rostråtta och ska se ut som en. Får någon av dem en egen PNG räcker
## det att ta bort raden här och lägga till en i [constant ENEMIES].
const ENEMY_ART_ALIASES: Dictionary = {
	"CHALK_DUMMY": "IRON_TICK",
	"RUST_MITE": "RUST_RAT",
	"SLAG_PUP": "SLAG_MOTH",
	"TICK_PUP": "IRON_TICK",
	"SCRAP_GATE": "GRAVE_HAND",
	"SLAGJAW_RUNT": "SLAGJAW",
}


## Arkets id för en fiende: sig själv, eller det ark den lånar.
static func enemy_art_id(enemy_id: String) -> String:
	if ENEMIES.has(enemy_id):
		return enemy_id
	return String(ENEMY_ART_ALIASES.get(enemy_id, enemy_id))


## Dödsanimationens takt. Tre frames på 10 fps ≈ 300 ms, vilket ryms i
## [code]enemy_killed[/code]-budgeten på 360 ms (UI_GUIDE §5.5).
const DEATH_FPS: float = 10.0

## Paperdoll-lagerark för UTRUSTNING, se assets/sprites/hero/PAPERDOLL.md §5.
## Reliklagren ligger inte här: de slås upp per relik-id i
## [method HeroFigure.apply_relics] enligt namnkontraktet
## [code]smith_<lager>_<id>.png[/code]. [code]legs[/code] tillkom i M2.
## [b]M2.5:[/b] [code]body[/code] och [code]hair[/code] ligger INTE här längre.
## De är kroppsvarianter ([constant SMITH_BODY_LAYERS]) och slås upp per variant
## i [method smith_layer]; resten av garderoben är kroppsoberoende och delas av
## båda (PAPERDOLL §1, DECISIONS 2026-09-21).
const HERO_LAYERS: Dictionary = {
	&"cape": "hero/smith_cape_ember.png",
	&"legs": "hero/smith_legs_iron.png",
	&"helm": "hero/smith_helm_iron.png",
	&"weapon": "hero/smith_weapon_hammer.png",
}

## Lagren som byts med kroppsvarianten.
const SMITH_BODY_LAYERS: Array[StringName] = [&"body", &"hair"]
## Vapenvariant B, för M2:s utrustningsbyte.
const HERO_WEAPON_TONGS: String = "hero/smith_weapon_tongs.png"

## PAPERDOLL.md §3. Reliken tänder sitt primärlager; är det upptaget flyttar den
## till reservlagret. [code]fx[/code] stackar och avslutar därför alltid kedjan.
## Arken heter [code]hero/smith_<lager>_<id i gemener>.png[/code] och slås upp av
## [method HeroFigure.apply_relics]; samtliga levererades i M2.
const RELIC_LAYERS: Dictionary = {
	"BLOOD_PRICE": [&"fx"],
	"BROKEN_SCALE": [&"torso", &"offhand"],
	"OCTOPUS": [&"cape", &"fx"],
	"ECHO_MIRROR": [&"cape", &"torso"],
	"CHEAT_CUBE": [&"offhand", &"torso"],
	"DOMINO": [&"helm", &"head"],
}

## Sidor med egen glyph (UI_GUIDE §9.3). Allt annat ritas som pips för sitt
## värde; en ny smidbar sida i M2 kostar en rad här och en PNG.
const FACE_GLYPHS: Dictionary = {
	"POISON_DROP": {"file": "dice/glyph_gift.png", "color": "SEM_POISON"},
	"EMBER": {"file": "dice/glyph_eld.png", "color": "SEM_FIRE"},
	"VAMP_FANG": {"file": "dice/glyph_blod.png", "color": "SEM_BLOOD"},
	"HOLLOW": {"file": "dice/glyph_tomrum.png", "color": "SEM_SHIELD"},
}

const LUTS: Dictionary = {
	Rules.DieMaterial.IRON: "dice/lut_iron.png",
	Rules.DieMaterial.BONE: "dice/lut_bone.png",
	Rules.DieMaterial.GLASS: "dice/lut_glass.png",
}

## Förtintade tärningskroppar, en per material. [b]Reserv sedan M2:[/b] den
## dokumenterade vägen (assets/sprites/README.md §3) är gråskalemastern
## [constant DIE_BODY_GRAY] genom [code]palette_lut.gdshader[/code] med en
## 16×1-LUT per material, och den fungerar igen sedan UI-agenten fixade
## shaderns dubbelmultiplikation mot modulate (DECISIONS 2026-09-21 antog
## sRGB-tapp; rotorsaken var att fragmentets COLOR redan innehåller modulate).
## De förtintade kropparna ritas bara om gråskalan eller LUT:en saknas.
const DIE_BODIES: Dictionary = {
	Rules.DieMaterial.IRON: "dice/die_body_iron.png",
	Rules.DieMaterial.BONE: "dice/die_body_bone.png",
	Rules.DieMaterial.GLASS: "dice/die_body_glass.png",
}

## Gråskalemastern som LUT-vägen använder.
const DIE_BODY_GRAY: String = "dice/die_body_gray.png"
const DIE_TUMBLE: String = "dice/die_tumble_gray.png"
const GLASS_RIM: String = "dice/glass_highlight.png"
# M5.5: FLOOR_TILE och PARALLAX är borta med den platta 2D-sidovyn. Korridoren
# har sina egna kakelbara texturer i [CorridorMesh]; parallax finns inte längre
# någonstans i spelet. PNG-filerna under assets/sprites/env/ ägs av UI-agenten
# och städas där (docs/BACKLOG.md).

static var _textures: Dictionary = {}
static var _frames: Dictionary = {}


# --- Texturer --------------------------------------------------------------

## Laddar en textur ur [code]assets/sprites/[/code]. Returnerar null om filen
## saknas – anroparen behåller då sin platshållare i stället för att krascha.
static func texture(relative_path: String) -> Texture2D:
	if relative_path == "":
		return null
	if _textures.has(relative_path):
		return _textures[relative_path] as Texture2D
	var path: String = "%s/%s" % [SPRITES, relative_path]
	var result: Texture2D = null
	if ResourceLoader.exists(path):
		result = ResourceLoader.load(path) as Texture2D
	_textures[relative_path] = result
	return result


static func has(relative_path: String) -> bool:
	return texture(relative_path) != null


static func enemy_cell(enemy_id: String) -> int:
	var entry: Dictionary = ENEMIES.get(enemy_art_id(enemy_id), {}) as Dictionary
	return int(entry.get("cell", 32))


## Idle-loopen för en fiende som [SpriteFrames]. Cachas: rum 1 är fyra
## Rostråttor och ska inte skära ut samma atlas fyra gånger.
static func enemy_frames(p_enemy_id: String, fps: float = 6.0) -> SpriteFrames:
	var enemy_id: String = enemy_art_id(p_enemy_id)
	if _frames.has(enemy_id):
		return _frames[enemy_id] as SpriteFrames
	var entry: Dictionary = ENEMIES.get(enemy_id, {}) as Dictionary
	var sheet: Texture2D = texture(String(entry.get("file", "")))
	var result: SpriteFrames = null
	if sheet != null:
		var cell: int = int(entry.get("cell", 32))
		result = SpriteFrames.new()
		_add_row(result, &"default", sheet, cell, 0, int(entry.get("frames", 1)), fps, true)
		var death_frames: int = int(entry.get("death_frames", 0))
		if death_frames > 0 and int(entry.get("rows", 1)) > 1:
			_add_row(result, &"death", sheet, cell, 1, death_frames, DEATH_FPS, false)
	_frames[enemy_id] = result
	return result


## Skär ut [param count] celler ur rad [param row]. [AtlasTexture] delar
## källbilden, så ett ark med två rader kostar inte mer minne än ett med en.
static func _add_row(frames: SpriteFrames, anim: StringName, sheet: Texture2D,
		cell: int, row: int, count: int, fps: float, loop: bool) -> void:
	if not frames.has_animation(anim):
		frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for i: int in range(count):
		var slice: AtlasTexture = AtlasTexture.new()
		slice.atlas = sheet
		slice.region = Rect2(float(i * cell), float(row * cell), float(cell), float(cell))
		slice.filter_clip = true
		frames.add_frame(anim, slice)


## Tärningskroppen för ett material. Gråskalemastern när den och materialets
## LUT finns (då bär [method die_material] färgen), annars den förtintade.
static func die_body(die_material: int) -> Texture2D:
	if lut_path_available(die_material):
		return texture(DIE_BODY_GRAY)
	return texture(String(DIE_BODIES.get(die_material, DIE_BODIES[Rules.DieMaterial.IRON])))


## Går LUT-vägen att använda för det här materialet?
static func lut_path_available(die_material: int) -> bool:
	return texture(DIE_BODY_GRAY) != null and die_lut(die_material) != null


## Materialet som färgar gråskalekroppen. [b]Ett eget ShaderMaterial per
## anrop[/b] och inte ett delat: [code]flash[/code] sätts per tärning, och ett
## delat material hade blixtrat alla sex tärningarna samtidigt.
## I hög kontrast höjs [code]luma_gamma[/code] till 1,35 (UI_GUIDE §8.5).
static func die_material(die_material: int) -> ShaderMaterial:
	var mat: ShaderMaterial = palette_material(die_lut(die_material), 1.0)
	if mat != null and Tokens.high_contrast:
		mat.set_shader_parameter("luma_gamma", 1.35)
	return mat


## 16×1-LUT:en för ett material (assets/sprites/README.md §3).
static func die_lut(die_material: int) -> Texture2D:
	return texture(String(LUTS.get(die_material, LUTS[Rules.DieMaterial.IRON])))


## Overlayn för en sida: glyph om sidan har en, annars pips för värdet.
## Returnerar [code]{texture, color_token, is_pips}[/code], där
## [code]color_token[/code] är "NONE" när texturen redan bär sin färg.
static func face_overlay(face: Face) -> Dictionary:
	if face == null:
		return {"texture": null, "color_token": "NONE", "is_pips": false}
	if FACE_GLYPHS.has(face.id):
		var glyph: Dictionary = FACE_GLYPHS[face.id]
		return {
			"texture": texture(String(glyph["file"])),
			"color_token": String(glyph["color"]),
			"is_pips": false,
		}
	# Pip-arken är redan tintade i bone/pip (#12161A). Ett modulate ovanpå det
	# skulle kvadrera färgen och göra ögonen svarta; glypherna är däremot vita
	# (chalk/100) och SKA tintas av sin semantiska token.
	var value: int = clampi(face.value, 0, 6)
	return {
		"texture": texture("dice/pips_%d.png" % value),
		"color_token": "NONE",
		"is_pips": true,
	}


## Sprickvariant. [param variant_seed] är visuell slump och får aldrig dra ur
## den seedade [Rng]-strömmen (ARCHITECTURE: rendering rör inte strömmen).
static func crack(variant_seed: int) -> Texture2D:
	return texture("dice/crack_%d.png" % (1 + posmod(variant_seed, 3)))


static func slot_icon(slot_type: int) -> Texture2D:
	return texture("ui/slot_%s.png" % Rules.slot_type_name(slot_type).to_lower())


## Nodikonen för en förgreningsknapp. M1 har bara strid och boss i grafen; de
## fyra övriga ikonerna finns och väntar på M2:s nodtyper.
static func node_icon(kind: String) -> Texture2D:
	return texture("ui/node_%s.png" % kind.to_lower())


static func relic_icon(relic_id: String) -> Texture2D:
	return texture("items/relic_%s.png" % relic_id.to_lower())


# --- Noder -----------------------------------------------------------------

## En [Sprite2D] med Nearest-filter och heltalsskala. Används även inuti
## krit-UI:t, som annars ärver Linear och suddar pixlarna.
static func pixel_sprite(tex: Texture2D = null, art_scale: int = 1) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = tex
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(art_scale, art_scale)
	return sprite


## Träffblixtens material: palette_lut utan LUT, bara [code]flash[/code].
## Sätts PÅ noden när blixten börjar och tas bort när den slutar – se noten vid
## [constant DIE_BODIES] om varför den inte får ligga kvar.
static func flash_material() -> ShaderMaterial:
	return palette_material(null, 0.0)


## Ett [ShaderMaterial] med palette_lut.gdshader. [param lut] null ⇒
## [code]lut_strength = 0[/code]: spriten behåller sina egna färger och shadern
## används bara för [code]flash[/code] (träffblixten, UI_GUIDE §5.3).
static func palette_material(lut: Texture2D = null, strength: float = 1.0, tint: Color = Color.WHITE) -> ShaderMaterial:
	var shader: Shader = ResourceLoader.load(PALETTE_SHADER) as Shader
	if shader == null:
		return null
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("palette_lut", lut)
	mat.set_shader_parameter("lut_strength", 0.0 if lut == null else strength)
	mat.set_shader_parameter("flash", 0.0)
	mat.set_shader_parameter("material_tint", tint)
	return mat


# --- Heltalsmatematik ------------------------------------------------------

## Största heltalsskala där [param cell] px konst får plats i [param box].
static func fit_scale(box: Vector2, cell: int, max_scale: int = 8) -> int:
	if cell <= 0:
		return 1
	var shortest: float = minf(box.x, box.y)
	return clampi(int(floor(shortest / float(cell))), 1, max_scale)


## Kvantiserar en position mot konstrutnätet. De globala snap_2d_*-flaggorna
## snappar mot viewportpixlar och hjälper inte här (research 04 §5).
static func snap(point: Vector2, art_scale: int) -> Vector2:
	var step: float = float(maxi(1, art_scale))
	return Vector2(floor(point.x / step) * step, floor(point.y / step) * step)
