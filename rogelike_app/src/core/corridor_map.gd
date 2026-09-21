class_name CorridorMap
extends RefCounted
## Korridorkartan för en våning: ren data, seedad, deterministisk, headless.
##
## [b]Vad den är:[/b] översättningen av en [RunGraph] (som säger VAD som väntar)
## till ett rutnät (som säger HUR det känns att gå dit). Ingen ny regel, ingen
## ny nod, inget Node-beroende – [code]src/core/[/code]-regeln gäller.
## [code]CORRIDOR_DESIGN.md §2[/code] äger grammatiken, [code]research/05 §2[/code]
## tekniken.
##
## [b]Rörelsen är framåtlåst[/b] (CORRIDOR_DESIGN §3.4): [method available_actions]
## returnerar högst [code]left[/code], [code]forward[/code] och [code]right[/code],
## aldrig vägen tillbaka. Följden är det löfte som gör döden till ett misstag i
## stället för otur: [b]ingenting dyker någonsin upp bakom spelaren[/b].
##
## [b]Det enda undantaget[/b] är återvändsgränden (§2.3 regel 4). Spelaren backar
## ändå aldrig: kartan vänder figuren på plats ([code]turn_around[/code]) när
## skatten är tagen, och vägen ut är återigen [code]forward[/code].
##
## [b]Hörn kostar ingen extra tapp[/b] (§2.2: "hörn kostar noll steg"). En ruta med
## exakt en utgång som inte är den man kom ifrån erbjuder den som
## [code]forward[/code], oavsett väderstreck, och [method apply] vrider dit.
##
## Typiskt bruk:
## [codeblock]
## var map: CorridorMap = CorridorMap.build(graph, rng.fork("corridor"))
## while not map.is_finished():
##     map.apply(policy_pick(map.available_actions()))
##     for event: Dictionary in map.events_since_last():
##         hud.play(event)
## [/codeblock]

# --- Väderstreck -----------------------------------------------------------
## Nord. Kameran tittar mot [code]-Z[/code] i Godot, därför är nord [code]-y[/code].
const FACING_NORTH: int = 0
const FACING_EAST: int = 1
const FACING_SOUTH: int = 2
const FACING_WEST: int = 3
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

# --- Handlingar ------------------------------------------------------------
const ACTION_LEFT: String = "left"
const ACTION_FORWARD: String = "forward"
const ACTION_RIGHT: String = "right"

# --- Rutans sort -----------------------------------------------------------
const KIND_START: String = "start"
const KIND_CORRIDOR: String = "corridor"
const KIND_CHAMBER: String = "chamber"
const KIND_JUNCTION: String = "junction"
## Återvändsgränd med ett altare (§2.5).
const KIND_ALCOVE: String = "alcove"
## Ödeskastets dörr (§2.2). Innehållet ligger i M3; kartan känner bara dörren.
const KIND_FATE_DOOR: String = "fate_door"
const KIND_BOSS_DOOR: String = "boss_door"

# --- Skyltnycklar (CORRIDOR_DESIGN §2.3) -----------------------------------
const SIGN_FIGHT: String = "fight"
const SIGN_ELITE: String = "elite"
const SIGN_REST: String = "rest"
const SIGN_MARKET: String = "market"
const SIGN_FATE: String = "fate"
const SIGN_UNKNOWN: String = "unknown"
const SIGN_BOSS: String = "boss"
## Alla nycklar en skylt får ha. Skylten ljuger aldrig (§2.3 regel 2); att stå
## på [constant SIGN_UNKNOWN] är att inte ha visat, inte att få byta åsikt.
const SIGN_KEYS: Array[String] = [SIGN_FIGHT, SIGN_ELITE, SIGN_REST, SIGN_MARKET,
	SIGN_FATE, SIGN_UNKNOWN, SIGN_BOSS]

# --- Händelser -------------------------------------------------------------
const EVENT_CELL_ENTERED: String = "cell_entered"
const EVENT_TURNED: String = "turned"
const EVENT_TURN_AROUND: String = "turn_around"
const EVENT_REACHED_JUNCTION: String = "reached_junction"
const EVENT_JUNCTION_AHEAD: String = "junction_ahead"
const EVENT_ENCOUNTER_AHEAD: String = "encounter_ahead"
const EVENT_ENCOUNTER_REACHED: String = "encounter_reached"
const EVENT_TRAP_CHOICE: String = "trap_choice"
const EVENT_TRAP_RESOLVED: String = "trap_resolved"
const EVENT_TREASURE: String = "treasure"
const EVENT_BOSS_DOOR: String = "boss_door"
const EVENT_FATE_DOOR: String = "fate_door"
const EVENT_SILENT_STRETCH: String = "silent_stretch"
const EVENT_BLOCKED: String = "blocked"
const EVENT_FLOOR_CLEARED: String = "floor_cleared"

