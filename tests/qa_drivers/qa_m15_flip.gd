## Passe QA M15 (docs/QA.md §18) — bascule de langue **à chaud** sur un écran
## précis, puis capture. Étend `tools/qa_capture.gd` (mêmes arguments de scène :
## `--day=… --screen=…`, `--qa-scene=… --title=…`, `--epilogue=…`, `--garde=…`) :
## à `--qa-wait` − 4 s la langue passe à `--qa-flip-to` (défaut `en`), à
## `--qa-wait` − 1 s tous les textes visibles sont relus ; ceux qui sont restés
## dans l'ancienne langue (texte de `fr.csv` / `en.csv` dont l'autre colonne
## diffère) sont imprimés, puis la capture est prise.
## Sorties : `QA15F_LEFT lang= node= key= text=` et `QA15F_SUMMARY screen= to= texts= left=`.
## Usage :
##   XDG_DATA_HOME=$(mktemp -d) xvfb-run -a -s "-screen 0 1920x1200x24" godot --path . --rendering-driver opengl3 \
##     --script res://tools/qa_boot.gd -- --qa-node=res://tests/qa_drivers/qa_m15_flip.gd --lang=fr --qa-flip-to=en \
##     --qa-wait=14 --qa-out=/tmp/c.png --day=8 --screen=evening --no-booth --household=demo
extends "res://tools/qa_capture.gd"

var _flip_to: String = "en"
var _flipped: bool = false
var _checked: bool = false
var _other: Dictionary = {}
var _texts: int = 0
var _left: PackedStringArray = []


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-flip-to="):
			_flip_to = arg.trim_prefix("--qa-flip-to=")
	var fr: Dictionary = Localization.csv_messages(Localization.CSV_PATHS["fr"])
	var en: Dictionary = Localization.csv_messages(Localization.CSV_PATHS["en"])
	var source: Dictionary = fr if _flip_to == "en" else en
	var target: Dictionary = en if _flip_to == "en" else fr
	for key: String in source:
		var a: String = str(source[key]).strip_edges()
		var b: String = str(target.get(key, "")).strip_edges()
		if a.length() >= 4 and not a.contains("%") and a != b and not b.is_empty():
			_other[a] = key
			_other[a.to_upper()] = key
	for key: String in target:
		var b2: String = str(target[key]).strip_edges()
		_other.erase(b2)
		_other.erase(b2.to_upper())
	super._ready()


func _process(delta: float) -> void:
	if not _flipped and _t + delta >= _wait - 4.0:
		_flipped = true
		Settings.set_session_value(Settings.KEY_LANGUAGE, _flip_to)
	elif _flipped and not _checked and _t + delta >= _wait - 1.0:
		_checked = true
		_scan(get_tree().root)
		for line: String in _left:
			print("QA15F_LEFT lang=%s %s" % [Localization.language(), line])
		print("QA15F_SUMMARY to=%s texts=%d left=%d" % [_flip_to, _texts, _left.size()])
	super._process(delta)


func _scan(node: Node) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
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
		_texts += 1
		var pieces: PackedStringArray = [text.strip_edges()]
		for line: String in text.split("\n", false):
			pieces.append(line.strip_edges())
			for sep: String in [" · ", " — ", " – ", " › "]:
				for part: String in line.split(sep, false):
					pieces.append(part.strip_edges())
		for piece: String in pieces:
			if _other.has(piece):
				var entry: String = "node=%s key=%s text=%s" % [node.name, _other[piece], piece.left(120)]
				if not _left.has(entry):
					_left.append(entry)
	for child: Node in node.get_children():
		_scan(child)
