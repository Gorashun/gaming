class_name CombatScreen
extends GameScreen
## Stridsskärmen. Fiendezon överst (läs-endast), fem slots i mitten, tärningar
## och knappar i tumzonen – UI_GUIDE §2.9 och wireframe_combat.html.
##
## [b]Den heliga regeln (GAME_DESIGN §6) är hela skärmens arkitektur:[/b] varje
## gång placeringen ändras kör vi en riktig [method Resolver.resolve] på en KOPIA
## och visar dess utfall. Vid bekräftelse körs [method Resolver.resolve] igen med
## identiska argument, och i debug asserterar vi att loggen är byte-identisk.
## Förhandsvisningen är alltså inte en uppskattning – den ÄR utfallet.
##
## Skärmen innehåller ingen regel. Skada, combos, Charge, Ward och omkast räknas
## av [Resolver] och [Reroll]; här ritas bara resultatet.

## En runda är resolvad, uppspelad och tillståndet är redo att sparas.
## [param state] är vid rundans BÖRJAN (efter [method Resolver.advance]) när
## striden fortsätter – autosave får aldrig ligga mitt i en kedja (§1).
signal round_finished(state: CombatState, result: ResolveResult)
## Striden är slut. [param won] är false när spelaren dog.
signal combat_finished(won: bool, state: CombatState)

## Tärningsplaceringar som lämnar slots tomma är tillåtna och ibland korrekta
## (GAME_DESIGN §7 fråga 4: Charge-banken kräver det).
const ALLOW_EMPTY_SLOTS: bool = true
## Bredden på hjältens kolumn i fiendezonen, i dp. Smulare än cellens 64 dp:
## figuren är ~24 px bred av sina 48, och resten av cellen får gärna sticka ut
## över parallaxen. Varje dp här tas från fiendepanelernas textbredd.
const HERO_SLOT_WIDTH: int = 40

@onready var _hp_label: Label = $Margin/Column/TopBar/HpLabel
@onready var _hp_bar: ProgressBar = $Margin/Column/TopBar/HpBar
@onready var _room_label: Label = $Margin/Column/TopBar/RoomLabel
@onready var _charge_label: Label = $Margin/Column/TopBar/ChargeLabel
@onready var _ward_label: Label = $Margin/Column/TopBar/WardLabel
@onready var _enemy_zone: HBoxContainer = $Margin/Column/EnemyZone
@onready var _preview_panel: PanelContainer = $Margin/Column/PreviewPanel
@onready var _total_label: Label = $Margin/Column/PreviewPanel/PreviewColumn/TotalLabel
@onready var _total_caption: Label = $Margin/Column/PreviewPanel/PreviewColumn/TotalCaption
@onready var _chain_label: Label = $Margin/Column/PreviewPanel/PreviewColumn/ChainLabel
@onready var _slot_row: HBoxContainer = $Margin/Column/SlotRow
@onready var _tray: HBoxContainer = $Margin/Column/Tray
@onready var _undo_button: Button = $Margin/Column/Actions/UndoButton
@onready var _reroll_button: Button = $Margin/Column/Actions/RerollButton
@onready var _confirm_button: Button = $Margin/Column/Actions/ConfirmButton
@onready var _fx_layer: Control = $FxLayer
@onready var _tap_catcher: Control = $TapCatcher
@onready var _player: EventPlayer = $EventPlayer

var state: CombatState = null
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
var _panels: Array[EnemyPanel] = []
var _slot_views: Array[SlotView] = []
var _die_views: Array[DieView] = []
var _view: Dictionary = {}
var _preview: ResolveResult = null
var _resolving: bool = false
var _chain_step: int = 0
var _pending_result: ResolveResult = null
## Runnens största kedja hittills. Kommer från [GameController] och avgör när
## "NEW BEST" visas.
var _best_chain: int = 0
## Bossintron körs. Skärmen tar ingen input under tiden.
var _intro_active: bool = false
var _intro_tween: Tween = null
var _intro_nodes: Array[Node] = []
## Röd skärmkantsblixt (skapas i [method _style], lever i FxLayer).
var _edge: Panel = null


