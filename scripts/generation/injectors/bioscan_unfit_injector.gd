## `BIOSCAN_UNFIT` (🟡 GDD §6) : statut bio-scan ≠ SAIN (QUARANTAINE, À REVOIR).
## Le passager est réellement concerné (`truth.health_status`). Détecté par R14.
class_name BioscanUnfitInjector
extends AnomalyInjector

const UNFIT: Array[StringName] = [Passenger.HEALTH_QUARANTINE, Passenger.HEALTH_REVIEW]


func get_kind() -> AnomalyType.Kind:
	return AnomalyType.Kind.BIOSCAN_UNFIT


func inject(state: InjectionState) -> Anomaly:
	var options: Array[FieldValueAllowedRule] = []
	for rule: Rule in active_rules(state, FieldValueAllowedRule):
		var value_rule: FieldValueAllowedRule = rule
		var evidence: StringName = field_for(state.case, value_rule.document_id, value_rule.truth_path)
		if evidence != &"" and state.is_free(value_rule.document_id, evidence):
			options.append(value_rule)
	if options.is_empty():
		return null
	var chosen: FieldValueAllowedRule = options[state.rng.randi_range(0, options.size() - 1)]
	var values: Array[StringName] = []
	for value: StringName in UNFIT:
		if not chosen.is_allowed(value):
			values.append(value)
	if values.is_empty():
		return null
	var field_id: StringName = field_for(state.case, chosen.document_id, chosen.truth_path)
	var doc: DocumentInstance = state.case.get_document(chosen.document_id)
	var original: Variant = doc.get_value(field_id)
	var status: StringName = values[state.rng.randi_range(0, values.size() - 1)]
	doc.set_value(field_id, status)
	if chosen.truth_path == &"health_status":
		state.truth.health_status = status
		state.case.passenger_presented.health_status = status
	state.mark(chosen.document_id, field_id)
	return make_anomaly(get_kind(), chosen.document_id, field_id, original, status)
