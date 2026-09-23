class_name CorridorMesh
extends RefCounted
## Bygger hela våningens geometri som EN [ArrayMesh] med fyra ytor.
##
## [b]Varför hela våningen på en gång och inte rutorna framför spelaren:[/b] en
## våning är ~35 rutor ⇒ under 400 trianglar och fyra draw calls, vilket är
## långt under de "under 100 draw calls" research 05 §7 sätter som tak för
## mid-range Android. Att bygga om meshen vid varje steg vore däremot en
## allokering i hot loopen, 63 gånger per run. Dimman döljer ändå allt bortom
## ~3 rutor, så det syns inte att resten finns.
##
## [b]En yta per textur[/b] i stället för en atlas: mipmaps på en atlas blöder
## mellan regionerna på de låga nivåerna, och tre extra draw calls är billigare
## än den artefakten. Mipmaparna genereras vid inläsning ([method tile_texture])
## eftersom [code].import[/code]-filerna under [code]assets/[/code] ägs av
## UI-agenten – se docs/CORRIDOR_DEV_NOTES.md.

## Rutans sida i meter. En 64 px-textur kaklas exakt en gång per 1,5 m, alltså
## två gånger per ruta (research 05 §1).
const TILE_M: float = 3.0
const CEIL_M: float = 3.2
const EYE_M: float = 1.7
const TEXELS_M: float = 1.5

const SURFACE_WALL: String = "wall"
const SURFACE_FLOOR: String = "floor"
const SURFACE_CEILING: String = "ceiling"
const SURFACE_DOOR: String = "door"

## Ytornas innehålls-id i art-manifestet (M6). [b]Ingen filsökväg här[/b]:
## [Art] slår upp manifestet och faller tillbaka på M5:s kakel.
const TEXTURES: Dictionary = {
	SURFACE_WALL: &"env.corridor.wall",
	SURFACE_FLOOR: &"env.corridor.floor",
	SURFACE_CEILING: &"env.corridor.ceiling",
	SURFACE_DOOR: &"env.corridor.door",
}

const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

static var _tiles: Dictionary = {}


## Rutans mittpunkt i världen, på golvnivå.
static func tile_origin(at: Vector2i) -> Vector3:
	return Vector3(float(at.x) * TILE_M, 0.0, float(at.y) * TILE_M)


## Ögonpunkten i en ruta.
static func eye_position(at: Vector2i) -> Vector3:
	return tile_origin(at) + Vector3(0.0, EYE_M, 0.0)


static func dir_vector(facing: int) -> Vector3:
	var d: Vector2i = DIRS[posmod(facing, 4)]
	return Vector3(float(d.x), 0.0, float(d.y))


## Ytans textur ur manifestet, alltid med mipmaps. [b]Undantaget från
## research 04:s "Mipmaps: Off"[/b]: den regeln gäller 2D-sprites. Utan mipmaps
## kokar golv och tak i snedvinkel, 63 steg per run (research 05 §7).
static func surface_texture(surface: String) -> Texture2D:
	return tile_texture(TEXTURES.get(surface, &"env.corridor.wall") as StringName)


## Texturen för ett manifest-id, med mipmaps genererade vid behov så att ett
## byte av en textur aldrig kan ge kokande golv utan att någon märker det.
static func tile_texture(id: StringName) -> Texture2D:
	if _tiles.has(id):
		return _tiles[id] as Texture2D
	var result: Texture2D = null
	if String(id).begins_with("res://"):
		# Bakåtkompatibelt för anropare utanför korridoren (town_view.gd) som
		# fortfarande skickar en sökväg. Nya anrop ska använda ett manifest-id.
		result = Art.with_mipmaps(ResourceLoader.load(String(id)) as Texture2D)
	else:
		result = Art.with_mipmaps(Art.tex(id))
	_tiles[id] = result
	return result


## Töms av [method Art.reload_manifest]-anropare som vill se ny konst.
static func clear_cache() -> void:
	_tiles.clear()


