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
## 32 px-konst × 4 = 128 px = 42,7 dp; 48 dp ger boss och statusglow marginal.
const ART_HOLE_HEIGHT: int = 48

var enemy_id: String = ""

var _flash: ColorRect = null
var _name_label: Label = null
var _hp_bar: ProgressBar = null
var _hp_label: Label = null
var _armor_label: Label = null
var _status_label: Label = null
var _intent_label: Label = null
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
	add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_1))

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
	column.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_1))
	margin.add_child(column)

	_name_label = _label(Tokens.TYPE_CAPTION, Tokens.CHALK_100)
	column.add_child(_name_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(0.0, Tokens.dp(8))
	_hp_bar.show_percentage = false
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_bg: StyleBoxFlat = StyleBoxFlat.new()
	bar_bg.bg_color = Tokens.SURFACE_PIT
	var bar_fill: StyleBoxFlat = StyleBoxFlat.new()
	bar_fill.bg_color = Tokens.SEM_BLOOD
	_hp_bar.add_theme_stylebox_override("background", bar_bg)
	_hp_bar.add_theme_stylebox_override("fill", bar_fill)
	column.add_child(_hp_bar)

	_hp_label = _label(Tokens.TYPE_CAPTION, Tokens.CHALK_300)
	column.add_child(_hp_label)

	_armor_label = _label(Tokens.TYPE_CAPTION, Tokens.SEM_SHIELD)
	column.add_child(_armor_label)

	_status_label = _label(Tokens.TYPE_CAPTION, Tokens.SEM_POISON)
	column.add_child(_status_label)

	_intent_label = _label(Tokens.TYPE_CAPTION, Tokens.SEM_FIRE)
	_intent_label.clip_text = false
	_intent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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


func bind(enemy: Enemy) -> void:
	enemy_id = enemy.id
	_name_label.text = Tokens.translate_or(Content.enemy_key(enemy.id), enemy.display_name)
	_hp_bar.max_value = maxi(1, enemy.max_hp)
	_intent_label.text = _intent_text(enemy)
	_intent_label.add_theme_color_override("font_color", _intent_color(enemy))
	update_vitals(enemy.hp, enemy.armor, enemy.burn, enemy.poison)


## Uppdaterar bara siffrorna. Uppspelaren anropar den per event, så den får inte
## göra om layouten.
func update_vitals(hp: int, armor: int, burn: int, poison: int) -> void:
	_hp_bar.value = clampi(hp, 0, int(_hp_bar.max_value))
	_hp_label.text = "%d / %d" % [maxi(0, hp), int(_hp_bar.max_value)]
	_armor_label.text = (tr("ENEMY_ARMOR") % armor) if armor > 0 else ""
	var statuses: PackedStringArray = PackedStringArray()
	if burn > 0:
		statuses.append(tr("STATUS_BURN") % burn)
	if poison > 0:
		statuses.append(tr("STATUS_POISON") % poison)
	_status_label.text = " · ".join(statuses)
	var dead: bool = hp <= 0
	modulate.a = 0.35 if dead else 1.0


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
static func _intent_text(enemy: Enemy) -> String:
	if enemy.intent == null:
		return Tokens.translate("INTENT_NONE")
	match enemy.intent.kind:
		Rules.IntentKind.ATTACK:
			return Tokens.translate("INTENT_ATTACK") % enemy.intent.value
		Rules.IntentKind.BLOCK:
			return Tokens.translate("INTENT_BLOCK") % enemy.intent.value
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
