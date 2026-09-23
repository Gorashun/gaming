class_name SlotView
extends PanelContainer
## En av brädets slots. UI_GUIDE §2.4/§2.9 och [b]COMBAT_READABILITY §3[/b].
##
## [b]M2.5: sloten visar hela räknestycket, inte halva.[/b] Diagnosen i §1.4 var
## att [code]5 ×2[/code] saknar produkten och att [code]MIRROR[/code] är ett namn
## utan regel. Sloten har därför fem rader, uppifrån och ned:
## [codeblock]
## ② ❖ MIRROR        nummerbricka + ikon + namn   (12 dp, slotfärg)
## copies left       REGELN, får aldrig utelämnas (11 dp, chalk/500)
## [tärningen]       pixelkonst; 55 % opacitet i en spegel
## 5 ×2 = 10         räkningen: bas ×mult = resultat (14 dp)
## copy of 2         VARFÖR, ≤ 14 tecken           (8 dp)
## [/codeblock]
##
## Regelraden är normativ: "det är den som ersätter tutorialen" (§3). Den enda
## gången den döljs är innan [code]slot_types[/code] avslöjats, och då är hela
## brädet [code]PLAIN[/code] så raden vore ändå tom (Reveal.may_hide).
##
## Sloten innehåller ingen regel. Talen kommer ur [ChainReceipt], som i sin tur
## kommer ur [code]_preview.events[/code].

signal tapped(slot_index: int)
## Spelaren släppte en tärning här (drag-and-drop, UI_GUIDE §4.1).
signal die_dropped(slot_index: int, die_index: int)
## Långtryck: popover med slotens hela regel (§3).
signal held(slot_index: int)

## Slot-ikonens cellstorlek (assets/sprites/ui/slot_*.png).
const ICON_CELL: int = 16
## Heltalsskala för tärningen i sloten. 32 px × 3 = 96 px.
const DIE_SCALE_IN_SLOT: int = 3
## Långtryckets tröskel (§3: 400 ms).
const HOLD_MS: int = 400
## Spegelns tärning ritas nedtonad: den betyder ingenting och ska se ut så
## (§3, "MIRROR kräver en extra visuell signal").
const MIRROR_DIE_ALPHA: float = 0.55

## Mikrotexten per slot-typ, ≤ 14 tecken (§3). Engelska källsträngar; nyckeln
## får sin svenska rad i CSV:n och slås upp med [method Tokens.translate_or], så
## att en saknad rad visar engelska i stället för en rå nyckel.
const RULE_TEXT: Dictionary = {
	Rules.SlotType.PLAIN: ["COMBAT_SLOT_RULE_PLAIN", "no effect"],
	Rules.SlotType.FIRE: ["COMBAT_SLOT_RULE_FIRE", "burn 2 on hit"],
	Rules.SlotType.MIRROR: ["COMBAT_SLOT_RULE_MIRROR", "copies left"],
	Rules.SlotType.ANVIL: ["COMBAT_SLOT_RULE_ANVIL", "×2 if ≥5"],
	Rules.SlotType.CHARGE: ["COMBAT_SLOT_RULE_CHARGE", "charge, no dmg"],
	Rules.SlotType.VOID: ["COMBAT_SLOT_RULE_VOID", "ward, no dmg"],
}

## Långtryckets mening per slot-typ (§3 och TOWN_AND_ONBOARDING §B.4).
const HELP_TEXT: Dictionary = {
	Rules.SlotType.PLAIN: ["COMBAT_HELP_SLOT_PLAIN", "No effect. The value counts as it is. A 4 deals 4."],
	Rules.SlotType.FIRE: ["COMBAT_HELP_SLOT_FIRE", "Every hit from here adds Burn 2. Burn deals its number at the end of each round, then drops by 1."],
	Rules.SlotType.MIRROR: ["COMBAT_HELP_SLOT_MIRROR", "Copies the value on its left; its own pips are ignored. That is how you make a pair."],
	Rules.SlotType.ANVIL: ["COMBAT_HELP_SLOT_ANVIL", "Doubles a value of 5 or more. A 6 becomes 12 — which no longer pairs with a 6."],
	Rules.SlotType.CHARGE: ["COMBAT_HELP_SLOT_CHARGE", "Damage from here goes to the bank instead of the enemy."],
	Rules.SlotType.VOID: ["COMBAT_HELP_SLOT_VOID", "Damage from here becomes Ward. Ward soaks the enemy attack this round, then it's gone."],
}

