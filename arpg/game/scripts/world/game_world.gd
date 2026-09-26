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
var _legendary_slowmo_done = false
## Telegraphed danger areas (for AI/bots/accessibility): [{kind, pos, pos2, radius, until, src}]
## kind: "circle" | "line" (capsule pos→pos2) | "melee" (a normal swing's reach).
var active_hazards: Array = []
var suppress_npc_screens = false
var game_time = 0.0               # pausable, time-scaled clock (hazards use it, not the wall clock)   # tests/bots: talk without opening screens

const PATH_RES := 2.0

func _init() -> void:
	name = "GameWorld"

## Delayed call tied to this zone: dropped if the world is freed first (travel), so pending
## callbacks never run against a freed world ("Lambda capture was freed").
func after(delay: float, cb: Callable) -> void:
	var tm = Timer.new()
	tm.one_shot = true
	tm.wait_time = max(0.001, delay)
	add_child(tm)
	tm.timeout.connect(func():
		tm.queue_free()
		if cb.is_valid():
			cb.call())
	tm.start()

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
	ch.track("zone_entered:" + zone_id)
	Deeds.check_all(ch)
	MainQuest.notify(ch, "reach_zone", zone_id)
	_place_story_object()
	_place_secrets()
	Events.zone_entered.emit(zone_id)

# ------------------------------------------------------------------ setup
func _setup_environment() -> void:
	# Owned by art (ART_BIBLE §2/§4): every value comes from the biome "env" block.
	# Depth fog starts just behind the hero plane so actors stay crisp and the room edges fall
	# off into the act colour; optional height fog = ground-hugging bog/mine haze.
	# Per-zone biome variant (e.g. each hub gets its own dressing while zones.json keeps "town").
	var variant = str(biome.get("variants", {}).get(str(zone.get("id", "")), ""))
	if variant != "" and Content.has_rec("biomes", variant):
		biome = Content.get_rec("biomes", variant)
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
	en.glow_intensity = float(e.get("glow", 0.6)) * 0.7
	en.glow_strength = float(e.get("glow_strength", 1.0))
	en.glow_bloom = float(e.get("bloom", 0.02))
	en.glow_hdr_threshold = float(e.get("glow_threshold", 1.35))
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
	if zone.get("boss", "") != "" and room_ids.size() > 1:
		room_ids.erase(layout.end_room)
	if room_ids.is_empty():
		packs = 0   # tiny layouts (boss arenas): only the boss
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
			affixes = roll_elite_affixes(Rng.int_on("world", 2, 3) if kind == "rare" else 1, monster_level)
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

## Elite affixes for a pack: drawn WITHOUT replacement, honouring monster_affixes[].min_level
## (and optional weight).
func roll_elite_affixes(n: int, lvl: int) -> Array:
	var pool = Content.all("monster_affixes").filter(func(a): return int(a.get("min_level", 1)) <= lvl)
	var out = []
	for i in n:
		if pool.is_empty():
			break
		var pick = Rng.weighted("world", pool)
		if pick == null:
			break
		out.append(pick.id)
		pool.erase(pick)
	return out

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
		# Welfare (research #26): contents are rolled now, and the chest glows its TRUE top rarity
		# from the first frame — no reveal that could read as a near-miss.
		var res = Loot.roll_kill({"loot_mult": 1.0}, monster_level, Game.character, Game.tier(), "chest_gold" if gold else "chest", {}, false)
		var top = Loot.top_rarity(res)
		var rank = Items.rarity_index(top) if top != "" else -1
		if rank >= 1:
			var beam = Fx.beam(n, Items.rarity_color(top), 1.5 + rank * 0.9, 0.25 + rank * 0.06)
			if beam:
				beam.set_meta("chest_glow", true)
		n.set_meta("loot", res)
		interactables.append({"node": n, "pos": c.pos, "radius": 1.8, "label": "Open", "once": true, "action": func(): _open_chest(n, gold)})

