## Logique pure de la sélection A → B du Mode Inspection (UI_FLOW §3.2–§3.3),
## sans nœud ni signal global : testable seule. `ComparisonUI` traduit les
## actions renvoyées en signaux `EventBus` et en visuels.
class_name InspectionSelection
extends RefCounted

enum Action {
	IGNORED, ## mode inactif, référence nulle
	SELECTED_A, ## premier champ choisi
	DESELECTED, ## re-clic sur A → retour à l'état actif
	REPLACED_A, ## autre champ du même document : A est remplacé
	REQUESTED, ## paire A/B nouvelle → `discrepancy_check_requested(a, b)`
	ALREADY_DONE, ## paire déjà évaluée (ou en cours) → pulsation du lien
}

var active: bool = false
var a: FieldRef = null
## Clés de paires déjà demandées (`pair_key`).
var _requested: Dictionary[String, bool] = {}
## Résultats reçus par paire.
var results: Dictionary[String, Discrepancy] = {}
## Dernière paire demandée (b fixé par `select`).
var last_a: FieldRef = null
var last_b: FieldRef = null


## Clé de paire indépendante de l'ordre.
static func pair_key(p: FieldRef, q: FieldRef) -> String:
	var ka: String = p.key()
	var kb: String = q.key()
	return "%s|%s" % [ka, kb] if ka < kb else "%s|%s" % [kb, ka]


func set_active(enabled: bool) -> void:
	active = enabled
	if not enabled:
		a = null


## Nouveau cas : tout est oublié.
func reset() -> void:
	a = null
	last_a = null
	last_b = null
	_requested.clear()
	results.clear()


func cancel() -> bool:
	var had: bool = a != null
	a = null
	return had


func has_a() -> bool:
	return a != null


func select(ref: FieldRef) -> Action:
	if not active or ref == null:
		return Action.IGNORED
	if a == null:
		a = ref
		return Action.SELECTED_A
	if a.equals(ref):
		a = null
		return Action.DESELECTED
	# Même document (hors pseudo-documents) : le joueur a changé d'avis.
	if a.document_id == ref.document_id and a.is_document_field() and ref.is_document_field():
		a = ref
		return Action.REPLACED_A
	var key: String = pair_key(a, ref)
	last_a = a
	last_b = ref
	if _requested.has(key):
		a = null
		return Action.ALREADY_DONE
	_requested[key] = true
	a = null
	return Action.REQUESTED


## Enregistre un résultat ; renvoie vrai s'il correspond à une paire demandée.
func receive(result: Discrepancy) -> bool:
	if result == null or result.a == null or result.b == null:
		return false
	var key: String = pair_key(result.a, result.b)
	if not _requested.has(key):
		return false
	results[key] = result
	# Une paire incomparable peut être retentée (aucune pénalité, §3.3).
	if result.result == Discrepancy.Result.INCOMPARABLE:
		_requested.erase(key)
	return true


func is_requested(p: FieldRef, q: FieldRef) -> bool:
	return _requested.has(pair_key(p, q))


## Discordances confirmées, dans l'ordre de réception.
func confirmed() -> Array[Discrepancy]:
	var list: Array[Discrepancy] = []
	for key: String in results:
		var d: Discrepancy = results[key]
		if d.confirmed:
			list.append(d)
	return list
