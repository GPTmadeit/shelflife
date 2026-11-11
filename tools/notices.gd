extends SceneTree
## Writes NOTICES.txt for the release zips: the game's credits, the font
## licenses and the Godot Engine's license with the notices of every library
## built into it, as those licenses ask.
## usage: godot --headless --path . --script tools/notices.gd -- <out.txt>
## Every failure quits with code 1: a script error alone would leave Godot
## running forever.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		_die("usage: godot --headless --path . --script tools/notices.gd -- <out.txt>")
		return
	var t := PackedStringArray()
	t.append("SHELF LIFE: THIRD-PARTY NOTICES")
	t.append("")
	t.append("Fonts: Lilita One by Juan Montoreano and Nunito by Vernon Adams, under the")
	t.append("SIL Open Font License 1.1 (full texts below).")
	t.append("")
	t.append("Made with the Godot Engine (https://godotengine.org). Its license and the")
	t.append("licenses of the libraries built into it follow the fonts.")
	for f in ["OFL-LilitaOne.txt", "OFL-Nunito.txt"]:
		var text := FileAccess.get_file_as_string("res://assets/fonts/" + f).strip_edges()
		if text == "":
			_die("can't read assets/fonts/" + f)
			return
		t.append("")
		t.append("==== %s ====" % f.get_basename().trim_prefix("OFL-"))
		t.append(text)
	t.append("")
	t.append("==== Godot Engine ====")
	t.append(Engine.get_license_text().strip_edges())
	t.append("")
	t.append("==== Components of the Godot Engine ====")
	for info in Engine.get_copyright_info():
		t.append("")
		t.append(str(info.get("name", "")))
		for part in info.get("parts", []):
			for c in part.get("copyright", []):
				t.append("  Copyright " + str(c))
			t.append("  License: " + str(part.get("license", "")))
	var licenses: Dictionary = Engine.get_license_info()
	for name in licenses.keys():
		t.append("")
		t.append("==== License: %s ====" % name)
		t.append(str(licenses[name]).strip_edges())
	var out := FileAccess.open(args[0], FileAccess.WRITE)
	if out == null:
		_die("can't write %s (%s)" % [args[0], error_string(FileAccess.get_open_error())])
		return
	out.store_string("\n".join(t) + "\n")
	out.close()
	quit()


func _die(msg: String) -> void:
	printerr("notices: ", msg)
	quit(1)