var slot_index: int = -1

var _slot: Slot = null
var _die: Die = null
var _art: Control = null
var _icon: Sprite2D = null
var _die_art: DieArt = null
var _badge: Label = null
var _type_label: Label = null
var _rule_label: Label = null
var _die_label: Label = null
var _calc_label: Label = null
var _why_label: Label = null
var _mirror_arrow: Label = null
var _highlight: bool = false
var _pulsing: bool = false
var _pulse_tween: Tween = null
var _press_ms: int = 0
var _show_rules: bool = true


func _init() -> void:
	custom_minimum_size = Vector2(Tokens.dp(Tokens.TOUCH_MIN), Tokens.dp(Tokens.TOUCH_MIN))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	add_child(column)

	# Rad 1: nummerbricka + ikon + namn. Brickan är SAMMA bricka som kvittots
	# leveransrad använder (§2.1c) – den är kopplingen mellan sloten och raden.
	var header: HBoxContainer = HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", Tokens.dpi(2))
	column.add_child(header)

	_badge = _make_label(Tokens.TYPE_CAPTION - 2, Tokens.CHALK_500)
	_badge.custom_minimum_size = Vector2(Tokens.dp(9), 0.0)
	header.add_child(_badge)

	_art = Control.new()
	_art.name = "Art"
	_art.custom_minimum_size = Vector2(float(ICON_CELL), float(ICON_CELL * 2))
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_art)

	_icon = Art.pixel_sprite(null, 1)
	_icon.name = "SlotIcon"
	_art.add_child(_icon)
	_art.resized.connect(_layout_icon)

	_type_label = _make_label(Tokens.TYPE_CAPTION - 3, Tokens.CHALK_300)
	_type_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_type_label)

	# Rad 2: REGELN. §3: "normativ och får aldrig utelämnas".
	# EN rad, klippt. §3 anger ≤ 14 tecken just för att raden ska rymmas i en
	# slot utan att växa; låter vi den radbryta äter fem slots 40 px extra och
	# tumzonen får betala, vilket §8 uttryckligen förbjuder.
	_rule_label = _make_label(Tokens.TYPE_CAPTION - 3, Tokens.CHALK_500)
	column.add_child(_rule_label)

	var stack: Control = Control.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Två gånger cellen som MINSTA höjd, tre som önskad: DieArt räknar själv ut
	# största heltalsskala som ryms (Art.fit_scale), så sloten krymper snyggt
	# när kvittot tar plats i stället för att trycka ut tumzonen.
	stack.custom_minimum_size = Vector2(0.0, float(DieArt.CELL * 2))
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(stack)

	_die_art = DieArt.new()
	_die_art.name = "DieArt"
	_die_art.visible = false
	stack.add_child(_die_art)
	_die_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_die_label = _make_label(Tokens.TYPE_HEADING, Tokens.CHALK_100)
	_die_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stack.add_child(_die_label)
	_die_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Vänsterpilen som säger att spegeln tittar åt vänster. Utan den ser
	# "5 ×2 = 10" ut som ett fel när tärningen visar 1 (§3).
	_mirror_arrow = _make_label(Tokens.TYPE_LABEL, Tokens.SEM_FROST)
	_mirror_arrow.text = "←"
	_mirror_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_mirror_arrow.visible = false
	stack.add_child(_mirror_arrow)
	_mirror_arrow.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)

	# Rad 4: räkningen. bas ×mult = resultat, aldrig "= x" utan härkomst.
	_calc_label = _make_label(Tokens.TYPE_CAPTION, Tokens.SEM_DAMAGE)
	column.add_child(_calc_label)

	# Rad 5: varför.
	_why_label = _make_label(Tokens.TYPE_CAPTION - 3, Tokens.CHALK_500)
	column.add_child(_why_label)


static func _make_label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", Tokens.dpi(maxi(8, font_size)))
	label.add_theme_color_override("font_color", color)
	# clip_text: utan detta blir etikettens textbredd containerns minsta bredd,
	# och fem slots med texten "AMBOSS" tvingar raden bredare än skärmen.
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Noden som bär slot-ikonen (assets/sprites/ui/slot_<typ>.png).
func art_root() -> Control:
	return _art


func _layout_icon() -> void:
	if _icon == null or _art == null:
		return
	_icon.position = Art.snap(_art.size * 0.5, 1)


