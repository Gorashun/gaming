extends Node
## Entry point: title screen (continue / new hero) or automated start from command-line args:
##   godot -- --autostart --class=<id> --zone=<id> --seed=<n> --tier=<id> --level=<n>
##           --screenshot=<path> --shot-after=<seconds> --quit-after=<seconds> --bot
## UI capture flags (ui-ux):
##   --title                 show the title flow even with --autostart (screenshots of the title)
##   --title-page=create     open the class-select page directly
##   --open-screen=<name>    after the session starts, wait 2 s then open that screen
##                           (any res://scripts/ui/<name>_screen.gd; e.g. inventory, crafting, pets)
##   --screen-ctx=<k:v,...>  context for that screen (e.g. tab:jeweler)
##   --golden=<rarity>       queue a golden-moment card with a generated item (HUD capture)

var args = {}
var session: Session
var ui: CanvasLayer

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv = a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	if args.has("title"):
		Game.testing = true
		_title()
		_capture()
	elif args.has("autostart"):
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
	if args.has("open-screen") or args.has("golden"):
		_seed_ui_demo(ch)
	_start_session(args.get("zone", "a1_z1"), int(args.get("seed", "-1")))
	if args.has("bot"):
		var bot = load("res://tests/playtest_bot.gd").new()
		bot.args = args
		add_child(bot)
	if args.has("open-screen"):
		_open_screen_later(str(args["open-screen"]))
	if args.has("golden"):
		_golden_later(str(args["golden"]))
	_capture()

## Give a UI capture run something to show: a bag with mixed rarities, materials and gold.
func _seed_ui_demo(ch: CharacterData) -> void:
	var rar = ["common", "magic", "magic", "rare", "rare", "epic", "legendary", "magic", "rare", "common", "epic", "unique"]
	for i in 18:
		var r: String = rar[i % rar.size()]
		var it = {}
		if r == "unique":
			var us = Content.all("uniques")
			if us.size() > 0:
				it = Items.from_unique(us[0].id, ch.level + 2, "test")
		else:
			it = Items.generate(max(1, ch.level + (i % 4)), r, ch.class_id if i % 3 != 0 else "", "", "", "test")
		if not it.is_empty():
			if i == 2:
				it["locked"] = true
			if i % 5 == 1:
				it["upgrade"] = 3
			ch.add_item(it)
	for m in Content.all("materials"):
		ch.add_material(m.id, 6 + (m.id.length() * 3) % 20)
	ch.gold += 2450
	# companions for the collection screens
	var pets = Content.all("pets")
	for i in min(5, pets.size()):
		UiTheme.api_call("Pets", "grant_pet", [ch, pets[i * 3 % pets.size()].id], false)
	if pets.size() > 0:
		UiTheme.api_call("Pets", "set_active", [ch, pets[0].id], false)
	var mounts = Content.all("mounts")
	for i in min(3, mounts.size()):
		UiTheme.api_call("Mounts", "grant_mount", [ch, mounts[i].id], false)
	if mounts.size() > 0:
		UiTheme.api_call("Mounts", "set_active", [ch, mounts[0].id], false)
	if "titles" in ch:
		ch.titles.append_array(["the Rekindler", "Friend of Moths"])
		ch.title = "the Rekindler"
	for q in Content.all("quests").slice(0, 2):
		UiTheme.api_call("Quests", "accept", [ch, q.id], false)
	if ch.materials.has("hushmark"):
		ch.materials["hushmark"] = 10
	ch.skill_points += 3
	ch.potions = max(ch.potions, 3)

func _open_screen_later(which: String) -> void:
	await get_tree().create_timer(2.0, true, false, true).timeout
	if session == null:
		return
	var ctx = {}
	for kv in str(args.get("screen-ctx", "")).split(",", false):
		var p = kv.split(":", true, 1)
		if p.size() == 2:
			ctx[p[0]] = p[1]
	ScreenBase.open(session, which, ctx)

func _golden_later(rarity: String) -> void:
	await get_tree().create_timer(1.5, true, false, true).timeout
	var ch = Game.character
	var it = Items.generate(ch.level + 2, rarity, ch.class_id, "", "main_hand", "test")
	if not it.is_empty():
		Events.golden_moment.emit(it)

func _capture() -> void:
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
		ui = null
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
	_start_session(ch.current_act_town())

func new_character(char_name: String, cls: String, hardcore: bool) -> void:
	Game.new_character(char_name, cls, hardcore)
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
