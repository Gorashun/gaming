class_name CorridorView
extends Control
## Förstapersonskorridoren: 3D i en [SubViewport], krita ovanpå.
##
## [b]Lagerbygget är oförändrat[/b] (ARCHITECTURE, UI_GUIDE §17): 3D ersätter
## innehållet i World-lagret, krit-UI:t ligger ovanpå och rör inte 3D:n. Inget
## tal och ingen stapel ritas i 3D.
##
## [b]Vyn äger ingen regel.[/b] [CorridorMap] säger vad som finns och vad ett
## steg leder till; vyn spelar upp händelseloggen och skickar vidare de fyra
## beslut som hör hemma hos [GameController]: en strid börjar, en fälla väntar
## på svar, en skatt är tagen, en dörr ska öppnas.
##
## Integrationen är beskriven i [code]docs/CORRIDOR_DEV_NOTES.md[/code].

## Spelaren står på en ny ruta. [b]Autosave-kroken:[/b] att kliva ett steg är en
## transaktion (CORRIDOR_DESIGN §1.2), och sparfilen skrivs per ruta.
signal cell_changed(cell: Dictionary, map_state: Dictionary)
## Fienderna står framför spelaren och striden ska ta över.
signal encounter_reached(node_id: String, enemy_ids: Array)
## En fälla väntar på svar. Båda prislapparna ligger i [code]trap.options[/code].
signal trap_choice(trap: Dictionary)
signal treasure_found(treasure: Dictionary)
## Bossdörren är nådd. Öppningen är ett eget tapp – aldrig automatiskt (§3.3).
signal boss_door_reached()
signal fate_door_reached()
signal floor_cleared(floor_index: int)
## Spelaren klev på trappan upp ur källaren (CORRIDOR_DESIGN §5.2 punkt 4).
signal stairs_reached()
signal character_sheet_requested()
signal settings_requested()
## "?" i HUD:en. Under strid i korridoren äger krit-raden hjälpknappen, eftersom
## stridsskärmen bara har 352 dp och inte har råd med ett eget toppfält.
signal help_requested()
## Korridorrutans höjd har ändrats. Stridsskärmen hänger i den underkanten.
signal split_changed(height: float)

# --- Splitar (UI_GUIDE §17.1) ----------------------------------------------
## Utforskning: korridoren fyller ytan mellan HUD och tumzon.
const SPLIT_EXPLORE: float = 1.0
## Strid: 45 % av höjden. Stridsskärm v2 tar de nedre 55 %.
const SPLIT_COMBAT: float = 0.45
## [b]Golvet när räknestycket inte får plats på 55 %[/b] (research 05 §3: "Faller
## strid v2 inte inom 352 dp vid textstorlek 130 %, sänk korridoren till 40 %").
##
## [b]Avvikelse, mätt:[/b] research gissade 40 %. Ett FULLT kvitto – sex
## leveransrader plus rustningsraden, alltså precis när spelaren har mest att
## läsa – behöver 395 dp även efter att toppfältet, leveransremsan och brickans
## rubrik lyfts bort. Golvet är därför 36 %. Det slår in bara med fem placerade
## tärningar och ett överflöde; resten av tiden står korridoren på 45 %.
## Tumzonen betalar aldrig (COMBAT_READABILITY §8).
const SPLIT_COMBAT_MIN: float = 0.36
## Tumzonens höjd inklusive luft, i dp.
const STEER_BLOCK_DP: int = 84
## Hur länge korridoren krymper ner i stridssplitten. 200 ms är UI_GUIDE §5:s
## "skärmen byter läge"-längd; reducerad rörelse hoppar rakt dit.
const SPLIT_MS: int = 200

## [b]Ståplatsen i en korsning och framför en dörr[/b] är inte rutans mitt.
## En 3 m gång med 75° horisontellt visar bara 2,3 m på 1,5 m avstånd, så en
## spelare som står MITT i T-korsningen ser en vägg och inga mynningar – exakt
## motsatsen till skyltbilden i design/mockup_corridor.html. Att backa kameran
## drygt en meter i rutan gör att bortre väggen och båda mynningarna ryms i
## bild, vilket är hela poängen med en korsning.
const STAND_BACK_JUNCTION_M: float = 1.35
const STAND_BACK_DOOR_M: float = 1.10

