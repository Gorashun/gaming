class_name GameOverScreen
extends GameScreen
## Död eller vinst. UI_GUIDE §3: "Stäng loopen ärligt: visa vad som dödade dig
## och vad du låste upp" med "EN RUN TILL" som primärknapp i tumzonen.
##
## Skärmen räknar ingenting själv. Siffrorna kommer från
## [method GameController.build_summary].
##
## [b]M6 – dödsskärm v2:[/b] Marrow presenterar Kistan. Det hjälten bar listas,
## spelaren väljer upp till Kistans kapacitet ([method Expedition.rescue_capacity]),
## och resten går förlorat med hjälten (permadöd). Räddningsannonsen är en
## frivillig sekundärknapp som ger en plats till: skärmen skickar
## [signal rescue_offer_requested], controllern svarar med
## [method grant_rescue_slot] när "annonsen" bekräftats. Ingen SDK i M6.
## MetaScore-siffran visas inte längre (PROGRESSION_REDESIGN §6); den lever kvar
## i koden som rekordmått.

## Spelaren vill se en annons för att rädda ett föremål till. Frivillig, aldrig
## ett avbrott (DECISIONS 2026-09-22).
signal rescue_offer_requested()

@onready var _title: Label = $Margin/Column/Title
@onready var _subtitle: Label = $Margin/Column/Subtitle
@onready var _stats: VBoxContainer = $Margin/Column/Stats
@onready var _seed_label: Label = $Margin/Column/SeedLabel
@onready var _again_button: Button = $Margin/Column/AgainButton

## Konfettins livslängd. UI_GUIDE §2.10 motion/celebrate = 520 ms; partiklarna
## får leva längre än så eftersom de faller, men bursten är en engångshändelse.
const CONFETTI_LIFETIME: float = 2.4
## Hur länge en siffra räknas upp. Kort nog att inte bli en väntan, långt nog
## att ögat hinner läsa att den STIGER (research 01 slutsats 2: synlig kausalitet).
const COUNT_UP_SECONDS: float = 0.9

var _summary: Dictionary = {}
## Etiketter som räknas upp i stället för att bara stå där.
var _count_labels: Dictionary = {}


func enter(ctx: Dictionary) -> void:
	_summary = ctx
	var won: bool = bool(ctx.get("won", false))
	_style(won)

	_title.text = tr("GAMEOVER_WIN_TITLE") if won else tr("GAMEOVER_LOSE_TITLE")
	_subtitle.text = _subtitle_text(ctx, won)

	_add_stat(tr("GAMEOVER_STAT_ROOM_REACHED"), "%d" % int(ctx.get("room_reached", 1)))
	_add_stat(tr("GAMEOVER_STAT_ROOMS_CLEARED"), "%d" % int(ctx.get("rooms_cleared", 0)))
	_add_count_stat(tr("GAMEOVER_STAT_BEST_CHAIN"), int(ctx.get("best_chain", 0)),
		tr("GAMEOVER_STAT_BEST_CHAIN_VALUE"))
	_add_stat(tr("GAMEOVER_STAT_HP_LEFT"), "%d" % int(ctx.get("hp_left", 0)))

	# Pips-utbetalningen (§A.3). Förlust betalar alltid, och "första gången"-
	# bonusarna gör att en spektakulär förlust betalar bättre än en trist
	# överlevnad. Det är rätt incitament: vi belönar att spelaren försökte.
	var award: Dictionary = ctx.get("award", {}) as Dictionary
	if not award.is_empty():
		_add_divider()
		_add_count_stat(Tokens.translate_or("GAMEOVER_PIPS", "Pips earned"),
			int(award.get("earned", 0)), "+%d", true)
	_add_hero_lines(ctx, won)

	_seed_label.text = tr("GAMEOVER_SEED") % int(ctx.get("seed", 0))
	# Knappen leder till staden, inte rakt in i en ny run: GO DOWN ligger redan
	# i tumzonen där, så "en run till" är fortfarande ett tapp (§A.4 regel 2).
	_again_button.text = Tokens.translate_or("GAMEOVER_BACK_TO_TOWN", "BACK TO CHALKRIM")
	_again_button.pressed.connect(play_again)
	_open_rescue(ctx, won)

	# Ögonblicket. Ljudet först, sedan siffrorna som räknas upp, sedan – bara
	# vid vinst – kritdammet. Ordningen är avsiktlig: ljudet säger vad som hände,
	# siffrorna säger hur mycket, konfettin är grädden.
	Juice.sfx(&"victory" if won else &"defeat", 1.0, -2.0 if won else -4.0)
	Juice.haptic(Haptics.Level.HEAVY)
	_run_count_ups()
	if won:
		_confetti()


