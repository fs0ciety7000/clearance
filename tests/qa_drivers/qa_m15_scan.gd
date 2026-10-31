## Lecteur de textes visibles de la passe QA M15 (docs/QA.md §18), partagé par
## `qa_m15_day_lang.gd` : relève tous les textes affichés, les classe (FR restant
## en anglais, EN restant en français, clé brute, spécificateur non résolu, « i »
## minuscule) et les ajoute à un fichier de relecture.
extends RefCounted

var fr_only: Dictionary = {}
var en_only: Dictionary = {}
var keys: Dictionary = {}
var seen: Dictionary = {}
var hits: Dictionary = {}
var count: Dictionary = {"FR": 0, "EN": 0, "KEY": 0, "PH": 0, "LOWI": 0}
var dump_path: String = ""
var _dump: FileAccess = null
var _re_ph: RegEx = RegEx.create_from_string("%[-+0-9.]*[sdif]|\\{[a-z_]+\\}")
var _re_lowi: RegEx = RegEx.create_from_string("(^|[\\s,;:\"(])i( |'m |'ve |'ll |'d )")


func _init(p_dump: String = "") -> void:
	dump_path = p_dump
	var fr: Dictionary = Localization.csv_messages(Localization.CSV_PATHS["fr"])
	var en: Dictionary = Localization.csv_messages(Localization.CSV_PATHS["en"])
	for key: String in fr:
		keys[key] = true
		var f: String = str(fr[key]).strip_edges()
		var e: String = str(en.get(key, "")).strip_edges()
		if f == e or e.is_empty():
			continue
		if f.length() >= 4 and not f.contains("%"):
			fr_only[f] = key
			fr_only[f.to_upper()] = key
		if e.length() >= 4 and not e.contains("%"):
			en_only[e] = key
			en_only[e.to_upper()] = key
	for key: String in en:
		fr_only.erase(str(en[key]).strip_edges())
		fr_only.erase(str(en[key]).strip_edges().to_upper())
	for key: String in fr:
		en_only.erase(str(fr[key]).strip_edges())
		en_only.erase(str(fr[key]).strip_edges().to_upper())


func scan(node: Node, tag: String) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if node is Node3D and not (node as Node3D).is_visible_in_tree():
		return
	var texts: PackedStringArray = []
	if node is RichTextLabel:
		texts.append((node as RichTextLabel).get_parsed_text())
	elif node is Label or node is Button or node is Label3D or node is LinkButton:
		texts.append(str(node.get(&"text")))
	if node is Control and not (node as Control).tooltip_text.is_empty():
		texts.append((node as Control).tooltip_text)
	for prop: StringName in Localization.CUSTOM_TEXT_PROPERTIES:
		if prop in node:
			var v: Variant = node.get(prop)
			if v is String and not (v as String).is_empty():
				texts.append(v)
	for text: String in texts:
		if text.strip_edges().is_empty():
			continue
		if not seen.has(text):
			seen[text] = tag
			_dump_line(tag, text)
		classify(node, text, tag)
	for child: Node in node.get_children():
		scan(child, tag)


func classify(node: Object, text: String, tag: String) -> void:
	var english: bool = Localization.is_english()
	var pieces: PackedStringArray = [text.strip_edges()]
	for line: String in text.split("\n", false):
		pieces.append(line.strip_edges())
		for sep: String in [" · ", " — ", " – ", " › "]:
			for part: String in line.split(sep, false):
				pieces.append(part.strip_edges())
	for piece: String in pieces:
		if english and fr_only.has(piece):
			_hit("FR", node, piece, fr_only[piece], tag)
		elif not english and en_only.has(piece):
			_hit("EN", node, piece, en_only[piece], tag)
		if keys.has(piece) and piece.contains("_"):
			_hit("KEY", node, piece, "", tag)
	if _re_ph.search(text) != null:
		_hit("PH", node, text.left(160), "", tag)
	if english and _re_lowi.search(text) != null:
		_hit("LOWI", node, text.left(200), "", tag)


func _hit(kind: String, node: Object, text: String, key: String, tag: String) -> void:
	var sig: String = "%s|%s" % [kind, text]
	if hits.has(sig):
		return
	hits[sig] = true
	count[kind] += 1
	var nm: String = str(node.get(&"name")) if node is Node else "?"
	print("QA15_HIT kind=%s at=%s lang=%s node=%s key=%s text=%s" % [kind, tag, Localization.language(), nm, key,
			text.replace("\n", "⏎").left(220)])


func summary() -> String:
	return "unique_texts=%d fr=%d en=%d key=%d ph=%d lowi=%d" % [seen.size(), count["FR"], count["EN"], count["KEY"],
			count["PH"], count["LOWI"]]


func _dump_line(tag: String, text: String) -> void:
	if dump_path.is_empty():
		return
	if _dump == null:
		var mode: int = FileAccess.READ_WRITE if FileAccess.file_exists(dump_path) else FileAccess.WRITE
		_dump = FileAccess.open(dump_path, mode)
		if _dump == null:
			dump_path = ""
			return
		_dump.seek_end()
	_dump.store_line("%s\t%s\t%s" % [tag, Localization.language(), text.replace("\n", "⏎")])
	_dump.flush()
