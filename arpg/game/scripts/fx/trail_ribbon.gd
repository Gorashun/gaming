class_name TrailRibbon
extends MeshInstance3D
## Camera-facing ribbon that follows a node (projectiles, dash/leap, souls). Built each frame
## into one ImmediateMesh strip (1 draw call). Outlives its target: when the target is freed the
## ribbon finishes fading and frees itself. Optionally orients a `head` node along its motion.

var target: Node3D
var offset := Vector3.ZERO
var width := 0.3
var life := 0.25
var min_step := 0.12
var head: Node3D
var max_points := 24
var _pts: Array = []        # [Vector3, time]
var _im := ImmediateMesh.new()
var _t := 0.0
var _last_dir := Vector3.FORWARD

func setup(t: Node3D, color: Color, w := 0.3, lifetime := 0.25, intensity := 1.6) -> TrailRibbon:
	target = t
	width = w
	life = lifetime
	top_level = true
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material_override = Fx.shader_mat("res://shaders/trail.gdshader", {"color": color, "intensity": intensity})
	extra_cull_margin = 16.0
	return self

func _process(delta: float) -> void:
	_t += delta
	var alive = target != null and is_instance_valid(target) and target.is_inside_tree()
	if alive:
		var p = target.global_position + offset
		if _pts.is_empty() or (p - _pts[_pts.size() - 1][0]).length() >= min_step:
			if not _pts.is_empty():
				var d = p - _pts[_pts.size() - 1][0]
				if d.length() > 0.001:
					_last_dir = d.normalized()
			_pts.append([p, _t])
			if _pts.size() > max_points:
				_pts.pop_front()
		if head and is_instance_valid(head) and _last_dir.length() > 0.5:
			var up = Vector3.UP if absf(_last_dir.y) < 0.95 else Vector3.RIGHT
			head.look_at(head.global_position + _last_dir, up)
	else:
		target = null
	while _pts.size() > 0 and _t - float(_pts[0][1]) > life:
		_pts.pop_front()
	if _pts.size() < 2:
		_im.clear_surfaces()
		if not alive:
			queue_free()
		return
	_rebuild(alive)

func _rebuild(alive: bool) -> void:
	var cam = get_viewport().get_camera_3d()
	if cam == null:
		return
	var cp = cam.global_position
	var pts = _pts.duplicate()
	if alive:
		pts.append([target.global_position + offset, _t])
	_im.clear_surfaces()
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n = pts.size()
	for i in n:
		var p: Vector3 = pts[i][0]
		var age = clampf((_t - float(pts[i][1])) / life, 0.0, 1.0)
		var tangent: Vector3
		if i < n - 1:
			tangent = (pts[i + 1][0] - p)
		else:
			tangent = (p - pts[i - 1][0])
		if tangent.length() < 0.0001:
			tangent = _last_dir
		var side = tangent.cross(cp - p).normalized() * width * 0.5 * (1.0 - age * 0.7)
		var a = 1.0 - age
		_im.surface_set_color(Color(1, 1, 1, a))
		_im.surface_set_uv(Vector2(age, 0.0))
		_im.surface_add_vertex(p - side)
		_im.surface_set_color(Color(1, 1, 1, a))
		_im.surface_set_uv(Vector2(age, 1.0))
		_im.surface_add_vertex(p + side)
	_im.surface_end()
