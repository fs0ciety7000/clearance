## M15 lot B — traduction anglaise (`data/i18n/en.csv`, D-213, D-214,
## `docs/LOCALIZATION.md`) : mêmes clés que `fr.csv` dans le même ordre, aucune
## valeur vide, placeholders identiques (`%s`, `%d`, `%02d`, `{motif}`, `\n`,
## BBCode) en nombre, ordre et type, Tessar (‹…›) jamais traduit, légendes
## `cin_*` ≤ 70 caractères, répliques ≤ 90, ressource importée (`en.en.translation`)
## fidèle au CSV, et déclarations composées (M13) en anglais correct : casse de
## début de phrase, jamais de « i » minuscule, longueur ≤ 90 quand le français
## tient.
extends GutTest

const FR_PATH: String = "res://data/i18n/fr.csv"
const EN_PATH: String = "res://data/i18n/en.csv"
const EN_TRANSLATION: String = "res://data/i18n/en.en.translation"
const TABLES_PATH: String = "res://data/statements/statements.tres"
const CAPTION_MAX: int = 70
const LINE_MAX: int = 90
## Répliques sous-titrées (mêmes familles que les tests M12–M14 côté français).
const LINE_KEY: String = "^(sc\\d+[a-z]?_|line_|bark_|react_|ans_|okonkwo_j|sato_j|pa_)"
const NON_LINE: String = "(note|label|desc|title|_doc|_item|_form$)"
const PLACEHOLDER: String = "%[-+0#]*\\d*(\\.\\d+)?[sdif%]|\\{[a-z_0-9]*\\}|\\\\n|\\[/?(b|i|u|s|color|font|font_size|url|center|right|img|outline_color|outline_size|bgcolor|fgcolor|wave|shake|pulse|code|lb|rb)(=[^\\]]*)?\\]"
const TESSAR: String = "‹[^›]*›"

var _fr_keys: PackedStringArray = []
var _en_keys: PackedStringArray = []
var _fr: Dictionary[String, String] = {}
var _en: Dictionary[String, String] = {}
var _en_header: PackedStringArray = []


func before_all() -> void:
	_fr_keys = _read(FR_PATH, _fr, PackedStringArray())
	var header: PackedStringArray = []
	_en_keys = _read(EN_PATH, _en, header)
	_en_header = header


## Lit un CSV de traduction : clés dans l'ordre, valeurs dans `into`, en-tête
## dans `header`.
static func _read(path: String, into: Dictionary[String, String], header: PackedStringArray) -> PackedStringArray:
	var keys: PackedStringArray = []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return keys
	header.append_array(file.get_csv_line())
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() < 2 or row[0].is_empty():
			continue
		keys.append(row[0])
		into[row[0]] = row[1]
	return keys


static func _matches(pattern: String, text: String) -> PackedStringArray:
	var result: PackedStringArray = []
	for m: RegExMatch in RegEx.create_from_string(pattern).search_all(text):
		result.append(m.get_string())
	return result


# --- Fichier ---------------------------------------------------------------

func test_header_and_columns() -> void:
	assert_true(FileAccess.file_exists(EN_PATH), "en.csv présent")
	assert_eq(_en_header, PackedStringArray(["keys", "en"]), "en-tête keys,en")
	var file: FileAccess = FileAccess.open(EN_PATH, FileAccess.READ)
	var bad: PackedStringArray = []
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() > 0 and not (row.size() == 1 and row[0].is_empty()) and row.size() != 2:
			bad.append(row[0])
	assert_eq(bad, PackedStringArray(), "deux colonnes par ligne")


func test_same_keys_same_order() -> void:
	assert_gt(_fr_keys.size(), 4000, "fr.csv lu")
	assert_eq(_en_keys.size(), _fr_keys.size(), "autant de clés qu'en français")
	var first_diff: String = ""
	for i: int in mini(_fr_keys.size(), _en_keys.size()):
		if _fr_keys[i] != _en_keys[i]:
			first_diff = "%d : %s ≠ %s" % [i, _fr_keys[i], _en_keys[i]]
			break
	assert_eq(first_diff, "", "mêmes clés, même ordre")
	var missing: PackedStringArray = []
	for key: String in _fr_keys:
		if not _en.has(key):
			missing.append(key)
	assert_eq(missing, PackedStringArray(), "clés FR absentes de en.csv")


