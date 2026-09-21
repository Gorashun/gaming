class_name TownScreen
extends GameScreen
## Chalkrim (sv Kritkanten). TOWN_AND_ONBOARDING del A.
##
## [b]Statusnot (PM 2026-09-21):[/b] riktningen bytte till first person dungeon
## crawler, och stadens sidoscroll-remsa utgick. Den här skärmen är därför en
## [b]tillfällig menyversion[/b]: all logik – Pips, Skrotmarknaden, Kritväggen,
## Marrows dödsrepliker och GO DOWN-flödet – ligger färdig i [Meta] och
## [Content], och bara presentationen är en lista med knappar. Byts listan mot
## en korridorvy senare rörs ingen regel.
##
## [b]Sex normativa regler för stadens UI[/b] (§A.4), alla uppfyllda här:
## [br]1. [code]GO DOWN[/code] är alltid synlig, 56 dp, full bredd, i tumzonen,
##    från första bildrutan. Aldrig inaktiv, aldrig bakom en dialog.
## [br]2. Max två tapp från stadsingång till ny run. Här räcker ett.
## [br]3. Menydjup = 1. En plats öppnar ETT kritpanel; ett panel öppnar aldrig
##    ett till.
## [br]4. Tidsbudget 20–40 s för någon som vet vad hen vill.
## [br]5. Nytt innehåll skriker, gammalt är tyst (badge på platsen).
## [br]6. Ingen timer, ingen daglig bonus, ingen inloggningsbelöning. Någonsin.

## Spelaren vill ned i Gropen. [param seed] är den seed runnen ska köras med.
signal go_down(seed_value: int)

const PLACE_PIT: String = "PIT_MOUTH"
const PLACE_MARKET: String = "MARKET"
const PLACE_WALL: String = "TALLY_WALL"
const PLACE_FORGE: String = "FORGE"

## Platserna i ordning. [code]unlock_runs[/code] är antalet avslutade runs som
## krävs (§A.2). Gropens mun är alltid öppen.
const PLACES: Array[Dictionary] = [
	{"id": PLACE_PIT, "key": "TOWN_PLACE_PIT_MOUTH", "en": "The Pit Mouth", "unlock_runs": 0},
	{"id": PLACE_MARKET, "key": "TOWN_PLACE_MARKET", "en": "The Scrap Market", "unlock_runs": 1},
	{"id": PLACE_WALL, "key": "TOWN_PLACE_TALLY_WALL", "en": "The Tally Wall", "unlock_runs": 1},
	{"id": PLACE_FORGE, "key": "TOWN_PLACE_FORGE", "en": "The Forge", "unlock_runs": 1},
]

@onready var _column: VBoxContainer = $Margin/Column

var meta: Meta = null

var _seed_value: int = 0
var _arrival: Dictionary = {}
var _open_place: String = ""
var _places_box: VBoxContainer = null
var _panel_host: PanelContainer = null
var _panel_scroll: ScrollContainer = null
var _pips_label: Label = null
var _tally_label: Label = null
var _marrow_label: Label = null
var _go_down: Button = null
var _place_buttons: Dictionary = {}


func enter(ctx: Dictionary) -> void:
	meta = ctx.get("meta", null) as Meta
	if meta == null:
		meta = Meta.fresh()
	_seed_value = int(ctx.get("seed", 0))
	_arrival = ctx.get("arrival", {}) as Dictionary
	_build()


