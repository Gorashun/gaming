class_name Deeds
extends RefCounted
## Deeds (achievements, GDD v2.5): generic counters → tiered deeds → rewards that are titles,
## cosmetics, small permanent stats (source "deeds"), skill points or gold. Never sold, never timed.
##
## Counters: per hero `ch.counters` (= stats_tracking, saved) and account-wide (Account.counters).
## Keys used by the game (unknown keys are fine — any counter a deed names works):
##   kills, kills:family:<id>, kills:monster:<id>, elites, bosses, crafts, upgrades, salvages,
##   gold_earned, zones_visited, secrets, uniques_found, legendaries_found, pets_owned, mounts_owned,
##   hushfalls, deaths, tiers_cleared, distance (metres), skills_cast, quests_done, chapters_done
## Data `deeds`: {id, name, desc, counter, account(bool: use the account counter), hidden,
##   tiers:[{goal, reward{title, cosmetic{slot: value}, skill_points, gold, stats{}}}]}
## Character: deeds{deed_id: tiers reached}, titles[], title, cosmetics_owned{slot: [values]},
##   cosmetics{cape_tint, aura, name_frame, pet_hat, mount_tint}.

const COSMETIC_SLOTS := ["cape_tint", "aura", "name_frame", "pet_hat", "mount_tint"]

static var _index = null   # counter -> [deed recs]

static func _deeds_for(counter: String) -> Array:
	if _index == null:
		_index = {}
		for d in Content.all("deeds"):
			var c = str(d.get("counter", ""))
			if not _index.has(c):
				_index[c] = []
			_index[c].append(d)
	return _index.get(counter, [])

## Call after Content.reload().
static func reset_index() -> void:
	_index = null

## Increment a counter (hero + account) and complete any deed tiers it reaches.
static func add(ch: CharacterData, key: String, n := 1) -> void:
	if ch == null or n == 0:
		return
	ch.stats_tracking[key] = int(ch.stats_tracking.get(key, 0)) + n
	Account.add_counter(key, n)
	check(ch, key)

static func value(ch: CharacterData, d: Dictionary) -> int:
	var key = str(d.get("counter", ""))
	return Account.counter(key) if d.get("account", false) else int(ch.stats_tracking.get(key, 0))

## Grants every newly reached tier of deeds on this counter.
static func check(ch: CharacterData, key: String) -> void:
	for d in _deeds_for(key):
		var reached = int(ch.deeds.get(d.id, 0))
		var tiers: Array = d.get("tiers", [])
		var v = value(ch, d)
		while reached < tiers.size() and v >= int(tiers[reached].get("goal", 1)):
			reached += 1
			ch.deeds[d.id] = reached
			_grant(ch, d, reached, tiers[reached - 1].get("reward", {}))

static func _grant(ch: CharacterData, d: Dictionary, tier: int, r: Dictionary) -> void:
	if r.has("title") and not ch.titles.has(str(r.title)):
		ch.titles.append(str(r.title))
	for slot in r.get("cosmetic", {}):
		var list: Array = ch.cosmetics_owned.get(slot, [])
		if not list.has(r.cosmetic[slot]):
			list.append(r.cosmetic[slot])
		ch.cosmetics_owned[slot] = list
	if r.has("skill_points"):
		ch.skill_points += int(r.skill_points)
	if r.has("gold"):
		ch.gold += int(r.gold)
	if r.has("stats"):
		ch.recalc()
	Events.deed_tier_completed.emit(str(d.id), tier)
	Events.toast.emit("Deed: %s %s" % [d.get("name", d.id), "I".repeat(min(tier, 3)) if tier <= 3 else str(tier)], Color(0.75, 0.9, 1.0))

## Permanent stats from all reached tiers (stat source "deeds").
static func stat_bonuses(ch: CharacterData) -> Dictionary:
	var out = {}
	for id in ch.deeds:
		var d = Content.get_rec("deeds", id)
		var tiers: Array = d.get("tiers", [])
		for i in min(int(ch.deeds[id]), tiers.size()):
			var st: Dictionary = tiers[i].get("reward", {}).get("stats", {})
			for k in st:
				out[k] = float(out.get(k, 0.0)) + float(st[k])
	return out

## UI list: [{deed, tier, tiers, value, next_goal, done}]
static func list(ch: CharacterData, include_hidden := false) -> Array:
	var out = []
	for d in Content.all("deeds"):
		var t = int(ch.deeds.get(d.id, 0))
		var tiers: Array = d.get("tiers", [])
		if d.get("hidden", false) and not include_hidden and t == 0:
			continue
		out.append({"deed": d, "tier": t, "tiers": tiers.size(), "value": value(ch, d),
			"next_goal": int(tiers[t].get("goal", 0)) if t < tiers.size() else 0, "done": t >= tiers.size()})
	return out

static func set_title(ch: CharacterData, title: String) -> bool:
	if title != "" and not ch.titles.has(title):
		return false
	ch.title = title
	return true

## Equip a cosmetic ("" clears the slot). Only owned values.
static func set_cosmetic(ch: CharacterData, slot: String, value) -> bool:
	if not COSMETIC_SLOTS.has(slot) and not ch.cosmetics_owned.has(slot):
		return false
	if value == null or str(value) == "":
		ch.cosmetics.erase(slot)
		return true
	if not ch.cosmetics_owned.get(slot, []).has(value):
		return false
	ch.cosmetics[slot] = value
	return true
