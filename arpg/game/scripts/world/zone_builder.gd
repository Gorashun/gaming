class_name ZoneBuilder
extends RefCounted
## Turns a ZoneLayout + biome record into scene nodes. Repeated meshes use MultiMesh (few draw calls).
## All kit meshes are drawn with ONE shared env shader (shaders/env_kit.gdshader) so the same
## KayKit pieces read as different places per biome (palette remap, snow/moss top layer,
## camera-occlusion dither). See docs/design/ART_BIBLE.md §11 for the biome list.
##
## Biome record keys (all optional except floor):
##  floor[], floor_alt[], floor_alt_chance, wall, wall_near, wall_variants[], corner_pillar,
##  outdoor(bool), corridor_width, boundary_props[], near_boundary, boundary_density,
##  backdrop: [{models[], density, scale:[a,b]}]    props on void cells 2-3 cells outside the floor
##  ground: "#hex"                                   big ground plane under outdoor zones
##  tint:   {color, saturation, brightness, hue, top_color, top_amount, top_scale, emission, emission_strength}
##  floor_tint / wall_tint / boundary_tint: same keys, merged over `tint` for that layer
##  props: [{models[], density, where: "wall"|"wall_mount"|"room"|"corner"|"center"|"deadend"|"any",
##           scale:[a,b], y, blocking, shadow, occlude, tint:{..}, crystal:{base, glow, strength},
##           light:{color, energy, range, y, halo}, chest}]
##  ambient: [{kind: motes|snow|spores|dust|fireflies|embers|ash|wisps, color, amount}]
##  critters: [{kind, color, count, scale, fly(bool)}]      CreatureFactory ambience
##  env: {sky, ambient, ambient_energy, fog, fog_density, fog_height, fog_height_density, sun, sun_energy,
##        sun_pitch, sun_yaw, mist, mist_color, glow, exposure, saturation, contrast, outline}
## Model ids: "name" (dungeon kit), "hal:name" (halloween), "hex:sub/name" (medieval hexagon),
##            "proc:id" (scripts/fx/proc_meshes.gd), or a full res:// path.

const DUN := "res://assets/thirdparty/kaykit/dungeon/models/"
const HAL := "res://assets/thirdparty/kaykit/halloween/models/"
const HEX := "res://assets/thirdparty/kaykit/medieval-hexagon/"
const DUN_ATLAS := "res://assets/thirdparty/kaykit/dungeon/texture/dungeon_texture.png"
const NOISE := "res://assets/generated/textures/noise_rgba.png"
const HEX_SCALE := 4.0   # medieval-hexagon models are authored ~1/4 of the dungeon/halloween kit scale
const ENV_SHADER := "res://shaders/env_kit.gdshader"
const CRYSTAL_SHADER := "res://shaders/crystal.gdshader"

static var _mesh_cache := {}
static var _scene_cache := {}
static var _mat_cache := {}

var root: Node3D
var layout: ZoneLayout
var biome: Dictionary
var rng = RandomNumberGenerator.new()
var lights = []          # [OmniLight3D] managed by GameWorld (nearest N active)
var halos = []           # [Sprite3D] flicker with their light (AmbientFx)
var chests = []          # positions for interactive chests
var occupied = {}        # Vector2i -> true (props placed)