func test_no_empty_value() -> void:
	var empty: PackedStringArray = []
	for key: String in _en_keys:
		if _en[key].strip_edges().is_empty():
			empty.append(key)
	assert_eq(empty, PackedStringArray(), "valeurs vides")


func test_no_untranslated_french() -> void:
	# Mots-outils français qui ne doivent pas survivre hors noms propres et Tessar.
	var french: RegEx = RegEx.create_from_string("(?i)\\b(le|la|les|des|une|avec|pour|vous|nous|est|sont|dans|sur|pas)\\b")
	var allowed: RegEx = RegEx.create_from_string("Basse-Marée|Long-Ruban|Bureau de Continuité|Autorité de Transit|Arbitrage de Continuité|Commission de Rééquilibrage|Dispensaire de Tycho|DISPENSAIRE DE TYCHO|Délégation tharsienne|Prospection indépendante|Équipage indépendant|Hydroponie Ceres-Verte|Valcourt-Hsu Logistique|Meridian Biosystèmes|Ondine Synaptique|Banque Aurel|Kessler-Ashe Orbital")
	var leftovers: PackedStringArray = []
	for key: String in _en_keys:
		var text: String = RegEx.create_from_string(TESSAR).sub(_en[key], "", true)
		text = allowed.sub(text, "", true)
		if french.search(text) != null:
			leftovers.append("%s : %s" % [key, _en[key]])
	assert_eq(leftovers, PackedStringArray(), "texte français résiduel")


# --- Placeholders, Tessar, longueurs ------------------------------------------

func test_placeholders_identical() -> void:
	var bad: PackedStringArray = []
	for key: String in _fr_keys:
		if not _en.has(key):
			continue
		if _matches(PLACEHOLDER, _fr[key]) != _matches(PLACEHOLDER, _en[key]):
			bad.append("%s %s ≠ %s" % [key, _matches(PLACEHOLDER, _fr[key]), _matches(PLACEHOLDER, _en[key])])
	assert_eq(bad, PackedStringArray(), "placeholders identiques en nombre, ordre et type")


func test_tessar_untranslated() -> void:
	var bad: PackedStringArray = []
	for key: String in _fr_keys:
		if _en.has(key) and _matches(TESSAR, _fr[key]) != _matches(TESSAR, _en[key]):
			bad.append(key)
	assert_eq(bad, PackedStringArray(), "segments Tessar ‹…› identiques au français")
	# « › » sert aussi de séparateur de menu (« Pause › Options ») : mêmes
	# comptes qu'en français.
	var unbalanced: PackedStringArray = []
	for key: String in _fr_keys:
		if _en.has(key) and (_en[key].count("‹") != _fr[key].count("‹") or _en[key].count("›") != _fr[key].count("›")):
			unbalanced.append(key)
	assert_eq(unbalanced, PackedStringArray(), "chevrons et séparateurs comme en français")


func test_cinematic_captions_fit() -> void:
	var too_long: PackedStringArray = []
	var count: int = 0
	for key: String in _en_keys:
		if key.begins_with("cin_"):
			count += 1
			if _en[key].length() > CAPTION_MAX:
				too_long.append("%s (%d)" % [key, _en[key].length()])
	assert_gt(count, 70, "légendes cin_* présentes")
	assert_eq(too_long, PackedStringArray(), "légendes cin_* ≤ 70 caractères")


func test_subtitled_lines_fit() -> void:
	var line_key: RegEx = RegEx.create_from_string(LINE_KEY)
	var non_line: RegEx = RegEx.create_from_string(NON_LINE)
	var too_long: PackedStringArray = []
	for key: String in _fr_keys:
		if not _en.has(key) or line_key.search(key) == null or non_line.search(key) != null:
			continue
		if _fr[key].length() <= LINE_MAX and _en[key].length() > LINE_MAX:
			too_long.append("%s (%d)" % [key, _en[key].length()])
	assert_eq(too_long, PackedStringArray(), "répliques ≤ 90 caractères")
	var pa_long: PackedStringArray = []
	for key: String in _en_keys:
		if key.begins_with(PaLineTable.KEY_PREFIX) and _en[key].length() > PaLineTable.MAX_CHARS:
			pa_long.append(key)
	assert_eq(pa_long, PackedStringArray(), "annonces du Hall ≤ 90 caractères")


