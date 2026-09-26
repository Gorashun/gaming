extends ScreenBase
## Credits & licenses (legal: Godot MIT + third-party notices + asset credits from res://assets/CREDITS.txt).
## Sections are collapsible so the long license texts don't bury the thank-yous.

var _list: VBoxContainer

func _ready() -> void:
	if screen_id == "":
		screen_id = "credits"
	build("Credits & Licenses", "credits")
	var sc = ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	sc.add_child(_list)
	var head = VBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	_list.add_child(head)
	var t = UiTheme.label("WICKWRIGHT", 48, UiTheme.GOLD, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(t)
	var s = UiTheme.label("Carry the Light — made by a small studio of humans and AI helpers", 20, UiTheme.EMBER)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(s)
	var credits = "Art: KayKit Adventurers, Skeletons, Dungeon Remastered, Halloween Bits and Medieval Hexagon by Kay Lousberg (kaylousberg.com), CC0.\nKenney asset kits (kenney.nl), CC0.\nFonts: Cinzel, Nunito and Andika — SIL Open Font License 1.1.\nUI icons: drawn procedurally for this game.\nThank you!"
	var path = "res://assets/CREDITS.txt"
	if FileAccess.file_exists(path):
		credits = FileAccess.get_file_as_string(path).strip_edges()
	_section("Credits", credits, true)
	var fonts = ""
	for fam in ["Cinzel", "Nunito", "Andika"]:
		var fp = "res://assets/fonts/%s/OFL.txt" % fam
		if FileAccess.file_exists(fp):
			fonts += "=== %s ===\n%s\n\n" % [fam, FileAccess.get_file_as_string(fp).strip_edges()]
	if fonts != "":
		_section("Font licenses (SIL OFL 1.1)", fonts, false)
	_section("Godot Engine", "This game uses Godot Engine, available under the following license:\n\n" + Engine.get_license_text(), false)
	var parts = ""
	for info in Engine.get_copyright_info():
		parts += "• " + str(info.name) + "\n"
		for part in info.parts:
			parts += "   " + ", ".join(PackedStringArray(part.copyright)) + " — " + str(part.license) + "\n"
	_section("Third-party components of Godot", parts, false)
	var lic = Engine.get_license_info()
	var txt = ""
	for k in lic:
		txt += "--- %s ---\n%s\n\n" % [k, lic[k]]
	_section("License texts", txt, false)

func _section(title: String, text: String, open: bool) -> void:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.09, 0.07, 0.12, 0.9), Color(0.35, 0.28, 0.2), 12, 2))
	_list.add_child(p)
	var v = VBoxContainer.new()
	p.add_child(v)
	var l = UiTheme.label(text, 17, UiTheme.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(900, 0)
	l.visible = open
	var b = UiTheme.icon_button("minus" if open else "plus", title, func(): pass, Vector2(420, 64), UiTheme.GOLD, true, 22)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func():
		l.visible = not l.visible
		(b.find_child("Icon", true, false) as TextureRect).texture = UiTheme.icon("minus" if l.visible else "plus"))
	v.add_child(b)
	v.add_child(l)
