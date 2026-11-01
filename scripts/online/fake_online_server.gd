## Faux serveur CLEARANCE en mémoire (M16) — double de transport injectable
## qui suit le contrat `docs/ONLINE.md` (API 1) : OTP (code à 6 chiffres,
## verrou après 5 échecs), jetons, `me`, pseudo, suppression du compte,
## sauvegardes (manifeste, lecture, écriture conditionnelle `if_rev`,
## suppressions, familles `game` / `demo`), scores de Garde (meilleur essai,
## plausibilité §6.2, rang), classement, fins (événements idempotents,
## agrégats). Aucun réseau : sert aux tests GUT (deux clients = deux
## appareils sur le même serveur) et aux captures (`--online-fake`).
## Pannes simulées : `offline` (tout échoue), `fail_next` (N échecs réseau),
## `status_next` (N réponses imposées), `async` (réponse à l'image suivante).
## `log` : requêtes reçues (`"GET /api/clearance/saves"`), sans corps.
class_name FakeOnlineServer
extends OnlineTransport

const TAG_ALPHABET: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const OTP_MAX_FAILS: int = 5
const GARDE_MAX_ERRORS: int = 3
const GARDE_MAX_PASSENGERS: int = 400
const TIER_STARTS: Array[int] = [1, 21, 41, 61, 101]
const ENDINGS: Array[String] = ["f1_arrested", "f2_reassigned", "f3_family_lost", "f4_glory", "f5_air", "f6_drift",
	"f7_reopens", "f8_registre", "f9_strike", "f10_pont"]

## Tout échoue (erreur réseau) tant que vrai.
var offline: bool = false
## Nombre de prochaines requêtes en échec réseau.
var fail_next: int = 0
## Réponses imposées aux prochaines requêtes : `[{status, body}]`.
var status_next: Array[Dictionary] = []
## Réponse différée d'une image (`call_deferred`) au lieu d'immédiate.
var async: bool = false
var log: PackedStringArray = []
## Appelé à chaque requête reçue, avant la réponse (tests : « pendant un shift ? »).
var probe: Callable = Callable()
var api_version: int = 1

var users: Dictionary = {}
var tokens: Dictionary = {}
var otps: Dictionary = {}
var saves: Dictionary = {}
var scores: Dictionary = {}
var endings: Dictionary = {}
var last_code: String = ""
var _counter: int = 0
var _clock_ms: int = 1793498400000


func send(req: OnlineRequest) -> void:
	super.send(req)
	log.append("%s %s" % [req.method, req.path])
	if probe.is_valid():
		probe.call(req)
	if offline or fail_next > 0:
		fail_next = maxi(fail_next - 1, 0)
		_finish(req, 0, {}, OnlineRequest.Failure.NETWORK)
		return
	if not status_next.is_empty():
		var forced: Dictionary = status_next.pop_front()
		_finish(req, int(forced.get("status", 500)), forced.get("body", {}) if forced.get("body") is Dictionary else {})
		return
	var body: Dictionary = {}
	if req.body is Dictionary:
		# Comme un vrai serveur : le corps passe par JSON (nombres en flottants).
		var parsed: Variant = JSON.parse_string(JSON.stringify(req.body))
		body = parsed if parsed is Dictionary else {}
	var result: Array = _route(req.method, req.path, req.query, body, req.token)
	var response: Dictionary = result[1]
	var parsed_response: Variant = JSON.parse_string(JSON.stringify(response))
	_finish(req, int(result[0]), parsed_response if parsed_response is Dictionary else {})


func _finish(req: OnlineRequest, status: int, body: Dictionary, failure: OnlineRequest.Failure = OnlineRequest.Failure.NONE) -> void:
	if async:
		req.finish.call_deferred(status, body, failure)
	else:
		req.finish(status, body, failure)


## Nombre de requêtes reçues dont le chemin commence par `prefix`.
func count(prefix: String) -> int:
	var n: int = 0
	for line: String in log:
		var parts: PackedStringArray = line.split(" ", true, 1)
		if parts.size() == 2 and parts[1].begins_with(prefix):
			n += 1
	return n


