extends Node3D
## Per-zone ambience: particle weather that follows the hero (snow, motes, spores, fireflies...)
## and torch/lantern flicker for the lights + halos ZoneBuilder created. Presentation only.
## Particle budget: every ambient layer <= 48 particles, total per biome <= 120 (Art Bible 6).

var _lights: Array = []
var _halos: Array = []
var _layers: Array = []     # CPUParticles3D following the hero
var _t = 0.0

const PRESETS := {
	# kind: [amount, lifetime, box extents, gravity, vel min, vel max, size min, size max, additive, texture]
	"snow":      [48, 6.0, Vector3(14, 5, 14), Vector3(0.35, -1.1, 0.1), 0.1, 0.3, 0.07, 0.14, false, "dot"],
	"motes":     [36, 5.0, Vector3(13, 3, 13), Vector3(0, 0.18, 0), 0.05, 0.2, 0.05, 0.1, true, "dot"],
	"spores":    [32, 7.0, Vector3(13, 3, 13), Vector3(0.05, 0.08, 0), 0.05, 0.15, 0.05, 0.09, true, "dot"],
	"fireflies": [18, 4.0, Vector3(12, 1.6, 12), Vector3(0, 0.05, 0), 0.2, 0.6, 0.06, 0.1, true, "dot"],
	"dust":      [36, 6.0, Vector3(12, 3, 12), Vector3(0.05, -0.02, 0), 0.02, 0.1, 0.04, 0.07, false, "dot"],
	"embers":    [24, 3.5, Vector3(12, 1.0, 12), Vector3(0, 0.6, 0), 0.2, 0.5, 0.04, 0.07, true, "dot"],
	"ash":       [36, 6.0, Vector3(14, 5, 14), Vector3(0.2, -0.5, 0.0), 0.05, 0.2, 0.05, 0.1, false, "dot"],
	"wisps":     [8, 6.0, Vector3(12, 1.4, 12), Vector3(0, 0.1, 0), 0.1, 0.3, 0.18, 0.3, true, "dot"],
}

func setup(specs: Array, lights: Array, halos: Array) -> void:
	_lights = lights
	_halos = halos
	for s in specs:
		_layers.append(_make_layer(s))

func _make_layer(s: Dictionary) -> CPUParticles3D:
	var kind: String = s.get("kind", "motes")
	var pr: Array = PRESETS.get(kind, PRESETS.motes)
	var p = CPUParticles3D.new()
	p.amount = mini(int(s.get("amount", pr[0])), 48)
	p.lifetime = pr[1]
	p.preprocess = pr[1]
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = pr[2]
	p.gravity = pr[3]
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = pr[4]
	p.initial_velocity_max = pr[5]
	p.scale_amount_min = pr[6] * 2.2
	p.scale_amount_max = pr[7] * 2.2
	p.mesh = Fx.particle_quad()
	p.material_override = Fx.particle_mat(pr[8], pr[9])
	p.color = Color(s.get("color", "#ffffff"))
	var g = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.2, Color(1, 1, 1, float(s.get("alpha", 0.9))))
	g.add_point(0.8, Color(1, 1, 1, float(s.get("alpha", 0.9))))
	p.color_ramp = g
	if kind == "fireflies" or kind == "wisps":
		p.orbit_velocity_min = -0.05
		p.orbit_velocity_max = 0.05
		p.hue_variation_min = -0.03
		p.hue_variation_max = 0.03
	p.position = Vector3(0, pr[2].y * 0.5, 0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p

func _process(delta: float) -> void:
	_t += delta
	var w = Game.world
	if w and w.player and is_instance_valid(w.player):
		var pp: Vector3 = w.player.global_position
		# Emitters follow the hero; particles themselves stay in world space.
		for l in _layers:
			var ext: Vector3 = l.emission_box_extents
			l.global_position = Vector3(pp.x - 2.0, ext.y * 0.5 + 0.2, pp.z - 2.0)
	# Flicker: cheap layered sines, phase per light. Only visible lights cost anything.
	for i in _lights.size():
		var l: OmniLight3D = _lights[i]
		if l.visible:
			var f = 0.88 + 0.08 * sin(_t * 9.0 + i * 1.7) + 0.05 * sin(_t * 23.0 + i * 3.1)
			l.light_energy = float(l.get_meta("base_energy", 1.4)) * f
	for i in _halos.size():
		var h: Sprite3D = _halos[i]
		var f2 = 0.9 + 0.1 * sin(_t * 8.0 + i * 2.3)
		h.scale = Vector3.ONE * f2