func enter(ctx: Dictionary) -> void:
	state = ctx.get("state", null) as CombatState
	_rng = ctx.get("rng", null) as Rng
	_node = ctx.get("node", {}) as Dictionary
	_best_chain = int(ctx.get("best_chain", 0))
	_style()
	_undo_button.pressed.connect(undo)
	_reroll_button.pressed.connect(reroll)
	_confirm_button.pressed.connect(confirm)
	_tap_catcher.gui_input.connect(_on_tap_during_playback)
	_player.event_started.connect(_on_event)
	_player.finished.connect(_on_playback_finished)
	_build_room()
	begin_round()
	if RunFlow.is_boss(_node) and state.round_number <= 1:
		play_boss_intro()


func _style() -> void:
	$Margin.add_theme_constant_override("margin_left", Tokens.dpi(Tokens.SCREEN_MARGIN))
	$Margin.add_theme_constant_override("margin_right", Tokens.dpi(Tokens.SCREEN_MARGIN))
	$Margin.add_theme_constant_override("margin_top", Tokens.dpi(Tokens.SCREEN_MARGIN))
	$Margin.add_theme_constant_override("margin_bottom", Tokens.dpi(Tokens.SCREEN_MARGIN))
	$Margin/Column.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_1))
	_enemy_zone.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_1))
	_slot_row.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))
	_tray.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))
	$Margin/Column/Actions.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))
	$Margin/Column/TopBar.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))

	_preview_panel.add_theme_stylebox_override("panel", Tokens.box(Tokens.SURFACE_LINE, true, Tokens.STROKE_HAIR))
	$Margin/Column/PreviewPanel/PreviewColumn.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_1))

	# Toppfältets etiketter får INTE klippas: med clip_text blir deras minsta
	# bredd noll, HP-baren äter hela raden och siffrorna försvinner.
	_apply_label(_hp_label, Tokens.TYPE_CAPTION, Tokens.SEM_BLOOD, false)
	_apply_label(_room_label, Tokens.TYPE_CAPTION, Tokens.CHALK_300, false)
	_apply_label(_charge_label, Tokens.TYPE_CAPTION, Tokens.SEM_CHARGE, false)
	_apply_label(_ward_label, Tokens.TYPE_CAPTION, Tokens.SEM_SHIELD, false)
	_apply_label(_total_label, Tokens.TYPE_DISPLAY_L, Tokens.CHALK_100)
	_apply_label(_total_caption, Tokens.TYPE_CAPTION, Tokens.CHALK_500)
	_apply_label(_chain_label, Tokens.TYPE_LABEL, Tokens.CHALK_300)

	_hp_bar.custom_minimum_size = Vector2(Tokens.dp(48), Tokens.dp(10))
	var bar_bg: StyleBoxFlat = StyleBoxFlat.new()
	bar_bg.bg_color = Tokens.SURFACE_RAISED
	var bar_fill: StyleBoxFlat = StyleBoxFlat.new()
	bar_fill.bg_color = Tokens.SEM_BLOOD
	_hp_bar.add_theme_stylebox_override("background", bar_bg)
	_hp_bar.add_theme_stylebox_override("fill", bar_fill)

	_style_button(_undo_button, Tokens.TYPE_LABEL, Tokens.CHALK_300, Tokens.BUTTON_SECONDARY_HEIGHT)
	_style_button(_reroll_button, Tokens.TYPE_LABEL, Tokens.SEM_FROST, Tokens.BUTTON_SECONDARY_HEIGHT)
	# Sekundärknapparna hålls precis över träffytans 48 dp. Varje dp de tar är
	# en bokstav mindre på primärknappen, som måste rymma både verbet och
	# kedjans summa på svenska ("BEKRÄFTA KEDJA · 28").
	_undo_button.custom_minimum_size.x = Tokens.dp(Tokens.TOUCH_MIN + 20)
	_reroll_button.custom_minimum_size.x = Tokens.dp(Tokens.TOUCH_MIN + 32)
	_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(_confirm_button, Tokens.TYPE_BODY, Tokens.SURFACE_PIT, Tokens.BUTTON_PRIMARY_HEIGHT)
	var primary: StyleBoxFlat = Tokens.box(Tokens.CHALK_100, true, Tokens.STROKE_REG)
	primary.bg_color = Tokens.CHALK_100
	_confirm_button.add_theme_stylebox_override("normal", primary)
	_confirm_button.add_theme_stylebox_override("hover", primary)
	_confirm_button.add_theme_stylebox_override("pressed", primary)

	# Krit-UI (UI_GUIDE §1A, riktning A): panelen, knapparna och den stora
	# siffran ritas genom chalk.gdshader. Pixelkonsten inuti sloten och brickan
	# rörs aldrig – shadern ligger på Control-noden, inte på dess barn (§8.4).
	ChalkFx.apply(_preview_panel, ChalkFx.PANEL)
	ChalkFx.apply(_total_label, ChalkFx.DISPLAY)
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

	# Paus: enda vägen till inställningarna mitt i en run (UI_GUIDE §2.9,
	# ikonknapp 48 dp). Modalen läggs ovanpå av GameController, så rundan och
	# placeringen står kvar orörda bakom den.
	var pause_button: Button = Button.new()
	pause_button.name = "PauseButton"
	pause_button.text = "⚙"
	_style_button(pause_button, Tokens.TYPE_BODY, Tokens.CHALK_300, Tokens.TOUCH_MIN)
	pause_button.custom_minimum_size = Vector2(Tokens.dp(Tokens.TOUCH_MIN), Tokens.dp(Tokens.TOUCH_MIN))
	pause_button.tooltip_text = Tokens.translate_or("SETTINGS_TITLE", "Settings")
	pause_button.pressed.connect(_open_settings)
	ChalkFx.apply(pause_button, ChalkFx.BUTTON)
	$Margin/Column/TopBar.add_child(pause_button)


