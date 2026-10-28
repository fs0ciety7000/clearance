## Famille « Révocations » (R30, Acte II J17 ; docs/ACT2.md §2.4) : le N° ID de
## la carte figure à l'onglet « Révocations » du jour (`RuleContext.revoked`,
## liste liée à des passagers du jour comme les avis, D-056) : le titulaire
## n'est plus citoyen, refus.
## Anomalie détectée : `REVOKED_ID`. Preuve : N° ID (carte) ↔ règle, ou N° ID ↔
## entrée de l'onglet (`FieldRef.revoked`).
class_name RevokedIdRule
extends Rule

@export var document_id: StringName = &"id_card"


func find_entry(case: Case, ctx: RuleContext) -> RevokedEntry:
	if ctx == null:
		return null
	var value: Variant = PurposeConsistentRule._value(case, document_id, &"citizen_id")
	if value == null:
		return null
	for entry: RevokedEntry in ctx.revoked:
		if FieldValue.equals(entry.citizen_id, value):
			return entry
	return null


func evaluate(case: Case, ctx: RuleContext) -> Array[Violation]:
	var violations: Array[Violation] = []
	var entry: RevokedEntry = find_entry(case, ctx)
	if entry == null:
		return violations
	var refs: Array[FieldRef] = []
	PurposeConsistentRule._append(refs, Rule.find_ref(case, document_id, &"citizen_id"))
	refs.append(get_ref())
	refs.append(entry.get_ref())
	violations.append(make_violation(refs, "viol_revoked"))
	return violations


func get_detectable_anomalies() -> Array[AnomalyType.Kind]:
	return [AnomalyType.Kind.REVOKED_ID]


func check_against(case: Case, ref: FieldRef, ctx: RuleContext) -> Discrepancy.Result:
	var field: FieldDef = case.get_field_def(ref)
	if field == null or ref.document_id != document_id or field.truth_path != &"citizen_id":
		return Discrepancy.Result.INCOMPARABLE
	return Discrepancy.Result.DISCORDANT if find_entry(case, ctx) != null else Discrepancy.Result.CONCORDANT


func get_referenced_truth_paths() -> Dictionary[StringName, Array]:
	return {document_id: [&"citizen_id"]}
