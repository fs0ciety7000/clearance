## M16 « En ligne » (D-230 → D-235, ARCHITECTURE §18, contrat `docs/ONLINE.md`) :
## client sans réseau réel — `FakeOnlineServer` (double de transport), deux
## clients sur deux dossiers = deux appareils. Couvre : configuration,
## décisions de synchronisation, fusion du profil, crochets de `SaveService`
## (série par emplacement, copies de conflit), connexion par code, échecs
## réseau et nouvelles tentatives, synchronisation avec conflits simulés,
## suppression, démo, classement, statistiques des fins, silence pendant un
## shift, aucune requête sans compte.
extends GutTest

const GameStateScript: GDScript = preload("res://scripts/autoload/game_state.gd")
const ROOT: String = "user://test_m16"
const DIR_A: String = "user://test_m16/a"
const DIR_B: String = "user://test_m16/b"

var server: FakeOnlineServer


func before_each() -> void:
	SaveService.remove_tree(ROOT)
	server = FakeOnlineServer.new()
	DemoMode.force = -1


func after_all() -> void:
	SaveService.remove_tree(ROOT)
	DemoMode.force = -1


func _client(dir: String, transport: OnlineTransport = null) -> OnlineClient:
	var c: OnlineClient = OnlineClient.new(transport if transport != null else server, OnlineStore.new(dir.path_join("online")), dir)
	c.retry_delays = [0.0, 0.0, 0.0]
	return c


func _sign_in(c: OnlineClient, email: String = "agent@example.org") -> void:
	var asked: Dictionary = await c.request_code(email)
	assert_true(asked["ok"], "code demandé")
	var done: Dictionary = await c.submit_code(server.last_code)
	assert_true(done["ok"], "code accepté")


## Partie `seed` jouée jusqu'au soir du jour `days` dans `slot` de `dir`.
func _play(dir: String, slot: int, p_seed: int, days: int, credits: int = 10) -> Node:
	var state: Node = autofree(GameStateScript.new())
	state.call(&"new_campaign", p_seed, slot, &"hard")
	for i: int in days:
		state.set(&"credits", credits + i)
		state.call(&"record_day_entry", {"processed": 5, "correct": 5, "credits": 25})
		assert_eq(state.call(&"save_to_slot", slot, dir), OK)
	return state


func _evening(state: Node, dir: String) -> void:
	state.call(&"record_day_entry", {"processed": 5, "correct": 4, "credits": 20})
	assert_eq(state.call(&"save_to_slot", SaveService.NO_SLOT, dir), OK)


func _day(dir: String, slot: int) -> int:
	return SaveService.as_int(SaveService.load_meta(slot, dir).get("current_day", 0))


# ---------------------------------------------------------------------------
# Configuration, règles pures
# ---------------------------------------------------------------------------

func test_config_helpers() -> void:
	assert_eq(OnlineConfig.DEFAULT_BASE_URL, "https://api.clearance.cardormedia.com")
	assert_eq(OnlineConfig.base_url("http://127.0.0.1:8090/"), "http://127.0.0.1:8090")
	assert_true(OnlineConfig.is_valid_email("agent@example.org"))
	for bad: String in ["", "agent", "agent@", "@example.org", "a b@example.org", "agent@example", "a@b@c.org"]:
		assert_false(OnlineConfig.is_valid_email(bad), bad)
	assert_eq(OnlineConfig.mask_email("nadia@example.org"), "n•••@e•••.org")
	assert_eq(OnlineConfig.clean_code(" 042-317 "), "042317")
	assert_true(OnlineConfig.is_valid_pseudo("Nadia K."))
	assert_true(OnlineConfig.is_valid_pseudo("Élodie_2-o'"))
	assert_false(OnlineConfig.is_valid_pseudo("<script>"))
	assert_false(OnlineConfig.is_valid_pseudo("x".repeat(21)))
	var req: OnlineRequest = OnlineRequest.make("GET", "/api/clearance/leaderboard", null, "secret-token", {"seed": "NUIT-2026-11-01"})
	assert_eq(req.url_path(), "/api/clearance/leaderboard?seed=NUIT-2026-11-01")
	req.finish(200, {})
	assert_false(req.describe().contains("secret"), "jamais le jeton dans les journaux")
	assert_false(req.describe().contains("NUIT"), "jamais la requête dans les journaux")


