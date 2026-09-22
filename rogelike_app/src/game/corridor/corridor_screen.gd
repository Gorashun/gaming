class_name CorridorScreen
extends GameScreen
## Korridoren som skärm: [CorridorView] i 3D, krit-lagret ovanpå och en värd för
## stridsskärmen i de nedre 55 %.
##
## [b]Varför striden monteras HÄR och inte som ett eget skärmbyte:[/b]
## CORRIDOR_DESIGN §3.1 takt 4 säger att stridsskärmen ska glida upp underifrån
## [i]över korridorbilden[/i] och att korridoren ligger kvar synlig i toppen.
## Ett skärmbyte skulle riva ned 3D-världen, kasta bort kamerans plats i rutnätet
## och tvinga fram en ominladdning efter varje strid. Korridoren lever därför
## hela våningen igenom, och striden är ett barn i den.
##
## [b]Skärmen äger ingen regel.[/b] Den vidarebefordrar vyns signaler till
## [GameController] och monterar det controllern ber om. Fällans pris, mötets
## fiender och belöningens innehåll bestäms i [code]src/core/[/code].

# --- Vyns signaler, oförändrade (docs/CORRIDOR_DEV_NOTES.md §3) -------------
signal cell_changed(cell: Dictionary, map_state: Dictionary)
signal encounter_reached(node_id: String, enemy_ids: Array)
signal trap_choice(trap: Dictionary)
signal treasure_found(treasure: Dictionary)
signal boss_door_reached()
signal fate_door_reached()
signal floor_cleared(floor_index: int)
## Trappan upp ur tutorialkällaren.
signal stairs_reached()
signal character_sheet_requested()
signal settings_requested()

# --- Skärmens egna -----------------------------------------------------------
## Spelaren svarade på en fälla. [param index] är indexet i [code]trap.options[/code].
signal trap_answered(index: int)
## Bossdörrens enda tapp (§3.3). Aldrig automatiskt.
signal door_opened()
## Altarets enda sak är tagen (§3.5).
signal treasure_taken()
## Ett av de tre korten i korridoren valdes.
signal reward_chosen(option: Dictionary, target: Dictionary)

const COMBAT_SCENE: String = "res://src/game/combat/combat_screen.tscn"

@onready var _view: CorridorView = $View
@onready var _chips: EnemyChips = $Chips
@onready var _combat_host: Control = $CombatHost
@onready var _overlay: Control = $Overlay

var _combat: CombatScreen = null
var _prompt: CorridorPrompt = null
var _reward: CorridorReward = null
## Splitten den pågående striden fått. Krymper aldrig tillbaka mitt i en strid:
## en ruta som hoppar upp och ner medan spelaren placerar tärningar är värre än
## en som är lite för liten.
var _combat_split: float = CorridorView.SPLIT_COMBAT


func enter(ctx: Dictionary) -> void:
	$Background.color = CorridorView.FOG_COLOR
	_chips.view = _view
	_chips.top_margin = Tokens.dp(CorridorHud.HUD_HEIGHT_DP + CorridorHud.TRAIL_HEIGHT_DP)
	_build_overlay()

	_view.set_reduced_motion(bool(ctx.get("reduced_motion", false)))
	_view.set_speed_scale(float(ctx.get("speed_scale", 1.0)))
	_view.cell_changed.connect(func(cell: Dictionary, state: Dictionary) -> void:
		cell_changed.emit(cell, state))
	_view.encounter_reached.connect(func(node_id: String, ids: Array) -> void:
		encounter_reached.emit(node_id, ids))
	_view.trap_choice.connect(func(trap: Dictionary) -> void: trap_choice.emit(trap))
	_view.treasure_found.connect(func(t: Dictionary) -> void: treasure_found.emit(t))
	_view.boss_door_reached.connect(func() -> void: boss_door_reached.emit())
	_view.fate_door_reached.connect(func() -> void: fate_door_reached.emit())
	_view.floor_cleared.connect(func(floor_index: int) -> void: floor_cleared.emit(floor_index))
	_view.stairs_reached.connect(func() -> void: stairs_reached.emit())
	_view.character_sheet_requested.connect(func() -> void: character_sheet_requested.emit())
	_view.settings_requested.connect(func() -> void: settings_requested.emit())
	_view.help_requested.connect(_on_help_requested)
	_view.split_changed.connect(_on_split_changed)

	var map: CorridorMap = ctx.get("map", null) as CorridorMap
	if map == null:
		push_error("CorridorScreen: ingen CorridorMap i ctx")
		return
	_view.setup(map, {
		"hp": int(ctx.get("hp", 100)),
		"max_hp": int(ctx.get("max_hp", 100)),
		"room": int(ctx.get("room", 1)),
		"pips": int(ctx.get("pips", 0)),
	})
	_on_split_changed(_view.split_height())


