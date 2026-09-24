class_name CharacterSheet
extends Control
## Character sheetet (CORRIDOR_DESIGN §4), [b]v2 i M6[/b].
##
## [b]Hjälten syns aldrig i korridoren. Den finns här, och bara här.[/b] Sheetet
## är en [b]modal[/b], precis som inställningarna: att byta skärm mitt i en run
## skulle kasta bort kamerans plats i rutnätet och stridens placering.
##
## [b]M6:[/b] paperdoll-figuren är ersatt av ett [b]målat porträtt[/b] ur
## art-manifestet ([code]hero.portrait.a/b[/code]), och de sju slotsen bär
## föremålets ikon ([code]gear.<id>[/code]) i sin raritetsram
## ([code]rarity.frame.<namn>[/code]). Allt går via [Art]; byte = byt fil.
##
## Uppifrån och ner:
## [br]1. Namn, stad · run, HP-linje, Pips, stäng-kryss.
## [br]2. Porträttet i mitten med sju slots runt om: fyra till vänster, tre till
##    höger och "CHANGE LOOK" under. En tom slot visar slotens egen ikon nedtonad;
##    en låst slot (hjältens nivå) säger vilken nivå som låser upp den.
## [br]3. Slotordningen – smedjans enda verktyg. [b]Aktiv bara i staden.[/b]
## [br]4. De sex tärningarna. Tapp fäller ut alla sidorna med värde och effekt.
## [br]5. Reliker, detaljraden och "GO DOWN" (bara i staden).
##
## [b]Gränssnittet mot gear[/b] (docs/M6_A_NOTES.md): ctx får bära
## [code]"hero": Hero[/code]. Sheetet läser då [code]hero.equipped(slot) -> Item|null[/code],
## [code]item.icon_id[/code], [code]item.rarity[/code], [code]item.name_key[/code] /
## [code]display_name[/code], [code]item.effect_summary_key[/code] och
## [code]hero.is_slot_unlocked(slot)[/code]. Utan hjälte läses relikerna som i M5
## ([constant Content.RELIC_SLOTS]). Sheetet äger ingen regel.

signal closed()
## [code]GO DOWN[/code] i staden. Samma tapp som stadens egen knapp.
signal go_down_pressed(seed_value: int)
## "CHANGE LOOK" bytte porträtt. [Settings] är redan skriven; har sheetet en
## hjälte är [member Hero.body_variant] också ändrad och controllern ska spara
## metan (docs/M6_A_NOTES.md).
signal look_changed(variant: String)

## Porträttets minsta höjd i dp. Det tar över paperdollens plats (§4.1: "~52 %
## av höjden").
const PORTRAIT_MIN_DP: int = 200
## Samma 52 dp som M5: fyra slots i höjd måste rymmas i paperdollens gamla
## höjdbudget, annars trycks GO DOWN ut under skärmkanten.
const SLOT_BOX_DP: int = 52
## Ikonen sitter innanför raritetsramens kant.
const ICON_INSET: float = 0.17
## En tom slots egen ikon, nedtonad. M7: ikonen är mono-krita
## ([code]ui.gearslot.*[/code]) tintad i chalk/300, inte en färgikon, och tål
## därför mer opacitet än M6:s 0,22 utan att se ut som ett föremål.
const EMPTY_GLYPH_ALPHA: float = 0.42
## Hur länge ett nytt föremål blixtrar i sin slot (§4.3).
const HIGHLIGHT_MS: int = 520
## Ny nyckel i M6; raden väntar i CSV:n (docs/M6_A_NOTES.md). Som konstant så
## att en saknad rad visar engelska i stället för att fälla i18n-testet innan
## asset-agenten lagt in den.
const KEY_LOCKED: String = "CHARSHEET_LOCKED_LV"

var state: CombatState = null
var meta: Meta = null
var in_town: bool = false

var _seed_value: int = 0
var _room: int = 0
var _hero: Hero = null
var _portrait_box: Control = null
var _slot_buttons: Dictionary = {}
var _detail: Label = null
var _dice_row: HBoxContainer = null
var _relic_row: HBoxContainer = null
var _order_row: HBoxContainer = null
var _hp_label: Label = null
var _hp_bar: ProgressBar = null
var _pips_label: Label = null
var _title: Label = null
var _subtitle: Label = null
var _portrait: TextureRect = null
var _go_down: Button = null
var _change_look: Button = null
var _materials_label: Label = null
var _open_die: int = -1

