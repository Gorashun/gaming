class_name Tokens
extends RefCounted
## Designtokens ur docs/UI_GUIDE.md §2 (riktning A, KRITGROPEN).
##
## Enda stället i [code]src/game/[/code] där en färg eller ett avstånd får stå
## som literal. Byter UI-agenten palett eller typsnitt ändras den här filen, inte
## tjugo scener.
##
## [b]dp → px:[/b] viewporten är 1080×1920 och UI_GUIDE:s referens är 360×640 dp,
## alltså exakt 3 px per dp. Använd [method dp] för allt som specen anger i dp,
## så att träffytorna (48 dp = 144 px) faktiskt blir rätt.

## Pixlar per dp i 1080×1920-viewporten.
const DP: float = 3.0

## Läge "Hög kontrast+" (UI_GUIDE §2.11). Speglas hit av [code]Settings[/code]
## via [method apply_high_contrast].
##
## [b]Varför färgerna är [code]static var[/code] och inte [code]const[/code]:[/b]
## §2.11 är uttryckligen "en token-override, inte ett andra tema – samma
## tokennamn, andra värden". Med statiska variabler byter [Tokens] tabell och
## [b]inget anropsställe ändras[/b]; med konstanter hade varje skärm behövt en
## egen uppslagning. Priset är att en skärm som redan är byggd behåller sina
## färger tills den byggs om – modalen bygger om sig själv direkt, övriga
## skärmar nästa gång de visas.
static var high_contrast: bool = false

# --- §2.1 Yta --------------------------------------------------------------
static var SURFACE_PIT: Color = Color("#0E1216")
static var SURFACE_SLATE: Color = Color("#161B21")
static var SURFACE_RAISED: Color = Color("#1F262E")
static var SURFACE_LINE: Color = Color("#2C353F")
static var SURFACE_SCRIM: Color = Color(0.055, 0.071, 0.086, 0.72)

# --- §2.2 Krita och tärning ------------------------------------------------
static var CHALK_100: Color = Color("#F2EDE3")
static var CHALK_300: Color = Color("#CFC7B8")
static var CHALK_500: Color = Color("#9A9486")
static var BONE_DIE: Color = Color("#E8E0CF")
static var BONE_PIP: Color = Color("#12161A")

# --- §2.3 Semantik ---------------------------------------------------------
static var SEM_DAMAGE: Color = Color("#F2EDE3")
static var SEM_FIRE: Color = Color("#FF6A2C")
static var SEM_POISON: Color = Color("#B77FFF")
static var SEM_FROST: Color = Color("#6ED2F5")
static var SEM_HEAL: Color = Color("#4FE3A0")
static var SEM_BLOOD: Color = Color("#FF556F")
static var SEM_CHARGE: Color = Color("#FFD447")
static var SEM_SHIELD: Color = Color("#D7DEE6")
## Överflödspilen, §4.4.
static var SEM_OVERFLOW: Color = Color("#FF8A2C")

# --- §2.6 Spacing (bas 4 dp) -----------------------------------------------
const SPACE_1: int = 4
const SPACE_2: int = 8
const SPACE_3: int = 12
const SPACE_4: int = 16
const SPACE_6: int = 24
const SPACE_8: int = 32
const SPACE_12: int = 48
const SPACE_16: int = 64
## Skärmmarginal i dp.
const SCREEN_MARGIN: int = 16

# --- §2.7 Radier och linjer ------------------------------------------------
const RADIUS_CHIP: int = 4
const RADIUS_BUTTON: int = 8
const RADIUS_DIE: int = 14
const RADIUS_CARD: int = 20
const STROKE_HAIR: float = 1.5
const STROKE_REG: float = 2.0
const STROKE_BOLD: float = 3.0
const STROKE_HEAVY: float = 4.0

# --- §2.8 Typografi (dp) ---------------------------------------------------
const TYPE_DISPLAY_XL: int = 56
const TYPE_DISPLAY_L: int = 40
const TYPE_TITLE: int = 28
const TYPE_HEADING: int = 22
const TYPE_BODY_L: int = 18
const TYPE_BODY: int = 16
const TYPE_LABEL: int = 14
const TYPE_CAPTION: int = 12

