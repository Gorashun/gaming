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
	return tex(portrait_key(variant))


## Porträttets manifest-id: [code]hero.portrait.a[/code] / [code].b[/code].
static func portrait_key(variant: String) -> StringName:
	return StringName("hero.portrait." + smith_variant(variant))

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


# ===========================================================================
# M6: art-manifestet. Innehålls-id → fil, byte = byt fil (DECISIONS 2026-09-23)
# ===========================================================================
#
# [b]Uppslagsordningen är hela kontraktet[/b] och den är densamma för varje id:
# [br]1. [code]assets/art/manifest.json[/code] – posten finns och filen laddas.
# [br]2. Fiender: aliaset ur [constant ENEMY_ART_ALIASES] i manifestet
#    ([code]enemy.RUST_MITE[/code] → [code]enemy.RUST_RAT[/code]).
# [br]3. Den gamla scriptgenererade spriten ur [code]assets/sprites/[/code]
#    ([constant LEGACY_ART]). Den är pixelkonst och ritas därför med Nearest.
# [br]4. Platshållaren: [code]enemy.placeholder[/code] / [code]icon.placeholder[/code]
#    ur manifestet, annars en genererad textur. Varnar EN gång per id.
#
# Ingen väg returnerar null för en fiende eller en ikon, och ingen väg kraschar.

const MANIFEST_PATH: String = "res://assets/art/manifest.json"
const ART_ROOT: String = "res://assets/art/"

const KIND_BATTLER: String = "battler"
const KIND_ICON: String = "icon"
const KIND_PORTRAIT: String = "portrait"
const KIND_FRAME: String = "frame"
const KIND_ENV: String = "env"
const KIND_FX: String = "fx"
const KIND_UI: String = "ui"
const KINDS: Array[String] = [KIND_BATTLER, KIND_ICON, KIND_PORTRAIT, KIND_FRAME, KIND_ENV, KIND_FX, KIND_UI]
const PIVOTS: Array[String] = ["bottom", "center"]

const SOURCE_MANIFEST: String = "manifest"
const SOURCE_LEGACY: String = "legacy"
const SOURCE_PLACEHOLDER: String = "placeholder"
const SOURCE_NONE: String = "none"

const ID_ENEMY_PLACEHOLDER: StringName = &"enemy.placeholder"
const ID_ICON_PLACEHOLDER: StringName = &"icon.placeholder"

## Miljö-id:n som korridoren frågar efter. Reserven är M5:s kakel.
## [b]Taket lånar golvets kakel i reserven.[/b] [code]ceiling_stone.png[/code]
## har två helt röda pixelrader (y 14 och 46, "glödfogar") som upprepas två
## gånger per ruta och läste som röda scanlines i taket (research 06 §1). Filen
## ägs av assets/ och ligger kvar; koden slutar bara använda den.
const LEGACY_ART: Dictionary = {
	&"env.corridor.wall": "env/corridor/wall_stone.png",
	&"env.corridor.floor": "env/corridor/floor_stone.png",
	&"env.corridor.ceiling": "env/corridor/floor_stone.png",
	&"env.corridor.door": "env/corridor/door_boss.png",
	&"env.corridor.torch": "env/corridor/torch.png",
	&"env.corridor.sign": "env/corridor/sign_plate.png",
	&"hero.portrait.a": "hero/smith_portrait_a.png",
	&"hero.portrait.b": "hero/smith_portrait_b.png",
}

## Bossarna ritas större (ART_DIRECTION_V2 §4: "Boss ritas 1,6×"). En
## manifestpost kan också säga [code]"tier": "boss"[/code].
const BOSS_IDS: Array[String] = ["SLAGJAW", "SLAGJAW_RUNT"]

static var _manifest: Dictionary = {}
static var _manifest_loaded: bool = false
static var _manifest_errors: PackedStringArray = PackedStringArray()
## Ökar vid varje [method reload_manifest]. En vy som vill byta konst i farten
## jämför sin sparade siffra med den här.
static var manifest_version: int = 0
static var _art_cache: Dictionary = {}
static var _art_warned: Dictionary = {}
static var _generated: Dictionary = {}
## Laddade filer, [code]"sökväg|mip"[/code] → textur. Två id:n som pekar på
## samma fil delar textur (och minne).
static var _file_cache: Dictionary = {}


## Hela manifestet, `id → post`. Laddas lat en gång och cachas.
static func manifest() -> Dictionary:
	if not _manifest_loaded:
		_manifest_loaded = true
		_manifest = _read_manifest(MANIFEST_PATH)
	return _manifest


