## Famille « Procédure » (R06 visage découvert, R08 interrogatoire TYC).
##
## Ne produit **jamais** de violation : ce n'est pas une propriété des papiers
## mais du comportement de l'agent. Elle figure au Rulebook (une seule source
## de texte) et est vérifiée par le `ScoringService` (M5) via `procedure_id`
## (citations VISAGE NON CONTRÔLÉ, INTERROGATOIRE OMIS).
class_name ProcedureRule
extends Rule

const PROCEDURE_FACE_UNCOVERED: StringName = &"face_uncovered"
const PROCEDURE_TYCHO_INTERVIEW: StringName = &"tycho_interview"

@export var procedure_id: StringName = &""
## Origines concernées (vide = toutes).
@export var applies_to_faction_ids: Array[StringName] = []


func applies_to(case: Case) -> bool:
	return applies_to_faction_ids.is_empty() or applies_to_faction_ids.has(Rule.visible_origin(case))
