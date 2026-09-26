class_name Monster
extends Actor
## Data-driven monster. Record fields (monsters table):
##  id, name, family, model, scale, tint, rim, attachments[], props[{path,bone}], life_mult, dmg_mult, speed,
##  xp, ai ("melee"|"ranged"|"caster"|"charger"|"swarm"|"summoner"), attack {range, windup, cooldown, anim, radius, angle},
##  ranged {projectile...}, abilities [ {skill-like effect list, cooldown, range, telegraph} ], spawn_anim, materials[], uniques[]

var rec: Dictionary
var kind = "normal"          # normal | champion | rare | boss | minion
var target: Actor = null
var _attack_ready = 0.0
var _ability_ready = {}
var _think = 0.0
var _path: PackedVector3Array = []
var _path_i = 0
var _repath = 0.0
var home = Vector3.ZERO
var aggro_range = 11.0
var elite_affixes = []
var owner_actor: Actor = null   # for minions
var expire_at = 0.0
var _spawn_until = 0.0
var healthbar: Node3D
# Flee AI (Magpie Imp): runs from the player, escapes through a portal after escape_after seconds
var _flee_started = -1.0
var _flee_dest = Vector3.ZERO
var _coin_cd = 0.0
var escaped = false
# Boss phases
var phase = 0
var _phase_locked = {}          # ability ids unlocked only by a later phase (phases[].abilities_add)
var _shield_fx: MeshInstance3D

func setup(r: Dictionary, lvl: int, k := "normal") -> void:
	rec = r
	kind = k
	level = lvl
	display_name = r.get("name", "Snuffed")
	faction = "monster" if k != "minion" else "player"
	var sc = float(r.get("scale", 1.0))
	if k == "champion":
		sc *= 1.15
	elif k == "rare":
		sc *= 1.25
	radius = 0.45
	var tint = Color(r.get("tint", "#ffffff"))
	setup_model(r.get("model", "res://assets/thirdparty/kaykit/skeletons/characters/Skeleton_Minion.glb"), sc, tint, Color(r.get("rim", "#8fa0ff")))
	show_only_attachments(r.get("attachments", []))
	for p in r.get("props", []):
		attach_prop(p.path, p.get("bone", "handslot.r"))
	element_color = Color(r.get("color", "#ff5a3c"))
	var tier = Game.tier()
	max_life = Combat.monster_life(float(r.get("life_mult", 1.0)), lvl, tier)
	match k:
		"champion": max_life *= 2.6
		"rare": max_life *= 4.0
		"boss": max_life *= float(r.get("boss_life_mult", 1.0))
	life = max_life
	move_speed = float(r.get("speed", 3.2))
	aggro_range = float(r.get("aggro", 11.0))
	stats.set_source("base", {"armor": lvl * 6.0 * float(r.get("armor_mult", 1.0)), "resist_all": float(r.get("resist", 0.0))})
	collision_layer = 2
	collision_mask = 1
	home = global_position
	for ph in r.get("phases", []):
		for ab in ph.get("abilities_add", []):
			if ab is String and not ab.contains("/"):
				_phase_locked[ab] = true

func _ready() -> void:
	var sa: String = rec.get("spawn_anim", "")
	if sa != "" and anim and anim.has_animation(sa):
		play(sa, 1.0, 1.2, true)
		_spawn_until = time_now() + 1.0
	_attack_ready = time_now() + randf_range(0.3, 1.0)

func is_boss() -> bool:
	return kind == "boss"