func _open_chest(n: Node3D, golden: bool) -> void:
	if not is_instance_valid(n) or not n.has_meta("loot"):
		return
	var res: Dictionary = n.get_meta("loot")
	n.remove_meta("loot")
	var top = Loot.top_rarity(res)
	var col = Items.rarity_color(top) if top != "" else Color(1, 0.85, 0.4)
	Sfx.play("chest_open")
	UiTheme.haptic(25, 0.6)
	Fx.burst(n.global_position + Vector3(0, 0.8, 0), col, 24, 5.0, 0.1, 0.8)
	Fx.flash_light(n.global_position + Vector3(0, 1, 0), col, 3.0, 0.5)
	Loot.book_pity(Game.character, res.items)
	_spawn_loot(res, n.global_position)
	for b in n.get_children():
		if b.has_meta("chest_glow"):
			b.queue_free()
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
	Game.character.track("zones_cleared")
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
				# events[].count spawns a pack; alt_monster is an alternative leader
				for i in max(1, int(ev.get("count", 1))):
					var mid = str(ev.monster)
					if ev.has("alt_monster") and Rng.chance("world", 0.5):
						mid = str(ev.alt_monster)
					var off = Vector3(Rng.range_on("world", -2.0, 2.0), 0, Rng.range_on("world", -2.0, 2.0)) if i > 0 else Vector3.ZERO
					var m = spawn_monster(mid, clamp_to_walkable(pos, pos + off), monster_level, ev.get("kind", "normal"))
					if m:
						m.set_meta("event", ev.id)
						if m.rec.get("ai", "") == "flee":
							m.add_sparkle_trail(Color(ev.get("color", "#ffd84a")))
			elif str(ev.get("portal", "")) != "":
				spawn_zone_portal(str(ev.portal), pos, Color(ev.get("color", "#ffd23f")))
			Game.character.discoveries.append("seen:" + ev.id)
			Events.surprise_event.emit(ev.id)
			Events.toast.emit(ev.get("announce", "Something stirs..."), Color(ev.get("color", "#ffd23f")))
			break

## A portal to a special zone (Magpie's Hoard, Candy Crypt…). Uses a fresh seed each time.
func spawn_zone_portal(zone_id: String, pos: Vector3, col: Color) -> void:
	if Content.get_rec("zones", zone_id).is_empty():
		return
	var p = preload("res://scripts/world/portal.gd").new()
	add_child(p)
	p.global_position = clamp_to_walkable(pos, pos)
	p.setup(col)
	Fx.ring(p.global_position, 3.0, col, 0.8)
	Sfx.play("portal")
	var zname = Content.get_rec("zones", zone_id).get("name", zone_id)
	interactables.append({"node": p, "pos": p.global_position, "radius": 2.0, "label": "Enter " + zname, "once": true,
		"action": func():
			_remember_for_portal()
			get_tree().call_group("session", "travel", zone_id)})

func _remember_for_portal() -> void:
	var sess = get_parent()
	if sess and sess.has_method("_remember_return_point"):
		sess._remember_return_point()

func _setup_town() -> void:
	var center = layout.cell_to_world(layout.rooms[layout.start_room].center)
	_place_return_portal(center)
	_place_onward_portal(center)
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
	# Art: hubs from ZoneBuilder's town generator provide stand points ringing the plaza, >= 4 m
	# apart and clear of props; NPCs face the plaza centre, not the spawn point.
	var slots: Array = builder.town_slots if builder else []
	var plaza = center
	if not slots.is_empty():
		plaza = Vector3.ZERO
		for sp in slots:
			plaza += sp
		plaza /= slots.size()
	for i in recs.size():
		var r: Dictionary = recs[i]
		var pos: Vector3
		if r.get("pos") is Array and r.pos.size() >= 2:
			pos = clamp_to_walkable(center, center + Vector3(float(r.pos[0]), 0, float(r.pos[1])))
		elif not slots.is_empty():
			pos = slots[i % slots.size()]
			if i >= slots.size():
				pos = plaza + (pos - plaza) * 1.35
			pos = clamp_to_walkable(plaza, pos)
		else:
			var ang = TAU * i / max(1, recs.size()) + 0.4
			var rad = 5.0 + (i % 2) * 2.0
			pos = clamp_to_walkable(center, center + Vector3(cos(ang), 0, sin(ang)) * rad)
		var n = Npc.new()
		actors_root.add_child(n)
		n.global_position = pos
		n.setup_npc(r)
		n.face_towards(plaza)
		n._base_rot = n.rotation.y
		npcs.append(n)
		interactables.append({"node": n, "pos": pos, "radius": 2.4, "label": "Talk to %s" % r.get("name", ""), "action": func(): interact_npc(n)})

