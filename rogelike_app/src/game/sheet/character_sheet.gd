class_name CharacterSheet
extends Control
## Character sheetet (CORRIDOR_DESIGN §4, mockup design/mockup_character_sheet.html).
##
## [b]Figuren syns aldrig i korridoren. Den finns här, och bara här[/b] – och det
## är därför den blir värd något att öppna (§4). Sheetet är en [b]modal[/b],
## precis som inställningarna: att byta skärm mitt i en run skulle kasta bort
## kamerans plats i rutnätet och stridens placering.
##
## Uppifrån och ner (§4.1):
## [br]1. Porträtt, namn, stad · run, HP-stapel, Pips, stäng-kryss.
## [br]2. Figuren i mitten med sju slots runt om. Tomma slots är en [b]kritad
##    kontur[/b], inte en grå ruta.
## [br]3. Slotordningen – smedjans enda verktyg. [b]Aktiv bara i staden[/b]: mitt
##    i en run är brädet redan i spel och en omordning vore ett drag utan kostnad.
## [br]4. De sex tärningarna. Tapp fäller ut alla sidorna med värde och effekt.
##    Detta är [b]enda platsen i spelet[/b] där hela uppsättningen går att läsa.
## [br]5. Reliker, "CHANGE LOOK" (bara i staden) och "GO DOWN" (bara i staden).
##
## Sheetet äger ingen regel. [Forge] garanterar att smedjan byter och ordnar om,
## aldrig lägger till, och [Content.RELIC_SLOTS] säger var en relik hänger.

signal closed()
## [code]GO DOWN[/code] i staden. Samma tapp som stadens egen knapp.
signal go_down_pressed(seed_value: int)

## Figurens ruta i mitten, i dp. 48 px-cellen × 4 = 192 px hög figur (§4.1:
## "~52 % av höjden" i portrait).
const FIGURE_HEIGHT_DP: int = 180
## [b]Dubbel världsskala.[/b] [HeroFigure] ritas 48 px × 4 i striden; här är den
## sidans huvudmotiv (§4.1: "~52 % av höjden") och ×8 ger 384 px. Heltalsfaktorn
## behåller pixelrutnätet – 1,5× hade gett halva pixlar (UI_GUIDE §8.3).
const FIGURE_SCALE: int = 2
const SLOT_BOX_DP: int = 52
const PORTRAIT_DP: int = 56
## Hur länge ett nytt lager kritas på figuren (§4.3).
const HIGHLIGHT_MS: int = 520

var state: CombatState = null
var meta: Meta = null
var in_town: bool = false

