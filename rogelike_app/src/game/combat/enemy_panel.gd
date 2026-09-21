class_name EnemyPanel
extends VBoxContainer
## En fiende i fiendezonen. UI_GUIDE §2.9: zonen är [b]läs-endast[/b] – inget
## spelbeslut sitter där, allt interaktivt ligger under 58 % av skärmhöjden.
##
## Visar det GAME_DESIGN §6.5 och §6.7 kräver ska vara synligt före varje
## bekräftelse: HP, rustning, statusar och intent i klartext med siffra. Det
## finns ingen "?" i intent-panelen.
##
## Pixelgrafik: silhuetten ritas i World-lagret av [EnemyActor]; den här panelen
## är krit-UI och ska förbli vektor. [method anchor_point] ger World-lagret var
## sprajten ska stå.

## Höjden på det genomskinliga hålet där fiendens sprite står, i dp.
##
## [b]M2.5: 34 dp, inte 48.[/b] Kvittot, bågarna och leveransremsan tog plats i
## kolumnen, och COMBAT_READABILITY §8 är uttrycklig om vem som får betala:
## [i]"Räknestycket behåller full höjd – det prioriteras före arenan, eftersom
## det är det som lär ut spelet."[/i] Aldrig tumzonen, alltid arenan.
const ART_HOLE_HEIGHT: int = 30


## Prognosfältet i HP-stapeln (COMBAT_READABILITY §2.2 punkt 2). Diagonal
## skraffering ovanpå den röda delen: "det här kommer att försvinna". Är hela
## stapeln skrafferad dör fienden.
##
## Ritas som [Control._draw] och inte som en shader eller en sprite: mönstret
## måste följa stapelns bredd, och en rent geometrisk skraffering kan inte
## tappa kontrast när paletten byts i hög kontrast-läget (UI_GUIDE §2.11).
class ForecastOverlay:
	extends Control

	## Andel av stapeln som ska skrafferas, 0..1.
	var fraction: float = 0.0
	## Avståndet mellan skrafferingslinjerna i px.
	const STEP: float = 7.0

	func set_fraction(value: float) -> void:
		var clamped: float = clampf(value, 0.0, 1.0)
		if is_equal_approx(clamped, fraction):
			return
		fraction = clamped
		queue_redraw()

	func _draw() -> void:
		if fraction <= 0.0 or size.x <= 0.0:
			return
		var width: float = size.x * fraction
		# Fältet ligger vid stapelns HÖGRA kant: HP töms från höger.
		var left: float = size.x - width
		var band: Color = Color(Tokens.CHALK_100, 0.20)
		draw_rect(Rect2(left, 0.0, width, size.y), band, true)
		var line: Color = Color(Tokens.CHALK_100, 0.85)
		var x: float = left - size.y
		while x < size.x:
			var a: Vector2 = Vector2(maxf(x, left), size.y if x >= left else size.y - (left - x))
			var b: Vector2 = Vector2(minf(x + size.y, size.x), maxf(0.0, size.y - (minf(x + size.y, size.x) - x)))
			if b.x > a.x:
				draw_line(a, b, line, 1.5, false)
			x += STEP
		draw_line(Vector2(left, 0.0), Vector2(left, size.y), line, 1.5, false)


var enemy_id: String = ""
## Numret i ett rum med flera av samma sort ("Rostråtta 1 … 4"). 0 = ensam.
var ordinal: int = 0

var _flash: ColorRect = null
var _name_label: Label = null
var _hp_bar: ProgressBar = null
var _hp_label: Label = null
var _armor_label: Label = null
var _status_label: Label = null
var _intent_label: Label = null
var _forecast: ForecastOverlay = null
var _show_armor: bool = true
## Plats för fiendens sprite. Fylls av World-lagret, inte av panelen.
var _art_slot: Control = null


