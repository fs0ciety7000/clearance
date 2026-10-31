## Passe QA M15 (docs/QA.md §18) — campagne réelle (`qa_m14_campaign.gd`,
## `day.tscn`, bot `--autoplay`) **lue à l'écran** dans une langue :
## tous les textes visibles (`Label`, `Button`, `RichTextLabel`, `Label3D`,
## infobulles, propriétés `_draw` de `Localization.CUSTOM_TEXT_PROPERTIES`)
## sont relevés toutes les `SCAN_FRAMES` images, découpés en pièces comme
## `test_m15_hot_language`, et classés :
##   - FR  : pièce égale à un texte de `fr.csv` dont l'anglais diffère (langue EN) ;
##   - EN  : pièce égale à un texte de `en.csv` dont le français diffère (langue FR) ;
##   - KEY : pièce égale à une clé de `fr.csv` (clé brute) ;
##   - PH  : spécificateur ou emplacement non résolu (`%s`, `%d`, `{motif}`…) ;
##   - LOWI: « i » isolé en minuscule (casse composée des déclarations, LOCALIZATION §6).
## `--qa-flip=S` : bascule FR ↔ EN toutes les S secondes de jeu (shift, soirée,
## cinématique, écrans) ; contrôle 3 images après chaque bascule.
## `--qa-dump=/chemin.txt` : tous les textes uniques vus (relecture humaine).
## Rien n'est modifié dans le jeu : lecture seule de l'arbre.
## Sorties : QA15_HIT kind= day= node= text=  ·  QA15_FLIP day= to= screen= left=  ·  QA15_SUMMARY …
## Usage :
##   XDG_DATA_HOME=$(mktemp -d) godot --headless --script res://tools/qa_boot.gd -- --lang=en \
##     --qa-node=res://tests/qa_drivers/qa_m15_lang.gd --autoplay --qa-seed=3 --qa-profile=loyal \
##     --qa-credits=3000 --qa-speed=10 [--qa-flip=40] [--qa-dump=/tmp/en.txt] [--qa-story]
extends "res://tests/qa_drivers/qa_m14_campaign.gd"

const SCAN_FRAMES: int = 15

static var _fr_only: Dictionary = {}
static var _en_only: Dictionary = {}
static var _keys: Dictionary = {}

var _seen: Dictionary = {}
var _hits: Dictionary = {}
var _hit_count: Dictionary = {"FR": 0, "EN": 0, "KEY": 0, "PH": 0, "LOWI": 0}
var _frame: int = 0
var _flip_every: float = 0.0
var _flip_t: float = 0.0
var _flip_pending: int = -1
var _flips: int = 0
var _flip_bad: int = 0
var _dump_path: String = ""
var _re_ph: RegEx = RegEx.create_from_string("%[-+0-9.]*[sdif]|\\{[a-z_]+\\}")
var _re_lowi: RegEx = RegEx.create_from_string("(^|[\\s,;:\"(])i( |'m |'ve |'ll |'d )")


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-flip="):
			_flip_every = arg.trim_prefix("--qa-flip=").to_float()
		elif arg.begins_with("--qa-dump="):
			_dump_path = arg.trim_prefix("--qa-dump=")
	if _keys.is_empty():
		var fr: Dictionary = Localization.csv_messages(Localization.CSV_PATHS["fr"])
		var en: Dictionary = Localization.csv_messages(Localization.CSV_PATHS["en"])
		for key: String in fr:
			_keys[key] = true
			var f: String = str(fr[key]).strip_edges()
			var e: String = str(en.get(key, "")).strip_edges()
			if f == e or e.is_empty():
				continue
			if f.length() >= 4 and not f.contains("%"):
				_fr_only[f] = key
				_fr_only[f.to_upper()] = key
			if e.length() >= 4 and not e.contains("%"):
				_en_only[e] = key
				_en_only[e.to_upper()] = key
		# Un texte présent dans les deux colonnes (ex. un nom) n'est d'aucune langue.
		for key: String in en:
			var e2: String = str(en[key]).strip_edges()
			_fr_only.erase(e2)
			_fr_only.erase(e2.to_upper())
		for key: String in fr:
			var f2: String = str(fr[key]).strip_edges()
			_en_only.erase(f2)
			_en_only.erase(f2.to_upper())
	print("QA15_START lang=%s flip=%.0f" % [Localization.language(), _flip_every])
	super._ready()


func _process(delta: float) -> void:
	super._process(delta)
	if _done:
		return
	_frame += 1
	if _flip_pending >= 0:
		_flip_pending -= 1
		if _flip_pending == 0:
			_flip_pending = -1
			_check_flip()
		return
	if _flip_every > 0.0:
		_flip_t += delta
		if _flip_t >= _flip_every:
			_flip_t = 0.0
			var to: String = Localization.LANG_FR if Localization.is_english() else Localization.LANG_EN
			Settings.set_session_value(Settings.KEY_LANGUAGE, to)
			_flips += 1
			_flip_pending = 3
			return
	if _frame % SCAN_FRAMES == 0:
		_scan(get_tree().root, false)