## Talking to an NPC: bark, quest turn-ins + talk progress, innkeeper binding, then its screen.
func interact_npc(n: Npc) -> void:
	var ch = Game.character
	Sfx.play("npc_talk", -4.0)
	Events.npc_talked.emit(n.npc_id)
	_secret_on_npc_talk(n.npc_id)
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
	if scr != "" and sess and sess.has_method("open_screen") and not suppress_npc_screens:
		after(0.6, func():
			if is_instance_valid(sess) and is_instance_valid(self):
				sess.open_screen(scr))

# ------------------------------------------------------------------ zone secrets
## zones[].secrets[{id, kind, hint, lore, reward{material|pet|mount|lore|portal|gold|item_rarity|title}}].
## Interact-style kinds become a faint sparkle to find. Condition kinds:
##   stand_still (30 s without moving), ride (reach the sparkle mounted), moon_night (sparkle only during
##   the in-game full moon), story_complete (sparkle only after finishing the story), silence (sparkle
##   in the last room; works only if you haven't attacked in this zone), riddles (the answer is to say
##   nothing: stand still beside it 5 s), no_hit_phase (the boss uses N abilities while you're unhit),
##   rekindle (defeat the act boss without having fallen in this act), talk_chain (talk to every NPC
##   in the town). Not spawned: rain_walk (no weather system), maze, third_mirror (need layouts).
## Portal secrets stay available after discovery; others are found once (flag secret:<id>).
const SECRET_SKIP := ["rain_walk", "maze", "third_mirror"]
var _no_hit_secret = {}
var _no_hit_count = 0
var _rekindle_secret = {}
var _talk_secret = {}
var _riddle = {}
var _casts_in_zone = 0
var _still_t = 0.0
var _still_secret = {}

func _place_secrets() -> void:
	var ch = Game.character
	var rooms = range(layout.rooms.size())
	if rooms.size() > 1:
		rooms.erase(layout.start_room)
	for sc in zone.get("secrets", []):
		var sid = str(sc.get("id", ""))
		var found = int(ch.stats_tracking.get("secret:" + sid, 0)) > 0
		var portal = str(sc.get("reward", {}).get("portal", ""))
		if SECRET_SKIP.has(str(sc.get("kind", ""))) or (found and portal == ""):
			continue
		var kind = str(sc.get("kind", ""))
		match kind:
			"stand_still":
				_still_secret = sc
				continue
			"no_hit_phase":
				_no_hit_secret = sc
				continue
			"rekindle":
				_rekindle_secret = sc
				continue
			"talk_chain":
				_talk_secret = sc
				continue
			"moon_night":
				if not Moon.is_full(ch):
					continue
			"story_complete":
				if not ch.discoveries.any(func(d): return str(d).begins_with("story_complete:")):
					continue
		var ri: int = rooms[Rng.int_on("world", 0, rooms.size() - 1)]
		if kind == "silence":
			ri = layout.end_room
		var cells = layout.room_cells(ri)
		var pos = layout.cell_to_world(cells[Rng.int_on("world", 0, cells.size() - 1)])
		var n = Node3D.new()
		add_child(n)
		n.global_position = pos
		var p = CPUParticles3D.new()
		p.amount = 6
		p.lifetime = 1.6
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.4
		p.gravity = Vector3(0, 0.4, 0)
		p.scale_amount_min = 0.03
		p.scale_amount_max = 0.06
		var sm = SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 4
		sm.rings = 2
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.85, 0.95, 1.0)
		sm.material = m
		p.mesh = sm
		p.position.y = 0.6
		n.add_child(p)
		var entry = {"node": n, "pos": pos, "radius": 1.6, "label": "Look closer", "once": portal == ""}
		entry.action = func():
			if str(sc.get("kind", "")) == "ride" and not player.mounted:
				Events.toast.emit(str(sc.get("hint", "Something here wants a rider...")), Color(0.8, 0.9, 1.0))
				return
			if str(sc.get("kind", "")) == "silence" and _casts_in_zone > 0:
				Events.toast.emit(str(sc.get("hint", "It only answers the quiet...")), Color(0.8, 0.9, 1.0))
				return
			if str(sc.get("kind", "")) == "riddles":
				Events.story_dialogue.emit([{"speaker": "?", "text": str(sc.get("hint", "What can you hold without touching, and keep by giving nothing?"))}])
				_riddle = {"sc": sc, "pos": pos, "t": 0.0}
				return
			found_secret(sc, pos)
		interactables.append(entry)

