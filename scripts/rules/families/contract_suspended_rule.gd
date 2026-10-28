## Famille « Contrat suspendu » (R35, Acte III J25, « Lock-out de Tycho » ;
## docs/ACT3.md §2.4) : un contrat de travail au code employeur
## `suspended_codes` (`KA`, Kessler-Ashe) présenté par un ressortissant d'une
## origine `faction_ids` (`TYC`, lue sur la carte) est suspendu : refus.
## Levée par une convocation authentique (R36). Anomalie détectée :
## `SUSPENDED_CONTRACT`. Preuve : Code (contrat) ↔ R35, ou Origine (carte) ↔ R35.
class_name ContractSuspendedRule
extends Rule

const CODE_PATH: StringName = &"employer_code"

@export var faction_ids: Array[StringName] = [&"tyc"]
@export var suspended_codes: PackedStringArray = ["KA"]
@export var contract_id: StringName = &"work_contract"
@export var card_id: StringName = &"id_card"


## Vrai si ce couple origine × code employeur est suspendu (générateur).
func suspends(faction_id: StringName, employer_code: String) -> bool:
	return faction_ids.has(faction_id) and suspended_codes.has(employer_code)


func is_violated(case: Case) -> bool:
	if case == null or case.get_own_document(contract_id) == null:
		return false
	if not faction_ids.has(Rule.visible_origin(case)):
		return false
	var code: Variant = PurposeConsistentRule._value(case, contract_id, CODE_PATH)
	return code != null and suspended_codes.has(str(code))


func evaluate(case: Case, _ctx: RuleContext) -> Array[Violation]:
	var violations: Array[Violation] = []
	if not is_violated(case):
		return violations
	var refs: Array[FieldRef] = []
	PurposeConsistentRule._append(refs, Rule.find_ref(case, contract_id, CODE_PATH))
	refs.append(get_ref())
	PurposeConsistentRule._append(refs, Rule.find_ref(case, card_id, &"faction_id"))
	violations.append(make_violation(refs, "viol_contract_suspended"))
	return violations


func get_detectable_anomalies() -> Array[AnomalyType.Kind]:
	return [AnomalyType.Kind.SUSPENDED_CONTRACT]


func check_against(case: Case, ref: FieldRef, _ctx: RuleContext) -> Discrepancy.Result:
	var field: FieldDef = case.get_field_def(ref)
	if field == null:
		return Discrepancy.Result.INCOMPARABLE
	var on_code: bool = ref.document_id == contract_id and field.truth_path == CODE_PATH
	var on_origin: bool = ref.document_id == card_id and field.truth_path == &"faction_id"
	if not on_code and not on_origin:
		return Discrepancy.Result.INCOMPARABLE
	return Discrepancy.Result.DISCORDANT if is_violated(case) else Discrepancy.Result.CONCORDANT


func get_referenced_truth_paths() -> Dictionary[StringName, Array]:
	return {contract_id: [CODE_PATH], card_id: [&"faction_id"]}
