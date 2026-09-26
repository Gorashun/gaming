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
## Label discipline (QA B-07): small, short names; Common items unnamed unless the hero is close;
## at most MAX_LABELS visible (newest / rarest win); hidden where they would cover the HUD.
const MAX_LABELS := 6
static var _labelled: Array = []      # drops with a name label, oldest first
var _label_check = 0.0

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
	var nm = str(it.name)
	_label.text = nm if nm.length() <= 18 else nm.substr(0, 17) + "…"
	_label.modulate = col
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0007 if rank < 4 else 0.0009
	_label.font_size = 34
	_label.outline_size = 10
	_label.outline_modulate = Color(0, 0, 0, 0.9)
	_label.position.y = 0.9
	_label.visible = rank > 0
	add_child(_label)
	_labelled.append(self)

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

func _exit_tree() -> void:
	_labelled.erase(self)

func _update_label() -> void:
	if _label == null:
		return
	var rank = Items.rarity_index(str(item.get("rarity", "common")))
	var p = Game.world.player if Game.world else null
	var near = p != null and is_instance_valid(p) and p.global_position.distance_to(global_position) < 4.0
	var show = rank > 0 or near
	if show and rank < 4:
		# only the newest / rarest MAX_LABELS keep a name (Legendary+ always)
		var alive = _labelled.filter(func(d): return is_instance_valid(d) and d.is_inside_tree())
		var shown = 0
		for i in range(alive.size() - 1, -1, -1):
			var d = alive[i]
			if d == self:
				break
			shown += 1
		show = shown < MAX_LABELS
		_label.modulate.a = 1.0 if alive.size() <= 3 else 0.8
	if show:
		var cam = get_viewport().get_camera_3d()
		if cam:
			var sp = cam.unproject_position(global_position + Vector3(0, 0.9, 0))
			for n in get_tree().get_nodes_in_group("hud_blocker"):
				var c = n as Control
				if c and c.is_visible_in_tree() and c.get_global_rect().grow(12).has_point(sp):
					show = false
					break
			if show:
				for n in get_tree().get_nodes_in_group("hud_arc"):
					var c2 = n as Control
					if c2 and c2.is_visible_in_tree() and c2.get_global_rect().grow(12).has_point(sp):
						show = false
						break
	_label.visible = show

func _process(delta: float) -> void:
	_t += delta
	_label_check -= delta
	if _label_check <= 0.0 and not item.is_empty():
		_label_check = 0.2
		_update_label()
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
