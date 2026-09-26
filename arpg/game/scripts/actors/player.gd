class_name Player
extends Actor
## The hero. Driven by intents (move vector, cast requests) so input source is swappable
## (touch, keyboard, bot, network).

var ch: CharacterData
var resource := 0.0
var cooldowns := {}               # skill_id -> ready_time
var intent_move := Vector3.ZERO
var intent_cast := []             # queue of {skill, pos}
var auto_attack := false
var _regen_acc := 0.0
var potion_ready_at := 0.0
var invuln_until := 0.0
var basic_skill := ""
var _step_timer := 0.0

func setup(c: CharacterData) -> void:
	ch = c
	faction = "player"
	var cls := ch.cls()
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
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.78, 0.5)
	l.light_energy = 1.6
	l.omni_range = 9.0
	l.omni_attenuation = 1.2
	l.position = Vector3(0, 2.6, 0)
	l.shadow_enabled = false
	add_child(l)

func sync_from_character() -> void:
	ch.recalc()
	stats = ch.stats
	level = ch.level
	var ratio := life / max_life if max_life > 0 else 1.0
	max_life = ch.max_life()
	life = clampf(max_life * ratio, 1.0, max_life)
	move_speed = 5.2
	Events.health_changed.emit(life, max_life)
	Events.resource_changed.emit(resource, ch.max_resource())

func on_buff_changed() -> void:
	var ml := ch.max_life()
	max_life = ml
	Events.health_changed.emit(life, max_life)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	_regen(delta)
	var v := Vector3.ZERO
	if can_act() and not anim_locked():
		v = intent_move * move_speed * speed_mult()
	var kb := _integrate_knockback(delta)
	velocity = v + kb
	move_and_slide()
	global_position.y = 0.0
	if intent_move.length() > 0.1 and can_act() and not anim_locked():
		face_towards(global_position + intent_move)
		play("Running_A", 0, clampf(speed_mult(), 0.8, 1.4))
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.32
			Sfx.play("step", -14.0, 0.15)
	elif not anim_locked():
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
	var dt := _regen_acc
	_regen_acc = 0.0
	var cls := ch.cls()
	var rmax := ch.max_resource()
	var regen := float(cls.get("resource_regen", 0.0)) + stats.get_stat("resource_regen")
	var decay := float(cls.get("resource_decay", 0.0))
	resource = clampf(resource + (regen - decay) * dt, 0.0, rmax)
	var lr := stats.get_stat("life_regen") + max_life * 0.004
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
	var s := Content.get_rec("skills", skill_id)
	if s.is_empty() or skill_rank(skill_id) <= 0:
		return false
	if cooldown_left(skill_id) > 0.0:
		return false
	return resource >= float(s.get("cost", 0.0))

func _process_casts() -> void:
	if intent_cast.is_empty() or not can_act() or anim_locked():
		return
	var req = intent_cast.pop_front()
	var s := Content.get_rec("skills", req.skill)
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
	resource -= float(s.get("cost", 0.0))
	resource = min(ch.max_resource(), resource + float(s.get("generate", 0.0)))
	Events.resource_changed.emit(resource, ch.max_resource())
	cooldowns[req.skill] = time_now() + cooldown_total(s)
	face_towards(pos)
	var aps := float(ch.weapon().get("aps", 1.2)) * (1.0 + stats.get_stat("attack_speed_pct") / 100.0)
	var speed := clampf(aps / 1.2, 0.6, 2.2) if req.skill == basic_skill else 1.0 + stats.get_stat("cast_speed_pct") / 100.0
	var lock := float(s.get("lock", 0.35)) / speed
	var anims = s.get("anim", "1H_Melee_Attack_Chop")
	if anims is Array:
		anims = anims[randi() % anims.size()]
	play(str(anims), lock, float(s.get("anim_speed", 1.3)) * speed, true)
	Sfx.play(s.get("sfx", "swing"), -4.0)
	Events.skill_cast.emit(req.skill)
	var windup := float(s.get("windup", 0.12)) / speed
	get_tree().create_timer(windup, false).timeout.connect(func():
		if is_instance_valid(self) and alive:
			SkillEffects.execute(self, s, skill_rank(req.skill), pos))

func use_potion() -> void:
	if ch.potions <= 0 or time_now() < potion_ready_at or not alive:
		return
	ch.potions -= 1
	potion_ready_at = time_now() + 1.0
	Game.world.heal_actor(self, max_life * 0.45)
	Sfx.play("potion")
	Fx.burst(global_position + Vector3(0, 1, 0), Color(1, 0.3, 0.35), 16, 2.0, 0.12, 0.8, 2.0)

func on_damaged(amount: float, crit: bool, source: Node) -> void:
	if time_now() < invuln_until:
		return
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
