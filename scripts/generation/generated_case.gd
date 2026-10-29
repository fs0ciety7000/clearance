## Produit du `CaseBuilder` : le cas vu par le joueur et sa clé de réponse,
## plus des informations de diagnostic (outil de stats, tests).
## `case` voyage vers l'UI ; `key` reste chez DayController/ScoringService.
class_name GeneratedCase
extends RefCounted

var case: Case = null
var key: CaseKey = null
## Cas scénarisé appliqué (`ScriptedCaseDef.id`), vide sinon.
var scripted_id: StringName = &""
## Essais nécessaires pour obtenir un cas propre (1 = du premier coup).
var clean_attempts: int = 1
## Violations du cas propre retenu, **avant** injection (0 attendu, §9.2 étape 4).
var clean_violation_count: int = 0
## Bruit légitime sur la photo (coupe différente, photo ancienne).
var photo_noise: bool = false
## Acte III (R32) : un document expiré dans la fenêtre de prorogation (bruit
## légitime : valide).
var prorogation_noise: bool = false
## Passager arrivé visière baissée (D-021).
var visor_down: bool = false
## Nombre d'anomalies tirées (avant échecs d'injection éventuels).
var requested_anomalies: int = 0
## Violations des invariants (§6, §9.3) ; vide en fonctionnement normal.
var invariant_errors: PackedStringArray = []


func get_anomaly_kinds() -> Array[AnomalyType.Kind]:
	var kinds: Array[AnomalyType.Kind] = []
	for anomaly: Anomaly in key.anomalies:
		kinds.append(anomaly.type)
	return kinds


func has_face_anomaly() -> bool:
	for anomaly: Anomaly in key.anomalies:
		if CaseBuilder.FACE_ANOMALIES.has(anomaly.type):
			return true
	return false
