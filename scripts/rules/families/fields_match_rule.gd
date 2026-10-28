## Famille « Champs identiques » (R07, et R21 MRZ plus tard) : une même donnée
## (`truth_path`) doit avoir la même valeur sur tous les documents qui la portent.
##
## Une violation par `truth_path` discordant, avec toutes les références de ce
## `truth_path` comme preuves. Comparaison via `FieldValue.equals` (identique à
## celle du `DiscrepancyChecker`). Anomalies détectées : paramétrables
## (`NAME_MISMATCH`, `ID_MISMATCH` pour R07).
class_name FieldsMatchRule
extends Rule

@export var truth_paths: Array[StringName] = []
## Documents comparés (vide = tous les documents présents).
@export var document_ids: Array[StringName] = []
@export var detected_anomalies: Array[AnomalyType.Kind] = []


func evaluate(case: Case, _ctx: RuleContext) -> Array[Violation]:
	var violations: Array[Violation] = []
	for path: StringName in truth_paths:
		var refs: Array[FieldRef] = _refs_for(case, path)
		if refs.size() < 2:
			continue
		var first_value: Variant = case.get_value(refs[0])
		for i: int in range(1, refs.size()):
			if not FieldValue.equals(first_value, case.get_value(refs[i])):
				violations.append(make_violation(refs, "viol_fields_mismatch"))
				break
	return violations


func get_detectable_anomalies() -> Array[AnomalyType.Kind]:
	return detected_anomalies.duplicate()


func get_referenced_truth_paths() -> Dictionary[StringName, Array]:
	var result: Dictionary[StringName, Array] = {}
	for document_id: StringName in document_ids:
		result[document_id] = truth_paths.duplicate()
	return result


func _refs_for(case: Case, path: StringName) -> Array[FieldRef]:
	var refs: Array[FieldRef] = []
	for ref: FieldRef in case.find_refs_by_truth_path(path):
		if case.get_document(ref.document_id).is_foreign():
			continue # Acte II : document d'un tiers (SC-27), jamais comparé.
		if document_ids.is_empty() or document_ids.has(ref.document_id):
			refs.append(ref)
	return refs
