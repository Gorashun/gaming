class_name ZoneLayout
extends RefCounted
## Pure layout generation (no nodes): rooms + corridors on a cell grid. Deterministic per seed.

const CELL := 4.0

var w = 28
var h = 28
var cells = PackedByteArray()      # 0 void, 1 floor
var rooms = []                     # [{rect: Rect2i, center: Vector2i}]
var start_room = 0
var end_room = 0
var rng = RandomNumberGenerator.new()

func generate(seed_value: int, size: int, room_count: int, room_min := 3, room_max := 6, corridor_w := 1) -> void:
	rng.seed = seed_value
	w = size
	h = size
	cells.resize(w * h)
	cells.fill(0)
	rooms.clear()
	var tries = 0
	while rooms.size() < room_count and tries < 400:
		tries += 1
		var rw = rng.randi_range(room_min, room_max)
		var rh = rng.randi_range(room_min, room_max)
		var rx = rng.randi_range(1, w - rw - 2)
		var ry = rng.randi_range(1, h - rh - 2)
		var r = Rect2i(rx, ry, rw, rh)
		var ok = true
		for o in rooms:
			if o.rect.grow(1).intersects(r):
				ok = false
				break
		if ok:
			rooms.append({"rect": r, "center": r.position + r.size / 2})
			for y in range(ry, ry + rh):
				for x in range(rx, rx + rw):
					set_cell(x, y, 1)
	# Connect: chain rooms by nearest unvisited (MST-ish), plus a couple of loops
	var connected = [0]
	var remaining = range(1, rooms.size())
	while remaining.size() > 0:
		var best_a = -1
		var best_b = -1
		var best_d = 1e9
		for a in connected:
			for b in remaining:
				var d: float = Vector2(rooms[a].center).distance_to(Vector2(rooms[b].center))
				if d < best_d:
					best_d = d
					best_a = a
					best_b = b
		_corridor(rooms[best_a].center, rooms[best_b].center, corridor_w)
		connected.append(best_b)
		remaining.erase(best_b)
	for i in 2:
		if rooms.size() > 3:
			var a = rng.randi_range(0, rooms.size() - 1)
			var b = rng.randi_range(0, rooms.size() - 1)
			if a != b:
				_corridor(rooms[a].center, rooms[b].center, corridor_w)
	# Start = room nearest a corner; end = farthest by BFS
	start_room = 0
	var best = 1e9
	for i in rooms.size():
		var d: float = Vector2(rooms[i].center).length()
		if d < best:
			best = d
			start_room = i
	var dist = bfs(rooms[start_room].center)
	var far = -1
	for i in rooms.size():
		var c: Vector2i = rooms[i].center
		var dd: int = dist.get(c, -1)
		if dd > far:
			far = dd
			end_room = i

func _corridor(a: Vector2i, b: Vector2i, cw: int) -> void:
	var p = a
	var horizontal_first = rng.randf() < 0.5
	var steps = [Vector2i(sign(b.x - a.x), 0), Vector2i(0, sign(b.y - a.y))]
	if not horizontal_first:
		steps.reverse()
	for s in steps:
		if s == Vector2i.ZERO:
			continue
		while (s.x != 0 and p.x != b.x) or (s.y != 0 and p.y != b.y):
			for ox in cw:
				for oy in cw:
					set_cell(p.x + ox, p.y + oy, 1)
			p += s
	set_cell(b.x, b.y, 1)

func set_cell(x: int, y: int, v: int) -> void:
	if x >= 0 and y >= 0 and x < w and y < h:
		cells[y * w + x] = v

func get_cell(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= w or y >= h:
		return 0
	return cells[y * w + x]

func bfs(from: Vector2i) -> Dictionary:
	var dist = {from: 0}
	var q = [from]
	while q.size() > 0:
		var c: Vector2i = q.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if get_cell(n.x, n.y) == 1 and not dist.has(n):
				dist[n] = dist[c] + 1
				q.append(n)
	return dist

func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3(c.x * CELL + CELL * 0.5, 0, c.y * CELL + CELL * 0.5)

func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / CELL)), int(floor(p.z / CELL)))

func floor_cells() -> Array:
	var out = []
	for y in h:
		for x in w:
			if cells[y * w + x] == 1:
				out.append(Vector2i(x, y))
	return out

func room_cells(i: int) -> Array:
	var out = []
	var r: Rect2i = rooms[i].rect
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			out.append(Vector2i(x, y))
	return out
