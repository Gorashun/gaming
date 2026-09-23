class_name TownView
extends Control
## Torget i Chalkrim som en [b]statisk förstapersonsvy[/b] (CORRIDOR_DESIGN §5.1,
## research 05 §6).
##
## [b]Ingen vridning, inga steg.[/b] Research 05 §6 är uttrycklig: att vända sig
## mot varje meny lägger 2 × 160 ms mellan spelaren och en skärm hen besöker efter
## [i]varje[/i] run – fiktion vinner över friktion bara första gången. Kameran
## står still och de tre platserna är tre upplysta mynningar rakt fram.
##
## Geometrin är [CorridorMap.town_square] genom [CorridorMesh]: samma väggar,
## samma golv, samma dimma och samma texturer som Gropen. Noll nya bildfiler.
##
## Tryckytorna är krit-UI ankrade med [method Camera3D.unproject_position] –
## exakt samma teknik som korridorens HP-chip, av samma skäl: platsen i bilden
## ÄR knappen, och den kan aldrig glida ifrån sin mynning.

signal place_tapped(place_id: String)

## Kameran står en meter bakom rutans mitt. Rakt i mitten ser man en vägg och
## inga mynningar – samma mätning som T-korsningen i korridoren
## (CORRIDOR_DEV_NOTES §6.4).
const STAND_BACK_M: float = 1.0
## Mynningens mittpunkt i höjdled, som andel av takhöjden.
const MOUTH_HEIGHT: float = 0.42
## Skyltens bredd och höjd i dp.
const SIGN_WIDTH_DP: int = 84
const SIGN_HEIGHT_DP: int = 40

@onready var _box: SubViewportContainer = $ViewportBox
@onready var _viewport: SubViewport = $ViewportBox/SubViewport
@onready var _world: Node3D = $ViewportBox/SubViewport/World
@onready var _camera: Camera3D = $ViewportBox/SubViewport/World/Camera
@onready var _environment: WorldEnvironment = $ViewportBox/SubViewport/World/Environment
@onready var _geometry: MeshInstance3D = $ViewportBox/SubViewport/World/Geometry
@onready var _props: Node3D = $ViewportBox/SubViewport/World/Props
@onready var _signs: Control = $Signs

var map: CorridorMap = null

var _places: Array[Dictionary] = []
var _buttons: Array[Button] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_camera.fov = CorridorCamera.FOV_DEGREES
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.near = 0.05
	_camera.far = 40.0
	_camera.current = true
	_apply_environment()
	_build_world()
	resized.connect(_place_signs)


## [param places] är tre poster i ordningen vänster, mitt, höger:
## [code]{id, label, unlocked, note}[/code].
func setup(places: Array) -> void:
	_places.clear()
	for raw: Variant in places:
		_places.append(raw as Dictionary)
	_build_signs()
	_place_signs.call_deferred()


func _apply_environment() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = CorridorView.FOG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = CorridorView.FOG_COLOR
	env.fog_light_energy = 1.0
	# Torget är ljusare än Gropen: dimman börjar längre bort, annars ser staden
	# ut som ännu en korridor och "du gick UPP ur mörkret" (§5.2) faller.
	env.fog_depth_begin = 4.0
	env.fog_depth_end = 16.0
	env.fog_depth_curve = 1.0
	env.fog_density = 1.0
	env.fog_sky_affect = 0.0
	_environment.environment = env


func _build_world() -> void:
	map = CorridorMap.town_square()
	var built: Dictionary = CorridorMesh.build(map, Color(1.0, 0.98, 0.94))
	_geometry.mesh = built["mesh"] as ArrayMesh
	for torch: Dictionary in built["torches"] as Array:
		_add_torch(torch)
	_camera.position = CorridorMesh.eye_position(map.position) \
		- CorridorMesh.dir_vector(map.facing) * STAND_BACK_M
	_camera.rotation = Vector3(0.0, map.yaw_radians(), 0.0)


