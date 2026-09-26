class_name WorldEvents
extends Node
## Hushfalls (GDD v2.4 #30): random world events. One GameWorld child per non-town zone.
## Data `world_events`: {id, name, kind ("invasion"|"cursed_shrine"|"treasure_swarm"|"escort"|
##   "echo_duel"), weight, min_level, acts[], announce, color,
##   stages:[{monsters:["family:x"|"any_family"|monster_id], count, elite:"champion"|"rare"}],
##   boss: spec ("family:x"|"any_family"|id), curse{stat: value}, swarm_count, escort_rooms,
##   reward:{loot_kind, mult, materials:[{id, chance, min, max}]}}
## config/world_events {chance_per_zone}. Test override: --hushfall=<id|any>.
## No real-time timers; leaving the zone ends it silently (curse removed in _exit_tree).

var world: GameWorld
var rec = {}
var state = "none"             # none | waiting | running | done | failed
var stage = 0
var total_stages = 0
var tear: Node3D
var tear_pos = Vector3.ZERO
var _alive: Array = []
var _wisp: EscortWisp
var _escort_points: Array = []
var _check = 0.0
var _cache_node: Node3D

const START_RADIUS := 8.0

func setup(w: GameWorld) -> void:
	world = w
	var list = Content.all("world_events").filter(func(r): return _eligible(r))
	if list.is_empty():
		return
	var forced = _forced_id()
	var pick = {}
	if forced != "":
		for r in list:
			if forced == "any" or r.id == forced:
				pick = r
				break
		if forced == "any" and not list.is_empty():
			pick = Rng.weighted("world", list)
	elif Rng.chance("world", float(Content.cfg("world_events", "chance_per_zone", 0.25))):
		pick = Rng.weighted("world", list)
	if pick == null or pick.is_empty():
		return
	rec = pick
	_place_tear()

func _forced_id() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hushfall="):
			return a.substr(11)
	return ""

func _eligible(r: Dictionary) -> bool:
	var ch = Game.character
	if ch.level < int(r.get("min_level", 1)):
		return false
	var acts: Array = r.get("acts", [])
	return acts.is_empty() or acts.has(world.zone.get("act", ""))

func kind() -> String:
	return str(rec.get("kind", "invasion"))

func color() -> Color:
	return Color(rec.get("color", "#b48cff"))

func _place_tear() -> void:
	var rooms = range(world.layout.rooms.size())
	rooms.erase(world.layout.start_room)
	if world.zone.get("boss", "") != "" and rooms.size() > 1:
		rooms.erase(world.layout.end_room)
	if rooms.is_empty():
		return
	var ri: int = rooms[Rng.int_on("world", 0, rooms.size() - 1)]
	tear_pos = world.layout.cell_to_world(world.layout.rooms[ri].center)
	tear = _make_tear(color())
	world.add_child(tear)
	tear.global_position = tear_pos
	state = "waiting"
	world.set_meta("hushfall_pos", tear_pos)
	Events.surprise_event.emit(str(rec.id))
	Events.toast.emit(str(rec.get("announce", "A Hushfall tears the air nearby...")), color())
	Sfx.play("portal", -4.0)

func _make_tear(col: Color) -> Node3D:
	var root = Node3D.new()
	root.name = "HushTear"
	var ring = MeshInstance3D.new()
	var t = TorusMesh.new()
	t.inner_radius = 0.85
	t.outer_radius = 1.05
	t.rings = 20
	t.ring_segments = 6
	ring.mesh = t
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 3.5
	ring.material_override = m
	ring.rotation_degrees.x = 90
	ring.scale = Vector3(0.8, 1.0, 1.6)
	ring.position.y = 1.7
	ring.name = "Ring"
	root.add_child(ring)
	var core = MeshInstance3D.new()
	var q = QuadMesh.new()
	q.size = Vector2(1.5, 2.9)
	core.mesh = q
	var cm = StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.albedo_color = Color(0.05, 0.03, 0.1, 0.85)
	cm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	core.material_override = cm
	core.position.y = 1.7
	root.add_child(core)
	var p = CPUParticles3D.new()
	p.amount = 28
	p.lifetime = 1.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.2
	p.direction = Vector3.UP
	p.gravity = Vector3(0, 0.8, 0)
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.5
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.12
	var sm = SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 4
	sm.rings = 2
	sm.material = m
	p.mesh = sm
	p.position.y = 1.5
	root.add_child(p)
	Fx.beam(root, col, 7.0, 0.9)
	return root

func _process(delta: float) -> void:
	if tear and is_instance_valid(tear):
		var ring = tear.get_node_or_null("Ring")
		if ring:
			ring.rotation.z += delta * 1.5
	if state != "waiting" and state != "running":
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.25
	var p = world.player
	if p == null or not is_instance_valid(p) or not p.alive:
		return
	if state == "waiting" and p.global_position.distance_to(tear_pos) < START_RADIUS:
		_start()
	elif state == "running":
		_alive = _alive.filter(func(x): return is_instance_valid(x) and x.alive)
		if _alive.is_empty() and not (_wisp and is_instance_valid(_wisp) and _wisp.moving):
			_next_stage()

