extends Node
## Ljud, haptik, hit-stop, skak, blixt och number pops. Autoload [code]Juice[/code].
##
## Allt som får kedjan att [i]kännas[/i] går genom den här noden, och den är
## medvetet den enda i projektet som rör [AudioStreamPlayer],
## [method Input.vibrate_handheld] och [member Engine.time_scale]. Skälet är
## tillgänglighet: UI_GUIDE §6.1/§6.4 kräver att skak, hit-stop och haptik ska
## gå att stänga av, och en avstängning som ligger på tjugo anropsställen är
## inte en avstängning.
##
## [b]Tre regler:[/b]
## [br]1. [b]Aldrig krascha på en asset som saknas.[/b] Ett ljud som inte finns
##    räknas i [member sfx_missing], varnar en gång och är sedan tyst. M2 byggs
##    mot namn som UI-agenten levererar parallellt (assets/sfx/<namn>.wav).
## [br]2. [b]Inga allokeringar i uppspelningsloopen.[/b] Number pops, blixt-
##    konturer och ljudkanaler är förinstansierade pooler; [method _process]
##    rör bara redan existerande noder och [PackedArray]-fält.
## [br]3. [b]Allt läser [code]Settings[/code] vid anropet[/b], inte vid start.
##    Ett byte i inställningsskärmen slår igenom nästa event.

## Katalogen UI-agenten levererar WAV-filerna i (assets/sfx/README.md).
const SFX_DIR: String = "res://assets/sfx"
## Samtidiga ljudkanaler. Sex tärningar + combo + träff kan ligga på varandra.
const VOICES: int = 8
## Number pop-poolen. En kedja gör som mest ~12 pops; 24 ger marginal för att
## rundans slut och fiendens svar överlappar kedjans sista pops.
const POP_POOL: int = 24
## Pooldjup för blixtkonturerna i reducerat rörelse-läge.
const OUTLINE_POOL: int = 8
## Tak för hit-stop, PM:s M2-brief. UI_GUIDE §5.6 föreslår 180 ms för
## [code]die_cracked[/code]; 180 ms frys på en telefon läser som en hängning,
## och taket är därför 90 ms. Avvikelsen är avsiktlig och noterad i ARCHITECTURE.
const HIT_STOP_MAX_MS: int = 90
## Tidsskalan under hit-stop. Inte 0: en nollad time_scale stoppar även de
## tweens som ska rita blixten som hit-stoppen finns till för att visa.
const HIT_STOP_SCALE: float = 0.04
## Number pop: stigning i dp och livslängd i sekunder (UI_GUIDE §5.3).
const POP_RISE_DP: float = 24.0
const POP_LIFE: float = 0.30
## Skakens avklingning per sekund.
const SHAKE_DECAY: float = 6.0

## Cues som spelas fler än en gång per runda får ±2 % tonhöjd ovanpå sin regel
## (assets/sfx/README.md §3.4). Under vad örat hör som en annan ton, över vad
## det hör som "exakt samma sampel igen".
const VARIED_SFX: Array[StringName] = [&"die_activate", &"damage_hit", &"ui_tap"]
const VARIATION: float = 0.02
## Mixnivå för UI-tryck (assets/sfx/README.md §2).
const UI_TAP_DB: float = -14.0
## Två haptikpulser närmare varandra än så slås ihop till en, med den starkaste
## nivån (UI_GUIDE §12.5). Skyddar mot SIDE-banan, som kan lägga en light mitt
## i ett kedjesteg: 13 pulser på 2,4 s läser som en vibrerande telefon.
const HAPTIC_MERGE_MS: int = 90

## Skriver varje anrop till konsolen. Sätts av rökprovet.
var verbose: bool = false
## Sparar anropen så att tester och rökprov kan asserta dem.
var log_calls: bool = false
var calls: Array[Dictionary] = []

## Räknare för rökprovets rapport: hur många WAV-filer som faktiskt laddades.
var sfx_loaded: int = 0
## Hur många UNIKA namn som saknade fil.
var sfx_missing: int = 0
## Namn → true för de som saknas. Skrivs ut av rökprovet.
var missing_sfx: Dictionary = {}

