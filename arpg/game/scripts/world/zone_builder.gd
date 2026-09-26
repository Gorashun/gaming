class_name ZoneBuilder
extends RefCounted
## Turns a ZoneLayout + biome record into scene nodes. Repeated meshes use MultiMesh (few draw calls).
## Biome record keys: floor[], floor_alt[], wall, wall_near, corner, outdoor(bool), boundary_props[],
## props: [{models[], density, where: "wall"|"room"|"corner"|"center"|"any", scale:[a,b], light:{color,energy,range}}],
## env: {ambient, ambient_energy, fog, fog_density, sky, sun, sun_energy, mist}

const DUN := "res://assets/thirdparty/kaykit/dungeon/models/"
const HAL := "res://assets/thirdparty/kaykit/halloween/models/"

static var _mesh_cache := {}
static var _scene_cache := {}

var root: Node3D
var layout: ZoneLayout
var biome: Dictionary
var rng = RandomNumberGenerator.new()
var lights = []          # [{node, pos}] managed by GameWorld (nearest N active)
var chests = []          # positions for interactive chests
var occupied = {}        # Vector2i -> true (props placed)

static func resolve(path: String) -> String:
	if path.begins_with("res://"):
		return path
	if path.begins_with("hal:"):
		return HAL + path.substr(4) + ".gltf"
	return DUN + path + ".gltf.glb"

static func mesh_of(path: String) -> Array:
	## Returns [[Mesh, Transform3D], ...] for all MeshInstance3D in a glTF scene.
	path = resolve(path)
	if _mesh_cache.has(path):
		return _mesh_cache[path]
	var out = []
	if ResourceLoader.exists(path):
		var inst: Node3D = load(path).instantiate()
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var xf = Transform3D.IDENTITY
			var n: Node = mi
			while n and n != inst:
				xf = (n as Node3D).transform * xf
				n = n.get_parent()
			out.append([mi.mesh, xf])
		inst.free()
	_mesh_cache[path] = out
	return out

static func scene_of(path: String) -> PackedScene:
	path = resolve(path)
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _scene_cache[path]

func build(parent: Node3D, l: ZoneLayout, b: Dictionary, seed_value: int) -> Node3D:
	layout = l
	biome = b
	rng.seed = seed_value
	root = Node3D.new()
	root.name = "Zone"
	parent.add_child(root)
	_build_floor()
	if b.get("outdoor", false):
		_build_outdoor_bounds()
	else:
		_build_walls()
	_build_colliders()
	_scatter_props()
	_build_mist()
	return root

# ------------------------------------------------------------------ floors
func _build_floor() -> void:
	var main: Array = biome.get("floor", ["floor_tile_large"])
	var alt: Array = biome.get("floor_alt", [])
	var buckets = {}
	for c in layout.floor_cells():
		var m: String = main[rng.randi_range(0, main.size() - 1)]
		if alt.size() > 0 and rng.randf() < float(biome.get("floor_alt_chance", 0.15)):
			m = alt[rng.randi_range(0, alt.size() - 1)]
		var xf = Transform3D(Basis(Vector3.UP, rng.randi_range(0, 3) * PI * 0.5), layout.cell_to_world(c))
		if not buckets.has(m):
			buckets[m] = []
		buckets[m].append(xf)
	for m in buckets:
		_multimesh(m, buckets[m])

func _multimesh(model: String, xforms: Array, cast_shadow := false) -> void:
	for part in mesh_of(model):
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = part[0]
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i] * part[1])
		var mmi = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)