## Död-skärmen ska svara på tre frågor i en mening: vad dödade dig, hur långt
## kom du, och att det var ditt beslut (UI_GUIDE §3: "stäng loopen ärligt").
func _subtitle_text(ctx: Dictionary, won: bool) -> String:
	if won:
		return tr("GAMEOVER_WIN_SUBTITLE")
	var lines: PackedStringArray = PackedStringArray()
	lines.append(Tokens.translate_or("GAMEOVER_YOUR_CALL", "It was your call."))
	var killer: String = String(ctx.get("killed_by", ""))
	if killer != "":
		lines.append(Tokens.translate_or("GAMEOVER_KILLED_BY", "Killed by %s.") % [
			Tokens.translate_or(Content.enemy_key(killer), killer)])
	lines.append(tr("GAMEOVER_LOSE_SUBTITLE") % int(ctx.get("room_reached", 1)))
	return " ".join(lines)


## Kritdamm som konfetti (UI_GUIDE §8.1: partiklar hör till händelsen, inte till
## objektet, och ritas därför i krit-lagret). Reducerad rörelse byter bursten mot
## en statisk uttoning (§6.1).
func _confetti() -> void:
	if Settings.reduced_motion:
		var flash: ColorRect = ColorRect.new()
		flash.color = Color(Tokens.SEM_CHARGE, 0.25)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(flash)
		flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var fade: Tween = create_tween()
		fade.tween_property(flash, "color:a", 0.0, Tokens.MOTION_CELEBRATE)
		fade.tween_callback(flash.queue_free)
		return

	var particles: GPUParticles2D = GPUParticles2D.new()
	particles.amount = 120
	particles.lifetime = CONFETTI_LIFETIME
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.position = Vector2(size.x * 0.5, size.y * 0.22)
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(size.x * 0.45, Tokens.dp(8), 0.0)
	material.direction = Vector3(0.0, 1.0, 0.0)
	material.spread = 35.0
	material.initial_velocity_min = Tokens.dp(80)
	material.initial_velocity_max = Tokens.dp(220)
	material.gravity = Vector3(0.0, Tokens.dp(220), 0.0)
	material.angular_velocity_min = -180.0
	material.angular_velocity_max = 180.0
	material.scale_min = 0.6
	material.scale_max = 1.6
	# Krita, inte glitter: fyra toner ur §2.2/§2.3, ingen gradient, ingen glow.
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Tokens.CHALK_100)
	ramp.set_color(1, Tokens.SEM_CHARGE)
	var texture_ramp: GradientTexture1D = GradientTexture1D.new()
	texture_ramp.gradient = ramp
	material.color_ramp = texture_ramp
	particles.process_material = material
	particles.texture = _chalk_fleck()
	add_child(particles)
	particles.emitting = true


## En 6×6 px vit fyrkant som partikeltextur. Att generera den här i stället för
## att lägga en PNG i assets/ håller dev ur UI-agentens katalog.
func _chalk_fleck() -> Texture2D:
	var image: Image = Image.create(6, 6, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


## Räknar upp varje siffra som lagts med [method _add_count_stat].
func _run_count_ups() -> void:
	for label: Variant in _count_labels:
		var entry: Dictionary = _count_labels[label] as Dictionary
		var target: int = int(entry["value"])
		var format: String = String(entry["format"])
		var node: Label = label as Label
		if target <= 0:
			node.text = format % 0
			continue
		var tween: Tween = create_tween()
		tween.tween_method(
			func(value: float) -> void: node.text = format % int(round(value)),
			0.0, float(target), COUNT_UP_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _style(won: bool) -> void:
	$Background.color = Tokens.SURFACE_PIT
	for side: String in ["left", "right", "top", "bottom"]:
		$Margin.add_theme_constant_override("margin_" + side, Tokens.dpi(Tokens.SCREEN_MARGIN))
	$Margin/Column.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_4))
	_stats.add_theme_constant_override("separation", Tokens.dpi(Tokens.SPACE_2))

	Tokens.apply_type(_title, Tokens.TYPE_DISPLAY_L)
	ChalkFx.apply(_title, ChalkFx.DISPLAY)
	_title.add_theme_color_override("font_color", Tokens.SEM_HEAL if won else Tokens.SEM_BLOOD)
	_title.clip_text = true
	_subtitle.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_BODY))
	_subtitle.add_theme_color_override("font_color", Tokens.CHALK_300)
	_seed_label.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_CAPTION))
	_seed_label.add_theme_color_override("font_color", Tokens.CHALK_500)
	_seed_label.clip_text = true

	# EN RUN TILL är skärmens enda riktiga knapp och den ska gå att träffa med
	# tummen utan att titta: 72 dp hög (56 dp är minimum för primär, §2.9) och
	# full bredd längst ned.
	_again_button.custom_minimum_size = Vector2(0.0, Tokens.dp(Tokens.BUTTON_PRIMARY_HEIGHT + 16))
	_again_button.clip_text = true
	_again_button.add_theme_font_size_override("font_size", Tokens.dpi(Tokens.TYPE_TITLE))
	ChalkFx.apply(_again_button, ChalkFx.BUTTON)
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


