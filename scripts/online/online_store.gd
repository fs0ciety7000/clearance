## Fichiers locaux du client en ligne (M16) — jamais envoyés, jamais dans les
## sauvegardes synchronisées.
##
## Dossier (`default_dir`) : `user://online/` (jeu complet), `user://demo/online/`
## (démo, compte séparé : familles `demo_*` du serveur), `<racine de test>/online/`
## quand `SaveService.use_root` redirige les sauvegardes (tests GUT, captures :
## jamais le vrai `user://`).
## - `account.json` : jeton, `user_id`, `pseudo`, `tag`, adresse (affichée
##   masquée dans Options › Compte, jamais journalisée), date du jeton,
##   `auto_sync`, `api_url` (réglage **caché**), dernière synchronisation ;
## - `sync_state.json` : par compte et par famille, l'**état de base** de
##   chaque emplacement (dernier état identique des deux côtés : empreinte,
##   `rev` de la méta distante, `save_serial`, `saved_unix_ms`) et du profil ;
## - `outbox.json` : par compte, scores de Garde en attente, fins envoyées ;
## - `cache.json` : statistiques des fins et classements (lecture hors ligne).
## Écriture atomique (`SaveService.write_atomic`), lecture de secours.
class_name OnlineStore
extends RefCounted

const ACCOUNT_FILE: String = "account.json"
const SYNC_FILE: String = "sync_state.json"
const OUTBOX_FILE: String = "outbox.json"
const CACHE_FILE: String = "cache.json"
const FULL_DIR: String = "user://online"
const DEMO_DIR: String = "user://demo/online"
## Scores de Garde gardés en file au plus (les plus anciens tombent).
const OUTBOX_MAX: int = 50
## Classements gardés en cache au plus.
const CACHE_BOARDS: int = 20

var dir: String = ""
var account: Dictionary = {}
var sync_state: Dictionary = {}
var outbox: Dictionary = {}
var cache: Dictionary = {}


func _init(p_dir: String = "") -> void:
	dir = p_dir if not p_dir.is_empty() else default_dir()
	reload()


## Dossier par défaut d'après le dossier des sauvegardes résolu.
static func default_dir(save_dir: String = SaveService.DEFAULT_DIR) -> String:
	var saves: String = SaveService.resolve_dir(save_dir)
	if saves == SaveService.DEFAULT_DIR:
		return FULL_DIR
	if saves == DemoMode.SAVES_DIR:
		return DEMO_DIR
	return saves.path_join("online")


func reload() -> void:
	account = _read(ACCOUNT_FILE)
	sync_state = _read(SYNC_FILE)
	outbox = _read(OUTBOX_FILE)
	cache = _read(CACHE_FILE)
	if not account.has("auto_sync"):
		account["auto_sync"] = true


func _read(file: String) -> Dictionary:
	return SaveService.read_json(dir.path_join(file))


func _write(file: String, data: Dictionary) -> Error:
	return SaveService.write_atomic(dir.path_join(file), JSON.stringify(data, "\t", true))


# --- Compte ---------------------------------------------------------------------------

func token() -> String:
	return str(account.get("token", ""))


func user_id() -> String:
	return str(account.get("user_id", ""))


func has_account() -> bool:
	return not token().is_empty() and not user_id().is_empty()


func auto_sync() -> bool:
	var value: Variant = account.get("auto_sync", true)
	return value is bool and value


func set_auto_sync(on: bool) -> void:
	account["auto_sync"] = on
	save_account()


## Réglage caché : URL de l'API (vide = production).
func api_url() -> String:
	return str(account.get("api_url", ""))


## Jeton et fiche publique reçus (`{token, record}` d'ONLINE.md §2.2).
func set_session(p_token: String, record: Dictionary, email: String = "") -> void:
	account["token"] = p_token
	account["token_unix"] = int(Time.get_unix_time_from_system())
	account["user_id"] = str(record.get("id", account.get("user_id", "")))
	account["pseudo"] = str(record.get("pseudo", ""))
	account["tag"] = str(record.get("tag", ""))
	if not email.is_empty():
		account["email"] = email.strip_edges()
	save_account()


## Oublie le jeton (déconnexion locale) ; garde adresse, réglages et bases.
func clear_session() -> void:
	for key: String in ["token", "token_unix", "user_id", "pseudo", "tag"]:
		account.erase(key)
	save_account()