var _players: Array[AudioStreamPlayer] = []
var _voice: int = 0
var _streams: Dictionary = {}

var _fx: CanvasLayer = null
var _pops: Array[Label] = []
var _pop_life: PackedFloat32Array = PackedFloat32Array()
var _pop_age: PackedFloat32Array = PackedFloat32Array()
var _pop_from: PackedVector2Array = PackedVector2Array()
var _pop_next: int = 0
var _pops_active: int = 0

var _outlines: Array[Panel] = []
var _outline_style: Array[StyleBoxFlat] = []
var _outline_age: PackedFloat32Array = PackedFloat32Array()
var _outline_life: PackedFloat32Array = PackedFloat32Array()
var _outline_next: int = 0
var _outlines_active: int = 0

var _shake_layers: Array[CanvasLayer] = []
var _shake_amount: float = 0.0
var _shake_left: float = 0.0
var _shake_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _visual_rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _last_haptic_ms: int = -10000
var _last_haptic_level: int = 0

var _hit_stop_left: float = 0.0
var _hit_stop_active: bool = false

## Appen ligger i bakgrunden (Android NOTIFICATION_APPLICATION_PAUSED).
var _audio_suspended: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shake_rng.seed = 0xC0FFEE
	_visual_rng.randomize()
	_build_voices()
	_build_fx_layer()
	set_process(true)


# ---------------------------------------------------------------------------
# Uppbyggnad
# ---------------------------------------------------------------------------

func _build_voices() -> void:
	for i: int in range(VOICES):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "Voice%d" % i
		player.bus = &"Master"
		add_child(player)
		_players.append(player)


func _build_fx_layer() -> void:
	_fx = CanvasLayer.new()
	_fx.name = "JuiceFx"
	# Över ChalkUI (layer 10): number pops och blixtkonturer ska aldrig hamna
	# under en panel. Samma 1080×1920-koordinatrymd som båda spellagren, så en
	# global rect från ett Control kan användas rakt av (ARCHITECTURE §M1).
	_fx.layer = 20
	add_child(_fx)

	_pop_life.resize(POP_POOL)
	_pop_age.resize(POP_POOL)
	_pop_from.resize(POP_POOL)
	for i: int in range(POP_POOL):
		var label: Label = Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.visible = false
		label.add_theme_color_override("font_outline_color", Tokens.SURFACE_PIT)
		label.add_theme_constant_override("outline_size", Tokens.dpi(2))
		_fx.add_child(label)
		_pops.append(label)
		_pop_life[i] = 0.0
		_pop_age[i] = 0.0

	_outline_age.resize(OUTLINE_POOL)
	_outline_life.resize(OUTLINE_POOL)
	for i: int in range(OUTLINE_POOL):
		var panel: Panel = Panel.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.visible = false
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		# UI_GUIDE §12.6: träffblixten ersätts av en 2 dp outline i målets färg.
		var width: int = int(round(Tokens.dp(Tokens.STROKE_REG)))
		style.border_width_left = width
		style.border_width_right = width
		style.border_width_top = width
		style.border_width_bottom = width
		style.border_color = Tokens.CHALK_100
		panel.add_theme_stylebox_override("panel", style)
		_fx.add_child(panel)
		_outlines.append(panel)
		_outline_style.append(style)
		_outline_age[i] = 0.0
		_outline_life[i] = 0.0


# ---------------------------------------------------------------------------
# Ljud
# ---------------------------------------------------------------------------

