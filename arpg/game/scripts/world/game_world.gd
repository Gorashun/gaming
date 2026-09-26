class_name GameWorld
extends Node3D
## One loaded zone. Authority for gameplay state changes (damage, kills, drops, pickups) so the same
## API can later run on a server. Presentation layers (Fx, HUD) listen via Events.

var zone: Dictionary = {}
var act: Dictionary = {}
var biome: Dictionary = {}
var layout: ZoneLayout
var builder: ZoneBuilder
var player: Player
var rig: CameraRig
var fx_root: Node3D
var actors_root: Node3D
var drops_root: Node3D
var monsters: Array = []
var minions: Array = []
var drops: Array = []
var _next_net_id = 1
var astar = AStarGrid2D.new()
var env: WorldEnvironment
var sun: DirectionalLight3D
var monster_level = 1
var exit_portal: Node3D
var boss: Monster
var zone_seed = 0
var cleared = false
var kills = 0
var _light_timer = 0.0
var interactables: Array = []   # [{node, pos, radius, action:Callable, label}]
var is_town = false
var stats_session = {"kills": 0, "items": 0, "gold": 0, "xp": 0, "start": 0.0}
var pet: Pet
var npcs: Array = []
var return_portal: Node3D
var world_events: WorldEvents
var zone_deaths = 0              # deaths during this zone visit (Lantern's Blessing)
var blessing_pct = 0.0

const PATH_RES := 2.0

func _init() -> void:
	name = "GameWorld"

func load_zone(zone_id: String, seed_value := -1) -> void:
	zone = Content.get_rec("zones", zone_id)
	if zone.is_empty():
		push_error("Unknown zone " + zone_id)
		return
	act = Content.get_rec("acts", zone.get("act", ""))
	biome = Content.get_rec("biomes", zone.get("biome", "crypt"))
	is_town = zone.get("town", false)
	Game.world = self
	var ch = Game.character
	var tier = Game.tier()
	# Monster level: zone base inside tier band, pulled toward the player's level
	var band: Array = tier.get("level_band", [1, 60])
	var zl = int(zone.get("level", 1)) + int(tier.get("level_offset", 0))
	monster_level = clampi(max(zl, ch.level - 1) if tier.get("scale_to_player", true) else zl, int(band[0]), int(band[1]))
	zone_seed = seed_value if seed_value >= 0 else hash(ch.id + zone_id + str(ch.play_seconds))
	Rng.reseed(zone_seed)
	stats_session.start = Time.get_ticks_msec() / 1000.0
	fx_root = Node3D.new(); fx_root.name = "Fx"; add_child(fx_root)
	actors_root = Node3D.new(); actors_root.name = "Actors"; add_child(actors_root)
	drops_root = Node3D.new(); drops_root.name = "Drops"; add_child(drops_root)
	_setup_environment()
	layout = ZoneLayout.new()
	var size = int(zone.get("size", 26))
	layout.generate(zone_seed, size, int(zone.get("rooms", 9)), int(zone.get("room_min", 3)), int(zone.get("room_max", 6)), int(biome.get("corridor_width", 1)))
	builder = ZoneBuilder.new()
	builder.build(self, layout, biome, zone_seed)
	_setup_astar()
	_spawn_player()
	spawn_pet()
	rig = CameraRig.new()
	add_child(rig)
	rig.target = player
	rig.global_position = player.global_position
	if zone.get("boss", "") != "":
		rig.distance = 16.0
	Fx.camera_rig = rig
	if is_town:
		_setup_town()
	else:
		_populate()
		_place_chests()
		_place_exit()
		_maybe_surprise()
		world_events = WorldEvents.new()
		world_events.name = "WorldEvents"
		add_child(world_events)
		world_events.setup(self)
	Sfx.play_music(zone.get("music", biome.get("music", "")))
	var amb = str(zone.get("ambience", biome.get("ambience", "")))
	if amb != "":
		Sfx.play_ambience(amb)
	else:
		Sfx.stop_ambience()
	Quests.notify(ch, "explore", zone_id)
	ch.track("zones_visited")
	MainQuest.notify(ch, "reach_zone", zone_id)
	_place_story_object()
	Events.zone_entered.emit(zone_id)

# ------------------------------------------------------------------ setup
func _setup_environment() -> void:
	# Owned by art (ART_BIBLE §2/§4): every value comes from the biome "env" block.
	# Depth fog starts just behind the hero plane so actors stay crisp and the room edges fall
	# off into the act colour; optional height fog = ground-hugging bog/mine haze.
	var e: Dictionary = biome.get("env", {})
	env = WorldEnvironment.new()
	var en = Environment.new()
	en.background_mode = Environment.BG_COLOR
	en.background_color = Color(e.get("sky", "#07060b"))
	en.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	en.ambient_light_color = Color(e.get("ambient", "#3a3550"))
	en.ambient_light_energy = float(e.get("ambient_energy", 1.0))
	en.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	en.tonemap_exposure = float(e.get("exposure", 1.0))
	en.tonemap_white = float(e.get("white", 6.0))
	en.fog_enabled = true
	var fog_col = Color(e.get("fog", "#141220"))
	if zone.has("fog_tint"):   # Deepdark modifiers / event zones tint the fog
		fog_col = fog_col.lerp(Color(zone.fog_tint), 0.5)
	en.fog_light_color = fog_col
	en.fog_light_energy = float(e.get("fog_energy", 1.0))
	en.fog_sky_affect = 1.0
	en.fog_mode = Environment.FOG_MODE_DEPTH
	en.fog_depth_begin = float(e.get("fog_begin", 14.0))
	en.fog_depth_end = float(e.get("fog_end", 42.0))
	en.fog_depth_curve = float(e.get("fog_curve", 1.2))
	en.fog_density = float(e.get("fog_density", 0.6))
	en.fog_height = float(e.get("fog_height", -10.0))
	en.fog_height_density = float(e.get("fog_height_density", 0.0))
	en.glow_enabled = float(e.get("glow", 0.6)) > 0.0
	en.glow_intensity = float(e.get("glow", 0.6))
	en.glow_strength = float(e.get("glow_strength", 1.0))
	en.glow_bloom = float(e.get("bloom", 0.02))
	en.glow_hdr_threshold = float(e.get("glow_threshold", 1.0))
	en.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	en.adjustment_enabled = true
	en.adjustment_brightness = float(e.get("brightness", 1.0))
	en.adjustment_saturation = float(e.get("saturation", 1.0))
	en.adjustment_contrast = float(e.get("contrast", 1.1))
	env.environment = en
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.light_color = Color(e.get("sun", "#8f9bd6"))
	sun.light_energy = float(e.get("sun_energy", 0.55))
	sun.rotation_degrees = Vector3(-float(e.get("sun_pitch", 55.0)), float(e.get("sun_yaw", 30.0)), 0)
	sun.shadow_enabled = sun.light_energy > 0.05
	sun.shadow_opacity = float(e.get("shadow_opacity", 0.8))
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 30.0
	sun.light_specular = 0.2
	add_child(sun)

