## Déclaration orale d'un passager (M13, D-139, D-143 ; ARCHITECTURE §12.2).
##
## Une réponse à « Motif ? », « Durée ? », « D'où venez-vous ? » porte des
## **valeurs comparables** : chaque valeur est une **puce** du journal de
## dialogue, sélectionnable en Mode Inspection comme un champ
## (`FieldRef.statement(id)` = `(__statement__, <id>)`).
##
## - Générée **avec le cas** (`Case.statements`, graine du cas, lot B :
##   `StatementGenerator`), jamais tirée de `CaseKey` ; elle existe avant toute
##   question (la violation R43 existe même si la question n'est pas posée).
## - `given` passe à vrai quand la réponse est **émise** dans la session
##   (`InspectionSession`, signal `statement_given`) : une puce n'est
##   résoluble qu'une fois obtenue.
## - Comparaison **au niveau du modèle** (`compare_to`) : vague, provenance et
##   valeur barrée sont toujours INCOMPARABLES ; une durée est un intervalle
##   `Vector2i(min, max)` en jours (discordant si la durée du document est hors
##   de l'intervalle) ; motif et origine par code ; employeur, vaisseau et
##   personne visitée par nom normalisé (sans casse, sans diacritique). Un
##   passager honnête (valeurs lues sur ses propres papiers) ne produit donc
##   jamais de DISCORDANCE.
class_name Statement
extends RefCounted

## Résultat d'une comparaison puce ↔ valeur de document (même ordre que
## `Discrepancy.Result`, sans dépendre de la couche des règles).
enum Match { CONCORDANT, DISCORDANT, INCOMPARABLE }

# Identifiants (`id`) — un par valeur comparable.
const ID_PURPOSE: StringName = &"purpose"
const ID_STAY: StringName = &"stay"
const ID_EMPLOYER: StringName = &"employer"
const ID_ORIGIN: StringName = &"origin"
const ID_PROVENANCE: StringName = &"provenance"
const ID_HOST: StringName = &"host"
const IDS: Array[StringName] = [ID_PURPOSE, ID_STAY, ID_EMPLOYER, ID_ORIGIN, ID_PROVENANCE, ID_HOST]

# Questions (sujets d'interrogatoire) qui produisent des puces.
const QUESTION_PURPOSE: StringName = &"purpose"
const QUESTION_STAY: StringName = &"stay"
const QUESTION_ORIGIN: StringName = &"origin"
## Puces émises par chaque question (M13 §1.4) : « Motif ? » donne motif,
## durée, employeur (J12+, TRAVAIL) et personne visitée (J24+) ; « Durée ? »
## la durée ; « D'où venez-vous ? » l'origine et la provenance. Seules les
## déclarations présentes dans le cas sont émises (le générateur suit le
## calendrier de R43).
const IDS_BY_QUESTION: Dictionary[StringName, Array] = {
	QUESTION_PURPOSE: [ID_PURPOSE, ID_STAY, ID_EMPLOYER, ID_HOST],
	QUESTION_STAY: [ID_STAY],
	QUESTION_ORIGIN: [ID_ORIGIN, ID_PROVENANCE],
}

# Champs comparables (`truth_path` des champs de document).
const PATH_PURPOSE: StringName = &"purpose"
const PATH_STAY: StringName = &"stay_days"
const PATH_EMPLOYER: StringName = &"employer"
const PATH_ORIGIN: StringName = &"faction_id"
## Dérivant : l'origine déclarée est le vaisseau du laissez-passer.
const PATH_VESSEL: StringName = &"vessel"
## Personne visitée ↔ nom imprimé sur la ligne Répondant du permis (ACT3 §2.5).
const PATH_SPONSOR_NAME: StringName = &"sponsor_name"

## Emplacements des cadres de réponse (`line_stmt_frame_*`) → déclaration.
const PLACEHOLDERS: Dictionary[String, StringName] = {
	"motif": ID_PURPOSE,
	"duree": ID_STAY,
	"employeur": ID_EMPLOYER,
	"hote": ID_HOST,
	"origine": ID_ORIGIN,
	"provenance": ID_PROVENANCE,
}
## Emplacement de la valeur barrée d'une auto-correction (VN-2).
const PLACEHOLDER_STRUCK: String = "duree_barree"

