class_name CameraRig
extends Node3D
## Diablo-style follow camera with trauma-based shake (Art Bible: FOV 38, pitch -52, yaw 45).

var target: Node3D
var camera: Camera3D
var distance = 15.0
var pitch_deg = -52.0
var yaw_deg = 45.0
var trauma = 0.0
var _noise_t = 0.0
var follow_speed = 8.0
var zoom = 1.0

func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 38.0
	camera.near = 0.5
	camera.far = 120.0
	add_child(camera)
	camera.current = true
	_place()

func add_trauma(a: float) -> void:
	trauma = clampf(trauma + a, 0.0, 1.0)

func _place() -> void:
	var d = distance * zoom
	var horiz = cos(deg_to_rad(-pitch_deg)) * d
	camera.position = Vector3(sin(deg_to_rad(yaw_deg)) * horiz, sin(deg_to_rad(-pitch_deg)) * d, cos(deg_to_rad(yaw_deg)) * horiz)
	camera.rotation = Vector3(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg), 0)

func _process(delta: float) -> void:
	if target and is_instance_valid(target):
		global_position = global_position.lerp(target.global_position, clampf(follow_speed * delta, 0.0, 1.0))
	_place()
	if trauma > 0.0:
		_noise_t += delta * 40.0
		var s = trauma * trauma
		camera.position += Vector3(sin(_noise_t * 1.3), cos(_noise_t * 1.7), sin(_noise_t * 0.9)) * s * 0.35
		camera.rotation.z = sin(_noise_t * 1.1) * s * 0.02
		trauma = max(0.0, trauma - delta * 1.8)
