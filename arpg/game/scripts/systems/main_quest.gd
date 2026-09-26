class_name MainQuest
extends RefCounted
## Main questline (GDD v2.5). Data:
##   `main_quest` chapters {id, act, order, name, objectives:[{type, target, count, text, zone,
##     dialogue}], dialogue_start, dialogue_end, unlocks{zones[], acts[]}, requires_zones_locked(bool),
##     reward{gold, xp, skill_points, item_rarity, pet, mount}}
##   Objective types: reach_zone (target zone), kill (monster id | "family:x" | "any"), collect
##     (material id), escort (world-event id or "any"), talk (npc id), solve (object id, placed in
##     objective.zone), boss (monster id | "any").
##   `main_quest_text` {id, lines:[{speaker, text}]} — dialogue shown via Events.story_dialogue.
## Gating: a zone listed in any chapter's unlocks.zones stays locked until that chapter is done.
## Character: main_quest {chapter, objective, progress, done:[]}.

static func chapters() -> Array:
	var list = Content.all("main_quest")
	list.sort_custom(func(a, b): return int(a.get("order", 0)) < int(b.get("order", 0)))
	return list

static func _state(ch: CharacterData) -> Dictionary:
	if not ch.main_quest.has("done"):
		ch.main_quest["done"] = []
	return ch.main_quest

## Starts the first unfinished chapter if none is active. Returns the chapter id ("" = all done).
static func ensure_started(ch: CharacterData) -> String:
	var st = _state(ch)
	var cur = str(st.get("chapter", ""))
	if cur != "" and not Content.get_rec("main_quest", cur).is_empty() and not st.done.has(cur):
		return cur
	for c in chapters():
		if not st.done.has(c.id):
			st.chapter = c.id
			st.objective = 0
			st.progress = 0
			dialogue(str(c.get("dialogue_start", "")))
			_emit(ch)
			return c.id
	st.chapter = ""
	return ""

static func current(ch: CharacterData) -> Dictionary:
	return Content.get_rec("main_quest", str(_state(ch).get("chapter", "")))

static func current_objective(ch: CharacterData) -> Dictionary:
	var c = current(ch)
	var objs: Array = c.get("objectives", [])
	var i = int(_state(ch).get("objective", 0))
	return objs[i] if i >= 0 and i < objs.size() else {}

## Tracker for the HUD: {chapter, name, index, total, objective{type, target, text, progress, count}}
static func tracker(ch: CharacterData) -> Dictionary:
	var c = current(ch)
	if c.is_empty():
		return {}
	var o = current_objective(ch)
	return {"chapter": c.id, "name": c.get("name", ""), "act": c.get("act", ""), "index": int(_state(ch).get("objective", 0)),
		"total": c.get("objectives", []).size(),
		"objective": {"type": o.get("type", ""), "target": o.get("target", ""), "text": o.get("text", ""),
			"zone": o.get("zone", ""), "progress": int(_state(ch).get("progress", 0)), "count": max(1, int(o.get("count", 1)))}}

static func dialogue(text_id: String) -> void:
	if text_id == "":
		return
	var t = Content.get_rec("main_quest_text", text_id)
	var lines: Array = t.get("lines", [])
	if lines.is_empty() and t.has("text"):
		lines = [{"speaker": t.get("speaker", ""), "text": t.text}]
	if not lines.is_empty():
		Events.story_dialogue.emit(lines)

static func _matches(o: Dictionary, type: String, target: String, extra: Dictionary) -> bool:
	if str(o.get("type", "")) != type:
		return false
	var t = str(o.get("target", "any"))
	if t == "" or t == "any" or t == target:
		return true
	return t.begins_with("family:") and t.substr(7) == str(extra.get("family", ""))

## Feed gameplay events (same vocabulary as Quests plus reach_zone/escort/solve).
static func notify(ch: CharacterData, type: String, target: String, amount := 1, extra := {}) -> void:
	if ch == null or Content.all("main_quest").is_empty():
		return
	if ensure_started(ch) == "":
		return
	var o = current_objective(ch)
	if o.is_empty() or not _matches(o, type, target, extra):
		return
	var st = _state(ch)
	var n = max(1, int(o.get("count", 1)))
	st.progress = min(n, int(st.get("progress", 0)) + amount)
	_emit(ch)
	if int(st.progress) >= n:
		_advance(ch)

static func _emit(ch: CharacterData) -> void:
	var st = _state(ch)
	var o = current_objective(ch)
	Events.main_quest_updated.emit(str(st.get("chapter", "")), int(st.get("objective", 0)), int(st.get("progress", 0)), max(1, int(o.get("count", 1))))

static func _advance(ch: CharacterData) -> void:
	var st = _state(ch)
	var c = current(ch)
	dialogue(str(current_objective(ch).get("dialogue", "")))
	st.objective = int(st.get("objective", 0)) + 1
	st.progress = 0
	if int(st.objective) >= c.get("objectives", []).size():
		complete_chapter(ch, c.id)
	else:
		_emit(ch)

static func complete_chapter(ch: CharacterData, chapter_id: String) -> void:
	var st = _state(ch)
	var c = Content.get_rec("main_quest", chapter_id)
	if not st.done.has(chapter_id):
		st.done.append(chapter_id)
	var r: Dictionary = c.get("reward", {})
	if r.has("gold"):
		ch.gold += int(r.gold)
	if r.has("xp"):
		ch.add_xp(int(r.xp))
	if r.has("skill_points"):
		ch.skill_points += int(r.skill_points)
	if r.has("item_rarity"):
		var it = Items.generate(ch.level, str(r.item_rarity), ch.class_id)
		if not it.is_empty() and not ch.add_item(it):
			ch.stash.append(it)
	if str(r.get("pet", "")) != "":
		Pets.grant_pet(ch, str(r.pet))
	if str(r.get("mount", "")) != "":
		Mounts.grant_mount(ch, str(r.mount))
	dialogue(str(c.get("dialogue_end", "")))
	ch.track("chapters_done")
	Events.main_quest_chapter_completed.emit(chapter_id)
	Events.toast.emit("Chapter complete: %s" % c.get("name", chapter_id), Color(1, 0.85, 0.4))
	st.chapter = ""
	ensure_started(ch)

## "" if the zone may be entered, else a reason (zone gated by an unfinished chapter).
static func zone_locked(ch: CharacterData, zone_id: String) -> String:
	for c in chapters():
		if c.get("unlocks", {}).get("zones", []).has(zone_id) and not _state(ch).done.has(c.id):
			return "Continue the story to open this path (%s)" % c.get("name", "")
	return ""

static func act_locked(ch: CharacterData, act_id: String) -> String:
	for c in chapters():
		if c.get("unlocks", {}).get("acts", []).has(act_id) and not _state(ch).done.has(c.id):
			return "Continue the story to reach this act"
	return ""

## Solve objectives: the zone to place an interactable object in, else "".
static func solve_object_for_zone(ch: CharacterData, zone_id: String) -> Dictionary:
	var o = current_objective(ch)
	if str(o.get("type", "")) == "solve" and str(o.get("zone", "")) == zone_id:
		return o
	return {}