func _build_overlay() -> void:
	_prompt = CorridorPrompt.new()
	_prompt.name = "Prompt"
	_prompt.visible = false
	_overlay.add_child(_prompt)
	# [b]set_anchors_PRESET sätter inte offsets[/b] (ARCHITECTURE, fallgropslistan).
	# Utan MINSIZE-varianten blev panelens rect inverterad och den växte till hela
	# skärmen. offset_top = offset_bottom ger noll höjd; GROW_DIRECTION_BEGIN
	# lägger sedan minsta höjden UPPÅT, så panelen blir exakt så hög som sin text.
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE)
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt.offset_left = Tokens.dp(Tokens.SCREEN_MARGIN)
	_prompt.offset_right = -Tokens.dp(Tokens.SCREEN_MARGIN)
	_prompt.offset_bottom = -Tokens.dp(CorridorPrompt.BOTTOM_DP)
	_prompt.offset_top = _prompt.offset_bottom
	_prompt.chosen.connect(_on_prompt_chosen)

	_reward = CorridorReward.new()
	_reward.name = "Reward"
	_overlay.add_child(_reward)
	_reward.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reward.chosen.connect(_on_reward_chosen)


func view() -> CorridorView:
	return _view


func combat() -> CombatScreen:
	return _combat


func chips() -> EnemyChips:
	return _chips


# ---------------------------------------------------------------------------
# Striden i de nedre 55 %
# ---------------------------------------------------------------------------

## Monterar stridsskärm v2 under korridoren och krymper korridoren till 45 %.
##
## [param connections] kopplas [b]före[/b] [method GameScreen.setup], eftersom
## stridsskärmen bygger rummet redan i [code]enter()[/code] och då frågar efter
## sina fiendeavläsningar.
func mount_combat(ctx: Dictionary, connections: Dictionary) -> CombatScreen:
	unmount_combat()
	var packed: PackedScene = ResourceLoader.load(COMBAT_SCENE) as PackedScene
	if packed == null:
		push_error("CorridorScreen: kunde inte ladda %s" % COMBAT_SCENE)
		return null
	_combat = packed.instantiate() as CombatScreen
	if _combat == null:
		push_error("CorridorScreen: %s har inte CombatScreen som rot" % COMBAT_SCENE)
		return null
	_combat.readout_host = _chips
	for signal_name: String in connections:
		_combat.connect(signal_name, connections[signal_name] as Callable)
	_combat.enemy_reaction.connect(_on_enemy_reaction)
	_combat.layout_pressure.connect(_on_layout_pressure)
	_combat_split = CorridorView.SPLIT_COMBAT
	_combat_host.visible = true
	_combat_host.add_child(_combat)
	_combat.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# World-lagret är TOMT med flit: figuren syns aldrig i korridoren (§4) utan
	# bara i character sheetet, och fienderna är billboards i 3D.
	_combat.setup(controller, null, ctx.duplicate())
	_view.set_help_visible(true)
	_view.show_combat_split(true)
	return _combat


func unmount_combat() -> void:
	if _combat != null and is_instance_valid(_combat):
		_combat.teardown()
		_combat.queue_free()
	_combat = null
	_combat_host.visible = false
	_chips.reset_readouts()
	if _view != null and is_instance_valid(_view):
		_view.set_help_visible(false)


## "?" i krit-raden öppnar stridens hjälp-lager. Utanför en strid finns inget
## lager att öppna och knappen är gömd.
func _on_help_requested() -> void:
	if _combat != null and is_instance_valid(_combat):
		_combat.open_help()


## Stridsskärmen säger hur hög den behöver vara; korridoren lämnar ifrån sig
## resten. Bara neråt, och bara när skillnaden är värd en animation.
func _on_layout_pressure(needed: float) -> void:
	if _combat == null or not is_instance_valid(_combat) or size.y <= 0.0:
		return
	var wanted: float = clampf((size.y - needed) / size.y,
		CorridorView.SPLIT_COMBAT_MIN, CorridorView.SPLIT_COMBAT)
	if wanted >= _combat_split - 0.004:
		return
	_combat_split = wanted
	_view.animate_split(wanted)


