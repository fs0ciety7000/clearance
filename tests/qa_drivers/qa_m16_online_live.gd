## Pilote d'intégration M16 (facultatif, hors GUT) : le vrai client
## (`OnlineClient` + `HttpTransport`) contre un **PocketBase local** lancé par
## `tools/online_dev_server.sh` (lot S, mode dev OTP : le code se lit par
## `GET /api/clearance/dev/otp`). Deux clients sur deux dossiers = deux
## appareils. Parcours : statut, connexion par code, envoi puis tirage d'un
## emplacement, conflit (copie gardée), fusion du profil, pseudo, score de
## Garde et classement, fins et statistiques, 4xx non réessayé, suppression du
## compte. Sorties : `M16LIVE PASS|FAIL <étape>` puis `M16LIVE SUMMARY`.
## Usage (données jetables) :
##   PB_HOME=/tmp/pb bash tools/online_dev_server.sh --port 8097 --fresh &
##   XDG_DATA_HOME=$(mktemp -d) godot --headless --path . --script res://tools/qa_boot.gd -- \
##       --qa-node=res://tests/qa_drivers/qa_m16_online_live.gd --online-url=http://127.0.0.1:8097
## (via `qa_boot` : le pilote a besoin des autoloads ; `tests/qa_drivers/qa_m16_online_live.sh`
## enchaîne serveur jetable + pilote dans une seule commande.)
extends Node

const GameStateScript: GDScript = preload("res://scripts/autoload/game_state.gd")
const DIR_A: String = "user://qa_m16_live/a"
const DIR_B: String = "user://qa_m16_live/b"

var host: Node = null
var passed: int = 0
var failed: int = 0
var base_url: String = "http://127.0.0.1:8090"


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	if ok:
		passed += 1
		print("M16LIVE PASS %s" % what)
	else:
		failed += 1
		print("M16LIVE FAIL %s" % what)


func _client(dir: String) -> OnlineClient:
	var c: OnlineClient = OnlineClient.new(HttpTransport.new(host, base_url), OnlineStore.new(dir.path_join("online")), dir)
	c.waiter = func(seconds: float) -> Signal: return get_tree().create_timer(seconds).timeout
	return c


## Code du mode dev (jamais en production).
func _dev_code(otp_id: String) -> String:
	var req: OnlineRequest = OnlineRequest.make("GET", "/api/clearance/dev/otp", null, "", {"otpId": otp_id})
	var t: HttpTransport = HttpTransport.new(host, base_url)
	t.send(req)
	if not req.done:
		await req.completed
	return str(req.response.get("code", ""))


func _sign_in(c: OnlineClient, email: String) -> bool:
	var asked: Dictionary = await c.request_code(email)
	if not asked.get("ok", false):
		print("M16LIVE request_code: %s" % asked)
		return false
	var code: String = await _dev_code(c._otp_id)
	var done: Dictionary = await c.submit_code(code)
	return done.get("ok", false)


func _play(dir: String, slot: int, p_seed: int, days: int) -> Node:
	var state: Node = GameStateScript.new()
	add_child(state)
	state.call(&"new_campaign", p_seed, slot, &"hard")
	for i: int in days:
		state.call(&"record_day_entry", {"processed": 5, "correct": 5, "credits": 25})
		state.call(&"save_to_slot", slot, dir)
	return state


func _evening(state: Node, dir: String) -> void:
	state.call(&"record_day_entry", {"processed": 5, "correct": 4, "credits": 20})
	state.call(&"save_to_slot", SaveService.NO_SLOT, dir)


func _day(dir: String, slot: int) -> int:
	return SaveService.as_int(SaveService.load_meta(slot, dir).get("current_day", 0))


