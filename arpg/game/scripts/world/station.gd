extends Node3D
## Town station (smith, alchemist, vendor, stash, waypoint...). Visual = kit prop + NPC + a soft
## ground sigil and halo in the station colour + a compact name plate. No real light: hubs get
## their warmth from the lantern posts (light budget, Art Bible 4).

func setup(st: Dictionary) -> void:
	var col = Color(st.get("color", "#ffd98a"))
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
		for m in a._overlay_mats:
			m.next_pass = null          # NPCs: rim only, no outline
		if Fx.toon_enabled:
			Fx._apply_toon(a, false)
		Fx.blob_shadow(a, 0.8, 0.5)
	var g = MeshInstance3D.new()
	var q = PlaneMesh.new()
	q.size = Vector2(3.6, 3.6)
	g.mesh = q
	g.material_override = Fx.shader_mat("res://shaders/loot_ground.gdshader", {"color": col, "disc": 0.35, "ring": 0.6, "rays": 0.0, "spin": 0.3, "alpha": 0.55})
	g.position.y = 0.06
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g)
	var halo = Fx.glow_sprite(Color(col, 0.35), 2.4)
	halo.position.y = 2.0
	add_child(halo)
	var l = Label3D.new()
	l.text = st.get("name", "")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.pixel_size = 0.0011
	l.font_size = 30
	l.outline_size = 10
	l.outline_modulate = Color(0.06, 0.04, 0.08, 0.9)
	l.modulate = col.lerp(Color.WHITE, 0.25)
	l.no_depth_test = true
	l.position.y = 3.3
	if UiTheme.has_method("font_title"):
		l.font = UiTheme.font_title()
	add_child(l)
