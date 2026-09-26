extends Node
## Juice library + FX director (autoload "Fx"). Everything here is presentation only — it never
## affects game state.
##
## Library: call directly (burst, sparks, ring, telegraph, slash, beam, trail, lightning,
## level_up_pillar, rekindle, aura, heal_fx, summon_puff, hush_tear, event_cache_spawn ...).
## Director: listens to Events and decorates what gameplay code spawns (actors, projectiles,
## ground zones, chain bolts, drops) so gameplay scripts stay free of art code:
##   - actors: toon shading, blob shadows, outline policy (hero/elite/boss only), hero Wick light,
##     elite ground ring, boss rim light, summon puffs
##   - projectiles: element look + ribbon trail; enemy shots = dark core + threat-red rim
##   - ground zones: swirling element shader; chain bolts: thick flickering ribbons
##   - skills (Events.skill_cast): buff auras, heal, dash/leap trails, nova shockwaves
##   - loot (Events.item_dropped): rarity beams + ground shapes (Art Bible 3)
##   - deaths (Events.actor_died): "rekindle" — the soul rises and flies home, an ember flies to the hero
## Budgets (Art Bible 6): <= 40 particles per effect, pooled CPUParticles3D, <= 3 transient lights.

const TEX := {
	"dot": "res://assets/generated/textures/fx_soft_dot.png",
	"spark": "res://assets/generated/textures/fx_spark.png",
	"smoke": "res://assets/generated/textures/fx_smoke.png",
	"flame": "res://assets/generated/textures/fx_flame.png",
	"noise": "res://assets/generated/textures/noise_rgba.png",
}
const THREAT := Color("#ff2b2b")
## Element colour language (Art Bible 6.1). Player VFX use these unless a skill sets its own colour.
const ELEMENT_COLORS := {
	"physical": Color("#fff1d6"),
	"fire": Color("#ff7a2e"),
	"cold": Color("#8fe3ff"),
	"lightning": Color("#c3ccff"),
	"shadow": Color("#9b6bff"),
	"holy": Color("#ffe08a"),
	"poison": Color("#8cff6b"),
	"hush": Color("#d0d0dc"),
}
const MAX_FLASH_LIGHTS := 3
const MAX_PARTICLES_PER_EFFECT := 40

var camera_rig: Node3D = null   # set by GameWorld; must implement add_trauma(amount)
var toon_enabled := true

var _mat_cache = {}
var _tex_cache = {}
var _std_cache = {}
var _dmg_pool: Array[Label3D] = []
var _hitstop_until = 0
var _pool: Array = []            # idle CPUParticles3D (parented to the current fx_root)
var _flash_lights = 0
var _last_hit_fx = {}
var _chain_bolts: Array = []     # [Color]
var _chain_targets: Array = []
var _chain_flush_queued = false
var _world_hooked: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_globals()
	toon_enabled = bool(Settings.get_value("toon_shading", true)) if Settings.has_method("get_value") else true
	Events.zone_entered.connect(_on_zone_entered)
	Events.skill_cast.connect(_on_skill_cast)
	Events.level_up.connect(_on_level_up)
	Events.item_dropped.connect(_on_item_dropped)
	Events.actor_died.connect(_on_actor_died)
	Events.actor_damaged.connect(_on_actor_damaged)
	Events.boss_spawned.connect(_on_boss_spawned)

func _register_globals() -> void:
	# Registered at runtime (Fx is an autoload, so this runs once before any zone shader compiles).
	RenderingServer.global_shader_parameter_add(&"wick_player_pos", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3(0, -1000, 0))

## Called every frame by CameraRig: drives wall dither + mist clearing around the hero.
func set_player_pos(p: Vector3) -> void:
	RenderingServer.global_shader_parameter_set(&"wick_player_pos", p)

func root3d() -> Node3D:
	return Game.world.fx_root if Game.world and "fx_root" in Game.world and is_instance_valid(Game.world.fx_root) else null

func tex(name: String) -> Texture2D:
	if not _tex_cache.has(name):
		_tex_cache[name] = load(TEX.get(name, name))
	return _tex_cache[name]

func shader_mat(path: String, params := {}) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	if not _mat_cache.has(path):
		_mat_cache[path] = load(path)
	m.shader = _mat_cache[path]
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m

func elem_color(element: String) -> Color:
	return ELEMENT_COLORS.get(element, ELEMENT_COLORS.physical)

func _is_threat(c: Color) -> bool:
	return c.r > 0.8 and c.g < 0.4 and c.b < 0.4

# ---------------------------------------------------------------- shared resources
func particle_quad() -> QuadMesh:
	if not _std_cache.has("quad"):
		var q = QuadMesh.new()
		q.size = Vector2(1, 1)
		_std_cache["quad"] = q
	return _std_cache["quad"]

## Billboard particle material. additive = glow; otherwise alpha blend (smoke, dust, snow).
func particle_mat(additive := true, texname := "dot") -> StandardMaterial3D:
	var key = "pm_%s_%s" % [additive, texname]
	if not _std_cache.has(key):
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = tex(texname)
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.disable_receive_shadows = true
		m.disable_fog = additive
		_std_cache[key] = m
	return _std_cache[key]

## Material for Sprite3D halos/glows (modulate = vertex colour).
func additive_sprite_mat(texname := "dot") -> StandardMaterial3D:
	var key = "sprite_add_" + texname
	if not _std_cache.has(key):
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = tex(texname)
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true      # glows inside scaled creatures / tweened souls
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.disable_fog = true
		_std_cache[key] = m
	return _std_cache[key]

func _unshaded_color_mat(c: Color, additive := false) -> StandardMaterial3D:
	var key = "uc_%s_%s" % [c.to_html(), additive]
	if not _std_cache.has(key):
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = c
		if additive:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.disable_fog = true
		_std_cache[key] = m
	return _std_cache[key]

func glow_sprite(color: Color, size := 1.0, texname := "dot") -> Sprite3D:
	var s = Sprite3D.new()
	s.texture = tex(texname)
	s.pixel_size = size / 64.0
	s.modulate = color
	s.material_override = additive_sprite_mat(texname)
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return s

var _fade_ramp: Gradient
var _shrink_curve: Curve
func _fade() -> Gradient:
	if _fade_ramp == null:
		_fade_ramp = Gradient.new()
		_fade_ramp.set_color(0, Color(1, 1, 1, 1))
		_fade_ramp.set_color(1, Color(1, 1, 1, 0))
	return _fade_ramp

func _shrink() -> Curve:
	if _shrink_curve == null:
		_shrink_curve = Curve.new()
		_shrink_curve.add_point(Vector2(0, 1))
		_shrink_curve.add_point(Vector2(1, 0.25))
	return _shrink_curve

# ---------------------------------------------------------------- feedback
func shake(amount: float) -> void:
	if camera_rig and camera_rig.has_method("add_trauma"):
		camera_rig.add_trauma(amount * float(Settings.get_value("screen_shake", 1.0)))

func hitstop(ms: int) -> void:
	# Brief global slow-down; real time based so it always recovers.
	var now = Time.get_ticks_msec()
	if now < _hitstop_until:
		return
	_hitstop_until = now + ms
	Engine.time_scale = 0.08
	await get_tree().create_timer(ms / 1000.0, true, false, true).timeout
	Engine.time_scale = 1.0

func slowmo(duration: float, scale := 0.3) -> void:
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

