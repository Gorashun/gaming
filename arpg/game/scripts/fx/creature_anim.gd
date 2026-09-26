class_name CreatureAnim
extends Node3D
## Procedural animation for CreatureFactory creatures. Styles:
##  float (wisp/ghost: bob + sway), fly (bat/moth: bob + wing flaps), hop (crow/frog/bunny),
##  walk (quadrupeds/beetle: leg swing + body bounce), skitter (spider), slide (snail),
##  squash (slime), perch (owl: head turns, occasional flap).
## Motion is auto-detected from global position, so pets/mounts just need to be moved.

var kind := ""
var style := "float"
var body: Node3D
var head: Node3D
var tail: Node3D
var saddle: Node3D
var wings: Array = []
var legs: Array = []
var extra: Array = []
var flap_speed := 10.0
var stride := 0.5
var anim_speed := 1.0

var _t := 0.0
var _moving := false
var _forced_moving := false
var _last := Vector3.ZERO
var _speed := 0.0
var _react := 0.0          # >0 during attack lunge / hurt squash
var _react_kind := ""
var _wander_r := 0.0
var _wander_fly := false
var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _wait := 0.0
var _head_turn := 0.0
var _light: OmniLight3D
var _light_base := 0.0

func setup_anim() -> void:
	_t = randf() * 10.0

func _ready() -> void:
	_last = global_position
	_home = position
	if has_meta("light"):
		_light = get_meta("light")
		_light_base = _light.light_energy

## Rider attach point for mounts (null for small creatures).
func get_saddle() -> Node3D:
	return saddle

func set_moving(m: bool) -> void:
	_forced_moving = m

func attack() -> void:
	_react = 0.3
	_react_kind = "attack"

func hurt() -> void:
	_react = 0.2
	_react_kind = "hurt"

## Ambient critters: roam (or circle, when flying) around the spawn point.
func set_wander(radius: float, fly := false) -> void:
	_wander_r = radius
	_wander_fly = fly
	_home = position
	_target = position
	_wait = randf_range(0.5, 3.0)