## Wizardry-formeringen ur research 05 §3. Djupet skiljer leden åt; fyra i bredd
## i en 3 m gång blir soppa.
const FORMATION: Array[Vector3] = [
	Vector3(-0.75, 0.0, -3.0),
	Vector3(0.75, 0.0, -3.0),
	# Bakre ledet står INNANFÖR det främre i sidled, inte bakom det. Research 05
	# §3 föreslog ±0,75 i båda leden, men då döljs de bakre helt av de främre
	# och "antal fiender läses av silhuetterna" (CORRIDOR_DESIGN §3.1) faller.
	Vector3(-0.40, 0.0, -4.4),
	Vector3(0.40, 0.0, -4.4),
]
## Samma värde för alla fiender, så den relativa storleken bevaras från 2D:
## en 32 px-fiende blir 1,76 m, en 48 px-boss 2,64 m.
const ENEMY_PIXEL_SIZE: float = 0.055
## Silhuetten är fiendespriten i svart. Noll nya bildfiler, hela genrens lockelse.
const SILHOUETTE: Color = Color(0.055, 0.071, 0.086, 0.92)
const REVEAL_MS: int = 180
const APPROACH_MS: int = 400
## Träffblixten på billboarden: samma 60 ms som den platta skärmens vitblixt
## (UI_GUIDE §5.3), här som överexponerad modulate i stället för ett ColorRect.
const HIT_FLASH: Color = Color(3.0, 3.0, 3.0, 1.0)
const HIT_FLASH_MS: int = 60
## Ryck i sidled, i meter. Aldrig kameran – se [method enemy_hit].
const HIT_SHAKE_M: float = 0.08
const DEATH_MS: int = 300
const DEATH_SINK_M: float = 0.3

## Dimman är samma svarta som krit-UI:ts botten (#0E1216) så att gränsen mellan
## 3D och UI aldrig syns som en kant (UI_GUIDE §17.3).
const FOG_COLOR: Color = Color(0.055, 0.071, 0.086)
## Sikten tar slut vid ~3 rutor.
const FOG_BEGIN_M: float = 2.0
const FOG_END_M: float = 11.0

## Våningstonen. Samma atlas, annan ton – noll nya bildfiler per våning
## (research 05 §5).
const FLOOR_TINTS: Array[Color] = [
	Color(1.0, 1.0, 1.0),
	Color(0.92, 0.95, 1.0),
	Color(1.0, 0.93, 0.88),
]

@onready var _box: SubViewportContainer = $ViewportBox
@onready var _viewport: SubViewport = $ViewportBox/SubViewport
@onready var _world: Node3D = $ViewportBox/SubViewport/World
@onready var _camera: CorridorCamera = $ViewportBox/SubViewport/World/Camera
@onready var _environment: WorldEnvironment = $ViewportBox/SubViewport/World/Environment
@onready var _geometry: MeshInstance3D = $ViewportBox/SubViewport/World/Geometry
@onready var _props: Node3D = $ViewportBox/SubViewport/World/Props
@onready var _encounter: Node3D = $ViewportBox/SubViewport/World/Encounter
@onready var _hud: CorridorHud = $Hud
@onready var _steer: DirectionButtons = $Steer

var map: CorridorMap = null
var reduced_motion: bool = false
## Kedjetempo-inställningen (Lugn/Normal/Snabb/Blixt). Blixt halverar stegtiden
## (CORRIDOR_DESIGN §7.3).
var speed_scale: float = 1.0

## Andelen av höjden korridoren tar. Tweenas av [method animate_split], därför
## en egendomsuppsättare och inte en vanlig variabel: [Tween] kan bara röra
## namngivna egenskaper.
var split_ratio: float = SPLIT_EXPLORE:
	set(value):
		split_ratio = clampf(value, 0.2, 1.0)
		_layout()

