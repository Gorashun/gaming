extends "res://scripts/ui/quests_screen.gd"
## Bounty board NPC screen = quest journal opened on the NPC's offers (else side quests).

func _ready() -> void:
	screen_id = "quests"
	if not ctx.has("tab"):
		ctx["tab"] = "side"
	super._ready()
