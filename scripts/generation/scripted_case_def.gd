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

@export_group("Acte II")
## Condition d'activation (B25), en plus de `requires_flag` / `forbids_flags`.
## Plusieurs définitions peuvent viser le même index : la **première** active
## l'emporte (SC-35 a/b/c, SC-49, SC-50 a/b).
@export var condition: FlagCondition = null
## Visage fixé une fois pour toutes (Okonkwo, Ilan) : graine de
## `AppearanceGenerator.generate` (0 = visage du roster).
@export var fixed_appearance_seed: int = 0
## Répliques conditionnelles (`ConditionalKey.replaces` = suffixe remplacé),
## résolues sur les drapeaux du matin (`Case.line_overrides`).
@export var line_variants: Array[ConditionalKey] = []
## Documents d'un tiers (SC-27) : `{document_id: {truth_path: valeur}}` ; le
## document est ajouté au dossier, marqué `third_party`, valeurs imposées
## (`serial` accepté).
@export var third_party_documents: Dictionary = {}
## Répondre à la phrase de passe donne `lucioles_trust +1` (faux pour un
## Brûlant, SC-47) ; `flags_on_password` posés à la réponse.
@export var password_grants_trust: bool = true
@export var flags_on_password: Dictionary[StringName, int] = {}
## Dates imposées des documents du cas propre : `{document_id: {issue: jour,
## expiry: jour}}` (`GameDate`), ex. SC-48 (carte qui expire aujourd'hui).
@export var document_dates: Dictionary = {}

@export_group("Acte III")
## Répondant (R34) : N° ID du passager présenté par ce cas scénarisé du jour
## (SC-60 → SC-61…) ; le protégé est désactivé (passager généré) si le
## répondant scénarisé est absent.
@export var sponsor_case_id: StringName = &""
## Emplacement du réseau (SC-81b) : le cas prend le prochain index libre du
## groupe `DayDef.slot_groups[slot_group]` (dans l'ordre des données).
@export var slot_group: StringName = &""
## M1 : documents présentés quand même mais retirés du guichet (SC-58 :
## bio-scan) — `DocumentInstance.retired`, jamais lus par les règles.
@export var retired_documents: Array[StringName] = []

@export_group("M12")
## Répondant **généré** (R39, SC-95) : le passager généré de cet index devient
## un répondant né-Halcyon C-1–C-3 propre, et ce cas porte son N° ID
## (`sponsor_id`) ; −1 = aucun.
@export var sponsor_index: int = -1
## Émetteurs imposés des documents du cas propre : `{document_id: issuer_id}`
## (SC-101, SC-103 : bio-scan du Dispensaire de Tycho, R41).
@export var document_issuers: Dictionary = {}
## Règles remplacées pour **tout le jour** quand ce cas est actif (même
## identifiant, ressource propre au cas) : SC-89a, Long-Ruban retiré du
## registre (R26) seulement si le mot de Sefa a été remis. Appliqué par le
## `CaseBuilder` sur le RuleSet de shift (`RuleChangeDef` RETIRE + ADD).
@export var rule_replacements: Array[Rule] = []
## Visage = photo présentée par ce cas antérieur (`CaseMemory`, B59 : SC-84b,
## le vrai titulaire de la carte du J2) ; repli : visage du roster.
@export var appearance_from_photo: StringName = &""

@export_group("M13")
## Déclarations orales imposées (docs/M13.md §1.3, §1.12 ; B75) :
## `{id: {"value": …, "key": "stmt_…", "args": […], "vague": bool,
## "corrected_from": "stmt_…"}}` (`Statement.ID_*` ; durée : `Vector2i(min, max)`).
## Vide : réponses en prose libre (`<dialogue_id>_purpose`…), **aucune puce**.
@export var statements: Dictionary = {}
## Cadres de réponse imposés (`purpose` → `line_stmt_frame_*`), facultatifs.
@export var statement_frames: Dictionary = {}
## Contenu de la fouille imposé (M13 §2.10, J8+) : `[{"zone": "z3", "item":
## "ol10", "implant": "KIN-11", "qty": 0}]` ; vide = fouille générée (objets
## légitimes, **aucun indice**).
@export var search_items: Array[Dictionary] = []
## Indices visibles imposés (`SearchLayout.CUE_*`).
@export var search_cues: Array[StringName] = []
## Réponse à « Quelque chose à déclarer ? » (`Case.CARGO_*`) ; la réplique
## dédiée `<dialogue_id>_cargo` la porte. Vide : réponse générée.
@export var cargo_reply: StringName = &""
## Drapeaux posés si une fouille est faite pendant le cas (`{drapeau: delta}`,
## SC-105 `sc105_searched`), lus par le `DayController` (lot A).
@export var flags_on_search: Dictionary[StringName, int] = {}
