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

var _panels: Array[EnemyPanel] = []
var _slot_views: Array[SlotView] = []
var _die_views: Array[DieView] = []
var _view: Dictionary = {}
var _preview: ResolveResult = null
var _resolving: bool = false
var _chain_step: int = 0
var _pending_result: ResolveResult = null


func enter(ctx: Dictionary) -> void:
	state = ctx.get("state", null) as CombatState
	_rng = ctx.get("rng", null) as Rng
	_node = ctx.get("node", {}) as Dictionary
	_style()
	_undo_button.pressed.connect(undo)
	_reroll_button.pressed.connect(reroll)
	_confirm_button.pressed.connect(confirm)
	_tap_catcher.gui_input.connect(_on_tap_during_playback)
	_player.event_started.connect(_on_event)
	_player.finished.connect(_on_playback_finished)
	_build_room()
	begin_round()


func _style() -> void:
	$Margin.add_theme_constant_override("margin_left", Tokens.dpi(Tokens.SCREEN_MARGIN))
	$Margin.add_theme_constant_override("margin_right", Tokens.dpi(Tokens.SCREEN_MARGIN))
	$Margin.add_theme_constant_override("margin_top", Tokens.dpi(Tokens.SCREEN_MARGIN))
	$Margin.add_theme_constant_override("margin_bottom", Tokens.dpi(Tokens.SCREEN_MARGIN))
	$Margin/Column.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_1))
	_enemy_zone.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))
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
	_undo_button.custom_minimum_size.x = Tokens.dp(Tokens.TOUCH_MIN + 24)
	_reroll_button.custom_minimum_size.x = Tokens.dp(Tokens.TOUCH_MIN + 36)
	_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(_confirm_button, Tokens.TYPE_BODY_L, Tokens.SURFACE_PIT, Tokens.BUTTON_PRIMARY_HEIGHT)
	var primary: StyleBoxFlat = Tokens.box(Tokens.CHALK_100, true, Tokens.STROKE_REG)
	primary.bg_color = Tokens.CHALK_100
	_confirm_button.add_theme_stylebox_override("normal", primary)
	_confirm_button.add_theme_stylebox_override("hover", primary)
	_confirm_button.add_theme_stylebox_override("pressed", primary)


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
	Juice.sfx("die_place", Juice.chain_pitch(slot_index))
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
	Juice.sfx("undo", 0.8)


func reroll() -> void:
	if _resolving or not Reroll.can_afford(state):
		return
	state = Reroll.apply(state, _placement, _rng, _locked_ids)
	_view = EventPlayer.view_from_state(state)
	_refresh_all()
	Juice.sfx("reroll", 1.0)
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
	Juice.sfx("confirm", 1.0)
	Juice.haptic(Haptics.Level.MEDIUM)
	_pending_result = result
	_player.play(result.events)


func _on_tap_during_playback(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_player.nudge()


## Hoppar direkt till slutläget. Används av smoke-testet och av dubbeltapp.
func skip_playback() -> void:
	if _player.is_playing():
		_player.skip_to_end()


func is_resolving() -> bool:
	return _resolving


func _on_event(event: Dictionary, duration: float) -> void:
	EventPlayer.apply_event(_view, event)
	_apply_view_to_panels()
	var event_type: String = String(event.get("t", ""))
	match event_type:
		"die_activated":
			var slot: int = int(event.get("slot", 0))
			if slot < _slot_views.size():
				Juice.pulse(_slot_views[slot], 1.18, maxf(0.08, duration))
			Juice.sfx("die_activate", Juice.chain_pitch(_chain_step))
			Juice.haptic(Haptics.Level.LIGHT)
			_chain_step += 1
		"combo_formed":
			var multiplier: int = int(event.get("multiplier", 1))
			for slot_value: Variant in event.get("slots", []) as Array:
				var index: int = int(slot_value)
				if index < _slot_views.size():
					Juice.blink(_slot_views[index], Tokens.multiplier_color(multiplier), 0.26)
			_pop(_preview_panel, "×%d %s" % [multiplier, String(event.get("kind", ""))],
				Tokens.multiplier_color(multiplier), Tokens.multiplier_size(multiplier))
			Juice.sfx("combo", Juice.chain_pitch(_chain_step, multiplier))
			Juice.haptic(Haptics.Level.MEDIUM if multiplier < 8 else Haptics.Level.HEAVY)
		"house_bonus":
			_pop(_preview_panel, tr("COMBAT_HOUSE") % int(event.get("factor", 2)), Tokens.SEM_CHARGE, Tokens.TYPE_DISPLAY_L)
			Juice.sfx("house", 1.5)
			Juice.haptic(Haptics.Level.HEAVY)
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
			Juice.sfx("enemy_killed", 0.8)
			Juice.haptic(Haptics.Level.HEAVY)
		"ward_gained":
			_pop(_ward_label, "+%d ⬟" % int(event.get("amount", 0)), Tokens.SEM_SHIELD, Tokens.TYPE_TITLE)
		"charge_stored":
			_pop(_charge_label, "+%d ⬤" % int(event.get("amount", 0)), Tokens.SEM_CHARGE, Tokens.TYPE_HEADING)
			Juice.sfx("charge", 1.2)
		"charge_applied":
			_pop(_charge_label, tr("COMBAT_CHARGE_SPENT") % int(event.get("amount", 0)), Tokens.SEM_CHARGE, Tokens.TYPE_TITLE)
		"enemy_attacks", "enemy_thorns", "player_damaged":
			var damage: int = int(event.get("amount", 0))
			if damage > 0:
				_pop(_hp_label, "-%d" % damage, Tokens.SEM_BLOOD, Tokens.TYPE_DISPLAY_L)
				Juice.shake(self, 4.0, 0.16)
				Juice.haptic(Haptics.Level.MEDIUM)
		"heal":
			_pop(_hp_label, "+%d" % int(event.get("amount", 0)), Tokens.SEM_HEAL, Tokens.TYPE_TITLE)
		"die_cracked":
			_pop(_preview_panel, tr("COMBAT_DIE_CRACKED"), Tokens.SEM_BLOOD, Tokens.TYPE_DISPLAY_L)
			Juice.haptic(Haptics.Level.HEAVY)
		"player_died":
			_pop(_hp_label, tr("COMBAT_PLAYER_DEAD"), Tokens.SEM_BLOOD, Tokens.TYPE_DISPLAY_XL)
		"round_end":
			_refresh_hud()


func _on_damage(event: Dictionary) -> void:
	var target_id: String = String(event.get("target", ""))
	var index: int = _panel_index_for(target_id, false)
	var amount: int = int(event.get("amount", 0))
	var blocked: int = int(event.get("blocked", 0))
	var overflow: int = int(event.get("overflow", 0))
	if index >= 0:
		_panels[index].flash_hit()
		var text: String = str(amount)
		var color: Color = Tokens.SEM_DAMAGE
		if amount == 0 and blocked > 0:
			text = tr("COMBAT_ARMOR_BLOCKED") % blocked
			color = Tokens.SEM_SHIELD
		elif overflow > 0:
			color = Tokens.SEM_OVERFLOW
		_pop(_panels[index], text, color, Tokens.TYPE_DISPLAY_XL)
		if world != null:
			var actor: EnemyActor = world.call("actor_at", index, target_id) as EnemyActor
			if actor != null:
				actor.hit_reaction()
	Juice.sfx("hit", clampf(1.2 - float(amount) / 200.0, 0.65, 1.2))
	Juice.haptic(Haptics.Level.MEDIUM)


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
