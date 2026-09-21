class_name RewardCard
extends Button
## Ett av tre belöningskort. UI_GUIDE §2.5 och wireframe_reward.html.
##
## Sällsynthet kodas med [b]färg + ramform + utskrivet ord[/b] (§6.2), aldrig
## med färg ensam. Kortet visar dessutom exakt vad valet gör – texten kommer
## från [method RewardApply.describe], inte från en egen formulering här, så att
## kortet och koden aldrig kan säga olika saker.

signal chosen(index: int)

var index: int = -1
var option: Dictionary = {}
var target: Dictionary = {}

var _art: Control = null
var _rarity_label: Label = null
var _name_label: Label = null
var _effect_label: Label = null


func _init() -> void:
	custom_minimum_size = Vector2(0.0, Tokens.dp(150))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_text = false
	add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_BODY))

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Tokens.dpi(Tokens.SPACE_4))
	add_child(margin)

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_4))
	margin.add_child(row)

	# Plats för relik-/sidsprite (Kenney 1-Bit enligt DECISIONS). Tom i M1.
	_art = Control.new()
	_art.name = "Art"
	_art.custom_minimum_size = Vector2(Tokens.dp(56), Tokens.dp(56))
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_art)

	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_1))
	row.add_child(column)

	_rarity_label = _make_label(Tokens.TYPE_LABEL, Tokens.CHALK_300)
	column.add_child(_rarity_label)
	_name_label = _make_label(Tokens.TYPE_HEADING, Tokens.CHALK_100)
	column.add_child(_name_label)
	_effect_label = _make_label(Tokens.TYPE_BODY_L, Tokens.CHALK_300)
	_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_effect_label)

	pressed.connect(_on_pressed)


static func _make_label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", Tokens.dpi(font_size))
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func art_root() -> Control:
	return _art


func bind(p_index: int, p_option: Dictionary, p_target: Dictionary, description: String) -> void:
	index = p_index
	option = p_option
	target = p_target
	var rarity: int = int(option.get("rarity", Rules.Rarity.COMMON))
	var style: Dictionary = Tokens.rarity_style(rarity)
	var color: Color = style["color"] as Color

	_rarity_label.text = "%s %s · %s" % [
		String(style["mark"]),
		String(style["name"]),
		Tokens.category_label(String(option.get("category", ""))),
	]
	_rarity_label.add_theme_color_override("font_color", color)
	_name_label.text = String(option.get("name", option.get("id", "")))
	_effect_label.text = description

	var box: StyleBoxFlat = Tokens.box(color, true, Tokens.STROKE_BOLD, Tokens.RADIUS_CARD)
	box.bg_color = Tokens.SURFACE_RAISED
	add_theme_stylebox_override("normal", box)
	add_theme_stylebox_override("hover", box)
	var pressed_box: StyleBoxFlat = Tokens.box(color, true, Tokens.STROKE_HEAVY, Tokens.RADIUS_CARD)
	pressed_box.bg_color = Tokens.SURFACE_SLATE
	add_theme_stylebox_override("pressed", pressed_box)
	add_theme_stylebox_override("focus", box)


func _on_pressed() -> void:
	Juice.sfx("reward_pick", 1.2)
	Juice.haptic(Haptics.Level.MEDIUM)
	Juice.pulse(self, 1.04, Tokens.MOTION_QUICK)
	chosen.emit(index)