func test_decide_table() -> void:
	var none: Dictionary = {}
	var base: Dictionary = {"fp": "L1", "rev": 3}
	assert_eq(SaveSync.decide("", 0, none), SaveSync.Action.NONE, "vide des deux côtés")
	assert_eq(SaveSync.decide("L1", 0, none), SaveSync.Action.PUSH, "jamais envoyé")
	assert_eq(SaveSync.decide("", 2, none), SaveSync.Action.PULL, "nouvel appareil")
	assert_eq(SaveSync.decide("L1", 2, none), SaveSync.Action.CONFLICT, "deux versions inconnues : comparer")
	assert_eq(SaveSync.decide("L1", 3, base), SaveSync.Action.NONE, "rien n'a bougé")
	assert_eq(SaveSync.decide("L2", 3, base), SaveSync.Action.PUSH, "avancé ici")
	assert_eq(SaveSync.decide("L1", 4, base), SaveSync.Action.PULL, "avancé ailleurs")
	assert_eq(SaveSync.decide("L2", 4, base), SaveSync.Action.CONFLICT, "avancé des deux côtés")
	assert_eq(SaveSync.decide("", 3, base), SaveSync.Action.DELETE_REMOTE, "supprimé ici")
	assert_eq(SaveSync.decide("", 4, base), SaveSync.Action.PULL, "supprimé ici mais avancé ailleurs : jamais perdu")
	assert_eq(SaveSync.decide("L1", 0, base), SaveSync.Action.DETACH, "supprimé ailleurs : copie locale gardée")
	assert_eq(SaveSync.decide("L2", 0, base), SaveSync.Action.PUSH, "supprimé ailleurs mais avancé ici")
	assert_eq(SaveSync.decide("", 0, base), SaveSync.Action.FORGET, "supprimé des deux côtés")
	assert_eq(SaveSync.decide("L1", 0, {"fp": "L1", "rev": 0}), SaveSync.Action.NONE, "copie détachée inchangée")
	assert_eq(SaveSync.decide("L3", 0, {"fp": "L1", "rev": 0}), SaveSync.Action.PUSH, "copie détachée qui avance")


func test_local_wins_by_serial_then_time() -> void:
	assert_true(SaveSync.local_wins({"save_serial": 5, "saved_unix_ms": 1}, {"save_serial": 4, "saved_unix_ms": 9}))
	assert_false(SaveSync.local_wins({"save_serial": 4, "saved_unix_ms": 9}, {"save_serial": 5, "saved_unix_ms": 1}))
	assert_true(SaveSync.local_wins({"save_serial": 5, "saved_unix_ms": 9}, {"save_serial": 5, "saved_unix_ms": 1}))
	assert_false(SaveSync.local_wins({"save_serial": 5, "saved_unix_ms": 1}, {"save_serial": 5, "saved_unix_ms": 9}))
	assert_true(SaveSync.local_wins({"save_serial": 5.0, "saved_unix_ms": 7}, {"save_serial": 5, "saved_unix_ms": 7}), "égalité : la locale reste")


func test_canonical_fingerprint_is_stable() -> void:
	var a: Dictionary = {"meta": {"save_serial": 3, "slot": 1}, "current": {"campaign_seed": 4503599627370497, "x": [1, 2.5]}, "snapshots": {2: {"d": 1}}}
	var b: Dictionary = JSON.parse_string('{"snapshots": {"2": {"d": 1}}, "current": {"x": [1, 2.5], "campaign_seed": 4503599627370497}, "meta": {"save_serial": 3}}')
	assert_eq(SaveSync.fingerprint(a), SaveSync.fingerprint(b), "entiers / flottants, ordre des clés, clé volatile `slot`")
	assert_eq(SaveSync.canon(JSON.parse_string("[9007199254740991]")), [9007199254740991], "graine 53 bits exacte à travers JSON")
	assert_eq(typeof(SaveSync.canon(2.5)), TYPE_FLOAT)
	assert_eq(SaveSync.fingerprint({}), "")


# ---------------------------------------------------------------------------
# Crochets de SaveService
# ---------------------------------------------------------------------------

func test_save_serial_grows_per_slot() -> void:
	_play(DIR_A, 1, 101, 3)
	var serial: int = SaveService.slot_serial(1, DIR_A)
	assert_gt(serial, 0)
	# Méta tirée d'un autre appareil avec une série plus haute : la suivante la dépasse.
	var meta: Dictionary = SaveService.read_json(SaveService.meta_path(1, DIR_A))
	meta["save_serial"] = serial + 50
	SaveService.write_atomic(SaveService.meta_path(1, DIR_A), JSON.stringify(meta))
	var state: Node = autofree(GameStateScript.new())
	assert_true(state.call(&"load_from_slot", 1, DIR_A))
	_evening(state, DIR_A)
	assert_eq(SaveService.slot_serial(1, DIR_A), serial + 51)


