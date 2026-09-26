class_name Pet
extends Node3D
## Companion follower (presentation + perks that act in the world). Rules live in systems/pets.gd.
## Visual: pets[].model (glTF, scale, tint) or a procedural glowing wisp. Follows the player with an
## idle bob; "fetch" collects drops nearby; Stitcher-type classes (pet_combat) get light attacks.

var pet_id = ""
var rec = {}
var player: Player
var _visual: Node3D
var _t = 0.0
var _think = 0.0
var _fetch_target: Node3D = null
var _attack_cd = 0.0
var _away = false
var _flying = true
var _skip = {}          # drops the pet could not pick up (bag full)
var _anim: AnimationPlayer

static var _scene_cache := {}

func setup(id: String, p: Player) -> void:
	pet_id = id
	rec = Pets.rec(id)
	player = p
	name = "Pet"
	var tint = Color(rec.get("tint", "#ffd98a"))
	var model_path = str(rec.get("model", ""))
	if model_path != "" and ResourceLoader.exists(model_path):
		if not _scene_cache.has(model_path):
			_scene_cache[model_path] = load(model_path)
		_visual = _scene_cache[model_path].instantiate()
		_visual.scale = Vector3.ONE * float(rec.get("scale", 0.5))
		_flying = bool(rec.get("flying", false))
		_anim = _visual.find_child("AnimationPlayer", true, false)
		if rec.has("tint"):
			_tint_meshes(_visual, tint)
	else:
		_visual = make_wisp(tint, float(rec.get("scale", 1.0)))
		_flying = true
	add_child(_visual)
	top_level = true
	global_position = p.global_position + Vector3(1.0, 0, 1.0)

func _tint_meshes(n: Node, tint: Color) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for si in mesh.get_surface_count():
			var base = mesh.surface_get_material(si)
			if base is StandardMaterial3D:
				var m: StandardMaterial3D = base.duplicate()
				m.albedo_color = m.albedo_color * tint
				(mi as MeshInstance3D).set_surface_override_material(si, m)

## Procedural wisp: emissive core + soft halo + a few motes (no real light — light budget).
static func make_wisp(col: Color, sc: float) -> Node3D:
	var root = Node3D.new()
	var core = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	sm.radial_segments = 10
	sm.rings = 6
	core.mesh = sm
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col.lightened(0.4)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 3.0
	core.material_override = m
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(core)
	var halo = MeshInstance3D.new()
	var hm = SphereMesh.new()
	hm.radius = 0.3
	hm.height = 0.6
	hm.radial_segments = 10
	hm.rings = 6
	halo.mesh = hm
	var h = StandardMaterial3D.new()
	h.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	h.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	h.albedo_color = Color(col.r, col.g, col.b, 0.22)
	h.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo.material_override = h
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(halo)
	var p = CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 0.9
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 30.0
	p.gravity = Vector3(0, 0.6, 0)
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.2
	p.scale_amount_min = 0.03
	p.scale_amount_max = 0.07
	var pm = SphereMesh.new()
	pm.radius = 0.5
	pm.height = 1.0
	pm.radial_segments = 4
	pm.rings = 2
	pm.material = m
	p.mesh = pm
	root.add_child(p)
	root.scale = Vector3.ONE * sc
	return root

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_t += delta
	var ch = player.ch
	var away_now = Pets.ferry_status(ch).away
	if away_now != _away:
		_set_away(away_now)
	if _away:
		return
	_think -= delta
	if _think <= 0.0:
		_think = 0.3
		_pick_fetch_target()
	var dest: Vector3
	if _fetch_target and is_instance_valid(_fetch_target):
		dest = _fetch_target.global_position
		if Vector2(dest.x - global_position.x, dest.z - global_position.z).length() < 0.7:
			var d = _fetch_target
			_fetch_target = null
			if Game.world and not Game.world.pickup(d):
				_skip[d.get_instance_id()] = true
	else:
		_fetch_target = null
		var side = player.global_transform.basis.x
		dest = player.global_position - player.facing * 1.1 + side * 0.9
	var speed = 9.0 if _fetch_target else 4.5
	var flat = Vector3(dest.x, 0, dest.z)
	var cur = Vector3(global_position.x, 0, global_position.z)
	var dist = cur.distance_to(flat)
	if dist > 14.0:
		cur = flat   # teleport-catch-up after dashes/travel
	elif dist > 0.05:
		cur = cur.move_toward(flat, max(speed, dist * 3.0) * delta)
	var h = (1.1 + sin(_t * 3.0) * 0.15) if _flying else absf(sin(_t * 6.0)) * (0.08 if dist > 0.2 else 0.02)
	global_position = Vector3(cur.x, h, cur.z)
	if dist > 0.1:
		var look = flat - cur
		rotation.y = lerp_angle(rotation.y, atan2(look.x, look.z), clampf(delta * 8.0, 0.0, 1.0))
	if _anim:
		var want = "Running_A" if dist > 0.4 and not _flying else "Idle"
		if _anim.has_animation(want) and _anim.current_animation != want:
			_anim.play(want)
	if Pets.combat_enabled(ch):
		_combat(delta)

func _pick_fetch_target() -> void:
	if Pets.perk(player.ch) != "fetch" or Game.world == null:
		return
	if _fetch_target and is_instance_valid(_fetch_target):
		return
	var r = float(Pets.perk_param(player.ch, "radius", 8.0))
	var best = null
	var bd = r
	for d in Game.world.drops:
		if not is_instance_valid(d) or _skip.has(d.get_instance_id()):
			continue
		var dd = d.global_position.distance_to(player.global_position)
		if dd < bd:
			bd = dd
			best = d
	_fetch_target = best

func _combat(delta: float) -> void:
	_attack_cd -= delta
	if _attack_cd > 0.0 or Game.world == null:
		return
	_attack_cd = float(Pets.perk_param(player.ch, "attack_interval", 1.2))
	var t = Game.world.nearest_enemy(player, player.global_position, 7.0, [])
	if t == null:
		return
	var mult = float(rec.get("combat_mult", Pets.perk_param(player.ch, "combat_mult", 0.35))) * (1.0 + 0.03 * Pets.level(player.ch, pet_id))
	Game.world.draw_bolt(global_position, t.hit_center(), Color(rec.get("tint", "#ffd98a")))
	Game.world.deal_damage(player, t, mult, str(rec.get("element", "physical")), ["minion", "pet"], {}, true)

func _set_away(v: bool) -> void:
	_away = v
	var tw = create_tween()
	if v:
		Fx.burst(global_position, Color(rec.get("tint", "#ffd98a")), 14, 3.0, 0.1, 0.7, 2.0)
		tw.tween_property(self, "global_position", global_position + Vector3(0, 6, 0), 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): visible = false)
	else:
		visible = true
		global_position = player.global_position + Vector3(0, 6, 0)
		tw.tween_property(self, "global_position", player.global_position + Vector3(1, 1, 1), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		Events.pet_ferry.emit("returned", {})
		Events.toast.emit("%s is back from town!" % rec.get("name", "Your pet"), Color(rec.get("tint", "#ffd98a")))
