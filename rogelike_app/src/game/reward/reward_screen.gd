class_name RewardScreen
extends GameScreen
## Belöningsvalet efter ett vunnet rum. Ett av tre, GAME_DESIGN §4.7.
##
## Alternativen kommer färdigdragna från [GameController] via [Rewards.generate];
## skärmen drar ingen slump själv. Det är samma princip som i striden: allt som
## lottats är redan synligt när spelaren fattar sitt beslut (§6.4).
##
## Tapp på ett kort väljer det direkt (UI_GUIDE §3: "Tryck ett av tre kort").
## Det finns ingen bekräftelsedialog – ett tryck är ett beslut (designprincip 5).

@onready var _kicker: Label = $Margin/Column/Header/Kicker
@onready var _title: Label = $Margin/Column/Header/Title
@onready var _subtitle: Label = $Margin/Column/Header/Subtitle
@onready var _cards: VBoxContainer = $Margin/Column/Cards
@onready var _scale_strip: Label = $Margin/Column/ScaleStrip

var _options: Array[Dictionary] = []
var _targets: Array[Dictionary] = []
var _state: CombatState = null


func enter(ctx: Dictionary) -> void:
	_state = ctx.get("state", null) as CombatState
	var node: Dictionary = ctx.get("node", {}) as Dictionary
	for raw: Variant in ctx.get("options", []) as Array:
		_options.append(raw as Dictionary)

	_style()
	_kicker.text = tr("REWARD_KICKER") % [int(node.get("room", 1)), int(node.get("floor", 1))]
	_title.text = tr("REWARD_TITLE")
	var breather: String = ""
	if bool(ctx.get("breather", false)):
		breather = tr("REWARD_BREATHER") % Rules.BREATHER_HEAL
	_subtitle.text = tr("REWARD_SUBTITLE") % breather

	for i: int in range(_options.size()):
		var option: Dictionary = _options[i]
		var target: Dictionary = RewardApply.default_target(_state, option)
		_targets.append(target)
		var card: RewardCard = RewardCard.new()
		_cards.add_child(card)
		card.bind(i, option, target, RewardApply.describe(_state, option, target))
		card.chosen.connect(_on_chosen)

	if _options.is_empty():
		# Poolen är slut: hoppa vidare i stället för att visa en tom skärm.
		call_deferred("_skip")


func _style() -> void:
	$Background.color = Tokens.SURFACE_PIT
	for side: String in ["left", "right", "top", "bottom"]:
		$Margin.add_theme_constant_override("margin_" + side, Tokens.dpi(Tokens.SCREEN_MARGIN))
	$Margin/Column.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_3))
	$Margin/Column/Header.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))
	_cards.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_4))

	_label(_kicker, Tokens.TYPE_LABEL, Tokens.CHALK_500)
	_label(_title, Tokens.TYPE_TITLE, Tokens.CHALK_100)
	_label(_subtitle, Tokens.TYPE_BODY, Tokens.CHALK_300)
	_label(_scale_strip, Tokens.TYPE_CAPTION, Tokens.CHALK_500)
	_scale_strip.text = tr("REWARD_SCALE_STRIP")


static func _label(label: Label, font_size: int, color: Color) -> void:
	label.add_theme_font_size_override("font_size", Tokens.dpi(font_size))
	label.add_theme_color_override("font_color", color)
	# Samma regel som i striden: en etikett som inte radbryter måste klippas,
	# annars blir dess textbredd hela kolumnens minsta bredd.
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		label.clip_text = true


## Väljer ett alternativ. Publikt så att smoke-testet kan välja utan indata.
func choose(index: int) -> void:
	_on_chosen(index)


func option_count() -> int:
	return _options.size()


func _on_chosen(index: int) -> void:
	if index < 0 or index >= _options.size():
		return
	screen_done.emit({"choice": _options[index], "target": _targets[index]})


func _skip() -> void:
	screen_done.emit({})
