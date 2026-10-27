## Famille « Documents requis » (R01, R04, R11) : le dossier doit contenir un
## document donné, sauf pour les origines dispensées (R04 : `HAL` sans permis).
##
## Anomalie détectée : `MISSING_DOCUMENT`. Preuve : la règle du Rulebook
## comparée à n'importe quel document du dossier (GDD §4.1).
class_name RequireDocumentRule
extends Rule

@export var document_id: StringName = &""
## Origines dispensées (`FactionDef.id`), lues sur l'origine visible.
@export var exempt_faction_ids: Array[StringName] = []


func applies_to(case: Case) -> bool:
	return not exempt_faction_ids.has(Rule.visible_origin(case))


func is_violated(case: Case) -> bool:
	return applies_to(case) and not case.has_document(document_id)


func evaluate(case: Case, _ctx: RuleContext) -> Array[Violation]:
	var violations: Array[Violation] = []
	if is_violated(case):
		violations.append(make_violation([get_ref()], "viol_missing_document"))
	return violations


func get_detectable_anomalies() -> Array[AnomalyType.Kind]:
	return [AnomalyType.Kind.MISSING_DOCUMENT]


## Règle ↔ n'importe quel champ d'un document présent (« le dossier »).
func check_against(case: Case, ref: FieldRef, _ctx: RuleContext) -> Discrepancy.Result:
	if not case.has_field(ref):
		return Discrepancy.Result.INCOMPARABLE
	return Discrepancy.Result.DISCORDANT if is_violated(case) else Discrepancy.Result.CONCORDANT


func get_required_document_ids() -> Array[StringName]:
	return [document_id]


func get_referenced_truth_paths() -> Dictionary[StringName, Array]:
	return {document_id: []}