# ------------------------------------------------------------------ walls
## Camera looks from +X/+Z towards -X/-Z, so edges on the +X/+Z side face the camera and get low walls.
func _build_walls() -> void:
	var far_wall: String = biome.get("wall", "wall")
	var near_wall: String = biome.get("wall_near", "wall_half")
	var variants: Array = biome.get("wall_variants", ["wall_cracked", "wall_broken"])
	var buckets = {}
	for c in layout.floor_cells():
		var p = layout.cell_to_world(c)
		var half = ZoneLayout.CELL * 0.5
		# -Z edge (north)
		if layout.get_cell(c.x, c.y - 1) == 0:
			_add(buckets, _pick_wall(far_wall, variants), Transform3D(Basis(), p + Vector3(0, 0, -half)))
		# -X edge (west)
		if layout.get_cell(c.x - 1, c.y) == 0:
			_add(buckets, _pick_wall(far_wall, variants), Transform3D(Basis(Vector3.UP, PI * 0.5), p + Vector3(-half, 0, 0)))
		# +Z edge (south, camera side)
		if layout.get_cell(c.x, c.y + 1) == 0:
			_add(buckets, near_wall, Transform3D(Basis(Vector3.UP, PI), p + Vector3(0, 0, half)))
		# +X edge (east, camera side)
		if layout.get_cell(c.x + 1, c.y) == 0:
			_add(buckets, near_wall, Transform3D(Basis(Vector3.UP, -PI * 0.5), p + Vector3(half, 0, 0)))
	for m in buckets:
		_multimesh(m, buckets[m], true)
	# Pillars at outer corners of far walls to hide seams
	var pillars = []
	for c in layout.floor_cells():
		if layout.get_cell(c.x, c.y - 1) == 0 and layout.get_cell(c.x - 1, c.y) == 0:
			pillars.append(Transform3D(Basis(), layout.cell_to_world(c) + Vector3(-2, 0, -2)))
	if pillars.size() > 0:
		_multimesh(biome.get("corner_pillar", "wall_pillar"), pillars, true)

func _pick_wall(base: String, variants: Array) -> String:
	if variants.size() > 0 and rng.randf() < 0.18:
		return variants[rng.randi_range(0, variants.size() - 1)]
	return base

func _add(buckets: Dictionary, m: String, xf: Transform3D) -> void:
	if not buckets.has(m):
		buckets[m] = []
	buckets[m].append(xf)

func _build_outdoor_bounds() -> void:
	# Ring the walkable area with trees/fences/graves just outside floor cells.
	var bprops: Array = biome.get("boundary_props", ["hal:tree_dead_large", "hal:fence", "hal:tree_dead_medium"])
	var buckets = {}
	for c in layout.floor_cells():
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if layout.get_cell(n.x, n.y) == 0 and not occupied.has(n):
				occupied[n] = true
				var base = layout.cell_to_world(n)
				var near = d == Vector2i(1, 0) or d == Vector2i(0, 1)
				for k in (1 if near else 2):
					var m: String = bprops[rng.randi_range(0, bprops.size() - 1)]
					if near and m.contains("tree"):
						m = biome.get("near_boundary", "hal:grave_A")
					var off = Vector3(rng.randf_range(-1.6, 1.6), 0, rng.randf_range(-1.6, 1.6))
					var s = rng.randf_range(0.8, 1.25) * (0.7 if near else 1.0)
					_add(buckets, m, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), base + off))
	for m in buckets:
		_multimesh(m, buckets[m], true)

# ------------------------------------------------------------------ collision
func _build_colliders() -> void:
	var body = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	# One box per void cell that borders floor (cheap and robust)
	for y in range(-1, layout.h + 1):
		for x in range(-1, layout.w + 1):
			if layout.get_cell(x, y) != 0:
				continue
			var borders = false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
				if layout.get_cell(x + d.x, y + d.y) == 1:
					borders = true
			if not borders:
				continue
			var cs = CollisionShape3D.new()
			var bx = BoxShape3D.new()
			bx.size = Vector3(ZoneLayout.CELL, 4, ZoneLayout.CELL)
			cs.shape = bx
			cs.position = layout.cell_to_world(Vector2i(x, y)) + Vector3(0, 2, 0)
			body.add_child(cs)

