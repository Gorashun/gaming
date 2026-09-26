class_name Mounts
extends RefCounted
## Mounts (GDD v2.1 #22). Mounted = move speed bonus (stat source "mount") + a mount model under the
## hero. Mount only outside combat; casting or being hit dismounts; with the "auto_mount" setting
## (default on) the hero remounts after 3 s out of combat. Data: `mounts` {id, name, model, scale,
## tint, speed_pct, seat_height, source, cost_gold, requires, desc}; config/mounts {remount_delay_s,
## fed_speed_pct, fed_duration_s}. Character: mounts_owned[], active_mount, mount_fed_until.

static func cfg() -> Dictionary:
	return Content.get_rec("config", "mounts")

static func rec(id: String) -> Dictionary:
	return Content.get_rec("mounts", id)

static func owns(ch: CharacterData, id: String) -> bool:
	return ch.mounts_owned.has(id)

static func grant_mount(ch: CharacterData, id: String) -> bool:
	if rec(id).is_empty() or owns(ch, id):
		return false
	ch.mounts_owned.append(id)
	ch.track("mounts_owned")
	if ch.active_mount == "":
		ch.active_mount = id
	Events.toast.emit("New mount: %s!" % rec(id).get("name", id), Color(1, 0.85, 0.5))
	return true

static func set_active(ch: CharacterData, id: String) -> bool:
	if id != "" and not owns(ch, id):
		return false
	ch.active_mount = id
	return true

## Stablemaster purchase: gold + optional quest/achievement requirement. Returns {ok, message}.
static func buy(ch: CharacterData, id: String) -> Dictionary:
	var r = rec(id)
	if r.is_empty():
		return {"ok": false, "message": "Unknown mount"}
	if owns(ch, id):
		return {"ok": false, "message": "Already yours"}
	var req = str(r.get("requires", ""))
	if req != "" and not ch.quests.get("done", []).has(req) and not ch.discoveries.has(req):
		return {"ok": false, "message": "Not yet earned"}
	var cost = int(r.get("cost_gold", 0))
	if ch.gold < cost:
		return {"ok": false, "message": "Not enough gold"}
	ch.gold -= cost
	grant_mount(ch, id)
	Events.gold_changed.emit(ch.gold)
	return {"ok": true, "message": "%s joins you!" % r.get("name", id)}

static func speed_pct(ch: CharacterData) -> float:
	var r = rec(ch.active_mount)
	var s = float(r.get("speed_pct", 40.0))
	if ch.play_seconds < float(ch.mount_fed_until):
		s += float(cfg().get("fed_speed_pct", 10.0))
	return s

static func feed(ch: CharacterData) -> void:
	ch.mount_fed_until = max(ch.play_seconds, float(ch.mount_fed_until)) + float(cfg().get("fed_duration_s", 600.0))

static func remount_delay() -> float:
	return float(cfg().get("remount_delay_s", 3.0))

## Builds the mount visual (data model or procedural "lantern hound"). Presentation only.
static func make_visual(id: String) -> Node3D:
	var r = rec(id)
	var tint = Color(r.get("tint", "#8a7a6a"))
	var path = str(r.get("model", ""))
	if path != "" and ResourceLoader.exists(path):
		var n: Node3D = load(path).instantiate()
		n.scale = Vector3.ONE * float(r.get("scale", 1.0))
		n.name = "Mount"
		return n
	var root = Node3D.new()
	root.name = "Mount"
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = tint
	body_mat.roughness = 0.8
	var body = MeshInstance3D.new()
	var cap = CapsuleMesh.new()
	cap.radius = 0.32
	cap.height = 1.3
	cap.radial_segments = 10
	cap.rings = 3
	body.mesh = cap
	body.material_override = body_mat
	body.rotation_degrees.x = 90
	body.position = Vector3(0, 0.62, 0)
	root.add_child(body)
	var head = MeshInstance3D.new()
	var hs = SphereMesh.new()
	hs.radius = 0.26
	hs.height = 0.5
	hs.radial_segments = 10
	hs.rings = 6
	head.mesh = hs
	head.material_override = body_mat
	head.position = Vector3(0, 0.95, 0.68)
	root.add_child(head)
	var eye_mat = StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.albedo_color = Color(1.0, 0.85, 0.4)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.75, 0.3)
	eye_mat.emission_energy_multiplier = 3.0
	for sx in [-0.1, 0.1]:
		var eye = MeshInstance3D.new()
		var es = SphereMesh.new()
		es.radius = 0.05
		es.height = 0.1
		es.radial_segments = 6
		es.rings = 3
		eye.mesh = es
		eye.material_override = eye_mat
		eye.position = Vector3(sx, 1.0, 0.9)
		root.add_child(eye)
	for p in [Vector3(-0.2, 0, 0.4), Vector3(0.2, 0, 0.4), Vector3(-0.2, 0, -0.4), Vector3(0.2, 0, -0.4)]:
		var leg = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 0.08
		cm.bottom_radius = 0.06
		cm.height = 0.5
		cm.radial_segments = 6
		leg.mesh = cm
		leg.material_override = body_mat
		leg.position = p + Vector3(0, 0.25, 0)
		leg.name = "Leg"
		root.add_child(leg)
	# Tail lantern: the mount's own little flame (emissive only, no light — light budget)
	var lantern = MeshInstance3D.new()
	var ls = SphereMesh.new()
	ls.radius = 0.09
	ls.height = 0.18
	lantern.mesh = ls
	lantern.material_override = eye_mat
	lantern.position = Vector3(0, 1.0, -0.8)
	root.add_child(lantern)
	root.scale = Vector3.ONE * float(r.get("scale", 1.0))
	return root