func _setup_astar() -> void:
	astar.region = Rect2i(0, 0, int(layout.w * ZoneLayout.CELL / PATH_RES), int(layout.h * ZoneLayout.CELL / PATH_RES))
	astar.cell_size = Vector2(PATH_RES, PATH_RES)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in astar.region.size.y:
		for x in astar.region.size.x:
			var wp = Vector3((x + 0.5) * PATH_RES, 0, (y + 0.5) * PATH_RES)
			var c = layout.world_to_cell(wp)
			if layout.get_cell(c.x, c.y) == 0 or builder.occupied.has(c) and layout.get_cell(c.x, c.y) == 0:
				astar.set_point_solid(Vector2i(x, y), true)

func _spawn_player() -> void:
	player = Player.new()
	actors_root.add_child(player)
	player.net_id = _nid()
	var start: Vector2i = layout.rooms[layout.start_room].center
	player.global_position = layout.cell_to_world(start)
	player.setup(Game.character)
	player.died.connect(_on_player_died)
	# Welcome light pillar at spawn
	Fx.ring(player.global_position, 3.0, Color(1, 0.8, 0.4), 0.8)

func _nid() -> int:
	_next_net_id += 1
	return _next_net_id

# ------------------------------------------------------------------ population
func _populate() -> void:
	var packs = int(zone.get("packs", 10))
	var fams: Array = zone.get("families", act.get("families", []))
	var pool = []
	for m in Content.all("monsters"):
		if fams.has(m.get("family", "")) and not m.get("boss", false) and not m.get("summon_only", false):
			pool.append(m)
	if pool.is_empty():
		push_warning("No monsters for zone %s" % zone.id)
		return
	var room_ids = range(layout.rooms.size())
	room_ids.erase(layout.start_room)
	var tier = Game.tier()
	var elite_chance = float(zone.get("elite_chance", 0.18)) * float(tier.get("elite_mult", 1.0))
	for i in packs:
		var ri: int = room_ids[Rng.int_on("world", 0, room_ids.size() - 1)]
		if zone.get("boss", "") != "" and ri == layout.end_room:
			continue
		var cells = layout.room_cells(ri)
		var center = layout.cell_to_world(cells[Rng.int_on("world", 0, cells.size() - 1)])
		var lead = Rng.weighted("world", pool, "spawn_weight")
		var size = Rng.int_on("world", int(lead.get("pack_min", 3)), int(lead.get("pack_max", 5)))
		var kind = "normal"
		if Rng.chance("world", elite_chance):
			kind = "rare" if Rng.chance("world", 0.35) else "champion"
		var affixes = []
		if kind != "normal":
			var all_aff = Content.all("monster_affixes")
			for k in (Rng.int_on("world", 2, 3) if kind == "rare" else 1):
				if all_aff.size() > 0:
					affixes.append(all_aff[Rng.int_on("world", 0, all_aff.size() - 1)].id)
		for j in size:
			var rec = lead if j == 0 or Rng.chance("world", 0.6) else pool[Rng.int_on("world", 0, pool.size() - 1)]
			var off = Vector3(Rng.range_on("world", -2.5, 2.5), 0, Rng.range_on("world", -2.5, 2.5))
			var k = kind
			if kind == "rare" and j > 0:
				k = "minion_of_rare"
			var m = spawn_monster(rec.id, clamp_to_walkable(center, center + off), monster_level, "champion" if k == "champion" else ("rare" if j == 0 and kind == "rare" else "normal"))
			if m and kind != "normal" and (kind == "champion" or j == 0):
				m.elite_affixes = affixes.duplicate()
				_apply_elite(m)
	if zone.get("boss", "") != "":
		var bc = layout.cell_to_world(layout.rooms[layout.end_room].center)
		boss = spawn_monster(zone.boss, bc, monster_level + int(Content.get_rec("monsters", zone.boss).get("level_bonus", 2)), "boss")
		if boss:
			Events.boss_spawned.emit(boss)

func spawn_monster(id: String, pos: Vector3, lvl: int, kind := "normal") -> Monster:
	var rec = Content.get_rec("monsters", id)
	if rec.is_empty():
		push_warning("Unknown monster " + id)
		return null
	return spawn_monster_rec(rec, pos, lvl, kind)

## Spawn from a record dictionary (generated monsters such as Echo Duel mirrors).
func spawn_monster_rec(rec: Dictionary, pos: Vector3, lvl: int, kind := "normal") -> Monster:
	var m = Monster.new()
	m.net_id = _nid()
	actors_root.add_child(m)
	m.global_position = pos
	m.face_towards(pos + Vector3(Rng.range_on("world", -1, 1), 0, Rng.range_on("world", -1, 1)))
	m.setup(rec, lvl, kind)
	m.home = pos
	m.died.connect(_on_monster_died)
	monsters.append(m)
	_attach_healthbar(m)
	return m

func _apply_elite(m: Monster) -> void:
	var names = []
	for a in m.elite_affixes:
		var rec = Content.get_rec("monster_affixes", a)
		names.append(rec.get("name", a))
		for k in rec.get("stats", {}):
			m.stats.add_to_source("affix", k, float(rec.stats[k]))
		if rec.has("speed_mult"):
			m.move_speed *= float(rec.speed_mult)
		if rec.has("life_mult"):
			m.max_life *= float(rec.life_mult)
			m.life = m.max_life
		for ab in rec.get("abilities", []):
			var list: Array = m.rec.get("abilities", []).duplicate()
			list.append(ab)
			m.rec = m.rec.duplicate()
			m.rec["abilities"] = list
	var col = Color("#6fb3ff") if m.kind == "champion" else Color("#ffd23f")
	for mat in m._overlay_mats:
		mat.set_shader_parameter("rim_color", col)
		mat.set_shader_parameter("rim_strength", 0.9)
	m.display_name = ("%s %s" % [" ".join(names), m.display_name]).strip_edges()

