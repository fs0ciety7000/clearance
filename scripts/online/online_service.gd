## OnlineService — autoload du client en ligne (M16, D-230 → D-235 ;
## ARCHITECTURE §18, contrat `docs/ONLINE.md`). Pas de `class_name` (autoload).
##
## Pourquoi un autoload (5ᵉ, P6) : le compte, la file d'envoi et les
## synchronisations en cours doivent survivre aux changements de scène
## (titre → jour → titre) ; les `HTTPRequest` ont besoin d'un nœud hôte.
## Toute la logique est dans `OnlineClient` (RefCounted, testable seul) ; ce
## nœud ne fait que le **relier au jeu** :
## - écran titre (`on_title`, appelé par `main.gd`) : premier contact (statut,
##   jeton), **tirage** des sauvegardes si la synchronisation automatique est
##   active, file d'envoi ;
## - `EventBus.day_started` → **silence** (aucune requête pendant un shift,
##   épilogue et Garde compris ; la partie chargée est protégée) ;
##   `day_ended` → fin du silence, ce qui attendait part ;
## - `game_saved` (soirée), `save_slots_changed` (fin archivée, suppression,
##   conflit tranché…) → **envoi** (si automatique) ; `profile_changed` →
##   fins à envoyer (événements, D-234) et profil à fusionner ;
## - relaie les écritures du client (`save_slots_changed`, `profile_changed`)
##   sans se relancer lui-même.
## Sans compte : aucune requête, aucun fichier écrit (comportement d'avant M16).
## Debug : `--online-url=…` (serveur local), `--online-fake[=demo]` (faux
## serveur en mémoire, compte de démonstration dans `user://qa_online_fake`,
## jamais le vrai `user://online`).
extends Node

signal state_changed(state: OnlineClient.State)
signal sync_finished(report: Dictionary)
signal account_changed()
signal code_requested()
signal leaderboard_updated(key: String, data: Dictionary)
signal ending_stats_updated(stats: Dictionary)
signal garde_submitted(key: String, result: Dictionary)
## Fin d'une action lancée par `start_action` (interface : la boîte ou la
## section qui l'a demandée l'écoute ; fermée entre-temps, rien ne se passe).
signal action_finished(action: StringName, result: Dictionary)
## Lecture d'un classement impossible (hors ligne, refus) : clé de cache.
signal leaderboard_failed(key: String)

const ACTION_REQUEST_CODE: StringName = &"request_code"
const ACTION_SUBMIT_CODE: StringName = &"submit_code"
const ACTION_SET_PSEUDO: StringName = &"set_pseudo"
const ACTION_DELETE_ACCOUNT: StringName = &"delete_account"
const ACTION_SYNC_NOW: StringName = &"sync_now"

## Dossier du compte de démonstration (`--online-fake`).
const FAKE_STORE_DIR: String = "user://qa_online_fake"

var client: OnlineClient = null
## Vrai à l'écran titre (aucune partie protégée).
var at_title: bool = false
## Faux serveur actif (`--online-fake` ou tests), null sinon.
var fake: FakeOnlineServer = null

var _started: bool = false
var _relaying: bool = false
var _scheduled: bool = false
var _sync_wanted: bool = false
var _endings_wanted: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OnlineConfig.fake_requested():
		_setup_fake_demo(OnlineConfig.debug_arg("online-fake"))
	else:
		var store: OnlineStore = OnlineStore.new()
		use_transport(HttpTransport.new(self, OnlineConfig.base_url(store.api_url())), SaveService.DEFAULT_DIR, store)
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.game_saved.connect(_on_game_saved)
	EventBus.save_slots_changed.connect(_on_slots_changed)
	EventBus.profile_changed.connect(_on_profile_changed)


func _exit_tree() -> void:
	if client != null and client.transport != null:
		client.transport.cancel_all()


