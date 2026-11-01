## Client en ligne (M16, D-230 → D-235 ; contrat `docs/ONLINE.md`) — état du
## compte, connexion par code, synchronisation des sauvegardes, classement de
## la Garde, statistiques des fins.
##
## `RefCounted` sans nœud ni autoload : le transport (`OnlineTransport` : HTTP
## réel ou `FakeOnlineServer`), les fichiers locaux (`OnlineStore`) et le
## dossier des sauvegardes sont injectés — deux clients sur deux dossiers et
## un même faux serveur simulent deux appareils (tests). L'autoload
## `OnlineService` en possède un et le relie au jeu (EventBus, écran titre,
## shifts).
## - **Hors ligne d'abord** : sans compte, aucune requête ; réseau absent :
##   état `OFFLINE`, les données locales ne bougent pas, rien n'est perdu.
## - **Silence pendant un shift** (`quiet`) : aucune requête n'est émise ;
##   ce qui était demandé part à la fin du shift (`set_quiet(false)`).
## - Nouvelles tentatives espacées (`retry_delays`, ONLINE.md §1) sur erreur
##   réseau, 429 ou 5xx seulement ; `waiter(s) -> Signal` attend (nœud hôte),
##   nul : sans attente (tests).
## - Journaux : jamais l'adresse ni le jeton (`OnlineRequest.describe`).
## Les méthodes réseau sont des coroutines (`await client.sync_all()`) ; avec
## un transport synchrone (faux serveur) elles se terminent dans l'appel.
class_name OnlineClient
extends RefCounted

signal state_changed(state: State)
## Fin d'une synchronisation : `{ok, pulled, pushed, conflicts, detached, errors, profile}`.
signal sync_finished(report: Dictionary)
## Des emplacements locaux ont été réécrits (tirage, conflit) → `save_slots_changed`.
signal slots_changed()
## Le profil local a été réécrit (fusion) → `profile_changed`.
signal profile_changed()
signal code_requested()
signal signed_in()
signal signed_out()
## Pseudo, tag ou compte changés (Options › Compte).
signal account_changed()
signal leaderboard_updated(key: String, data: Dictionary)
signal ending_stats_updated(stats: Dictionary)
## Réponse à l'envoi d'un score (`{improved, best, rank, total}`), clé de la garde.
signal garde_submitted(key: String, result: Dictionary)

enum State {
	DISCONNECTED, ## pas de compte (ou session expirée)
	CONNECTING, ## connexion en cours (code, jeton, premier contact)
	CONNECTED, ## compte et serveur joignable
	OFFLINE, ## compte, serveur injoignable : tout reste local
	ERROR, ## compte, mais refus du serveur (version d'API, quota…)
}

## Erreurs (`last_error`) — clés stables, traduites par l'interface.
const ERR_NETWORK: String = "network"
const ERR_SESSION: String = "session_expired"
const ERR_EMAIL: String = "email_invalid"
const ERR_OTP: String = "otp_invalid"
const ERR_OTP_LOCKED: String = "otp_locked"
const ERR_OTP_MISSING: String = "otp_missing"
const ERR_RATE: String = "rate_limited"
const ERR_API: String = "api_version"
const ERR_QUOTA: String = "quota"
const ERR_TOO_LARGE: String = "too_large"
const ERR_PSEUDO: String = "pseudo_invalid"
const ERR_FUTURE: String = "version_future"
const ERR_SERVER: String = "server"
const ERR_QUIET: String = "quiet"
const ERR_NO_ACCOUNT: String = "no_account"

var transport: OnlineTransport = null
var store: OnlineStore = null
## Dossier des sauvegardes (`SaveService.DEFAULT_DIR`, ou un dossier de test).
var save_dir: String = SaveService.DEFAULT_DIR
## Famille de données (`game` / `demo`, `SaveSync.family`).
var family: String = SaveSync.FAMILY_GAME
var state: State = State.DISCONNECTED
var last_error: String = ""
var retry_delays: Array[float] = OnlineConfig.RETRY_DELAYS_S.duplicate()
var waiter: Callable = Callable()
## Emplacement de la partie en cours (jamais remplacé par un tirage pendant
## qu'elle est chargée) ; `SaveService.NO_SLOT` à l'écran titre.
var protected_slot: int = SaveService.NO_SLOT
## Réponse de `GET /api/clearance/status` (limites, longueur du code).
var server_status: Dictionary = {}
## Dernier rapport de synchronisation.
var last_report: Dictionary = {}
## Synchronisation, envoi des scores, fins : à faire dès que possible.
var pending_sync: bool = false
var pending_outbox: bool = false

var _quiet: bool = false
var _syncing: bool = false
var _resync: bool = false
var _flushing: bool = false
var _otp_id: String = ""
var _otp_email: String = ""


func _init(p_transport: OnlineTransport = null, p_store: OnlineStore = null, p_save_dir: String = SaveService.DEFAULT_DIR) -> void:
	transport = p_transport if p_transport != null else OnlineTransport.new()
	save_dir = p_save_dir
	store = p_store if p_store != null else OnlineStore.new(OnlineStore.default_dir(p_save_dir))
	family = SaveSync.family()
	# Compte connu mais pas encore de contact avec le serveur : hors ligne
	# jusqu'à `start()` (aucune requête avant l'écran titre).
	state = State.OFFLINE if store.has_account() else State.DISCONNECTED