## Läser om manifestet och tömmer alla texturcacher. [b]Hot-swap:[/b] noder som
## byggs efter anropet får den nya konsten; befintliga noder behåller sin.
static func reload_manifest() -> void:
	_manifest_loaded = false
	_manifest = {}
	_manifest_errors = PackedStringArray()
	_art_cache.clear()
	_art_warned.clear()
	_file_cache.clear()
	_frames.clear()
	manifest_version += 1
	manifest()


## Ersätter manifestet med [param data] utan att läsa filen. För tester och
## för verktyg som vill prova en post innan den skrivs till disk.
static func use_manifest(data: Dictionary) -> void:
	_manifest_loaded = true
	_manifest = {}
	_manifest_errors = PackedStringArray()
	for key: Variant in data:
		if data[key] is Dictionary:
			_manifest[String(key)] = data[key]
	_art_cache.clear()
	_art_warned.clear()
	_file_cache.clear()
	_frames.clear()
	manifest_version += 1


## Problem som hittades när manifestet lästes (trasig JSON, fel form).
static func manifest_errors() -> PackedStringArray:
	manifest()
	return _manifest_errors


static func _read_manifest(path: String) -> Dictionary:
	var text: String = ""
	# JSON är en importerad resurs i Godot 4 och följer därför med i exporten
	# (export_presets har inget include_filter). FileAccess är reserven för en
	# fil som lagts dit utan att editorn importerat den.
	if ResourceLoader.exists(path):
		var res: JSON = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as JSON
		if res != null and res.data is Dictionary:
			return _only_entries(res.data as Dictionary)
	if FileAccess.file_exists(path):
		text = FileAccess.get_file_as_string(path)
	if text == "":
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		_manifest_errors.append("%s är inte ett JSON-objekt" % path)
		push_warning("Art: %s gick inte att läsa som JSON – all konst faller tillbaka" % path)
		return {}
	return _only_entries(parsed as Dictionary)


static func _only_entries(data: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in data:
		var value: Variant = data[key]
		if value is Dictionary:
			out[String(key)] = value
		elif not String(key).begins_with("_"):
			_manifest_errors.append("posten %s är inte ett objekt" % String(key))
	return out


## Manifestposten för [param id], eller tom.
static func entry(id: StringName) -> Dictionary:
	return manifest().get(String(id), {}) as Dictionary


## Texturen för ett innehålls-id. Se uppslagsordningen i sektionens huvud.
static func tex(id: StringName) -> Texture2D:
	return art_info(id)["texture"] as Texture2D


## Allt en vy behöver veta om ett id:
## [code]{texture, source, pixel, size: Vector2, pivot, frames, kind, scale, boss}[/code].
## [code]source[/code] är [constant SOURCE_MANIFEST], [constant SOURCE_LEGACY],
## [constant SOURCE_PLACEHOLDER] eller [constant SOURCE_NONE].
static func art_info(id: StringName) -> Dictionary:
	if _art_cache.has(id):
		return _art_cache[id] as Dictionary
	var info: Dictionary = _resolve(id)
	_art_cache[id] = info
	return info


static func _resolve(id: StringName) -> Dictionary:
	var key: String = String(id)
	var from_manifest: Dictionary = _from_manifest(key)
	if not from_manifest.is_empty():
		return from_manifest
	# Fiendealias: tutorialens pedagogiska varianter lånar våning 1:s konst.
	if key.begins_with("enemy."):
		var enemy_id: String = key.trim_prefix("enemy.")
		var art_id: String = enemy_art_id(enemy_id)
		if art_id != enemy_id:
			var aliased: Dictionary = _from_manifest("enemy." + art_id)
			if not aliased.is_empty():
				return aliased
	var legacy: Dictionary = _legacy(key)
	if not legacy.is_empty():
		return legacy
	return _placeholder(key)


static func _from_manifest(key: String) -> Dictionary:
	var e: Dictionary = manifest().get(key, {}) as Dictionary
	if e.is_empty():
		return {}
	var path: String = String(e.get("file", ""))
	var kind: String = String(e.get("kind", ""))
	var pixel: bool = bool(e.get("pixel", false))
	var mipmapped: bool = not pixel and (kind == KIND_BATTLER or kind == KIND_ENV)
	var cache_key: String = "%s|%s" % [path, "mip" if mipmapped else "raw"]
	var loaded: Texture2D = _file_cache.get(cache_key, null) as Texture2D
	if loaded == null:
		loaded = _load_art_file(path)
		if loaded != null and mipmapped:
			loaded = with_mipmaps(loaded)
		if loaded != null:
			_file_cache[cache_key] = loaded
	if loaded == null:
		_warn_once(key, "manifestet pekar på %s som inte finns" % path)
		return {}
	var frames: int = maxi(1, int(e.get("frames", 1)))
	var size: Vector2 = _entry_size(e, loaded)
	return {
		"texture": loaded,
		"source": SOURCE_MANIFEST,
		"pixel": pixel,
		"size": size,
		"pivot": String(e.get("pivot", "bottom")),
		"frames": frames,
		"kind": kind,
		"scale": float(e.get("scale", 1.0)),
		"boss": String(e.get("tier", "")) == "boss",
	}


static func _entry_size(e: Dictionary, texture: Texture2D) -> Vector2:
	var raw: Variant = e.get("size", null)
	if raw is Array and (raw as Array).size() == 2:
		var w: float = float((raw as Array)[0])
		var h: float = float((raw as Array)[1])
		if w > 0.0 and h > 0.0:
			return Vector2(w, h)
	var frames: int = maxi(1, int(e.get("frames", 1)))
	return Vector2(float(texture.get_width()) / float(frames), float(texture.get_height()))


## Laddar en fil ur manifestet. [b]Två vägar:[/b] den importerade resursen, och
## om den saknas själva PNG:en från disk – så att en fil som bytts ut under
## utveckling syns efter [method reload_manifest] utan omimport.
static func _load_art_file(path: String) -> Texture2D:
	if path == "" or not path.begins_with("res://"):
		return null
	if ResourceLoader.exists(path):
		var loaded: Texture2D = ResourceLoader.load(path) as Texture2D
		if loaded != null:
			return loaded
	if FileAccess.file_exists(path):
		var image: Image = Image.load_from_file(path)
		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)
	return null


