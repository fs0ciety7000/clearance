## Transport des requêtes en ligne (M16) — interface injectable.
##
## `HttpTransport` (réseau réel, `HTTPRequest` non bloquant) et
## `FakeOnlineServer` (faux serveur en mémoire : tests GUT, captures) en
## héritent. `send()` ne bloque jamais : la requête est terminée plus tard
## (ou tout de suite) par `OnlineRequest.finish()`.
## `sent` compte les requêtes émises (tests : « aucune requête pendant un shift »).
class_name OnlineTransport
extends RefCounted

## Nombre de requêtes émises depuis la création.
var sent: int = 0
## URL de base (`OnlineConfig.base_url`).
var base_url: String = OnlineConfig.DEFAULT_BASE_URL


## Émet la requête ; à surcharger (appeler `super` pour le compteur).
func send(_req: OnlineRequest) -> void:
	sent += 1


## Abandonne les requêtes en cours (arrêt du service).
func cancel_all() -> void:
	pass
