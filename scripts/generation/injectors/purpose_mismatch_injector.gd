## `PURPOSE_MISMATCH` (GDD §6, R09, M7) : motif TRAVAIL « SANS EMPLOYEUR »,
## séjour > 30 jours pour un `C-4`, ou séjour plus long que la validité
## restante du permis. Modifie le permis et la déclaration du passager.
## Paramètres : `field_path` (`employer` | `stay_days`), `employer` (texte).
class_name PurposeMismatchInjector
extends AnomalyInjector

const NO_EMPLOYER: String = "SANS EMPLOYEUR"


func get_kind() -> AnomalyType.Kind:
	return AnomalyType.Kind.PURPOSE_MISMATCH


func inject(state: InjectionState) -> Anomaly:
	var rules: Array[Rule] = active_rules(state, PurposeConsistentRule)
	if rules.is_empty():
		return null
	var rule: PurposeConsistentRule = rules[0]
	var c: Case = state.case
	var permit: DocumentInstance = c.get_document(rule.permit_id)
	if permit == null or state.filter_documents([rule.permit_id]).is_empty():
		return null
	var forced: String = str(state.param(&"field_path", ""))
	var employer_field: StringName = field_for(c, rule.permit_id, &"employer")
	var purpose_field: StringName = field_for(c, rule.permit_id, &"purpose")
	var stay_field: StringName = field_for(c, rule.permit_id, &"stay_days")
	var class_field: StringName = field_for(c, rule.card_id, &"citizen_class")
	var options: Array[StringName] = []
	if (forced.is_empty() or forced == "employer") and employer_field != &"" and purpose_field != &"" \
			and state.is_free(rule.permit_id, employer_field) and state.is_free(rule.permit_id, purpose_field) \
			and FieldValue.equals(permit.get_value(purpose_field), rule.work_purpose):
		options.append(PurposeConsistentRule.CHECK_EMPLOYER)
	if (forced.is_empty() or forced == "stay_days") and stay_field != &"" and state.is_free(rule.permit_id, stay_field):
		if class_field != &"" and state.is_free(rule.card_id, class_field) \
				and FieldValue.equals(c.get_document(rule.card_id).get_value(class_field), rule.short_stay_class):
			options.append(PurposeConsistentRule.CHECK_CLASS_STAY)
		if permit.expiry_date >= state.ctx.today:
			options.append(PurposeConsistentRule.CHECK_VALIDITY)
	if options.is_empty():
		return null
	var check: StringName = options[state.rng.randi_range(0, options.size() - 1)]
	match check:
		PurposeConsistentRule.CHECK_EMPLOYER:
			var original: Variant = permit.get_value(employer_field)
			var employer: String = str(state.param(&"employer", NO_EMPLOYER))
			permit.set_value(employer_field, employer)
			state.truth.employer = employer
			c.passenger_presented.employer = employer
			state.mark(rule.permit_id, employer_field)
			state.mark(rule.permit_id, purpose_field)
			return make_anomaly(get_kind(), rule.permit_id, employer_field, original, employer)
	var old_stay: int = permit.get_value(stay_field)
	var stay: int = old_stay
	if check == PurposeConsistentRule.CHECK_CLASS_STAY:
		stay = rule.short_stay_max + state.rng.randi_range(1, 30)
		state.mark(rule.card_id, class_field)
	else:
		stay = permit.expiry_date - state.ctx.today + state.rng.randi_range(1, 10)
	permit.set_value(stay_field, stay)
	state.truth.stay_days = stay
	c.passenger_presented.stay_days = stay
	state.mark(rule.permit_id, stay_field)
	state.mark(rule.permit_id, field_for(c, rule.permit_id, &"document.expiry_date"))
	return make_anomaly(get_kind(), rule.permit_id, stay_field, old_stay, stay)