# ---------------------------------------------------------------------------
# État
# ---------------------------------------------------------------------------

func has_account() -> bool:
	return store.has_account()


func is_connected_online() -> bool:
	return state == State.CONNECTED


func is_quiet() -> bool:
	return _quiet


## Pendant un shift : aucune requête. À la fin : ce qui attendait part.
func set_quiet(value: bool) -> void:
	if _quiet == value:
		return
	_quiet = value
	if not _quiet:
		flush_pending()


## Code demandé, en attente de saisie.
func awaiting_code() -> bool:
	return not _otp_id.is_empty()


func pending_email() -> String:
	return _otp_email


## Nom affiché du joueur : pseudo, sinon « Agent·e #TAG » (clé `online_agent_tag`).
func display_name() -> String:
	return display_name_of(str(store.account.get("pseudo", "")), str(store.account.get("tag", "")))


static func display_name_of(pseudo: String, tag: String) -> String:
	if not pseudo.strip_edges().is_empty():
		return pseudo.strip_edges()
	return UiText.tf("online_agent_tag", [tag if not tag.is_empty() else "????"], "Agent·e #%s")


func _set_state(value: State, error: String = "") -> void:
	last_error = error
	if state == value:
		return
	state = value
	state_changed.emit(state)


## Longueur du code à saisir (statut du serveur, sinon 6).
func otp_length() -> int:
	var otp: Variant = server_status.get("otp", {})
	if otp is Dictionary:
		return clampi(SaveService.as_int((otp as Dictionary).get("length", OnlineConfig.OTP_LENGTH)), 4, 10)
	return OnlineConfig.OTP_LENGTH


# ---------------------------------------------------------------------------
# Envoi (silence, nouvelles tentatives)
# ---------------------------------------------------------------------------

## Envoie une requête (une seule tentative). Pendant un shift : rien n'est
## émis, la requête est rendue `CANCELLED`.
func _send(req: OnlineRequest) -> OnlineRequest:
	if _quiet:
		req.finish(0, {}, OnlineRequest.Failure.CANCELLED)
		return req
	transport.send(req)
	if not req.done:
		await req.completed
	return req


## Envoie avec nouvelles tentatives espacées (réseau, 429, 5xx).
func _send_retry(req: OnlineRequest) -> OnlineRequest:
	var attempt: int = 0
	var current: OnlineRequest = req
	while true:
		current = await _send(current)
		if current.ok() or not current.is_transient() or attempt >= retry_delays.size():
			return current
		var delay: float = maxf(retry_delays[attempt], current.retry_after_s())
		attempt += 1
		if delay > 0.0 and waiter.is_valid():
			var signal_value: Variant = waiter.call(delay)
			if signal_value is Signal:
				await (signal_value as Signal)
		if _quiet:
			current.failure = OnlineRequest.Failure.CANCELLED
			return current
		current = _clone(current)
	return current


static func _clone(req: OnlineRequest) -> OnlineRequest:
	var copy: OnlineRequest = OnlineRequest.make(req.method, req.path, req.body, req.token, req.query)
	copy.timeout_s = req.timeout_s
	return copy


## Requête authentifiée.
func _authed(method: String, path: String, body: Variant = null, query: Dictionary = {}) -> OnlineRequest:
	return OnlineRequest.make(method, path, body, store.token(), query)


## Suite commune après une réponse : hors ligne, session expirée, connecté.
## Renvoie vrai si la réponse est exploitable (2xx).
func _note(req: OnlineRequest) -> bool:
	if req.failure == OnlineRequest.Failure.CANCELLED:
		last_error = ERR_QUIET
		return false
	if req.is_offline():
		if has_account():
			_set_state(State.OFFLINE, ERR_NETWORK)
		else:
			last_error = ERR_NETWORK
		return false
	if req.status == 401 and not req.token.is_empty():
		push_warning("OnlineClient: session refusée (%s)" % req.describe())
		store.clear_session()
		_set_state(State.DISCONNECTED, ERR_SESSION)
		signed_out.emit()
		return false
	if has_account() and state != State.ERROR:
		_set_state(State.CONNECTED)
	return req.ok()


static func _error_of(req: OnlineRequest) -> String:
	if req.failure == OnlineRequest.Failure.CANCELLED:
		return ERR_QUIET
	if req.is_offline():
		return ERR_NETWORK
	match req.status:
		401:
			return ERR_SESSION
		403:
			return ERR_QUOTA if req.error_code() == "quota_exceeded" else ERR_SERVER
		413:
			return ERR_TOO_LARGE
		429:
			return ERR_OTP_LOCKED if req.error_code() == "otp_locked" else ERR_RATE
	return ERR_SERVER


# ---------------------------------------------------------------------------
# Démarrage, jeton
# ---------------------------------------------------------------------------