func test_conflict_copies_lifecycle() -> void:
	_play(DIR_A, 2, 202, 4)
	var files: Dictionary = SaveService.read_slot_files(2, DIR_A)
	assert_eq((files["snapshots"] as Dictionary).size(), 4)
	var name: String = SaveService.write_conflict(2, files, {"source": "remote", "device": "Deck"}, "20261101T020000", DIR_A)
	assert_eq(name, "conflict_20261101T020000")
	assert_eq(SaveService.list_conflicts(2, DIR_A), PackedStringArray([name]))
	assert_eq(SaveService.list_snapshots(2, DIR_A).size(), 4, "les copies ne sont jamais des instantanés")
	var copy: Dictionary = SaveService.read_conflict(2, name, DIR_A)
	assert_eq(str((copy["origin"] as Dictionary)["device"]), "Deck")
	SaveService.discard_conflict(2, name, DIR_A)
	assert_false(SaveService.has_conflict(2, DIR_A))
	# « Garder l'autre » : la copie remplace l'emplacement, série au-dessus des deux.
	var older: Dictionary = SaveService.read_slot_files(2, DIR_A)
	var state: Node = autofree(GameStateScript.new())
	state.call(&"load_from_slot", 2, DIR_A)
	_evening(state, DIR_A)
	assert_eq(_day(DIR_A, 2), 6)
	var other: String = SaveService.write_conflict(2, older, {"source": "remote"}, "", DIR_A)
	var serial_before: int = SaveService.slot_serial(2, DIR_A)
	assert_eq(SaveService.adopt_conflict(2, other, DIR_A), OK)
	assert_eq(_day(DIR_A, 2), 5, "version adoptée")
	assert_gt(SaveService.slot_serial(2, DIR_A), serial_before)
	assert_false(SaveService.has_conflict(2, DIR_A))
	assert_eq(SaveService.list_snapshots(2, DIR_A).size(), 4, "instantanés de la version adoptée seulement")
	# Supprimer l'emplacement retire aussi ses copies.
	SaveService.write_conflict(2, older, {}, "", DIR_A)
	SaveService.delete_slot(2, DIR_A)
	assert_false(DirAccess.dir_exists_absolute(SaveService.slot_dir(2, DIR_A)))


# ---------------------------------------------------------------------------
# Fusion du profil
# ---------------------------------------------------------------------------

func _profile_a() -> Dictionary:
	var p: Dictionary = ProfileService.empty_profile()
	p["endings_seen"] = [{"id": "f5_air", "variant": "b", "act": 3, "day": 30, "date": "2026-10-20T10:00:00", "count": 2,
		"last_date": "2026-10-25T10:00:00", "first_line_key": ""}]
	p["characters_met"] = ["sc_01", "sc_02"]
	p["max_day_reached"] = 30
	p["best_runs"] = [{"score": 40, "seed_code": "K2Q-9TX", "kind": "free", "date": "2026-10-20", "garde_version": 2,
		"duration_sec": 900, "directives": 4, "palier": 1}]
	p["garde_daily"] = {"2026-10-31": {"best": 30, "first_try": 30, "attempts": 2, "garde_version": 2}}
	p["portraits"] = {"chr_arkady": {"appearance": {"skin": 1}, "visor": "none", "case_id": "sc_02", "day": 4, "act": 1}}
	return p


func _profile_b() -> Dictionary:
	var p: Dictionary = ProfileService.empty_profile()
	p["endings_seen"] = [
		{"id": "f5_air", "variant": "b", "act": 3, "day": 29, "date": "2026-10-18T10:00:00", "count": 1,
			"last_date": "2026-10-18T10:00:00", "first_line_key": "end_f5_l1"},
		{"id": "f3_family_lost", "variant": "", "act": 1, "day": 6, "date": "2026-10-19T10:00:00", "count": 1,
			"last_date": "2026-10-19T10:00:00", "first_line_key": ""}]
	p["characters_met"] = ["sc_02", "sc_03"]
	p["max_day_reached"] = 12
	p["story_mode_used"] = true
	p["best_runs"] = [{"score": 55, "seed_code": "NUIT-2026-10-31", "kind": "daily", "date": "2026-10-31", "garde_version": 2,
		"duration_sec": 1200, "directives": 6, "palier": 2}]
	p["garde_daily"] = {"2026-10-31": {"best": 55, "first_try": 12, "attempts": 3, "garde_version": 2}}
	p["portraits"] = {"chr_arkady": {"appearance": {"skin": 2}, "visor": "up", "case_id": "sc_40", "day": 22, "act": 2}}
	return p