# --- Kantlängder (§2.2, seedat inom research 05:s 2–4 steg) ----------------
## [b]Stegbudgeten styr intervallen[/b], inte tvärtom. En våning kostar
## [code]entry+mid+junction+branch+silent+4[/code] steg (de fyra fasta är hörnet
## ut i grenen, hörnet in mot mitten, bossdörren och bossrummet), och en run är
## tre våningar plus upp till tre återvändsgränder à 4 steg:
## [codeblock]
## min = 3 * (2+2+2+2+3+4)            = 45 steg
## max = 3 * (2+3+3+3+4+4) + 3 * 4    = 69 steg
## [/codeblock]
## Det håller CORRIDOR_DESIGN §8.1:s stoppregel (≤ 90 s korridortid per run)
## med marginal vid 260 ms per steg. Vidgas något av intervallen nedan måste
## [code]test_a_run_stays_inside_the_step_budget[/code] räknas om.
##
## Lärkanten: kort, spelaren lär sig att sikten ändras.
const ENTRY_STEPS: Vector2i = Vector2i(2, 2)
## Rum 1 → rum 2.
const MID_STEPS: Vector2i = Vector2i(2, 3)
## Rum 2 → T-korsningen. Skylten syns efter sista hörnet.
const JUNCTION_STEPS: Vector2i = Vector2i(2, 3)
## T-korsning → rum 3. Samma längd i båda grenarna, annars möts de inte.
const BRANCH_STEPS: Vector2i = Vector2i(2, 3)
## Den tysta sträckan (§2.4). Alltid ett steg längre än sina grannar.
const SILENT_STEPS: Vector2i = Vector2i(3, 4)
## Återvändsgränden ligger två rutor in: 2 steg in + 2 ut = 4 steg (§2.3 regel 4).
const ALCOVE_DEPTH: int = 2
## §2.5: "det ska kännas som tur, inte som en checklista".
const ALCOVE_CHANCE: float = 0.35
## Så långt bort en skylt eller en silhuett blir synlig (rutor).
const SIGHT_TILES: int = 2

## Återvändsgrändens viktade innehåll (§2.5). De 15 % "ingenting materiellt" är
## obligatoriska: en gränd som alltid lönar sig är inte nyfikenhet.
const TREASURE_TABLE: Array[Dictionary] = [
	{"id": "FORGE_FACE", "weight": 40},
	{"id": "PIPS", "weight": 25, "amount": 3},
	{"id": "RELIC", "weight": 20, "pool": "uncommon"},
	{"id": "CODEX", "weight": 15, "amount": 1},
]

## Fälltyperna (§2.6). En per våning, två prislappar, ingen gratis utväg.
const TRAPS: Array[Dictionary] = [
	{
		"id": "TRAP_WEB",
		"options": [
			{"id": "PUSH_THROUGH", "cost": "hp", "amount": 5},
			{"id": "CUT_FREE", "cost": "cracked_face", "amount": 1},
		],
	},
	{
		"id": "TRAP_EMBERS",
		"options": [
			{"id": "RUN_ACROSS", "cost": "hp", "amount": 8},
			{"id": "SMOTHER", "cost": "cracked_face", "amount": 1},
		],
	},
	{
		"id": "TRAP_COLLAPSE",
		"options": [
			{"id": "SQUEEZE", "cost": "hp", "amount": 3},
			{"id": "DIG_OUT", "cost": "cracked_face", "amount": 1},
		],
	},
]

var floor_index: int = 1
## [code]"x,y"[/code] → rut-Dictionary. Strängnyckel så att kartan går rakt ner i
## sparfilens JSON utan egen serialiserare, precis som [RunGraph.nodes].
var cells: Dictionary = {}
## Rutnycklarna i den ordning de byggdes. Stabil ordning för mesh och test.
var order: Array[String] = []

var position: Vector2i = Vector2i.ZERO
## 0=N, 1=Ö, 2=S, 3=V. Härleds ur [member yaw_quarters] och hålls i synk.
var facing: int = FACING_NORTH
## [b]Obegränsad[/b] kvartsvarvsräknare. Kameran tweenar mot en absolut vinkel,
## annars tar [Tween] kortaste vägen och snurrar åt fel håll vid 270° → 0°
## (research 05 §1).
var yaw_quarters: int = 0
var steps_taken: int = 0
## Rutan spelaren står på när en fälla väntar på svar. Tom = ingen fälla väntar.
var pending_trap_key: String = ""
## Ödeskastet är M3-innehåll (DECISIONS 2026-09-21). Kartan kan bygga dörren,
## men gör det bara när anroparen säger att det finns något bakom den.
var allow_fate: bool = false

var _events: Array[Dictionary] = []
## Rutan spelaren kom ifrån. Tömd av [method _turn_around] så att gränden får
## en utgång igen.
var _came_from: String = ""
## Sant medan spelaren går ut ur en återvändsgränd.
var _backtracking: bool = false
## Rutorna längs den väg spelaren faktiskt gått. Underlag för kritstråket (§2.7).
var _trail: Array[String] = []


# ---------------------------------------------------------------------------
# Byggnation
# ---------------------------------------------------------------------------

