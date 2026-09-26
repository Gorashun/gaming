extends Node
## Autonomous playtest bot. Drives the player through intents (same path as touch input).
## Args: --bot[=novice|competent|expert] --duration=<s> --metrics-out=<path.jsonl> --auto-equip
##       --pet=<id|first> --mount=<id|first> (grant + use) --exercise (hearth → town NPCs → portal back)
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
var _dodges := 0
var _ex_stage := 0
var _ex_t := 0.0

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
	_grant_companions()

var _tour_i := -1
var _tour_t := 0.0
## --screens=a,b:c,... opens each screen for 2 s (prints SCREEN <name>) to catch UI errors.
func _screen_tour(w: GameWorld, delta: float) -> void:
	_tour_t -= delta
	if _tour_t > 0.0:
		return
	var list: Array = str(args.screens).split(",")
	var sess = w.get_parent()
	if sess.screen and is_instance_valid(sess.screen):
		sess.screen.queue_free()
		get_tree().paused = false
	_tour_i += 1
	if _tour_i >= list.size():
		_finish()
		return
	_tour_t = float(args.get("screen-interval", "2.0"))
	print("SCREEN ", list[_tour_i])
	sess.current_npc = str(args.get("npc", ""))
	sess.open_screen(list[_tour_i])
	if args.has("burst"):
		sess.open_screen(str(args.burst))   # same-frame replace (stress test)

func _pick(table: String, want: String) -> String:
	if want == "first" or want == "true":
		var all = Content.all(table)
		return all[0].id if all.size() > 0 else ""
	return want if Content.has_rec(table, want) else ""

func _grant_companions() -> void:
	var sess = Game.world.get_parent() if Game.world else null
	if sess == null:
		return
	if args.has("pet"):
		var id = _pick("pets", args.pet)
		if id != "":
			sess.grant_pet(id)
			sess.set_active_pet(id)
			_write({"ev": "pet", "id": id})
	if args.has("mount"):
		var id = _pick("mounts", args.mount)
		if id != "":
			sess.grant_mount(id)
			Game.world.player.wants_mount = true
			_write({"ev": "mount", "id": id})

## Scripted systems walk-through: hearth home, talk to every NPC, portal back.
func _exercise(w: GameWorld, p: Player, delta: float) -> bool:
	var sess = w.get_parent()
	_ex_t += delta
	match _ex_stage:
		0:
			if _t > 12.0 and not w.is_town and w.nearest_enemy(p, p.global_position, 12.0, []) == null:
				var r = sess.hearth()
				_write({"ev": "hearth", "ok": r.ok, "t": _t})
				_ex_stage = 1 if r.ok else 9
				_ex_t = 0.0
				p.intent_move = Vector3.ZERO
				return true
		1:
			p.intent_move = Vector3.ZERO
			if w.is_town:
				_ex_stage = 2
				_ex_t = 0.0
			elif not p.is_channeling() and _ex_t > 4.5:
				_ex_stage = 0   # interrupted (hit) → retry later
			return true
		2:
			p.intent_move = Vector3.ZERO
			if _ex_t > 1.5:
				for n in w.npcs:
					if is_instance_valid(n):
						w.interact_npc(n)
				sess.bind_town()
				_write({"ev": "town", "npcs": w.npcs.size(), "return_portal": w.return_portal != null, "t": _t})
				_ex_stage = 3
				_ex_t = 0.0
			return true
		3:
			p.intent_move = Vector3.ZERO
			if _ex_t > 3.0:
				var r = sess.portal_back()
				_write({"ev": "portal_back", "ok": r.ok, "t": _t})
				_ex_stage = 9
			return true
	return false

func _write(d: Dictionary) -> void:
	if args.has("exercise"):
		print("EV ", JSON.stringify(d))
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
	if args.has("talk-all"):
		w.suppress_npc_screens = true
		_tour_t -= delta
		if _tour_t <= 0.0:
			_tour_t = 1.5
			_tour_i += 1
			if _tour_i >= w.npcs.size():
				_finish()
				return
			var n = w.npcs[_tour_i]
			print("NPC ", n.npc_id)
			w.interact_npc(n)
		return
	if args.has("screens"):
		_screen_tour(w, delta)
		return
	if get_tree().paused:
		_handle_pause(w)
		return
	if not p.alive:
		return
	if args.has("exercise") and _exercise(w, p, delta):
		return
	if args.has("auto-equip") and int(_t * 2) % 20 == 0:
		if InventoryOps.best_gear(p.ch) > 0:
			p.sync_from_character()
		if p.ch.skill_points > 0:
			w.get_parent().auto_spend_points()
	var target = w.nearest_enemy(p, p.global_position, 30.0, [])
	var basic = Content.get_rec("skills", p.basic_skill)
	var ranged = basic.get("tags", []).has("projectile")
	# Potions: novice drinks late; others drink at 35 %, or at 55 % when a telegraph is on them
	var danger = []
	if skill_level != "novice":
		# Only react to telegraphs that are about to land (reaction window), never to normal swings
		var window = 1.1 if skill_level == "expert" else 0.85
		var now_s = Time.get_ticks_msec() / 1000.0
		danger = w.hazards_at(p.global_position, 0.6, false).filter(func(h): return float(h.until) - now_s < window)
	var pot_at = 0.15 if skill_level == "novice" else (0.55 if not danger.is_empty() else 0.35)
	if p.life < p.max_life * pot_at and p.ch.potions > 0:
		p.use_potion()
	# Dodge telegraphs (competent/expert): step out; roll when it is about to land
	if not danger.is_empty():
		var h = danger[0]
		var esc = w.hazard_escape_dir(p.global_position, h)
		var left = float(h.until) - Time.get_ticks_msec() / 1000.0
		if left < (0.55 if skill_level == "expert" else 0.4) and h.kind != "melee":
			if p.dodge(esc):
				_dodges += 1
		p.intent_move = esc
		if ranged and target:
			p.request_cast(p.basic_skill, target.global_position)
		_last_pos = p.global_position
		return
	if target:
		var d = p.global_position.distance_to(target.global_position)
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
			# Kite: ranged heroes back off when something gets close (not novices)
			if ranged and skill_level != "novice" and d < (4.0 if skill_level == "expert" else 2.5):
				var away = (p.global_position - target.global_position)
				away.y = 0
				var dest = w.clamp_to_walkable(p.global_position, p.global_position + away.normalized() * 3.0)
				if dest.distance_to(p.global_position) > 0.5:
					p.intent_move = (dest - p.global_position).normalized()
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
		"drops": _drops, "dodges": _dodges, "level_start": _start_level, "level_end": ch.level, "gold": ch.gold, "zones_cleared": _zones_done,
		"dmg_dealt": int(_dmg_dealt), "dmg_taken": int(_dmg_taken), "zone": Game.world.zone.id if Game.world else ""}
	_write(summary)
	print("BOT_SUMMARY ", JSON.stringify(summary))
	get_tree().quit()
