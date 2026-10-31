## PaScheduler (M14 §4.4, VH-6, D-189 ; §6.3) : déterminisme par graine,
## espacements, plafond, exclusions (bark, annonce de jeu ±25 s, fin du chrono,
## coupure), pools par acte, jour, événement, monde et Garde, pas de
## répétition, veille exclue, aucune information de jeu dans les textes,
## rendu (jingle + voix) et durée du sous-titre.
extends GutTest

## Mentions de document validées dans le texte même de M14 §4.4 (D-189) : une
## consigne générale, sans règle ni seuil ; signalées au lot E pour relecture.
const VALIDATED_MENTIONS: Dictionary = {"pa_ev07": "carte d'identité"}
const QUIET: Dictionary = {"bark_active": false, "since_bark": 999.0, "since_game_announce": 999.0,
	"remaining_sec": INF, "power_down": false, "event_id": ""}


func _all_keys(_key: String) -> bool:
	return true


## Simule un shift de `seconds` (pas de 0,5 s) : [[temps, clé], …].
func _run(s: PaScheduler, seconds: float, ctx: Dictionary = QUIET) -> Array[Array]:
	var out: Array[Array] = []
	var t: float = 0.0
	while t < seconds:
		t += 0.5
		var key: String = s.tick(0.5, ctx)
		if not key.is_empty():
			out.append([t, key])
	return out


func _scheduler(day: int, garde: bool = false, world: StringName = &"", seed_value: int = 77) -> PaScheduler:
	var s: PaScheduler = PaScheduler.new()
	s.setup(seed_value, day, garde, world, _all_keys)
	return s


func test_deterministic_by_seed() -> void:
	var a: Array[Array] = _run(_scheduler(4), 1200.0)
	var b: Array[Array] = _run(_scheduler(4), 1200.0)
	assert_eq(a, b, "même graine, mêmes annonces")
	var c: Array[Array] = _run(_scheduler(4, false, &"", 78), 1200.0)
	assert_ne(a, c, "autre graine, autres annonces")


func test_spacing_and_cap() -> void:
	for seed_value: int in 20:
		var shots: Array[Array] = _run(_scheduler(5, false, &"", seed_value), 2400.0)
		assert_eq(shots.size(), PaScheduler.MAX_PER_SHIFT, "6 au plus par shift")
		assert_between(float(shots[0][0]), PaScheduler.FIRST_MIN_SEC, PaScheduler.FIRST_MAX_SEC + 0.5)
		for k: int in range(1, shots.size()):
			var gap: float = float(shots[k][0]) - float(shots[k - 1][0])
			assert_between(gap, PaScheduler.GAP_MIN_SEC - 0.5, PaScheduler.GAP_MAX_SEC + 0.5)
		var keys: Dictionary = {}
		for shot: Array in shots:
			assert_false(keys.has(shot[1]), "pas de répétition dans la journée")
			keys[shot[1]] = true
	var garde: Array[Array] = _run(_scheduler(3, true), 3000.0)
	assert_gt(garde.size(), 6, "Garde : pas de plafond")
	for k: int in range(1, garde.size()):
		assert_ne(garde[k][1], garde[k - 1][1], "Garde : jamais deux fois de suite")
	for k: int in range(1, garde.size()):
		assert_between(float(garde[k][0]) - float(garde[k - 1][0]), PaScheduler.GARDE_GAP_MIN_SEC - 0.5,
				PaScheduler.GARDE_GAP_MAX_SEC + 0.5)


func test_exclusions_defer_then_abandon() -> void:
	for ctx_patch: Dictionary in [{"bark_active": true}, {"since_bark": 2.0}, {"since_game_announce": 10.0},
			{"remaining_sec": 20.0}, {"power_down": true}]:
		var ctx: Dictionary = QUIET.duplicate()
		ctx.merge(ctx_patch, true)
		assert_true(PaScheduler.blocked(ctx), "exclusion %s" % ctx_patch)
		var s: PaScheduler = _scheduler(2)
		s.next_in = 0.0
		assert_eq(s.tick(0.1, ctx), "", "repoussée")
		assert_almost_eq(s.next_in, PaScheduler.RETRY_SEC, 0.001, "de 10 s")
		for k: int in PaScheduler.MAX_RETRIES:
			s.next_in = 0.0
			s.tick(0.1, ctx)
		assert_eq(s.retries, 0, "abandonnée après 3 reports")
		assert_true(s.next_in >= PaScheduler.GAP_MIN_SEC, "puis la suivante plus tard")
		assert_true(s.played.is_empty())
	assert_false(PaScheduler.blocked(QUIET))
	var late: Dictionary = QUIET.duplicate()
	late["since_game_announce"] = 26.0
	late["remaining_sec"] = 31.0
	assert_false(PaScheduler.blocked(late), "hors des marges")


