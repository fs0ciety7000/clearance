## M12 lot A — Garde de nuit (B57, D-126 → D-128, ARCHITECTURE §11.5) :
## graines (jour UTC, codes libres), ordre des directives (tiers, prérequis,
## rotation), déterminisme indépendant des verdicts, erreurs et fin, records
## au profil, mode garde du `DayController`.
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")
const DIR: String = "user://test_m12_garde"


func before_each() -> void:
	_clear()


func after_all() -> void:
	_clear()
	DirAccess.remove_absolute(DIR)


func _clear() -> void:
	for name: String in [ProfileService.FILE_NAME, ProfileService.V1_BACKUP_FILE]:
		SaveService.remove_with_fallbacks(DIR.path_join(name))


func _unit(id: StringName, rule_ids: Array[StringName], tier: int, prerequisites: Array[StringName] = [],
		detain: bool = false) -> GardeUnitDef:
	var unit: GardeUnitDef = GardeUnitDef.new()
	unit.id = id
	unit.tier = tier
	unit.prerequisites = prerequisites
	unit.enables_detain = detain
	for rule_id: StringName in rule_ids:
		unit.rules.append(CaseFactory.rule(rule_id))
	return unit


func _tier(index: int, from_passenger: int, rotation: bool = false) -> GardeTierDef:
	var tier: GardeTierDef = GardeTierDef.new()
	tier.index = index
	tier.from_passenger = from_passenger
	tier.anomaly_count_weights = PackedFloat32Array([1.0, 0.0, 0.0, 0.0])
	tier.legit_noise_rate = 0.0
	tier.visor_down_rate = 0.0
	tier.rotation = rotation
	return tier


## Garde de test : 9 unités réelles (R04 → R21), paliers sans anomalie.
func _def() -> GardeDef:
	var def: GardeDef = GardeDef.new()
	def.version = 3
	var template: DayDef = CaseFactory.catalog().get_day(3).duplicate() as DayDef
	template.day_number = 0
	template.scripted_cases = []
	template.wanted_notices = []
	template.mode = DayDef.MODE_GARDE
	template.passenger_count = 60
	template.detain_enabled = false
	template.rule_set = CaseFactory.rule_set_of([&"r_id_card_required", &"r_id_card_valid", &"r_portrait_match",
			&"r_identity_fields_match"])
	def.day_template = template
	def.units = [
		_unit(&"u01", [&"r_permit_required", &"r_permit_valid"], 1),
		_unit(&"u03", [&"r_origin_block"], 1),
		_unit(&"u04", [&"r_face_uncovered"], 1),
		_unit(&"u05", [&"r_mrz_valid"], 1),
		_unit(&"u02", [&"r_purpose_consistent"], 1, [&"u01"]),
		_unit(&"u07", [&"r_bioscan_required", &"r_bioscan_valid"], 2),
		_unit(&"u08", [&"r_bioscan_issuer", &"r_bioscan_fit"], 2, [&"u07"]),
		_unit(&"u11", [&"r_identity_fraud_detain"], 2, [], true),
		_unit(&"u14", [&"r_seals_valid"], 3),
	]
	def.tiers = [_tier(0, 1), _tier(1, 21), _tier(2, 41), _tier(3, 61), _tier(4, 101, true)]
	def.date_min = GameDate.from_ymd(2187, 5, 1)
	def.date_max = GameDate.from_ymd(2187, 11, 30)
	return def


func _events() -> StationEventsDef:
	var events: StationEventsDef = StationEventsDef.new()
	for id: StringName in [&"ev_02", &"ev_04", &"ev_01"]:
		var event: StationEventDef = StationEventDef.new()
		event.id = id
		event.garde_window_passengers = 5 if id == &"ev_04" else 3
		if id == &"ev_01":
			event.garde_required_unit = &"u05"
			event.changes = [RuleChangeDef.retire(&"r_mrz_valid", "sev_mrz_reader_rb")]
		elif id == &"ev_04":
			event.garde_changes = [RuleChangeDef.modify(RuleChangeDef.MOD_SCORE_PER_CORRECT, 1)]
		else:
			event.changes = [RuleChangeDef.modify(RuleChangeDef.MOD_COMPARATOR_DOWN, 1)]
		events.events.append(event)
	return events