func test_profile_merge_is_a_lossless_union() -> void:
	var merged: Dictionary = ProfileService.merge(_profile_a(), _profile_b())
	assert_eq(ProfileService.ending_ids(merged), PackedStringArray(["f5_air", "f3_family_lost"]))
	var f5: Dictionary = {}
	for e: Dictionary in merged["endings_seen"]:
		if e["id"] == "f5_air":
			f5 = e
	assert_eq(str(f5["date"]), "2026-10-18T10:00:00", "première fois : la plus ancienne")
	assert_eq(str(f5["last_date"]), "2026-10-25T10:00:00")
	assert_eq(SaveService.as_int(f5["count"]), 2, "passages : le plus grand (jamais additionnés)")
	assert_eq(str(f5["first_line_key"]), "end_f5_l1")
	assert_eq(merged["characters_met"], ["sc_01", "sc_02", "sc_03"])
	assert_eq(SaveService.as_int(merged["max_day_reached"]), 30)
	assert_true(merged["story_mode_used"])
	assert_eq((merged["best_runs"] as Array).size(), 2)
	assert_eq(SaveService.as_int((merged["best_runs"] as Array)[0]["score"]), 55)
	assert_eq(SaveService.as_int(((merged["garde_daily"] as Dictionary)["2026-10-31"] as Dictionary)["best"]), 55)
	assert_eq(str(((merged["portraits"] as Dictionary)["chr_arkady"] as Dictionary)["case_id"]), "sc_40", "dernière rencontre")


func test_profile_merge_is_idempotent() -> void:
	var once: Dictionary = ProfileService.merge(_profile_a(), _profile_b())
	var twice: Dictionary = ProfileService.merge(once, _profile_b())
	assert_eq(SaveSync.payload_fingerprint(once), SaveSync.payload_fingerprint(twice))
	var thrice: Dictionary = ProfileService.merge(_profile_b(), once)
	assert_eq(ProfileService.ending_ids(thrice).size(), 2)
	assert_eq(SaveService.as_int(thrice["max_day_reached"]), 30)


# ---------------------------------------------------------------------------
# Connexion par code, erreurs réseau
# ---------------------------------------------------------------------------

func test_sign_in_with_code() -> void:
	var c: OnlineClient = _client(DIR_A)
	assert_eq(c.state, OnlineClient.State.DISCONNECTED)
	var bad: Dictionary = await c.request_code("pas-une-adresse")
	assert_eq(bad["error"], OnlineClient.ERR_EMAIL)
	assert_eq(server.sent, 0, "adresse refusée localement : aucune requête")
	var asked: Dictionary = await c.request_code("Nadia@Example.org")
	assert_true(asked["ok"])
	assert_true(c.awaiting_code())
	var wrong: Dictionary = await c.submit_code("000000" if server.last_code != "000000" else "111111")
	assert_eq(wrong["error"], OnlineClient.ERR_OTP)
	assert_eq(c.state, OnlineClient.State.DISCONNECTED)
	var short: Dictionary = await c.submit_code("12")
	assert_eq(short["error"], OnlineClient.ERR_OTP, "longueur vérifiée localement")
	var ok: Dictionary = await c.submit_code(server.last_code.insert(3, " "))
	assert_true(ok["ok"])
	assert_eq(c.state, OnlineClient.State.CONNECTED)
	assert_true(c.has_account())
	assert_string_starts_with(c.display_name(), "Agent·e #")
	var stored: String = FileAccess.get_file_as_string(DIR_A.path_join("online").path_join(OnlineStore.ACCOUNT_FILE))
	assert_true(stored.contains(c.store.token()), "jeton stocké localement")
	var pseudo: Dictionary = await c.set_pseudo("  Nadia  ")
	assert_true(pseudo["ok"])
	assert_eq(c.display_name(), "Nadia")
	var refused: Dictionary = await c.set_pseudo("<b>")
	assert_eq(refused["error"], OnlineClient.ERR_PSEUDO)


