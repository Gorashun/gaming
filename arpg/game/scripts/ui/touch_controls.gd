class_name TouchControls
extends Control
## Floating joystick (thumb zone) + action button arc. Produces player intents.
## Options (Settings): left_handed (mirror sides), button_scale (0.8–1.3), control_scheme
## ("stick" = floating joystick; "tap" = tap-to-move / tap-to-attack, one-handed friendly),
## joystick_fixed (joystick parks at a fixed spot). Keyboard/mouse also work for desktop testing.

var player: Player
var _joy_touch = -1
var _joy_origin = Vector2.ZERO
var _joy_vec = Vector2.ZERO
var _joy_base: Control
var _joy_knob: Control
var buttons = {}        # key -> ActionButton
var _aim_touch = {}     # touch index -> key
var _aim_start = {}
var _aim_vec = {}
var _move_target = null # Vector3 (tap-to-move)
var _tap_attack: Node = null
var mirrored = false
const JOY_RADIUS := 95.0

## Layout in ref px relative to the bottom-right corner of the (safe-area) HUD rect.
## Attack at the thumb rest; S1–S4 on a 215 px arc (180°→90°); dodge and potion outside the arc.
const ATTACK := Vector2(-104, -96)
const ARC_R := 215.0
const DODGE := Vector2(-428, -214)
const POTION := Vector2(-433, -67)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_base = _circle(JOY_RADIUS * 2.0, Color(1, 1, 1, 0.07), Color(1, 0.9, 0.7, 0.28))
	_joy_knob = _circle(84, Color(1, 0.85, 0.55, 0.38), Color(1, 0.9, 0.7, 0.7))
	add_child(_joy_base)
	add_child(_joy_knob)
	_joy_base.visible = false
	_joy_knob.visible = false

func _circle(d: float, fill: Color, edge: Color) -> Panel:
	var p = Panel.new()
	var s = StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(3)
	s.set_corner_radius_all(int(d / 2))
	s.anti_aliasing = true
	p.add_theme_stylebox_override("panel", s)
	p.size = Vector2(d, d)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func setup(p: Player) -> void:
	player = p
	layout()

## (Re)build the button layout from settings (call after changing handedness/scale).
func layout() -> void:
	for c in get_children():
		if c is ActionButton:
			c.queue_free()
	buttons.clear()
	if player == null:
		return
	mirrored = bool(Settings.get_value("left_handed", false))
	var k = clampf(float(Settings.get_value("button_scale", 1.0)), 0.8, 1.3)
	_add_button("attack", player.basic_skill, ATTACK * Vector2(1, 1) * lerpf(1.0, k, 0.5), 160 * k)
	for i in 4:
		var a = deg_to_rad(180.0 - 30.0 * i)
		var off = ATTACK + Vector2(cos(a), -sin(a)) * ARC_R * k
		_add_button("skill%d" % i, player.ch.skill_bar[i], off, 112 * k)
	_add_button("dodge", "__dodge", ATTACK + (DODGE - ATTACK) * k, 112 * k)
	_add_button("potion", "__potion", ATTACK + (POTION - ATTACK) * k, 104 * k)
	_joy_base.size = Vector2.ONE * JOY_RADIUS * 2.0 * k
	_joy_base.get_theme_stylebox("panel").set_corner_radius_all(int(JOY_RADIUS * k))

func refresh_bar() -> void:
	for i in 4:
		var key = "skill%d" % i
		if buttons.has(key):
			buttons[key].set_skill(player.ch.skill_bar[i])

## Mirror-aware: `off` is relative to the bottom-right corner (bottom-left when mirrored).
func _add_button(key: String, skill: String, off: Vector2, sz: float) -> void:
	var b = ActionButton.new()
	add_child(b)
	b.setup(key, skill, sz)
	if mirrored:
		UiTheme.place(b, 0.0, 1.0, -off.x - sz * 0.5, off.y - sz * 0.5, sz, sz)
	else:
		UiTheme.place(b, 1.0, 1.0, off.x - sz * 0.5, off.y - sz * 0.5, sz, sz)
	buttons[key] = b