func _add_torch(spec: Dictionary) -> void:
	var tile: Vector2i = spec["tile"]
	var facing: int = int(spec["facing"])
	var sprite: Sprite3D = Sprite3D.new()
	sprite.name = "Torch_%s" % CorridorMap.cell_key(tile)
	# M6: facklan följer art-manifestet (docs/M6_A_NOTES.md §2), precis som i
	# korridoren. M5:s ark har två rutor; en målad remsa säger själv hur många.
	var info: Dictionary = Art.art_info(&"env.corridor.torch")
	sprite.texture = Art.tex(&"env.corridor.torch")
	sprite.hframes = 2 if String(info["source"]) == Art.SOURCE_LEGACY else maxi(1, int(info["frames"]))
	sprite.pixel_size = 0.042 if bool(info["pixel"]) \
		else 0.042 * 32.0 / maxf(1.0, (info["size"] as Vector2).y)
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST if bool(info["pixel"]) \
		else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.shaded = false
	sprite.double_sided = true
	sprite.position = CorridorMesh.tile_origin(tile) \
		+ CorridorMesh.dir_vector(facing) * (CorridorMesh.TILE_M * 0.5 - 0.08) \
		+ Vector3(0.0, CorridorMesh.CEIL_M * 0.62, 0.0)
	sprite.rotation.y = -float(facing) * PI * 0.5 + PI
	_props.add_child(sprite)


# ---------------------------------------------------------------------------
# Skyltarna: krit-UI ankrat i 3D
# ---------------------------------------------------------------------------

func _build_signs() -> void:
	for child: Node in _signs.get_children():
		child.queue_free()
	_buttons.clear()
	for i: int in range(_places.size()):
		var spec: Dictionary = _places[i]
		var button: Button = Button.new()
		button.name = "Place%d" % i
		button.text = String(spec.get("label", ""))
		button.clip_text = true
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = not bool(spec.get("unlocked", true))
		button.custom_minimum_size = Vector2(Tokens.dp(SIGN_WIDTH_DP), Tokens.dp(SIGN_HEIGHT_DP))
		button.size = button.custom_minimum_size
		button.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_LABEL))
		button.add_theme_color_override("font_color", Tokens.CHALK_100)
		button.add_theme_color_override("font_disabled_color", Tokens.CHALK_500)
		var style: StyleBoxFlat = Tokens.box(Tokens.CHALK_300, true, Tokens.STROKE_REG, Tokens.RADIUS_CHIP)
		style.bg_color = Color(Tokens.SURFACE_PIT, 0.86)
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, style)
		ChalkFx.apply(button, ChalkFx.BUTTON)
		button.pressed.connect(_on_place_pressed.bind(String(spec.get("id", ""))))
		_signs.add_child(button)
		_buttons.append(button)


## Skylten hänger i sin mynning. [b]Samma matematik som HP-chipen[/b]
## ([method CorridorView.enemy_anchor]): kameran står still, så det räcker att
## räkna om vid layoutbyte i stället för varje bildruta.
func _place_signs() -> void:
	if _camera == null or _box == null:
		return
	for i: int in range(_buttons.size()):
		var anchor: Vector2 = exit_anchor(i)
		var button: Button = _buttons[i]
		if anchor.x < 0.0:
			button.visible = false
			continue
		button.visible = true
		var button_size: Vector2 = button.custom_minimum_size
		button.position = Vector2(
			clampf(anchor.x - button_size.x * 0.5, 0.0, maxf(size.x - button_size.x, 0.0)),
			clampf(anchor.y - button_size.y * 0.5, 0.0, maxf(_signs.size.y - button_size.y, 0.0)))


## Mynningens mittpunkt i krit-lagret, eller (-1, -1) om den ligger bakom kameran.
func exit_anchor(index: int) -> Vector2:
	if _camera == null or index < 0 or index >= CorridorMap.TOWN_EXIT_OFFSETS.size():
		return Vector2(-1.0, -1.0)
	var tile: Vector2i = CorridorMap.town_exit_tile(index)
	var point: Vector3 = CorridorMesh.tile_origin(tile) \
		+ Vector3(0.0, CorridorMesh.CEIL_M * MOUTH_HEIGHT, CorridorMesh.TILE_M * 0.5)
	if _camera.is_position_behind(point):
		return Vector2(-1.0, -1.0)
	return _camera.unproject_position(point) * float(_box.stretch_shrink)


func _on_place_pressed(place_id: String) -> void:
	Juice.ui_tap(1.0)
	place_tapped.emit(place_id)


func place_button(index: int) -> Button:
	return _buttons[index] if index >= 0 and index < _buttons.size() else null