# ------------------------------------------------------------------ props
func _scatter_props() -> void:
	var start: Rect2i = layout.rooms[layout.start_room].rect
	for spec in biome.get("props", []):
		var models: Array = spec.get("models", [])
		if models.is_empty():
			continue
		var density = float(spec.get("density", 0.1))
		var where: String = spec.get("where", "any")
		var buckets = {}
		for c in layout.floor_cells():
			if occupied.has(c):
				continue
			if not _cell_matches(c, where):
				continue
			if rng.randf() > density:
				continue
			var m: String = models[rng.randi_range(0, models.size() - 1)]
			var p = layout.cell_to_world(c)
			var rot = rng.randi_range(0, 3) * PI * 0.5
			var off = Vector3(rng.randf_range(-1.2, 1.2), 0, rng.randf_range(-1.2, 1.2))
			if where == "wall" or where == "wall_mount":
				var wd = _wall_dir(c)
				off = Vector3(wd.x, 0, wd.y) * (1.35 if where == "wall" else 1.62)
				rot = atan2(-wd.x, -wd.y)
			var sr: Array = spec.get("scale", [1.0, 1.0])
			var s = rng.randf_range(float(sr[0]), float(sr[1]))
			var xf = Transform3D(Basis(Vector3.UP, rot).scaled(Vector3.ONE * s), p + off + Vector3(0, float(spec.get("y", 0.0)), 0))
			if spec.get("blocking", false):
				occupied[c] = true
			if spec.has("light"):
				_add_light(xf.origin + Vector3(0, float(spec.light.get("y", 1.6)), 0), spec.light)
			if spec.get("chest", false):
				if not start.has_point(c):
					chests.append({"pos": xf.origin, "rot": rot, "model": m})
				continue
			_add(buckets, m, xf)
		for m in buckets:
			_multimesh(m, buckets[m], spec.get("shadow", false))

func _cell_matches(c: Vector2i, where: String) -> bool:
	var n = 0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if layout.get_cell(c.x + d.x, c.y + d.y) == 1:
			n += 1
	match where:
		"wall", "wall_mount":
			var wd = _wall_dir(c)
			return wd != Vector2i.ZERO and (wd.x < 0 or wd.y < 0)   # only far walls (visible)
		"corner":
			return n == 2 and _wall_dir(c) != Vector2i.ZERO
		"center":
			return n == 4
		"deadend":
			return n == 1
		_:
			return true

func _wall_dir(c: Vector2i) -> Vector2i:
	for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]:
		if layout.get_cell(c.x + d.x, c.y + d.y) == 0:
			return d
	return Vector2i.ZERO

func _add_light(pos: Vector3, spec: Dictionary) -> void:
	var l = OmniLight3D.new()
	l.light_color = Color(spec.get("color", "#ff9a40"))
	l.light_energy = float(spec.get("energy", 1.4))
	l.omni_range = float(spec.get("range", 7.0))
	l.omni_attenuation = 1.4
	l.shadow_enabled = false
	l.position = pos
	l.visible = false
	root.add_child(l)
	lights.append(l)
	# Emissive halo so unlit torches still read as light sources
	var halo = Sprite3D.new()
	halo.texture = _halo_tex()
	halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	halo.modulate = Color(spec.get("color", "#ff9a40"), 0.55)
	halo.pixel_size = 0.02
	halo.position = pos
	halo.shaded = false
	halo.no_depth_test = false
	var mat = StandardMaterial3D.new()
	root.add_child(halo)

static var _halo: Texture2D
static func _halo_tex() -> Texture2D:
	if _halo:
		return _halo
	var g = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t = GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	_halo = t
	return t

func _build_mist() -> void:
	var env: Dictionary = biome.get("env", {})
	if float(env.get("mist", 0.0)) <= 0.0:
		return
	var mi = MeshInstance3D.new()
	var q = PlaneMesh.new()
	q.size = Vector2(layout.w * ZoneLayout.CELL, layout.h * ZoneLayout.CELL)
	mi.mesh = q
	mi.material_override = Fx.shader_mat("res://shaders/fog_floor.gdshader", {"color": Color(env.get("mist_color", "#5a6680")), "density": float(env.mist)})
	mi.position = Vector3(layout.w * ZoneLayout.CELL * 0.5, 0.35, layout.h * ZoneLayout.CELL * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