## Bygger våningens korridor ur [param graph]. Samma seed ⇒ byte-identisk karta.
##
## [b]Formen[/b] (§2.2, ett hörn per gren så att grenarna möts igen före den
## tysta sträckan):
## [codeblock]
##                      [BOSS]
##                        |
##                   [bossdörr]
##                        |
##                 (tysta sträckan)
##                        |
##          +-------- (möte) --------+
##          |                        |
##       [rum 3a]                [rum 3b]
##          |                        |
##          +------ [T-korsning] ----+
##                     |    \
##                  [rum 2]  (återvändsgränd)
## [/codeblock]
static func build(graph: RunGraph, rng: Rng, p_allow_fate: bool = false) -> CorridorMap:
	var map: CorridorMap = CorridorMap.new()
	map.floor_index = graph.floor_index
	map.allow_fate = p_allow_fate

	# Dragningsordningen är fast: den är en del av seedkontraktet och får aldrig
	# bero på en gren, annars glider samma seed isär mellan två körningar.
	var l_entry: int = rng.next_int(ENTRY_STEPS.x, ENTRY_STEPS.y)
	var l_mid: int = rng.next_int(MID_STEPS.x, MID_STEPS.y)
	var l_junction: int = rng.next_int(JUNCTION_STEPS.x, JUNCTION_STEPS.y)
	var l_branch: int = rng.next_int(BRANCH_STEPS.x, BRANCH_STEPS.y)
	var l_silent: int = rng.next_int(SILENT_STEPS.x, SILENT_STEPS.y)
	var has_side_branch: bool = rng.chance(ALCOVE_CHANCE)
	var unknown_on_left: bool = rng.next_int(0, 1) == 0
	var trap_roll: float = rng.next_float()
	var treasure: Dictionary = map._roll_treasure(rng)

	var rooms: Dictionary = map._rooms_by_index(graph)
	var room1: String = map._first_id(rooms, 1)
	var room2: String = map._first_id(rooms, 2)
	var branch_ids: Array = rooms.get(3, []) as Array
	var boss_id: String = map._first_id(rooms, RunGraph.ROOMS_PER_FLOOR)

	var p: Vector2i = Vector2i.ZERO
	var start_cell: Dictionary = map._ensure(p, KIND_START)
	start_cell["visited"] = true

	# Lärkanten, sedan rum 1 och rum 2.
	p = map._carve(p, FACING_NORTH, l_entry)
	map._make_chamber(p, graph, room1)
	var trap_candidates: Array[String] = []
	p = map._carve(p, FACING_NORTH, l_mid, trap_candidates)
	map._make_chamber(p, graph, room2)
	p = map._carve(p, FACING_NORTH, l_junction, trap_candidates)

	# T-korsningen. Absolut riktning nord ⇒ vänster = väster, höger = öster.
	var junction: Vector2i = p
	map._cell(junction)["kind"] = KIND_JUNCTION
	var signs: Dictionary = {}

	# Det tredje valet, rakt fram, är ALDRIG en strid och aldrig en genväg
	# (§2.3 regel 4): antingen en återvändsgränd eller ödeskastets dörr.
	if has_side_branch:
		var tip: Vector2i = map._carve(junction, FACING_NORTH, ALCOVE_DEPTH)
		var tip_cell: Dictionary = map._cell(tip)
		if map.allow_fate:
			tip_cell["kind"] = KIND_FATE_DOOR
			signs[str(FACING_NORTH)] = SIGN_FATE
		else:
			tip_cell["kind"] = KIND_ALCOVE
			tip_cell["treasure"] = treasure
			signs[str(FACING_NORTH)] = SIGN_UNKNOWN

	# Grenarna. branch_index 0 = vänster (§2.3 regel 4).
	var left_id: String = String(branch_ids[0]) if branch_ids.size() > 0 else ""
	var right_id: String = String(branch_ids[1]) if branch_ids.size() > 1 else left_id
	var merge_left: Vector2i = map._carve_branch(junction, FACING_WEST, l_branch, graph, left_id)
	var merge_right: Vector2i = map._carve_branch(junction, FACING_EAST, l_branch, graph, right_id)
	assert(merge_left == merge_right)
	# Mötesrutan har tre mynningar men bara EN väg vidare. Utan det här skulle
	# spelaren kunna vika av ner i den gren hen valde bort – en väg grafen inte
	# har (§2.3 regel 5).
	(map._cell(merge_left)["blocked"] as Array).append_array([str(FACING_WEST), str(FACING_EAST)])

	signs[str(FACING_WEST)] = map._sign_for(graph, left_id)
	signs[str(FACING_EAST)] = map._sign_for(graph, right_id)
	# Exakt ETT "?" per våning (§2.3 regel 3). Finns en sidogren bär den frågan;
	# annars får en av stridsgrenarna den, seedat.
	if not signs.has(str(FACING_NORTH)) or String(signs[str(FACING_NORTH)]) == SIGN_FATE:
		signs[str(FACING_WEST if unknown_on_left else FACING_EAST)] = SIGN_UNKNOWN
	map._cell(junction)["signs"] = signs

	# Den tysta sträckan och bossdörren (§2.4). Ingen fälla får ligga här.
	var door: Vector2i = map._carve(merge_left, FACING_NORTH, l_silent)
	var door_cell: Dictionary = map._cell(door)
	door_cell["kind"] = KIND_BOSS_DOOR
	door_cell["sign"] = SIGN_BOSS
	map._cell(merge_left)["silent_stretch"] = true
	var boss: Vector2i = map._carve(door, FACING_NORTH, 1)
	map._make_chamber(boss, graph, boss_id)

	map._place_trap(trap_candidates, trap_roll)
	map._trail = [map._key(Vector2i.ZERO)]
	map._push({"type": EVENT_CELL_ENTERED, "cell": map._key(Vector2i.ZERO), "kind": KIND_START})
	map._face_the_only_way_on()
	map._look_ahead()
	return map


