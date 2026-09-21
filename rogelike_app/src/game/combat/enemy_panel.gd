class_name EnemyPanel
extends EnemyReadout
## En fiende i fiendezonen, i den [b]platta[/b] stridsskärmen (tutorialens
## källare). UI_GUIDE §2.9: zonen är [b]läs-endast[/b] – inget spelbeslut sitter
## där, allt interaktivt ligger under 58 % av skärmhöjden.
##
## Visar det GAME_DESIGN §6.5 och §6.7 kräver ska vara synligt före varje
## bekräftelse: HP, rustning, statusar och intent i klartext med siffra. Det
## finns ingen "?" i intent-panelen.
##
## Pixelgrafik: silhuetten ritas i World-lagret av [EnemyActor]; den här panelen
## är krit-UI och ska förbli vektor. [method anchor_point] ger World-lagret var
## sprajten ska stå.
##
## I korridoren används [EnemyChip] i stället – samma kontrakt, annan layout.

## Höjden på det genomskinliga hålet där fiendens sprite står, i dp.
##
## [b]M2.5: 34 dp, inte 48.[/b] Kvittot, bågarna och leveransremsan tog plats i
## kolumnen, och COMBAT_READABILITY §8 är uttrycklig om vem som får betala:
## [i]"Räknestycket behåller full höjd – det prioriteras före arenan, eftersom
## det är det som lär ut spelet."[/i] Aldrig tumzonen, alltid arenan.
const ART_HOLE_HEIGHT: int = 30

var _flash: ColorRect = null
var _name_label: Label = null
var _hp_bar: ProgressBar = null
var _hp_label: Label = null
var _armor_label: Label = null
var _status_label: Label = null
var _intent_label: Label = null
var _forecast: ForecastOverlay = null
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

	_name_label = make_label(Tokens.TYPE_CAPTION - 1, Tokens.CHALK_100)
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

	_hp_label = make_label(Tokens.TYPE_CAPTION - 1, Tokens.CHALK_300)
	column.add_child(_hp_label)

	# Rustning ÖVER intent: rustning påverkar det spelaren gör härnäst, intent
	# det som händer sedan. Läsordningen följer tidsordningen (§5).
	_armor_label = make_label(Tokens.TYPE_CAPTION - 2, Tokens.SEM_SHIELD)
	column.add_child(_armor_label)

	_status_label = make_label(Tokens.TYPE_CAPTION, Tokens.SEM_POISON)
	column.add_child(_status_label)

	# En rad, klippt. "Attacks 3" är kort, och ett radbrytande intent äter två
	# rader i FYRA kolumner samtidigt – det är 24 dp av arenan för ingenting.
	_intent_label = make_label(Tokens.TYPE_CAPTION - 2, Tokens.SEM_FIRE)
	column.add_child(_intent_label)


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
	_intent_label.text = intent_text(enemy)
	_intent_label.add_theme_color_override("font_color", intent_color(enemy))
	update_vitals(enemy.hp, enemy.armor, enemy.burn, enemy.poison)


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
			icon_glyph(&"armor"),
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


func set_forecast(incoming: int) -> void:
	if _forecast == null:
		return
	var maximum: float = maxf(1.0, float(_hp_bar.max_value))
	_forecast.set_fraction(clampf(float(incoming) / maximum, 0.0, float(_hp_bar.value) / maximum))


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