func found_secret(sc: Dictionary, at: Vector3) -> void:
	var ch = Game.character
	var sid = str(sc.get("id", ""))
	var first = int(ch.stats_tracking.get("secret:" + sid, 0)) == 0
	var r: Dictionary = sc.get("reward", {})
	if str(r.get("portal", "")) != "":
		spawn_zone_portal(str(r.portal), at, Color("#ff9ed8"))
	if first:
		get_tree().call_group("session", "set_flag", "secret:" + sid)
		if int(ch.stats_tracking.get("secret:" + sid, 0)) == 0:   # no session (tests)
			ch.track("secret:" + sid)
			ch.track("secrets")
		if r.has("material"):
			ch.add_material(str(r.material), int(r.get("count", 1)))
		if r.has("gold"):
			ch.gold += int(r.gold)
			Events.gold_changed.emit(ch.gold)
		if r.has("item_rarity"):
			_spawn_loot({"items": [Items.generate(monster_level, str(r.item_rarity), ch.class_id)], "gold": 0, "materials": {}}, at)
		if str(r.get("pet", "")) != "" and Pets.grant_pet(ch, str(r.pet)):
			spawn_pet()
		if str(r.get("mount", "")) != "":
			Mounts.grant_mount(ch, str(r.mount))
		if r.has("title") and not ch.titles.has(str(r.title)):
			ch.titles.append(str(r.title))
		var lore = str(r.get("lore", sc.get("lore", "")))
		if lore != "" and not ch.discoveries.has("lore:" + lore):
			ch.discoveries.append("lore:" + lore)
		Fx.burst(at + Vector3(0, 0.8, 0), Color(0.85, 0.95, 1.0), 30, 4.0, 0.1, 1.0, 1.0)
		Sfx.play("quest_done", -4.0)
		Events.surprise_event.emit("secret:" + sid)
		Events.toast.emit("A secret! " + str(sc.get("hint", "")), Color(0.85, 0.95, 1.0))
		Game.save_character()

## Called by monsters when they use an ability (no_hit_phase secret).
func on_monster_ability(m: Node) -> void:
	if _no_hit_secret.is_empty() or not (m is Monster) or not m.is_boss():
		return
	_no_hit_count += 1
	if _no_hit_count >= int(_no_hit_secret.get("count_needed", 3)):
		var sc = _no_hit_secret
		_no_hit_secret = {}
		found_secret(sc, player.global_position)

func _secret_on_player_hit() -> void:
	_no_hit_count = 0

func _secret_on_npc_talk(npc_id: String) -> void:
	if _talk_secret.is_empty():
		return
	var ch = Game.character
	ch.stats_tracking["talked:" + npc_id] = 1
	for n in npcs:
		if is_instance_valid(n) and int(ch.stats_tracking.get("talked:" + n.npc_id, 0)) == 0:
			return
	var sc = _talk_secret
	_talk_secret = {}
	found_secret(sc, player.global_position)

func _update_still_secret(delta: float) -> void:
	if not _riddle.is_empty() and player:
		if player.intent_move.length() > 0.1 or player.global_position.distance_to(_riddle.pos) > 3.0:
			_riddle.t = 0.0
		else:
			_riddle.t = float(_riddle.t) + delta
			if float(_riddle.t) >= 5.0:
				var rsc = _riddle.sc
				_riddle = {}
				found_secret(rsc, player.global_position)
	if _still_secret.is_empty() or player == null:
		return
	if player.intent_move.length() > 0.1 or not player.alive:
		_still_t = 0.0
		return
	_still_t += delta
	if _still_t >= float(_still_secret.get("seconds", 30.0)):
		var sc = _still_secret
		_still_secret = {}
		found_secret(sc, player.global_position)

