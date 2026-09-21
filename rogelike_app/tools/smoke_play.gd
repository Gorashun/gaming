extends SceneTree
## Headless/xvfb-rökprov: spelar en hel run på våning 1 med Lookahead-policyn,
## tar skärmdumpar och avslutar med exit code 0 om allt gick igenom.
##
## Körs med:
## [codeblock]
## xvfb-run -a -s "-screen 0 1080x1920x24" "$GODOT_BIN" --resolution 1080x1920 \
##   --audio-driver Dummy -s tools/smoke_play.gd -- --pipwreck-seed=7 \
##   --shots=res://docs/screenshots/m2
##
## # Bara logiken, utan fönster och utan skärmdumpar:
## "$GODOT_BIN" --headless -s tools/smoke_play.gd -- --pipwreck-seed=7
## [/codeblock]
##
## Flaggor:
##   --pipwreck-seed=N   seed för runnen (läses även av GameController)
##   --shots=DIR         katalog för skärmdumpar (tom = inga skärmdumpar)
##   --locale=xx         tvingar språk (t.ex. sv). Tomt = projektets standard.
##   --max-seconds=N     säkerhetsstopp (standard 180)
##   --reduced-motion    kör hela rökprovet i reducerat rörelse-läge (§6.1)
##
## [b]Den här filen är medvetet tunn.[/b] Ett [code]-s[/code]-skript kompileras
## innan motorn registrerat autoloadarna, och allt som filen typar mot
## kompileras med den. En skärm som nämner [code]Juice[/code] skulle då fälla
## hela rökprovet med "Compile Error: Identifier not found: Juice" – felet ser ut
## som en trasig skärm men är en startordning. Drivrutinen ligger därför i
## [code]tools/smoke_driver.gd[/code] och laddas på första bildrutan, när
## [code]/root/Settings[/code] och [code]/root/Juice[/code] finns.
##
## Rökprovet rör aldrig [Resolver] eller [Rng] direkt annat än genom
## [method Policy.lookahead]: det går samma väg genom UI som en spelare gör, och
## hittar därför fel som ett rent logiktest inte kan hitta.

const DRIVER_SCRIPT: String = "res://tools/smoke_driver.gd"

var _args: Dictionary = {}


func _initialize() -> void:
	_args = _parse_args()
	# Första bildrutan, inte _initialize: awaits som återupptas ur
	# SceneTree-initieringen ligger utanför motorns trädtraversering, och
	# autoloadarna finns inte heller ännu.
	process_frame.connect(_boot, CONNECT_ONE_SHOT)


func _boot() -> void:
	var script: GDScript = load(DRIVER_SCRIPT) as GDScript
	if script == null:
		printerr("SMOKE FAIL: kunde inte ladda %s" % DRIVER_SCRIPT)
		quit(1)
		return
	var driver: Node = script.new() as Node
	driver.name = "SmokeDriver"
	driver.set("args", _args)
	root.add_child(driver)


func _parse_args() -> Dictionary:
	var parsed: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var body: String = arg.substr(2)
		var equals: int = body.find("=")
		if equals < 0:
			parsed[body] = true
		else:
			parsed[body.substr(0, equals)] = body.substr(equals + 1)
	return parsed
