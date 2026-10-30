## Événement de station (M12 §3, D-129 ; ARCHITECTURE §11.6) — EV-01 → EV-08,
## `res://data/events/ev_NN.tres` (lot B), référencés par `StationEventsDef`.
class_name StationEventDef
extends Resource

enum EventClass { A = 1, B = 2 }
## Fenêtre d'effet.
enum WindowKind {
	PASSENGERS = 0,  ## `window_passengers` passagers après l'annonce
	REST_OF_DAY = 1,  ## jusqu'à la fin du jour, après le dernier cas scénarisé
	CLOCK = 2,  ## plage d'horloge `clock_from` → `clock_to` (EV-08)
	SECONDS = 3,  ## `window_seconds` s réelles (EV-05), entre deux passagers
}

## `ev_01`… ; préfixe de texte `sev_<key>_` (`key` : `mrz_reader`…).
@export var id: StringName = &""
@export var key: StringName = &""
@export var event_class: EventClass = EventClass.A
## Règle active nécessaire ce jour (`r_mrz_valid`…), vide = aucune.
@export var required_rule_id: StringName = &""
## Bornes de jour de campagne (incluses ; 0 = sans borne).
@export var day_min: int = 0
@export var day_max: int = 0
@export var window_kind: WindowKind = WindowKind.PASSENGERS
@export var window_passengers: int = 4
## Décalage de l'effet après l'annonce, en passagers (EV-07 : 1 = « du 2ᵉ
## passager après l'annonce »).
@export var start_delay: int = 0
@export var clock_from: int = -1
@export var clock_to: int = -1
@export var window_seconds: float = 60.0
## Changements de règles pendant la fenêtre (défaits à la fin).
@export var changes: Array[RuleChangeDef] = []
## Annonce (texte du haut-parleur), bandeau, ligne Rulebook, fin.
@export var announce_key: String = ""
@export var title_key: String = ""
@export var rulebook_key: String = ""
@export var end_key: String = ""
## Liste nommée publiée pendant la fenêtre (EV-07 : `stolen`) et taille.
@export var list_label: StringName = &""
@export var list_size: int = 0
## Garde de nuit.
@export var garde_allowed: bool = true
@export var garde_window_passengers: int = 5
## Unité de Garde nécessaire (`u05` pour EV-01…), vide = aucune.
@export var garde_required_unit: StringName = &""
## Changements propres à la Garde (EV-04 : points doubles) ; vide = `changes`.
@export var garde_changes: Array[RuleChangeDef] = []
@export var garde_announce_key: String = ""
## D-138 (QA-062) : titre du bandeau et ligne du Rulebook propres à la Garde
## (fenêtre exprimée en passagers : EV-08 « pour les 5 prochains passagers ») ;
## vide = `title_key` / `rulebook_key`. Lus par `StationEventPlan.title_key()`
## / `rulebook_key()`.
@export var garde_title_key: String = ""
@export var garde_rulebook_key: String = ""
## M13 (EV-09, D-153) : profils tirés par plan (graine du jour, ou de la
## directive en Garde) ; chacun redéfinit la **portée** des surcharges
## (`OVERRIDE`) : `{"faction_ids": Array[StringName], "purposes":
## Array[StringName], "label_key": String}` (`label_key` : argument `%s` de
## l'annonce et de la ligne du Rulebook). Vide = portée des données.
@export var override_profiles: Array[Dictionary] = []


func is_class_b() -> bool:
	return event_class == EventClass.B