## Spelar [param sound_name] ur poolen. [param pitch] kommer från
## [method chain_pitch] eller ur [method EventPlayer.feedback].
##
## Filen laddas lat första gången och cachas – även ett [b]misslyckat[/b]
## uppslag cachas, så ett saknat ljud kostar en varning totalt och inte en per
## kedjesteg.
func sfx(sound_name: StringName, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if log_calls:
		calls.append({"kind": "sfx", "name": String(sound_name), "pitch": pitch, "volume_db": volume_db})
	if verbose:
		print("[juice] sfx %s pitch=%.3f" % [sound_name, pitch])
	if _audio_suspended:
		return
	var stream: AudioStream = _stream(sound_name)
	if stream == null:
		return
	var linear: float = Settings.sfx_linear()
	if linear <= 0.0:
		return
	var varied: float = pitch
	if VARIED_SFX.has(sound_name):
		# Slumpen är VISUELL och får aldrig dras ur den seedade Rng-strömmen
		# (ARCHITECTURE: rendering rör inte strömmen).
		varied *= _visual_rng.randf_range(1.0 - VARIATION, 1.0 + VARIATION)
	var player: AudioStreamPlayer = _free_voice()
	player.stream = stream
	player.pitch_scale = clampf(varied, 0.05, 4.0)
	player.volume_db = volume_db + linear_to_db(linear)
	player.play()


## Ljudet som en [AudioStream], eller null när filen saknas.
func _stream(sound_name: StringName) -> AudioStream:
	var key: String = String(sound_name)
	if _streams.has(key):
		return _streams[key] as AudioStream
	var path: String = "%s/%s.wav" % [SFX_DIR, key]
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = ResourceLoader.load(path) as AudioStream
	if stream == null:
		sfx_missing += 1
		missing_sfx[key] = true
		push_warning("Juice: ljudet %s saknas (%s) – tyst stubb" % [key, path])
	else:
		sfx_loaded += 1
	_streams[key] = stream
	return stream


## Fri kanal, annars den äldsta. Round-robin så att sex tärningar i rad inte
## klipper varandra.
func _free_voice() -> AudioStreamPlayer:
	for i: int in range(_players.size()):
		var index: int = (_voice + i) % _players.size()
		if not _players[index].playing:
			_voice = (index + 1) % _players.size()
			return _players[index]
	var fallback: AudioStreamPlayer = _players[_voice]
	_voice = (_voice + 1) % _players.size()
	return fallback


## Ett UI-tryck. Egen funktion därför att nivån är en regel, inte ett val:
## assets/sfx/README.md §2 lägger [code]ui_tap[/code] på −14 dB, och en knapp
## som låter lika mycket som en träff gör kedjan platt.
func ui_tap(pitch: float = 1.0) -> void:
	sfx(&"ui_tap", pitch, UI_TAP_DB)


## Global tonhöjdsregel, UI_GUIDE §5:
## [code]pitch = pow(2, (step + combo_bonus) / 12)[/code], tak 2,0 (en oktav).
## [param step_index] nollställs varje runda, [param multiplier] är kedjestegets
## combomultiplikator (1 / 2 / 4 / 8).
func chain_pitch(step_index: int, multiplier: int = 1) -> float:
	var combo_bonus: int = 0
	match multiplier:
		2:
			combo_bonus = 2
		4:
			combo_bonus = 4
		8, 16:
			combo_bonus = 7
	return minf(2.0, pow(2.0, float(mini(step_index + combo_bonus, 12)) / 12.0))


## Master-bussens index. Allt spelet spelar ligger på den.
const MASTER_BUS: int = 0


## Tystar allt ljud medan appen ligger i bakgrunden, och släpper på igen.
##
## Anropas av [GameController] på Androids
## [code]NOTIFICATION_APPLICATION_PAUSED[/code]/[code]_RESUMED[/code]. Godot
## suspenderar ljuddrivrutinen själv på Android, men inte kanalerna: utan det
## här fortsätter ett halvspelat träffljud när appen kommer tillbaka, flera
## minuter efter att träffen hände.
##
## [b]Hit-stoppen släpps samtidigt.[/b] En paus mitt i en hit-stop lämnar
## annars [member Engine.time_scale] på 0,04, och spelet är obrukbart när
## användaren kommer tillbaka.
func suspend_audio(suspended: bool) -> void:
	if suspended == _audio_suspended:
		return
	_audio_suspended = suspended
	if log_calls:
		calls.append({"kind": "suspend_audio", "suspended": suspended})
	if suspended:
		for player: AudioStreamPlayer in _players:
			if player.playing:
				player.stop()
		if _hit_stop_active:
			_end_hit_stop()
	AudioServer.set_bus_mute(MASTER_BUS, suspended)


func is_audio_suspended() -> bool:
	return _audio_suspended


# ---------------------------------------------------------------------------
# Haptik
# ---------------------------------------------------------------------------

## Vibrerar. [param level] är en [enum Haptics.Level]. Respekterar
## [code]Settings.haptics[/code] via [member Haptics.enabled].
func haptic(level: int) -> void:
	if not Haptics.allows(level):
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_haptic_ms < HAPTIC_MERGE_MS and level <= _last_haptic_level:
		# Sammanslagning: den starkaste nivån i fönstret vinner, och den har
		# redan spelats. En svagare puls ovanpå den känns bara som brus.
		return
	_last_haptic_ms = now
	_last_haptic_level = level
	var duration: int = Haptics.duration_ms(level)
	if log_calls:
		calls.append({"kind": "haptic", "level": level, "ms": duration})
	if verbose:
		print("[juice] haptic level=%d (%d ms)" % [level, duration])
	Haptics.note(level)
	# Desktop och headless har ingen vibrator; anropet är en no-op där, men det
	# ska ändå gå genom samma väg så att loggen är sann på alla plattformar.
	Input.vibrate_handheld(duration)


# ---------------------------------------------------------------------------
# Hit-stop
# ---------------------------------------------------------------------------

## Fryser tiden i [param ms] millisekunder. Aldrig staplat: ett andra anrop
## under en pågående hit-stop ignoreras helt, annars kan en kedja med fyra
## combos frysa spelet i en halv sekund.
## Reducerad rörelse halverar längden (UI_GUIDE §6.1).
func hit_stop(ms: int) -> void:
	if ms <= 0 or _hit_stop_active:
		return
	var duration: int = mini(ms, HIT_STOP_MAX_MS)
	if Settings.reduced_motion:
		duration = duration / 2
	if duration <= 0:
		return
	if log_calls:
		calls.append({"kind": "hit_stop", "ms": duration})
	if verbose:
		print("[juice] hit_stop %d ms" % duration)
	_hit_stop_active = true
	_hit_stop_left = float(duration) / 1000.0
	Engine.time_scale = HIT_STOP_SCALE


func is_hit_stopped() -> bool:
	return _hit_stop_active


func _end_hit_stop() -> void:
	_hit_stop_active = false
	_hit_stop_left = 0.0
	Engine.time_scale = 1.0


# ---------------------------------------------------------------------------
# Skärmskak
# ---------------------------------------------------------------------------

## Registrerar ett lager som skakas. [GameController] registrerar World och
## ChalkUI, så att pixelvärlden och kritan skakar tillsammans.
func register_shake_layer(layer: CanvasLayer) -> void:
	if layer != null and not _shake_layers.has(layer):
		_shake_layers.append(layer)


func clear_shake_layers() -> void:
	for layer: CanvasLayer in _shake_layers:
		if is_instance_valid(layer):
			layer.offset = Vector2.ZERO
	_shake_layers.clear()


## Skärmskak. [param strength] i dp, [param ms] längd.
## UI_GUIDE §6.1: [b]helt av[/b] i reducerat rörelse-läge.
func shake(strength: float, ms: int = 180) -> void:
	if log_calls:
		calls.append({"kind": "shake", "strength": strength, "ms": ms})
	if Settings.reduced_motion or strength <= 0.0 or ms <= 0:
		return
	_shake_amount = maxf(_shake_amount, Tokens.dp(strength))
	_shake_left = maxf(_shake_left, float(ms) / 1000.0)


## Kort skak av en enskild nod (fiendepanel, HP-rad). Egen bana än skärmskaket:
## den här får finnas kvar i reducerat rörelse-läge som en ren uttoning.
func shake_node(node: Control, amplitude: float = 6.0, duration: float = 0.18) -> void:
	if node == null or not node.is_inside_tree():
		return
	if Settings.reduced_motion:
		blink(node, Tokens.CHALK_100, duration)
		return
	var base: Vector2 = node.position
	var px: float = Tokens.dp(amplitude)
	var tween: Tween = node.create_tween()
	var cycles: int = 3
	for i: int in range(cycles):
		var sign_x: float = 1.0 if i % 2 == 0 else -1.0
		tween.tween_property(node, "position", base + Vector2(px * sign_x, 0.0), duration / float(cycles * 2))
		tween.tween_property(node, "position", base, duration / float(cycles * 2))


# ---------------------------------------------------------------------------
# Blixt och puls
# ---------------------------------------------------------------------------

## Vitblixt på en nod. Går via [code]palette_lut.gdshader[/code]:s
## [code]flash[/code]-uniform när noden har materialet (pixellagret), annars via
## [member CanvasItem.modulate].
## Reducerad rörelse byter blixten mot en kontur (UI_GUIDE §6.1: informationen
## ska finnas kvar, rörelsen inte).
func flash(node: CanvasItem, color: Color = Tokens.CHALK_100, ms: int = 140) -> void:
	if node == null or not node.is_inside_tree():
		return
	if log_calls:
		calls.append({"kind": "flash", "ms": ms})
	if Settings.reduced_motion:
		outline(node as Control, color, ms)
		return
	# get_shader_parameter returnerar null för en uniform som inte finns OCH för
	# en som aldrig satts. Art.palette_material sätter alltid flash = 0.0, så
	# "inte null" betyder här "det här är pixellagrets material".
	var material: ShaderMaterial = node.material as ShaderMaterial
	if material != null and material.shader != null and material.get_shader_parameter(&"flash") != null:
		var tween: Tween = node.create_tween()
		tween.tween_method(
			func(value: float) -> void: material.set_shader_parameter("flash", value),
			0.9, 0.0, float(ms) / 1000.0)
		return
	blink(node, color, float(ms) / 1000.0)


## Färgblink via modulate (UI_GUIDE §5.2/5.3).
func blink(node: CanvasItem, color: Color, duration: float = 0.22) -> void:
	if node == null or not node.is_inside_tree():
		return
	var original: Color = node.modulate
	node.modulate = color
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "modulate", original, duration)