## Regelraden syns när slot-typerna är avslöjade. Är de inte det är brädet
## enligt Reveal.may_hide bara PLAIN, och raden hade ändå inte lärt ut något.
func set_show_rules(value: bool) -> void:
	_show_rules = value
	if _rule_label != null:
		_rule_label.visible = value


func bind(index: int, slot: Slot, die: Die) -> void:
	slot_index = index
	_slot = slot
	_die = die
	_badge.text = circled(index + 1)
	_type_label.text = Tokens.slot_label(slot.type)
	_icon.texture = Art.slot_icon(slot.type)
	_icon.modulate = Tokens.slot_color(slot.type)
	_icon.visible = _icon.texture != null
	if _icon.texture == null:
		# Saknas ikonen faller typraden tillbaka på reservglyphen ur §2.4, så
		# formkoden aldrig försvinner helt.
		_type_label.text = "%s %s" % [Tokens.slot_icon(slot.type), Tokens.slot_label(slot.type)]
	_layout_icon()
	_type_label.add_theme_color_override("font_color", Tokens.slot_color(slot.type))
	_rule_label.text = rule_text(slot.type)
	_rule_label.visible = _show_rules
	_mirror_arrow.visible = slot.type == Rules.SlotType.MIRROR and die != null

	_die_art.visible = false
	if slot.blocked:
		_die_label.visible = true
		_die_label.text = tr("SLOT_STATE_GRABBED")
		_die_label.add_theme_color_override("font_color", Tokens.SEM_BLOOD)
		_word_size()
	elif die != null:
		_die_art.show_die(die, hash(die.id))
		_die_art.visible = _die_art.is_drawing()
		var face: Face = die.showing_face()
		_die_label.visible = not _die_art.shows_value()
		_die_label.text = str(face.value) if face != null else "?"
		_die_label.add_theme_color_override("font_color", Tokens.BONE_DIE)
		_number_size()
		var alpha: float = MIRROR_DIE_ALPHA if slot.type == Rules.SlotType.MIRROR else 1.0
		_die_art.modulate.a = alpha
		_die_label.modulate.a = alpha
	else:
		_die_label.visible = true
		_die_label.text = tr("SLOT_STATE_EMPTY")
		_die_label.add_theme_color_override("font_color", Tokens.CHALK_500)
		_word_size()

	_apply_style()


## Siffran i sloten får vara stor; ett ORD i samma storlek är bredare än cellen
## och klipps mitt itu ("EMPTY" blev "MPTY" i fem slots bredvid varandra).
func _word_size() -> void:
	_die_label.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_CAPTION - 1))


func _number_size() -> void:
	_die_label.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_HEADING))


## Regeltexten för en slot-typ. Statisk så att hjälp-lagret kan använda den.
static func rule_text(slot_type: int) -> String:
	var spec: Array = RULE_TEXT.get(slot_type, RULE_TEXT[Rules.SlotType.PLAIN]) as Array
	return Tokens.translate_or(String(spec[0]), String(spec[1]))


## Långtryckets mening.
static func help_text(slot_type: int) -> String:
	var spec: Array = HELP_TEXT.get(slot_type, HELP_TEXT[Rules.SlotType.PLAIN]) as Array
	return Tokens.translate_or(String(spec[0]), String(spec[1]))


## Räkningen och orsaken, hämtade ur [ChainReceipt].
## [param calc] är redan formaterad ("5 ×2 = 10"), [param why] är redan
## översatt – båda byggs i [CombatScreen], som äger prosan.
func set_calculation(calc: String, why: String, multiplier: int, dimmed: bool) -> void:
	_calc_label.text = calc
	_calc_label.add_theme_color_override("font_color",
		Tokens.CHALK_500 if dimmed else (Tokens.multiplier_color(multiplier) if multiplier > 1 else Tokens.SEM_DAMAGE))
	_why_label.text = why
	_why_label.visible = why != ""


## Aktiveringspulsen i kedjan (UI_GUIDE §5.1).
func pulse_die(duration: float = Tokens.MOTION_BASE) -> void:
	if _die_art != null and _die_art.visible:
		_die_art.flash(0.8, duration)
	Juice.pulse(self, 1.18, duration)


## Tomma slots pulsar när en tärning är vald (§4): kontur i sem/charge, skala
## 1,00 → 1,04, 1 200 ms loop, fasförskjuten 80 ms per slot vänster→höger –
## vilket samtidigt lär ut kedjans riktning.
##
## Reducerad rörelse: ingen puls, i stället en statisk kontur på alla giltiga
## slots (UI_GUIDE §6.1, ingen rörelse alls).
func set_highlight(value: bool) -> void:
	if _highlight == value:
		return
	_highlight = value
	_apply_style()
	_update_pulse()


