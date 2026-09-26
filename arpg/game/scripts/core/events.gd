extends Node
## Global signal bus. Gameplay systems emit here; UI/audio/FX listen.

signal actor_damaged(target: Node, amount: float, is_crit: bool, element: String)
signal actor_died(actor: Node, killer: Node)
signal item_dropped(drop: Node, item: Dictionary)
signal item_picked_up(item: Dictionary)
signal gold_changed(total: int)
signal xp_gained(amount: int)
signal level_up(new_level: int)
signal inventory_changed
signal equipment_changed
signal stats_changed
signal resource_changed(current: float, maximum: float)
signal health_changed(current: float, maximum: float)
signal skill_cast(skill_id: String)
signal zone_entered(zone_id: String)
signal zone_cleared(zone_id: String)
signal boss_spawned(boss: Node)
signal boss_defeated(boss: Node)
signal golden_moment(item: Dictionary)
signal toast(text: String, color: Color)
signal surprise_event(event_id: String)
signal craft_completed(result: Dictionary)
signal profession_level_up(profession: String, level: int)
signal player_died
signal difficulty_changed(tier_id: String)
# --- Wave 2 systems (gameplay-programmer) ---
signal skill_mastery_ready(skill_id: String)
signal skill_mastery_up(skill_id: String, rank: int)
signal proficiency_up(weapon_type: String, level: int)
signal item_upgraded(item: Dictionary)
signal pet_acquired(pet_id: String)
signal pet_level_up(pet_id: String, level: int)
signal pet_ferry(state: String, result: Dictionary)   # "left" | "returned"
signal mount_changed(mounted: bool)
signal channel_progress(what: String, t: float)        # 0..1, -1 = cancelled
signal hearth_used
signal quest_accepted(quest_id: String)
signal quest_updated(quest_id: String, progress: int, count: int)
signal quest_ready(quest_id: String)
signal quest_completed(quest_id: String)
signal npc_talked(npc_id: String)
signal boss_phase(boss: Node, phase: int)
signal world_event_started(event_id: String)
signal world_event_stage(event_id: String, stage: int, total: int)
signal world_event_completed(event_id: String)
signal codex_updated(entry_id: String)
signal blessing_changed(pct: float)