func later(t: float, f: Callable) -> void:
	if t <= 0.0:
		f.call()
	else:
		get_tree().create_timer(t, false).timeout.connect(f)

var _recent_numbers = {}   # grid key -> {label, amount, t}: merges rapid hits into one number
var _active_numbers = 0
const MAX_NUMBERS := 24

func damage_number(pos: Vector3, amount: float, crit: bool, color := Color.WHITE, is_player := false) -> void:
	if not Settings.get_value("damage_numbers", true):
		return
	var r = root3d()
	if r == null:
		return
	# Declutter crowded fights: hits on the same spot within 0.3 s add up into one number.
	var key = "%d_%d_%s_%s" % [int(round(pos.x)), int(round(pos.z)), is_player, crit]
	var now = Time.get_ticks_msec()
	if _recent_numbers.has(key):
		var rec = _recent_numbers[key]
		if now - int(rec.t) < 300 and is_instance_valid(rec.label) and rec.label.is_inside_tree():
			rec.amount = float(rec.amount) + amount
			rec.t = now
			(rec.label as Label3D).text = _fmt(rec.amount) + ("!" if crit else "")
			(rec.label as Label3D).scale = Vector3.ONE * (1.9 if crit else 1.3)
			return
	if _active_numbers >= MAX_NUMBERS and not crit and not is_player:
		return
	var l: Label3D
	if _dmg_pool.size() > 0:
		l = _dmg_pool.pop_back()
	else:
		l = Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = true
		l.outline_size = 10
		l.outline_modulate = Color(0.05, 0.03, 0.08, 0.9)
		l.render_priority = 10
		l.font = UiTheme.font_numbers()
	r.add_child(l)
	l.text = _fmt(amount) + ("!" if crit else "")
	l.pixel_size = 0.0022 if crit else 0.0016
	l.font_size = 64 if crit else 48
	l.modulate = Color(1.0, 0.8, 0.25) if crit else color
	if is_player:
		l.modulate = Color("#ff6b6b")
	l.global_position = pos + Vector3(randf_range(-0.4, 0.4), 1.9, randf_range(-0.4, 0.4))
	l.scale = Vector3.ONE * (1.7 if crit else 1.15)
	_recent_numbers[key] = {"label": l, "amount": amount, "t": now}
	if _recent_numbers.size() > 64:
		_recent_numbers.clear()
	_active_numbers += 1
	var t = l.create_tween()
	t.set_parallel(true)
	t.tween_property(l, "global_position", l.global_position + Vector3(0, 1.2, 0), 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(l, "scale", Vector3.ONE * (1.1 if crit else 0.8), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.45)
	t.chain().tween_callback(func():
		_active_numbers = maxi(0, _active_numbers - 1)
		if is_instance_valid(l):
			l.get_parent().remove_child(l)
			l.modulate.a = 1.0
			_dmg_pool.append(l))

func _fmt(v: float) -> String:
	if v >= 1_000_000:
		return "%.1fM" % (v / 1_000_000.0)
	if v >= 10_000:
		return "%.1fK" % (v / 1000.0)
	return str(int(round(v)))

func float_text(pos: Vector3, text: String, color: Color, size := 40) -> void:
	var r = root3d()
	if r == null:
		return
	var l = Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0018
	l.font_size = size
	l.outline_size = 10
	l.outline_modulate = Color(0.05, 0.03, 0.08, 0.9)
	l.text = text
	l.modulate = color
	r.add_child(l)
	l.global_position = pos + Vector3(0, 2.4, 0)
	var t = l.create_tween()
	t.tween_property(l, "global_position", l.global_position + Vector3(0, 1.0, 0), 1.2)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.7)
	t.tween_callback(l.queue_free)

# ---------------------------------------------------------------- particles (pooled)
func _take_particles(r: Node3D) -> CPUParticles3D:
	while _pool.size() > 0:
		var p = _pool.pop_back()
		if is_instance_valid(p) and p.get_parent() == r:
			return p
	var n = CPUParticles3D.new()
	n.one_shot = true
	n.emitting = false
	n.explosiveness = 0.95
	n.direction = Vector3.UP
	n.spread = 180.0
	n.mesh = particle_quad()
	n.color_ramp = _fade()
	n.scale_amount_curve = _shrink()
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.process_mode = Node.PROCESS_MODE_PAUSABLE
	r.add_child(n)
	return n

func _release(p) -> void:   # untyped: the bound particle may be freed
	if is_instance_valid(p):
		p.emitting = false
		_pool.append(p)

## Omni-directional burst. Dull greys/browns automatically render as alpha-blended dust/smoke,
## everything else as additive glow.
func burst(pos: Vector3, color: Color, amount := 16, speed := 4.0, size := 0.12, lifetime := 0.5, gravity := -6.0, texname := "", spread := 180.0) -> void:
	var r = root3d()
	if r == null:
		return
	var dusty = color.s < 0.35 and color.v < 0.75
	if texname == "":
		texname = "smoke" if dusty else "dot"
	var p = _take_particles(r)
	p.amount = clampi(amount, 1, MAX_PARTICLES_PER_EFFECT)
	p.lifetime = lifetime
	p.spread = spread
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	var sz = size * (3.2 if dusty else 2.4)
	p.scale_amount_min = sz * 0.6
	p.scale_amount_max = sz
	p.damping_min = 1.0 if dusty else 0.0
	p.damping_max = 2.0 if dusty else 0.0
	p.material_override = particle_mat(not dusty, texname)
	p.color = color
	p.global_position = pos
	p.restart()
	get_tree().create_timer(lifetime + 0.15, false).timeout.connect(_release.bind(p))

func sparks(pos: Vector3, color := Color(1, 0.8, 0.4)) -> void:
	burst(pos + Vector3(0, 0.9, 0), color, 10, 6.0, 0.08, 0.3, -12.0, "spark")

## Quick star pop at the impact point (every non-DoT hit, rate-limited per target).
func hit_spark(pos: Vector3, color: Color, size := 0.9) -> void:
	var r = root3d()
	if r == null:
		return
	var s = glow_sprite(color.lightened(0.3), size, "spark")
	r.add_child(s)
	s.global_position = pos
	s.rotation.z = randf() * TAU
	s.scale = Vector3.ONE * 0.3
	var t = s.create_tween()
	t.tween_property(s, "scale", Vector3.ONE, 0.05)
	t.tween_property(s, "scale", Vector3.ONE * 0.1, 0.1)
	t.tween_callback(s.queue_free)

## Cute smoke puff (minion spawn/despawn, teleports). The death effect is rekindle().
func soul_puff(pos: Vector3, color := Color(0.7, 0.9, 1.0)) -> void:
	burst(pos + Vector3(0, 0.5, 0), Color(0.32, 0.3, 0.38), 10, 2.2, 0.28, 0.7, 1.2, "smoke")
	burst(pos + Vector3(0, 0.8, 0), color, 10, 3.0, 0.08, 0.8, 2.5, "spark")
	flash_light(pos + Vector3(0, 1, 0), color, 2.0, 0.3)

func flash_light(pos: Vector3, color: Color, energy := 2.0, duration := 0.25, rng := 6.0) -> void:
	var r = root3d()
	if r == null or _flash_lights >= MAX_FLASH_LIGHTS:
		return
	_flash_lights += 1
	var l = OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	r.add_child(l)
	l.global_position = pos
	var t = l.create_tween()
	t.tween_property(l, "light_energy", 0.0, duration)
	t.tween_callback(func():
		_flash_lights = maxi(0, _flash_lights - 1)
		l.queue_free())
	l.tree_exiting.connect(func():
		if t.is_running():
			_flash_lights = maxi(0, _flash_lights - 1))