func _attach_healthbar(m) -> void:
	var hb = preload("res://scripts/fx/healthbar3d.gd").new()
	m.add_child(hb)
	hb.setup(m)
	m.healthbar = hb

func _place_chests() -> void:
	for c in builder.chests:
		var n: Node3D = ZoneBuilder.scene_of(c.model).instantiate() if ZoneBuilder.scene_of(c.model) else Node3D.new()
		add_child(n)
		n.global_position = c.pos
		n.rotation.y = c.rot
		var gold = String(c.model).contains("gold")
		interactables.append({"node": n, "pos": c.pos, "radius": 1.8, "label": "Open", "action": func(): _open_chest(n, gold)})

func _open_chest(n: Node3D, golden: bool) -> void:
	Sfx.play("chest_open")
	Fx.burst(n.global_position + Vector3(0, 0.8, 0), Color(1, 0.85, 0.4), 24, 5.0, 0.1, 0.8)
	Fx.flash_light(n.global_position + Vector3(0, 1, 0), Color(1, 0.8, 0.4), 3.0, 0.5)
	var fake = {"loot_mult": 1.0}
	var res = Loot.roll_kill(fake, monster_level, Game.character, Game.tier(), "chest_gold" if golden else "chest")
	_spawn_loot(res, n.global_position)
	var t = n.create_tween()
	t.tween_property(n, "scale", Vector3(1.2, 0.8, 1.2), 0.08)
	t.tween_property(n, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK)

func _place_exit() -> void:
	var pos = layout.cell_to_world(layout.rooms[layout.end_room].center)
	if zone.get("boss", "") != "":
		pos += Vector3(0, 0, 2.0)
	exit_portal = preload("res://scripts/world/portal.gd").new()
	add_child(exit_portal)
	exit_portal.global_position = pos
	exit_portal.setup(Color(0.55, 0.75, 1.0))
	exit_portal.visible = zone.get("boss", "") == "" and not zone.get("clear_to_exit", false)
	interactables.append({"node": exit_portal, "pos": pos, "radius": 2.0, "label": "Leave", "action": _use_exit, "enabled": func(): return exit_portal.visible})

func _use_exit() -> void:
	Events.zone_cleared.emit(zone.id)
	get_tree().call_group("session", "on_zone_exit", zone.id)

func _maybe_surprise() -> void:
	for ev in Content.all("events"):
		var chance = float(ev.get("chance", 0.0))
		var forced = false
		if ev.has("force_zone") and ev.force_zone == zone.id and not Game.character.discoveries.has("seen:" + ev.id):
			forced = true
		if forced or Rng.chance("world", chance):
			var room: int = Rng.int_on("world", 0, layout.rooms.size() - 1)
			if room == layout.start_room:
				room = layout.end_room
			var pos = layout.cell_to_world(layout.rooms[room].center)
			if ev.get("monster", "") != "":
				var m = spawn_monster(ev.monster, pos, monster_level, ev.get("kind", "normal"))
				if m:
					m.set_meta("event", ev.id)
					if m.rec.get("ai", "") == "flee":
						m.add_sparkle_trail(Color(ev.get("color", "#ffd84a")))
			Game.character.discoveries.append("seen:" + ev.id)
			Events.surprise_event.emit(ev.id)
			Events.toast.emit(ev.get("announce", "Something stirs..."), Color(ev.get("color", "#ffd23f")))
			break

func _setup_town() -> void:
	var center = layout.cell_to_world(layout.rooms[layout.start_room].center)
	_place_return_portal(center)
	var npc_recs = _town_npcs()
	if not npc_recs.is_empty():
		_spawn_npcs(npc_recs, center)
		return
	var stations: Array = zone.get("stations", [])
	for i in stations.size():
		var st: Dictionary = stations[i]
		var ang = TAU * i / max(1, stations.size())
		var pos = center + Vector3(cos(ang), 0, sin(ang)) * 5.0
		pos = clamp_to_walkable(center, pos)
		var n = preload("res://scripts/world/station.gd").new()
		add_child(n)
		n.global_position = pos
		n.setup(st)
		interactables.append({"node": n, "pos": pos, "radius": 2.2, "label": st.get("name", "Use"), "action": func(): get_tree().call_group("session", "open_station", st.get("screen", ""))})

## NPC records for this town: zone.npcs ids, else npcs whose `town` is this zone.
func _town_npcs() -> Array:
	var out = []
	for id in zone.get("npcs", []):
		var r = Content.get_rec("npcs", str(id))
		if not r.is_empty():
			out.append(r)
	if out.is_empty() and not zone.has("npcs"):
		for r in Content.all("npcs"):
			if str(r.get("town", "")) == zone.id:
				out.append(r)
	return out

func _spawn_npcs(recs: Array, center: Vector3) -> void:
	for i in recs.size():
		var r: Dictionary = recs[i]
		var pos: Vector3
		if r.get("pos") is Array and r.pos.size() >= 2:
			pos = clamp_to_walkable(center, center + Vector3(float(r.pos[0]), 0, float(r.pos[1])))
		else:
			var ang = TAU * i / max(1, recs.size()) + 0.4
			var rad = 5.0 + (i % 2) * 2.0
			pos = clamp_to_walkable(center, center + Vector3(cos(ang), 0, sin(ang)) * rad)
		var n = Npc.new()
		actors_root.add_child(n)
		n.global_position = pos
		n.setup_npc(r)
		n.face_towards(center)
		n._base_rot = n.rotation.y
		npcs.append(n)
		interactables.append({"node": n, "pos": pos, "radius": 2.4, "label": "Talk to %s" % r.get("name", ""), "action": func(): interact_npc(n)})

