class_name Session
extends Node
## Runs a play session: owns the GameWorld + HUD, travel between zones, screens, death handling.

var world: GameWorld
var hud: Hud
var screen: Control
var ui_layer: CanvasLayer
var args = {}
var current_npc = ""        # last NPC talked to (screens read this for quests/vendors)

func _init() -> void:
	name = "Session"
	add_to_group("session")
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)

func start(zone_id: String) -> void:
	MainQuest.ensure_started(Game.character)
	travel(zone_id)

## spawn_pos: optional Vector3 to place the hero (portal back); otherwise the zone start.
func travel(zone_id: String, seed_value := -1, spawn_pos = null) -> void:
	get_tree().paused = false
	if screen and is_instance_valid(screen):
		screen.queue_free()
	var ch = Game.character
	var was_mounted = world != null and is_instance_valid(world) and world.player != null and world.player.wants_mount
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
	if spawn_pos is Vector3 and world.player:
		world.player.global_position = world.clamp_to_walkable(world.player.global_position, spawn_pos) if world.is_walkable(spawn_pos) else world.player.global_position
	if was_mounted and world.player:
		world.player.wants_mount = true
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

var screen_arg = ""        # "crafting:smith" → screen "crafting", screen_arg "smith"

## Opens scripts/ui/<name>_screen.gd. "name:arg" (e.g. "crafting:smith") passes arg as screen_arg and
## ScreenBase.context {arg, tab, npc}. Known names include inventory, skills, map, menu, character,
## crafting, stash, vendor, curio, pets, mounts, stable, quests, bounties, lore, inn, codex, deeds,
## wardrobe, starmap, settings, credits, hall, collection.
func open_screen(which: String) -> void:
	screen_arg = ""
	if which.contains(":"):
		var parts = which.split(":", true, 1)
		which = parts[0]
		screen_arg = parts[1]
	which = SCREEN_ALIASES.get(which, which)
	var path = "res://scripts/ui/%s_screen.gd" % which
	if not which.is_valid_identifier() or not ResourceLoader.exists(path):
		Events.toast.emit("Coming soon", UiTheme.MUTED)
		return
	var s = ScreenBase.open(self, which, {"arg": screen_arg, "tab": screen_arg, "npc": current_npc})
	if s and "screen_arg" in s:
		s.screen_arg = screen_arg

const SCREEN_ALIASES := {"hero": "character", "bag": "inventory", "achievements": "deeds", "journal": "quests"}

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
		ch.track("tiers_cleared")
		ch.track("story_complete:" + ch.difficulty)
		if ch.hardcore:
			ch.track("lastflame_story_complete")

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
	var lock = MainQuest.zone_locked(Game.character, next)
	if lock != "":
		v.add_child(UiTheme.label(lock, 20, UiTheme.MUTED))
	else:
		h.add_child(UiTheme.button("Continue: " + nz.get("name", "Onward"), func(): travel(next), 22, Vector2(380, 76)))
	h.add_child(UiTheme.button("Return to town", func():
		Game.character.track("summary_return_to_town")
		travel(Game.character.current_act_town()), 22, Vector2(260, 76)))
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
	Game.character.track("salvages")
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

# ================================================================== Wave 2 gameplay APIs (for UI)
# All functions act on Game.character, return {ok:bool, message:String, ...} where it makes sense,
# refresh the hero and save. Pure rules live in scripts/rpg/* and scripts/systems/*.

func _refresh(save := true) -> void:
	if world and is_instance_valid(world) and world.player:
		world.player.sync_from_character()
	Events.stats_changed.emit()
	if save:
		Game.save_character()

func _result(ok: bool, message: String, extra := {}) -> Dictionary:
	var r = {"ok": ok, "message": message}
	r.merge(extra)
	if message != "":
		Events.toast.emit(message, Color(1, 0.85, 0.45) if ok else Color(0.85, 0.85, 0.9))
	return r

func _remember_return_point() -> void:
	## Saves where the hero stands so a "portal back" in town can return here.
	if world == null or not is_instance_valid(world) or world.is_town or world.player == null:
		return
	var p = world.player.global_position
	Game.character.return_portal = {"zone": world.zone.id, "seed": world.zone_seed, "pos": [p.x, p.z], "tier": Game.character.difficulty}

# ------------------------------------------------------------------ travel
func travel_fee(zone_id: String) -> int:
	return Travel.fee(Game.character, zone_id)

func travel_destinations() -> Array:
	return Travel.destinations(Game.character)

## Fast travel between unlocked waypoints (gold fee, free to towns).
func fast_travel(zone_id: String) -> Dictionary:
	var ch = Game.character
	var err = Travel.can_fast_travel(ch, zone_id)
	if err == "":
		err = MainQuest.zone_locked(ch, zone_id)
	if err != "":
		return _result(false, err)
	var fee = Travel.fee(ch, zone_id)
	ch.gold -= fee
	Events.gold_changed.emit(ch.gold)
	if Travel.is_town(zone_id):
		_remember_return_point()
	travel(zone_id)
	return {"ok": true, "message": "", "fee": fee}

