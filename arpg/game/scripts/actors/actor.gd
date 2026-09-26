class_name Actor
extends CharacterBody3D
## Base for every combatant (player, monsters, minions). Presentation (model/anim/flash) + local
## combat state. Authoritative damage/death go through GameWorld so they can move server-side later.

signal died(actor: Actor)

var net_id := 0
var faction := "monster"          # "player" | "monster"
var level := 1
var stats := StatBlock.new()
var life := 100.0
var max_life := 100.0
var alive := true
var move_speed := 4.0
var radius := 0.5
var display_name := ""
var element_color := Color(1, 0.85, 0.5)

var model: Node3D
var anim: AnimationPlayer
var _overlay_mats: Array[ShaderMaterial] = []
var _current_anim := ""
var _anim_lock_until := 0.0
var knockback := Vector3.ZERO
var status := {}                  # id -> {until, value}
var facing := Vector3.FORWARD

const LOOPING := ["Idle", "Idle_B", "Idle_Combat", "Running_A", "Running_B", "Running_C", "Walking_A", "Walking_B", "Walking_C", "2H_Melee_Idle", "Unarmed_Idle", "Spellcasting", "Blocking", "Lie_Idle", "Sit_Floor_Idle", "Jump_Idle", "2H_Melee_Attack_Spinning"]

static var _scene_cache := {}

func _init() -> void:
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING

func time_now() -> float:
	return Time.get_ticks_msec() / 1000.0

## Load a glTF character, attach overlay (rim + flash) and outline materials.
func setup_model(path: String, scale_mult := 1.0, tint := Color(1, 1, 1, 1), rim := Color(0.55, 0.6, 0.9)) -> void:
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	var ps: PackedScene = _scene_cache[path]
	model = ps.instantiate()
	add_child(model)
	model.scale = Vector3.ONE * scale_mult
	anim = model.find_child("AnimationPlayer", true, false)
	if anim:
		for n in LOOPING:
			if anim.has_animation(n):
				anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		anim.playback_default_blend_time = 0.12
	var outline_mat := Fx.shader_mat("res://shaders/outline.gdshader", {"thickness": 0.012 / max(0.3, scale_mult)})
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := Fx.shader_mat("res://shaders/actor_overlay.gdshader", {"rim_color": rim})
		m.next_pass = outline_mat
		(mi as MeshInstance3D).material_overlay = m
		_overlay_mats.append(m)
		if tint != Color(1, 1, 1, 1):
			for si in (mi as MeshInstance3D).mesh.get_surface_count():
				var base = (mi as MeshInstance3D).mesh.surface_get_material(si)
				if base is StandardMaterial3D:
					var tm: StandardMaterial3D = base.duplicate()
					tm.albedo_color = tint
					(mi as MeshInstance3D).set_surface_override_material(si, tm)
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius * scale_mult
	cap.height = 1.6 * scale_mult
	shape.shape = cap
	shape.position.y = cap.height * 0.5
	add_child(shape)

## Hide all attachment meshes except those whose names contain one of `keep` (KayKit rigs ship
## with several weapons/shields attached to the hand bones).
func show_only_attachments(keep: Array) -> void:
	if model == null:
		return
	var skel := model.find_child("Skeleton3D", true, false)
	if skel == null:
		return
	for ba in skel.find_children("*", "BoneAttachment3D", true, false):
		for child in ba.get_children():
			var n := String(child.name).to_lower()
			var show := false
			for k in keep:
				if n.contains(String(k).to_lower()):
					show = true
			child.visible = show

func attach_prop(path: String, bone_hint := "handslot.r") -> void:
	if model == null or not ResourceLoader.exists(path):
		return
	var skel: Skeleton3D = model.find_child("Skeleton3D", true, false)
	if skel == null:
		return
	for ba in skel.find_children("*", "BoneAttachment3D", true, false):
		if String((ba as BoneAttachment3D).bone_name).to_lower() == bone_hint:
			var p = load(path).instantiate()
			ba.add_child(p)
			return

func play(name: String, lock := 0.0, speed := 1.0, force := false) -> void:
	if anim == null or not anim.has_animation(name):
		return
	if not force and time_now() < _anim_lock_until:
		return
	if name == _current_anim and not force and anim.is_playing():
		return
	_current_anim = name
	anim.play(name, -1, speed)
	if force:
		anim.seek(0.0, true)
	if lock > 0.0:
		_anim_lock_until = time_now() + lock

func anim_locked() -> bool:
	return time_now() < _anim_lock_until

func flash(color := Color.WHITE, strength := 0.9) -> void:
	for m in _overlay_mats:
		m.set_shader_parameter("flash_color", color)
		m.set_shader_parameter("flash", strength)
	var t := create_tween()
	t.tween_method(func(v):
		for m in _overlay_mats:
			m.set_shader_parameter("flash", v), strength, 0.0, 0.14)

func face_towards(point: Vector3) -> void:
	var d := point - global_position
	d.y = 0
	if d.length() > 0.05:
		facing = d.normalized()
		rotation.y = atan2(facing.x, facing.z)

func has_status(id: String) -> bool:
	return status.has(id) and float(status[id].until) > time_now()

func add_status(id: String, duration: float, value := 0.0) -> void:
	status[id] = {"until": time_now() + duration, "value": value}

func speed_mult() -> float:
	var m := 1.0 + stats.get_stat("move_speed_pct") / 100.0
	if has_status("slow"):
		m *= 1.0 - float(status.slow.value)
	if has_status("haste"):
		m *= 1.0 + float(status.haste.value)
	return clampf(m, 0.2, 2.5)

func can_act() -> bool:
	return alive and not has_status("stun") and not has_status("freeze")

func apply_knockback(from: Vector3, force: float) -> void:
	if has_status("unstoppable"):
		return
	var d := global_position - from
	d.y = 0
	if d.length() < 0.01:
		d = Vector3.FORWARD
	knockback += d.normalized() * force

func _integrate_knockback(delta: float) -> Vector3:
	var k := knockback
	knockback = knockback.move_toward(Vector3.ZERO, 30.0 * delta)
	return k

func hit_center() -> Vector3:
	return global_position + Vector3(0, 0.9, 0)

## Called by GameWorld after mitigation. Presentation + local state.
func on_damaged(amount: float, crit: bool, source: Node) -> void:
	life = max(0.0, life - amount)
	flash(Color(1, 1, 1) if faction == "monster" else Color(1, 0.3, 0.3))
	if life <= 0.0 and alive:
		alive = false
		_die(source)

func _die(_killer: Node) -> void:
	died.emit(self)

func heal(amount: float) -> void:
	if not alive:
		return
	life = min(max_life, life + amount)