## Premier contact (écran titre) : statut et version d'API, jeton rafraîchi
## s'il a plus de 24 h ; puis ce qui attendait (synchronisation si
## automatique, scores, fins). Sans compte : rien.
func start() -> void:
	if not has_account() or _quiet:
		return
	_set_state(State.CONNECTING)
	var status_req: OnlineRequest = await _send_retry(OnlineRequest.make("GET", "/api/clearance/status"))
	if not _note(status_req):
		if state == State.CONNECTING:
			_set_state(State.OFFLINE, ERR_NETWORK if status_req.is_offline() else ERR_SERVER)
		return
	server_status = status_req.response
	if SaveService.as_int(server_status.get("api_version", OnlineConfig.API_VERSION)) != OnlineConfig.API_VERSION:
		_set_state(State.ERROR, ERR_API)
		return
	if store.token_age_s() > OnlineConfig.TOKEN_REFRESH_AFTER_S:
		await refresh_token()
		if not has_account():
			return
	_set_state(State.CONNECTED)
	if store.auto_sync():
		pending_sync = true
	pending_outbox = true
	await flush_pending()


## Rafraîchit le jeton (ONLINE.md §2.3).
func refresh_token() -> bool:
	var req: OnlineRequest = await _send_retry(_authed("POST", "/api/collections/users/auth-refresh"))
	if not _note(req):
		return false
	var new_token: String = str(req.response.get("token", ""))
	if new_token.is_empty():
		return false
	var record: Dictionary = req.response.get("record", {}) if req.response.get("record") is Dictionary else {}
	store.set_session(new_token, record)
	account_changed.emit()
	return true


## Ce qui attendait la fin d'un shift ou le retour du réseau.
func flush_pending() -> void:
	if _quiet or not has_account() or state == State.ERROR:
		return
	if pending_sync:
		await sync_all()
	if pending_outbox:
		await flush_outbox()


# ---------------------------------------------------------------------------
# Compte : code par e-mail, pseudo, déconnexion, suppression
# ---------------------------------------------------------------------------

## Demande un code (ONLINE.md §2.1). `{ok, error}`.
func request_code(email: String) -> Dictionary:
	var clean: String = email.strip_edges()
	if not OnlineConfig.is_valid_email(clean):
		last_error = ERR_EMAIL
		return {"ok": false, "error": ERR_EMAIL}
	if server_status.is_empty():
		var status_req: OnlineRequest = await _send(OnlineRequest.make("GET", "/api/clearance/status"))
		if status_req.ok():
			server_status = status_req.response
	var req: OnlineRequest = await _send_retry(OnlineRequest.make("POST", "/api/collections/users/request-otp", {"email": clean}))
	if not req.ok():
		var error: String = ERR_EMAIL if req.status == 400 else _error_of(req)
		last_error = error
		return {"ok": false, "error": error}
	_otp_id = str(req.response.get("otpId", ""))
	_otp_email = clean
	last_error = ""
	code_requested.emit()
	return {"ok": true, "error": ""}


## Échange le code contre un jeton (ONLINE.md §2.2). `{ok, error}`.
func submit_code(code: String) -> Dictionary:
	if _otp_id.is_empty():
		last_error = ERR_OTP_MISSING
		return {"ok": false, "error": ERR_OTP_MISSING}
	var digits: String = OnlineConfig.clean_code(code)
	if digits.length() != otp_length():
		last_error = ERR_OTP
		return {"ok": false, "error": ERR_OTP}
	var previous: State = state
	_set_state(State.CONNECTING)
	var req: OnlineRequest = await _send_retry(OnlineRequest.make("POST", "/api/collections/users/auth-with-otp",
			{"otpId": _otp_id, "password": digits}))
	if not req.ok():
		var error: String = ERR_OTP if req.status == 400 else _error_of(req)
		if error == ERR_OTP_LOCKED:
			_otp_id = ""
		_set_state(previous if previous != State.CONNECTING else State.DISCONNECTED, error)
		return {"ok": false, "error": error}
	var token: String = str(req.response.get("token", ""))
	var record: Dictionary = req.response.get("record", {}) if req.response.get("record") is Dictionary else {}
	if token.is_empty() or str(record.get("id", "")).is_empty():
		_set_state(State.DISCONNECTED, ERR_SERVER)
		return {"ok": false, "error": ERR_SERVER}
	store.set_session(token, record, _otp_email)
	_otp_id = ""
	_otp_email = ""
	_set_state(State.CONNECTED)
	signed_in.emit()
	account_changed.emit()
	# Premier contact du compte : tout se rapproche (fusion du profil, emplacements).
	pending_sync = true
	pending_outbox = true
	await flush_pending()
	return {"ok": true, "error": ""}


## Abandonne la saisie du code (retour à l'adresse).
func cancel_code() -> void:
	_otp_id = ""


## Déconnexion de cet appareil (locale, ONLINE.md §2.5) ; données locales intactes.
func sign_out() -> void:
	if not has_account():
		return
	store.clear_session()
	_otp_id = ""
	_set_state(State.DISCONNECTED)
	signed_out.emit()
	account_changed.emit()


## Supprime le compte et toutes ses données distantes (ONLINE.md §2.6) ;
## les données locales ne sont pas touchées. `{ok, error}`.
func delete_account() -> Dictionary:
	var uid: String = store.user_id()
	if uid.is_empty():
		return {"ok": false, "error": ERR_NO_ACCOUNT}
	var req: OnlineRequest = await _send_retry(_authed("DELETE", "/api/collections/users/records/%s" % uid))
	if not _note(req) and req.status != 404:
		return {"ok": false, "error": last_error if not last_error.is_empty() else _error_of(req)}
	store.forget_user(uid)
	_set_state(State.DISCONNECTED)
	signed_out.emit()
	account_changed.emit()
	return {"ok": true, "error": ""}


