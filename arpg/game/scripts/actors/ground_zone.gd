class_name GroundZone
extends Node3D
## Persistent area (consecration, poison pool, frost field). Ticks damage/heal/slow.

var caster: Actor
var e = {}
var mult = 1.0
var element = "physical"
var tags = []
var radius = 3.0
var until = 0.0
var _tick = 0.0
var _mat: ShaderMaterial

func setup(c: Actor, effect: Dictionary, m: float, el: String, t: Array, col: Color) -> void:
	caster = c
	e = effect
	mult = m
	element = el
	tags = t
	radius = float(effect.get("radius", 3.0)) * sqrt(1.0 + c.stats.get_stat("area_pct") / 100.0)
	until = Time.get_ticks_msec() / 1000.0 + float(effect.get("duration", 4.0))
	var mi = MeshInstance3D.new()
	var q = PlaneMesh.new()
	q.size = Vector2(2, 2)
	mi.mesh = q
	_mat = Fx.shader_mat("res://shaders/ground_ring.gdshader", {"color": col, "fill": 1.0, "ring_width": 0.12, "pulse": 0.5, "alpha": 0.8})
	mi.material_override = _mat
	mi.scale = Vector3(radius, 1, radius)
	mi.position.y = 0.05
	add_child(mi)
	var p = CPUParticles3D.new()
	p.amount = 24
	p.lifetime = 1.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius * 0.8
	p.direction = Vector3.UP
	p.gravity = Vector3(0, 1.5, 0)
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.8
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.14
	var sm = SphereMesh.new()
	sm.radius = 0.5; sm.height = 1.0; sm.radial_segments = 6; sm.rings = 3
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	sm.material = mat
	p.mesh = sm
	var g = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.9))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	p.position.y = 0.3
	add_child(p)

func _physics_process(delta: float) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	if now > until or caster == null or not is_instance_valid(caster):
		if caster and is_instance_valid(caster) and caster is Player and Hooks.has(caster.ch, "zone_expire_burst") and not e.get("_burst", false):
			Fx.ring(global_position, radius, Color(1, 0.7, 0.3), 0.35)
			for t in Game.world.enemies_in_radius(caster, global_position, radius):
				Game.world.deal_damage(caster, t, mult * float(Hooks.param(caster.ch, "zone_expire_burst", "mult", 1.5)), element, tags, e)
		queue_free()
		return
	if until - now < 0.5:
		_mat.set_shader_parameter("alpha", (until - now) / 0.5 * 0.8)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = float(e.get("tick", 0.5))
	for t in Game.world.enemies_in_radius(caster, global_position, radius):
		Game.world.deal_damage(caster, t, mult, element, tags, e, true)
		if e.has("slow"):
			t.add_status("slow", 0.6, float(e.slow))
	if e.has("heal_pct") and Game.world.player and Game.world.player.global_position.distance_to(global_position) < radius:
		Game.world.heal_actor(Game.world.player, Game.world.player.max_life * float(e.heal_pct) * float(e.get("tick", 0.5)))