## Tärningsmaterialens etiketter. Tre rader i CSV:n i stället för en funktion i
## [Rules]: materialet är presentation här, inte en regel.
const MATERIAL_KEYS: Dictionary = {
	Rules.DieMaterial.IRON: ["DIE_MATERIAL_IRON", "Iron"],
	Rules.DieMaterial.BONE: ["DIE_MATERIAL_BONE", "Bone"],
	Rules.DieMaterial.GLASS: ["DIE_MATERIAL_GLASS", "Glass"],
}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_style()


## Fyller sheetet. [param ctx] är
## [code]{state, meta, in_town, room, seed, highlight}[/code].
func open_for(ctx: Dictionary) -> void:
	state = ctx.get("state", null) as CombatState
	meta = ctx.get("meta", null) as Meta
	if meta == null:
		meta = Meta.fresh()
	in_town = bool(ctx.get("in_town", false))
	_hero = ctx.get("hero", null) as Hero
	_room = int(ctx.get("room", 0))
	_seed_value = int(ctx.get("seed", 0))
	refresh()
	var highlight: String = String(ctx.get("highlight", ""))
	if highlight != "":
		call_deferred("_play_highlight", highlight)


func _style() -> void:
	var background: ColorRect = ColorRect.new()
	background.name = "Background"
	background.color = Tokens.SURFACE_PIT
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, Tokens.dpi(Tokens.SCREEN_MARGIN))
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Tokens.dpi(Tokens.SPACE_3))
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))
	margin.add_child(column)

	column.add_child(_build_header())
	column.add_child(_build_body())
	column.add_child(_build_footer())


# --- Toppraden --------------------------------------------------------------

func _build_header() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Header"
	row.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_3))

	var names: VBoxContainer = VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 0)
	row.add_child(names)

	_title = _label(Tokens.TYPE_TITLE, Tokens.CHALK_100)
	Tokens.apply_display_font(_title)
	names.add_child(_title)

	_subtitle = _label(Tokens.TYPE_LABEL, Tokens.CHALK_500)
	var scrawl: Font = Tokens.font_scrawl()
	if scrawl != null:
		_subtitle.add_theme_font_override("font", scrawl)
	names.add_child(_subtitle)

	var vitals: HBoxContainer = HBoxContainer.new()
	vitals.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))
	names.add_child(vitals)

	_hp_label = _label(Tokens.TYPE_BODY, Tokens.SEM_BLOOD)
	_hp_label.clip_text = false
	vitals.add_child(_hp_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(Tokens.dp(64), Tokens.dp(4))
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track: StyleBoxFlat = Tokens.box(Tokens.SURFACE_LINE, true, 0.0, 0)
	track.bg_color = Color(0.09, 0.11, 0.13)
	var fill: StyleBoxFlat = Tokens.box(Tokens.SEM_BLOOD, true, 0.0, 0)
	fill.bg_color = Tokens.SEM_BLOOD
	_hp_bar.add_theme_stylebox_override("background", track)
	_hp_bar.add_theme_stylebox_override("fill", fill)
	vitals.add_child(_hp_bar)

	_pips_label = _label(Tokens.TYPE_BODY, Tokens.SEM_CHARGE)
	_pips_label.clip_text = false
	vitals.add_child(_pips_label)

	var close: Button = Button.new()
	close.name = "CloseButton"
	close.text = "✕"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(Tokens.dp(Tokens.TOUCH_MIN), Tokens.dp(Tokens.TOUCH_MIN))
	close.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_HEADING))
	close.add_theme_color_override("font_color", Tokens.CHALK_300)
	var close_style: StyleBoxFlat = CorridorHud.hud_button_style(Tokens.SURFACE_LINE)
	for state_name: String in ["normal", "hover", "pressed", "focus"]:
		close.add_theme_stylebox_override(state_name, close_style)
	close.pressed.connect(close_sheet)
	row.add_child(close)
	return row


# --- Porträttet och de sju slotsen -----------------------------------------

