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

const TEXTURES: Dictionary = {
	SURFACE_WALL: "res://assets/sprites/env/corridor/wall_stone.png",
	SURFACE_FLOOR: "res://assets/sprites/env/corridor/floor_stone.png",
	SURFACE_CEILING: "res://assets/sprites/env/corridor/ceiling_stone.png",
	SURFACE_DOOR: "res://assets/sprites/env/corridor/door_boss.png",
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


## Texturen med mipmaps. [b]Undantaget från research 04:s "Mipmaps: Off"[/b]:
## den regeln gäller 2D-sprites. Nearest utan mipmaps kokar på golv och tak i
## snedvinkel, och den kokningen upprepad 63 steg per run är värre än den lilla
## oskärpan (research 05 §7).
static func tile_texture(path: String) -> Texture2D:
	if _tiles.has(path):
		return _tiles[path] as Texture2D
	var source: Texture2D = ResourceLoader.load(path) as Texture2D
	var result: Texture2D = source
	if source != null:
		var image: Image = source.get_image()
		if image != null:
			image = Image.create_from_data(image.get_width(), image.get_height(), false,
				image.get_format(), image.get_data())
			image.generate_mipmaps()
			result = ImageTexture.create_from_image(image)
	_tiles[path] = result
	return result


## Unlit material. Ljuset i korridoren är dimma, inte lampor (research 05 §1),
## så [constant BaseMaterial3D.SHADING_MODE_UNSHADED] är inte en förenkling –
## det är designen.
static func tile_material(surface: String, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = tile_texture(String(TEXTURES[surface]))
	mat.albedo_color = tint
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.texture_repeat = true
	# Väggarna ses bara inifrån, men korridoren korsar sig själv vid mötesrutan
	# och en felvänd kvad där skulle bli ett hål rakt ut i tomrummet.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Per-vertex-mörkningen ligger i COLOR och måste få multiplicera albedon.
	mat.vertex_color_use_as_albedo = true
	if surface == SURFACE_DOOR:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.5
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

	for key: String in map.tiles():
		var cell: Dictionary = map.cells[key]
		var at: Vector2i = Vector2i(int(cell["x"]), int(cell["y"]))
		var o: Vector3 = tile_origin(at)
		_floor_quad(tools[SURFACE_FLOOR], o, 0.0)
		_floor_quad(tools[SURFACE_CEILING], o, CEIL_M)
		for facing: int in range(4):
			if map.is_open(at, facing):
				continue
			_wall_quad(tools[SURFACE_WALL], o, facing)
		_collect_props(map, cell, at, doors, torches, signs)

	var mesh: ArrayMesh = ArrayMesh.new()
	for surface: String in [SURFACE_FLOOR, SURFACE_CEILING, SURFACE_WALL]:
		var st: SurfaceTool = tools[surface]
		st.index()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, tile_material(surface, floor_tint))

	return {"mesh": mesh, "doors": doors, "torches": torches, "signs": signs}


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


## Golv- eller takkvad. UV:n räknas ur VÄRLDSkoordinaten, inte ur rutan, så att
## mönstret fortsätter obrutet över rutgränsen.
static func _floor_quad(st: SurfaceTool, o: Vector3, height: float) -> void:
	var h: float = TILE_M * 0.5
	var a: Vector3 = o + Vector3(-h, height, -h)
	var b: Vector3 = o + Vector3(h, height, -h)
	var c: Vector3 = o + Vector3(h, height, h)
	var d: Vector3 = o + Vector3(-h, height, h)
	var uv: Array[Vector2] = [
		Vector2(a.x, a.z) / TEXELS_M,
		Vector2(b.x, b.z) / TEXELS_M,
		Vector2(c.x, c.z) / TEXELS_M,
		Vector2(d.x, d.z) / TEXELS_M,
	]
	_emit(st, [a, b, c, d], uv)


## Väggkvad på rutans sida [param facing]. Väggen står i rutgränsen, alltså
## halva rutan ut från mitten.
static func _wall_quad(st: SurfaceTool, o: Vector3, facing: int) -> void:
	var h: float = TILE_M * 0.5
	var n: Vector3 = dir_vector(facing) * h
	# Tangenten längs väggen: nästa väderstreck medurs.
	var t: Vector3 = dir_vector(posmod(facing + 1, 4)) * h
	var base: Vector3 = o + n
	var a: Vector3 = base - t
	var b: Vector3 = base + t
	var quad: Array[Vector3] = [
		a, b,
		b + Vector3(0.0, CEIL_M, 0.0),
		a + Vector3(0.0, CEIL_M, 0.0),
	]
	# u längs väggen i världsmeter, v uppifrån och ner så att golvlisten hamnar
	# nedtill oavsett vilket väderstreck väggen vetter åt.
	var u0: float = (a.x + a.z) / TEXELS_M
	var u1: float = (b.x + b.z) / TEXELS_M
	var v1: float = CEIL_M / TEXELS_M
	_emit(st, quad, [Vector2(u0, v1), Vector2(u1, v1), Vector2(u1, 0.0), Vector2(u0, 0.0)])


static func _emit(st: SurfaceTool, quad: Array[Vector3], uv: Array[Vector2]) -> void:
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_color(Color.WHITE)
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
	_emit(st, quad, [Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0)])
	st.index()
	var mesh: ArrayMesh = ArrayMesh.new()
	st.commit(mesh)
	return mesh