func _build() -> void:
	$Background.color = Tokens.SURFACE_PIT
	for side: String in ["left", "right", "top", "bottom"]:
		$Margin.add_theme_constant_override("margin_" + side, Tokens.dpi(Tokens.SCREEN_MARGIN))
	_column.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_3))

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_4))
	_column.add_child(header)

	var title: Label = _label(Tokens.TYPE_TITLE, Tokens.CHALK_100)
	title.text = Tokens.translate_or("TOWN_NAME", "CHALKRIM")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ChalkFx.apply(title, ChalkFx.DISPLAY)
	header.add_child(title)

	_pips_label = _label(Tokens.TYPE_BODY_L, Tokens.SEM_CHARGE)
	# Rubriken tar all bredd med SIZE_EXPAND_FILL; en klippt Pips-etikett får då
	# minsta bredd noll och siffran försvinner helt.
	_pips_label.clip_text = false
	header.add_child(_pips_label)

	# Kritmärkena: ett streck per person som gått ner. Kommer du upp suddar du
	# ditt eget streck med tummen (§A.1). Spelets enda monument.
	_tally_label = _label(Tokens.TYPE_BODY, Tokens.CHALK_500)
	_tally_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_column.add_child(_tally_label)

	# Marrow möter dig när du dör och säger EN rad om HUR du dog (§A.1).
	_marrow_label = _label(Tokens.TYPE_BODY, Tokens.CHALK_300)
	_marrow_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_marrow_label.clip_text = false
	_column.add_child(_marrow_label)

	_places_box = VBoxContainer.new()
	_places_box.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))
	_column.add_child(_places_box)

	# Panelen får ALDRIG trycka ut GO DOWN. §A.4 regel 1 är normativ: knappen
	# är synlig från första bildrutan, aldrig bakom en dialog. En lång panel
	# scrollar i stället för att växa.
	_panel_host = PanelContainer.new()
	_panel_host.name = "PanelHost"
	_panel_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_host.add_theme_stylebox_override("panel", Tokens.box(Tokens.SURFACE_LINE, true, Tokens.STROKE_HAIR))
	_panel_host.visible = false
	_column.add_child(_panel_host)

	_panel_scroll = ScrollContainer.new()
	_panel_scroll.name = "PanelScroll"
	_panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel_scroll.custom_minimum_size = Vector2(0.0, Tokens.dp(120))
	_panel_host.add_child(_panel_scroll)

	# Luften mellan platserna och GO DOWN. Panelen får tre gånger så mycket av
	# det lediga utrymmet, men knappen ligger alltid kvar i tumzonen.
	_panel_host.size_flags_stretch_ratio = 3.0
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = 1.0
	spacer.custom_minimum_size = Vector2(0.0, Tokens.dp(Tokens.SPACE_2))
	_column.add_child(spacer)

	# Regel 1: alltid synlig, alltid tryckbar, alltid längst ned.
	_go_down = Button.new()
	_go_down.name = "GoDownButton"
	_go_down.text = Tokens.translate_or("TOWN_GO_DOWN", "GO DOWN")
	_go_down.clip_text = true
	_go_down.custom_minimum_size = Vector2(0.0, Tokens.dp(Tokens.BUTTON_PRIMARY_HEIGHT + 8))
	_go_down.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_TITLE))
	var primary: StyleBoxFlat = Tokens.box(Tokens.CHALK_100, true, Tokens.STROKE_REG)
	primary.bg_color = Tokens.CHALK_100
	for state_name: String in ["normal", "hover", "pressed", "focus"]:
		_go_down.add_theme_stylebox_override(state_name, primary)
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		_go_down.add_theme_color_override(color_name, Tokens.SURFACE_PIT)
	ChalkFx.apply(_go_down, ChalkFx.BUTTON)
	_go_down.pressed.connect(descend)
	_column.add_child(_go_down)

	_build_places()
	_refresh_header()
	_show_arrival()


func _build_places() -> void:
	for child: Node in _places_box.get_children():
		child.queue_free()
	_place_buttons.clear()
	for spec: Dictionary in PLACES:
		var unlocked: bool = meta.runs >= int(spec["unlock_runs"])
		var button: Button = Button.new()
		button.text = Tokens.translate_or(String(spec["key"]), String(spec["en"]))
		if not unlocked:
			# Balatro-modellen (§A.2): du ser alltid vad som finns kvar och
			# exakt hur du får det. En låst plats är en kritsilhuett med villkor.
			button.text = "%s — %s" % [button.text, Tokens.translate_or(
				"TOWN_LOCKED_RUNS", "after %d run(s)") % int(spec["unlock_runs"])]
		button.disabled = not unlocked
		button.clip_text = true
		button.custom_minimum_size = Vector2(0.0, Tokens.dp(Tokens.BUTTON_SECONDARY_HEIGHT))
		button.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_BODY_L))
		button.add_theme_color_override("font_color", Tokens.CHALK_100)
		button.add_theme_color_override("font_disabled_color", Tokens.CHALK_500)
		var style: StyleBoxFlat = Tokens.box(Tokens.SURFACE_LINE, true, Tokens.STROKE_REG)
		for state_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state_name, style)
		ChalkFx.apply(button, ChalkFx.BUTTON)
		button.pressed.connect(open_place.bind(String(spec["id"])))
		_places_box.add_child(button)
		_place_buttons[String(spec["id"])] = button


