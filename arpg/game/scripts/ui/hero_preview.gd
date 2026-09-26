class_name HeroPreview
extends SubViewportContainer
## Live 3D hero turntable(s) for the title, Hero and Bag screens: toon-shaded class model on a stone
## pedestal with a warm key light and a class-coloured rim light. Drag to rotate; tap picks a hero.
## Shows equipped weapon props (item_bases.model / weapon_types.prop) on the hand slots.

signal hero_tapped(index: int)

const WEAPON_WORDS := ["sword", "shield", "axe", "staff", "knife", "crossbow", "wand", "dagger", "book", "mug", "bow", "quiver"]

var vp: SubViewport
var cam: Camera3D
var heroes: Array = []        # [{root, actor, ring, light, class_id}]
var spin_speed = 0.0          # idle auto-spin rad/s
var focus_index = -1
var camera_distance = 5.2
var camera_height = 1.55
var look_height = 0.85
var fov = 30.0
var _drag = false
var _drag_moved = 0.0
var _drag_target = -1

func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	vp = SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.handle_input_locally = false
	add_child(vp)
	var we = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.42, 0.36, 0.5)
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = e
	vp.add_child(we)
	var key = DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.82, 0.62)
	key.light_energy = 1.25
	key.rotation_degrees = Vector3(-32, -28, 0)
	key.shadow_enabled = true
	vp.add_child(key)
	cam = Camera3D.new()
	cam.fov = fov
	vp.add_child(cam)
	_update_camera()

func _update_camera() -> void:
	var cx = 0.0
	if heroes.size() > 0 and focus_index >= 0 and focus_index < heroes.size():
		cx = heroes[focus_index].root.position.x
	cam.fov = fov
	cam.position = Vector3(cx, camera_height, camera_distance)
	cam.look_at(Vector3(cx, look_height, 0))

## Add one hero. `ch` (CharacterData) → equipment props; otherwise class defaults.
func add_hero(class_id: String, ch: Object = null, x := 0.0) -> Actor:
	var cls = Content.get_rec("classes", class_id)
	var col = Color(cls.get("color", "#ffd27a"))
	var root = Node3D.new()
	root.position = Vector3(x, 0, 0)
	vp.add_child(root)
	# Pedestal: dark stone drum + glowing class-coloured ring
	var ped = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.78
	cyl.bottom_radius = 0.9
	cyl.height = 0.28
	cyl.radial_segments = 32
	ped.mesh = cyl
	var sm = StandardMaterial3D.new()
	sm.albedo_color = Color("#2c2433")
	sm.roughness = 0.9
	ped.material_override = sm
	ped.position.y = -0.14
	root.add_child(ped)
	var ring = MeshInstance3D.new()
	var tor = TorusMesh.new()
	tor.inner_radius = 0.76
	tor.outer_radius = 0.84
	tor.rings = 32
	ring.mesh = tor
	var rm = StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = col
	rm.emission_enabled = true
	rm.emission = col
	ring.material_override = rm
	ring.position.y = 0.01
	ring.scale = Vector3(1, 0.4, 1)
	root.add_child(ring)
	# Rim light behind the hero, in the class colour
	var rim = OmniLight3D.new()
	rim.light_color = col
	rim.light_energy = 2.2
	rim.omni_range = 3.2
	rim.position = Vector3(0, 1.6, -1.1)
	root.add_child(rim)
	var actor = Actor.new()
	actor.set_physics_process(false)
	root.add_child(actor)
	actor.setup_model(cls.get("model", "res://assets/thirdparty/kaykit/adventurers/characters/Knight.glb"), 1.0, Color(1, 1, 1, 1), Color(cls.get("rim", "#ffd9a0")))
	actor.rotation.y = deg_to_rad(14)
	var h = {"root": root, "actor": actor, "ring": ring, "light": rim, "class_id": class_id, "ped": ped}
	heroes.append(h)
	apply_gear(heroes.size() - 1, ch)
	_update_camera()
	return actor