func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var kb = Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if Input.is_physical_key_pressed(KEY_A): kb.x -= 1
	if Input.is_physical_key_pressed(KEY_D): kb.x += 1
	if Input.is_physical_key_pressed(KEY_W): kb.y -= 1
	if Input.is_physical_key_pressed(KEY_S): kb.y += 1
	var v = _joy_vec if _joy_touch >= 0 else kb.limit_length(1.0)
	var move = screen_to_world_dir(v)
	if move == Vector3.ZERO and _move_target is Vector3:
		var d: Vector3 = _move_target - player.global_position
		d.y = 0
		if d.length() < 0.45:
			_move_target = null
		else:
			move = d.normalized()
	elif move != Vector3.ZERO:
		_move_target = null
	if _tap_attack and is_instance_valid(_tap_attack) and _tap_attack.get("alive"):
		if player.global_position.distance_to(_tap_attack.global_position) < 2.4 or player.basic_skill.begins_with("sg_") or player.basic_skill.begins_with("rr_"):
			move = Vector3.ZERO
			_move_target = null
			player.request_cast(player.basic_skill, _tap_attack.global_position)
	else:
		_tap_attack = null
	player.intent_move = move
	for k in buttons:
		buttons[k].update_state(player)

## Camera yaw 45°: screen up = world (-1,0,-1)
func screen_to_world_dir(v: Vector2) -> Vector3:
	if v.length() < 0.12:
		return Vector3.ZERO
	var yaw = deg_to_rad(45.0)
	var fwd = Vector3(-sin(yaw), 0, -cos(yaw))
	var right = Vector3(cos(yaw), 0, -sin(yaw))
	var t = clampf((v.length() - 0.12) / (0.7 - 0.12), 0.0, 1.0)   # dead zone 12 %, full speed at 70 %
	return (right * v.x + fwd * -v.y).normalized() * t

func _in_stick_zone(pos: Vector2) -> bool:
	var vp = get_viewport_rect().size
	if mirrored:
		return pos.x > vp.x * 0.55 and pos.y > vp.y * 0.28
	return pos.x < vp.x * 0.45 and pos.y > vp.y * 0.28

func _input(event: InputEvent) -> void:
	if player == null or get_tree().paused:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var hit_key = _button_at(event.position)
			if hit_key != "":
				_aim_touch[event.index] = hit_key
				_aim_start[event.index] = event.position
				_aim_vec[event.index] = Vector2.ZERO
				buttons[hit_key].set_pressed_look(true)
				_preview(hit_key, Vector2.ZERO)
				get_viewport().set_input_as_handled()
			elif _over_ui(event.position):
				return
			elif str(Settings.get_value("control_scheme", "stick")) == "tap":
				_tap_world(event.position)
			elif _in_stick_zone(event.position) and _joy_touch < 0:
				_joy_touch = event.index
				_joy_origin = event.position
				if bool(Settings.get_value("joystick_fixed", false)):
					var vp = get_viewport_rect().size
					_joy_origin = Vector2(vp.x - 190 if mirrored else 190, vp.y - 160)
				_joy_vec = Vector2.ZERO
				_joy_base.visible = true
				_joy_knob.visible = true
				_joy_base.position = _joy_origin - _joy_base.size * 0.5
				_joy_knob.position = event.position - _joy_knob.size * 0.5
		else:
			if event.index == _joy_touch:
				_joy_touch = -1
				_joy_vec = Vector2.ZERO
				_joy_base.visible = false
				_joy_knob.visible = false
			elif _aim_touch.has(event.index):
				var key: String = _aim_touch[event.index]
				var aim: Vector2 = _aim_vec.get(event.index, Vector2.ZERO)
				# dragging back onto the button cancels a manual aim
				var back_on = aim != Vector2.ZERO and event.position.distance_to(buttons[key].global_position + buttons[key].size * 0.5) < buttons[key].size.x * 0.4
				if not back_on:
					_fire(key, aim)
				buttons[key].set_pressed_look(false)
				_aim_touch.erase(event.index)
				_hide_preview()
	elif event is InputEventScreenDrag:
		if event.index == _joy_touch:
			var d: Vector2 = event.position - _joy_origin
			var r = _joy_base.size.x * 0.5
			if d.length() > r and not bool(Settings.get_value("joystick_fixed", false)):
				# Floating: base follows the finger
				_joy_origin = event.position - d.normalized() * r
				_joy_base.position = _joy_origin - _joy_base.size * 0.5
				d = d.normalized() * r
			d = d.limit_length(r)
			_joy_vec = d / r
			_joy_knob.position = _joy_origin + d - _joy_knob.size * 0.5
		elif _aim_touch.has(event.index):
			var dv: Vector2 = event.position - _aim_start[event.index]
			_aim_vec[event.index] = dv / 120.0 if dv.length() > 30.0 else Vector2.ZERO
			buttons[_aim_touch[event.index]].show_aim(_aim_vec[event.index])
			_preview(_aim_touch[event.index], _aim_vec[event.index])
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1: _fire("skill0", Vector2.ZERO)
			KEY_2: _fire("skill1", Vector2.ZERO)
			KEY_3: _fire("skill2", Vector2.ZERO)
			KEY_4: _fire("skill3", Vector2.ZERO)
			KEY_SPACE: _fire("dodge", Vector2.ZERO)
			KEY_Q: _fire("potion", Vector2.ZERO)
			KEY_J: _fire("attack", Vector2.ZERO)

