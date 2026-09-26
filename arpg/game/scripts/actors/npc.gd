class_name Npc
extends Actor
## Town NPC from the `npcs` table: {id, name, role, town, model, attachments[], tint, anim, screen,
## barks[], greeting, quest_ids[], scale}. Idle animation, floating name + role icon, speech bubble
## barks, quest markers ("!" offer, "?" turn-in). Interaction is routed by GameWorld.

const ROLE_COLORS := {"smith": "#ffb35a", "alchemist": "#7dff9a", "jeweler": "#8fd0ff", "runecarver": "#c49bff",
	"trader": "#9cffb0", "stash": "#ffd23f", "stablemaster": "#d9a066", "petkeeper": "#ffa8d8", "innkeeper": "#ffcf7a",
	"questgiver": "#ffe066", "storyteller": "#b0c4ff", "waypoint": "#8fd0ff", "curio": "#e0a0ff"}
const ROLE_ICONS := {"smith": "⚒", "alchemist": "⚗", "jeweler": "◆", "runecarver": "ᚱ", "trader": "●", "stash": "▣",
	"stablemaster": "♞", "petkeeper": "♥", "innkeeper": "☾", "questgiver": "!", "storyteller": "✎", "waypoint": "✦", "curio": "✧"}
const DEFAULT_MODEL := "res://assets/thirdparty/kaykit/adventurers/characters/Knight.glb"

var npc_id = ""
var rec = {}
var _name_label: Label3D
var _marker: Label3D
var _bubble: Label3D
var _bubble_until = 0.0
var _think = 0.0
var _ambient_cd = 8.0
var _base_rot = 0.0

func setup_npc(r: Dictionary) -> void:
	rec = r
	npc_id = str(r.get("id", ""))
	faction = "npc"
	display_name = str(r.get("name", "Villager"))
	var path = str(r.get("model", DEFAULT_MODEL))
	if not ResourceLoader.exists(path):
		path = DEFAULT_MODEL
	setup_model(path, float(r.get("scale", 1.0)), Color(r.get("tint", "#ffffff")), Color(role_color()))
	show_only_attachments(r.get("attachments", []))
	collision_layer = 1
	collision_mask = 0
	_base_rot = rotation.y
	play(str(r.get("anim", "Idle")))
	var role_name = str(r.get("role", "")).capitalize()
	_name_label = _label("%s\n%s %s" % [display_name, ROLE_ICONS.get(str(r.get("role", "")), "•"), role_name], 34, Color(role_color()))
	_name_label.position.y = 2.7
	_marker = _label("", 72, Color("#ffd23f"))
	_marker.position.y = 3.35
	_marker.outline_size = 16
	_bubble = _label("", 30, Color(0.1, 0.08, 0.06))
	_bubble.position.y = 2.25
	_bubble.outline_modulate = Color(1, 0.97, 0.9, 0.95)
	_bubble.outline_size = 26
	_bubble.width = 420
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.visible = false
	set_physics_process(false)

func role() -> String:
	return str(rec.get("role", ""))

func role_color() -> String:
	return str(rec.get("color", ROLE_COLORS.get(role(), "#ffd98a")))

func _label(text: String, size: int, col: Color) -> Label3D:
	var l = Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.pixel_size = 0.0012
	l.font_size = size
	l.outline_size = 10
	l.modulate = col
	l.no_depth_test = true
	add_child(l)
	return l

## Speech bubble with a random bark (or `text`).
func bark(text := "") -> void:
	if text == "":
		var barks: Array = rec.get("barks", [])
		if barks.is_empty():
			text = str(rec.get("greeting", "Well met, Wickbearer."))
		else:
			text = str(barks[Rng.int_on("fx", 0, barks.size() - 1)])
	_bubble.text = text
	_bubble.visible = true
	_bubble.modulate.a = 1.0
	_bubble_until = time_now() + 3.5
	play("Interact" if anim and anim.has_animation("Interact") else str(rec.get("anim", "Idle")), 0.8, 1.0, true)

func greet() -> void:
	bark(str(rec.get("greeting", "")) if rec.has("greeting") else "")

func _process(delta: float) -> void:
	if _bubble.visible and time_now() > _bubble_until:
		_bubble.modulate.a = max(0.0, _bubble.modulate.a - delta * 3.0)
		if _bubble.modulate.a <= 0.0:
			_bubble.visible = false
	if not anim_locked():
		play(str(rec.get("anim", "Idle")))
	_think -= delta
	if _think > 0.0:
		return
	_think = 0.5
	var ch = Game.character
	var p = Game.world.player if Game.world else null
	if ch:
		var mark = ""
		if not Quests.ready_for(ch, npc_id).is_empty():
			mark = "?"
		elif not Quests.available_for(ch, npc_id).is_empty():
			mark = "!"
		_marker.text = mark
	if p and is_instance_valid(p):
		var d = global_position.distance_to(p.global_position)
		if d < 6.0:
			face_towards(p.global_position)
			_ambient_cd -= 0.5
			if _ambient_cd <= 0.0 and not _bubble.visible:
				_ambient_cd = Rng.range_on("fx", 12.0, 22.0)
				bark()
		elif absf(rotation.y - _base_rot) > 0.01:
			rotation.y = lerp_angle(rotation.y, _base_rot, 0.3)