## Konturblixt ur poolen. Ritas i [member _fx] ovanför allt annat och tonar ut.
func outline(node: Control, color: Color, ms: int = 140) -> void:
	if node == null or not node.is_inside_tree() or _outlines.is_empty():
		return
	var index: int = _outline_next
	_outline_next = (_outline_next + 1) % _outlines.size()
	var panel: Panel = _outlines[index]
	var rect: Rect2 = node.get_global_rect()
	panel.position = rect.position
	panel.size = rect.size
	_outline_style[index].border_color = color
	panel.modulate.a = 1.0
	panel.visible = true
	_outline_age[index] = 0.0
	_outline_life[index] = maxf(0.05, float(ms) / 1000.0)
	_outlines_active += 1
	set_process(true)


## Skala-puls, UI_GUIDE §5.1: 1,00 → 1,18 → 1,00.
## Reducerad rörelse: ingen overshoot, bara en kort ljusning.
func pulse(node: Control, amount: float = 1.18, duration: float = Tokens.MOTION_BASE) -> void:
	if node == null or not node.is_inside_tree():
		return
	if Settings.reduced_motion:
		blink(node, Tokens.CHALK_100, duration)
		return
	node.pivot_offset = node.size * 0.5
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "scale", Vector2.ONE * amount, duration * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, duration * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------------------
# Number pops
# ---------------------------------------------------------------------------