func _start() -> void:
	state = "running"
	stage = 0
	var stages: Array = rec.get("stages", [])
	match kind():
		"treasure_swarm", "echo_duel":
			total_stages = 1
		_:
			total_stages = max(1, stages.size() if not stages.is_empty() else 3) + (1 if _has_boss() else 0)
	if kind() == "cursed_shrine":
		var curse: Dictionary = rec.get("curse", {"damage_reduction": -15.0, "move_speed_pct": -10.0})
		Game.character.stats.set_source("curse", curse)
		world.player.on_buff_changed()
		Events.toast.emit("A curse settles on you — survive it!", color())
	if kind() == "escort":
		_spawn_wisp()
	Fx.ring(tear_pos, 5.0, color(), 0.8)
	Fx.shake(0.3)
	Events.world_event_started.emit(str(rec.id))
	_next_stage()

func _has_boss() -> bool:
	return kind() in ["invasion", "cursed_shrine", "escort"] and str(rec.get("boss", "default")) != ""

func _next_stage() -> void:
	if state != "running":
		return
	if kind() == "escort" and stage > 0 and _wisp and is_instance_valid(_wisp) and not _escort_points.is_empty():
		# Wave cleared → the wisp walks on to the next point before the next wave
		if not _wisp.moving and _wisp.global_position.distance_to(_escort_points[0]) > 1.5:
			_wisp.dest = _escort_points[0]
			_wisp.moving = true
			return
		if _wisp.global_position.distance_to(_escort_points[0]) <= 1.5:
			_escort_points.pop_front()
	if stage >= total_stages:
		_complete()
		return
	stage += 1
	Events.world_event_stage.emit(str(rec.id), stage, total_stages)
	var center = tear_pos
	if kind() == "escort" and _wisp and is_instance_valid(_wisp):
		center = _wisp.global_position
	match kind():
		"treasure_swarm":
			var n = int(rec.get("swarm_count", 5))
			var imp = str(rec.get("swarm_monster", "magpie_imp"))
			for i in n:
				var m = _spawn(imp, center, "normal")
				if m:
					m.add_sparkle_trail(color().lerp(Color("#ffd84a"), 0.7))
					if rec.has("swarm_event"):
						m.set_meta("event", str(rec.swarm_event))
		"echo_duel":
			var er = echo_rec()
			var m = world.spawn_monster_rec(er, world.clamp_to_walkable(tear_pos, tear_pos + Vector3(0, 0, 1.5)), world.monster_level + 1, "rare")
			if m:
				_alive.append(m)
				m.target = world.player
		_:
			var stages: Array = rec.get("stages", [])
			var is_boss_stage = _has_boss() and stage == total_stages
			if is_boss_stage:
				var boss_spec = str(rec.get("boss", "any_family"))
				if boss_spec == "default":
					boss_spec = "zone"
				var m = _spawn(resolve_spec(boss_spec), center, "rare")
				if m:
					m.elite_affixes = _random_affixes(2)
					world._apply_elite(m)
					m.max_life *= float(rec.get("boss_life_mult", 1.6))
					m.life = m.max_life
					Events.toast.emit("%s emerges from the Hush!" % m.display_name, color())
			else:
				var st: Dictionary = stages[stage - 1] if stage - 1 < stages.size() else {"monsters": ["zone"], "count": 3 + stage * 2}
				var specs: Array = st.get("monsters", ["zone"])
				var count = int(st.get("count", 5))
				for i in count:
					var spec = str(specs[i % specs.size()]) if not specs.is_empty() else "zone"
					var k = "normal"
					if i == 0 and st.has("elite"):
						k = str(st.elite)
					var m = _spawn(resolve_spec(spec), center, k)
					if m and k != "normal":
						m.elite_affixes = _random_affixes(1 if k == "champion" else 2)
						world._apply_elite(m)
	Fx.ring(center, 4.0, color(), 0.5)
	Sfx.play("portal", -6.0)

func _spawn(monster_id: String, center: Vector3, k: String) -> Monster:
	if monster_id == "":
		return null
	var off = Vector3(Rng.range_on("world", -3.5, 3.5), 0, Rng.range_on("world", -3.5, 3.5))
	var m = world.spawn_monster(monster_id, world.clamp_to_walkable(center, center + off), world.monster_level, k)
	if m:
		m.set_meta("hushfall", true)
		m.target = world.player
		m.aggro_range = max(m.aggro_range, 30.0)
		Fx.soul_puff(m.global_position, color())
		_alive.append(m)
	return m

