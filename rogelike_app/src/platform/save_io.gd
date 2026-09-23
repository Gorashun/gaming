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
## Profilen mellan runs ([Meta]). [b]Separat fil med flit:[/b] en run som tar
## slut, och "Reset save" i inställningarna, får inte sudda kritväggen, Pips
## eller det spelaren lärt sig (TOWN_AND_ONBOARDING §A.1).
const META_PATH: String = "user://meta.json"
const TEMP_SUFFIX: String = ".part"

## Går att peka om i tester. Rör aldrig i speldrift.
static var save_path: String = SAVE_PATH
static var meta_path: String = META_PATH


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

	return _write_atomic(save_path, data)


## Skriver via en temporärfil som byter namn sist: antingen finns den gamla
## filen kvar orörd, eller den nya kompletta. Aldrig en halv.
static func _write_atomic(path: String, data: Dictionary) -> bool:
	var temp_path: String = path + TEMP_SUFFIX
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveIO: kunde inte öppna %s (%d)" % [temp_path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data))
	file.close()

	var dir: DirAccess = DirAccess.open(path.get_base_dir())
	if dir == null:
		push_warning("SaveIO: kunde inte öppna katalogen %s" % path.get_base_dir())
		return false
	if dir.file_exists(path.get_file()):
		dir.remove(path.get_file())
	var err: Error = dir.rename(temp_path.get_file(), path.get_file())
	if err != OK:
		push_warning("SaveIO: kunde inte byta namn på %s (%d)" % [temp_path, err])
		return false
	return true


# --- Profilen mellan runs ---------------------------------------------------

## Skriver [Meta] till [constant META_PATH]. Samma atomiska skrivning som
## runnen, och samma kontrakt: en halvskriven fil får aldrig uppstå.
static func save_meta(meta: Meta) -> bool:
	if meta == null:
		return false
	var data: Dictionary = meta.to_dict()
	data["saved_at"] = Time.get_datetime_string_from_system(true)
	return _write_atomic(meta_path, data)


## Läser profilen. En saknad, trasig eller framtida fil ger en [b]färsk[/b]
## profil – aldrig null och aldrig en krasch. Skälet: profilen efterfrågas
## innan titelskärmen ritas, och det finns ingen skärm att visa ett fel på.
static func load_meta() -> Meta:
	if not FileAccess.file_exists(meta_path):
		return Meta.fresh()
	var file: FileAccess = FileAccess.open(meta_path, FileAccess.READ)
	if file == null:
		push_warning("SaveIO: kunde inte läsa %s (%d)" % [meta_path, FileAccess.get_open_error()])
		return Meta.fresh()
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("SaveIO: %s är inte giltig JSON – ny profil" % meta_path)
		return Meta.fresh()
	var data: Dictionary = parsed as Dictionary
	var version: int = int(data.get("version", 0))
	if version <= 0 or version > Meta.SAVE_VERSION:
		push_warning("SaveIO: profilversion %d kan inte läsas (stöder 1..%d)" % [version, Meta.SAVE_VERSION])
		return Meta.fresh()
	return Meta.from_dict(data)


static func has_meta_profile() -> bool:
	return FileAccess.file_exists(meta_path)


