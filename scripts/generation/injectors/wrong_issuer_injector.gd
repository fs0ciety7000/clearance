## `WRONG_ISSUER` (GDD §6) : certificat d'une clinique inexistante (« Clinique
## Meridiane ») ou d'un centre non agréé. Détecté par R13 (`IssuerAllowedRule`).
class_name WrongIssuerInjector
extends AnomalyInjector

const ISSUER_PATH: StringName = &"document.issuer_id"
const FAKE_ISSUERS: Array[StringName] = [&"clinique_meridiane", &"dispensaire_tycho", &"centre_medical_ceres"]


func get_kind() -> AnomalyType.Kind:
	return AnomalyType.Kind.WRONG_ISSUER


func inject(state: InjectionState) -> Anomaly:
	var options: Array[IssuerAllowedRule] = []
	for rule: Rule in active_rules(state, IssuerAllowedRule):
		var issuer_rule: IssuerAllowedRule = rule
		var evidence: StringName = field_for(state.case, issuer_rule.document_id, ISSUER_PATH)
		if evidence != &"" and state.is_free(issuer_rule.document_id, evidence) \
				and not state.filter_documents([issuer_rule.document_id]).is_empty():
			options.append(issuer_rule)
	if options.is_empty():
		return null
	var chosen: IssuerAllowedRule = options[state.rng.randi_range(0, options.size() - 1)]
	var fakes: Array[StringName] = []
	for fake: StringName in FAKE_ISSUERS:
		if not chosen.allowed_issuer_ids.has(fake):
			fakes.append(fake)
	var doc: DocumentInstance = state.case.get_document(chosen.document_id)
	var original: StringName = doc.issuer_id
	doc.issuer_id = fakes[state.rng.randi_range(0, fakes.size() - 1)]
	var field_id: StringName = field_for(state.case, chosen.document_id, ISSUER_PATH)
	state.mark(chosen.document_id, field_id)
	return make_anomaly(get_kind(), chosen.document_id, field_id, original, doc.issuer_id)
