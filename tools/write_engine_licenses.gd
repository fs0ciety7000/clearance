## Notices de licence du moteur Godot et de ses composants tiers, à joindre à
## chaque archive distribuée (obligation MIT / « Complying with licenses »).
## Le texte vient du binaire Godot lui-même (`Engine.get_*`) : il correspond
## toujours à la version qui a servi à l'export.
##
## Usage (appelé par tools/export_all.sh) :
##   godot --headless --script res://tools/write_engine_licenses.gd -- --out=<fichier>
extends SceneTree


func _init() -> void:
	var out_path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
	if out_path.is_empty():
		push_error("write_engine_licenses: --out=<fichier> requis")
		quit(1)
		return
	var lines: PackedStringArray = []
	var info: Dictionary = Engine.get_version_info()
	lines.append("Godot Engine %s — https://godotengine.org" % info.get("string", ""))
	lines.append("")
	lines.append(Engine.get_license_text())
	lines.append("")
	lines.append("=" .repeat(78))
	lines.append("Composants tiers inclus dans le moteur / Third-party components")
	lines.append("=" .repeat(78))
	for component: Dictionary in Engine.get_copyright_info():
		lines.append("")
		lines.append("- %s" % component.get("name", ""))
		for part: Dictionary in component.get("parts", []):
			for holder: String in part.get("copyright", PackedStringArray()):
				lines.append("  © %s" % holder)
			lines.append("  License: %s" % part.get("license", ""))
	var licenses: Dictionary = Engine.get_license_info()
	var names: Array = licenses.keys()
	names.sort()
	for license_name: String in names:
		lines.append("")
		lines.append("-" .repeat(78))
		lines.append("License: %s" % license_name)
		lines.append("-" .repeat(78))
		var text: String = licenses[license_name]
		lines.append(text)
	var file: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		push_error("write_engine_licenses: écriture de %s impossible" % out_path)
		quit(1)
		return
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("write_engine_licenses : %s" % out_path)
	quit(0)