func _build_body() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Body"
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))

	var left: VBoxContainer = _slot_column("LeftSlots", Content.SHEET_SLOTS.slice(0, 4))
	row.add_child(left)

	_portrait_box = Control.new()
	_portrait_box.name = "Figure"
	_portrait_box.custom_minimum_size = Vector2(0.0, Tokens.dp(PORTRAIT_MIN_DP))
	_portrait_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_portrait_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_portrait_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_portrait_box)

	# Ett varmt sken bakom porträttet: samma fackla som i korridoren, så att
	# hjälten står i samma ljus som resten av spelet (ART_DIRECTION_V2 §4).
	var glow: ColorRect = ColorRect.new()
	glow.name = "Glow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow_mat: ShaderMaterial = ShaderMaterial.new()
	glow_mat.shader = load(CorridorView.VIGNETTE_SHADER) as Shader
	glow_mat.set_shader_parameter(&"void_color", Tokens.SURFACE_PIT)
	glow_mat.set_shader_parameter(&"vignette", 0.9)
	glow_mat.set_shader_parameter(&"inner", 0.35)
	glow_mat.set_shader_parameter(&"outer", 1.0)
	glow_mat.set_shader_parameter(&"top_dark", 0.0)
	glow_mat.set_shader_parameter(&"bottom_dark", 0.0)
	glow_mat.set_shader_parameter(&"glow_center", Vector2(0.55, 0.72))
	# Skenet måste ta slut innanför rutan, annars syns rutans kant.
	glow_mat.set_shader_parameter(&"glow_radius", Vector2(0.45, 0.3))
	glow_mat.set_shader_parameter(&"glow_strength", 0.28)
	# Inget korn och ingen kall ton här: rutan får inte synas som en rektangel
	# mot sheetets platta botten.
	glow_mat.set_shader_parameter(&"grain", 0.0)
	glow_mat.set_shader_parameter(&"cool_strength", 0.0)
	glow.material = glow_mat
	_portrait_box.add_child(glow)
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_box.add_child(_portrait)
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var inset: float = Tokens.dp(Tokens.SPACE_2)
	_portrait.offset_left = inset
	_portrait.offset_right = -inset
	_portrait.offset_top = inset
	_portrait.offset_bottom = -inset

	var right: VBoxContainer = _slot_column("RightSlots", Content.SHEET_SLOTS.slice(4))
	_change_look = Button.new()
	_change_look.name = "ChangeLook"
	_change_look.text = Tokens.translate_or("CHARSHEET_LOOK", "LOOK")
	_change_look.clip_text = true
	_change_look.focus_mode = Control.FOCUS_NONE
	_change_look.custom_minimum_size = Vector2(Tokens.dp(SLOT_BOX_DP), Tokens.dp(SLOT_BOX_DP))
	_change_look.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_CAPTION))
	_change_look.add_theme_color_override("font_color", Tokens.SEM_CHARGE)
	_change_look.add_theme_color_override("font_disabled_color", Tokens.CHALK_500)
	var look_style: StyleBoxFlat = Tokens.box(Tokens.SEM_CHARGE, true, Tokens.STROKE_REG, Tokens.RADIUS_BUTTON)
	look_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	for state_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		_change_look.add_theme_stylebox_override(state_name, look_style)
	_change_look.pressed.connect(change_look)
	right.add_child(_change_look)
	row.add_child(right)
	return row


func _slot_column(column_name: String, slots: Array) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.name = column_name
	column.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	for raw: Variant in slots:
		var slot: String = String(raw)
		var button: Button = _make_slot_button(slot)
		column.add_child(button)
		_slot_buttons[slot] = button
	return column


## En slot: raritetsram, föremålets ikon och slotens namn under. En tom slot
## visar slotens egen ikon nedtonad, inte en grå ruta (§4.1 punkt 3).
func _make_slot_button(slot: String) -> Button:
	var button: Button = Button.new()
	button.name = "Slot%s" % slot
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(Tokens.dp(SLOT_BOX_DP), Tokens.dp(SLOT_BOX_DP))
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for state_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state_name, empty)
	button.pressed.connect(_on_slot_pressed.bind(slot))

	var box: Control = Control.new()
	box.name = "Box"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var plate: Panel = Panel.new()
	plate.name = "Plate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(plate)
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var icon: TextureRect = TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(icon)
	# Ikonen i ramens övre del; slotens namn står i den nedre, innanför ramen.
	icon.anchor_left = ICON_INSET
	icon.anchor_top = ICON_INSET * 0.6
	icon.anchor_right = 1.0 - ICON_INSET
	icon.anchor_bottom = 0.74

	var frame: TextureRect = TextureRect.new()
	frame.name = "Frame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	box.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var caption: Label = _label(Tokens.TYPE_CAPTION - 2, Tokens.CHALK_500)
	caption.name = "Caption"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_child(caption)
	caption.anchor_top = 1.0
	caption.anchor_right = 1.0
	caption.anchor_bottom = 1.0
	caption.offset_top = -Tokens.dp(15)
	caption.offset_bottom = -Tokens.dp(2)
	return button