func _refresh_header() -> void:
	_pips_label.text = "%d %s" % [meta.pips, Tokens.translate_or("TOWN_CURRENCY_PIPS", "Pips")]
	_tally_label.text = "%s  %s" % [
		_tally_marks(meta.tally),
		Tokens.translate_or("TOWN_TALLY", "%d marks on the rim") % meta.tally,
	]


## Kritstrecken ritade som text: fyra streck och ett tvärstreck, som på en vägg.
static func _tally_marks(count: int) -> String:
	if count <= 0:
		return ""
	var groups: int = count / 5
	var rest: int = count % 5
	var marks: String = ""
	for i: int in range(mini(groups, 8)):
		marks += "卌 "
	for i: int in range(rest):
		marks += "|"
	return marks.strip_edges()


func _show_arrival() -> void:
	_marrow_label.text = ""
	if _arrival.is_empty():
		return
	var killed_by: String = String(_arrival.get("killed_by", ""))
	var line: Dictionary = Content.death_line_for(killed_by, meta.last_death_line, int(_arrival.get("seed", 0)))
	if line.get("key", "") == "":
		return
	meta.last_death_line = int(line["index"])
	_marrow_label.text = "%s: “%s”" % [
		Tokens.translate_or("TOWN_MARROW_NAME", "Marrow"),
		Tokens.translate_or(String(line["key"]), String(line["en"])),
	]
	var earned: int = int(_arrival.get("pips_earned", 0))
	if earned > 0:
		_marrow_label.text += "\n%s" % (Tokens.translate_or("TOWN_PIPS_GAINED", "+%d PIPS") % earned)


# ---------------------------------------------------------------------------
# Platserna. Menydjup 1: ett panel, aldrig ett till.
# ---------------------------------------------------------------------------

func open_place(place_id: String) -> void:
	Juice.ui_tap(1.0)
	if _open_place == place_id:
		close_place()
		return
	_open_place = place_id
	for child: Node in _panel_scroll.get_children():
		child.queue_free()
	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Tokens.dpi(Tokens.SPACE_3))
	_panel_scroll.add_child(margin)
	var body: VBoxContainer = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))
	margin.add_child(body)
	match place_id:
		PLACE_PIT:
			_build_pit(body)
		PLACE_MARKET:
			_build_market(body)
		PLACE_WALL:
			_build_wall(body)
		PLACE_FORGE:
			_build_forge(body)
	_panel_host.visible = true


func close_place() -> void:
	_open_place = ""
	_panel_host.visible = false
	for child: Node in _panel_scroll.get_children():
		child.queue_free()


func current_place() -> String:
	return _open_place


# --- Gropens mun -----------------------------------------------------------

func _build_pit(body: VBoxContainer) -> void:
	_heading(body, Tokens.translate_or("TOWN_PLACE_PIT_MOUTH", "The Pit Mouth"))
	_line(body, Tokens.translate_or("TAGLINE", "ROLL SIX. PLACE FIVE. THE ORDER IS THE DAMAGE."), Tokens.CHALK_100)
	_line(body, Tokens.translate_or("TAGLINE_SUB", "Equal neighbours multiply."), Tokens.CHALK_500)
	# GAME_DESIGN §6.10: seeden är synlig. Communityns bevis på att vi inte
	# fuskar, och förutsättningen för dagliga utmaningar.
	_line(body, Tokens.translate_or("TOWN_SEED", "Seed %d") % _seed_value, Tokens.CHALK_300)
	_action(body, Tokens.translate_or("TOWN_NEW_SEED", "NEW SEED"), _new_seed)


func _new_seed() -> void:
	_seed_value = abs(int(Time.get_unix_time_from_system() * 1000.0) ^ int(Time.get_ticks_usec()))
	open_place(PLACE_PIT)
	open_place(PLACE_PIT)


# --- Skrotmarknaden --------------------------------------------------------