func _now_ms() -> int:
	_clock_ms += 1000
	return _clock_ms


static func _err(status: int, code: String, message: String = "", data: Dictionary = {}) -> Array:
	var body: Dictionary = {"status": status, "message": message, "data": data}
	if not code.is_empty():
		body["code"] = code
	return [status, body]


func _user_of(token: String) -> String:
	return str(tokens.get(token.trim_prefix("Bearer "), ""))


func _route(method: String, path: String, query: Dictionary, body: Dictionary, token: String) -> Array:
	var uid: String = _user_of(token)
	var parts: PackedStringArray = path.trim_prefix("/").split("/")
	match [method, path]:
		["GET", "/api/health"]:
			return [200, {"message": "API is healthy.", "code": 200, "data": {}}]
		["GET", "/api/clearance/status"]:
			return [200, {"api_version": api_version, "server": "fake", "time_unix_ms": _now_ms(),
					"limits": {"payload_max_bytes": 262144, "body_max_bytes": 327680, "save_rows_max": 240, "pseudo_max_chars": 20},
					"garde_versions": [1, 2], "otp": {"length": 6, "duration_s": 600}, "token_duration_s": 2592000}]
		["POST", "/api/collections/users/request-otp"]:
			return _request_otp(str(body.get("email", "")))
		["POST", "/api/collections/users/auth-with-otp"]:
			return _auth_otp(str(body.get("otpId", "")), str(body.get("password", "")))
		["POST", "/api/collections/users/auth-refresh"]:
			if uid.is_empty():
				return _err(401, "", "The request requires valid record authorization token.")
			return [200, {"token": _issue(uid), "record": _record(uid)}]
		["GET", "/api/clearance/me"]:
			if uid.is_empty():
				return _err(401, "unauthorized")
			var me: Dictionary = _record(uid)
			return [200, {"id": uid, "pseudo": me["pseudo"], "tag": me["tag"], "created": me["created"]}]
		["POST", "/api/clearance/logout-all"]:
			if uid.is_empty():
				return _err(401, "unauthorized")
			for t: Variant in tokens.keys():
				if str(tokens[t]) == uid:
					tokens.erase(t)
			return [204, {}]
		["GET", "/api/clearance/saves"]:
			if uid.is_empty():
				return _err(401, "unauthorized")
			return [200, {"items": _manifest(uid, str(query.get("family", "game"))), "rows": _user_saves(uid).size(), "rows_max": 240}]
		["POST", "/api/clearance/garde/scores"]:
			if uid.is_empty():
				return _err(401, "unauthorized")
			return _post_score(uid, body)
		["GET", "/api/clearance/leaderboard"]:
			return _leaderboard(uid, query)
		["POST", "/api/clearance/endings"]:
			if uid.is_empty():
				return _err(401, "unauthorized")
			return _post_ending(uid, body)
		["GET", "/api/clearance/endings"]:
			return [200, _ending_stats(str(query.get("ids", "")))]
		["GET", "/api/clearance/dev/otp"]:
			var otp: Dictionary = otps.get(str(query.get("otpId", "")), {})
			return [200, {"otpId": query.get("otpId", ""), "code": otp.get("code", "")}] if not otp.is_empty() else _err(404, "not_found")
	if parts.size() == 5 and parts[1] == "collections" and parts[2] == "users" and parts[3] == "records":
		if uid.is_empty() or uid != parts[4]:
			return _err(403 if not uid.is_empty() else 401, "", "Forbidden.")
		if method == "PATCH":
			for key: Variant in body:
				if str(key) != "pseudo":
					return _err(400, "", "Failed to update record.", {str(key): {"code": "not_editable", "message": ""}})
			var pseudo: String = str(body.get("pseudo", "")).strip_edges()
			if pseudo.length() > 20:
				return _err(400, "", "Failed to update record.", {"pseudo": {"code": "out_of_range", "message": ""}})
			var user: Dictionary = users[uid]
			user["pseudo"] = pseudo
			return [200, _record(uid)]
		if method == "DELETE":
			users.erase(uid)
			saves.erase(uid)
			endings.erase(uid)
			for key: Variant in scores.keys():
				if str(key).begins_with(uid + "|"):
					scores.erase(key)
			for t: Variant in tokens.keys():
				if str(tokens[t]) == uid:
					tokens.erase(t)
			return [204, {}]
	if parts.size() >= 4 and parts[1] == "clearance" and parts[2] == "saves":
		if uid.is_empty():
			return _err(401, "unauthorized")
		var slot: int = parts[3].to_int()
		if parts.size() == 4 and method == "DELETE":
			var fam: String = str(query.get("family", "game"))
			var n: int = 0
			for key: Variant in _user_saves(uid).keys():
				var row: Dictionary = _user_saves(uid)[key]
				if int(row["slot"]) == slot and _family_of(str(row["kind"])) == fam:
					_user_saves(uid).erase(key)
					n += 1
			return [200, {"deleted": n}]
		if parts.size() == 6:
			return _save_row(uid, method, slot, parts[4], parts[5].to_int(), body)
	return _err(404, "not_found", "Not found.")


