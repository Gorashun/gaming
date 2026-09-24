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

## Konstrutans sida i dp.
const ART_DP: int = 44
## §3.3: EPIC är lila. Tills Tokens har en egen rad för den.
const EPIC_COLOR: Color = Color("#B06BFF")

var _art: Control = null
var _icon: TextureRect = null
var _die_art: DieArt = null
var _rarity_label: Label = null
var _name_label: Label = null
var _effect_label: Label = null


func _init() -> void:
	custom_minimum_size = Vector2(0.0, Tokens.dp(110))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_text = true
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

	# Relik-/föremålsikon, slot-ikon eller en ritad tärning med sidan,
	# beroende på belöningens kategori. M7: allt skalas fritt till rutan,
	# Linear + mipmaps – ingen pixelkonst kvar här.
	_art = Control.new()
	_art.name = "Art"
	_art.custom_minimum_size = Vector2(Tokens.dp(ART_DP), Tokens.dp(ART_DP))
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	row.add_child(_art)

	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.add_child(_icon)
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_die_art = DieArt.new()
	_die_art.name = "DieArt"
	_die_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_die_art.visible = false
	_art.add_child(_die_art)

	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_1))
	row.add_child(column)

	_rarity_label = _make_label(Tokens.TYPE_CAPTION, Tokens.CHALK_300)
	column.add_child(_rarity_label)
	_name_label = _make_label(Tokens.TYPE_BODY_L, Tokens.CHALK_100)
	# Namnraden [b]krymper i stället för att klippas[/b] (M5.8). Ett långt
	# kortnamn – "Scrapheap Anvil Blessing" – klipptes mitt i ordet i
	# korridorens belöning, där kortet ligger på sin minsta höjd och en extra
	# rad inte får plats. Se [method Tokens.shrink_to_fit].
	column.add_child(_name_label)
	Tokens.shrink_to_fit(_name_label, Tokens.TYPE_BODY_L)
	_effect_label = _make_label(Tokens.TYPE_BODY, Tokens.CHALK_300)
	_effect_label.clip_text = false
	_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_effect_label)

	pressed.connect(_on_pressed)


static func _make_label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", Tokens.dpi(font_size))
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func art_root() -> Control:
	return _art


## Fyller konstrutan: relikikon för en relik, komponerad tärningssida för en
## smidbar sida, slot-ikon för ett slot-byte. Hittas ingen textur lämnas rutan
## tom – kortet är ändå läsbart, texten bär hela beslutet.
func _bind_art() -> void:
	var data: Dictionary = option.get("data", {}) as Dictionary
	_icon.texture = null
	_icon.modulate = Color.WHITE
	_die_art.visible = false
	# Målad konst och krita: Linear + mipmaps. Nearest bara om en post faller
	# tillbaka på en gammal pixelsprite (Art.filter_for).
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	match String(option.get("category", "")):
		Rewards.CATEGORY_RELIC:
			var relic_id: String = String(data.get("relic_id", ""))
			_icon.texture = Art.relic_icon(relic_id)
			_art.texture_filter = Art.filter_for(StringName("relic." + relic_id))
		Rewards.CATEGORY_GEAR:
			# M6: föremålets ikon ur art-manifestet (gear.<ID> / relic.<ID>).
			var icon_id: String = String((data.get("item", {}) as Dictionary).get("icon_id", ""))
			_icon.texture = Art.gear_icon(icon_id)
			_art.texture_filter = Art.filter_for(StringName(icon_id)) if icon_id != "" \
				else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		Rewards.CATEGORY_SLOT_SWAP:
			var slot_type: int = int(data.get("slot_type", Rules.SlotType.PLAIN))
			_icon.texture = Art.slot_icon(slot_type)
			_icon.modulate = Tokens.slot_color(slot_type)
			_art.texture_filter = Art.filter_for(Art.slot_icon_key(slot_type))
		Rewards.CATEGORY_FORGE_FACE:
			var die: Die = Die.new("preview", [Content.make_face(String(data.get("face_id", "")))])
			_die_art.show_die(die, 0)
			_die_art.visible = _die_art.is_drawing()
	_icon.visible = _icon.texture != null


func bind(p_index: int, p_option: Dictionary, p_target: Dictionary, description: String) -> void:
	index = p_index
	option = p_option
	target = p_target
	var rarity: int = int(option.get("rarity", Rules.Rarity.COMMON))
	var style: Dictionary = Tokens.rarity_style(rarity)
	var color: Color = style["color"] as Color
	var rarity_text: String = Tokens.rarity_label(rarity)
	var category_text: String = Tokens.category_label(String(option.get("category", "")))
	# M6: Tokens känner ännu inte EPIC eller GEAR (dev A, docs/M6_B_NOTES.md §2).
	# Episkt är lila (PROGRESSION_REDESIGN §3.3); kategorin översätts här.
	if rarity >= Rules.Rarity.EPIC:
		color = EPIC_COLOR
		rarity_text = Tokens.translate_or("GEAR_RARITY_EPIC", "EPIC")
	if String(option.get("category", "")) == Rewards.CATEGORY_GEAR:
		category_text = Tokens.translate_or("GEAR_CATEGORY", "gear")

	_rarity_label.text = tr("REWARD_CARD_HEADER") % [
		String(style["mark"]),
		rarity_text,
		category_text,
	]
	_rarity_label.add_theme_color_override("font_color", color)
	_name_label.text = Tokens.translate_or(
		String(option.get("name_key", "")),
		String(option.get("name", option.get("id", ""))),
	)
	# Texten är ny, alltså är den uppmätta storleken det inte längre.
	Tokens.shrink_to_fit(_name_label, Tokens.TYPE_BODY_L)
	_effect_label.text = description
	_bind_art()

	var box: StyleBoxFlat = Tokens.box(color, true, Tokens.STROKE_BOLD, Tokens.RADIUS_CARD)
	box.bg_color = Tokens.SURFACE_RAISED
	add_theme_stylebox_override("normal", box)
	add_theme_stylebox_override("hover", box)
	var pressed_box: StyleBoxFlat = Tokens.box(color, true, Tokens.STROKE_HEAVY, Tokens.RADIUS_CARD)
	pressed_box.bg_color = Tokens.SURFACE_SLATE
	add_theme_stylebox_override("pressed", pressed_box)
	add_theme_stylebox_override("focus", box)


func _on_pressed() -> void:
	Juice.sfx(&"reward_pick", 1.0, -5.0)
	Juice.haptic(Haptics.Level.MEDIUM)
	Juice.pulse(self, 1.04, Tokens.MOTION_QUICK)
	chosen.emit(index)
