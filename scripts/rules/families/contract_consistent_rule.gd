## Famille « Code employeur » (R25, Acte II J12 ; docs/ACT2.md §2.4) : le code
## du Contrat de travail (`CT-XX`) correspond à l'employeur du permis d'entrée
## (onglet « Codes employeurs » : `employer_codes`). Un contrat d'un tiers
## (SC-27) n'est jamais lu.
##
## Porte aussi les données du générateur pour les contrats : table des codes
## (`code_for`) et postes tirables (`posts`).
## Anomalie détectée : `CONTRACT_MISMATCH`. Preuve : Code (contrat) ↔ règle
## (onglet), puis Code ↔ Employeur (permis).
class_name ContractConsistentRule
extends Rule

const CODE_PATH: StringName = &"employer_code"

@export var contract_id: StringName = &"work_contract"
@export var permit_id: StringName = &"entry_permit"
## Employeur (texte du permis) → code à deux lettres (`KA`, `CV`…).
@export var employer_codes: Dictionary[String, String] = {}
## Postes tirés pour un contrat généré (`recycleur`, `manutention`…).
@export var posts: PackedStringArray = []


## Clé i18n du libellé d'un code pour l'onglet « Codes employeurs »
## (`rb_emp_ka` → « KA · Kessler-Ashe Orbital » ; QA-028).
static func label_key(code: String) -> String:
	return "rb_emp_%s" % code.to_lower()


## Code attendu pour un employeur (comparaison normalisée), vide si inconnu.
func code_for(employer: Variant) -> String:
	for name: String in employer_codes:
		if FieldValue.equals(name, employer):
			return employer_codes[name]
	return ""


func is_violated(case: Case) -> bool:
	var contract: DocumentInstance = case.get_own_document(contract_id)
	var permit: DocumentInstance = case.get_own_document(permit_id)
	if contract == null or permit == null:
		return false
	var code: Variant = PurposeConsistentRule._value(case, contract_id, CODE_PATH)
	var employer: Variant = PurposeConsistentRule._value(case, permit_id, &"employer")
	return not FieldValue.equals(code, code_for(employer))


func evaluate(case: Case, _ctx: RuleContext) -> Array[Violation]:
	var violations: Array[Violation] = []
	if not is_violated(case):
		return violations
	var refs: Array[FieldRef] = []
	PurposeConsistentRule._append(refs, Rule.find_ref(case, contract_id, CODE_PATH))
	refs.append(get_ref())
	PurposeConsistentRule._append(refs, Rule.find_ref(case, permit_id, &"employer"))
	violations.append(make_violation(refs, "viol_contract_mismatch"))
	return violations


func get_detectable_anomalies() -> Array[AnomalyType.Kind]:
	return [AnomalyType.Kind.CONTRACT_MISMATCH]


func check_against(case: Case, ref: FieldRef, _ctx: RuleContext) -> Discrepancy.Result:
	var field: FieldDef = case.get_field_def(ref)
	if field == null:
		return Discrepancy.Result.INCOMPARABLE
	var doc: DocumentInstance = case.get_document(ref.document_id)
	var on_code: bool = ref.document_id == contract_id and field.truth_path == CODE_PATH and doc != null and not doc.third_party
	var on_employer: bool = ref.document_id == permit_id and field.truth_path == &"employer"
	if not on_code and not on_employer:
		return Discrepancy.Result.INCOMPARABLE
	if case.get_own_document(contract_id) == null:
		return Discrepancy.Result.INCOMPARABLE
	return Discrepancy.Result.DISCORDANT if is_violated(case) else Discrepancy.Result.CONCORDANT


func get_referenced_truth_paths() -> Dictionary[StringName, Array]:
	return {contract_id: [CODE_PATH, &"post"], permit_id: [&"employer"]}