const SHADER_PAINTED: String = "res://src/game/shaders/corridor_surface.gdshader"
const SHADER_PIXEL: String = "res://src/game/shaders/corridor_surface_pixel.gdshader"
## Hur många delar varje kvad delas i per led. Ljuset är bakat per hörn, och en
## 3 m-kvad med fyra hörn ger ett ljusfall som syns som en diagonal. 3 × 3 är
## ~2 500 trianglar för en hel våning, långt under research 05 §7:s budget.
const SUBDIV: int = 3
## Dörrens fyllnad: den har inga bakade hörn, så den får en fast kall ton.
const DOOR_FILL: Color = Color(0.30, 0.32, 0.38)


## Materialet för en yta: [code]corridor_surface.gdshader[/code], med
## ljuset i hörnfärgerna och handfacklan i shadern (se [CorridorLight]).
## [b]Målad konst ur manifestet ritas linear + mipmaps; Nearest bara för
## pixelkonst[/b] (M5:s kakel eller [code]"pixel": true[/code]).
static func tile_material(surface: String, tint: Color = Color.WHITE) -> ShaderMaterial:
	var id: StringName = TEXTURES.get(surface, &"env.corridor.wall") as StringName
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load(SHADER_PIXEL if Art.is_pixel(id) else SHADER_PAINTED) as Shader
	mat.set_shader_parameter(&"albedo_tex", surface_texture(surface))
	mat.set_shader_parameter(&"tint", tint)
	mat.set_shader_parameter(&"hand_color", CorridorLight.HAND_COLOR)
	mat.set_shader_parameter(&"hand_energy", CorridorLight.HAND_ENERGY)
	mat.set_shader_parameter(&"hand_range", CorridorLight.HAND_RANGE_M)
	if surface == SURFACE_DOOR:
		mat.set_shader_parameter(&"alpha_scissor", 0.5)
	return mat


## Bygger våningen. [param floor_tint] är våningsvarianten: samma atlas, annan
## ton, noll nya bildfiler (research 05 §5).
##
## Returnerar [code]{mesh, doors, torches, signs}[/code] där de tre sista är
## listor med platsbeskrivningar som vyn gör noder av.
static func build(map: CorridorMap, floor_tint: Color = Color.WHITE) -> Dictionary:
	var tools: Dictionary = {}
	for surface: String in [SURFACE_WALL, SURFACE_FLOOR, SURFACE_CEILING]:
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[surface] = st

	var doors: Array[Dictionary] = []
	var torches: Array[Dictionary] = []
	var signs: Array[Dictionary] = []

	# Två varv: facklorna måste vara kända innan första hörnet bakas.
	for key: String in map.tiles():
		var cell: Dictionary = map.cells[key]
		var at: Vector2i = Vector2i(int(cell["x"]), int(cell["y"]))
		_collect_props(map, cell, at, doors, torches, signs)
	var lights: PackedVector3Array = torch_points(torches)

	for key: String in map.tiles():
		var cell: Dictionary = map.cells[key]
		var at: Vector2i = Vector2i(int(cell["x"]), int(cell["y"]))
		var o: Vector3 = tile_origin(at)
		_floor_quad(tools[SURFACE_FLOOR], o, 0.0, lights)
		_floor_quad(tools[SURFACE_CEILING], o, CEIL_M, lights)
		for facing: int in range(4):
			if map.is_open(at, facing):
				continue
			_wall_quad(tools[SURFACE_WALL], o, facing, lights)

	var mesh: ArrayMesh = ArrayMesh.new()
	for surface: String in [SURFACE_FLOOR, SURFACE_CEILING, SURFACE_WALL]:
		var st: SurfaceTool = tools[surface]
		st.index()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, tile_material(surface, floor_tint))

	return {"mesh": mesh, "doors": doors, "torches": torches, "signs": signs, "lights": lights}


## Facklornas punkter i världen, samma formel som [method CorridorView._add_torch]
## använder för att hänga upp dem.
static func torch_points(torches: Array[Dictionary]) -> PackedVector3Array:
	var points: PackedVector3Array = PackedVector3Array()
	for spec: Dictionary in torches:
		points.append(torch_position(spec))
	return points