## Pseudo public (ONLINE.md §2.4) ; vide = anonyme. `{ok, error}`.
func set_pseudo(text: String) -> Dictionary:
	var clean: String = OnlineConfig.clean_pseudo(text)
	if not OnlineConfig.is_valid_pseudo(clean):
		return {"ok": false, "error": ERR_PSEUDO}
	if not has_account():
		return {"ok": false, "error": ERR_NO_ACCOUNT}
	var req: OnlineRequest = await _send_retry(_authed("PATCH", "/api/collections/users/records/%s" % store.user_id(), {"pseudo": clean}))
	if not _note(req):
		var error: String = ERR_PSEUDO if req.status == 400 else (last_error if not last_error.is_empty() else _error_of(req))
		return {"ok": false, "error": error}
	store.account["pseudo"] = str(req.response.get("pseudo", clean))
	store.save_account()
	account_changed.emit()
	return {"ok": true, "error": ""}


func set_auto_sync(on: bool) -> void:
	store.set_auto_sync(on)
	account_changed.emit()


# ---------------------------------------------------------------------------
# Synchronisation des sauvegardes (D-232)
# ---------------------------------------------------------------------------

## Synchronise les trois emplacements et le profil. Une demande pendant une
## synchronisation en relance une à la fin. Pendant un shift, hors ligne ou
## sans compte : rien (demande gardée, `pending_sync`).
func sync_all() -> Dictionary:
	if not has_account():
		return {"ok": false, "errors": [ERR_NO_ACCOUNT]}
	if _quiet:
		pending_sync = true
		return {"ok": false, "errors": [ERR_QUIET]}
	if _syncing:
		_resync = true
		return {"ok": false, "errors": ["busy"]}
	_syncing = true
	pending_sync = false
	var report: Dictionary = await _sync_once()
	while _resync and not _quiet and has_account():
		_resync = false
		report = await _sync_once()
	_syncing = false
	last_report = report
	if report.get("ok", false):
		store.account["last_sync_unix_ms"] = int(Time.get_unix_time_from_system() * 1000.0)
		store.save_account()
	sync_finished.emit(report)
	return report


func is_syncing() -> bool:
	return _syncing


func _sync_once() -> Dictionary:
	var report: Dictionary = {"ok": false, "pulled": [], "pushed": [], "conflicts": [], "detached": [], "errors": [], "profile": ""}
	var manifest_req: OnlineRequest = await _send_retry(_authed("GET", "/api/clearance/saves", null, {"family": family}))
	if not _note(manifest_req):
		(report["errors"] as Array).append(last_error if not last_error.is_empty() else _error_of(manifest_req))
		if manifest_req.failure == OnlineRequest.Failure.CANCELLED:
			pending_sync = true
		return report
	var rows: Array = manifest_req.response.get("items", []) if manifest_req.response.get("items") is Array else []
	var changed_slots: bool = false
	for slot: int in range(1, SaveService.SLOT_COUNT + 1):
		var result: Dictionary = await _sync_slot(slot, _rows_of(rows, slot))
		var action: String = str(result.get("action", ""))
		if not str(result.get("error", "")).is_empty():
			(report["errors"] as Array).append(str(result["error"]))
		if action in ["pull", "conflict_pull"]:
			(report["pulled"] as Array).append(slot)
			changed_slots = true
		if action in ["push", "conflict_push", "delete"]:
			(report["pushed"] as Array).append(slot)
		if action.begins_with("conflict_"):
			(report["conflicts"] as Array).append(slot)
			changed_slots = true
		if action == "detach":
			(report["detached"] as Array).append(slot)
	var profile_result: String = await _sync_profile(_rows_of(rows, 0))
	report["profile"] = profile_result
	if profile_result.begins_with("error:"):
		(report["errors"] as Array).append(profile_result.trim_prefix("error:"))
	if changed_slots:
		slots_changed.emit()
	report["ok"] = (report["errors"] as Array).is_empty()
	return report


## Lignes du manifeste pour un emplacement et la famille (`slot` 0 : profil).
func _rows_of(rows: Array, slot: int) -> Array:
	var out: Array = []
	for value: Variant in rows:
		if not value is Dictionary:
			continue
		var row: Dictionary = value
		var kind: String = str(row.get("kind", ""))
		var in_family: bool = kind.begins_with(SaveSync.DEMO_PREFIX) == (family == SaveSync.FAMILY_DEMO)
		if in_family and SaveService.as_int(row.get("slot", -1)) == slot:
			out.append(SaveSync.canon(row))
	return out


static func _row_of(rows: Array, kind: String, day: int = 0) -> Dictionary:
	for row: Dictionary in rows:
		if SaveSync.base_kind(str(row.get("kind", ""))) == kind and SaveService.as_int(row.get("day", 0)) == day:
			return row
	return {}