func _process(delta: float) -> void:
	var dt = delta * anim_speed
	_t += dt
	if _wander_r > 0.0:
		_do_wander(delta)
	if _light == null and has_meta("light"):
		_light = get_meta("light")
		_light_base = _light.light_energy
	var gp = global_position
	var v = (gp - _last).length() / maxf(delta, 0.0001)
	_last = gp
	_speed = lerpf(_speed, v, clampf(delta * 8.0, 0.0, 1.0))
	_moving = _forced_moving or _speed > 0.25
	if body == null:
		return
	var sq = 1.0
	if _react > 0.0:
		_react -= delta
		var k = sin((1.0 - _react / 0.3) * PI)
		if _react_kind == "attack":
			body.position.z = k * 0.25
		else:
			sq = 1.0 - k * 0.25
	else:
		body.position.z = 0.0
	match style:
		"float":
			body.position.y = sin(_t * 2.2) * 0.08 + 0.05
			body.rotation.z = sin(_t * 1.3) * 0.08
			if tail:
				tail.rotation.y = sin(_t * 3.0) * 0.2
			for e in extra:
				e.scale = Vector3.ONE * (0.9 + 0.12 * sin(_t * 17.0) + 0.06 * sin(_t * 29.0))
		"fly":
			body.position.y = sin(_t * 3.0) * 0.1
			var f = sin(_t * flap_speed)
			for w in wings:
				var sd = float(w.get_meta("side", 1.0))
				w.rotation.z = sd * (0.2 + f * 0.75)
			body.rotation.x = 0.15 if _moving else 0.0
		"hop":
			var hop_t = fmod(_t * (2.4 if _moving else 0.6), 1.0)
			var hopping = _moving or hop_t < 0.25
			body.position.y = absf(sin(hop_t * PI)) * (0.25 if _moving else 0.06) if hopping else 0.0
			if head and not _moving:
				head.rotation.x = maxf(0.0, sin(_t * 1.7)) * 0.5 * float(sin(_t * 0.37) > 0.6)
			for w in wings:
				var sd2 = float(w.get_meta("side", 1.0))
				w.rotation.z = sd2 * (absf(sin(_t * 16.0)) * 0.8 if _moving else 0.0)
			for e in extra:
				e.rotation.x = sin(_t * 2.0) * 0.12
		"walk":
			var rate = 7.0 / maxf(0.3, stride)
			var amp = 0.55 if _moving else 0.0
			for l in legs:
				var ph = float(l.get_meta("phase", 0.0))
				l.rotation.x = lerpf(l.rotation.x, sin(_t * rate + ph) * amp, clampf(dt * 12.0, 0.0, 1.0))
			body.position.y = (absf(sin(_t * rate)) * 0.05 if _moving else sin(_t * 1.6) * 0.012)
			if tail:
				tail.rotation.y = sin(_t * (6.0 if _moving else 1.8)) * 0.35
			if head and not _moving:
				_head_turn = lerpf(_head_turn, sin(_t * 0.4) * 0.5, dt * 2.0)
				head.rotation.y = _head_turn
		"skitter":
			for l in legs:
				var ph2 = float(l.get_meta("phase", 0.0))
				l.rotation.y = sin(_t * (18.0 if _moving else 2.0) + ph2) * (0.35 if _moving else 0.05)
			body.position.y = sin(_t * 20.0) * 0.015 if _moving else 0.0
		"slide":
			var s = 1.0 + (sin(_t * 3.0) * 0.06 if _moving else sin(_t * 1.2) * 0.02)
			body.scale = Vector3(1.0 / sqrt(s), 1.0, s) * sq
			if head:
				head.rotation.x = sin(_t * 1.1) * 0.12
			return
		"squash":
			var b = absf(sin(_t * (5.0 if _moving else 2.2)))
			var s2 = 1.0 + (b - 0.5) * (0.28 if _moving else 0.12)
			body.scale = Vector3(1.0 / sqrt(s2), s2, 1.0 / sqrt(s2)) * sq
			body.position.y = b * (0.18 if _moving else 0.0)
			return
		"perch":
			_head_turn = lerpf(_head_turn, (1.0 if sin(_t * 0.5) > 0.3 else -0.6) * 0.9, dt * 3.0)
			if head:
				head.rotation.y = _head_turn
			var flap = sin(_t * 0.3) > 0.97 or _moving
			for w in wings:
				var sd3 = float(w.get_meta("side", 1.0))
				w.rotation.z = sd3 * (absf(sin(_t * 14.0)) * 1.1 if flap else 0.0)
			body.position.y = absf(sin(_t * 3.0)) * 0.3 if _moving else 0.0
	body.scale = Vector3(1.0 / sqrt(sq), sq, 1.0 / sqrt(sq)) if sq != 1.0 else Vector3.ONE
	if _light:
		_light.light_energy = _light_base * (0.9 + 0.07 * sin(_t * 11.0) + 0.05 * sin(_t * 23.0))

func _do_wander(delta: float) -> void:
	if _wander_fly:
		var a = _t * 0.6
		var p = _home + Vector3(cos(a) * _wander_r, sin(_t * 1.3) * 0.4, sin(a) * _wander_r)
		var d = p - position
		position = p
		if d.length() > 0.001:
			rotation.y = atan2(d.x, d.z)
		return
	if _wait > 0.0:
		_wait -= delta
		return
	var to = _target - position
	to.y = 0.0
	if to.length() < 0.1:
		_wait = randf_range(1.5, 5.0)
		_target = _home + Vector3(randf_range(-_wander_r, _wander_r), 0, randf_range(-_wander_r, _wander_r))
		return
	var sp = 0.9 if style != "slide" else 0.25
	position += to.normalized() * minf(sp * delta, to.length())
	rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), clampf(delta * 6.0, 0.0, 1.0))
