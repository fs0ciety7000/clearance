## Passager scénarisé injecté à un index donné d'un jour (ARCHITECTURE §5.2,
## GDD §12), généré par la même chaîne que les autres (`CaseBuilder`, M3).
##
## `forced_anomalies` est la liste **exacte** des anomalies du cas (vide = cas
## propre). `passenger_overrides` : clés = `Passenger.TRUTH_PATHS` (l'origine
## et la date de naissance sont lues dès le roster d'apparences).
class_name ScriptedCaseDef
extends Resource

## Identifiant narratif (`&"sc_01"`, `&"tuto_concordant"`…).
@export var id: StringName = &""
@export var at_index: int = 0
@export var passenger_overrides: Dictionary = {}
## Traits imposés (slot → option), ex. `{&"headwear": &"visor_down"}`.
@export var appearance_overrides: Dictionary[StringName, StringName] = {}
@export var forced_anomalies: Array[AnomalyType.Kind] = []
## Paramètres des injecteurs (ajout M3), clés `StringName` : `document_id`
## (document ciblé), `expired_days`, `trait_count` (slots de visage modifiés),
## `char_count` (caractères du N° ID), `field_path` (`truth_path` altéré),
## `photo_noise` (bool : bruit légitime sur la photo).
@export var injection_params: Dictionary = {}
## Préfixe des répliques dédiées (`<dialogue_id>_arrival`, `_present`,
## `_purpose`, `_about_<raison>`, `_note`…) ; posé dans `Case.dialogue_tags`.
@export var dialogue_id: StringName = &""
## Drapeau mis à vrai dès que le passager a été traité (M5).
@export var sets_flag: StringName = &""
@export var requires_flag: StringName = &""
## Conséquences narratives du verdict (M5, GDD §11.1, §12) : `{drapeau: delta}`
## ajouté aux jauges entières (`lucioles_trust`, `loyalty`…) ou drapeau mis à
## vrai si le delta vaut 0. APPROUVÉ → `flags_on_approve` ; REFUSÉ ou
## DÉTENTION → `flags_on_deny`.
@export var flags_on_approve: Dictionary[StringName, int] = {}
@export var flags_on_deny: Dictionary[StringName, int] = {}
