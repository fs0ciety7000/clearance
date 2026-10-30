## Relecture des répliques scénarisées « motif / durée / origine » (M13,
## docs/M13.md §1.12, D-154 ; B78) — outil de QA et du Scénariste.
##
## Les réponses scénarisées restent en **prose libre** (aucune puce, jamais
## épinglables) ; l'outil repère celles qui pourraient **sembler** contredire
## les documents du cas, au cas où un joueur refuserait « sur parole » :
## - durée dite (« Dix jours », « trois semaines »…) hors de la durée du permis
##   (surcharge `stay_days` du cas) ou dite alors que la durée est **tirée**
##   par le générateur (à vérifier : la réplique peut contredire un permis tiré) ;
## - motif dit (« Commerce », « travailler »…) différent du motif imposé ;
## - origine dite (« Je suis de Cérès »…) différente de l'origine imposée.
## Les cas qui déclarent `statements` (puces) sont contrôlés à part par R43.
##
## QA-068 — **réponses composées** (cadre + puces, `Statement.compose`)
## réellement générées sur `--campaigns=N` campagnes (défaut 8) × J4 → J30 :
## rejet des tournures fautives (`BAD_PHRASINGS` : « pour je ne sais pas
## encore », « Quelques jours. Pas un jour de plus. », « J'arrive de Tycho.
## Mais je suis de Tycho », « chez le Bureau »…) et des incohérences de
## structure (durée vague « du travail » sans motif TRAVAIL), ligne
## `TOURNURE` ; comptées comme contradictions.
##
## Usage : `godot --headless --script res://tools/qa_statements_audit.gd [-- --strict] [--campaigns=N]`
## Sortie : une ligne par réplique relevée (`CONTRADICTION`, `À VÉRIFIER`,
## `TOURNURE`) ; code 0, ou 1 avec `--strict` s'il reste une contradiction.
extends SceneTree

const CSV_PATH: String = "res://data/i18n/fr.csv"
const SUFFIXES: PackedStringArray = ["purpose", "stay", "origin"]
## Durées dites → intervalle (jours) ; « %d jours » est lu à part.
const DURATION_WORDS: Dictionary[String, Vector2i] = {
	"un jour": Vector2i(1, 1), "une journée": Vector2i(1, 1), "deux jours": Vector2i(2, 2),
	"trois jours": Vector2i(3, 3), "quatre jours": Vector2i(4, 4), "cinq jours": Vector2i(5, 5),
	"six jours": Vector2i(6, 6), "sept jours": Vector2i(7, 7), "huit jours": Vector2i(8, 8),
	"dix jours": Vector2i(9, 11), "douze jours": Vector2i(12, 12), "quatorze jours": Vector2i(14, 14),
	"quinze jours": Vector2i(14, 16), "vingt jours": Vector2i(20, 20), "trente jours": Vector2i(30, 30),
	"une semaine": Vector2i(6, 8), "deux semaines": Vector2i(12, 16), "trois semaines": Vector2i(18, 24),
	"un mois": Vector2i(26, 34), "deux mois": Vector2i(55, 65), "trois mois": Vector2i(80, 100),
	"six mois": Vector2i(170, 190), "un an": Vector2i(350, 380),
}
const PURPOSE_WORDS: Dictionary[String, StringName] = {
	"commerce": &"trade", "vendre": &"trade", "travail": &"work", "travailler": &"work", "contrat": &"work",
	"visite familiale": &"family_visit", "voir ma": &"family_visit", "voir mon": &"family_visit",
	"je rentre": &"return", "rentrer": &"return", "transit": &"transit", "correspondance": &"transit",
	"mission officielle": &"diplomatic",
}
const ORIGIN_WORDS: Dictionary[String, StringName] = {
	"je suis de tycho": &"tyc", "je suis de cérès": &"cer", "je suis de la terre": &"ter",
	"je suis de tharsis": &"thr", "je suis d'ici": &"hal",
}