func test_daily_code_is_utc_and_seed_is_53_bits() -> void:
	var unix: int = int(Time.get_unix_time_from_datetime_string("2026-10-29T00:00:00"))
	assert_eq(GardeService.daily_code(unix), "NUIT-2026-10-29")
	assert_eq(GardeService.daily_code(unix + 86399), "NUIT-2026-10-29", "23:59:59 UTC")
	assert_eq(GardeService.daily_code(unix + 86400), "NUIT-2026-10-30", "minuit UTC")
	assert_eq(GardeService.daily_code(unix - 1), "NUIT-2026-10-28")
	var garde_seed: int = GardeService.seed_of("NUIT-2026-10-29")
	assert_eq(garde_seed, SeededRng.hash_string("NUIT-2026-10-29") & GardeService.JSON_SAFE_MASK, "FNV-1a 64 tronqué")
	assert_true(garde_seed >= 0 and garde_seed <= GardeService.JSON_SAFE_MASK)
	assert_eq(SaveService.as_int(float(garde_seed)), garde_seed, "exacte en JSON")
	assert_eq(GardeService.daily_date("NUIT-2026-10-29"), "2026-10-29")
	assert_eq(GardeService.normalize_code("nuit-2026-10-29")["code"], "NUIT-2026-10-29")
	assert_ne(GardeService.stream_seed(garde_seed, &"order"), GardeService.stream_seed(garde_seed, &"queue"), "flux séparés")


func test_free_codes_accept_case_and_dash_refuse_ambiguous_symbols() -> void:
	assert_eq(GardeService.normalize_code("k2q9tx")["code"], "K2Q-9TX")
	assert_eq(GardeService.normalize_code(" K2Q-9TX ")["code"], "K2Q-9TX")
	assert_eq(GardeService.normalize_code("k2q-9tx")["kind"], GardeService.KIND_FREE)
	for bad: String in ["K2Q-9TO", "I2Q9TX", "K2Q9T0", "12Q9TX"]:
		var result: Dictionary = GardeService.normalize_code(bad)
		assert_false(result["ok"], bad)
		assert_eq(result["error_key"], GardeService.ERROR_INVALID_CHARS, "%s : O, I, 0, 1 signalés" % bad)
	assert_false(GardeService.normalize_code("K2Q9T")["ok"], "5 caractères")
	assert_false(GardeService.normalize_code("K2Q9TXA")["ok"], "7 caractères")
	assert_eq(GardeService.seed_of("k2q9tx"), GardeService.seed_of("K2Q-9TX"), "même graine")
	assert_eq(GardeService.seed_of("O00000"), 0, "invalide")
	for bits: int in [0, 1, 31, 32, 123456789, 0x3FFFFFFF]:
		var code: String = GardeService.code_from_bits(bits)
		assert_true(GardeService.normalize_code(code)["ok"], code)
		assert_eq(GardeService.bits_of(code), bits, "aller-retour %s" % code)
	assert_eq(GardeService.random_code(42), GardeService.random_code(42), "reproductible avec entropie")
	assert_true(GardeService.normalize_code(GardeService.random_code())["ok"])


func test_access_requires_first_day_done() -> void:
	assert_false(GardeService.is_unlocked(ProfileService.empty_profile()))
	var profile: Dictionary = ProfileService.empty_profile()
	profile["max_day_reached"] = 1
	assert_false(GardeService.is_unlocked(profile), "J1 en cours")
	profile["max_day_reached"] = 2
	assert_true(GardeService.is_unlocked(profile), "J1 terminé (D-128)")