func _physics_process(delta: float) -> void:
	if not alive:
		return
	if kind == "minion" and expire_at > 0.0 and time_now() > expire_at:
		Game.world.kill_actor(self, null)
		return
	if time_now() < _spawn_until:
		return
	_think -= delta
	if _think <= 0.0:
		_think = 0.25 + randf() * 0.1
		_acquire_target()
	var move = Vector3.ZERO
	if target and is_instance_valid(target) and target.alive and can_act():
		var d = global_position.distance_to(target.global_position)
		var atk: Dictionary = rec.get("attack", {})
		var atk_range = float(atk.get("range", 1.6)) + target.radius
		var ai: String = rec.get("ai", "melee")
		if ai == "flee":
			move = _flee(d, delta)
		elif _try_abilities(d):
			pass
		elif (ai == "ranged" or ai == "caster") and d < float(rec.get("keep_distance", 5.0)) and not anim_locked():
			move = (global_position - target.global_position).normalized()   # kite
		elif d > atk_range:
			move = _steer_to(target.global_position, delta)
		elif time_now() >= _attack_ready and not anim_locked():
			_attack()
		if not anim_locked() and move == Vector3.ZERO:
			face_towards(target.global_position)
	elif kind == "minion" and owner_actor and is_instance_valid(owner_actor):
		if global_position.distance_to(owner_actor.global_position) > 3.5:
			move = _steer_to(owner_actor.global_position, delta)
	var v = Vector3.ZERO
	if not anim_locked() and move.length() > 0.01:
		v = move.normalized() * move_speed * speed_mult()
		face_towards(global_position + v)
		play(rec.get("run_anim", "Running_A"), 0, clampf(move_speed / 3.5, 0.7, 1.5))
	elif not anim_locked():
		play(rec.get("idle_anim", "Idle_Combat" if anim and anim.has_animation("Idle_Combat") else "Idle"))
	velocity = v + _integrate_knockback(delta)
	move_and_slide()
	global_position.y = 0.0

func _acquire_target() -> void:
	if kind == "minion":
		target = Game.world.nearest_enemy(self, global_position, 12.0, [])
		return
	var p: Actor = Game.world.player
	if p and p.alive:
		var d = global_position.distance_to(p.global_position)
		if d < aggro_range or (target == p and d < aggro_range * 2.0) or is_boss():
			if target == null:
				Game.world.alert_pack(self, p)
			target = p
			return
	# Taunting minions pull aggro
	var m = Game.world.nearest_enemy(self, global_position, 5.0, [])
	target = m

func _steer_to(dest: Vector3, delta: float) -> Vector3:
	_repath -= delta
	if Game.world.has_line(global_position, dest):
		_path = []
		var sep = Game.world.separation(self)
		return ((dest - global_position).normalized() + sep * 0.6)
	if _repath <= 0.0 or _path.is_empty():
		_repath = 0.6
		_path = Game.world.find_path(global_position, dest)
		_path_i = 0
	while _path_i < _path.size() and global_position.distance_to(_path[_path_i]) < 0.8:
		_path_i += 1
	if _path_i < _path.size():
		return (_path[_path_i] - global_position).normalized()
	return (dest - global_position).normalized()

func _attack() -> void:
	var atk: Dictionary = rec.get("attack", {})
	_attack_ready = time_now() + float(atk.get("cooldown", 1.4)) * randf_range(0.9, 1.2) / (1.3 if has_affix("fast") else 1.0)
	var windup = float(atk.get("windup", 0.45))
	var anim_name = atk.get("anim", "1H_Melee_Attack_Chop")
	if anim_name is Array:
		anim_name = anim_name[randi() % anim_name.size()]
	face_towards(target.global_position)
	play(str(anim_name), windup + 0.35, float(atk.get("anim_speed", 1.0)), true)
	var t_ref = weakref(target)
	if atk.has("projectile"):
		after(windup, func():
			var t = t_ref.get_ref()
			if is_instance_valid(self) and alive and is_instance_valid(t):
				var dir = (t.global_position - global_position)
				dir.y = 0
				Game.world.spawn_projectile(self, dir.normalized(), atk.projectile, 1.0, atk.get("element", "physical"), [], Color("#ff2b2b")))
		return
	# Melee: short telegraph flash on the monster, then hit if still in range/arc
	flash(Color(1, 0.3, 0.2), 0.35)
	after(windup, func():
		var t = t_ref.get_ref()
		if not (is_instance_valid(self) and alive and is_instance_valid(t) and t.alive):
			return
		var r = float(atk.get("range", 1.6)) + t.radius + 0.4
		var to = t.global_position - global_position
		to.y = 0
		if to.length() <= r and facing.angle_to(to.normalized()) < deg_to_rad(float(atk.get("angle", 100.0)) * 0.5 + 15.0):
			Game.world.monster_hit(self, t, float(atk.get("mult", 1.0)), atk.get("element", "physical"))
			Sfx.play("hit_player", -6.0))

