class_name ProcMeshes
extends RefCounted
## Procedural low-poly meshes that fill gaps in the KayKit kits (flat-shaded, vertex coloured,
## chunky toy proportions so they sit next to KayKit props). Referenced from biomes as "proc:<id>".
## Every mesh is built once and cached. Vertex COLOR.r is a brightness/variation channel the
## crystal shader uses; COLOR.rgb is the albedo for the non-crystal meshes (env_kit vertex_color_mix).
##
## ids: crystal_cluster, crystal_small, ice_cluster, stalagmite, rock_pile, mushroom_glow,
##      minecart, rails, hush_obelisk, snow_mound, root_arch, lily_pads, bone_spire

static var _cache := {}

## Material "family" of a proc mesh: "crystal" meshes use crystal.gdshader, the rest env_kit.
static func material_kind(id: String) -> String:
	if id in ["crystal_cluster", "crystal_small", "ice_cluster", "mushroom_glow"]:
		return "crystal"
	return "kit"

static func get_mesh(id: String) -> Mesh:
	if _cache.has(id):
		return _cache[id]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r = RandomNumberGenerator.new()
	r.seed = hash(id)
	match id:
		"crystal_cluster":
			_crystal(st, Vector3.ZERO, 0.28, 1.6, Vector3(0, 0, 0), 1.0)
			_crystal(st, Vector3(0.35, 0, 0.1), 0.2, 1.0, Vector3(0.35, 0, -0.3), 0.8)
			_crystal(st, Vector3(-0.3, 0, 0.2), 0.18, 0.85, Vector3(-0.2, 0, 0.45), 0.75)
			_crystal(st, Vector3(0.05, 0, -0.35), 0.16, 0.7, Vector3(0.1, 0, -0.5), 0.7)
			_crystal(st, Vector3(-0.15, 0, -0.1), 0.12, 0.5, Vector3(-0.5, 0, 0.0), 0.6)
		"crystal_small":
			_crystal(st, Vector3.ZERO, 0.16, 0.8, Vector3(0.1, 0, 0), 1.0)
			_crystal(st, Vector3(0.18, 0, 0.08), 0.1, 0.45, Vector3(0.4, 0, 0.2), 0.8)
		"ice_cluster":
			for i in 6:
				var a = TAU * i / 6.0 + r.randf_range(-0.3, 0.3)
				var d = r.randf_range(0.05, 0.4)
				_crystal(st, Vector3(cos(a) * d, 0, sin(a) * d), r.randf_range(0.1, 0.22), r.randf_range(0.6, 1.8), Vector3(cos(a), 0, sin(a)) * r.randf_range(0.1, 0.35), r.randf_range(0.7, 1.0), 4)
		"mushroom_glow":
			for i in 4:
				var a = TAU * i / 4.0 + r.randf_range(-0.4, 0.4)
				var d = 0.0 if i == 0 else r.randf_range(0.25, 0.5)
				var h = 0.6 if i == 0 else r.randf_range(0.25, 0.45)
				var base = Vector3(cos(a) * d, 0, sin(a) * d)
				_cylinder(st, base, 0.05 + h * 0.06, 0.04 + h * 0.05, h, 6, Color(0.35, 0.35, 0.35))
				_dome(st, base + Vector3(0, h, 0), 0.14 + h * 0.35, 0.08 + h * 0.18, 8, Color(1, 1, 1))
		"stalagmite":
			_cone(st, Vector3.ZERO, 0.55, 2.2, 7, Color(0.42, 0.36, 0.32), r)
			_cone(st, Vector3(0.5, 0, 0.25), 0.3, 1.2, 6, Color(0.38, 0.33, 0.3), r)
			_cone(st, Vector3(-0.35, 0, 0.4), 0.22, 0.8, 6, Color(0.45, 0.39, 0.34), r)
		"rock_pile":
			for i in 5:
				var p = Vector3(r.randf_range(-0.5, 0.5), 0, r.randf_range(-0.5, 0.5))
				_rock(st, p, r.randf_range(0.2, 0.45), Color(0.42, 0.38, 0.36), r)
		"bone_spire":
			_cone(st, Vector3.ZERO, 0.35, 1.8, 6, Color(0.85, 0.82, 0.74), r)
			_cone(st, Vector3(0.3, 0, 0.1), 0.2, 1.0, 6, Color(0.8, 0.78, 0.7), r)
		"minecart":
			var wood = Color(0.45, 0.3, 0.2)
			var iron = Color(0.3, 0.3, 0.34)
			_box(st, Vector3(0, 0.55, 0), Vector3(1.3, 0.12, 0.9), iron)
			_box(st, Vector3(0, 0.85, 0.42), Vector3(1.3, 0.55, 0.08), wood)
			_box(st, Vector3(0, 0.85, -0.42), Vector3(1.3, 0.55, 0.08), wood)
			_box(st, Vector3(0.62, 0.85, 0), Vector3(0.08, 0.55, 0.9), wood)
			_box(st, Vector3(-0.62, 0.85, 0), Vector3(0.08, 0.55, 0.9), wood)
			_box(st, Vector3(0, 1.1, 0.46), Vector3(1.36, 0.06, 0.06), iron)
			_box(st, Vector3(0, 1.1, -0.46), Vector3(1.36, 0.06, 0.06), iron)
			for sx in [-0.42, 0.42]:
				for sz in [-0.5, 0.5]:
					_wheel(st, Vector3(sx, 0.28, sz), 0.26, 0.1, iron)
			# a few ore lumps
			for i in 4:
				_rock(st, Vector3(r.randf_range(-0.4, 0.4), 1.05, r.randf_range(-0.25, 0.25)), 0.16, Color(0.36, 0.32, 0.3), r)
		"rails":
			var iron2 = Color(0.32, 0.32, 0.36)
			var wood2 = Color(0.36, 0.25, 0.18)
			for i in 5:
				_box(st, Vector3(-1.6 + i * 0.8, 0.05, 0), Vector3(0.22, 0.08, 1.3), wood2)
			_box(st, Vector3(0, 0.13, 0.45), Vector3(4.0, 0.08, 0.07), iron2)
			_box(st, Vector3(0, 0.13, -0.45), Vector3(4.0, 0.08, 0.07), iron2)
		"hush_obelisk":
			var stone = Color(0.42, 0.42, 0.45)
			_box(st, Vector3(0, 0.15, 0), Vector3(1.1, 0.3, 1.1), stone.darkened(0.2))
			_taper(st, Vector3(0, 0.3, 0), 0.38, 0.24, 2.6, stone)
			_pyramid(st, Vector3(0, 2.9, 0), 0.24, 0.35, stone.lightened(0.1))
		"snow_mound":
			_dome(st, Vector3.ZERO, 0.9, 0.35, 10, Color(0.92, 0.95, 1.0))
			_dome(st, Vector3(0.6, 0, 0.3), 0.5, 0.22, 8, Color(0.9, 0.93, 1.0))
		"root_arch":
			var bark = Color(0.28, 0.22, 0.2)
			var pts = []
			for i in 9:
				var t = float(i) / 8.0
				pts.append(Vector3(lerpf(-1.4, 1.4, t), sin(t * PI) * 2.2, sin(t * 7.0) * 0.15))
			_tube(st, pts, 0.28, 0.12, 6, bark)
			var pts2 = []
			for i in 6:
				var t = float(i) / 5.0
				pts2.append(Vector3(lerpf(-1.0, 0.2, t), sin(t * PI) * 1.2, 0.35 + t * 0.2))
			_tube(st, pts2, 0.16, 0.06, 5, bark.lightened(0.05))
		"lily_pads":
			for i in 5:
				var p = Vector3(r.randf_range(-1.2, 1.2), 0.06, r.randf_range(-1.2, 1.2))
				_disc(st, p, r.randf_range(0.25, 0.45), 9, Color(0.3, 0.42, 0.3), r.randf() * TAU)
		_:
			_box(st, Vector3(0, 0.5, 0), Vector3.ONE, Color.MAGENTA)
	st.generate_normals()
	var m = st.commit()
	_cache[id] = m
	return m