## Oublie tout ce qui concerne le compte `uid` (suppression du compte).
func forget_user(uid: String) -> void:
	clear_session()
	account.erase("email")
	account.erase("last_sync_unix_ms")
	sync_state.erase(uid)
	outbox.erase(uid)
	save_account()
	_write(SYNC_FILE, sync_state)
	_write(OUTBOX_FILE, outbox)


func token_age_s() -> int:
	return int(Time.get_unix_time_from_system()) - SaveService.as_int(account.get("token_unix", 0))


func save_account() -> Error:
	return _write(ACCOUNT_FILE, account)


# --- États de base de la synchronisation -------------------------------------------

## Base d'un élément (`slot_N`, `profile`) pour le compte et la famille ; vide si inconnue.
func base(family: String, item: String) -> Dictionary:
	var by_user: Dictionary = sync_state.get(user_id(), {}) if sync_state.get(user_id()) is Dictionary else {}
	var by_family: Dictionary = by_user.get(family, {}) if by_user.get(family) is Dictionary else {}
	return by_family.get(item, {}) if by_family.get(item) is Dictionary else {}


func set_base(family: String, item: String, value: Dictionary) -> void:
	var uid: String = user_id()
	if uid.is_empty():
		return
	if not sync_state.get(uid) is Dictionary:
		sync_state[uid] = {}
	var by_user: Dictionary = sync_state[uid]
	if not by_user.get(family) is Dictionary:
		by_user[family] = {}
	var by_family: Dictionary = by_user[family]
	if value.is_empty():
		by_family.erase(item)
	else:
		by_family[item] = value.duplicate(true)
	_write(SYNC_FILE, sync_state)


# --- File d'envoi ----------------------------------------------------------------------

func _user_outbox() -> Dictionary:
	var uid: String = user_id()
	if not outbox.get(uid) is Dictionary:
		outbox[uid] = {"garde": [], "endings_sent": []}
	var box: Dictionary = outbox[uid]
	if not box.get("garde") is Array:
		box["garde"] = []
	if not box.get("endings_sent") is Array:
		box["endings_sent"] = []
	return box


func pending_scores() -> Array:
	return _user_outbox()["garde"]


func queue_score(body: Dictionary) -> void:
	var list: Array = pending_scores()
	var key: String = str(body.get("_key", ""))
	for entry: Variant in list:
		if entry is Dictionary and str((entry as Dictionary).get("_key", "")) == key and not key.is_empty():
			return
	list.append(body.duplicate(true))
	while list.size() > OUTBOX_MAX:
		list.remove_at(0)
	_write(OUTBOX_FILE, outbox)


func drop_score(key: String) -> void:
	var list: Array = pending_scores()
	for i: int in range(list.size() - 1, -1, -1):
		if list[i] is Dictionary and str((list[i] as Dictionary).get("_key", "")) == key:
			list.remove_at(i)
	_write(OUTBOX_FILE, outbox)


## Fins déjà envoyées (`"<id>:<variante>"`).
func endings_sent() -> Array:
	return _user_outbox()["endings_sent"]


func mark_ending_sent(key: String) -> void:
	var list: Array = endings_sent()
	if not list.has(key):
		list.append(key)
		_write(OUTBOX_FILE, outbox)


# --- Caches ----------------------------------------------------------------------------

func cached(key: String) -> Dictionary:
	return cache.get(key, {}) if cache.get(key) is Dictionary else {}


func set_cached(key: String, data: Dictionary) -> void:
	cache[key] = {"unix_ms": int(Time.get_unix_time_from_system() * 1000.0), "data": data.duplicate(true)}
	# Classements : les `CACHE_BOARDS` plus récents seulement.
	var boards: Array = []
	for k: Variant in cache.keys():
		if str(k).begins_with("leaderboard:"):
			boards.append(k)
	if boards.size() > CACHE_BOARDS:
		boards.sort_custom(func(a: Variant, b: Variant) -> bool:
			return SaveService.as_int((cache[a] as Dictionary).get("unix_ms", 0)) < SaveService.as_int((cache[b] as Dictionary).get("unix_ms", 0)))
		for i: int in boards.size() - CACHE_BOARDS:
			cache.erase(boards[i])
	_write(CACHE_FILE, cache)
