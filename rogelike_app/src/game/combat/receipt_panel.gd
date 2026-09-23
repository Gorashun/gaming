class_name ReceiptPanel
extends PanelContainer
## Kvittot på skärmen. COMBAT_READABILITY §2.1 och TOWN_AND_ONBOARDING §B.3.
##
## Tre lager, uppifrån och ned:
## [codeblock]
## (a)  2  +  10  +  10  +  6  +  12  =  40      meningen, ett tal per slot
##    slot1  slot2  slot3  slot4 slot5
## (b)  40 − 12 armor (2 per hit × 6 hits) = 28 damage
## (c)  ① 2 − 2 = 0      stopped dead by armour
##      ② 10 − 2 = 8     → Rust Rat 1   28 → 20
## [/codeblock]
##
## Rad (b) är [i]"den enskilt viktigaste ändringen i hela dokumentet"[/i]
## (§B.3): den kostar en [Label] och är skillnaden mellan "spelet är slump" och
## "jag förstår vad som hände". Är rustningsavdraget 0 visas raden inte alls.
##
## Panelen räknar ingenting. Allt kommer ur [ChainReceipt], som i sin tur bara
## läser [code]_preview.events[/code].

## Matematikkolumnens bredd i dp. Fast bredd, så att de fem minustecknen ligger
## i lodrät linje – det är den linjen som får hjärnan att se mönstret
## "rustning varje gång" (§2.1c).
const MATH_WIDTH: int = 96
## Max antal leveransrader innan listan klipps. 5 slots + DOMINO + spill.
const MAX_LINES: int = 6

var _column: VBoxContainer = null
var _header: Label = null
var _honest: Label = null
var _sentence: HBoxContainer = null
var _armor_line: Label = null
var _extra_line: Label = null
var _lines: VBoxContainer = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	# M6: kedjeuträkningen sätts direkt på svart, utan panel (ART_DIRECTION_V2
	# §4). Innermarginalen står kvar så att höjdbudgeten inte flyttar sig.
	var flat: StyleBoxFlat = StyleBoxFlat.new()
	flat.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	var pad: float = Tokens.dp(Tokens.STROKE_HAIR)
	flat.content_margin_left = pad
	flat.content_margin_right = pad
	flat.content_margin_top = pad
	flat.content_margin_bottom = pad
	if Tokens.high_contrast:
		flat = Tokens.box(Tokens.SURFACE_LINE, true, Tokens.STROKE_HAIR)
	add_theme_stylebox_override("panel", flat)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, Tokens.dpi(Tokens.SPACE_2))
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Tokens.dpi(Tokens.SPACE_1))
	add_child(margin)

	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", 0)
	margin.add_child(_column)

	var head: HBoxContainer = HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(head)

	_header = _label(Tokens.TYPE_CAPTION - 2, Tokens.CHALK_500)
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_header)

	# Löftet, utskrivet: när spelaren trycker Bekräfta finns ingen slump kvar
	# (GAME_DESIGN §6). Det är spelets viktigaste påstående och det står aldrig
	# någonstans i M2.
	_honest = _label(Tokens.TYPE_CAPTION - 2, Tokens.SEM_CHARGE)
	_honest.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_honest.text = Tokens.translate_or("COMBAT_NO_RANDOMNESS", "NO RANDOMNESS LEFT")
	head.add_child(_honest)

	_sentence = HBoxContainer.new()
	_sentence.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sentence.alignment = BoxContainer.ALIGNMENT_CENTER
	_sentence.add_theme_constant_override("separation", Tokens.dpi(2))
	_column.add_child(_sentence)

	# 11 dp: raden "40 rolled − 12 armor (2 per hit × 6 hits) = 28 DAMAGE" är
	# lång med flit (§B.3) och måste rymmas på 360 dp utan att klippas.
	_armor_line = _label(Tokens.TYPE_CAPTION - 1, Tokens.CHALK_300)
	_armor_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(_armor_line)

	_extra_line = _label(Tokens.TYPE_CAPTION - 2, Tokens.SEM_FIRE)
	_extra_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(_extra_line)

	_lines = VBoxContainer.new()
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.add_theme_constant_override("separation", 0)
	_column.add_child(_lines)


static func _label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", Tokens.dpi(maxi(8, font_size)))
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func set_header(text: String) -> void:
	_header.text = text