## Typsnitten ur §2.8. [code]assets/fonts/[/code] har de fulla OFL-originalen av
## Familjen Grotesk, Anton och Caveat Brush plus symbolfallbacken
## [code]pipwreck_symbols.ttf[/code]. Alla fyra importeras med
## [code]allow_system_fallback=false[/code]: spelet får aldrig låna en
## systemfont, för då ser webbexporten annorlunda ut än telefonen
## (docs/BACKLOG.md, "Symbolglyfer blir tofu i webbexporten").
##
## [code]ui_regular.tres[/code] är också projektets standardfont
## ([code]project.godot[/code], [code]gui/theme/custom_font[/code]), så en
## [Label] utan override får den automatiskt. De tre andra sätts explicit där
## §2.8 kräver dem.
const FONT_UI_PATH: String = "res://assets/fonts/ui_regular.tres"
const FONT_UI_BOLD_PATH: String = "res://assets/fonts/ui_bold.tres"
const FONT_DISPLAY_PATH: String = "res://assets/fonts/display.tres"
const FONT_SCRAWL_PATH: String = "res://assets/fonts/scrawl.tres"

## Laddade en gång. [method ResourceLoader.load] cachar redan, men uppslaget
## ligger i varje etikettbygge och en Dictionary-läsning är billigare.
static var _fonts: Dictionary = {}


## Fonten bakom en av FONT_*_PATH. Returnerar null om filen saknas; anroparen
## hoppar då över sin override och får projektets standardfont.
static func font(path: String) -> Font:
	if _fonts.has(path):
		return _fonts[path] as Font
	var loaded: Font = ResourceLoader.load(path) as Font
	if loaded == null:
		push_warning("Tokens: fonten %s saknas – ritar med standardfonten" % path)
	_fonts[path] = loaded
	return loaded


## Familjen Grotesk 400 (§2.8 body/caption). Samma som standardfonten.
static func font_ui() -> Font:
	return font(FONT_UI_PATH)


## Familjen Grotesk 700 (§2.8 title/heading/label).
static func font_ui_bold() -> Font:
	return font(FONT_UI_BOLD_PATH)


## Anton (§2.8 display-xl/display-l: kedjans totalsiffra, number pop, rubrik).
static func font_display() -> Font:
	return font(FONT_DISPLAY_PATH)


## Caveat Brush (§2.8 scrawl: kritklotter, max 3 ord).
static func font_scrawl() -> Font:
	return font(FONT_SCRAWL_PATH)


## Sätter [param node]:s textfont. Tyst no-op när fonten inte gick att ladda.
static func apply_font(node: Control, value: Font) -> void:
	if node == null or value == null:
		return
	node.add_theme_font_override("normal_font" if node is RichTextLabel else "font", value)


## §2.8: allt som ritas i display-xl eller display-l sätts i Anton.
static func apply_display_font(node: Control) -> void:
	apply_font(node, font_display())


## §2.8: rubrik, knapptext och etikett är Familjen Grotesk 700.
static func apply_bold_font(node: Control) -> void:
	apply_font(node, font_ui_bold())


## Storlek [b]och[/b] typsnitt för en av TYPE_*-konstanterna, enligt tabellen i
## §2.8: display-xl/display-l är Anton, title/heading är Familjen Grotesk 700,
## allt mindre är Familjen Grotesk 400 (projektets standardfont, ingen override
## behövs). Ett anropsställe i stället för "sätt storlek här, kom ihåg fonten
## där" – §2.8 är en tabell och ska läsas som en.
static func apply_type(node: Control, size_token: int) -> void:
	if node == null:
		return
	node.add_theme_font_size_override("font_size", dpi(size_token))
	if size_token >= TYPE_DISPLAY_L:
		apply_display_font(node)
	elif size_token >= TYPE_TITLE:
		apply_bold_font(node)


# --- §2.9 Touch targets (dp) -----------------------------------------------
const TOUCH_MIN: int = 48
const DIE_SIZE: int = 64
const DIE_HIT: int = 72
## Minsta bredd per tärning i brickan. UI_GUIDE §8 mätte 49,7 dp på 360 dp
## bredd: sex 72 dp-tärningar ryms helt enkelt inte i portrait.
const DIE_MIN_WIDTH: int = 48
const SLOT_WIDTH: int = 64
const SLOT_HEIGHT: int = 76
const BUTTON_PRIMARY_HEIGHT: int = 56
const BUTTON_SECONDARY_WIDTH: int = 96
const BUTTON_SECONDARY_HEIGHT: int = 48

