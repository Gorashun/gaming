extends ScreenBase
## Credits & licenses (legal requirement: Godot MIT + third-party notices + CC0 asset credits).

func _ready() -> void:
	build("Credits & Licenses")
	var sc = ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(sc)
	var v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	var txt = "WICKWRIGHT — made by an in-house studio of humans and AI agents.\n\n"
	txt += "Art: KayKit Adventurers, Skeletons, Dungeon Remastered and Halloween Bits by Kay Lousberg (kaylousberg.com), CC0. Thank you!\n"
	var credits_path = "res://assets/CREDITS.txt"
	if FileAccess.file_exists(credits_path):
		txt += FileAccess.get_file_as_string(credits_path) + "\n"
	txt += "\nThis game uses Godot Engine, available under the following license:\n\n" + Engine.get_license_text() + "\n\nThird-party components of Godot Engine:\n"
	for info in Engine.get_copyright_info():
		txt += "\n• " + str(info.name)
		for part in info.parts:
			txt += "\n   " + ", ".join(PackedStringArray(part.copyright)) + " — " + str(part.license)
	var lic = Engine.get_license_info()
	txt += "\n\nLicense texts:\n"
	for k in lic:
		txt += "\n--- %s ---\n%s\n" % [k, lic[k]]
	var l = UiTheme.label(txt, 15, UiTheme.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(1100, 0)
	v.add_child(l)
