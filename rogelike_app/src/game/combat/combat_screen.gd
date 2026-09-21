class_name CombatScreen
extends GameScreen
## Stridsskärmen, [b]v2[/b]. docs/design/COMBAT_READABILITY.md.
##
## [b]Den heliga regeln (GAME_DESIGN §6) är hela skärmens arkitektur:[/b] varje
## gång placeringen ändras kör vi en riktig [method Resolver.resolve] på en KOPIA
## och visar dess utfall. Vid bekräftelse körs [method Resolver.resolve] igen med
## identiska argument, och i debug asserterar vi att loggen är byte-identisk.
##
## [b]Vad v2 lägger till[/b] är inte en enda regel, bara uträkningen:
## [br]• [ReceiptPanel] – meningen, rustningsraden och en rad per skadeinstans.
## [br]• [ArcRow] – multiplikatorbågen med sin orsak (`×2 PAIR · BOTH 5`).
## [br]• [RouteStrip] + prognosfält i HP-staplarna – vart skadan tar vägen.
## [br]• [SlotView] med regel, räkning och varför; [DieView] med tomma socklar.
## [br]• [HelpLayer] – "?" tänder sex callouts samtidigt.
##
## Allt ovan är [b]ren presentation av [code]_preview.events[/code][/b] via
## [ChainReceipt]. [code]src/core/resolver.gd[/code] är orörd.
##
## [Reveal] avgör vad som finns på skärmen. Regeln (§7): ett element får bara
## döljas när det är tomt eller overksamt i tillståndet – UI ljuger aldrig.

## En runda är resolvad, uppspelad och tillståndet är redo att sparas.
## [param state] är vid rundans BÖRJAN (efter [method Resolver.advance]) när
## striden fortsätter – autosave får aldrig ligga mitt i en kedja (§1).
signal round_finished(state: CombatState, result: ResolveResult)
## Striden är slut. [param won] är false när spelaren dog.
signal combat_finished(won: bool, state: CombatState)
## En fiende träffades eller dog. [b]Skärmen ritar ingen varelse själv[/b] – i
## korridoren står de som billboards i 3D och i källaren som [EnemyActor] i
## World-lagret. Signalen är kontraktet mot båda.
signal enemy_reaction(index: int, kind: String)
## Så här hög måste skärmen vara för att inget ska klippas. [b]Arenan betalar[/b]
## (COMBAT_READABILITY §8): i korridoren ÄR arenan korridorbilden, och
## [CorridorScreen] krymper den tills räknestycket och tumzonen får plats.
signal layout_pressure(needed: float)

const REACTION_HIT: String = "hit"
const REACTION_DEATH: String = "death"

## Tärningsplaceringar som lämnar slots tomma är tillåtna och ibland korrekta
## (GAME_DESIGN §7 fråga 4: Charge-banken kräver det).
const ALLOW_EMPTY_SLOTS: bool = true
## Bredden på hjältens kolumn i fiendezonen, i dp.
const HERO_SLOT_WIDTH: int = 40
## "?" pulsar en gång efter spelarens tredje runda i första striden om ingen
## kedja ännu bekräftats – därefter aldrig igen (§6).
const HELP_PULSE_ROUND: int = 3

@onready var _hp_label: Label = $Margin/Column/TopBar/HpLabel
@onready var _hp_bar: ProgressBar = $Margin/Column/TopBar/HpBar
@onready var _room_label: Label = $Margin/Column/TopBar/RoomLabel
@onready var _charge_label: Label = $Margin/Column/TopBar/ChargeLabel
@onready var _ward_label: Label = $Margin/Column/TopBar/WardLabel
@onready var _enemy_zone: HBoxContainer = $Margin/Column/EnemyZone
@onready var _column: VBoxContainer = $Margin/Column
@onready var _slot_row: HBoxContainer = $Margin/Column/SlotRow
@onready var _tray: HBoxContainer = $Margin/Column/Tray
@onready var _tray_label: Label = $Margin/Column/TrayHeader/TrayLabel
@onready var _tray_hint: Label = $Margin/Column/TrayHeader/TrayHint
@onready var _undo_button: Button = $Margin/Column/Actions/UndoButton
@onready var _reroll_button: Button = $Margin/Column/Actions/RerollButton
@onready var _confirm_button: Button = $Margin/Column/Actions/ConfirmButton
@onready var _fx_layer: Control = $FxLayer
@onready var _tap_catcher: Control = $TapCatcher
@onready var _player: EventPlayer = $EventPlayer

var state: CombatState = null
var reveal: Reveal = null
## Sant när skärmen är monterad i de nedre 55 % av [CorridorScreen]. Då äger
## korridorens HUD HP och rum, och fienderna läses av som chip ovanför sina
## billboards i stället för som kort i fiendezonen (COMBAT_READABILITY §8).
var in_corridor: bool = false
## Den som bygger fiendeavläsningarna. Null ⇒ [EnemyPanel] i fiendezonen.
## Sätts före [method GameScreen.setup] av [method CorridorScreen.mount_combat].
var readout_host: Node = null

var _rng: Rng = null
var _node: Dictionary = {}
var _placement: PackedInt32Array = PackedInt32Array()
## Obegränsad ångra-historik inom rundan (UI_GUIDE §4.3).
var _history: Array[PackedInt32Array] = []
var _selected_die: int = -1
var _locked_ids: Array = []

## Tom kolumn längst till vänster i fiendezonen. Där står Smeden i
## World-lagret; krit-UI:t reserverar bara platsen (UI_GUIDE §8.1).
var _hero_slot: Control = null
var _panels: Array[EnemyReadout] = []
var _slot_views: Array[SlotView] = []
var _die_views: Array[DieView] = []
var _view: Dictionary = {}
var _preview: ResolveResult = null
var _receipt: Dictionary = {}
var _ordinals: PackedInt32Array = PackedInt32Array()
var _enemy_names: PackedStringArray = PackedStringArray()
var _resolving: bool = false
var _rng_moved: bool = false
var _chain_step: int = 0
var _pending_result: ResolveResult = null
var _best_chain: int = 0
var _intro_active: bool = false
var _intro_tween: Tween = null
var _intro_nodes: Array[Node] = []
var _edge: Panel = null

var _receipt_panel: ReceiptPanel = null
var _arc_row: ArcRow = null
var _route_strip: RouteStrip = null
var _help_layer: HelpLayer = null
var _help_button: Button = null
var _help_pulsed: bool = false
var _popover: PanelContainer = null

## Tutorialrummets index, eller -1. Sätter pekaren, tipset och träningshjulen.
var _tutorial_room: int = -1
var _tip_label: Label = null
var _pointer: TutorialPointer = null
var _tip_dismissed: bool = false


func enter(ctx: Dictionary) -> void:
	state = ctx.get("state", null) as CombatState
	_rng = ctx.get("rng", null) as Rng
	_node = ctx.get("node", {}) as Dictionary
	_best_chain = int(ctx.get("best_chain", 0))
	reveal = ctx.get("reveal", null) as Reveal
	if reveal == null:
		reveal = Reveal.all_on()
	_tutorial_room = int(ctx.get("tutorial_room", -1))
	in_corridor = bool(ctx.get("in_corridor", false))
	_style()
	_undo_button.pressed.connect(undo)
	_reroll_button.pressed.connect(reroll)
	_confirm_button.pressed.connect(confirm)
	_tap_catcher.gui_input.connect(_on_tap_during_playback)
	_player.event_started.connect(_on_event)
	_player.finished.connect(_on_playback_finished)
	_build_room()
	_setup_tutorial()
	begin_round()
	if RunFlow.is_boss(_node) and state.round_number <= 1:
		play_boss_intro()


