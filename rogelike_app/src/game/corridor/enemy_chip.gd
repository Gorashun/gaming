class_name EnemyChip
extends EnemyReadout
## En fiendes avläsning i korridoren: ett kritchip ankrat ovanför billboarden.
##
## [b]Varför chip och inte kort[/b] (COMBAT_READABILITY §8, research 05 §3):
## varelsen ÄR bilden i 3D. Ett kort bredvid skulle bli en andra representation
## av samma fiende, och problem #8 i COMBAT_READABILITY är just att spelaren inte
## vet vilket kort som är vilken varelse. Chipet hänger i stället fast i sin
## varelse med ett kritstreck och kan aldrig förväxlas.
##
## Innehållet är detsamma som i [EnemyPanel] och i samma ord: namn, HP-stapel med
## prognosfält, rustning och attack med ikon och siffra. Layouten är hopdragen
## till två rader eftersom chipet ligger ovanpå bilden och inte får skymma den.
##
## [b]Tapp på chipet är ett tapp på fienden[/b] (§5): samma detaljtext som
## långtrycket på en slot ger, ordagrant.

## Chipets minsta bredd i dp. Innehållet kan göra det bredare; fyra chip à 70 dp
## får plats bredvid varandra på 360 dp, vilket är hela skälet till den staplade
## layouten (se kommentaren i [method _init]).
const WIDTH_DP: int = 70
const BAR_HEIGHT_DP: int = 8

var _name_label: Label = null
var _hp_bar: ProgressBar = null
var _hp_label: Label = null
var _stats_label: Label = null
var _route_label: Label = null
var _forecast: ForecastOverlay = null
var _plate: PanelContainer = null
var _flash: ColorRect = null
var _enemy: Enemy = null


func _init() -> void:
	custom_minimum_size = Vector2(Tokens.dp(WIDTH_DP), 0.0)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Chipet ÄR fiendens tryckyta. Utan STOP går tappet igenom till korridoren.
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_constant_override("separation", 0)

	_name_label = make_label(Tokens.TYPE_CAPTION - 1, Tokens.CHALK_100)
	_name_label.add_theme_color_override("font_outline_color", Tokens.SURFACE_PIT)
	_name_label.add_theme_constant_override("outline_size", Tokens.dpi(3))
	add_child(_name_label)

	_plate = PanelContainer.new()
	_plate.name = "Plate"
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: StyleBoxFlat = Tokens.box(Tokens.SURFACE_LINE, true, Tokens.STROKE_HAIR, Tokens.RADIUS_CHIP)
	# Halvgenomskinlig botten: chipet ligger ovanpå korridorbilden och ska gå att
	# läsa utan att sudda ut varelsen bakom sig (UI_GUIDE §17.2).
	box.bg_color = Color(Tokens.SURFACE_PIT, 0.82)
	_plate.add_theme_stylebox_override("panel", box)
	add_child(_plate)

	_flash = ColorRect.new()
	_flash.name = "Flash"
	_flash.color = Color(Tokens.CHALK_100, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(_flash)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, Tokens.dpi(Tokens.SPACE_1))
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Tokens.dpi(2))
	_plate.add_child(margin)

	# [b]Två rader och inte en.[/b] En rad (stapel + HP + rustning + attack)
	# blev 112 dp bred, och fyra chip i en 360 dp-skärm skrev då ovanpå
	# varandra. Staplad är chipet 70 dp och fyra får plats bredvid varandra.
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", Tokens.dpi(1))
	margin.add_child(column)

	var bar_stack: Control = Control.new()
	bar_stack.name = "BarStack"
	bar_stack.custom_minimum_size = Vector2(Tokens.dp(40), Tokens.dp(BAR_HEIGHT_DP))
	bar_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(bar_stack)

	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = Tokens.SURFACE_PIT
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = Tokens.SEM_BLOOD
	_hp_bar.add_theme_stylebox_override("background", track)
	_hp_bar.add_theme_stylebox_override("fill", fill)
	bar_stack.add_child(_hp_bar)
	_hp_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_forecast = ForecastOverlay.new()
	_forecast.name = "Forecast"
	_forecast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_stack.add_child(_forecast)
	_forecast.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Stats"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_1))
	column.add_child(row)

	# INTE clip_text: i en HBoxContainer nollar det etikettens minsta bredd och
	# siffran försvinner helt (samma fälla som stadens Pips-etikett, M2.5).
	_hp_label = make_label(Tokens.TYPE_CAPTION - 2, Tokens.CHALK_100)
	_hp_label.clip_text = false
	row.add_child(_hp_label)

	_stats_label = make_label(Tokens.TYPE_CAPTION - 2, Tokens.SEM_SHIELD)
	_stats_label.clip_text = false
	row.add_child(_stats_label)

	# Leveransraden, på fienden själv. I den platta skärmen står den i
	# [RouteStrip]; här finns ingen sådan rad, och siffran hör ändå hemma där
	# varelsen är (COMBAT_READABILITY §2.2).
	_route_label = make_label(Tokens.TYPE_CAPTION - 1, Tokens.SEM_DAMAGE)
	_route_label.add_theme_color_override("font_outline_color", Tokens.SURFACE_PIT)
	_route_label.add_theme_constant_override("outline_size", Tokens.dpi(3))
	_route_label.visible = false
	add_child(_route_label)

	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed:
		Juice.ui_tap(1.0)
		tapped.emit(index)