## Hela kvittot. [param names] är fiendenamn per index ("Rust Rat 1"), redan
## översatta — panelen innehåller ingen uppslagning.
## [param show_armor_line] följer Reveal: rustningsraden finns inte förrän
## lektionen givits, och då är all rustning 0 ändå.
func show_receipt(receipt: Dictionary, names: PackedStringArray, show_armor_line: bool) -> void:
	_build_sentence(receipt)
	_build_armor_line(receipt, show_armor_line)
	_build_lines(receipt, names, show_armor_line)


# --- (a) Meningen ----------------------------------------------------------

func _build_sentence(receipt: Dictionary) -> void:
	for child: Node in _sentence.get_children():
		child.queue_free()
	var slots: Array = receipt["slots"] as Array
	var first: bool = true
	for entry: Variant in slots:
		var slot: Dictionary = entry as Dictionary
		if not bool(slot["occupied"]):
			continue
		if not first:
			_sentence.add_child(_operator("+"))
		first = false
		_sentence.add_child(_term(
			str(int(slot["amount"])),
			Tokens.translate_or("COMBAT_SLOT_CAPTION", "slot %d") % (int(slot["slot"]) + 1),
			_term_color(slot),
			Tokens.TYPE_BODY_L))
	if first:
		# Ingen tärning placerad: meningen är tom, men totalen ska stå kvar så
		# att spelaren ser att noll är ett giltigt drag (GAME_DESIGN §7 fråga 4).
		_sentence.add_child(_term("0", "", Tokens.CHALK_500, Tokens.TYPE_BODY_L))
	_sentence.add_child(_operator("="))
	_sentence.add_child(_term(str(int(receipt["raw"])), "", Tokens.CHALK_100, Tokens.TYPE_HEADING))


## Färgkodningen i §2.1a: multiplicerade tal i multiplikatorfärgen, Amboss-
## dubblade i sem/shield, Ward i grått, Laddning i sem/charge.
static func _term_color(slot: Dictionary) -> Color:
	match String(slot["outcome"]):
		ChainReceipt.OUT_WARD:
			return Tokens.SEM_SHIELD
		ChainReceipt.OUT_CHARGE:
			return Tokens.SEM_CHARGE
	if int(slot["multiplier"]) > 1:
		return Tokens.multiplier_color(int(slot["multiplier"]))
	if bool(slot.get("doubled", false)):
		return Tokens.SEM_SHIELD
	return Tokens.CHALK_100


func _operator(text: String) -> Label:
	var label: Label = _label(Tokens.TYPE_BODY, Tokens.CHALK_500)
	label.clip_text = false
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


## Ett tal med sin 8 dp mikroetikett under, så att blicken kan hoppa mellan
## meningen och brädet (§2.1a).
func _term(value: String, tick: String, color: Color, font_size: int) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	var number: Label = _label(font_size, color)
	number.text = value
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# INTE clip_text. §8 är normativ: "räknestyckets mening bryts aldrig". En
	# klippt Label rapporterar minsta bredd noll, och i en HBoxContainer blir
	# talen då noll pixlar breda – meningen försvinner helt och bara de små
	# slot-etiketterna blir kvar som streck.
	number.clip_text = false
	box.add_child(number)
	var caption: Label = _label(Tokens.TYPE_CAPTION - 4, Tokens.CHALK_500)
	caption.text = tick
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.clip_text = false
	box.add_child(caption)
	return box


# --- (b) Rustningsraden ----------------------------------------------------

func _build_armor_line(receipt: Dictionary, show_armor_line: bool) -> void:
	var raw: int = int(receipt["raw"])
	var armor: int = int(receipt["armor"])
	var damage: int = int(receipt["damage"])
	var hits: int = int(receipt["hits"])
	var per_hit: int = int(receipt["armor_per_hit"])

	_armor_line.visible = armor > 0 and show_armor_line
	if _armor_line.visible:
		# "40 rolled − 12 armor (2 per hit × 6 hits) = 28 DAMAGE".
		# §B.3: "den enskilt viktigaste ändringen i hela dokumentet".
		var text: String = Tokens.translate_or("COMBAT_RECEIPT_SUMMARY",
			"%d rolled − %d armor") % [raw, armor]
		if per_hit > 0 and hits > 0:
			text += " (%s)" % (Tokens.translate_or("COMBAT_RECEIPT_ARMOR_NOTE",
				"%d per hit × %d hits") % [per_hit, hits])
		text += " = %s" % (Tokens.translate_or("COMBAT_RECEIPT_TOTAL", "%d DAMAGE") % damage)
		_armor_line.text = text

	# Övriga termer i §2.1b: ward, laddning och spill utan mål. De visas bara
	# när de är nollskilda, och max tre i taget.
	var terms: PackedStringArray = PackedStringArray()
	if int(receipt["ward"]) > 0:
		terms.append(Tokens.translate_or("COMBAT_RECEIPT_TO_WARD", "→ %d ward") % int(receipt["ward"]))
	if int(receipt["charge"]) > 0:
		terms.append(Tokens.translate_or("COMBAT_RECEIPT_TO_CHARGE", "→ %d charge") % int(receipt["charge"]))
	if int(receipt["wasted"]) > 0:
		terms.append(Tokens.translate_or("COMBAT_TERM_WASTED", "%d spilled with no target") % int(receipt["wasted"]))
	if int(receipt["status_tick"]) > 0:
		terms.append(Tokens.translate_or("COMBAT_TERM_STATUS", "+%d at end of round") % int(receipt["status_tick"]))
	_extra_line.text = " · ".join(terms)
	_extra_line.visible = not terms.is_empty()