## Un emplacement : décision (`SaveSync.decide`) puis action. `{action, error}`.
func _sync_slot(slot: int, rows: Array) -> Dictionary:
	var item: String = "slot_%d" % slot
	var local: Dictionary = SaveSync.slot_files(slot, save_dir)
	var local_fp: String = SaveSync.fingerprint(local)
	var meta_row: Dictionary = _row_of(rows, SaveSync.KIND_META)
	var remote_rev: int = SaveService.as_int(meta_row.get("rev", 0))
	var base: Dictionary = store.base(family, item)
	var action: SaveSync.Action = SaveSync.decide(local_fp, remote_rev, base)
	var protected: bool = slot == protected_slot
	match action:
		SaveSync.Action.NONE:
			return {"action": "none"}
		SaveSync.Action.FORGET:
			store.set_base(family, item, {})
			return {"action": "none"}
		SaveSync.Action.DETACH:
			store.set_base(family, item, {"fp": local_fp, "rev": 0, "records": {}})
			return {"action": "detach"}
		SaveSync.Action.DELETE_REMOTE:
			var del: OnlineRequest = await _send_retry(_authed("DELETE", "/api/clearance/saves/%d" % slot, null, {"family": family}))
			if not _note(del):
				return {"action": "", "error": _error_of(del)}
			store.set_base(family, item, {})
			return {"action": "delete"}
		SaveSync.Action.PUSH:
			return await _push_slot(slot, local, rows, base)
		SaveSync.Action.PULL:
			if protected:
				# Partie chargée sur cet emplacement : jamais remplacée sous les pieds du joueur.
				pending_sync = true
				return {"action": "deferred"}
			return await _pull_slot(slot, rows)
	return await _resolve_conflict(slot, local, local_fp, rows, base, protected)


## Envoie les lignes changées d'un emplacement : instantanés, suppression des
## instantanés distants absents d'ici, état courant, méta **en dernier**
## (`if_rev` : la ligne distante n'a pas bougé depuis le manifeste).
func _push_slot(slot: int, local: Dictionary, rows: Array, base: Dictionary) -> Dictionary:
	var records: Dictionary = SaveSync.record_fingerprints(local)
	var base_records: Dictionary = base.get("records", {}) if base.get("records") is Dictionary else {}
	var meta: Dictionary = local["meta"]
	var common: Dictionary = {"game_version": SaveService.game_version(), "save_serial": SaveService.as_int(meta.get("save_serial", 0)),
			"saved_unix_ms": SaveService.as_int(meta.get("saved_unix_ms", 0)), "device": OnlineConfig.device_label()}
	var snapshots: Dictionary = local["snapshots"]
	var days: Array = snapshots.keys()
	days.sort()
	var plan: Array[Dictionary] = []
	for day: Variant in days:
		plan.append({"kind": SaveSync.KIND_SNAPSHOT, "day": int(day), "payload": snapshots[day]})
	plan.append({"kind": SaveSync.KIND_CURRENT, "day": 0, "payload": local["current"]})
	plan.append({"kind": SaveSync.KIND_META, "day": 0, "payload": meta})
	var meta_rev: int = 0
	for step: Dictionary in plan:
		var kind: String = step["kind"]
		var day: int = step["day"]
		var key: String = SaveSync.record_key(kind, day)
		var row: Dictionary = _row_of(rows, kind, day)
		if kind == SaveSync.KIND_META:
			# Avant la méta : instantanés distants qui n'existent plus ici.
			for remote: Dictionary in rows:
				var remote_day: int = SaveService.as_int(remote.get("day", 0))
				if SaveSync.base_kind(str(remote.get("kind", ""))) == SaveSync.KIND_SNAPSHOT and not snapshots.has(remote_day):
					var gone: OnlineRequest = await _send_retry(_authed("DELETE", "/api/clearance/saves/%d/%s/%d"
							% [slot, SaveSync.kind_name(SaveSync.KIND_SNAPSHOT, family), remote_day]))
					if not _note(gone) and gone.status != 404:
						return {"action": "", "error": _error_of(gone)}
		elif not row.is_empty() and str(base_records.get(key, "")) == str(records.get(key, "?")):
			continue # ligne déjà à jour à distance
		var body: Dictionary = common.duplicate()
		body["payload"] = step["payload"]
		body["if_rev"] = SaveService.as_int(row.get("rev", 0))
		var req: OnlineRequest = await _send_retry(_authed("PUT", "/api/clearance/saves/%d/%s/%d" % [slot, SaveSync.kind_name(kind, family), day], body))
		if not _note(req):
			if req.status == 409:
				# La ligne distante a changé entre-temps : une nouvelle passe tranchera.
				_resync = true
				return {"action": "", "error": ""}
			return {"action": "", "error": _error_of(req)}
		if kind == SaveSync.KIND_META:
			meta_rev = SaveService.as_int(req.response.get("rev", 0))
	store.set_base(family, "slot_%d" % slot, {"fp": SaveSync.fingerprint(local), "rev": meta_rev, "records": records,
			"serial": common["save_serial"], "ms": common["saved_unix_ms"]})
	return {"action": "push"}


