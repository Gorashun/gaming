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
