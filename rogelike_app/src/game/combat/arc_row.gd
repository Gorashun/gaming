class_name ArcRow
extends Control
## Multiplikatorbågarna ovanför slotraden. COMBAT_READABILITY §2.3.
##
## Diagnosen i §1.4 punkt 22: [i]"Multiplikatorbåge saknas helt. Därmed är
## parets orsak – två lika värden bredvid varandra – osynlig."[/i] Betyg 1/10.
## Wireframen har haft bågen sedan M1; den byggdes aldrig.
##
## Bågen spänner över exakt de slots som ingår i gruppen, med etiketten
## [code]×2 PAIR · BOTH 5[/code] – tre delar: multiplikator, gruppnamn och
## [b]varför[/b] (det gemensamma värdet). [code]HOUSE[/code] ritas som en andra,
## yttre båge över hela brädet.
##
## Ren [method Control._draw] plus en [Label] per båge: ingen sprite, ingen
## shader, inget som kan sakna en fil (§9).

## Radens höjd i dp. Två lager (grupper + HOUSE) kräver 32 (§2.3).
const HEIGHT_ONE: int = 20
const HEIGHT_TWO: int = 32
## Avstånd mellan inre och yttre båge, i dp.
const OUTER_GAP: int = 4
## Linjetjocklek i dp.
const STROKE: float = 2.0

## [{slots, multiplier, kind, value, outer}] ur [ChainReceipt].
var _arcs: Array[Dictionary] = []
## Slotens vänster/höger i radens lokala x-led.
var _spans: Array[Vector2] = []
var _labels: Array[Label] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0.0, Tokens.dp(HEIGHT_ONE))
	clip_contents = false


## [param arcs] kommer ur kvittot, [param spans] är varje slots x-intervall i
## den här nodens koordinater. Skärmen äger layouten; bågen ritar bara.
func set_arcs(arcs: Array, spans: Array[Vector2]) -> void:
	_arcs.clear()
	for entry: Variant in arcs:
		_arcs.append(entry as Dictionary)
	_spans = spans.duplicate()
	custom_minimum_size.y = Tokens.dp(HEIGHT_TWO if _has_outer() else HEIGHT_ONE)
	_rebuild_labels()
	queue_redraw()


func _has_outer() -> bool:
	for arc: Dictionary in _arcs:
		if bool(arc.get("outer", false)):
			return true
	return false


func _rebuild_labels() -> void:
	for label: Label in _labels:
		label.queue_free()
	_labels.clear()
	for arc: Dictionary in _arcs:
		var span: Vector2 = _span_of(arc)
		if span.y <= span.x:
			continue
		var label: Label = Label.new()
		label.text = label_text(arc)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_CAPTION - 2))
		label.add_theme_color_override("font_color", _color(arc))
		# Bakgrundsplatta så att texten aldrig ligger ovanpå sin egen linje.
		var plate: StyleBoxFlat = StyleBoxFlat.new()
		plate.bg_color = Tokens.SURFACE_PIT
		plate.content_margin_left = Tokens.dp(4)
		plate.content_margin_right = Tokens.dp(4)
		label.add_theme_stylebox_override("normal", plate)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# INTE clip_text: en klippt Label rapporterar minsta bredd noll, och då
		# blir plattan en centimeter bred och etiketten läser "R · E".
		label.clip_text = false
		add_child(label)
		_labels.append(label)
	_place_labels()


func _place_labels() -> void:
	for i: int in range(mini(_labels.size(), _arcs.size())):
		var arc: Dictionary = _arcs[i]
		var span: Vector2 = _span_of(arc)
		var label: Label = _labels[i]
		# Plattan ska vara precis så bred som texten. Tidigare spände den över
		# hela bågen och målade över topplinjen, så klammern syntes bara som två
		# lösa streck – exakt det §1.4 punkt 22 klagade på.
		var width: float = label.get_combined_minimum_size().x + Tokens.dp(8)
		label.size = Vector2(width, Tokens.dp(12))
		label.position = Vector2((span.x + span.y) * 0.5 - width * 0.5, _top_of(arc) - Tokens.dp(6))


## [code]×2 PAIR · BOTH 5[/code]. Tre delar, och den tredje är varför.
## [code]HOUSE[/code] får sin egen form: [code]HOUSE ×2 · TRIPLE + PAIR[/code].
static func label_text(arc: Dictionary) -> String:
	var multiplier: int = int(arc.get("multiplier", 1))
	var kind: String = String(arc.get("kind", ""))
	if kind == "HOUSE":
		return Tokens.translate_or("COMBAT_ARC_HOUSE", "HOUSE ×%d · TRIPLE + PAIR") % multiplier
	var fallback: String = "×%%d %s · ALL %%d" % kind
	return Tokens.translate_or("COMBAT_ARC_%s" % kind, fallback) % [
		multiplier, int(arc.get("value", 0))]


static func _color(arc: Dictionary) -> Color:
	if String(arc.get("kind", "")) == "HOUSE":
		return Tokens.SEM_CHARGE
	return Tokens.multiplier_color(int(arc.get("multiplier", 1)))


func _span_of(arc: Dictionary) -> Vector2:
	var low: float = INF
	var high: float = -INF
	for entry: Variant in arc.get("slots", []) as Array:
		var index: int = int(entry)
		if index < 0 or index >= _spans.size():
			continue
		low = minf(low, _spans[index].x)
		high = maxf(high, _spans[index].y)
	if low == INF:
		return Vector2.ZERO
	return Vector2(low, high)


func _top_of(arc: Dictionary) -> float:
	if bool(arc.get("outer", false)):
		return Tokens.dp(2)
	return Tokens.dp(OUTER_GAP + 2) if _has_outer() else Tokens.dp(2)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place_labels()


func _draw() -> void:
	for arc: Dictionary in _arcs:
		var span: Vector2 = _span_of(arc)
		if span.y <= span.x:
			continue
		var top: float = _top_of(arc)
		var bottom: float = size.y
		var color: Color = _color(arc)
		var width: float = Tokens.dp(STROKE)
		var radius: float = Tokens.dp(6)
		# Klammern: ned – in – längs toppen – in – ned. Ritad med raka linjer och
		# ett hörnsteg i stället för en kurva, eftersom kritjittret i
		# chalk.gdshader annars gör radien oregelbunden mellan bågarna.
		draw_line(Vector2(span.x, bottom), Vector2(span.x, top + radius), color, width, false)
		draw_line(Vector2(span.x, top + radius), Vector2(span.x + radius, top), color, width, false)
		draw_line(Vector2(span.x + radius, top), Vector2(span.y - radius, top), color, width, false)
		draw_line(Vector2(span.y - radius, top), Vector2(span.y, top + radius), color, width, false)
		draw_line(Vector2(span.y, top + radius), Vector2(span.y, bottom), color, width, false)