var _seed_value: int = 0
var _room: int = 0
var _figure: HeroFigure = null
var _figure_box: Control = null
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

	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.custom_minimum_size = Vector2(Tokens.dp(PORTRAIT_DP), Tokens.dp(PORTRAIT_DP))
	row.add_child(_portrait)

	var names: VBoxContainer = VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 0)
	row.add_child(names)

	_title = _label(Tokens.TYPE_TITLE, Tokens.CHALK_100)
	ChalkFx.apply(_title, ChalkFx.DISPLAY)
	names.add_child(_title)

	_subtitle = _label(Tokens.TYPE_LABEL, Tokens.CHALK_500)
	names.add_child(_subtitle)

	var vitals: HBoxContainer = HBoxContainer.new()
	vitals.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))
	names.add_child(vitals)

	_hp_label = _label(Tokens.TYPE_BODY, Tokens.SEM_BLOOD)
	_hp_label.clip_text = false
	vitals.add_child(_hp_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(Tokens.dp(64), Tokens.dp(9))
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track: StyleBoxFlat = Tokens.box(Tokens.SURFACE_LINE, true, Tokens.STROKE_HAIR, Tokens.RADIUS_CHIP)
	track.bg_color = Tokens.SURFACE_PIT
	var fill: StyleBoxFlat = Tokens.box(Tokens.SEM_BLOOD, true, 0.0, Tokens.RADIUS_CHIP)
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
	var close_style: StyleBoxFlat = Tokens.box(Tokens.SURFACE_LINE, true, Tokens.STROKE_HAIR)
	close_style.bg_color = Tokens.SURFACE_RAISED
	for state_name: String in ["normal", "hover", "pressed", "focus"]:
		close.add_theme_stylebox_override(state_name, close_style)
	close.pressed.connect(close_sheet)
	row.add_child(close)
	return row


# --- Figuren och de sju slotsen --------------------------------------------

func _build_body() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Body"
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))

	var left: VBoxContainer = _slot_column("LeftSlots", Content.SHEET_SLOTS.slice(0, 4))
	row.add_child(left)

	_figure_box = Control.new()
	_figure_box.name = "Figure"
	_figure_box.custom_minimum_size = Vector2(0.0, Tokens.dp(FIGURE_HEIGHT_DP))
	_figure_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_figure_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_figure_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_figure_box.clip_contents = true
	row.add_child(_figure_box)

	_figure = HeroFigure.new()
	_figure.name = "Paperdoll"
	_figure.scale = Vector2(FIGURE_SCALE, FIGURE_SCALE)
	_figure_box.add_child(_figure)
	_figure_box.resized.connect(_place_figure)

	var right: VBoxContainer = _slot_column("RightSlots", Content.SHEET_SLOTS.slice(4))
	_change_look = Button.new()
	_change_look.name = "ChangeLook"
	# Kort etikett: rutan är 52 dp bred och "CHANGE LOOK" klipps mitt i ordet.
	# Hela meningen står i smedjans panel.
	_change_look.text = Tokens.translate_or("CHARSHEET_LOOK", "LOOK")
	_change_look.clip_text = true
	_change_look.focus_mode = Control.FOCUS_NONE
	_change_look.custom_minimum_size = Vector2(Tokens.dp(SLOT_BOX_DP), Tokens.dp(SLOT_BOX_DP))
	_change_look.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_CAPTION))
	_change_look.add_theme_color_override("font_color", Tokens.SEM_CHARGE)
	_change_look.add_theme_color_override("font_disabled_color", Tokens.CHALK_500)
	var look_style: StyleBoxFlat = Tokens.box(Tokens.SEM_CHARGE, true, Tokens.STROKE_REG, Tokens.RADIUS_BUTTON)
	look_style.bg_color = Tokens.SURFACE_RAISED
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


## En tom slot är en [b]kritad kontur[/b], inte en grå ruta (§4.1 punkt 3).
func _make_slot_button(slot: String) -> Button:
	var button: Button = Button.new()
	button.name = "Slot%s" % slot
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.custom_minimum_size = Vector2(Tokens.dp(SLOT_BOX_DP), Tokens.dp(SLOT_BOX_DP))
	button.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_CAPTION - 1))
	button.add_theme_color_override("font_color", Tokens.CHALK_300)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.expand_icon = false
	button.pressed.connect(_on_slot_pressed.bind(slot))
	return button


func _place_figure() -> void:
	if _figure == null or _figure_box == null:
		return
	# [member Node2D.position] ligger i förälderns rymd och påverkas INTE av
	# nodens egen [member Node2D.scale], men [constant HeroFigure.FOOT_OFFSET]
	# räknas i figurens oskalade pixlar. Skillnaden kompenseras här, annars står
	# figuren en halv kropp under golvlinjen.
	var foot: float = float(HeroFigure.FOOT_OFFSET) * float(FIGURE_SCALE - 1)
	_figure.stand_on(
		_figure_box.size.x * 0.5,
		_figure_box.size.y - Tokens.dp(Tokens.SPACE_2) - foot)


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
	var variant: String = Art.smith_variant(Settings.smith_variant)
	_portrait.texture = Art.smith_portrait(variant)
	_portrait.texture_filter = Art.filter_for(Art.portrait_key(variant))
	_title.text = Tokens.translate_or("SMITH_SHEET_TITLE", "THE SMITH")
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
	if _figure != null:
		_figure.set_variant(variant)
		if state != null:
			_figure.apply_relics(state.relics)
	_place_figure()
	_refresh_slots()
	_refresh_order()
	_refresh_dice()
	_refresh_relics()