## Talking to an NPC: bark, quest turn-ins + talk progress, innkeeper binding, then its screen.
func interact_npc(n: Npc) -> void:
	var ch = Game.character
	Sfx.play("npc_talk", -4.0)
	Events.npc_talked.emit(n.npc_id)
	Quests.notify(ch, "talk", n.npc_id)
	MainQuest.notify(ch, "talk", n.npc_id)
	var done = Quests.ready_for(ch, n.npc_id)
	for q in done:
		var res = Quests.turn_in(ch, q.id, self)
		if res.ok:
			Sfx.play("quest_done")
			n.bark(res.message)
			Fx.burst(player.global_position + Vector3(0, 1.2, 0), Color(1, 0.85, 0.4), 24, 4.0, 0.12, 0.9, 1.0)
	if done.is_empty():
		n.bark()
	var sess = get_parent()
	if sess and "current_npc" in sess:
		sess.current_npc = n.npc_id
	if n.role() == "innkeeper" and sess and sess.has_method("bind_town"):
		sess.bind_town(zone.id)
	var scr = str(n.rec.get("screen", ""))
	if scr == "" and not Quests.available_for(ch, n.npc_id).is_empty():
		scr = "quests"
	if scr != "" and sess and sess.has_method("open_screen"):
		get_tree().create_timer(0.6).timeout.connect(func():
			if is_instance_valid(sess) and is_instance_valid(self):
				sess.open_screen(scr))

## Main-quest "solve" objectives: a glowing object to interact with somewhere in this zone.
func _place_story_object() -> void:
	var o = MainQuest.solve_object_for_zone(Game.character, zone.id)
	if o.is_empty() or layout.rooms.size() < 2:
		return
	var rooms = range(layout.rooms.size())
	rooms.erase(layout.start_room)
	var pos = layout.cell_to_world(layout.rooms[rooms[Rng.int_on("world", 0, rooms.size() - 1)]].center)
	var n = Node3D.new()
	add_child(n)
	n.global_position = pos
	var mi = MeshInstance3D.new()
	var pm = PrismMesh.new()
	pm.size = Vector3(0.6, 0.9, 0.6)
	mi.mesh = pm
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.7, 0.9, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.6, 0.85, 1.0)
	m.emission_energy_multiplier = 3.0
	mi.material_override = m
	mi.position.y = 1.0
	n.add_child(mi)
	Fx.beam(n, Color(0.6, 0.85, 1.0), 6.0, 0.6)
	var target = str(o.get("target", ""))
	interactables.append({"node": n, "pos": pos, "radius": 2.0, "label": str(o.get("label", "Examine")), "once": true,
		"action": func():
			MainQuest.notify(Game.character, "solve", target)
			Fx.burst(pos + Vector3(0, 1, 0), Color(0.6, 0.85, 1.0), 30, 4.0, 0.12, 0.9, 1.0)
			n.queue_free()})

## "Portal back": after hearthing/travelling to town, a portal leads back to where you left.
func _place_return_portal(center: Vector3) -> void:
	var rp: Dictionary = Game.character.return_portal
	if rp.is_empty() or Content.get_rec("zones", str(rp.get("zone", ""))).is_empty():
		return
	var pos = clamp_to_walkable(center, center + Vector3(-3.0, 0, 3.0))
	return_portal = preload("res://scripts/world/portal.gd").new()
	add_child(return_portal)
	return_portal.global_position = pos
	return_portal.setup(Color(1.0, 0.75, 0.35))
	var zname = Content.get_rec("zones", str(rp.zone)).get("name", "")
	interactables.append({"node": return_portal, "pos": pos, "radius": 2.0, "label": "Return to " + zname,
		"action": func(): get_tree().call_group("session", "portal_back")})

## Companion follower for the active pet (call again after changing pets).
func spawn_pet() -> void:
	if pet and is_instance_valid(pet):
		pet.queue_free()
	pet = null
	var ch = Game.character
	if ch.active_pet == "" or Pets.rec(ch.active_pet).is_empty():
		return
	pet = Pet.new()
	add_child(pet)
	pet.setup(ch.active_pet, player)

## Removes a monster without a kill (escaped Magpie, despawned event actors).
func remove_monster(m: Node) -> void:
	monsters.erase(m)
	minions.erase(m)
	if world_events:
		world_events.on_monster_removed(m)

func spawn_gold(at: Vector3, amount: int) -> void:
	if amount <= 0:
		return
	var d = Drop.new()
	d.net_id = _nid()
	drops_root.add_child(d)
	d.setup_gold(amount)
	d.toss(at, clamp_to_walkable(at, at + Vector3(Rng.range_on("fx", -1.5, 1.5), 0, Rng.range_on("fx", -1.5, 1.5))))
	drops.append(d)

## Magpie Imp: coins burst out on every (throttled) hit.
func spill_coins(m: Monster) -> void:
	var amount = int((2.0 + m.level * 0.8) * Rng.range_on("loot", 0.6, 1.4) * (1.0 + Game.character.stats.total("gold_find") / 100.0))
	spawn_gold(m.global_position, max(1, amount))
	Fx.burst(m.global_position + Vector3(0, 1.0, 0), Color(1, 0.85, 0.3), 10, 4.0, 0.08, 0.5, -8.0)
	Sfx.play("coin_burst", -6.0)

## Pet "dig" perk: a small treasure pops out of the ground next to the pet.
func pet_dig() -> void:
	var at: Vector3 = pet.global_position if pet and is_instance_valid(pet) else player.global_position
	at.y = 0
	at = clamp_to_walkable(player.global_position, at)
	Fx.burst(at + Vector3(0, 0.2, 0), Color(0.5, 0.4, 0.3), 18, 3.5, 0.14, 0.6)
	Fx.float_text(at, "Dug something up!", Color(1, 0.85, 0.4), 30)
	var res = Loot.roll_kill({}, monster_level, Game.character, Game.tier(), "pet_dig",
		{"item_chance": 0.25, "max_items": 1, "gold_chance": 1.0, "gold_mult": 2.0, "materials": [{"id": "soot", "chance": 0.8, "min": 1, "max": 3}, {"id": "wickthread", "chance": 0.25}]})
	_spawn_loot(res, at)