func test_code_locked_after_five_failures() -> void:
	var c: OnlineClient = _client(DIR_A)
	await c.request_code("agent@example.org")
	var wrong: String = "999999" if server.last_code != "999999" else "888888"
	for i: int in 5:
		assert_eq((await c.submit_code(wrong))["error"], OnlineClient.ERR_OTP)
	var locked: Dictionary = await c.submit_code(server.last_code)
	assert_eq(locked["error"], OnlineClient.ERR_OTP_LOCKED)
	assert_false(c.awaiting_code(), "redemander un code")


func test_network_failures_retry_then_offline() -> void:
	var c: OnlineClient = _client(DIR_A)
	await _sign_in(c)
	server.offline = true
	var before: int = server.sent
	var report: Dictionary = await c.sync_all()
	assert_false(report["ok"])
	assert_eq(server.sent - before, 4, "1 essai + 3 nouvelles tentatives espacées")
	assert_eq(c.state, OnlineClient.State.OFFLINE)
	assert_true(c.has_account(), "le compte reste")
	server.offline = false
	server.fail_next = 2
	report = await c.sync_all()
	assert_true(report["ok"], "réussite après deux échecs")
	assert_eq(c.state, OnlineClient.State.CONNECTED)
	# 4xx : jamais réessayé.
	server.status_next = [{"status": 400, "body": {"code": "bad_request"}}]
	before = server.sent
	await c.fetch_leaderboard("NUIT-2026-11-01", 2)
	assert_eq(server.sent - before, 1)


func test_expired_session_disconnects_and_keeps_local_data() -> void:
	var c: OnlineClient = _client(DIR_A)
	await _sign_in(c)
	_play(DIR_A, 1, 303, 2)
	server.tokens.clear()
	var report: Dictionary = await c.sync_all()
	assert_false(report["ok"])
	assert_eq(c.state, OnlineClient.State.DISCONNECTED)
	assert_eq(c.last_error, OnlineClient.ERR_SESSION)
	assert_false(c.has_account())
	assert_eq(_day(DIR_A, 1), 3, "données locales intactes")


func test_api_version_mismatch_is_an_error_state() -> void:
	var c: OnlineClient = _client(DIR_A)
	await _sign_in(c)
	server.api_version = 2
	await c.start()
	assert_eq(c.state, OnlineClient.State.ERROR)
	assert_eq(c.last_error, OnlineClient.ERR_API)


# ---------------------------------------------------------------------------
# Synchronisation : deux appareils
# ---------------------------------------------------------------------------

func test_two_devices_push_then_pull() -> void:
	var a: OnlineClient = _client(DIR_A)
	var b: OnlineClient = _client(DIR_B)
	_play(DIR_A, 1, 404, 3)
	await _sign_in(a)
	assert_true(server.saves.values()[0].size() >= 5, "méta, état, 3 instantanés envoyés")
	await _sign_in(b)
	assert_eq(_day(DIR_B, 1), 4, "tiré sur le second appareil")
	assert_eq(SaveService.list_snapshots(1, DIR_B), SaveService.list_snapshots(1, DIR_A))
	assert_eq(SaveSync.fingerprint(SaveSync.slot_files(1, DIR_A)), SaveSync.fingerprint(SaveSync.slot_files(1, DIR_B)))
	var seed_b: int = SaveService.as_int(SaveService.load_current(1, DIR_B)["campaign_seed"])
	assert_eq(seed_b, 404)
	# B joue une soirée de plus et envoie ; A tire.
	var state_b: Node = autofree(GameStateScript.new())
	assert_true(state_b.call(&"load_from_slot", 1, DIR_B))
	_evening(state_b, DIR_B)
	var before: int = server.sent
	await b.sync_all()
	assert_lt(server.sent - before, 7, "seules les lignes changées partent (instantané, état, méta + manifeste, profil)")
	await a.sync_all()
	assert_eq(_day(DIR_A, 1), 5)
	assert_false(SaveService.has_conflict(1, DIR_A))
	# Rien de neuf : aucune écriture.
	before = server.sent
	await a.sync_all()
	assert_eq(server.sent - before, 1, "manifeste seul")