## Main-quest "solve" objectives: a glowing object to interact with somewhere in this zone.
func _place_story_object() -> void:
	_place_story_escort()
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
	var pz = Content.get_rec("puzzles", target)
	var props: Array = pz.get("props", [])
	if not props.is_empty() and ZoneBuilder.scene_of(str(props[0])):
		mi.visible = false
		n.add_child(ZoneBuilder.scene_of(str(props[0])).instantiate())
	interactables.append({"node": n, "pos": pos, "radius": 2.0, "label": str(o.get("label", "Examine")), "once": true,
		"action": func():
			MainQuest.notify(Game.character, "solve", target)
			Fx.burst(pos + Vector3(0, 1, 0), Color(0.6, 0.85, 1.0), 30, 4.0, 0.12, 0.9, 1.0)
			n.queue_free()})

## Main-quest escort: a small companion walks from the start to the exit while the hero is near.
func _place_story_escort() -> void:
	var e = MainQuest.escort_for_zone(Game.character, zone.id)
	if e.is_empty():
		return
	var w = EscortWisp.new()
	actors_root.add_child(w)
	w.global_position = clamp_to_walkable(player.global_position, player.global_position + Vector3(1.5, 0, 0))
	var cr: Dictionary = e.get("creature", {})
	w.setup_wisp(999999.0, Color(cr.get("tint", "#bfe3ff")))
	w.display_name = str(cr.get("name", "Friend"))
	w.move_speed = float(e.get("speed", 2.5))
	w.wait_for = player if e.get("waits_for_player", true) else null
	var end = layout.cell_to_world(layout.rooms[layout.end_room].center)
	if is_town:
		var far = layout.rooms[layout.start_room].rect
		end = clamp_to_walkable(w.global_position, w.global_position + Vector3(far.size.x * ZoneLayout.CELL * 0.4, 0, 0))
	w.dest = end
	w.moving = true
	var eid = str(e.id)
	w.arrived.connect(func():
		MainQuest.notify(Game.character, "escort", eid)
		Fx.burst(w.global_position + Vector3(0, 1, 0), Color(0.8, 0.95, 1.0), 30, 4.0, 0.12, 0.9, 1.0)
		w.queue_free())

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

## Town "onward" portal to the next unvisited story zone of this act (the waypoint map covers the rest).
func _place_onward_portal(center: Vector3) -> void:
	var sess = get_parent()
	if sess == null or not sess.has_method("onward_zone"):
		return
	var zid: String = sess.onward_zone(str(zone.get("act", "")))
	if zid == "":
		return
	var pos = clamp_to_walkable(center, center + Vector3(3.0, 0, 3.0))
	var p = preload("res://scripts/world/portal.gd").new()
	add_child(p)
	p.global_position = pos
	p.setup(Color(0.55, 0.75, 1.0))
	interactables.append({"node": p, "pos": pos, "radius": 2.0, "label": "Onward: " + str(Content.get_rec("zones", zid).get("name", zid)),
		"action": func(): get_tree().call_group("session", "travel", zid)})
	set_meta("onward_zone", zid)

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

func add_hazard(kind: String, pos: Vector3, radius: float, duration: float, pos2 = null, src: Node = null) -> void:
	active_hazards.append({"kind": kind, "pos": Vector3(pos.x, 0, pos.z), "pos2": Vector3(pos2.x, 0, pos2.z) if pos2 is Vector3 else Vector3(pos.x, 0, pos.z),
		"radius": radius, "until": game_time + duration, "src": weakref(src) if src else null})

## Hazards covering `p` (with a safety margin), soonest first.
func hazards_at(p: Vector3, margin := 0.6, include_melee := true) -> Array:
	var now = game_time
	var out = []
	for h in active_hazards:
		if float(h.until) < now or (not include_melee and h.kind == "melee"):
			continue
		var c: Vector3 = h.pos if h.kind != "line" else Geometry3D.get_closest_point_to_segment(Vector3(p.x, 0, p.z), h.pos, h.pos2)
		if Vector2(p.x - c.x, p.z - c.z).length() <= float(h.radius) + margin:
			out.append(h)
	out.sort_custom(func(a, b): return float(a.until) < float(b.until))
	return out

