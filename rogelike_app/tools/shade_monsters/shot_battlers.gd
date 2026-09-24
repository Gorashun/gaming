extends SceneTree
## Skärmdumpar av fiendekonsten i korridoren: ställer ett möte framför
## spelaren i stridssplitten (45 % korridor) och sparar en bild per uppsättning.
## Samma vy och samma ljus som i spelet; ingen spellogik körs.
##
## [codeblock]
## xvfb-run -a -s "-screen 0 480x900x24" "$GODOT_BIN" --resolution 480x900 \
##   --rendering-driver vulkan --audio-driver Dummy -s tools/shade_monsters/shot_battlers.gd -- \
##   --shots=res://docs/screenshots/m7_shades --tag=shades
## [/codeblock]
##
## Flaggor:
##   --shots=DIR   katalog för skärmdumparna (krävs)
##   --tag=NAME    prefix på filnamnen
##   --seed=N      våningens seed (standard 7)
##   --explore     explore-splitten i stället för stridssplitten

const VIEW_SCENE: String = "res://src/game/corridor/corridor_view.tscn"

## Namn → fiende-id:n i formeringsordning (främre ledet först).
const SETS: Array[Dictionary] = [
	{"name": "rust_rat_x4", "ids": ["RUST_RAT", "RUST_RAT", "RUST_RAT", "RUST_RAT"]},
	{"name": "boss_slagjaw", "ids": ["SLAGJAW"]},
	{"name": "thorn_imp_pip_thief", "ids": ["THORN_IMP", "PIP_THIEF"]},
	{"name": "iron_tick", "ids": ["IRON_TICK"]},
	{"name": "grave_hand_slag_moth", "ids": ["GRAVE_HAND", "SLAG_MOTH"]},
	{"name": "chalk_dummy", "ids": ["CHALK_DUMMY"]},
]

var _args: Dictionary = {}
var _failed: bool = false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var body: String = arg.substr(2)
			var eq: int = body.find("=")
			_args[body if eq < 0 else body.substr(0, eq)] = true if eq < 0 else body.substr(eq + 1)
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var dir: String = String(_args.get("shots", ""))
	if dir == "":
		printerr("shot_battlers: --shots=DIR krävs")
		quit(2)
		return
	var tag: String = String(_args.get("tag", ""))
	var rng: Rng = Rng.new(int(_args.get("seed", 7)))
	var graph: RunGraph = RunGraph.generate_floor(1, rng)
	var map: CorridorMap = CorridorMap.build(graph, rng.fork("corridor"), false)

	var host: Control = Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var view: Node = (load(VIEW_SCENE) as PackedScene).instantiate()
	host.add_child(view)
	view.call("set_reduced_motion", true)
	view.call("setup", map, {"hp": 74, "max_hp": 100, "room": 1, "pips": 12})
	await _settle(4)
	if not bool(_args.get("explore", false)):
		view.call("show_combat_split")

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for spec: Dictionary in SETS:
		view.call("clear_encounter")
		view.call("set_next_enemies", spec["ids"])
		if bool(spec.get("far", false)):
			# Takt 1: silhuetten i mörkret, två rutor bort.
			view.call("_show_silhouettes", 2)
		else:
			view.call("restore_encounter")
		await _settle(6)
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var path: String = "%s/%s%s.png" % [dir, "%s_" % tag if tag != "" else "", spec["name"]]
		if image == null or image.save_png(path) != OK:
			printerr("shot_battlers: kunde inte spara %s" % path)
			_failed = true
			continue
		var sources: PackedStringArray = PackedStringArray()
		for i: int in range(int(view.call("enemy_count"))):
			var battler: EnemyBattler = view.call("enemy_battler", i) as EnemyBattler
			sources.append("%s:%s %.2fx%.2fm" % [battler.enemy_id, battler.source, battler.width_m, battler.height_m])
		print("  shot %s  [%s]" % [path, ", ".join(sources)])
	quit(1 if _failed else 0)


func _settle(frames: int) -> void:
	for _i: int in range(frames):
		await process_frame
