## Convocation de l'Enquête d'un jour (Acte III, R36, onglet « Convocations »)
## — données de `DayDef.summons`. Comme une révocation (D-056), l'entrée est
## liée à un passager du jour : un cas scénarisé (`scripted_case_id`) ou un
## passager généré à `at_index` ; N° et nom sont ceux de son permis, calculés
## par le `CaseBuilder` au début du jour (`SummonsEntry`).
class_name SummonsDef
extends Resource

@export var id: StringName = &""
@export var scripted_case_id: StringName = &""
## Index du passager généré convoqué (−1 si scénarisé).
@export var at_index: int = -1
@export var reason_key: String = ""
@export var condition: FlagCondition = null