var _split_tween: Tween = null
var _busy: bool = false
var _status: Dictionary = {"hp": 100, "max_hp": 100, "room": 1, "pips": 0}
var _pending_enemies: Array[String] = []
var _enemy_nodes: Array[AnimatedSprite3D] = []
var _door_nodes: Dictionary = {}
## Sant från det att mötet avslöjats tills striden är slut. [b]Spärr:[/b]
## [method CorridorMap._look_ahead] kör EFTER att mötet nåtts i samma
## händelselogg och skulle annars skjuta formeringen två rutor bort – mitt i
## striden, med chipen kvar i luften (den buggen kostade en eftermiddag).
var _encounter_active: bool = false
## Krypningen i takt 3 (§3.1). Måste gå att döda: den är 400 ms lång och ett steg
## är 180 ms, så den var fortfarande igång när mötet avslöjades och skrev
## tillbaka formeringen till platsen den kröp FRÅN.
var _approach_tween: Tween = null
## Steg sedan senaste händelse. CORRIDOR_DESIGN §1.2: max 3, mäts i rökprovet.
var _quiet_steps: int = 0
var _max_quiet_steps: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_camera.reduced_motion = reduced_motion
	_camera.speed_scale = speed_scale
	_apply_environment()
	_steer.direction_pressed.connect(_on_direction_pressed)
	_hud.character_sheet_pressed.connect(func() -> void: character_sheet_requested.emit())
	_hud.settings_pressed.connect(func() -> void: settings_requested.emit())
	_hud.help_pressed.connect(func() -> void: help_requested.emit())
	resized.connect(_layout)
	_layout()


# ---------------------------------------------------------------------------
# Uppstart
# ---------------------------------------------------------------------------

## Monterar en våning. [param ctx] är HUD-data:
## [code]{hp, max_hp, room, pips, enemies}[/code].
func setup(p_map: CorridorMap, ctx: Dictionary = {}) -> void:
	map = p_map
	for key: Variant in ctx:
		_status[key] = ctx[key]
	_build_world()
	_camera.place(_stand_position(), map.yaw_radians())
	_refresh()
	# En karta som laddats ur en sparfil har redan sina händelser spelade.
	map.events_since_last()


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if _camera != null:
		_camera.reduced_motion = value


func set_speed_scale(value: float) -> void:
	speed_scale = value
	if _camera != null:
		_camera.speed_scale = value


func set_status(hp: int, max_hp: int, room: int, pips: int) -> void:
	_status = {"hp": hp, "max_hp": max_hp, "room": room, "pips": pips}
	_refresh_hud()


## 100 % korridor (utforskning) eller 45 % (strid). Samma kamera, samma
## horisontella utsnitt – det är vad KEEP_WIDTH är till för.
func set_split(ratio: float) -> void:
	_kill_split_tween()
	split_ratio = ratio


## Samma sak, men animerat. [b]Reducerad rörelse hoppar rakt dit[/b]
## (DECISIONS 2026-09-21): tidslinjen ändras inte, bara interpolationen.
func animate_split(ratio: float) -> void:
	_kill_split_tween()
	var target: float = clampf(ratio, 0.2, 1.0)
	if reduced_motion or is_equal_approx(split_ratio, target) or not is_inside_tree():
		split_ratio = target
		return
	_split_tween = create_tween()
	_split_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_split_tween.tween_property(self, "split_ratio", target, float(SPLIT_MS) / 1000.0)


func _kill_split_tween() -> void:
	if _split_tween != null and _split_tween.is_valid():
		_split_tween.kill()
	_split_tween = null


func show_combat_split(animate: bool = false) -> void:
	_steer.visible = false
	if animate:
		animate_split(SPLIT_COMBAT)
	else:
		set_split(SPLIT_COMBAT)


func show_explore_split(animate: bool = false) -> void:
	_steer.visible = true
	if animate:
		animate_split(SPLIT_EXPLORE)
	else:
		set_split(SPLIT_EXPLORE)
	_refresh()


## Korridorrutans höjd i pixlar. Stridsskärmen monteras direkt under den.
func split_height() -> float:
	var steer_block: float = Tokens.dp(STEER_BLOCK_DP)
	var full: float = maxf(size.y - steer_block, 1.0)
	return size.y * split_ratio if split_ratio < SPLIT_EXPLORE else full


