extends Node
## Juice library (autoload "Fx"). Everything here is presentation only — never affects game state.

var _mat_cache := {}
var _dmg_pool: Array[Label3D] = []
var camera_rig: Node3D = null   # set by GameWorld; must implement add_trauma(amount)
var _hitstop_until := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func root3d() -> Node3D:
	return Game.world.fx_root if Game.world and "fx_root" in Game.world else null

func shader_mat(path: String, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	if not _mat_cache.has(path):
		_mat_cache[path] = load(path)
	m.shader = _mat_cache[path]
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m

# ---------------------------------------------------------------- feedback
func shake(amount: float) -> void:
	if camera_rig and camera_rig.has_method("add_trauma"):
		camera_rig.add_trauma(amount * float(Settings.get_value("screen_shake", 1.0)))

func hitstop(ms: int) -> void:
	# Brief global slow-down; real time based so it always recovers.
	var now := Time.get_ticks_msec()
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

func damage_number(pos: Vector3, amount: float, crit: bool, color := Color.WHITE, is_player := false) -> void:
	if not Settings.get_value("damage_numbers", true):
		return
	var r := root3d()
	if r == null:
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
		l.outline_modulate = Color(0, 0, 0, 0.85)
		l.render_priority = 10
		l.font = UiTheme.font_bold() if Engine.has_singleton("UiTheme") or ClassDB.class_exists("UiTheme") else null
	r.add_child(l)
	l.text = _fmt(amount) + ("!" if crit else "")
	l.pixel_size = 0.0022 if crit else 0.0016
	l.font_size = 64 if crit else 48
	l.modulate = Color(1.0, 0.85, 0.2) if crit else color
	if is_player:
		l.modulate = Color(1.0, 0.3, 0.3)
	l.global_position = pos + Vector3(randf_range(-0.3, 0.3), 1.8, randf_range(-0.3, 0.3))
	l.scale = Vector3.ONE * (1.6 if crit else 1.0)
	var t := l.create_tween()
	t.set_parallel(true)
	t.tween_property(l, "global_position", l.global_position + Vector3(0, 1.2, 0), 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(l, "scale", Vector3.ONE * (1.1 if crit else 0.8), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.45)
	t.chain().tween_callback(func():
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
	var r := root3d()
	if r == null:
		return
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0018
	l.font_size = size
	l.outline_size = 10
	l.text = text
	l.modulate = color
	r.add_child(l)
	l.global_position = pos + Vector3(0, 2.4, 0)
	var t := l.create_tween()
	t.tween_property(l, "global_position", l.global_position + Vector3(0, 1.0, 0), 1.2)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.7)
	t.tween_callback(l.queue_free)

# ---------------------------------------------------------------- particles
func burst(pos: Vector3, color: Color, amount := 16, speed := 4.0, size := 0.12, lifetime := 0.5, gravity := -6.0) -> void:
	var r := root3d()
	if r == null:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = lifetime
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	mesh.material = m
	p.mesh = mesh
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = grad
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0.2))
	p.scale_amount_curve = curve
	r.add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(lifetime + 0.2).timeout.connect(p.queue_free)

func sparks(pos: Vector3, color := Color(1, 0.8, 0.4)) -> void:
	burst(pos + Vector3(0, 0.9, 0), color, 10, 6.0, 0.08, 0.3, -12.0)

func soul_puff(pos: Vector3, color := Color(0.7, 0.9, 1.0)) -> void:
	# "Rekindled" death: smoke + rising motes (no gore).
	burst(pos + Vector3(0, 0.6, 0), Color(0.25, 0.25, 0.3), 14, 2.0, 0.35, 0.8, 1.5)
	burst(pos + Vector3(0, 0.8, 0), color, 12, 3.0, 0.1, 1.1, 3.5)
	flash_light(pos + Vector3(0, 1, 0), color, 3.0, 0.4)

func flash_light(pos: Vector3, color: Color, energy := 2.0, duration := 0.25, rng := 6.0) -> void:
	var r := root3d()
	if r == null:
		return
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	r.add_child(l)
	l.global_position = pos
	var t := l.create_tween()
	t.tween_property(l, "light_energy", 0.0, duration)
	t.tween_callback(l.queue_free)

