class_name CreatureFactory
extends RefCounted
## Cute chibi creatures built from primitives with the shared toon look (toon_actor.gdshader),
## animated procedurally by CreatureAnim (bob, wing flaps, walk cycles, hops, squash).
## Used for pets, mounts, ambient critters and monster families that lack a KayKit model.
##
##   var c = CreatureFactory.build("owl", Color("#8a7a6a"), 0.6)
##   add_child(c)                      # faces +Z like KayKit actors
##   c.set_moving(true)                # walk/fly cycle (auto-detected from motion too)
##   c.attack()  /  c.hurt()           # lunge / squash reaction
##   c.set_wander(3.0, false)          # ambient critter: roam around its spawn point
##   c.get_node("Saddle")              # mounts only: rider attach point (Marker3D)
##
## Options (4th arg): {eyes: "cute"|"glow", eye_color: Color, outline: bool, glow: Color}
## "glow" eyes = emissive family-accent eyes for monsters (Art Bible 7); "cute" = dark eyes with a
## white catch-light for pets. Tris per creature: 300-1500 (primitives with low segment counts).

const SMALL := ["wisp", "wick", "bat", "moth", "lantern_moth", "slime", "ghost", "crow", "spider", "frog", "cat", "owl", "fox", "snail", "bunny"]
const MOUNTS := ["wolf", "boar", "stag", "giant_snail", "lantern_beetle"]
const TOON := "res://shaders/toon_actor.gdshader"

static var _mats := {}
static var _meshes := {}

static func kinds() -> Array:
	return SMALL + MOUNTS

static func is_mount(kind: String) -> bool:
	return MOUNTS.has(kind)

static func build(kind: String, color: Color, scale: float = 1.0, opts: Dictionary = {}) -> Node3D:
	var root = CreatureAnim.new()
	root.name = kind.capitalize().replace(" ", "")
	root.kind = kind
	var body = Node3D.new()
	body.name = "Body"
	root.add_child(body)
	root.body = body
	var eyes: String = opts.get("eyes", "cute")
	var eye_col: Color = opts.get("eye_color", Color("#ffd27a") if eyes == "glow" else Color("#1a1420"))
	var ctx = {"root": root, "eyes": eyes, "eye_col": eye_col, "col": color, "glow": opts.get("glow", color.lightened(0.35))}
	match kind:
		"wisp": _wisp(ctx, body, false)
		"wick": _wisp(ctx, body, true)
		"bat": _bat(ctx, body)
		"moth": _moth(ctx, body, false)
		"lantern_moth": _moth(ctx, body, true)
		"slime": _slime(ctx, body)
		"ghost": _ghost(ctx, body)
		"crow": _crow(ctx, body)
		"spider": _spider(ctx, body)
		"frog": _frog(ctx, body)
		"cat": _quadruped(ctx, body, {"len": 0.55, "h": 0.32, "head": 0.3, "ears": "cat", "tail": "thin", "snout": 0.0})
		"fox": _quadruped(ctx, body, {"len": 0.6, "h": 0.32, "head": 0.28, "ears": "fox", "tail": "bushy", "snout": 0.16, "chest": Color("#f4ead8")})
		"owl": _owl(ctx, body)
		"snail": _snail(ctx, body, 1.0, false)
		"bunny": _bunny(ctx, body)
		"wolf": _quadruped(ctx, body, {"len": 1.3, "h": 0.8, "head": 0.42, "ears": "fox", "tail": "bushy", "snout": 0.3, "chest": color.lightened(0.35), "mount": true})
		"boar": _quadruped(ctx, body, {"len": 1.25, "h": 0.62, "head": 0.45, "ears": "boar", "tail": "thin", "snout": 0.25, "tusks": true, "fat": 1.35, "mount": true})
		"stag": _quadruped(ctx, body, {"len": 1.2, "h": 1.0, "head": 0.36, "ears": "stag", "tail": "stub", "snout": 0.22, "antlers": true, "slim": 0.75, "mount": true, "chest": color.lightened(0.3)})
		"giant_snail": _snail(ctx, body, 2.4, true)
		"lantern_beetle": _beetle(ctx, body)
		_:
			push_warning("CreatureFactory: unknown kind " + kind)
			_slime(ctx, body)
	root.scale = Vector3.ONE * scale
	if opts.get("outline", false):
		var om = Fx.shader_mat("res://shaders/outline.gdshader", {"thickness": 0.02 / maxf(0.3, scale), "outline_color": Color("#120c18")})
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).material_override is ShaderMaterial:
				(mi as GeometryInstance3D).material_overlay = om
	root.setup_anim()
	return root