func test_directive_plan_tiers_prerequisites_and_rotation() -> void:
	var def: GardeDef = _def()
	for garde_seed: int in range(1, 60):
		var plan: Array[Dictionary] = GardeService.directive_plan(def, garde_seed, 16)
		assert_eq(plan, GardeService.directive_plan(def, garde_seed, 16), "déterministe")
		var active: Array[StringName] = []
		var adds: int = 0
		for entry: Dictionary in plan:
			var unit: GardeUnitDef = def.get_unit(entry["unit_id"])
			var number: int = entry["number"]
			match StringName(entry["action"]):
				GardeService.ACTION_ADD:
					adds += 1
					if number <= 3:
						assert_eq(unit.tier, 1, "directives 1 à 3 : tier 1")
					elif number <= 8:
						assert_lte(unit.tier, 2, "directives 4 à 8 : tiers 1 et 2 (sauf épuisement)")
					for prerequisite: StringName in unit.prerequisites:
						assert_true(active.has(prerequisite), "%s après %s" % [unit.id, prerequisite])
					assert_false(active.has(unit.id))
					active.append(unit.id)
				GardeService.ACTION_RETIRE:
					assert_eq(adds, def.units.size(), "rotation seulement après épuisement du pool")
					assert_lte(unit.tier, 2, "rotation : tier 1 ou 2")
					active.erase(unit.id)
				GardeService.ACTION_RESTORE:
					var previous: Dictionary = plan[number - 2]
					assert_eq(previous["action"], GardeService.ACTION_RETIRE, "un retrait, puis son rétablissement")
					assert_eq(previous["unit_id"], unit.id)
					active.append(unit.id)
		assert_eq(adds, def.units.size(), "tout le pool sort")
	assert_eq(GardeService.tier_cap(def, 1), 1)
	assert_eq(GardeService.tier_cap(def, 4), 2)
	assert_eq(GardeService.tier_cap(def, 9), 3)


func _result(citation: bool, index: int) -> CaseResult:
	var result: CaseResult = CaseResult.new(StringName("g_%d" % index))
	result.verdict_kind = VerdictKind.Kind.DENY if citation else VerdictKind.Kind.APPROVE
	result.expected_verdict = VerdictKind.Kind.APPROVE
	result.citation_reason_key = ScoringService.CIT_UNJUSTIFIED_DENIAL if citation else ""
	result.correct = not citation
	return result


## Trace d'une garde : directives et événements, pour une politique de verdict.
func _trace(def: GardeDef, events: StationEventsDef, code: String, error_every: int, count: int) -> Array:
	var run: GardeRun = GardeService.new_run(code, def, events)
	var trace: Array = []
	for i: int in count:
		var step: Dictionary = run.after_case(_result(error_every > 0 and i % error_every == 0, i))
		var directive: Dictionary = step["directive"]
		if not directive.is_empty():
			trace.append(["dir", run.passengers, directive["unit_id"], directive["action"]])
		for plan: StationEventPlan in step["events_started"]:
			trace.append(["ev", run.passengers, plan.event.id, plan.start_index, plan.end_index])
		if step["tier_changed"]:
			trace.append(["tier", run.passengers, run.tier_index])
	return trace


func test_run_is_deterministic_whatever_the_verdicts() -> void:
	var def: GardeDef = _def()
	def.max_errors = 1000
	var events: StationEventsDef = _events()
	for code: String in ["NUIT-2026-10-29", "K2Q-9TX", "ABC-234"]:
		var perfect: Array = _trace(def, events, code, 0, 120)
		var sloppy: Array = _trace(def, events, code, 3, 120)
		assert_eq(perfect, sloppy, "%s : mêmes directives, paliers et événements" % code)
		var directive_count: int = 0
		var event_passengers: Array[int] = []
		for row: Array in perfect:
			if row[0] == "dir":
				directive_count += 1
				assert_eq(int(row[1]) % 5, 0, "une directive tous les 5 passagers")
			elif row[0] == "ev":
				event_passengers.append(int(row[1]))
		assert_eq(directive_count, 24)
		assert_false(event_passengers.is_empty(), "au moins un événement en 120 passagers")
		assert_between(event_passengers[0] + 1, 16, 26, "premier événement vers les passagers 16 à 20")
		for p: int in event_passengers:
			assert_gte(p % 5, def.event_quiet_after_directive, "pas juste après une directive")
	var other: Array = _trace(def, events, "NUIT-2026-10-30", 0, 120)
	assert_ne(_trace(def, events, "NUIT-2026-10-29", 0, 120), other, "une autre graine, une autre garde")