# --- Compte ---------------------------------------------------------------------------

func _request_otp(email: String) -> Array:
	if not OnlineConfig.is_valid_email(email):
		return _err(400, "", "Something went wrong.", {"email": {"code": "validation_is_email", "message": ""}})
	var uid: String = ""
	for id: Variant in users:
		if str((users[id] as Dictionary)["email"]) == email.strip_edges().to_lower():
			uid = str(id)
	if uid.is_empty():
		_counter += 1
		uid = ("u%014d" % _counter)
		var tag: String = ""
		for i: int in 4:
			tag += TAG_ALPHABET[(_counter * 7 + i * 13) % TAG_ALPHABET.length()]
		users[uid] = {"id": uid, "email": email.strip_edges().to_lower(), "pseudo": "", "tag": tag, "created": "2026-11-01 02:00:25.123Z"}
	_counter += 1
	var otp_id: String = "otp%012d" % _counter
	last_code = "%06d" % ((_counter * 7919 + 4231) % 1000000)
	otps[otp_id] = {"user": uid, "code": last_code, "fails": 0}
	return [200, {"otpId": otp_id}]


func _auth_otp(otp_id: String, code: String) -> Array:
	var otp: Dictionary = otps.get(otp_id, {})
	if otp.is_empty():
		return _err(400, "", "Invalid or expired OTP")
	if int(otp["fails"]) >= OTP_MAX_FAILS:
		return _err(429, "otp_locked", "Too many attempts.")
	if str(otp["code"]) != code:
		otp["fails"] = int(otp["fails"]) + 1
		return _err(400, "", "Failed to authenticate.")
	otps.erase(otp_id)
	var uid: String = str(otp["user"])
	return [200, {"token": _issue(uid), "record": _record(uid)}]


func _issue(uid: String) -> String:
	_counter += 1
	var token: String = "tok-%s-%d" % [uid, _counter]
	tokens[token] = uid
	return token


func _record(uid: String) -> Dictionary:
	var user: Dictionary = users.get(uid, {})
	return {"collectionName": "users", "id": uid, "email": user.get("email", ""), "emailVisibility": false, "verified": true,
			"pseudo": user.get("pseudo", ""), "tag": user.get("tag", ""), "created": user.get("created", ""), "updated": ""}


# --- Sauvegardes ----------------------------------------------------------------------

func _user_saves(uid: String) -> Dictionary:
	if not saves.has(uid):
		saves[uid] = {}
	return saves[uid]


static func _family_of(kind: String) -> String:
	return "demo" if kind.begins_with("demo_") else "game"


func _manifest(uid: String, fam: String) -> Array:
	var rows: Array = []
	var keys: Array = _user_saves(uid).keys()
	keys.sort()
	for key: Variant in keys:
		var row: Dictionary = (_user_saves(uid)[key] as Dictionary).duplicate()
		if fam != "all" and _family_of(str(row["kind"])) != fam:
			continue
		row.erase("payload")
		rows.append(row)
	return rows


