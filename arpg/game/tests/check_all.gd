extends Node
## Loads every script so parse/compile errors surface with autoloads available. Run:
##   godot --headless --path . res://tests/check_all.tscn
func _ready() -> void:
	var bad = 0
	for f in _walk("res://scripts") + _walk("res://tests"):
		var s = load(f)
		if s == null or (s is GDScript and not s.can_instantiate()):
			print("FAIL ", f)
			bad += 1
	print("CHECK DONE, failures: ", bad)
	get_tree().quit(1 if bad > 0 else 0)

func _walk(dir: String) -> Array:
	var out = []
	var d = DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		out += _walk(dir + "/" + sub)
	return out