## Direction that leaves hazard h fastest (away from centre / perpendicular to a line).
func hazard_escape_dir(p: Vector3, h: Dictionary) -> Vector3:
	var c: Vector3 = h.pos if h.kind != "line" else Geometry3D.get_closest_point_to_segment(Vector3(p.x, 0, p.z), h.pos, h.pos2)
	var d = Vector3(p.x - c.x, 0, p.z - c.z)
	if d.length() < 0.05:
		d = (h.pos2 - h.pos).cross(Vector3.UP) if h.kind == "line" else Vector3(1, 0, 0)
	d = d.normalized()
	# Prefer a direction that stays walkable
	for ang in [0.0, 0.6, -0.6, 1.2, -1.2, PI]:
		var dir = d.rotated(Vector3.UP, ang)
		if is_walkable(p + dir * 2.0):
			return dir
	return d

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

## block_casts hook: a block releases a free skill (internal cooldown).
func _block_hook(p: Player) -> void:
	if not Hooks.has(p.ch, "block_casts") or p.time_now() < float(p.get_meta("block_cast_cd", 0.0)):
		return
	var sid = str(Hooks.param(p.ch, "block_casts", "skill", ""))
	if not Content.has_rec("skills", sid):
		return
	p.set_meta("block_cast_cd", p.time_now() + float(Hooks.param(p.ch, "block_casts", "cooldown", 2.0)))
	var t = nearest_enemy(p, p.global_position, 8.0, [])
	SkillEffects.execute(p, p.skill_def(sid), max(1, p.skill_rank(sid)), t.global_position if t else p.global_position + p.facing * 2.0)

