class_name GameScreen
extends Control
## Bas för alla skärmar. En skärm är ett [Control] som lever i
## [code]ChalkUI/UiRoot/ScreenRoot[/code].
##
## [b]M5.5: det separata World-lagret är borta.[/b] Det bar M1:s platta
## 2D-sidovy för striden – parallaxband, golv, hjältefigur och
## [code]EnemyActor[/code]-sprajtar. Från och med korridoren finns exakt EN
## stridspresentation: varelserna är billboards i korridorens [SubViewport] och
## figuren syns bara i character sheetet. Pixelreglerna ur research 04 §5
## (Nearest, heltalsskala) gäller oförändrat och ägs av [Art].
##
## [param world_root] i [method setup] står kvar som null av bakåtkompatibilitet
## mot rökprovet och testerna; ingen skärm använder den längre.

var controller: Node = null

## Skärmen är klar och vill lämna över. [param payload] tolkas av controllern.
signal screen_done(payload: Dictionary)


## Anropas av [GameController] direkt efter att skärmen lagts in i trädet.
func setup(p_controller: Node, _world_root: Node2D, ctx: Dictionary) -> void:
	controller = p_controller
	enter(ctx)
	apply_safe_area()


## Skjuter ner skärmens toppmarginal förbi kameraurtaget (M4, docs/ANDROID.md
## §6). Körs EFTER [method enter], därför att varje skärm sätter sin egen
## [code]margin_top[/code] i sin [code]_style()[/code] och skulle skriva över
## insetet om det lades på före.
##
## Alla fem skärmar har en [MarginContainer] som heter [code]Margin[/code].
## Saknas den händer ingenting; det är inte ett fel, bara en skärm utan
## toppinnehåll.
func apply_safe_area() -> void:
	var margin: MarginContainer = get_node_or_null(^"Margin") as MarginContainer
	if margin == null:
		return
	# Bastalet sparas i metadata första gången. Utan det skulle ett andra anrop
	# addera insetet ovanpå ett redan justerat värde.
	if not margin.has_meta(&"safe_area_base"):
		margin.set_meta(&"safe_area_base", margin.get_theme_constant(&"margin_top"))
	var base: int = int(margin.get_meta(&"safe_area_base"))
	SafeArea.apply_top_margin(margin, base, SafeArea.top_inset(get_viewport()))


## Skärmspecifik uppstart. Överskugga denna, inte [method setup].
func enter(_ctx: Dictionary) -> void:
	pass


## Anropas av [GameController] före skärmbytet.
func teardown() -> void:
	exit()


func exit() -> void:
	pass