func _style() -> void:
	$Margin.add_theme_constant_override("margin_left", Tokens.dpi(Tokens.SCREEN_MARGIN))
	$Margin.add_theme_constant_override("margin_right", Tokens.dpi(Tokens.SCREEN_MARGIN))
	$Margin.add_theme_constant_override("margin_top", Tokens.dpi(Tokens.SCREEN_MARGIN))
	$Margin.add_theme_constant_override("margin_bottom", Tokens.dpi(Tokens.SPACE_2))
	# 2 dp och inte 4: nio rader × 2 dp är 18 dp av kolumnen, och kvittot är
	# viktigare än luften mellan raderna (§8).
	_column.add_theme_constant_override("separation", Tokens.dpi(2))
	_enemy_zone.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_1))
	_slot_row.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_1))
	_tray.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_1))
	$Margin/Column/Actions.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))
	$Margin/Column/TopBar.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))
	$Margin/Column/TrayHeader.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))

	# Toppfältets etiketter får INTE klippas: med clip_text blir deras minsta
	# bredd noll, HP-baren äter hela raden och siffrorna försvinner.
	# Toppfältets etiketter får INTE klippas: med clip_text blir deras minsta
	# bredd noll, HP-baren äter hela raden och siffrorna försvinner. Priset är
	# att deras textbredd ÄR radens minsta bredd, och raden bär nu två knappar
	# (? och ⚙) till – därför 10 dp och inte 12.
	_apply_label(_hp_label, Tokens.TYPE_CAPTION - 2, Tokens.SEM_BLOOD, false)
	_apply_label(_room_label, Tokens.TYPE_CAPTION - 2, Tokens.CHALK_300, false)
	_apply_label(_charge_label, Tokens.TYPE_CAPTION - 2, Tokens.SEM_CHARGE, false)
	_apply_label(_ward_label, Tokens.TYPE_CAPTION - 2, Tokens.SEM_SHIELD, false)
	_apply_label(_tray_label, Tokens.TYPE_CAPTION - 2, Tokens.CHALK_500)
	_apply_label(_tray_hint, Tokens.TYPE_CAPTION - 2, Tokens.SEM_CHARGE, false)
	_tray_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_hp_bar.custom_minimum_size = Vector2(Tokens.dp(28), Tokens.dp(10))
	var bar_bg: StyleBoxFlat = StyleBoxFlat.new()
	bar_bg.bg_color = Tokens.SURFACE_RAISED
	var bar_fill: StyleBoxFlat = StyleBoxFlat.new()
	bar_fill.bg_color = Tokens.SEM_BLOOD
	_hp_bar.add_theme_stylebox_override("background", bar_bg)
	_hp_bar.add_theme_stylebox_override("fill", bar_fill)

	_style_button(_undo_button, Tokens.TYPE_CAPTION - 2, Tokens.CHALK_300, Tokens.BUTTON_SECONDARY_HEIGHT)
	_style_button(_reroll_button, Tokens.TYPE_CAPTION - 2, Tokens.SEM_FROST, Tokens.BUTTON_SECONDARY_HEIGHT)
	# Varje dp här är en bokstav mindre på primärknappen, som måste rymma både
	# verbet och kedjans summa ("CONFIRM · 28 DAMAGE").
	_undo_button.custom_minimum_size.x = Tokens.dp(Tokens.TOUCH_MIN + 4)
	_reroll_button.custom_minimum_size.x = Tokens.dp(Tokens.TOUCH_MIN + 16)
	_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(_confirm_button, Tokens.TYPE_LABEL, Tokens.SURFACE_PIT, Tokens.BUTTON_PRIMARY_HEIGHT)
	var primary: StyleBoxFlat = Tokens.box(Tokens.CHALK_100, true, Tokens.STROKE_REG)
	primary.bg_color = Tokens.CHALK_100
	_confirm_button.add_theme_stylebox_override("normal", primary)
	_confirm_button.add_theme_stylebox_override("hover", primary)
	_confirm_button.add_theme_stylebox_override("pressed", primary)

	_build_receipt()
	_build_arc_row()
	_build_route_strip()
	_build_help()

	for button: Button in [_undo_button, _reroll_button, _confirm_button]:
		ChalkFx.apply(button, ChalkFx.BUTTON)

	_edge = Panel.new()
	_edge.name = "EdgeFlash"
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge.visible = false
	var edge_style: StyleBoxFlat = StyleBoxFlat.new()
	edge_style.bg_color = Color(0, 0, 0, 0)
	var edge_width: int = int(round(Tokens.dp(10)))
	edge_style.border_width_left = edge_width
	edge_style.border_width_right = edge_width
	edge_style.border_width_top = edge_width
	edge_style.border_width_bottom = edge_width
	edge_style.border_color = Tokens.SEM_BLOOD
	edge_style.border_blend = true
	_edge.add_theme_stylebox_override("panel", edge_style)
	_fx_layer.add_child(_edge)
	_edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Paus: enda vägen till inställningarna mitt i en run (UI_GUIDE §2.9).
	var pause_button: Button = Button.new()
	pause_button.name = "PauseButton"
	pause_button.text = "⚙"
	_style_button(pause_button, Tokens.TYPE_BODY, Tokens.CHALK_300, Tokens.TOUCH_MIN)
	pause_button.custom_minimum_size = Vector2(Tokens.dp(Tokens.TOUCH_MIN), Tokens.dp(Tokens.TOUCH_MIN))
	pause_button.tooltip_text = Tokens.translate_or("SETTINGS_TITLE", "Settings")
	pause_button.pressed.connect(_open_settings)
	ChalkFx.apply(pause_button, ChalkFx.BUTTON)
	$Margin/Column/TopBar.add_child(pause_button)

	_apply_corridor_mode()


## I korridoren äger [CorridorHud] HP, rum och Pips – de står redan högst upp
## över korridorbilden (se design/screenshots/corridor_combat_390x844.png). Att
## rita dem en gång till i stridens toppfält vore två sanningskällor för samma
## siffra, och det är dessutom 44 dp av höjdbudgeten som §8 hellre ger kvittot.
## Laddning, Ward, "?" och ⚙ står kvar: de finns ingen annanstans.
func _apply_corridor_mode() -> void:
	if not in_corridor:
		return
	_hp_label.visible = false
	_hp_bar.visible = false
	_room_label.visible = false
	_enemy_zone.visible = false
	# Fiendezonen expanderar vertikalt; en osynlig container gör det fortfarande.
	_enemy_zone.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_enemy_zone.custom_minimum_size = Vector2.ZERO
	# "?" och ⚙ flyttar upp i korridorens krit-rad. Knapparna är 48 dp höga och
	# sätter därmed hela toppfältets höjd; utan dem är raden två pillertexter.
	_help_button.visible = false
	var pause: Button = $Margin/Column/TopBar.get_node_or_null(^"PauseButton") as Button
	if pause != null:
		pause.visible = false
	# Leveransremsan blir överflödig när fienderna står i bild: siffran "↑ 28 ·
	# DIES" ritas på fiendens eget chip i stället, där varelsen faktiskt är
	# (COMBAT_READABILITY §8 – arenan betalar, och här ÄR arenan bilden).
	_route_strip.visible = false
	# Brickans rubrikrad kostar 14 dp för ordet "THE TRAY". Laddningstipset
	# ("1 left = +4 charge") är det enda av de två som lär ut något, och det
	# flyttar upp till pillerraden. Rubriken har brickan rakt under sig.
	_tray_hint.reparent($Margin/Column/TopBar)
	_tray_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	$Margin/Column/TrayHeader.visible = false
	# 1 dp mellan raderna i stället för 2: åtta rader ger 8 dp tillbaka, och
	# kvittot är viktigare än luften mellan dem (§8).
	_column.add_theme_constant_override("separation", Tokens.dpi(1))
	$Margin.add_theme_constant_override("margin_top", Tokens.dpi(Tokens.SPACE_2))
	$Margin.add_theme_constant_override("margin_bottom", Tokens.dpi(Tokens.SPACE_1))