func _try_abilities(dist: float) -> bool:
	if anim_locked():
		return false
	for ab in rec.get("abilities", []):
		var id: String = ab.get("id", "ab")
		if _phase_locked.has(id) or time_now() < float(_ability_ready.get(id, 0.0)):
			continue
		if dist > float(ab.get("range", 8.0)) or dist < float(ab.get("min_range", 0.0)):
			continue
		if float(ab.get("life_below", 1.0)) < life / max_life:
			continue
		_ability_ready[id] = time_now() + float(ab.get("cooldown", 6.0))
		_use_ability(ab)
		return true
	return false

func _use_ability(ab: Dictionary) -> void:
	var tel = max(float(ab.get("telegraph", 1.0)), float(Game.tier().get("min_telegraph", 0.8)))
	play(ab.get("anim", "Spellcast_Raise"), tel + 0.3, 1.0, true)
	var pos: Vector3 = target.global_position if target else global_position
	match str(ab.get("type", "slam")):
		"slam":
			var at: Vector3 = global_position if ab.get("at", "target") == "self" else pos
			var r = float(ab.get("radius", 3.0))
			Fx.telegraph(at, r, tel, Color("#ff2b2b"))
			after(tel, func():
				if not (is_instance_valid(self) and alive):
					return
				Fx.ring(at, r, Color(1, 0.4, 0.2), 0.4)
				Fx.burst(at + Vector3(0, 0.3, 0), Color(0.6, 0.5, 0.45), 20, 5.0, 0.2, 0.5)
				Fx.shake(0.3)
				Sfx.play("slam", -2.0)
				var p: Actor = Game.world.player
				if p and p.alive and p.global_position.distance_to(at) <= r + p.radius:
					Game.world.monster_hit(self, p, float(ab.get("mult", 2.0)), ab.get("element", "physical")))
		"volley":
			var n = int(ab.get("count", 5))
			after(tel * 0.5, func():
				if not (is_instance_valid(self) and alive):
					return
				var base_dir = (pos - global_position)
				base_dir.y = 0
				base_dir = base_dir.normalized() if base_dir.length() > 0.1 else facing
				var spread = float(ab.get("spread", 50.0))
				for i in n:
					var a = lerpf(-spread, spread, float(i) / max(1, n - 1))
					Game.world.spawn_projectile(self, base_dir.rotated(Vector3.UP, deg_to_rad(a)), ab.get("projectile", {}), float(ab.get("mult", 0.8)), ab.get("element", "shadow"), [], Color("#ff2b2b")))
		"nova_ring":
			# Expanding ring of projectiles around the caster
			var n = int(ab.get("count", 12))
			after(tel, func():
				if not (is_instance_valid(self) and alive):
					return
				for i in n:
					var dir = Vector3.FORWARD.rotated(Vector3.UP, TAU * i / n)
					Game.world.spawn_projectile(self, dir, ab.get("projectile", {"speed": 7.0, "range": 12.0}), float(ab.get("mult", 0.7)), ab.get("element", "shadow"), [], Color("#ff2b2b")))
		"summon":
			after(tel, func():
				if not (is_instance_valid(self) and alive):
					return
				for i in int(ab.get("count", 3)):
					var off = Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
					Game.world.spawn_monster(str(ab.monster), global_position + off, level, "normal"))
		"charge":
			var dest: Vector3 = pos
			Fx.telegraph(global_position.lerp(dest, 0.5), 1.2, tel, Color("#ff2b2b"))
			after(tel, func():
				if not (is_instance_valid(self) and alive):
					return
				var start = global_position
				var end: Vector3 = Game.world.clamp_to_walkable(start, start + (dest - start).normalized() * float(ab.get("distance", 8.0)))
				play("Running_B", 0.5, 2.0, true)
				var tw = create_tween()
				tw.tween_property(self, "global_position", end, 0.35)
				await tw.finished
				if not is_instance_valid(self):
					return
				var p: Actor = Game.world.player
				if p and p.alive and Geometry3D.get_closest_point_to_segment(p.global_position, start, end).distance_to(p.global_position) < 1.4:
					Game.world.monster_hit(self, p, float(ab.get("mult", 1.8)), "physical")
					p.apply_knockback(global_position, 10.0)
				Fx.shake(0.25))
		"heal_allies":
			after(tel, func():
				if not (is_instance_valid(self) and alive):
					return
				for m in Game.world.monsters_near(global_position, float(ab.get("radius", 7.0))):
					Game.world.heal_actor(m, m.max_life * float(ab.get("pct", 0.2)))
				Fx.ring(global_position, float(ab.get("radius", 7.0)), Color(0.4, 1, 0.5), 0.6))
		"teleport":
			after(tel * 0.5, func():
				if not (is_instance_valid(self) and alive):
					return
				Fx.soul_puff(global_position, Color(0.6, 0.4, 1.0))
				var off = Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
				global_position = Game.world.clamp_to_walkable(global_position, global_position + off)
				Fx.soul_puff(global_position, Color(0.6, 0.4, 1.0)))

