class_name EnemyReadout
extends VBoxContainer
## Gemensam bas för avläsningen av en fiende.
##
## [b]Varför en bas och en implementation:[/b] [CombatScreen] binder, uppdaterar
## och blixtrar fienderna på exakt ett ställe och ska inte veta var avläsningen
## hänger. [EnemyChip] (korridoren, ovanför varsin billboard,
## COMBAT_READABILITY §5/§8) är enda implementationen sedan M5.5, men basen står
## kvar: den är kontraktet [CombatScreen] talar med.
##
## Det som ligger här är dessutom det som [b]aldrig[/b] får formuleras två
## gånger: fiendens visningsnamn, intent-texten och prognosfältet. Två olika
## formuleringar för samma regel är `TOWN_AND_ONBOARDING §B.1`-problemet om igen.

## Spelaren tryckte på avläsningen. I korridoren är ett tapp på chipet samma sak
## som ett tapp på fienden (COMBAT_READABILITY §5).
signal tapped(index: int)

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
## Fiendens plats i [member CombatState.enemies]. Bärs med så att ett tapp på
## avläsningen kan pekas tillbaka på rätt varelse.
var index: int = -1
var _show_armor: bool = true


# --- Kontraktet mot [CombatScreen] -----------------------------------------
# Underklasserna överskuggar det de behöver; ingen av dem är abstrakt, så en
# avläsning som saknar en del (t.ex. rustningsraden) tiger i stället för att
# krascha.

func bind(_enemy: Enemy, _p_ordinal: int = 0) -> void:
	pass


func update_vitals(_hp: int, _armor: int, _burn: int, _poison: int) -> void:
	pass


## Hur mycket av stapeln som kommer att försvinna när spelaren bekräftar.
## Siffran kommer ur [ChainReceipt] och därmed ur [code]_preview.events[/code];
## avläsningen räknar ingenting själv.
func set_forecast(_incoming: int) -> void:
	pass


## Vart skadan tar vägen, för [b]den här[/b] fienden. [param route] är en post ur
## [code]ChainReceipt.routes[/code]. Chipet ritar den på varelsen själv.
func show_route(_route: Dictionary) -> void:
	pass


func flash_hit() -> void:
	pass


func flash_death() -> void:
	pass


## Döljer rustningsraden tills lektionen är given ([Reveal]). Avläsningen döljer
## den bara när rustningen är 0 – se [method Reveal.may_hide].
func set_show_armor(value: bool) -> void:
	_show_armor = value


## Där fiendens sprite ska stå i World-lagret. Korridorens chip har ingen egen
## konstruta – billboarden lever i 3D – och svarar därför med sin egen mitt.
func anchor_point() -> Vector2:
	if not is_inside_tree():
		return Vector2.ZERO
	return get_global_rect().get_center()


func art_bottom() -> float:
	if not is_inside_tree():
		return 0.0
	return get_global_rect().end.y


# --- Text som bara får formuleras en gång ----------------------------------

## Namnet som visas. Flera fiender med samma namn numreras från fronten (§5),
## och samma nummer används i kvittots leveransrad.
static func display_name_of(enemy: Enemy, p_ordinal: int) -> String:
	var name: String = Tokens.translate_or(Content.enemy_key(enemy.id), enemy.display_name)
	if p_ordinal <= 0:
		return name
	return Tokens.translate_or("COMBAT_ENEMY_NUMBERED", "%s %d") % [name, p_ordinal]


## Intent-texten. [member Intent.note] är en ÖVERSÄTTNINGSNYCKEL, inte prosa:
## core får aldrig innehålla spelartext (CLAUDE.md). Nyckeln formateras med
## [member Intent.note_args].
## [b]Ett verb, så att riktningen framgår[/b] (§5): "⚔ Attacks 3" och inte
## "▲ 3 dmg", som inte säger om skadan går mot spelaren eller mot fienden.
static func intent_text(enemy: Enemy) -> String:
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
			return Tokens.translate("INTENT_SPECIAL") % note_text(enemy.intent)
	return note_text(enemy.intent)


static func note_text(intent: Intent) -> String:
	if intent == null or intent.note == "":
		return ""
	var text: String = Tokens.translate(intent.note)
	if intent.note_args.is_empty():
		return text
	return text % intent.note_args


static func intent_color(enemy: Enemy) -> Color:
	if enemy.intent == null:
		return Tokens.CHALK_500
	match enemy.intent.kind:
		Rules.IntentKind.ATTACK:
			return Tokens.SEM_FIRE
		Rules.IntentKind.BLOCK:
			return Tokens.SEM_SHIELD
	return Tokens.SEM_POISON


## Hela avläsningen som en mening, för långtrycket och för chipets popover.
## Samma siffror som står i avläsningen, i samma ord (§B.1).
static func detail_text(enemy: Enemy, p_ordinal: int) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append(display_name_of(enemy, p_ordinal))
	parts.append(Tokens.translate_or("COMBAT_ENEMY_HP", "HP %d / %d") % [maxi(0, enemy.hp), enemy.max_hp])
	if enemy.armor > 0:
		parts.append(Tokens.translate_or("COMBAT_ENEMY_ARMOR", "Armor %d") % enemy.armor)
	if enemy.burn > 0:
		parts.append(Tokens.translate_or("COMBAT_ENEMY_BURN", "Burn %d") % enemy.burn)
	if enemy.poison > 0:
		parts.append(Tokens.translate_or("COMBAT_ENEMY_POISON", "Poison %d") % enemy.poison)
	parts.append(intent_text(enemy))
	return " · ".join(parts)


## Ikonen som text. 16×16-sprajtarna ligger i UI-agentens katalog; saknas de
## ritas reservglyfen, aldrig ett hål (Art.ui_icon varnar en gång per ikon).
static func icon_glyph(icon_name: StringName) -> String:
	return Art.ui_icon_glyph(icon_name)


static func make_label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", Tokens.dpi(font_size))
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