func test_divergent_devices_keep_a_conflict_copy() -> void:
	var a: OnlineClient = _client(DIR_A)
	var b: OnlineClient = _client(DIR_B)
	_play(DIR_A, 2, 505, 2)
	await _sign_in(a)
	await _sign_in(b)
	assert_eq(_day(DIR_B, 2), 3)
	# Les deux appareils avancent sans se voir : A de trois soirées, B d'une.
	var state_a: Node = autofree(GameStateScript.new())
	state_a.call(&"load_from_slot", 2, DIR_A)
	for i: int in 3:
		_evening(state_a, DIR_A)
	var state_b: Node = autofree(GameStateScript.new())
	state_b.call(&"load_from_slot", 2, DIR_B)
	_evening(state_b, DIR_B)
	await a.sync_all()
	var report: Dictionary = await b.sync_all()
	assert_eq(report["conflicts"], [2])
	assert_eq(_day(DIR_B, 2), 6, "la version la plus avancée (série) gagne")
	var copies: PackedStringArray = SaveService.list_conflicts(2, DIR_B)
	assert_eq(copies.size(), 1, "la version perdante est gardée")
	var copy: Dictionary = SaveService.read_conflict(2, copies[0], DIR_B)
	assert_eq(SaveService.as_int((copy["meta"] as Dictionary)["current_day"]), 4)
	assert_eq(str((copy["origin"] as Dictionary)["source"]), "local")
	# Une seconde synchronisation ne recrée pas de conflit.
	report = await b.sync_all()
	assert_eq(report["conflicts"], [])
	# B choisit « Garder l'autre » : sa version repart et gagne partout.
	assert_eq(SaveService.adopt_conflict(2, copies[0], DIR_B), OK)
	await b.sync_all()
	await a.sync_all()
	assert_eq(_day(DIR_A, 2), 4, "le choix du joueur se propage")
	assert_eq(SaveService.list_conflicts(2, DIR_A).size(), 0, "A n'avait pas avancé depuis : simple tirage")


func test_local_winner_keeps_the_remote_copy() -> void:
	var a: OnlineClient = _client(DIR_A)
	var b: OnlineClient = _client(DIR_B)
	_play(DIR_A, 3, 606, 2)
	await _sign_in(a)
	await _sign_in(b)
	var state_a: Node = autofree(GameStateScript.new())
	state_a.call(&"load_from_slot", 3, DIR_A)
	_evening(state_a, DIR_A)
	var state_b: Node = autofree(GameStateScript.new())
	state_b.call(&"load_from_slot", 3, DIR_B)
	for i: int in 2:
		_evening(state_b, DIR_B)
	await a.sync_all()
	await b.sync_all()
	assert_eq(_day(DIR_B, 3), 5, "B garde sa version (série plus haute)")
	var copies: PackedStringArray = SaveService.list_conflicts(3, DIR_B)
	assert_eq(copies.size(), 1)
	assert_eq(str((SaveService.read_conflict(3, copies[0], DIR_B)["origin"] as Dictionary)["source"]), "remote")
	await a.sync_all()
	assert_eq(_day(DIR_A, 3), 5, "A tire la gagnante ; sa version est déjà en copie chez B")


func test_protected_slot_is_never_replaced_under_the_player() -> void:
	var a: OnlineClient = _client(DIR_A)
	var b: OnlineClient = _client(DIR_B)
	_play(DIR_A, 1, 707, 2)
	await _sign_in(a)
	await _sign_in(b)
	var state_a: Node = autofree(GameStateScript.new())
	state_a.call(&"load_from_slot", 1, DIR_A)
	for i: int in 3:
		_evening(state_a, DIR_A)
	await a.sync_all()
	# B a chargé l'emplacement 1 (partie en cours) : pas de tirage sous ses pieds.
	b.protected_slot = 1
	var report: Dictionary = await b.sync_all()
	assert_eq(_day(DIR_B, 1), 3)
	assert_true(b.pending_sync, "tirage repoussé")
	assert_eq(report["pulled"], [])
	b.protected_slot = SaveService.NO_SLOT
	await b.sync_all()
	assert_eq(_day(DIR_B, 1), 6)


func test_deletion_propagates_without_silent_loss() -> void:
	var a: OnlineClient = _client(DIR_A)
	var b: OnlineClient = _client(DIR_B)
	_play(DIR_A, 1, 808, 2)
	await _sign_in(a)
	await _sign_in(b)
	SaveService.delete_slot(1, DIR_A)
	await a.sync_all()
	assert_eq(_manifest_rows(1).size(), 0, "supprimé à distance")
	await b.sync_all()
	assert_eq(_day(DIR_B, 1), 3, "l'autre appareil garde sa copie")
	await b.sync_all()
	assert_eq(_manifest_rows(1).size(), 0, "et ne la renvoie pas tant qu'elle ne change pas")
	var state_b: Node = autofree(GameStateScript.new())
	state_b.call(&"load_from_slot", 1, DIR_B)
	_evening(state_b, DIR_B)
	await b.sync_all()
	assert_gt(_manifest_rows(1).size(), 0, "une partie qui avance repart dans le cloud")


