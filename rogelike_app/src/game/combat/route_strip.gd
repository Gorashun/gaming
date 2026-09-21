class_name RouteStrip
extends HBoxContainer
## Leveransremsan direkt under arenan. COMBAT_READABILITY §2.2 punkt 1.
##
## [b]En kolumn per fiende, exakt lika bred och i exakt samma ordning som
## fiendekorten.[/b] Träffad fiende får stor pil + stor siffra + KILLS;
## överflödsmål får liten pil + liten siffra + SPILL. Kolumner utan inkommande
## skada är tomma men håller sin plats – annars glider remsan ur fas med korten
## och hela poängen med kolumnjusteringen faller.
##
## §2.2 motiverar valet: frisvävande kurvade pilar från slot upp till fiende
## korsar räknestycket, går inte att layouta robust på fem slots × fyra fiender
## och blir oläsliga i reducerat rörelse-läge. Kolumnjustering plus delad
## nummerbricka bär samma information utan att korsa något.

## Remsans höjd i dp.
const HEIGHT: int = 32

var _columns: Array[VBoxContainer] = []
var _amounts: Array[Label] = []
var _tags: Array[Label] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0.0, Tokens.dp(HEIGHT))
	alignment = BoxContainer.ALIGNMENT_BEGIN


## Egen botten, ritad och inte en nod: en [ColorRect] i en [HBoxContainer] blir
## en KOLUMN och skjuter fiendekolumnerna ur fas med korten ovanför. Plattan
## behövs för att fiendesprajterna ritas i World-lagret och sticker ned under
## sina kritkort – utan den hamnar "↑ 28 DIES" ovanpå en råtta.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(Tokens.SURFACE_PIT, 0.82), true)


## Bygger om remsan för ett rum. [param lead_width] är bredden på Smedens
## tomma kolumn i fiendezonen, så att kolumn 0 hamnar över första fienden.
func build(count: int, lead_width: float) -> void:
	for child: Node in get_children():
		child.queue_free()
	_columns.clear()
	_amounts.clear()
	_tags.clear()

	var lead: Control = Control.new()
	lead.custom_minimum_size = Vector2(lead_width, 0.0)
	lead.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lead)

	for i: int in range(count):
		var column: VBoxContainer = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation", 0)
		add_child(column)

		# Pilen ligger i SAMMA etikett som beloppet: en egen rad för en glyf
		# kostade 45 px av arenan i fyra kolumner samtidigt.
		var amount: Label = _label(Tokens.TYPE_BODY, Tokens.CHALK_100)
		column.add_child(amount)
		var tag: Label = _label(Tokens.TYPE_CAPTION - 3, Tokens.CHALK_500)
		column.add_child(tag)

		_columns.append(column)
		_amounts.append(amount)
		_tags.append(tag)
	clear()


static func _label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", Tokens.dpi(maxi(8, font_size)))
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func clear() -> void:
	for i: int in range(_columns.size()):
		_amounts[i].text = ""
		_tags[i].text = ""


## [param routes] är [code]receipt["routes"][/code] – en post per fiende, i
## samma ordning som panelerna.
func show_routes(routes: Array) -> void:
	clear()
	for i: int in range(mini(_columns.size(), routes.size())):
		var route: Dictionary = routes[i] as Dictionary
		var damage: int = int(route["damage"])
		if damage <= 0:
			continue
		var spill_only: bool = int(route["overflow"]) >= damage
		var killed: bool = bool(route["killed"])
		_amounts[i].text = "↑ %d" % damage
		if killed:
			_tags[i].text = Tokens.translate_or("COMBAT_ENEMY_DIES", "DIES")
			_color_column(i, Tokens.SEM_BLOOD, Tokens.TYPE_BODY_L)
		elif spill_only:
			_tags[i].text = Tokens.translate_or("COMBAT_ENEMY_SPILL", "SPILL")
			_color_column(i, Tokens.SEM_OVERFLOW, Tokens.TYPE_BODY)
		else:
			_tags[i].text = ""
			_color_column(i, Tokens.SEM_DAMAGE, Tokens.TYPE_BODY)


func _color_column(index: int, color: Color, font_size: int) -> void:
	_amounts[index].add_theme_color_override("font_color", color)
	_amounts[index].add_theme_font_size_override("font_size", Tokens.dpi(font_size))
	_tags[index].add_theme_color_override("font_color", color)