func _check_flip() -> void:
	var before: int = _hit_count["FR"] + _hit_count["EN"]
	_scan(get_tree().root, true)
	var left: int = _hit_count["FR"] + _hit_count["EN"] - before
	var scene: DayScene = get_tree().current_scene as DayScene
	var where: String = "?"
	if scene != null and is_instance_valid(scene):
		where = scene.screen.get_class() if scene.screen != null and is_instance_valid(scene.screen) else "booth"
		if scene.screen != null and is_instance_valid(scene.screen) and scene.screen.get_script() != null:
			where = str((scene.screen.get_script() as Script).get_global_name())
		if scene.has_node("CinematicScreen") or _find_cin(scene) != null:
			where += "+cinematic"
	if left > 0:
		_flip_bad += 1
	print("QA15_FLIP n=%d day=%d to=%s screen=%s left=%d" % [_flips, GameState.current_day, Localization.language(), where, left])


func _find_cin(node: Node) -> Node:
	if node is CinematicScreen:
		return node
	for child: Node in node.get_children():
		var found: Node = _find_cin(child)
		if found != null:
			return found
	return null


func _scan(node: Node, after_flip: bool) -> void:
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
		if not _seen.has(text):
			_seen[text] = GameState.current_day
			_dump_line(text)
		_classify(node, text, after_flip)
	for child: Node in node.get_children():
		_scan(child, after_flip)


func _classify(node: Node, text: String, after_flip: bool) -> void:
	var english: bool = Localization.is_english()
	for piece: String in _pieces(text):
		if piece.is_empty():
			continue
		if english and _fr_only.has(piece):
			_hit("FR", node, piece, "%s" % _fr_only[piece], after_flip)
		elif not english and _en_only.has(piece):
			_hit("EN", node, piece, "%s" % _en_only[piece], after_flip)
		if _keys.has(piece) and piece.contains("_"):
			_hit("KEY", node, piece, "", after_flip)
	if _re_ph.search(text) != null:
		_hit("PH", node, text.left(160), "", after_flip)
	if english and _re_lowi.search(text) != null:
		_hit("LOWI", node, text.left(200), "", after_flip)


func _hit(kind: String, node: Node, text: String, key: String, after_flip: bool) -> void:
	var sig: String = "%s|%s|%s" % [kind, node.name, text]
	if _hits.has(sig):
		return
	_hits[sig] = true
	_hit_count[kind] += 1
	var path: String = str(node.get_path()).replace("/root/", "")
	if path.length() > 90:
		path = "…" + path.right(89)
	print("QA15_HIT kind=%s day=%d lang=%s flip=%s node=%s key=%s text=%s" % [kind, GameState.current_day,
			Localization.language(), after_flip, path, key, text.replace("\n", "⏎").left(220)])


static func _pieces(text: String) -> PackedStringArray:
	var pieces: PackedStringArray = [text.strip_edges()]
	for line: String in text.split("\n", false):
		pieces.append(line.strip_edges())
		for sep: String in [" · ", " — ", " – ", " › "]:
			for part: String in line.split(sep, false):
				pieces.append(part.strip_edges())
	return pieces


func _finish(code: int) -> void:
	print("QA15_SUMMARY lang=%s unique_texts=%d fr=%d en=%d key=%d ph=%d lowi=%d flips=%d flips_with_leftovers=%d" % [
			Localization.language(), _seen.size(), _hit_count["FR"], _hit_count["EN"], _hit_count["KEY"],
			_hit_count["PH"], _hit_count["LOWI"], _flips, _flip_bad])
	if _dump != null:
		_dump.close()
		_dump = null
	super._finish(code)


var _dump: FileAccess = null


## Ajout immédiat (une campagne coupée par `timeout` garde ce qu'elle a vu).
func _dump_line(text: String) -> void:
	if _dump_path.is_empty():
		return
	if _dump == null:
		var mode: int = FileAccess.READ_WRITE if FileAccess.file_exists(_dump_path) else FileAccess.WRITE
		_dump = FileAccess.open(_dump_path, mode)
		if _dump == null:
			_dump_path = ""
			return
		_dump.seek_end()
	_dump.store_line("J%02d\t%s\t%s" % [GameState.current_day, Localization.language(), text.replace("\n", "⏎")])
	_dump.flush()


## L'écran de fin est lu (épilogue, tableau) avant que le pilote de campagne ne termine.
func _on_end(scene: DayScene, end: EndScreen) -> void:
	_scan(get_tree().root, false)
	for line: String in end.epilogue_lines():
		if not _seen.has(line):
			_seen[line] = GameState.current_day
			_dump_line(line)
		_classify(end, line, false)
	super._on_end(scene, end)
