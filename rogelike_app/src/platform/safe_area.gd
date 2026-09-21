class_name SafeArea
extends RefCounted
## Skärmurtag och statusfält: hur långt ner HUD:en måste börja.
##
## Android-exporten kör i immersive mode (`screen/immersive_mode=true`,
## docs/ANDROID.md §3), men immersive gömmer bara system-barerna – det flyttar
## inte kameraurtaget. På en telefon med hålkamera ligger HP-raden annars under
## linsen.
##
## [b]Enheter är hela poängen här.[/b] Tre rymder är inblandade:
## [br]1. [i]Skärmpixlar[/i]: det [method DisplayServer.get_display_safe_area]
##    och [method DisplayServer.window_get_size] talar.
## [br]2. [i]Viewport-enheter[/i]: projektets 1080×1920-rymd, som allt UI ritas
##    i. Med `stretch/mode=canvas_items` och `aspect=expand` är skalan
##    `skärmbredd / 1080`, och en högre telefon får en HÖGRE viewport än 1920.
## [br]3. [i]dp[/i]: [method Tokens.dp] mellan design och viewport.
##
## Funktionerna nedan räknar 1 → 2. Den räkningen är en ren funktion av tre
## värden och testas därför utan en telefon ([code]tests/test_safe_area.gd[/code]).

## Tak för insetet i viewport-enheter. Ett orimligt värde (en emulator som
## rapporterar hela skärmen som osäker, en delad skärm) ska inte kunna trycka
## ner hela HUD:en utanför bild. 1920/8 = 240 är gott och väl över det värsta
## riktiga urtaget.
const MAX_INSET: float = 240.0


## Toppens inset i VIEWPORT-enheter, räknat ur rena värden.
##
## [param safe_area] och [param screen_size] är i skärmpixlar,
## [param viewport_size] i viewport-enheter. Returnerar 0 när något av
## värdena är nonsens – en saknad eller trasig rapport ska aldrig flytta UI:t.
static func top_inset_from(safe_area: Rect2i, screen_size: Vector2i, viewport_size: Vector2) -> float:
	if screen_size.y <= 0 or viewport_size.y <= 0.0:
		return 0.0
	if safe_area.size.x <= 0 or safe_area.size.y <= 0:
		return 0.0
	# Ett safe area som är större än skärmen är per definition fel; lita inte
	# på det. (Sedd på Android-emulatorer i delad skärm.)
	if safe_area.size.y > screen_size.y or safe_area.position.y < 0:
		return 0.0
	var scale: float = viewport_size.y / float(screen_size.y)
	return clampf(float(safe_area.position.y) * scale, 0.0, MAX_INSET)


## Samma sak, men frågar plattformen. Returnerar 0 på skrivbord och headless.
static func top_inset(viewport: Viewport) -> float:
	if viewport == null:
		return 0.0
	var screen_size: Vector2i = DisplayServer.window_get_size()
	var area: Rect2i = DisplayServer.get_display_safe_area()
	return top_inset_from(area, screen_size, viewport.get_visible_rect().size)


## Lägger insetet OVANPÅ [param base_px] på en [MarginContainer].
##
## Skärmarna sätter sin egen [code]margin_top[/code] i sin
## [code]_style()[/code]; den här funktionen körs efter det och adderar. Den är
## idempotent så länge [param base_px] är samma bastal varje gång.
static func apply_top_margin(margin: MarginContainer, base_px: int, inset: float) -> void:
	if margin == null:
		return
	margin.add_theme_constant_override("margin_top", base_px + int(round(maxf(0.0, inset))))