func _random_affixes(n: int) -> Array:
	var all_aff = Content.all("monster_affixes")
	var out = []
	for i in n:
		if all_aff.size() > 0:
			var a = all_aff[Rng.int_on("world", 0, all_aff.size() - 1)].id
			if not out.has(a):
				out.append(a)
	return out

## "family:x" → weighted monster of family x; "any_family" → any regular monster (other acts too);
## "zone" → the zone's families; anything else is a monster id.
func resolve_spec(spec: String) -> String:
	var pool = []
	if spec.begins_with("family:"):
		var fam = spec.substr(7)
		pool = Content.all("monsters").filter(func(m): return m.get("family", "") == fam and not m.get("boss", false) and not m.get("summon_only", false))
	elif spec == "any_family":
		pool = Content.all("monsters").filter(func(m): return not m.get("boss", false) and not m.get("summon_only", false) and m.get("family", "") != "event")
	elif spec == "zone":
		var fams: Array = world.zone.get("families", world.act.get("families", []))
		pool = Content.all("monsters").filter(func(m): return fams.has(m.get("family", "")) and not m.get("boss", false) and not m.get("summon_only", false))
		if pool.is_empty():
			return resolve_spec("any_family")
	else:
		return spec if Content.has_rec("monsters", spec) else resolve_spec("zone")
	if pool.is_empty():
		return ""
	var pick = Rng.weighted("world", pool, "spawn_weight")
	return pick.id if pick else ""

func _spawn_wisp() -> void:
	_wisp = EscortWisp.new()
	world.actors_root.add_child(_wisp)
	_wisp.global_position = world.clamp_to_walkable(tear_pos, tear_pos + Vector3(1.5, 0, 0))
	_wisp.setup_wisp(world.player.max_life * float(rec.get("wisp_life_mult", 1.5)))
	_wisp.net_id = world._nid()
	world.minions.append(_wisp)
	world._attach_healthbar(_wisp)
	_wisp.died.connect(func(_a):
		world.minions.erase(_wisp)
		_fail("The Lost Wisp faded back into the Hush..."))
	# Walk toward rooms farther away, one leg per wave
	var rooms = range(world.layout.rooms.size())
	rooms.sort_custom(func(a, b): return world.layout.cell_to_world(world.layout.rooms[a].center).distance_to(tear_pos) < world.layout.cell_to_world(world.layout.rooms[b].center).distance_to(tear_pos))
	var legs = int(rec.get("escort_rooms", 2))
	_escort_points = []
	for i in range(1, min(rooms.size(), legs + 1)):
		_escort_points.append(world.layout.cell_to_world(world.layout.rooms[rooms[i]].center))

## A grey mirror of the player's class: same model, basic attack and up to 3 skills as abilities.
func echo_rec() -> Dictionary:
	var ch = Game.character
	var cls = ch.cls()
	var basic = Content.get_rec("skills", str(cls.get("basic_attack", "")))
	var ranged = basic.get("tags", []).has("projectile")
	var anim = basic.get("anim", "1H_Melee_Attack_Chop")
	var r = {"id": "echo_" + ch.class_id, "name": "Echo of %s" % ch.name, "family": "echo", "model": cls.get("model", ""),
		"attachments": cls.get("attachments", []), "tint": "#8d8d99", "rim": "#d0d0e0", "scale": 1.0,
		"life_mult": float(rec.get("echo_life_mult", 7.0)), "dmg_mult": 1.1, "speed": 4.2, "xp": 80, "ai": "ranged" if ranged else "melee",
		"keep_distance": 5.0, "soul_color": "#e0e0f0", "summon_only": true,
		"attack": {"range": 7.0 if ranged else 1.8, "windup": 0.4, "cooldown": 1.3, "anim": anim, "mult": 1.0}, "abilities": []}
	if ranged:
		r.attack["projectile"] = {"speed": 12.0, "range": 12.0, "size": 0.25}
	var n = 0
	for s in Content.where("skills", "class", ch.class_id):
		if n >= 3 or s.id == basic.get("id", ""):
			continue
		var ab = _skill_to_ability(s)
		if not ab.is_empty():
			r.abilities.append(ab)
			n += 1
	return r

func _skill_to_ability(s: Dictionary) -> Dictionary:
	for e in s.get("effects", []):
		var base = {"id": "echo_" + str(s.id), "cooldown": max(5.0, float(s.get("cooldown", 4.0)) * 1.5), "telegraph": 1.0, "anim": s.get("anim", "Spellcast_Raise") if s.get("anim") is String else "Spellcast_Raise", "element": s.get("element", "shadow")}
		match str(e.get("type", "")):
			"aoe", "nova", "ground_zone", "spin":
				base.merge({"type": "slam", "at": "self" if e.type in ["nova", "spin"] else "target", "radius": float(e.get("radius", 3.0)), "mult": 1.4, "range": 8.0})
				return base
			"projectile", "chain":
				base.merge({"type": "volley", "count": 3, "spread": 20.0, "mult": 0.8, "range": 10.0, "projectile": {"speed": 10.0, "range": 12.0, "size": 0.25}})
				return base
			"dash", "leap":
				base.merge({"type": "charge", "distance": 7.0, "mult": 1.3, "range": 10.0, "min_range": 3.0})
				return base
	return {}