## Torget i Chalkrim som rutnät (CORRIDOR_DESIGN §5.1, research 05 §6).
##
## [b]Ingen graf, ingen seed, ingen regel[/b] – bara geometri: en 3×2-kammare med
## tre upplysta mynningar i den bortre väggen. Poängen är att staden byggs med
## exakt samma [CorridorMesh] och samma kamera som Gropen, vilket enligt research
## 05 §6 kostar "noll ny kod" och gör att spelaren lär sig dungeon-inputen på
## torget utan att det kallas tutorial.
##
## Mynningarna ligger i ordningen vänster, mitt, höger; anroparen binder dem till
## Skrotmarknaden, Gropens mun och Kritväggen.
const TOWN_EXIT_OFFSETS: Array[int] = [-1, 0, 1]
## Torgets djup i rutor. Två: då hamnar sidomynningarna på ±29° i ett
## 37,5°-halvfält, alltså tydligt åt vänster och höger men fortfarande hela i
## bild. Tre rutor drar ihop dem mot mitten och torget blir en korridor till.
const TOWN_DEPTH: int = 2


static func town_square() -> CorridorMap:
	var map: CorridorMap = CorridorMap.new()
	for y: int in range(0, TOWN_DEPTH):
		for x: int in TOWN_EXIT_OFFSETS:
			var cell: Dictionary = map._ensure(Vector2i(x, y), KIND_CHAMBER)
			cell["visited"] = true
	# Golvet hänger ihop i båda led, annars emitterar meshen väggar mitt i torget.
	for y: int in range(0, TOWN_DEPTH):
		for x: int in [-1, 0]:
			map._link(Vector2i(x, y), FACING_EAST, Vector2i(x + 1, y))
	for y: int in range(1, TOWN_DEPTH):
		for x: int in TOWN_EXIT_OFFSETS:
			map._link(Vector2i(x, y), FACING_NORTH, Vector2i(x, y - 1))
	for x: int in TOWN_EXIT_OFFSETS:
		# Mynningen är en egen ruta: en nisch med en fackla i, inte ett hål i en
		# vägg. KIND_ALCOVE gör att CorridorMesh sätter facklan där av sig själv.
		var mouth: Dictionary = map._ensure(Vector2i(x, -1), KIND_ALCOVE)
		mouth["torch"] = true
		map._link(Vector2i(x, 0), FACING_NORTH, Vector2i(x, -1))
	map.position = Vector2i(0, TOWN_DEPTH - 1)
	map.facing = FACING_NORTH
	map._trail = [_key(map.position)]
	map._events.clear()
	return map


## Rutan en av torgets tre mynningar ligger i. [param index] är 0 = vänster,
## 1 = mitt, 2 = höger.
static func town_exit_tile(index: int) -> Vector2i:
	return Vector2i(TOWN_EXIT_OFFSETS[clampi(index, 0, TOWN_EXIT_OFFSETS.size() - 1)], -1)


## Rum-index → nod-id:n, i grenordning. Kartan läser grafen, aldrig tvärtom.
func _rooms_by_index(graph: RunGraph) -> Dictionary:
	var rooms: Dictionary = {}
	for id: String in graph.ordered_ids():
		var room: int = int(graph.node_at(id).get("room_in_floor", 0))
		if not rooms.has(room):
			rooms[room] = [] as Array
		(rooms[room] as Array).append(id)
	return rooms


func _first_id(rooms: Dictionary, room: int) -> String:
	var ids: Array = rooms.get(room, []) as Array
	return String(ids[0]) if not ids.is_empty() else ""


## Skyltnyckeln för en nod. Grafen har bara COMBAT och BOSS i M5; de fyra andra
## nycklarna finns för M3 och kostar en rad var när nodtyperna kommer.
func _sign_for(graph: RunGraph, node_id: String) -> String:
	if node_id == "":
		return SIGN_UNKNOWN
	if graph.is_boss(node_id):
		return SIGN_BOSS
	return SIGN_FIGHT


## En gren: ett steg ut i sidled, [param steps] norrut till kammaren, ett steg
## till och sedan tillbaka in mot mittlinjen. Returnerar mötesrutan.
func _carve_branch(from: Vector2i, side: int, steps: int, graph: RunGraph, node_id: String) -> Vector2i:
	var p: Vector2i = _carve(from, side, 1)
	p = _carve(p, FACING_NORTH, steps)
	_make_chamber(p, graph, node_id)
	p = _carve(p, FACING_NORTH, 1)
	return _carve(p, FACING_EAST if side == FACING_WEST else FACING_WEST, 1)


## Gräver [param steps] rutor i riktning [param dir] och länkar dem åt båda håll.
## Länken är dubbelriktad i geometrin – att den inte får GÅS åt båda håll är
## [method available_actions] ensam om att bestämma.
func _carve(from: Vector2i, dir: int, steps: int, collect: Array = []) -> Vector2i:
	var p: Vector2i = from
	for _i: int in range(steps):
		var next_pos: Vector2i = p + DIRS[dir]
		_ensure(next_pos, KIND_CORRIDOR)
		_link(p, dir, next_pos)
		p = next_pos
		collect.append(_key(p))
	return p


func _make_chamber(at: Vector2i, graph: RunGraph, node_id: String) -> void:
	var cell: Dictionary = _cell(at)
	cell["kind"] = KIND_CHAMBER
	cell["node_id"] = node_id
	cell["encounter"] = node_id != ""
	cell["boss"] = graph.is_boss(node_id)
	# Facklan markerar alltid NÅGOT (UI_GUIDE §17.3): en kammare eller en korsning.
	cell["torch"] = true


