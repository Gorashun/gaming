class_name GameScreen
extends Control
## Bas för alla skärmar. En skärm är ett [Control] som lever i
## [code]ChalkUI/UiRoot/ScreenRoot[/code] och som valfritt monterar en egen
## [Node2D] i [code]World/WorldRoot[/code].
##
## [b]Varför två lager:[/b] research 04 §5. Pixelsprites ska renderas med
## [code]Nearest[/code] i exakt heltalsskala, krit-UI:t med [code]Linear[/code]
## så att kurvor och fonter förblir mjuka. Den uppdelningen går inte att göra i
## efterhand utan att skriva om scenerna, därför finns den redan i M1 där allt
## världsinnehåll fortfarande är [Polygon2D]-platshållare.
##
## Kontrakt för UI-agenten: byt ut noderna i [member world_scene] mot
## [Sprite2D]/[AnimatedSprite2D] med samma namn och position, så följer UI-lagret
## med utan ändringar – det positionerar via [method world_anchor].

## Scenen som monteras i [code]World[/code]-lagret. Får vara null.
@export var world_scene: PackedScene

## Instansen av [member world_scene], eller null.
var world: Node2D = null

var controller: Node = null

## Skärmen är klar och vill lämna över. [param payload] tolkas av controllern.
signal screen_done(payload: Dictionary)


## Anropas av [GameController] direkt efter att skärmen lagts in i trädet.
func setup(p_controller: Node, world_root: Node2D, ctx: Dictionary) -> void:
	controller = p_controller
	if world_scene != null and world_root != null:
		world = world_scene.instantiate() as Node2D
		world_root.add_child(world)
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


## Städar bort världsinnehållet. Anropas av [GameController] före byte.
func teardown() -> void:
	exit()
	if world != null and is_instance_valid(world):
		world.queue_free()
		world = null


func exit() -> void:
	pass


## Positionen i World-lagret som motsvarar mitten av ett UI-element.
## Båda [CanvasLayer]-lagren delar samma 1080×1920-koordinatrymd, så en sprite
## placerad här hamnar exakt bakom sin kritpanel.
static func world_anchor(ui_node: Control) -> Vector2:
	if ui_node == null or not ui_node.is_inside_tree():
		return Vector2.ZERO
	return ui_node.get_global_rect().get_center()
