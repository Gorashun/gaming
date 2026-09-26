extends Node
## Autonomous playtest bot. Drives the player through intents (same path as touch input).
## Args: --bot[=novice|competent|expert] --duration=<s> --metrics-out=<path.jsonl> --auto-equip
## Writes one JSON line per event + a summary line at the end.

var args := {}
var skill_level := "competent"
var _t := 0.0
var _duration := 120.0
var _log: FileAccess
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _wander_target := Vector3.ZERO
var _deaths := 0
var _kills := 0
var _drops := {}
var _dmg_taken := 0.0
var _dmg_dealt := 0.0
var _ttk := []
var _engaged := {}
var _zones_done := 0
var _start_level := 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	skill_level = args.get("bot", "competent")
	if skill_level == "true":
		skill_level = "competent"
	_duration = float(args.get("duration", "120"))
	if args.has("metrics-out"):
		_log = FileAccess.open(args["metrics-out"], FileAccess.WRITE)
	Events.actor_died.connect(_on_died)
	Events.item_dropped.connect(func(_d, it): _drops[it.rarity] = int(_drops.get(it.rarity, 0)) + 1)
	Events.actor_damaged.connect(_on_dmg)
	Events.player_died.connect(func(): _deaths += 1; _write({"ev": "death", "t": _t}))
	Events.zone_cleared.connect(func(z): _zones_done += 1; _write({"ev": "zone_cleared", "zone": z, "t": _t}))
	await get_tree().create_timer(1.0).timeout
	_start_level = Game.character.level if Game.character else 1

func _write(d: Dictionary) -> void:
	if _log:
		_log.store_line(JSON.stringify(d))

func _on_died(a, _k) -> void:
	_kills += 1
	if _engaged.has(a.get_instance_id()):
		_ttk.append(_t - float(_engaged[a.get_instance_id()]))

func _on_dmg(target, amount, _crit, _el) -> void:
	if target is Player:
		_dmg_taken += amount
	elif target is Monster:
		_dmg_dealt += amount
		if not _engaged.has(target.get_instance_id()):
			_engaged[target.get_instance_id()] = _t

func _process(delta: float) -> void:
	_t += delta
	if _t > _duration:
		_finish()
		return
	var w: GameWorld = Game.world
	if w == null or w.player == null or not is_instance_valid(w.player):
		return
	var p: Player = w.player
	# Dismiss summary / death screens
	var s = w.get_parent().screen if w.get_parent() and "screen" in w.get_parent() else null
	if get_tree().paused:
		_handle_pause(w)
		return
	if not p.alive:
		return
	if args.has("auto-equip") and int(_t * 2) % 20 == 0:
		if InventoryOps.best_gear(p.ch) > 0:
			p.sync_from_character()
		if p.ch.skill_points > 0:
			w.get_parent().auto_spend_points()
	if p.life < p.max_life * (0.35 if skill_level != "novice" else 0.15):
		p.use_potion()
	var target = w.nearest_enemy(p, p.global_position, 30.0, [])
	if target:
		var d = p.global_position.distance_to(target.global_position)
		var basic = Content.get_rec("skills", p.basic_skill)
		var ranged = basic.get("tags", []).has("projectile")
		var want = 7.0 if ranged else 1.8
		# try skills
		for sid in p.ch.skill_bar:
			if sid != "" and p.can_cast(sid) and d < 9.0 and randf() < (0.9 if skill_level == "expert" else 0.5):
				p.request_cast(sid, target.global_position)
				break
		if d > want:
			p.intent_move = _dir_to(w, p.global_position, target.global_position)
		else:
			p.intent_move = Vector3.ZERO
			p.request_cast(p.basic_skill, target.global_position)
			if skill_level == "expert" and d < 1.2 and ranged:
				p.intent_move = (p.global_position - target.global_position).normalized()
	else:
		# loot then exit
		var drop = null
		for dr in w.drops:
			if is_instance_valid(dr):
				drop = dr
				break
		if drop:
			p.intent_move = _dir_to(w, p.global_position, drop.global_position)
			if p.global_position.distance_to(drop.global_position) < 2.2:
				w.pickup(drop)
		elif w.exit_portal and w.exit_portal.visible:
			p.intent_move = _dir_to(w, p.global_position, w.exit_portal.global_position)
			if p.global_position.distance_to(w.exit_portal.global_position) < 2.0:
				w._use_exit()
		else:
			p.intent_move = _dir_to(w, p.global_position, _explore_target(w, p))
	# stuck detection
	if p.global_position.distance_to(_last_pos) < 0.05 and p.intent_move.length() > 0.1:
		_stuck_t += delta
		if _stuck_t > 1.5:
			p.intent_move = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
			_stuck_t = 0.0
	else:
		_stuck_t = 0.0
	_last_pos = p.global_position

func _explore_target(w: GameWorld, p: Player) -> Vector3:
	# nearest remaining monster anywhere, else a random room
	var best = null
	var bd = 1e9
	for m in w.monsters:
		if is_instance_valid(m) and m.alive:
			var dd = m.global_position.distance_to(p.global_position)
			if dd < bd:
				bd = dd
				best = m
	if best:
		return best.global_position
	if _wander_target == Vector3.ZERO or p.global_position.distance_to(_wander_target) < 2.0:
		var r = w.layout.rooms[randi() % w.layout.rooms.size()]
		_wander_target = w.layout.cell_to_world(r.center)
	return _wander_target

func _dir_to(w: GameWorld, a: Vector3, b: Vector3) -> Vector3:
	if w.has_line(a, b):
		return (b - a).normalized()
	var path = w.find_path(a, b)
	if path.size() > 1:
		return (path[1] - a).normalized()
	return (b - a).normalized()

func _handle_pause(w: GameWorld) -> void:
	var sess = w.get_parent()
	if sess.screen and is_instance_valid(sess.screen):
		var title = sess.screen.title_label.text if sess.screen.title_label else ""
		_write({"ev": "screen", "title": title, "t": _t})
		if title.contains("snuffed"):
			sess.screen.queue_free()
			get_tree().paused = false
			w.player.revive()
		elif title.contains("cleansed"):
			var z = Content.get_rec("zones", w.zone.id)
			sess.travel(z.get("next", "a1_z1"))
		else:
			sess.screen.close()

func _finish() -> void:
	var ch = Game.character
	var avg_ttk = 0.0
	for x in _ttk:
		avg_ttk += x
	avg_ttk = avg_ttk / max(1, _ttk.size())
	var summary = {"ev": "summary", "bot": skill_level, "class": ch.class_id, "tier": ch.difficulty, "duration_s": _t,
		"kills": _kills, "kills_per_min": _kills / (_t / 60.0), "deaths": _deaths, "avg_ttk_s": avg_ttk,
		"drops": _drops, "level_start": _start_level, "level_end": ch.level, "gold": ch.gold, "zones_cleared": _zones_done,
		"dmg_dealt": int(_dmg_dealt), "dmg_taken": int(_dmg_taken), "zone": Game.world.zone.id if Game.world else ""}
	_write(summary)
	print("BOT_SUMMARY ", JSON.stringify(summary))
	get_tree().quit()
