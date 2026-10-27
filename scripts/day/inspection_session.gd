## Session d'inspection d'un cas (ARCHITECTURE §8) — service de jour, M4 minimal.
##
## - Mode Inspection : `discrepancy_check_requested(a, b)` →
##   `DiscrepancyChecker.check()` → `discrepancy_checked(result)` ; les
##   discordances confirmées sont mémorisées (preuves du verdict).
## - Interrogatoire minimal (`interrogation_requested(topic)`, sujets de
##   `InterrogationTopics` côté UI) : `purpose` / `stay` / `origin` (réponse
##   tirée de ce que *dit* le passager présenté), `remove_visor` (D-021),
##   `about_<raison>[:<doc>]` = confrontation à une discordance confirmée
##   (NERVOUS si elle a bien été constatée, ANGRY sinon), `confront` (générique).
##   La réplique dépend de la **famille** de la discordance (visage, N° ID, nom,
##   naissance, validité, document manquant, émetteur, origine, santé, autre ;
##   `family_of()`) : `line_about_<famille>_<n>` si elle est constatée (gêne,
##   excuse plausible ou mensonge), `line_about_<famille>_outrage_<n>` sinon
##   (indignation). Variante tirée de la graine du cas (déterministe).
## - Réactions du passager (`passenger_reaction_triggered`) : comparaison de
##   visages discordante, confrontation, verdict. Elles ne dépendent **jamais**
##   de la vérité cachée (`CaseKey`), seulement de ce que le joueur a constaté.
## - `remove_visor` : `LINE_VISOR_NONE` s'il n'y a rien à retirer, sinon la
##   réplique de retrait (`<dialogue_id>_visor` ou `LINE_VISOR_REMOVED`) — tout
##   autre `line_key` que `LINE_VISOR_NONE` signifie « visière retirée ».
## - M5 : répliques des passagers scénarisés — si le cas porte une étiquette de
##   dialogue (`ScriptedCaseDef.dialogue_id`) et que la clé
##   `<dialogue_id>_<sujet>` existe dans `fr.csv`, elle remplace la réplique
##   générique (`sc02_hurried_mother_about_expired`…). Une réplique de
##   supplication déclenche NERVOUS.
## Ne connaît pas la clé de réponse ; le DayController la garde.
class_name InspectionSession
extends Node

## Sujets d'interrogatoire reconnus en M4 (le Scénariste les étend en M5).
const TOPIC_REMOVE_VISOR: StringName = &"remove_visor"
const TOPIC_CONFRONT: StringName = &"confront"
const TOPIC_PURPOSE: StringName = &"purpose"
const TOPIC_STAY: StringName = &"stay"
const TOPIC_ORIGIN: StringName = &"origin"
const ABOUT_PREFIX: String = "about_"
const DOC_SEPARATOR: String = ":"
## Au-delà, la réponse « séjour » est longue.
const SHORT_STAY_DAYS: int = 7
## Répliques (clés de traduction, sous-titrées par l'UI).
const LINE_VISOR_REMOVED: String = "line_visor_removed"
const LINE_VISOR_NONE: String = "line_visor_none"
const LINE_CONFRONT_NERVOUS: String = "line_confront_nervous"
const LINE_CONFRONT_ANGRY: String = "line_confront_angry"
const LINE_GENERIC_SHRUG: String = "line_generic_shrug"
const LINE_PURPOSE_PREFIX: String = "line_purpose_"
const LINE_STAY_SHORT: String = "line_stay_short"
const LINE_STAY_LONG: String = "line_stay_long"
const LINE_ORIGIN_PREFIX: String = "line_origin_"
const LINE_ABOUT_PREFIX: String = "line_about_"
const LINE_OUTRAGE_INFIX: String = "outrage_"
## Variantes cherchées par famille (`_1` … `_MAX_VARIANTS`).
const MAX_VARIANTS: int = 6
## Familles de discordance (suffixes des répliques `line_about_<famille>_…`).
const FAMILY_FACE: String = "face"
const FAMILY_ID_NUMBER: String = "id_number"
const FAMILY_NAME: String = "name"
const FAMILY_BIRTH: String = "birth"
const FAMILY_VALIDITY: String = "validity"
const FAMILY_MISSING: String = "missing"
const FAMILY_ISSUER: String = "issuer"
const FAMILY_ORIGIN: String = "origin"
const FAMILY_HEALTH: String = "health"
const FAMILY_OTHER: String = "other"
const FAMILIES: Array[String] = [FAMILY_FACE, FAMILY_ID_NUMBER, FAMILY_NAME, FAMILY_BIRTH, FAMILY_VALIDITY,
		FAMILY_MISSING, FAMILY_ISSUER, FAMILY_ORIGIN, FAMILY_HEALTH, FAMILY_OTHER]
