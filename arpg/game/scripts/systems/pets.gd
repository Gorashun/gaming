class_name Pets
extends RefCounted
## Pets (GDD v2.1 #21): collectible companions, levels 1–30 from player kills. Non-combat unless the
## class has `pet_combat: true` (Stitcher). Rules only — the follower node is actors/pet.gd.
## Data: `pets` {id, name, model, scale, tint, rarity, source, drop_chance, max_level,
##   bonuses_per_level{magic_find, gold_find, pickup_radius, material_find, xp_pct, ...}, perk
##   ("fetch"|"dig"|"glow"|"lucky"), perk_params{}, desc}; config/pets {xp_base, xp_growth,
##   xp_per_kill, ferry_cooldown_s, ferry_duration_s, ferry_max_rank, treat_xp}.
## Character: pets_owned{id: {level, xp}}, active_pet, pet_state{dig_kills, ferry_ready_at, ferry_back_at}.

## Keyword → CreatureFactory kind for pets whose data has no `creature` and only a placeholder model.
const PET_KEYWORDS := [["lantern", "lantern_moth"], ["glowworm", "wisp"], ["moth", "moth"], ["owl", "owl"], ["hoot", "owl"],
	["bat", "bat"], ["frog", "frog"], ["spider", "spider"], ["ghost", "ghost"], ["sparrow", "crow"], ["crow", "crow"],
	["magpie", "crow"], ["hound", "fox"], ["puppy", "fox"], ["bear", "bunny"], ["cat", "cat"], ["fox", "fox"], ["snail", "snail"],
	["bunny", "bunny"], ["hare", "bunny"], ["candle", "wick"], ["wick", "wick"], ["soot", "wisp"], ["wisp", "wisp"],
	["sprout", "slime"], ["pebble", "slime"], ["egg", "slime"], ["hush", "ghost"]]

## Visual kind for a pet: pets[].creature, else "" when a real custom model exists, else a keyword guess.
static func creature_kind(r: Dictionary) -> String:
	var k = str(r.get("creature", ""))
	if k != "":
		return k
	var model = str(r.get("model", ""))
	if model != "" and ResourceLoader.exists(model) and not model.contains("/characters/") and not r.get("art_needed", false):
		return ""
	var text = (str(r.get("id", "")) + " " + str(r.get("name", "")) + " " + str(r.get("desc", ""))).to_lower()
	for kw in PET_KEYWORDS:
		if text.contains(kw[0]):
			return kw[1]
	return "wisp"

static func cfg() -> Dictionary:
	return Content.get_rec("config", "pets")

static func rec(id: String) -> Dictionary:
	return Content.get_rec("pets", id)

static func active_rec(ch: CharacterData) -> Dictionary:
	return rec(ch.active_pet) if ch.active_pet != "" else {}

static func max_level(id: String) -> int:
	return int(rec(id).get("max_level", cfg().get("max_level", 30)))

static func xp_to_next(level: int) -> int:
	var c = cfg()
	var curve: Dictionary = c.get("curve", {})
	return int(round(float(curve.get("base", c.get("xp_base", 25.0))) * pow(float(curve.get("growth", c.get("xp_growth", 1.16))), level - 1)))

static func level(ch: CharacterData, id: String) -> int:
	var p = ch.pets_owned.get(id)
	return int(p.get("level", 1)) if p is Dictionary else 0

static func owns(ch: CharacterData, id: String) -> bool:
	return ch.pets_owned.has(id)

## Acquisition API (drops, events, quests, crafting, vendor). Returns true when newly acquired.
static func grant_pet(ch: CharacterData, id: String) -> bool:
	if rec(id).is_empty() or owns(ch, id):
		return false
	ch.pets_owned[id] = {"level": 1, "xp": 0}
	ch.track("pets_owned")
	if ch.active_pet == "":
		ch.active_pet = id
		ch.recalc()
	Events.pet_acquired.emit(id)
	return true

static func set_active(ch: CharacterData, id: String) -> bool:
	if id != "" and not owns(ch, id):
		return false
	ch.active_pet = id
	ch.recalc()
	return true