## Lägger våningens enda fälla på en av korridorrutorna mellan rum 1 och
## T-korsningen. [b]Aldrig[/b] på den tysta sträckan och aldrig i en kammare:
## att gå in i bossen skadad ska vara spelarens eget fel (§2.6 regel 3).
func _place_trap(candidates: Array[String], roll: float) -> void:
	var open: Array[String] = []
	for key: String in candidates:
		var cell: Dictionary = cells.get(key, {}) as Dictionary
		if String(cell.get("kind", "")) == KIND_CORRIDOR:
			open.append(key)
	if open.is_empty():
		return
	var index: int = clampi(int(roll * float(open.size())), 0, open.size() - 1)
	var spec: Dictionary = TRAPS[posmod(floor_index - 1, TRAPS.size())].duplicate(true)
	(cells[open[index]] as Dictionary)["trap"] = spec


func _roll_treasure(rng: Rng) -> Dictionary:
	var items: Array = []
	var weights: Array = []
	for row: Dictionary in TREASURE_TABLE:
		items.append(row)
		weights.append(int(row["weight"]))
	var picked: Variant = rng.weighted_pick(items, weights)
	return (picked as Dictionary).duplicate(true) if picked != null else {}


# ---------------------------------------------------------------------------
# Rutor
# ---------------------------------------------------------------------------

static func _key(at: Vector2i) -> String:
	return "%d,%d" % [at.x, at.y]


## Rutnyckeln för en position. Publik: vyn namnger sina noder med den.
static func cell_key(at: Vector2i) -> String:
	return _key(at)


static func key_to_vec(key: String) -> Vector2i:
	var parts: PackedStringArray = key.split(",")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))


func _ensure(at: Vector2i, kind: String) -> Dictionary:
	var key: String = _key(at)
	if cells.has(key):
		return cells[key] as Dictionary
	var cell: Dictionary = {
		"key": key,
		"x": at.x,
		"y": at.y,
		"kind": kind,
		"node_id": "",
		"encounter": false,
		"boss": false,
		"torch": false,
		"sign": "",
		"signs": {},
		"trap": {},
		"trap_done": false,
		"treasure": {},
		"links": {},
		"blocked": [],
		"visited": false,
		"silent_stretch": false,
	}
	cells[key] = cell
	order.append(key)
	return cell


func _link(a: Vector2i, dir: int, b: Vector2i) -> void:
	(_cell(a)["links"] as Dictionary)[str(dir)] = _key(b)
	(_cell(b)["links"] as Dictionary)[str(posmod(dir + 2, 4))] = _key(a)


func _cell(at: Vector2i) -> Dictionary:
	return cells.get(_key(at), {}) as Dictionary


## Rutan spelaren står på.
func current_cell() -> Dictionary:
	return _cell(position)


func cell_at(at: Vector2i) -> Dictionary:
	return _cell(at)


## Sant om man kan gå från [param at] i riktning [param dir]. Meshen använder
## den för att veta var en väggkvad ska emitteras och var en öppning ska stå.
func is_open(at: Vector2i, dir: int) -> bool:
	return (_cell(at).get("links", {}) as Dictionary).has(str(dir))


func is_walkable(at: Vector2i) -> bool:
	return cells.has(_key(at))


## Alla rutnycklar i byggordning.
func tiles() -> Array[String]:
	return order.duplicate()


## Kammaren med bossen, eller en tom Dictionary.
func boss_cell() -> Dictionary:
	for key: String in order:
		var cell: Dictionary = cells[key] as Dictionary
		if bool(cell.get("boss", false)):
			return cell
	return {}


func is_finished() -> bool:
	return bool(current_cell().get("boss", false))


## Rutorna spelaren gått på, i ordning. Kritstråket (§2.7) ritar exakt detta och
## ingenting annat: den visar bara det du sett.
func trail() -> Array[String]:
	return _trail.duplicate()


# ---------------------------------------------------------------------------
# Rörelse
# ---------------------------------------------------------------------------

## Kamerans absoluta vinkel i hela kvartsvarv. Aldrig wrappad.
func yaw_quarter_turns() -> int:
	return yaw_quarters


func yaw_degrees() -> int:
	return yaw_quarters * 90


## Kamerans [code]rotation.y[/code]. Nord (facing 0) är [code]-Z[/code], och ett
## steg åt höger är ett negativt varv runt Y.
func yaw_radians() -> float:
	return -float(yaw_quarters) * PI * 0.5


## Vad de tre knapparna leder till. Högst tre poster, aldrig vägen tillbaka.
##
## Returnerar [code]{left|forward|right: {dir, sign, kind, cell, node_id, distance}}[/code].
## En ruta med exakt en utgång är en korridor och inte en korsning (§2.3 regel 1)
## – då ligger utgången alltid på [constant ACTION_FORWARD], även i ett hörn.
## Väntar en fälla på svar returneras en tom Dictionary: valet är vägen framåt.
func available_actions() -> Dictionary:
	if pending_trap_key != "":
		return {}
	var exits: Array[int] = _open_dirs()
	var result: Dictionary = {}
	if exits.is_empty():
		return result
	if exits.size() == 1:
		result[ACTION_FORWARD] = _action_info(exits[0])
		return result
	for dir: int in exits:
		result[_action_for(dir)] = _action_info(dir)
	return result