func test_three_errors_end_the_run_and_score_counts_correct_verdicts() -> void:
	var run: GardeRun = GardeService.new_run("K2Q-9TX", _def(), _events())
	assert_not_null(run)
	assert_eq(run.kind, GardeService.KIND_FREE)
	var date: int = run.game_date
	assert_true(date >= GameDate.from_ymd(2187, 5, 1) and date <= GameDate.from_ymd(2187, 11, 30), "date de 2187")
	assert_eq(run.clock_minute(), 22 * 60)
	for i: int in 7:
		run.after_case(_result(false, i))
	assert_eq(run.score, 7)
	assert_eq(run.clock_minute(), 22 * 60 + 42, "6 min par passager")
	run.after_case(_result(true, 7))
	run.after_case(_result(true, 8))
	assert_false(run.ended)
	var last: Dictionary = run.after_case(_result(true, 9))
	assert_true(last["over"])
	assert_true(run.ended)
	assert_eq(run.end_reason, GardeRun.END_ERRORS)
	assert_eq(run.errors.size(), 3)
	assert_eq(run.errors[0]["citation"], ScoringService.CIT_UNJUSTIFIED_DENIAL)
	assert_eq(run.after_case(_result(false, 10))["points"], 0, "plus rien après la fin")
	var record: Dictionary = run.to_record()
	assert_eq(record["score"], 7)
	assert_eq(record["garde_version"], 3)
	assert_eq(record["seed_code"], "K2Q-9TX")
	assert_eq(record["directives"], 1)
	var quitter: GardeRun = GardeService.new_run("NUIT-2026-10-29", _def())
	quitter.after_case(_result(false, 0))
	quitter.quit()
	assert_eq(quitter.end_reason, GardeRun.END_QUIT)
	assert_eq(quitter.to_record()["date"], "2026-10-29", "graine du jour : date du code")
	assert_null(GardeService.new_run("OOO-000", _def()), "code invalide")


func test_inspection_event_doubles_points() -> void:
	var run: GardeRun = GardeService.new_run("K2Q-9TX", _def(), _events())
	var ctx: RuleContext = CaseFactory.context(CaseFactory.rule_set_of([&"r_id_card_required"]))
	ctx.apply_changes([RuleChangeDef.modify(RuleChangeDef.MOD_SCORE_PER_CORRECT, 1)], &"ev_04@g1")
	assert_eq(run.after_case(_result(false, 0), ctx)["points"], 2, "EV-04 en Garde : double")
	assert_eq(run.after_case(_result(false, 1))["points"], 1)