# ---------------------------------------------------------------- ground shapes
func _ground_quad(r: Node3D, pos: Vector3, radius: float, mat: Material, y := 0.06) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var q = PlaneMesh.new()
	q.size = Vector2(2, 2)
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(mi)
	mi.global_position = pos + Vector3(0, y, 0)
	mi.scale = Vector3(radius, 1, radius)
	return mi

func ring(pos: Vector3, radius: float, color: Color, duration := 0.35, grow := true) -> void:
	var r = root3d()
	if r == null:
		return
	var mat = shader_mat("res://shaders/ground_ring.gdshader", {"color": color, "ring_width": 0.14})
	var mi = _ground_quad(r, Vector3(pos.x, 0, pos.z), radius * 0.3 if grow else radius, mat)
	var t = mi.create_tween()
	t.set_parallel(true)
	if grow:
		t.tween_property(mi, "scale", Vector3(radius, 1, radius), duration * 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_method(func(a): mat.set_shader_parameter("alpha", a), 1.0, 0.0, duration)
	t.chain().tween_callback(mi.queue_free)
	# soft inner flash disc
	var dm = shader_mat("res://shaders/loot_ground.gdshader", {"color": color, "disc": 1.2, "ring": 0.0, "alpha": 0.8})
	var d = _ground_quad(r, Vector3(pos.x, 0, pos.z), radius * 0.9, dm, 0.05)
	var t2 = d.create_tween()
	t2.tween_method(func(a): dm.set_shader_parameter("alpha", a), 0.8, 0.0, duration * 0.6)
	t2.tween_callback(d.queue_free)

## Vertical expanding band (novas, landings, level-up).
func shockwave(pos: Vector3, radius: float, color: Color, duration := 0.35, height := 0.9) -> void:
	var r = root3d()
	if r == null:
		return
	var mi = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = height
	cm.cap_top = false
	cm.cap_bottom = false
	cm.radial_segments = 24
	cm.rings = 1
	mi.mesh = cm
	var mat = shader_mat("res://shaders/beam.gdshader", {"color": color, "intensity": 1.4, "streaks": 0.0})
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(mi)
	mi.global_position = Vector3(pos.x, height * 0.5, pos.z)
	mi.scale = Vector3(radius * 0.2, 1, radius * 0.2)
	var t = mi.create_tween()
	t.set_parallel(true)
	t.tween_property(mi, "scale", Vector3(radius, 0.4, radius), duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_method(func(a): mat.set_shader_parameter("alpha", a), 1.0, 0.0, duration)
	t.chain().tween_callback(mi.queue_free)

## Telegraph that fills over `duration`. Threat-red colours use the hatched threat shader
## (Art Bible 6); player-coloured telegraphs get a falling star that lands on time.
func telegraph(pos: Vector3, radius: float, duration: float, color := THREAT) -> Node3D:
	var r = root3d()
	if r == null:
		return null
	var threat = _is_threat(color)
	var mat: ShaderMaterial
	if threat:
		mat = shader_mat("res://shaders/telegraph.gdshader", {"color": THREAT, "fill": 0.0, "hatch_scale": clampf(radius * 2.5, 4.0, 14.0)})
	else:
		mat = shader_mat("res://shaders/ground_ring.gdshader", {"color": color, "fill": 0.0, "pulse": 1.0})
	var mi = _ground_quad(r, Vector3(pos.x, 0, pos.z), radius, mat, 0.07)
	var t = mi.create_tween()
	t.tween_method(func(f): mat.set_shader_parameter("fill", f), 0.0, 1.0, duration)
	t.tween_callback(mi.queue_free)
	if not threat:
		_falling_star(pos, color, duration)
	return mi

func _falling_star(pos: Vector3, color: Color, duration: float) -> void:
	var r = root3d()
	if r == null:
		return
	var n = Node3D.new()
	r.add_child(n)
	var start = pos + Vector3(-2.5, 11.0, -2.5)
	n.global_position = start
	n.add_child(glow_sprite(color.lightened(0.4), 1.4))
	n.add_child(glow_sprite(Color(1, 1, 1, 0.9), 0.5))
	var tr = TrailRibbon.new().setup(n, color, 0.55, 0.3, 2.0)
	tr.set_meta("fx", true)
	r.add_child(tr)
	var t = n.create_tween()
	t.tween_property(n, "global_position", pos + Vector3(0, 0.4, 0), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(n.queue_free)

func slash(origin: Vector3, forward: Vector3, radius: float, angle_deg: float, color := Color(1, 0.9, 0.6), duration := 0.22) -> void:
	var r = root3d()
	if r == null:
		return
	var f = forward
	f.y = 0
	if f.length() < 0.01:
		f = Vector3.FORWARD
	f = f.normalized()
	for layer in 2:
		var mi = MeshInstance3D.new()
		mi.mesh = _arc_mesh(radius * (1.0 if layer == 0 else 0.82), angle_deg)
		var mat = shader_mat("res://shaders/slash.gdshader", {"color": color if layer == 0 else color.lerp(Color.WHITE, 0.5), "intensity": 2.0 if layer == 0 else 1.2})
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r.add_child(mi)
		mi.global_position = origin + Vector3(0, 0.95 - layer * 0.3, 0)
		mi.look_at(mi.global_position + f, Vector3.UP)
		mi.rotate_object_local(Vector3.FORWARD, 0.12 if layer == 0 else -0.1)
		var t = mi.create_tween()
		t.tween_method(func(p): mat.set_shader_parameter("progress", p), 0.0, 1.0, duration * (1.0 if layer == 0 else 1.15))
		t.tween_callback(mi.queue_free)
	later(duration * 0.5, func(): burst(origin + f * radius * 0.85 + Vector3(0, 0.9, 0), color, 6, 3.0, 0.07, 0.3, -6.0, "spark"))

var _arc_cache = {}
func _arc_mesh(radius: float, angle_deg: float) -> ArrayMesh:
	var key = "%0.2f_%d" % [radius, int(angle_deg)]
	if _arc_cache.has(key):
		return _arc_cache[key]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs = 20
	var inner = radius * 0.35
	var half = deg_to_rad(angle_deg) * 0.5
	for i in segs:
		var a0 = -half + (2.0 * half) * i / segs
		var a1 = -half + (2.0 * half) * (i + 1) / segs
		var u0 = float(i) / segs
		var u1 = float(i + 1) / segs
		var p0i = Vector3(sin(a0) * inner, 0, -cos(a0) * inner)
		var p0o = Vector3(sin(a0) * radius, 0, -cos(a0) * radius)
		var p1i = Vector3(sin(a1) * inner, 0, -cos(a1) * inner)
		var p1o = Vector3(sin(a1) * radius, 0, -cos(a1) * radius)
		for v in [[p0i, Vector2(u0, 0)], [p0o, Vector2(u0, 1)], [p1o, Vector2(u1, 1)], [p0i, Vector2(u0, 0)], [p1o, Vector2(u1, 1)], [p1i, Vector2(u1, 0)]]:
			st.set_uv(v[1])
			st.add_vertex(v[0])
	var m = st.commit()
	_arc_cache[key] = m
	return m

## Vertical light pillar (open cylinder, additive, fog-free). Returns the MeshInstance3D.
func beam(parent: Node3D, color: Color, height := 6.0, width := 0.5, core := 0.0, pulse := 0.0) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = width * 0.5
	cm.bottom_radius = width * 0.5
	cm.height = height
	cm.cap_top = false
	cm.cap_bottom = false
	cm.radial_segments = 12
	cm.rings = 1
	mi.mesh = cm
	mi.position.y = height * 0.5
	mi.material_override = shader_mat("res://shaders/beam.gdshader", {"color": color, "core": core, "pulse": pulse})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("fx", true)
	parent.add_child(mi)
	return mi

## Ribbon trail following `target` (see TrailRibbon). Parented to the world fx root.
func trail(target: Node3D, color: Color, width := 0.3, life := 0.25, offset := Vector3.ZERO, intensity := 1.6) -> TrailRibbon:
	var r = root3d()
	if r == null:
		return null
	var tr = TrailRibbon.new().setup(target, color, width, life, intensity)
	tr.offset = offset
	tr.set_meta("fx", true)
	r.add_child(tr)
	return tr

## Thick flickering bolt between two points (chain lightning), re-jagged every few frames.
func lightning(a: Vector3, b: Vector3, color: Color, duration := 0.22, width := 0.32) -> void:
	var r = root3d()
	if r == null:
		return
	var im = ImmediateMesh.new()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	mi.set_meta("fx", true)
	mi.top_level = true
	mi.extra_cull_margin = 16.0
	var mat = shader_mat("res://shaders/lightning.gdshader", {"color": color})
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(mi)
	var build = func(alpha: float):
		if not is_instance_valid(mi):
			return
		var cam = mi.get_viewport().get_camera_3d()
		if cam == null:
			return
		var segs = 8
		var pts = []
		for i in segs + 1:
			var p = a.lerp(b, float(i) / segs)
			if i > 0 and i < segs:
				p += Vector3(randf_range(-0.35, 0.35), randf_range(-0.25, 0.35), randf_range(-0.35, 0.35))
			pts.append(p)
		im.clear_surfaces()
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in pts.size():
			var p: Vector3 = pts[i]
			var tng: Vector3 = (pts[mini(i + 1, segs)] - pts[maxi(i - 1, 0)])
			var side = tng.cross(cam.global_position - p).normalized() * width * 0.5
			im.surface_set_uv(Vector2(float(i) / segs, 0))
			im.surface_add_vertex(p - side)
			im.surface_set_uv(Vector2(float(i) / segs, 1))
			im.surface_add_vertex(p + side)
		im.surface_end()
		mat.set_shader_parameter("alpha", alpha)
	var t = mi.create_tween()
	t.tween_method(func(v): build.call(1.0 - v * v), 0.0, 1.0, duration)
	t.tween_callback(mi.queue_free)
	burst(b, color, 8, 4.0, 0.07, 0.25, -4.0, "spark")
	flash_light(b, color, 2.0, 0.18, 5.0)

# ---------------------------------------------------------------- signature effects
func level_up_pillar(pos: Vector3) -> void:
	var r = root3d()
	if r == null:
		return
	var gold = Color(1.0, 0.82, 0.4)
	var n = Node3D.new()
	r.add_child(n)
	n.global_position = Vector3(pos.x, 0, pos.z)
	var b = beam(n, gold, 12.0, 1.8, 0.6, 0.0)
	var bm: ShaderMaterial = b.material_override
	var gm = shader_mat("res://shaders/loot_ground.gdshader", {"color": gold, "rays": 12.0, "disc": 0.8, "ring": 1.0, "spin": 1.2})
	var g = MeshInstance3D.new()
	var q = PlaneMesh.new()
	q.size = Vector2(6, 6)
	g.mesh = q
	g.material_override = gm
	g.position.y = 0.06
	n.add_child(g)
	var t = n.create_tween()
	t.set_parallel(true)
	t.tween_method(func(a): bm.set_shader_parameter("alpha", a), 0.0, 1.0, 0.15)
	t.tween_method(func(a): bm.set_shader_parameter("alpha", a), 1.0, 0.0, 1.2).set_delay(0.6)
	t.tween_method(func(a): gm.set_shader_parameter("alpha", a), 1.0, 0.0, 1.6).set_delay(0.3)
	t.tween_property(b, "scale", Vector3(0.3, 1, 0.3), 1.5).set_delay(0.3)
	t.chain().tween_callback(n.queue_free)
	shockwave(pos, 5.0, gold, 0.6, 1.2)
	ring(pos, 4.5, gold, 0.8)
	burst(pos + Vector3(0, 0.5, 0), gold, 30, 3.0, 0.1, 1.4, 2.5, "spark")
	later(0.25, func(): burst(pos + Vector3(0, 2.0, 0), Color(1, 0.95, 0.8), 20, 5.0, 0.08, 1.0, 1.0, "dot"))
	flash_light(pos + Vector3(0, 2, 0), gold, 5.0, 1.0, 10.0)

## Death of a Snuffed: the light inside is rekindled and flies home. No gore (Art Bible 1.4).
func rekindle(pos: Vector3, color: Color, big := false) -> void:
	var r = root3d()
	if r == null:
		return
	var s = 1.8 if big else 1.0
	burst(pos + Vector3(0, 0.7, 0), Color(0.3, 0.28, 0.36), 8, 1.8, 0.3 * s, 0.7, 1.0, "smoke")
	burst(pos + Vector3(0, 0.9, 0), color, int(12 * s), 4.0 * s, 0.08, 0.45, -5.0, "spark")
	var pop = glow_sprite(Color(1, 1, 1, 0.9), 1.8 * s)
	r.add_child(pop)
	pop.global_position = pos + Vector3(0, 0.9, 0)
	var tp = pop.create_tween()
	tp.tween_property(pop, "scale", Vector3.ONE * 0.1, 0.18)
	tp.tween_callback(pop.queue_free)
	# the soul
	var soul = Node3D.new()
	r.add_child(soul)
	soul.global_position = pos + Vector3(0, 0.9, 0)
	soul.add_child(glow_sprite(color, 1.2 * s))
	soul.add_child(glow_sprite(Color(1, 1, 1, 0.95), 0.4 * s))
	var tr = trail(soul, color, 0.28 * s, 0.35)
	var away = Vector3(-1, 0, -1).normalized().rotated(Vector3.UP, randf_range(-0.9, 0.9))
	var p1 = soul.global_position + Vector3(randf_range(-0.3, 0.3), 1.4 * s, randf_range(-0.3, 0.3))
	var p2 = p1 + away * 5.0 + Vector3(0, 7.0, 0)
	var ts = soul.create_tween()
	ts.tween_property(soul, "global_position", p1, 0.45 * s).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	ts.tween_interval(0.1)
	ts.tween_method(func(k):
		if is_instance_valid(soul):
			var q = p1.lerp(p2, k * k)
			q.x += sin(k * 12.0) * 0.25
			soul.global_position = q
			soul.scale = Vector3.ONE * (1.0 - k * 0.8), 0.0, 1.0, 0.8 * s)
	ts.tween_callback(soul.queue_free)
	# ember to the hero (XP): small spark that homes in
	var w = Game.world
	if w and w.player and is_instance_valid(w.player):
		var em = glow_sprite(Color(1.0, 0.8, 0.45), 0.5, "spark")
		r.add_child(em)
		em.global_position = pos + Vector3(0, 1.0, 0)
		var pl: Node3D = w.player
		var from = em.global_position
		var ctrl = from + Vector3(0, 2.0, 0)
		var te = em.create_tween()
		te.tween_interval(0.25)
		te.tween_method(func(k):
			if is_instance_valid(em) and is_instance_valid(pl):
				var to = pl.global_position + Vector3(0, 1.2, 0)
				em.global_position = from.lerp(ctrl, k).lerp(ctrl.lerp(to, k), k), 0.0, 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		te.tween_callback(func():
			if is_instance_valid(em):
				if is_instance_valid(pl):
					hit_spark(pl.global_position + Vector3(0, 1.2, 0), Color(1, 0.85, 0.5), 0.8)
				em.queue_free())
	if big:
		flash_light(pos + Vector3(0, 1.5, 0), color, 5.0, 1.0, 12.0)
		ring(pos, 6.0, color, 0.9)

## Lasting buff aura: rotating ground sigil + rising motes, attached to the actor.
func aura(actor: Node3D, color: Color, duration: float, radius := 1.3) -> Node3D:
	if not is_instance_valid(actor):
		return null
	var n = Node3D.new()
	n.name = "FxAura"
	actor.add_child(n)
	var gm = shader_mat("res://shaders/loot_ground.gdshader", {"color": color, "disc": 0.3, "ring": 1.0, "rays": 6.0, "spin": 1.5, "alpha": 0.0})
	var g = MeshInstance3D.new()
	var q = PlaneMesh.new()
	q.size = Vector2(radius * 2.0, radius * 2.0)
	g.mesh = q
	g.material_override = gm
	g.position.y = 0.07
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(g)
	var p = CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 1.2
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = radius * 0.8
	p.emission_ring_inner_radius = radius * 0.5
	p.emission_ring_height = 0.1
	p.direction = Vector3.UP
	p.spread = 10.0
	p.gravity = Vector3(0, 1.2, 0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.22
	p.mesh = particle_quad()
	p.material_override = particle_mat(true, "spark")
	p.color = color
	p.color_ramp = _fade()
	p.position.y = 0.2
	n.add_child(p)
	var t = n.create_tween()
	t.tween_method(func(a): gm.set_shader_parameter("alpha", a), 0.0, 0.9, 0.2)
	t.tween_interval(maxf(0.1, duration - 0.5))
	t.tween_callback(func(): p.emitting = false)
	t.tween_method(func(a): gm.set_shader_parameter("alpha", a), 0.9, 0.0, 0.3)
	t.tween_callback(n.queue_free)
	return n

func heal_fx(actor: Node3D, color := Color(0.62, 1.0, 0.72)) -> void:
	if not is_instance_valid(actor):
		return
	var pos = actor.global_position
	burst(pos + Vector3(0, 0.4, 0), color, 14, 1.2, 0.12, 1.0, 3.0, "spark", 40.0)
	var r = root3d()
	if r:
		var dm = shader_mat("res://shaders/loot_ground.gdshader", {"color": color, "disc": 1.0, "ring": 0.8, "alpha": 0.9})
		var d = _ground_quad(r, pos, 1.4, dm)
		var t = d.create_tween()
		t.tween_method(func(a): dm.set_shader_parameter("alpha", a), 0.9, 0.0, 0.6)
		t.tween_callback(d.queue_free)
	flash_light(pos + Vector3(0, 1.5, 0), color, 1.5, 0.4, 5.0)

func dash_fx(actor: Node3D, color: Color, duration: float, leap := false) -> void:
	if not is_instance_valid(actor):
		return
	burst(actor.global_position + Vector3(0, 0.3, 0), Color(0.45, 0.42, 0.4), 8, 2.0, 0.25, 0.5, 0.5, "smoke")
	var t1 = trail(actor, color, 1.1 if not leap else 0.8, 0.28, Vector3(0, 1.0, 0), 1.2)
	var t2 = trail(actor, color.lerp(Color.WHITE, 0.4), 0.4, 0.2, Vector3(0, 0.35, 0), 1.6)
	later(duration + 0.05, func():
		for t in [t1, t2]:
			if is_instance_valid(t):
				t.target = null)

func summon_puff(pos: Vector3, color: Color) -> void:
	burst(pos + Vector3(0, 0.4, 0), Color(0.4, 0.36, 0.44), 10, 2.0, 0.3, 0.6, 1.0, "smoke")
	burst(pos + Vector3(0, 0.3, 0), color, 14, 1.5, 0.1, 0.9, 3.5, "spark", 35.0)
	ring(pos, 1.6, color, 0.45)

## Surprise reward cache appearing (events): golden pop, spiral of motes, soft chime light.
func event_cache_spawn(pos: Vector3) -> void:
	var gold = Color(1.0, 0.85, 0.45)
	burst(pos + Vector3(0, 0.5, 0), Color(0.45, 0.42, 0.5), 10, 2.5, 0.3, 0.7, 1.0, "smoke")
	burst(pos + Vector3(0, 0.8, 0), gold, 28, 5.0, 0.1, 0.8, -3.0, "spark")
	burst(pos + Vector3(0, 0.3, 0), Color(1, 0.97, 0.85), 16, 1.2, 0.1, 1.4, 3.0, "dot", 25.0)
	ring(pos, 3.0, gold, 0.6)
	shockwave(pos, 3.5, gold, 0.5)
	flash_light(pos + Vector3(0, 1.5, 0), gold, 4.0, 0.8, 9.0)
	shake(0.15)

## Hushfall tear (GDD v2.4 world event): tall swirling grey-violet rift with white motes, dark
## smoke, a pulsing light and a cracked ground ring. Tall + beam so it reads from far away.
## Returns the node (parented to `parent`); free it to close the tear.
func hush_tear(parent: Node3D) -> Node3D:
	var violet = Color("#9c8cc8")
	var n = Node3D.new()
	n.name = "HushTear"
	parent.add_child(n)
	var q = QuadMesh.new()
	q.size = Vector2(2.4, 4.8)
	var tear = MeshInstance3D.new()
	tear.mesh = q
	tear.material_override = shader_mat("res://shaders/portal_swirl.gdshader", {"color": violet, "eye_color": Color(0.03, 0.02, 0.05), "speed": 1.4, "stretch": 1.0, "noise_tex": tex("noise")})
	tear.position.y = 2.7
	tear.rotation.y = deg_to_rad(45.0)   # faces the fixed-yaw camera
	tear.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(tear)
	beam(n, violet.lightened(0.2), 11.0, 1.2, 0.3, 0.6)
	var gm = shader_mat("res://shaders/loot_ground.gdshader", {"color": violet, "rays": 9.0, "disc": 0.5, "ring": 1.0, "spin": -0.3})
	var g = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(7, 7)
	g.mesh = pm
	g.material_override = gm
	g.position.y = 0.06
	n.add_child(g)
	var motes = CPUParticles3D.new()
	motes.amount = 30
	motes.lifetime = 2.2
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(1.0, 2.0, 1.0)
	motes.gravity = Vector3(0, 0.6, 0)
	motes.initial_velocity_min = 0.2
	motes.initial_velocity_max = 0.6
	motes.scale_amount_min = 0.1
	motes.scale_amount_max = 0.22
	motes.mesh = particle_quad()
	motes.material_override = particle_mat(true, "dot")
	motes.color = Color(1, 1, 1, 0.9)
	motes.color_ramp = _fade()
	motes.position.y = 2.4
	n.add_child(motes)
	var smoke = CPUParticles3D.new()
	smoke.amount = 14
	smoke.lifetime = 2.5
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 1.2
	smoke.gravity = Vector3(0, 0.4, 0)
	smoke.initial_velocity_min = 0.1
	smoke.initial_velocity_max = 0.4
	smoke.scale_amount_min = 1.0
	smoke.scale_amount_max = 1.8
	smoke.mesh = particle_quad()
	smoke.material_override = particle_mat(false, "smoke")
	smoke.color = Color(0.12, 0.1, 0.16, 0.8)
	smoke.color_ramp = _fade()
	smoke.position.y = 0.6
	n.add_child(smoke)
	var l = OmniLight3D.new()
	l.light_color = violet
	l.light_energy = 1.5
	l.omni_range = 8.0
	l.position.y = 2.5
	n.add_child(l)
	var t = l.create_tween().set_loops()
	t.tween_property(l, "light_energy", 2.6, 0.9).set_trans(Tween.TRANS_SINE)
	t.tween_property(l, "light_energy", 1.2, 0.9).set_trans(Tween.TRANS_SINE)
	return n

## Blob shadow: unshaded dark soft quad (Decals are unsupported in Compatibility).
func blob_shadow(actor: Node3D, radius := 0.6, strength := 0.5) -> MeshInstance3D:
	if not _std_cache.has("blob"):
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = tex("dot")
		m.albedo_color = Color(0.0, 0.0, 0.02, 1.0)
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.disable_receive_shadows = true
		_std_cache["blob"] = m
		var q = PlaneMesh.new()
		q.size = Vector2(2, 2)
		_std_cache["blob_mesh"] = q
	var mi = MeshInstance3D.new()
	mi.name = "BlobShadow"
	mi.mesh = _std_cache["blob_mesh"]
	mi.material_override = _std_cache["blob"]
	mi.transparency = 1.0 - strength
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.04
	mi.scale = Vector3(radius, 1, radius)
	actor.add_child(mi)
	return mi

# ---------------------------------------------------------------- director: hooks
func _on_zone_entered(_zone_id: String) -> void:
	var w = Game.world
	if w == null:
		return
	_chain_bolts.clear()
	_chain_targets.clear()
	_pool.clear()
	_flash_lights = 0
	if _world_hooked != w:
		_world_hooked = w
		if w.actors_root and not w.actors_root.child_entered_tree.is_connected(_on_actor_added):
			w.actors_root.child_entered_tree.connect(_on_actor_added)
		if w.fx_root and not w.fx_root.child_entered_tree.is_connected(_on_fx_added):
			w.fx_root.child_entered_tree.connect(_on_fx_added)
	for a in w.actors_root.get_children():
		_decorate_actor(a)

func _on_actor_added(n: Node) -> void:
	call_deferred("_decorate_actor", n)

func _on_fx_added(n: Node) -> void:
	if n.has_meta("fx"):
		return
	if n is MeshInstance3D and (n as MeshInstance3D).mesh is ImmediateMesh:
		# GameWorld.draw_bolt: replace the 1 px line with a thick ribbon (see _flush_chain)
		var im: ImmediateMesh = n.mesh
		var col = Color(0.8, 0.85, 1.0)
		if im.get_surface_count() > 0 and im.surface_get_material(0) is BaseMaterial3D:
			col = (im.surface_get_material(0) as BaseMaterial3D).emission
		(n as MeshInstance3D).visible = false
		_chain_bolts.append(col)
		if not _chain_flush_queued:
			_chain_flush_queued = true
			call_deferred("_flush_chain")
		return
	call_deferred("_decorate_fx_node", n)

func _flush_chain() -> void:
	_chain_flush_queued = false
	var w = Game.world
	if w == null or w.player == null or _chain_targets.is_empty():
		_chain_bolts.clear()
		_chain_targets.clear()
		return
	var from: Vector3 = w.player.hit_center()
	for i in _chain_targets.size():
		var t = _chain_targets[i]
		if not is_instance_valid(t):
			continue
		var col: Color = _chain_bolts[mini(i, _chain_bolts.size() - 1)]
		var to: Vector3 = t.hit_center()
		lightning(from, to, col, 0.22 + i * 0.03)
		from = to
	_chain_bolts.clear()
	_chain_targets.clear()

func _on_actor_damaged(target: Node, amount: float, crit: bool, element: String) -> void:
	if _chain_bolts.size() > _chain_targets.size():
		_chain_targets.append(target)
	if not is_instance_valid(target) or not (target is Node3D):
		return
	var id = target.get_instance_id()
	var now = Time.get_ticks_msec()
	if now - int(_last_hit_fx.get(id, 0)) < 110:
		return
	_last_hit_fx[id] = now
	if _last_hit_fx.size() > 256:
		_last_hit_fx.clear()
	var c = Color("#ff6b6b") if target is Player else elem_color(element)
	hit_spark((target as Node3D).global_position + Vector3(randf_range(-0.2, 0.2), 1.0, randf_range(-0.2, 0.2)), c, 1.3 if crit else 0.85)

func _on_actor_died(actor: Node, _killer: Node) -> void:
	if not (actor is Monster) or not is_instance_valid(actor):
		return
	var m: Monster = actor
	if m.kind == "minion":
		return
	var col = Color(m.rec.get("soul_color", "#bfe3ff"))
	rekindle(m.global_position, col, m.kind == "boss")

func _on_level_up(_lvl: int) -> void:
	var w = Game.world
	if w and w.player:
		level_up_pillar(w.player.global_position)

func _on_boss_spawned(boss: Node) -> void:
	var w = Game.world
	if w and w.sun:
		w.sun.light_energy *= 0.7   # Art Bible 4: key light dims 30 % in boss arenas
	if is_instance_valid(boss) and boss is Monster:
		var l = OmniLight3D.new()
		l.name = "BossRim"
		l.light_color = Color(boss.rec.get("soul_color", boss.rec.get("rim", "#9fe8ff")))
		l.light_energy = 1.4
		l.omni_range = 9.0
		l.position = Vector3(0, 4.5, 0)
		l.shadow_enabled = false
		boss.add_child(l)

func _on_skill_cast(skill_id: String) -> void:
	var w = Game.world
	if w == null or w.player == null or not is_instance_valid(w.player):
		return
	var p: Player = w.player
	var s = Content.get_rec("skills", skill_id)
	if s.is_empty():
		return
	var t0 = float(s.get("windup", 0.12))
	for e in s.get("effects", []):
		t0 += float(e.get("delay", 0.0))
		var col: Color = SkillEffects.color_of(p, s, e)
		match str(e.get("type", "")):
			"buff":
				var dur = float(e.get("duration", 5.0))
				later(t0, func(): aura(p, col, dur))
			"heal":
				later(t0, func(): heal_fx(p))
			"dash", "leap":
				var dd = float(e.get("duration", 0.18))
				var lp = e.type == "leap"
				later(t0, func(): dash_fx(p, col, dd, lp))
			"nova":
				var rr = float(e.get("radius", 3.0))
				later(t0 + float(e.get("telegraph", 0.0)), func():
					if is_instance_valid(p):
						shockwave(p.global_position, rr, col, 0.4))
			"spin":
				var sd = int(e.get("ticks", 5)) * float(e.get("interval", 0.18))
				later(t0, func(): aura(p, col, sd + 0.2, float(e.get("radius", 2.4))))
			"resource":
				later(t0, func():
					if is_instance_valid(p):
						burst(p.global_position + Vector3(0, 1.0, 0), col, 10, 1.5, 0.08, 0.6, 2.0, "spark"))

func _on_item_dropped(d: Node, it: Dictionary) -> void:
	if is_instance_valid(d):
		decorate_drop(d, str(it.get("rarity", "common")))

# ---------------------------------------------------------------- director: decorators
func _decorate_actor(a: Node) -> void:
	if not is_instance_valid(a) or not (a is Actor) or a.has_meta("fx_done"):
		return
	a.set_meta("fx_done", true)
	var act: Actor = a
	var is_player = act is Player
	var kind = "hero" if is_player else (act.kind if act is Monster else "normal")
	var important = is_player or kind in ["champion", "rare", "boss"]
	var sc = act.model.scale.x if act.model else 1.0
	var outline_col = Color(Game.world.biome.get("env", {}).get("outline", "#120c18")) if Game.world else Color("#120c18")
	for m in act._overlay_mats:
		if important:
			if m.next_pass:
				m.next_pass.set_shader_parameter("outline_color", outline_col)
		else:
			m.next_pass = null
	blob_shadow(act, 0.75 * sc, 0.55 if important else 0.45)
	if act.model and not important:
		for mi in act.model.find_children("*", "MeshInstance3D", true, false):
			(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if toon_enabled:
		_apply_toon(act, is_player)
	if is_player:
		_decorate_hero(act)
	elif kind == "minion":
		summon_puff(act.global_position, act.element_color if act.element_color != Color(1, 0.85, 0.5) else Color(1, 0.8, 0.9))
	elif kind in ["champion", "rare"]:
		var col = Color("#6fb3ff") if kind == "champion" else Color("#ffd23f")
		var gm = shader_mat("res://shaders/loot_ground.gdshader", {"color": col, "disc": 0.15, "ring": 0.9, "spin": 0.8, "star_points": 0.0, "alpha": 0.7})
		var g = MeshInstance3D.new()
		var q = PlaneMesh.new()
		q.size = Vector2(2.4 * sc, 2.4 * sc)
		g.mesh = q
		g.material_override = gm
		g.position.y = 0.06
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		act.add_child(g)

var _toon_cache = {}
func _apply_toon(a: Actor, hero: bool) -> void:
	if a.model == null:
		return
	for mi in a.model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		for si in m.mesh.get_surface_count():
			var base = m.get_surface_override_material(si)
			if base == null:
				base = m.mesh.surface_get_material(si)
			if not (base is StandardMaterial3D):
				continue
			var sm: StandardMaterial3D = base
			var key = "%s|%s|%s" % [sm.albedo_texture.resource_path if sm.albedo_texture else "", sm.albedo_color.to_html(), hero]
			if not _toon_cache.has(key):
				_toon_cache[key] = shader_mat("res://shaders/toon_actor.gdshader", {"albedo_tex": sm.albedo_texture, "albedo": sm.albedo_color,
					"rim_amount": 0.45 if hero else 0.3, "emission_boost": 0.06 if hero else 0.0})
			m.set_surface_override_material(si, _toon_cache[key])

func _decorate_hero(p: Actor) -> void:
	# The Wick: the hero's warm light, carried by a tiny flame spirit at the shoulder.
	var light: OmniLight3D = null
	for c in p.get_children():
		if c is OmniLight3D:
			light = c
	var wick = CreatureFactory.build("wick", Color("#ffb54a"), 0.26)
	wick.name = "Wick"
	p.add_child(wick)
	wick.position = Vector3(-0.75, 1.75, -0.35)   # floats beside the shoulder, never over the face
	if light:
		# High and slightly behind: a warm pool on the ground around the hero without blowing
		# out the hero's own colours (Art Bible 4: #FFB54A, "the Wick").
		light.light_color = Color("#ffb869")
		light.light_energy = 1.25
		light.omni_range = 9.0
		light.omni_attenuation = 0.8
		light.position = Vector3(-0.5, 3.6, -0.4)
		wick.set_meta("light", light)

func decorate_drop(d: Node, rarity: String) -> void:
	if not (d is Node3D):
		return
	var col = Items.rarity_color(rarity)
	var rank = Items.rarity_index(rarity)
	# Remove the plain beam/light Drop created; rarity look is owned here.
	for c in d.get_children():
		if c is MeshInstance3D and c.material_override is ShaderMaterial and not c.has_meta("fx"):
			var sh: Shader = (c.material_override as ShaderMaterial).shader
			if sh and sh.resource_path.ends_with("beam.gdshader"):
				c.queue_free()
		elif c is OmniLight3D and rank < 4:
			c.queue_free()
	# Outline the loot model (Art Bible 5: loot on the ground gets outlines).
	if "_visual" in d and d._visual:
		var om = shader_mat("res://shaders/outline.gdshader", {"thickness": 0.02, "outline_color": col.darkened(0.75)})
		for mi in (d._visual as Node).find_children("*", "MeshInstance3D", true, false):
			(mi as GeometryInstance3D).material_overlay = om
		if d._visual is MeshInstance3D:
			(d._visual as GeometryInstance3D).material_overlay = om
	var ground = {"color": col, "disc": 0.5, "ring": 0.0, "alpha": 0.8}
	var gsize = 0.8
	match rarity:
		"common":
			return
		"magic":
			ground.ring = 0.3
		"rare":
			ground.ring = 0.5
			beam(d, col, 1.5, 0.18)
			_loot_particles(d, col, 6, "spark", 0.3)
		"epic":
			ground.ring = 0.7
			beam(d, col, 3.0, 0.3)
			_loot_particles(d, col, 10, "dot", 1.0)
		"legendary":
			ground = {"color": col, "disc": 0.4, "ring": 1.0, "star_points": 5.0, "spin": 0.5}
			gsize = 1.4
			beam(d, col, 8.0, 0.7)
			_loot_particles(d, col, 14, "spark", 1.4)
		"mythic":
			ground = {"color": col, "disc": 0.6, "ring": 1.0, "spin": 0.9}
			gsize = 1.6
			beam(d, col, 12.0, 0.8, 1.0, 1.0)
			_loot_particles(d, col, 18, "flame", 1.8)
		"unique":
			ground = {"color": col, "disc": 0.4, "ring": 1.0, "crown": 5.0, "spin": 0.4}
			gsize = 1.4
			beam(d, col, 8.0, 0.7)
			_loot_particles(d, col, 14, "spark", 1.4)
		"named":
			ground = {"color": col, "disc": 0.4, "ring": 1.0, "rays": 12.0, "spin": 0.7}
			gsize = 1.8
			beam(d, col, 12.0, 0.8, 0.5, 0.4)
			_loot_particles(d, col, 16, "dot", 2.0)
			_halo_rings(d, col)
		_:
			if rank >= 2:
				beam(d, col, 1.5 + rank, 0.3)
	var g = MeshInstance3D.new()
	var q = PlaneMesh.new()
	q.size = Vector2(gsize * 2.0, gsize * 2.0)
	g.mesh = q
	g.material_override = shader_mat("res://shaders/loot_ground.gdshader", ground)
	g.position.y = 0.05
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.set_meta("fx", true)
	(d as Node3D).add_child(g)

func _loot_particles(d: Node3D, col: Color, amount: int, texname: String, rise: float) -> void:
	var p = CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 1.4
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.45
	p.direction = Vector3.UP
	p.spread = 15.0
	p.gravity = Vector3(0, rise, 0)
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.4
	p.scale_amount_min = 0.12 if texname != "flame" else 0.25
	p.scale_amount_max = 0.24 if texname != "flame" else 0.5
	p.mesh = particle_quad()
	p.material_override = particle_mat(true, texname)
	p.color = col.lerp(Color.WHITE, 0.25)
	p.color_ramp = _fade()
	p.position.y = 0.4
	p.set_meta("fx", true)
	d.add_child(p)

func _halo_rings(d: Node3D, col: Color) -> void:
	# Named: three halo rings climbing the beam, phase-offset, looping.
	for i in 3:
		var mi = MeshInstance3D.new()
		var q = PlaneMesh.new()
		q.size = Vector2(1.6, 1.6)
		mi.mesh = q
		var m = shader_mat("res://shaders/ground_ring.gdshader", {"color": col, "ring_width": 0.12})
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("fx", true)
		d.add_child(mi)
		var phase = i / 3.0
		var t = mi.create_tween().set_loops()
		t.tween_method(func(k):
			var u = fmod(k + phase, 1.0)
			mi.position.y = 0.3 + u * 8.7
			m.set_shader_parameter("alpha", 1.0 - u), 0.0, 1.0, 3.0)

func _decorate_fx_node(n) -> void:   # untyped: may receive a freed object
	if not is_instance_valid(n) or n.has_meta("fx"):
		return
	if n is Projectile:
		_decorate_projectile(n)
	elif n is GroundZone:
		_decorate_ground_zone(n)

func _decorate_projectile(p: Projectile) -> void:
	p.set_meta("fx", true)
	var sphere: MeshInstance3D = null
	var old_trail: CPUParticles3D = null
	for c in p.get_children():
		if c is MeshInstance3D and sphere == null:
			sphere = c
		elif c is CPUParticles3D:
			old_trail = c
	var size = float(p.e.get("size", 0.28))
	if p.hostile_to == "player":
		# Enemy shot: dark core, threat-red rim, dark red smoke trail.
		if sphere:
			if not _std_cache.has("enemy_orb"):
				_std_cache["enemy_orb"] = shader_mat("res://shaders/enemy_orb.gdshader")
			sphere.material_override = _std_cache["enemy_orb"]
		if old_trail:
			old_trail.mesh = particle_quad()
			old_trail.material_override = particle_mat(false, "smoke")
			old_trail.color_ramp = _fade()
			old_trail.color = Color(0.35, 0.05, 0.08, 0.8)
			old_trail.scale_amount_min = size * 1.6
			old_trail.scale_amount_max = size * 2.4
		var t = trail(p, THREAT, size * 1.2, 0.18, Vector3.ZERO, 1.0)
		var halo = glow_sprite(Color(1.0, 0.2, 0.2, 0.5), size * 5.0)
		p.add_child(halo)
		return
	var el: String = p.element
	var col: Color = p.color
	var ec = elem_color(el)
	var tcol = col
	var head: Node3D = null
	if old_trail:
		old_trail.mesh = particle_quad()
		old_trail.material_override = particle_mat(true, "spark" if el in ["holy", "lightning", "cold"] else "dot")
		old_trail.color_ramp = _fade()
		old_trail.color = col
		old_trail.scale_amount_min = size * 0.8
		old_trail.scale_amount_max = size * 1.6
	match el:
		"fire":
			if old_trail:
				old_trail.gravity = Vector3(0, 2.5, 0)
				old_trail.color = ec.lerp(col, 0.5)
			p.add_child(glow_sprite(Color(1.0, 0.55, 0.2, 0.8), size * 6.0))
		"cold":
			if sphere:
				sphere.visible = false
			head = _shard_mesh(col.lerp(Color.WHITE, 0.4), size)
			p.add_child(head)
			p.add_child(glow_sprite(Color(0.6, 0.9, 1.0, 0.6), size * 5.0))
		"lightning":
			if sphere:
				sphere.scale = Vector3.ONE * 0.6
			var g = glow_sprite(Color(0.85, 0.9, 1.0, 0.9), size * 6.0, "spark")
			p.add_child(g)
			var tw = g.create_tween().set_loops()
			tw.tween_property(g, "rotation:z", TAU, 0.3).from(0.0)
		"shadow":
			if sphere:
				sphere.material_override = shader_mat("res://shaders/enemy_orb.gdshader", {"rim_color": ec, "core_color": Color(0.06, 0.02, 0.1)})
			tcol = ec
		"holy":
			var g2 = glow_sprite(Color(1.0, 0.95, 0.7, 0.9), size * 6.0, "spark")
			p.add_child(g2)
			var tw2 = g2.create_tween().set_loops()
			tw2.tween_property(g2, "rotation:z", TAU, 0.6).from(0.0)
		_:
			# physical: arrow / bolt / needle streak
			if sphere:
				sphere.visible = false
			head = _streak_mesh(col.lerp(Color.WHITE, 0.3), size)
			p.add_child(head)
	var tr = trail(p, tcol, size * (1.4 if el != "physical" else 0.7), 0.22 if el != "physical" else 0.14)
	if tr and head:
		tr.head = head

func _shard_mesh(col: Color, size: float) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var pm = PrismMesh.new()
	pm.size = Vector3(size * 0.9, size * 3.2, size * 0.9)
	mi.mesh = pm
	mi.material_override = _unshaded_color_mat(col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation_degrees.x = -90
	var holder = Node3D.new()
	holder.add_child(mi)
	return holder

func _streak_mesh(col: Color, size: float) -> Node3D:
	var mi = MeshInstance3D.new()
	var bm = CapsuleMesh.new()
	bm.radius = size * 0.22
	bm.height = size * 4.0
	bm.radial_segments = 6
	bm.rings = 1
	mi.mesh = bm
	mi.material_override = _unshaded_color_mat(col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation_degrees.x = 90
	var holder = Node3D.new()
	holder.add_child(mi)
	return holder

func _decorate_ground_zone(z: GroundZone) -> void:
	z.set_meta("fx", true)
	if z._mat:
		var col: Color = z._mat.get_shader_parameter("color")
		if not _mat_cache.has("res://shaders/ground_zone.gdshader"):
			_mat_cache["res://shaders/ground_zone.gdshader"] = load("res://shaders/ground_zone.gdshader")
		z._mat.shader = _mat_cache["res://shaders/ground_zone.gdshader"]
		z._mat.set_shader_parameter("noise_tex", tex("noise"))
		z._mat.set_shader_parameter("color", col)
		for c in z.get_children():
			if c is CPUParticles3D:
				var p: CPUParticles3D = c
				var el: String = z.element
				p.mesh = particle_quad()
				p.material_override = particle_mat(true, "flame" if el == "fire" else ("spark" if el in ["holy", "cold", "lightning"] else "dot"))
				p.color = col
				p.color_ramp = _fade()
				p.scale_amount_min = 0.2 if el != "fire" else 0.35
				p.scale_amount_max = 0.4 if el != "fire" else 0.7
				p.amount = mini(p.amount, 24)