## Kvittot ersätter M2:s PreviewPanel: en stor siffra utan härkomst.
func _build_receipt() -> void:
	_receipt_panel = ReceiptPanel.new()
	_receipt_panel.name = "Receipt"
	_column.add_child(_receipt_panel)
	_column.move_child(_receipt_panel, _slot_row.get_index())
	ChalkFx.apply(_receipt_panel, ChalkFx.PANEL)


func _build_arc_row() -> void:
	_arc_row = ArcRow.new()
	_arc_row.name = "ArcRow"
	_column.add_child(_arc_row)
	_column.move_child(_arc_row, _slot_row.get_index())


func _build_route_strip() -> void:
	_route_strip = RouteStrip.new()
	_route_strip.name = "RouteStrip"
	_column.add_child(_route_strip)
	_column.move_child(_route_strip, _receipt_panel.get_index())


func _build_help() -> void:
	_help_button = Button.new()
	_help_button.name = "HelpButton"
	_help_button.text = Art.ui_icon_glyph(&"help")
	_style_button(_help_button, Tokens.TYPE_BODY, Tokens.SEM_CHARGE, Tokens.TOUCH_MIN)
	_help_button.custom_minimum_size = Vector2(Tokens.dp(Tokens.TOUCH_MIN), Tokens.dp(Tokens.TOUCH_MIN))
	var outline: StyleBoxFlat = Tokens.box(Tokens.SEM_CHARGE, true, Tokens.STROKE_REG)
	for state_name: String in ["normal", "hover", "pressed"]:
		_help_button.add_theme_stylebox_override(state_name, outline)
	_help_button.pressed.connect(open_help)
	ChalkFx.apply(_help_button, ChalkFx.BUTTON)
	$Margin/Column/TopBar.add_child(_help_button)

	_help_layer = HelpLayer.new()
	_help_layer.name = "HelpLayer"
	add_child(_help_layer)
	_help_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_help_layer.closed.connect(_on_help_closed)


static func _apply_label(label: Label, font_size: int, color: Color, clip: bool = true) -> void:
	label.add_theme_font_size_override("font_size", Tokens.dpi(font_size))
	label.add_theme_color_override("font_color", color)
	if clip and label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		label.clip_text = true


static func _style_button(button: Button, font_size: int, color: Color, height: int) -> void:
	button.clip_text = true
	button.add_theme_font_size_override("font_size", Tokens.dpi(font_size))
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color)
	button.add_theme_color_override("font_pressed_color", color)
	button.add_theme_color_override("font_disabled_color", Tokens.CHALK_500)
	button.custom_minimum_size = Vector2(Tokens.dp(Tokens.BUTTON_SECONDARY_WIDTH), Tokens.dp(height))
	var style: StyleBoxFlat = Tokens.box(Tokens.SURFACE_LINE, true, Tokens.STROKE_REG)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("disabled", Tokens.box(Tokens.SURFACE_LINE, true, Tokens.STROKE_HAIR))


# ---------------------------------------------------------------------------
# Uppbyggnad
# ---------------------------------------------------------------------------

func _build_room() -> void:
	for panel: EnemyReadout in _panels:
		if is_instance_valid(panel):
			panel.queue_free()
	_panels.clear()
	if readout_host != null and is_instance_valid(readout_host):
		readout_host.call("reset_readouts")
	if _hero_slot != null:
		_hero_slot.queue_free()
	_hero_slot = Control.new()
	_hero_slot.name = "HeroSlot"
	_hero_slot.custom_minimum_size = Vector2(Tokens.dp(HERO_SLOT_WIDTH), 0.0)
	_hero_slot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_hero_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemy_zone.add_child(_hero_slot)

	_ordinals = ChainReceipt.ordinals(state.enemies)
	_enemy_names = PackedStringArray()
	var facts: Dictionary = _reveal_facts()
	for i: int in range(state.enemies.size()):
		var enemy: Enemy = state.enemies[i]
		_enemy_names.append(EnemyReadout.display_name_of(enemy, _ordinals[i]))
		var panel: EnemyReadout = _make_readout(i)
		panel.index = i
		panel.set_show_armor(reveal.shows("armor", facts))
		panel.bind(enemy, _ordinals[i])
		panel.tapped.connect(_on_enemy_tapped)
		_panels.append(panel)
	_route_strip.build(state.enemies.size(), Tokens.dp(HERO_SLOT_WIDTH))
	_route_strip.visible = reveal.shows("overflow", facts) and not in_corridor

	for slot_view: SlotView in _slot_views:
		slot_view.queue_free()
	_slot_views.clear()
	for i: int in range(state.board.size()):
		var slot_view: SlotView = SlotView.new()
		_slot_row.add_child(slot_view)
		slot_view.set_show_rules(reveal.shows("slot_types", facts))
		slot_view.tapped.connect(_on_slot_tapped)
		slot_view.die_dropped.connect(_on_die_dropped)
		slot_view.held.connect(_on_slot_held)
		_slot_views.append(slot_view)

	for die_view: DieView in _die_views:
		die_view.queue_free()
	_die_views.clear()
	for i: int in range(state.dice.size()):
		var die_view: DieView = DieView.new()
		_tray.add_child(die_view)
		die_view.set_tray_extended(reveal.has("tray_ext"))
		die_view.tapped.connect(_on_die_tapped)
		_die_views.append(die_view)

	if world != null:
		world.call("build", state.enemies, Tokens.dp(34))
	# Positionerna kan först läsas när containrarna har gjort sin layout.
	call_deferred("_sync_world")
	call_deferred("_sync_arcs")


## En avläsning per fiende: chip i korridoren, panel i fiendezonen.
func _make_readout(index: int) -> EnemyReadout:
	if readout_host != null and is_instance_valid(readout_host):
		var made: EnemyReadout = readout_host.call("make_readout", index) as EnemyReadout
		if made != null:
			return made
	var panel: EnemyPanel = EnemyPanel.new()
	_enemy_zone.add_child(panel)
	return panel


## Ett tapp på en fiende (eller på dess chip i korridoren) svarar med hela
## avläsningen i ord – samma siffror som redan står där, men som en mening
## (COMBAT_READABILITY §5).
func _on_enemy_tapped(index: int) -> void:
	if index < 0 or index >= state.enemies.size() or index >= _panels.size():
		return
	var ordinal: int = _ordinals[index] if index < _ordinals.size() else 0
	_show_popover(_panels[index], EnemyReadout.detail_text(state.enemies[index], ordinal))