func has_affix(id: String) -> bool:
	return elite_affixes.has(id)

# ------------------------------------------------------------------ flee AI (Magpie Imp)
func _flee(dist: float, delta: float) -> Vector3:
	if _flee_started < 0.0:
		_flee_started = time_now()
		Events.toast.emit("It's running — catch it!", Color("#ffd84a"))
		Sfx.play("magpie_laugh")
	if time_now() - _flee_started > float(rec.get("escape_after", 20.0)):
		_escape()
		return Vector3.ZERO
	if dist > float(rec.get("flee_range", 10.0)):
		return Vector3.ZERO
	# Pick a walkable point away from the player; re-pick when reached or cornered
	var away = global_position - target.global_position
	away.y = 0
	if _flee_dest == Vector3.ZERO or global_position.distance_to(_flee_dest) < 1.2 or _flee_dest.distance_to(target.global_position) < 4.0:
		var best = global_position
		var best_score = -1e9
		for i in 8:
			var dir = away.normalized().rotated(Vector3.UP, deg_to_rad(-120 + i * 34.0)) if away.length() > 0.1 else Vector3.FORWARD.rotated(Vector3.UP, i * 0.8)
			var cand: Vector3 = Game.world.clamp_to_walkable(global_position, global_position + dir * 7.0)
			var score = cand.distance_to(target.global_position) + cand.distance_to(global_position) * 0.5
			if score > best_score:
				best_score = score
				best = cand
		_flee_dest = best
	return _steer_to(_flee_dest, delta)

## Escapes through a little portal: no loot (the chase is the fun; it will be back another time).
func _escape() -> void:
	if escaped or not alive:
		return
	escaped = true
	alive = false
	collision_layer = 0
	Fx.ring(global_position, 1.5, Color("#ffd84a"), 0.6)
	Fx.burst(global_position + Vector3(0, 0.8, 0), Color("#ffd84a"), 30, 5.0, 0.12, 0.8, 2.0)
	Fx.flash_light(global_position + Vector3(0, 1, 0), Color("#ffd84a"), 3.0, 0.6)
	Events.toast.emit("The %s escaped through a shimmering portal!" % display_name, Color("#ffd84a"))
	Sfx.play("portal", -2.0)
	if Game.world:
		Game.world.remove_monster(self)
	var t = create_tween()
	t.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)