## Remplace le transport (tests, `--online-fake`) : nouveau client sur
## `save_dir` et `store` (par défaut : `OnlineStore.default_dir(save_dir)`).
func use_transport(transport: OnlineTransport, save_dir: String = SaveService.DEFAULT_DIR, store: OnlineStore = null) -> OnlineClient:
	if client != null and client.transport != null and client.transport != transport:
		client.transport.cancel_all()
	fake = transport as FakeOnlineServer
	client = OnlineClient.new(transport, store if store != null else OnlineStore.new(OnlineStore.default_dir(save_dir)), save_dir)
	client.waiter = func(seconds: float) -> Signal: return get_tree().create_timer(seconds, true).timeout
	client.state_changed.connect(func(value: OnlineClient.State) -> void: state_changed.emit(value))
	client.sync_finished.connect(func(report: Dictionary) -> void: sync_finished.emit(report))
	client.account_changed.connect(func() -> void: account_changed.emit())
	client.signed_in.connect(func() -> void: account_changed.emit())
	client.signed_out.connect(func() -> void: account_changed.emit())
	client.code_requested.connect(func() -> void: code_requested.emit())
	client.leaderboard_updated.connect(func(key: String, data: Dictionary) -> void: leaderboard_updated.emit(key, data))
	client.ending_stats_updated.connect(func(stats: Dictionary) -> void: ending_stats_updated.emit(stats))
	client.garde_submitted.connect(func(key: String, result: Dictionary) -> void: garde_submitted.emit(key, result))
	client.slots_changed.connect(_relay_slots)
	client.profile_changed.connect(_relay_profile)
	_started = false
	return client


# ---------------------------------------------------------------------------
# Accès pour l'interface
# ---------------------------------------------------------------------------

func state() -> OnlineClient.State:
	return client.state


func has_account() -> bool:
	return client.has_account()


func last_error() -> String:
	return client.last_error


func display_name() -> String:
	return client.display_name()


func auto_sync() -> bool:
	return client.store.auto_sync()


func is_syncing() -> bool:
	return client.is_syncing()


## Pendant un shift (Options du menu pause) : rien ne part.
func is_quiet() -> bool:
	return client.is_quiet()


## Dernière synchronisation réussie (ms Unix, 0 si jamais).
func last_sync_unix_ms() -> int:
	return SaveService.as_int(client.store.account.get("last_sync_unix_ms", 0))


## Adresse du compte, masquée (jamais journalisée).
func masked_email() -> String:
	var email: String = str(client.store.account.get("email", ""))
	return OnlineConfig.mask_email(email) if not email.is_empty() else ""


## Emplacements portant une copie de conflit (écran Charger, titre).
func conflict_slots(dir: String = SaveService.DEFAULT_DIR) -> Array[int]:
	var slots: Array[int] = []
	for slot: int in range(1, SaveService.SLOT_COUNT + 1):
		if SaveService.has_conflict(slot, dir):
			slots.append(slot)
	return slots


# ---------------------------------------------------------------------------
# Actions (coroutines : `await OnlineService.request_code(…)`)
# ---------------------------------------------------------------------------

## Lance une action sans que l'appelant attende (boîtes de l'interface) ;
## le résultat arrive par `action_finished(action, {ok, error…})`.
func start_action(action: StringName, arg: String = "") -> void:
	var result: Dictionary = {}
	match action:
		ACTION_REQUEST_CODE:
			result = await client.request_code(arg)
		ACTION_SUBMIT_CODE:
			result = await client.submit_code(arg)
		ACTION_SET_PSEUDO:
			result = await client.set_pseudo(arg)
		ACTION_DELETE_ACCOUNT:
			result = await client.delete_account()
		ACTION_SYNC_NOW:
			result = await sync_now()
			if not result.has("error"):
				var errors: Array = result.get("errors", []) if result.get("errors") is Array else []
				result["error"] = str(errors[0]) if not errors.is_empty() else ""
		_:
			result = {"ok": false, "error": "unknown_action"}
	action_finished.emit(action, result)


func request_code(email: String) -> Dictionary:
	return await client.request_code(email)


func submit_code(code: String) -> Dictionary:
	return await client.submit_code(code)


func sign_out() -> void:
	client.sign_out()


func delete_account() -> Dictionary:
	return await client.delete_account()


func set_pseudo(text: String) -> Dictionary:
	return await client.set_pseudo(text)


func set_auto_sync(on: bool) -> void:
	client.set_auto_sync(on)
	if on:
		_schedule(true, false)


## « SYNCHRONISER MAINTENANT ».
func sync_now() -> Dictionary:
	if not client.has_account():
		return {"ok": false, "errors": [OnlineClient.ERR_NO_ACCOUNT]}
	if client.state != OnlineClient.State.CONNECTED and not client.is_quiet():
		_started = true
		await client.start()
		if client.state != OnlineClient.State.CONNECTED:
			return {"ok": false, "errors": [client.last_error]}
	return await client.sync_all()


## Fin d'une garde (écran FIN DE GARDE) : score en file d'envoi (compte seulement).
func submit_garde(record: Dictionary, first_try: bool) -> void:
	await client.submit_garde(record, first_try)