func _layout() -> void:
	if _box == null:
		return
	# Anchor_right = 1 sköter bredden; offseten är bara marginalen. Att skriva
	# size.x här skulle göra containern dubbelt så bred som skärmen och kameran
	# skulle zooma in i väggen (KEEP_WIDTH mäter mot containerns bredd).
	var height: float = split_height()
	_box.offset_left = 0.0
	_box.offset_right = 0.0
	_box.offset_top = 0.0
	_box.offset_bottom = height
	_steer.offset_top = -Tokens.dp(STEER_BLOCK_DP - 10)
	_steer.offset_bottom = -Tokens.dp(10)
	_steer.offset_left = Tokens.dp(Tokens.SPACE_3)
	_steer.offset_right = -Tokens.dp(Tokens.SPACE_3)
	split_changed.emit(height)


## Depth fog, ingen lampa. [b]Verifieras i båda renderarna[/b] (research 05 §7);
## per-vertex-mörkningen i meshen är reserven om fog saknas.
func _apply_environment() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = FOG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = FOG_COLOR
	env.fog_light_energy = 1.0
	env.fog_depth_begin = FOG_BEGIN_M
	env.fog_depth_end = FOG_END_M
	env.fog_depth_curve = 1.0
	env.fog_density = 1.0
	env.fog_sky_affect = 0.0
	_environment.environment = env


func _build_world() -> void:
	for child: Node in _props.get_children():
		child.queue_free()
	_clear_encounter()
	_door_nodes.clear()
	var tint: Color = FLOOR_TINTS[posmod(map.floor_index - 1, FLOOR_TINTS.size())]
	var built: Dictionary = CorridorMesh.build(map, tint)
	_geometry.mesh = built["mesh"] as ArrayMesh
	for door: Dictionary in built["doors"] as Array:
		_add_door(door)
	for torch: Dictionary in built["torches"] as Array:
		_add_torch(torch)
	for sign_spec: Dictionary in built["signs"] as Array:
		_add_sign(sign_spec)


# ---------------------------------------------------------------------------
# Rekvisita
# ---------------------------------------------------------------------------

func _add_door(spec: Dictionary) -> void:
	var tile: Vector2i = spec["tile"]
	var facing: int = int(spec["facing"])
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = "Door_%s_%d" % [CorridorMap.cell_key(tile), facing]
	node.mesh = CorridorMesh.door_mesh(Vector2(CorridorMesh.TILE_M * 0.62, CorridorMesh.CEIL_M * 0.86))
	var mat: StandardMaterial3D = CorridorMesh.tile_material(CorridorMesh.SURFACE_DOOR)
	node.material_override = mat
	var origin: Vector3 = CorridorMesh.tile_origin(tile)
	# 6 cm in mot rutan: annars z-fightar dörren med väggen den står i.
	node.position = origin + CorridorMesh.dir_vector(facing) * (CorridorMesh.TILE_M * 0.5 - 0.06)
	node.rotation.y = -float(facing) * PI * 0.5 + PI
	_props.add_child(node)
	_door_nodes[CorridorMap.cell_key(tile)] = node


func _add_torch(spec: Dictionary) -> void:
	var tile: Vector2i = spec["tile"]
	var facing: int = int(spec["facing"])
	var sprite: AnimatedSprite3D = AnimatedSprite3D.new()
	sprite.name = "Torch_%s" % CorridorMap.cell_key(tile)
	sprite.sprite_frames = _torch_frames()
	sprite.animation = &"default"
	sprite.pixel_size = 0.042
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.double_sided = true
	var origin: Vector3 = CorridorMesh.tile_origin(tile)
	var along: Vector3 = CorridorMesh.dir_vector(posmod(facing + 1, 4))
	sprite.position = origin + CorridorMesh.dir_vector(facing) * (CorridorMesh.TILE_M * 0.5 - 0.08) \
		+ along * float(spec.get("lateral", 0.0)) \
		+ Vector3(0.0, CorridorMesh.CEIL_M * float(spec.get("height", 0.62)), 0.0)
	sprite.rotation.y = -float(facing) * PI * 0.5 + PI
	sprite.play()
	_props.add_child(sprite)