## Relues par le Scénariste (2026-10-29) : la durée dite ne porte pas sur le
## séjour (attente, passé, autre personne) — jamais une contradiction.
const REVIEWED: PackedStringArray = ["sc84_miner_purpose", "sc86_kaito_purpose", "sc60_margaux_stay",
		"sc63_dmitri_purpose", "sc78_mazur_origin"]

## QA-068 : tournures fautives d'une réponse composée (motifs FR).
const BAD_PHRASINGS: PackedStringArray = [
	"pour (je|ça|aussi|le temps) ",
	"^(Quelques jours|Le temps du contrat|Je ne sais pas encore|Aussi longtemps qu'on voudra de moi|Ça dépend du travail)\\. (C'est ce qu'on m'a accordé|Pas un jour de plus)",
	"(Quelques jours|Le temps du contrat|Je ne sais pas encore|Aussi longtemps qu'on voudra de moi|Ça dépend du travail)(, pas plus|, normalement|, le temps du chantier)",
	"J'arrive de (\\S+( \\S+)?)\\. Mais je suis de \\1,",
	"chez (le|les) ",
	"Le temps du contrat, le temps du chantier",
	"\\.\\.(?!\\.)|,,| ,| \\.",
]
const DEFAULT_CAMPAIGNS: int = 8

var _texts: Dictionary[String, String] = {}
var _contradictions: int = 0
var _checks: int = 0


func _init() -> void:
	_texts = _read_csv(CSV_PATH)
	var strict: bool = OS.get_cmdline_user_args().has("--strict")
	var data: DataCatalog = DataCatalog.load_from()
	var cases: Array[ScriptedCaseDef] = []
	var days: Array[int] = []
	days.assign(data.days.keys())
	days.sort()
	for n: int in days:
		for scripted: ScriptedCaseDef in data.get_day(n).scripted_cases:
			if scripted != null and scripted.dialogue_id != &"":
				cases.append(scripted)
				_audit(n, scripted)
	var campaigns: int = DEFAULT_CAMPAIGNS
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--campaigns="):
			campaigns = maxi(arg.trim_prefix("--campaigns=").to_int(), 0)
	var composed: int = _audit_composed(data, days, campaigns)
	print("qa_statements_audit : %d répliques relues, %d réponses composées, %d contradiction(s)" % [
			_checks, composed, _contradictions])
	quit(1 if strict and _contradictions > 0 else 0)


## QA-068 : réponses composées réellement générées (passagers générés et
## scénarisés à puces) ; renvoie le nombre de réponses uniques relues.
func _audit_composed(data: DataCatalog, days: Array[int], campaigns: int) -> int:
	var patterns: Array[RegEx] = []
	for pattern: String in BAD_PHRASINGS:
		patterns.append(RegEx.create_from_string(pattern))
	var translate: Callable = func(k: String) -> String: return _texts.get(k, k)
	var tables: StatementTablesDef = data.statement_tables
	var seen: Dictionary[String, bool] = {}
	for campaign: int in campaigns:
		for n: int in days:
			if n < 4:
				continue
			var builder: CaseBuilder = CaseBuilder.new(data, data.get_day(n), SeededRng.day_seed(campaign + 1, n))
			builder.presentation_minute = 12 * 60
			for g: GeneratedCase in builder.build_day():
				if g == null or g.case.statements.is_empty():
					continue
				_check_structure("J%d %s" % [n, g.case.case_id], g.case, tables)
				for q: StringName in g.case.statement_frames:
					var line: String = Statement.compose(translate.call(g.case.statement_frames[q]),
							g.case.statements_for_question(q), translate)
					if seen.has(line):
						continue
					seen[line] = true
					for rx: RegEx in patterns:
						if rx.search(line) != null:
							_contradictions += 1
							print("TOURNURE      J%d %s %s : « %s »" % [n, g.case.case_id, g.case.statement_frames[q], line])
							break
	return seen.size()


