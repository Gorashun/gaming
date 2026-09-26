class_name Account
extends RefCounted
## Account-wide data shared by every hero on this device: user://account.json
## {"codex": {...}, "counters": {...}, "deeds": {deed_id: tier}}. Offline only (welfare §6).
## Writes are batched: mark_dirty() + flush() (flushed on every character save).

static var path := "user://account.json"
static var _data = null
static var _dirty = false

static func data() -> Dictionary:
	if _data == null:
		_data = {}
		if FileAccess.file_exists(path):
			var d = JSON.parse_string(FileAccess.get_file_as_string(path))
			if d is Dictionary:
				_data = d
		for k in ["codex", "counters", "deeds"]:
			if not (_data.get(k) is Dictionary):
				_data[k] = {}
	return _data

static func mark_dirty() -> void:
	_dirty = true

static func flush(force := false) -> void:
	if not _dirty and not force:
		return
	_dirty = false
	var tmp = path + ".tmp"
	var f = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data()))
	f.close()
	DirAccess.rename_absolute(tmp, path)

## Test hook: use another file and drop the cache.
static func use_path(p: String) -> void:
	path = p
	_data = null
	_dirty = false

static func add_counter(key: String, n := 1) -> int:
	var c: Dictionary = data().counters
	c[key] = int(c.get(key, 0)) + n
	mark_dirty()
	return int(c[key])

static func counter(key: String) -> int:
	return int(data().counters.get(key, 0))
