extends Node
## Player-facing options (accessibility first). Persisted to user://settings.json.

const PATH := "user://settings.json"

var data = {
	"music_volume": 0.7,
	"sfx_volume": 0.9,
	"screen_shake": 1.0,
	"damage_numbers": true,
	"text_scale": 1.0,
	"colorblind_mode": false,
	"high_contrast": false,
	"auto_attack": false,
	"loot_filter": 0,          # 0 all, 1 hide common, 2 hide magic-, 3 rare+ only
	"auto_salvage_below": -1,  # rarity index; -1 off
	"show_fps": false,
}

func _ready() -> void:
	load_settings()

func get_value(key: String, default = null):
	return data.get(key, default)

func set_value(key: String, value) -> void:
	data[key] = value
	save_settings()

func load_settings() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		for k in parsed:
			data[k] = parsed[k]

func save_settings() -> void:
	var f = FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