var id: StringName = &""
## Question qui produit la déclaration à titre principal (`purpose`, `stay`, `origin`).
var topic: StringName = &""
## Champ de document comparable ; vide = jamais comparé (provenance).
var truth_path: StringName = &""
## Code de motif (`StringName`), intervalle `Vector2i(min, max)` en jours,
## nom canonique (`String`, après table d'alias), `faction_id` ou nom complet.
var value: Variant = null
## Réponse imprécise (VN-1, « quelques jours ») : puce grise, INCOMPARABLE.
var vague: bool = false
## Fragment affiché (`stmt_*`) et ses arguments (`{nom}`, `%d`).
var phrase_key: String = ""
var args: Array = []
## Première valeur dite avant une auto-correction (VN-2) : fragment barré,
## jamais comparable ; vide sinon.
var corrected_from: String = ""
var corrected_args: Array = []
## Réponse émise dans la session (puce obtenue, donc sélectionnable).
var given: bool = false


static func make(p_id: StringName, p_value: Variant, p_phrase_key: String = "", p_args: Array = []) -> Statement:
	var statement: Statement = Statement.new()
	statement.id = p_id
	statement.topic = default_topic(p_id)
	statement.truth_path = default_truth_path(p_id)
	statement.value = p_value
	statement.phrase_key = p_phrase_key
	statement.args = p_args.duplicate()
	return statement


## Durée déclarée : intervalle en jours (`[n, n]` pour une valeur exacte).
static func duration(min_days: int, max_days: int, p_phrase_key: String = "", p_args: Array = []) -> Statement:
	return make(ID_STAY, Vector2i(mini(min_days, max_days), maxi(min_days, max_days)), p_phrase_key, p_args)


## Réponse imprécise (VN-1) : jamais comparable.
static func vague_answer(p_id: StringName, p_phrase_key: String = "") -> Statement:
	var statement: Statement = make(p_id, null, p_phrase_key)
	statement.vague = true
	return statement


static func default_topic(p_id: StringName) -> StringName:
	match p_id:
		ID_STAY:
			return QUESTION_STAY
		ID_ORIGIN, ID_PROVENANCE:
			return QUESTION_ORIGIN
	return QUESTION_PURPOSE


static func default_truth_path(p_id: StringName) -> StringName:
	match p_id:
		ID_PURPOSE:
			return PATH_PURPOSE
		ID_STAY:
			return PATH_STAY
		ID_EMPLOYER:
			return PATH_EMPLOYER
		ID_ORIGIN:
			return PATH_ORIGIN
		ID_HOST:
			return PATH_SPONSOR_NAME
	return &""


