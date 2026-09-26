class_name Player
extends Actor
## The hero. Driven by intents (move vector, cast requests) so input source is swappable
## (touch, keyboard, bot, network).

var ch: CharacterData
var resource = 0.0
var cooldowns = {}               # skill_id -> ready_time
var intent_move = Vector3.ZERO
var intent_cast = []             # queue of {skill, pos}
var auto_attack = false
var _regen_acc = 0.0
var potion_ready_at = 0.0
var invuln_until = 0.0
var basic_skill = ""
var _step_timer = 0.0
var hero_light: OmniLight3D
var _skill_cache = {}            # skill_id -> resolved skill (modifiers + mastery applied)
var _gear_props: Array = []      # attached weapon/off-hand prop nodes
var _tinted: Array = []          # [MeshInstance3D] with rarity tint overrides
# Mount state
var mounted = false
var wants_mount = false          # player chose to ride (auto-remount only if true)
var mount_visual: Node3D
var _last_combat = -99.0
var _mount_check = 0.0
# Channel (hearth etc.)
var _channel = {}                # {what, t, dur, cb}
var _walked = 0.0
var _step_sfx = "step"
var _aura: CPUParticles3D

func setup(c: CharacterData) -> void:
	ch = c
	faction = "player"
	var cls = ch.cls()
	display_name = ch.name
	radius = 0.45
	setup_model(cls.get("model", "res://assets/thirdparty/kaykit/adventurers/characters/Knight.glb"), 1.0, Color(1, 1, 1, 1), Color(cls.get("rim", "#ffd9a0")))
	show_only_attachments(cls.get("attachments", []))
	element_color = Color(cls.get("color", "#ffd27a"))
	basic_skill = cls.get("basic_attack", "")
	stats = ch.stats
	sync_from_character()
	life = max_life
	resource = ch.max_resource() * float(cls.get("resource_start", 1.0))
	collision_layer = 4
	collision_mask = 1
	# Hero light: the "last flame" — keeps the hero readable in dark zones.
	var l = OmniLight3D.new()
	l.light_color = Color(1.0, 0.78, 0.5)
	l.light_energy = 1.6
	l.omni_range = 9.0
	l.omni_attenuation = 1.2
	l.position = Vector3(0, 2.6, 0)
	l.shadow_enabled = false
	add_child(l)
	hero_light = l
	if Game.world and "biome" in Game.world:
		var surf = str(Game.world.biome.get("surface", ""))
		if surf != "":
			_step_sfx = "step_" + surf
	ch.stats.remove_source("mount")
	refresh_gear()
	refresh_companion_light()
	if not Events.equipment_changed.is_connected(_on_equipment_changed):
		Events.equipment_changed.connect(_on_equipment_changed)

func _on_equipment_changed() -> void:
	if is_inside_tree():
		sync_from_character()

## "glow" pet perk: bigger hero light.
func refresh_companion_light() -> void:
	if hero_light == null:
		return
	var m = 1.0
	if Pets.perk(ch) == "glow":
		m = float(Pets.perk_param(ch, "light_mult", 1.4))
	hero_light.omni_range = 9.0 * m
	hero_light.light_energy = 1.6 * (1.0 + (m - 1.0) * 0.5)

## The skill as this hero executes it (modifiers + mastery). Cached; cleared on sync.
func skill_def(skill_id: String) -> Dictionary:
	if not _skill_cache.has(skill_id):
		_skill_cache[skill_id] = SkillMods.resolve(ch, skill_id)
	return _skill_cache[skill_id]

# ------------------------------------------------------------------ visible gear (GDD v2.1 #20)
const GEAR_HANDS := ["handslot.r", "handslot.l"]

