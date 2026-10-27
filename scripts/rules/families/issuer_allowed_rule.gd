## Famille « Émetteur agréé » (R13 : bio-scan de la Clinique Orbitale Meridian).
##
## Violation si l'émetteur imprimé (`document.issuer_id`) n'est pas dans la
## liste. Anomalie détectée : `WRONG_ISSUER`.
class_name IssuerAllowedRule
extends Rule

const ISSUER_PATH: StringName = &"document.issuer_id"

@export var document_id: StringName = &""
@export var allowed_issuer_ids: Array[StringName] = []


func is_violated(doc: DocumentInstance) -> bool:
	return doc != null and not allowed_issuer_ids.has(doc.issuer_id)


func evaluate(case: Case, _ctx: RuleContext) -> Array[Violation]:
	var violations: Array[Violation] = []
	var doc: DocumentInstance = case.get_document(document_id)
	if not is_violated(doc):
		return violations
	var refs: Array[FieldRef] = []
	var evidence: FieldRef = Rule.find_ref(case, document_id, ISSUER_PATH)
	if evidence != null:
		refs.append(evidence)
	refs.append(get_ref())
	violations.append(make_violation(refs, "viol_wrong_issuer"))
	return violations


func get_detectable_anomalies() -> Array[AnomalyType.Kind]:
	return [AnomalyType.Kind.WRONG_ISSUER]


func check_against(case: Case, ref: FieldRef, _ctx: RuleContext) -> Discrepancy.Result:
	var field: FieldDef = case.get_field_def(ref)
	if ref.document_id != document_id or field == null or field.truth_path != ISSUER_PATH:
		return Discrepancy.Result.INCOMPARABLE
	var doc: DocumentInstance = case.get_document(document_id)
	return Discrepancy.Result.DISCORDANT if is_violated(doc) else Discrepancy.Result.CONCORDANT


func get_referenced_truth_paths() -> Dictionary[StringName, Array]:
	return {document_id: [ISSUER_PATH]}
