## Famille « Réintégrations » (R33, Acte III J22 ; docs/ACT3.md §2.4) — règle
## de **contexte**, jamais de violation : tant qu'elle est active, un N° ID de
## l'onglet Révocations dont la date de réintégration est atteinte
## (`RevokedEntry.is_reinstated`) est valide pour R30 (`RevokedIdRule`) et la
## paire « N° ID ↔ onglet Révocations » est CONCORDANTE (`disc_reinstated`).
## Sans date : refus (R30). Exclus : personnes impliquées dans les nuits du
## 22.03 et du 01.04 (motif `excluded_reason_key`).
class_name ReinstatementRule
extends Rule

@export var document_id: StringName = &"id_card"


func check_against(case: Case, ref: FieldRef, ctx: RuleContext) -> Discrepancy.Result:
	var field: FieldDef = case.get_field_def(ref)
	if field == null or ref.document_id != document_id or field.truth_path != &"citizen_id" or ctx == null:
		return Discrepancy.Result.INCOMPARABLE
	for entry: RevokedEntry in ctx.revoked:
		if FieldValue.equals(entry.citizen_id, case.get_value(ref)):
			return Discrepancy.Result.CONCORDANT if entry.is_reinstated(ctx.today) else Discrepancy.Result.DISCORDANT
	return Discrepancy.Result.CONCORDANT


func get_referenced_truth_paths() -> Dictionary[StringName, Array]:
	return {document_id: [&"citizen_id"]}
