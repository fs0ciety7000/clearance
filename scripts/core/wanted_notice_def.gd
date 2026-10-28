## Entrée de l'avis de recherche d'un jour (M7, GDD §6 `WANTED_PERSON`, R22 ;
## NARRATIVE §4.7) — données de `DayDef.wanted_notices`.
##
## La personne recherchée est un passager du jour : un cas scénarisé
## (`scripted_case_id`) ou un passager généré à l'index `at_index`. Son
## portrait (et, par défaut, son nom) est celui du cas, calculé par le
## `CaseBuilder` au début du jour (`WantedNotice`). `given_name` /
## `family_name` remplacent le nom (SC-20 : la vraie identité « Arkady Novak »,
## alors que ses papiers d'emprunt disent « Bastien Duval »).
class_name WantedNoticeDef
extends Resource

@export var id: StringName = &""
@export var scripted_case_id: StringName = &""
## Index du passager généré recherché (−1 si scénarisé).
@export var at_index: int = -1
@export var given_name: String = ""
@export var family_name: String = ""
## Motif affiché (`wanted_novak_reason`…).
@export var reason_key: String = ""
