## Famille « Valeur autorisée » (R14 : statut bio-scan SAIN uniquement).
##
## Violation si la valeur affichée du champ (`truth_path` sur `document_id`)
## n'est pas dans `allowed_values`. Anomalies détectées : paramétrables
## (`BIOSCAN_UNFIT` pour R14).
class_name FieldValueAllowedRule
extends Rule

@export var document_id: StringName = &""
@export var truth_path: StringName = &""
@export var allowed_values: Array[StringName] = []
@export var detected_anomalies: Array[AnomalyType.Kind] = []


func is_allowed(value: Variant) -> bool:
	for allowed: StringName in allowed_values:
		if FieldValue.equals(value, allowed):
			return true
	return false


func evaluate(case: Case, _ctx: RuleContext) -> Array[Violation]:
	var violations: Array[Violation] = []
	var ref: FieldRef = Rule.find_ref(case, document_id, truth_path)
	if ref == null or is_allowed(case.get_value(ref)):
		return violations
	violations.append(make_violation([ref, get_ref()], "viol_value_not_allowed"))
	return violations


func get_detectable_anomalies() -> Array[AnomalyType.Kind]:
	return detected_anomalies.duplicate()


func check_against(case: Case, ref: FieldRef, _ctx: RuleContext) -> Discrepancy.Result:
	var field: FieldDef = case.get_field_def(ref)
	if ref.document_id != document_id or field == null or field.truth_path != truth_path:
		return Discrepancy.Result.INCOMPARABLE
	return Discrepancy.Result.CONCORDANT if is_allowed(case.get_value(ref)) else Discrepancy.Result.DISCORDANT


func get_referenced_truth_paths() -> Dictionary[StringName, Array]:
	return {document_id: [truth_path]}