## Öppna riktningar från rutan. Vägen tillbaka och varje ruta som redan är
## besökt faller bort – det är den regeln som gör
## [code]THE WAY BACK IS GONE[/code] (§3.4) till en egenskap hos kartan i
## stället för en kontroll spridd över UI:t.
##
## Under [member _backtracking] (vägen ut ur en återvändsgränd) stängs
## besöktfiltret av, annars skulle gränden inte ha någon utgång alls.
func _open_dirs() -> Array[int]:
	var cell: Dictionary = current_cell()
	var links: Dictionary = cell.get("links", {}) as Dictionary
	var blocked: Array = cell.get("blocked", []) as Array
	var result: Array[int] = []
	for dir: int in range(4):
		var slot: String = str(dir)
		if not links.has(slot) or blocked.has(slot):
			continue
		var target_key: String = String(links[slot])
		if target_key == _came_from:
			continue
		if not _backtracking and bool((cells.get(target_key, {}) as Dictionary).get("visited", false)):
			continue
		result.append(dir)
	return result


## Finns det något obesökt åt något håll härifrån? Svaret avslutar
## [member _backtracking] i samma stund gränden mynnar ut i korsningen igen.
func _has_unvisited_exit() -> bool:
	var cell: Dictionary = current_cell()
	var links: Dictionary = cell.get("links", {}) as Dictionary
	var blocked: Array = cell.get("blocked", []) as Array
	for slot: Variant in links:
		if blocked.has(String(slot)) or String(links[slot]) == _came_from:
			continue
		if not bool((cells.get(String(links[slot]), {}) as Dictionary).get("visited", false)):
			return true
	return false


func _action_for(dir: int) -> String:
	match posmod(dir - facing, 4):
		0: return ACTION_FORWARD
		1: return ACTION_RIGHT
		3: return ACTION_LEFT
	return ACTION_FORWARD


## Vad som väntar åt ett håll: skylten om det finns en, annars den första
## intressanta rutan inom sikthåll. Knappens underetikett läser den här.
func _action_info(dir: int) -> Dictionary:
	var cell: Dictionary = current_cell()
	var target_key: String = String((cell.get("links", {}) as Dictionary).get(str(dir), ""))
	var target: Dictionary = cells.get(target_key, {}) as Dictionary
	var sign_key: String = String((cell.get("signs", {}) as Dictionary).get(str(dir), ""))
	var notable: Dictionary = _first_notable(position, dir)
	if sign_key == "":
		sign_key = String(notable.get("sign_key", ""))
	return {
		"dir": dir,
		"cell": target_key,
		"kind": String(target.get("kind", "")),
		"node_id": String(target.get("node_id", "")),
		"sign": sign_key,
		"distance": int(notable.get("distance", 0)),
		"leads_to": String(notable.get("kind", "")),
		# Noden vid den första intressanta rutan, inte bara vid grannrutan:
		# fienderna måste stå på plats innan spelaren ser silhuetten på två
		# rutors håll (CORRIDOR_DESIGN §3.1 takt 1).
		"leads_to_node": String(notable.get("node_id", "")),
	}


## Går längs korridoren åt [param dir] tills något händer: en kammare, en
## korsning, en dörr, en fälla eller en gren. Ren lookahead, muterar ingenting.
func _first_notable(from: Vector2i, dir: int) -> Dictionary:
	var at: Vector2i = from
	var heading: int = dir
	for step: int in range(1, 24):
		if not is_open(at, heading):
			return {"distance": step - 1, "kind": "", "sign_key": ""}
		at += DIRS[heading]
		var cell: Dictionary = _cell(at)
		var kind: String = String(cell.get("kind", ""))
		if kind == KIND_CHAMBER:
			return {"distance": step, "kind": kind, "node_id": String(cell.get("node_id", "")),
				"sign_key": SIGN_BOSS if bool(cell.get("boss", false)) else SIGN_FIGHT}
		if kind == KIND_JUNCTION:
			return {"distance": step, "kind": kind, "sign_key": ""}
		if kind == KIND_BOSS_DOOR:
			return {"distance": step, "kind": kind, "sign_key": SIGN_BOSS}
		if kind == KIND_FATE_DOOR:
			return {"distance": step, "kind": kind, "sign_key": SIGN_FATE}
		if kind == KIND_ALCOVE:
			return {"distance": step, "kind": kind, "sign_key": SIGN_UNKNOWN}
		if not (cell.get("trap", {}) as Dictionary).is_empty():
			return {"distance": step, "kind": "trap", "sign_key": ""}
		# Rak korridor: fortsätt genom hörnet, det är fortfarande samma kant.
		var onward: Array[int] = []
		var blocked: Array = cell.get("blocked", []) as Array
		for candidate: int in range(4):
			if candidate == posmod(heading + 2, 4) or blocked.has(str(candidate)):
				continue
			if is_open(at, candidate):
				onward.append(candidate)
		if onward.size() != 1:
			return {"distance": step, "kind": "", "sign_key": ""}
		heading = onward[0]
	return {"distance": 0, "kind": "", "sign_key": ""}


