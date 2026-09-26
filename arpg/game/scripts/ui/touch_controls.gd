class_name TouchControls
extends Control
## Floating joystick (left half) + action buttons arc (right). Produces player intents.
## Keyboard/mouse also supported for desktop testing.

var player: Player
var _joy_touch = -1
var _joy_origin = Vector2.ZERO
var _joy_vec = Vector2.ZERO
var _joy_base: Control
var _joy_knob: Control
var buttons = {}        # key -> {btn, skill, cd_overlay}
var _aim_touch = {}     # touch index -> key
var _aim_start = {}
var _aim_vec = {}
const JOY_RADIUS := 110.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_base = _circle(200, Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.25))
	_joy_knob = _circle(90, Color(1, 0.85, 0.55, 0.35), Color(1, 0.9, 0.7, 0.6))
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
	p.add_theme_stylebox_override("panel", s)
	p.size = Vector2(d, d)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func setup(p: Player) -> void:
	player = p
	for c in get_children():
		if c is ActionButton:
			c.queue_free()
	buttons.clear()
	var vp = get_viewport_rect().size
	var anchor = Vector2(vp.x - 150, vp.y - 150)
	_add_button("attack", player.basic_skill, anchor, 160)
	var arc = [Vector2(-175, 20), Vector2(-150, -120), Vector2(-60, -195), Vector2(55, -210)]
	for i in 4:
		_add_button("skill%d" % i, player.ch.skill_bar[i], anchor + arc[i], 112)
	_add_button("dodge", "__dodge", anchor + Vector2(-280, 70), 100)
	_add_button("potion", "__potion", anchor + Vector2(-270, -60) + Vector2(-90, 130), 96)

func refresh_bar() -> void:
	for i in 4:
		var k = "skill%d" % i
		if buttons.has(k):
			buttons[k].set_skill(player.ch.skill_bar[i])

func _add_button(key: String, skill: String, center: Vector2, size: float) -> void:
	var b = ActionButton.new()
	add_child(b)
	b.setup(key, skill, size)
	var vp = get_viewport_rect().size
	UiTheme.place(b, 1.0, 1.0, center.x - vp.x - size * 0.5, center.y - vp.y - size * 0.5, size, size)
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
	player.intent_move = screen_to_world_dir(v)
	for k in buttons:
		buttons[k].update_state(player)

## Camera yaw 45°: screen up = world (-1,0,-1)
func screen_to_world_dir(v: Vector2) -> Vector3:
	if v.length() < 0.15:
		return Vector3.ZERO
	var yaw = deg_to_rad(45.0)
	var fwd = Vector3(-sin(yaw), 0, -cos(yaw))
	var right = Vector3(cos(yaw), 0, -sin(yaw))
	return (right * v.x + fwd * -v.y).limit_length(1.0)

func _input(event: InputEvent) -> void:
	if player == null:
		return
	if event is InputEventScreenTouch:
		var vp = get_viewport_rect().size
		if event.pressed:
			var hit_key = _button_at(event.position)
			if hit_key != "":
				_aim_touch[event.index] = hit_key
				_aim_start[event.index] = event.position
				_aim_vec[event.index] = Vector2.ZERO
				buttons[hit_key].set_pressed_look(true)
				get_viewport().set_input_as_handled()
			elif event.position.x < vp.x * 0.45 and _joy_touch < 0 and not _over_ui(event.position):
				_joy_touch = event.index
				_joy_origin = event.position
				_joy_vec = Vector2.ZERO
				_joy_base.visible = true
				_joy_knob.visible = true
				_joy_base.position = _joy_origin - _joy_base.size * 0.5
				_joy_knob.position = _joy_origin - _joy_knob.size * 0.5
		else:
			if event.index == _joy_touch:
				_joy_touch = -1
				_joy_vec = Vector2.ZERO
				_joy_base.visible = false
				_joy_knob.visible = false
			elif _aim_touch.has(event.index):
				var key: String = _aim_touch[event.index]
				_fire(key, _aim_vec.get(event.index, Vector2.ZERO))
				buttons[key].set_pressed_look(false)
				_aim_touch.erase(event.index)
	elif event is InputEventScreenDrag:
		if event.index == _joy_touch:
			var d: Vector2 = event.position - _joy_origin
			if d.length() > JOY_RADIUS:
				# Floating: base follows the finger
				_joy_origin = event.position - d.normalized() * JOY_RADIUS
				_joy_base.position = _joy_origin - _joy_base.size * 0.5
				d = d.normalized() * JOY_RADIUS
			_joy_vec = d / JOY_RADIUS
			_joy_knob.position = _joy_origin + d - _joy_knob.size * 0.5
		elif _aim_touch.has(event.index):
			var dv: Vector2 = event.position - _aim_start[event.index]
			_aim_vec[event.index] = dv / 120.0 if dv.length() > 30.0 else Vector2.ZERO
			buttons[_aim_touch[event.index]].show_aim(_aim_vec[event.index])
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1: _fire("skill0", Vector2.ZERO)
			KEY_2: _fire("skill1", Vector2.ZERO)
			KEY_3: _fire("skill2", Vector2.ZERO)
			KEY_4: _fire("skill3", Vector2.ZERO)
			KEY_SPACE: _fire("dodge", Vector2.ZERO)
			KEY_Q: _fire("potion", Vector2.ZERO)
			KEY_J: _fire("attack", Vector2.ZERO)

func _over_ui(pos: Vector2) -> bool:
	return pos.y < 110   # top bar area

func _button_at(pos: Vector2) -> String:
	for k in buttons:
		var b: Control = buttons[k]
		var c = b.global_position + b.size * 0.5
		if pos.distance_to(c) <= b.size.x * 0.58:
			return k
	return ""

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
		return
	var target = player.global_position + player.facing * 5.0
	if aim.length() > 0.1:
		var wd = screen_to_world_dir(aim.normalized())
		target = player.global_position + wd * 6.0
		var s = Content.get_rec("skills", skill)
		s = s.duplicate()
	player.request_cast(skill, target)
	if not player.can_cast(skill) and player.cooldown_left(skill) > 0:
		buttons[key].shake()

func _dodge() -> void:
	if player.cooldown_left("__dodge") > 0 or not player.can_act():
		return
	player.cooldowns["__dodge"] = player.time_now() + 2.0
	var dir = player.intent_move if player.intent_move.length() > 0.1 else player.facing
	var dest: Vector3 = Game.world.clamp_to_walkable(player.global_position, player.global_position + dir.normalized() * 5.0)
	player.face_towards(player.global_position + dir)
	player.play("Dodge_Forward", 0.35, 1.4, true)
	player.invuln_until = player.time_now() + 0.4
	var t = player.create_tween()
	t.tween_property(player, "global_position", dest, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Sfx.play("dodge", -4.0)
	Fx.burst(player.global_position + Vector3(0, 0.3, 0), Color(0.6, 0.6, 0.7), 10, 2.0, 0.2, 0.4)

func _unhandled_input(event: InputEvent) -> void:
	# Desktop: click to attack towards the mouse
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and player:
		var cam = get_viewport().get_camera_3d()
		var from = cam.project_ray_origin(event.position)
		var dir = cam.project_ray_normal(event.position)
		if absf(dir.y) > 0.01:
			var t = -from.y / dir.y
			player.request_cast(player.basic_skill, from + dir * t)