static func _torch_frames() -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.set_animation_speed(&"default", 6.0)
	frames.set_animation_loop(&"default", true)
	var sheet: Texture2D = Art.tex(&"env.corridor.torch")
	if sheet == null:
		return frames
	var cell: int = sheet.get_width() / 2
	for i: int in range(2):
		var slice: AtlasTexture = AtlasTexture.new()
		slice.atlas = sheet
		slice.region = Rect2(float(i * cell), 0.0, float(cell), float(sheet.get_height()))
		slice.filter_clip = true
		frames.add_frame(&"default", slice)
	return frames


## Skylten över en mynning: stenplattan som quad, nodikonen som eget quad ovanpå
## (UI_GUIDE §8: objektet är pixlar, ordet på det är krita).
func _add_sign(spec: Dictionary) -> void:
	var tile: Vector2i = spec["tile"]
	var facing: int = int(spec["facing"])
	var origin: Vector3 = CorridorMesh.tile_origin(tile)
	var out: Vector3 = CorridorMesh.dir_vector(facing)
	var height: float = CorridorMesh.CEIL_M * 0.72
	var lateral: float = float(spec.get("lateral", 0.0))
	var side: Vector3 = Vector3.ZERO
	if lateral != 0.0:
		side = CorridorMesh.dir_vector(int(spec.get("lateral_dir", facing))) * lateral
	var base: Vector3 = origin + out * (CorridorMesh.TILE_M * 0.5 - 0.10) + side + Vector3(0.0, height, 0.0)

	var plate: Sprite3D = _quad_sprite(
		Art.tex(&"env.corridor.sign"), 0.012)
	plate.name = "Sign_%s_%d" % [CorridorMap.cell_key(tile), facing]
	plate.position = base
	plate.rotation.y = -float(facing) * PI * 0.5 + PI
	_props.add_child(plate)

	var icon: Texture2D = Art.node_icon(_icon_key(String(spec["key"])))
	if icon == null:
		return
	var glyph: Sprite3D = _quad_sprite(icon, 0.030)
	glyph.name = "SignIcon_%s_%d" % [CorridorMap.cell_key(tile), facing]
	# Ikonen ligger FRAMFÖR plattan. out pekar in i väggen, så plustecknet hade
	# lagt den bakom plattan och den hade försvunnit i djuptestet.
	glyph.position = base - out * 0.03
	glyph.rotation.y = plate.rotation.y
	glyph.render_priority = 1
	_props.add_child(glyph)


## Skyltnyckel → filnamnet i [code]assets/sprites/ui/node_*.png[/code].
static func _icon_key(sign_key: String) -> String:
	match sign_key:
		CorridorMap.SIGN_FIGHT: return "combat"
		CorridorMap.SIGN_ELITE: return "elite"
		CorridorMap.SIGN_REST: return "rest"
		CorridorMap.SIGN_MARKET: return "forge"
		CorridorMap.SIGN_FATE: return "mystery"
		CorridorMap.SIGN_BOSS: return "boss"
	return "mystery"


static func _quad_sprite(texture: Texture2D, pixel_size: float) -> Sprite3D:
	var sprite: Sprite3D = Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = pixel_size
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.double_sided = true
	return sprite


# ---------------------------------------------------------------------------
# Rörelse
# ---------------------------------------------------------------------------

func _on_direction_pressed(action: String) -> void:
	step(action)


## Ett tapp = ett steg = en ruta. Spärren ligger på ETT ställe.
func step(action: String) -> bool:
	if map == null or _busy:
		return false
	if not map.apply(action):
		return false
	_busy = true
	_steer.set_all_disabled(true)
	await _play_events(map.events_since_last())
	_busy = false
	_refresh()
	return true