func _build_market(body: VBoxContainer) -> void:
	_heading(body, Tokens.translate_or("TOWN_PLACE_MARKET", "The Scrap Market"))
	# Den heliga regeln för metan (§A.3): aldrig en statsiffra. Marknaden
	# säljer bara INNEHÅLL till belöningspoolen.
	_line(body, Tokens.translate_or("MARKET_RULE",
		"Pips buy variety, never power. Everything here joins the reward pool."), Tokens.CHALK_500)
	var sold: int = 0
	for entry: Dictionary in Content.market_catalogue():
		if sold >= 5:
			break
		if meta.unlocked.has(String(entry["id"])):
			continue
		sold += 1
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))
		body.add_child(row)
		var name: Label = _label(Tokens.TYPE_BODY, Tokens.CHALK_100)
		name.text = Tokens.translate_or(String(entry.get("name_key", "")), String(entry["name"]))
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var price: int = Meta.price_of(entry)
		var buy: Button = Button.new()
		buy.text = Tokens.translate_or("TOWN_PRICE", "%d pips") % price
		buy.disabled = not meta.can_afford(entry)
		buy.clip_text = true
		buy.custom_minimum_size = Vector2(Tokens.dp(96), Tokens.dp(Tokens.BUTTON_SECONDARY_HEIGHT))
		buy.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_LABEL))
		buy.add_theme_color_override("font_color", Tokens.SEM_CHARGE)
		buy.add_theme_color_override("font_disabled_color", Tokens.CHALK_500)
		var style: StyleBoxFlat = Tokens.box(Tokens.SURFACE_LINE, true, Tokens.STROKE_REG)
		for state_name: String in ["normal", "hover", "pressed", "disabled"]:
			buy.add_theme_stylebox_override(state_name, style)
		buy.pressed.connect(_buy.bind(entry))
		row.add_child(buy)
	if sold == 0:
		_line(body, Tokens.translate_or("MARKET_EMPTY", "Shelves are bare. Go earn some eyes."), Tokens.CHALK_500)


func _buy(entry: Dictionary) -> void:
	if not meta.buy(entry):
		return
	Juice.ui_tap(1.3)
	Juice.haptic(Haptics.Level.MEDIUM)
	_refresh_header()
	open_place(PLACE_MARKET)
	open_place(PLACE_MARKET)
	_save_meta()


# --- Kritväggen ------------------------------------------------------------

func _build_wall(body: VBoxContainer) -> void:
	_heading(body, Tokens.translate_or("TOWN_PLACE_TALLY_WALL", "The Tally Wall"))
	_stat(body, Tokens.translate_or("WALL_RUNS", "Runs"), str(meta.runs))
	_stat(body, Tokens.translate_or("WALL_WINS", "Runs survived"), str(meta.wins))
	_stat(body, Tokens.translate_or("WALL_DEATHS", "Marks earned"), str(meta.deaths))
	_stat(body, Tokens.translate_or("WALL_BEST_CHAIN", "Best chain"), str(meta.best_chain))
	_stat(body, Tokens.translate_or("WALL_BEST_SCORE", "Best score"), str(meta.best_score))
	_stat(body, Tokens.translate_or("WALL_SEEN_ENEMIES", "Enemies logged"),
		"%d / %d" % [meta.seen_enemies.size(), Content.codex_enemy_count()])
	_stat(body, Tokens.translate_or("WALL_SEEN_COMBOS", "Chains logged"),
		"%d / 4" % meta.seen_combos.size())
	_line(body, "%s: “%s”" % [
		Tokens.translate_or("NPC_TALLY", "Tallow"),
		Tokens.translate_or("TALLY_LINE", "The wall keeps better books than you do."),
	], Tokens.CHALK_500)


# --- Smedjan ---------------------------------------------------------------

func _build_forge(body: VBoxContainer) -> void:
	_heading(body, Tokens.translate_or("FORGE_TITLE", "THE FORGE"))
	_line(body, "%s: “%s”" % [
		Tokens.translate_or("NPC_HOB", "Hob"),
		Tokens.translate_or("FORGE_NO_ADD", "The forge never adds power. It moves it."),
	], Tokens.CHALK_500)

	var order: PackedInt32Array = _slot_order()
	var types: Array[int] = _ordered_types(order)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_1))
	body.add_child(row)
	for i: int in range(types.size()):
		var cell: VBoxContainer = VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(cell)
		var name: Label = _label(Tokens.TYPE_CAPTION, Tokens.slot_color(types[i]))
		name.text = Tokens.slot_label(types[i])
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(name)
		var move: Button = Button.new()
		move.text = "→"
		move.disabled = i >= types.size() - 1
		move.custom_minimum_size = Vector2(0.0, Tokens.dp(Tokens.TOUCH_MIN))
		move.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_BODY))
		move.add_theme_color_override("font_color", Tokens.CHALK_100)
		move.add_theme_stylebox_override("normal", Tokens.box(Tokens.SURFACE_LINE, true, Tokens.STROKE_REG))
		move.pressed.connect(_move_slot.bind(i))
		cell.add_child(move)

	_action(body, Tokens.translate_or("FORGE_REVERT", "PUT IT BACK"), _reset_order)
	_action(body, Tokens.translate_or("FORGE_TAB_FACES", "FACES"), _swap_faces)
	# Könsvalet kan bytas i staden (DECISIONS 2026-09-21). Inga könsord i texten.
	_action(body, Tokens.translate_or("SMITH_SHEET_CHANGE_LOOK", "CHANGE LOOK"), _change_smith)