## QA-068 : durée vague « du travail » dite sans le motif TRAVAIL.
func _check_structure(where: String, c: Case, tables: StatementTablesDef) -> void:
	var stay: Statement = c.get_statement(Statement.ID_STAY)
	var purpose: Statement = c.get_statement(Statement.ID_PURPOSE)
	if tables == null or stay == null or purpose == null or not stay.vague:
		return
	if tables.vague_work_keys.has(stay.phrase_key) and StringName(str(purpose.value)) != Passenger.PURPOSE_WORK:
		_contradictions += 1
		print("TOURNURE      %s : « %s » avec le motif %s" % [where, _texts.get(stay.phrase_key, stay.phrase_key), purpose.value])


func _audit(day_number: int, scripted: ScriptedCaseDef) -> void:
	for suffix: String in SUFFIXES:
		var keys: PackedStringArray = ["%s_%s" % [scripted.dialogue_id, suffix]]
		for variant: ConditionalKey in scripted.line_variants:
			if variant != null and variant.replaces == suffix:
				keys.append(variant.key)
		for key: String in keys:
			if not _texts.has(key):
				continue
			_checks += 1
			var text: String = _texts[key].to_lower()
			var where: String = "J%d %s %s" % [day_number, scripted.id, key]
			if not scripted.statements.is_empty() or REVIEWED.has(key):
				continue
			_check_duration(where, text, scripted)
			_check_purpose(where, text, scripted)
			_check_origin(where, text, scripted)


func _check_duration(where: String, text: String, scripted: ScriptedCaseDef) -> void:
	var said: Array[Vector2i] = []
	for words: String in DURATION_WORDS:
		if text.contains(words):
			said.append(DURATION_WORDS[words])
	var digits: RegEx = RegEx.create_from_string("(\\d+) jours")
	for found: RegExMatch in digits.search_all(text):
		var n: int = found.get_string(1).to_int()
		said.append(Vector2i(n, n))
	if said.is_empty():
		return
	# Né·e-Halcyon : aucun permis, aucune durée à contredire.
	if scripted.passenger_overrides.get(&"faction_id", &"") == &"hal":
		return
	var stay: Variant = scripted.passenger_overrides.get(&"stay_days", null)
	if stay == null:
		print("À VÉRIFIER    %s : durée dite, durée du permis tirée — « %s »" % [where, _texts[where.get_slice(" ", 2)]])
		return
	var days: int = stay
	for span: Vector2i in said:
		if days >= span.x and days <= span.y:
			return
	_contradictions += 1
	print("CONTRADICTION %s : permis %d j — « %s »" % [where, days, _texts[where.get_slice(" ", 2)]])


func _check_purpose(where: String, text: String, scripted: ScriptedCaseDef) -> void:
	var forced: Variant = scripted.passenger_overrides.get(&"purpose", null)
	if forced == null:
		return
	var said: Array[StringName] = []
	for words: String in PURPOSE_WORDS:
		if text.begins_with(words) or text.contains(". " + words) or text.contains("‹ " + words):
			said.append(PURPOSE_WORDS[words])
	if said.is_empty() or said.has(StringName(str(forced))):
		return
	_contradictions += 1
	print("CONTRADICTION %s : motif %s — « %s »" % [where, forced, _texts[where.get_slice(" ", 2)]])


func _check_origin(where: String, text: String, scripted: ScriptedCaseDef) -> void:
	var forced: Variant = scripted.passenger_overrides.get(&"faction_id", null)
	if forced == null:
		return
	for words: String in ORIGIN_WORDS:
		if text.contains(words) and ORIGIN_WORDS[words] != StringName(str(forced)):
			_contradictions += 1
			print("CONTRADICTION %s : origine %s — « %s »" % [where, forced, _texts[where.get_slice(" ", 2)]])
			return


static func _read_csv(path: String) -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return result
	file.get_csv_line()
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() >= 2:
			result[row[0]] = row[1]
	return result