# --- Botten ------------------------------------------------------------------

func _build_footer() -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Footer"
	column.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))

	var order_header: HBoxContainer = HBoxContainer.new()
	order_header.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))
	column.add_child(order_header)
	var order_title: Label = _label(Tokens.TYPE_LABEL, Tokens.CHALK_500)
	order_title.text = Tokens.translate_or("FORGE_TAB_SLOTS", "SLOT ORDER")
	order_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	order_header.add_child(order_title)
	var order_note: Label = _label(Tokens.TYPE_CAPTION, Tokens.CHALK_500)
	order_note.name = "OrderNote"
	order_note.text = Tokens.translate_or("FORGE_NO_ADD", "The forge never adds power. It moves it.")
	order_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	order_header.add_child(order_note)

	_order_row = HBoxContainer.new()
	_order_row.name = "SlotOrder"
	_order_row.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_1))
	column.add_child(_order_row)

	var dice_header: HBoxContainer = HBoxContainer.new()
	dice_header.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))
	column.add_child(dice_header)
	var dice_title: Label = _label(Tokens.TYPE_LABEL, Tokens.CHALK_500)
	dice_title.text = Tokens.translate_or("SMITH_SHEET_DICE", "YOUR SIX DICE")
	dice_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dice_header.add_child(dice_title)
	_materials_label = _label(Tokens.TYPE_CAPTION, Tokens.CHALK_500)
	_materials_label.name = "Materials"
	_materials_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dice_header.add_child(_materials_label)

	_dice_row = HBoxContainer.new()
	_dice_row.name = "Dice"
	_dice_row.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_1))
	column.add_child(_dice_row)

	_relic_row = HBoxContainer.new()
	_relic_row.name = "Relics"
	_relic_row.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))
	column.add_child(_relic_row)

	_detail = _label(Tokens.TYPE_CAPTION, Tokens.CHALK_300)
	_detail.name = "Detail"
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.clip_text = false
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_detail)

	_go_down = Button.new()
	_go_down.name = "GoDownButton"
	_go_down.text = Tokens.translate_or("TOWN_GO_DOWN", "GO DOWN")
	_go_down.clip_text = true
	_go_down.focus_mode = Control.FOCUS_NONE
	_go_down.custom_minimum_size = Vector2(0.0, Tokens.dp(Tokens.BUTTON_PRIMARY_HEIGHT))
	_go_down.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_TITLE))
	var primary: StyleBoxFlat = Tokens.box(Tokens.CHALK_100, true, Tokens.STROKE_REG)
	primary.bg_color = Tokens.SEM_CHARGE
	for state_name: String in ["normal", "hover", "pressed", "focus"]:
		_go_down.add_theme_stylebox_override(state_name, primary)
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		_go_down.add_theme_color_override(color_name, Tokens.SURFACE_PIT)
	ChalkFx.apply(_go_down, ChalkFx.BUTTON)
	_go_down.pressed.connect(_on_go_down)
	column.add_child(_go_down)
	return column


# ---------------------------------------------------------------------------
# Innehåll
# ---------------------------------------------------------------------------

