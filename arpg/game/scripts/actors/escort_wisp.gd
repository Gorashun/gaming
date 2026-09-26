class_name EscortWisp
extends Actor
## Friendly "Lost Wisp" for the escort Hushfall. Player faction: monsters attack it, the hero
## protects it. Walks toward `dest` only while `moving` is true (set by WorldEvents between waves).

signal arrived

var rec = {"scale": 1.0}
var kind = "champion"            # blue health bar + name label
var dest = Vector3.ZERO
var moving = false
var healthbar: Node3D
var _path: PackedVector3Array = []
var _path_i = 0
var _repath = 0.0
var _visual: Node3D
var _t = 0.0

func setup_wisp(max_hp: float, col := Color(0.7, 0.9, 1.0)) -> void:
	faction = "player"
	display_name = "Lost Wisp"
	radius = 0.4
	max_life = max_hp
	life = max_hp
	move_speed = 2.2
	_visual = Pet.make_wisp(col, 1.6)
	add_child(_visual)
	var shape = CollisionShape3D.new()
	var sph = SphereShape3D.new()
	sph.radius = 0.4
	shape.shape = sph
	shape.position.y = 1.0
	add_child(shape)
	collision_layer = 8
	collision_mask = 1

func _physics_process(delta: float) -> void:
	if not alive:
		return
	_t += delta
	_visual.position.y = 1.0 + sin(_t * 2.5) * 0.18
	if not moving or Game.world == null:
		return
	if global_position.distance_to(dest) < 1.2:
		moving = false
		arrived.emit()
		return
	_repath -= delta
	if _repath <= 0.0 or _path.is_empty():
		_repath = 1.0
		_path = Game.world.find_path(global_position, dest)
		_path_i = 0
	var target = dest
	while _path_i < _path.size() and global_position.distance_to(_path[_path_i]) < 0.6:
		_path_i += 1
	if _path_i < _path.size():
		target = _path[_path_i]
	var dir = target - global_position
	dir.y = 0
	velocity = dir.normalized() * move_speed if dir.length() > 0.05 else Vector3.ZERO
	move_and_slide()
	global_position.y = 0.0

func on_damaged(amount: float, crit: bool, source: Node) -> void:
	super.on_damaged(amount, crit, source)
	if healthbar and healthbar.has_method("set_value"):
		healthbar.set_value(life / max_life)

func _die(killer: Node) -> void:
	Fx.soul_puff(global_position, Color(0.7, 0.9, 1.0))
	super._die(killer)
	queue_free()