## Shows the equipped main-/off-hand props instead of the class default weapons (hats/capes stay),
## and tints cape/helmet subtly with the chest/head item rarity colour.
func refresh_gear() -> void:
	if model == null:
		return
	var skel: Skeleton3D = model.find_child("Skeleton3D", true, false)
	if skel == null:
		return
	for p in _gear_props:
		if is_instance_valid(p):
			p.queue_free()
	_gear_props.clear()
	var mh = ch.equipment.get("main_hand")
	var oh = ch.equipment.get("off_hand")
	var has_weapon = (mh is Dictionary and not mh.is_empty()) or (oh is Dictionary and not oh.is_empty())
	var keep: Array = ch.cls().get("attachments", [])
	var bones = {}
	for ba in skel.find_children("*", "BoneAttachment3D", true, false):
		var bone = String((ba as BoneAttachment3D).bone_name).to_lower()
		bones[bone] = ba
		for child in ba.get_children():
			if child.has_meta("gear_prop"):
				continue
			var n = String(child.name).to_lower()
			var is_hand = GEAR_HANDS.has(bone)
			var show = false
			for k in keep:
				if n == String(k).to_lower():
					show = true
			if is_hand and has_weapon:
				show = false
			child.visible = show
	if has_weapon:
		for pair in [[mh, "handslot.r"], [oh, "handslot.l"]]:
			var it = pair[0]
			if not (it is Dictionary) or it.is_empty():
				continue
			var path = Weapons.prop_path(it)
			var bone = str(Weapons.type_rec(Weapons.item_type(it)).get("attach", pair[1])) if pair[1] == "handslot.r" else pair[1]
			if path == "" or not ResourceLoader.exists(path) or not bones.has(bone):
				continue
			if not _scene_cache.has(path):
				_scene_cache[path] = load(path)
			var prop: Node3D = _scene_cache[path].instantiate()
			prop.set_meta("gear_prop", true)
			bones[bone].add_child(prop)
			_gear_props.append(prop)
			if _overlay_mats.size() > 0:
				for mi in prop.find_children("*", "MeshInstance3D", true, false):
					(mi as MeshInstance3D).material_overlay = _overlay_mats[0]
			if Items.rarity_index(str(it.get("rarity", "common"))) >= 4:
				_tint_node(prop, Items.rarity_color(it.rarity), 0.18)
	_apply_armor_tints(bones)
	_apply_cosmetics(bones)

const AURA_COLORS := {"ember": "#ff9a3c", "frost": "#8fd8ff", "holy": "#fff1a8", "shadow": "#a07bff", "verdant": "#7dff9a", "rose": "#ff8fc8"}

## Cosmetic value → colour: a `cosmetics` record id (its color), a named aura, or a hex colour.
static func cosmetic_color(v, fallback := Color(1, 0.85, 0.5)) -> Color:
	var sv = str(v)
	var crec = Content.get_rec("cosmetics", sv)
	if crec.has("color"):
		return Color(str(crec.color))
	if AURA_COLORS.has(sv):
		return Color(AURA_COLORS[sv])
	if sv.begins_with("#") or sv.is_valid_html_color():
		return Color(sv)
	return fallback

## Deed cosmetics: cape tint (overrides the rarity tint), aura ring at the feet.
func _apply_cosmetics(bones: Dictionary) -> void:
	var cos: Dictionary = ch.cosmetics
	if cos.has("cape_tint") and bones.has("chest"):
		_tint_node(bones["chest"], cosmetic_color(cos.cape_tint), 0.6)
	if _aura and is_instance_valid(_aura):
		_aura.queue_free()
		_aura = null
	if cos.has("aura") and str(cos.aura) != "":
		var col = cosmetic_color(cos.aura)
		_aura = CPUParticles3D.new()
		_aura.amount = 20
		_aura.lifetime = 1.2
		_aura.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		_aura.emission_ring_axis = Vector3.UP
		_aura.emission_ring_radius = 0.7
		_aura.emission_ring_inner_radius = 0.55
		_aura.emission_ring_height = 0.05
		_aura.direction = Vector3.UP
		_aura.spread = 10.0
		_aura.gravity = Vector3(0, 0.8, 0)
		_aura.initial_velocity_min = 0.2
		_aura.initial_velocity_max = 0.5
		_aura.scale_amount_min = 0.04
		_aura.scale_amount_max = 0.08
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
		m.emission_energy_multiplier = 2.5
		sm.material = m
		_aura.mesh = sm
		_aura.position.y = 0.05
		add_child(_aura)

func _apply_armor_tints(bones: Dictionary) -> void:
	for mi in _tinted:
		if is_instance_valid(mi):
			for si in (mi as MeshInstance3D).get_surface_override_material_count():
				(mi as MeshInstance3D).set_surface_override_material(si, null)
	_tinted.clear()
	for pair in [["chest", "chest"], ["head", "head"]]:
		var it = ch.equipment.get(pair[0])
		if not (it is Dictionary) or not bones.has(pair[1]):
			continue
		var rank = Items.rarity_index(str(it.get("rarity", "common")))
		if rank <= 0:
			continue
		_tint_node(bones[pair[1]], Items.rarity_color(it.rarity), 0.12 + 0.05 * min(rank, 5))

