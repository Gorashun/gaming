extends Node
## Session state: the active character, save slots, difficulty, rested bonus.

const SAVE_DIR := "user://saves"          # real heroes
const TEST_SAVE_DIR := "user://saves_test" # automated runs / tests (never touch real saves)
var save_dir = SAVE_DIR
const BACKUPS := 3            # rolling backups: <id>.bak1 (newest) … <id>.bak3

var character: CharacterData
var world: Node = null    # current GameWorld (authority for gameplay state)
var paused_for_ui = false
## Set by automated runs: disables focus auto-pause and redirects saves + account data to test files.
var testing = false:
	set(v):
		testing = v
		save_dir = TEST_SAVE_DIR if v else SAVE_DIR
		DirAccess.make_dir_recursive_absolute(save_dir)
		Account.use_path("user://account_test.json" if v else "user://account.json")

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(save_dir)

func _process(delta: float) -> void:
	if character and world and not get_tree().paused:
		character.play_seconds += delta

func tier() -> Dictionary:
	return Content.get_rec("difficulties", character.difficulty if character else "twilight")

func new_character(char_name: String, class_id: String, hardcore: bool) -> CharacterData:
	var c = CharacterData.new()
	c.id = "%d_%d" % [Time.get_unix_time_from_system(), randi() % 10000]
	c.name = char_name
	c.class_id = class_id
	c.hardcore = hardcore
	c.created_unix = int(Time.get_unix_time_from_system())
	c.last_played_unix = c.created_unix
	var cls = c.cls()
	# Starting skills & gear
	for s in cls.get("start_skills", []):
		c.skill_ranks[s] = 1
	var bar: Array = cls.get("start_bar", [])
	for i in min(4, bar.size()):
		c.skill_bar[i] = bar[i]
	for base_id in cls.get("start_gear", []):
		var it = Items.generate(1, "common", class_id, base_id, "", "start")
		if not it.is_empty():
			var slot: String = it.slot
			if slot == "ring":
				slot = "ring1"
			c.equipment[slot] = it
	for prof in Content.all("professions"):
		c.professions[prof.id] = {"level": 1, "xp": 0}
	for r in Content.all("recipes"):
		if r.get("known_from_start", false):
			c.recipes_known.append(r.id)
	c.recalc()
	character = c
	save_character()
	return c

func list_saves() -> Array:
	var out = []
	var dir = DirAccess.open(save_dir)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".json"):
			var d = JSON.parse_string(FileAccess.get_file_as_string(save_dir + "/" + f))
			if d is Dictionary:
				out.append(d)
	out.sort_custom(func(a, b): return int(a.get("last_played_unix", 0)) > int(b.get("last_played_unix", 0)))
	return out

## Loads a hero; if the main file is missing/corrupt, falls back to the newest valid backup.
func load_character(id: String) -> CharacterData:
	var d = read_save_dict(id)
	if d.is_empty():
		return null
	character = CharacterData.from_dict(d)
	_apply_rested()
	return character

func _apply_rested() -> void:
	var now = int(Time.get_unix_time_from_system())
	var away_h = float(now - character.last_played_unix) / 3600.0
	if away_h > 0.5:
		var cfg: Dictionary = Content.get_rec("config", "rested")
		var per_hour: float = cfg.get("fraction_of_level_per_hour", 0.05)
		var cap: float = cfg.get("cap_levels", 1.0)
		var gain: float = Progression.xp_to_next(character.level) * min(away_h * per_hour, cap)
		character.rested_xp = min(character.rested_xp + gain, Progression.xp_to_next(character.level) * cap)
	character.last_played_unix = now

func read_save_dict(id: String) -> Dictionary:
	for path in [save_dir + "/" + id + ".json"] + backup_paths(id):
		if not FileAccess.file_exists(path):
			continue
		var d = JSON.parse_string(FileAccess.get_file_as_string(path))
		if d is Dictionary and d.has("class_id"):
			if path.ends_with(".json") == false:
				push_warning("Save %s was unreadable; restored from %s" % [id, path])
			return d
	return {}

func backup_paths(id: String) -> Array:
	var out = []
	for i in range(1, BACKUPS + 1):
		out.append(save_dir + "/%s.bak%d" % [id, i])
	return out

## Atomic save (tmp + rename) with 3 rolling backups of the previous good file.
func save_character() -> void:
	if character == null:
		return
	character.last_played_unix = int(Time.get_unix_time_from_system())
	write_save(character)
	Account.flush()

func write_save(c: CharacterData) -> bool:
	var main = save_dir + "/" + c.id + ".json"
	var tmp = save_dir + "/" + c.id + ".tmp"
	var f = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(c.to_dict()))
	f.close()
	_rotate_backups(c.id)
	DirAccess.rename_absolute(tmp, main)
	return true

func _rotate_backups(id: String) -> void:
	var main = save_dir + "/" + id + ".json"
	if not FileAccess.file_exists(main):
		return
	# Throttle: only roll when the newest backup is older than a minute (autosaves are frequent)
	var b1 = save_dir + "/%s.bak1" % id
	if FileAccess.file_exists(b1) and Time.get_unix_time_from_system() - FileAccess.get_modified_time(b1) < 60 and not testing_backups:
		DirAccess.copy_absolute(main, b1)
		return
	for i in range(BACKUPS, 1, -1):
		var older = save_dir + "/%s.bak%d" % [id, i]
		var newer = save_dir + "/%s.bak%d" % [id, i - 1]
		if FileAccess.file_exists(newer):
			DirAccess.rename_absolute(newer, older)
	DirAccess.copy_absolute(main, b1)

var testing_backups = false   # tests: roll on every save

func delete_character(id: String) -> void:
	DirAccess.remove_absolute(save_dir + "/" + id + ".json")
	for p in backup_paths(id):
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_character()