## `truth_path` d'un champ → famille de réplique.
const TRUTH_PATH_FAMILIES: Dictionary[StringName, String] = {
	&"appearance": FAMILY_FACE,
	&"citizen_id": FAMILY_ID_NUMBER,
	&"document.serial": FAMILY_ID_NUMBER,
	&"family_name": FAMILY_NAME,
	&"given_name": FAMILY_NAME,
	&"birth_date": FAMILY_BIRTH,
	&"document.expiry_date": FAMILY_VALIDITY,
	&"document.issue_date": FAMILY_VALIDITY,
	&"document.issuer_id": FAMILY_ISSUER,
	&"faction_id": FAMILY_ORIGIN,
	&"health_status": FAMILY_HEALTH,
}

var case: Case = null
var ctx: RuleContext = null
var active: bool = false
var inspection_mode: bool = false
## Temps depuis `documents_presented` (vaut 0 avant).
var elapsed_sec: float = 0.0
var documents_presented: bool = false
var confirmed: Array[Discrepancy] = []
var questions_asked: Array[StringName] = []


func _ready() -> void:
	EventBus.documents_presented.connect(_on_documents_presented)
	EventBus.discrepancy_check_requested.connect(_on_discrepancy_check_requested)
	EventBus.interrogation_requested.connect(_on_interrogation_requested)
	EventBus.inspection_mode_changed.connect(_on_inspection_mode_changed)


## Démarre l'inspection d'un nouveau cas (appelé par le DayController).
func begin(p_case: Case, p_ctx: RuleContext) -> void:
	case = p_case
	ctx = p_ctx
	active = true
	elapsed_sec = 0.0
	documents_presented = false
	confirmed.clear()
	questions_asked.clear()


## Termine la session au tampon : complète le verdict (preuves, questions,
## durée) et déclenche la réaction de sortie.
func end(verdict: Verdict) -> void:
	if verdict != null:
		if verdict.flagged.is_empty():
			verdict.flagged = confirmed.duplicate()
		if verdict.questions_asked.is_empty():
			verdict.questions_asked = questions_asked.duplicate()
		if verdict.elapsed_sec <= 0.0:
			verdict.elapsed_sec = elapsed_sec
		EventBus.passenger_reaction_triggered.emit(reaction_for_verdict(verdict.kind))
	active = false


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if active and documents_presented:
		elapsed_sec += delta


static func reaction_for_verdict(kind: VerdictKind.Kind) -> PassengerReaction.Kind:
	match kind:
		VerdictKind.Kind.APPROVE:
			return PassengerReaction.Kind.RELIEVED
		VerdictKind.Kind.DETAIN:
			return PassengerReaction.Kind.NERVOUS
	return PassengerReaction.Kind.ANGRY


func _on_documents_presented(case_id: StringName) -> void:
	if active and case != null and case_id == case.case_id:
		documents_presented = true


func _on_inspection_mode_changed(enabled: bool) -> void:
	inspection_mode = enabled


func _on_discrepancy_check_requested(a: FieldRef, b: FieldRef) -> void:
	if not active or case == null:
		return
	var result: Discrepancy = DiscrepancyChecker.check(case, a, b, ctx)
	if result.confirmed and not _already_confirmed(result):
		confirmed.append(result)
	EventBus.discrepancy_checked.emit(result)
	# Visage ↔ photo discordant : le passager se sait observé (UI_FLOW §4.9).
	if result.confirmed and (a.is_passenger_face() or b.is_passenger_face()):
		EventBus.passenger_reaction_triggered.emit(PassengerReaction.Kind.NERVOUS)