# ------------------------------------------------------------------ primitives (flat shaded)
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	st.set_smooth_group(-1)
	st.set_color(col)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	_tri(st, a, b, c, col)
	_tri(st, a, c, d, col)

## Hexagonal crystal: prism + pointed tip, leaning towards `lean`. COLOR.r = brightness.
static func _crystal(st: SurfaceTool, base: Vector3, radius: float, height: float, lean: Vector3, bright: float, sides := 6) -> void:
	var top = base + Vector3(lean.x, height, lean.z)
	var shoulder = base.lerp(top, 0.72)
	var ring_b = []
	var ring_s = []
	for i in sides:
		var a = TAU * i / sides
		var off = Vector3(cos(a), 0, sin(a)) * radius
		ring_b.append(base + off * 0.9 - Vector3(0, 0.1, 0))
		ring_s.append(shoulder + off)
	for i in sides:
		var j = (i + 1) % sides
		var c1 = Color(bright * 0.55, 0, 0)
		var c2 = Color(bright, 0, 0)
		# side face (darker at the root)
		st.set_smooth_group(-1)
		st.set_color(c1); st.add_vertex(ring_b[i])
		st.set_color(c2); st.add_vertex(ring_s[j])
		st.set_color(c1); st.add_vertex(ring_b[j])
		st.set_color(c1); st.add_vertex(ring_b[i])
		st.set_color(c2); st.add_vertex(ring_s[i])
		st.set_color(c2); st.add_vertex(ring_s[j])
		# tip
		st.set_color(c2); st.add_vertex(ring_s[i])
		st.set_color(Color(bright * 1.2, 0, 0)); st.add_vertex(top)
		st.set_color(c2); st.add_vertex(ring_s[j])