## Télécharge toutes les lignes d'un emplacement (`{files, error}`).
func _download_slot(slot: int, rows: Array) -> Dictionary:
	var full: Array = []
	for row: Dictionary in rows:
		var req: OnlineRequest = await _send_retry(_authed("GET", "/api/clearance/saves/%d/%s/%d"
				% [slot, str(row.get("kind", "")), SaveService.as_int(row.get("day", 0))]))
		if req.status == 404:
			continue
		if not _note(req):
			return {"files": {}, "error": _error_of(req)}
		full.append(req.response)
	var files: Dictionary = SaveSync.files_from_rows(full)
	if files.is_empty():
		return {"files": {}, "error": ""}
	if not SaveSync.files_loadable(files):
		return {"files": {}, "error": ERR_FUTURE}
	return {"files": files, "error": ""}


func _pull_slot(slot: int, rows: Array) -> Dictionary:
	var got: Dictionary = await _download_slot(slot, rows)
	var files: Dictionary = got["files"]
	if files.is_empty():
		return {"action": "", "error": str(got.get("error", ""))}
	var err: Error = SaveService.write_slot_files(slot, files, save_dir)
	if err != OK:
		return {"action": "", "error": ERR_SERVER}
	_store_pulled_base(slot, rows)
	return {"action": "pull"}


## Base après un tirage : l'emplacement local relu (identique au distant).
func _store_pulled_base(slot: int, rows: Array) -> void:
	var now: Dictionary = SaveSync.slot_files(slot, save_dir)
	var meta: Dictionary = now.get("meta", {})
	store.set_base(family, "slot_%d" % slot, {"fp": SaveSync.fingerprint(now),
			"rev": SaveService.as_int(_row_of(rows, SaveSync.KIND_META).get("rev", 0)),
			"records": SaveSync.record_fingerprints(now), "serial": SaveService.as_int(meta.get("save_serial", 0)),
			"ms": SaveService.as_int(meta.get("saved_unix_ms", 0))})


## Deux versions ont avancé : identiques → base ; sinon la gagnante
## (`SaveSync.local_wins` ; emplacement de la partie en cours : toujours la
## locale) reste, l'autre est copiée dans `slot_N/conflict_<horodatage>/`.
func _resolve_conflict(slot: int, local: Dictionary, local_fp: String, rows: Array, base: Dictionary, protected: bool) -> Dictionary:
	var got: Dictionary = await _download_slot(slot, rows)
	var remote: Dictionary = got["files"]
	if remote.is_empty():
		if str(got.get("error", "")) == ERR_FUTURE:
			# Version distante plus récente que ce jeu : rien n'est écrasé ici.
			return {"action": "", "error": ERR_FUTURE}
		if not str(got.get("error", "")).is_empty():
			return {"action": "", "error": str(got["error"])}
		return await _push_slot(slot, local, rows, base)
	if SaveSync.fingerprint(remote) == local_fp:
		_store_pulled_base(slot, rows)
		return {"action": "none"}
	var meta_row: Dictionary = _row_of(rows, SaveSync.KIND_META)
	if protected or SaveSync.local_wins(local["meta"], remote["meta"]):
		var origin: Dictionary = {"source": "remote", "device": str(meta_row.get("device", "")),
				"save_serial": SaveService.as_int(remote["meta"].get("save_serial", 0)),
				"saved_unix_ms": SaveService.as_int(remote["meta"].get("saved_unix_ms", 0))}
		if SaveService.write_conflict(slot, remote, origin, "", save_dir).is_empty():
			return {"action": "", "error": ERR_SERVER}
		var pushed: Dictionary = await _push_slot(slot, local, rows, {})
		if not str(pushed.get("action", "")).is_empty():
			pushed["action"] = "conflict_push"
		return pushed
	var mine: Dictionary = {"source": "local", "device": OnlineConfig.device_label(),
			"save_serial": SaveService.as_int(local["meta"].get("save_serial", 0)),
			"saved_unix_ms": SaveService.as_int(local["meta"].get("saved_unix_ms", 0))}
	if SaveService.write_conflict(slot, local, mine, "", save_dir).is_empty():
		return {"action": "", "error": ERR_SERVER}
	if SaveService.write_slot_files(slot, remote, save_dir) != OK:
		return {"action": "", "error": ERR_SERVER}
	_store_pulled_base(slot, rows)
	return {"action": "conflict_pull"}