func _tint_node(n: Node, col: Color, amount: float) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var mo = (mi as MeshInstance3D).material_override
		if mo is StandardMaterial3D:
			var om: StandardMaterial3D = mo.duplicate()
			om.albedo_color = om.albedo_color.lerp(col, amount)
			(mi as MeshInstance3D).material_override = om
			continue
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for si in mesh.get_surface_count():
			var base = mesh.surface_get_material(si)
			if base is StandardMaterial3D:
				var m: StandardMaterial3D = base.duplicate()
				m.albedo_color = m.albedo_color.lerp(col, amount)
				(mi as MeshInstance3D).set_surface_override_material(si, m)
		_tinted.append(mi)

func sync_from_character() -> void:
	ch.recalc()
	_skill_cache.clear()
	if model:
		refresh_gear()
		refresh_companion_light()
	stats = ch.stats
	level = ch.level
	var ratio = life / max_life if max_life > 0 else 1.0
	max_life = ch.max_life()
	life = clampf(max_life * ratio, 1.0, max_life)
	move_speed = 5.2
	Events.health_changed.emit(life, max_life)
	Events.resource_changed.emit(resource, ch.max_resource())

func on_buff_changed() -> void:
	var ml = ch.max_life()
	max_life = ml
	Events.health_changed.emit(life, max_life)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	_regen(delta)
	_update_channel(delta)
	_update_mount(delta)
	var v = Vector3.ZERO
	if can_act() and not anim_locked():
		v = intent_move * move_speed * speed_mult()
	var kb = _integrate_knockback(delta)
	velocity = v + kb
	var before = global_position
	move_and_slide()
	global_position.y = 0.0
	_walked += Vector2(global_position.x - before.x, global_position.z - before.z).length()
	if _walked >= 10.0:
		ch.track("distance", int(_walked))
		_walked -= float(int(_walked))
	if intent_move.length() > 0.1 and can_act() and not anim_locked():
		face_towards(global_position + intent_move)
		play("Sit_Chair_Idle" if mounted and anim and anim.has_animation("Sit_Chair_Idle") else "Running_A", 0, clampf(speed_mult(), 0.8, 1.4))
		if mount_visual:
			if mount_visual.has_method("set_moving"):
				mount_visual.set_moving(true)
			else:
				mount_visual.position.y = absf(sin(time_now() * 10.0)) * 0.08
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.32
			Sfx.play(_step_sfx, -14.0, 0.15)
	elif not anim_locked():
		if mount_visual and mount_visual.has_method("set_moving"):
			mount_visual.set_moving(false)
		if mounted and anim and anim.has_animation("Sit_Chair_Idle"):
			play("Sit_Chair_Idle")
		elif not _channel.is_empty() and anim and anim.has_animation("Spellcasting"):
			play("Spellcasting")
		else:
			play(ch.cls().get("idle_anim", "Idle"))
	_process_casts()
	if (auto_attack or Settings.get_value("auto_attack", false)) and intent_cast.is_empty() and intent_move.length() < 0.1:
		var t = Game.world.nearest_enemy(self, global_position, 7.0, [])
		if t:
			request_cast(basic_skill, t.global_position)

func _regen(delta: float) -> void:
	_regen_acc += delta
	if _regen_acc < 0.25:
		return
	var dt = _regen_acc
	_regen_acc = 0.0
	var cls = ch.cls()
	var rmax = ch.max_resource()
	var regen = float(cls.get("resource_regen", 0.0)) + stats.get_stat("resource_regen")
	var decay = float(cls.get("resource_decay", 0.0))
	resource = clampf(resource + (regen - decay) * dt, 0.0, rmax)
	var lr = stats.get_stat("life_regen") + max_life * 0.004
	if life < max_life:
		life = min(max_life, life + lr * dt)
		Events.health_changed.emit(life, max_life)
	Events.resource_changed.emit(resource, rmax)

func gain_resource(amount: float) -> void:
	resource = clampf(resource + amount, 0.0, ch.max_resource())
	Events.resource_changed.emit(resource, ch.max_resource())

func skill_rank(skill_id: String) -> int:
	if skill_id == basic_skill:
		return max(1, int(ch.skill_ranks.get(skill_id, 1)))
	return int(ch.skill_ranks.get(skill_id, 0)) + int(stats.get_stat("skill_rank:" + skill_id))

func cooldown_left(skill_id: String) -> float:
	return max(0.0, float(cooldowns.get(skill_id, 0.0)) - time_now())

func cooldown_total(skill: Dictionary) -> float:
	return float(skill.get("cooldown", 0.0)) * (1.0 - clampf(stats.get_stat("cdr_pct"), 0.0, 50.0) / 100.0)