func _update_pulse() -> void:
	var should_pulse: bool = _highlight and not Settings.reduced_motion \
		and _slot != null and not _slot.blocked and _die == null
	if should_pulse == _pulsing:
		return
	_pulsing = should_pulse
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null
	pivot_offset = size * 0.5
	if not should_pulse:
		scale = Vector2.ONE
		return
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_interval(0.08 * float(maxi(0, slot_index)))
	_pulse_tween.tween_property(self, "scale", Vector2(1.04, 1.04), 0.6)
	_pulse_tween.tween_property(self, "scale", Vector2.ONE, 0.6)


## [b]M6 (ART_DIRECTION_V2 §4, "UI-brus ned ~60 %"):[/b] en slot är ikon +
## färgad underlinje, [b]ingen låda[/b]. Tärningarna är de enda objekten med
## egen upphöjd yta, så ögat alltid vet var handlingen är. Markeringen (vald
## tärning, tomma slots pulsar) är en tjockare linje i sem/charge och ett svagt
## sken – aldrig en ram. Hög kontrast behåller den hela ramen (UI_GUIDE §2.11).
func _apply_style() -> void:
	if _slot == null:
		return
	var color: Color = Tokens.slot_color(_slot.type)
	var width: float = Tokens.STROKE_BOLD
	var glow: Color = Color(0.0, 0.0, 0.0, 0.0)
	if _slot.blocked:
		color = Tokens.SURFACE_LINE
	elif _highlight:
		color = Tokens.SEM_CHARGE
		width = Tokens.STROKE_HEAVY
		glow = Color(Tokens.SEM_CHARGE, 0.08)
	add_theme_stylebox_override("panel", underline_style(color, width, glow, _slot.blocked))
	modulate.a = 0.45 if _slot.blocked else 1.0


## Stilen för en slot: en underlinje, eller hela ramen i hög kontrast. Statisk
## så att testerna kan läsa den utan en skärm.
static func underline_style(color: Color, width: float, glow: Color, blocked: bool) -> StyleBoxFlat:
	if Tokens.high_contrast:
		var framed: StyleBoxFlat = Tokens.box(color, true, width, Tokens.RADIUS_BUTTON)
		framed.bg_color = Tokens.SURFACE_SLATE if blocked else Tokens.SURFACE_RAISED
		return framed
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(Tokens.SURFACE_SLATE, 0.5) if blocked else glow
	style.border_color = color
	style.border_width_bottom = int(round(Tokens.dp(width)))
	# Samma innermarginal som ramen gav, så att höjdbudgeten i
	# tests/test_combat_layout.gd inte flyttar sig när ramen försvinner.
	var pad: float = Tokens.dp(Tokens.STROKE_REG)
	style.content_margin_left = pad
	style.content_margin_right = pad
	style.content_margin_top = pad
	style.corner_radius_top_left = Tokens.dpi(Tokens.RADIUS_CHIP)
	style.corner_radius_top_right = Tokens.dpi(Tokens.RADIUS_CHIP)
	return style


func accepts_dice() -> bool:
	return _slot != null and not _slot.blocked


func slot_type() -> int:
	return _slot.type if _slot != null else Rules.SlotType.PLAIN


## Slotens nummer – samma bricka i sloten och i kvittots leveransrad.
##
## [b]Ren siffra sedan 2026-09-22.[/b] Här stod ①②③④⑤ (U+2460…), som varken
## Familjen Grotesk eller Noto Sans Symbols 2 har. De kom ur systemfonten och
## blev tomma rutor i webbexporten (docs/BACKLOG.md). Ringen runt siffran är
## brickans StyleBox, inte tecknet – formkoden sitter alltså kvar.
static func circled(number: int) -> String:
	return str(number)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_press_ms = Time.get_ticks_msec()
		accept_event()
		return
	# Långtryck 400 ms → hjälp. Kortare → placera/plocka upp (§3).
	if Time.get_ticks_msec() - _press_ms >= HOLD_MS:
		held.emit(slot_index)
	else:
		tapped.emit(slot_index)
	accept_event()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return accepts_dice() and data is Dictionary and (data as Dictionary).has("die_index")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	die_dropped.emit(slot_index, int((data as Dictionary)["die_index"]))