## Lantern's Blessing (research #23): optional assist after repeated deaths in a zone. Never in
## Hardcore; framed positively. config/blessing {base_pct, per_death_pct, cap_pct, min_deaths}.
func _update_blessing() -> void:
	var ch = Game.character
	var c = Content.get_rec("config", "blessing")
	var pct = 0.0
	if not ch.hardcore and Settings.get_value("lanterns_blessing", true) and zone_deaths >= int(c.get("min_deaths", 2)):
		pct = float(c.get("base_pct", 20.0)) + float(c.get("per_death_pct", 2.0)) * (zone_deaths - int(c.get("min_deaths", 2)))
		pct = min(pct, float(c.get("cap_pct", 60.0)))
	if pct != blessing_pct:
		blessing_pct = pct
		Events.blessing_changed.emit(pct)
		if pct > 0.0:
			Events.toast.emit("The Lantern's Blessing shields you (-%d%% damage taken)" % int(pct), Color(1, 0.9, 0.6))

# ------------------------------------------------------------------ authority: combat
func deal_damage(src: Actor, target: Actor, mult: float, element: String, tags: Array, e := {}, is_dot := false) -> void:
	if not is_instance_valid(target) or not target.alive or target.faction == src.faction:
		return
	var src_ctx = {"stats": src.stats, "level": src.level, "primary": "might"}
	if src is Player:
		src_ctx.weapon = src.ch.weapon()
		src_ctx.primary = src.ch.cls().get("primary", "might")
	elif src is Monster and src.kind == "minion" and src.owner_actor is Player:
		src_ctx.stats = src.owner_actor.stats
		src_ctx.weapon = src.owner_actor.ch.weapon()
		src_ctx.primary = src.owner_actor.ch.cls().get("primary", "might")
		mult *= float(src.rec.get("owner_damage_mult", 0.5))
	var hit = Combat.roll_player_hit(src_ctx, mult, element, tags)
	var def = {"stats": target.stats, "level": target.level}
	var amount = Combat.mitigate(hit, def, src.level)
	if target is Monster and target.shield_active():
		amount *= 0.5
		Sfx.play("shield_block", -10.0)
	_apply_damage(target, amount, hit.crit, element, src)
	# On-hit effects
	var owner: Actor = src.owner_actor if (src is Monster and src.owner_actor) else src
	# Skill mastery XP: effects carry "_skill"; minions remember the skill that summoned them
	var sk = str(e.get("_skill", ""))
	if sk == "" and src is Monster and src.has_meta("skill_id"):
		sk = str(src.get_meta("skill_id"))
	if sk != "" and owner is Player:
		SkillMastery.on_hit(owner.ch, sk)
		if not target.alive:
			SkillMastery.on_kill(owner.ch, sk)
	if owner is Player and not is_dot:
		var loh = owner.stats.get_stat("life_on_hit")
		if loh > 0:
			heal_actor(owner, loh)
		var gen = float(owner.ch.cls().get("resource_on_hit", 0.0))
		if gen > 0 and tags.has("basic"):
			owner.gain_resource(gen)
	if e.has("knockback"):
		target.apply_knockback(src.global_position, float(e.knockback))
	if e.has("status"):
		var st: Dictionary = e.status
		if Rng.chance("combat", float(st.get("chance", 1.0))):
			target.add_status(st.id, float(st.get("duration", 1.0)), float(st.get("value", 0.3)))
			if st.id == "freeze" or st.id == "stun":
				target.flash(Color(0.6, 0.85, 1.0), 0.6)
	if hit.crit and not is_dot:
		Fx.sparks(target.global_position, Color(1, 0.9, 0.4))
		Sfx.play("crit", -3.0)
	elif not is_dot:
		Sfx.play("hit", -8.0)

func monster_hit(src: Actor, target: Actor, mult: float, element: String) -> void:
	if not is_instance_valid(target) or not target.alive:
		return
	if target is Player:
		var hit = Combat.monster_hit(src.level, float(src.rec.get("dmg_mult", 1.0)) * mult * (1.35 if src is Monster and src.kind == "rare" else 1.0), Game.tier())
		hit.element = element
		var def = {"stats": target.stats, "level": target.level, "resist_penalty": float(Game.tier().get("resist_penalty", 0.0))}
		var amount = Combat.mitigate(hit, def, src.level)
		# Block (Lanternbearer & shields)
		if Rng.chance("combat", clampf(target.stats.get_stat("block") / 100.0, 0.0, 0.6)):
			amount *= 0.3
			Fx.float_text(target.global_position, "Block", Color(0.8, 0.9, 1.0), 32)
			target.gain_resource(float(target.ch.cls().get("resource_on_block", 0.0)))
		target.gain_resource(float(target.ch.cls().get("resource_on_hurt", 0.0)))
		var thorns = target.stats.get_stat("thorns")
		if thorns > 0 and src.alive:
			_apply_damage(src, thorns, false, "physical", target)
		if blessing_pct > 0.0:
			amount *= 1.0 - blessing_pct / 100.0
		_apply_damage(target, amount, false, element, src)
	else:
		# monster hits a minion
		var hit = Combat.monster_hit(src.level, float(src.rec.get("dmg_mult", 1.0)) * mult, Game.tier())
		_apply_damage(target, hit.amount * 0.7, false, element, src)

func _apply_damage(target: Actor, amount: float, crit: bool, element: String, src: Node) -> void:
	if amount <= 0.0:
		Fx.float_text(target.global_position, "Dodge", Color(0.8, 0.8, 0.8), 30)
		return
	target.on_damaged(amount, crit, src)
	Fx.damage_number(target.global_position, amount, crit, _elem_color(element), target is Player)
	Events.actor_damaged.emit(target, amount, crit, element)

func _elem_color(e: String) -> Color:
	match e:
		"fire": return Color(1.0, 0.55, 0.25)
		"cold": return Color(0.55, 0.85, 1.0)
		"lightning": return Color(0.95, 0.95, 0.5)
		"shadow": return Color(0.75, 0.55, 1.0)
		"holy": return Color(1.0, 0.95, 0.7)
	return Color.WHITE

func heal_actor(a: Actor, amount: float) -> void:
	if not is_instance_valid(a) or not a.alive:
		return
	a.heal(amount)
	if a is Player:
		Events.health_changed.emit(a.life, a.max_life)

