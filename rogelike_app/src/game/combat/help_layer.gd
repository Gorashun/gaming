class_name HelpLayer
extends Control
## "?"-lagret. COMBAT_READABILITY §6.
##
## [b]Tänder alla förklaringar samtidigt.[/b] Ingen stegvis guide, ingen
## "nästa"-knapp, ingen ordning: bakgrunden dimmas, sex callouts tänds, var och
## en med RUBRIK + [b]en[/b] mening och en streckad ledarlinje till sitt element.
## Hela lagret är en stängknapp.
##
## Max sex callouts. Fler får inte plats på 360 dp utan att täcka varandra, och
## sju meningar är inte längre en hjälp utan en manual (§6). Långtryck på
## enskilda element (§3) är fördjupningen.
##
## [b]Reducerad rörelse:[/b] ingen inflygning, ingen skala – bara opacitet
## 0 → 1 på 200 ms, och ledarlinjerna ritas statiskt (§6).
##
## Färg bär ingen information: gul kontur + svart platta + vit text ger 12:1.

signal closed()

## Normativt tak (§6).
const MAX_CALLOUTS: int = 6
const FADE_SECONDS: float = 0.2
## Kortets bredd i dp.
const CARD_WIDTH: int = 272

## De sex meningarna (§6). Engelska källsträngar; svenskan är en CSV-rad.
## [code]anchor[/code] är namnet skärmen använder i [method show_for].
const CALLOUTS: Array[Dictionary] = [
	{"anchor": "charge", "key": "COMBAT_HELP_CHARGE", "title_key": "COMBAT_HELP_CHARGE_TITLE",
		"title": "Charge", "en": "Dice you don't place become Charge. Next round it is added to your leftmost die."},
	{"anchor": "receipt", "key": "COMBAT_HELP_MATH", "title_key": "COMBAT_HELP_MATH_TITLE",
		"title": "The sum", "en": "Left to right, slot by slot. Exactly this happens when you press Confirm — no randomness left."},
	{"anchor": "enemies", "key": "COMBAT_HELP_ENEMY", "title_key": "COMBAT_HELP_ENEMY_TITLE",
		"title": "The enemy", "en": "Armor is subtracted from every hit. \"Attacks 3\" is what it does to you once your chain is done."},
	{"anchor": "board", "key": "COMBAT_HELP_BOARD", "title_key": "COMBAT_HELP_BOARD_TITLE",
		"title": "The board", "en": "The arc means two equal values side by side double. Three in a row give ×4. The line under the slot name is the whole rule."},
	{"anchor": "tray", "key": "COMBAT_HELP_TRAY", "title_key": "COMBAT_HELP_TRAY_TITLE",
		"title": "The tray", "en": "Empty sockets are dice that are already on the board. Tap a die, then tap a slot."},
	{"anchor": "confirm", "key": "COMBAT_HELP_CONFIRM", "title_key": "COMBAT_HELP_CONFIRM_TITLE",
		"title": "Confirm", "en": "The number on the button is the damage you deal. Then the enemies hit back."},
]

var _scrim: ColorRect = null
var _leaders: Control = null
var _cards: Array[Control] = []
## [{from: Vector2, to: Vector2}] i lagrets koordinater.
var _lines: Array[Dictionary] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_scrim = ColorRect.new()
	_scrim.name = "Scrim"
	# 80 % svart (§6). Inte scrim-token: hjälpen ska dimma HÅRDARE än en modal,
	# så att callout-texten är det enda som har kontrast.
	_scrim.color = Color(0.0, 0.0, 0.0, 0.8)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scrim)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_leaders = LeaderLines.new()
	_leaders.name = "Leaders"
	_leaders.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_leaders)
	_leaders.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## De streckade ledarlinjerna. Egen nod så att korten kan ligga ovanpå dem.