func _on_interrogation_requested(topic: StringName) -> void:
	if not active or case == null or not documents_presented:
		return
	if not questions_asked.has(topic):
		questions_asked.append(topic)
	match topic:
		TOPIC_REMOVE_VISOR:
			# Le cas est muté avant la réponse : le booth relit l'apparence.
			var removed: bool = case.remove_visor()
			# Passager scénarisé : sa réplique (`<dialogue_id>_visor`, ex. `sc04_mira_visor`).
			EventBus.interrogation_answered.emit(topic, scripted_line("visor", LINE_VISOR_REMOVED) if removed else LINE_VISOR_NONE)
		TOPIC_CONFRONT:
			if confirmed.is_empty():
				EventBus.interrogation_answered.emit(topic, LINE_CONFRONT_ANGRY)
				EventBus.passenger_reaction_triggered.emit(PassengerReaction.Kind.ANGRY)
			else:
				EventBus.interrogation_answered.emit(topic, scripted_line("confront", LINE_CONFRONT_NERVOUS))
				EventBus.passenger_reaction_triggered.emit(PassengerReaction.Kind.NERVOUS)
		TOPIC_PURPOSE:
			EventBus.interrogation_answered.emit(topic, scripted_line("purpose", LINE_PURPOSE_PREFIX + String(case.passenger_presented.purpose)))
		TOPIC_STAY:
			var short: bool = case.passenger_presented.stay_days <= SHORT_STAY_DAYS
			EventBus.interrogation_answered.emit(topic, scripted_line("stay", LINE_STAY_SHORT if short else LINE_STAY_LONG))
		TOPIC_ORIGIN:
			EventBus.interrogation_answered.emit(topic, scripted_line("origin", LINE_ORIGIN_PREFIX + String(case.passenger_presented.faction_id)))
		_:
			if String(topic).begins_with(ABOUT_PREFIX):
				_confront_about(topic)
			else:
				EventBus.interrogation_answered.emit(topic, LINE_GENERIC_SHRUG)
				EventBus.passenger_reaction_triggered.emit(PassengerReaction.Kind.SHRUG)


## `about_<raison>[:<doc>]` : confrontation à une discordance précise. Réelle
## (constatée dans cette session) → réplique de sa famille + NERVOUS ; sinon
## indignation + ANGRY. Un passager scénarisé garde sa réplique dédiée.
func _confront_about(topic: StringName) -> void:
	var body: String = String(topic).trim_prefix(ABOUT_PREFIX)
	var reason: String = body.get_slice(DOC_SEPARATOR, 0)
	var doc: StringName = StringName(body.get_slice(DOC_SEPARATOR, 1)) if body.contains(DOC_SEPARATOR) else &""
	var found: Discrepancy = find_confirmed(reason, doc)
	if found != null:
		var family: String = family_of(found, case, ctx)
		EventBus.interrogation_answered.emit(topic, scripted_line("about_" + reason, about_line(family, true)))
		EventBus.passenger_reaction_triggered.emit(PassengerReaction.Kind.NERVOUS)
	else:
		EventBus.interrogation_answered.emit(topic, about_line(family_of_reason(reason), false))
		EventBus.passenger_reaction_triggered.emit(PassengerReaction.Kind.ANGRY)


## Réplique d'une famille de discordance : `line_about_<famille>_<n>` (réelle)
## ou `line_about_<famille>_outrage_<n>` (non constatée) ; variante choisie par
## la graine du cas. Repli : famille « autre », puis réplique générique.
func about_line(family: String, real: bool) -> String:
	for fam: String in [family, FAMILY_OTHER]:
		var stem: String = about_stem(fam, real)
		var count: int = 0
		while count < MAX_VARIANTS and UiText.has(stem + str(count + 1)):
			count += 1
		if count > 0:
			var case_seed: int = case.case_seed if case != null else 0
			return stem + str(posmod(hash("%d|%s" % [case_seed, fam]), count) + 1)
	return LINE_CONFRONT_NERVOUS if real else LINE_CONFRONT_ANGRY


