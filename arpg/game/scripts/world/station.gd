extends Node3D
## Town station (smith, alchemist, vendor, stash, waypoint...). Visual = props + floating icon label.

func setup(st: Dictionary) -> void:
	var model: String = st.get("model", "")
	if model != "":
		var ps = ZoneBuilder.scene_of(model)
		if ps:
			var n: Node3D = ps.instantiate()
			n.scale = Vector3.ONE * float(st.get("scale", 1.0))
			add_child(n)
	if st.has("npc"):
		var a = Actor.new()
		add_child(a)
		a.setup_model(st.npc, 1.0, Color(st.get("tint", "#ffffff")), Color(0.9, 0.8, 0.5))
		a.show_only_attachments(st.get("attachments", []))
		a.position = Vector3(0, 0, -1.2)
		a.play(st.get("npc_anim", "Idle"))
		a.set_physics_process(false)
	var l = Label3D.new()
	l.text = st.get("name", "")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.pixel_size = 0.0014
	l.font_size = 40
	l.outline_size = 10
	l.modulate = Color(st.get("color", "#ffd98a"))
	l.no_depth_test = true
	l.position.y = 3.0
	add_child(l)
	var light = OmniLight3D.new()
	light.light_color = Color(st.get("color", "#ffd98a"))
	light.light_energy = 1.2
	light.omni_range = 5.0
	light.position.y = 2.0
	add_child(light)