## Spelar upp kartans händelselogg. Ordningen i loggen ÄR tidslinjen.
func _play_events(events: Array[Dictionary]) -> void:
	var quiet: bool = true
	for event: Dictionary in events:
		match String(event["type"]):
			CorridorMap.EVENT_TURNED:
				_camera.turn_to(deg_to_rad(-float(event["to_deg"])))
				await _camera.move_finished
			CorridorMap.EVENT_TURN_AROUND:
				_camera.turn_around_to(deg_to_rad(-float(event["to_deg"])))
				await _camera.move_finished
			CorridorMap.EVENT_CELL_ENTERED:
				_camera.step_to(_stand_position())
				await _camera.move_finished
				cell_changed.emit(map.current_cell(), map.to_dict())
			CorridorMap.EVENT_ENCOUNTER_AHEAD:
				quiet = false
				_show_silhouettes(int(event["distance"]))
			CorridorMap.EVENT_ENCOUNTER_REACHED:
				quiet = false
				await _reveal_encounter(String(event["node_id"]))
				encounter_reached.emit(String(event["node_id"]), _pending_enemies.duplicate())
			CorridorMap.EVENT_REACHED_JUNCTION, CorridorMap.EVENT_JUNCTION_AHEAD:
				quiet = false
			CorridorMap.EVENT_TRAP_CHOICE:
				quiet = false
				trap_choice.emit(event["trap"] as Dictionary)
			CorridorMap.EVENT_TREASURE:
				quiet = false
				treasure_found.emit(event["treasure"] as Dictionary)
			CorridorMap.EVENT_BOSS_DOOR:
				quiet = false
				if not bool(event.get("ahead", false)):
					boss_door_reached.emit()
			CorridorMap.EVENT_FATE_DOOR:
				quiet = false
				fate_door_reached.emit()
			CorridorMap.EVENT_FLOOR_CLEARED:
				quiet = false
				floor_cleared.emit(int(event["floor"]))
			CorridorMap.EVENT_STAIRS_UP:
				quiet = false
				stairs_reached.emit()
	_quiet_steps = _quiet_steps + 1 if quiet else 0
	_max_quiet_steps = maxi(_max_quiet_steps, _quiet_steps)


## Steg sedan senaste händelse, och det värsta hittills. Treställningsregeln
## (CORRIDOR_DESIGN §1.2) säger max 3 och rökprovet skriver ut siffran.
func max_steps_without_event() -> int:
	return _max_quiet_steps


## Ögonpunkten i rutan spelaren står på, med korsnings- och dörrmarginalen.
func _stand_position() -> Vector3:
	var eye: Vector3 = CorridorMesh.eye_position(map.position)
	var back: float = 0.0
	match String(map.current_cell().get("kind", "")):
		CorridorMap.KIND_JUNCTION:
			back = STAND_BACK_JUNCTION_M
		CorridorMap.KIND_BOSS_DOOR, CorridorMap.KIND_FATE_DOOR:
			back = STAND_BACK_DOOR_M
	return eye - CorridorMesh.dir_vector(map.facing) * back


## Låser eller släpper tumzonen. En fälla, en dörr eller ett belöningsval äger
## skärmen tills spelaren svarat; knapparna dimmas då men försvinner aldrig
## (UI_GUIDE §17.4 regel 3).
func set_steering_enabled(value: bool) -> void:
	if value:
		_refresh()
	else:
		_steer.set_all_disabled(true)


## HUD-knappens kritring: något har ändrats och inte setts (§4.4).
func set_sheet_badge(pending: bool) -> void:
	_hud.set_sheet_badge(pending)


## "?" syns bara medan en strid pågår – utanför striden finns inget att förklara
## i korridoren, och en knapp som inte gör något är värre än ingen knapp.
func set_help_visible(value: bool) -> void:
	_hud.set_help_visible(value)


func _refresh() -> void:
	_refresh_hud()
	if map != null and not _busy:
		_steer.set_actions(map.available_actions())


func _refresh_hud() -> void:
	if map == null:
		return
	_hud.set_status(int(_status["hp"]), int(_status["max_hp"]), int(_status["room"]),
		map.floor_index, int(_status["pips"]))
	_hud.set_trail(map.trail().size(), map.steps_taken)


## Betalar fällan och går vidare. Anropas av [GameController] när spelaren valt.
func resolve_trap(option_index: int) -> Dictionary:
	if map == null:
		return {}
	var chosen: Dictionary = map.resolve_trap(option_index)
	map.events_since_last()
	_refresh()
	return chosen


## Öppnar bossdörren. Ett eget tapp, aldrig automatiskt (§3.3).
func open_door() -> void:
	var node: MeshInstance3D = _door_nodes.get(CorridorMap.cell_key(map.position), null)
	if node == null:
		return
	if reduced_motion:
		node.visible = false
		return
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(node, "position:y", node.position.y - CorridorMesh.CEIL_M, 0.42)
	await tween.finished
	node.visible = false


