extends Node3D
## Swirling exit portal (procedural): ring + beam + particles + light.

func setup(col: Color) -> void:
	var ring = MeshInstance3D.new()
	var t = TorusMesh.new()
	t.inner_radius = 0.9
	t.outer_radius = 1.15
	t.rings = 24
	t.ring_segments = 8
	ring.mesh = t
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 3.0
	ring.material_override = m
	ring.rotation_degrees.x = 90
	ring.position.y = 1.3
	add_child(ring)
	var disc = MeshInstance3D.new()
	var q = QuadMesh.new()
	q.size = Vector2(1.9, 1.9)
	disc.mesh = q
	disc.position.y = 1.3
	disc.material_override = Fx.shader_mat("res://shaders/ground_ring.gdshader", {"color": col, "fill": 1.0, "pulse": 1.0})
	add_child(disc)
	Fx.beam(self, col, 5.0, 1.2)
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = 2.0
	l.omni_range = 6.0
	l.position.y = 1.5
	add_child(l)
	var p = CPUParticles3D.new()
	p.amount = 30
	p.lifetime = 1.4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3(0, 0, 1)
	p.emission_ring_radius = 1.0
	p.emission_ring_inner_radius = 0.8
	p.emission_ring_height = 0.1
	p.gravity = Vector3(0, 0.5, 0)
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.3
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.1
	var sm = SphereMesh.new()
	sm.radius = 0.5; sm.height = 1.0; sm.radial_segments = 6; sm.rings = 3
	sm.material = m
	p.mesh = sm
	p.position.y = 1.3
	add_child(p)
	set_process(true)

func _process(delta: float) -> void:
	if get_child_count() > 0:
		get_child(0).rotation.z += delta * 2.0