func _refresh_slots() -> void:
	var worn: Dictionary = {}
	if state != null:
		for relic: Relic in state.relics:
			var slot: String = Content.relic_slot(relic.id)
			if slot != "":
				worn[slot] = relic
	for raw: Variant in Content.SHEET_SLOTS:
		var slot: String = String(raw)
		var button: Button = _slot_buttons[slot] as Button
		var relic: Relic = worn.get(slot, null) as Relic
		button.text = Tokens.translate_or(Content.sheet_slot_key(slot), slot)
		button.icon = Art.relic_icon(relic.id) if relic != null else null
		var color: Color = Tokens.CHALK_100 if relic != null else Tokens.CHALK_500
		button.add_theme_color_override("font_color", color)
		# Kritad kontur för en tom slot, fylld ruta för en buren relik.
		var style: StyleBoxFlat = Tokens.box(
			Tokens.SURFACE_LINE if relic != null else Tokens.CHALK_500,
			true, Tokens.STROKE_HAIR, Tokens.RADIUS_BUTTON)
		style.bg_color = Tokens.SURFACE_RAISED if relic != null else Color(Tokens.SURFACE_PIT, 0.0)
		for state_name: String in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state_name, style)


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
		var style: StyleBoxFlat = Tokens.box(Tokens.SURFACE_LINE, true, Tokens.STROKE_HAIR, Tokens.RADIUS_DIE)
		style.bg_color = Tokens.SURFACE_RAISED
		for state_name: String in ["normal", "hover", "pressed", "focus"]:
			art_button.add_theme_stylebox_override(state_name, style)
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
		button.icon = Art.relic_icon(relic.id)
		button.pressed.connect(_on_relic_pressed.bind(relic))
		_relic_row.add_child(button)


# ---------------------------------------------------------------------------
# Handlingar
# ---------------------------------------------------------------------------

## Tapp på en slot: regeltexten i krita, [b]ordagrant samma sträng[/b] som på
## belöningskortet (§4.2). Olika formuleringar för samma regel är §B.1-problemet.
func _on_slot_pressed(slot: String) -> void:
	Juice.ui_tap(1.0)
	if state != null:
		for relic: Relic in state.relics:
			if Content.relic_slot(relic.id) == slot:
				_on_relic_pressed(relic)
				return
	_detail.text = "%s · %s" % [
		Tokens.translate_or(Content.sheet_slot_key(slot), slot),
		Tokens.translate_or("SMITH_SLOT_EMPTY", "empty"),
	]


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
	var next: String = "b" if Art.smith_variant(Settings.smith_variant) == "a" else "a"
	Settings.set_value(&"smith_variant", next)
	Juice.ui_tap(1.0)
	refresh()


## §4.3: lagret kritas på figuren, sloten blixtrar. 520 ms, sedan är det bara
## en del av figuren – ingen permanent markering.
func _play_highlight(reward_id: String) -> void:
	var relic_id: String = reward_id.trim_prefix("RELIC_")
	var slot: String = Content.relic_slot(relic_id)
	var seconds: float = float(HIGHLIGHT_MS) / 1000.0
	if _figure != null and is_instance_valid(_figure):
		var layer: Sprite2D = null
		for raw: Variant in Art.RELIC_LAYERS.get(relic_id, []) as Array:
			layer = _figure.layer_sprite(StringName(raw))
			if layer != null and layer.visible:
				break
			layer = null
		if layer != null:
			layer.modulate = Color(Tokens.CHALK_100, 0.0)
			var draw_in: Tween = create_tween()
			draw_in.tween_property(layer, "modulate", Color.WHITE, seconds)
	if slot != "" and _slot_buttons.has(slot):
		Juice.outline(_slot_buttons[slot] as Control, Tokens.SEM_CHARGE, HIGHLIGHT_MS)
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


static func _label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", Tokens.dpi(font_size))
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