static func torch_position(spec: Dictionary) -> Vector3:
	var tile: Vector2i = spec["tile"]
	var facing: int = int(spec["facing"])
	var along: Vector3 = dir_vector(posmod(facing + 1, 4))
	return tile_origin(tile) + dir_vector(facing) * (TILE_M * 0.5 - 0.08) \
		+ along * float(spec.get("lateral", 0.0)) \
		+ Vector3(0.0, CEIL_M * float(spec.get("height", 0.62)), 0.0)


## Dörrar, facklor och skyltar. Dörrkvaden hänger i den BORTRE mynningen av sin
## ruta, inte i den närmaste: bossdörren ska växa i bild under hela den tysta
## sträckan (CORRIDOR_DESIGN §2.4) och fortfarande stå framför spelaren när hen
## kommit fram, så att öppnandet blir ett eget tapp (§3.3).
static func _collect_props(map: CorridorMap, cell: Dictionary, at: Vector2i,
		doors: Array[Dictionary], torches: Array[Dictionary], signs: Array[Dictionary]) -> void:
	var kind: String = String(cell["kind"])
	var links: Dictionary = cell["links"]

	if kind == CorridorMap.KIND_BOSS_DOOR:
		for slot: Variant in links:
			var neighbour: Dictionary = map.cells.get(String(links[slot]), {}) as Dictionary
			if bool(neighbour.get("boss", false)):
				doors.append({"tile": at, "facing": int(String(slot)), "kind": CorridorMap.KIND_BOSS_DOOR})
	elif kind == CorridorMap.KIND_FATE_DOOR:
		for slot: Variant in links:
			doors.append({"tile": at, "facing": posmod(int(String(slot)) + 2, 4), "kind": CorridorMap.KIND_FATE_DOOR})

	# Facklan markerar alltid NÅGOT (UI_GUIDE §17.3). Den sätts på den vägg som
	# finns; en fackla i en öppning skulle hänga i luften. Sidoförskjutningen
	# håller den ur vägen för skylten på samma vägg.
	if bool(cell.get("torch", false)) or kind == CorridorMap.KIND_JUNCTION or kind == CorridorMap.KIND_ALCOVE:
		for facing: int in [CorridorMap.FACING_WEST, CorridorMap.FACING_EAST,
				CorridorMap.FACING_NORTH, CorridorMap.FACING_SOUTH]:
			if not map.is_open(at, facing):
				torches.append({
					"tile": at,
					"facing": facing,
					"lateral": -1.05 if kind == CorridorMap.KIND_JUNCTION else 0.0,
					"height": 0.44 if kind == CorridorMap.KIND_JUNCTION else 0.62,
				})
				break

	# Skyltarna vid en korsning hänger på den BORTRE väggen, vända mot den som
	# kommer, och förskjutna åt sitt eget håll. En skylt i själva mynningen står
	# vinkelrätt mot blicken och syns inte förrän man redan vänt sig dit – och
	# då är valet redan gjort (CORRIDOR_DESIGN §2.3, UI_GUIDE §17.2).
	var cell_signs: Dictionary = cell.get("signs", {}) as Dictionary
	if cell_signs.is_empty():
		return
	var look: int = _approach_facing(cell, cell_signs)
	for slot: Variant in cell_signs:
		var exit_dir: int = int(String(slot))
		signs.append({
			"tile": at,
			"facing": look,
			"lateral": 0.0 if exit_dir == look else 1.0,
			"lateral_dir": exit_dir,
			"key": String(cell_signs[slot]),
		})


## Riktningen spelaren tittar åt när hen kommer fram till korsningen: motsatsen
## till den enda mynning som inte har en skylt, alltså den man kom in genom.
static func _approach_facing(cell: Dictionary, cell_signs: Dictionary) -> int:
	for slot: Variant in cell.get("links", {}) as Dictionary:
		if not cell_signs.has(String(slot)):
			return posmod(int(String(slot)) + 2, 4)
	return CorridorMap.FACING_NORTH


## Golv- eller takkvad, delad i [constant SUBDIV] × [constant SUBDIV]. UV:n
## räknas ur VÄRLDSkoordinaten, inte ur rutan, så att mönstret fortsätter
## obrutet över rutgränsen.
static func _floor_quad(st: SurfaceTool, o: Vector3, height: float, lights: PackedVector3Array = PackedVector3Array()) -> void:
	var h: float = TILE_M * 0.5
	var corner: Vector3 = o + Vector3(-h, height, -h)
	var ceiling: bool = height > 0.0
	var normal: Vector3 = Vector3.DOWN if ceiling else Vector3.UP
	_grid(st, corner, Vector3(TILE_M, 0.0, 0.0), Vector3(0.0, 0.0, TILE_M), normal, lights, ceiling, false)


