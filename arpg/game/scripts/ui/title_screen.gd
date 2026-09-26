extends Control
## Title: continue a hero or create a new one (class pick, name, Last Flame toggle).

var main: Node
var _box: VBoxContainer
var _class = "lanternbearer"
var _name_edit: LineEdit
var _hc: CheckButton

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.theme()
	var bg = ColorRect.new()
	bg.color = Color("#07060b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_box = VBoxContainer.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box.offset_left = 80
	_box.offset_right = -80
	_box.offset_top = 40
	_box.offset_bottom = -40
	_box.add_theme_constant_override("separation", 14)
	add_child(_box)
	Sfx.play_music("title")
	_show_home()

func _clear() -> void:
	for c in _box.get_children():
		c.queue_free()

func _title_label() -> void:
	var t = UiTheme.label("WICKWRIGHT", 84, UiTheme.GOLD, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_outline_color", Color("#3a1a00"))
	t.add_theme_constant_override("outline_size", 14)
	_box.add_child(t)
	var s = UiTheme.label("Carry the Light", 28, UiTheme.EMBER, true)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(s)

func _show_home() -> void:
	_clear()
	_title_label()
	var saves = Game.list_saves()
	var list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(list)
	for d in saves.slice(0, 5):
		var cls = Content.get_rec("classes", d.get("class_id", ""))
		var label = "%s — Level %d %s%s" % [d.get("name", "?"), int(d.get("level", 1)), cls.get("name", ""), ("  ☠" if d.get("dead", false) else ("  🔥 Last Flame" if d.get("hardcore", false) else ""))]
		var b = UiTheme.button(label, func():
			var ch = Game.load_character(d.id)
			if ch and not ch.dead:
				main.play_character(ch), 24, Vector2(620, 70))
		b.disabled = d.get("dead", false)
		list.add_child(b)
	list.add_child(UiTheme.button("New Hero", _show_create, 28, Vector2(620, 80)))

func _show_create() -> void:
	_clear()
	_box.add_child(UiTheme.label("Choose your Wickbearer", 40, UiTheme.GOLD, true))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_box.add_child(row)
	var desc = UiTheme.label("", 22, UiTheme.TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for c in Content.all("classes"):
		var col = Color(c.get("color", "#ffd27a"))
		var b = UiTheme.button(c.name, func():
			_class = c.id
			desc.text = "%s — %s\n%s" % [c.name, c.get("tagline", ""), c.get("desc", "")]
			desc.add_theme_color_override("font_color", col), 22, Vector2(210, 90))
		b.add_theme_color_override("font_color", col)
		row.add_child(b)
	var c0 = Content.get_rec("classes", _class)
	desc.text = "%s — %s\n%s" % [c0.name, c0.get("tagline", ""), c0.get("desc", "")]
	_box.add_child(desc)
	var nrow = HBoxContainer.new()
	_box.add_child(nrow)
	nrow.add_child(UiTheme.label("Name  ", 24))
	_name_edit = LineEdit.new()
	_name_edit.text = ["Ember", "Wisp", "Tallow", "Pip", "Moth", "Cinder"].pick_random()
	_name_edit.custom_minimum_size = Vector2(360, 60)
	_name_edit.max_length = 16
	nrow.add_child(_name_edit)
	_hc = CheckButton.new()
	_hc.text = "Last Flame (one life) — unlocks after finishing the story once"
	_hc.add_theme_font_size_override("font_size", 18)
	var unlocked = _story_done_any()
	_hc.disabled = not unlocked
	_box.add_child(_hc)
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	_box.add_child(h)
	h.add_child(UiTheme.button("Back", _show_home, 22, Vector2(180, 70)))
	h.add_child(UiTheme.button("Begin", func():
		var nm = _name_edit.text.strip_edges()
		if nm == "":
			nm = "Wickbearer"
		main.new_character(nm, _class, _hc.button_pressed), 28, Vector2(260, 76)))

func _story_done_any() -> bool:
	for d in Game.list_saves():
		for k in d.get("discoveries", []):
			if str(k).begins_with("story_complete:"):
				return true
	return false