## Sparkle trail for treasure monsters (presentation only).
func add_sparkle_trail(col := Color("#ffd84a")) -> void:
	var p = CPUParticles3D.new()
	p.amount = 24
	p.lifetime = 0.9
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 60.0
	p.gravity = Vector3(0, -1.5, 0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.2
	p.scale_amount_min = 0.04
	p.scale_amount_max = 0.1
	var sm = SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 4
	sm.rings = 2
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 3.0
	sm.material = m
	p.mesh = sm
	p.position.y = 0.7
	add_child(p)
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = 1.4
	l.omni_range = 4.0
	l.position.y = 1.2
	l.shadow_enabled = false
	add_child(l)

# ------------------------------------------------------------------ boss phases
## monsters[].phases: [{life_below, abilities_add[], speed_mult, dmg_mult, announce, anim}]
func _check_phase() -> void:
	var phases: Array = rec.get("phases", [])
	while phase < phases.size() and life / max_life <= float(phases[phase].get("life_below", 0.5)):
		var ph: Dictionary = phases[phase]
		phase += 1
		var list: Array = rec.get("abilities", []).duplicate()
		for ab in ph.get("abilities_add", []):
			if ab is Dictionary:
				list.append(ab)
			elif ab is String and _phase_locked.has(ab):
				_phase_locked.erase(ab)   # own ability, unlocked by this phase
			elif ab is String:
				# reference an ability of another monster record: "monster_id/ability_id"
				var parts = ab.split("/")
				if parts.size() == 2:
					for a2 in Content.get_rec("monsters", parts[0]).get("abilities", []):
						if a2.get("id", "") == parts[1]:
							list.append(a2)
		rec = rec.duplicate()
		rec["abilities"] = list
		move_speed *= float(ph.get("speed_mult", 1.0))
		if ph.has("dmg_mult"):
			rec["dmg_mult"] = float(rec.get("dmg_mult", 1.0)) * float(ph.dmg_mult)
		_attack_ready = time_now() + 1.2
		play(str(ph.get("anim", "Cheer")), 1.1, 1.0, true)
		flash(Color(1, 0.5, 0.3), 1.0)
		Fx.ring(global_position, 6.0, Color("#ff2b2b"), 0.8)
		Fx.shake(0.5)
		Sfx.play("boss_roar")
		Events.boss_phase.emit(self, phase)
		Events.toast.emit(str(ph.get("announce", "%s grows furious!" % display_name)), Color("#ff8a5a"))

# ------------------------------------------------------------------ elite visuals
func add_shield_bubble() -> void:
	if _shield_fx:
		return
	_shield_fx = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 16
	sm.rings = 8
	_shield_fx.mesh = sm
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(0.45, 0.75, 1.0, 0.18)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.rim_enabled = true
	_shield_fx.material_override = m
	_shield_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sc = float(rec.get("scale", 1.0)) * 1.1
	_shield_fx.scale = Vector3(sc * 0.9, sc * 1.1, sc * 0.9)
	_shield_fx.position.y = 0.9 * sc
	add_child(_shield_fx)

func shield_active() -> bool:
	return has_affix("shielded") and life > max_life * 0.5

func _update_shield() -> void:
	if _shield_fx and not shield_active():
		Fx.burst(global_position + Vector3(0, 1, 0), Color(0.5, 0.8, 1.0), 24, 5.0, 0.1, 0.5)
		Sfx.play("shield_block", -2.0)
		_shield_fx.queue_free()
		_shield_fx = null
	elif _shield_fx:
		var mat: StandardMaterial3D = _shield_fx.material_override
		mat.albedo_color.a = 0.45
		create_tween().tween_property(mat, "albedo_color:a", 0.18, 0.2)

func on_damaged(amount: float, crit: bool, source: Node) -> void:
	super.on_damaged(amount, crit, source)
	if healthbar and healthbar.has_method("set_value"):
		healthbar.set_value(life / max_life)
	if _shield_fx:
		_update_shield()
	if alive and not rec.get("phases", []).is_empty():
		_check_phase()
	# Treasure monsters spill coins while being hit (throttled)
	if alive and rec.get("ai", "") == "flee" and time_now() >= _coin_cd and Game.world:
		_coin_cd = time_now() + 0.3
		Game.world.spill_coins(self)
	if alive and not anim_locked() and kind in ["normal", "minion"] and amount > max_life * 0.15:
		play("Hit_A", 0.25, 1.5, true)
	if source is Actor and target == null:
		target = source

func _die(killer: Node) -> void:
	_anim_lock_until = 999999.0
	collision_layer = 0
	var death: String = rec.get("death_anim", "Death_A")
	if anim and anim.has_animation(death):
		anim.play(death, 0.05, 1.3)
	super._die(killer)
