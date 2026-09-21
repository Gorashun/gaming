class_name SaveIO
extends RefCounted
## Autosave till [code]user://save.json[/code]. Offline-first, versionerad,
## migrerbar. Enda filsystemsberoendet i spelet.
##
## [b]Kontrakt:[/b] en trasig, halvskriven eller framtida sparfil får ALDRIG
## krascha spelet. [method load_run] returnerar [code]null[/code] och spelet
## startar en ny run. Det är det enda beteendet som är acceptabelt på en telefon
## som kan bli dödad av OS:et mitt i en [method FileAccess.store_string].
##
## Skrivningen går därför via en temporärfil som sedan byter namn: antingen
## finns den gamla sparfilen kvar orörd, eller den nya kompletta. Aldrig en halv.

const SAVE_PATH: String = "user://save.json"
const TEMP_SUFFIX: String = ".part"

## Går att peka om i tester. Rör aldrig i speldrift.
static var save_path: String = SAVE_PATH


## Skriver hela runnen. [param extra] läggs in under [code]meta[/code] och är
## avsett för run-nivådata som inte ligger i [RunState]: aktuell graf-nod,
## rensade rum, största kedja.
static func save_run(run: RunState, extra: Dictionary = {}) -> bool:
	if run == null:
		return false
	var data: Dictionary = run.to_dict()
	if not extra.is_empty():
		var meta: Dictionary = (data.get("meta", {}) as Dictionary).duplicate(true)
		for key: Variant in extra:
			meta[key] = extra[key]
		data["meta"] = meta
	data["saved_at"] = Time.get_datetime_string_from_system(true)

	var temp_path: String = save_path + TEMP_SUFFIX
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveIO: kunde inte öppna %s (%d)" % [temp_path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data))
	file.close()

	var dir: DirAccess = DirAccess.open(save_path.get_base_dir())
	if dir == null:
		push_warning("SaveIO: kunde inte öppna katalogen %s" % save_path.get_base_dir())
		return false
	if dir.file_exists(save_path.get_file()):
		dir.remove(save_path.get_file())
	var err: Error = dir.rename(temp_path.get_file(), save_path.get_file())
	if err != OK:
		push_warning("SaveIO: kunde inte byta namn på %s (%d)" % [temp_path, err])
		return false
	return true


static func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## Läser sparfilen. Returnerar [code]null[/code] när den saknas, är trasig eller
## har en version vi inte kan migrera. Anroparen startar då en ny run.
static func load_run() -> RunState:
	var raw: Dictionary = load_dict()
	if raw.is_empty():
		return null
	return RunState.from_dict(raw)


## Rådatan, migrerad till aktuell [constant RunState.SAVE_VERSION].
## Tom Dictionary = ingen användbar sparfil.
static func load_dict() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_warning("SaveIO: kunde inte läsa %s (%d)" % [save_path, FileAccess.get_open_error()])
		return {}
	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("SaveIO: %s är inte giltig JSON – startar ny run" % save_path)
		return {}

	var data: Dictionary = parsed as Dictionary
	if not data.has("version") or not data.has("combat"):
		push_warning("SaveIO: sparfilen saknar obligatoriska fält – startar ny run")
		return {}
	return migrate(data)


## Migrerar en sparfil till aktuellt format. Returnerar tom Dictionary för en
## version vi inte känner igen (t.ex. en fil från en nyare klient).
##
## M1 har bara version 1, så funktionen är än så länge en vakt. Varje framtida
## höjning av [constant RunState.SAVE_VERSION] lägger till ett steg här.
static func migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("version", 0))
	if version <= 0 or version > RunState.SAVE_VERSION:
		push_warning("SaveIO: sparfilsversion %d kan inte läsas (stöder 1..%d)" % [version, RunState.SAVE_VERSION])
		return {}
	# while version < RunState.SAVE_VERSION: ... version += 1
	return data


static func clear() -> void:
	for path: String in [save_path, save_path + TEMP_SUFFIX]:
		if FileAccess.file_exists(path):
			var dir: DirAccess = DirAccess.open(path.get_base_dir())
			if dir != null:
				dir.remove(path.get_file())
