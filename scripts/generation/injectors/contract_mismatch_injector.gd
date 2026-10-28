## `CONTRACT_MISMATCH` (Acte II, R25 ; docs/ACT2.md §2.2) : le code `CT-XX` du
## contrat de travail ne correspond pas à l'employeur du permis (contrat acheté
## à un courtier, SC-28). Seulement si le porteur présente un contrat et un
## permis (motif TRAVAIL). Le numéro `CT-XX-NNNN` est réécrit avec le code faux.
## Paramètre : `contract_code` (code imposé, ex. `MB`).
class_name ContractMismatchInjector
extends AnomalyInjector

const CODE_PATH: StringName = &"employer_code"
const SERIAL_PATH: StringName = &"document.serial"


func get_kind() -> AnomalyType.Kind:
	return AnomalyType.Kind.CONTRACT_MISMATCH


func inject(state: InjectionState) -> Anomaly:
	for rule: Rule in active_rules(state, ContractConsistentRule):
		var consistent: ContractConsistentRule = rule
		var contract: DocumentInstance = state.case.get_own_document(consistent.contract_id)
		if contract == null or state.case.get_own_document(consistent.permit_id) == null:
			continue
		var field_id: StringName = field_for(state.case, consistent.contract_id, CODE_PATH)
		if field_id == &"" or not state.is_free(consistent.contract_id, field_id) \
				or state.filter_documents([consistent.contract_id]).is_empty():
			continue
		var original: String = str(contract.get_value(field_id))
		var code: String = str(state.param(&"contract_code", ""))
		if code.is_empty():
			var others: PackedStringArray = []
			for employer: String in consistent.employer_codes:
				var candidate: String = consistent.employer_codes[employer]
				if candidate != original and not others.has(candidate):
					others.append(candidate)
			others.sort()
			if others.is_empty():
				return null
			code = others[state.rng.randi_range(0, others.size() - 1)]
		if FieldValue.equals(code, original):
			return null
		contract.set_value(field_id, code)
		contract.serial = contract.serial.replace("-%s-" % original, "-%s-" % code)
		state.mark(consistent.contract_id, field_id)
		# Témoin : l'employeur du permis (jamais retiré ni altéré ensuite).
		state.mark(consistent.permit_id, field_for(state.case, consistent.permit_id, &"employer"))
		var serial_field: StringName = field_for(state.case, consistent.contract_id, SERIAL_PATH)
		if serial_field != &"":
			state.mark(consistent.contract_id, serial_field)
		return make_anomaly(get_kind(), consistent.contract_id, field_id, original, code)
	return null