func _sync_world() -> void:
	if world == null:
		return
	await get_tree().process_frame
	if world == null or not is_instance_valid(world):
		return
	var floor_y: float = _enemy_zone.get_global_rect().end.y
	if not _panels.is_empty():
		floor_y = _panels[0].art_bottom()
	world.call("set_band", _enemy_zone.get_global_rect(), floor_y, state.relics)
	if _hero_slot != null and _hero_slot.is_inside_tree():
		world.call("place_hero", _hero_slot.get_global_rect().get_center())
	for i: int in range(_panels.size()):
		world.call("place", i, _panels[i].enemy_id, _panels[i].anchor_point())


## Bågarna behöver slotarnas x-intervall, som finns först efter layouten.
func _sync_arcs() -> void:
	await get_tree().process_frame
	if not is_instance_valid(_arc_row) or not _arc_row.is_inside_tree():
		return
	var spans: Array[Vector2] = []
	var origin: float = _arc_row.get_global_rect().position.x
	for slot_view: SlotView in _slot_views:
		if not is_instance_valid(slot_view) or not slot_view.is_inside_tree():
			spans.append(Vector2.ZERO)
			continue
		var rect: Rect2 = slot_view.get_global_rect()
		spans.append(Vector2(rect.position.x - origin, rect.end.x - origin))
	_arc_row.set_arcs(_receipt.get("arcs", []) as Array, spans)


## Förbereder en runda: tom placering, tom historik, färsk förhandsvisning.
func begin_round() -> void:
	_placement = CombatState.empty_placement(state.board.size())
	_history.clear()
	_selected_die = -1
	_chain_step = 0
	_resolving = false
	_rng_moved = false
	_tap_catcher.visible = false
	_view = EventPlayer.view_from_state(state)
	_refresh_all()
	_maybe_pulse_help()


## Tillståndets siffror som [method Reveal.may_hide] behöver. Utan dem skulle UI
## kunna dölja en laddningsmätare som står på 7 – alltså ljuga (§7).
func _reveal_facts() -> Dictionary:
	var types: Array[int] = []
	var max_armor: int = 0
	for slot: Slot in state.board.slots:
		types.append(slot.type)
	for enemy: Enemy in state.enemies:
		max_armor = maxi(max_armor, enemy.armor)
	return {
		"charge": state.charge,
		"ward": state.ward,
		"rerolls_left": state.rerolls_left,
		"max_armor": max_armor,
		"slot_types": types,
	}


func _refresh_all() -> void:
	_refresh_hud()
	_refresh_slots()
	_refresh_tray()
	_refresh_preview()


func _refresh_hud() -> void:
	var facts: Dictionary = _reveal_facts()
	_hp_label.text = "◖ %d/%d" % [state.player_hp, state.player_max_hp]
	_hp_bar.max_value = maxi(1, state.player_max_hp)
	_hp_bar.value = clampi(state.player_hp, 0, state.player_max_hp)
	var room_key: String = "COMBAT_BOSS_ROUND" if RunFlow.is_boss(_node) else "COMBAT_ROOM_ROUND"
	_room_label.text = tr(room_key) % [int(_node.get("room", 1)), state.round_number]

	# Laddningen med ORD och enhet. "⬤0/20" var skärmens mest obegripliga
	# element (§1.1 rad 4, betyg 1/10).
	_charge_label.visible = reveal.shows("charge", facts)
	_charge_label.text = "%s %s" % [
		Art.ui_icon_glyph(&"charge"),
		Tokens.translate_or("COMBAT_CHARGE_PILL", "Charge %d") % state.charge,
	]
	# Ward har ingen egen lärkurveflagga: pillret finns bara när det betyder
	# något, dvs. när spelaren har Ward eller en VOID-slot som kan ge det (§7).
	_ward_label.visible = state.ward > 0 or (facts["slot_types"] as Array).has(Rules.SlotType.VOID)
	_ward_label.text = Tokens.translate_or("COMBAT_WARD_PILL", "Ward %d") % state.ward

	_reroll_button.visible = reveal.shows("reroll", facts)
	_reroll_button.text = tr("COMBAT_REROLL") % state.rerolls_left
	_undo_button.text = tr("COMBAT_UNDO")
	_reroll_button.disabled = _resolving or not Reroll.can_afford(state) \
		or Reroll.rerollable_indices(state, _placement, _locked_ids).is_empty()
	_undo_button.disabled = _resolving or _history.is_empty()


func _refresh_slots() -> void:
	for i: int in range(_slot_views.size()):
		var die: Die = null
		if _placement[i] >= 0:
			die = state.dice[_placement[i]]
		_slot_views[i].bind(i, state.board.slots[i], die)
		_slot_views[i].set_highlight(_selected_die >= 0 and not state.board.slots[i].blocked)


func _refresh_tray() -> void:
	for i: int in range(_die_views.size()):
		var slot_of_die: int = -1
		for s: int in range(_placement.size()):
			if _placement[s] == i:
				slot_of_die = s
		_die_views[i].bind(i, state.dice[i], slot_of_die, state.stolen.has(state.dice[i].id))
		_die_views[i].set_selected(i == _selected_die)

	# Brickans rubrik bär den enda kvarvarande siffran som behövde en
	# förklaring: "1 left = +4 charge" förklarar Laddning första gången
	# spelaren ser den, utan tooltip (§4).
	_tray_label.text = Tokens.translate_or("COMBAT_TRAY_TITLE", "THE TRAY")
	var unplaced: Array[int] = state.unplaced_die_indices(_placement)
	var banked: int = 0
	for index: int in unplaced:
		var face: Face = state.dice[index].showing_face()
		if face != null:
			banked += face.value
	var facts: Dictionary = _reveal_facts()
	_tray_hint.visible = reveal.shows("charge", facts) and not unplaced.is_empty()
	_tray_hint.text = Tokens.translate_or("COMBAT_TRAY_LEFT", "%d left = +%d charge") % [unplaced.size(), banked]


## Kör hela resolvern på en kopia och visar dess exakta utfall.
func _refresh_preview() -> void:
	_preview = Resolver.resolve(state, _placement)
	_receipt = ChainReceipt.build(_preview.events, state.enemies, state.board)
	var facts: Dictionary = _reveal_facts()
	var show_armor: bool = reveal.shows("armor", facts)

	# Per slot: hela räknestycket, inte halva (§2.4).
	var slots: Array = _receipt["slots"] as Array
	for i: int in range(mini(_slot_views.size(), slots.size())):
		var slot: Dictionary = slots[i] as Dictionary
		_slot_views[i].set_calculation(
			calc_text(slot),
			why_text(slot),
			int(slot["multiplier"]),
			String(slot["outcome"]) == ChainReceipt.OUT_FIZZLE)

	_receipt_panel.set_header(Tokens.translate_or("COMBAT_RECEIPT_HEADER",
		"ROUND %d · THE CHAIN BEFORE YOU CONFIRM") % state.round_number)
	_receipt_panel.show_receipt(_receipt, _enemy_names, show_armor)

	if _route_strip.visible:
		_route_strip.show_routes(_receipt["routes"] as Array)
	elif in_corridor:
		var chip_routes: Array = _receipt["routes"] as Array
		for i: int in range(mini(_panels.size(), chip_routes.size())):
			_panels[i].show_route(chip_routes[i] as Dictionary)
	# Prognosfältet i HP-stapeln: den enda "vem dör"-signalen som fungerar utan
	# färgseende (§2.2 punkt 2).
	var routes: Array = _receipt["routes"] as Array
	for i: int in range(mini(_panels.size(), routes.size())):
		_panels[i].set_forecast(int((routes[i] as Dictionary)["damage"]))

	_sync_arcs()
	call_deferred("_report_layout_pressure")

	var total: int = int(_receipt["damage"])
	var placed: int = 0
	for i: int in range(_placement.size()):
		if _placement[i] >= 0:
			placed += 1
	# §7 fråga 4: bekräfta med tomma slots MÅSTE vara tillåtet – det är så man
	# bankar Charge. Knappen är därför aktiv även med noll placerade tärningar.
	_confirm_button.disabled = _resolving
	if placed == 0 and ALLOW_EMPTY_SLOTS:
		_confirm_button.text = tr("COMBAT_CONFIRM_EMPTY")
	else:
		# Siffran på knappen och TOTAL i kvittot är samma tal, alltid (§B.3).
		_confirm_button.text = Tokens.translate_or("COMBAT_CONFIRM_DAMAGE", "CONFIRM · %d DAMAGE") % total


