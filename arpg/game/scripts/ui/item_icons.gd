class_name ItemIcons
extends Node
## Item icons in the game's own 3D style: the item's prop model (item_bases.model or weapon_types.prop)
## is rendered once in an off-screen SubViewport "icon studio", cached in memory and on disk
## (user://icon_cache). Items without a model (armour, jewellery) use the vector slot icon set.
## Usage: ItemIcons.texture_for(item) → Texture2D (vector fallback until the render is ready);
##        ItemIcons.instance().icon_ready.connect(func(key): ...) to refresh.

signal icon_ready(key: String)

const SIZE := 160
const CACHE_DIR := "user://icon_cache/"
const CACHE_VERSION := 2

static var _inst: ItemIcons
static var _tex := {}          # key -> Texture2D

var _queue: Array = []         # model paths
var _vp: SubViewport
var _cam: Camera3D
var _holder: Node3D
var _busy = false

static func instance() -> ItemIcons:
	if _inst == null or not is_instance_valid(_inst):
		_inst = ItemIcons.new()
		_inst.name = "ItemIconStudio"
		var root = (Engine.get_main_loop() as SceneTree).root
		root.add_child.call_deferred(_inst)
	return _inst

## The model path for an item (or "" when it has none).
static func model_for(item: Dictionary) -> String:
	if item == null or item.is_empty():
		return ""
	var wp = UiTheme.api_call("Weapons", "prop_path", [item], "")
	if wp is String and wp != "" and ResourceLoader.exists(wp):
		return wp
	var base = Content.get_rec("item_bases", str(item.get("base", "")))
	var m = str(base.get("model", ""))
	if m == "":
		var wt = Content.get_rec("weapon_types", str(item.get("type", "")))
		m = str(wt.get("prop", ""))
	return m if (m != "" and ResourceLoader.exists(m)) else ""

## Vector icon name for an item type/slot.
static func glyph_for(item: Dictionary) -> String:
	var t = str(item.get("type", ""))
	if t != "" and UiTheme.has_icon(t):
		return t
	var s = str(item.get("slot", ""))
	if s.begins_with("ring"):
		return "ring"
	return s if UiTheme.has_icon(s) else "unknown"

static func texture_for(item: Dictionary) -> Texture2D:
	if item == null or item.is_empty():
		return null
	var m = model_for(item)
	if m == "":
		return UiTheme.icon(glyph_for(item))
	var t = cached(m)
	if t:
		return t
	instance().request(m)
	return null

static func is_vector(item: Dictionary) -> bool:
	return model_for(item) == ""

static func cached(model_path: String) -> Texture2D:
	if _tex.has(model_path):
		return _tex[model_path]
	var disk = _disk_path(model_path)
	if FileAccess.file_exists(disk):
		var img = Image.load_from_file(disk)
		if img:
			var t = ImageTexture.create_from_image(img)
			_tex[model_path] = t
			return t
	return null

static func _disk_path(model_path: String) -> String:
	return CACHE_DIR + ("%d_%s.png" % [CACHE_VERSION, model_path.md5_text()])

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.72, 0.8)
	e.ambient_light_energy = 0.9
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	_vp.add_child(env)
	var key = DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.92, 0.8)
	key.light_energy = 1.4
	key.rotation_degrees = Vector3(-40, -30, 0)
	_vp.add_child(key)
	var rim = DirectionalLight3D.new()
	rim.light_color = Color(0.7, 0.8, 1.0)
	rim.light_energy = 1.1
	rim.rotation_degrees = Vector3(-10, 150, 0)
	_vp.add_child(rim)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.position = Vector3(0, 0, 10)
	_vp.add_child(_cam)
	_holder = Node3D.new()
	_vp.add_child(_holder)

func request(model_path: String) -> void:
	if _tex.has(model_path) or _queue.has(model_path):
		return
	_queue.append(model_path)

func _process(_d: float) -> void:
	if _busy or _queue.is_empty() or _vp == null:
		return
	_render_next()

func _render_next() -> void:
	_busy = true
	var path: String = _queue.pop_front()
	for c in _holder.get_children():
		c.queue_free()
	var ps = load(path)
	if ps == null or not (ps is PackedScene):
		_tex[path] = UiTheme.icon("unknown")
		_busy = false
		return
	var n: Node3D = ps.instantiate()
	_holder.add_child(n)
	# Diagonal "icon pose": long axis from bottom-left to top-right.
	var aabb = _aabb(n)
	var long_axis = 1 if aabb.size.y >= max(aabb.size.x, aabb.size.z) else (0 if aabb.size.x >= aabb.size.z else 2)
	n.position = -aabb.get_center()
	var pivot = Node3D.new()
	_holder.add_child(pivot)
	n.reparent(pivot, false)
	match long_axis:
		1:
			pivot.rotation_degrees = Vector3(0, 30, -38)
		0:
			pivot.rotation_degrees = Vector3(0, 30, 45)
		2:
			pivot.rotation_degrees = Vector3(0, -60, 45)
	var ext = aabb.size.length()
	_cam.size = max(0.2, ext * 0.78)
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img = _vp.get_texture().get_image()
	if img and not img.is_empty():
		var t = ImageTexture.create_from_image(img)
		_tex[path] = t
		img.save_png(_disk_path(path))
		icon_ready.emit(path)
	_busy = false

func _aabb(n: Node3D) -> AABB:
	var out = AABB()
	var first = true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		var xf = n.global_transform.affine_inverse() * m.global_transform if n.is_inside_tree() else m.transform
		var b = xf * m.mesh.get_aabb()
		if first:
			out = b
			first = false
		else:
			out = out.merge(b)
	if first:
		out = AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	return out
