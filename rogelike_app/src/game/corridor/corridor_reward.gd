class_name CorridorReward
extends Control
## Belöningsvalet [b]i rummet du just vann[/b] (CORRIDOR_DESIGN §3.5), inte på en
## egen skärm.
##
## Tre kort ligger som ett altare över korridorbilden: korridoren syns kvar bakom
## dem, dimmad, så att valet hör ihop med platsen i stället för att vara en
## mellanskärm. Korten är samma [RewardCard] som M1:s belöningsskärm – samma ord,
## samma rarity-kodning, samma [method RewardApply.describe]-mening. Två
## formuleringar för samma belöning vore §B.1-problemet om igen.
##
## Ingen slump dras här: alternativen kommer färdiga från [GameController].

signal chosen(index: int, option: Dictionary, target: Dictionary)

## Kortets höjd i korridoren, i dp. Se kommentaren i [method show_options].
const CARD_HEIGHT_DP: int = 132

var _scrim: ColorRect = null
var _heading: Label = null
var _cards: VBoxContainer = null
var _options: Array[Dictionary] = []
var _targets: Array[Dictionary] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_scrim = ColorRect.new()
	_scrim.name = "Scrim"
	# Kritdammet: korridoren ska synas igenom, annars är det en skärm och inte
	# ett altare i rummet (§3.5).
	_scrim.color = Color(Tokens.SURFACE_PIT, 0.58)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scrim)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, Tokens.dpi(Tokens.SCREEN_MARGIN))
	# Toppmarginalen lämnar krit-raden (HP, rum, Pips) synlig: belöningen ligger i
	# rummet, och rummets HUD hör till rummet (§3.5).
	margin.add_theme_constant_override("margin_top",
		Tokens.dpi(CorridorHud.HUD_HEIGHT_DP + CorridorHud.TRAIL_HEIGHT_DP))
	margin.add_theme_constant_override("margin_bottom", Tokens.dpi(Tokens.SPACE_4))
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	# SHRINK_CENTER: korten behåller sin minsta höjd och korridoren syns kvar
	# över och under dem. Fyller de hela ytan är det en skärm, inte ett altare.
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_3))
	margin.add_child(column)

	_heading = Label.new()
	_heading.name = "Heading"
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# [b]Bryter rad, klipper inte[/b] (M5.8). Rubriken klipptes i båda kanterna
	# på en 480 px-skärm: 1080 viewport-enheter minus två 16 dp-marginaler är
	# 328 dp, och rubriken i TYPE_HEADING är bredare än så på svenska. Att klippa
	# en rubrik är värre än att sätta den på två rader.
	_heading.clip_text = false
	_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_heading.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_HEADING))
	_heading.add_theme_color_override("font_color", Tokens.CHALK_100)
	ChalkFx.apply(_heading, ChalkFx.DISPLAY)
	column.add_child(_heading)

	_cards = VBoxContainer.new()
	_cards.name = "Cards"
	_cards.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_cards.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_3))
	column.add_child(_cards)


## [param options] kommer ur [method Rewards.generate]. [param breather] tänder
## facklan-raden: läkningen får en synlig orsak i rummet (§3.5).
##
## [param title] är [code][nyckel, engelsk källsträng][/code] och skriver över
## rubriken; [param targets] är ett färdigt mål per kort. Båda är tomma i en
## vanlig run – de finns för källaren, där [Tutorial] äger både orden
## ("Loot. Pick one.") och vilken sida som får bytas ut (§B.2, M5.7).
func show_options(state: CombatState, options: Array, breather: bool,
		title: Array = [], targets: Array = []) -> void:
	_options.clear()
	_targets.clear()
	for child: Node in _cards.get_children():
		child.queue_free()

	var heading: String = Tokens.translate_or("CORRIDOR_REWARD_TITLE", "THE ROOM LEAVES SOMETHING")
	if breather:
		heading = Tokens.translate_or("CORRIDOR_REWARD_BREATHER",
			"TORCH FLARES · +%d HP") % Rules.BREATHER_HEAL
	if title.size() >= 2:
		heading = Tokens.translate_or(String(title[0]), String(title[1]))
	_heading.text = heading

	for raw: Variant in options:
		var option: Dictionary = raw as Dictionary
		var index: int = _options.size()
		var target: Dictionary = RewardApply.default_target(state, option)
		if index < targets.size() and not (targets[index] as Dictionary).is_empty():
			target = targets[index] as Dictionary
		var card: RewardCard = RewardCard.new()
		# Kortet är på sin minsta höjd här (till skillnad från M1:s belöningsskärm,
		# där det fick expandera), och en [Label] med autowrap rapporterar EN rads
		# höjd som minsta storlek. Utan de här extra dp:na klipps sista raden i
		# regeltexten – samma fälla som HelpLayer löste i M2.5.
		card.custom_minimum_size.y = Tokens.dp(CARD_HEIGHT_DP)
		_cards.add_child(card)
		card.bind(_options.size(), option, target, _describe(state, option, target))
		card.chosen.connect(_on_chosen)
		_options.append(option)
		_targets.append(target)
	visible = true


static func _describe(state: CombatState, option: Dictionary, target: Dictionary) -> String:
	var key: String = String(option.get("desc_key", ""))
	if key != "":
		return Tokens.translate_or(key, String(option.get("desc_en", option.get("name", ""))))
	return RewardApply.describe(state, option, target)


func option_count() -> int:
	return _options.size()


## Väljer utan indata. Rökprovet och testerna använder den.
func choose(index: int) -> void:
	_on_chosen(index)


func _on_chosen(index: int) -> void:
	if index < 0 or index >= _options.size():
		return
	visible = false
	chosen.emit(index, _options[index], _targets[index])


func close() -> void:
	visible = false
	for child: Node in _cards.get_children():
		child.queue_free()
	_options.clear()
	_targets.clear()