## Kolumnens minsta höjd plus marginalerna. Mäts efter layouten, aldrig före:
## en [Label] med [code]autowrap[/code] rapporterar EN rads höjd innan den fått
## sin bredd (se noten i ARCHITECTURE om höjdbudgeten).
func _report_layout_pressure() -> void:
	if not is_inside_tree() or _column == null:
		return
	await get_tree().process_frame
	if not is_instance_valid(_column) or not _column.is_inside_tree():
		return
	var margin: MarginContainer = $Margin
	var needed: float = _column.get_combined_minimum_size().y \
		+ float(margin.get_theme_constant(&"margin_top")) \
		+ float(margin.get_theme_constant(&"margin_bottom"))
	layout_pressure.emit(needed)


## Höjden skärmen behöver just nu. Publik för [code]tests/test_combat_layout.gd[/code].
func required_height() -> float:
	if _column == null:
		return 0.0
	var margin: MarginContainer = $Margin
	return _column.get_combined_minimum_size().y \
		+ float(margin.get_theme_constant(&"margin_top")) \
		+ float(margin.get_theme_constant(&"margin_bottom"))


## [code]bas ×mult = resultat[/code]. Aldrig [code]= x[/code] utan härkomst och
## aldrig [code]5 ×2[/code] utan produkt (§B.1 punkt 3).
static func calc_text(slot: Dictionary) -> String:
	if not bool(slot["occupied"]):
		return ""
	var value: int = int(slot["value"])
	var multiplier: int = int(slot["multiplier"])
	var amount: int = int(slot["amount"])
	if slot.has("copies_from"):
		# Spegeln skriver ut pilen i räkningen också: "←5 ×2 = 10". Utan den
		# ser talet ut som ett fel när tärningen visar 1 (§B.1 punkt 2).
		return Tokens.translate_or("COMBAT_SLOT_MATH_MIRROR", "←%d ×%d = %d") % [value, multiplier, amount]
	if multiplier > 1:
		return Tokens.translate_or("COMBAT_SLOT_MATH", "%d ×%d = %d") % [value, multiplier, amount]
	return Tokens.translate_or("COMBAT_SLOT_MATH_PLAIN", "= %d") % amount


## Slotens "varför"-rad. Orsakskoden kommer ur [ChainReceipt]; prosan bor här.
static func why_text(slot: Dictionary) -> String:
	var args: Array = slot["why_args"] as Array
	match String(slot["why"]):
		ChainReceipt.WHY_PAIR_WITH:
			return Tokens.translate_or("COMBAT_WHY_PAIR_WITH", "pair with %d") % int(args[0])
		ChainReceipt.WHY_COPY_OF:
			return Tokens.translate_or("COMBAT_WHY_COPY_OF", "copy of %d") % int(args[0])
		ChainReceipt.WHY_NO_LEFT:
			return Tokens.translate_or("COMBAT_WHY_NO_LEFT", "no neighbour")
		ChainReceipt.WHY_LEFT_EMPTY:
			return Tokens.translate_or("COMBAT_WHY_LEFT_EMPTY", "left is empty")
		ChainReceipt.WHY_ANVIL_OK:
			return Tokens.translate_or("COMBAT_WHY_ANVIL_OK", "%d is 5+") % int(args[0])
		ChainReceipt.WHY_ANVIL_LOW:
			# slot_modifier_failed SOM SYNLIG TEXT (§2.4). Utan den lär sig
			# spelaren aldrig Ambossens tröskel.
			return Tokens.translate_or("COMBAT_WHY_ANVIL_LOW", "too low")
		ChainReceipt.WHY_BURN:
			return Tokens.translate_or("COMBAT_WHY_BURN", "+ burn %d") % int(args[0])
		ChainReceipt.WHY_TO_WARD:
			return Tokens.translate_or("COMBAT_WHY_TO_WARD", "→ ward")
		ChainReceipt.WHY_TO_CHARGE:
			return Tokens.translate_or("COMBAT_WHY_TO_CHARGE", "→ charge")
		ChainReceipt.WHY_CHARGE_PLUS:
			return Tokens.translate_or("COMBAT_WHY_CHARGE_PLUS", "charge +%d") % int(args[0])
	return ""


# ---------------------------------------------------------------------------
# Hjälp-lagret och långtryck
# ---------------------------------------------------------------------------

## Ankarna som [HelpLayer] pekar på. Ett dolt element hoppas över, så lagret
## kan aldrig peka på ett tomt hål.
func pointer_anchors() -> Dictionary:
	var anchors: Dictionary = {
		"charge": _charge_label,
		"receipt": _receipt_panel,
		"enemies": _enemy_zone,
		"board": _slot_row,
		"arcs": _arc_row,
		"routes": _route_strip,
		"tray": _tray,
		"confirm": _confirm_button,
	}
	for i: int in range(_slot_views.size()):
		anchors["slot_%d" % i] = _slot_views[i]
	return anchors


func open_help() -> void:
	Juice.ui_tap(1.0)
	if _player.is_playing():
		# §6: öppnas lagret under uppspelning pausas den på nuvarande event.
		_player.set_process(false)
	_help_layer.show_for(pointer_anchors())


func _on_help_closed() -> void:
	if _pending_result != null:
		_player.set_process(true)


func _maybe_pulse_help() -> void:
	if _help_pulsed or _tutorial_room >= 0:
		return
	if state.round_number < HELP_PULSE_ROUND or int(_node.get("room", 1)) != 1:
		return
	_help_pulsed = true
	# Opacitet, inte skala (§6), och exakt en gång.
	var tween: Tween = create_tween()
	tween.tween_property(_help_button, "modulate:a", 0.35, 0.3)
	tween.tween_property(_help_button, "modulate:a", 1.0, 0.3)


## Långtryck på en slot: en mening, ett exempel (§3 och §B.4).
func _on_slot_held(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _slot_views.size():
		return
	_show_popover(_slot_views[slot_index], SlotView.help_text(_slot_views[slot_index].slot_type()))


func _show_popover(anchor: Control, text: String) -> void:
	_hide_popover()
	var card: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = Tokens.box(Tokens.SEM_CHARGE, true, Tokens.STROKE_REG)
	style.bg_color = Color(0.0, 0.0, 0.0, 0.92)
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(Tokens.dp(280), 0.0)
	label.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_BODY))
	label.add_theme_color_override("font_color", Tokens.CHALK_100)
	card.add_child(label)
	_fx_layer.add_child(card)
	_popover = card
	await get_tree().process_frame
	if not is_instance_valid(card) or not is_instance_valid(anchor):
		return
	var card_size: Vector2 = card.get_combined_minimum_size()
	var rect: Rect2 = anchor.get_global_rect()
	# [b]Global → lokal.[/b] I korridoren ligger FxLayer i de nedre 55 % medan
	# ankaret (ett HP-chip) sitter i den övre 45 %. Utan omräkningen hamnar
	# popovern en halv skärm för långt ned.
	var origin: Vector2 = _fx_layer.get_global_rect().position
	var target: Vector2 = Vector2(
		clampf(rect.get_center().x - card_size.x * 0.5, Tokens.dp(8), size.x - card_size.x - Tokens.dp(8)),
		maxf(Tokens.dp(8), rect.position.y - card_size.y - Tokens.dp(8)))
	card.position = target - origin
	card.size = card_size