## Som [method _add_stat], men värdet räknas upp från noll när skärmen visas.
func _add_count_stat(label_text: String, value: int, format: String, emphasise: bool = false) -> void:
	_add_stat(label_text, format % 0, emphasise)
	var row: HBoxContainer = _stats.get_child(_stats.get_child_count() - 1) as HBoxContainer
	var value_label: Label = row.get_child(1) as Label
	_count_labels[value_label] = {"value": value, "format": format}


func _add_divider() -> void:
	var line: ColorRect = ColorRect.new()
	line.color = Tokens.SURFACE_LINE
	line.custom_minimum_size = Vector2(0.0, Tokens.dp(Tokens.STROKE_HAIR))
	_stats.add_child(line)


## Startar en ny seedad run direkt. UI_GUIDE §3: ett tryck, ingen mellanmeny.
func play_again() -> void:
	Juice.ui_tap(1.0)
	Juice.haptic(Haptics.Level.MEDIUM)
	screen_done.emit({"again": true})


# --- M6: hjälten och Kistan ----------------------------------------------------

var _picker: ItemPicker = null
var _rescue: Dictionary = {}
var _ad_used: bool = false


## Hjältens rad: vem som dog (och på vilken nivå), eller vad vinsten gav.
func _add_hero_lines(ctx: Dictionary, won: bool) -> void:
	var hero: Dictionary = ctx.get("hero", {}) as Dictionary
	if hero.is_empty():
		return
	_add_divider()
	if won:
		_add_stat(Tokens.translate_or("HERO_XP_GAINED", "XP gained"), "+%d" % int(hero.get("xp", 0)))
		if int(hero.get("level_ups", 0)) > 0:
			_add_stat(Tokens.translate_or("HERO_LEVEL_UP", "Level up"), Tokens.translate_or(
				"HERO_LEVEL_VALUE", "level %d") % int(hero.get("level", 1)), true)
		if int(hero.get("secured", 0)) > 0:
			_add_stat(Tokens.translate_or("HERO_GEAR_SECURED", "Gear secured"), "%d" % int(hero.get("secured", 0)))
		return
	_add_stat(Tokens.translate_or("HERO_FALLEN", "%s is dead") % String(hero.get("name", "")),
		Tokens.translate_or("HERO_LEVEL_VALUE", "level %d") % int(hero.get("level", 1)), true)


## Marrow vid kärran: välj vad Kistan räddar (§3.4). Visas bara vid död och bara
## när hjälten bar något.
func _open_rescue(ctx: Dictionary, won: bool) -> void:
	_rescue = ctx.get("rescue", {}) as Dictionary
	if won or _rescue.is_empty():
		return
	var items: Array[Item] = Item.list_from_dicts(_rescue.get("items", []))
	if items.is_empty():
		return
	_picker = ItemPicker.new()
	_picker.name = "RescuePicker"
	_picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	$Margin/Column.add_child(_picker)
	$Margin/Column.move_child(_picker, _again_button.get_index())
	_again_button.visible = false
	var capacity: int = int(_rescue.get("capacity", 0))
	var body: String = Tokens.translate_or("CHEST_MARROW_BODY",
		"Everything else stays down there with them.")
	if capacity <= 0:
		body = Tokens.translate_or("CHEST_EMPTY_BODY",
			"No chest to put it in. Build one in the forge and I will carry what fits.")
	var secondary: Array = []
	if bool(_rescue.get("ad_available", true)) and items.size() > capacity:
		secondary = ["CHEST_AD_OFFER", "Watch an ad: rescue one more"]
	_picker.open(["CHEST_MARROW_TITLE", "Marrow holds out the cart"], body, items, capacity,
		["CHEST_RESCUE_CONFIRM", "RESCUE %d AND GO UP"], secondary)
	_picker.confirmed.connect(_on_rescue_confirmed)
	_picker.secondary_pressed.connect(func() -> void: rescue_offer_requested.emit())


## Controllern svarar på [signal rescue_offer_requested] när "annonsen" är
## bekräftad: en plats till, en gång per död.
func grant_rescue_slot() -> void:
	if _picker == null or _ad_used:
		return
	_ad_used = true
	_picker.set_max(_picker.max_select() + 1)
	_picker.set_secondary_enabled(false)


func rescue_picker() -> ItemPicker:
	return _picker


func _on_rescue_confirmed(indices: Array) -> void:
	Juice.haptic(Haptics.Level.MEDIUM)
	screen_done.emit({"again": true, "rescue": indices, "ad": _ad_used})


func summary() -> Dictionary:
	return _summary
