class_name ChalkFx
extends RefCounted
## Kritshadern som ett API. Enda platsen i [code]src/game/[/code] som känner
## till [code]src/game/shaders/chalk.gdshader[/code] och dess uniformer.
##
## UI_GUIDE §8.4 är hård på punkten: kritshadern ligger [b]bara[/b] på
## ChalkUI-noder och palett-LUT:en [b]bara[/b] på World-noder. Att lägga
## kritshadern på pixelkonst suddar rutnätet. Den här klassen tar därför bara
## [Control]-noder och sätter materialet på noden själv – aldrig på dess barn,
## eftersom ett [Control] ritar sin stylebox men inte sina barns.
##
## UI_GUIDE §6.1 (reducerad rörelse): [code]jitter_speed = 0[/code]. Kornet och
## erosionen finns kvar, skakningen försvinner. Den regeln ligger här och inte
## på anropsställena, så att ett nytt UI aldrig kan glömma den.

const SHADER_PATH: String = "res://src/game/shaders/chalk.gdshader"

## Profiler. Skillnaden är hur mycket kritan får äta av ytan: en knapp måste
## kunna läsas i solljus (UI_GUIDE §6.3, minst 4,9:1), en display-siffra får
## vara riktigt sliten eftersom den är 40–56 dp hög.
const PANEL: StringName = &"panel"
const BUTTON: StringName = &"button"
const DISPLAY: StringName = &"display"
const LINE: StringName = &"line"

## Värdet på [code]wipe[/code] som betyder "ingenting är bortsopat".
const WIPE_DRAWN: float = -0.25

const PROFILES: Dictionary = {
	PANEL: {"jitter_amount": 0.003, "jitter_scale": 10.0, "jitter_speed": 0.8, "grain_amount": 0.22, "erosion": 0.10, "edge_bias": 0.5},
	BUTTON: {"jitter_amount": 0.002, "jitter_scale": 12.0, "jitter_speed": 0.6, "grain_amount": 0.18, "erosion": 0.08, "edge_bias": 0.4},
	# Jittret måste hållas LÅGT på text: en bokstav är tunn, och en UV-förskjutning
	# på 0,005 river sönder stammarna i stället för att göra dem handdragna.
	# Uppmätt på "SETTINGS" i 28 dp: 0,005 ger trasiga glyfer, 0,002 ger krita.
	DISPLAY: {"jitter_amount": 0.002, "jitter_scale": 16.0, "jitter_speed": 1.0, "grain_amount": 0.26, "erosion": 0.12, "edge_bias": 0.6},
	LINE: {"jitter_amount": 0.006, "jitter_scale": 14.0, "jitter_speed": 1.4, "grain_amount": 0.35, "erosion": 0.28, "edge_bias": 0.6},
}

static var _shader: Shader = null
static var _missing_logged: bool = false


## Shadern, eller null om filen saknas. UI-agenten äger filen och kan ha den
## utcheckad; ett saknat material ska ge ett UI utan kritkorn, aldrig en krasch.
static func shader() -> Shader:
	if _shader == null:
		if not ResourceLoader.exists(SHADER_PATH):
			if not _missing_logged:
				_missing_logged = true
				push_warning("ChalkFx: %s saknas – UI ritas utan kritshader" % SHADER_PATH)
			return null
		_shader = ResourceLoader.load(SHADER_PATH) as Shader
	return _shader


## Ett nytt [ShaderMaterial] för en profil. Varje anrop ger ett eget material:
## [code]wipe[/code] är per nod (UI_GUIDE §5.7 sveper en panel i taget) och ett
## delat material skulle sudda hela skärmen samtidigt.
static func material(profile: StringName = PANEL) -> ShaderMaterial:
	var chalk: Shader = shader()
	if chalk == null:
		return null
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = chalk
	var values: Dictionary = PROFILES.get(profile, PROFILES[PANEL]) as Dictionary
	for key: String in values:
		mat.set_shader_parameter(key, values[key])
	if Settings.reduced_motion:
		# UI_GUIDE §12.6: korn och erosion kvar, skakningen borta.
		mat.set_shader_parameter("jitter_speed", 0.0)
	if Settings.high_contrast:
		# §2.11: strecket ska bli täckande utan att tappa handkänslan.
		mat.set_shader_parameter("erosion", 0.10)
		mat.set_shader_parameter("grain_amount", 0.12)
	# −0,25 = "helt uppritad". Vid wipe = 0 ligger svepets mjuka kant precis på
	# vänsterkanten och tunnar ut den (chalk.gdshader: smoothstep runt UV.x).
	mat.set_shader_parameter("wipe", WIPE_DRAWN)
	return mat


## Sätter kritmaterialet på [param node]. Returnerar materialet så att
## anroparen kan animera [code]wipe[/code].
static func apply(node: CanvasItem, profile: StringName = PANEL) -> ShaderMaterial:
	if node == null:
		return null
	var mat: ShaderMaterial = material(profile)
	if mat != null:
		node.material = mat
	return mat


## Squeegee-svepet i UI_GUIDE §5.7: brädets kritstreck sopas bort
## vänster→höger och lämnar smetrester. [param node] behöver materialet från
## [method apply].
static func wipe(node: CanvasItem, seconds: float = 0.3, back: bool = true) -> void:
	if node == null or not node.is_inside_tree():
		return
	var mat: ShaderMaterial = node.material as ShaderMaterial
	if mat == null:
		return
	var tween: Tween = node.create_tween()
	tween.tween_method(
		func(value: float) -> void: mat.set_shader_parameter("wipe", value),
		WIPE_DRAWN, 1.0, seconds)
	if back:
		tween.tween_method(
			func(value: float) -> void: mat.set_shader_parameter("wipe", value),
			1.0, WIPE_DRAWN, seconds * 0.6)
