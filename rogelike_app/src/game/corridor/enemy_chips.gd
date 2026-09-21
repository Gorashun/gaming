class_name EnemyChips
extends Control
## Krit-lagret med fiendernas HP-chip, ankrade ovanför varsin billboard.
##
## [b]Ankringen är ren matematik på kameratransformen[/b] (research 05 §3):
## [codeblock]
## chip = box.position + cam.unproject_position(sprite + UP*1.2) * upscale
## [/codeblock]
## [CorridorView.enemy_anchor] äger formeln; det här lagret flyttar bara noder
## dit och drar ett kritstreck ner till varelsens hjässa.
##
## [b]Inga allokeringar i loopen.[/b] Chipen skapas en gång per rum och flyttas
## sedan med rena [code]Vector2[/code]-tilldelningar. Omritningen av strecken
## begärs bara när ett ankare faktiskt rört sig mer än en halv pixel – annars
## skulle en stillastående strid rita om sex linjer per bildruta i onödan.

## Hur långt ovanför ankarpunkten chipets underkant ligger, i dp.
const LIFT_DP: int = 10
## Hur nära varandra två ankare får hamna innan omritning begärs, i px.
const REDRAW_EPSILON: float = 0.5

var view: CorridorView = null
## Överkanten chipen inte får krypa ovanför: korridorens HUD äger de raderna.
var top_margin: float = 0.0

var _chips: Array[EnemyChip] = []
var _anchors: PackedVector2Array = PackedVector2Array()
## Arbetsytor. Förallokerade: loopen körs varje bildruta och får inte allokera
## (ARCHITECTURE: "inga allokeringar i uppspelningsloopen").
var _order: Array[int] = []
var _targets: PackedVector2Array = PackedVector2Array()


func _init() -> void:
	# PASS och inte IGNORE: chipen ska gå att trycka på, men ytan mellan dem hör
	# till korridoren under.
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_process(false)


## Rensar rummets chip. Anropas av [CombatScreen] innan ett nytt rum byggs.
func reset_readouts() -> void:
	for chip: EnemyChip in _chips:
		chip.queue_free()
	_chips.clear()
	_anchors.clear()
	_targets.clear()
	_order.clear()
	set_process(false)
	queue_redraw()


## Bygger avläsningen för fiende nummer [param index].
func make_readout(index: int) -> EnemyReadout:
	var chip: EnemyChip = EnemyChip.new()
	chip.name = "Chip%d" % index
	chip.index = index
	add_child(chip)
	_chips.append(chip)
	_anchors.append(Vector2(-1.0, -1.0))
	_targets.append(Vector2.ZERO)
	set_process(true)
	return chip


func chips() -> Array[EnemyChip]:
	return _chips.duplicate()


func _process(_delta: float) -> void:
	if view == null or not is_instance_valid(view):
		return
	var moved: bool = false
	_order.clear()
	var row_top: float = 0.0
	var tallest: float = 0.0

	# 1. Vilka chip har en billboard i bild, och var hänger de?
	for i: int in range(_chips.size()):
		var chip: EnemyChip = _chips[i]
		var anchor: Vector2 = view.enemy_anchor(i) - global_position
		if _anchors[i].distance_to(anchor) > REDRAW_EPSILON:
			_anchors[i] = anchor
			moved = true
		if anchor.x < 0.0:
			# Bakom kameran eller utan billboard. Ett chip som ligger kvar i
			# kanten pekar på ingenting.
			if chip.visible:
				chip.visible = false
				moved = true
			continue
		if not chip.visible:
			chip.visible = true
			moved = true
		_order.append(i)
		tallest = maxf(tallest, chip.size.y)


	if _order.is_empty():
		if moved:
			queue_redraw()
		return

	# 2. EN rad, ovanför den högsta billboarden. Fyra chip staplade i höjdled
	#    ryms inte mellan HUD:en och varelserna (det är 684 px och fyra chip är
	#    568 px plus mellanrum), och ett chip som klipps av säger ingenting.
	#    Kritstrecket bär kopplingen i stället – det är exakt vad research 05 §3
	#    ger det för uppgift.
	row_top = INF
	for i: int in _order:
		row_top = minf(row_top, _anchors[i].y - _chips[i].size.y - Tokens.dp(LIFT_DP))
	row_top = maxf(row_top, top_margin)

	# 3. Vänster till höger i samma ordning som varelserna står. Ett chip får
	#    knuffas i sidled men aldrig byta plats med sin granne: då skulle
	#    strecken korsa varandra och peka fel.
	_order.sort_custom(func(a: int, b: int) -> bool: return _anchors[a].x < _anchors[b].x)
	var gap: float = Tokens.dp(Tokens.SPACE_1)
	var cursor: float = 0.0
	for i: int in _order:
		var chip: EnemyChip = _chips[i]
		var x: float = maxf(_anchors[i].x - chip.size.x * 0.5, cursor)
		cursor = x + chip.size.x + gap
		_targets[i] = Vector2(x, row_top)
	# Rättar till åt andra hållet när raden trycktes ut över högerkanten.
	var overflow: float = maxf(cursor - gap - size.x, 0.0)
	if overflow > 0.0:
		var limit: float = size.x
		for j: int in range(_order.size() - 1, -1, -1):
			var index: int = _order[j]
			var chip_width: float = _chips[index].size.x
			var x: float = minf(_targets[index].x, limit - chip_width)
			_targets[index] = Vector2(maxf(x, 0.0), row_top)
			limit = _targets[index].x - gap

	for i: int in _order:
		var chip: EnemyChip = _chips[i]
		if chip.position.distance_to(_targets[i]) > REDRAW_EPSILON:
			chip.position = _targets[i]
			moved = true
	if moved:
		queue_redraw()


## Kritstrecket från chipets underkant ner till varelsens hjässa. 2 px, samma
## krita som allt annat i lagret (research 05 §3).
func _draw() -> void:
	for i: int in range(_chips.size()):
		var chip: EnemyChip = _chips[i]
		if not chip.visible or i >= _anchors.size():
			continue
		var anchor: Vector2 = _anchors[i]
		if anchor.x < 0.0:
			continue
		var from: Vector2 = chip.position + Vector2(chip.size.x * 0.5, chip.size.y)
		if from.distance_to(anchor) < 2.0:
			continue
		draw_line(from, anchor, Color(Tokens.CHALK_300, 0.7), 2.0, false)