# ---------------------------------------------------------------- shapes
func ring(pos: Vector3, radius: float, color: Color, duration := 0.35, grow := true) -> void:
	var r := root3d()
	if r == null:
		return
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(2, 2)
	mi.mesh = q
	var mat := shader_mat("res://shaders/ground_ring.gdshader", {"color": color, "ring_width": 0.18})
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.06, 0)
	mi.scale = Vector3.ONE * (radius * 0.3 if grow else radius)
	var t := mi.create_tween()
	t.set_parallel(true)
	if grow:
		t.tween_property(mi, "scale", Vector3.ONE * radius, duration * 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_method(func(a): mat.set_shader_parameter("alpha", a), 1.0, 0.0, duration)
	t.chain().tween_callback(mi.queue_free)

## Telegraph that fills over `duration` — used by monsters/bosses before big hits.
func telegraph(pos: Vector3, radius: float, duration: float, color := Color(1.0, 0.25, 0.15)) -> Node3D:
	var r := root3d()
	if r == null:
		return null
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(2, 2)
	mi.mesh = q
	var mat := shader_mat("res://shaders/ground_ring.gdshader", {"color": color, "fill": 0.0, "pulse": 1.0})
	mi.material_override = mat
	r.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.07, 0)
	mi.scale = Vector3(radius, 1, radius)
	var t := mi.create_tween()
	t.tween_method(func(f): mat.set_shader_parameter("fill", f), 0.0, 1.0, duration)
	t.tween_callback(mi.queue_free)
	return mi

func slash(origin: Vector3, forward: Vector3, radius: float, angle_deg: float, color := Color(1, 0.9, 0.6), duration := 0.22) -> void:
	var r := root3d()
	if r == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = _arc_mesh(radius, angle_deg)
	var mat := shader_mat("res://shaders/slash.gdshader", {"color": color})
	mi.material_override = mat
	r.add_child(mi)
	mi.global_position = origin + Vector3(0, 0.9, 0)
	var f := forward
	f.y = 0
	if f.length() < 0.01:
		f = Vector3.FORWARD
	mi.look_at(mi.global_position + f.normalized(), Vector3.UP)
	var t := mi.create_tween()
	t.tween_method(func(p): mat.set_shader_parameter("progress", p), 0.0, 1.0, duration)
	t.tween_callback(mi.queue_free)

var _arc_cache := {}
func _arc_mesh(radius: float, angle_deg: float) -> ArrayMesh:
	var key := "%0.2f_%d" % [radius, int(angle_deg)]
	if _arc_cache.has(key):
		return _arc_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 20
	var inner := radius * 0.35
	var half := deg_to_rad(angle_deg) * 0.5
	for i in segs:
		var a0 := -half + (2.0 * half) * i / segs
		var a1 := -half + (2.0 * half) * (i + 1) / segs
		var u0 := float(i) / segs
		var u1 := float(i + 1) / segs
		var p0i := Vector3(sin(a0) * inner, 0, -cos(a0) * inner)
		var p0o := Vector3(sin(a0) * radius, 0, -cos(a0) * radius)
		var p1i := Vector3(sin(a1) * inner, 0, -cos(a1) * inner)
		var p1o := Vector3(sin(a1) * radius, 0, -cos(a1) * radius)
		for v in [[p0i, Vector2(u0, 0)], [p0o, Vector2(u0, 1)], [p1o, Vector2(u1, 1)], [p0i, Vector2(u0, 0)], [p1o, Vector2(u1, 1)], [p1i, Vector2(u1, 0)]]:
			st.set_uv(v[1])
			st.add_vertex(v[0])
	var m := st.commit()
	_arc_cache[key] = m
	return m

func beam(parent: Node3D, color: Color, height := 6.0, width := 0.5) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(width, height)
	q.center_offset = Vector3(0, height * 0.5, 0)
	mi.mesh = q
	mi.material_override = shader_mat("res://shaders/beam.gdshader", {"color": color})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var mi2 := mi.duplicate()
	mi2.rotation_degrees.y = 90
	parent.add_child(mi2)
	return mi