func test_pools_by_act_day_event_world_and_garde() -> void:
	var keys: Callable = func(day: int, garde: bool, world: StringName, event: StringName) -> Array[String]:
		var out: Array[String] = []
		for entry: Array in PaScheduler.pool_for(day, garde, world, event):
			out.append(entry[0])
		return out
	var j3: Array[String] = keys.call(3, false, &"", &"")
	assert_eq(j3.size(), 10)
	for k: String in j3:
		assert_true(k.begins_with("pa_a1_") and not k.begins_with("pa_a1_q2"), "J3 : Acte I seulement (%s)" % k)
	assert_true(keys.call(9, false, &"", &"").has("pa_a1_q2_01"), "J8–J10 : quai 2")
	assert_false(keys.call(11, false, &"", &"").has("pa_a1_q2_01"))
	assert_true(keys.call(17, false, &"", &"").has("pa_a2_08"), "couvre-feu J16–J20")
	assert_false(keys.call(12, false, &"", &"").has("pa_a2_08"))
	assert_true(keys.call(28, false, &"", &"").has("pa_a3_10"))
	assert_false(keys.call(29, false, &"", &"").has("pa_a3_05"), "J21–J28 seulement")
	assert_true(keys.call(4, false, &"", &"ev_06").has("pa_ev06"), "événement actif")
	assert_false(keys.call(4, false, &"", &"").has("pa_ev06"))
	assert_false(keys.call(4, false, &"", &"ev_05").has("pa_ev05"), "EV-05 : aucune annonce")
	assert_eq(keys.call(5, true, &"", &""), ["pa_garde_01", "pa_garde_02", "pa_garde_03", "pa_garde_04"] as Array[String])
	assert_eq(keys.call(31, false, &"d", &""), ["pa_epi_d_01", "pa_epi_d_02"] as Array[String])
	assert_eq(PaScheduler.load_table().call(&"all_keys").size(), 52, "52 lignes (M14 §4.4, data/audio/pa_lines.tres)")
	var with_event: Array[Array] = PaScheduler.pool_for(4, false, &"", &"ev_02")
	for entry: Array in with_event:
		if entry[0] == "pa_ev02":
			assert_eq(float(entry[1]), PaScheduler.WEIGHT_EVENT, "l'événement pèse plus")
	var none: Callable = func(_k: String) -> bool: return false
	assert_true(PaScheduler.pool_for(4, false, &"", &"", none).is_empty(), "clé absente de fr.csv : ignorée")


func test_yesterday_last_lines_are_excluded() -> void:
	var s: PaScheduler = _scheduler(6)
	var yesterday: Array[String] = PaScheduler.order_for(77, 5, &"", _all_keys)
	assert_eq(s.excluded, yesterday.slice(3, 6), "3 dernières lignes de la veille")
	for shot: Array in _run(s, 2400.0):
		assert_false(s.excluded.has(shot[1]))


func test_texts_carry_no_game_information() -> void:
	var present: int = 0
	var rule_code: RegEx = RegEx.create_from_string("\\bR\\d+\\b")
	var doc_titles: PackedStringArray = []
	for key: String in ["doc_id_card_title", "doc_entry_permit_title", "doc_work_permit_title", "doc_medical_cert_title"]:
		if UiText.has(key):
			doc_titles.append(UiText.t(key).to_lower())
	for key: String in PaScheduler.load_table().call(&"all_keys"):
		assert_true(key.begins_with(PaScheduler.KEY_PREFIX))
		assert_null(rule_code.search(key), "%s : pas de code de règle" % key)
		if not UiText.has(key):
			continue
		present += 1
		var text: String = UiText.t(key)
		assert_lte(text.length(), 90, "%s : ≤ 90 caractères" % key)
		assert_null(rule_code.search(text), "%s : aucun code de règle" % key)
		for title: String in doc_titles:
			if VALIDATED_MENTIONS.get(key, "") == title:
				continue
			assert_false(text.to_lower().contains(title), "%s : aucun nom de document" % key)
	if present == 0:
		pending("textes pa_* du lot E pas encore dans fr.csv")


func test_render_and_subtitle_duration() -> void:
	var p: Passenger = Passenger.new()
	p.appearance_seed = 9100
	var prof: TessarVoice.Profile = TessarVoice.profile_for(p)
	var voice: PackedFloat32Array = PaScheduler.render("vesh ota lumi", prof, &"")
	assert_gt(voice.size(), AudioDsp.samples(1.5, PaScheduler.RATE), "jingle + voix")
	assert_lte(AudioDsp.peak(voice), 0.71)
	assert_eq(PaScheduler.render("vesh ota lumi", prof, &""), voice, "déterministe")
	assert_ne(PaScheduler.jingle(&"d"), PaScheduler.jingle(&""), "monde D : MO-2, pas MO-1")
	assert_ne(PaScheduler.jingle(&"b"), PaScheduler.jingle(&""), "monde B : MO-1 adouci")
	assert_almost_eq(PaScheduler.subtitle_seconds(1.0, "court"), 2.5, 0.001)
	assert_almost_eq(PaScheduler.subtitle_seconds(4.0, "court"), 4.8, 0.001)
	var long_text: String = "x".repeat(100)
	assert_almost_eq(PaScheduler.subtitle_seconds(2.0, long_text), 6.0, 0.001)