# ---------------------------------------------------------------------------
# Fienderna
# ---------------------------------------------------------------------------

## Vilka fiender som står i nästa kammare. Sätts av [GameController] ur
## [method Content.encounter] innan spelaren når fram.
func set_next_enemies(enemy_ids: Array) -> void:
	if _encounter_active:
		# Striden pågår. Nästa rums monster får vänta tills det här är avgjort.
		return
	var ids: Array[String] = []
	for id: Variant in enemy_ids:
		ids.append(String(id))
	if ids == _pending_enemies:
		return
	# Ny uppsättning ⇒ nya billboards. Utan det här skulle nästa möte ärva
	# förra mötets FÄRGADE sprites och silhuetten i mörkret, som är hela
	# poängen med takt 1, aldrig visa sig igen.
	_clear_encounter()
	_pending_enemies = ids


## Städar bort mötet. Anropas av [GameController] när striden är över.
func clear_encounter() -> void:
	_clear_encounter()
	_pending_enemies.clear()


func _clear_encounter() -> void:
	_kill_approach()
	for child: Node in _encounter.get_children():
		child.queue_free()
	_enemy_nodes.clear()
	_encounter_active = false


## Takt 1 och 3 i CORRIDOR_DESIGN §3.1: silhuett i mörkret på två rutor, sedan
## ett steg fram. Formen mot en aning ljusare vägg är hela genrens lockelse och
## kostar noll nya sprites.
func _show_silhouettes(distance: int) -> void:
	if _pending_enemies.is_empty() or _encounter_active:
		return
	if _enemy_nodes.is_empty():
		_spawn_enemies()
	_kill_approach()
	var target: Vector3 = _formation_origin(distance)
	if reduced_motion or distance >= 2:
		_encounter.position = target
		return
	_approach_tween = create_tween()
	_approach_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_approach_tween.tween_property(_encounter, "position", target, float(APPROACH_MS) / 1000.0)


func _kill_approach() -> void:
	if _approach_tween != null and _approach_tween.is_valid():
		_approach_tween.kill()
	_approach_tween = null


## Ställer mötet på plats [b]utan[/b] avslöjandet (M5.8). En återupptagen run
## står redan mitt i striden: monstren ska inte krypa fram ur mörkret igen, de
## ska bara stå där. Utan den här raden mötte en laddad sparfil en tom korridor
## med ett stridsbräde under – fienderna spawnas annars av
## [constant CorridorMap.EVENT_ENCOUNTER_REACHED], som aldrig kommer en andra gång.
##
## No-op när mötet redan står framme, så den normala vägen är orörd.
func restore_encounter() -> void:
	if _encounter_active or _pending_enemies.is_empty():
		return
	_kill_approach()
	if _enemy_nodes.is_empty():
		_spawn_enemies()
	_encounter.position = _formation_origin(0)
	_encounter_active = true
	for sprite: AnimatedSprite3D in _enemy_nodes:
		sprite.modulate = Color.WHITE


## Står ett möte framme just nu?
func has_encounter() -> bool:
	return _encounter_active


## Takt 3 forts.: silhuetten fylls med färg och pixlar på 180 ms.
func _reveal_encounter(_node_id: String) -> void:
	_kill_approach()
	if _enemy_nodes.is_empty():
		_spawn_enemies()
	_encounter.position = _formation_origin(0)
	_encounter_active = true
	if reduced_motion:
		for sprite: AnimatedSprite3D in _enemy_nodes:
			sprite.modulate = Color.WHITE
		return
	var tween: Tween = create_tween().set_parallel(true)
	for sprite: AnimatedSprite3D in _enemy_nodes:
		tween.tween_property(sprite, "modulate", Color.WHITE, float(REVEAL_MS) / 1000.0)
	await tween.finished


