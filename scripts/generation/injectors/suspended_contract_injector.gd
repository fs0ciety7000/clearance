## `SUSPENDED_CONTRACT` (Acte III, R35 « Lock-out de Tycho » ; docs/ACT3.md
## §2.2) : un ressortissant de Tycho au motif TRAVAIL présente un contrat
## Kessler-Ashe (`CT-KA`), suspendu. Les papiers restent cohérents entre eux
## (employeur du permis = code du contrat, R25) : c'est la règle qui refuse.
## Jamais sur un convoqué (la convocation lève R35).
class_name SuspendedContractInjector
extends AnomalyInjector

const SERIAL_PATH: StringName = &"document.serial"


func get_kind() -> AnomalyType.Kind:
	return AnomalyType.Kind.SUSPENDED_CONTRACT


func inject(state: InjectionState) -> Anomaly:
	for rule: Rule in active_rules(state, ContractSuspendedRule):
		var lockout: ContractSuspendedRule = rule
		if not lockout.faction_ids.has(Rule.visible_origin(state.case)) or state.ctx.has_valid_summons(state.case):
			continue
		var contract: DocumentInstance = state.case.get_own_document(lockout.contract_id)
		var code_field: StringName = field_for(state.case, lockout.contract_id, ContractSuspendedRule.CODE_PATH)
		if contract == null or code_field == &"" or not state.is_free(lockout.contract_id, code_field) \
				or state.filter_documents([lockout.contract_id]).is_empty():
			continue
		var code: String = lockout.suspended_codes[0]
		var employer: String = _employer_of(state, code)
		var original: Variant = contract.get_value(code_field)
		if not FieldValue.equals(original, code):
			if employer.is_empty():
				continue
			var contract_employer: StringName = field_for(state.case, lockout.contract_id, &"employer")
			var permit_employer: StringName = field_for(state.case, &"entry_permit", &"employer")
			if not state.is_free(lockout.contract_id, contract_employer) \
					or (permit_employer != &"" and not state.is_free(&"entry_permit", permit_employer)):
				continue
			contract.set_value(code_field, code)
			contract.set_value(contract_employer, employer)
			contract.serial = contract.serial.replace("-%s-" % str(original), "-%s-" % code)
			var permit: DocumentInstance = state.case.get_own_document(&"entry_permit")
			if permit != null and permit_employer != &"":
				permit.set_value(permit_employer, employer)
				state.mark(&"entry_permit", permit_employer)
			state.truth.employer = employer
			state.truth.employer_code = code
			state.case.passenger_presented.employer = employer
			state.case.passenger_presented.employer_code = code
			state.mark(lockout.contract_id, contract_employer)
			var serial_field: StringName = field_for(state.case, lockout.contract_id, SERIAL_PATH)
			if serial_field != &"":
				state.mark(lockout.contract_id, serial_field)
		state.mark(lockout.contract_id, code_field)
		state.mark(lockout.card_id, field_for(state.case, lockout.card_id, &"faction_id"))
		return make_anomaly(get_kind(), lockout.contract_id, code_field, original, code)
	return null


## Employeur du registre R25 portant ce code, vide sinon.
static func _employer_of(state: InjectionState, code: String) -> String:
	for rule: Rule in state.get_rule_set().rules:
		var consistent: ContractConsistentRule = rule as ContractConsistentRule
		if consistent == null:
			continue
		for employer: String in consistent.employer_codes:
			if consistent.employer_codes[employer] == code:
				return employer
	return ""