func _hide_popover() -> void:
	if _popover != null and is_instance_valid(_popover):
		_popover.queue_free()
	_popover = null


# ---------------------------------------------------------------------------
# Tutorialens pekare och tips
# ---------------------------------------------------------------------------

## Kritpilen som pekar på rätt element per rum. Den är en [Sprite2D] när
## UI-agentens [code]ui/tutorial_pointer.png[/code] finns, annars en ritad
## triangel – aldrig ett tomt hål (briefen: placeholder + varning, aldrig krasch).
class TutorialPointer:
	extends Control

	var target: Control = null
	var _sprite: Sprite2D = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var texture: Texture2D = Art.ui_icon(&"pointer")
		if texture != null:
			_sprite = Art.pixel_sprite(texture, Art.ICON_SCALE)
			add_child(_sprite)

	func point_at(node: Control) -> void:
		target = node
		set_process(true)

	func _process(_delta: float) -> void:
		if target == null or not is_instance_valid(target) or not target.is_inside_tree() or not target.visible:
			visible = false
			return
		visible = true
		var rect: Rect2 = target.get_global_rect()
		position = Vector2(rect.get_center().x, rect.position.y - Tokens.dp(14))
		if _sprite == null:
			queue_redraw()

	func _draw() -> void:
		if _sprite != null:
			return
		var w: float = Tokens.dp(9)
		var h: float = Tokens.dp(11)
		draw_colored_polygon(PackedVector2Array([
			Vector2(0.0, h), Vector2(-w, 0.0), Vector2(w, 0.0),
		]), Tokens.SEM_CHARGE)


func _setup_tutorial() -> void:
	if _tutorial_room < 0:
		return
	var tip: Dictionary = Tutorial.tip_for(_tutorial_room)
	if tip.is_empty():
		return
	_tip_label = Label.new()
	_tip_label.name = "TutorialTip"
	_tip_label.text = Tokens.translate_or(String(tip["key"]), String(tip["en"]))
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_BODY))
	_tip_label.add_theme_color_override("font_color", Tokens.SEM_CHARGE)
	_tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_tip_label)
	_column.move_child(_tip_label, _receipt_panel.get_index())

	_pointer = TutorialPointer.new()
	_pointer.name = "TutorialPointer"
	_fx_layer.add_child(_pointer)
	call_deferred("_aim_pointer", String(tip["point_at"]))


func _aim_pointer(anchor_name: String) -> void:
	await get_tree().process_frame
	if _pointer == null or not is_instance_valid(_pointer):
		return
	var anchor: Control = pointer_anchors().get(anchor_name, null) as Control
	if anchor == null:
		push_warning("CombatScreen: tutorialen pekar på '%s' som inte finns" % anchor_name)
		_pointer.visible = false
		return
	_pointer.point_at(anchor)


## Tipset försvinner vid handling (§B.2: "max en mening, försvinner vid handling").
func _dismiss_tip() -> void:
	if _tip_dismissed or _tip_label == null or not is_instance_valid(_tip_label):
		return
	_tip_dismissed = true
	_tip_label.visible = false
	if _pointer != null and is_instance_valid(_pointer):
		_pointer.visible = false
		_pointer.set_process(false)


# ---------------------------------------------------------------------------
# Placering (UI_GUIDE §4.1–4.3)
# ---------------------------------------------------------------------------

func _push_history() -> void:
	_history.append(_placement.duplicate())


func place(die_index: int, slot_index: int) -> bool:
	if _resolving:
		return false
	if slot_index < 0 or slot_index >= _placement.size():
		return false
	if state.board.slots[slot_index].blocked:
		return false
	if die_index < 0 or die_index >= state.dice.size():
		return false
	if state.stolen.has(state.dice[die_index].id):
		return false

	_push_history()
	# Låg tärningen redan i en annan slot blir det ett byte, inte ett fel
	# (UI_GUIDE §4.2): tärningen som stod i målsloten flyttar till den lediga.
	var previous_slot: int = -1
	for i: int in range(_placement.size()):
		if _placement[i] == die_index:
			previous_slot = i
			break
	if previous_slot >= 0:
		_placement[previous_slot] = _placement[slot_index]
	_placement[slot_index] = die_index
	_after_placement_changed()
	Juice.ui_tap(Juice.chain_pitch(slot_index))
	Juice.haptic(Haptics.Level.LIGHT)
	return true


func clear_slot(slot_index: int) -> void:
	if _resolving or slot_index < 0 or slot_index >= _placement.size():
		return
	if _placement[slot_index] < 0:
		return
	_push_history()
	_placement[slot_index] = -1
	_after_placement_changed()


func _after_placement_changed() -> void:
	_selected_die = -1
	_dismiss_tip()
	_hide_popover()
	_refresh_all()


## Ångrar senaste placeringen. Obegränsad historik inom rundan (UI_GUIDE §4.3).
func undo() -> void:
	if _resolving or _history.is_empty():
		return
	_placement = _history.pop_back()
	_selected_die = -1
	_refresh_all()
	Juice.ui_tap(0.8)


func reroll() -> void:
	if _resolving or not Reroll.can_afford(state):
		return
	state = Reroll.apply(state, _placement, _rng, _locked_ids)
	# Tutorialens tärningar är fasta: ett omkast får inte bryta lektionen, så
	# värdena skrivs tillbaka. (Strömmen har ändå rullat; se force_dice.)
	if _tutorial_room >= 0:
		Tutorial.force_dice(state, _tutorial_room)
	_rng_moved = true
	_view = EventPlayer.view_from_state(state)
	_refresh_all()
	Juice.ui_tap(1.25)
	Juice.haptic(Haptics.Level.MEDIUM)


func _on_die_tapped(die_index: int) -> void:
	if _resolving:
		return
	# Tapp på en placerad tärning (eller dess tomma sockel) plockar tillbaka
	# den (§4: "tapp på sockeln är i dag odefinierat").
	for i: int in range(_placement.size()):
		if _placement[i] == die_index:
			clear_slot(i)
			return
	_selected_die = -1 if _selected_die == die_index else die_index
	_dismiss_tip()
	_refresh_all()


func _on_slot_tapped(slot_index: int) -> void:
	if _resolving:
		return
	if _selected_die >= 0:
		place(_selected_die, slot_index)
		return
	clear_slot(slot_index)


func _on_die_dropped(slot_index: int, die_index: int) -> void:
	place(die_index, slot_index)


# ---------------------------------------------------------------------------
# Bekräftelse och uppspelning
# ---------------------------------------------------------------------------