# ------------------------------------------------------------------ materials & primitives
static func toon(c: Color, glow := 0.0) -> ShaderMaterial:
	var key = "%s_%0.2f" % [c.to_html(), glow]
	if not _mats.has(key):
		var m = ShaderMaterial.new()
		m.shader = load(TOON)
		m.set_shader_parameter("albedo", c)
		m.set_shader_parameter("rim_amount", 0.4)
		m.set_shader_parameter("emission_boost", glow)
		_mats[key] = m
	return _mats[key]

static func glow_mat(c: Color) -> StandardMaterial3D:
	var key = "glow_" + c.to_html()
	if not _mats.has(key):
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = c
		m.disable_fog = true
		_mats[key] = m
	return _mats[key]

static func _sphere_mesh(seg: int) -> SphereMesh:
	var key = "s%d" % seg
	if not _meshes.has(key):
		var s = SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = seg
		s.rings = maxi(3, seg / 2)
		_meshes[key] = s
	return _meshes[key]

static func _part(parent: Node3D, mesh: Mesh, pos: Vector3, size: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = size
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func sphere(parent: Node3D, pos: Vector3, d: Vector3, mat: Material, seg := 10) -> MeshInstance3D:
	return _part(parent, _sphere_mesh(seg), pos, d, mat)

static func capsule(parent: Node3D, pos: Vector3, r: float, h: float, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var key = "cap"
	if not _meshes.has(key):
		var c = CapsuleMesh.new()
		c.radius = 0.5
		c.height = 2.0
		c.radial_segments = 8
		c.rings = 2
		_meshes[key] = c
	return _part(parent, _meshes[key], pos, Vector3(r * 2.0, h * 0.5, r * 2.0), mat, rot)

static func cone(parent: Node3D, pos: Vector3, r: float, h: float, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var key = "cone"
	if not _meshes.has(key):
		var c = CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = 0.5
		c.height = 1.0
		c.radial_segments = 8
		c.rings = 1
		_meshes[key] = c
	return _part(parent, _meshes[key], pos, Vector3(r * 2.0, h, r * 2.0), mat, rot)

static func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	if not _meshes.has("box"):
		_meshes["box"] = BoxMesh.new()
	return _part(parent, _meshes["box"], pos, size, mat, rot)

static func flat(parent: Node3D, pos: Vector3, size: Vector2, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	# wing membrane / ear: a flattened sphere reads softer than a quad
	return _part(parent, _sphere_mesh(8), pos, Vector3(size.x, 0.05, size.y), mat, rot)

static func pivot(parent: Node3D, pos: Vector3, name := "") -> Node3D:
	var p = Node3D.new()
	if name != "":
		p.name = name
	p.position = pos
	parent.add_child(p)
	return p

static func eyes(ctx: Dictionary, head: Node3D, center: Vector3, spacing: float, size: float) -> void:
	var glow = ctx.eyes == "glow"
	for sx in [-1.0, 1.0]:
		var p = center + Vector3(sx * spacing * 0.5, 0, 0)
		if glow:
			sphere(head, p, Vector3.ONE * size, glow_mat(ctx.eye_col), 8)
		else:
			sphere(head, p, Vector3.ONE * size, toon(ctx.eye_col), 8)
			sphere(head, p + Vector3(size * 0.15, size * 0.2, size * 0.35), Vector3.ONE * size * 0.35, glow_mat(Color(1, 1, 1)), 6)

static func _halo(parent: Node3D, pos: Vector3, c: Color, size: float) -> Sprite3D:
	var s = Fx.glow_sprite(c, size)
	s.position = pos
	parent.add_child(s)
	return s

# ------------------------------------------------------------------ small creatures
static func _wisp(ctx: Dictionary, b: Node3D, wick: bool) -> void:
	var a: CreatureAnim = ctx.root
	a.style = "float"
	var c: Color = ctx.col
	var core = sphere(b, Vector3(0, 0.5, 0), Vector3.ONE * 0.5, glow_mat(c.lightened(0.45)), 12)
	if wick:
		# the hero's Wick: a round ember with a soft flame lick, not a spike
		var f = Fx.glow_sprite(Color(c, 0.85), 0.9, "flame")
		f.position = Vector3(0, 0.82, 0)
		b.add_child(f)
		a.extra.append(f)
		_halo(b, Vector3(0, 0.55, 0), Color(c, 0.45), 1.6)
	else:
		cone(b, Vector3(0, 0.88, -0.05), 0.2, 0.45, glow_mat(c.lightened(0.2)), Vector3(-0.3, 0, 0))
		_halo(b, Vector3(0, 0.55, 0), Color(c, 0.6), 2.0)
	var ectx = ctx.duplicate()
	ectx.eyes = "cute"
	ectx.eye_col = Color("#2a1a10")
	eyes(ectx, b, Vector3(0, 0.52, 0.22), 0.18, 0.09)
	a.head = core

static func _bat(ctx: Dictionary, b: Node3D) -> void:
	var a: CreatureAnim = ctx.root
	a.style = "fly"
	var m = toon(ctx.col)
	var dark = toon(ctx.col.darkened(0.35))
	sphere(b, Vector3(0, 0.5, 0), Vector3(0.42, 0.45, 0.4), m)
	var head = pivot(b, Vector3(0, 0.82, 0.05), "Head")
	sphere(head, Vector3.ZERO, Vector3.ONE * 0.42, m)
	for sx in [-1.0, 1.0]:
		cone(head, Vector3(sx * 0.13, 0.22, 0), 0.08, 0.22, dark, Vector3(0, 0, -sx * 0.35))
	eyes(ctx, head, Vector3(0, 0.03, 0.18), 0.16, 0.08)
	for sx in [-1.0, 1.0]:
		var w = pivot(b, Vector3(sx * 0.18, 0.6, 0), "Wing")
		flat(w, Vector3(sx * 0.35, 0, 0), Vector2(0.7, 0.45), dark, Vector3(0, 0, 0))
		flat(w, Vector3(sx * 0.62, -0.05, -0.05), Vector2(0.35, 0.3), dark, Vector3(0, 0.4 * sx, 0))
		w.set_meta("side", sx)
		a.wings.append(w)
	a.head = head

static func _moth(ctx: Dictionary, b: Node3D, lantern: bool) -> void:
	var a: CreatureAnim = ctx.root
	a.style = "fly"
	var fur = toon(ctx.col.lightened(0.25))
	var wing = toon(ctx.col)
	capsule(b, Vector3(0, 0.5, -0.05), 0.14, 0.5, fur, Vector3(PI * 0.5, 0, 0))
	var head = pivot(b, Vector3(0, 0.55, 0.22), "Head")
	sphere(head, Vector3.ZERO, Vector3.ONE * 0.26, fur)
	eyes(ctx, head, Vector3(0, 0.02, 0.1), 0.14, 0.08)
	for sx in [-1.0, 1.0]:
		capsule(head, Vector3(sx * 0.07, 0.18, 0.04), 0.012, 0.25, toon(ctx.col.darkened(0.4)), Vector3(0.4, 0, -sx * 0.4))
		var w = pivot(b, Vector3(sx * 0.1, 0.56, 0.02), "Wing")
		flat(w, Vector3(sx * 0.3, 0, 0.1), Vector2(0.55, 0.45), wing)
		flat(w, Vector3(sx * 0.24, -0.02, -0.22), Vector2(0.38, 0.32), toon(ctx.col.darkened(0.15)))
		w.set_meta("side", sx)
		a.wings.append(w)
	if lantern:
		sphere(b, Vector3(0, 0.46, -0.32), Vector3.ONE * 0.2, glow_mat(ctx.glow), 10)
		_halo(b, Vector3(0, 0.46, -0.32), Color(ctx.glow, 0.7), 1.2)
	a.flap_speed = 14.0
	a.head = head

static func _slime(ctx: Dictionary, b: Node3D) -> void:
	var a: CreatureAnim = ctx.root
	a.style = "squash"
	var m = toon(ctx.col, 0.12)
	sphere(b, Vector3(0, 0.32, 0), Vector3(0.8, 0.62, 0.8), m, 14)
	sphere(b, Vector3(0.14, 0.52, 0.18), Vector3(0.16, 0.1, 0.12), glow_mat(ctx.col.lightened(0.6)), 6)
	eyes(ctx, b, Vector3(0, 0.36, 0.34), 0.24, 0.12)
	a.head = b

static func _ghost(ctx: Dictionary, b: Node3D) -> void:
	var a: CreatureAnim = ctx.root
	a.style = "float"
	var m = toon(ctx.col, 0.25)
	var head = pivot(b, Vector3(0, 0.95, 0), "Head")
	sphere(head, Vector3.ZERO, Vector3(0.7, 0.66, 0.66), m, 12)
	var skirt = cone(b, Vector3(0, 0.45, 0), 0.34, 0.8, m, Vector3(PI, 0, 0))
	for i in 3:
		var ang = TAU * i / 3.0
		sphere(b, Vector3(cos(ang) * 0.2, 0.1, sin(ang) * 0.2), Vector3.ONE * 0.18, m, 6)
	for sx in [-1.0, 1.0]:
		capsule(b, Vector3(sx * 0.34, 0.72, 0.05), 0.07, 0.3, m, Vector3(0, 0, sx * 0.9))
	var ectx = ctx.duplicate()
	eyes(ectx, head, Vector3(0, 0.02, 0.3), 0.22, 0.12)
	sphere(head, Vector3(0, -0.14, 0.31), Vector3(0.1, 0.07, 0.04), toon(Color("#1a1420")), 6)
	a.head = head
	a.tail = skirt

static func _crow(ctx: Dictionary, b: Node3D) -> void:
	var a: CreatureAnim = ctx.root
	a.style = "hop"
	var m = toon(ctx.col)
	var dark = toon(ctx.col.darkened(0.3))
	var beak = toon(Color("#d8b050"))
	sphere(b, Vector3(0, 0.42, -0.02), Vector3(0.42, 0.44, 0.55), m)
	var head = pivot(b, Vector3(0, 0.72, 0.16), "Head")
	sphere(head, Vector3.ZERO, Vector3.ONE * 0.36, m)
	cone(head, Vector3(0, -0.02, 0.24), 0.07, 0.2, beak, Vector3(PI * 0.5, 0, 0))
	eyes(ctx, head, Vector3(0, 0.05, 0.14), 0.22, 0.08)
	box(b, Vector3(0, 0.4, -0.38), Vector3(0.22, 0.05, 0.3), dark, Vector3(-0.5, 0, 0))
	for sx in [-1.0, 1.0]:
		var w = pivot(b, Vector3(sx * 0.2, 0.5, 0), "Wing")
		flat(w, Vector3(sx * 0.05, 0, -0.05), Vector2(0.2, 0.5), dark, Vector3(0, 0, sx * 1.3))
		w.set_meta("side", sx)
		a.wings.append(w)
		capsule(b, Vector3(sx * 0.08, 0.12, 0.02), 0.025, 0.24, beak)
	a.head = head

static func _spider(ctx: Dictionary, b: Node3D) -> void:
	var a: CreatureAnim = ctx.root
	a.style = "skitter"
	var m = toon(ctx.col)
	var dark = toon(ctx.col.darkened(0.4))
	sphere(b, Vector3(0, 0.38, -0.25), Vector3(0.6, 0.5, 0.65), m)
	var head = pivot(b, Vector3(0, 0.3, 0.12), "Head")
	sphere(head, Vector3.ZERO, Vector3(0.36, 0.3, 0.34), m)
	var ectx = ctx.duplicate()
	eyes(ectx, head, Vector3(0, 0.06, 0.15), 0.16, 0.08)
	eyes(ectx, head, Vector3(0, 0.12, 0.1), 0.08, 0.05)
	for sx in [-1.0, 1.0]:
		for i in 4:
			var lp = pivot(b, Vector3(sx * 0.14, 0.3, 0.2 - i * 0.14), "Leg")
			var ang = (i - 1.5) * 0.35
			capsule(lp, Vector3(sx * 0.28, 0.08, 0), 0.03, 0.5, dark, Vector3(ang, 0, sx * 1.1))
			capsule(lp, Vector3(sx * 0.5, -0.12, 0), 0.025, 0.35, dark, Vector3(ang, 0, -sx * 0.5))
			lp.set_meta("phase", float(i % 2) * PI + (0.0 if sx > 0 else PI))
			a.legs.append(lp)
	a.head = head

static func _frog(ctx: Dictionary, b: Node3D) -> void:
	var a: CreatureAnim = ctx.root
	a.style = "hop"
	var m = toon(ctx.col)
	var belly = toon(ctx.col.lightened(0.45))
	sphere(b, Vector3(0, 0.3, 0), Vector3(0.7, 0.5, 0.65), m)
	sphere(b, Vector3(0, 0.24, 0.12), Vector3(0.5, 0.34, 0.45), belly)
	for sx in [-1.0, 1.0]:
		sphere(b, Vector3(sx * 0.18, 0.56, 0.12), Vector3.ONE * 0.24, m)
		capsule(b, Vector3(sx * 0.3, 0.12, -0.12), 0.08, 0.35, m, Vector3(1.2, 0, 0))
		sphere(b, Vector3(sx * 0.2, 0.06, 0.25), Vector3(0.14, 0.08, 0.16), m, 6)
	var ectx = ctx.duplicate()
	for sx in [-1.0, 1.0]:
		eyes(ectx, b, Vector3(sx * 0.18, 0.6, 0.2), 0.0, 0.12)
	box(b, Vector3(0, 0.32, 0.31), Vector3(0.3, 0.02, 0.02), toon(Color("#1a1420")))
	a.head = b

static func _owl(ctx: Dictionary, b: Node3D) -> void:
	var a: CreatureAnim = ctx.root
	a.style = "perch"
	var m = toon(ctx.col)
	var belly = toon(ctx.col.lightened(0.35))
	sphere(b, Vector3(0, 0.42, 0), Vector3(0.6, 0.7, 0.55), m)
	sphere(b, Vector3(0, 0.38, 0.12), Vector3(0.42, 0.5, 0.35), belly)
	var head = pivot(b, Vector3(0, 0.86, 0.02), "Head")
	sphere(head, Vector3.ZERO, Vector3(0.58, 0.46, 0.5), m)
	for sx in [-1.0, 1.0]:
		cone(head, Vector3(sx * 0.2, 0.22, 0), 0.07, 0.18, m, Vector3(0, 0, -sx * 0.4))
		sphere(head, Vector3(sx * 0.12, 0.02, 0.2), Vector3(0.2, 0.2, 0.06), toon(Color("#f0e0b0")), 8)
	var ectx = ctx.duplicate()
	if ectx.eyes != "glow":
		ectx.eye_col = Color("#1a1420")
	eyes(ectx, head, Vector3(0, 0.03, 0.24), 0.24, 0.1)
	cone(head, Vector3(0, -0.07, 0.26), 0.04, 0.1, toon(Color("#d8b050")), Vector3(PI, 0, 0))
	for sx in [-1.0, 1.0]:
		var w = pivot(b, Vector3(sx * 0.28, 0.5, 0), "Wing")
		sphere(w, Vector3(0, -0.05, -0.02), Vector3(0.14, 0.45, 0.36), toon(ctx.col.darkened(0.2)))
		w.set_meta("side", sx)
		a.wings.append(w)
		cone(b, Vector3(sx * 0.1, 0.06, 0.12), 0.05, 0.1, toon(Color("#d8b050")))
	a.head = head

static func _snail(ctx: Dictionary, b: Node3D, s: float, mount: bool) -> void:
	var a: CreatureAnim = ctx.root
	a.style = "slide"
	var skin = toon(Color("#c8b8a0") if not mount else ctx.col.lightened(0.3))
	var shell = toon(ctx.col)
	var shell2 = toon(ctx.col.darkened(0.25))
	capsule(b, Vector3(0, 0.12 * s, 0.05 * s), 0.14 * s, 0.9 * s, skin, Vector3(PI * 0.5, 0, 0))
	var head = pivot(b, Vector3(0, 0.22 * s, 0.42 * s), "Head")
	sphere(head, Vector3.ZERO, Vector3.ONE * 0.26 * s, skin)
	for sx in [-1.0, 1.0]:
		capsule(head, Vector3(sx * 0.06 * s, 0.17 * s, 0), 0.025 * s, 0.26 * s, skin, Vector3(0.2, 0, -sx * 0.3))
		var ep = Vector3(sx * 0.1 * s, 0.3 * s, 0.03 * s)
		if ctx.eyes == "glow":
			sphere(head, ep, Vector3.ONE * 0.07 * s, glow_mat(ctx.eye_col), 6)
		else:
			sphere(head, ep, Vector3.ONE * 0.07 * s, toon(Color("#1a1420")), 6)
	# spiral shell: stacked shrinking spheres along a curl
	for i in 5:
		var t = float(i) / 4.0
		var ang = t * PI * 1.4
		var rad = lerpf(0.5, 0.14, t) * s
		var p = Vector3(0, 0.42 * s + sin(ang) * 0.14 * s, -0.08 * s - cos(ang) * 0.14 * s + t * 0.05 * s)
		sphere(b, p, Vector3(0.75, 1.0, 1.0) * rad * 2.0 * (1.0 if i % 2 == 0 else 0.97), shell if i % 2 == 0 else shell2, 12)
	if mount:
		var sad = pivot(b, Vector3(0, 0.95 * s, -0.05 * s), "Saddle")
		box(sad, Vector3(0, -0.02 * s, 0), Vector3(0.4, 0.06, 0.45) * s, toon(Color("#6a3a28")))
		a.saddle = sad
		sphere(b, Vector3(0, 0.95 * s, -0.4 * s), Vector3.ONE * 0.12 * s, glow_mat(Color("#ffc070")), 8)
		_halo(b, Vector3(0, 0.95 * s, -0.4 * s), Color(1.0, 0.75, 0.4, 0.6), 1.2 * s)
	a.head = head

static func _bunny(ctx: Dictionary, b: Node3D) -> void:
	var a: CreatureAnim = ctx.root
	a.style = "hop"
	var m = toon(ctx.col)
	var inner = toon(Color("#f0b8c0"))
	sphere(b, Vector3(0, 0.3, -0.05), Vector3(0.5, 0.48, 0.55), m)
	sphere(b, Vector3(0, 0.3, -0.34), Vector3.ONE * 0.18, toon(ctx.col.lightened(0.5)), 8)
	var head = pivot(b, Vector3(0, 0.6, 0.12), "Head")
	sphere(head, Vector3.ZERO, Vector3(0.44, 0.4, 0.4), m)
	for sx in [-1.0, 1.0]:
		var ear = pivot(head, Vector3(sx * 0.09, 0.16, -0.02), "Ear")
		capsule(ear, Vector3(0, 0.2, 0), 0.06, 0.42, m, Vector3(-0.2, 0, sx * 0.15))
		capsule(ear, Vector3(0, 0.2, 0.025), 0.035, 0.32, inner, Vector3(-0.2, 0, sx * 0.15))
		a.extra.append(ear)
	eyes(ctx, head, Vector3(0, 0.02, 0.17), 0.2, 0.09)
	sphere(head, Vector3(0, -0.06, 0.2), Vector3(0.06, 0.04, 0.03), inner, 6)
	a.head = head

static func _quadruped(ctx: Dictionary, b: Node3D, o: Dictionary) -> void:
	var a: CreatureAnim = ctx.root
	a.style = "walk"
	var c: Color = ctx.col
	var m = toon(c)
	var dark = toon(c.darkened(0.3))
	var ln: float = o.len
	var h: float = o.h
	var fat: float = o.get("fat", 1.0)
	var slim: float = o.get("slim", 1.0)
	var hr: float = o.head
	var torso_r = h * 0.42 * fat * slim
	var torso = pivot(b, Vector3(0, h * 0.95, 0), "Torso")
	capsule(torso, Vector3.ZERO, torso_r, ln, m, Vector3(PI * 0.5, 0, 0))
	if o.has("chest"):
		sphere(torso, Vector3(0, -torso_r * 0.2, ln * 0.3), Vector3(torso_r * 1.6, torso_r * 1.7, torso_r * 1.4), toon(o.chest))
	# legs (pivot at hip, swing around X)
	var leg_len = h * 0.85
	for fz in [1.0, -1.0]:
		for sx in [-1.0, 1.0]:
			var lp = pivot(b, Vector3(sx * torso_r * 0.55, h * 0.85, fz * ln * 0.34), "Leg")
			capsule(lp, Vector3(0, -leg_len * 0.5, 0), h * 0.1 * fat * (0.8 if slim < 1.0 else 1.0), leg_len, m)
			sphere(lp, Vector3(0, -leg_len + 0.02, 0.03), Vector3(h * 0.22, h * 0.12, h * 0.26) * (0.8 if slim < 1.0 else 1.0), dark, 6)
			lp.set_meta("phase", (0.0 if (fz > 0) == (sx > 0) else PI))
			a.legs.append(lp)
	# head
	var neck_up = 0.35 if o.has("antlers") else 0.18
	var head = pivot(b, Vector3(0, h * 0.95 + hr * (0.5 + neck_up), ln * 0.55 + hr * 0.2), "Head")
	if o.has("antlers"):
		capsule(b, Vector3(0, h * 1.2, ln * 0.45), torso_r * 0.45, hr * 1.6, m, Vector3(-0.6, 0, 0))
	sphere(head, Vector3.ZERO, Vector3(hr * 2.0, hr * 1.85, hr * 1.9), m, 12)
	var sn: float = o.get("snout", 0.0)
	if sn > 0.0:
		var snout_col = toon(c.lightened(0.25)) if not o.has("tusks") else toon(Color("#c89a8a"))
		sphere(head, Vector3(0, -hr * 0.25, hr * 0.85), Vector3(hr * 0.9, hr * 0.7, sn * 2.6), snout_col, 10)
		sphere(head, Vector3(0, -hr * 0.1, hr * 0.85 + sn * 1.25), Vector3.ONE * hr * 0.28, toon(Color("#1a1420")), 6)
	if o.get("tusks", false):
		for sx in [-1.0, 1.0]:
			cone(head, Vector3(sx * hr * 0.35, -hr * 0.35, hr * 1.0), hr * 0.08, hr * 0.5, toon(Color("#f4ecd8")), Vector3(-0.6, 0, sx * 0.3))
	eyes(ctx, head, Vector3(0, hr * 0.15, hr * 0.8), hr * 0.8, hr * 0.26)
	match str(o.get("ears", "cat")):
		"cat":
			for sx in [-1.0, 1.0]:
				cone(head, Vector3(sx * hr * 0.55, hr * 0.8, 0), hr * 0.3, hr * 0.6, m, Vector3(0, 0, -sx * 0.25))
				cone(head, Vector3(sx * hr * 0.55, hr * 0.78, hr * 0.06), hr * 0.18, hr * 0.4, toon(Color("#f0b8c0")), Vector3(0, 0, -sx * 0.25))
		"fox":
			for sx in [-1.0, 1.0]:
				cone(head, Vector3(sx * hr * 0.5, hr * 0.85, -hr * 0.05), hr * 0.3, hr * 0.8, m, Vector3(-0.1, 0, -sx * 0.3))
				cone(head, Vector3(sx * hr * 0.5, hr * 0.82, hr * 0.02), hr * 0.16, hr * 0.5, dark, Vector3(-0.1, 0, -sx * 0.3))
		"boar":
			for sx in [-1.0, 1.0]:
				cone(head, Vector3(sx * hr * 0.6, hr * 0.6, -hr * 0.1), hr * 0.25, hr * 0.45, dark, Vector3(-0.5, 0, -sx * 0.9))
		"stag":
			for sx in [-1.0, 1.0]:
				flat(head, Vector3(sx * hr * 0.85, hr * 0.35, -hr * 0.1), Vector2(hr * 0.9, hr * 0.4), m, Vector3(0, 0, sx * 0.4))
	if o.get("antlers", false):
		var ant = toon(Color("#e8dcc0"))
		for sx in [-1.0, 1.0]:
			var ap = pivot(head, Vector3(sx * hr * 0.35, hr * 0.75, -hr * 0.1), "Antler")
			capsule(ap, Vector3(sx * 0.12, 0.3, 0), 0.035, 0.7, ant, Vector3(0, 0, -sx * 0.4))
			capsule(ap, Vector3(sx * 0.3, 0.58, 0.05), 0.03, 0.4, ant, Vector3(0.3, 0, -sx * 1.0))
			capsule(ap, Vector3(sx * 0.14, 0.62, -0.08), 0.03, 0.35, ant, Vector3(-0.5, 0, sx * 0.1))
			sphere(ap, Vector3(sx * 0.42, 0.68, 0.08), Vector3.ONE * 0.07, glow_mat(ctx.glow), 6)
	# tail
	var tail = pivot(b, Vector3(0, h * 1.0, -ln * 0.55), "Tail")
	match str(o.get("tail", "thin")):
		"thin":
			capsule(tail, Vector3(0, 0.12 * ln, -0.15 * ln), 0.035 + 0.02 * fat, ln * 0.55, m, Vector3(-0.9, 0, 0))
		"bushy":
			sphere(tail, Vector3(0, 0.12 * ln, -0.28 * ln), Vector3(0.3, 0.3, 0.7) * ln * 0.7, m, 10)
			sphere(tail, Vector3(0, 0.18 * ln, -0.5 * ln), Vector3.ONE * ln * 0.16, toon(Color("#f4ead8")), 8)
		"stub":
			sphere(tail, Vector3(0, 0.05, -0.08), Vector3.ONE * 0.16, toon(Color("#f4ead8")), 6)
	a.tail = tail
	if o.get("mount", false):
		var sad = pivot(torso, Vector3(0, torso_r * 0.95, -ln * 0.05), "Saddle")
		box(sad, Vector3.ZERO, Vector3(torso_r * 1.9, 0.08, ln * 0.45), toon(Color("#6a3a28")))
		box(sad, Vector3(0, -torso_r * 0.4, 0), Vector3(torso_r * 2.05, torso_r * 0.8, 0.08), toon(Color("#b08040")))
		a.saddle = sad
	a.head = head
	a.stride = ln * 0.9

static func _beetle(ctx: Dictionary, b: Node3D) -> void:
	var a: CreatureAnim = ctx.root
	a.style = "walk"
	var shell = toon(ctx.col)
	var dark = toon(Color("#1e1a24"))
	var torso = pivot(b, Vector3(0, 0.75, 0), "Torso")
	sphere(torso, Vector3(0, 0.1, -0.1), Vector3(1.4, 0.95, 1.9), shell, 14)
	box(torso, Vector3(0, 0.3, -0.1), Vector3(0.04, 0.6, 1.8), dark)
	sphere(torso, Vector3(0, -0.15, -0.95), Vector3(0.8, 0.6, 0.6), glow_mat(ctx.glow), 10)
	_halo(torso, Vector3(0, -0.15, -1.1), Color(ctx.glow, 0.7), 2.4)
	var head = pivot(b, Vector3(0, 0.7, 0.95), "Head")
	sphere(head, Vector3.ZERO, Vector3(0.7, 0.55, 0.55), dark, 10)
	cone(head, Vector3(0, 0.25, 0.25), 0.1, 0.5, dark, Vector3(0.7, 0, 0))
	eyes(ctx, head, Vector3(0, 0.08, 0.24), 0.36, 0.13)
	for sx in [-1.0, 1.0]:
		for i in 3:
			var lp = pivot(b, Vector3(sx * 0.5, 0.55, 0.5 - i * 0.5), "Leg")
			capsule(lp, Vector3(sx * 0.2, -0.1, 0), 0.06, 0.55, dark, Vector3(0, 0, sx * 1.0))
			capsule(lp, Vector3(sx * 0.42, -0.35, 0), 0.05, 0.5, dark, Vector3(0, 0, -sx * 0.3))
			lp.set_meta("phase", float(i % 2) * PI + (0.0 if sx > 0 else PI))
			a.legs.append(lp)
	var sad = pivot(torso, Vector3(0, 0.58, 0.15), "Saddle")
	box(sad, Vector3.ZERO, Vector3(0.6, 0.08, 0.6), toon(Color("#6a3a28")))
	a.saddle = sad
	a.head = head
	a.stride = 0.8