## Profil (`slot` 0) : **fusion** (union) des deux côtés, jamais écrasé
## (ONLINE.md §5.5 : tirer → fusionner → réécrire avec `if_rev` ; 409 :
## recommencer, au plus 3 fois). Renvoie `none`, `pulled`, `pushed`, `merged`
## ou `error:<clé>`.
func _sync_profile(rows: Array) -> String:
	var kind: String = SaveSync.kind_name(SaveSync.KIND_PROFILE, family)
	var has_local_file: bool = SaveService.file_exists_any(ProfileService.profile_path(save_dir))
	var row: Dictionary = _row_of(rows, SaveSync.KIND_PROFILE)
	var outcome: String = "none"
	for attempt: int in OnlineConfig.PROFILE_MERGE_ATTEMPTS:
		var base: Dictionary = store.base(family, "profile")
		var remote_rev: int = SaveService.as_int(row.get("rev", 0))
		var local: Dictionary = SaveSync.canon(ProfileService.load_profile(save_dir))
		var local_fp: String = SaveSync.payload_fingerprint(local) if has_local_file else ""
		var merged: Dictionary = local
		var remote_fp: String = ""
		if remote_rev > 0 and remote_rev != SaveService.as_int(base.get("rev", 0)):
			var req: OnlineRequest = await _send_retry(_authed("GET", "/api/clearance/saves/0/%s/0" % kind))
			if req.status == 404:
				remote_rev = 0
			elif not _note(req):
				return "error:" + _error_of(req)
			else:
				var payload: Variant = req.response.get("payload", {})
				var remote: Dictionary = SaveSync.canon(ProfileService.sanitize(payload if payload is Dictionary else {}))
				remote_fp = SaveSync.payload_fingerprint(remote)
				merged = SaveSync.canon(ProfileService.merge(local, remote)) if has_local_file else remote
				if SaveSync.payload_fingerprint(merged) != local_fp:
					ProfileService.save_profile(merged, save_dir)
					has_local_file = true
					profile_changed.emit()
					outcome = "pulled"
		elif remote_rev > 0:
			remote_fp = str(base.get("fp", ""))
		var merged_fp: String = SaveSync.payload_fingerprint(merged) if has_local_file else ""
		if merged_fp.is_empty() or merged_fp == remote_fp:
			if not merged_fp.is_empty():
				store.set_base(family, "profile", {"fp": merged_fp, "rev": remote_rev})
			return outcome
		var body: Dictionary = {"payload": merged, "game_version": SaveService.game_version(), "save_serial": 0,
				"saved_unix_ms": int(Time.get_unix_time_from_system() * 1000.0), "device": OnlineConfig.device_label(),
				"if_rev": remote_rev}
		var put: OnlineRequest = await _send_retry(_authed("PUT", "/api/clearance/saves/0/%s/0" % kind, body))
		if put.status == 409:
			var current: Variant = (put.response.get("data", {}) as Dictionary).get("current", null) if put.response.get("data") is Dictionary else null
			row = SaveSync.canon(current) if current is Dictionary else {}
			continue
		if not _note(put):
			return "error:" + _error_of(put)
		store.set_base(family, "profile", {"fp": merged_fp, "rev": SaveService.as_int(put.response.get("rev", 0))})
		return "merged" if outcome == "pulled" else "pushed"
	return "error:" + ERR_SERVER


# ---------------------------------------------------------------------------
# Garde de nuit : scores et classement (D-233)
# ---------------------------------------------------------------------------

## Corps d'envoi d'un score (ONLINE.md §6.1) depuis `GardeRun.to_record()`.
static func garde_body(record: Dictionary, first_try: bool) -> Dictionary:
	var errors: Variant = record.get("errors", [])
	var body: Dictionary = {
		"seed_code": str(record.get("seed_code", "")),
		"garde_version": SaveService.as_int(record.get("garde_version", 1), 1),
		"score": SaveService.as_int(record.get("score", 0)),
		"errors": (errors as Array).size() if errors is Array else SaveService.as_int(errors),
		"tier_max": SaveService.as_int(record.get("palier", record.get("tier_max", 0))),
		"passengers": SaveService.as_int(record.get("passengers", 0)),
		"directives": SaveService.as_int(record.get("directives", 0)),
		"duration_s": SaveService.as_int(record.get("duration_sec", record.get("duration_s", 0))),
		"first_try": first_try,
		"end_reason": str(record.get("end_reason", "")),
		"game_version": SaveService.game_version(),
	}
	body["_key"] = garde_key(record)
	return body


## Identifiant d'une garde (évite un double envoi).
static func garde_key(record: Dictionary) -> String:
	return "%s|%s|%d|%d|%d" % [str(record.get("seed_code", "")), str(record.get("played_on", "")),
			SaveService.as_int(record.get("score", 0)), SaveService.as_int(record.get("passengers", 0)),
			SaveService.as_int(record.get("duration_sec", record.get("duration_s", 0)))]


## Met une garde terminée en file d'envoi (si un compte existe) puis tente
## l'envoi. Sans compte : rien (records locaux seulement).
func submit_garde(record: Dictionary, first_try: bool) -> void:
	if not has_account() or str(record.get("seed_code", "")).is_empty():
		return
	store.queue_score(garde_body(record, first_try))
	pending_outbox = true
	await flush_outbox()


## Envoie la file : scores de Garde, puis fins non encore envoyées.
func flush_outbox() -> void:
	if not has_account() or _quiet or _flushing:
		if _quiet:
			pending_outbox = true
		return
	_flushing = true
	pending_outbox = false
	for value: Variant in store.pending_scores().duplicate():
		if not value is Dictionary:
			continue
		var entry: Dictionary = value
		var key: String = str(entry.get("_key", ""))
		var body: Dictionary = entry.duplicate()
		body.erase("_key")
		var req: OnlineRequest = await _send_retry(_authed("POST", "/api/clearance/garde/scores", body))
		if req.ok():
			_note(req)
			store.drop_score(key)
			garde_submitted.emit(key, req.response)
			# Le classement de cette graine a changé : il sera relu.
			store.cache.erase(board_key(str(body["seed_code"]), SaveService.as_int(body["garde_version"])))
			continue
		_note(req)
		if req.is_transient() or req.failure == OnlineRequest.Failure.CANCELLED or req.status == 401:
			pending_outbox = true
			break
		# 4xx (score jugé invraisemblable, champ refusé) : jamais renvoyé ; le record local reste.
		push_warning("OnlineClient: score de Garde refusé (%s)" % req.describe())
		store.drop_score(key)
		garde_submitted.emit(key, {"error": req.error_code()})
	if not pending_outbox:
		await report_endings()
	_flushing = false


