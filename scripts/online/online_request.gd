## Une requête vers l'API (M16, `docs/ONLINE.md`) et sa réponse.
##
## Créée par `OnlineClient`, exécutée par un `OnlineTransport` (HTTP réel ou
## faux serveur) qui renseigne la réponse puis appelle `finish()` (signal
## `completed`, une seule fois). Le transport peut terminer tout de suite
## (faux serveur synchrone) : l'appelant teste `done` avant d'attendre.
## Aucune donnée personnelle dans `describe()` (journaux) : ni corps, ni jeton.
class_name OnlineRequest
extends RefCounted

signal completed()

enum Failure {
	NONE, ## réponse HTTP reçue (voir `status`)
	NETWORK, ## hôte injoignable, TLS, connexion coupée
	TIMEOUT, ## délai dépassé
	PARSE, ## corps illisible
	CANCELLED, ## abandonnée (service arrêté)
}

var method: String = "GET"
## Chemin (`/api/clearance/status`) et requête (`{"seed": …}`), encodée par `url()`.
var path: String = ""
var query: Dictionary = {}
## Corps JSON (dictionnaire) ; `null` : pas de corps.
var body: Variant = null
## Jeton d'authentification (en-tête `Authorization`), vide sinon.
var token: String = ""
var timeout_s: float = OnlineConfig.REQUEST_TIMEOUT_S

var done: bool = false
var failure: Failure = Failure.NONE
## Code HTTP (0 sans réponse).
var status: int = 0
## Corps de réponse décodé (dictionnaire vide si absent ou non objet).
var response: Dictionary = {}


static func make(p_method: String, p_path: String, p_body: Variant = null, p_token: String = "",
		p_query: Dictionary = {}) -> OnlineRequest:
	var req: OnlineRequest = OnlineRequest.new()
	req.method = p_method
	req.path = p_path
	req.body = p_body
	req.token = p_token
	req.query = p_query
	return req


## Chemin + requête encodée (`?seed=NUIT-2026-11-01&limit=10`).
func url_path() -> String:
	if query.is_empty():
		return path
	var parts: PackedStringArray = []
	var keys: Array = query.keys()
	keys.sort()
	for key: Variant in keys:
		parts.append("%s=%s" % [str(key).uri_encode(), str(query[key]).uri_encode()])
	return path + "?" + "&".join(parts)


## Termine la requête (idempotent) et émet `completed`.
func finish(p_status: int, p_response: Dictionary = {}, p_failure: Failure = Failure.NONE) -> void:
	if done:
		return
	status = p_status
	response = p_response
	failure = p_failure
	done = true
	completed.emit()


func ok() -> bool:
	return failure == Failure.NONE and status >= 200 and status < 300


## Erreur transitoire : réseau, délai, 429 ou 5xx (seules à réessayer, ONLINE.md §1).
func is_transient() -> bool:
	return failure == Failure.NETWORK or failure == Failure.TIMEOUT or status == 429 or status >= 500


## Pas de réponse exploitable du serveur (hors ligne).
func is_offline() -> bool:
	return failure == Failure.NETWORK or failure == Failure.TIMEOUT or status >= 500


## Code d'erreur stable (`code` des routes `/api/clearance/*`), vide sinon.
func error_code() -> String:
	return str(response.get("code", "")) if response.get("code") is String else ""


## Délai demandé par un `429 rate_limited` (`data.retry_after_s`), 0 sinon.
func retry_after_s() -> float:
	var data: Variant = response.get("data", {})
	if data is Dictionary and ((data as Dictionary).get("retry_after_s") is float or (data as Dictionary).get("retry_after_s") is int):
		return float((data as Dictionary)["retry_after_s"])
	return 0.0


## Résumé pour les journaux : méthode, chemin **sans requête**, statut. Jamais
## de corps, de jeton ni d'adresse.
func describe() -> String:
	return "%s %s → %s" % [method, path, str(status) if failure == Failure.NONE else Failure.keys()[failure]]