static func _cylinder(st: SurfaceTool, base: Vector3, r0: float, r1: float, h: float, sides: int, col: Color) -> void:
	for i in sides:
		var a0 = TAU * i / sides
		var a1 = TAU * (i + 1) / sides
		var p0 = base + Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var p1 = base + Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var q0 = base + Vector3(cos(a0) * r1, h, sin(a0) * r1)
		var q1 = base + Vector3(cos(a1) * r1, h, sin(a1) * r1)
		_quad(st, p0, q0, q1, p1, col)

static func _taper(st: SurfaceTool, base: Vector3, r0: float, r1: float, h: float, col: Color) -> void:
	# square tapered pillar (obelisk)
	var b = [Vector3(-r0, 0, -r0), Vector3(r0, 0, -r0), Vector3(r0, 0, r0), Vector3(-r0, 0, r0)]
	var t = [Vector3(-r1, h, -r1), Vector3(r1, h, -r1), Vector3(r1, h, r1), Vector3(-r1, h, r1)]
	for i in 4:
		var j = (i + 1) % 4
		_quad(st, base + b[i], base + t[i], base + t[j], base + b[j], col)

static func _pyramid(st: SurfaceTool, base: Vector3, r: float, h: float, col: Color) -> void:
	var b = [Vector3(-r, 0, -r), Vector3(r, 0, -r), Vector3(r, 0, r), Vector3(-r, 0, r)]
	for i in 4:
		var j = (i + 1) % 4
		_tri(st, base + b[i], base + Vector3(0, h, 0), base + b[j], col)

static func _cone(st: SurfaceTool, base: Vector3, radius: float, h: float, sides: int, col: Color, r: RandomNumberGenerator) -> void:
	var tip = base + Vector3(r.randf_range(-0.1, 0.1), h, r.randf_range(-0.1, 0.1))
	var mid = []
	var bot = []
	for i in sides:
		var a = TAU * i / sides
		var rr = radius * r.randf_range(0.85, 1.1)
		bot.append(base + Vector3(cos(a) * rr, -0.05, sin(a) * rr))
		mid.append(base.lerp(tip, 0.45) + Vector3(cos(a + 0.3) * rr * 0.55, 0, sin(a + 0.3) * rr * 0.55))
	for i in sides:
		var j = (i + 1) % sides
		var c = col.lightened(r.randf_range(-0.08, 0.08))
		_quad(st, bot[i], mid[i], mid[j], bot[j], c)
		_tri(st, mid[i], tip, mid[j], c.lightened(0.06))

static func _rock(st: SurfaceTool, c: Vector3, s: float, col: Color, r: RandomNumberGenerator) -> void:
	# squashed octahedron-ish lump
	var pts = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
	var top = c + Vector3(r.randf_range(-0.2, 0.2) * s, s * 0.9, 0)
	var ring = []
	for i in 6:
		var a = TAU * i / 6.0 + r.randf_range(-0.2, 0.2)
		ring.append(c + Vector3(cos(a), 0.15, sin(a)) * s * r.randf_range(0.8, 1.2))
	for i in 6:
		var j = (i + 1) % 6
		_tri(st, ring[i], top, ring[j], col.lightened(r.randf_range(-0.06, 0.1)))
		_tri(st, ring[j], c - Vector3(0, s * 0.2, 0), ring[i], col.darkened(0.2))

