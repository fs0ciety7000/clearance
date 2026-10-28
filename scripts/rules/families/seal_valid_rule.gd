## Famille « Sceaux conformes » (R20, GDD §6 `INVALID_SEAL`, onglet Sceaux, M7) :
## chaque document porte le sceau en vigueur de son type
## (`DocumentTypeDef.seal_id` ; au 21.03, nouveau modèle d'anneau barré).
## Un ancien modèle ou le sceau d'un autre émetteur est une violation.
## Preuve : champ « Sceau » ↔ règle.
class_name SealValidRule
extends Rule

const SEAL_PATH: StringName = &"document.seal_id"


func is_valid(doc: DocumentInstance) -> bool:
	return doc == null or doc.type_def == null or doc.seal_id == doc.type_def.seal_id


func evaluate(case: Case, _ctx: RuleContext) -> Array[Violation]:
	var violations: Array[Violation] = []
	for doc: DocumentInstance in case.documents:
		if is_valid(doc):
			continue
		var refs: Array[FieldRef] = []
		PurposeConsistentRule._append(refs, Rule.find_ref(case, doc.get_document_id(), SEAL_PATH))
		refs.append(get_ref())
		violations.append(make_violation(refs, "viol_invalid_seal"))
	return violations


func get_detectable_anomalies() -> Array[AnomalyType.Kind]:
	return [AnomalyType.Kind.INVALID_SEAL]


func check_against(case: Case, ref: FieldRef, _ctx: RuleContext) -> Discrepancy.Result:
	var field: FieldDef = case.get_field_def(ref)
	if field == null or field.truth_path != SEAL_PATH:
		return Discrepancy.Result.INCOMPARABLE
	return Discrepancy.Result.CONCORDANT if is_valid(case.get_document(ref.document_id)) else Discrepancy.Result.DISCORDANT
