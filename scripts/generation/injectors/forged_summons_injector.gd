## `FORGED_SUMMONS` (Acte III, R36 ; docs/ACT3.md §2.2) : la Convocation du
## permis est un faux — N° `ENQ-` absent de l'onglet Convocations (variante
## `absent`), ou présent sous un autre nom (`other_name` : N° d'un leurre).
## Un passager qui n'avait pas de convocation en reçoit une (SC-76 : toute
## convocation fausse est une violation). Paramètre : `variant`.
class_name ForgedSummonsInjector
extends AnomalyInjector

const VARIANTS: PackedStringArray = ["absent", "other_name"]


func get_kind() -> AnomalyType.Kind:
	return AnomalyType.Kind.FORGED_SUMMONS


func inject(state: InjectionState) -> Anomaly:
	for rule: Rule in active_rules(state, SummonsRule):
		var summons_rule: SummonsRule = rule
		var permit: DocumentInstance = state.case.get_own_document(summons_rule.permit_id)
		var field_id: StringName = field_for(state.case, summons_rule.permit_id, SummonsRule.SUMMONS_PATH)
		if permit == null or field_id == &"" or not state.is_free(summons_rule.permit_id, field_id) \
				or state.filter_documents([summons_rule.permit_id]).is_empty():
			continue
		# Le nom de la carte est le témoin de R36 : sans carte (MISSING_DOCUMENT
		# tiré avant), la convocation ne peut pas être prouvée fausse.
		if state.case.get_own_document(summons_rule.card_id) == null:
			continue
		var original: Variant = permit.get_value(field_id)
		var current: String = str(original) if original != null else ""
		var variant: String = str(state.param(&"variant", ""))
		if variant.is_empty():
			variant = VARIANTS[state.rng.randi_range(0, VARIANTS.size() - 1)]
		var value: String = ""
		if variant == "absent" and not current.is_empty() and state.ctx.find_summons_by_number(current) == null:
			# Convocation scénarisée déjà absente de l'onglet (Lev, Sato) : confirmée.
			value = current
		elif variant == "other_name":
			value = _decoy_number(state)
		if value.is_empty():
			value = _absent_number(state)
		permit.set_value(field_id, value)
		state.truth.summons_id = value
		state.case.passenger_presented.summons_id = value
		state.mark(summons_rule.permit_id, field_id)
		state.mark(summons_rule.card_id, field_for(state.case, summons_rule.card_id, &"family_name"))
		state.mark(summons_rule.card_id, field_for(state.case, summons_rule.card_id, &"given_name"))
		return make_anomaly(get_kind(), summons_rule.permit_id, field_id, original, value)
	return null


## N° d'un leurre de l'onglet (présent sous un autre nom), vide sinon.
static func _decoy_number(state: InjectionState) -> String:
	var decoys: PackedStringArray = []
	for entry: SummonsEntry in state.ctx.summons:
		if entry.case_index < 0:
			decoys.append(entry.number)
	return decoys[state.rng.randi_range(0, decoys.size() - 1)] if not decoys.is_empty() else ""


## N° `ENQ-` absent de l'onglet du jour.
static func _absent_number(state: InjectionState) -> String:
	var number: String = ""
	for attempt: int in 16:
		number = "%s%04d" % [CaseBuilder.SUMMONS_PREFIX, state.rng.randi_range(CaseBuilder.SUMMONS_RANGE.x, CaseBuilder.SUMMONS_RANGE.y)]
		if state.ctx.find_summons_by_number(number) == null:
			break
	return number