## HUD widgets register in group "hud_blocker" so touches on them never start the joystick.
func _over_ui(pos: Vector2) -> bool:
	for n in get_tree().get_nodes_in_group("hud_blocker"):
		var c = n as Control
		if c and c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
			return true
	return false

func _button_at(pos: Vector2) -> String:
	var best = ""
	var bd = 1e9
	for k in buttons:
		var b: Control = buttons[k]
		var c = b.global_position + b.size * 0.5
		var d = pos.distance_to(c)
		if d <= b.size.x * 0.58 and d < bd:
			bd = d
			best = k
	return best

## Tap-to-move / tap-to-attack (control_scheme "tap").
func _tap_world(pos: Vector2) -> void:
	var cam = get_viewport().get_camera_3d()
	if cam == null or Game.world == null:
		return
	var from = cam.project_ray_origin(pos)
	var dir = cam.project_ray_normal(pos)
	if absf(dir.y) < 0.01:
		return
	var p = from + dir * (-from.y / dir.y)
	var near = Game.world.monsters_near(p, 1.6) if Game.world.has_method("monsters_near") else []
	if near.size() > 0:
		_tap_attack = near[0]
		_move_target = near[0].global_position
	else:
		_tap_attack = null
		_move_target = Game.world.clamp_to_walkable(player.global_position, p) if Game.world.has_method("clamp_to_walkable") else p
		if Fx.has_method("ring"):
			Fx.ring(_move_target + Vector3(0, 0.05, 0), 0.6, Color(1, 0.85, 0.5), 0.35)

func _fire(key: String, aim: Vector2) -> void:
	if not buttons.has(key):
		return
	var skill: String = buttons[key].skill
	if skill == "__potion":
		player.use_potion()
		return
	if skill == "__dodge":
		_dodge()
		return
	if skill == "":
		buttons[key].shake()
		return
	# Aim-free by default: the player picks the best target itself. Dragging = manual aim.
	var target = player.global_position + player.facing * 5.0
	var manual = aim.length() > 0.1
	if manual:
		var wd = screen_to_world_dir(aim.normalized())
		target = player.global_position + wd * 6.0
	if skill != player.basic_skill and not player.can_cast(skill):
		buttons[key].shake()
		UiTheme.haptic(15, 0.5)
	if player.has_method("request_cast"):
		if manual:
			player.request_cast(skill, target, true)
		else:
			player.request_cast(skill, target)

func _marker() -> Node:
	return get_tree().get_first_node_in_group("target_marker")

## Faint area preview while a skill button is held (drag shows the aimed direction).
func _preview(key: String, aim: Vector2) -> void:
	var m = _marker()
	if m == null or not buttons.has(key):
		return
	var sk: String = buttons[key].skill
	if sk == "" or sk.begins_with("__"):
		return
	var s = player.skill_def(sk) if player.has_method("skill_def") else Content.get_rec("skills", sk)
	m.show_preview(s, screen_to_world_dir(aim.normalized()) if aim.length() > 0.1 else Vector3.ZERO)

func _hide_preview() -> void:
	var m = _marker()
	if m:
		m.hide_preview()

func _dodge() -> void:
	if player.cooldown_left("__dodge") > 0 or not player.can_act():
		buttons["dodge"].shake()
		return
	player.cooldowns["__dodge"] = player.time_now() + 2.0
	var dir = player.intent_move if player.intent_move.length() > 0.1 else player.facing
	var dest: Vector3 = Game.world.clamp_to_walkable(player.global_position, player.global_position + dir.normalized() * 4.0)
	player.face_towards(player.global_position + dir)
	player.play("Dodge_Forward", 0.35, 1.4, true)
	player.invuln_until = player.time_now() + 0.3
	var t = player.create_tween()
	t.tween_property(player, "global_position", dest, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Sfx.play("dodge", -4.0)
	Fx.burst(player.global_position + Vector3(0, 0.3, 0), Color(0.6, 0.6, 0.7), 10, 2.0, 0.2, 0.4)

func _unhandled_input(event: InputEvent) -> void:
	# Desktop: right-click to attack towards the mouse
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and player:
		var cam = get_viewport().get_camera_3d()
		var from = cam.project_ray_origin(event.position)
		var dir = cam.project_ray_normal(event.position)
		if absf(dir.y) > 0.01:
			var t = -from.y / dir.y
			player.request_cast(player.basic_skill, from + dir * t)