func test_records_top_ten_daily_first_try_and_free_seeds() -> void:
	var badges: Dictionary = ProfileService.record_garde(DIR, {"score": 12, "seed_code": "NUIT-2026-10-29", "kind": "daily",
			"date": "2026-10-29", "garde_version": 3, "passengers": 15, "directives": 3})
	assert_true(badges["new_record"])
	assert_true(badges["first_try"])
	assert_true(badges["daily_record"])
	badges = ProfileService.record_garde(DIR, {"score": 20, "seed_code": "NUIT-2026-10-29", "kind": "daily",
			"date": "2026-10-29", "garde_version": 3, "passengers": 23})
	assert_false(badges["first_try"], "second essai")
	assert_true(badges["daily_record"])
	assert_true(badges["new_record"])
	badges = ProfileService.record_garde(DIR, {"score": 5, "seed_code": "NUIT-2026-10-29", "kind": "daily",
			"date": "2026-10-29", "garde_version": 3})
	assert_false(badges["daily_record"])
	assert_false(badges["new_record"])
	var profile: Dictionary = ProfileService.load_profile(DIR)
	var daily: Dictionary = profile["garde_daily"]["2026-10-29"]
	assert_eq(daily["first_try"], 12, "premier essai conservé")
	assert_eq(daily["best"], 20)
	assert_eq(daily["attempts"], 3)
	assert_eq(profile["garde_stats"]["runs"], 3)
	assert_eq(profile["garde_stats"]["total_correct"], 37)
	assert_eq(profile["garde_stats"]["longest_run"], 23)
	# Autre version : un record ne se compare qu'à version égale.
	badges = ProfileService.record_garde(DIR, {"score": 6, "seed_code": "K2Q-9TX", "kind": "free", "garde_version": 4})
	assert_true(badges["new_record"], "nouvelle garde_version")
	for i: int in 12:
		ProfileService.record_garde(DIR, {"score": 30 + i, "seed_code": GardeService.code_from_bits(i), "kind": "free",
				"garde_version": 3})
	profile = ProfileService.load_profile(DIR)
	var runs: Array = profile["best_runs"]
	assert_eq(runs.size(), ProfileService.TOP_RUNS, "top 10")
	assert_eq(runs[0]["score"], 41)
	for i: int in runs.size() - 1:
		assert_gte(int(runs[i]["score"]), int(runs[i + 1]["score"]), "décroissant")
	assert_eq((profile["garde_seeds"] as Array).size(), 13)
	assert_eq(profile["garde_seeds"][0]["seed_code"], GardeService.code_from_bits(11), "la plus récente d'abord")
	for i: int in 10:
		ProfileService.record_garde(DIR, {"score": 1, "seed_code": GardeService.code_from_bits(100 + i), "kind": "free"})
	assert_eq((ProfileService.load_profile(DIR)["garde_seeds"] as Array).size(), ProfileService.FREE_SEEDS, "20 graines libres")
	# Purge à 60 jours.
	ProfileService.record_garde(DIR, {"score": 3, "seed_code": "NUIT-2026-12-28", "kind": "daily", "date": "2026-12-28",
			"garde_version": 3})
	var keys: Array = ProfileService.load_profile(DIR)["garde_daily"].keys()
	assert_false(keys.has("2026-10-29"), "plus de 60 jours : purgé")
	assert_true(keys.has("2026-12-28"))
	ProfileService.record_garde(DIR, {"score": 3, "seed_code": "NUIT-2026-10-30", "kind": "daily", "date": "2026-10-30",
			"garde_version": 3})
	assert_true(ProfileService.load_profile(DIR)["garde_daily"].has("2026-10-30"), "59 jours avant : gardé")


