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
## - Réactions du passager (`passenger_reaction_triggered`) : comparaison de
##   visages discordante, confrontation, verdict. Elles ne dépendent **jamais**
##   de la vérité cachée (`CaseKey`), seulement de ce que le joueur a constaté.
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
			EventBus.interrogation_answered.emit(topic, LINE_VISOR_REMOVED if removed else LINE_VISOR_NONE)
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
## (constatée dans cette session) → réplique dédiée + NERVOUS ; sinon ANGRY.
func _confront_about(topic: StringName) -> void:
	var body: String = String(topic).trim_prefix(ABOUT_PREFIX)
	var reason: String = body.get_slice(DOC_SEPARATOR, 0)
	var doc: StringName = StringName(body.get_slice(DOC_SEPARATOR, 1)) if body.contains(DOC_SEPARATOR) else &""
	if has_confirmed(reason, doc):
		EventBus.interrogation_answered.emit(topic, scripted_line("about_" + reason, LINE_ABOUT_PREFIX + reason))
		EventBus.passenger_reaction_triggered.emit(PassengerReaction.Kind.NERVOUS)
	else:
		EventBus.interrogation_answered.emit(topic, LINE_CONFRONT_ANGRY)
		EventBus.passenger_reaction_triggered.emit(PassengerReaction.Kind.ANGRY)


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
	for d: Discrepancy in confirmed:
		if d.reason_key.trim_prefix("disc_") != reason:
			continue
		if doc == &"" or (d.a != null and d.a.document_id == doc) or (d.b != null and d.b.document_id == doc):
			return true
	return false


func _already_confirmed(result: Discrepancy) -> bool:
	for known: Discrepancy in confirmed:
		if (known.a.equals(result.a) and known.b.equals(result.b)) or (known.a.equals(result.b) and known.b.equals(result.a)):
			return true
	return false
