extends ScreenBase
## Wardrobe & Titles: pick a title (shown under the hero name) and cosmetics per slot
## (cape tint, aura, name frame, pet hat, mount tint) with a live 3D hero preview.
## Everything is earned through Deeds/quests — never sold.

var ch: CharacterData
var _slot = "title"
var _preview: HeroPreview
var _opts: VBoxContainer
var _rail: VBoxContainer
var _name: Label

const SLOTS := [["title", "crown", "Title"], ["cape_tint", "hero", "Cape"], ["aura", "spark", "Aura"], ["name_frame", "star", "Name frame"],
	["pet_hat", "pets", "Pet hat"], ["mount_tint", "mounts", "Mount colour"]]

func _ready() -> void:
	ch = Game.character
	if screen_id == "":
		screen_id = "wardrobe"
	build("Wardrobe", "hanger", true)
	var h = HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 12)
	body.add_child(h)
	_rail = VBoxContainer.new()
	_rail.add_theme_constant_override("separation", 6)
	h.add_child(_rail)
	var stage = Control.new()
	stage.custom_minimum_size = Vector2(360, 0)
	h.add_child(stage)
	var bg = Panel.new()
	bg.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.1, 0.07, 0.12, 0.85), Color(0.35, 0.27, 0.18), 16, 2))
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(bg)
	_preview = HeroPreview.new()
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview.camera_distance = 7.2
	_preview.camera_height = 1.8
	_preview.look_height = 1.15
	stage.add_child(_preview)
	_preview.add_hero(ch.class_id, ch, 0.0)
	_name = UiTheme.label("", 22, UiTheme.GOLD, true)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_name.offset_top = 8
	_name.offset_bottom = 70
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stage.add_child(_name)
	var sc = ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(sc)
	_opts = VBoxContainer.new()
	_opts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_opts.add_theme_constant_override("separation", 6)
	sc.add_child(_opts)
	refresh()

func refresh() -> void:
	var title = str(UiTheme.chf(ch, "title", ""))
	_name.text = ch.name + ("\n" + title if title != "" else "")
	ScreenBase.clear(_rail)
	for s in SLOTS:
		var id: String = s[0]
		var b = UiTheme.icon_button(s[1], s[2], func():
			_slot = id
			refresh(), Vector2(200, 72), UiTheme.GOLD if id == _slot else UiTheme.MUTED, true, 18)
		if id == _slot:
			b.add_theme_stylebox_override("normal", UiTheme.panel_style(Color(0.3, 0.18, 0.08, 0.95), UiTheme.EMBER, 12, 3))
		_rail.add_child(b)
	ScreenBase.clear(_opts)
	_apply_preview()
	if _slot == "title":
		var titles: Array = UiTheme.chf(ch, "titles", [])
		_opt_row("", "No title", title == "", UiTheme.MUTED, func(): _set_title(""))
		for t in titles:
			var tt = str(t)
			_opt_row("crown", tt, tt == title, UiTheme.GOLD, func(): _set_title(tt))
		if titles.is_empty():
			_opts.add_child(UiTheme.wrap_label("Earn titles from Deeds — look in the Deeds book!", 18, UiTheme.MUTED, 400))
		return
	var owned: Array = (UiTheme.chf(ch, "cosmetics_owned", {}) as Dictionary).get(_slot, [])
	var cur = (UiTheme.chf(ch, "cosmetics", {}) as Dictionary).get(_slot, "")
	_opt_row("", "Default", str(cur) == "", UiTheme.MUTED, func(): _set_cos(""))
	for c in Content.all("cosmetics"):
		if str(c.get("kind", "")) != _slot:
			continue
		var have = owned.has(c.id)
		var col = Color(c.get("color", "#ffffff"))
		var cid = str(c.id)
		var row = _opt_row("check" if have else "lock", str(c.get("name", c.get("desc", cid))), str(cur) == cid, col if have else UiTheme.LOCKED, func():
			if have:
				_set_cos(cid)
			else:
				flash_msg("Earn it from a Deed", UiTheme.MUTED, "lock"))
		row.tooltip_text = str(c.get("desc", ""))

func _opt_row(icon_name: String, text: String, sel: bool, col: Color, cb: Callable) -> Button:
	var b = UiTheme.icon_button(icon_name if icon_name != "" else "minus", text, cb, Vector2(0, 64), col, true, 18)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_stylebox_override("normal", UiTheme.card_style(col, sel))
	_opts.add_child(b)
	return b

func _set_title(t: String) -> void:
	var ok = sess_call("set_title", [t], null)
	if ok == null:
		UiTheme.api_call("Deeds", "set_title", [ch, t], false)
	if Events.has_signal("cosmetics_changed"):
		Events.emit_signal("cosmetics_changed")
	refresh()

func _set_cos(v: String) -> void:
	var ok = sess_call("set_cosmetic", [_slot, v], null)
	if ok == null:
		UiTheme.api_call("Deeds", "set_cosmetic", [ch, _slot, v], false)
	refresh()

## Preview: cape tint + aura ring colour on the pedestal (in-world visuals are the gameplay code's).
func _apply_preview() -> void:
	if _preview.heroes.is_empty():
		return
	var cos: Dictionary = UiTheme.chf(ch, "cosmetics", {})
	var h = _preview.heroes[0]
	var aura = Content.get_rec("cosmetics", str(cos.get("aura", "")))
	var col = Color(aura.get("color", ch.cls().get("color", "#ffd27a")))
	(h.ring.material_override as StandardMaterial3D).albedo_color = col
	h.light.light_color = col
	var cape = Content.get_rec("cosmetics", str(cos.get("cape_tint", "")))
	if cape.has("color"):
		for mi in h.actor.find_children("*Cape*", "MeshInstance3D", true, false):
			var m = StandardMaterial3D.new()
			m.albedo_color = Color(cape.color)
			(mi as MeshInstance3D).material_override = m
	else:
		for mi in h.actor.find_children("*Cape*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = null