static func _apply_label(label: Label, font_size: int, color: Color, clip: bool = true) -> void:
	label.add_theme_font_size_override("font_size", Tokens.dpi(font_size))
	label.add_theme_color_override("font_color", color)
	# Utan clip_text blir textens bredd containerns minsta bredd och hela
	# kolumnen växer utanför skärmen. Gäller inte etiketter som radbryter.
	if clip and label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		label.clip_text = true


static func _style_button(button: Button, font_size: int, color: Color, height: int) -> void:
	# Samma fälla som med etiketterna: utan clip_text blir knapptextens bredd
	# knappens minsta bredd, och raden OMKAST + ÅNGRA + BEKRÄFTA KEDJA · 28
	# tvingar hela kolumnen bredare än skärmen.
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
	for panel: EnemyPanel in _panels:
		panel.queue_free()
	_panels.clear()
	if _hero_slot != null:
		_hero_slot.queue_free()
	# Smeden står till vänster om fienderna, som i mockupen. Platsen reserveras
	# i krit-UI:t så att panelerna inte lägger sig ovanpå figuren; själva
	# paperdollen ritas i World-lagret av CombatWorld.
	_hero_slot = Control.new()
	_hero_slot.name = "HeroSlot"
	_hero_slot.custom_minimum_size = Vector2(Tokens.dp(HERO_SLOT_WIDTH), 0.0)
	_hero_slot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_hero_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemy_zone.add_child(_hero_slot)
	for enemy: Enemy in state.enemies:
		var panel: EnemyPanel = EnemyPanel.new()
		_enemy_zone.add_child(panel)
		panel.bind(enemy)
		_panels.append(panel)

	for slot_view: SlotView in _slot_views:
		slot_view.queue_free()
	_slot_views.clear()
	for i: int in range(state.board.size()):
		var slot_view: SlotView = SlotView.new()
		_slot_row.add_child(slot_view)
		slot_view.tapped.connect(_on_slot_tapped)
		slot_view.die_dropped.connect(_on_die_dropped)
		_slot_views.append(slot_view)

	for die_view: DieView in _die_views:
		die_view.queue_free()
	_die_views.clear()
	for i: int in range(state.dice.size()):
		var die_view: DieView = DieView.new()
		_tray.add_child(die_view)
		die_view.tapped.connect(_on_die_tapped)
		_die_views.append(die_view)

	if world != null:
		world.call("build", state.enemies, Tokens.dp(34))
	# Positionerna kan först läsas när containrarna har gjort sin layout.
	call_deferred("_sync_world")


