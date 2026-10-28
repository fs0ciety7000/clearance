## `EXPIRED_DOCUMENT` (GDD §6) : la date d'expiration passe à aujourd'hui − 1…N
## jours (J1–J3 : 1–10, « presque valide » ; ensuite 1–30). Pour une règle
## d'ancienneté (`max_age_days`, bio-scan R12), c'est l'émission qui recule.
## Cible : un document présent dont la règle d'expiration est active (Acte II :
## ou dont la `RequireDocumentRule` exige un document **valide**, R24 / R28).
## Paramètres : `document_id`, `expired_days`.
class_name ExpiredDocumentInjector
extends AnomalyInjector

const EARLY_DAYS_MAX: int = 10
const LATE_DAYS_MAX: int = 30
const EARLY_DAY_LIMIT: int = 3
const ISSUE_PATH: StringName = &"document.issue_date"
const EXPIRY_PATH: StringName = &"document.expiry_date"


func get_kind() -> AnomalyType.Kind:
	return AnomalyType.Kind.EXPIRED_DOCUMENT


func inject(state: InjectionState) -> Anomaly:
	var by_document: Dictionary[StringName, int] = {} # document → âge maximal (0 = expiration)
	for rule: Rule in state.get_rule_set().rules:
		var rule_document: StringName = &""
		var max_age: int = 0
		if rule is DocumentNotExpiredRule and rule.get_detectable_anomalies().has(get_kind()):
			var expiry_rule: DocumentNotExpiredRule = rule
			rule_document = expiry_rule.document_id
			max_age = expiry_rule.max_age_days
		elif rule is RequireDocumentRule and (rule as RequireDocumentRule).require_valid:
			var require: RequireDocumentRule = rule
			if not require.applies_to(state.case):
				continue
			rule_document = require.document_id
		else:
			continue
		if by_document.has(rule_document) or state.case.get_own_document(rule_document) == null:
			continue
		var issue_field: StringName = field_for(state.case, rule_document, ISSUE_PATH)
		var expiry_field: StringName = field_for(state.case, rule_document, EXPIRY_PATH)
		if expiry_field == &"" or not state.is_free(rule_document, expiry_field):
			continue
		if issue_field != &"" and not state.is_free(rule_document, issue_field):
			continue
		by_document[rule_document] = max_age
	var candidates: Array[StringName] = []
	candidates.assign(by_document.keys())
	candidates = state.prefer_focus_documents(state.filter_documents(candidates))
	if candidates.is_empty():
		return null
	var document_id: StringName = candidates[state.rng.randi_range(0, candidates.size() - 1)]
	var rule_max_age: int = by_document[document_id]
	var doc: DocumentInstance = state.case.get_own_document(document_id)
	var max_days: int = EARLY_DAYS_MAX if state.get_day_number() <= EARLY_DAY_LIMIT else LATE_DAYS_MAX
	var days: int = maxi(state.param_int(&"expired_days", state.rng.randi_range(1, max_days)), 1)
	var today: int = state.ctx.today
	var duration: int = doc.expiry_date - doc.issue_date
	var anomaly: Anomaly
	if rule_max_age > 0:
		var old_issue: int = doc.issue_date
		doc.issue_date = today - rule_max_age - (days - 1)
		doc.expiry_date = doc.issue_date + duration
		anomaly = make_anomaly(get_kind(), document_id, field_for(state.case, document_id, ISSUE_PATH), old_issue, doc.issue_date)
	else:
		var old_expiry: int = doc.expiry_date
		doc.expiry_date = today - days
		doc.issue_date = doc.expiry_date - duration
		anomaly = make_anomaly(get_kind(), document_id, field_for(state.case, document_id, EXPIRY_PATH), old_expiry, doc.expiry_date)
	state.mark(document_id, field_for(state.case, document_id, EXPIRY_PATH))
	state.mark(document_id, field_for(state.case, document_id, ISSUE_PATH))
	_mark_conditions(state, document_id)
	return anomaly


## Acte II : un document exigé sous condition (motif du permis, classe,
## origine : R24, R26, R28) garde ses témoins (permis, carte) intacts.
static func _mark_conditions(state: InjectionState, document_id: StringName) -> void:
	for rule: Rule in state.get_rule_set().rules:
		var require: RequireDocumentRule = rule as RequireDocumentRule
		if require == null or require.document_id != document_id:
			continue
		if not require.applies_to_purposes.is_empty():
			state.mark(require.permit_id, field_for(state.case, require.permit_id, &"purpose"))
		if not require.applies_to_classes.is_empty():
			state.mark(require.card_id, field_for(state.case, require.card_id, &"citizen_class"))
		if not require.applies_to_faction_ids.is_empty():
			state.mark(require.card_id, field_for(state.case, require.card_id, &"faction_id"))
