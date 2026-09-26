class_name Codex
extends RefCounted
## Codex of Light (research player_wants #1): account-wide record of legendary powers and uniques
## found, shared by every hero. Stored in user://account.json {"codex": {entry_id: {...}}}.
## A better roll of an already-known entry upgrades it. Entry ids: "power:<id>", "unique:<id>", "named:<id>".

static var path := "user://account.json"
static var _data = null

static func _load() -> Dictionary:
	if _data == null:
		_data = {}
		if FileAccess.file_exists(path):
			var d = JSON.parse_string(FileAccess.get_file_as_string(path))
			if d is Dictionary:
				_data = d
		if not (_data.get("codex") is Dictionary):
			_data["codex"] = {}
	return _data

static func _save() -> void:
	var tmp = path + ".tmp"
	var f = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_load()))
	f.close()
	DirAccess.rename_absolute(tmp, path)

## Test hook: point the codex at another file and drop the cache.
static func use_path(p: String) -> void:
	path = p
	_data = null

static func _quality(item: Dictionary) -> float:
	var q = 0.0
	for a in item.get("affixes", []):
		q += float(a.get("value", 0.0))
	return q

## Record a found item. Returns true when a new entry was learned or an entry improved.
static func record(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	var ids = []
	if str(item.get("power", "")) != "":
		ids.append("power:" + str(item.power))
	if str(item.get("unique", "")) != "":
		ids.append("unique:" + str(item.unique))
	if str(item.get("named", "")) != "":
		ids.append("named:" + str(item.named))
	if ids.is_empty():
		return false
	var codex: Dictionary = _load().codex
	var changed = false
	var q = _quality(item)
	for id in ids:
		var e = codex.get(id)
		if e == null:
			codex[id] = {"first_found_unix": int(Time.get_unix_time_from_system()), "item_name": item.get("name", ""),
				"rarity": item.get("rarity", ""), "best": q, "ilvl": int(item.get("ilvl", 1)), "count": 1}
			changed = true
			Events.codex_updated.emit(id)
		else:
			e.count = int(e.get("count", 0)) + 1
			if q > float(e.get("best", 0.0)) or int(item.get("ilvl", 1)) > int(e.get("ilvl", 1)):
				e.best = max(q, float(e.get("best", 0.0)))
				e.ilvl = max(int(item.get("ilvl", 1)), int(e.get("ilvl", 1)))
				e.item_name = item.get("name", "")
				changed = true
				Events.codex_updated.emit(id)
	_save()
	return changed

static func has(entry_id: String) -> bool:
	return _load().codex.has(entry_id)

## [{id, kind, ref (power/unique id), name, desc, ...entry}] sorted by id.
static func list() -> Array:
	var out = []
	var codex: Dictionary = _load().codex
	var keys = codex.keys()
	keys.sort()
	for id in keys:
		var e: Dictionary = codex[id].duplicate()
		var parts = str(id).split(":", true, 1)
		e.id = id
		e.kind = parts[0]
		e.ref = parts[1] if parts.size() > 1 else ""
		var table = {"power": "powers", "unique": "uniques", "named": "named"}.get(e.kind, "")
		var r = Content.get_rec(table, e.ref) if table != "" else {}
		e.name = r.get("name", e.ref)
		e.desc = r.get("desc", r.get("flavor", ""))
		out.append(e)
	return out