func hearth_cooldown_left() -> float:
	return Travel.hearth_cooldown_left(Game.character)

## Homeward Wick: 3 s channel (cancelled by moving/casting/being hit), then home to the bound town.
func hearth() -> Dictionary:
	var ch = Game.character
	if world == null or world.player == null:
		return _result(false, "")
	var err = Travel.can_hearth(ch)
	if err != "":
		return _result(false, err)
	if world.player.is_channeling():
		return _result(false, "")
	var ok = world.player.start_channel("hearth", Travel.hearth_channel_s(), func():
		Travel.consume_hearth(ch)
		_remember_return_point()
		Events.hearth_used.emit()
		ch.track("hearth_uses")
		Sfx.play("hearth_done")
		Fx.burst(world.player.global_position + Vector3(0, 1, 0), Color(1, 0.8, 0.45), 30, 4.0, 0.12, 0.8, 2.0)
		travel(Travel.hearth_target(ch)))
	return {"ok": ok, "message": "", "channel_s": Travel.hearth_channel_s()}

## Bind the Homeward Wick to a visited town (innkeeper).
func bind_town(zone_id := "") -> Dictionary:
	var ch = Game.character
	if zone_id == "" and world:
		zone_id = world.zone.get("id", "")
	var err = Travel.can_bind(ch, zone_id)
	if err != "":
		return _result(false, err)
	if ch.bound_town == zone_id:
		return {"ok": true, "message": ""}
	ch.bound_town = zone_id
	Game.save_character()
	return _result(true, "Your wick is bound to %s" % Content.get_rec("zones", zone_id).get("name", zone_id))

## Opens the way back to the zone you left (same layout seed and position).
func portal_back() -> Dictionary:
	var ch = Game.character
	var rp: Dictionary = ch.return_portal
	if rp.is_empty() or Content.get_rec("zones", str(rp.get("zone", ""))).is_empty():
		return _result(false, "No portal to return through")
	ch.return_portal = {}
	var pos = null
	if rp.get("pos") is Array and rp.pos.size() >= 2:
		pos = Vector3(float(rp.pos[0]), 0, float(rp.pos[1]))
	travel(str(rp.zone), int(rp.get("seed", -1)), pos)
	return {"ok": true, "message": ""}

# ------------------------------------------------------------------ pets & mounts
func grant_pet(pet_id: String) -> Dictionary:
	if not Pets.grant_pet(Game.character, pet_id):
		return _result(false, "")
	if world and Game.character.active_pet == pet_id:
		world.spawn_pet()
	_refresh()
	return _result(true, "New companion: %s!" % Pets.rec(pet_id).get("name", pet_id))

func set_active_pet(pet_id: String) -> Dictionary:
	if not Pets.set_active(Game.character, pet_id):
		return _result(false, "You don't have that companion")
	if world:
		world.spawn_pet()
	_refresh()
	return {"ok": true, "message": ""}

func pet_ferry(mode := "sell", max_rank := -1) -> Dictionary:
	var r = Pets.ferry(Game.character, mode, max_rank)
	if r.ok:
		Sfx.play("pet_happy")
	_refresh()
	return _result(r.ok, r.message, r)

func grant_mount(mount_id: String) -> Dictionary:
	var ok = Mounts.grant_mount(Game.character, mount_id)
	Game.save_character()
	return {"ok": ok, "message": ""}

func buy_mount(mount_id: String) -> Dictionary:
	var r = Mounts.buy(Game.character, mount_id)
	Game.save_character()
	return _result(r.ok, r.message)

func set_active_mount(mount_id: String) -> Dictionary:
	var ch = Game.character
	var was = world and world.player and world.player.mounted
	if was:
		world.player.dismount("manual")
	if not Mounts.set_active(ch, mount_id):
		return _result(false, "You don't have that mount")
	if was:
		world.player.mount()
	Game.save_character()
	return {"ok": true, "message": ""}

## Mount/dismount. Returns {ok, mounted}.
func toggle_mount() -> Dictionary:
	if world == null or world.player == null:
		return {"ok": false, "mounted": false}
	if Game.character.active_mount == "":
		return _result(false, "Visit the Stablemaster to get a mount")
	var m = world.player.toggle_mount()
	return {"ok": true, "mounted": m, "message": ""}

# ------------------------------------------------------------------ quests
func available_quests(npc_id: String = "") -> Array:
	return Quests.available_for(Game.character, npc_id if npc_id != "" else current_npc)

func ready_quests(npc_id: String = "") -> Array:
	return Quests.ready_for(Game.character, npc_id if npc_id != "" else current_npc)

func active_quests() -> Array:
	return Quests.active_list(Game.character)