static func resolve(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("proc:"):
		return path
	if path.begins_with("hal:"):
		return HAL + path.substr(4) + ".gltf"
	if path.begins_with("hex:"):
		return HEX + path.substr(4) + ".gltf"
	return DUN + path + ".gltf.glb"

static func mesh_of(path: String) -> Array:
	## Returns [[Mesh, Transform3D], ...] for all MeshInstance3D in a glTF scene (or a proc mesh).
	path = resolve(path)
	if _mesh_cache.has(path):
		return _mesh_cache[path]
	var out = []
	if path.begins_with("proc:"):
		out.append([ProcMeshes.get_mesh(path.substr(5)), Transform3D.IDENTITY])
	elif ResourceLoader.exists(path):
		var inst: Node3D = load(path).instantiate()
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var xf = Transform3D.IDENTITY
			var n: Node = mi
			while n and n != inst:
				xf = (n as Node3D).transform * xf
				n = n.get_parent()
			if path.begins_with(HEX):
				xf = Transform3D(Basis().scaled(Vector3.ONE * HEX_SCALE), Vector3.ZERO) * xf
			out.append([mi.mesh, xf])
		inst.free()
	else:
		push_warning("ZoneBuilder: missing model " + path)
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
	_build_backdrop()
	_build_ground_plane()
	_build_colliders()
	_scatter_props()
	_build_mist()
	_build_ambient()
	_build_critters()
	return root

# ------------------------------------------------------------------ materials
## Merge the biome tint with a layer tint (floor/wall/boundary) and a prop tint.
func _tint_for(layer: String, extra = null) -> Dictionary:
	var t: Dictionary = biome.get("tint", {}).duplicate()
	var lt = biome.get(layer + "_tint", {})
	for k in lt:
		t[k] = lt[k]
	if extra is Dictionary:
		for k in extra:
			t[k] = extra[k]
	return t

## Shared env material for a mesh surface material + tint. Cached across zones (materials are
## few: one per atlas x tint x flags).
static func env_material(src: Material, t: Dictionary, occlude := false, darken := 0.0, vertex_col := false) -> ShaderMaterial:
	var tex: Texture2D = null
	if src is BaseMaterial3D:
		tex = (src as BaseMaterial3D).albedo_texture
	var tex_path = tex.resource_path if tex else ""
	# All 200+ dungeon models ship an identical copy of the atlas: share one texture (VRAM + batching).
	if tex_path.ends_with("_dungeon_texture.png") and ResourceLoader.exists(DUN_ATLAS):
		tex_path = DUN_ATLAS
		tex = load(DUN_ATLAS)
	var key = "%s|%s|%s|%s|%s" % [tex_path if tex_path != "" else str(tex), JSON.stringify(t), occlude, darken, vertex_col]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m = ShaderMaterial.new()
	m.shader = load(ENV_SHADER)
	if tex:
		m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("noise_tex", load(NOISE))
	m.set_shader_parameter("tint", Color(t.get("color", "#ffffff")))
	m.set_shader_parameter("saturation", float(t.get("saturation", 1.0)))
	m.set_shader_parameter("brightness", float(t.get("brightness", 1.0)))
	m.set_shader_parameter("hue_shift", deg_to_rad(float(t.get("hue", 0.0))))
	m.set_shader_parameter("top_color", Color(t.get("top_color", "#ffffff")))
	m.set_shader_parameter("top_amount", float(t.get("top_amount", 0.0)))
	m.set_shader_parameter("top_scale", float(t.get("top_scale", 0.12)))
	m.set_shader_parameter("emission_color", Color(t.get("emission", "#000000")))
	m.set_shader_parameter("emission_strength", float(t.get("emission_strength", 0.0)))
	m.set_shader_parameter("occlude", 1.0 if occlude else 0.0)
	m.set_shader_parameter("ground_darken", darken)
	m.set_shader_parameter("vertex_color_mix", 1.0 if vertex_col else 0.0)
	_mat_cache[key] = m
	return m

static func crystal_material(spec: Dictionary) -> ShaderMaterial:
	var key = "crystal|" + JSON.stringify(spec)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m = ShaderMaterial.new()
	m.shader = load(CRYSTAL_SHADER)
	m.set_shader_parameter("base_color", Color(spec.get("base", "#6f9fc0")))
	m.set_shader_parameter("glow_color", Color(spec.get("glow", "#cfe8f0")))
	m.set_shader_parameter("glow", float(spec.get("strength", 1.2)))
	m.set_shader_parameter("pulse", float(spec.get("pulse", 0.25)))
	_mat_cache[key] = m
	return m

## opts: {layer, tint, occlude, darken, crystal, shadow}
func _multimesh(model: String, xforms: Array, opts := {}) -> void:
	var cast_shadow: bool = opts.get("shadow", false)
	var is_proc = model.begins_with("proc:")
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
		if is_proc and ProcMeshes.material_kind(model.substr(5)) == "crystal":
			mmi.material_override = crystal_material(opts.get("crystal", {}))
		else:
			var src: Material = (part[0] as Mesh).surface_get_material(0) if (part[0] as Mesh).get_surface_count() > 0 else null
			mmi.material_override = env_material(src, _tint_for(opts.get("layer", "prop"), opts.get("tint", null)), opts.get("occlude", false), float(opts.get("darken", 0.0)), is_proc)
		root.add_child(mmi)

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
		_add(buckets, m, xf)
	for m in buckets:
		_multimesh(m, buckets[m], {"layer": "floor"})

# ------------------------------------------------------------------ walls
## Camera looks from +X/+Z towards -X/-Z, so edges on the +X/+Z side face the camera and get low
## walls. Far walls are full height and dither away where they cover the hero (env_kit occlude).
func _build_walls() -> void:
	var far_wall: String = biome.get("wall", "wall")
	var near_wall: String = biome.get("wall_near", "wall_half")
	var variants: Array = biome.get("wall_variants", ["wall_cracked", "wall_broken"])
	var far = {}
	var near = {}
	for c in layout.floor_cells():
		var p = layout.cell_to_world(c)
		var half = ZoneLayout.CELL * 0.5
		if layout.get_cell(c.x, c.y - 1) == 0:
			_add(far, _pick_wall(far_wall, variants), Transform3D(Basis(), p + Vector3(0, 0, -half)))
		if layout.get_cell(c.x - 1, c.y) == 0:
			_add(far, _pick_wall(far_wall, variants), Transform3D(Basis(Vector3.UP, PI * 0.5), p + Vector3(-half, 0, 0)))
		if layout.get_cell(c.x, c.y + 1) == 0:
			_add(near, near_wall, Transform3D(Basis(Vector3.UP, PI), p + Vector3(0, 0, half)))
		if layout.get_cell(c.x + 1, c.y) == 0:
			_add(near, near_wall, Transform3D(Basis(Vector3.UP, -PI * 0.5), p + Vector3(half, 0, 0)))
	for m in far:
		_multimesh(m, far[m], {"layer": "wall", "shadow": true, "occlude": true, "darken": float(biome.get("wall_darken", 0.35))})
	for m in near:
		_multimesh(m, near[m], {"layer": "wall", "shadow": false, "darken": float(biome.get("wall_darken", 0.35)) * 0.6})
	# Pillars at inner corners of far walls to hide seams; outer corners get a pillar too.
	var pillars = []
	for c in layout.floor_cells():
		if layout.get_cell(c.x, c.y - 1) == 0 and layout.get_cell(c.x - 1, c.y) == 0:
			pillars.append(Transform3D(Basis(), layout.cell_to_world(c) + Vector3(-2, 0, -2)))
	if pillars.size() > 0:
		_multimesh(biome.get("corner_pillar", "wall_pillar"), pillars, {"layer": "wall", "shadow": true, "occlude": true})

func _pick_wall(base: String, variants: Array) -> String:
	if variants.size() > 0 and rng.randf() < float(biome.get("wall_variant_chance", 0.18)):
		return variants[rng.randi_range(0, variants.size() - 1)]
	return base

func _add(buckets: Dictionary, m: String, xf: Transform3D) -> void:
	if not buckets.has(m):
		buckets[m] = []
	buckets[m].append(xf)

func _build_outdoor_bounds() -> void:
	# Ring the walkable area with trees/fences/graves just outside floor cells. The camera side
	# (+X/+Z) only gets low props so nothing tall stands between camera and hero.
	var bprops: Array = biome.get("boundary_props", ["hal:tree_dead_large", "hal:fence", "hal:tree_dead_medium"])
	var nprops = biome.get("near_boundary", "hal:grave_A")
	if nprops is String:
		nprops = [nprops]
	var per_cell = int(biome.get("boundary_density", 2))
	var far = {}
	var near_b = {}
	for c in layout.floor_cells():
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if layout.get_cell(n.x, n.y) == 0 and not occupied.has(n):
				occupied[n] = true
				var base = layout.cell_to_world(n)
				var near = d == Vector2i(1, 0) or d == Vector2i(0, 1)
				for k in (1 if near else per_cell):
					var m: String = bprops[rng.randi_range(0, bprops.size() - 1)]
					if near:
						m = nprops[rng.randi_range(0, nprops.size() - 1)]
					var off = Vector3(rng.randf_range(-1.6, 1.6), 0, rng.randf_range(-1.6, 1.6))
					var s = rng.randf_range(0.8, 1.25) * (0.8 if near else 1.0)
					_add(near_b if near else far, m, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), base + off))
	for m in far:
		_multimesh(m, far[m], {"layer": "boundary", "shadow": true, "occlude": true})
	for m in near_b:
		_multimesh(m, near_b[m], {"layer": "boundary", "shadow": false, "occlude": true})