func _manifest_rows(slot: int) -> Array:
	var out: Array = []
	for uid: Variant in server.saves:
		for key: Variant in server.saves[uid]:
			if int((server.saves[uid][key] as Dictionary)["slot"]) == slot:
				out.append(key)
	return out


func test_profile_is_merged_across_devices() -> void:
	ProfileService.save_profile(_profile_a(), DIR_A)
	ProfileService.save_profile(_profile_b(), DIR_B)
	var a: OnlineClient = _client(DIR_A)
	var b: OnlineClient = _client(DIR_B)
	await _sign_in(a)
	await _sign_in(b)
	await a.sync_all()
	var pa: Dictionary = ProfileService.load_profile(DIR_A)
	var pb: Dictionary = ProfileService.load_profile(DIR_B)
	assert_eq(ProfileService.ending_ids(pa).size(), 2, "union des fins sur A")
	assert_eq(ProfileService.ending_ids(pb).size(), 2, "union des fins sur B")
	assert_eq(SaveSync.payload_fingerprint(SaveSync.canon(pa)), SaveSync.payload_fingerprint(SaveSync.canon(pb)))
	assert_eq(SaveService.as_int(pb["max_day_reached"]), 30)


func test_newer_game_version_is_never_pulled() -> void:
	var a: OnlineClient = _client(DIR_A)
	var b: OnlineClient = _client(DIR_B)
	_play(DIR_A, 1, 909, 1)
	await _sign_in(a)
	# Une version future du jeu a écrit l'emplacement (format v7).
	for key: Variant in server.saves.values()[0]:
		var row: Dictionary = server.saves.values()[0][key]
		if str(row["kind"]) == "current":
			(row["payload"] as Dictionary)["version"] = 7
	_play(DIR_B, 1, 910, 3)
	await _sign_in(b)
	assert_eq(_day(DIR_B, 1), 4, "rien n'est écrasé")
	assert_true((b.last_report["errors"] as Array).has(OnlineClient.ERR_FUTURE))


func test_demo_family_is_separate() -> void:
	DemoMode.force = 1
	var a: OnlineClient = _client(DIR_A)
	assert_eq(a.family, SaveSync.FAMILY_DEMO)
	_play(DIR_A, 1, 111, 1)
	await _sign_in(a)
	for key: Variant in server.saves.values()[0]:
		assert_string_starts_with(str((server.saves.values()[0][key] as Dictionary)["kind"]), "demo_")
	DemoMode.force = 0
	var b: OnlineClient = _client(DIR_B)
	await _sign_in(b)
	assert_eq(_day(DIR_B, 1), 0, "le jeu complet ne voit pas la démo")


func test_account_deletion_keeps_local_data() -> void:
	var a: OnlineClient = _client(DIR_A)
	_play(DIR_A, 1, 222, 2)
	await _sign_in(a)
	var result: Dictionary = await a.delete_account()
	assert_true(result["ok"])
	assert_false(a.has_account())
	assert_eq(server.users.size(), 0)
	assert_eq(server.saves.size(), 0)
	assert_eq(_day(DIR_A, 1), 3)
	assert_eq(str(a.store.account.get("email", "")), "", "adresse oubliée")


# ---------------------------------------------------------------------------
# Garde, fins
# ---------------------------------------------------------------------------

func _garde_record(score: int, passengers: int, played_on: String = "2026-11-01") -> Dictionary:
	return {"score": score, "seed_code": "NUIT-2026-11-01", "kind": "daily", "date": "2026-11-01", "played_on": played_on,
			"garde_version": 2, "duration_sec": passengers * 20, "directives": passengers / 5, "palier": 1,
			"passengers": passengers, "end_reason": "errors", "errors": [{}, {}, {}]}