func kill_actor(a: Actor, killer: Node) -> void:
	if a.alive:
		a.alive = false
		a._die(killer)

# ------------------------------------------------------------------ deaths, xp, loot
func _on_monster_died(a: Actor) -> void:
	var m = a as Monster
	monsters.erase(a)
	minions.erase(a)
	if m == null:
		return
	if m.kind == "minion":
		Fx.soul_puff(m.global_position, Color(1.0, 0.8, 0.6))
		get_tree().create_timer(0.6).timeout.connect(m.queue_free)
		return
	kills += 1
	stats_session.kills += 1
	var ch = Game.character
	ch.track("kills")
	var tier = Game.tier()
	var xp_mult = {"normal": 1.0, "champion": 3.0, "rare": 5.0, "boss": 40.0}.get(m.kind, 1.0) * float(tier.get("xp_mult", 1.0))
	var xp = Progression.monster_xp(float(m.rec.get("xp", 10.0)), m.level, ch.level, xp_mult)
	grant_xp(xp)
	var loot_kind: String = {"normal": "normal", "champion": "champion", "rare": "rare", "boss": "boss"}.get(m.kind, "normal")
	if m.has_meta("event"):
		loot_kind = Content.get_rec("events", m.get_meta("event")).get("loot_kind", "rare")
	var res = Loot.roll_kill(m.rec, m.level, ch, tier, loot_kind)
	# Weapon proficiency, pet XP/perks, pet drops, quests
	Weapons.gain_proficiency(ch, Weapons.main_type(ch), int(Weapons.prof_cfg().get("xp_per_kill", 1)) * {"champion": 2, "rare": 3, "boss": 10}.get(m.kind, 1))
	var pet_res = Pets.on_kill(ch, m.kind)
	if pet_res.dig:
		pet_dig()
	var new_pet = Pets.roll_drop(ch, m.kind)
	if new_pet != "" and Pets.grant_pet(ch, new_pet):
		Fx.burst(m.global_position + Vector3(0, 1, 0), Color(Pets.rec(new_pet).get("tint", "#ffd98a")), 30, 4.0, 0.12, 1.0, 1.0)
		Sfx.play("pet_happy")
		Events.toast.emit("A companion found you: %s!" % Pets.rec(new_pet).get("name", new_pet), Color(1, 0.8, 0.95))
		if ch.active_pet == new_pet:
			spawn_pet()
	var fam = str(m.rec.get("family", ""))
	Quests.notify(ch, "kill", str(m.rec.get("id", "")), 1, {"family": fam, "kind": m.kind})
	MainQuest.notify(ch, "kill", str(m.rec.get("id", "")), 1, {"family": fam})
	if fam != "":
		ch.track("kills:family:" + fam)
	ch.track("kills:monster:" + str(m.rec.get("id", "")))
	if m.kind in ["champion", "rare"]:
		ch.track("elites")
	if m.kind == "boss" or m.rec.get("boss", false):
		Quests.notify(ch, "boss", str(m.rec.get("id", "")), 1)
		MainQuest.notify(ch, "boss", str(m.rec.get("id", "")), 1)
	if world_events:
		world_events.on_monster_died(m)
	# Scripted first-session hook: first elite drops a guaranteed Rare
	if m.kind in ["champion", "rare"] and not ch.discoveries.has("hook:first_elite"):
		ch.discoveries.append("hook:first_elite")
		res.items.append(Items.generate(m.level, "rare", ch.class_id))
	_spawn_loot(res, m.global_position)
	var soul_col = Color(m.rec.get("soul_color", "#bfe3ff"))
	Fx.soul_puff(m.global_position, soul_col)
	Sfx.play("monster_die", -4.0)
	if m.kind == "boss":
		Fx.slowmo(0.8, 0.25)
		Fx.shake(0.8)
		Events.boss_defeated.emit(m)
		ch.track("bosses")
		_mark_boss_progress()
		exit_portal.visible = true
		Events.toast.emit("%s is rekindled!" % m.display_name, Color(1, 0.85, 0.4))
	Events.actor_died.emit(m, player)
	get_tree().create_timer(1.4).timeout.connect(func():
		if is_instance_valid(m):
			var t = m.create_tween()
			t.tween_property(m, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
			t.tween_callback(m.queue_free))
	if monsters.filter(func(x): return x.kind != "minion").is_empty() and not cleared:
		cleared = true
		exit_portal.visible = true
		Events.toast.emit("Area cleansed", Color(0.7, 0.9, 1.0))

func _mark_boss_progress() -> void:
	var ch = Game.character
	if not ch.progress.has(ch.difficulty):
		ch.progress[ch.difficulty] = {}
	var p: Dictionary = ch.progress[ch.difficulty]
	if not p.has(zone.act):
		p[zone.act] = {"zones": [], "boss": false}
	p[zone.act].boss = true

func grant_xp(xp: int) -> void:
	var ch = Game.character
	var before = ch.level
	var gained = ch.add_xp(xp)
	stats_session.xp += xp
	Events.xp_gained.emit(xp)
	if gained > 0:
		player.sync_from_character()
		player.life = player.max_life
		player.resource = ch.max_resource()
		Fx.ring(player.global_position, 4.0, Color(1, 0.85, 0.4), 0.8)
		Fx.burst(player.global_position + Vector3(0, 1, 0), Color(1, 0.85, 0.4), 40, 6.0, 0.12, 1.2, 1.0)
		Fx.flash_light(player.global_position + Vector3(0, 2, 0), Color(1, 0.85, 0.5), 5.0, 1.0, 10.0)
		Sfx.play("level_up")
		Events.level_up.emit(ch.level)
		if Settings.get_value("simple_mode", false):
			get_tree().call_group("session", "auto_spend_points")

func _spawn_loot(res: Dictionary, at: Vector3) -> void:
	var ch = Game.character
	var n = 0
	for it in res.items:
		# Loot filter (never hides Legendary+)
		var rank = Items.rarity_index(it.rarity)
		var filt = int(Settings.get_value("loot_filter", 0))
		if rank < filt and rank < 4:
			continue
		spawn_drop_item(it, at, n)
		n += 1
		if rank >= 4:
			Events.golden_moment.emit(it)
			Sfx.play("drop_" + it.rarity, 0.0, 0.0)
			ch.track("found_" + it.rarity)
		elif rank >= 2:
			Sfx.play("drop_" + it.rarity, -3.0, 0.0)
	if res.gold > 0:
		var d = Drop.new()
		d.net_id = _nid()
		drops_root.add_child(d)
		d.setup_gold(res.gold)
		d.toss(at, clamp_to_walkable(at, at + _scatter(n)))
		drops.append(d)
		n += 1
	for mid in res.materials:
		var d = Drop.new()
		d.net_id = _nid()
		drops_root.add_child(d)
		d.setup_material(mid, int(res.materials[mid]))
		d.toss(at, clamp_to_walkable(at, at + _scatter(n)))
		drops.append(d)
		n += 1

func _scatter(i: int) -> Vector3:
	var a = i * 2.4 + Rng.range_on("fx", 0, 1.0)
	var r = 1.0 + 0.35 * i
	return Vector3(cos(a) * r, 0, sin(a) * r)

func spawn_drop_item(it: Dictionary, at: Vector3, index := 0) -> Drop:
	var d = Drop.new()
	d.net_id = _nid()
	drops_root.add_child(d)
	d.setup_item(it)
	d.toss(at, clamp_to_walkable(at, at + _scatter(index)))
	drops.append(d)
	Events.item_dropped.emit(d, it)
	return d

func pickup(d: Drop) -> bool:
	var ch = Game.character
	if d.gold > 0:
		ch.gold += d.gold
		stats_session.gold += d.gold
		ch.track("gold_earned", d.gold)
		Events.gold_changed.emit(ch.gold)
		Fx.float_text(d.global_position, "+%d gold" % d.gold, Color(1, 0.85, 0.3), 30)
		Sfx.play("gold", -6.0)
	elif d.material_id != "":
		ch.add_material(d.material_id, d.material_count)
		Quests.notify(ch, "collect", d.material_id, d.material_count)
		MainQuest.notify(ch, "collect", d.material_id, d.material_count)
		var m = Content.get_rec("materials", d.material_id)
		Fx.float_text(d.global_position, "+%d %s" % [d.material_count, m.get("name", d.material_id)], Color(m.get("color", "#9be7ff")), 28)
		Sfx.play("pickup", -6.0)
	else:
		var it = d.item
		var auto_below = int(Settings.get_value("auto_salvage_below", -1))
		if Items.rarity_index(it.rarity) <= auto_below:
			get_tree().call_group("session", "salvage_item", it)
		elif not ch.add_item(it):
			if Items.rarity_index(it.rarity) >= 4:
				ch.stash.append(it)
				Events.toast.emit("Bag full — sent to your mailbox", Color(1, 0.7, 0.3))
			else:
				Events.toast.emit("Bag full!", Color(1, 0.4, 0.3))
				return false
		stats_session.items += 1
		if Items.rarity_index(it.rarity) >= 4 or it.has("unique") or it.has("named"):
			Codex.record(it)
			ch.track("uniques_found" if it.has("unique") else "legendaries_found")
		Quests.notify(ch, "collect", str(it.get("base", "")), 1)
		Events.item_picked_up.emit(it)
		Events.inventory_changed.emit()
		Sfx.play("pickup", -4.0)
	drops.erase(d)
	d.queue_free()
	return true

func _on_player_died(_a: Actor) -> void:
	var ch = Game.character
	ch.track("deaths")
	zone_deaths += 1
	_update_blessing()
	get_tree().call_group("session", "on_player_died")

# ------------------------------------------------------------------ spawning helpers used by skills
func spawn_projectile(caster: Actor, dir: Vector3, e: Dictionary, mult: float, element: String, tags: Array, col: Color) -> void:
	var p = Projectile.new()
	fx_root.add_child(p)
	p.global_position = caster.global_position + Vector3(0, 0.95, 0) + dir * 0.6
	p.setup(caster, dir, e, mult, element, tags, col)

func spawn_ground_zone(caster: Actor, pos: Vector3, e: Dictionary, mult: float, element: String, tags: Array, col: Color) -> void:
	var z = GroundZone.new()
	fx_root.add_child(z)
	z.global_position = Vector3(pos.x, 0, pos.z)
	z.setup(caster, e, mult, element, tags, col)

func spawn_minion(owner: Actor, minion_id: String, e: Dictionary, rank: int) -> void:
	var limit = int(e.get("max", 4)) + int(owner.stats.get_stat("summon_count"))
	var mine = minions.filter(func(x): return is_instance_valid(x) and x is Monster and x.alive and x.rec.get("id", "") == minion_id)
	if mine.size() >= limit:
		kill_actor(mine[0], null)
	var pos = clamp_to_walkable(owner.global_position, owner.global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)))
	var rec = Content.get_rec("monsters", minion_id)
	if rec.is_empty():
		return
	var m = Monster.new()
	m.net_id = _nid()
	actors_root.add_child(m)
	m.global_position = pos
	m.setup(rec, owner.level, "minion")
	m.owner_actor = owner
	if str(e.get("_skill", "")) != "":
		m.set_meta("skill_id", str(e._skill))
	m.max_life = owner.max_life * float(rec.get("owner_life_mult", 0.35)) * (1.0 + 0.1 * (rank - 1))
	m.life = m.max_life
	m.collision_layer = 8
	m.collision_mask = 1
	if e.has("duration"):
		m.expire_at = Time.get_ticks_msec() / 1000.0 + float(e.duration)
	m.died.connect(_on_monster_died)
	minions.append(m)
	Fx.soul_puff(pos, Color(1.0, 0.85, 0.6))