## Silhouette dressing further out (forest mass, rocks, mountains) so the zone edge never reads
## as floating in a void. Only on void cells 2-3 cells from the floor, far (-X/-Z) side mostly.
func _build_backdrop() -> void:
	var specs: Array = biome.get("backdrop", [])
	if specs.is_empty():
		return
	var dist = _void_distance(3)
	for spec in specs:
		var models: Array = spec.get("models", [])
		if models.is_empty():
			continue
		var buckets = {}
		var dmin = int(spec.get("min_dist", 2))
		var dmax = int(spec.get("max_dist", 3))
		for cell in dist:
			var dd: int = dist[cell]
			if dd < dmin or dd > dmax:
				continue
			if rng.randf() > float(spec.get("density", 0.5)):
				continue
			var m: String = models[rng.randi_range(0, models.size() - 1)]
			var sr: Array = spec.get("scale", [1.0, 1.4])
			var s = rng.randf_range(float(sr[0]), float(sr[1]))
			var off = Vector3(rng.randf_range(-1.4, 1.4), float(spec.get("y", 0.0)), rng.randf_range(-1.4, 1.4))
			_add(buckets, m, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), layout.cell_to_world(cell) + off))
		for m in buckets:
			_multimesh(m, buckets[m], {"layer": "boundary", "tint": spec.get("tint", null), "occlude": true})