## Number pop ur poolen (UI_GUIDE §5.3). [param at] är en GLOBAL punkt i
## 1080×1920-rymden; [param parent] används bara som giltighetskontroll, texten
## ritas alltid i [member _fx] så att den aldrig klipps av en panel.
##
## Ingen allokering: etiketterna finns redan, animationen körs i
## [method _process] mot [PackedArray]-fält.
func number_pop(parent: Control, text: String, color: Color, at: Vector2, font_size: int = Tokens.TYPE_DISPLAY_XL) -> Label:
	if _pops.is_empty():
		return null
	if parent != null and not parent.is_inside_tree():
		return null
	if log_calls:
		calls.append({"kind": "pop", "text": text})
	var index: int = _pop_next
	_pop_next = (_pop_next + 1) % _pops.size()
	var label: Label = _pops[index]
	label.text = text
	label.add_theme_color_override("font_color", color)
	# Storlek OCH typsnitt: en number pop i display-xl är Anton (UI_GUIDE §2.8).
	Tokens.apply_type(label, font_size)
	label.visible = true
	label.modulate.a = 1.0
	label.scale = Vector2.ONE if Settings.reduced_motion else Vector2.ONE * 0.6
	label.reset_size()
	label.pivot_offset = label.size * 0.5
	# Klamras inom viewporten: en number pop på den vänstra fienden är bredare
	# än sin panel och skulle annars ritas utanför skärmkanten.
	var screen: Vector2 = Vector2(_fx.get_viewport().get_visible_rect().size)
	var margin: float = Tokens.dp(Tokens.SPACE_2)
	var spot: Vector2 = at - label.size * 0.5
	spot.x = clampf(spot.x, margin, maxf(margin, screen.x - label.size.x - margin))
	spot.y = clampf(spot.y, margin, maxf(margin, screen.y - label.size.y - margin))
	_pop_from[index] = spot
	label.position = _pop_from[index]
	_pop_age[index] = 0.0
	_pop_life[index] = POP_LIFE
	_pops_active += 1
	set_process(true)
	return label