func draw_bolt(a: Vector3, b: Vector3, col: Color) -> void:
	var im = ImmediateMesh.new()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col.lightened(0.3)
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 4.0
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)
	var segs = 7
	for i in segs + 1:
		var p = a.lerp(b, float(i) / segs)
		if i > 0 and i < segs:
			p += Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
		im.surface_add_vertex(p)
	im.surface_end()
	fx_root.add_child(mi)
	Fx.flash_light(b, col, 2.0, 0.2)
	get_tree().create_timer(0.12).timeout.connect(mi.queue_free)

# ------------------------------------------------------------------ queries
func _hostiles_for(a: Actor) -> Array:
	if a.faction == "player":
		return monsters
	var out: Array = minions.duplicate()
	if player and player.alive:
		out.append(player)
	return out

func hostiles_in_radius_of(faction_target: String, pos: Vector3, r: float, exclude: Array) -> Array:
	var list: Array = monsters if faction_target == "monster" else (minions + ([player] if player and player.alive else []))
	var out = []
	for m in list:
		if is_instance_valid(m) and m.alive and not exclude.has(m):
			var d = Vector2(m.global_position.x - pos.x, m.global_position.z - pos.z).length()
			if d <= r + m.radius:
				out.append(m)
	return out

func nearest_hostile_of(faction_target: String, pos: Vector3, r: float, exclude: Array):
	var best = null
	var bd = r
	for m in hostiles_in_radius_of(faction_target, pos, r, exclude):
		var d: float = m.global_position.distance_to(pos)
		if d < bd:
			bd = d
			best = m
	return best