## Nollställer profilen. Anropas bara av ett uttryckligt val i inställningarna,
## aldrig av [method clear].
static func clear_meta() -> void:
	_remove(meta_path)
	_remove(meta_path + TEMP_SUFFIX)


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
## version vi inte känner igen (t.ex. en fil från en nyare klient) eller för en
## fil som inte går att översätta.
##
## [b]1 → 2 (M5):[/b] version 1 sparade en marsch mellan noder. Korridoren finns
## inte i den filen, och den går inte att räkna fram: kartan är seedad ur
## [code]rng.fork("corridor")[/code] vid runnens början, och den forken har redan
## rullat vidare när filen skrevs. Att gissa en ruta vore att flytta spelaren
## utan att säga det. Filen kasseras därför, och [GameController] går till staden
## – aldrig en krasch, aldrig en run spelaren inte bad om.
##
## [b]2 → 3 (M5.8):[/b] version 3 lade till källarens fält. Tillägget är rent
## additivt, och en version 2-fil är per definition en riktig run: den stämplas
## med [code]tutorial_room = -1[/code] och spelas vidare. Att kassera den vore
## att ta en run ifrån någon för att vi lagt till ett fält.
static func migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("version", 0))
	if version <= 0 or version > RunState.SAVE_VERSION:
		push_warning("SaveIO: sparfilsversion %d kan inte läsas (stöder 1..%d)" % [version, RunState.SAVE_VERSION])
		return {}
	if version < 2 or not (data.get("meta", {}) as Dictionary).has("corridor"):
		push_warning("SaveIO: sparfil v%d saknar korridorläge – ny run i staden" % version)
		return {}
	if version < 3:
		var meta: Dictionary = (data.get("meta", {}) as Dictionary).duplicate(true)
		meta["tutorial_room"] = -1
		meta["tutorial_loot_pending"] = false
		meta["tutorial_loot_open"] = false
		data = data.duplicate(true)
		data["meta"] = meta
		data["version"] = 3
	if int(data.get("version", 0)) < 4:
		data = migrate_relics_to_gear(data)
	return data


## [b]3 → 4 (M6):[/b] reliker blev gear (DECISIONS 2026-09-23). Varje relik i
## [code]combat.relics[/code] som finns i [constant Content.RELICS] blir föremålet
## med samma id, i den slot [constant Content.RELIC_SLOTS] redan hängde det på.
## Klassreliken ([code]ANVIL_BLESSING[/code]) är ingen gear och ligger kvar.
##
## Runnen får en hjälte med tomt id; [GameController] binder den till rostrets
## aktiva hjälte när filen återupptas. Föremålen sitter på kroppen även i en
## slot som en nivå 1-hjälte inte har låst upp ännu – spelaren hade effekten när
## filen skrevs, och en migrering får inte ta ifrån någon en regel mitt i en run.
## Två reliker i samma slot kan inte förekomma (RELIC_SLOTS är unik), men om
## det ändå händer hamnar den andra i packningen.
static func migrate_relics_to_gear(data: Dictionary) -> Dictionary:
	var out: Dictionary = data.duplicate(true)
	var combat: Dictionary = out.get("combat", {}) as Dictionary
	var kept: Array = []
	var worn: Dictionary = {}
	var pack: Array = []
	for raw: Variant in combat.get("relics", []) as Array:
		var relic: Dictionary = raw as Dictionary
		var item: Item = Content.item_for_relic(String(relic.get("id", "")))
		if item == null:
			kept.append(relic)
			continue
		item.secured = false
		if worn.has(item.slot):
			pack.append(item.to_dict())
		else:
			worn[item.slot] = item.to_dict()
	combat["relics"] = kept
	var gear: Array = []
	for slot: String in Hero.SLOT_UNLOCK_ORDER:
		if worn.has(slot):
			gear.append(worn[slot])
	combat["gear"] = gear
	out["combat"] = combat
	if not out.has("hero") or (out.get("hero", {}) as Dictionary).is_empty():
		var hero: Hero = Hero.new("", "")
		var hero_data: Dictionary = hero.to_dict()
		hero_data["worn"] = worn
		out["hero"] = hero_data
	out["pack"] = pack
	out["version"] = 4
	return out


## Tar bort runnen. [b]Rör inte profilen[/b] – se [method clear_meta].
static func clear() -> void:
	_remove(save_path)
	_remove(save_path + TEMP_SUFFIX)


static func _remove(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var dir: DirAccess = DirAccess.open(path.get_base_dir())
	if dir != null:
		dir.remove(path.get_file())
