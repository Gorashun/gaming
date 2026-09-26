class_name Minimap
extends Control
## Top-down minimap from the zone layout (floor cells), rotated to match the 45° camera yaw so
## "up" on the minimap is "up" on screen. Fog of war: cells are revealed within a radius of the hero
## and remembered per zone+seed for the session. Markers: exit portal, town stations, boss,
## Legendary+ drops, world-event tears, elites. Tap → full map.

signal tapped

const VIEW_CELLS := 7.5          # cells from centre to edge
const REVEAL_R := 3
static var _fog := {}            # "zone:seed" -> PackedByteArray

var world: Node
var _key = ""
var _revealed: PackedByteArray
var _acc = 0.0
var event_marker = null          # Vector3 or null (world-event tear)

func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(190, 190)

func setup(w: Node) -> void:
	world = w
	if world == null or world.layout == null:
		return
	_key = "%s:%s" % [world.zone.get("id", ""), world.get("zone_seed")]
	if not _fog.has(_key) or _fog[_key].size() != world.layout.w * world.layout.h:
		var b = PackedByteArray()
		b.resize(world.layout.w * world.layout.h)
		b.fill(0)
		_fog[_key] = b
	_revealed = _fog[_key]
	if world.get("is_town"):
		_revealed.fill(1)

func _process(delta: float) -> void:
	_acc += delta
	if _acc < 0.12:
		return
	_acc = 0.0
	if world == null or not is_instance_valid(world) or world.player == null or not is_instance_valid(world.player):
		return
	var lay: ZoneLayout = world.layout
	var pc = lay.world_to_cell(world.player.global_position)
	for y in range(pc.y - REVEAL_R, pc.y + REVEAL_R + 1):
		for x in range(pc.x - REVEAL_R, pc.x + REVEAL_R + 1):
			if x >= 0 and y >= 0 and x < lay.w and y < lay.h and Vector2(x - pc.x, y - pc.y).length() <= REVEAL_R + 0.5:
				_revealed[y * lay.w + x] = 1
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		tapped.emit()
		accept_event()

func _draw() -> void:
	var r = Rect2(Vector2.ZERO, size)
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.025, 0.05, 0.82)
	bg.set_corner_radius_all(18)
	draw_style_box(bg, r)
	if world == null or not is_instance_valid(world) or world.layout == null or world.player == null or not is_instance_valid(world.player):
		return
	var lay: ZoneLayout = world.layout
	var cell = ZoneLayout.CELL
	var ppos: Vector3 = world.player.global_position
	var pcf = Vector2(ppos.x / cell, ppos.z / cell)
	var k = min(size.x, size.y) * 0.5 / VIEW_CELLS
	draw_set_transform(size * 0.5, PI / 4.0, Vector2(k, k))
	var range_c = int(VIEW_CELLS * 1.5) + 1
	var pc = Vector2i(int(floor(pcf.x)), int(floor(pcf.y)))
	var floor_col = Color(0.62, 0.52, 0.4, 0.8)
	var edge_col = Color(0.95, 0.8, 0.55, 0.9)
	for y in range(pc.y - range_c, pc.y + range_c + 1):
		for x in range(pc.x - range_c, pc.x + range_c + 1):
			if lay.get_cell(x, y) != 1 or _revealed[y * lay.w + x] == 0:
				continue
			var o = Vector2(x, y) - pcf
			draw_rect(Rect2(o, Vector2(1.02, 1.02)), floor_col)
			# walls: edges next to void
			if lay.get_cell(x, y - 1) != 1:
				draw_line(o, o + Vector2(1, 0), edge_col, 0.14)
			if lay.get_cell(x, y + 1) != 1:
				draw_line(o + Vector2(0, 1), o + Vector2(1, 1), edge_col, 0.14)
			if lay.get_cell(x - 1, y) != 1:
				draw_line(o, o + Vector2(0, 1), edge_col, 0.14)
			if lay.get_cell(x + 1, y) != 1:
				draw_line(o + Vector2(1, 0), o + Vector2(1, 1), edge_col, 0.14)
	# Markers
	var marks = []
	if world.get("exit_portal") and is_instance_valid(world.exit_portal) and world.exit_portal.visible:
		marks.append([world.exit_portal.global_position, "portal", Color("#8fd0ff")])
	if world.get("is_town"):
		for it in world.interactables:
			if it.has("pos"):
				marks.append([it.pos, "talk", UiTheme.GOLD])
	if world.get("boss") and is_instance_valid(world.boss) and world.boss.alive:
		marks.append([world.boss.global_position, "skull_soft", Color("#ff6a5a")])
	for d in world.drops:
		if is_instance_valid(d) and d.get("item") is Dictionary and not d.item.is_empty() and Items.rarity_index(d.item.get("rarity", "common")) >= 4:
			marks.append([d.global_position, "star", UiTheme.rarity_color(d.item.rarity)])
	if event_marker is Vector3:
		marks.append([event_marker, "portal", Color("#c9a0ff")])
	draw_set_transform(size * 0.5, 0.0, Vector2.ONE)
	var rot = Transform2D(PI / 4.0, Vector2.ZERO)
	for m in marks:
		var p: Vector3 = m[0]
		var o2 = rot * ((Vector2(p.x / cell, p.z / cell) - pcf) * k)
		var half = size * 0.5 - Vector2(14, 14)
		var clamped = Vector2(clampf(o2.x, -half.x, half.x), clampf(o2.y, -half.y, half.y))
		var sz = 26.0 if clamped == o2 else 20.0
		draw_circle(clamped, sz * 0.55, Color(0, 0, 0, 0.55))
		draw_texture_rect(UiTheme.icon(m[1]), Rect2(clamped - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, m[2])
	# Hero arrow (facing, in screen space)
	var f: Vector3 = world.player.facing
	var fd = rot * Vector2(f.x, f.z)
	if fd.length() < 0.1:
		fd = Vector2(0, -1)
	fd = fd.normalized()
	var side = Vector2(-fd.y, fd.x)
	var tip = fd * 11
	var pts = PackedVector2Array([tip, -fd * 7 + side * 8, -fd * 3, -fd * 7 - side * 8])
	draw_colored_polygon(pts, Color("#ffd98a"))
	var cl = pts.duplicate()
	cl.append(pts[0])
	draw_polyline(cl, Color(0.15, 0.06, 0), 2.0, true)
	var frame = StyleBoxFlat.new()
	frame.draw_center = false
	frame.border_color = Color("#8a7448")
	frame.set_border_width_all(3)
	frame.set_corner_radius_all(18)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_style_box(frame, r)