# --- Import Godot ----------------------------------------------------------------

func test_translation_resource_imported() -> void:
	assert_true(ResourceLoader.exists(EN_TRANSLATION), "en.en.translation importé (godot --headless --import)")
	var translation: Translation = load(EN_TRANSLATION) as Translation
	assert_not_null(translation, "ressource Translation")
	if translation == null:
		return
	assert_eq(translation.locale, "en", "locale en")
	# Import compressé (`OptimizedTranslation`) : pas de comptage, on interroge
	# chaque clé.
	var differ: PackedStringArray = []
	for key: String in _en_keys:
		if String(translation.get_message(StringName(key))) != _en[key].c_unescape():
			differ.append(key)
			if differ.size() > 10:
				break
	assert_eq(differ, PackedStringArray(), "messages importés = CSV (à jour : relancer l'import)")


# --- Déclarations composées (M13) -----------------------------------------------

func _compose(lang: Dictionary[String, String], frame_key: String, statements: Array[Statement]) -> String:
	var translate: Callable = func(key: String) -> String: return lang.get(key, key)
	return Statement.compose(lang.get(frame_key, frame_key), statements, translate)


## Défauts d'anglais d'une réplique composée : début en minuscule, « i »
## minuscule, phrase qui suit un point sans majuscule, mot doublé.
static func _english_defects(line: String) -> PackedStringArray:
	var defects: PackedStringArray = []
	var plain: String = RegEx.create_from_string(TESSAR + "\\s*").sub(line, "", true).strip_edges()
	if not plain.is_empty() and plain[0] != plain[0].to_upper():
		defects.append("début minuscule")
	if RegEx.create_from_string("(^|[^\\w'])i('|\\b)").search(plain) != null:
		defects.append("« i » minuscule")
	if RegEx.create_from_string("[.!?] +[a-z]").search(plain) != null:
		defects.append("minuscule après un point")
	if RegEx.create_from_string("(?i)\\b(\\w+) \\1\\b").search(plain) != null:
		defects.append("mot doublé")
	return defects