# --- §2.10 Rörelse (sekunder) ----------------------------------------------
const MOTION_SNAP: float = 0.09
const MOTION_QUICK: float = 0.14
const MOTION_BASE: float = 0.22
const MOTION_CHAIN_STEP: float = 0.26
const MOTION_CELEBRATE: float = 0.52
const MOTION_PANEL: float = 0.30


## dp → px i 1080×1920-viewporten.
static func dp(value: float) -> float:
	return value * DP


## dp → px som heltal, för storlekar och teckenstorlekar.
static func dpi(value: int) -> int:
	return int(round(float(value) * DP))


# --- §2.11 Hög kontrast+ ---------------------------------------------------

## Standardpaletten, sparad vid inläsning så att läget går att stänga av igen.
static var _standard: Dictionary = {}

## Övervärdena ur UI_GUIDE §2.11. Minsta kontrast i läget: 6,1:1
## ([code]surface/line[/code]); standardtemats minimum är 4,9:1.
const HIGH_CONTRAST: Dictionary = {
	"SURFACE_PIT": "#000000",
	"SURFACE_SLATE": "#000000",
	"SURFACE_RAISED": "#0A0A0A",
	"SURFACE_LINE": "#808C99",
	"CHALK_100": "#FFFFFF",
	"CHALK_300": "#EDEDED",
	"CHALK_500": "#B9B9B9",
	"BONE_DIE": "#FFFFFF",
	"BONE_PIP": "#000000",
	"SEM_DAMAGE": "#FFFFFF",
	"SEM_FIRE": "#FF8A3D",
	"SEM_POISON": "#C99CFF",
	"SEM_FROST": "#8FE4FF",
	"SEM_HEAL": "#6BF7B8",
	"SEM_BLOOD": "#FF7D90",
	"SEM_CHARGE": "#FFE270",
	"SEM_SHIELD": "#E9EEF4",
}


## Slår om paletten. Idempotent, och [b]återställbar[/b]: standardvärdena
## sparas första gången läget slås på.
static func apply_high_contrast(enabled: bool) -> void:
	if enabled == high_contrast and not _standard.is_empty():
		high_contrast = enabled
		return
	if _standard.is_empty():
		for token: String in HIGH_CONTRAST:
			_standard[token] = get_color(token)
	high_contrast = enabled
	for token: String in HIGH_CONTRAST:
		set_color(token, Color(String(HIGH_CONTRAST[token])) if enabled else _standard[token] as Color)
	# Scrim är samma botten med 72 % alfa (§2.1) och följer därför med.
	SURFACE_SCRIM = Color(SURFACE_PIT, 0.72)
	SLOT_STYLE = _build_slot_style()
	RARITY_STYLE = _build_rarity_style()


## Färgen bakom ett tokennamn. Reflection i stället för en lång match: tabellen
## ovan får aldrig kunna glida isär från fälten.
static func get_color(token: String) -> Color:
	match token:
		"SURFACE_PIT": return SURFACE_PIT
		"SURFACE_SLATE": return SURFACE_SLATE
		"SURFACE_RAISED": return SURFACE_RAISED
		"SURFACE_LINE": return SURFACE_LINE
		"CHALK_100": return CHALK_100
		"CHALK_300": return CHALK_300
		"CHALK_500": return CHALK_500
		"BONE_DIE": return BONE_DIE
		"BONE_PIP": return BONE_PIP
		"SEM_DAMAGE": return SEM_DAMAGE
		"SEM_FIRE": return SEM_FIRE
		"SEM_POISON": return SEM_POISON
		"SEM_FROST": return SEM_FROST
		"SEM_HEAL": return SEM_HEAL
		"SEM_BLOOD": return SEM_BLOOD
		"SEM_CHARGE": return SEM_CHARGE
		"SEM_SHIELD": return SEM_SHIELD
	return CHALK_100