func _on_enemy_reaction(index: int, kind: String) -> void:
	match kind:
		CombatScreen.REACTION_HIT:
			_view.enemy_hit(index)
		CombatScreen.REACTION_DEATH:
			_view.enemy_die(index)


func _on_split_changed(height: float) -> void:
	if _combat_host == null:
		return
	_combat_host.offset_top = height
	_chips.offset_bottom = height


# ---------------------------------------------------------------------------
# Frågorna
# ---------------------------------------------------------------------------

## Fällans två prislappar, båda utskrivna före tappet (§2.6).
func show_trap(trap: Dictionary) -> void:
	var options: PackedStringArray = PackedStringArray()
	for raw: Variant in trap.get("options", []) as Array:
		var option: Dictionary = raw as Dictionary
		options.append("%s · %s" % [
			Tokens.translate_or(String(option.get("id", "")), String(option.get("id", ""))),
			trap_cost_text(option),
		])
	_open_prompt("trap",
		Tokens.translate_or(String(trap.get("id", "")), String(trap.get("id", ""))),
		Tokens.translate_or("CORRIDOR_TRAP_BODY", "No free way past. Pick what it costs you."),
		options)


## Prislappen i ord. [b]Aldrig en ikon ensam[/b]: en spräckt sida och fem HP är
## inte jämförbara om det ena står som symbol och det andra som siffra (§6).
static func trap_cost_text(option: Dictionary) -> String:
	var amount: int = int(option.get("amount", 0))
	match String(option.get("cost", "")):
		"hp":
			return Tokens.translate_or("CORRIDOR_COST_HP", "%d HP") % amount
		"cracked_face":
			return Tokens.translate_or("CORRIDOR_COST_CRACK", "%d cracked face") % amount
	return ""


## Bossdörren. Ett eget tapp, aldrig automatiskt (§3.3).
func show_door_prompt() -> void:
	_open_prompt("door",
		Tokens.translate_or("CORRIDOR_BOSS_DOOR", "THE DOOR BREATHES"),
		Tokens.translate_or("CORRIDOR_WAY_BACK", "THE WAY BACK IS GONE"),
		PackedStringArray([Tokens.translate_or("CORRIDOR_OPEN_DOOR", "OPEN")]))


## Altaret i återvändsgränden: en enda sak, ingen valsituation (§3.5).
func show_treasure(treasure: Dictionary) -> void:
	_open_prompt("treasure",
		Tokens.translate_or("CORRIDOR_ALTAR", "AN ALTAR, AND ONE THING ON IT"),
		treasure_text(treasure),
		PackedStringArray([Tokens.translate_or("CORRIDOR_TAKE_IT", "TAKE IT")]))


static func treasure_text(treasure: Dictionary) -> String:
	var amount: int = int(treasure.get("amount", 0))
	match String(treasure.get("id", "")):
		"FORGE_FACE":
			return Tokens.translate_or("CORRIDOR_TREASURE_FORGE_FACE", "A face, still warm.")
		"PIPS":
			return Tokens.translate_or("CORRIDOR_TREASURE_PIPS", "%d pips in the dust.") % amount
		"RELIC":
			return Tokens.translate_or("CORRIDOR_TREASURE_RELIC", "Something worth carrying.")
		"CODEX":
			return Tokens.translate_or("CORRIDOR_TREASURE_CODEX", "A page for the codex.")
	return Tokens.translate_or("CORRIDOR_TREASURE_NONE", "Dust, and nothing in it.")


func _open_prompt(kind: String, title_text: String, body_text: String, options: PackedStringArray) -> void:
	_prompt.set_meta(&"kind", kind)
	_view.set_steering_enabled(false)
	_prompt.show_prompt(title_text, body_text, options)


func _on_prompt_chosen(index: int) -> void:
	var kind: String = String(_prompt.get_meta(&"kind", ""))
	match kind:
		"trap":
			trap_answered.emit(index)
		"door":
			door_opened.emit()
		"treasure":
			treasure_taken.emit()


func prompt() -> CorridorPrompt:
	return _prompt


# ---------------------------------------------------------------------------
# Belöningen i korridoren
# ---------------------------------------------------------------------------

func show_reward(state: CombatState, options: Array, breather: bool,
		title: Array = [], targets: Array = []) -> void:
	_view.set_steering_enabled(false)
	_reward.show_options(state, options, breather, title, targets)


func reward() -> CorridorReward:
	return _reward


func _on_reward_chosen(_index: int, option: Dictionary, target: Dictionary) -> void:
	reward_chosen.emit(option, target)


func exit() -> void:
	unmount_combat()