func refresh() -> void:
	var variant: String = look()
	_portrait.texture = Art.smith_portrait(variant)
	_portrait.texture_filter = Art.filter_for(Art.portrait_key(variant))
	_title.text = _hero.name if _hero != null and _hero.name != "" \
		else Tokens.translate_or("SMITH_SHEET_TITLE", "THE SMITH")
	_subtitle.text = Tokens.translate_or("CHARSHEET_SUBTITLE", "%s · run %d") % [
		Tokens.translate_or("TOWN_NAME", "CHALKRIM"), maxi(meta.runs, 1)]
	var hp: int = state.player_hp if state != null else 0
	var max_hp: int = state.player_max_hp if state != null else 0
	_hp_label.text = Tokens.translate_or("SMITH_HP", "%d / %d HP") % [hp, max_hp]
	_hp_bar.max_value = maxi(max_hp, 1)
	_hp_bar.value = clampi(hp, 0, maxi(max_hp, 1))
	_pips_label.text = "◉ %d" % meta.pips
	_detail.text = Tokens.translate_or("SMITH_SHEET_HINT", "Tap a slot to read what it does.")

	_go_down.visible = in_town
	_change_look.disabled = not in_town
	_refresh_slots()
	_refresh_order()
	_refresh_dice()
	_refresh_relics()


## Porträttets kroppsvariant: hjältens om sheetet har en, annars [Settings].
func look() -> String:
	if _hero != null:
		return Art.smith_variant(_hero.body_variant)
	return Art.smith_variant(Settings.smith_variant)


## Vad som bärs i [param slot], som en vy: [code]{kind, icon, rarity, name,
## locked, unlock_level, item, relic}[/code]. [b]Enda stället som frågar
## hjälten eller relikerna[/b] – resten av sheetet ritar bara vyn.
func slot_view(slot: String) -> Dictionary:
	var view: Dictionary = {"kind": "empty", "icon": null, "rarity": Rules.Rarity.COMMON,
		"name": "", "locked": false, "unlock_level": 0, "item": null, "relic": null}
	if _hero != null:
		if not _hero.is_slot_unlocked(slot):
			view["locked"] = true
			view["unlock_level"] = Hero.level_for_slot(slot)
			return view
		var item: Item = _hero.equipped(slot)
		if item != null:
			view["kind"] = "gear"
			view["item"] = item
			view["icon"] = Art.gear_icon(item.icon_id if item.icon_id != "" else item.id)
			view["rarity"] = item.rarity
			view["name"] = Tokens.translate_or(item.name_key, item.display_name) \
				if item.name_key != "" else item.display_name
			return view
	if state != null:
		for relic: Relic in state.relics:
			if Content.relic_slot(relic.id) == slot:
				view["kind"] = "relic"
				view["relic"] = relic
				view["icon"] = Art.relic_icon(relic.id)
				view["rarity"] = relic.rarity
				view["name"] = Tokens.translate_or(Content.relic_key(relic.id), relic.display_name)
				return view
	return view


func _refresh_slots() -> void:
	for raw: Variant in Content.SHEET_SLOTS:
		var slot: String = String(raw)
		var button: Button = _slot_buttons[slot] as Button
		_paint_slot(button, slot, slot_view(slot))


func _paint_slot(button: Button, slot: String, view: Dictionary) -> void:
	var icon: TextureRect = button.get_node("Box/Icon") as TextureRect
	var frame: TextureRect = button.get_node("Box/Frame") as TextureRect
	var plate: Panel = button.get_node("Box/Plate") as Panel
	var caption: Label = button.get_node("Caption") as Label
	var kind: String = String(view["kind"])
	var filled: bool = kind != "empty"
	var rarity: int = int(view["rarity"])
	var rarity_name: String = Rules.rarity_name(rarity)

	caption.text = Tokens.translate_or(Content.sheet_slot_key(slot), slot)
	caption.add_theme_color_override("font_color", Tokens.CHALK_100 if filled else Tokens.CHALK_500)
	button.tooltip_text = String(view["name"])

	if filled:
		icon.texture = view["icon"] as Texture2D
		icon.modulate = Color.WHITE
	else:
		# Slotens egen ikon, nedtonad: formen säger vad som hör hemma här.
		icon.texture = Art.gearslot_icon(slot)
		icon.modulate = Color(Tokens.CHALK_300, EMPTY_GLYPH_ALPHA * (0.5 if bool(view["locked"]) else 1.0))
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if kind == "relic":
		icon.texture_filter = Art.filter_for(StringName("relic." + (view["relic"] as Relic).id))

	var ring: Color = Tokens.rarity_color(rarity) if filled else Tokens.SURFACE_LINE
	frame.texture = Art.rarity_frame(rarity_name) if filled else null
	var style: StyleBoxFlat = Tokens.box(ring, true,
		Tokens.STROKE_HAIR if frame.texture != null or not filled else Tokens.STROKE_REG, Tokens.RADIUS_BUTTON)
	style.bg_color = Color(0.0, 0.0, 0.0, 0.35) if filled else Color(0.0, 0.0, 0.0, 0.0)
	if frame.texture != null:
		style.border_width_left = 0
		style.border_width_right = 0
		style.border_width_top = 0
		style.border_width_bottom = 0
	plate.add_theme_stylebox_override("panel", style)

	if bool(view["locked"]):
		caption.text = Tokens.translate_or(KEY_LOCKED, "LV %d") % int(view["unlock_level"])