func enemies_in_radius(a: Actor, pos: Vector3, r: float) -> Array:
	return hostiles_in_radius_of("monster" if a.faction == "player" else "player", pos, r, [])

func enemies_in_arc(a: Actor, origin: Vector3, fwd: Vector3, r: float, angle: float) -> Array:
	var out = []
	for m in enemies_in_radius(a, origin, r):
		var to: Vector3 = m.global_position - origin
		to.y = 0
		if to.length() < 0.8 or fwd.angle_to(to.normalized()) <= deg_to_rad(angle * 0.5):
			out.append(m)
	return out

func enemies_in_capsule(a: Actor, p0: Vector3, p1: Vector3, width: float) -> Array:
	var out = []
	for m in enemies_in_radius(a, (p0 + p1) * 0.5, p0.distance_to(p1) * 0.5 + width):
		var cp = Geometry3D.get_closest_point_to_segment(m.global_position, p0, p1)
		if cp.distance_to(m.global_position) <= width + m.radius:
			out.append(m)
	return out

func nearest_enemy(a: Actor, pos: Vector3, r: float, exclude: Array):
	return nearest_hostile_of("monster" if a.faction == "player" else "player", pos, r, exclude)

func monsters_near(pos: Vector3, r: float) -> Array:
	return hostiles_in_radius_of("monster", pos, r, [])

func alert_pack(m: Monster, t: Actor) -> void:
	for o in monsters_near(m.global_position, 7.0):
		if o.target == null:
			o.target = t

func separation(m: Actor) -> Vector3:
	var s = Vector3.ZERO
	for o in monsters_near(m.global_position, 1.2):
		if o != m:
			var d: Vector3 = m.global_position - o.global_position
			d.y = 0
			if d.length() > 0.01:
				s += d.normalized() / max(0.3, d.length())
	return s

func is_walkable(p: Vector3) -> bool:
	var c = layout.world_to_cell(p)
	return layout.get_cell(c.x, c.y) == 1

func has_line(a: Vector3, b: Vector3) -> bool:
	var steps = int(a.distance_to(b) / 1.0) + 1
	for i in steps + 1:
		if not is_walkable(a.lerp(b, float(i) / steps)):
			return false
	return true

func clamp_to_walkable(from: Vector3, to: Vector3) -> Vector3:
	var steps = int(from.distance_to(to) / 0.5) + 1
	var last = from
	for i in range(1, steps + 1):
		var p = from.lerp(to, float(i) / steps)
		if not is_walkable(p) or not is_walkable(p + Vector3(0.6, 0, 0.6)) or not is_walkable(p - Vector3(0.6, 0, 0.6)):
			return last
		last = p
	return Vector3(last.x, 0, last.z)

func find_path(a: Vector3, b: Vector3) -> PackedVector3Array:
	var ia = Vector2i(int(a.x / PATH_RES), int(a.z / PATH_RES))
	var ib = Vector2i(int(b.x / PATH_RES), int(b.z / PATH_RES))
	if not astar.is_in_boundsv(ia) or not astar.is_in_boundsv(ib) or astar.is_point_solid(ia) or astar.is_point_solid(ib):
		return PackedVector3Array()
	var pts = astar.get_id_path(ia, ib)
	var out = PackedVector3Array()
	for p in pts:
		out.append(Vector3((p.x + 0.5) * PATH_RES, 0, (p.y + 0.5) * PATH_RES))
	return out

# ------------------------------------------------------------------ per-frame
func _process(delta: float) -> void:
	if player == null:
		return
	_light_timer -= delta
	if _light_timer <= 0.0:
		_light_timer = 0.5
		_update_lights()
	# Auto-pickup magnet for gold/materials and (simple mode or always for items within 1.3 m)
	var pickup_bonus = clampf(player.stats.get_stat("pickup_radius"), 0.0, 8.0)
	for d in drops.duplicate():
		if not is_instance_valid(d):
			drops.erase(d)
			continue
		var dist = d.global_position.distance_to(player.global_position)
		var auto_items: bool = Settings.get_value("auto_pickup", true)
		if (d.magnet and dist < 4.0 + pickup_bonus) or (not d.magnet and auto_items and dist < 2.0 + pickup_bonus * 0.5):
			d.global_position = d.global_position.lerp(player.global_position + Vector3(0, 0.6, 0), clampf(delta * 10.0, 0.0, 1.0))
			if dist < 0.9:
				pickup(d)

func _update_lights() -> void:
	var ls: Array = builder.lights.duplicate()
	var pp = player.global_position
	ls.sort_custom(func(a, b): return a.position.distance_squared_to(pp) < b.position.distance_squared_to(pp))
	for i in ls.size():
		ls[i].visible = i < 3 and ls[i].position.distance_to(pp) < 24.0

func nearest_interactable():
	var best = null
	var bd = 999.0
	for it in interactables:
		if it.has("enabled") and not it.enabled.call():
			continue
		if not is_instance_valid(it.node):
			continue
		var d: float = it.pos.distance_to(player.global_position)
		if d < float(it.radius) and d < bd:
			bd = d
			best = it
	return best

func nearest_drop():
	var best = null
	var bd = 2.5
	for d in drops:
		if is_instance_valid(d) and not d.magnet:
			var dist: float = d.global_position.distance_to(player.global_position)
			if dist < bd:
				bd = dist
				best = d
	return best
