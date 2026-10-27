## `EXPIRED_DOCUMENT` (GDD §6) : la date d'expiration passe à aujourd'hui − 1…N
## jours (J1–J3 : 1–10, « presque valide » ; ensuite 1–30). Pour une règle
## d'ancienneté (`max_age_days`, bio-scan R12), c'est l'émission qui recule.
## Cible : un document présent dont la règle d'expiration est active.
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
	var by_document: Dictionary[StringName, DocumentNotExpiredRule] = {}
	for rule: Rule in active_rules(state, DocumentNotExpiredRule):
		var expiry_rule: DocumentNotExpiredRule = rule
		var rule_document: StringName = expiry_rule.document_id
		var issue_field: StringName = field_for(state.case, rule_document, ISSUE_PATH)
		var expiry_field: StringName = field_for(state.case, rule_document, EXPIRY_PATH)
		if expiry_field == &"" or not state.is_free(rule_document, expiry_field):
			continue
		if issue_field != &"" and not state.is_free(rule_document, issue_field):
			continue
		by_document[rule_document] = expiry_rule
	var candidates: Array[StringName] = []
	candidates.assign(by_document.keys())
	candidates = state.filter_documents(candidates)
	if candidates.is_empty():
		return null
	var document_id: StringName = candidates[state.rng.randi_range(0, candidates.size() - 1)]
	var rule: DocumentNotExpiredRule = by_document[document_id]
	var doc: DocumentInstance = state.case.get_document(document_id)
	var max_days: int = EARLY_DAYS_MAX if state.get_day_number() <= EARLY_DAY_LIMIT else LATE_DAYS_MAX
	var days: int = maxi(state.param_int(&"expired_days", state.rng.randi_range(1, max_days)), 1)
	var today: int = state.ctx.today
	var duration: int = doc.expiry_date - doc.issue_date
	var anomaly: Anomaly
	if rule.max_age_days > 0:
		var old_issue: int = doc.issue_date
		doc.issue_date = today - rule.max_age_days - (days - 1)
		doc.expiry_date = doc.issue_date + duration
		anomaly = make_anomaly(get_kind(), document_id, field_for(state.case, document_id, ISSUE_PATH), old_issue, doc.issue_date)
	else:
		var old_expiry: int = doc.expiry_date
		doc.expiry_date = today - days
		doc.issue_date = doc.expiry_date - duration
		anomaly = make_anomaly(get_kind(), document_id, field_for(state.case, document_id, EXPIRY_PATH), old_expiry, doc.expiry_date)
	state.mark(document_id, field_for(state.case, document_id, EXPIRY_PATH))
	state.mark(document_id, field_for(state.case, document_id, ISSUE_PATH))
	return anomaly