func _save_row(uid: String, method: String, slot: int, kind: String, day: int, body: Dictionary) -> Array:
	var base: String = kind.trim_prefix("demo_")
	var valid_kind: bool = base in ["current", "meta", "snapshot", "profile"]
	var coherent: bool = valid_kind and ((base == "profile" and slot == 0 and day == 0) \
			or (base in ["current", "meta"] and slot >= 1 and slot <= 3 and day == 0) \
			or (base == "snapshot" and slot >= 1 and slot <= 3 and day >= 1 and day <= 31))
	if not coherent:
		return _err(400, "invalid_field", "Bad slot/kind/day.", {"kind": {"code": "bad_value", "message": ""}})
	var key: String = "%d|%s|%02d" % [slot, kind, day]
	var rows: Dictionary = _user_saves(uid)
	var existing: Dictionary = rows.get(key, {})
	match method:
		"GET":
			if existing.is_empty():
				return _err(404, "not_found")
			return [200, existing.duplicate(true)]
		"DELETE":
			rows.erase(key)
			return [200, {"deleted": 0 if existing.is_empty() else 1}]
		"PUT":
			if not body.get("payload") is Dictionary:
				return _err(400, "invalid_field", "payload", {"payload": {"code": "required", "message": ""}})
			var if_rev: Variant = body.get("if_rev", null)
			if if_rev != null:
				var want: int = int(if_rev)
				var have: int = int(existing.get("rev", 0))
				if want != have:
					var current: Variant = null
					if not existing.is_empty():
						var copy: Dictionary = existing.duplicate()
						copy.erase("payload")
						current = copy
					return _err(409, "rev_conflict", "Row changed.", {"current": current})
			var size: int = JSON.stringify(body["payload"]).to_utf8_buffer().size()
			if size > 262144:
				return _err(413, "payload_too_large")
			if existing.is_empty() and rows.size() >= 240:
				return _err(403, "quota_exceeded")
			_counter += 1
			var row: Dictionary = {"id": "r%014d" % _counter, "slot": slot, "kind": kind, "day": day,
					"rev": int(existing.get("rev", 0)) + 1, "save_serial": int(body.get("save_serial", 0)),
					"saved_unix_ms": int(body.get("saved_unix_ms", 0)), "game_version": str(body.get("game_version", "")),
					"device": str(body.get("device", "")), "size": size, "updated_unix_ms": _now_ms(), "payload": body["payload"]}
			rows[key] = row
			var out: Dictionary = row.duplicate()
			out.erase("payload")
			return [201 if existing.is_empty() else 200, out]
	return _err(405, "bad_request")


# --- Garde ----------------------------------------------------------------------------