## Returns levels gained.
static func gain_xp(ch: CharacterData, id: String, amount: int) -> int:
	if not owns(ch, id) or amount <= 0:
		return 0
	var p: Dictionary = ch.pets_owned[id]
	var lvl = int(p.get("level", 1))
	var xp = int(p.get("xp", 0)) + amount
	var gained = 0
	var mx = max_level(id)
	while lvl < mx and xp >= xp_to_next(lvl):
		xp -= xp_to_next(lvl)
		lvl += 1
		gained += 1
	if lvl >= mx:
		xp = 0
	p.level = lvl
	p.xp = xp
	if gained > 0:
		ch.recalc()
		Events.pet_level_up.emit(id, lvl)
	return gained

## Stat source "pet": bonuses_per_level × level (+ "lucky" pity speed).
static func stat_bonuses(ch: CharacterData) -> Dictionary:
	var r = active_rec(ch)
	if r.is_empty():
		return {}
	var lvl = level(ch, ch.active_pet)
	var out = {}
	var b: Dictionary = r.get("bonuses_per_level", {})
	for k in b:
		out[k] = float(b[k]) * lvl
	if str(r.get("perk", "")) == "lucky":
		var pp: Dictionary = r.get("perk_params", {})
		out["pity_speed_pct"] = float(out.get("pity_speed_pct", 0.0)) + float(pp.get("pity_speed_pct", 20.0)) + float(pp.get("per_level", 0.5)) * lvl
	return out

static func perk(ch: CharacterData) -> String:
	return str(active_rec(ch).get("perk", ""))

static func perk_param(ch: CharacterData, key: String, default):
	return active_rec(ch).get("perk_params", {}).get(key, default)

## Combat help only for minion classes: classes[].pet_combat, config/pets.combat_classes or
## pets[].combat_for listing the class.
static func combat_enabled(ch: CharacterData) -> bool:
	if ch.active_pet == "":
		return false
	return bool(ch.cls().get("pet_combat", false)) or cfg().get("combat_classes", []).has(ch.class_id) \
		or active_rec(ch).get("combat_for", []).has(ch.class_id)

## Called for every player kill. Returns {dig:bool} so the world can spawn a dug-up treasure.
static func on_kill(ch: CharacterData, kind := "normal") -> Dictionary:
	var out = {"dig": false}
	if ch.active_pet == "":
		return out
	var mult = {"champion": 3, "rare": 5, "boss": 20}.get(kind, 1)
	gain_xp(ch, ch.active_pet, int(cfg().get("xp_per_kill", 1)) * mult)
	if perk(ch) == "dig":
		var every = int(perk_param(ch, "every", 0))
		if every > 0:
			# Kill-count mode: every N kills, chance
			var n = int(ch.pet_state.get("dig_kills", 0)) + 1
			if n >= every:
				n = 0
				out.dig = Rng.chance("loot", float(perk_param(ch, "chance", 0.6)))
			ch.pet_state["dig_kills"] = n
		elif ch.play_seconds >= float(ch.pet_state.get("dig_ready_at", 0.0)):
			# Data mode (dig{chance}): per-kill chance, then config dig_cooldown_s of play time
			if Rng.chance("loot", float(perk_param(ch, "chance", 0.03))):
				out.dig = true
				ch.pet_state["dig_ready_at"] = ch.play_seconds + float(cfg().get("dig_cooldown_s", 45.0))
	if level(ch, ch.active_pet) >= max_level(ch.active_pet) and not ch.pet_state.get("maxed", []).has(ch.active_pet):
		var mx: Array = ch.pet_state.get("maxed", [])
		mx.append(ch.active_pet)
		ch.pet_state["maxed"] = mx
		ch.track("pets_at_level_30")
	return out

## "lucky" perk: chance to double a gold pickup.
static func double_gold(ch: CharacterData) -> bool:
	return perk(ch) == "lucky" and Rng.chance("loot", float(perk_param(ch, "double_gold_chance", 0.0)))

## "lucky" perk: chance for one extra affix on a dropped Magic+ item (within affix hygiene max).
static func extra_affix_chance(ch: CharacterData) -> float:
	return float(perk_param(ch, "extra_affix_chance", 0.0)) if perk(ch) == "lucky" else 0.0