func test_day_controller_garde_mode_directives_detain_and_end() -> void:
	var def: GardeDef = _def()
	var run: GardeRun = GardeService.new_run("K2Q-9TX", def, _events())
	var credits_before: int = GameState.credits
	var clock: DayClock = DayClock.new()
	var dc: DayController = DayController.new()
	dc.clock = clock
	add_child_autofree(clock)
	add_child_autofree(dc)
	clock.set_process(false)
	dc.set_process(false)
	var directives: Array[int] = []
	var ended: Array[Dictionary] = []
	var changed: Array[RuleDiff] = []
	var on_directive: Callable = func(number: int, _unit: StringName, _action: StringName) -> void: directives.append(number)
	var on_end: Callable = func(record: Dictionary) -> void: ended.append(record)
	var on_rules: Callable = func(diff: RuleDiff) -> void: changed.append(diff)
	EventBus.garde_directive.connect(on_directive)
	EventBus.garde_ended.connect(on_end)
	EventBus.rules_changed.connect(on_rules)
	assert_true(dc.start_garde(CaseFactory.catalog(), run))
	assert_eq(dc.mode, DayDef.MODE_GARDE)
	assert_eq(dc.day.game_date, run.game_date)
	assert_eq(dc.day.rule_set.rules.size(), 4, "socle R01, R02, R03, R07")
	assert_true(clock.untimed, "pas de chrono")
	assert_eq(dc.current_minute(), 22 * 60)
	dc.close_intro()
	var first_unit: GardeUnitDef = def.get_unit(run.plan_entry(1)["unit_id"])
	for i: int in 5:
		EventBus.next_case_requested.emit()
		if dc.current_case != null:
			EventBus.passenger_arrived.emit(dc.current_case.case_id)
		var c: Case = dc.current_case
		assert_eq(dc.current_key.expected_verdict, VerdictKind.Kind.APPROVE, "garde de test sans anomalie")
		EventBus.verdict_stamped.emit(Verdict.new(c.case_id, VerdictKind.Kind.APPROVE))
		EventBus.passenger_departed.emit(c.case_id)
	assert_eq(run.score, 5)
	assert_eq(directives, [1] as Array[int], "directive après le 5ᵉ passager")
	assert_false(dc.day.rule_set.has_rule(first_unit.rules[0].id), "pas encore en vigueur")
	EventBus.next_case_requested.emit()
	if dc.current_case != null:
		EventBus.passenger_arrived.emit(dc.current_case.case_id)
	assert_true(dc.day.rule_set.has_rule(first_unit.rules[0].id), "en vigueur au 6ᵉ passager (D-077)")
	assert_eq(changed.size(), 1)
	assert_true(changed[0].rulebook[changed[0].rulebook.size() - 1].is_new, "badge NOUVEAU")
	# Trois erreurs : refus injustifiés.
	var c6: Case = dc.current_case
	EventBus.verdict_stamped.emit(Verdict.new(c6.case_id, VerdictKind.Kind.DENY))
	EventBus.passenger_departed.emit(c6.case_id)
	for i: int in 2:
		EventBus.next_case_requested.emit()
		if dc.current_case != null:
			EventBus.passenger_arrived.emit(dc.current_case.case_id)
		var c: Case = dc.current_case
		EventBus.verdict_stamped.emit(Verdict.new(c.case_id, VerdictKind.Kind.DENY))
		EventBus.passenger_departed.emit(c.case_id)
	assert_true(run.ended)
	assert_eq(dc.phase, DayPhase.Kind.SUMMARY, "fin de garde")
	assert_eq(ended.size(), 1)
	assert_eq(ended[0]["score"], 5)
	assert_eq((ended[0]["errors"] as Array).size(), 3)
	assert_eq(GameState.credits, credits_before, "aucune économie")
	assert_eq(dc.summary.get_wage_total(), 0)
	var badges: Dictionary = Campaign.finish_garde(run, DIR)
	assert_true(badges["new_record"])
	assert_eq(ProfileService.load_profile(DIR)["best_runs"][0]["score"], 5)
	EventBus.garde_directive.disconnect(on_directive)
	EventBus.garde_ended.disconnect(on_end)
	EventBus.rules_changed.disconnect(on_rules)


func test_request_end_garde_between_passengers() -> void:
	var run: GardeRun = GardeService.new_run("NUIT-2026-10-29", _def())
	var dc: DayController = DayController.new()
	add_child_autofree(dc)
	dc.set_process(false)
	dc.start_garde(CaseFactory.catalog(), run)
	dc.close_intro()
	EventBus.next_case_requested.emit()
	if dc.current_case != null:
		EventBus.passenger_arrived.emit(dc.current_case.case_id)
	var c: Case = dc.current_case
	EventBus.verdict_stamped.emit(Verdict.new(c.case_id, VerdictKind.Kind.APPROVE))
	EventBus.passenger_departed.emit(c.case_id)
	assert_true(dc.request_end_garde())
	assert_eq(dc.phase, DayPhase.Kind.SUMMARY)
	assert_eq(run.end_reason, GardeRun.END_QUIT)
	assert_eq(run.score, 1, "le score compte")
	assert_false(dc.request_end_garde(), "déjà terminée")