static func set_color(token: String, value: Color) -> void:
	match token:
		"SURFACE_PIT": SURFACE_PIT = value
		"SURFACE_SLATE": SURFACE_SLATE = value
		"SURFACE_RAISED": SURFACE_RAISED = value
		"SURFACE_LINE": SURFACE_LINE = value
		"CHALK_100": CHALK_100 = value
		"CHALK_300": CHALK_300 = value
		"CHALK_500": CHALK_500 = value
		"BONE_DIE": BONE_DIE = value
		"BONE_PIP": BONE_PIP = value
		"SEM_DAMAGE": SEM_DAMAGE = value
		"SEM_FIRE": SEM_FIRE = value
		"SEM_POISON": SEM_POISON = value
		"SEM_FROST": SEM_FROST = value
		"SEM_HEAL": SEM_HEAL = value
		"SEM_BLOOD": SEM_BLOOD = value
		"SEM_CHARGE": SEM_CHARGE = value
		"SEM_SHIELD": SEM_SHIELD = value


# --- i18n ------------------------------------------------------------------
# CLAUDE.md: all spelartext är engelska i källan och går via tr(). Statiska
# funktioner kan inte anropa Object.tr(), så de går via TranslationServer –
# samma uppslagning, samma CSV, samma fallback (en).

## Översätter [param key]. Saknas nyckeln returnerar Godot nyckeln själv.
static func translate(key: String) -> String:
	return String(TranslationServer.translate(key))


## Översätter [param key], men faller tillbaka på [param fallback] om nyckeln
## saknas helt. Används för innehålls-id:n ur [Content] som kan vara okända
## (en fiende som lagts till i data men inte i CSV:n syns då med sitt engelska
## källnamn i stället för som en rå nyckel).
static func translate_or(key: String, fallback: String) -> String:
	var value: String = String(TranslationServer.translate(key))
	return fallback if value == key else value


# --- §2.4 Slot-typer: färg + form + ramstil --------------------------------
## Ramstilen är redundant med färgen (§2.4) så att en färgblind spelare kan
## skilja alla fem typer på enbart ram + ikon + text.
## [code]key[/code] slås upp i assets/i18n/translations.csv; [code]icon[/code] är
## reservglyphen när slot-spriten (assets/sprites/ui/slot_*.png) inte laddas.
## Färgen slås upp per token-NAMN, inte som ett värde, så att tabellen följer
## med när §2.11 byter palett. Ramstil och ikon är oberoende av färgen – det är
## hela poängen med §2.4.
const SLOT_STYLE_SPEC: Dictionary = {
	Rules.SlotType.PLAIN: {"key": "SLOT_PLAIN", "icon": "·", "token": "CHALK_300", "border": "solid", "width": STROKE_REG},
	Rules.SlotType.FIRE: {"key": "SLOT_FIRE", "icon": "▲", "token": "SEM_FIRE", "border": "solid", "width": STROKE_REG},
	Rules.SlotType.MIRROR: {"key": "SLOT_MIRROR", "icon": "❖", "token": "SEM_FROST", "border": "double", "width": STROKE_REG},
	Rules.SlotType.ANVIL: {"key": "SLOT_ANVIL", "icon": "⬣", "token": "SEM_SHIELD", "border": "thick", "width": STROKE_HEAVY},
	Rules.SlotType.CHARGE: {"key": "SLOT_CHARGE", "icon": "⬤", "token": "SEM_CHARGE", "border": "dotted", "width": STROKE_REG},
	Rules.SlotType.VOID: {"key": "SLOT_VOID", "icon": "⬚", "token": "SURFACE_LINE_TEXT", "border": "dashed", "width": STROKE_REG},
}

static var SLOT_STYLE: Dictionary = _build_slot_style()


## Tomrummets grå (§2.4, #8A94A6) har ingen egen token i §2.1–2.3. I hög
## kontrast följer den [code]chalk/500[/code], som är den ljusaste neutrala.
static func _build_slot_style() -> Dictionary:
	var out: Dictionary = {}
	for slot_type: Variant in SLOT_STYLE_SPEC:
		var spec: Dictionary = (SLOT_STYLE_SPEC[slot_type] as Dictionary).duplicate()
		var token: String = String(spec["token"])
		spec["color"] = CHALK_500 if token == "SURFACE_LINE_TEXT" and high_contrast \
			else (Color("#8A94A6") if token == "SURFACE_LINE_TEXT" else get_color(token))
		out[slot_type] = spec
	return out


