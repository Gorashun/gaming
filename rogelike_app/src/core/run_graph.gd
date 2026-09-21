class_name RunGraph
extends RefCounted
## Nod-grafen för en våning. Ren data, inga Node-beroenden, seedad.
##
## Datamodellen är Slay the Spire-kartan (DECISIONS 2026-09-21: "nod-graf som
## datamodell, presenterad som sidescroll-marsch"). Grafen säger VAD som väntar;
## [code]src/game/march/[/code] bestämmer hur det ritas.
##
## Formen på våning 1 är normativ (GAME_DESIGN §1): rum 1–3 är [code]COMBAT[/code]
## och rum 4 är [code]BOSS[/code]. Det seedade är [b]vilken variant som hamnar på
## vilken gren[/b] i förgreningen (§4.4 rum 3 har två specade möten), samt
## grenarnas ordning på skärmen. Resten av formen är fast: en våning som ibland
## saknar boss vore inte en våning.
##
## En nod är en Dictionary så att grafen kan ligga rakt i sparfilens
## [member RunState.meta] utan egen serialiserare:
## [codeblock]
## {id: "r3a", room: 3, room_in_floor: 3, floor: 1, kind: "COMBAT",
##  variant: 0, branch_index: 0, next: ["r4"]}
## [/codeblock]

const KIND_COMBAT: String = "COMBAT"
const KIND_BOSS: String = "BOSS"

## Rum per våning (GAME_DESIGN §1). Rum 4/8/12 är boss.
const ROOMS_PER_FLOOR: int = 4
## Vilket rum i våningen som förgrenar sig. Rum 3 är det enda rummet i §4.4 med
## två specade möten, så det är det enda stället där valet betyder något.
const BRANCH_ROOM_IN_FLOOR: int = 3

var floor_index: int = 1
var start_id: String = ""
## id -> nod-Dictionary.
var nodes: Dictionary = {}


## Bygger grafen för en våning. Samma seed ger byte-identisk graf.
static func generate_floor(p_floor: int, rng: Rng) -> RunGraph:
	var graph: RunGraph = RunGraph.new()
	graph.floor_index = p_floor
	var room_offset: int = (p_floor - 1) * ROOMS_PER_FLOOR

	# Seedad del: vilken mötesvariant som ligger på övre respektive undre grenen.
	var upper_variant: int = rng.next_int(0, 1)
	var lower_variant: int = 1 - upper_variant

	var previous: Array[String] = []
	for room_in_floor: int in range(1, ROOMS_PER_FLOOR + 1):
		var is_boss: bool = room_in_floor == ROOMS_PER_FLOOR
		var ids: Array[String] = []
		if room_in_floor == BRANCH_ROOM_IN_FLOOR:
			ids.append(graph._add_node(p_floor, room_in_floor, room_offset, KIND_COMBAT, upper_variant, 0))
			ids.append(graph._add_node(p_floor, room_in_floor, room_offset, KIND_COMBAT, lower_variant, 1))
		else:
			var kind: String = KIND_BOSS if is_boss else KIND_COMBAT
			ids.append(graph._add_node(p_floor, room_in_floor, room_offset, kind, 0, -1))

		if previous.is_empty():
			graph.start_id = ids[0]
		else:
			for parent_id: String in previous:
				var parent: Dictionary = graph.nodes[parent_id]
				var next_ids: Array = parent["next"] as Array
				for child_id: String in ids:
					next_ids.append(child_id)
		previous = ids

	return graph


func _add_node(p_floor: int, room_in_floor: int, room_offset: int, kind: String, variant: int, branch_index: int) -> String:
	var suffix: String = ""
	if branch_index == 0:
		suffix = "a"
	elif branch_index == 1:
		suffix = "b"
	var id: String = "f%dr%d%s" % [p_floor, room_in_floor, suffix]
	nodes[id] = {
		"id": id,
		"floor": p_floor,
		"room": room_offset + room_in_floor,
		"room_in_floor": room_in_floor,
		"kind": kind,
		"variant": variant,
		"branch_index": branch_index,
		"next": [] as Array,
	}
	return id


func has_node(id: String) -> bool:
	return nodes.has(id)


## Noden med [param id], eller en tom Dictionary om den inte finns.
func node_at(id: String) -> Dictionary:
	return nodes.get(id, {}) as Dictionary


## Id:n som [param id] leder vidare till. Tom när noden är bossen.
func next_ids(id: String) -> Array[String]:
	var result: Array[String] = []
	var node: Dictionary = node_at(id)
	for value: Variant in node.get("next", []) as Array:
		result.append(String(value))
	return result


## Sant när noden har mer än en fortsättning, dvs. spelaren måste välja.
func is_branch(id: String) -> bool:
	return next_ids(id).size() > 1


func is_boss(id: String) -> bool:
	return String(node_at(id).get("kind", "")) == KIND_BOSS


func boss_id() -> String:
	for id: String in nodes:
		if is_boss(id):
			return id
	return ""


## Sant om det finns minst en väg från [param id] till en BOSS-nod.
## Invariant: detta måste gälla för ALLA noder i grafen (test_run_graph).
func reaches_boss(id: String) -> bool:
	var seen: Dictionary = {}
	var queue: Array[String] = [id]
	while not queue.is_empty():
		var current: String = queue.pop_front()
		if seen.has(current) or not has_node(current):
			continue
		seen[current] = true
		if is_boss(current):
			return true
		for next_id: String in next_ids(current):
			queue.append(next_id)
	return false


## Alla noder i grafen, sorterade på rum och sedan grenindex. Stabil ordning för
## test och för marsch-skärmens remsa.
func ordered_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in nodes:
		ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		var na: Dictionary = nodes[a]
		var nb: Dictionary = nodes[b]
		if int(na["room"]) != int(nb["room"]):
			return int(na["room"]) < int(nb["room"])
		return int(na["branch_index"]) < int(nb["branch_index"]))
	return ids


func to_dict() -> Dictionary:
	return {
		"floor_index": floor_index,
		"start_id": start_id,
		"nodes": nodes.duplicate(true),
	}


static func from_dict(data: Dictionary) -> RunGraph:
	var graph: RunGraph = RunGraph.new()
	graph.floor_index = int(data.get("floor_index", 1))
	graph.start_id = String(data.get("start_id", ""))
	var raw: Dictionary = data.get("nodes", {}) as Dictionary
	for key: Variant in raw:
		var node: Dictionary = (raw[key] as Dictionary).duplicate(true)
		# JSON gör om heltal till float; tvätta tillbaka dem.
		node["floor"] = int(node.get("floor", 1))
		node["room"] = int(node.get("room", 1))
		node["room_in_floor"] = int(node.get("room_in_floor", 1))
		node["variant"] = int(node.get("variant", 0))
		node["branch_index"] = int(node.get("branch_index", -1))
		node["id"] = String(node.get("id", key))
		var next_list: Array = []
		for value: Variant in node.get("next", []) as Array:
			next_list.append(String(value))
		node["next"] = next_list
		graph.nodes[String(key)] = node
	return graph