static func _box(st: SurfaceTool, c: Vector3, size: Vector3, col: Color) -> void:
	var h = size * 0.5
	var v = [c + Vector3(-h.x, -h.y, -h.z), c + Vector3(h.x, -h.y, -h.z), c + Vector3(h.x, h.y, -h.z), c + Vector3(-h.x, h.y, -h.z),
		c + Vector3(-h.x, -h.y, h.z), c + Vector3(h.x, -h.y, h.z), c + Vector3(h.x, h.y, h.z), c + Vector3(-h.x, h.y, h.z)]
	_quad(st, v[0], v[3], v[2], v[1], col.darkened(0.1))   # -z
	_quad(st, v[4], v[5], v[6], v[7], col.darkened(0.1))   # +z
	_quad(st, v[0], v[4], v[7], v[3], col.darkened(0.15))  # -x
	_quad(st, v[1], v[2], v[6], v[5], col.darkened(0.15))  # +x
	_quad(st, v[3], v[7], v[6], v[2], col.lightened(0.08)) # top
	_quad(st, v[0], v[1], v[5], v[4], col.darkened(0.3))   # bottom

static func _wheel(st: SurfaceTool, c: Vector3, radius: float, width: float, col: Color) -> void:
	var sides = 8
	for i in sides:
		var a0 = TAU * i / sides
		var a1 = TAU * (i + 1) / sides
		var p0 = Vector3(cos(a0) * radius, sin(a0) * radius, 0)
		var p1 = Vector3(cos(a1) * radius, sin(a1) * radius, 0)
		var dz = Vector3(0, 0, width * 0.5)
		_quad(st, c + p0 - dz, c + p1 - dz, c + p1 + dz, c + p0 + dz, col)
		_tri(st, c + dz, c + p0 + dz, c + p1 + dz, col.darkened(0.2))
		_tri(st, c - dz, c + p1 - dz, c + p0 - dz, col.darkened(0.2))

static func _dome(st: SurfaceTool, c: Vector3, radius: float, h: float, sides: int, col: Color) -> void:
	var rings = 3
	for k in rings:
		var t0 = float(k) / rings
		var t1 = float(k + 1) / rings
		var r0 = cos(t0 * PI * 0.5) * radius
		var r1 = cos(t1 * PI * 0.5) * radius
		var y0 = sin(t0 * PI * 0.5) * h
		var y1 = sin(t1 * PI * 0.5) * h
		for i in sides:
			var a0 = TAU * i / sides
			var a1 = TAU * (i + 1) / sides
			var p00 = c + Vector3(cos(a0) * r0, y0, sin(a0) * r0)
			var p01 = c + Vector3(cos(a1) * r0, y0, sin(a1) * r0)
			var p10 = c + Vector3(cos(a0) * r1, y1, sin(a0) * r1)
			var p11 = c + Vector3(cos(a1) * r1, y1, sin(a1) * r1)
			if k == rings - 1:
				_tri(st, p00, p10, p01, col)
			else:
				_quad(st, p00, p10, p11, p01, col)
	# underside
	for i in sides:
		var a0 = TAU * i / sides
		var a1 = TAU * (i + 1) / sides
		_tri(st, c, c + Vector3(cos(a0) * radius, 0, sin(a0) * radius), c + Vector3(cos(a1) * radius, 0, sin(a1) * radius), col.darkened(0.4))

static func _disc(st: SurfaceTool, c: Vector3, radius: float, sides: int, col: Color, notch: float) -> void:
	for i in sides:
		var a0 = TAU * i / sides + notch
		var a1 = TAU * (i + 1) / sides + notch
		if i == 0:
			continue   # the lily-pad notch
		_tri(st, c, c + Vector3(cos(a1) * radius, 0, sin(a1) * radius), c + Vector3(cos(a0) * radius, 0, sin(a0) * radius), col.lightened(0.05 * (i % 2)))

static func _tube(st: SurfaceTool, pts: Array, r0: float, r1: float, sides: int, col: Color) -> void:
	for k in pts.size() - 1:
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[k + 1]
		var ra = lerpf(r0, r1, float(k) / (pts.size() - 1))
		var rb = lerpf(r0, r1, float(k + 1) / (pts.size() - 1))
		var dir = (b - a).normalized()
		var side = dir.cross(Vector3.FORWARD).normalized()
		if side.length() < 0.1:
			side = Vector3.RIGHT
		var up = side.cross(dir).normalized()
		for i in sides:
			var a0 = TAU * i / sides
			var a1 = TAU * (i + 1) / sides
			var o0 = (side * cos(a0) + up * sin(a0))
			var o1 = (side * cos(a1) + up * sin(a1))
			_quad(st, a + o0 * ra, b + o0 * rb, b + o1 * rb, a + o1 * ra, col.lightened(0.04 * (i % 2)))