## Smedjans enda verktyg. [b]Aktivt bara i staden[/b] (§4.1, DECISIONS: smedjan
## byter och ordnar om mellan runs, aldrig under dem).
func _refresh_order() -> void:
	for child: Node in _order_row.get_children():
		child.queue_free()
	var order: PackedInt32Array = _slot_order()
	var board: Board = Forge.reorder_slots(Board.smith_board(), order)
	for i: int in range(board.slots.size()):
		var cell: VBoxContainer = VBoxContainer.new()
		cell.name = "Order%d" % i
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 0)
		_order_row.add_child(cell)
		var name_label: Label = _label(Tokens.TYPE_CAPTION - 1, Tokens.slot_color(board.slots[i].type))
		name_label.text = Tokens.slot_label(board.slots[i].type)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(name_label)
		var move: Button = Button.new()
		move.name = "Move%d" % i
		move.text = "→"
		move.focus_mode = Control.FOCUS_NONE
		move.disabled = not in_town or i >= board.slots.size() - 1
		move.custom_minimum_size = Vector2(0.0, Tokens.dp(Tokens.TOUCH_MIN - 12))
		move.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_LABEL))
		move.add_theme_color_override("font_color", Tokens.CHALK_100)
		move.add_theme_color_override("font_disabled_color", Tokens.CHALK_500)
		var style: StyleBoxFlat = Tokens.box(Tokens.SURFACE_LINE, true, Tokens.STROKE_HAIR)
		for state_name: String in ["normal", "hover", "pressed", "disabled"]:
			move.add_theme_stylebox_override(state_name, style)
		move.pressed.connect(move_slot.bind(i))
		cell.add_child(move)


func _slot_order() -> PackedInt32Array:
	var raw: Array = meta.loadout.get(Forge.KEY_SLOT_ORDER, []) as Array
	var order: PackedInt32Array = PackedInt32Array()
	for value: Variant in raw:
		order.append(int(value))
	if not Forge.is_permutation(order, Rules.SLOT_COUNT):
		order = Forge.identity_order(Rules.SLOT_COUNT)
	return order


## Flyttar en slot ett steg åt höger. [Forge] tar en PERMUTATION: är den inte
## det returneras brädet oförändrat, så en trasig sparfil kan inte duplicera
## en AMBOSS.
func move_slot(index: int) -> void:
	if not in_town:
		return
	meta.loadout[Forge.KEY_SLOT_ORDER] = Array(Forge.move(_slot_order(), index, index + 1))
	SaveIO.save_meta(meta)
	Juice.ui_tap(1.1)
	_refresh_order()