func _post_score(uid: String, body: Dictionary) -> Array:
	var reasons: Array[String] = []
	var errors: int = int(body.get("errors", 0))
	var passengers: int = int(body.get("passengers", 0))
	var score: int = int(body.get("score", 0))
	var correct: int = passengers - errors
	if errors > GARDE_MAX_ERRORS:
		reasons.append("errors_above_max")
	if errors > passengers:
		reasons.append("errors_above_passengers")
	if passengers > GARDE_MAX_PASSENGERS:
		reasons.append("passengers_above_max")
	if score < correct:
		reasons.append("score_below_correct")
	if score > 2 * correct:
		reasons.append("score_above_max")
	if int(body.get("duration_s", 0)) < 2 * passengers:
		reasons.append("too_fast")
	var tier: int = 0
	for i: int in TIER_STARTS.size():
		if passengers + 1 >= TIER_STARTS[i]:
			tier = i
	if int(body.get("tier_max", 0)) > tier:
		reasons.append("tier_above_passengers")
	if int(body.get("directives", 0)) > floori(passengers / 5.0):
		reasons.append("directives_above_passengers")
	if not reasons.is_empty():
		return _err(422, "score_implausible", "Score hors des bornes plausibles.", {"reasons": reasons})
	var seed_code: String = str(body.get("seed_code", "")).strip_edges().to_upper()
	if seed_code.is_empty():
		return _err(400, "invalid_field", "seed_code", {"seed_code": {"code": "required", "message": ""}})
	var version: int = int(body.get("garde_version", 1))
	var key: String = "%s|%s|%d" % [uid, seed_code, version]
	var best: Dictionary = scores.get(key, {})
	var improved: bool = best.is_empty() or score > int(best["score"]) \
			or (score == int(best["score"]) and errors < int(best["errors"])) \
			or (score == int(best["score"]) and errors == int(best["errors"]) and int(body.get("duration_s", 0)) < int(best["duration_s"]))
	var attempts: int = int(best.get("attempts", 0)) + 1
	if improved:
		best = {"seed_code": seed_code, "garde_version": version, "score": score, "errors": errors,
				"tier_max": int(body.get("tier_max", 0)), "passengers": passengers, "duration_s": int(body.get("duration_s", 0)),
				"first_try": body.get("first_try", false) == true, "user": uid, "order": _now_ms()}
	best["attempts"] = attempts
	scores[key] = best
	var board: Array = _board(seed_code, version)
	var rank: int = 1
	for entry: Dictionary in board:
		if int(entry["score"]) > int(best["score"]):
			rank += 1
	var shown: Dictionary = best.duplicate()
	shown.erase("user")
	shown.erase("order")
	return [200, {"improved": improved, "best": shown, "rank": rank, "total": board.size()}]


func _board(seed_code: String, version: int) -> Array:
	var board: Array = []
	for key: Variant in scores:
		var entry: Dictionary = scores[key]
		if str(entry["seed_code"]) == seed_code and int(entry["garde_version"]) == version:
			board.append(entry)
	board.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["score"]) != int(b["score"]):
			return int(a["score"]) > int(b["score"])
		if int(a["errors"]) != int(b["errors"]):
			return int(a["errors"]) < int(b["errors"])
		if int(a["duration_s"]) != int(b["duration_s"]):
			return int(a["duration_s"]) < int(b["duration_s"])
		return int(a["order"]) < int(b["order"]))
	return board


func _leaderboard(uid: String, query: Dictionary) -> Array:
	var seed_code: String = str(query.get("seed", "")).strip_edges().to_upper()
	if seed_code.is_empty():
		return _err(400, "bad_request", "seed")
	var version: int = int(str(query.get("version", "1")))
	var limit: int = clampi(int(str(query.get("limit", "10"))), 1, 50)
	var board: Array = _board(seed_code, version)
	var entries: Array = []
	var me: Variant = null
	for entry: Dictionary in board:
		var rank: int = 1
		for other: Dictionary in board:
			if int(other["score"]) > int(entry["score"]):
				rank += 1
		var user: Dictionary = users.get(str(entry["user"]), {})
		var row: Dictionary = {"rank": rank, "pseudo": user.get("pseudo", ""), "tag": user.get("tag", ""), "score": entry["score"],
				"errors": entry["errors"], "tier_max": entry["tier_max"], "passengers": entry["passengers"],
				"duration_s": entry["duration_s"], "first_try": entry["first_try"], "is_me": str(entry["user"]) == uid}
		if entries.size() < limit:
			entries.append(row)
		if row["is_me"]:
			me = row
	return [200, {"seed_code": seed_code, "garde_version": version, "total": board.size(), "entries": entries, "me": me}]


# --- Fins -----------------------------------------------------------------------------

func _post_ending(uid: String, body: Dictionary) -> Array:
	var ending_id: String = str(body.get("ending_id", ""))
	var act: int = int(body.get("act", 0))
	var difficulty: String = str(body.get("difficulty", ""))
	if not ENDINGS.has(ending_id) or act < 1 or act > 3 or not difficulty in ["hard", "story"]:
		return _err(400, "invalid_field", "ending", {"ending_id": {"code": "bad_value", "message": ""}})
	if not endings.has(uid):
		endings[uid] = {}
	var key: String = "%s:%s" % [ending_id, str(body.get("variant", ""))]
	var mine: Dictionary = endings[uid]
	if mine.has(key):
		return [200, {"created": false}]
	mine[key] = {"ending_id": ending_id, "variant": str(body.get("variant", ""))}
	return [201, {"created": true}]