## Clé de cache d'un classement.
static func board_key(seed_code: String, version: int) -> String:
	return "leaderboard:%s:%d" % [seed_code, version]


## Classement mis en cache (`{unix_ms, data}`), vide sinon.
func cached_leaderboard(seed_code: String, version: int) -> Dictionary:
	return store.cached(board_key(seed_code, version))


## Top 10 d'une graine et rang du joueur (ONLINE.md §6.3). Sans compte :
## rien (aucune requête, D-235 proposition). `{ok, data, error}`.
func fetch_leaderboard(seed_code: String, version: int) -> Dictionary:
	if not has_account():
		return {"ok": false, "data": {}, "error": ERR_NO_ACCOUNT}
	var req: OnlineRequest = await _send_retry(_authed("GET", "/api/clearance/leaderboard", null,
			{"seed": seed_code, "version": version, "limit": OnlineConfig.LEADERBOARD_LIMIT}))
	if not _note(req):
		return {"ok": false, "data": cached_leaderboard(seed_code, version).get("data", {}), "error": last_error if not last_error.is_empty() else _error_of(req)}
	var key: String = board_key(seed_code, version)
	store.set_cached(key, req.response)
	leaderboard_updated.emit(key, req.response)
	return {"ok": true, "data": req.response, "error": ""}


# ---------------------------------------------------------------------------
# Fins : événements et statistiques (D-234)
# ---------------------------------------------------------------------------

## Envoie les fins du profil jamais envoyées par ce compte (`difficulty` : celle
## de la partie qui vient de finir ; rattrapage : `hard`).
func report_endings(difficulty: String = SaveService.DIFFICULTY_HARD) -> void:
	if not has_account() or _quiet:
		return
	var profile: Dictionary = ProfileService.load_profile(save_dir)
	var sent: Array = store.endings_sent()
	for entry: Dictionary in profile["endings_seen"]:
		var ending_id: String = str(entry["id"])
		if not EndingService.ALL_ENDINGS.has(StringName(ending_id)):
			continue
		var key: String = "%s:%s" % [ending_id, entry["variant"]]
		if sent.has(key):
			continue
		var body: Dictionary = {"ending_id": ending_id, "variant": str(entry["variant"]), "act": clampi(SaveService.as_int(entry["act"]), 1, 3),
				"difficulty": difficulty if difficulty == SaveService.DIFFICULTY_STORY else SaveService.DIFFICULTY_HARD,
				"game_version": SaveService.game_version()}
		var req: OnlineRequest = await _send_retry(_authed("POST", "/api/clearance/endings", body))
		if req.ok() or (req.status >= 400 and req.status < 500 and req.status != 401 and req.status != 429):
			_note(req)
			store.mark_ending_sent(key)
			continue
		_note(req)
		pending_outbox = true
		return
	store.cache.erase("ending_stats")


## Statistiques en cache (`{unix_ms, data}` ; `data` = réponse d'ONLINE.md §7.2).
func cached_ending_stats() -> Dictionary:
	return store.cached("ending_stats")


## « X % des agents » d'une fin (toutes variantes), −1 si inconnu.
func ending_percent(ending_id: String) -> float:
	var data: Dictionary = cached_ending_stats().get("data", {})
	var endings: Dictionary = data.get("endings", {}) if data.get("endings") is Dictionary else {}
	var entry: Variant = endings.get(ending_id, null)
	if not entry is Dictionary:
		return -1.0
	var value: Variant = (entry as Dictionary).get("percent", -1.0)
	return float(value) if value is float or value is int else -1.0


## Relit les statistiques des fins **vues** seulement (`ids`, aucun spoiler),
## au plus toutes les 5 min (cache). Sans compte : rien.
func fetch_ending_stats(ids: PackedStringArray, force: bool = false) -> Dictionary:
	if not has_account() or ids.is_empty():
		return {"ok": false, "error": ERR_NO_ACCOUNT}
	var cached: Dictionary = cached_ending_stats()
	var age_ms: int = int(Time.get_unix_time_from_system() * 1000.0) - SaveService.as_int(cached.get("unix_ms", 0))
	var known: Dictionary = (cached.get("data", {}) as Dictionary).get("endings", {}) if (cached.get("data", {}) as Dictionary).get("endings") is Dictionary else {}
	var complete: bool = true
	for id: String in ids:
		complete = complete and known.has(id)
	if not force and complete and age_ms < OnlineConfig.ENDING_STATS_MAX_AGE_S * 1000:
		return {"ok": true, "error": ""}
	var sorted: Array = Array(ids)
	sorted.sort()
	var req: OnlineRequest = await _send_retry(_authed("GET", "/api/clearance/endings", null, {"ids": ",".join(PackedStringArray(sorted))}))
	if not _note(req):
		return {"ok": false, "error": last_error}
	store.set_cached("ending_stats", req.response)
	ending_stats_updated.emit(req.response)
	return {"ok": true, "error": ""}