func bind(enemy: Enemy, p_ordinal: int = 0) -> void:
	_enemy = enemy
	enemy_id = enemy.id
	ordinal = p_ordinal
	_name_label.text = display_name_of(enemy, p_ordinal)
	_hp_bar.max_value = maxi(1, enemy.max_hp)
	update_vitals(enemy.hp, enemy.armor, enemy.burn, enemy.poison)


func update_vitals(hp: int, armor: int, burn: int, poison: int) -> void:
	_hp_bar.value = clampi(hp, 0, int(_hp_bar.max_value))
	_hp_label.text = "%d/%d" % [maxi(0, hp), int(_hp_bar.max_value)]
	# Rustning och attack med ikon OCH siffra på samma rad. Intent står som en
	# siffra bakom svärdet: i korridoren finns ingen plats för verbet, men
	# ikonen bär riktningen (§5) och långtrycket ger hela meningen.
	var parts: PackedStringArray = PackedStringArray()
	if armor > 0 and _show_armor:
		parts.append("%s%d" % [icon_glyph(&"armor"), armor])
	if burn > 0:
		parts.append(Tokens.translate_or("COMBAT_ENEMY_BURN_SHORT", "b%d") % burn)
	if poison > 0:
		parts.append(Tokens.translate_or("COMBAT_ENEMY_POISON_SHORT", "p%d") % poison)
	if _enemy != null and _enemy.intent != null and _enemy.intent.kind == Rules.IntentKind.ATTACK:
		parts.append("%s%d" % [icon_glyph(&"attack"), _enemy.intent.value])
	_stats_label.text = " ".join(parts)
	_stats_label.visible = not parts.is_empty()
	var dead: bool = hp <= 0
	modulate.a = 0.3 if dead else 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE if dead else Control.MOUSE_FILTER_STOP
	if dead:
		set_forecast(0)
		if _route_label != null:
			_route_label.visible = false


func set_forecast(incoming: int) -> void:
	if _forecast == null:
		return
	var maximum: float = maxf(1.0, float(_hp_bar.max_value))
	_forecast.set_fraction(clampf(float(incoming) / maximum, 0.0, float(_hp_bar.value) / maximum))


## [b]Samma ord som [RouteStrip][/b]: "↑ 28" och DIES / SPILL. Två formuleringar
## för samma händelse vore §B.1-problemet om igen.
func show_route(route: Dictionary) -> void:
	var damage: int = int(route.get("damage", 0))
	if damage <= 0 or _hp_bar.value <= 0.0:
		_route_label.visible = false
		return
	var text: String = "↑ %d" % damage
	var color: Color = Tokens.SEM_DAMAGE
	if bool(route.get("killed", false)):
		text = "%s %s" % [text, Tokens.translate_or("COMBAT_ENEMY_DIES", "DIES")]
		color = Tokens.SEM_BLOOD
	elif int(route.get("overflow", 0)) >= damage:
		text = "%s %s" % [text, Tokens.translate_or("COMBAT_ENEMY_SPILL", "SPILL")]
		color = Tokens.SEM_OVERFLOW
	_route_label.text = text
	_route_label.add_theme_color_override("font_color", color)
	_route_label.visible = true


func flash_hit() -> void:
	_flash_with(Tokens.CHALK_100, 0.5, 0.14)


func flash_death() -> void:
	_flash_with(Tokens.SEM_BLOOD, 0.65, 0.26)


func _flash_with(color: Color, alpha: float, duration: float) -> void:
	if _flash == null or not _flash.is_inside_tree():
		return
	_flash.color = Color(color, alpha)
	var tween: Tween = _flash.create_tween()
	tween.tween_property(_flash, "color:a", 0.0, duration)


## Hela avläsningen som en mening. Chipets tapp visar exakt den här texten.
func detail() -> String:
	if _enemy == null:
		return ""
	return detail_text(_enemy, ordinal)
