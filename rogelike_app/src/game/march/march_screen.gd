class_name MarchScreen
extends GameScreen
## Marschen mellan rum. DECISIONS 2026-09-21: "nod-graf som datamodell,
## presenterad som sidescroll-marsch där figuren går åt höger och spelaren tappar
## vägval vid förgreningar. Fri gång avråds (joystick, kollisioner, bryter
## en-tumme)."
##
## Skärmen har därför exakt två lägen:
## [br]1. [b]En väg:[/b] figuren går, kameran rullar, spelaren gör ingenting och
##    rummet startar när marschen är klar.
## [br]2. [b]Förgrening:[/b] figuren stannar och två stora knappar visar vad som
##    väntar på respektive väg – fiendenamn och total HP, hämtat ur [Content],
##    inte gissat här. Tapp väljer.
##
## Ingen fri styrning, ingen joystick, inga kollisioner.

## Hur länge marschen tar innan valet visas.
const MARCH_SECONDS: float = 1.3

@onready var _heading: Label = $Margin/Column/Heading
@onready var _strip: Control = $Margin/Column/Strip
@onready var _prompt: Label = $Margin/Column/Prompt
@onready var _choices: VBoxContainer = $Margin/Column/Choices

var _graph: RunGraph = null
var _options: Array[String] = []
var _arrived: bool = false
var _elapsed: float = 0.0


func enter(ctx: Dictionary) -> void:
	_graph = ctx.get("graph", null) as RunGraph
	for value: Variant in ctx.get("options", []) as Array:
		_options.append(String(value))

	_style()
	var rooms_cleared: int = int(ctx.get("rooms_cleared", 0))
	_heading.text = tr("MARCH_HEADING") % [
		int(_graph.floor_index) if _graph != null else 1,
		rooms_cleared,
	]
	_prompt.text = tr("MARCH_WALKING")
	_choices.visible = false
	set_process(true)
	call_deferred("_build_world")


func _build_world() -> void:
	await get_tree().process_frame
	if world == null or not is_instance_valid(world):
		return
	var rect: Rect2 = _strip.get_global_rect()
	world.call("build", rect.get_center(), rect.size.x, rect.size.y)
	world.call("set_marching", true)


func _style() -> void:
	# Ingen egen bakgrund: marschens parallaxlager ligger i World-lagret under
	# krit-UI:t och måste synas igenom. Bakgrundsfärgen kommer från Backdrop i
	# main.tscn (CanvasLayer -10).
	for side: String in ["left", "right", "top", "bottom"]:
		$Margin.add_theme_constant_override("margin_" + side, Tokens.dpi(Tokens.SCREEN_MARGIN))
	$Margin/Column.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_6))
	_choices.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_4))
	_heading.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_HEADING))
	_heading.add_theme_color_override("font_color", Tokens.CHALK_100)
	_heading.clip_text = true
	_prompt.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_BODY_L))
	_prompt.add_theme_color_override("font_color", Tokens.CHALK_300)
	_prompt.clip_text = true


func _process(delta: float) -> void:
	if _arrived:
		return
	_elapsed += delta
	if _elapsed >= MARCH_SECONDS:
		arrive()


## Avslutar marschen omedelbart. Publik för smoke-testet.
func arrive() -> void:
	if _arrived:
		return
	_arrived = true
	set_process(false)
	if world != null and is_instance_valid(world):
		world.call("set_marching", false)
	Juice.sfx("march_arrive", 1.0)

	if _options.size() <= 1:
		choose(0)
		return
	_prompt.text = tr("MARCH_SPLIT")
	_choices.visible = true
	for i: int in range(_options.size()):
		_choices.add_child(_make_choice_button(i, _options[i]))


func _make_choice_button(index: int, node_id: String) -> Button:
	var node: Dictionary = _graph.node_at(node_id)
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(0.0, Tokens.dp(96))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.clip_text = true
	button.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_BODY_L))
	button.add_theme_color_override("font_color", Tokens.CHALK_100)
	button.add_theme_color_override("font_hover_color", Tokens.CHALK_100)
	button.add_theme_color_override("font_pressed_color", Tokens.CHALK_100)
	var accent: Color = Tokens.SEM_FIRE if RunFlow.is_boss(node) else Tokens.SEM_FROST
	var style: StyleBoxFlat = Tokens.box(accent, true, Tokens.STROKE_BOLD, Tokens.RADIUS_CARD)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", style)
	button.text = "%s  %s\n%s" % [node_icon(node), node_title(node), preview_text(node)]
	button.pressed.connect(choose.bind(index))
	return button


## Ikonen för en nodtyp. Blir en 32×32-sprite ur Kenney 1-Bit i M2
## (research 04 §6: COMBAT, ELITE, FORGE, REST, BOSS, MYSTERY).
static func node_icon(node: Dictionary) -> String:
	return "☠" if RunFlow.is_boss(node) else "⚔"


static func node_title(node: Dictionary) -> String:
	if RunFlow.is_boss(node):
		return Tokens.translate("MARCH_NODE_BOSS") % int(node.get("room", 1))
	return Tokens.translate("MARCH_NODE_COMBAT") % int(node.get("room", 1))


## Vad som väntar på vägen. Läses ur [Content] så att kortet och mötet aldrig
## kan säga olika saker.
static func preview_text(node: Dictionary) -> String:
	var enemies: Array[Enemy] = Content.encounter(int(node.get("room_in_floor", 1)), int(node.get("variant", 0)))
	var names: PackedStringArray = PackedStringArray()
	var total_hp: int = 0
	for enemy: Enemy in enemies:
		names.append(Tokens.translate_or(Content.enemy_key(enemy.id), enemy.display_name))
		total_hp += enemy.max_hp
	return Tokens.translate("MARCH_PREVIEW") % [", ".join(names), total_hp]


## Väljer väg. Publik så att smoke-testet kan gå vidare utan indata.
func choose(index: int) -> void:
	if index < 0 or index >= _options.size():
		return
	Juice.sfx("march_choose", 1.2)
	Juice.haptic(Haptics.Level.MEDIUM)
	screen_done.emit({"node_id": _options[index]})


func option_count() -> int:
	return _options.size()


func has_arrived() -> bool:
	return _arrived
