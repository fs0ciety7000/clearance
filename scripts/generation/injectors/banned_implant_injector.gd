## `BANNED_IMPLANT` (GDD §6, R16, M7) : un implant interdit est **déclaré** sur
## la carte (et porté) : `DER-19` (contrebande) ou un `MIL-` sans dérogation
## (ressortissants de Tharsis). Paramètre : `implant`.
class_name BannedImplantInjector
extends AnomalyInjector

const MILITARY: PackedStringArray = ["MIL-2", "MIL-9", "MIL-15"]


func get_kind() -> AnomalyType.Kind:
	return AnomalyType.Kind.BANNED_IMPLANT


func inject(state: InjectionState) -> Anomaly:
	var rules: Array[Rule] = active_rules(state, BannedImplantsRule)
	if rules.is_empty():
		return null
	var rule: BannedImplantsRule = rules[0]
	var field_id: StringName = field_for(state.case, rule.document_id, &"implants")
	if field_id == &"" or not state.is_free(rule.document_id, field_id) \
			or state.filter_documents([rule.document_id]).is_empty():
		return null
	var presented: Passenger = state.case.passenger_presented
	var code: String = str(state.param(&"implant", ""))
	if code.is_empty():
		code = MILITARY[state.rng.randi_range(0, MILITARY.size() - 1)] if presented.faction_id == &"thr" \
				else String(rule.always_banned[0]) if not rule.always_banned.is_empty() else "DER-19"
	if presented.implants.has(code):
		return null
	var card: DocumentInstance = state.case.get_document(rule.document_id)
	var original: PackedStringArray = ImplantsDeclaredRule.as_list(card.get_value(field_id)).duplicate()
	var declared: PackedStringArray = original.duplicate()
	declared.append(code)
	card.set_value(field_id, declared)
	presented.implants.append(code)
	state.truth.implants.append(code)
	state.mark(rule.document_id, field_id)
	return make_anomaly(get_kind(), rule.document_id, field_id, original, declared)