## Tar ett steg. [param action] är [constant ACTION_LEFT], [constant ACTION_FORWARD]
## eller [constant ACTION_RIGHT]. Returnerar false och lägger en
## [constant EVENT_BLOCKED] i loggen när riktningen inte är giltig – ett "nej"
## ska höras som ett mjukt [code]wall_bump[/code], inte som ett straff (§7.2).
func apply(action: String) -> bool:
	var actions: Dictionary = available_actions()
	if not actions.has(action):
		_push({"type": EVENT_BLOCKED, "action": action})
		return false
	var dir: int = int((actions[action] as Dictionary)["dir"])
	_turn_to(dir)
	_came_from = _key(position)
	position += DIRS[dir]
	steps_taken += 1
	var cell: Dictionary = current_cell()
	cell["visited"] = true
	if _backtracking and _has_unvisited_exit():
		_backtracking = false
	_trail.append(_key(position))
	_push({
		"type": EVENT_CELL_ENTERED,
		"cell": _key(position),
		"kind": String(cell.get("kind", "")),
		"steps": steps_taken,
		"silent": bool(cell.get("silent_stretch", false)),
	})
	_enter_cell(cell)
	return true


## Vrider mot en absolut riktning och lägger en [constant EVENT_TURNED] i loggen.
## Halvvarv görs som två högervarv så att kameran aldrig tar kortaste vägen
## genom en vägg.
func _turn_to(dir: int) -> void:
	var delta: int = posmod(dir - facing, 4)
	if delta == 0:
		return
	if delta == 3:
		delta = -1
	var from_deg: int = yaw_degrees()
	yaw_quarters += delta
	facing = posmod(yaw_quarters, 4)
	_push({"type": EVENT_TURNED, "from_deg": from_deg, "to_deg": yaw_degrees(), "quarters": delta})


func _enter_cell(cell: Dictionary) -> void:
	if bool(cell.get("silent_stretch", false)):
		_push({"type": EVENT_SILENT_STRETCH})
	var trap: Dictionary = cell.get("trap", {}) as Dictionary
	if not trap.is_empty() and not bool(cell.get("trap_done", false)):
		pending_trap_key = String(cell["key"])
		_push({"type": EVENT_TRAP_CHOICE, "trap": trap.duplicate(true), "cell": pending_trap_key})
		return
	match String(cell.get("kind", "")):
		KIND_JUNCTION:
			_push({"type": EVENT_REACHED_JUNCTION, "signs": (cell.get("signs", {}) as Dictionary).duplicate()})
		KIND_BOSS_DOOR:
			_push({"type": EVENT_BOSS_DOOR, "cell": String(cell["key"])})
		KIND_FATE_DOOR:
			_push({"type": EVENT_FATE_DOOR, "cell": String(cell["key"])})
			_turn_around()
		KIND_ALCOVE:
			_push({"type": EVENT_TREASURE, "treasure": (cell.get("treasure", {}) as Dictionary).duplicate(true)})
			_turn_around()
		KIND_CHAMBER:
			if bool(cell.get("encounter", false)):
				_push({
					"type": EVENT_ENCOUNTER_REACHED,
					"node_id": String(cell.get("node_id", "")),
					"boss": bool(cell.get("boss", false)),
				})
			if bool(cell.get("boss", false)):
				_push({"type": EVENT_FLOOR_CLEARED, "floor": floor_index})
	_face_the_only_way_on()
	_look_ahead()


## Hörnet vrids i samma stund man kommer fram, inte vid nästa tapp. §2.2 säger
## att hörn kostar noll steg och all sikt; att lämna spelaren stirrande in i en
## vägg tills hen trycker FRAM igen är motsatsen till det, och blir dessutom en
## bild där ingenting går att läsa.
func _face_the_only_way_on() -> void:
	if pending_trap_key != "":
		return
	var exits: Array[int] = _open_dirs()
	if exits.size() == 1 and exits[0] != facing:
		_turn_to(exits[0])


## Återvändsgränden är det enda stället spelaren vänder. Hen backar aldrig:
## kartan vänder figuren på plats och vägen ut är återigen [constant ACTION_FORWARD].
func _turn_around() -> void:
	_backtracking = true
	_came_from = ""
	yaw_quarters += 2
	facing = posmod(yaw_quarters, 4)
	_push({"type": EVENT_TURN_AROUND, "to_deg": yaw_degrees()})


## Vad som syns framåt just nu: silhuetten två rutor bort, skylten vid
## korsningen. Kallas efter varje steg och en gång vid start.
func _look_ahead() -> void:
	var dirs: Array[int] = _open_dirs()
	if dirs.size() != 1:
		return
	var notable: Dictionary = _first_notable(position, dirs[0])
	var distance: int = int(notable.get("distance", 0))
	if distance <= 0 or distance > SIGHT_TILES:
		return
	match String(notable.get("kind", "")):
		KIND_CHAMBER:
			_push({
				"type": EVENT_ENCOUNTER_AHEAD,
				"distance": distance,
				"node_id": String(notable.get("node_id", "")),
			})
		KIND_JUNCTION:
			_push({"type": EVENT_JUNCTION_AHEAD, "distance": distance})
		KIND_BOSS_DOOR:
			_push({"type": EVENT_BOSS_DOOR, "distance": distance, "ahead": true})


# ---------------------------------------------------------------------------
# Fällan
# ---------------------------------------------------------------------------

