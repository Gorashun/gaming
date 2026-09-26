class_name Starmap
extends RefCounted
## Brightness starmap (levels 61–200). Nodes: `starmap` records {id, kind "star", links[], stats{},
## class ("" any), start:bool}. The first star must be a start node (start:true or kind "start");
## every later star must link (either direction) to an owned star. Respec is free (GDD v2 #7).
## Stats are applied in CharacterData.recalc ("star:*" + completed "constellation:*").

static func node(id: String) -> Dictionary:
	return Content.get_rec("starmap", id)

static func is_start(n: Dictionary) -> bool:
	return bool(n.get("start", false)) or str(n.get("kind", "")) == "start"

static func is_star(n: Dictionary) -> bool:
	return not n.is_empty() and str(n.get("kind", "star")) != "constellation"

static func linked(a: Dictionary, b_id: String) -> bool:
	if a.get("links", []).has(b_id):
		return true
	return node(b_id).get("links", []).has(a.get("id", ""))

## "" if allowed, else the reason.
static func can_allocate(ch: CharacterData, node_id: String) -> String:
	var n = node(node_id)
	if not is_star(n):
		return "Unknown star"
	if ch.stars.has(node_id):
		return "Already lit"
	if ch.star_points <= 0:
		return "No star points"
	var c = str(n.get("class", ""))
	if c != "" and c != ch.class_id:
		return "Another class's star"
	if ch.stars.is_empty():
		return "" if is_start(n) else "Begin at a starting star"
	if is_start(n):
		return ""
	for owned in ch.stars:
		if linked(n, str(owned)):
			return ""
	return "Must connect to a lit star"

static func allocate(ch: CharacterData, node_id: String) -> Dictionary:
	var err = can_allocate(ch, node_id)
	if err != "":
		return {"ok": false, "message": err}
	ch.stars.append(node_id)
	ch.star_points -= 1
	ch.recalc()
	return {"ok": true, "message": "%s shines!" % node(node_id).get("name", node_id)}

## Stars that could be lit right now (for UI highlighting).
static func allocatable(ch: CharacterData) -> Array:
	var out = []
	for n in Content.all("starmap"):
		if is_star(n) and can_allocate(ch, n.id) == "":
			out.append(n.id)
	return out

## Free respec: refund every star point.
static func respec(ch: CharacterData) -> int:
	var n = ch.stars.size()
	ch.star_points += n
	ch.stars = []
	ch.recalc()
	return n
