## Entrée résolue de l'onglet « Révocations » d'un jour (Acte II, R30) :
## N° ID révoqué (et nom du titulaire), publiée par
## `EventBus.revocations_published` et lue par `RevokedIdRule` via
## `RuleContext.revoked`. Pseudo-référence sélectionnable en Mode Inspection :
## `FieldRef.revoked(id)` (paire « N° ID (carte) ↔ onglet Révocations »).
class_name RevokedEntry
extends RefCounted

var id: StringName = &""
var citizen_id: String = ""
var given_name: String = ""
var family_name: String = ""
var reason_key: String = ""
## Index du passager concerné dans la file du jour (−1 : leurre sans passager).
var case_index: int = -1
## Acte III (R33) : date de réintégration (`GameDate`), 0 = non réintégré·e
## (colonne « RÉINTÉGRÉ·E LE » ; `reinstated_reason_key` sinon : exclusion).
var reinstated_on: int = 0
var excluded_reason_key: String = ""


## Réintégré·e à la date `today` (date de réintégration atteinte).
func is_reinstated(today: int) -> bool:
	return reinstated_on > 0 and reinstated_on <= today


func full_name() -> String:
	return "%s %s" % [given_name, family_name]


func get_ref() -> FieldRef:
	return FieldRef.revoked(id)