func _ending_stats(ids_text: String) -> Dictionary:
	var players: int = 0
	var counts: Dictionary = {}
	for uid: Variant in endings:
		var mine: Dictionary = endings[uid]
		if mine.is_empty():
			continue
		players += 1
		var seen: Dictionary = {}
		for key: Variant in mine:
			seen[str(key).get_slice(":", 0)] = true
		for id: Variant in seen:
			counts[id] = int(counts.get(id, 0)) + 1
	var wanted: Array = []
	if not ids_text.is_empty():
		for id: String in ids_text.split(","):
			wanted.append(id)
	else:
		wanted = counts.keys()
	var out: Dictionary = {}
	for id: Variant in wanted:
		var n: int = int(counts.get(id, 0))
		out[str(id)] = {"players": n, "percent": snappedf(100.0 * n / players, 0.1) if players > 0 else 0.0, "variants": {}}
	return {"players": players, "generated_unix_ms": _now_ms(), "max_age_s": 300, "endings": out}


# --- Démonstration (captures `--online-fake`) -----------------------------------------

## Remplit le serveur : 14 agents et leurs scores sur `daily_code`, fins
## obtenues ; crée le compte « Nadia » (classé 4ᵉ) et renvoie sa connexion
## `{token, record}`.
func seed_demo(daily_code: String, version: int) -> Dictionary:
	var names: Array[String] = ["Okonkwo_fan", "", "Mira.K", "", "Tessar-7", "lumen", "", "Arkady", "Quai 3", "", "Halcyon", "", "Noa", ""]
	var demo_scores: Array[int] = [112, 98, 91, 77, 70, 64, 58, 51, 47, 40, 33, 28, 19, 12]
	var demo_endings: Array[String] = ["f5_air", "f3_family_lost", "f10_pont", "f5_air", "f1_arrested", "f7_reopens", "f5_air",
			"f2_reassigned", "f10_pont", "f3_family_lost", "f5_air", "f9_strike", "f6_drift", "f4_glory"]
	for i: int in names.size():
		var email: String = "agent%02d@example.org" % i
		var otp: Dictionary = _request_otp(email)[1]
		var login: Dictionary = _auth_otp(str(otp["otpId"]), last_code)[1]
		var uid: String = str((login["record"] as Dictionary)["id"])
		var user: Dictionary = users[uid]
		user["pseudo"] = names[i]
		var passengers: int = demo_scores[i] / 2 + 3
		_post_score(uid, {"seed_code": daily_code, "garde_version": version, "score": mini(demo_scores[i], 2 * (passengers - 3)),
				"errors": 3, "tier_max": 0, "passengers": passengers, "directives": passengers / 5, "duration_s": passengers * 30, "first_try": i % 3 == 0})
		_post_ending(uid, {"ending_id": demo_endings[i], "variant": "", "act": 3, "difficulty": "hard"})
	var otp_me: Dictionary = _request_otp("nadia.demo@example.org")[1]
	var me: Dictionary = _auth_otp(str(otp_me["otpId"]), last_code)[1]
	var my_id: String = str((me["record"] as Dictionary)["id"])
	var mine: Dictionary = users[my_id]
	mine["pseudo"] = "Nadia"
	_post_score(my_id, {"seed_code": daily_code, "garde_version": version, "score": 84, "errors": 2, "tier_max": 3,
			"passengers": 61, "directives": 9, "duration_s": 1830, "first_try": true})
	for ending: String in ["f3_family_lost", "f5_air", "f10_pont"]:
		_post_ending(my_id, {"ending_id": ending, "variant": "", "act": 3, "difficulty": "hard"})
	me["record"] = _record(my_id)
	return me