static func slot_style(slot_type: int) -> Dictionary:
	return SLOT_STYLE.get(slot_type, SLOT_STYLE[Rules.SlotType.PLAIN]) as Dictionary


static func slot_color(slot_type: int) -> Color:
	return slot_style(slot_type)["color"] as Color


static func slot_label(slot_type: int) -> String:
	return translate(String(slot_style(slot_type)["key"]))


static func slot_icon(slot_type: int) -> String:
	return String(slot_style(slot_type)["icon"])


# --- §2.5 Sällsynthet: färg + ramform + utskrivet ord ----------------------
const RARITY_STYLE_SPEC: Dictionary = {
	Rules.Rarity.COMMON: {"key": "RARITY_COMMON", "mark": "▭", "token": "CHALK_300"},
	Rules.Rarity.UNCOMMON: {"key": "RARITY_UNCOMMON", "mark": "◣", "token": "SEM_HEAL"},
	Rules.Rarity.RARE: {"key": "RARITY_RARE", "mark": "▤", "token": "SEM_FROST"},
}

static var RARITY_STYLE: Dictionary = _build_rarity_style()


static func _build_rarity_style() -> Dictionary:
	var out: Dictionary = {}
	for rarity: Variant in RARITY_STYLE_SPEC:
		var spec: Dictionary = (RARITY_STYLE_SPEC[rarity] as Dictionary).duplicate()
		spec["color"] = get_color(String(spec["token"]))
		out[rarity] = spec
	return out


static func rarity_style(rarity: int) -> Dictionary:
	return RARITY_STYLE.get(rarity, RARITY_STYLE[Rules.Rarity.COMMON]) as Dictionary


static func rarity_color(rarity: int) -> Color:
	return rarity_style(rarity)["color"] as Color


static func rarity_label(rarity: int) -> String:
	return translate(String(rarity_style(rarity)["key"]))


# --- §2.5 Multiplikatorbadge ------------------------------------------------
## Färg OCH storlek skiljer multiplikatorerna åt; siffran står alltid utskriven,
## så färgen är dekor (§6.2).
static func multiplier_color(multiplier: int) -> Color:
	if multiplier >= 16:
		# §2.5 mytisk rosa. Har ingen egen rad i §2.11; i hög kontrast lånar den
		# sem/charge, som är den ljusaste accenten och redan mäter 16,4:1.
		return SEM_CHARGE if high_contrast else Color("#FF5CA8")
	if multiplier >= 8:
		return SEM_BLOOD
	if multiplier >= 4:
		return SEM_OVERFLOW
	if multiplier >= 2:
		return SEM_CHARGE
	return CHALK_300


static func multiplier_size(multiplier: int) -> int:
	if multiplier >= 16:
		return 40
	if multiplier >= 8:
		return 34
	if multiplier >= 4:
		return 28
	return 24


# --- Kategorietiketter för belöningskort -----------------------------------
static func category_label(category: String) -> String:
	match category:
		Rewards.CATEGORY_FORGE_FACE:
			return translate("CATEGORY_FORGE_FACE")
		Rewards.CATEGORY_RELIC:
			return translate("CATEGORY_RELIC")
		Rewards.CATEGORY_SLOT_SWAP:
			return translate("CATEGORY_SLOT_SWAP")
	return category


# --- Hjälpare för placeholder-grafik ---------------------------------------
## En ram i UI_GUIDE-stil. [param filled] fyller botten med [constant SURFACE_RAISED].
static func box(border: Color, filled: bool = true, width: float = STROKE_REG, radius: int = RADIUS_BUTTON) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = SURFACE_RAISED if filled else Color(0, 0, 0, 0)
	style.border_color = border
	if high_contrast:
		# §2.11: "alla ramar går upp till stroke/bold". Botten sköts av
		# tokenbytet (surface/raised → #0A0A0A) och ska inte dubbleras här.
		width = maxf(width, STROKE_BOLD)
	var w: int = int(round(dp(width)))
	style.border_width_left = w
	style.border_width_right = w
	style.border_width_top = w
	style.border_width_bottom = w
	var r: int = dpi(radius)
	style.corner_radius_top_left = r
	style.corner_radius_top_right = r
	style.corner_radius_bottom_left = r
	style.corner_radius_bottom_right = r
	return style
