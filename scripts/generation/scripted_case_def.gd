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
## vrai si le delta vaut 0. APPROUVÉ → `flags_on_approve` ; REFUSÉ →
## `flags_on_deny` ; DÉTENTION → `flags_on_detain` (M7, repli `flags_on_deny`).
@export var flags_on_approve: Dictionary[StringName, int] = {}
@export var flags_on_deny: Dictionary[StringName, int] = {}

@export_group("M7")
## DÉTENTION (NARRATIVE B3) ; vide → `flags_on_deny`.
@export var flags_on_detain: Dictionary[StringName, int] = {}
## Posés si le cas n'est pas traité avant la fin du shift (`final_unprocessed`).
@export var flags_if_unprocessed: Dictionary[StringName, int] = {}
## Effets conditionnels supplémentaires (verdict × drapeaux).
@export var extra_effects: Array[CaseEffectDef] = []
## Drapeaux qui empêchent le cas (remplacé par un passager généré, B4).
@export var forbids_flags: Array[StringName] = []
## Continuité (B5) : visage / identité d'un cas scénarisé d'un jour antérieur
## (`CaseMemory`) ; les `appearance_overrides` s'appliquent par-dessus.
@export var appearance_from_case: StringName = &""
@export var identity_from_case: StringName = &""
## Surcharges de la **vraie** identité (`CaseKey.truth`) après injection
## (SC-13 : Lev Petrenko derrière les papiers de Soren Whitmore).
@export var truth_overrides: Dictionary = {}
## Documents ajoutés au dossier (SC-11 : dérogation d'implant militaire).
@export var extra_documents: Array[StringName] = []
## Objet glissé avec les papiers (enveloppe, mot, carte de quai).
@export var slipped_item: SlippedItemDef = null
## Codes Lucioles portés (LORE §7) ; `injection_params` : `mrz_issuer`
## (code 2, « 07 »), `permit_suffix` (code 3, dernier chiffre du permis).
@export var luciole_codes: PackedInt32Array = []
## Étiquettes de dialogue supplémentaires (`luciole_password`…).
@export var extra_tags: Array[StringName] = []