func request_cast(skill_id: String, pos: Vector3) -> void:
	if skill_id == "":
		return
	if intent_cast.size() < 2:
		intent_cast.append({"skill": skill_id, "pos": pos})

func can_cast(skill_id: String) -> bool:
	var s = skill_def(skill_id)
	if s.is_empty() or skill_rank(skill_id) <= 0:
		return false
	if cooldown_left(skill_id) > 0.0:
		return false
	return resource >= float(s.get("cost", 0.0))

func _process_casts() -> void:
	if intent_cast.is_empty() or not can_act() or anim_locked():
		return
	var req = intent_cast.pop_front()
	var s = skill_def(req.skill)
	if not can_cast(req.skill):
		if resource < float(s.get("cost", 0.0)):
			Events.toast.emit("Not enough " + str(ch.cls().get("resource_name", "power")), Color(0.6, 0.7, 1.0))
		return
	var pos: Vector3 = req.pos
	# Auto-aim: snap to the best target near the requested point
	if s.get("targeted", true):
		var t = Game.world.nearest_enemy(self, pos, float(s.get("aim_assist", 4.0)), [])
		if t == null:
			t = Game.world.nearest_enemy(self, global_position, float(s.get("range", 8.0)), [])
		if t:
			pos = t.global_position
	_last_combat = time_now()
	if mounted:
		dismount("cast")
	if not _channel.is_empty():
		cancel_channel()
	resource -= float(s.get("cost", 0.0))
	resource = min(ch.max_resource(), resource + float(s.get("generate", 0.0)))
	Events.resource_changed.emit(resource, ch.max_resource())
	cooldowns[req.skill] = time_now() + cooldown_total(s)
	face_towards(pos)
	var aps = float(ch.weapon().get("aps", 1.2)) * (1.0 + stats.get_stat("attack_speed_pct") / 100.0)
	var speed = clampf(aps / 1.2, 0.6, 2.2) if req.skill == basic_skill else 1.0 + stats.get_stat("cast_speed_pct") / 100.0
	var lock = float(s.get("lock", 0.35)) / speed
	var anims = s.get("anim", "1H_Melee_Attack_Chop")
	# Weapon-driven attack set (1h/2h/ranged/caster/dual) unless the skill forces its own animation
	if not s.get("anim_force", false) and (s.get("tags", []).has("basic") or not s.has("anim")):
		var wa = Weapons.attack_anims(ch)
		if not wa.is_empty():
			anims = wa
	if anims is Array:
		anims = anims[randi() % anims.size()]
	play(str(anims), lock, float(s.get("anim_speed", 1.3)) * speed, true)
	Sfx.play(s.get("sfx", "swing"), -4.0)
	ch.track("skills_cast")
	Events.skill_cast.emit(req.skill)
	var windup = float(s.get("windup", 0.12)) / speed
	get_tree().create_timer(windup, false).timeout.connect(func():
		if is_instance_valid(self) and alive:
			SkillEffects.execute(self, s, skill_rank(req.skill), pos))

func use_potion() -> void:
	if ch.potions <= 0 or time_now() < potion_ready_at or not alive:
		return
	ch.potions -= 1
	potion_ready_at = time_now() + 1.0
	Game.world.heal_actor(self, max_life * float(Content.get_rec("consumables", ch.potion_kind).get("effect", {}).get("heal_pct", 0.45)))
	ch.track("potions_used")
	Sfx.play("potion")
	Fx.burst(global_position + Vector3(0, 1, 0), Color(1, 0.3, 0.35), 16, 2.0, 0.12, 0.8, 2.0)

func on_damaged(amount: float, crit: bool, source: Node) -> void:
	if time_now() < invuln_until:
		return
	_last_combat = time_now()
	if mounted:
		dismount("hit")
	if not _channel.is_empty():
		cancel_channel()
	super.on_damaged(amount, crit, source)
	Events.health_changed.emit(life, max_life)
	if amount > max_life * 0.08:
		Fx.shake(0.25)
	if alive and amount > max_life * 0.12 and not anim_locked():
		play("Hit_A", 0.2, 1.4, true)

func _die(killer: Node) -> void:
	play("Death_A", 99.0, 1.0, true)
	Sfx.play("player_death")
	Events.player_died.emit()
	super._die(killer)

func revive() -> void:
	alive = true
	life = max_life
	resource = ch.max_resource() * 0.5
	invuln_until = time_now() + 2.0
	_anim_lock_until = 0.0
	play("Idle", 0, 1, true)
	Events.health_changed.emit(life, max_life)