## Identifiants des puces émises par une question (vide : aucune).
static func ids_for_question(question: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for statement_id: Variant in IDS_BY_QUESTION.get(question, []):
		result.append(StringName(str(statement_id)))
	return result


func get_ref() -> FieldRef:
	return FieldRef.statement(id)


## Vrai si la puce peut être comparée à un champ (ni vague, ni provenance,
## champ connu, valeur présente). La valeur barrée ne l'est jamais.
func is_comparable() -> bool:
	return not vague and id != ID_PROVENANCE and truth_path != &"" and value != null


func is_corrected() -> bool:
	return not corrected_from.is_empty()


## Durée : vrai si `days` est dans l'intervalle déclaré.
func contains_days(days: int) -> bool:
	if not value is Vector2i:
		return false
	var interval: Vector2i = value
	return days >= interval.x and days <= interval.y


## Compare la puce à la valeur d'un champ de document (déjà choisi par
## l'appelant : `DiscrepancyChecker` / règle R43, lot B). Ne regarde jamais la
## vérité. Les tables (alias d'employeurs, code CT-XX → employeur) sont
## résolues avant l'appel.
func compare_to(document_value: Variant) -> Match:
	if not is_comparable() or document_value == null:
		return Match.INCOMPARABLE
	if value is Vector2i:
		if typeof(document_value) != TYPE_INT:
			return Match.INCOMPARABLE
		var days: int = document_value
		return Match.CONCORDANT if contains_days(days) else Match.DISCORDANT
	var said: String = normalize_text(str(value))
	var written: String = normalize_text(str(document_value))
	if said.is_empty() or written.is_empty():
		return Match.INCOMPARABLE
	return Match.CONCORDANT if said == written else Match.DISCORDANT


## Texte comparable : minuscules, sans diacritique, espaces et tirets
## normalisés (« Tomás Moreno-Lind » == « TOMAS MORENO LIND »).
static func normalize_text(text: String) -> String:
	var folded: String = ""
	for character: String in text.to_lower():
		folded += _FOLD.get(character, character)
	folded = folded.replace("-", " ").replace("_", " ").replace("'", " ").replace("’", " ")
	while folded.contains("  "):
		folded = folded.replace("  ", " ")
	return folded.strip_edges()


const _FOLD: Dictionary[String, String] = {
	"à": "a", "â": "a", "ä": "a", "á": "a", "ã": "a", "å": "a",
	"ç": "c", "č": "c", "ć": "c",
	"é": "e", "è": "e", "ê": "e", "ë": "e", "ě": "e",
	"î": "i", "ï": "i", "í": "i", "ì": "i",
	"ô": "o", "ö": "o", "ó": "o", "ò": "o", "õ": "o", "ø": "o",
	"û": "u", "ü": "u", "ú": "u", "ù": "u", "ů": "u",
	"ÿ": "y", "ý": "y", "ñ": "n", "ń": "n", "š": "s", "ś": "s", "ž": "z", "ź": "z", "ż": "z",
	"ł": "l", "ř": "r", "œ": "oe", "æ": "ae", "ß": "ss",
}


## Texte du fragment : `translate.call(phrase_key)` puis arguments (jetons
## `{…}` remplacés dans l'ordre ; sans jeton, formatage `%`). Sans clé :
## la valeur brute.
func fragment_text(translate: Callable) -> String:
	if phrase_key.is_empty():
		return _value_text()
	return format_fragment(str(translate.call(phrase_key)), translated_args(args, translate))


## M15 : arguments de lieu donnés par clé (`stmt_place_*`, provenance) traduits
## dans la langue courante avant formatage ; les autres (noms propres,
## employeurs, nombres) restent tels quels.
const PLACE_KEY_PREFIX: String = "stmt_place_"


static func translated_args(p_args: Array, translate: Callable) -> Array:
	var out: Array = []
	for arg: Variant in p_args:
		if arg is String and (arg as String).begins_with(PLACE_KEY_PREFIX):
			out.append(str(translate.call(arg)))
		else:
			out.append(arg)
	return out


## Texte de la valeur barrée (VN-2), vide sans auto-correction.
func struck_text(translate: Callable) -> String:
	if corrected_from.is_empty():
		return ""
	return format_fragment(str(translate.call(corrected_from)), translated_args(corrected_args, translate))


## Fragment selon sa place dans la phrase (finition M13) : majuscule en début
## de phrase, minuscule au milieu (« Le commerce, pour cinq jours. ») ;
## `struck` = la valeur barrée. La casse porte sur le **gabarit** traduit,
## jamais sur les arguments (noms propres) ; une valeur brute n'est jamais
## mise en minuscule.
func cased_fragment_text(translate: Callable, sentence_start: bool, struck: bool = false) -> String:
	var key: String = corrected_from if struck else phrase_key
	if key.is_empty():
		if struck:
			return ""
		return apply_case(_value_text(), true) if sentence_start else _value_text()
	return format_fragment(apply_case(str(translate.call(key)), sentence_start),
			translated_args(corrected_args if struck else args, translate))


## Casse de la première lettre d'un gabarit : majuscule si `sentence_start`,
## sinon minuscule quand le premier mot est en casse de phrase (« Je »,
## « J'arrive », « Ça » ; pas un sigle). Un gabarit qui commence par un
## argument (`%s`, `{…}`) ou une ponctuation (‹tessar›) est laissé tel quel.
static func apply_case(text: String, sentence_start: bool) -> String:
	if text.is_empty() or not _is_letter(text[0]):
		return text
	if sentence_start:
		return text[0].to_upper() + text.substr(1)
	if text.length() > 1 and _is_letter(text[1]) and text[1] != text[1].to_lower():
		return text
	return text[0].to_lower() + text.substr(1)


## Vrai si la suite d'un cadre commence une phrase : texte vide, ou dernier
## signe non blanc `.`, `!`, `?` (éventuellement suivi d'un guillemet `›`,
## `»`, `"`). Les points de suspension et deux-points ne terminent pas.
static func is_sentence_start(prefix: String) -> bool:
	var trimmed: String = prefix.strip_edges(false, true)
	if trimmed.is_empty():
		return true
	var last: String = trimmed[trimmed.length() - 1]
	if last in ["›", "»", "\""] and trimmed.length() > 1:
		last = trimmed[trimmed.length() - 2]
	return last in [".", "!", "?"]


static func _is_letter(c: String) -> bool:
	return c.to_upper() != c.to_lower()


static func format_fragment(text: String, p_args: Array) -> String:
	if p_args.is_empty():
		return text
	var result: String = text
	var used: int = 0
	while used < p_args.size():
		var start: int = result.find("{")
		var stop: int = result.find("}", start) if start >= 0 else -1
		if start < 0 or stop < 0:
			break
		result = result.substr(0, start) + str(p_args[used]) + result.substr(stop + 1)
		used += 1
	if used == 0 and result.contains("%"):
		return result % p_args
	return result


## Découpe un cadre de réponse en segments : `{"text": …}` ou
## `{"statement": id, "struck": bool, "sentence_start": bool}` (l'UI en fait
## des puces, lot C ; texte de la puce : `cased_fragment_text(translate,
## sentence_start, struck)`). Un emplacement inconnu reste du texte.
static func segments(frame_text: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var rest: String = frame_text
	while not rest.is_empty():
		var prefix: String = frame_text.substr(0, frame_text.length() - rest.length())
		var start: int = rest.find("{")
		var stop: int = rest.find("}", start) if start >= 0 else -1
		if start < 0 or stop < 0:
			result.append({"text": rest})
			break
		if start > 0:
			result.append({"text": rest.substr(0, start)})
		var token: String = rest.substr(start + 1, stop - start - 1)
		var opening: bool = is_sentence_start(prefix + rest.substr(0, start))
		if token == PLACEHOLDER_STRUCK:
			result.append({"statement": ID_STAY, "struck": true, "sentence_start": opening})
		elif PLACEHOLDERS.has(token):
			result.append({"statement": PLACEHOLDERS[token], "struck": false, "sentence_start": opening})
		else:
			result.append({"text": rest.substr(start, stop - start + 1)})
		rest = rest.substr(stop + 1)
	return result


## Réplique composée (texte brut : sous-titre, tests de longueur ≤ 90) : le
## cadre `frame_text` dont les emplacements reçoivent les fragments des
## déclarations, à la casse de leur place (`cased_fragment_text`) ; un
## emplacement sans déclaration reste vide.
static func compose(frame_text: String, statements: Array[Statement], translate: Callable) -> String:
	var text: String = ""
	for segment: Dictionary in segments(frame_text):
		if segment.has("text"):
			text += str(segment["text"])
			continue
		var statement: Statement = find_in(statements, StringName(str(segment["statement"])))
		if statement == null:
			continue
		text += statement.cased_fragment_text(translate, bool(segment["sentence_start"]), bool(segment["struck"]))
	return text


static func find_in(statements: Array[Statement], p_id: StringName) -> Statement:
	for statement: Statement in statements:
		if statement != null and statement.id == p_id:
			return statement
	return null


func copy() -> Statement:
	var result: Statement = Statement.new()
	result.id = id
	result.topic = topic
	result.truth_path = truth_path
	result.value = value
	result.vague = vague
	result.phrase_key = phrase_key
	result.args = args.duplicate()
	result.corrected_from = corrected_from
	result.corrected_args = corrected_args.duplicate()
	result.given = given
	return result


## Dictionnaire stable (`CaseSerializer`).
func serialize() -> Dictionary:
	var shown: Variant = value
	if value is Vector2i:
		var interval: Vector2i = value
		shown = [interval.x, interval.y]
	elif value is StringName:
		shown = String(value)
	return {
		"id": String(id), "topic": String(topic), "truth_path": String(truth_path), "value": shown,
		"vague": vague, "phrase_key": phrase_key, "args": args.map(func(arg: Variant) -> String: return str(arg)),
		"corrected_from": corrected_from,
	}


func _value_text() -> String:
	if value is Vector2i:
		var interval: Vector2i = value
		return str(interval.x) if interval.x == interval.y else "%d–%d" % [interval.x, interval.y]
	return str(value) if value != null else ""


func _to_string() -> String:
	return "Statement(%s=%s%s)" % [id, _value_text(), " vague" if vague else ""]