func _init() -> void:
	# VBox och inte en enda panel: [member _art_slot] måste vara ett GENOMSKINLIGT
	# hål så att fiendens silhuett i World-lagret syns. En opak panel ovanpå
	# skulle dölja exakt det pixelgrafiken ska visa.
	custom_minimum_size = Vector2(Tokens.dp(Tokens.TOUCH_MIN), 0.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 0)

	_art_slot = Control.new()
	_art_slot.name = "ArtSlot"
	_art_slot.custom_minimum_size = Vector2(0.0, Tokens.dp(ART_HOLE_HEIGHT))
	_art_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_art_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art_slot)

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Plate"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", Tokens.box(Tokens.SURFACE_LINE, true, Tokens.STROKE_HAIR))
	add_child(panel)

	_flash = ColorRect.new()
	_flash.name = "Flash"
	_flash.color = Color(Tokens.CHALK_100, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_flash)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# SPACE_1 och inte SPACE_2: med fem kolumner (Smeden + fyra Rostråttor) på
	# 360 dp är varje dp innermarginal en bokstav mindre av fiendenamnet.
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Tokens.dpi(Tokens.SPACE_1))
	panel.add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	margin.add_child(column)

	_name_label = _label(Tokens.TYPE_CAPTION - 1, Tokens.CHALK_100)
	column.add_child(_name_label)

	# HP-stapeln med PROGNOSFÄLT: den del som kommer att försvinna ritas som
	# diagonalskrafferad ljus yta ovanpå den röda (§2.2). Det är den enda
	# "vem dör"-signalen som fungerar utan färgseende.
	var bar_stack: Control = Control.new()
	bar_stack.custom_minimum_size = Vector2(0.0, Tokens.dp(10))
	bar_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(bar_stack)

	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_bg: StyleBoxFlat = StyleBoxFlat.new()
	bar_bg.bg_color = Tokens.SURFACE_PIT
	var bar_fill: StyleBoxFlat = StyleBoxFlat.new()
	bar_fill.bg_color = Tokens.SEM_BLOOD
	_hp_bar.add_theme_stylebox_override("background", bar_bg)
	_hp_bar.add_theme_stylebox_override("fill", bar_fill)
	bar_stack.add_child(_hp_bar)
	_hp_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_forecast = ForecastOverlay.new()
	_forecast.name = "Forecast"
	_forecast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_stack.add_child(_forecast)
	_forecast.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_hp_label = _label(Tokens.TYPE_CAPTION - 1, Tokens.CHALK_300)
	column.add_child(_hp_label)

	# Rustning ÖVER intent: rustning påverkar det spelaren gör härnäst, intent
	# det som händer sedan. Läsordningen följer tidsordningen (§5).
	_armor_label = _label(Tokens.TYPE_CAPTION - 2, Tokens.SEM_SHIELD)
	column.add_child(_armor_label)

	_status_label = _label(Tokens.TYPE_CAPTION, Tokens.SEM_POISON)
	column.add_child(_status_label)

	# En rad, klippt. "Attacks 3" är kort, och ett radbrytande intent äter två
	# rader i FYRA kolumner samtidigt – det är 24 dp av arenan för ingenting.
	_intent_label = _label(Tokens.TYPE_CAPTION - 2, Tokens.SEM_FIRE)
	column.add_child(_intent_label)


static func _label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", Tokens.dpi(font_size))
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Där fiendens sprite ska stå i World-lagret.
func anchor_point() -> Vector2:
	if not _art_slot.is_inside_tree():
		return Vector2.ZERO
	return _art_slot.get_global_rect().get_center()


## Konsthålets underkant: fiendens fotlinje. Alla paneler i raden är lika höga,
## så en enda panel räcker för att ge World-lagret hela radens golvlinje.
func art_bottom() -> float:
	if not _art_slot.is_inside_tree():
		return 0.0
	return _art_slot.get_global_rect().end.y


func bind(enemy: Enemy, p_ordinal: int = 0) -> void:
	enemy_id = enemy.id
	ordinal = p_ordinal
	_name_label.text = display_name_of(enemy, p_ordinal)
	_hp_bar.max_value = maxi(1, enemy.max_hp)
	_intent_label.text = _intent_text(enemy)
	_intent_label.add_theme_color_override("font_color", _intent_color(enemy))
	update_vitals(enemy.hp, enemy.armor, enemy.burn, enemy.poison)


## Namnet som visas. Flera fiender med samma namn numreras från fronten (§5),
## och samma nummer används i kvittots leveransrad.
static func display_name_of(enemy: Enemy, p_ordinal: int) -> String:
	var name: String = Tokens.translate_or(Content.enemy_key(enemy.id), enemy.display_name)
	if p_ordinal <= 0:
		return name
	return Tokens.translate_or("COMBAT_ENEMY_NUMBERED", "%s %d") % [name, p_ordinal]


## Döljer rustningsraden tills lektionen är given (Reveal). Panelen döljer den
## bara när rustningen är 0 – se [method Reveal.may_hide].
func set_show_armor(value: bool) -> void:
	_show_armor = value


