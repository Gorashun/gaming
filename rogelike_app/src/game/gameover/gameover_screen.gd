class_name GameOverScreen
extends GameScreen
## Död eller vinst. UI_GUIDE §3: "Stäng loopen ärligt: visa vad som dödade dig
## och vad du låste upp" med "EN RUN TILL" som primärknapp i tumzonen.
##
## Skärmen räknar ingenting själv. Siffrorna kommer från
## [method GameController.build_summary] och poängen från [MetaScore], så att
## formeln kan testas utan UI och ändras på ett ställe.

@onready var _title: Label = $Margin/Column/Title
@onready var _subtitle: Label = $Margin/Column/Subtitle
@onready var _stats: VBoxContainer = $Margin/Column/Stats
@onready var _seed_label: Label = $Margin/Column/SeedLabel
@onready var _again_button: Button = $Margin/Column/AgainButton

var _summary: Dictionary = {}


func enter(ctx: Dictionary) -> void:
	_summary = ctx
	var won: bool = bool(ctx.get("won", false))
	_style(won)

	_title.text = "VÅNINGEN RENSAD" if won else "PIPWRECK"
	_subtitle.text = (
		"Slaggkäften föll. Våning 2 väntar i nästa milstolpe."
		if won
		else "Du dog i rum %d. Ingen continue, inga revives." % int(ctx.get("room_reached", 1))
	)

	var score: Dictionary = ctx.get("score", {}) as Dictionary
	_add_stat("RUM NÅTT", "%d" % int(ctx.get("room_reached", 1)))
	_add_stat("RUM RENSADE", "%d" % int(ctx.get("rooms_cleared", 0)))
	_add_stat("STÖRSTA KEDJA", "%d skada" % int(ctx.get("best_chain", 0)))
	_add_stat("HP KVAR", "%d" % int(ctx.get("hp_left", 0)))
	_add_divider()
	_add_stat("Rum × %d" % MetaScore.POINTS_PER_ROOM, "+%d" % int(score.get("rooms", 0)))
	_add_stat("Kedja / %d" % MetaScore.CHAIN_DAMAGE_PER_POINT, "+%d" % int(score.get("chain", 0)))
	_add_stat("Överlevnad / %d HP" % MetaScore.HP_LEFT_PER_POINT, "+%d" % int(score.get("survival", 0)))
	if int(score.get("win", 0)) > 0:
		_add_stat("Vinstbonus", "+%d" % int(score.get("win", 0)))
	_add_stat("META-POÄNG", "%d" % int(score.get("total", 0)), true)

	# GAME_DESIGN §6.10: seeden är synlig. Det är communityns bevis på att vi
	# inte fuskar, och förutsättningen för dagliga utmaningar.
	_seed_label.text = "SEED %d" % int(ctx.get("seed", 0))
	_again_button.pressed.connect(play_again)


func _style(won: bool) -> void:
	$Background.color = Tokens.SURFACE_PIT
	for side: String in ["left", "right", "top", "bottom"]:
		$Margin.add_theme_constant_override("margin_" + side, Tokens.dpi(Tokens.SCREEN_MARGIN))
	$Margin/Column.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_4))
	_stats.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))

	_title.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_TITLE))
	_title.add_theme_color_override("font_color", Tokens.SEM_HEAL if won else Tokens.SEM_BLOOD)
	_title.clip_text = true
	_subtitle.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_BODY))
	_subtitle.add_theme_color_override("font_color", Tokens.CHALK_300)
	_seed_label.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_CAPTION))
	_seed_label.add_theme_color_override("font_color", Tokens.CHALK_500)
	_seed_label.clip_text = true

	_again_button.custom_minimum_size = Vector2(0.0, Tokens.dp(Tokens.BUTTON_PRIMARY_HEIGHT))
	_again_button.clip_text = true
	_again_button.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_HEADING))
	var style: StyleBoxFlat = Tokens.box(Tokens.CHALK_100, true, Tokens.STROKE_REG)
	style.bg_color = Tokens.CHALK_100
	for state_name: String in ["normal", "hover", "pressed", "focus"]:
		_again_button.add_theme_stylebox_override(state_name, style)
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		_again_button.add_theme_color_override(color_name, Tokens.SURFACE_PIT)


func _add_stat(label_text: String, value_text: String, emphasise: bool = false) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var name_label: Label = Label.new()
	name_label.text = label_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label: Label = Label.new()
	value_label.text = value_text
	var size: int = Tokens.TYPE_TITLE if emphasise else Tokens.TYPE_BODY_L
	var color: Color = Tokens.SEM_CHARGE if emphasise else Tokens.CHALK_300
	for label: Label in [name_label, value_label]:
		label.add_theme_font_size_override("font_size", Tokens.dpi(size))
		label.add_theme_color_override("font_color", color)
	# Bara etiketten klipps. Klipps även värdet blir dess minsta bredd noll och
	# siffran försvinner helt, eftersom etiketten tar hela raden.
	name_label.clip_text = true
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(name_label)
	row.add_child(value_label)
	_stats.add_child(row)


func _add_divider() -> void:
	var line: ColorRect = ColorRect.new()
	line.color = Tokens.SURFACE_LINE
	line.custom_minimum_size = Vector2(0.0, Tokens.dp(Tokens.STROKE_HAIR))
	_stats.add_child(line)


## Startar en ny seedad run direkt. UI_GUIDE §3: ett tryck, ingen mellanmeny.
func play_again() -> void:
	Juice.sfx("run_again", 1.0)
	Juice.haptic(Haptics.Level.MEDIUM)
	screen_done.emit({"again": true})


func summary() -> Dictionary:
	return _summary
