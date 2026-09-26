class_name TargetMarker
extends Node3D
## Aim-free combat readability (owner playtest):
##  • pulsing ring under the CURRENT TARGET in the hero's class colour,
##  • a ground arrow under the hero pointing at the target (or the facing direction),
##  • a faint area preview (arc / circle / line) while a skill button is held.
## Unshaded, no shadows, depth-test on so it sits on the floor; cheap (3 small meshes).

var player: Node3D
var color = Color(1, 0.85, 0.5)
var _ring: MeshInstance3D
var _arrow: MeshInstance3D
var _preview: MeshInstance3D
var _t = 0.0
var _preview_skill: Dictionary = {}
var _preview_dir = Vector3.ZERO

func setup(p: Node3D, col: Color) -> void:
	player = p
	color = col
	_ring = MeshInstance3D.new()
	var tor = TorusMesh.new()
	tor.inner_radius = 0.62
	tor.outer_radius = 0.9
	tor.rings = 32
	tor.ring_segments = 6
	_ring.mesh = tor
	_ring.material_override = _mat(Color(col, 0.9))
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)
	_arrow = MeshInstance3D.new()
	_arrow.mesh = _arrow_mesh()
	_arrow.material_override = _mat(Color(col, 0.55))
	_arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_arrow)
	_preview = MeshInstance3D.new()
	_preview.material_override = _mat(Color(col, 0.22))
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_preview.visible = false
	add_child(_preview)

func _mat(c: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.disable_fog = true
	return m

func _arrow_mesh() -> ArrayMesh:
	## Flat chevron ahead of the hero's feet (local -Z = forward).
	var pts = [Vector3(0, 0, -2.0), Vector3(0.45, 0, -1.35), Vector3(0.2, 0, -1.35), Vector3(0.2, 0, -1.0),
		Vector3(-0.2, 0, -1.0), Vector3(-0.2, 0, -1.35), Vector3(-0.45, 0, -1.35)]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri in [[0, 1, 2], [0, 2, 5], [0, 5, 6], [2, 3, 4], [2, 4, 5]]:
		for i in tri:
			st.add_vertex(pts[i])
	return st.commit()

## Show the area shape of `skill` (resolved skill dict) aimed along `dir` (world, flat) while held.
func show_preview(skill: Dictionary, dir: Vector3) -> void:
	_preview_skill = skill
	_preview_dir = dir
	_preview.mesh = _preview_mesh(skill)
	_preview.visible = _preview.mesh != null

func hide_preview() -> void:
	_preview_skill = {}
	_preview.visible = false

func _preview_mesh(s: Dictionary) -> Mesh:
	var e: Dictionary = {}
	for x in s.get("effects", []):
		if x is Dictionary and str(x.get("type", "")) in ["melee_arc", "aoe", "nova", "ground_zone", "spin", "projectile", "leap", "dash"]:
			e = x
			break
	if e.is_empty():
		return null
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var t = str(e.type)
	if t == "melee_arc":
		var r = float(e.get("radius", 2.3))
		var ang = deg_to_rad(float(e.get("angle", 120)))
		var n = 16
		for i in n:
			var a0 = -ang * 0.5 + ang * i / n
			var a1 = -ang * 0.5 + ang * (i + 1) / n
			st.add_vertex(Vector3.ZERO)
			st.add_vertex(Vector3(sin(a0), 0, -cos(a0)) * r)
			st.add_vertex(Vector3(sin(a1), 0, -cos(a1)) * r)
	elif t in ["projectile", "dash"]:
		var L = float(e.get("range", e.get("distance", 8.0)))
		var w = float(e.get("width", 0.8)) * 0.5
		for v in [Vector3(-w, 0, 0), Vector3(w, 0, 0), Vector3(w, 0, -L), Vector3(-w, 0, 0), Vector3(w, 0, -L), Vector3(-w, 0, -L)]:
			st.add_vertex(v)
	else:
		var r2 = float(e.get("radius", e.get("land_radius", 3.0)))
		var n2 = 24
		for i in n2:
			var a0 = TAU * i / n2
			var a1 = TAU * (i + 1) / n2
			st.add_vertex(Vector3.ZERO)
			st.add_vertex(Vector3(cos(a0), 0, sin(a0)) * r2)
			st.add_vertex(Vector3(cos(a1), 0, sin(a1)) * r2)
		_preview.set_meta("at_target", t in ["aoe", "ground_zone", "leap"])
		return st.commit()
	_preview.set_meta("at_target", false)
	return st.commit()

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_t += delta
	var tgt = player.get("current_target")
	var has_t = tgt != null and is_instance_valid(tgt) and bool(tgt.get("alive"))
	_ring.visible = has_t
	var pp: Vector3 = player.global_position
	var dir: Vector3 = player.get("facing") if player.get("facing") is Vector3 else Vector3.FORWARD
	if has_t:
		var tp: Vector3 = tgt.global_position
		var s = 1.0 + 0.12 * sin(_t * 7.0)
		var rad = float(tgt.get("radius")) if tgt.get("radius") != null else 0.5
		var k = clampf(rad * 1.9, 0.9, 3.0) * s
		_ring.global_position = Vector3(tp.x, 0.06, tp.z)
		_ring.scale = Vector3(k, 0.25, k)
		(_ring.material_override as StandardMaterial3D).albedo_color = Color(color, 0.65 + 0.3 * sin(_t * 7.0))
		var d = tp - pp
		d.y = 0
		if d.length() > 0.3:
			dir = d.normalized()
	dir.y = 0
	if dir.length() < 0.01:
		dir = Vector3.FORWARD
	_arrow.global_position = Vector3(pp.x, 0.05, pp.z)
	_arrow.global_basis = Basis.looking_at(dir.normalized(), Vector3.UP)
	(_arrow.material_override as StandardMaterial3D).albedo_color = Color(color, 0.9 if has_t else 0.5)
	if _preview.visible:
		var pd = _preview_dir if _preview_dir.length() > 0.1 else dir
		pd.y = 0
		if _preview.get_meta("at_target", false) and has_t and _preview_dir.length() < 0.1:
			_preview.global_position = Vector3(tgt.global_position.x, 0.04, tgt.global_position.z)
		elif _preview.get_meta("at_target", false):
			_preview.global_position = Vector3(pp.x, 0.04, pp.z) + pd.normalized() * 5.0
		else:
			_preview.global_position = Vector3(pp.x, 0.04, pp.z)
		_preview.global_basis = Basis.looking_at(pd.normalized(), Vector3.UP)
