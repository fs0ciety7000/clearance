## `SPONSOR_MISMATCH` (Acte III, R34 ; docs/ACT3.md §2.2) : le Répondant du
## permis d'un ressortissant au motif VISITE FAMILIALE n'est pas à la Main
## courante au moment de la présentation. Trois variantes
## (`injection_params.variant`) : `absent` (N° ID d'un·e Né·e-Halcyon jamais
## passé·e, SC-62), `later` (répondant placé **après** dans la file),
## `ineligible` (passager admis plus tôt mais non admissible : hors HAL).
## Sans paramètre : tirage parmi les trois (repli sur `absent`).
class_name SponsorMismatchInjector
extends AnomalyInjector

const VARIANTS: PackedStringArray = ["absent", "later", "ineligible"]


func get_kind() -> AnomalyType.Kind:
	return AnomalyType.Kind.SPONSOR_MISMATCH


func inject(state: InjectionState) -> Anomaly:
	for rule: Rule in active_rules(state, SponsorRule):
		var sponsor_rule: SponsorRule = rule
		if not sponsor_rule.applies_to(state.case):
			continue
		var field_id: StringName = field_for(state.case, sponsor_rule.permit_id, SponsorRule.SPONSOR_PATH)
		if field_id == &"" or not state.is_free(sponsor_rule.permit_id, field_id) \
				or state.filter_documents([sponsor_rule.permit_id]).is_empty():
			continue
		var permit: DocumentInstance = state.case.get_own_document(sponsor_rule.permit_id)
		var original: Variant = permit.get_value(field_id)
		var variant: String = str(state.param(&"variant", ""))
		if variant.is_empty():
			variant = VARIANTS[state.rng.randi_range(0, VARIANTS.size() - 1)]
		var value: String = _sponsor_for(state, variant)
		if value.is_empty() or (original != null and FieldValue.equals(original, value) and variant != "absent"):
			value = _absent_id(state)
		if state.ctx.find_ledger_by_citizen(value) != null:
			return null
		permit.set_value(field_id, value)
		state.truth.sponsor_id = value
		state.case.passenger_presented.sponsor_id = value
		state.mark(sponsor_rule.permit_id, field_id)
		# Témoins : le motif (VISITE FAMILIALE) et l'origine restent intacts.
		state.mark(sponsor_rule.permit_id, field_for(state.case, sponsor_rule.permit_id, &"purpose"))
		state.mark(&"id_card", field_for(state.case, &"id_card", &"faction_id"))
		return make_anomaly(get_kind(), sponsor_rule.permit_id, field_id, original, value)
	return null


## N° ID du répondant fautif selon la variante (vide : repli `absent`).
static func _sponsor_for(state: InjectionState, variant: String) -> String:
	var index: int = state.case.index
	match variant:
		"later":
			if index + 1 < state.passenger_count:
				return state.citizen_id_at(state.rng.randi_range(index + 1, state.passenger_count - 1))
		"ineligible":
			var earlier: Array[int] = []
			for k: int in index:
				var id: String = state.citizen_id_at(k)
				if not id.is_empty() and not id.begins_with("HG-1"):
					earlier.append(k)
			if not earlier.is_empty():
				return state.citizen_id_at(earlier[state.rng.randi_range(0, earlier.size() - 1)])
	return ""


## N° ID d'un·e Né·e-Halcyon qui n'est jamais passé·e (variante `absent`).
static func _absent_id(state: InjectionState) -> String:
	var hal: FactionDef = state.get_faction(&"hal")
	if hal == null:
		return "HG-1000-AAAA"
	return PassengerGenerator.make_citizen_id(state.rng, hal)