func _refresh_dice() -> void:
	for child: Node in _dice_row.get_children():
		child.queue_free()
	var materials: Dictionary = {}
	if state == null:
		return
	for i: int in range(state.dice.size()):
		var die: Die = state.dice[i]
		materials[die.material] = int(materials.get(die.material, 0)) + 1
		var cell: VBoxContainer = VBoxContainer.new()
		cell.name = "Die%d" % i
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 0)
		_dice_row.add_child(cell)

		var art_button: Button = Button.new()
		art_button.name = "DieButton%d" % i
		art_button.focus_mode = Control.FOCUS_NONE
		art_button.custom_minimum_size = Vector2(0.0, Tokens.dp(46))
		# M7: tärningen ritar sin egen kropp och skugga (DieArt), så knappen har
		# ingen låda runt den – bara ett svagt sken när den trycks.
		var style: StyleBoxEmpty = StyleBoxEmpty.new()
		var pressed: StyleBoxFlat = Tokens.box(Tokens.SURFACE_LINE, true, Tokens.STROKE_HAIR, Tokens.RADIUS_DIE)
		pressed.bg_color = Color(Tokens.SURFACE_RAISED, 0.6)
		for state_name: String in ["normal", "hover", "focus"]:
			art_button.add_theme_stylebox_override(state_name, style)
		art_button.add_theme_stylebox_override("pressed", pressed)
		art_button.pressed.connect(show_die_faces.bind(i))
		cell.add_child(art_button)

		var art: DieArt = DieArt.new()
		art.name = "Art"
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_button.add_child(art)
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.show_die(die, i)

		var caption: Label = _label(Tokens.TYPE_CAPTION - 1, Tokens.CHALK_500)
		caption.text = face_label(die.showing_face())
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(caption)

	var parts: PackedStringArray = PackedStringArray()
	for material: Variant in materials:
		var row: Array = MATERIAL_KEYS.get(int(material), ["", "?"]) as Array
		parts.append("%s ×%d" % [
			Tokens.translate_or(String(row[0]), String(row[1])), int(materials[material])])
	if _materials_label != null:
		_materials_label.text = " · ".join(parts)


## Sidans etikett under tärningen. Pips bär sitt värde, glyph-sidor sitt namn och
## en sprucken sida säger det rakt ut.
static func face_label(face: Face) -> String:
	if face == null:
		return ""
	if face.id == Resolver.CRACKED_FACE_ID:
		return Tokens.translate_or("CHARSHEET_CRACKED", "CRACKED")
	if face.id.begins_with("PIP_"):
		return str(face.value)
	return Tokens.translate_or(Content.face_key(face.id), face.id)


## Fäller ut alla sex sidorna med värde, effekt och magnitud (§4.1 punkt 4).
func show_die_faces(index: int) -> void:
	if state == null or index < 0 or index >= state.dice.size():
		return
	Juice.ui_tap(1.0)
	if _open_die == index:
		_open_die = -1
		_detail.text = Tokens.translate_or("SMITH_SHEET_HINT", "Tap a slot to read what it does.")
		return
	_open_die = index
	var parts: PackedStringArray = PackedStringArray()
	for face: Face in state.dice[index].faces:
		parts.append(face_label(face))
	_detail.text = "%s %d: %s" % [
		Tokens.translate_or("CHARSHEET_DIE", "DIE"), index + 1, " · ".join(parts)]


func _refresh_relics() -> void:
	for child: Node in _relic_row.get_children():
		child.queue_free()
	var title: Label = _label(Tokens.TYPE_LABEL, Tokens.CHALK_500)
	title.text = Tokens.translate_or("SMITH_SHEET_RELICS", "RELICS")
	# INTE klippt: i en HBoxContainer blir en klippt etikett noll pixlar bred och
	# raden ser tom ut (samma fälla som stadens Pips-siffra, M2.5).
	title.clip_text = false
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_relic_row.add_child(title)
	if state == null:
		return
	for relic: Relic in state.relics:
		var button: Button = Button.new()
		button.name = "Relic%s" % relic.id
		button.focus_mode = Control.FOCUS_NONE
		button.text = Tokens.translate_or(Content.relic_key(relic.id), relic.display_name)
		button.clip_text = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, Tokens.dp(Tokens.TOUCH_MIN - 14))
		button.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_CAPTION))
		button.add_theme_color_override("font_color", Tokens.CHALK_100)
		button.add_theme_stylebox_override("normal", Tokens.box(Tokens.SURFACE_LINE, true, Tokens.STROKE_HAIR))
		# Platshållaren (ett rött kryss) hör inte hemma i en rad som visar vad
		# spelaren bär: saknas ikonen står namnet ensamt, som i M5.
		var info: Dictionary = Art.art_info(StringName("relic." + relic.id))
		if String(info["source"]) != Art.SOURCE_PLACEHOLDER:
			button.icon = _small_icon(info["texture"] as Texture2D)
		button.pressed.connect(_on_relic_pressed.bind(relic))
		_relic_row.add_child(button)


# ---------------------------------------------------------------------------
# Handlingar
# ---------------------------------------------------------------------------