func on_monster_died(m: Node) -> void:
	_alive.erase(m)

func on_monster_removed(m: Node) -> void:
	_alive.erase(m)

func _complete() -> void:
	state = "done"
	_clear_curse()
	if _wisp and is_instance_valid(_wisp):
		Fx.burst(_wisp.global_position + Vector3(0, 1, 0), Color(0.7, 0.9, 1.0), 30, 4.0, 0.12, 1.0, 2.0)
		world.minions.erase(_wisp)
		_wisp.queue_free()
	Events.world_event_completed.emit(str(rec.id))
	Events.toast.emit("The Hushfall is sealed! A cache of light appears.", color())
	Game.character.track("hushfalls")
	if kind() == "escort":
		MainQuest.notify(Game.character, "escort", str(rec.id))
		MainQuest.notify(Game.character, "escort", "any")
	_close_tear()
	_spawn_cache()

func _fail(msg: String) -> void:
	if state != "running":
		return
	state = "failed"
	_clear_curse()
	Events.toast.emit(msg, Color(0.8, 0.8, 0.9))
	_close_tear()

func _close_tear() -> void:
	if tear and is_instance_valid(tear):
		Fx.ring(tear_pos, 3.0, color(), 0.6)
		var t = tear.create_tween()
		t.tween_property(tear, "scale", Vector3(0.01, 0.01, 0.01), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t.tween_callback(tear.queue_free)
	if world.has_meta("hushfall_pos"):
		world.remove_meta("hushfall_pos")

func _spawn_cache() -> void:
	var model = "chest_gold"
	var ps = ZoneBuilder.scene_of(model)
	_cache_node = ps.instantiate() if ps else Node3D.new()
	world.add_child(_cache_node)
	_cache_node.global_position = tear_pos
	Fx.beam(_cache_node, color(), 5.0, 0.8)
	var entry = {"node": _cache_node, "pos": tear_pos, "radius": 2.0, "label": "Open Hush cache", "once": true}
	entry.action = func(): open_cache()
	world.interactables.append(entry)

## Reward: loot kind (config) or a generous chest fallback, × mult, plus data materials.
func open_cache() -> void:
	if _cache_node == null or not is_instance_valid(_cache_node):
		return
	var reward: Dictionary = rec.get("reward", {})
	var ch = Game.character
	var fallback = {"item_chance": 0.8, "min_items": 2, "max_items": 4, "gold_chance": 1.0, "gold_mult": 8.0, "min_rank": 1,
		"rarity_bonus": {"rare": 2.5, "epic": 3.0, "legendary": 3.0}}
	var mult = int(max(1, round(float(reward.get("mult", 2.0 if kind() == "cursed_shrine" else 1.0)))))
	var res = {"items": [], "gold": 0, "materials": {}}
	for i in mult:
		var r = Loot.roll_kill({"materials": reward.get("materials", [])}, world.monster_level, ch, Game.tier(), str(reward.get("loot_kind", "hushfall_cache")), fallback)
		res.items += r.items
		res.gold += int(r.gold)
		for k in r.materials:
			res.materials[k] = int(res.materials.get(k, 0)) + int(r.materials[k])
	world._spawn_loot(res, tear_pos)
	Sfx.play("chest_open")
	Fx.burst(tear_pos + Vector3(0, 0.8, 0), color(), 30, 5.0, 0.12, 0.9)
	Fx.flash_light(tear_pos + Vector3(0, 1, 0), color(), 4.0, 0.6)
	world.interactables = world.interactables.filter(func(it): return it.node != _cache_node)
	var t = _cache_node.create_tween()
	t.tween_property(_cache_node, "scale", Vector3(1.2, 0.8, 1.2), 0.08)
	t.tween_property(_cache_node, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	_cache_node = null

func _clear_curse() -> void:
	if Game.character and Game.character.stats.sources.has("curse"):
		Game.character.stats.remove_source("curse")
		if world and world.player and is_instance_valid(world.player):
			world.player.on_buff_changed()

func _exit_tree() -> void:
	_clear_curse()

## Progress for the HUD: {id, name, kind, state, stage, total, pos}
func status() -> Dictionary:
	if rec.is_empty():
		return {}
	return {"id": rec.id, "name": rec.get("name", ""), "kind": kind(), "state": state, "stage": stage, "total": total_stages, "pos": tear_pos}