## Väggkvad på rutans sida [param facing]. Väggen står i rutgränsen, alltså
## halva rutan ut från mitten.
static func _wall_quad(st: SurfaceTool, o: Vector3, facing: int, lights: PackedVector3Array = PackedVector3Array()) -> void:
	var h: float = TILE_M * 0.5
	var n: Vector3 = dir_vector(facing) * h
	# Tangenten längs väggen: nästa väderstreck medurs.
	var t: Vector3 = dir_vector(posmod(facing + 1, 4)) * h
	var a: Vector3 = o + n - t
	_grid(st, a, t * 2.0, Vector3(0.0, CEIL_M, 0.0), -dir_vector(facing), lights, false, true)


## Ett rutnät av kvader från [param corner] längs [param u_axis] och
## [param v_axis], med bakat ljus i varje hörn.
static func _grid(st: SurfaceTool, corner: Vector3, u_axis: Vector3, v_axis: Vector3,
		normal: Vector3, lights: PackedVector3Array, ceiling: bool, wall: bool) -> void:
	var n: int = SUBDIV
	for iu: int in range(n):
		for iv: int in range(n):
			var p: Array[Vector3] = [
				corner + u_axis * (float(iu) / n) + v_axis * (float(iv) / n),
				corner + u_axis * (float(iu + 1) / n) + v_axis * (float(iv) / n),
				corner + u_axis * (float(iu + 1) / n) + v_axis * (float(iv + 1) / n),
				corner + u_axis * (float(iu) / n) + v_axis * (float(iv + 1) / n),
			]
			var uv: Array[Vector2] = []
			var colors: Array[Color] = []
			for q: Vector3 in p:
				uv.append(_uv(q, wall))
				colors.append(_baked(q, lights, ceiling, wall))
			_emit(st, p, uv, normal, colors)


static func _uv(q: Vector3, wall: bool) -> Vector2:
	if wall:
		# u längs väggen i världsmeter, v uppifrån och ner så att golvlisten
		# hamnar nedtill oavsett vilket väderstreck väggen vetter åt.
		return Vector2((q.x + q.z) / TEXELS_M, (CEIL_M - q.y) / TEXELS_M)
	return Vector2(q.x, q.z) / TEXELS_M


static func _baked(q: Vector3, lights: PackedVector3Array, ceiling: bool, wall: bool) -> Color:
	var c: Color = CorridorLight.bake(q, lights)
	var factor: float = 1.0
	if ceiling:
		factor = CorridorLight.CEILING_FACTOR
	elif wall:
		factor = CorridorLight.wall_occlusion(q.y, CEIL_M)
	return Color(c.r * factor, c.g * factor, c.b * factor, 1.0)


static func _emit(st: SurfaceTool, quad: Array[Vector3], uv: Array[Vector2],
		normal: Vector3 = Vector3.UP, colors: Array[Color] = []) -> void:
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_color(colors[i] if colors.size() == 4 else Color.WHITE)
		st.set_normal(normal)
		st.set_uv(uv[i])
		st.add_vertex(quad[i])


## En fristående kvad, t.ex. en dörr i en mynning. [param inset] drar den några
## centimeter mot betraktaren så att den inte z-fightar med väggen bredvid.
static func door_mesh(size: Vector2) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx: float = size.x * 0.5
	var quad: Array[Vector3] = [
		Vector3(-hx, 0.0, 0.0), Vector3(hx, 0.0, 0.0),
		Vector3(hx, size.y, 0.0), Vector3(-hx, size.y, 0.0),
	]
	_emit(st, quad, [Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0)],
		Vector3.BACK, [DOOR_FILL, DOOR_FILL, DOOR_FILL, DOOR_FILL])
	st.index()
	var mesh: ArrayMesh = ArrayMesh.new()
	st.commit(mesh)
	return mesh