## Lantern's Blessing (research #23): optional assist after repeated deaths in a zone. Never in
## Hardcore; framed positively. config/assist {damage_taken_reduction_pct, per_death_pct, cap_pct,
## allowed_in_hardcore, min_deaths}.
func _update_blessing() -> void:
	var ch = Game.character
	var c = Content.get_rec("config", "assist")
	if c.is_empty():
		c = Content.get_rec("config", "blessing")
	var pct = 0.0
	var hc_ok = bool(c.get("allowed_in_hardcore", false)) or not ch.hardcore
	if hc_ok and Settings.get_value("lanterns_blessing", true) and zone_deaths >= int(c.get("min_deaths", 2)):
		pct = float(c.get("damage_taken_reduction_pct", c.get("base_pct", 20.0))) + float(c.get("per_death_pct", 2.0)) * (zone_deaths - int(c.get("min_deaths", 2)))
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
	var owner: Actor = src.owner_actor if (src is Monster and src.owner_actor) else src
	var hit = Combat.roll_player_hit(src_ctx, mult, element, tags)
	if owner is Player and not is_dot:
		# dodge_next_crit: the hit after a dodge is a guaranteed critical
		if not hit.crit and owner.has_meta("next_crit"):
			hit.crit = true
			hit.amount = float(hit.amount) * (1.5 + owner.stats.get_stat("crit_damage") / 100.0)
		if owner.has_meta("next_crit"):
			owner.remove_meta("next_crit")
	if owner is Player and Hooks.has(owner.ch, "bonus_vs_status"):
		for stid in Hooks.param(owner.ch, "bonus_vs_status", "statuses", []):
			if target.has_status(str(stid)):
				hit.amount = float(hit.amount) * (1.0 + float(Hooks.param(owner.ch, "bonus_vs_status", "more", 25)) / 100.0)
				break
	# zone_minion_bonus hook: foes inside the hero's ground zones take more damage from minions
	if owner is Player and src != owner and Hooks.has(owner.ch, "zone_minion_bonus"):
		for z in get_tree().get_nodes_in_group("player_zones"):
			if z.global_position.distance_to(target.global_position) <= float(z.radius):
				hit.amount = float(hit.amount) * (1.0 + float(Hooks.param(owner.ch, "zone_minion_bonus", "more", 20)) / 100.0)
				break
	var def = {"stats": target.stats, "level": target.level}
	var amount = Combat.mitigate(hit, def, src.level)
	if target is Monster and target.shield_active():
		amount *= 0.5
		Sfx.play("shield_block", -10.0)
	_apply_damage(target, amount, hit.crit, element, src)
	# On-hit effects
	# Skill mastery XP: effects carry "_skill"; minions remember the skill that summoned them
	var sk = str(e.get("_skill", ""))
	if sk == "" and src is Monster and src.has_meta("skill_id"):
		sk = str(src.get_meta("skill_id"))
	if sk != "" and owner is Player:
		SkillMastery.on_hit(owner.ch, sk)
		owner.ch.track("hits:skill:" + sk)
		if not target.alive:
			SkillMastery.on_kill(owner.ch, sk)
	if owner is Player and not is_dot:
		for t in tags:
			owner.ch.track("hits:tag:" + str(t))
		if hit.crit:
			owner.ch.track("crits")
			if Hooks.has(owner.ch, "crit_gain_resource"):
				owner.gain_resource(float(Hooks.param(owner.ch, "crit_gain_resource", "amount", 5)))
		if src != owner and not target.alive:
			owner.ch.track("minion_kills")
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
			var dur = float(st.get("duration", 1.0))
			if st.id == "stun" and owner is Player and Hooks.has(owner.ch, "quake_stun_bonus"):
				dur += float(Hooks.param(owner.ch, "quake_stun_bonus", "seconds", 0.5))
			target.add_status(st.id, dur, float(st.get("value", 0.3)))
			if st.id == "stun" and owner is Player:
				owner.ch.track("stuns")
			if st.id == "freeze" or st.id == "stun":
				target.flash(Color(0.6, 0.85, 1.0), 0.6)
	if hit.crit and not is_dot:
		if src is Player:
			UiTheme.haptic(15, 0.4)
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
			target.ch.track("blocks")
			_block_hook(target)
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
		if target is Player:
			target.ch.track("dodges")
			if Hooks.has(target.ch, "dodge_next_crit"):
				target.set_meta("next_crit", true)
		Fx.float_text(target.global_position, "Dodge", Color(0.8, 0.8, 0.8), 30)
		return
	if target is Player:
		_secret_on_player_hit()
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
	if m.kind == "minion" and m.owner_actor is Player and is_instance_valid(m.owner_actor) and Hooks.has(m.owner_actor.ch, "minion_death_burst"):
		var r = float(Hooks.param(m.owner_actor.ch, "minion_death_burst", "radius", 2.5))
		Fx.ring(m.global_position, r, Color(1, 0.85, 0.6), 0.35)
		for t in enemies_in_radius(m.owner_actor, m.global_position, r):
			deal_damage(m.owner_actor, t, float(Hooks.param(m.owner_actor.ch, "minion_death_burst", "mult", 0.8)), "physical", ["minion"], {}, true)
	if m.kind == "minion":
		Fx.soul_puff(m.global_position, Color(1.0, 0.8, 0.6))
		after(0.6, m.queue_free)
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
		var ev = Content.get_rec("events", m.get_meta("event"))
		loot_kind = ev.get("loot_kind", "rare")
		if str(ev.get("portal", "")) != "" and Rng.chance("loot", float(ev.get("portal_chance", 0.0))):
			spawn_zone_portal(str(ev.portal), m.global_position, Color(ev.get("color", "#ffd84a")))
		var rm = ev.get("reward_material", {})
		if rm is Dictionary and rm.has("id"):
			ch.add_material(str(rm.id), int(rm.get("count", 1)))
			Fx.float_text(m.global_position, "+%s" % Content.get_rec("materials", str(rm.id)).get("name", rm.id), Color(ev.get("color", "#9cffb0")), 30)
	var res = Loot.roll_kill(m.rec, m.level, ch, tier, loot_kind)
	var xa = Pets.extra_affix_chance(ch)
	if xa > 0.0:
		for it in res.items:
			if Items.rarity_index(it.rarity) >= 1 and it.affixes.size() < Items.max_affixes(it.rarity) and Rng.chance("loot", xa):
				var pool = Items.affix_pool(it)
				if not pool.is_empty():
					it.affixes.append(Items.roll_affix(Rng.weighted("loot", Items.weighted_pool(pool, it)).a, int(it.ilvl), false, "loot"))
	if int(res.materials.get("hushmark", 0)) > 0:
		ch.track("hushmarks_earned", int(res.materials.hushmark))
	# Weapon proficiency, pet XP/perks, pet drops, quests
	var pc = Weapons.prof_cfg()
	var pxp = int(pc.get("xp_per_boss", 40)) if m.kind == "boss" else (int(pc.get("xp_per_elite", 5)) if m.kind in ["champion", "rare"] else int(pc.get("xp_per_kill", 1)))
	Weapons.gain_proficiency(ch, Weapons.main_type(ch), pxp)
	if m.kind == "boss":
		ch.track("kills:boss:" + str(m.rec.get("id", "")))
	if m.kind in ["champion", "rare"]:
		ch.track("kills:elite")
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
	if MainQuest.on_kill_in_zone(ch, zone.id):
		var o = MainQuest.current_objective(ch)
		Fx.float_text(m.global_position, "Found: %s" % str(o.get("target", "")).trim_prefix("qi_").replace("_", " ").capitalize(), Color(0.7, 0.9, 1.0), 30)
	var fam = str(m.rec.get("family", ""))
	Quests.notify(ch, "kill", str(m.rec.get("id", "")), 1, {"family": fam, "kind": m.kind})
	MainQuest.notify(ch, "kill", str(m.rec.get("id", "")), 1, {"family": fam})
	if fam != "":
		ch.track("kills:family:" + fam)
	ch.track("kills:monster:" + str(m.rec.get("id", "")))
	if int(ch.stats_tracking.get("kills:monster:" + str(m.rec.get("id", "")), 0)) == 1:
		ch.track("monster_kinds_met")
	if m.elite_affixes.size() >= 3:
		ch.track("kills:elite_3plus_affixes")
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
		if not _rekindle_secret.is_empty() and int(ch.stats_tracking.get("deaths_in_act:" + str(zone.get("act", "")), 0)) == 0:
			found_secret(_rekindle_secret, m.global_position)
			_rekindle_secret = {}
		exit_portal.visible = true
		Events.toast.emit("%s is rekindled!" % m.display_name, Color(1, 0.85, 0.4))
	Events.actor_died.emit(m, player)
	var mref = weakref(m)
	after(1.4, func():
		var m2 = mref.get_ref()
		if is_instance_valid(m2):
			var t = m2.create_tween()
			t.tween_property(m2, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
			t.tween_callback(m2.queue_free))
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
		Deeds.check(ch, "level")
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
			UiTheme.haptic(60, 1.0)
			# Slow-mo only for the first Legendary+ of this zone visit (research #26)
			if not _legendary_slowmo_done:
				_legendary_slowmo_done = true
				Fx.slowmo(0.5, 0.35)
		elif rank >= 2:
			Sfx.play("drop_" + it.rarity, -3.0, 0.0)
		elif n <= 1:
			Sfx.play("drop_" + it.rarity, -10.0, 0.0)
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
		if Pets.double_gold(ch):
			d.gold *= 2
			Fx.float_text(d.global_position + Vector3(0, 0.5, 0), "Lucky!", Color(0.5, 1, 0.6), 28)
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
			var new_entry = Codex.record(it)
			ch.track("uniques_found" if it.has("unique") else "legendaries_found")
			if it.has("unique") and new_entry:
				ch.track("uniques_found_distinct")
			if it.rarity == "mythic":
				ch.track("mythics_found")
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
	ch.stats_tracking["deaths_in_act:" + str(zone.get("act", ""))] = int(ch.stats_tracking.get("deaths_in_act:" + str(zone.get("act", "")), 0)) + 1
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
	if Fx.has_method("lightning"):
		Fx.lightning(a, b, col)
		return
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
	after(0.12, mi.queue_free)

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

func _nearest_open(c: Vector2i) -> Vector2i:
	if astar.is_in_boundsv(c) and not astar.is_point_solid(c):
		return c
	for r in range(1, 3):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n = c + Vector2i(dx, dy)
				if astar.is_in_boundsv(n) and not astar.is_point_solid(n):
					return n
	return Vector2i(-99999, -99999)

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
	# Start/end on a solid or out-of-bounds point (actor pushed against a wall, target on a ledge):
	# path from the nearest walkable point instead of giving up.
	var ia = _nearest_open(Vector2i(int(a.x / PATH_RES), int(a.z / PATH_RES)))
	var ib = _nearest_open(Vector2i(int(b.x / PATH_RES), int(b.z / PATH_RES)))
	if ia.x < -9999 or ib.x < -9999:
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
	_update_still_secret(delta)
	game_time += delta
	if not active_hazards.is_empty():
		var now = game_time
		active_hazards = active_hazards.filter(func(h): return float(h.until) >= now)
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
