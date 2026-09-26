extends ScreenBase
## Skill list per branch: rank up with points, assign to the 4 bar slots.

var ch: CharacterData
var _list: VBoxContainer
var _pts: Label
var _assign_skill = ""

func _ready() -> void:
	ch = Game.character
	build("Skills")
	var v = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(v)
	_pts = UiTheme.label("", 22, Color("#b58cff"), true)
	v.add_child(_pts)
	var sc = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	sc.add_child(_list)
	refresh()

func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	_pts.text = "Skill points: %d   ·   Tap + to learn, then tap a slot to place it" % ch.skill_points
	var skills = Content.where("skills", "class", ch.class_id)
	skills.sort_custom(func(a, b): return int(a.get("unlock_level", 1)) < int(b.get("unlock_level", 1)))
	for s in skills:
		if s.id == ch.cls().get("basic_attack", ""):
			continue
		var row = PanelContainer.new()
		var col = Color(s.get("color", "#ffd98a"))
		row.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.08, 0.07, 0.11, 0.95), col.darkened(0.3), 12, 2))
		_list.add_child(row)
		var h = HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)
		var icon = UiTheme.label(ActionButton.GLYPHS.get(s.get("icon", ""), "+"), 40, col)
		icon.custom_minimum_size = Vector2(64, 0)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(icon)
		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		var rank = int(ch.skill_ranks.get(s.id, 0))
		info.add_child(UiTheme.label("%s   %s" % [s.name, ("Rank %d/%d" % [rank, s.get("max_rank", 5)]) if rank > 0 else "Unlocks at level %d" % s.get("unlock_level", 1)], 22, col, true))
		var cost = "Cost %d · Cooldown %ss" % [s.get("cost", 0), str(s.get("cooldown", 0))]
		info.add_child(UiTheme.label(s.get("desc", "") + "   (" + cost + ")", 17, UiTheme.MUTED))
		var can_up = ch.skill_points > 0 and ch.level >= int(s.get("unlock_level", 1)) and rank < int(s.get("max_rank", 5))
		var up = UiTheme.button("+", func():
			ch.skill_points -= 1
			ch.skill_ranks[s.id] = rank + 1
			Sfx.play("skill_up")
			if rank == 0:
				_auto_place(s.id)
			refresh(), 30, Vector2(72, 64))
		up.disabled = not can_up
		h.add_child(up)
		if rank > 0:
			for i in 4:
				var slot_i = i
				var b = UiTheme.button(str(i + 1), func():
					for j in 4:
						if ch.skill_bar[j] == s.id:
							ch.skill_bar[j] = ""
					ch.skill_bar[slot_i] = s.id
					_notify_bar()
					refresh(), 20, Vector2(56, 64))
				if ch.skill_bar[i] == s.id:
					b.add_theme_color_override("font_color", col)
					b.add_theme_stylebox_override("normal", UiTheme.panel_style(col.darkened(0.6), col, 10, 3))
				h.add_child(b)

func _auto_place(id: String) -> void:
	for i in 4:
		if ch.skill_bar[i] == "":
			ch.skill_bar[i] = id
			_notify_bar()
			return

func _notify_bar() -> void:
	if session and session.hud:
		session.hud.touch.refresh_bar()
