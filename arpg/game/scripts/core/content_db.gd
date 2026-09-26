extends Node
## Loads and merges content packs. A pack is a folder with pack.json:
##   { "id", "name", "version", "load_order", "requires": [], "tables": { "<table>": "<file.json>" } }
## Each table file is an Array of records with a unique "id". Later packs (higher load_order)
## can add records or override records by id ("_merge": true merges fields instead of replacing).
## Packs are discovered in res://content/* and user://dlc/*.pck (DLC/expansions).

signal content_loaded

var tables: Dictionary = {}   # table -> { id -> record }
var order: Dictionary = {}    # table -> [ids] in load order
var packs: Array = []

func _ready() -> void:
	reload()

func reload() -> void:
	tables.clear()
	order.clear()
	packs.clear()
	_mount_dlc_pcks()
	var manifests = []
	for dir_path in ["res://content"]:
		var dir = DirAccess.open(dir_path)
		if dir == null:
			continue
		for sub in dir.get_directories():
			var p = dir_path + "/" + sub + "/pack.json"
			if FileAccess.file_exists(p):
				var m = JSON.parse_string(FileAccess.get_file_as_string(p))
				if m is Dictionary:
					m["_path"] = dir_path + "/" + sub
					manifests.append(m)
	manifests.sort_custom(func(a, b): return int(a.get("load_order", 0)) < int(b.get("load_order", 0)))
	for m in manifests:
		if not _requirements_met(m, manifests):
			push_warning("Content pack %s skipped: missing requirement" % m.get("id"))
			continue
		_load_pack(m)
	content_loaded.emit()

func _mount_dlc_pcks() -> void:
	var dir = DirAccess.open("user://dlc")
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".pck") or f.ends_with(".zip"):
			ProjectSettings.load_resource_pack("user://dlc/" + f)

func _requirements_met(m: Dictionary, all: Array) -> bool:
	for req in m.get("requires", []):
		var found = false
		for o in all:
			if o.get("id") == req:
				found = true
		if not found:
			return false
	return true

func _load_pack(m: Dictionary) -> void:
	packs.append(m)
	var t: Dictionary = m.get("tables", {})
	for table in t:
		var files = t[table]
		if files is String:
			files = [files]
		for file in files:
			var path: String = m["_path"] + "/" + file
			if not FileAccess.file_exists(path):
				push_error("Content file missing: " + path)
				continue
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed == null:
				push_error("Content JSON parse error: " + path)
				continue
			var records: Array = parsed if parsed is Array else [parsed]
			for r in records:
				_add_record(table, r, m.get("id", "?"))

func _add_record(table: String, r: Dictionary, pack_id: String) -> void:
	if not tables.has(table):
		tables[table] = {}
		order[table] = []
	var id: String = str(r.get("id", ""))
	if id == "":
		push_error("Record without id in table %s (pack %s)" % [table, pack_id])
		return
	r["_pack"] = pack_id
	if tables[table].has(id):
		if r.get("_merge", false):
			var existing: Dictionary = tables[table][id]
			for k in r:
				existing[k] = r[k]
			return
	else:
		order[table].append(id)
	tables[table][id] = r

func get_rec(table: String, id: String) -> Dictionary:
	return tables.get(table, {}).get(id, {})

func has_rec(table: String, id: String) -> bool:
	return tables.get(table, {}).has(id)

func all(table: String) -> Array:
	var out = []
	for id in order.get(table, []):
		out.append(tables[table][id])
	return out

func where(table: String, key: String, value) -> Array:
	return all(table).filter(func(r): return r.get(key) == value)

## Balance constants live in the "config" table as { "id": "<name>", ... }.
func cfg(id: String, key: String, default = null):
	return get_rec("config", id).get(key, default)