func test_garde_scores_and_leaderboard() -> void:
	var a: OnlineClient = _client(DIR_A)
	var b: OnlineClient = _client(DIR_B)
	await _sign_in(a, "a@example.org")
	await _sign_in(b, "b@example.org")
	await b.set_pseudo("Rook")
	var results: Array = []
	a.garde_submitted.connect(func(_key: String, result: Dictionary) -> void: results.append(result))
	await a.submit_garde(_garde_record(40, 30), true)
	await b.submit_garde(_garde_record(50, 35), false)
	assert_eq(results.size(), 1)
	assert_eq(SaveService.as_int(results[0]["rank"]), 1)
	var board: Dictionary = await a.fetch_leaderboard("NUIT-2026-11-01", 2)
	var data: Dictionary = board["data"]
	assert_eq(SaveService.as_int(data["total"]), 2)
	assert_eq(str((data["entries"] as Array)[0]["pseudo"]), "Rook")
	assert_eq(SaveService.as_int((data["me"] as Dictionary)["rank"]), 2)
	assert_false(a.cached_leaderboard("NUIT-2026-11-01", 2).is_empty(), "cache local (hors ligne)")
	# Score invraisemblable : refusé, jamais renvoyé.
	await a.submit_garde(_garde_record(500, 30, "2026-11-02"), false)
	assert_eq(a.store.pending_scores().size(), 0)
	# Hors ligne : en file, envoyé au retour ; un même envoi n'est jamais doublé.
	server.offline = true
	await a.submit_garde(_garde_record(45, 31, "2026-11-03"), false)
	await a.submit_garde(_garde_record(45, 31, "2026-11-03"), false)
	assert_eq(a.store.pending_scores().size(), 1)
	server.offline = false
	await a.flush_outbox()
	assert_eq(a.store.pending_scores().size(), 0)


func test_endings_reported_once_and_stats_only_for_seen() -> void:
	ProfileService.save_profile(_profile_b(), DIR_A)
	var a: OnlineClient = _client(DIR_A)
	await _sign_in(a)
	assert_eq(server.endings.values()[0].size(), 2, "fins du profil envoyées (rattrapage)")
	var before: int = server.count("/api/clearance/endings")
	await a.report_endings()
	assert_eq(server.count("/api/clearance/endings"), before, "jamais deux fois")
	var result: Dictionary = await a.fetch_ending_stats(PackedStringArray(["f3_family_lost", "f5_air"]))
	assert_true(result["ok"])
	var last: String = server.log[server.log.size() - 1]
	assert_eq(last, "GET /api/clearance/endings")
	assert_eq(a.ending_percent("f5_air"), 100.0)
	assert_eq(a.ending_percent("f1_arrested"), -1.0, "fin non vue : jamais demandée")
	before = server.sent
	await a.fetch_ending_stats(PackedStringArray(["f3_family_lost", "f5_air"]))
	assert_eq(server.sent, before, "cache de 5 min")


# ---------------------------------------------------------------------------
# Silence pendant un shift, sans compte
# ---------------------------------------------------------------------------

func test_no_request_while_quiet() -> void:
	var a: OnlineClient = _client(DIR_A)
	await _sign_in(a)
	_play(DIR_A, 1, 333, 1)
	a.set_quiet(true)
	var before: int = server.sent
	await a.sync_all()
	await a.submit_garde(_garde_record(40, 30), false)
	await a.fetch_leaderboard("NUIT-2026-11-01", 2)
	assert_eq(server.sent, before, "aucune requête pendant un shift")
	assert_true(a.pending_sync)
	a.set_quiet(false)
	assert_gt(server.sent, before, "envoyé à la fin du shift")
	assert_false(a.pending_sync)
	assert_eq(a.store.pending_scores().size(), 0)


func test_no_request_without_account() -> void:
	var a: OnlineClient = _client(DIR_A)
	_play(DIR_A, 1, 444, 2)
	await a.start()
	await a.sync_all()
	await a.submit_garde(_garde_record(40, 30), true)
	await a.fetch_leaderboard("NUIT-2026-11-01", 2)
	await a.fetch_ending_stats(PackedStringArray(["f5_air"]))
	await a.report_endings()
	a.set_quiet(true)
	a.set_quiet(false)
	assert_eq(server.sent, 0)
	assert_false(DirAccess.dir_exists_absolute(DIR_A.path_join("online")), "aucun fichier en ligne écrit sans compte")
	assert_eq(a.state, OnlineClient.State.DISCONNECTED)


func test_async_transport_does_not_block() -> void:
	server.async = true
	var a: OnlineClient = _client(DIR_A)
	var pending: Array = [true]
	var run: Callable = func() -> void:
		await a.request_code("agent@example.org")
		pending[0] = false
	run.call()
	assert_true(pending[0], "l'appel rend la main avant la réponse")
	await wait_physics_frames(3)
	assert_false(pending[0])
	assert_true(a.awaiting_code())