## Show class attachments minus default weapons, then attach equipped weapon props.
func apply_gear(index: int, ch: Object) -> void:
	var h = heroes[index]
	var actor: Actor = h.actor
	var cls = Content.get_rec("classes", h.class_id)
	var atts: Array = cls.get("attachments", [])
	var mh = null
	var oh = null
	if ch:
		mh = ch.equipment.get("main_hand")
		oh = ch.equipment.get("off_hand")
	# Gameplay code may own this (v2.1 §20); prefer it when present.
	for m in ["apply_gear_visuals", "apply_equipment_visuals", "refresh_gear_visuals"]:
		if ch and actor.has_method(m):
			actor.call(m, ch)
			_idle(index)
			return
	var mh_model = ItemIcons.model_for(mh) if mh else ""
	var oh_model = ItemIcons.model_for(oh) if oh else ""
	var keep = []
	for a in atts:
		var low = str(a).to_lower()
		var is_weapon = false
		for w in WEAPON_WORDS:
			if low.contains(w):
				is_weapon = true
		if is_weapon:
			# keep default weapon only when that hand has nothing equipped with a model
			var left = low.contains("shield") or low.contains("offhand") or low.contains("book")
			if (left and oh_model == "" and oh == null) or (not left and mh_model == "" and mh == null):
				keep.append(a)
		else:
			keep.append(a)
	actor.show_only_attachments(keep)
	_clear_props(actor)
	if mh_model != "":
		actor.attach_prop(mh_model, "handslot.r")
	if oh_model != "":
		actor.attach_prop(oh_model, "handslot.l")
	_mark_props(actor)
	_idle(index)

func _clear_props(actor: Actor) -> void:
	for n in actor.find_children("*", "Node3D", true, false):
		if n.has_meta("ui_prop"):
			n.queue_free()

func _mark_props(actor: Actor) -> void:
	var skel = actor.model.find_child("Skeleton3D", true, false) if actor.model else null
	if skel == null:
		return
	for ba in skel.find_children("*", "BoneAttachment3D", true, false):
		for c in ba.get_children():
			if c.scene_file_path != "":
				c.set_meta("ui_prop", true)

func _idle(index: int) -> void:
	var h = heroes[index]
	var cls = Content.get_rec("classes", h.class_id)
	var anim_name = str(cls.get("idle_anim", "Idle"))
	h.actor.play(anim_name, 0.0, 1.0, true)

func cheer(index: int) -> void:
	if index < 0 or index >= heroes.size():
		return
	var a: Actor = heroes[index].actor
	a.play("Cheer", 1.6, 1.0, true)
	var t = create_tween()
	t.tween_interval(1.7)
	t.tween_callback(func(): _idle(index))

func play(index: int, anim_name: String) -> void:
	if index >= 0 and index < heroes.size():
		heroes[index].actor.play(anim_name, 0.0, 1.0, true)

func set_focus(index: int, highlight := true) -> void:
	focus_index = index
	for i in heroes.size():
		var h = heroes[i]
		var on = (i == index) or not highlight
		h.light.light_energy = 2.6 if i == index else (1.0 if not on else 2.2)
		var mat: StandardMaterial3D = h.ring.material_override
		var col = Color(Content.get_rec("classes", h.class_id).get("color", "#ffd27a"))
		mat.albedo_color = col if on else col.darkened(0.6)
		mat.emission = mat.albedo_color

func _process(delta: float) -> void:
	if spin_speed != 0.0 and not _drag:
		for h in heroes:
			h.actor.rotation.y += spin_speed * delta

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag = true
			_drag_moved = 0.0
			_drag_target = _pick(event.position)
		else:
			if _drag and _drag_moved < 12.0:
				var i = _pick(event.position)
				if i >= 0:
					hero_tapped.emit(i)
			_drag = false
		accept_event()
	elif event is InputEventMouseMotion and _drag:
		_drag_moved += absf(event.relative.x)
		_rotate(_drag_target, event.relative.x)
		accept_event()
	elif event is InputEventScreenDrag:
		_drag_moved += absf(event.relative.x)
		_rotate(_pick(event.position), event.relative.x)
		accept_event()

func _rotate(i: int, dx: float) -> void:
	if heroes.is_empty():
		return
	if i < 0:
		i = focus_index if focus_index >= 0 else 0
	heroes[i].actor.rotation.y += dx * 0.012

func _pick(pos: Vector2) -> int:
	var best = -1
	var bd = 1e9
	for i in heroes.size():
		var p = cam.unproject_position(heroes[i].root.global_position + Vector3(0, 0.8, 0))
		var d = absf(p.x - pos.x)
		if d < bd:
			bd = d
			best = i
	if bd > size.x / max(1, heroes.size()):
		return -1
	return best