static func about_stem(family: String, real: bool) -> String:
	return LINE_ABOUT_PREFIX + family + "_" + ("" if real else LINE_OUTRAGE_INFIX)


## Famille d'une discordance constatée (visible seulement : jamais `CaseKey`).
static func family_of(d: Discrepancy, p_case: Case, p_ctx: RuleContext) -> String:
	if d == null:
		return FAMILY_OTHER
	var reason: String = d.reason_key.trim_prefix("disc_")
	match reason:
		"face_mismatch":
			return FAMILY_FACE
		"expired":
			return FAMILY_VALIDITY
		"rule_violated":
			var rule_ref: FieldRef = d.a if d.a != null and d.a.is_rule() else d.b
			var other: FieldRef = d.b if rule_ref == d.a else d.a
			var rule: Rule = p_ctx.find_active_rule(rule_ref.field_id) if p_ctx != null and rule_ref != null else null
			if rule is RequireDocumentRule:
				return FAMILY_MISSING
			if rule is IssuerAllowedRule:
				return FAMILY_ISSUER
			if rule is OriginIdBlockRule:
				return FAMILY_ORIGIN
			if rule is DocumentNotExpiredRule:
				return FAMILY_VALIDITY
			if rule is PortraitMatchRule:
				return FAMILY_FACE
			if rule is FieldValueAllowedRule:
				var allowed: FieldValueAllowedRule = rule as FieldValueAllowedRule
				return family_of_truth_path(allowed.truth_path)
			return _family_of_ref(other, p_case)
	# Deux champs de documents (`mismatch`) : la donnée comparée.
	var family: String = _family_of_ref(d.a, p_case)
	return family if family != FAMILY_OTHER else _family_of_ref(d.b, p_case)


## Famille déductible du seul sujet (discordance non constatée).
static func family_of_reason(reason: String) -> String:
	match reason:
		"face_mismatch":
			return FAMILY_FACE
		"expired":
			return FAMILY_VALIDITY
	return FAMILY_OTHER


static func family_of_truth_path(path: StringName) -> String:
	return TRUTH_PATH_FAMILIES.get(path, FAMILY_OTHER)


static func _family_of_ref(ref: FieldRef, p_case: Case) -> String:
	if ref == null:
		return FAMILY_OTHER
	if ref.is_passenger_face():
		return FAMILY_FACE
	var field: FieldDef = p_case.get_field_def(ref) if p_case != null else null
	if field == null:
		return FAMILY_OTHER
	if field.kind == FieldDef.FieldKind.PORTRAIT:
		return FAMILY_FACE
	return family_of_truth_path(field.truth_path)


## Réplique dédiée du passager scénarisé (`<dialogue_id>_<suffixe>`) si elle
## existe, sinon `fallback`.
func scripted_line(suffix: String, fallback: String) -> String:
	if case == null:
		return fallback
	for tag: StringName in case.dialogue_tags:
		var key: String = "%s_%s" % [tag, suffix]
		if UiText.has(key):
			return key
	return fallback


## Vrai si une discordance confirmée a cette raison (`expired`, `mismatch`…)
## et touche le document `doc` (si précisé).
func has_confirmed(reason: String, doc: StringName = &"") -> bool:
	return find_confirmed(reason, doc) != null


## Première discordance confirmée de cette raison touchant `doc` (null sinon).
func find_confirmed(reason: String, doc: StringName = &"") -> Discrepancy:
	for d: Discrepancy in confirmed:
		if d.reason_key.trim_prefix("disc_") != reason:
			continue
		if doc == &"" or (d.a != null and d.a.document_id == doc) or (d.b != null and d.b.document_id == doc):
			return d
	return null


func _already_confirmed(result: Discrepancy) -> bool:
	for known: Discrepancy in confirmed:
		if (known.a.equals(result.a) and known.b.equals(result.b)) or (known.a.equals(result.b) and known.b.equals(result.a)):
			return true
	return false
