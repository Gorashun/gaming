class_name SkillEffects
extends RefCounted
## Data-driven skill effect primitives. A skill record has "effects": [ {type, ...}, ... ].
## New primitives are added here; content refers to them by "type" name.
##
## Common keys: mult (weapon damage multiplier), element, knockback, status {id, duration, value},
## delay (seconds before this effect), vfx_color.

static func execute(caster: Actor, skill: Dictionary, rank: int, target_pos: Vector3) -> void:
	var world = Game.world
	if world == null:
		return
	for e in skill.get("effects", []):
		var d := float(e.get("delay", 0.0))
		if d > 0.0:
			await caster.get_tree().create_timer(d, false).timeout
			if not is_instance_valid(caster) or not caster.alive:
				return
		_run(world, caster, skill, rank, e, target_pos)

static func rank_mult(skill: Dictionary, e: Dictionary, rank: int) -> float:
	var base := float(e.get("mult", 1.0))
	var per := float(skill.get("mult_per_rank", 0.12))
	return base * (1.0 + per * (rank - 1))

static func color_of(caster: Actor, skill: Dictionary, e: Dictionary) -> Color:
	if e.has("color"):
		return Color(e.color)
	if skill.has("color"):
		return Color(skill.color)
	return caster.element_color

static func _run(world, caster: Actor, skill: Dictionary, rank: int, e: Dictionary, target_pos: Vector3) -> void:
	var col := color_of(caster, skill, e)
	var element: String = e.get("element", skill.get("element", "physical"))
	var mult := rank_mult(skill, e, rank)
	var tags: Array = skill.get("tags", [])
	var fwd := (target_pos - caster.global_position)
	fwd.y = 0
	fwd = fwd.normalized() if fwd.length() > 0.01 else caster.facing
	var area := 1.0 + caster.stats.get_stat("area_pct") / 100.0
	match str(e.type):
		"melee_arc":
			var r := float(e.get("radius", 2.2)) * sqrt(area)
			var ang := float(e.get("angle", 120.0))
			Fx.slash(caster.global_position, fwd, r, ang, col)
			var hits := world.enemies_in_arc(caster, caster.global_position, fwd, r, ang)
			for t in hits:
				world.deal_damage(caster, t, mult, element, tags, e)
			if hits.size() > 0:
				Fx.hitstop(int(e.get("hitstop_ms", 45)))
				Fx.shake(float(e.get("shake", 0.18)))
		"aoe", "nova":
			var center: Vector3 = caster.global_position if (e.type == "nova" or e.get("at", "target") == "self") else target_pos
			var r := float(e.get("radius", 3.0)) * sqrt(area)
			if e.has("telegraph"):
				Fx.telegraph(center, r, float(e.telegraph), col)
				await caster.get_tree().create_timer(float(e.telegraph), false).timeout
				if not is_instance_valid(caster):
					return
			Fx.ring(center, r, col, 0.4)
			Fx.burst(center + Vector3(0, 0.3, 0), col, 18, 5.0, 0.14, 0.45)
			Fx.flash_light(center + Vector3(0, 1, 0), col, 2.5, 0.3, r * 2.0)
			for t in world.enemies_in_radius(caster, center, r):
				world.deal_damage(caster, t, mult, element, tags, e)
			Fx.shake(float(e.get("shake", 0.25)))
		"projectile":
			var count := int(e.get("count", 1)) + int(caster.stats.get_stat("projectiles"))
			var spread := float(e.get("spread", 12.0))
			for i in count:
				var ang := 0.0 if count == 1 else lerpf(-spread, spread, float(i) / (count - 1)) 
				var dir := fwd.rotated(Vector3.UP, deg_to_rad(ang))
				world.spawn_projectile(caster, dir, e, mult, element, tags, col)
		"dash", "leap":
			var dist := float(e.get("distance", 5.0))
			var dest: Vector3 = caster.global_position + fwd * dist
			if e.type == "leap" and caster.global_position.distance_to(target_pos) < dist:
				dest = target_pos
			dest = world.clamp_to_walkable(caster.global_position, dest)
			var dur := float(e.get("duration", 0.18))
			var start := caster.global_position
			caster.add_status("unstoppable", dur + 0.1)
			var tw := caster.create_tween()
			if e.type == "leap":
				tw.tween_method(func(p):
					if is_instance_valid(caster):
						var pos := start.lerp(dest, p)
						pos.y = start.y + sin(p * PI) * 2.0
						caster.global_position = pos, 0.0, 1.0, dur)
			else:
				tw.tween_property(caster, "global_position", dest, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			await tw.finished
			if not is_instance_valid(caster):
				return
			if e.get("path_damage", false):
				for t in world.enemies_in_capsule(caster, start, dest, float(e.get("width", 1.4))):
					world.deal_damage(caster, t, mult, element, tags, e)
			if e.has("land_radius"):
				var r := float(e.land_radius) * sqrt(area)
				Fx.ring(dest, r, col, 0.35)
				Fx.burst(dest + Vector3(0, 0.2, 0), Color(0.5, 0.45, 0.4), 16, 4.0, 0.2, 0.5)
				for t in world.enemies_in_radius(caster, dest, r):
					world.deal_damage(caster, t, mult, element, tags, e)
				Fx.shake(0.35)
				Fx.hitstop(50)
		"chain":
			var jumps := int(e.get("jumps", 3))
			var rng := float(e.get("range", 6.0))
			var from: Vector3 = caster.hit_center()
			var hit_set := []
			var current = world.nearest_enemy(caster, target_pos, rng * 1.5, hit_set)
			while current and jumps >= 0:
				world.draw_bolt(from, current.hit_center(), col)
				world.deal_damage(caster, current, mult, element, tags, e)
				hit_set.append(current)
				from = current.hit_center()
				current = world.nearest_enemy(caster, current.global_position, rng, hit_set)
				jumps -= 1
		"ground_zone":
			world.spawn_ground_zone(caster, target_pos if e.get("at", "target") == "target" else caster.global_position, e, mult, element, tags, col)
		"summon":
			var n := int(e.get("count", 1)) + int(caster.stats.get_stat("summon_count"))
			for i in n:
				world.spawn_minion(caster, str(e.minion), e, rank)
		"buff":
			var dur := float(e.get("duration", 5.0))
			var bstats: Dictionary = {}
			for k in e.get("stats", {}):
				bstats[k] = float(e.stats[k]) * (1.0 + float(e.get("per_rank", 0.1)) * (rank - 1))
			caster.stats.set_source("buff:" + skill.id, bstats)
			if e.has("status"):
				caster.add_status(e.status, dur, float(e.get("status_value", 0.0)))
			Fx.ring(caster.global_position, 2.0, col, 0.5)
			Fx.burst(caster.global_position + Vector3(0, 1, 0), col, 14, 2.5, 0.12, 0.7, 2.0)
			if caster.has_method("on_buff_changed"):
				caster.on_buff_changed()
			caster.get_tree().create_timer(dur, false).timeout.connect(func():
				if is_instance_valid(caster):
					caster.stats.remove_source("buff:" + skill.id)
					if caster.has_method("on_buff_changed"):
						caster.on_buff_changed())
		"heal":
			var amt := caster.max_life * float(e.get("pct", 0.2))
			world.heal_actor(caster, amt)
			Fx.burst(caster.global_position + Vector3(0, 1, 0), Color(0.4, 1.0, 0.5), 16, 2.0, 0.12, 0.8, 2.0)
		"spin":
			var ticks := int(e.get("ticks", 5))
			var interval := float(e.get("interval", 0.18))
			var r := float(e.get("radius", 2.4)) * sqrt(area)
			for i in ticks:
				if not is_instance_valid(caster) or not caster.alive:
					return
				Fx.slash(caster.global_position, caster.facing.rotated(Vector3.UP, i * 2.1), r, 200.0, col, interval * 1.2)
				for t in world.enemies_in_radius(caster, caster.global_position, r):
					world.deal_damage(caster, t, mult, element, tags, e)
				await caster.get_tree().create_timer(interval, false).timeout
		"pull":
			for t in world.enemies_in_radius(caster, target_pos, float(e.get("radius", 5.0))):
				t.apply_knockback(t.global_position + (t.global_position - target_pos), float(e.get("force", 8.0)))
			Fx.ring(target_pos, float(e.get("radius", 5.0)), col, 0.5, false)
		"resource":
			if caster.has_method("gain_resource"):
				caster.gain_resource(float(e.get("amount", 10.0)))
		_:
			push_warning("Unknown skill effect type: %s" % e.type)
