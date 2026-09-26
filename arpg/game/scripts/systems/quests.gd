class_name Quests
extends RefCounted
## Side quests from the `quests` table: {id, name, giver (npc id), act, type ("kill"|"collect"|
## "explore"|"boss"|"talk"), target, count, reward{gold, xp, item_rarity, pet, mount, recipe,
## skill_points, materials{}}, text_offer, text_done, repeatable, requires (quest id), min_level}.
## Targets: kill → monster id, "family:<id>" or "any"; collect → material id; explore → zone id;
## boss → monster id (or "any"); talk → npc id. Character: quests{active:{id:{progress}}, done:[]}.
## Progress is fed by GameWorld/NPC calls to notify(); rewards are granted on turn_in().

static func rec(id: String) -> Dictionary:
	return Content.get_rec("quests", id)

static func state(ch: CharacterData, id: String) -> String:
	## "unknown" | "locked" | "available" | "active" | "ready" | "done"
	var q = rec(id)
	if q.is_empty():
		return "unknown"
	if ch.quests.active.has(id):
		return "ready" if progress(ch, id) >= count(q) else "active"
	if ch.quests.done.has(id) and not q.get("repeatable", false):
		return "done"
	if ch.level < int(q.get("min_level", 1)):
		return "locked"
	var req = str(q.get("requires", ""))
	if req != "" and not ch.quests.done.has(req):
		return "locked"
	return "available"

static func count(q: Dictionary) -> int:
	return max(1, int(q.get("count", 1)))

static func progress(ch: CharacterData, id: String) -> int:
	var a = ch.quests.active.get(id)
	return int(a.get("progress", 0)) if a is Dictionary else 0

## Quests an NPC can offer right now.
static func available_for(ch: CharacterData, npc_id: String) -> Array:
	var out = []
	for q in Content.all("quests"):
		if str(q.get("giver", "")) == npc_id and state(ch, q.id) == "available":
			out.append(q)
	return out

## Active quests whose giver is this NPC and that are complete.
static func ready_for(ch: CharacterData, npc_id: String) -> Array:
	var out = []
	for id in ch.quests.active:
		var q = rec(id)
		if str(q.get("giver", "")) == npc_id and state(ch, id) == "ready":
			out.append(q)
	return out

static func active_list(ch: CharacterData) -> Array:
	var out = []
	for id in ch.quests.active:
		var q = rec(id)
		if not q.is_empty():
			out.append({"quest": q, "progress": progress(ch, id), "count": count(q), "state": state(ch, id)})
	return out

static func accept(ch: CharacterData, id: String) -> bool:
	if state(ch, id) != "available":
		return false
	ch.quests.active[id] = {"progress": 0}
	Events.quest_accepted.emit(id)
	var q = rec(id)
	# Explore/collect targets already satisfied count immediately where it makes sense
	if str(q.get("type", "")) == "explore" and ch.waypoints.has(str(q.get("target", ""))) and q.get("count_visited", false):
		notify(ch, "explore", str(q.target))
	return true

static func abandon(ch: CharacterData, id: String) -> bool:
	return ch.quests.active.erase(id)

static func _matches(q: Dictionary, type: String, target: String, extra: Dictionary) -> bool:
	if str(q.get("type", "")) != type:
		return false
	var t = str(q.get("target", "any"))
	if t == "" or t == "any" or t == target:
		return true
	if t.begins_with("family:") and t.substr(7) == str(extra.get("family", "")):
		return true
	if t.begins_with("kind:") and t.substr(5) == str(extra.get("kind", "")):
		return true
	return false

## Feed a gameplay event: type kill|collect|explore|boss|talk, target id, amount.
## extra: {family, kind} for kill targets like "family:rattlebones" / "kind:rare".
static func notify(ch: CharacterData, type: String, target: String, amount := 1, extra := {}) -> void:
	if ch == null or ch.quests.active.is_empty():
		return
	for id in ch.quests.active.keys():
		var q = rec(id)
		if q.is_empty() or not _matches(q, type, target, extra):
			continue
		var before = progress(ch, id)
		var n = count(q)
		if before >= n:
			continue
		var after = min(n, before + amount)
		ch.quests.active[id].progress = after
		Events.quest_updated.emit(id, after, n)
		if after >= n:
			Events.quest_ready.emit(id)
			Events.toast.emit("Quest complete: %s" % q.get("name", id), Color(1, 0.85, 0.4))
			if str(q.get("giver", "")) == "":
				turn_in(ch, id)

## Grants rewards. world (optional) is used for XP so level-ups get their usual juice.
static func turn_in(ch: CharacterData, id: String, world = null) -> Dictionary:
	if state(ch, id) != "ready":
		return {"ok": false, "message": "Not finished yet"}
	var q = rec(id)
	var r: Dictionary = q.get("reward", {})
	var got = {"gold": 0, "xp": 0, "items": [], "pet": "", "mount": "", "recipe": "", "skill_points": 0, "materials": {}}
	ch.quests.active.erase(id)
	if not ch.quests.done.has(id):
		ch.quests.done.append(id)
	if r.has("gold"):
		got.gold = int(r.gold)
		ch.gold += got.gold
		Events.gold_changed.emit(ch.gold)
	if r.has("xp"):
		got.xp = int(r.xp)
		if world and is_instance_valid(world) and world.has_method("grant_xp"):
			world.grant_xp(got.xp)
		else:
			ch.add_xp(got.xp)
	if r.has("item_rarity"):
		var it = Items.generate(ch.level, str(r.item_rarity), ch.class_id, str(r.get("item_base", "")), str(r.get("item_slot", "")), "loot")
		if not it.is_empty():
			got.items.append(it)
			if not ch.add_item(it):
				ch.stash.append(it)
	for m in r.get("materials", {}):
		ch.add_material(m, int(r.materials[m]))
		got.materials[m] = int(r.materials[m])
	if str(r.get("pet", "")) != "":
		if Pets.grant_pet(ch, str(r.pet)):
			got.pet = str(r.pet)
	if str(r.get("mount", "")) != "":
		if Mounts.grant_mount(ch, str(r.mount)):
			got.mount = str(r.mount)
	if str(r.get("recipe", "")) != "" and not ch.recipes_known.has(str(r.recipe)):
		ch.recipes_known.append(str(r.recipe))
		got.recipe = str(r.recipe)
	if r.has("skill_points"):
		got.skill_points = int(r.skill_points)
		ch.skill_points += got.skill_points
	ch.recalc()
	Events.quest_completed.emit(id)
	Events.inventory_changed.emit()
	return {"ok": true, "message": str(q.get("text_done", "Thank you, Wickbearer!")), "rewards": got}