func _run() -> void:
	await get_tree().process_frame
	var arg: String = OnlineConfig.debug_arg("online-url")
	if not arg.is_empty():
		base_url = arg
	host = Node.new()
	add_child(host)
	SaveService.remove_tree("user://qa_m16_live")
	var email: String = "m16live+%d@example.org" % (Time.get_ticks_usec() % 1000000)
	# 1. Statut.
	var a: OnlineClient = _client(DIR_A)
	var b: OnlineClient = _client(DIR_B)
	var p: Dictionary = ProfileService.empty_profile()
	p["endings_seen"] = [{"id": "f5_air", "variant": "b", "act": 3, "day": 30, "date": "2026-10-20T10:00:00", "count": 1,
		"last_date": "2026-10-20T10:00:00", "first_line_key": ""}]
	p["characters_met"] = ["sc_01"]
	ProfileService.save_profile(p, DIR_A)
	var q: Dictionary = ProfileService.empty_profile()
	q["endings_seen"] = [{"id": "f3_family_lost", "variant": "", "act": 1, "day": 6, "date": "2026-10-21T10:00:00", "count": 1,
		"last_date": "2026-10-21T10:00:00", "first_line_key": ""}]
	q["characters_met"] = ["sc_02"]
	ProfileService.save_profile(q, DIR_B)
	var state_a: Node = _play(DIR_A, 1, 4242, 3)
	# 2. Connexion par code et premier envoi.
	check(await _sign_in(a, email), "connexion par code (A)")
	check(a.state == OnlineClient.State.CONNECTED, "état connecté (A)")
	check((a.last_report.get("pushed", []) as Array).has(1), "emplacement 1 envoyé")
	await a.start()
	check(a.state == OnlineClient.State.CONNECTED and a.otp_length() == 6, "statut, API 1, code à 6 chiffres")
	# 3. Second appareil : tirage, fusion du profil.
	check(await _sign_in(b, email), "connexion par code (B)")
	check(_day(DIR_B, 1) == 4, "emplacement tiré sur B (jour 4)")
	check(SaveSync.fingerprint(SaveSync.slot_files(1, DIR_A)) == SaveSync.fingerprint(SaveSync.slot_files(1, DIR_B)), "contenu identique")
	await a.sync_all()
	check(ProfileService.ending_ids(ProfileService.load_profile(DIR_A)).size() == 2, "profil fusionné sur A (2 fins)")
	check(ProfileService.ending_ids(ProfileService.load_profile(DIR_B)).size() == 2, "profil fusionné sur B (2 fins)")
	# 4. Conflit : les deux avancent.
	for i: int in 2:
		_evening(state_a, DIR_A)
	var state_b: Node = GameStateScript.new()
	add_child(state_b)
	state_b.call(&"load_from_slot", 1, DIR_B)
	_evening(state_b, DIR_B)
	await a.sync_all()
	var report: Dictionary = await b.sync_all()
	check((report.get("conflicts", []) as Array).has(1), "conflit détecté sur B")
	check(_day(DIR_B, 1) == 6, "la version la plus avancée gagne (jour 6)")
	check(SaveService.list_conflicts(1, DIR_B).size() == 1, "copie de conflit gardée")
	report = await b.sync_all()
	check((report.get("conflicts", []) as Array).is_empty() and report.get("ok", false), "pas de second conflit")
	# 5. Pseudo, Garde, classement.
	check((await a.set_pseudo("Nadia"))["ok"], "pseudo")
	var code: String = GardeService.today_code()
	var record: Dictionary = {"score": 40, "seed_code": code, "kind": "daily", "played_on": "x", "garde_version": GardeScreen.current_version(),
			"duration_sec": 900, "directives": 5, "palier": 1, "passengers": 30, "end_reason": "errors", "errors": [{}, {}, {}]}
	var results: Array = []
	a.garde_submitted.connect(func(_k: String, r: Dictionary) -> void: results.append(r))
	await a.submit_garde(record, true)
	check(results.size() == 1 and SaveService.as_int((results[0] as Dictionary).get("rank", 0)) >= 1, "score de Garde accepté (rang %d)" % [SaveService.as_int((results[0] as Dictionary).get("rank", 0)) if not results.is_empty() else 0])
	var board: Dictionary = await a.fetch_leaderboard(code, GardeScreen.current_version())
	var me: Variant = (board.get("data", {}) as Dictionary).get("me", null)
	check(board.get("ok", false) and me is Dictionary and str((me as Dictionary).get("pseudo", "")) == "Nadia", "classement : top N et rang du joueur")
	var bad: Dictionary = record.duplicate()
	bad["score"] = 999
	bad["played_on"] = "y"
	var before: int = a.transport.sent
	await a.submit_garde(bad, false)
	check(a.transport.sent - before == 1 and a.store.pending_scores().is_empty(), "score invraisemblable : 422, jamais réessayé")
	# 6. Fins.
	await a.report_endings()
	var stats: Dictionary = await a.fetch_ending_stats(PackedStringArray(["f3_family_lost", "f5_air"]), true)
	check(stats.get("ok", false) and a.ending_percent("f5_air") > 0.0, "statistiques des fins vues (%.1f %%)" % a.ending_percent("f5_air"))
	# 7. Suppression du compte.
	check((await a.delete_account())["ok"], "compte supprimé")
	await b.sync_all()
	check(not b.has_account() and b.last_error == OnlineClient.ERR_SESSION, "l'autre appareil est déconnecté")
	check(_day(DIR_B, 1) == 6, "données locales intactes")
	print("M16LIVE SUMMARY passed=%d failed=%d (%s)" % [passed, failed, base_url])
	state_a.queue_free()
	state_b.queue_free()
	get_tree().quit(1 if failed > 0 else 0)