## Uppdaterar bara siffrorna. Uppspelaren anropar den per event, så den får inte
## göra om layouten.
func update_vitals(hp: int, armor: int, burn: int, poison: int) -> void:
	_hp_bar.value = clampi(hp, 0, int(_hp_bar.max_value))
	_hp_label.text = "%d / %d" % [maxi(0, hp), int(_hp_bar.max_value)]
	# Ikon OCH ord, aldrig förkortat (§5): "⛊ Armor 2", inte "⬟ 2 arm".
	# Rustning OCH statusar på SAMMA rad. En tom etikett tar ändå en rad i en
	# VBoxContainer, och två tomma rader i fyra fiendekolumner kostade 90 px av
	# arenan varje runda – utrymme som §8 säger att kvittot ska ha.
	var parts: PackedStringArray = PackedStringArray()
	if armor > 0 and _show_armor:
		parts.append("%s %s" % [
			_icon_glyph(&"armor"),
			Tokens.translate_or("COMBAT_ENEMY_ARMOR", "Armor %d") % armor,
		])
	if burn > 0:
		parts.append(Tokens.translate_or("COMBAT_ENEMY_BURN", "Burn %d") % burn)
	if poison > 0:
		parts.append(Tokens.translate_or("COMBAT_ENEMY_POISON", "Poison %d") % poison)
	_armor_label.text = " · ".join(parts)
	_armor_label.visible = not parts.is_empty()
	_status_label.visible = false
	var dead: bool = hp <= 0
	modulate.a = 0.35 if dead else 1.0
	if dead:
		set_forecast(0)


## Hur mycket av stapeln som kommer att försvinna när spelaren bekräftar.
## Siffran kommer ur [ChainReceipt] och därmed ur [code]_preview.events[/code];
## panelen räknar ingenting själv.
func set_forecast(incoming: int) -> void:
	if _forecast == null:
		return
	var maximum: float = maxf(1.0, float(_hp_bar.max_value))
	_forecast.set_fraction(clampf(float(incoming) / maximum, 0.0, float(_hp_bar.value) / maximum))


## Ikonen som text. 16×16-sprajtarna ligger i UI-agentens katalog; saknas de
## ritas reservglyfen, aldrig ett hål (Art.ui_icon varnar en gång per ikon).
static func _icon_glyph(icon_name: StringName) -> String:
	return Art.ui_icon_glyph(icon_name)


## Vitblixt enligt UI_GUIDE §5.3. Ligger som ett eget lager i stället för på
## panelens modulate, eftersom modulate också skulle tona texten.
func flash_hit() -> void:
	_flash_with(Tokens.CHALK_100, 0.45, 0.14)
	Juice.shake_node(self, 6.0, 0.18)


func flash_death() -> void:
	_flash_with(Tokens.SEM_BLOOD, 0.6, 0.26)
	Juice.shake_node(self, 5.0, 0.2)


func _flash_with(color: Color, alpha: float, duration: float) -> void:
	if _flash == null or not _flash.is_inside_tree():
		return
	_flash.color = Color(color, alpha)
	var tween: Tween = _flash.create_tween()
	tween.tween_property(_flash, "color:a", 0.0, duration)


## Intent-texten. [member Intent.note] är en ÖVERSÄTTNINGSNYCKEL, inte prosa:
## core får aldrig innehålla spelartext (CLAUDE.md). Nyckeln formateras med
## [member Intent.note_args].
## [b]Ett verb, så att riktningen framgår[/b] (§5): "⚔ Attacks 3" och inte
## "▲ 3 dmg", som inte säger om skadan går mot spelaren eller mot fienden.
static func _intent_text(enemy: Enemy) -> String:
	if enemy.intent == null:
		return Tokens.translate("INTENT_NONE")
	match enemy.intent.kind:
		Rules.IntentKind.ATTACK:
			return "%s %s" % [
				Art.ui_icon_glyph(&"attack"),
				Tokens.translate_or("COMBAT_ENEMY_INTENT_ATTACK", "Attacks %d") % enemy.intent.value,
			]
		Rules.IntentKind.BLOCK:
			return Tokens.translate_or("COMBAT_ENEMY_INTENT_BLOCK", "Hardens +%d") % enemy.intent.value
		Rules.IntentKind.SPECIAL:
			return Tokens.translate("INTENT_SPECIAL") % _note_text(enemy.intent)
	return _note_text(enemy.intent)


static func _note_text(intent: Intent) -> String:
	if intent == null or intent.note == "":
		return ""
	var text: String = Tokens.translate(intent.note)
	if intent.note_args.is_empty():
		return text
	return text % intent.note_args


static func _intent_color(enemy: Enemy) -> Color:
	if enemy.intent == null:
		return Tokens.CHALK_500
	match enemy.intent.kind:
		Rules.IntentKind.ATTACK:
			return Tokens.SEM_FIRE
		Rules.IntentKind.BLOCK:
			return Tokens.SEM_SHIELD
	return Tokens.SEM_POISON