class LeaderLines:
	extends Control

	var lines: Array[Dictionary] = []
	const DASH: float = 8.0

	func _draw() -> void:
		for entry: Dictionary in lines:
			var from: Vector2 = entry["from"] as Vector2
			var to: Vector2 = entry["to"] as Vector2
			var length: float = from.distance_to(to)
			if length <= 0.0:
				continue
			var step: Vector2 = (to - from).normalized() * DASH
			var drawn: float = 0.0
			var cursor: Vector2 = from
			while drawn < length:
				var next: Vector2 = cursor + step
				draw_line(cursor, next, Tokens.SEM_CHARGE, 2.0, false)
				cursor = next + step
				drawn += DASH * 2.0


## Öppnar lagret. [param anchors] är [code]{anchor_name: Control}[/code]; en
## ankare som saknas hoppas över, så att lagret aldrig pekar på ett tomt hål när
## ett element är dolt av [Reveal].
func show_for(anchors: Dictionary) -> void:
	_clear()
	var used: int = 0
	for spec: Dictionary in CALLOUTS:
		if used >= MAX_CALLOUTS:
			break
		var anchor: Control = anchors.get(String(spec["anchor"]), null) as Control
		if anchor == null or not is_instance_valid(anchor) or not anchor.is_inside_tree() or not anchor.visible:
			continue
		_add_callout(spec, anchor)
		used += 1
	visible = true
	if Settings.reduced_motion:
		modulate.a = 1.0
	else:
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, FADE_SECONDS)
	# Layouten är klar först nästa bildruta; ledarlinjerna ritas då.
	call_deferred("_place")


func _add_callout(spec: Dictionary, anchor: Control) -> void:
	var card: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = Tokens.box(Tokens.SEM_CHARGE, true, Tokens.STROKE_REG, Tokens.RADIUS_BUTTON)
	style.bg_color = Color(0.0, 0.0, 0.0, 0.92)
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(Tokens.dp(CARD_WIDTH), 0.0)
	add_child(card)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Tokens.dpi(Tokens.SPACE_2))
	card.add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	var title: Label = Label.new()
	title.text = Tokens.translate_or(String(spec["title_key"]), String(spec["title"]))
	title.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_CAPTION - 1))
	title.add_theme_color_override("font_color", Tokens.SEM_CHARGE)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)

	var body: Label = Label.new()
	body.text = Tokens.translate_or(String(spec["key"]), String(spec["en"]))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_LABEL))
	body.add_theme_color_override("font_color", Tokens.CHALK_100)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(body)

	# [b]En radbrytande Label rapporterar EN rads höjd som minsta storlek.[/b]
	# Godot kan inte veta bättre: höjden beror på bredden, och bredden sätts av
	# föräldern. Frågar man ändå får man 100 px för ett kort som ritas 300 px
	# högt – och då staplas sex callouts ovanpå varandra. Vi mäter texten själva
	# mot den bredd kortet faktiskt kommer att ha.
	var inner: float = Tokens.dp(CARD_WIDTH) - 2.0 * float(Tokens.dpi(Tokens.SPACE_2))
	# Mät mot en SMALARE bredd än kortet faktiskt har. Panelens ram och dess
	# inre kantmarginaler äter några pixlar som vi inte kan fråga efter innan
	# layouten kört, och en underskattad höjd betyder att nästa kort lägger sig
	# ovanpå den sista textraden. Att överskatta kostar bara lite luft.
	var text_height: float = measured_height(body, inner - Tokens.dp(12))
	body.custom_minimum_size = Vector2(inner, text_height)

	card.set_meta(&"anchor", anchor)
	# Kortets höjd räknas ut HÄR och lagras, i stället för att frågas efter i
	# _place(). get_combined_minimum_size() på en radbrytande Label svarar med
	# EN rads höjd tills layouten kört, och _place() körs före det – korten
	# staplades därför på ett mått som var tre gånger för litet.
	card.set_meta(&"height", text_height
		+ float(Tokens.dpi(Tokens.TYPE_CAPTION - 1)) * 1.4
		+ 2.0 * float(Tokens.dpi(Tokens.SPACE_2))
		+ 2.0 * Tokens.dp(Tokens.STROKE_REG))
	_cards.append(card)