func quest_state(quest_id: String) -> String:
	return Quests.state(Game.character, quest_id)

func accept(quest_id: String) -> bool:
	var ok = Quests.accept(Game.character, quest_id)
	if ok:
		Sfx.play("quest_accept")
		Events.toast.emit("New quest: %s" % Quests.rec(quest_id).get("name", quest_id), Color(1, 0.9, 0.5))
		Game.save_character()
	return ok

func turn_in(quest_id: String) -> Dictionary:
	var r = Quests.turn_in(Game.character, quest_id, world)
	if r.ok:
		Sfx.play("quest_done")
		if world and Game.character.active_pet != "" and (world.pet == null or not is_instance_valid(world.pet)):
			world.spawn_pet()
		_refresh()
	return r

# ------------------------------------------------------------------ skills, stars, builds
func choose_modifier(skill_id: String, option_id: String) -> Dictionary:
	var r = SkillMods.choose(Game.character, skill_id, option_id)
	if r.ok:
		_refresh()
	return r

func mastery_progress(skill_id: String) -> Dictionary:
	return SkillMastery.xp_progress(Game.character, skill_id)

func upgrade_mastery(skill_id: String) -> Dictionary:
	var r = SkillMastery.upgrade(Game.character, skill_id)
	if r.ok:
		_refresh()
	return _result(r.ok, r.message)

func allocate_star(node_id: String) -> Dictionary:
	var r = Starmap.allocate(Game.character, node_id)
	if r.ok:
		_refresh()
	return r

func respec_stars() -> Dictionary:
	var n = Starmap.respec(Game.character)
	_refresh()
	return {"ok": true, "message": "%d star points returned" % n, "refunded": n}

func respec_skills() -> Dictionary:
	var r = Builds.respec_skills(Game.character)
	if r.ok:
		_refresh()
		if hud:
			hud.touch.refresh_bar()
	return _result(r.ok, r.message, r)

func save_loadout(slot: int, label := "") -> Dictionary:
	var r = Builds.save_loadout(Game.character, slot, label)
	Game.save_character()
	return _result(r.ok, r.message)

func load_loadout(slot: int) -> Dictionary:
	var r = Builds.load_loadout(Game.character, slot)
	if r.ok:
		_refresh()
		Events.equipment_changed.emit()
		if hud:
			hud.touch.refresh_bar()
	return _result(r.ok, r.message)

# ------------------------------------------------------------------ items & merchants
func upgrade_preview(item: Dictionary) -> Dictionary:
	return Upgrade.preview(Game.character, item)

func upgrade_item(item: Dictionary) -> Dictionary:
	var r = Upgrade.upgrade(Game.character, item)
	if r.ok:
		Sfx.play("upgrade")
		_refresh()
		Events.equipment_changed.emit()
		Events.inventory_changed.emit()
	return r

func vendor_buy(vendor_id: String, entry) -> Dictionary:
	var r = Merchants.buy(Game.character, vendor_id, entry)
	Game.save_character()
	return r

func curio_buy(offer_id: String) -> Dictionary:
	var r = Merchants.curio_buy(Game.character, offer_id)
	if r.ok:
		Sfx.play("drop_" + str(r.item.rarity), -2.0, 0.0)
	if r.ok and Items.rarity_index(r.item.rarity) >= 4:
		Events.golden_moment.emit(r.item)
	Game.save_character()
	return r

func codex_list() -> Array:
	return Codex.list()

# ------------------------------------------------------------------ main quest, deeds, cosmetics
func main_quest_tracker() -> Dictionary:
	MainQuest.ensure_started(Game.character)
	return MainQuest.tracker(Game.character)

func deeds_list(include_hidden := false) -> Array:
	return Deeds.list(Game.character, include_hidden)

func set_title(title: String) -> bool:
	var ok = Deeds.set_title(Game.character, title)
	Game.save_character()
	return ok

func set_cosmetic(slot: String, value) -> bool:
	var ok = Deeds.set_cosmetic(Game.character, slot, value)
	if ok:
		Events.cosmetics_changed.emit()
		_refresh()
	return ok

## Deed flags/secrets ("flag:<id>", "secret:<id>") are set to 1 once.
func set_flag(key: String) -> void:
	var ch = Game.character
	if int(ch.stats_tracking.get(key, 0)) >= 1:
		return
	ch.track(key)
	if key.begins_with("secret:"):
		ch.track("secrets")

func bounty_status() -> Dictionary:
	return Quests.bounty_status(Game.character)

func bounties(act_id := "") -> Array:
	return Quests.bounties_for(Game.character, act_id if act_id != "" else Game.character.current_act)

## The Cauldron: {material_id: count} or [ids]. Nothing is consumed unless a recipe matches.
func cauldron_stir(items) -> Dictionary:
	var r = Crafting.cauldron_stir(Game.character, items)
	Game.save_character()
	return _result(r.ok, r.message, r)