## Fällan som väntar på svar, eller en tom Dictionary. Båda prislapparna ligger
## i [code]options[/code] och båda är läsbara före tappet (§6 i korridoren).
func pending_trap() -> Dictionary:
	if pending_trap_key == "":
		return {}
	return ((cells[pending_trap_key] as Dictionary).get("trap", {}) as Dictionary).duplicate(true)


## Betalar en av fällans två prislappar. Returnerar det valda alternativet så
## att anroparen kan dra HP eller spräcka en sida – kartan äger ingen regel.
func resolve_trap(option_index: int) -> Dictionary:
	if pending_trap_key == "":
		return {}
	var cell: Dictionary = cells[pending_trap_key] as Dictionary
	var options: Array = (cell.get("trap", {}) as Dictionary).get("options", []) as Array
	if options.is_empty():
		pending_trap_key = ""
		return {}
	var index: int = clampi(option_index, 0, options.size() - 1)
	var chosen: Dictionary = (options[index] as Dictionary).duplicate(true)
	cell["trap_done"] = true
	pending_trap_key = ""
	_push({"type": EVENT_TRAP_RESOLVED, "option": chosen, "index": index})
	_look_ahead()
	return chosen


# ---------------------------------------------------------------------------
# Händelselogg
# ---------------------------------------------------------------------------

func _push(event: Dictionary) -> void:
	_events.append(event)


## Händelserna sedan förra anropet. Tömmer loggen – HUD:en spelar upp dem en
## gång, precis som [EventPlayer] gör med stridens logg.
func events_since_last() -> Array[Dictionary]:
	var result: Array[Dictionary] = _events.duplicate()
	_events.clear()
	return result


func peek_events() -> Array[Dictionary]:
	return _events.duplicate()


# ---------------------------------------------------------------------------
# Serialisering
# ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"floor_index": floor_index,
		"cells": cells.duplicate(true),
		"order": order.duplicate(),
		"x": position.x,
		"y": position.y,
		"yaw_quarters": yaw_quarters,
		"steps_taken": steps_taken,
		"pending_trap_key": pending_trap_key,
		"allow_fate": allow_fate,
		"trail": _trail.duplicate(),
		"came_from": _came_from,
		"backtracking": _backtracking,
	}


static func from_dict(data: Dictionary) -> CorridorMap:
	var map: CorridorMap = CorridorMap.new()
	map.floor_index = int(data.get("floor_index", 1))
	map.position = Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
	map.yaw_quarters = int(data.get("yaw_quarters", 0))
	map.facing = posmod(map.yaw_quarters, 4)
	map.steps_taken = int(data.get("steps_taken", 0))
	map.pending_trap_key = String(data.get("pending_trap_key", ""))
	map.allow_fate = bool(data.get("allow_fate", false))
	map._came_from = String(data.get("came_from", ""))
	map._backtracking = bool(data.get("backtracking", false))
	for key: Variant in data.get("order", []) as Array:
		map.order.append(String(key))
	for key: Variant in data.get("trail", []) as Array:
		map._trail.append(String(key))
	var raw: Dictionary = data.get("cells", {}) as Dictionary
	for key: Variant in raw:
		map.cells[String(key)] = map._clean_cell((raw[key] as Dictionary).duplicate(true), String(key))
	if map.order.is_empty():
		for key: Variant in map.cells:
			map.order.append(String(key))
		map.order.sort()
	return map


## JSON gör om heltal till float och tappar typen på tomma listor. Tvätta
## tillbaka dem, annars går en laddad karta inte att jämföra med en byggd.
func _clean_cell(cell: Dictionary, key: String) -> Dictionary:
	var at: Vector2i = key_to_vec(key)
	cell["key"] = key
	cell["x"] = int(cell.get("x", at.x))
	cell["y"] = int(cell.get("y", at.y))
	cell["kind"] = String(cell.get("kind", KIND_CORRIDOR))
	cell["node_id"] = String(cell.get("node_id", ""))
	cell["encounter"] = bool(cell.get("encounter", false))
	cell["boss"] = bool(cell.get("boss", false))
	cell["torch"] = bool(cell.get("torch", false))
	cell["visited"] = bool(cell.get("visited", false))
	cell["silent_stretch"] = bool(cell.get("silent_stretch", false))
	cell["sign"] = String(cell.get("sign", ""))
	cell["signs"] = (cell.get("signs", {}) as Dictionary).duplicate(true)
	cell["links"] = (cell.get("links", {}) as Dictionary).duplicate(true)
	var blocked: Array = []
	for slot: Variant in cell.get("blocked", []) as Array:
		blocked.append(String(slot))
	cell["blocked"] = blocked
	cell["trap_done"] = bool(cell.get("trap_done", false))
	var trap: Dictionary = (cell.get("trap", {}) as Dictionary).duplicate(true)
	if trap.has("options"):
		var options: Array = []
		for option: Variant in trap["options"] as Array:
			var row: Dictionary = (option as Dictionary).duplicate(true)
			row["amount"] = int(row.get("amount", 0))
			options.append(row)
		trap["options"] = options
	cell["trap"] = trap
	var treasure: Dictionary = (cell.get("treasure", {}) as Dictionary).duplicate(true)
	if treasure.has("weight"):
		treasure["weight"] = int(treasure["weight"])
	if treasure.has("amount"):
		treasure["amount"] = int(treasure["amount"])
	cell["treasure"] = treasure
	return cell
