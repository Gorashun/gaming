extends Node3D
## Exit / return portal: a KayKit arch (biome-tinted like the rest of the zone) framing a
## swirling vortex, ground sigil, rising motes, short light pillar and one soft light.
## The arch faces the fixed-yaw camera so the swirl always reads.

var _swirl: MeshInstance3D

func setup(col: Color) -> void:
	var holder = Node3D.new()
	holder.rotation.y = deg_to_rad(45.0)
	add_child(holder)
	var tint = {}
	if Game.world and "biome" in Game.world:
		tint = Game.world.biome.get("tint", {})
	for part in ZoneBuilder.mesh_of("hal:arch"):
		var mi = MeshInstance3D.new()
		mi.mesh = part[0]
		mi.transform = Transform3D(Basis().scaled(Vector3(0.72, 0.72, 0.72)), Vector3.ZERO) * part[1]
		var src: Material = (part[0] as Mesh).surface_get_material(0)
		mi.material_override = ZoneBuilder.env_material(src, tint)
		holder.add_child(mi)
	_swirl = MeshInstance3D.new()
	var q = QuadMesh.new()
	q.size = Vector2(2.2, 2.8)
	_swirl.mesh = q
	_swirl.material_override = Fx.shader_mat("res://shaders/portal_swirl.gdshader", {"color": col, "eye_color": col.darkened(0.85), "speed": 1.0, "stretch": 1.25, "noise_tex": Fx.tex("noise")})
	_swirl.position = Vector3(0, 1.45, 0)
	_swirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(_swirl)
	var g = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(4.4, 4.4)
	g.mesh = pm
	g.material_override = Fx.shader_mat("res://shaders/loot_ground.gdshader", {"color": col, "disc": 0.45, "ring": 1.0, "rays": 8.0, "spin": 0.4})
	g.position.y = 0.06
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g)
	Fx.beam(self, col, 5.0, 1.4, 0.2, 0.3)
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = 1.5
	l.omni_range = 6.0
	l.position.y = 1.6
	l.shadow_enabled = false
	add_child(l)
	var p = CPUParticles3D.new()
	p.amount = 24
	p.lifetime = 1.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 1.3
	p.emission_ring_inner_radius = 0.6
	p.emission_ring_height = 0.1
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, 1.0, 0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	p.scale_amount_min = 0.1
	p.scale_amount_max = 0.22
	p.mesh = Fx.particle_quad()
	p.material_override = Fx.particle_mat(true, "spark")
	p.color = col.lerp(Color.WHITE, 0.3)
	var gr = Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = gr
	p.position.y = 0.2
	add_child(p)
