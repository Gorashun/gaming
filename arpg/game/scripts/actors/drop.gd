class_name Drop
extends Node3D
## A loot pickup on the ground: item, gold or material. Beam + label in rarity colour.

var net_id = 0
var item = {}
var gold = 0
var material_id = ""
var material_count = 0
var _label: Label3D
var _visual: Node3D
var _t = 0.0
var _land_from = Vector3.ZERO
var _land_to = Vector3.ZERO
var _land_t = 1.0
var magnet = false

static var _prop_cache := {}

func setup_item(it: Dictionary) -> void:
	item = it
	var col = Items.rarity_color(it.rarity)
	var rank = Items.rarity_index(it.rarity)
	var base = Content.get_rec("item_bases", it.base)
	_visual = _make_visual(base.get("model", ""), col)
	add_child(_visual)
	if rank >= 2:
		var h = 2.0 + rank * 1.2
		Fx.beam(self, col, h, 0.35 + rank * 0.08)
		var l = OmniLight3D.new()
		l.light_color = col
		l.light_energy = 0.6 + rank * 0.3
		l.omni_range = 2.5 + rank * 0.5
		l.position.y = 0.8
		l.shadow_enabled = false
		add_child(l)
	_label = Label3D.new()
	_label.text = it.name
	_label.modulate = col
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0012
	_label.font_size = 36
	_label.outline_size = 12
	_label.outline_modulate = Color(0, 0, 0, 0.9)
	_label.position.y = 1.1
	add_child(_label)

func setup_gold(amount: int) -> void:
	gold = amount
	_visual = _make_visual("res://assets/thirdparty/kaykit/dungeon/models/coin_stack_small.gltf.glb" if amount > 30 else "res://assets/thirdparty/kaykit/dungeon/models/coin.gltf.glb", Color(1, 0.85, 0.3))
	add_child(_visual)
	magnet = true

func setup_material(id: String, count: int) -> void:
	material_id = id
	material_count = count
	var m = Content.get_rec("materials", id)
	var col = Color(m.get("color", "#9be7ff"))
	_visual = _gem(col)
	add_child(_visual)
	magnet = true

func _make_visual(path: String, col: Color) -> Node3D:
	if path != "" and ResourceLoader.exists(path):
		if not _prop_cache.has(path):
			_prop_cache[path] = load(path)
		var n: Node3D = _prop_cache[path].instantiate()
		n.scale = Vector3.ONE * 0.8
		return n
	return _gem(col)

func _gem(col: Color) -> Node3D:
	var mi = MeshInstance3D.new()
	var pm = PrismMesh.new()
	pm.size = Vector3(0.3, 0.4, 0.3)
	mi.mesh = pm
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.5
	mi.material_override = mat
	return mi

func toss(from: Vector3, to: Vector3) -> void:
	_land_from = from
	_land_to = to
	_land_t = 0.0
	global_position = from

func _process(delta: float) -> void:
	_t += delta
	if _land_t < 1.0:
		_land_t = min(1.0, _land_t + delta * 2.2)
		var p = _land_from.lerp(_land_to, _land_t)
		p.y = sin(_land_t * PI) * 1.6
		global_position = p
		if _land_t >= 1.0 and not item.is_empty() and Items.rarity_index(item.rarity) >= 4:
			Fx.ring(global_position, 2.5, Items.rarity_color(item.rarity), 0.6)
			Fx.flash_light(global_position + Vector3(0, 1, 0), Items.rarity_color(item.rarity), 4.0, 0.6, 8.0)
	if _visual:
		_visual.rotation.y += delta * 1.5
		_visual.position.y = 0.25 + sin(_t * 3.0) * 0.08
