extends Node
## Entry point: title screen (continue / new hero) or automated start from command-line args:
##   godot -- --autostart --class=<id> --zone=<id> --seed=<n> --tier=<id> --level=<n>
##           --screenshot=<path> --shot-after=<seconds> --quit-after=<seconds> --bot

var args = {}
var session: Session
var ui: CanvasLayer

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv = a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	if args.has("autostart"):
		_autostart()
	else:
		_title()

func _autostart() -> void:
	Game.testing = true
	var cls: String = args.get("class", "lanternbearer")
	var ch = Game.new_character("Tester", cls, args.has("hardcore"))
	if args.has("level"):
		var target = int(args.level)
		while ch.level < target:
			ch.add_xp(Progression.xp_to_next(ch.level))
		ch.recalc()
	if args.has("tier"):
		ch.difficulty = args.tier
		if not ch.unlocked_tiers.has(args.tier):
			ch.unlocked_tiers.append(args.tier)
	if args.has("gear"):
		for s in Items.SLOTS:
			var slot = "ring" if s.begins_with("ring") else s
			var it = Items.generate(ch.level, args.gear, cls, "", slot, "test")
			if not it.is_empty():
				ch.equipment[s] = it
		ch.recalc()
	_start_session(args.get("zone", "a1_z1"), int(args.get("seed", "-1")))
	if args.has("bot"):
		var bot = load("res://tests/playtest_bot.gd").new()
		bot.args = args
		add_child(bot)
	if args.has("screenshot"):
		var after = float(args.get("shot-after", "4"))
		await get_tree().create_timer(after, true, false, true).timeout
		var shots = int(args.get("shots", "1"))
		if args.has("debug-ui"):
			_dump(get_tree().root, 0)
		for i in shots:
			var img = get_viewport().get_texture().get_image()
			var path: String = args.screenshot
			if shots > 1:
				path = path.replace(".png", "_%d.png" % i)
			img.save_png(path)
			await get_tree().create_timer(float(args.get("shot-interval", "2")), true, false, true).timeout
	if args.has("quit-after"):
		await get_tree().create_timer(float(args["quit-after"]), true, false, true).timeout
		get_tree().quit()
	elif args.has("screenshot"):
		get_tree().quit()

func _start_session(zone: String, seed_value := -1) -> void:
	if ui:
		ui.queue_free()
	session = Session.new()
	add_child(session)
	session.travel(zone, seed_value)

func _title() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var t = load("res://scripts/ui/title_screen.gd").new()
	t.main = self
	ui.add_child(t)

func play_character(ch: CharacterData) -> void:
	Game.character = ch
	_start_session(ch.current_act_town() if ch.waypoints.is_empty() else ch.current_act_town())

func new_character(char_name: String, cls: String, hardcore: bool) -> void:
	var ch = Game.new_character(char_name, cls, hardcore)
	_start_session("a1_z1")

func _dump(n: Node, depth: int) -> void:
	if depth > 6:
		return
	var info = ""
	if n is Control:
		info = " pos=%s size=%s vis=%s mod=%s" % [n.global_position, n.size, n.visible, n.modulate]
	elif n is CanvasLayer:
		info = " layer=%d" % n.layer
	if n is Control or n is CanvasLayer or depth < 3:
		print("  ".repeat(depth), n.name, " [", n.get_class(), "]", info)
	for c in n.get_children():
		if c is Control or c is CanvasLayer or c.name in ["Session", "Main"]:
			_dump(c, depth + 1)
