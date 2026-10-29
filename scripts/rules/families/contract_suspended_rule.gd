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
## M12 (R42 « Cadres de Kessler-Ashe », B55) : toutes origines (sans
## condition d'origine, `faction_ids` ignoré).
@export var any_origin: bool = false
## M12 (R42) : classes citoyennes (carte) visées ; vide = toutes.
@export var classes: Array[StringName] = []
## M12 (R42, monde D sans R25) : registre employeur → code utilisé par le
## générateur pour imprimer le code des contrats (vide : celui de R25).
@export var employer_codes: Dictionary[String, String] = {}


## Vrai si ce couple origine × code employeur est suspendu (générateur) ;
## M12 : classe du porteur (`citizen_class`, vide = non contrôlée).
func suspends(faction_id: StringName, employer_code: String, citizen_class: StringName = &"") -> bool:
	if not any_origin and not faction_ids.has(faction_id):
		return false
	if not classes.is_empty() and citizen_class != &"" and not classes.has(citizen_class):
		return false
	return suspended_codes.has(employer_code)


## Vrai si la règle vise ce porteur (origine et classe lues sur la carte).
func targets(case: Case) -> bool:
	if not any_origin and not faction_ids.has(Rule.visible_origin(case)):
		return false
	if classes.is_empty():
		return true
	var citizen_class: Variant = PurposeConsistentRule._value(case, card_id, &"citizen_class")
	if citizen_class == null:
		return false
	for wanted: StringName in classes:
		if FieldValue.equals(citizen_class, wanted):
			return true
	return false


func is_violated(case: Case) -> bool:
	if case == null or case.get_own_document(contract_id) == null:
		return false
	if not targets(case):
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
	if not classes.is_empty():
		PurposeConsistentRule._append(refs, Rule.find_ref(case, card_id, &"citizen_class"))
	if not any_origin:
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
	var on_origin: bool = not any_origin and ref.document_id == card_id and field.truth_path == &"faction_id"
	var on_class: bool = not classes.is_empty() and ref.document_id == card_id and field.truth_path == &"citizen_class"
	if not on_code and not on_origin and not on_class:
		return Discrepancy.Result.INCOMPARABLE
	return Discrepancy.Result.DISCORDANT if is_violated(case) else Discrepancy.Result.CONCORDANT


func get_referenced_truth_paths() -> Dictionary[StringName, Array]:
	return {contract_id: [CODE_PATH], card_id: [&"faction_id", &"citizen_class"]}