func _sync_world() -> void:
	if world == null:
		return
	await get_tree().process_frame
	if world == null or not is_instance_valid(world):
		return
	# Bandet (parallax + golv) kan först byggas när containrarna har gjort sin
	# layout: det är fiendezonens rect som avgör var horisonten ligger.
	# Golvlinjen är fiendepanelernas konsthåll-underkant, inte bandets botten:
	# fienderna ska stå PÅ golvet i det genomskinliga hålet, inte bakom
	# kritplattan under det.
	var floor_y: float = _enemy_zone.get_global_rect().end.y
	if not _panels.is_empty():
		floor_y = _panels[0].art_bottom()
	world.call("set_band", _enemy_zone.get_global_rect(), floor_y, state.relics)
	if _hero_slot != null and _hero_slot.is_inside_tree():
		world.call("place_hero", _hero_slot.get_global_rect().get_center())
	for i: int in range(_panels.size()):
		world.call("place", i, _panels[i].enemy_id, _panels[i].anchor_point())


## Förbereder en runda: tom placering, tom historik, färsk förhandsvisning.
func begin_round() -> void:
	_placement = CombatState.empty_placement(state.board.size())
	_history.clear()
	_selected_die = -1
	_chain_step = 0
	_resolving = false
	_tap_catcher.visible = false
	_view = EventPlayer.view_from_state(state)
	_refresh_all()


func _refresh_all() -> void:
	_refresh_hud()
	_refresh_slots()
	_refresh_tray()
	_refresh_preview()


func _refresh_hud() -> void:
	_hp_label.text = "◖ %d/%d" % [state.player_hp, state.player_max_hp]
	_hp_bar.max_value = maxi(1, state.player_max_hp)
	_hp_bar.value = clampi(state.player_hp, 0, state.player_max_hp)
	var room_key: String = "COMBAT_BOSS_ROUND" if RunFlow.is_boss(_node) else "COMBAT_ROOM_ROUND"
	_room_label.text = tr(room_key) % [int(_node.get("room", 1)), state.round_number]
	_charge_label.text = "⬤%d/%d" % [state.charge, Rules.CHARGE_CAP]
	_ward_label.text = "⬟ %d" % state.ward
	_total_caption.text = tr("COMBAT_TOTAL_CAPTION") % state.dice.size()
	_reroll_button.text = tr("COMBAT_REROLL") % state.rerolls_left
	_undo_button.text = tr("COMBAT_UNDO")
	_reroll_button.disabled = _resolving or not Reroll.can_afford(state) or Reroll.rerollable_indices(state, _placement, _locked_ids).is_empty()
	_undo_button.disabled = _resolving or _history.is_empty()


func _refresh_slots() -> void:
	for i: int in range(_slot_views.size()):
		var die: Die = null
		if _placement[i] >= 0:
			die = state.dice[_placement[i]]
		_slot_views[i].bind(i, state.board.slots[i], die)
		_slot_views[i].set_highlight(_selected_die >= 0 and state.board.slots[i].blocked == false)


func _refresh_tray() -> void:
	for i: int in range(_die_views.size()):
		var slot_of_die: int = -1
		for s: int in range(_placement.size()):
			if _placement[s] == i:
				slot_of_die = s
		_die_views[i].bind(i, state.dice[i], slot_of_die, state.stolen.has(state.dice[i].id))
		_die_views[i].set_selected(i == _selected_die)


