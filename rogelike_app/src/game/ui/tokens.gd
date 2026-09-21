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

## Läge "Hög kontrast+" (UI_GUIDE §6.3). Speglas hit av [code]Settings[/code].
##
## [b]M2-status:[/b] paletten i §6.3 (botten #000000, krita #FFFFFF, semantiska
## färger till max chroma) är inte levererad av UI-agenten än. Det som finns
## här är den del som inte kräver en ny palett: alla ramar går till
## [constant STROKE_BOLD] och panelbotten till [constant SURFACE_PIT], vilket
## höjer kontrasten mellan ram och yta utan att röra någon semantisk färg.
static var high_contrast: bool = false

# --- §2.1 Yta --------------------------------------------------------------
const SURFACE_PIT: Color = Color("#0E1216")
const SURFACE_SLATE: Color = Color("#161B21")
const SURFACE_RAISED: Color = Color("#1F262E")
const SURFACE_LINE: Color = Color("#2C353F")
const SURFACE_SCRIM: Color = Color(0.055, 0.071, 0.086, 0.72)

# --- §2.2 Krita och tärning ------------------------------------------------
const CHALK_100: Color = Color("#F2EDE3")
const CHALK_300: Color = Color("#CFC7B8")
const CHALK_500: Color = Color("#9A9486")
const BONE_DIE: Color = Color("#E8E0CF")
const BONE_PIP: Color = Color("#12161A")

# --- §2.3 Semantik ---------------------------------------------------------
const SEM_DAMAGE: Color = Color("#F2EDE3")
const SEM_FIRE: Color = Color("#FF6A2C")
const SEM_POISON: Color = Color("#B77FFF")
const SEM_FROST: Color = Color("#6ED2F5")
const SEM_HEAL: Color = Color("#4FE3A0")
const SEM_BLOOD: Color = Color("#FF556F")
const SEM_CHARGE: Color = Color("#FFD447")
const SEM_SHIELD: Color = Color("#D7DEE6")
## Överflödspilen, §4.4.
const SEM_OVERFLOW: Color = Color("#FF8A2C")

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
const SLOT_STYLE: Dictionary = {
	Rules.SlotType.PLAIN: {"key": "SLOT_PLAIN", "icon": "·", "color": CHALK_300, "border": "solid", "width": STROKE_REG},
	Rules.SlotType.FIRE: {"key": "SLOT_FIRE", "icon": "▲", "color": SEM_FIRE, "border": "solid", "width": STROKE_REG},
	Rules.SlotType.MIRROR: {"key": "SLOT_MIRROR", "icon": "❖", "color": SEM_FROST, "border": "double", "width": STROKE_REG},
	Rules.SlotType.ANVIL: {"key": "SLOT_ANVIL", "icon": "⬣", "color": SEM_SHIELD, "border": "thick", "width": STROKE_HEAVY},
	Rules.SlotType.CHARGE: {"key": "SLOT_CHARGE", "icon": "⬤", "color": SEM_CHARGE, "border": "dotted", "width": STROKE_REG},
	Rules.SlotType.VOID: {"key": "SLOT_VOID", "icon": "⬚", "color": Color("#8A94A6"), "border": "dashed", "width": STROKE_REG},
}


static func slot_style(slot_type: int) -> Dictionary:
	return SLOT_STYLE.get(slot_type, SLOT_STYLE[Rules.SlotType.PLAIN]) as Dictionary


static func slot_color(slot_type: int) -> Color:
	return slot_style(slot_type)["color"] as Color


static func slot_label(slot_type: int) -> String:
	return translate(String(slot_style(slot_type)["key"]))


static func slot_icon(slot_type: int) -> String:
	return String(slot_style(slot_type)["icon"])


# --- §2.5 Sällsynthet: färg + ramform + utskrivet ord ----------------------
const RARITY_STYLE: Dictionary = {
	Rules.Rarity.COMMON: {"key": "RARITY_COMMON", "mark": "▭", "color": CHALK_300},
	Rules.Rarity.UNCOMMON: {"key": "RARITY_UNCOMMON", "mark": "◣", "color": SEM_HEAL},
	Rules.Rarity.RARE: {"key": "RARITY_RARE", "mark": "▤", "color": SEM_FROST},
}


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
		return Color("#FF5CA8")
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
		# §6.3: "alla ramar till stroke/bold" och en mörkare botten, så att ram
		# mot yta separerar även i solljus.
		width = maxf(width, STROKE_BOLD)
		if filled:
			style.bg_color = SURFACE_PIT
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