# --- (c) Leveransraderna ---------------------------------------------------

func _build_lines(receipt: Dictionary, names: PackedStringArray, show_armor_line: bool) -> void:
	for child: Node in _lines.get_children():
		child.queue_free()
	var lines: Array = receipt["lines"] as Array
	for i: int in range(mini(lines.size(), MAX_LINES)):
		_lines.add_child(_delivery_row(lines[i] as Dictionary, names, show_armor_line))


func _delivery_row(line: Dictionary, names: PackedStringArray, show_armor_line: bool) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_1))

	var dealt: int = int(line["dealt"])
	var dimmed: bool = dealt <= 0
	# Rader som ger 0 skada gråas men tas ALDRIG bort – de är lektionen om
	# rustning (§2.1c).
	var ink: Color = Tokens.CHALK_500 if dimmed else Tokens.CHALK_300

	var badge: Label = _label(Tokens.TYPE_CAPTION - 3, ink)
	# ⮡ och inte ↳: U+21B3 saknas i båda de buntade fonterna, U+2BA1 finns i
	# Noto Sans Symbols 2 (assets/fonts/, docs/BACKLOG.md).
	badge.text = "⮡" if bool(line["is_overflow"]) else SlotView.circled(int(line["slot"]) + 1)
	badge.custom_minimum_size = Vector2(Tokens.dp(14), 0.0)
	row.add_child(badge)

	var math: Label = _label(Tokens.TYPE_CAPTION - 3, ink)
	if int(line["blocked"]) > 0 and show_armor_line:
		math.text = Tokens.translate_or("COMBAT_RECEIPT_LINE", "%d − %d = %d") % [
			int(line["incoming"]), int(line["blocked"]), dealt]
	else:
		math.text = "%d" % dealt
	math.custom_minimum_size = Vector2(Tokens.dp(MATH_WIDTH), 0.0)
	math.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(math)

	var target: Label = _label(Tokens.TYPE_CAPTION - 3, ink)
	target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target.text = _target_text(line, names, dimmed)
	if bool(line["killed"]):
		target.add_theme_color_override("font_color", Tokens.SEM_BLOOD)
	row.add_child(target)
	return row


## Statusens namn på spelarens språk, utan siffra. Nyckeln bär formatet
## "Burn %d", så vi plockar bort formatspecifikationen i stället för att införa
## en andra nyckel som kan glida isär från den första.
static func status_name(status: String) -> String:
	var text: String = Tokens.translate_or(
		"COMBAT_ENEMY_%s" % status, status.capitalize() + " %d")
	return text.replace("%d", "").strip_edges()


static func _target_text(line: Dictionary, names: PackedStringArray, dimmed: bool) -> String:
	var index: int = int(line["target"])
	var name: String = names[index] if index >= 0 and index < names.size() else String(line["target_id"])
	if dimmed:
		return Tokens.translate_or("COMBAT_RECEIPT_STOPPED", "stopped by the armor")
	var text: String = Tokens.translate_or("COMBAT_RECEIPT_TARGET", "→ %s   %d → %d") % [
		name, int(line["hp_before"]), int(line["hp_after"])]
	if bool(line["killed"]):
		text = "→ %s" % (Tokens.translate_or("COMBAT_RECEIPT_KILL", "%s dies") % name)
	for entry: Variant in line["statuses"] as Array:
		var status: Dictionary = entry as Dictionary
		# Statusens NAMN, inte dess mätarformat: COMBAT_ENEMY_BURN är "Burn %d"
		# och skulle annars skriva ut sitt eget %d rakt på skärmen.
		text += "  %s" % (Tokens.translate_or("COMBAT_RECEIPT_STATUS", "+ %s %d") % [
			status_name(String(status["status"])),
			int(status["stacks"]),
		])
	return text