## BFS distance (in cells) from the walkable area for void cells up to `maxd`.
func _void_distance(maxd: int) -> Dictionary:
	var out = {}
	var frontier = layout.floor_cells()
	var seen = {}
	for c in frontier:
		seen[c] = true
	for dstep in range(1, maxd + 1):
		var nxt = []
		for c in frontier:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + d
				if seen.has(n):
					continue
				seen[n] = true
				if layout.get_cell(n.x, n.y) == 0:
					out[n] = dstep
					nxt.append(n)
		frontier = nxt
	return out

func _build_ground_plane() -> void:
	if not biome.has("ground"):
		return
	var mi = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	var ext = Vector2(layout.w * ZoneLayout.CELL + 60.0, layout.h * ZoneLayout.CELL + 60.0)
	pm.size = ext
	mi.mesh = pm
	var t = _tint_for("floor")
	t["color"] = biome.ground
	t["saturation"] = 1.0
	t["brightness"] = 1.0
	mi.material_override = env_material(null, t)
	mi.position = Vector3(layout.w * ZoneLayout.CELL * 0.5, float(biome.get("ground_y", -0.04)), layout.h * ZoneLayout.CELL * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

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
			if spec.get("free_rot", false):
				rot = rng.randf() * TAU
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
			_multimesh(m, buckets[m], {"layer": "prop", "tint": spec.get("tint", null), "shadow": spec.get("shadow", false),
				"occlude": spec.get("occlude", false), "crystal": spec.get("crystal", {})})

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
		"room":
			return n >= 3
		"deadend":
			return n == 1
		_:
			return true

func _wall_dir(c: Vector2i) -> Vector2i:
	for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]:
		if layout.get_cell(c.x + d.x, c.y + d.y) == 0:
			return d
	return Vector2i.ZERO

## Torch/lantern light: a real OmniLight (GameWorld keeps only the 3 nearest visible) plus an
## always-on additive halo so out-of-budget torches still read as light sources.
func _add_light(pos: Vector3, spec: Dictionary) -> void:
	var col = Color(spec.get("color", "#ff9a40"))
	var l = OmniLight3D.new()
	l.light_color = col
	l.light_energy = float(spec.get("energy", 1.4))
	l.omni_range = float(spec.get("range", 7.0))
	l.omni_attenuation = 1.3
	l.shadow_enabled = false
	l.position = pos
	l.visible = false
	l.set_meta("base_energy", l.light_energy)
	root.add_child(l)
	lights.append(l)
	var halo = Sprite3D.new()
	halo.texture = Fx.tex("dot")
	halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	halo.modulate = Color(col, float(spec.get("halo", 0.5)))
	halo.pixel_size = 0.03 * float(spec.get("halo_size", 1.0))
	halo.position = pos
	halo.shaded = false
	halo.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.material_override = Fx.additive_sprite_mat()
	root.add_child(halo)
	halos.append(halo)