## Kör hela resolvern på en kopia och visar dess exakta utfall.
func _refresh_preview() -> void:
	_preview = Resolver.resolve(state, _placement)
	var values: Array = []
	var occupied: Array = []
	var multipliers: Array = []
	multipliers.resize(state.board.size())
	multipliers.fill(1)

	for event: Dictionary in _preview.events:
		match String(event.get("t", "")):
			"value_pass_done":
				values = event.get("values", []) as Array
				occupied = event.get("occupied", []) as Array
			"combo_formed":
				for slot_value: Variant in event.get("slots", []) as Array:
					multipliers[int(slot_value)] = int(event.get("multiplier", 1))
			"house_bonus":
				var after: Array = event.get("multipliers_after", []) as Array
				for i: int in range(mini(after.size(), multipliers.size())):
					multipliers[i] = int(after[i])

	for i: int in range(_slot_views.size()):
		var value: int = int(values[i]) if i < values.size() else 0
		var is_occupied: bool = bool(occupied[i]) if i < occupied.size() else false
		_slot_views[i].set_preview(value, int(multipliers[i]), is_occupied)

	var total: int = MetaScore.chain_damage(_preview.events)
	_total_label.text = str(total)
	_total_label.add_theme_color_override("font_color", Tokens.CHALK_100 if total > 0 else Tokens.CHALK_500)
	_chain_label.text = chain_text(_preview.events, state.enemies)
	# Förhandsvisningen står färdigskriven; det är UPPSPELNINGEN som drar
	# strecken (se _draw_chain_text).
	_chain_label.visible_ratio = 1.0

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
		_confirm_button.text = tr("COMBAT_CONFIRM_CHAIN") % total


## Kedjetexten under totalen, som i wireframen:
## [code]34 → Grottråtta ↳ 14 överflöd → Vrakvakt[/code].
## Ett nytt segment per skadeinstans; samma slot två gånger i rad = överflöd.
static func chain_text(events: Array[Dictionary], enemies: Array[Enemy]) -> String:
	var names: Dictionary = {}
	for enemy: Enemy in enemies:
		names[enemy.id] = Tokens.translate_or(Content.enemy_key(enemy.id), enemy.display_name)

	var segments: PackedStringArray = PackedStringArray()
	var previous_slot: int = -99
	for event: Dictionary in events:
		if String(event.get("t", "")) != "damage_dealt":
			continue
		var amount: int = int(event.get("amount", 0))
		if amount <= 0:
			continue
		var target: String = String(names.get(String(event.get("target", "")), event.get("target", "")))
		var slot: int = int(event.get("slot", -1))
		if slot == previous_slot:
			segments.append(Tokens.translate("COMBAT_CHAIN_OVERFLOW") % [amount, target])
		else:
			segments.append(Tokens.translate("COMBAT_CHAIN_HIT") % [amount, target])
		previous_slot = slot
		if segments.size() >= 3:
			segments.append("…")
			break
	if segments.is_empty():
		return Tokens.translate("COMBAT_CHAIN_EMPTY")
	return " ".join(segments)


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
	_view = EventPlayer.view_from_state(state)
	_refresh_all()
	Juice.ui_tap(1.25)
	Juice.haptic(Haptics.Level.MEDIUM)


func _on_die_tapped(die_index: int) -> void:
	if _resolving:
		return
	# Tapp på en placerad tärning plockar tillbaka den (UI_GUIDE §4.3).
	for i: int in range(_placement.size()):
		if _placement[i] == die_index:
			clear_slot(i)
			return
	_selected_die = -1 if _selected_die == die_index else die_index
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
	_tap_catcher.visible = true
	_confirm_button.disabled = true
	_undo_button.disabled = true
	_reroll_button.disabled = true
	Juice.ui_tap(0.9)
	Juice.haptic(Haptics.Level.MEDIUM)
	_pending_result = result
	_draw_chain_text(_player.play(result.events))


## Kedjetexten "dras" med kritan vänster→höger medan kedjan spelas upp
## (UI_GUIDE §1A: strecken ritas ut i realtid, designprincip 2 – synlig
## kausalitet). [param timeline_ms] är uppspelningens längd, så texten är
## färdigdragen ungefär när sista slaget landar.
func _draw_chain_text(timeline_ms: int) -> void:
	var seconds: float = clampf(float(timeline_ms) / 1000.0 * 0.6, 0.2, 1.2)
	_chain_label.visible_ratio = 0.0
	var tween: Tween = _chain_label.create_tween()
	tween.tween_property(_chain_label, "visible_ratio", 1.0, seconds)


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


## True medan skärmen inte tar emot spelbeslut: under uppspelning ELLER under
## bossintrot. Rökprovet väntar på den här.
func is_resolving() -> bool:
	return _resolving or _intro_active


func is_intro_active() -> bool:
	return _intro_active


func _open_settings() -> void:
	Juice.ui_tap(1.0)
	if controller != null and controller.has_method("open_settings"):
		controller.call("open_settings")


