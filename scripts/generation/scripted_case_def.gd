## Passager scénarisé injecté à un index donné d'un jour (ARCHITECTURE §5.2,
## GDD §12). Définition seulement : la génération arrive en M3.
##
## `forced_anomalies` est la liste **exacte** des anomalies du cas (vide = cas
## propre). `passenger_overrides` : clés = `Passenger.TRUTH_PATHS`.
class_name ScriptedCaseDef
extends Resource

## Identifiant narratif (`&"sc_01"`, `&"tuto_concordant"`…).
@export var id: StringName = &""
@export var at_index: int = 0
@export var passenger_overrides: Dictionary = {}
## Traits imposés (slot → option), ex. `{&"headwear": &"visor_down"}`.
@export var appearance_overrides: Dictionary[StringName, StringName] = {}
@export var forced_anomalies: Array[AnomalyType.Kind] = []
@export var dialogue_id: StringName = &""
@export var sets_flag: StringName = &""
@export var requires_flag: StringName = &""
