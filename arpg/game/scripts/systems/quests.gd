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
	if q.get("bounty", false) and bounty_bank(ch) <= 0:
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

# ------------------------------------------------------------------ bounties (research #17)
## Bounty board: a bank of up to bank_max bounties; one refills per refill_active_play_minutes of
## ACTIVE play (play_seconds — absence never costs anything, nothing expires). config/bounties.
static func _bcfg() -> Dictionary:
	return Content.get_rec("config", "bounties")

static func bounty_bank(ch: CharacterData) -> int:
	var c = _bcfg()
	var mx = int(c.get("bank_max", 3))
	var period = float(c.get("refill_active_play_minutes", 30)) * 60.0
	if not ch.quests.has("bounty_bank"):
		ch.quests["bounty_bank"] = mx
		ch.quests["bounty_clock"] = ch.play_seconds
	var bank = int(ch.quests.bounty_bank)
	var clock = float(ch.quests.get("bounty_clock", ch.play_seconds))
	if bank >= mx:
		ch.quests["bounty_clock"] = ch.play_seconds   # full bank: the timer does not run ahead
		return mx
	var n = int((ch.play_seconds - clock) / period)
	if n > 0:
		bank = min(mx, bank + n)
		ch.quests["bounty_bank"] = bank
		ch.quests["bounty_clock"] = clock + n * period
	return bank

## {bank, max, next_in_s} for the board UI.
static func bounty_status(ch: CharacterData) -> Dictionary:
	var c = _bcfg()
	var bank = bounty_bank(ch)
	var period = float(c.get("refill_active_play_minutes", 30)) * 60.0
	var next_in = 0.0 if bank >= int(c.get("bank_max", 3)) else max(0.0, float(ch.quests.bounty_clock) + period - ch.play_seconds)
	return {"bank": bank, "max": int(c.get("bank_max", 3)), "next_in_s": next_in}

## Bounties offered on a town board (act of the town), as long as the bank is not empty.
static func bounties_for(ch: CharacterData, act_id := "") -> Array:
	return Content.all("quests").filter(func(q): return q.get("bounty", false) and (act_id == "" or str(q.get("act", "")) == act_id) and state(ch, q.id) == "available")

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
	if rec(id).get("bounty", false):
		ch.quests["bounty_bank"] = bounty_bank(ch) - 1
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
	if r.has("xp") or r.has("xp_levels"):
		got.xp = int(r.get("xp", 0)) + int(round(float(r.get("xp_levels", 0.0)) * Progression.xp_to_next(ch.level)))
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
	var mats: Dictionary = r.get("materials", {}).duplicate()
	var rm = r.get("material")
	if rm is Dictionary:
		if rm.has("id"):
			mats[str(rm.id)] = int(mats.get(str(rm.id), 0)) + int(rm.get("count", 1))
		else:
			for k in rm:
				mats[k] = int(mats.get(k, 0)) + int(rm[k])
	elif rm is String:
		mats[rm] = int(mats.get(rm, 0)) + 1
	for m in mats:
		ch.add_material(m, int(mats[m]))
		got.materials[m] = int(mats[m])
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
	ch.track("quests_done")
	ch.track("side_quests_completed")
	if q.get("bounty", false):
		ch.track("bounties_completed")
	ch.recalc()
	Events.quest_completed.emit(id)
	Events.inventory_changed.emit()
	return {"ok": true, "message": str(q.get("text_done", "Thank you, Wickbearer!")), "rewards": got}