## Samma textur med mipmaps. Målad konst skalas ner 3–6× i korridoren och
## blinkar utan dem. En komprimerad textur lämnas orörd (den har sina egna).
static func with_mipmaps(texture: Texture2D) -> Texture2D:
	if texture == null or texture is AtlasTexture:
		return texture
	var image: Image = texture.get_image()
	if image == null or image.is_empty() or image.has_mipmaps() or image.is_compressed():
		return texture
	image = image.duplicate() as Image
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


static func _legacy(key: String) -> Dictionary:
	var found: Texture2D = null
	var size: Vector2 = Vector2.ZERO
	var kind: String = ""
	if key.begins_with("enemy."):
		var enemy_id: String = enemy_art_id(key.trim_prefix("enemy."))
		var spec: Dictionary = ENEMIES.get(enemy_id, {}) as Dictionary
		var sheet: Texture2D = texture(String(spec.get("file", "")))
		if sheet != null:
			var cell: int = int(spec.get("cell", 32))
			var slice: AtlasTexture = AtlasTexture.new()
			slice.atlas = sheet
			slice.region = Rect2(0.0, 0.0, float(cell), float(cell))
			slice.filter_clip = true
			found = slice
			size = Vector2(cell, cell)
			kind = KIND_BATTLER
	elif LEGACY_ART.has(StringName(key)):
		found = texture(String(LEGACY_ART[StringName(key)]))
		kind = KIND_ENV if key.begins_with("env.") else KIND_PORTRAIT
	elif key.begins_with("relic."):
		found = texture("items/relic_%s.png" % key.trim_prefix("relic.").to_lower())
		kind = KIND_ICON
	elif key.begins_with("slot."):
		found = texture("ui/slot_%s.png" % key.trim_prefix("slot.").to_lower())
		kind = KIND_ICON
	elif key.begins_with("node."):
		found = texture("ui/node_%s.png" % key.trim_prefix("node.").to_lower())
		kind = KIND_ICON
	elif key.begins_with("ui.icon."):
		found = ui_icon(StringName(key.trim_prefix("ui.icon.")))
		kind = KIND_ICON
	if found == null:
		return {}
	if size == Vector2.ZERO:
		size = Vector2(found.get_width(), found.get_height())
	return {
		"texture": found,
		"source": SOURCE_LEGACY,
		"pixel": true,
		"size": size,
		"pivot": "bottom",
		"frames": 1,
		"kind": kind,
		"scale": 1.0,
		"boss": BOSS_IDS.has(key.trim_prefix("enemy.")) or size.y >= 48.0 and kind == KIND_BATTLER,
	}


