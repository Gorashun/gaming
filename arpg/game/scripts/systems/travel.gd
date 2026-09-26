class_name Travel
extends RefCounted
## Fast travel + Homeward Wick rules (GDD v2.1 #23/#24). Scene work (channel, loading) is in Session.
## config/travel {fee_base, fee_per_zone_level, fee_per_act_distance, town_free, hearth_cooldown_s,
## hearth_channel_s}. Cooldowns use play_seconds, so they pause while the game is not being played.

static func cfg() -> Dictionary:
	return Content.get_rec("config", "travel")

static func is_town(zone_id: String) -> bool:
	return bool(Content.get_rec("zones", zone_id).get("town", false))

static func act_order(act_id: String) -> int:
	return int(Content.get_rec("acts", act_id).get("order", 1))

static func fee(ch: CharacterData, zone_id: String) -> int:
	var z = Content.get_rec("zones", zone_id)
	if z.is_empty():
		return 0
	var c = cfg()
	if bool(z.get("town", false)) and c.get("town_free", true):
		return 0
	var dist = absi(act_order(str(z.get("act", ""))) - act_order(ch.current_act))
	return int(c.get("fee_base", 10)) + int(c.get("fee_per_zone_level", 2)) * int(z.get("level", 1)) + int(c.get("fee_per_act_distance", 50)) * dist

## "" when allowed, else reason.
static func can_fast_travel(ch: CharacterData, zone_id: String) -> String:
	if Content.get_rec("zones", zone_id).is_empty():
		return "Unknown place"
	if not ch.waypoints.has(zone_id):
		return "You haven't found that waypoint yet"
	if ch.gold < fee(ch, zone_id):
		return "Not enough gold"
	return ""

## Waypoints for the map UI: [{zone, name, act, town, fee, can}]
static func destinations(ch: CharacterData) -> Array:
	var out = []
	for zid in ch.waypoints:
		var z = Content.get_rec("zones", zid)
		if z.is_empty():
			continue
		out.append({"zone": zid, "name": z.get("name", zid), "act": z.get("act", ""), "town": z.get("town", false),
			"fee": fee(ch, zid), "can": can_fast_travel(ch, zid) == ""})
	return out

static func hearth_channel_s() -> float:
	return float(cfg().get("hearth_channel_s", 3.0))

static func hearth_cooldown_left(ch: CharacterData) -> float:
	return max(0.0, float(ch.hearth_ready_at) - ch.play_seconds)

static func hearth_target(ch: CharacterData) -> String:
	if ch.bound_town != "" and not Content.get_rec("zones", ch.bound_town).is_empty():
		return ch.bound_town
	return ch.current_act_town()

## "" when the hearth may be used (a Wick charge skips the cooldown).
static func can_hearth(ch: CharacterData) -> String:
	if hearth_cooldown_left(ch) > 0.0 and ch.wick_charges <= 0:
		return "Homeward Wick is rekindling (%ds)" % int(ceil(hearth_cooldown_left(ch)))
	return ""

## Called when the channel completes: starts the cooldown (or spends a charge).
static func consume_hearth(ch: CharacterData) -> void:
	if hearth_cooldown_left(ch) > 0.0 and ch.wick_charges > 0:
		ch.wick_charges -= 1
	else:
		ch.hearth_ready_at = ch.play_seconds + float(cfg().get("hearth_cooldown_s", 300.0))

static func can_bind(ch: CharacterData, zone_id: String) -> String:
	if not is_town(zone_id):
		return "You can only bind your wick in a town"
	if not ch.waypoints.has(zone_id):
		return "Visit that town first"
	return ""