## Formeringens nollpunkt. [constant FORMATION] är redan uttryckt relativt en
## spelare som står en ruta från främre ledet, så noll betyder "striden börjar
## här". Silhuetten på två rutors håll skjuts därför en ruta längre bort, och
## [param distance] 1 lägger till 0,6 m krypning: det är takt 3 i
## CORRIDOR_DESIGN §3.1, "den kliver fram och blir sedd".
func _formation_origin(distance: int) -> Vector3:
	var forward: Vector3 = CorridorMesh.dir_vector(map.facing)
	var ranks: float = float(maxi(distance, 1) - 1) * CorridorMesh.TILE_M
	var creep: float = 0.6 if distance == 1 else 0.0
	_encounter.rotation.y = map.yaw_radians()
	var ground: Vector3 = _stand_position() - Vector3(0.0, CorridorMesh.EYE_M, 0.0)
	return ground + forward * (ranks - creep)


func _spawn_enemies() -> void:
	_clear_encounter()
	for i: int in range(mini(_pending_enemies.size(), FORMATION.size())):
		var id: String = _pending_enemies[i]
		var sprite: AnimatedSprite3D = AnimatedSprite3D.new()
		sprite.name = "Enemy%d" % i
		sprite.sprite_frames = Art.enemy_frames(id)
		sprite.animation = &"default"
		sprite.pixel_size = ENEMY_PIXEL_SIZE
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.shaded = false
		sprite.modulate = SILHOUETTE
		# Formeringen ligger i en lokal rymd som roteras med spelaren, därför
		# är -Z alltid "bort från spelaren" oavsett väderstreck.
		sprite.position = FORMATION[i] + Vector3(0.0, float(Art.enemy_cell(id)) * ENEMY_PIXEL_SIZE * 0.5, 0.0)
		sprite.play()
		_encounter.add_child(sprite)
		_enemy_nodes.append(sprite)


## Antalet billboards som står i formeringen just nu.
func enemy_count() -> int:
	return _enemy_nodes.size()


## Träffblixt och ryck på billboarden (research 05 §3).
##
## [b]Skaket ligger på sprajten, aldrig på kameran.[/b] Kameraskak i
## förstaperson är åksjuka, och korridorkameran har med flit ingen skakfunktion
## alls ([CorridorCamera] regel 2).
func enemy_hit(index: int) -> void:
	if index < 0 or index >= _enemy_nodes.size():
		return
	var sprite: AnimatedSprite3D = _enemy_nodes[index]
	sprite.modulate = HIT_FLASH
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, float(HIT_FLASH_MS) / 1000.0)
	if reduced_motion:
		return
	var home: float = sprite.position.x
	var shake: Tween = create_tween()
	shake.set_trans(Tween.TRANS_SINE)
	shake.tween_property(sprite, "position:x", home + HIT_SHAKE_M, 0.05)
	shake.tween_property(sprite, "position:x", home - HIT_SHAKE_M, 0.06)
	shake.tween_property(sprite, "position:x", home, 0.05)


## Döden: arkets tre death-frames, sedan uttoning och en halv meter nedåt.
## Saknar arket raden tonas billboarden bara ut – aldrig en krasch (Art-regeln).
func enemy_die(index: int) -> void:
	if index < 0 or index >= _enemy_nodes.size():
		return
	var sprite: AnimatedSprite3D = _enemy_nodes[index]
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"death"):
		sprite.animation = &"death"
		sprite.frame = 0
		sprite.play()
	var seconds: float = float(DEATH_MS) / 1000.0
	if reduced_motion:
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
		return
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, seconds)
	tween.tween_property(sprite, "position:y", sprite.position.y - DEATH_SINK_M, seconds)


## Chipens ankarpunkt i krit-lagret. Ren matematik på kameratransformen, alltså
## testbar headless (research 05 §7).
func enemy_anchor(index: int) -> Vector2:
	# [b](-1, -1) och inte (0, 0) för ett index utan billboard.[/b] Noll är en
	# giltig skärmpunkt; ett chip för en fiende som inte står i formeringen
	# hamnade då i skärmens övre vänstra hörn och pekade på ingenting.
	if index < 0 or index >= _enemy_nodes.size():
		return Vector2(-1.0, -1.0)
	var sprite: AnimatedSprite3D = _enemy_nodes[index]
	var point: Vector3 = sprite.global_position + Vector3.UP * 1.2
	if _camera.is_position_behind(point):
		return Vector2(-1.0, -1.0)
	return _box.global_position + _camera.unproject_position(point) * float(_box.stretch_shrink)
