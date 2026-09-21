class_name Juice
extends RefCounted
## Ljud, haptik och de små tweenarna som UI_GUIDE §5 kallar "feedback-spec".
##
## M1 levererar [b]stubbar[/b] för ljud och haptik och [b]riktiga men enkla[/b]
## tweenar för det visuella. Poängen med att skriva stubbarna nu är att
## anropsställena och tonhöjdsregeln ska sitta på rätt plats i tidslinjen; M2
## byter bara ut kroppen i [method sfx] mot en riktig [AudioStreamPlayer]-pool.

## Skriver varje anrop till konsolen. Sätts av smoke-scriptet.
static var verbose: bool = false
## Sparar anropen så att tester och smoke-körning kan asserta dem.
static var log_calls: bool = false
static var calls: Array[Dictionary] = []


## Ljudstubb. [param pitch] kommer från [method chain_pitch].
static func sfx(sound_name: String, pitch: float = 1.0) -> void:
	if log_calls:
		calls.append({"kind": "sfx", "name": sound_name, "pitch": pitch})
	if verbose:
		print("[juice] sfx %s pitch=%.3f" % [sound_name, pitch])
	# M2: spela upp sound_name ur en förladdad pool med pitch_scale = pitch.


## Haptikstubb. [param level] är en [enum Haptics.Level].
static func haptic(level: int) -> void:
	if log_calls:
		calls.append({"kind": "haptic", "level": level})
	if verbose:
		print("[juice] haptic level=%d" % level)
	Haptics.pulse(level)


## Global tonhöjdsregel, UI_GUIDE §5:
## [code]pitch = pow(2, (step + combo_bonus) / 12)[/code], tak 2,0 (en oktav).
## [param step_index] nollställs varje runda, [param multiplier] är kedjesteget's
## combomultiplikator (1 / 2 / 4 / 8).
static func chain_pitch(step_index: int, multiplier: int = 1) -> float:
	var combo_bonus: int = 0
	match multiplier:
		2:
			combo_bonus = 2
		4:
			combo_bonus = 4
		8, 16:
			combo_bonus = 7
	return minf(2.0, pow(2.0, float(step_index + combo_bonus) / 12.0))


static func reset_log() -> void:
	calls.clear()


# --- Visuella placeholder-effekter ----------------------------------------
# Alla tar emot noden och returnerar direkt; de skapar en egen Tween så att
# uppspelaren aldrig behöver vänta in dem (UI_GUIDE §5.8: överlappande banor).

## Skala-puls, UI_GUIDE §5.1: 1,00 → 1,18 → 1,00.
static func pulse(node: Control, amount: float = 1.18, duration: float = Tokens.MOTION_BASE) -> void:
	if node == null or not node.is_inside_tree():
		return
	node.pivot_offset = node.size * 0.5
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "scale", Vector2.ONE * amount, duration * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, duration * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Kort horisontell skak, UI_GUIDE §5.3. [param amplitude] i dp.
static func shake(node: Control, amplitude: float = 6.0, duration: float = 0.18) -> void:
	if node == null or not node.is_inside_tree():
		return
	var base: Vector2 = node.position
	var px: float = Tokens.dp(amplitude)
	var tween: Tween = node.create_tween()
	var cycles: int = 3
	for i: int in range(cycles):
		var sign_x: float = 1.0 if i % 2 == 0 else -1.0
		tween.tween_property(node, "position", base + Vector2(px * sign_x, 0.0), duration / float(cycles * 2))
		tween.tween_property(node, "position", base, duration / float(cycles * 2))


## Färgblink, UI_GUIDE §5.2/5.3: vit blixt som tonar tillbaka.
static func blink(node: CanvasItem, color: Color, duration: float = 0.22) -> void:
	if node == null or not node.is_inside_tree():
		return
	var original: Color = node.modulate
	node.modulate = color
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "modulate", original, duration)


## Number pop, UI_GUIDE §5.3: Anton-siffra som stiger 24 dp och tonar ut.
## Läggs som barn till [param parent] och städar upp sig själv.
static func number_pop(parent: Control, text: String, color: Color, at: Vector2, font_size: int = Tokens.TYPE_DISPLAY_XL) -> Label:
	if parent == null or not parent.is_inside_tree():
		return null
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", Tokens.dpi(font_size))
	label.add_theme_color_override("font_outline_color", Tokens.SURFACE_PIT)
	label.add_theme_constant_override("outline_size", Tokens.dpi(2))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 50
	parent.add_child(label)
	label.reset_size()
	label.position = at - label.size * 0.5
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE * 0.6

	# Två tweenar i stället för en med parallel/chain-mix: skalan och
	# rörelsen har olika längd och blandad kedjning är lätt att få fel.
	var scale_tween: Tween = label.create_tween()
	scale_tween.tween_property(label, "scale", Vector2.ONE * 1.3, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(label, "scale", Vector2.ONE, 0.08)

	var drift_tween: Tween = label.create_tween()
	drift_tween.set_parallel(true)
	drift_tween.tween_property(label, "position", label.position - Vector2(0.0, Tokens.dp(24)), 0.26)
	drift_tween.tween_property(label, "modulate:a", 0.0, 0.18).set_delay(0.08)
	drift_tween.set_parallel(false)
	drift_tween.tween_callback(label.queue_free)
	return label
