extends Node
## Session state: the active character, save slots, difficulty, rested bonus.

const SAVE_DIR := "user://saves"

var character: CharacterData
var world: Node = null    # current GameWorld (authority for gameplay state)
var paused_for_ui := false

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func _process(delta: float) -> void:
	if character and world and not get_tree().paused:
		character.play_seconds += delta

func tier() -> Dictionary:
	return Content.get_rec("difficulties", character.difficulty if character else "twilight")

func new_character(char_name: String, class_id: String, hardcore: bool) -> CharacterData:
	var c := CharacterData.new()
	c.id = "%d_%d" % [Time.get_unix_time_from_system(), randi() % 10000]
	c.name = char_name
	c.class_id = class_id
	c.hardcore = hardcore
	c.created_unix = int(Time.get_unix_time_from_system())
	c.last_played_unix = c.created_unix
	var cls := c.cls()
	# Starting skills & gear
	for s in cls.get("start_skills", []):
		c.skill_ranks[s] = 1
	var bar: Array = cls.get("start_bar", [])
	for i in min(4, bar.size()):
		c.skill_bar[i] = bar[i]
	for base_id in cls.get("start_gear", []):
		var it := Items.generate(1, "common", class_id, base_id, "", "start")
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
	var out := []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".json"):
			var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_DIR + "/" + f))
			if d is Dictionary:
				out.append(d)
	out.sort_custom(func(a, b): return int(a.get("last_played_unix", 0)) > int(b.get("last_played_unix", 0)))
	return out

func load_character(id: String) -> CharacterData:
	var path := SAVE_DIR + "/" + id + ".json"
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary):
		return null
	character = CharacterData.from_dict(d)
	_apply_rested()
	return character

func _apply_rested() -> void:
	var now := int(Time.get_unix_time_from_system())
	var away_h := float(now - character.last_played_unix) / 3600.0
	if away_h > 0.5:
		var cfg: Dictionary = Content.get_rec("config", "rested")
		var per_hour: float = cfg.get("fraction_of_level_per_hour", 0.05)
		var cap: float = cfg.get("cap_levels", 1.0)
		var gain: float = Progression.xp_to_next(character.level) * min(away_h * per_hour, cap)
		character.rested_xp = min(character.rested_xp + gain, Progression.xp_to_next(character.level) * cap)
	character.last_played_unix = now

func save_character() -> void:
	if character == null:
		return
	character.last_played_unix = int(Time.get_unix_time_from_system())
	var tmp := SAVE_DIR + "/" + character.id + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(character.to_dict()))
	f.close()
	DirAccess.rename_absolute(tmp, SAVE_DIR + "/" + character.id + ".json")

func delete_character(id: String) -> void:
	DirAccess.remove_absolute(SAVE_DIR + "/" + id + ".json")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_character()
