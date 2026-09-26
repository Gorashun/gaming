class_name Session
extends Node
## Runs a play session: owns the GameWorld + HUD, travel between zones, screens, death handling.

var world: GameWorld
var hud: Hud
var screen: Control
var ui_layer: CanvasLayer
var args = {}

func _init() -> void:
	name = "Session"
	add_to_group("session")
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)

func start(zone_id: String) -> void:
	travel(zone_id)

func travel(zone_id: String, seed_value := -1) -> void:
	get_tree().paused = false
	if screen and is_instance_valid(screen):
		screen.queue_free()
	var ch = Game.character
	var z = Content.get_rec("zones", zone_id)
	if z.is_empty():
		zone_id = ch.current_act_town()
		z = Content.get_rec("zones", zone_id)
	ch.current_act = z.get("act", ch.current_act)
	if not ch.waypoints.has(zone_id):
		ch.waypoints.append(zone_id)
	Game.save_character()
	if world:
		world.queue_free()
		world = null
	if hud:
		hud.queue_free()
	await get_tree().process_frame
	world = GameWorld.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	world.load_zone(zone_id, seed_value)
	hud = Hud.new()
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	ui_layer.add_child(hud)
	hud.setup(world.player, self)
	_fade_in()

func _fade_in() -> void:
	var r = ColorRect.new()
	r.color = Color(0, 0, 0, 1)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(r)
	var t = r.create_tween()
	t.tween_property(r, "color:a", 0.0, 0.6)
	t.tween_callback(r.queue_free)

func open_screen(which: String) -> void:
	if screen and is_instance_valid(screen):
		screen.queue_free()
	var path = {"inventory": "res://scripts/ui/inventory_screen.gd", "skills": "res://scripts/ui/skills_screen.gd",
		"map": "res://scripts/ui/map_screen.gd", "menu": "res://scripts/ui/menu_screen.gd", "credits": "res://scripts/ui/credits_screen.gd",
		"character": "res://scripts/ui/character_screen.gd", "crafting": "res://scripts/ui/crafting_screen.gd",
		"stash": "res://scripts/ui/stash_screen.gd", "vendor": "res://scripts/ui/vendor_screen.gd"}.get(which, "")
	if path == "" or not ResourceLoader.exists(path):
		Events.toast.emit("Coming soon", UiTheme.MUTED)
		return
	var s: ScreenBase = load(path).new()
	s.session = self
	ui_layer.add_child(s)
	screen = s
	get_tree().paused = true
	s.closed.connect(func():
		get_tree().paused = false
		if world and world.player:
			world.player.sync_from_character()
		Game.save_character())

func open_station(which: String) -> void:
	open_screen(which)

func on_zone_exit(zone_id: String) -> void:
	var z = Content.get_rec("zones", zone_id)
	var next: String = z.get("next", Game.character.current_act_town())
	if z.get("boss", "") != "":
		_on_act_complete(z)
	_show_summary(zone_id, next)

func _on_act_complete(z: Dictionary) -> void:
	var ch = Game.character
	var acts = Content.all("acts")
	var last_act: Dictionary = acts[-1]
	if z.get("act", "") == last_act.id:
		# Story complete on this tier → unlock next
		for d in Content.all("difficulties"):
			if d.get("unlock", "") == ch.difficulty and not ch.unlocked_tiers.has(d.id):
				ch.unlocked_tiers.append(d.id)
				Events.toast.emit("New difficulty unlocked: " + d.name, UiTheme.EMBER)
		ch.discoveries.append("story_complete:" + ch.difficulty)