# ---------------------------------------------------------------------------
# Bossintro (UI_GUIDE §3: "ögonblicket innan")
# ---------------------------------------------------------------------------

## Namnskylt + kort mörkläggning, högst [constant BOSS_INTRO_MS] ms, och den
## går alltid att tappa bort. Intron ändrar ingenting i striden: den är helt och
## hållet presentation och kan hoppas över utan att ett event går förlorat.
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


## Tapp under intron hoppar direkt till striden (UI_GUIDE §5.9-principen:
## ett tapp ska alltid göra spelet snabbare, aldrig ingenting).
func skip_boss_intro() -> void:
	if _intro_active:
		_end_boss_intro()


func _boss_name() -> String:
	var enemy: Enemy = state.enemies[0] if not state.enemies.is_empty() else null
	if enemy == null:
		return Tokens.translate_or("COMBAT_BOSS", "BOSS")
	return Tokens.translate_or(Content.enemy_key(enemy.id), enemy.display_name).to_upper()


## Det VISUELLA för ett event. Ljud, haptik, hit-stop och skärmskak spelas av
## [EventPlayer] själv ur [method EventPlayer.feedback] – den delen av specen är
## nodoberoende och hör inte hemma i en skärm.
func _on_event(event: Dictionary, duration: float) -> void:
	EventPlayer.apply_event(_view, event)
	_apply_view_to_panels()
	var event_type: String = String(event.get("t", ""))
	match event_type:
		"die_activated":
			var slot: int = int(event.get("slot", 0))
			if slot < _slot_views.size():
				# Pulsen ligger på den riktiga tärningssprajten i sloten och i
				# brickan, inte på en platshållarruta (UI_GUIDE §5.1).
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
			# Badgen växer med multiplikatorn (UI_GUIDE §2.5: 24/28/34/40 dp) och
			# siffran står alltid utskriven, så färgen är dekor (§6.2).
			_pop(_preview_panel, "×%d %s" % [multiplier, String(event.get("kind", ""))],
				Tokens.multiplier_color(multiplier), Tokens.multiplier_size(multiplier))
		"house_bonus":
			_pop(_preview_panel, tr("COMBAT_HOUSE") % int(event.get("factor", 2)), Tokens.SEM_CHARGE, Tokens.TYPE_DISPLAY_L)
		"damage_dealt":
			_on_damage(event)
		"enemy_killed":
			var killed: int = _panel_index_for(String(event.get("target", "")), true)
			if killed >= 0:
				_panels[killed].flash_death()
				if world != null:
					var actor: EnemyActor = world.call("actor_at", killed, String(event.get("target", ""))) as EnemyActor
					if actor != null:
						actor.death_reaction()
		"ward_gained":
			_pop(_ward_label, "+%d ⬟" % int(event.get("amount", 0)), Tokens.SEM_SHIELD, Tokens.TYPE_TITLE)
		"charge_stored":
			_pop(_charge_label, "+%d ⬤" % int(event.get("amount", 0)), Tokens.SEM_CHARGE, Tokens.TYPE_HEADING)
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


## Sprickan, UI_GUIDE §5.6: ett medvetet mönsterbrott. Ordet ligger kvar,
## sloten blixtrar och [EventPlayer] har redan lagt hit-stop och skak på den.
func _on_die_cracked(event: Dictionary) -> void:
	_pop(_preview_panel, tr("COMBAT_DIE_CRACKED"), Tokens.SEM_BLOOD, Tokens.TYPE_DISPLAY_L)
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


## Skärmkantens röda blixt när spelaren tar skada (UI_GUIDE §5: fiendens svar
## ska kännas på kroppen även om man inte tittar på HP-siffran).
func _edge_flash(color: Color) -> void:
	if _edge == null:
		return
	_edge.modulate = Color(color, 1.0)
	_edge.visible = true
	var tween: Tween = _edge.create_tween()
	tween.tween_property(_edge, "modulate:a", 0.0, Tokens.MOTION_BASE)
	tween.tween_callback(func() -> void: _edge.visible = false)


