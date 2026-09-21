extends Node
## Spelarens inställningar. Autoload [code]Settings[/code].
##
## Sparas i [code]user://settings.cfg[/code] via [ConfigFile] – alltså [b]inte[/b]
## i sparfilen. Inställningar ska överleva att en run tar slut, att sparfilen
## nollställs och att spelet avinstalleras och installeras om med kvarvarande
## user://-katalog.
##
## [b]Kontrakt (samma som [SaveIO]):[/b] en trasig eller halvskriven fil får
## aldrig krascha spelet. [method load_settings] faller tillbaka på
## standardvärdena och skriver över filen vid nästa ändring.
##
## Tre av fälten är tillgänglighetskrav ur UI_GUIDE §6 och DECISIONS
## 2026-09-21 ("Reducerad rörelse-läge och färgblindspalett flyttas in hårt i
## M2"): [member reduced_motion], [member high_contrast] och [member haptics].
## [Juice] läser dem vid varje anrop, så ett byte slår igenom utan omstart.

const PATH: String = "user://settings.cfg"
const SECTION: String = "pipwreck"
## Spelets standardspråk. [b]Aldrig enhetens.[/b]
const DEFAULT_LOCALE: String = "en"

## Standardvärden.
##
## [b]DECISIONS 2026-09-21: [code]locale[/code] är "en", inte "".[/b] Godot
## väljer annars operativsystemets språk automatiskt, och Anders svenska telefon
## visade därför svenska utan att någon bett om det. Engelska är källspråket
## (CLAUDE.md) och ska vara standard oavsett enhet; svenska bara om spelaren
## själv väljer det i inställningarna.
##
## Tom sträng betyder fortfarande "rör inte språket" och är tillåten i filen –
## en äldre sparad inställning ska inte krascha – men den skrivs aldrig av oss.
const DEFAULTS: Dictionary = {
	"locale": DEFAULT_LOCALE,
	"sfx_volume": 80,
	"haptics": true,
	"reduced_motion": false,
	"high_contrast": false,
	"chain_speed": 1.0,
	"smith_variant": "",
}

## Någon inställning har ändrats. [param key] är fältnamnet.
signal changed(key: StringName)

## Går att peka om i tester. Rör aldrig i speldrift.
var config_path: String = PATH

## "en" / "sv". Tom sträng accepteras från en äldre fil och betyder "rör inte
## språket"; nya filer får alltid ett uttryckligt språk.
var locale: String = String(DEFAULTS["locale"])
## 0–100. 0 är helt tyst och spelet ska fortfarande gå att spela (UI_GUIDE §6.4:
## "all pitch-information dubbleras visuellt av multiplikator-badgen").
var sfx_volume: int = int(DEFAULTS["sfx_volume"])
var haptics: bool = bool(DEFAULTS["haptics"])
## UI_GUIDE §6.1. Ingen skak, halverad hit-stop, ingen overshoot i number pops.
var reduced_motion: bool = bool(DEFAULTS["reduced_motion"])
## UI_GUIDE §2.11 "Hög kontrast+". Byter hela tokentabellen i [Tokens];
## minsta kontrast i läget är 6,1:1 mot standardtemats 4,9:1.
var high_contrast: bool = bool(DEFAULTS["high_contrast"])
## Kedjetempo, UI_GUIDE §2.10: Lugn 1,25 · Normal 1,0 · Snabb 0,6 · Blixt 0,35.
var chain_speed: float = float(DEFAULTS["chain_speed"])
## Smedens kroppsvariant, "a" eller "b". Tom sträng = inte valt ännu, vilket är
## det som utlöser könsvalsskärmen vid första start (DECISIONS 2026-09-21).
## [b]Ligger här och inte i sparfilen[/b]: valet ska överleva att en run tar
## slut och att sparfilen nollställs.
var smith_variant: String = String(DEFAULTS["smith_variant"])


func _ready() -> void:
	load_settings()


# ---------------------------------------------------------------------------
# Läsa och skriva
# ---------------------------------------------------------------------------

## Läser filen. Saknas den, eller är den trasig, behålls standardvärdena.
## Returnerar true när en fil faktiskt lästes.
func load_settings() -> bool:
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load(config_path)
	# ConfigFile är förlåtande och svarar OK även på rader den inte begriper.
	# Saknas vår sektion är filen oanvändbar oavsett vad felkoden säger, och då
	# gäller standardvärdena – aldrig en halvläst inställningsuppsättning.
	if err != OK or not config.has_section(SECTION):
		reset_to_defaults(false)
		return false
	for key: String in DEFAULTS:
		var value: Variant = config.get_value(SECTION, key, DEFAULTS[key])
		_assign(key, value)
	apply()
	return true


func save_settings() -> bool:
	var config: ConfigFile = ConfigFile.new()
	for key: String in DEFAULTS:
		config.set_value(SECTION, key, get(key))
	var err: Error = config.save(config_path)
	if err != OK:
		push_warning("Settings: kunde inte skriva %s (%d)" % [config_path, err])
		return false
	return true


## Sätter ett fält, applicerar effekten och sparar. Enda vägen in från UI:t.
func set_value(key: StringName, value: Variant, persist: bool = true) -> void:
	if not DEFAULTS.has(String(key)):
		push_warning("Settings: okänd nyckel %s" % key)
		return
	_assign(String(key), value)
	apply()
	if persist:
		save_settings()
	changed.emit(key)


func reset_to_defaults(persist: bool = true) -> void:
	for key: String in DEFAULTS:
		_assign(key, DEFAULTS[key])
	apply()
	if persist:
		save_settings()
	changed.emit(&"all")


## Tvättar typerna. ConfigFile ger tillbaka Variant, och ett heltal som skrivits
## som float skulle annars smyga in i [member sfx_volume].
func _assign(key: String, value: Variant) -> void:
	match key:
		"locale":
			locale = String(value)
		"sfx_volume":
			sfx_volume = clampi(int(value), 0, 100)
		"haptics":
			haptics = bool(value)
		"reduced_motion":
			reduced_motion = bool(value)
		"high_contrast":
			high_contrast = bool(value)
		"chain_speed":
			chain_speed = clampf(float(value), 0.2, 2.0)
		"smith_variant":
			# "" är ett giltigt värde ("inte valt"); allt annat måste vara a/b.
			var raw: String = String(value)
			smith_variant = "" if raw == "" else Art.smith_variant(raw)


# ---------------------------------------------------------------------------
# Effekter
# ---------------------------------------------------------------------------

## Speglar inställningarna ut i motorn. Idempotent: kan köras hur ofta som helst.
func apply() -> void:
	# Alltid, inte "om satt": det är just tystnaden här som lät OS-språket
	# slå igenom. En tom sparad sträng tolkas som standardspråket.
	TranslationServer.set_locale(effective_locale())
	Haptics.enabled = haptics
	Tokens.apply_high_contrast(high_contrast)


## Språket som faktiskt ska gälla. Enda stället som känner till att en tom
## sträng betyder [constant DEFAULT_LOCALE].
func effective_locale() -> String:
	return DEFAULT_LOCALE if locale == "" else locale


## Volymen som en linjär faktor, 0–1. [Juice] översätter till dB.
func sfx_linear() -> float:
	return clampf(float(sfx_volume) / 100.0, 0.0, 1.0)


## Alla fält som en Dictionary. Används av tester och av felrapporter.
func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for key: String in DEFAULTS:
		out[key] = get(key)
	return out
