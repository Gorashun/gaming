class_name Projectile
extends Node3D
## Lightweight projectile (no physics body): moves each frame, checks hits against GameWorld.

var caster: Actor
var dir = Vector3.FORWARD
var speed = 14.0
var max_range = 12.0
var travelled = 0.0
var mult = 1.0
var element = "physical"
var tags = []
var e = {}
var pierce = 0
var hit_radius = 0.6
var hostile_to = "monster"
var _hit = []
var color = Color.WHITE
var homing = 0.0

func setup(c: Actor, d: Vector3, effect: Dictionary, m: float, el: String, t: Array, col: Color) -> void:
	caster = c
	dir = d.normalized()
	e = effect
	mult = m
	element = el
	tags = t
	color = col
	speed = float(effect.get("speed", 14.0))
	max_range = float(effect.get("range", 12.0))
	pierce = int(effect.get("pierce", 0)) + int(c.stats.get_stat("pierce")) if c else 0
	hit_radius = float(effect.get("radius", 0.6))
	homing = float(effect.get("homing", 0.0))
	hostile_to = "monster" if c.faction == "player" else "player"
	var size = float(effect.get("size", 0.28))
	var mi = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = size
	sm.height = size * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	mi.mesh = sm
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col.lightened(0.4)
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 3.0
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var trail = CPUParticles3D.new()
	trail.amount = 16
	trail.lifetime = 0.3
	trail.local_coords = false
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_min = 0.1
	trail.initial_velocity_max = 0.4
	trail.scale_amount_min = size * 0.5
	trail.scale_amount_max = size * 0.9
	var tm = SphereMesh.new()
	tm.radius = 0.5
	tm.height = 1.0
	tm.radial_segments = 6
	tm.rings = 3
	var tmat = mat.duplicate()
	tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tmat.vertex_color_use_as_albedo = true
	tm.material = tmat
	trail.mesh = tm
	var g = Gradient.new()
	g.set_color(0, Color(col, 0.8))
	g.set_color(1, Color(col, 0.0))
	trail.color_ramp = g
	add_child(trail)

func _physics_process(delta: float) -> void:
	if homing > 0.0:
		var t = Game.world.nearest_hostile_of(hostile_to, global_position, 6.0, _hit)
		if t:
			var want: Vector3 = (t.global_position - global_position)
			want.y = 0
			dir = dir.slerp(want.normalized(), clampf(homing * delta, 0.0, 1.0)).normalized()
	var step = speed * delta
	global_position += dir * step
	travelled += step
	var hits: Array = Game.world.hostiles_in_radius_of(hostile_to, global_position, hit_radius, _hit)
	for h in hits:
		_hit.append(h)
		if caster and is_instance_valid(caster):
			if hostile_to == "monster":
				Game.world.deal_damage(caster, h, mult, element, tags, e)
			else:
				Game.world.monster_hit(caster, h, mult, element)
		Fx.sparks(global_position - Vector3(0, 0.9, 0), color)
		if e.has("explode_radius"):
			_explode()
			return
		if pierce <= 0:
			queue_free()
			return
		pierce -= 1
	if travelled >= max_range or not Game.world.is_walkable(global_position):
		if e.has("explode_radius"):
			_explode()
		else:
			Fx.sparks(global_position - Vector3(0, 0.9, 0), color)
		queue_free()

func _explode() -> void:
	var r = float(e.explode_radius)
	Fx.ring(global_position - Vector3(0, 0.95, 0), r, color, 0.35)
	Fx.burst(global_position, color, 16, 5.0, 0.14, 0.4)
	Fx.flash_light(global_position, color, 3.0, 0.25, r * 2.5)
	if caster and is_instance_valid(caster):
		for t in Game.world.hostiles_in_radius_of(hostile_to, global_position, r, []):
			if hostile_to == "monster":
				Game.world.deal_damage(caster, t, mult * float(e.get("explode_mult", 0.6)), element, tags, e)
			else:
				Game.world.monster_hit(caster, t, mult * float(e.get("explode_mult", 0.6)), element)
	Fx.shake(0.12)
	queue_free()