func _slot_order() -> PackedInt32Array:
	var raw: Array = meta.loadout.get(Forge.KEY_SLOT_ORDER, []) as Array
	var order: PackedInt32Array = PackedInt32Array()
	for value: Variant in raw:
		order.append(int(value))
	if not Forge.is_permutation(order, Rules.SLOT_COUNT):
		order = Forge.identity_order(Rules.SLOT_COUNT)
	return order


func _ordered_types(order: PackedInt32Array) -> Array[int]:
	var board: Board = Forge.reorder_slots(Board.smith_board(), order)
	var types: Array[int] = []
	for slot: Slot in board.slots:
		types.append(slot.type)
	return types


func _move_slot(index: int) -> void:
	meta.loadout[Forge.KEY_SLOT_ORDER] = Array(Forge.move(_slot_order(), index, index + 1))
	Juice.ui_tap(1.1)
	_save_meta()
	open_place(PLACE_FORGE)
	open_place(PLACE_FORGE)


func _reset_order() -> void:
	meta.loadout[Forge.KEY_SLOT_ORDER] = Array(Forge.identity_order(Rules.SLOT_COUNT))
	_save_meta()
	open_place(PLACE_FORGE)
	open_place(PLACE_FORGE)


## MVP: roterar sidorna 1↔6 på tärning 1. Byte, aldrig tillägg – multimängden
## av sidor är oförändrad, vilket [Forge] och dess test garanterar.
func _swap_faces() -> void:
	var swaps: Array = (meta.loadout.get(Forge.KEY_FACE_SWAPS, []) as Array).duplicate()
	if swaps.is_empty():
		swaps.append([0, 0, 5])
	else:
		swaps.clear()
	meta.loadout[Forge.KEY_FACE_SWAPS] = swaps
	Juice.ui_tap(1.2)
	_save_meta()
	open_place(PLACE_FORGE)
	open_place(PLACE_FORGE)


func _change_smith() -> void:
	var next: String = "b" if Art.smith_variant(Settings.smith_variant) == "a" else "a"
	Settings.set_value(&"smith_variant", next)
	Juice.ui_tap(1.0)
	open_place(PLACE_FORGE)
	open_place(PLACE_FORGE)


# ---------------------------------------------------------------------------

## Startar runnen. [b]Ett tapp[/b] – regel 2 tillåter två.
func descend() -> void:
	Juice.ui_tap(1.15)
	Juice.haptic(Haptics.Level.MEDIUM)
	go_down.emit(_seed_value)
	screen_done.emit({"action": "go_down", "seed": _seed_value})


func seed_value() -> int:
	return _seed_value


func _save_meta() -> void:
	SaveIO.save_meta(meta)


# --- Byggstenar ------------------------------------------------------------

static func _label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", Tokens.dpi(font_size))
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
	return label


func _heading(parent: Control, text: String) -> void:
	var label: Label = _label(Tokens.TYPE_HEADING, Tokens.CHALK_100)
	label.text = text
	parent.add_child(label)


func _line(parent: Control, text: String, color: Color) -> void:
	var label: Label = _label(Tokens.TYPE_BODY, color)
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = false
	parent.add_child(label)


func _stat(parent: Control, name_text: String, value_text: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var name: Label = _label(Tokens.TYPE_BODY, Tokens.CHALK_300)
	name.text = name_text
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	var value: Label = _label(Tokens.TYPE_BODY, Tokens.CHALK_100)
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.clip_text = false
	row.add_child(value)
	parent.add_child(row)


func _action(parent: Control, text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.clip_text = true
	button.custom_minimum_size = Vector2(0.0, Tokens.dp(Tokens.BUTTON_SECONDARY_HEIGHT))
	button.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_LABEL))
	button.add_theme_color_override("font_color", Tokens.CHALK_100)
	button.add_theme_stylebox_override("normal", Tokens.box(Tokens.SURFACE_LINE, true, Tokens.STROKE_REG))
	button.pressed.connect(action)
	parent.add_child(button)
	return button