## Tapp på en slot: regeltexten i krita, [b]ordagrant samma sträng[/b] som på
## belöningskortet (§4.2). Olika formuleringar för samma regel är §B.1-problemet.
func _on_slot_pressed(slot: String) -> void:
	Juice.ui_tap(1.0)
	var view: Dictionary = slot_view(slot)
	var slot_name: String = Tokens.translate_or(Content.sheet_slot_key(slot), slot)
	match String(view["kind"]):
		"relic":
			_on_relic_pressed(view["relic"] as Relic)
			return
		"gear":
			var item: Item = view["item"] as Item
			var summary: String = Tokens.translate_or(item.effect_summary_key, "") \
				if item.effect_summary_key != "" else ""
			_detail.text = "%s · %s%s" % [slot_name, String(view["name"]),
				"" if summary == "" else " · " + summary]
			return
	if bool(view["locked"]):
		_detail.text = "%s · %s" % [slot_name,
			Tokens.translate_or(KEY_LOCKED, "LV %d") % int(view["unlock_level"])]
		return
	_detail.text = "%s · %s" % [slot_name, Tokens.translate_or("SMITH_SLOT_EMPTY", "empty")]


## [b]Ordagrant samma mening som på belöningskortet[/b] (§4.2): texten byggs av
## [method RewardApply.describe] med samma alternativpost som kortet bar. Två
## formuleringar för samma regel är TOWN_AND_ONBOARDING §B.1-problemet om igen.
func _on_relic_pressed(relic: Relic) -> void:
	var option: Dictionary = {
		"id": "RELIC_%s" % relic.id,
		"category": Rewards.CATEGORY_RELIC,
		"name": relic.display_name,
		"name_key": Content.relic_key(relic.id),
		"rarity": relic.rarity,
		"data": {"relic_id": relic.id},
	}
	_detail.text = RewardApply.describe(state, option, {})


## Kroppsvarianten bor i [Settings], inte i sparfilen: den ska överleva att en
## run tar slut (DECISIONS 2026-09-21). Bara i staden – mitt i en run står
## figuren redan i Gropen.
func change_look() -> void:
	if not in_town:
		return
	var next: String = "b" if look() == "a" else "a"
	Settings.set_value(&"smith_variant", next)
	if _hero != null:
		_hero.body_variant = next
	Juice.ui_tap(1.0)
	refresh()
	look_changed.emit(next)


## §4.3: det nya föremålet blixtrar i sin slot och porträttet tänds kort.
## 520 ms, sedan är det bara en del av hjälten – ingen permanent markering.
func _play_highlight(reward_id: String) -> void:
	var relic_id: String = reward_id.trim_prefix("RELIC_")
	var slot: String = Content.relic_slot(relic_id)
	if slot == "" and _hero != null:
		for raw: Variant in Content.SHEET_SLOTS:
			var item: Item = _hero.equipped(String(raw))
			if item != null and (item.id == reward_id or "GEAR_" + item.id == reward_id):
				slot = String(raw)
	if slot != "" and _slot_buttons.has(slot):
		Juice.outline(_slot_buttons[slot] as Control, Tokens.SEM_CHARGE, HIGHLIGHT_MS)
	if _portrait != null and not Settings.reduced_motion:
		_portrait.modulate = Color(1.35, 1.2, 1.05)
		var tween: Tween = create_tween()
		tween.tween_property(_portrait, "modulate", Color.WHITE, float(HIGHLIGHT_MS) / 1000.0)
	Juice.haptic(Haptics.Level.MEDIUM)


func close_sheet() -> void:
	Juice.ui_tap(0.9)
	closed.emit()
	queue_free()


func _on_go_down() -> void:
	Juice.ui_tap(1.15)
	Juice.haptic(Haptics.Level.MEDIUM)
	go_down_pressed.emit(_seed_value)
	queue_free()


func slot_button(slot: String) -> Button:
	return _slot_buttons.get(slot, null) as Button


func detail_text() -> String:
	return _detail.text if _detail != null else ""


## En ikon i knappstorlek. [member Button.icon] ritas i texturens egen storlek,
## och en målad 128 px-ikon blev en halv knapp hög.
static func _small_icon(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var px: int = Tokens.dpi(Tokens.TOUCH_MIN - 22)
	if texture.get_height() <= px:
		return texture
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return texture
	image = image.duplicate() as Image
	if image.is_compressed():
		image.decompress()
	image.resize(px, px, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)


static func _label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", Tokens.dpi(font_size))
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