func fetch_leaderboard(seed_code: String, version: int) -> Dictionary:
	return await client.fetch_leaderboard(seed_code, version)


## Lecture sans attente (écrans) : `leaderboard_updated` ou `leaderboard_failed`.
func request_leaderboard(seed_code: String, version: int) -> void:
	var result: Dictionary = await client.fetch_leaderboard(seed_code, version)
	if not result.get("ok", false):
		leaderboard_failed.emit(OnlineClient.board_key(seed_code, version))


## Statistiques des fins vues, sans attente (Dossier) : `ending_stats_updated`.
func request_ending_stats(ids: PackedStringArray) -> void:
	await client.fetch_ending_stats(ids)


func cached_leaderboard(seed_code: String, version: int) -> Dictionary:
	return client.cached_leaderboard(seed_code, version)


func fetch_ending_stats(ids: PackedStringArray) -> Dictionary:
	return await client.fetch_ending_stats(ids)


func ending_percent(ending_id: String) -> float:
	return client.ending_percent(ending_id)


# ---------------------------------------------------------------------------
# Liens avec le jeu
# ---------------------------------------------------------------------------

## Écran titre (`main.gd`) : fin du silence, aucune partie protégée ; premier
## contact (statut, jeton, tirage), puis synchronisation à chaque retour.
func on_title() -> void:
	at_title = true
	client.protected_slot = SaveService.NO_SLOT
	client.set_quiet(false)
	if not client.has_account():
		return
	if not _started:
		_started = true
		await client.start()
		return
	_schedule(client.store.auto_sync(), true)


func _on_day_started(_day: DayDef, _rulebook: Array[RulebookEntry]) -> void:
	at_title = false
	client.protected_slot = GameState.active_slot if GameState.is_campaign_session() else SaveService.NO_SLOT
	client.set_quiet(true)


func _on_day_ended(_summary: DaySummary) -> void:
	client.set_quiet(false)


func _on_game_saved(slot: int) -> void:
	client.protected_slot = slot if not at_title else SaveService.NO_SLOT
	_schedule(client.store.auto_sync(), false)


func _on_slots_changed() -> void:
	if _relaying:
		return
	_schedule(client.store.auto_sync(), false)


func _on_profile_changed() -> void:
	if _relaying:
		return
	_schedule(client.store.auto_sync(), true)


## Regroupe les demandes d'une même image (une sauvegarde émet plusieurs signaux).
func _schedule(sync: bool, endings: bool) -> void:
	if not client.has_account():
		return
	_sync_wanted = _sync_wanted or sync
	_endings_wanted = _endings_wanted or endings
	if _scheduled:
		return
	_scheduled = true
	_run_scheduled.call_deferred()


func _run_scheduled() -> void:
	_scheduled = false
	var sync: bool = _sync_wanted
	var endings: bool = _endings_wanted
	_sync_wanted = false
	_endings_wanted = false
	if sync:
		await client.sync_all()
	if endings:
		var difficulty: String = String(GameState.difficulty) if GameState.is_campaign_session() else SaveService.DIFFICULTY_HARD
		await client.report_endings(difficulty)


func _relay_slots() -> void:
	_relaying = true
	EventBus.save_slots_changed.emit()
	_relaying = false


func _relay_profile() -> void:
	_relaying = true
	EventBus.profile_changed.emit()
	_relaying = false


# ---------------------------------------------------------------------------
# Debug : faux serveur de démonstration (captures)
# ---------------------------------------------------------------------------

## `--online-fake` : faux serveur et compte de démonstration (dossier
## `FAKE_STORE_DIR`, vidé au démarrage). `kind` : `demo` (connecté·e, pseudo,
## classement et statistiques remplis), `signed-out`, `offline`.
func _setup_fake_demo(kind: String) -> void:
	SaveService.remove_tree(FAKE_STORE_DIR)
	var server: FakeOnlineServer = FakeOnlineServer.new()
	var store: OnlineStore = OnlineStore.new(FAKE_STORE_DIR)
	use_transport(server, SaveService.DEFAULT_DIR, store)
	client.retry_delays = []
	if kind == "signed-out":
		return
	var body: Dictionary = server.seed_demo(GardeService.today_code(), GardeScreen.current_version())
	store.set_session(str(body["token"]), body["record"], "nadia.demo@example.org")
	if kind == "offline":
		server.offline = true