func _build_mist() -> void:
	var env: Dictionary = biome.get("env", {})
	if float(env.get("mist", 0.0)) <= 0.0:
		return
	var mi = MeshInstance3D.new()
	var q = PlaneMesh.new()
	q.size = Vector2(layout.w * ZoneLayout.CELL + 40.0, layout.h * ZoneLayout.CELL + 40.0)
	mi.mesh = q
	mi.material_override = Fx.shader_mat("res://shaders/fog_floor.gdshader", {"color": Color(env.get("mist_color", "#5a6680")),
		"density": float(env.mist), "noise_tex": load(NOISE), "scale": float(env.get("mist_scale", 0.05))})
	mi.position = Vector3(layout.w * ZoneLayout.CELL * 0.5, float(env.get("mist_y", 0.45)), layout.h * ZoneLayout.CELL * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

func _build_ambient() -> void:
	var af = preload("res://scripts/fx/ambient_fx.gd").new()
	af.name = "AmbientFx"
	root.add_child(af)
	af.setup(biome.get("ambient", []), lights, halos)

func _build_critters() -> void:
	if biome.get("showcase_creatures", false):
		_build_showcase()
	var specs: Array = biome.get("critters", [])
	if specs.is_empty():
		return
	var cells = layout.floor_cells()
	var start: Rect2i = layout.rooms[layout.start_room].rect
	for spec in specs:
		for i in int(spec.get("count", 3)):
			var c: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
			var cr = CreatureFactory.build(str(spec.get("kind", "crow")), Color(spec.get("color", "#6a6070")), float(spec.get("scale", 0.6)))
			cr.set_meta("ambient", true)
			root.add_child(cr)
			var p = layout.cell_to_world(c) + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5))
			if spec.get("fly", false):
				p.y = rng.randf_range(2.5, 4.0)
			cr.position = p
			cr.rotation.y = rng.randf() * TAU
			if spec.get("wander", true) and cr.has_method("set_wander"):
				cr.set_wander(float(spec.get("wander_radius", 2.5)), spec.get("fly", false))

## Dev showcase (content/dev_art "dev_menagerie"): every CreatureFactory kind in two rings.
func _build_showcase() -> void:
	var center = layout.cell_to_world(layout.rooms[layout.start_room].center)
	var cols = ["#8fd9a0", "#ffb54a", "#3a3040", "#9a88b8", "#b8a8ff", "#6ab88a", "#c8c8d8", "#2c2834", "#2a2434", "#4a6a48",
		"#5a5060", "#8a7a6a", "#d8703a", "#8a6a9a", "#e8e0d8", "#5a5a68", "#6a4a3a", "#8a6a4a", "#7a8aa8", "#3a5a6a"]
	var small = CreatureFactory.SMALL
	for i in small.size():
		var a = TAU * i / small.size()
		var c = CreatureFactory.build(small[i], Color(cols[i % cols.size()]), 1.5, {"eyes": "glow" if i % 4 == 3 else "cute"})
		root.add_child(c)
		c.position = center + Vector3(cos(a), 0, sin(a)) * 5.0 + (Vector3(0, 1.4, 0) if small[i] in ["bat", "moth", "lantern_moth"] else Vector3.ZERO)
		c.rotation.y = deg_to_rad(45.0)
		_showcase_label(c, small[i])
	var mounts = CreatureFactory.MOUNTS
	for i in mounts.size():
		var a = TAU * i / mounts.size() + 0.3
		var m = CreatureFactory.build(mounts[i], Color(cols[(i + 15) % cols.size()]), 1.3, {"outline": true})
		root.add_child(m)
		m.position = center + Vector3(cos(a), 0, sin(a)) * 9.5
		m.rotation.y = deg_to_rad(45.0)
		_showcase_label(m, mounts[i])
	# loot beam ladder (Art Bible 3) + a Hushfall tear, for VFX review
	var rar = ["magic", "rare", "epic", "legendary", "mythic", "unique", "named"]
	for i in rar.size():
		var d = Node3D.new()
		root.add_child(d)
		d.position = center + Vector3(-13.0 + i * 2.6, 0, -13.0 + i * 2.6) + Vector3(3, 0, -3)
		Fx.decorate_drop(d, rar[i])
		_showcase_label(d, rar[i])
	var tear_at = Node3D.new()
	root.add_child(tear_at)
	tear_at.position = center + Vector3(-9, 0, 5)
	Fx.hush_tear(tear_at)

func _showcase_label(n: Node3D, text: String) -> void:
	var l = Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.pixel_size = 0.001
	l.font_size = 20
	l.outline_size = 8
	l.position.y = 2.2 / maxf(0.3, n.scale.y)
	l.no_depth_test = true
	n.add_child(l)