func test_composed_statements_read_as_english() -> void:
	var tables: StatementTablesDef = load(TABLES_PATH) as StatementTablesDef
	assert_not_null(tables, "tables de déclarations")
	if tables == null:
		return
	var purposes: Array[Statement] = []
	for purpose: StringName in tables.purpose_keys:
		for key: String in tables.purpose_keys[purpose]:
			purposes.append(Statement.make(Statement.ID_PURPOSE, purpose, key))
	var stays: Array[Statement] = []
	var vague_stays: Array[Statement] = []
	for key: String in tables.duration_keys:
		stays.append(Statement.make(Statement.ID_STAY, Vector2i(1, 1), key))
	for n: int in tables.exact_duration_keys:
		stays.append(Statement.make(Statement.ID_STAY, Vector2i(n, n), tables.exact_duration_keys[n]))
	stays.append(Statement.make(Statement.ID_STAY, Vector2i(14, 14), tables.exact_key, [14]))
	for key: String in tables.vague_keys:
		vague_stays.append(Statement.make(Statement.ID_STAY, null, key))
	var all_stays: Array[Statement] = []
	all_stays.append_array(stays)
	all_stays.append_array(vague_stays)
	var stay_frame_keys: PackedStringArray = []
	stay_frame_keys.append_array(tables.stay_frames)
	stay_frame_keys.append_array(tables.stay_frames_vague)
	var defects: PackedStringArray = []
	var too_long: PackedStringArray = []
	var frames: PackedStringArray = []
	for faction: StringName in tables.frames:
		frames.append_array(tables.frames[faction])
	var employers: Array[Statement] = [
		Statement.make(Statement.ID_EMPLOYER, "Valcourt-Hsu Logistique", tables.employer_key, ["Valcourt-Hsu Logistique"]),
		Statement.make(Statement.ID_EMPLOYER, "Bureau de Continuité", "stmt_employer_au", ["Bureau"]),
	]
	var hosts: Array[Statement] = []
	for relation: StringName in tables.host_keys:
		hosts.append(Statement.make(Statement.ID_HOST, "Ana Moreno-Lind", tables.host_keys[relation], ["Ana Moreno-Lind"]))
	var checked: int = 0
	for purpose: Statement in purposes:
		for stay: Statement in all_stays:
			var vague: bool = vague_stays.has(stay)
			var pools: Array[Dictionary] = [{"frames": frames, "extra": [] as Array[Statement]}]
			# Cadres spécialisés : employeur avec TRAVAIL, personne visitée avec
			# VISITE FAMILIALE (comme `StatementGenerator`).
			if purpose.value == Passenger.PURPOSE_WORK:
				for employer: Statement in employers:
					pools.append({"frames": tables.work_frames, "extra": [employer] as Array[Statement]})
			if purpose.value == Passenger.PURPOSE_FAMILY_VISIT:
				for host: Statement in hosts:
					pools.append({"frames": tables.visit_frames, "extra": [host] as Array[Statement]})
			for pool: Dictionary in pools:
				for frame_key: String in pool["frames"]:
					if vague and tables.vague_unfit_frames.has(frame_key):
						continue
					var statements: Array[Statement] = [purpose, stay]
					statements.append_array(pool["extra"])
					checked += _check_line(frame_key, statements, defects, too_long)
			if not vague:
				var corrected: Statement = stay.copy()
				corrected.corrected_from = tables.duration_keys[0] if stay.phrase_key != tables.duration_keys[0] else tables.duration_keys[1]
				for frame_key: String in tables.correction_frames:
					checked += _check_line(frame_key, [purpose, corrected] as Array[Statement], defects, too_long)
	for stay: Statement in all_stays:
		for frame_key: String in stay_frame_keys:
			checked += _check_line(frame_key, [stay] as Array[Statement], defects, too_long)
	var provenances: Array[Statement] = [Statement.make(Statement.ID_PROVENANCE, null, tables.provenance_shuttle_key)]
	for place: String in tables.provenance_places:
		provenances.append(Statement.make(Statement.ID_PROVENANCE, null, tables.provenance_place_key, [place]))
	for faction: StringName in tables.origin_keys:
		var origin: Statement = Statement.make(Statement.ID_ORIGIN, faction, tables.origin_keys[faction],
				["Long-Ruban"] if faction == &"drv" else [])
		var origin_frames: PackedStringArray = tables.origin_frames_drv if faction == &"drv" else tables.origin_frames_plain
		for frame_key: String in origin_frames:
			checked += _check_line(frame_key, [origin] as Array[Statement], defects, too_long)
		for provenance: Statement in provenances:
			for frame_key: String in tables.origin_frames:
				checked += _check_line(frame_key, [origin, provenance] as Array[Statement], defects, too_long)
	assert_gt(checked, 1000, "combinaisons composées")
	assert_eq(defects, PackedStringArray(), "déclarations composées en anglais correct")
	assert_eq(too_long, PackedStringArray(), "réplique ≤ 90 quand le français tient")


func _check_line(frame_key: String, statements: Array[Statement], defects: PackedStringArray,
		too_long: PackedStringArray) -> int:
	var en: String = _compose(_en, frame_key, statements)
	var fr: String = _compose(_fr, frame_key, statements)
	var found: PackedStringArray = _english_defects(en)
	if not found.is_empty() and defects.size() < 20:
		defects.append("%s → « %s » (%s)" % [frame_key, en, ", ".join(found)])
	if fr.length() <= LINE_MAX and en.length() > LINE_MAX and too_long.size() < 20:
		too_long.append("%s → %d « %s »" % [frame_key, en.length(), en])
	return 1


func test_statement_fragments_never_start_with_i() -> void:
	# `Statement.apply_case` met en minuscule le premier mot d'un fragment au
	# milieu d'une phrase : un fragment anglais ne commence donc jamais par « I ».
	var bad: PackedStringArray = []
	for key: String in _en_keys:
		if key.begins_with("stmt_") and not key.ends_with("_sub") and RegEx.create_from_string("^I\\b").search(_en[key]) != null:
			bad.append(key)
	assert_eq(bad, PackedStringArray(), "fragments stmt_* sans « I » initial")