## Sista utvägen. Fiender och ikoner får ALDRIG vara null; ramar, paneler och
## effekter får det – deras anropare ritar en StyleBox i stället.
static func _placeholder(key: String) -> Dictionary:
	var is_enemy: bool = key.begins_with("enemy.")
	var is_icon: bool = key.begins_with("gear.") or key.begins_with("relic.") \
		or key.begins_with("slot.") or key.begins_with("node.") or key.begins_with("icon.") \
		or key.begins_with("ui.icon.")
	if not is_enemy and not is_icon:
		_warn_once(key, "ingen konst och ingen reserv – anroparen ritar sin egen")
		return {"texture": null, "source": SOURCE_NONE, "pixel": false, "size": Vector2.ZERO,
			"pivot": "bottom", "frames": 1, "kind": "", "scale": 1.0, "boss": false}
	var holder: StringName = ID_ENEMY_PLACEHOLDER if is_enemy else ID_ICON_PLACEHOLDER
	var info: Dictionary = {}
	if key != String(holder):
		info = _from_manifest(String(holder))
	if info.is_empty():
		var generated: Texture2D = placeholder_texture(is_enemy)
		info = {"texture": generated, "source": SOURCE_PLACEHOLDER, "pixel": false,
			"size": Vector2(generated.get_width(), generated.get_height()), "pivot": "bottom",
			"frames": 1, "kind": KIND_BATTLER if is_enemy else KIND_ICON, "scale": 1.0,
			"boss": false}
	else:
		info = info.duplicate()
		info["source"] = SOURCE_PLACEHOLDER
	info["boss"] = is_enemy and BOSS_IDS.has(key.trim_prefix("enemy."))
	_warn_once(key, "saknas i manifestet och har ingen gammal sprite – ritar platshållaren")
	return info


## En genererad platshållare: en mörk, huvförsedd silhuett (fiende) eller en
## sotcirkel med en ljus kant (ikon). Ingen fil, alltså kan den aldrig saknas.
static func placeholder_texture(enemy: bool) -> Texture2D:
	var key: String = "enemy" if enemy else "icon"
	if _generated.has(key):
		return _generated[key] as Texture2D
	var w: int = 96 if enemy else 64
	var h: int = 128 if enemy else 64
	var image: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var body: Color = Color(0.16, 0.18, 0.21)
	var rim: Color = Color(0.91, 0.88, 0.81)
	for y: int in range(h):
		for x: int in range(w):
			var u: float = (float(x) + 0.5) / float(w) * 2.0 - 1.0
			var v: float = (float(y) + 0.5) / float(h)
			var inside: float = 0.0
			if enemy:
				# Huva (cirkel) på en kropp som vidgas nedåt.
				var head: float = Vector2(u, (v - 0.26) * 2.2).length()
				var half_width: float = lerpf(0.34, 0.92, clampf((v - 0.30) / 0.66, 0.0, 1.0))
				inside = 1.0 if head < 0.46 or (v > 0.30 and v < 0.98 and absf(u) < half_width) else 0.0
			else:
				var r: float = Vector2(u, v * 2.0 - 1.0).length()
				inside = 1.0 if r < 0.86 else 0.0
				if inside > 0.0 and r > 0.72:
					image.set_pixel(x, y, rim)
					continue
			if inside > 0.0:
				image.set_pixel(x, y, body)
	var result: ImageTexture = ImageTexture.create_from_image(image)
	_generated[key] = result
	return result


static func _warn_once(key: String, message: String) -> void:
	if _art_warned.has(key):
		return
	_art_warned[key] = true
	push_warning("Art: '%s' %s" % [key, message])


## Rätt 2D-filter för ett id: Nearest bara när konsten är pixelkonst
## (manifestets [code]pixel: true[/code] eller en gammal sprite).
static func filter_for(id: StringName) -> int:
	if bool(art_info(id)["pixel"]):
		return CanvasItem.TEXTURE_FILTER_NEAREST
	return CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


static func is_pixel(id: StringName) -> bool:
	return bool(art_info(id)["pixel"])


## Innehålls-id:t för en fiende.
static func enemy_art_key(enemy_id: String) -> StringName:
	return StringName("enemy." + enemy_id)


## Varje fiende-id spelet kan visa: våning 1:s möten, tutorialens fiender och
## arkregistret. Manifestvalideringen och testerna går över den här listan.
static func content_enemy_ids() -> PackedStringArray:
	var seen: Dictionary = {}
	for enemy_id: String in ENEMIES:
		seen[enemy_id] = true
	for room: int in range(1, Content.rooms_per_floor() + 1):
		for variant: int in [0, 1]:
			for enemy: Enemy in Content.encounter(room, variant):
				seen[enemy.id] = true
	for index: int in range(Tutorial.room_count()):
		for enemy: Enemy in Tutorial.enemies_for(index):
			seen[enemy.id] = true
	var ids: PackedStringArray = PackedStringArray()
	for key: Variant in seen:
		ids.append(String(key))
	ids.sort()
	return ids