# ------------------------------------------------------------------ mounts (GDD v2.1 #22)
func in_combat() -> bool:
	if time_now() - _last_combat < Mounts.remount_delay():
		return true
	if Game.world:
		for m in Game.world.monsters_near(global_position, 9.0):
			if m.target == self and m.kind != "minion":
				return true
	return false

func mount() -> bool:
	if mounted or ch.active_mount == "" or not alive:
		return false
	if in_combat():
		Events.toast.emit("Can't mount during a fight", Color(0.8, 0.8, 0.9))
		return false
	mounted = true
	wants_mount = true
	ch.stats.set_source("mount", {"move_speed_pct": Mounts.speed_pct(ch)})
	mount_visual = Mounts.make_visual(ch.active_mount)
	add_child(mount_visual)
	if ch.cosmetics.has("mount_tint"):
		_tint_node(mount_visual, cosmetic_color(ch.cosmetics.mount_tint), 0.5)
	mount_visual.rotation.y = 0.0
	var seat = float(Mounts.rec(ch.active_mount).get("seat_height", 0.55))
	var saddle = mount_visual.find_child("Saddle", true, false)
	if saddle is Node3D and not Mounts.rec(ch.active_mount).has("seat_height"):
		seat = (saddle as Node3D).global_position.y - global_position.y
	if model:
		model.position.y = seat
	Fx.burst(global_position + Vector3(0, 0.5, 0), Color(0.9, 0.8, 0.6), 12, 3.0, 0.12, 0.5)
	Sfx.play("mount", -4.0)
	Events.mount_changed.emit(true)
	return true

func dismount(reason := "manual") -> void:
	if not mounted:
		return
	mounted = false
	if reason == "manual":
		wants_mount = false
	ch.stats.remove_source("mount")
	if mount_visual and is_instance_valid(mount_visual):
		mount_visual.queue_free()
	mount_visual = null
	if model:
		model.position.y = 0.0
	Fx.burst(global_position + Vector3(0, 0.5, 0), Color(0.9, 0.8, 0.6), 8, 2.5, 0.1, 0.4)
	Sfx.play("dismount", -6.0)
	Events.mount_changed.emit(false)

func toggle_mount() -> bool:
	if mounted:
		dismount("manual")
		return false
	return mount()

func _update_mount(delta: float) -> void:
	_mount_check -= delta
	if _mount_check > 0.0:
		return
	_mount_check = 0.5
	for b in ch.buffs:
		if float(ch.buffs[b].get("until", 0.0)) <= ch.play_seconds:
			sync_from_character()   # an elixir ran out
			break
	if mounted:
		# keep the speed bonus current (mount feed can expire)
		ch.stats.set_source("mount", {"move_speed_pct": Mounts.speed_pct(ch)})
	elif wants_mount and ch.active_mount != "" and Settings.get_value("auto_mount", true) and not in_combat() and _channel.is_empty():
		mount()

# ------------------------------------------------------------------ channel (Homeward Wick etc.)
## Starts a channel; cancelled by moving, casting or being hit. `cb` runs on completion.
func start_channel(what: String, duration: float, cb: Callable) -> bool:
	if not alive or not _channel.is_empty():
		return false
	_channel = {"what": what, "t": 0.0, "dur": max(0.1, duration), "cb": cb, "grace": 0.25}
	intent_move = Vector3.ZERO
	Fx.ring(global_position, 1.6, Color(1, 0.8, 0.45), duration, false)
	Sfx.play(what + "_channel", -4.0)
	Events.channel_progress.emit(what, 0.0)
	return true

func cancel_channel() -> void:
	if _channel.is_empty():
		return
	var what = _channel.what
	_channel = {}
	Events.channel_progress.emit(what, -1.0)
	Events.toast.emit("Interrupted", Color(0.85, 0.85, 0.9))

func is_channeling() -> bool:
	return not _channel.is_empty()

func _update_channel(delta: float) -> void:
	if _channel.is_empty():
		return
	_channel.grace = float(_channel.grace) - delta
	if intent_move.length() > 0.1 and float(_channel.grace) <= 0.0:
		cancel_channel()
		return
	_channel.t = float(_channel.t) + delta
	var f = clampf(float(_channel.t) / float(_channel.dur), 0.0, 1.0)
	Events.channel_progress.emit(_channel.what, f)
	if f >= 1.0:
		var cb: Callable = _channel.cb
		_channel = {}
		if cb.is_valid():
			cb.call()
