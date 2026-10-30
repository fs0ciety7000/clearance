## Famille « Procédure » (R06 visage découvert, R08 interrogatoire TYC).
##
## Ne produit **jamais** de violation : ce n'est pas une propriété des papiers
## mais du comportement de l'agent. Elle figure au Rulebook (une seule source
## de texte) et est vérifiée par le `ScoringService` (M5) via `procedure_id`
## (citations VISAGE NON CONTRÔLÉ, INTERROGATOIRE OMIS).
## M13 (docs/M13.md §2.4, §2.6 ; D-146, D-148) : R44 « Fouille sur motif »
## (`search_cause`, FOUILLE SANS MOTIF) et R47 « Fouille des Ceinturiers »
## (`belt_search`, FOUILLE OMISE : origine visible × séjour du permis
## > `min_stay_days`). Les citations restent émises par le `ScoringService`.
class_name ProcedureRule
extends Rule

const PROCEDURE_FACE_UNCOVERED: StringName = &"face_uncovered"
const PROCEDURE_TYCHO_INTERVIEW: StringName = &"tycho_interview"
## M13 : R44 (fouille sur motif) et R47 (fouille obligatoire des Ceinturiers).
const PROCEDURE_SEARCH_CAUSE: StringName = &"search_cause"
const PROCEDURE_BELT_SEARCH: StringName = &"belt_search"

@export var procedure_id: StringName = &""
## Origines concernées (vide = toutes).
@export var applies_to_faction_ids: Array[StringName] = []
## M13 (R47) : la procédure ne vise que les séjours **strictement** plus longs
## (durée lue sur le document `stay_document_id`) ; 0 = sans condition.
@export var min_stay_days: int = 0
@export var stay_document_id: StringName = &"entry_permit"


func applies_to(case: Case) -> bool:
	if not applies_to_faction_ids.is_empty() and not applies_to_faction_ids.has(Rule.visible_origin(case)):
		return false
	return min_stay_days <= 0 or presented_stay(case) > min_stay_days


## M13 (R47) : durée du séjour lue sur le document (−1 sans document ni champ).
func presented_stay(case: Case) -> int:
	var ref: FieldRef = Rule.find_ref(case, stay_document_id, &"stay_days")
	if ref == null:
		return -1
	var value: Variant = case.get_value(ref)
	return value if value is int else -1


## M13 (R47) : vrai si l'admission de ce passager exige une fouille (motif MF-5).
func requires_search(case: Case) -> bool:
	return procedure_id == PROCEDURE_BELT_SEARCH and applies_to(case)
