## Entrée de la liste des révocations d'un jour (Acte II, R30, onglet
## « Révocations » ; docs/ACT2.md §2.4, B20) — données de `DayDef.revocations`.
##
## Comme un avis de recherche (D-056), l'entrée est liée à un passager du
## jour : un cas scénarisé (`scripted_case_id`, SC-40/41/45) ou un passager
## généré à l'index `at_index`. Son N° ID est celui de la carte présentée par
## ce passager, calculé par le `CaseBuilder` au début du jour (`RevokedEntry`).
class_name RevocationDef
extends Resource

@export var id: StringName = &""
@export var scripted_case_id: StringName = &""
## Index du passager généré révoqué (−1 si scénarisé).
@export var at_index: int = -1
## Motif affiché (`revoked_reason_*`), facultatif.
@export var reason_key: String = ""
## Condition sur les drapeaux du matin (null = toujours).
@export var condition: FlagCondition = null
## Acte III (R33) : date de réintégration (`GameDate`), 0 = aucune ; un
## passager généré réintégré est un **bruit légitime** (pas d'anomalie).
@export var reinstated_on: int = 0
## Acte III : motif d'exclusion de la réintégration (`rb_reinstated_excluded`).
@export var excluded_reason_key: String = ""