func confirm() -> void:
	if _resolving:
		return
	var result: ResolveResult = Resolver.resolve(state, _placement)
	# GAME_DESIGN §6.3: förhandsvisningen ÄR utfallet. Är den inte det ska det
	# smälla i debug, inte tyst avvika.
	assert(_preview == null or _preview.events_json() == result.events_json(),
		"Förhandsvisningen skiljer sig från utfallet – heliga regeln bruten")

	_resolving = true
	_chain_step = 0
	_selected_die = -1
	_dismiss_tip()
	_hide_popover()
	_tap_catcher.visible = true
	_confirm_button.disabled = true
	_undo_button.disabled = true
	_reroll_button.disabled = true
	Juice.ui_tap(0.9)
	Juice.haptic(Haptics.Level.MEDIUM)
	_pending_result = result
	_player.play(result.events)


func _on_tap_during_playback(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
		return
	if _intro_active:
		skip_boss_intro()
		return
	_player.nudge()


## Hoppar direkt till slutläget. Används av smoke-testet och av dubbeltapp.
func skip_playback() -> void:
	if _player.is_playing():
		_player.skip_to_end()


## True medan skärmen inte tar emot spelbeslut.
func is_resolving() -> bool:
	return _resolving or _intro_active


## Får [GameController] skriva sparfilen medan den HÄR skärmen står framme?
## Se den långa noten i ARCHITECTURE: stridsläget och slumpströmmens position
## måste höra ihop, och ett omkast har redan rullat strömmen vidare.
func is_safe_to_autosave() -> bool:
	return not _resolving and not _rng_moved


func is_intro_active() -> bool:
	return _intro_active


func _open_settings() -> void:
	Juice.ui_tap(1.0)
	if controller != null and controller.has_method("open_settings"):
		controller.call("open_settings")


# ---------------------------------------------------------------------------
# Bossintro (UI_GUIDE §3: "ögonblicket innan")
# ---------------------------------------------------------------------------

const BOSS_INTRO_MS: int = 1200


func play_boss_intro() -> void:
	if _intro_active or _panels.is_empty():
		return
	_intro_active = true
	_tap_catcher.visible = true

	var scrim: ColorRect = ColorRect.new()
	scrim.color = Tokens.SURFACE_SCRIM
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var plate: Label = Label.new()
	plate.text = _boss_name()
	plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_label(plate, Tokens.TYPE_DISPLAY_L, Tokens.CHALK_100, false)
	plate.add_theme_color_override("font_outline_color", Tokens.SURFACE_PIT)
	plate.add_theme_constant_override("outline_size", Tokens.dpi(3))
	ChalkFx.apply(plate, ChalkFx.DISPLAY)
	_fx_layer.add_child(plate)
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	Juice.sfx(&"boss_intro", 1.0, -6.0)
	Juice.haptic(Haptics.Level.HEAVY)

	var seconds: float = float(BOSS_INTRO_MS) / 1000.0
	var tween: Tween = create_tween()
	tween.tween_interval(seconds * 0.55)
	tween.tween_property(scrim, "color:a", 0.0, seconds * 0.45)
	tween.parallel().tween_property(plate, "modulate:a", 0.0, seconds * 0.45)
	tween.tween_callback(_end_boss_intro)
	_intro_tween = tween
	_intro_nodes = [scrim, plate]


func _end_boss_intro() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = null
	for node: Node in _intro_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_intro_nodes.clear()
	if not _intro_active:
		return
	_intro_active = false
	if not _resolving:
		_tap_catcher.visible = false
	_refresh_all()


func skip_boss_intro() -> void:
	if _intro_active:
		_end_boss_intro()


func _boss_name() -> String:
	var enemy: Enemy = state.enemies[0] if not state.enemies.is_empty() else null
	if enemy == null:
		return Tokens.translate_or("COMBAT_BOSS", "BOSS")
	return Tokens.translate_or(Content.enemy_key(enemy.id), enemy.display_name).to_upper()


## Det VISUELLA för ett event. Ljud, haptik, hit-stop och skärmskak spelas av
## [EventPlayer] själv ur [method EventPlayer.feedback].
func _on_event(event: Dictionary, duration: float) -> void:
	EventPlayer.apply_event(_view, event)
	_apply_view_to_panels()
	var event_type: String = String(event.get("t", ""))
	match event_type:
		"die_activated":
			var slot: int = int(event.get("slot", 0))
			if slot < _slot_views.size():
				_slot_views[slot].pulse_die(maxf(0.08, duration))
			var die_index: int = _placement[slot] if slot < _placement.size() else -1
			if die_index >= 0 and die_index < _die_views.size():
				_die_views[die_index].pulse_art(maxf(0.08, duration))
			_swing_hero()
			_chain_step += 1
		"combo_formed":
			var multiplier: int = int(event.get("multiplier", 1))
			for slot_value: Variant in event.get("slots", []) as Array:
				var index: int = int(slot_value)
				if index < _slot_views.size():
					Juice.blink(_slot_views[index], Tokens.multiplier_color(multiplier), 0.26)
			_pop(_arc_row, "×%d %s" % [multiplier, String(event.get("kind", ""))],
				Tokens.multiplier_color(multiplier), Tokens.multiplier_size(multiplier))
		"house_bonus":
			_pop(_arc_row, tr("COMBAT_HOUSE") % int(event.get("factor", 2)), Tokens.SEM_CHARGE, Tokens.TYPE_DISPLAY_L)
		"damage_dealt":
			_on_damage(event)
		"enemy_killed":
			var killed: int = _panel_index_for(String(event.get("target", "")), true)
			if killed >= 0:
				_panels[killed].flash_death()
				enemy_reaction.emit(killed, REACTION_DEATH)
				if world != null:
					var actor: EnemyActor = world.call("actor_at", killed, String(event.get("target", ""))) as EnemyActor
					if actor != null:
						actor.death_reaction()
		"ward_gained":
			_pop(_ward_label, "+%d" % int(event.get("amount", 0)), Tokens.SEM_SHIELD, Tokens.TYPE_TITLE)
		"charge_stored":
			_pop(_charge_label, "+%d" % int(event.get("amount", 0)), Tokens.SEM_CHARGE, Tokens.TYPE_HEADING)
			_charge_glow()
		"charge_applied":
			_pop(_charge_label, tr("COMBAT_CHARGE_SPENT") % int(event.get("amount", 0)), Tokens.SEM_CHARGE, Tokens.TYPE_TITLE)
			_charge_glow()
		"enemy_attacks", "enemy_thorns", "player_damaged":
			var damage: int = int(event.get("amount", 0))
			if damage > 0:
				_pop(_hp_label, "-%d" % damage, Tokens.SEM_BLOOD, Tokens.TYPE_DISPLAY_L)
				_edge_flash(Tokens.SEM_BLOOD)
				Juice.shake_node(_hp_bar, 4.0, 0.18)
				_stagger_hero()
		"heal":
			_pop(_hp_label, "+%d" % int(event.get("amount", 0)), Tokens.SEM_HEAL, Tokens.TYPE_TITLE)
		"die_cracked":
			_on_die_cracked(event)
		"player_died":
			_pop(_hp_label, tr("COMBAT_PLAYER_DEAD"), Tokens.SEM_BLOOD, Tokens.TYPE_DISPLAY_XL)
			_edge_flash(Tokens.SEM_BLOOD)
		"round_end":
			_refresh_hud()
			_check_record()


func _on_die_cracked(event: Dictionary) -> void:
	_pop(_receipt_panel, tr("COMBAT_DIE_CRACKED"), Tokens.SEM_BLOOD, Tokens.TYPE_DISPLAY_L)
	var die_id: String = String(event.get("die_id", ""))
	for i: int in range(_placement.size()):
		var die_index: int = _placement[i]
		if die_index < 0 or die_index >= state.dice.size():
			continue
		if state.dice[die_index].id != die_id:
			continue
		if i < _slot_views.size():
			Juice.outline(_slot_views[i], Tokens.SEM_BLOOD, 520)
			_slot_views[i].pulse_die(0.3)
		if die_index < _die_views.size():
			_die_views[die_index].pulse_art(0.3)


func _edge_flash(color: Color) -> void:
	if _edge == null:
		return
	_edge.modulate = Color(color, 1.0)
	_edge.visible = true
	var tween: Tween = _edge.create_tween()
	tween.tween_property(_edge, "modulate:a", 0.0, Tokens.MOTION_BASE)
	tween.tween_callback(func() -> void: _edge.visible = false)


func _charge_glow() -> void:
	Juice.blink(_charge_label, Tokens.SEM_CHARGE, Tokens.MOTION_BASE)
	Juice.pulse(_charge_label, 1.2, Tokens.MOTION_QUICK)


func _check_record() -> void:
	if _pending_result == null:
		return
	var chain: int = MetaScore.chain_damage(_pending_result.events)
	if chain <= 0 or chain <= _best_chain:
		return
	_best_chain = chain
	_pop(_receipt_panel, Tokens.translate_or("COMBAT_NEW_BEST", "NEW BEST"), Tokens.SEM_CHARGE, Tokens.TYPE_DISPLAY_L)
	Juice.sfx(EventPlayer.SFX_COMBO_HOUSE, 1.6)
	Juice.haptic(Haptics.Level.HEAVY)


func _swing_hero() -> void:
	var figure: HeroFigure = _hero()
	if figure != null:
		figure.strike()


func _stagger_hero() -> void:
	var figure: HeroFigure = _hero()
	if figure != null:
		figure.stagger()


func _hero() -> HeroFigure:
	if world == null or not is_instance_valid(world):
		return null
	return world.get("hero") as HeroFigure


## ARMOR-poppen behålls, men den kommer nu EFTER att räknestycket redan visat
## samma avdrag: poppen blir en bekräftelse, inte en nyhet (§5).
func _on_damage(event: Dictionary) -> void:
	var target_id: String = String(event.get("target", ""))
	var index: int = _panel_index_for(target_id, false)
	var amount: int = int(event.get("amount", 0))
	var blocked: int = int(event.get("blocked", 0))
	var overflow: int = int(event.get("overflow", 0))
	if index >= 0:
		_panels[index].flash_hit()
		enemy_reaction.emit(index, REACTION_HIT)
		if Settings.reduced_motion:
			Juice.outline(_panels[index], Tokens.SEM_DAMAGE, 60)
		var text: String = str(amount)
		var color: Color = Tokens.SEM_DAMAGE
		var font_size: int = Tokens.TYPE_DISPLAY_XL
		if amount == 0 and blocked > 0:
			text = tr("COMBAT_ARMOR_BLOCKED") % blocked
			color = Tokens.SEM_SHIELD
			font_size = Tokens.TYPE_TITLE
		elif overflow > 0:
			color = Tokens.SEM_OVERFLOW
		_pop(_panels[index], text, color, font_size)
		if world != null:
			var actor: EnemyActor = world.call("actor_at", index, target_id) as EnemyActor
			if actor != null:
				actor.hit_reaction()
	if overflow > 0:
		_overflow_arrow(index, overflow)


func _overflow_arrow(from_index: int, amount: int) -> void:
	var next_index: int = -1
	var enemies: Array = _view.get("enemies", []) as Array
	for i: int in range(enemies.size()):
		if i <= from_index:
			continue
		if int((enemies[i] as Dictionary).get("hp", 0)) > 0:
			next_index = i
			break
	var anchor: Control = _panels[next_index] if next_index >= 0 and next_index < _panels.size() else _receipt_panel
	_pop(anchor, "%s %d" % [Art.ui_icon_glyph(&"overflow"), amount], Tokens.SEM_OVERFLOW, Tokens.TYPE_TITLE)


func _panel_index_for(enemy_id: String, already_dead: bool) -> int:
	var enemies: Array = _view.get("enemies", []) as Array
	if already_dead:
		for i: int in range(enemies.size()):
			var enemy: Dictionary = enemies[i] as Dictionary
			if String(enemy.get("id", "")) == enemy_id and int(enemy.get("hp", 0)) <= 0:
				return i
		return -1
	return EventPlayer.target_index(_view, enemy_id)


func _pop(anchor: Control, text: String, color: Color, font_size: int) -> void:
	if anchor == null or not anchor.is_inside_tree():
		return
	Juice.number_pop(_fx_layer, text, color, anchor.get_global_rect().get_center(), font_size)


func _apply_view_to_panels() -> void:
	var enemies: Array = _view.get("enemies", []) as Array
	for i: int in range(mini(_panels.size(), enemies.size())):
		var enemy: Dictionary = enemies[i] as Dictionary
		_panels[i].update_vitals(
			int(enemy.get("hp", 0)),
			int(enemy.get("armor", 0)),
			int(enemy.get("burn", 0)),
			int(enemy.get("poison", 0)),
		)
		if world != null and int(enemy.get("hp", 0)) <= 0:
			var actor: EnemyActor = world.call("actor_at", i, String(enemy.get("id", ""))) as EnemyActor
			if actor != null:
				actor.set_alive(false)
	_hp_label.text = "◖ %d/%d" % [int(_view.get("player_hp", 0)), state.player_max_hp]
	_hp_bar.value = clampi(int(_view.get("player_hp", 0)), 0, state.player_max_hp)
	_charge_label.text = "%s %s" % [
		Art.ui_icon_glyph(&"charge"),
		Tokens.translate_or("COMBAT_CHARGE_PILL", "Charge %d") % int(_view.get("charge", 0)),
	]
	_ward_label.text = Tokens.translate_or("COMBAT_WARD_PILL", "Ward %d") % int(_view.get("ward", 0))


func _on_playback_finished() -> void:
	var result: ResolveResult = _pending_result
	_pending_result = null
	if result == null:
		return
	_tap_catcher.visible = false
	state = result.state_after

	# Träningshjulen i våning 0: spelaren kan inte dö, och vi säger det rakt ut
	# (§B.2). Att ljuga om det vore värre än att dö.
	if state.player_dead and _tutorial_room >= 0:
		state.player_dead = false
		state.player_hp = Tutorial.REVIVE_HP
		var line: Array[String] = Tutorial.cart_line()
		_pop(_hp_label, Tokens.translate_or(line[0], line[1]), Tokens.SEM_HEAL, Tokens.TYPE_BODY)
		_view = EventPlayer.view_from_state(state)

	if state.player_dead:
		round_finished.emit(state, result)
		combat_finished.emit(false, state)
		return
	if state.is_won():
		round_finished.emit(state, result)
		combat_finished.emit(true, state)
		return

	# All slump för nästa runda dras här, FÖRE nästa bekräftelse (§6.4).
	state = Resolver.advance(state, _rng)
	if _tutorial_room >= 0:
		Tutorial.force_dice(state, _tutorial_room)
		Tutorial.apply_limits(state, _tutorial_room)
		Tutorial.apply_intents(state, _tutorial_room)
	round_finished.emit(state, result)
	_refresh_room_bindings()
	begin_round()


## Fiendepanelerna binds om efter en runda: intents har bytts av
## [method Resolver.advance] och måste läsas om.
func _refresh_room_bindings() -> void:
	for i: int in range(mini(_panels.size(), state.enemies.size())):
		_panels[i].bind(state.enemies[i], _ordinals[i] if i < _ordinals.size() else 0)