## Formkontroll av manifestet. Returnerar en rad per problem, tom när allt
## håller. [b]Körs av tests/test_manifest.gd[/b], så en trasig post fäller
## bygget i stället för att bli en tyst platshållare i spelet.
static func validate_manifest(data: Dictionary = {}) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var entries: Dictionary = data if not data.is_empty() else manifest()
	if data.is_empty():
		problems.append_array(manifest_errors())
	for key: Variant in entries:
		var id: String = String(key)
		var e: Dictionary = entries[key] as Dictionary
		var path: String = String(e.get("file", ""))
		if path == "":
			problems.append("%s: saknar file" % id)
		elif not path.begins_with(ART_ROOT):
			problems.append("%s: %s ligger inte under %s" % [id, path, ART_ROOT])
		elif not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
			problems.append("%s: filen %s finns inte" % [id, path])
		var kind: String = String(e.get("kind", ""))
		if not KINDS.has(kind):
			problems.append("%s: okänd kind '%s'" % [id, kind])
		var raw_size: Variant = e.get("size", null)
		if not (raw_size is Array and (raw_size as Array).size() == 2
				and float((raw_size as Array)[0]) > 0.0 and float((raw_size as Array)[1]) > 0.0):
			problems.append("%s: size ska vara [w, h] > 0" % id)
		if e.has("pivot") and not PIVOTS.has(String(e["pivot"])):
			problems.append("%s: okänd pivot '%s'" % [id, String(e["pivot"])])
		if e.has("frames") and int(e["frames"]) < 1:
			problems.append("%s: frames < 1" % id)
		if id.begins_with("enemy.") and kind != "" and kind != KIND_BATTLER:
			problems.append("%s: fiender ska vara kind battler" % id)
		if (id.begins_with("gear.") or id.begins_with("relic.")) and kind != "" and kind != KIND_ICON:
			problems.append("%s: föremål ska vara kind icon" % id)
		if not e.has("license") or String(e.get("license", "")) == "":
			problems.append("%s: saknar license" % id)
	return problems


## En föremålsikon ur manifestet: [code]gear.<ID>[/code]. [param icon_id] får
## vara med eller utan prefix. Faller tillbaka på den generiska ikonen.
static func gear_icon(icon_id: String) -> Texture2D:
	if icon_id == "":
		return tex(ID_ICON_PLACEHOLDER)
	var key: String = icon_id if icon_id.contains(".") else "gear." + icon_id
	return tex(StringName(key))


## Sällsynthetens ram, eller null (anroparen ritar då en StyleBox i
## sällsynthetens färg). Namnen följer [code]rarity.frame.<common|uncommon|rare|epic>[/code].
static func rarity_frame(rarity_name: String) -> Texture2D:
	var info: Dictionary = art_info(StringName("rarity.frame." + rarity_name.to_lower()))
	return info["texture"] as Texture2D if String(info["source"]) == SOURCE_MANIFEST else null


## Kastskuggan under en fiende: en mjuk svart ellips, genererad en gång.
static func shadow_texture() -> Texture2D:
	if _generated.has("shadow"):
		return _generated["shadow"] as Texture2D
	var w: int = 64
	var h: int = 32
	var image: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y: int in range(h):
		for x: int in range(w):
			var d: float = Vector2((float(x) + 0.5) / float(w) * 2.0 - 1.0,
				(float(y) + 0.5) / float(h) * 2.0 - 1.0).length()
			var a: float = clampf(1.0 - smoothstep(0.35, 1.0, d), 0.0, 1.0)
			image.set_pixel(x, y, Color(0.0, 0.0, 0.0, a))
	image.generate_mipmaps()
	var result: ImageTexture = ImageTexture.create_from_image(image)
	_generated["shadow"] = result
	return result


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


## Slot-ikonen ur manifestet ([code]slot.<typ>[/code]), med M1.5-spriten som reserv.
static func slot_icon(slot_type: int) -> Texture2D:
	return tex(StringName("slot." + Rules.slot_type_name(slot_type).to_lower()))


## Nodikonen för en förgreningsknapp. M1 har bara strid och boss i grafen; de
## fyra övriga ikonerna finns och väntar på M2:s nodtyper.
static func node_icon(kind: String) -> Texture2D:
	return tex(StringName("node." + kind.to_lower()))


## Relikens ikon ([code]relic.<ID>[/code]). Aldrig null: saknas både manifest
## och sprite blir det den generiska ikonen.
static func relic_icon(relic_id: String) -> Texture2D:
	return tex(StringName("relic." + relic_id))


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
