class_name Moon
extends RefCounted
## In-game moon cycle counted in ACTIVE play time (play_seconds) — never the device clock (welfare).
## config/moon {cycle_nights: 8, night_minutes: 12, day_minutes: 18, full_moon_night: 8}.

static func cfg() -> Dictionary:
	return Content.get_rec("config", "moon")

## {night (1..cycle), is_night, full, t_in_day_s, next_full_in_s}
static func state(ch: CharacterData) -> Dictionary:
	var c = cfg()
	var day_s = float(c.get("day_minutes", 18)) * 60.0
	var night_s = float(c.get("night_minutes", 12)) * 60.0
	var period = day_s + night_s
	var cycle = int(c.get("cycle_nights", 8))
	var full_n = int(c.get("full_moon_night", cycle))
	var t = ch.play_seconds
	var idx = int(t / period) % cycle + 1
	var within = fmod(t, period)
	var is_night = within >= day_s
	var full = is_night and idx == full_n
	var ci = int(t / (cycle * period))
	var start = (ci * cycle + (full_n - 1)) * period + day_s
	var next = 0.0
	if t < start:
		next = start - t
	elif t >= start + night_s:
		next = start + cycle * period - t
	return {"night": idx, "is_night": is_night, "full": full, "t_in_day_s": within, "next_full_in_s": max(0.0, next)}

static func is_full(ch: CharacterData) -> bool:
	return bool(state(ch).full)