## Textens verkliga höjd vid bredden [param width]. Saknas temats typsnitt
## faller vi tillbaka på en rimlig uppskattning i stället för att returnera 0 –
## ett kort med höjd 0 är osynligt, vilket är värre än ett som är lite för högt.
static func measured_height(label: Label, width: float) -> float:
	var font: Font = label.get_theme_font(&"font")
	var font_size: int = label.get_theme_font_size(&"font_size")
	if font == null or font_size <= 0:
		return float(label.text.length()) / maxf(1.0, width / 12.0) * 24.0
	return font.get_multiline_string_size(
		label.text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size).y


## Placerar korten. [b]Sex callouts får aldrig täcka varandra[/b] (§6: "fler får
## inte plats på 360 dp utan att täcka varandra") – ett kort som ligger ovanpå
## ett annat är värre än ingen hjälp alls, eftersom spelaren då läser en halv
## mening och tror att det är hela.
##
## Reglerna, i ordning:
## [br]1. Korten sorteras efter sitt ankares y-läge, så att ordningen på skärmen
##    följer ordningen i spelet.
## [br]2. De staplas uppifrån och ned. Varje kort vill ligga bredvid sitt ankare
##    men skjuts ned tills det inte krockar med det förra.
## [br]3. Går stapeln utanför nederkanten dras hela stapeln upp lika mycket.
##    Hellre alla sex lite fel än ett av dem utanför skärmen.
func _place() -> void:
	_lines.clear()
	var ordered: Array[Control] = []
	for card: Control in _cards:
		if is_instance_valid(card) and _anchor_of(card) != null:
			ordered.append(card)
	ordered.sort_custom(func(a: Control, b: Control) -> bool:
		return _anchor_of(a).get_global_rect().position.y < _anchor_of(b).get_global_rect().position.y)

	var gap: float = Tokens.dp(Tokens.SPACE_2)
	var margin: float = Tokens.dp(Tokens.SCREEN_MARGIN)

	var rects: Array[Rect2] = []
	var cursor: float = margin
	for card: Control in ordered:
		if not is_instance_valid(card) or _anchor_of(card) == null:
			continue
		var target: Rect2 = _anchor_of(card).get_global_rect()
		var card_size: Vector2 = Vector2(Tokens.dp(CARD_WIDTH), float(card.get_meta(&"height", 0.0)))
		var x: float = clampf(target.get_center().x - card_size.x * 0.5,
			margin, maxf(margin, size.x - card_size.x - margin))
		var y: float = maxf(cursor, target.position.y - card_size.y * 0.5)
		rects.append(Rect2(Vector2(x, y), card_size))
		cursor = y + card_size.y + gap

	# Stapeln fick inte plats: dra upp allt lika mycket i stället för att
	# klämma ihop korten, så att avstånden förblir jämna.
	var overflow: float = (cursor - gap) - (size.y - margin)
	if overflow > 0.0:
		for i: int in range(rects.size()):
			rects[i].position.y = maxf(margin, rects[i].position.y - overflow)

	for i: int in range(mini(ordered.size(), rects.size())):
		var card: Control = ordered[i]
		var rect: Rect2 = rects[i]
		card.position = rect.position
		card.size = rect.size
		var target: Rect2 = _anchor_of(card).get_global_rect()
		_lines.append({
			"from": Vector2(rect.get_center().x,
				rect.end.y if rect.get_center().y < target.get_center().y else rect.position.y),
			"to": target.get_center(),
		})
	var leaders: LeaderLines = _leaders as LeaderLines
	leaders.lines = _lines
	leaders.queue_redraw()


static func _anchor_of(card: Control) -> Control:
	var anchor: Control = card.get_meta(&"anchor") as Control
	if anchor == null or not is_instance_valid(anchor) or not anchor.is_inside_tree():
		return null
	return anchor


func _clear() -> void:
	for card: Control in _cards:
		if is_instance_valid(card):
			card.queue_free()
	_cards.clear()
	_lines.clear()


## Stängs vid tapp var som helst – hela lagret är en stängknapp (§6).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close()
		accept_event()


func close() -> void:
	if not visible:
		return
	visible = false
	_clear()
	closed.emit()


func is_open() -> bool:
	return visible