## Pet drops: pets with drop_chance roll on kills (elites/bosses more likely). Returns pet id or "".
static func roll_drop(ch: CharacterData, kind := "normal") -> String:
	var mult = {"champion": 2.0, "rare": 3.0, "boss": 6.0}.get(kind, 1.0)
	for p in Content.all("pets"):
		var c = float(p.get("drop_chance", 0.0))
		if c <= 0.0 or owns(ch, p.id):
			continue
		if str(p.get("source", "drop")) != "drop":
			continue
		if Rng.chance("loot", c * mult):
			return p.id
	return ""

static func feed_treat(ch: CharacterData, amount := -1) -> bool:
	if ch.active_pet == "":
		return false
	gain_xp(ch, ch.active_pet, amount if amount > 0 else int(cfg().get("treat_xp", 40)))
	return true

# ------------------------------------------------------------------ pet ferry (research #6)
## Pets with perk "ferry" carry loads; if no pet in the content has that perk, any pet can.
static func can_ferry(ch: CharacterData) -> bool:
	if perk(ch) == "ferry" or cfg().get("ferry_any_pet", false):
		return true
	return not Content.all("pets").any(func(p): return str(p.get("perk", "")) == "ferry")

static func ferry_status(ch: CharacterData) -> Dictionary:
	var now = ch.play_seconds
	return {"has_pet": ch.active_pet != "", "ready": ch.active_pet != "" and now >= float(ch.pet_state.get("ferry_ready_at", 0.0)),
		"cooldown_left": max(0.0, float(ch.pet_state.get("ferry_ready_at", 0.0)) - now),
		"away": now < float(ch.pet_state.get("ferry_back_at", 0.0))}

## Items the pet would carry: unlocked bag items at or below `max_rank` (default: Common + Magic).
static func ferry_candidates(ch: CharacterData, max_rank := -1) -> Array:
	if max_rank < 0:
		max_rank = int(cfg().get("ferry_max_rank", 1))
	var out = []
	for i in ch.inventory.size():
		var it = ch.inventory[i]
		if it is Dictionary and not it.get("locked", false) and Items.rarity_index(it.rarity) <= max_rank:
			out.append(i)
	return out

## Send the pet to town with junk. mode "sell" → gold, "salvage" → materials. Outcome is granted
## immediately (saved), the pet is away for ferry_duration_s, cooldown counts play time only.
static func ferry(ch: CharacterData, mode := "sell", max_rank := -1, indices := []) -> Dictionary:
	var st = ferry_status(ch)
	if not st.has_pet:
		return {"ok": false, "message": "You have no companion"}
	if not can_ferry(ch):
		return {"ok": false, "message": "%s can't carry loads — try a ferrying companion" % active_rec(ch).get("name", "Your pet")}
	if not st.ready:
		return {"ok": false, "message": "Your companion is resting (%ds)" % int(ceil(st.cooldown_left))}
	var list: Array = indices if not indices.is_empty() else ferry_candidates(ch, max_rank)
	var gold = 0
	var mats = {}
	var n = 0
	for i in list:
		var it = ch.inventory[i] if i >= 0 and i < ch.inventory.size() else null
		if not (it is Dictionary) or it.get("locked", false):
			continue
		if mode == "salvage":
			var y = InventoryOps.salvage_yield(it)
			for m in y:
				mats[m] = int(mats.get(m, 0)) + int(y[m])
		else:
			gold += InventoryOps.sell_value(it)
		ch.inventory[i] = null
		n += 1
	if n == 0:
		return {"ok": false, "message": "Nothing to carry"}
	ch.gold += gold
	for m in mats:
		ch.add_material(m, mats[m])
	var c = cfg()
	ch.pet_state["ferry_back_at"] = ch.play_seconds + float(perk_param(ch, "trip_seconds", c.get("ferry_duration_s", 6.0))) + 2.0
	ch.pet_state["ferry_ready_at"] = ch.play_seconds + float(c.get("ferry_cooldown_s", 90.0))
	var res = {"ok": true, "count": n, "gold": gold, "materials": mats,
		"message": "%s carries %d items to town" % [active_rec(ch).get("name", "Your pet"), n]}
	Events.pet_ferry.emit("left", res)
	Events.inventory_changed.emit()
	Events.gold_changed.emit(ch.gold)
	return res