# ---------------------------------------------------------------------------
# Loopen
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	# Hit-stop mäts i OSKALAD tid; annars skulle en frysning på 90 ms ta
	# 90 ms / time_scale att ta slut, alltså över två sekunder.
	if _hit_stop_active:
		_hit_stop_left -= delta / maxf(HIT_STOP_SCALE, 0.0001)
		if _hit_stop_left <= 0.0:
			_end_hit_stop()

	if _shake_left > 0.0:
		_shake_left -= delta
		_shake_amount = maxf(0.0, _shake_amount - _shake_amount * SHAKE_DECAY * delta)
		var offset: Vector2 = Vector2(
			_shake_rng.randf_range(-_shake_amount, _shake_amount),
			_shake_rng.randf_range(-_shake_amount, _shake_amount) * 0.6)
		if _shake_left <= 0.0:
			offset = Vector2.ZERO
			_shake_amount = 0.0
		for layer: CanvasLayer in _shake_layers:
			if is_instance_valid(layer):
				layer.offset = offset

	if _pops_active > 0:
		_step_pops(delta)
	if _outlines_active > 0:
		_step_outlines(delta)


func _step_pops(delta: float) -> void:
	var rise: float = Tokens.dp(POP_RISE_DP)
	var reduced: bool = Settings.reduced_motion
	for i: int in range(_pops.size()):
		if _pop_life[i] <= 0.0:
			continue
		_pop_age[i] += delta
		var t: float = clampf(_pop_age[i] / _pop_life[i], 0.0, 1.0)
		var label: Label = _pops[i]
		label.position = _pop_from[i] - Vector2(0.0, rise * t)
		if not reduced:
			# 0,60 → 1,30 → 1,00 (UI_GUIDE §5.3). Reducerad rörelse: ingen
			# overshoot alls, bara stigningen och uttoningen.
			var scale_value: float = 1.3 - 0.3 * t if t > 0.35 else 0.6 + 2.0 * t
			label.scale = Vector2.ONE * scale_value
		label.modulate.a = 1.0 if t < 0.45 else 1.0 - (t - 0.45) / 0.55
		if t >= 1.0:
			_pop_life[i] = 0.0
			label.visible = false
			_pops_active -= 1


func _step_outlines(delta: float) -> void:
	for i: int in range(_outlines.size()):
		if _outline_life[i] <= 0.0:
			continue
		_outline_age[i] += delta
		var t: float = clampf(_outline_age[i] / _outline_life[i], 0.0, 1.0)
		_outlines[i].modulate.a = 1.0 - t
		if t >= 1.0:
			_outline_life[i] = 0.0
			_outlines[i].visible = false
			_outlines_active -= 1


# ---------------------------------------------------------------------------
# Test- och rökprovsstöd
# ---------------------------------------------------------------------------

func reset_log() -> void:
	calls.clear()


## Nollställer räknare och cache. Används av tester som vill mäta laddningen.
func reset_sfx_cache() -> void:
	_streams.clear()
	missing_sfx.clear()
	sfx_loaded = 0
	sfx_missing = 0


## Antal anrop av en viss sort i loggen. Bekvämlighet för tester.
func count_calls(kind: String) -> int:
	var total: int = 0
	for entry: Dictionary in calls:
		if String(entry.get("kind", "")) == kind:
			total += 1
	return total
