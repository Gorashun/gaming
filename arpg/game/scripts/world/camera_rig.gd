class_name CameraRig
extends Node3D
## Diablo-style follow camera (Art Bible 8): vertical FOV 38 (keep height, so wide phones see
## more, never less), pitch -52, fixed yaw 45. Distance per context (zone / hub / boss) eased over
## 0.6 s, "Zoom" setting +-15 %. The hero sits at 54 % of screen height (slightly below centre)
## with 1.5 m look-ahead in the move direction; critically damped follow (~0.12 s).
## Shake = trauma model, camera offset only, rotation <= 1.5 deg.
## Also feeds the hero position to the env shader (wall dither) every frame via Fx.set_player_pos.

const DIST_ZONE := 17.5
const DIST_HUB := 15.0
const DIST_BOSS := 21.0
const SCREEN_Y := 0.54          # hero position, fraction of screen height from the top
const LOOK_AHEAD := 1.5

var target: Node3D
var camera: Camera3D
var distance = DIST_ZONE        # legacy: GameWorld may set 16 for bosses; mode presets win
var pitch_deg = -52.0
var yaw_deg = 45.0
var trauma = 0.0
var _noise_t = 0.0
var follow_speed = 8.0          # legacy
var zoom = 1.0
var mode = "zone"               # zone | hub | boss
var _dist_now = DIST_ZONE
var _vel = Vector3.ZERO
var _focus = Vector3.ZERO
var _ahead = Vector3.ZERO
var _last_target = Vector3.ZERO
var _inited = false

func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 38.0
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.5
	camera.far = 140.0
	add_child(camera)
	camera.current = true
	var w = Game.world
	if w:
		if w.is_town:
			mode = "hub"
		elif str(w.zone.get("boss", "")) != "":
			mode = "boss"
	_dist_now = _mode_distance()
	_place()

func _mode_distance() -> float:
	var z = clampf(float(Settings.get_value("camera_zoom", 1.0)), 0.85, 1.15)
	var d = DIST_ZONE
	match mode:
		"hub": d = DIST_HUB
		"boss": d = DIST_BOSS
	return d * z * zoom

func add_trauma(a: float) -> void:
	trauma = clampf(trauma + a, 0.0, 1.0)

func set_mode(m: String) -> void:
	mode = m

func _place() -> void:
	var d = _dist_now
	var pitch = deg_to_rad(-pitch_deg)
	var yaw = deg_to_rad(yaw_deg)
	var horiz = cos(pitch) * d
	# Aim at a point slightly "up-screen" (away from camera) so the hero sits at 54 % height.
	var view_h = 2.0 * d * tan(deg_to_rad(camera.fov * 0.5))
	var ground_shift = (SCREEN_Y - 0.5) * view_h / sin(pitch)
	var back = Vector3(sin(yaw), 0, cos(yaw))
	camera.position = back * horiz + Vector3(0, sin(pitch) * d, 0) - back * ground_shift
	camera.rotation = Vector3(-pitch, yaw, 0)

func _process(delta: float) -> void:
	if target and is_instance_valid(target):
		var tp = target.global_position
		if not _inited:
			_inited = true
			_focus = tp
			_last_target = tp
		var mv = (tp - _last_target) / maxf(delta, 0.0001)
		mv.y = 0.0
		_last_target = tp
		var want_ahead = mv.normalized() * LOOK_AHEAD if mv.length() > 1.0 else Vector3.ZERO
		_ahead = _ahead.lerp(want_ahead, clampf(delta * 2.5, 0.0, 1.0))
		# critically damped spring towards the hero (+ look-ahead)
		var goal = tp + _ahead
		var omega = 2.0 / 0.12 * 0.5
		var x = _focus - goal
		var exp_k = 1.0 / (1.0 + omega * delta + 0.48 * omega * omega * delta * delta + 0.235 * pow(omega * delta, 3))
		var tmp = (_vel + x * omega) * delta
		_vel = (_vel - tmp * omega) * exp_k
		_focus = goal + (x + tmp) * exp_k
		global_position = _focus
		Fx.set_player_pos(tp)
	var want = _mode_distance()
	_dist_now = lerpf(_dist_now, want, clampf(delta / 0.6 * 3.0, 0.0, 1.0))
	_place()
	if trauma > 0.0:
		_noise_t += delta * 40.0
		var s = trauma * trauma
		camera.position += Vector3(sin(_noise_t * 1.3), cos(_noise_t * 1.7), sin(_noise_t * 0.9)) * s * 0.35
		camera.rotation.z = sin(_noise_t * 1.1) * s * deg_to_rad(1.5)
		trauma = max(0.0, trauma - delta * 1.8)
	else:
		camera.rotation.z = 0.0