## Natural stopping point (welfare): summary + choice, next run never auto-starts.
func _show_summary(zone_id: String, next: String) -> void:
	get_tree().paused = true
	var s = ScreenBase.new()
	s.session = self
	ui_layer.add_child(s)
	s.build(Content.get_rec("zones", zone_id).get("name", "") + " — cleansed")
	screen = s
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	s.body.add_child(v)
	var st: Dictionary = world.stats_session
	var mins = (Time.get_ticks_msec() / 1000.0 - float(st.start)) / 60.0
	v.add_child(UiTheme.label("Monsters rekindled: %d     Items found: %d     Gold: %d     XP: %d     Time: %.1f min" % [st.kills, st.items, st.gold, st.xp, mins], 22))
	v.add_child(UiTheme.label("A good place to rest your wick. Your progress is saved.", 20, UiTheme.MUTED))
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	var nz = Content.get_rec("zones", next)
	h.add_child(UiTheme.button("Continue: " + nz.get("name", "Onward"), func(): travel(next), 22, Vector2(380, 76)))
	h.add_child(UiTheme.button("Return to town", func(): travel(Game.character.current_act_town()), 22, Vector2(260, 76)))
	h.add_child(UiTheme.button("Save & rest", func():
		Game.save_character()
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main.tscn"), 22, Vector2(220, 76)))
	s.closed.connect(func(): get_tree().paused = false)

func on_player_died() -> void:
	var ch = Game.character
	await get_tree().create_timer(1.6).timeout
	get_tree().paused = true
	var s = ScreenBase.new()
	s.session = self
	ui_layer.add_child(s)
	screen = s
	if ch.hardcore:
		s.build("Your Last Flame has gone out")
		ch.dead = true
		Game.save_character()
		var v = VBoxContainer.new()
		s.body.add_child(v)
		v.add_child(UiTheme.label("%s, level %d, rests now in the Hall of Embers." % [ch.name, ch.level], 24))
		v.add_child(UiTheme.button("Carry the ember on (continue as a normal hero)", func():
			var copy = CharacterData.from_dict(ch.to_dict())
			copy.id = ch.id + "_ember"
			copy.hardcore = false
			copy.dead = false
			copy.name = ch.name + " (Ember)"
			Game.character = copy
			Game.save_character()
			travel(copy.current_act_town()), 22, Vector2(640, 76)))
		v.add_child(UiTheme.button("Return to title", func():
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/main.tscn"), 22, Vector2(300, 70)))
	else:
		s.build("You were snuffed out...")
		var v = VBoxContainer.new()
		s.body.add_child(v)
		v.add_child(UiTheme.label("No worries — your flame rekindles. You keep everything.", 22, UiTheme.MUTED))
		v.add_child(UiTheme.button("Rekindle here", func():
			s.queue_free()
			get_tree().paused = false
			world.player.revive()
			var start = world.layout.cell_to_world(world.layout.rooms[world.layout.start_room].center)
			world.player.global_position = start, 24, Vector2(320, 76)))
		v.add_child(UiTheme.button("Return to town", func(): travel(ch.current_act_town()), 22, Vector2(320, 70)))

func salvage_item(it: Dictionary) -> void:
	var y = InventoryOps.salvage_yield(it)
	for m in y:
		Game.character.add_material(m, y[m])

func auto_spend_points() -> void:
	var ch = Game.character
	var skills = Content.where("skills", "class", ch.class_id)
	var guard = 0
	while ch.skill_points > 0 and guard < 50:
		guard += 1
		var best = null
		for s in skills:
			if s.id == ch.cls().get("basic_attack", ""):
				continue
			var r = int(ch.skill_ranks.get(s.id, 0))
			if ch.level >= int(s.get("unlock_level", 1)) and r < int(s.get("max_rank", 5)):
				if best == null or r < int(ch.skill_ranks.get(best.id, 0)):
					best = s
		if best == null:
			break
		ch.skill_points -= 1
		ch.skill_ranks[best.id] = int(ch.skill_ranks.get(best.id, 0)) + 1
		if not ch.skill_bar.has(best.id):
			for i in 4:
				if ch.skill_bar[i] == "":
					ch.skill_bar[i] = best.id
					break
	if hud:
		hud.touch.refresh_bar()

func _notification(what: int) -> void:
	# Welfare: auto-pause + save when the app loses focus; no damage while paused.
	if (what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED) and not Game.testing:
		if world and not (screen and is_instance_valid(screen)):
			open_screen("menu")
		Game.save_character()