## Laddningsräknaren lyser upp när ögon bankas (UI_GUIDE §5.4).
func _charge_glow() -> void:
	Juice.blink(_charge_label, Tokens.SEM_CHARGE, Tokens.MOTION_BASE)
	Juice.pulse(_charge_label, 1.2, Tokens.MOTION_QUICK)


## "NEW BEST" när rundans kedja slår runnens rekord. Rekordet kommer från
## [GameController] (det gäller hela runnen, inte striden) och uppdateras här
## lokalt så att två rekordrundor i rad inte båda firas.
func _check_record() -> void:
	if _pending_result == null:
		return
	var chain: int = MetaScore.chain_damage(_pending_result.events)
	if chain <= 0 or chain <= _best_chain:
		return
	_best_chain = chain
	_pop(_total_label, Tokens.translate_or("COMBAT_NEW_BEST", "NEW BEST"), Tokens.SEM_CHARGE, Tokens.TYPE_DISPLAY_L)
	# Extra tonhöjd: rekordet ska höras över kedjans egen stegring.
	# Ingen egen rekord-cue i registret: kåkens klang en kvint över kedjans tak.
	Juice.sfx(EventPlayer.SFX_COMBO_HOUSE, 1.6)
	Juice.haptic(Haptics.Level.HEAVY)


## Smeden svingar när en tärning aktiveras. [method HeroFigure.strike] lägger
## kontakten 180 ms in, vilket sammanfaller med kedjestegets damage_dealt
## (PAPERDOLL §4, "Tidsbudget mot kedjan").
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


func _on_damage(event: Dictionary) -> void:
	var target_id: String = String(event.get("target", ""))
	var index: int = _panel_index_for(target_id, false)
	var amount: int = int(event.get("amount", 0))
	var blocked: int = int(event.get("blocked", 0))
	var overflow: int = int(event.get("overflow", 0))
	if index >= 0:
		_panels[index].flash_hit()
		if Settings.reduced_motion:
			# Ersätter pixelsprajtens vita blixt (UI_GUIDE §12.6), samma 60 ms.
			Juice.outline(_panels[index], Tokens.SEM_DAMAGE, 60)
		var text: String = str(amount)
		var color: Color = Tokens.SEM_DAMAGE
		# Siffran är display-xl (UI_GUIDE §5.3), men ORD är det inte: "ARMOR 2"
		# i 56 dp är bredare än skärmen och säger mindre än en siffra.
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


## Överflödet, UI_GUIDE §5.3: en pil från det fulla målet till nästa levande,
## med det KVARVARANDE värdet i överflödsfärgen. Pilen förklarar sig själv
## första gången (§7: "överflöd lärs ut av kritpilen").
func _overflow_arrow(from_index: int, amount: int) -> void:
	var next_index: int = -1
	var enemies: Array = _view.get("enemies", []) as Array
	for i: int in range(enemies.size()):
		if i <= from_index:
			continue
		if int((enemies[i] as Dictionary).get("hp", 0)) > 0:
			next_index = i
			break
	var anchor: Control = _panels[next_index] if next_index >= 0 and next_index < _panels.size() else _preview_panel
	_pop(anchor, "↳ %d" % amount, Tokens.SEM_OVERFLOW, Tokens.TYPE_TITLE)


## Panelindex för ett fiende-id. [param already_dead] väljer den första döda i
## stället för den första levande – se [method EventPlayer.target_index].
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
	_charge_label.text = "⬤%d/%d" % [int(_view.get("charge", 0)), Rules.CHARGE_CAP]
	_ward_label.text = "⬟ %d" % int(_view.get("ward", 0))


func _on_playback_finished() -> void:
	var result: ResolveResult = _pending_result
	_pending_result = null
	if result == null:
		return
	_tap_catcher.visible = false
	state = result.state_after

	if state.player_dead:
		round_finished.emit(state, result)
		combat_finished.emit(false, state)
		return
	if state.is_won():
		round_finished.emit(state, result)
		combat_finished.emit(true, state)
		return

	# All slump för nästa runda dras här, FÖRE nästa bekräftelse (§6.4), och
	# autosaven skrivs på den nya rundans början.
	state = Resolver.advance(state, _rng)
	round_finished.emit(state, result)
	begin_round()
