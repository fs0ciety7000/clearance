## M12 lot A — événements de station (B58, D-129, ARCHITECTURE §11.6) :
## calendrier pur et déterministe, jours et classes éligibles, fenêtres hors
## cas scénarisés, annonce avant effet, fin de fenêtre, clôture avant un cas
## scénarisé, modificateurs du contrôleur (comparateur, prime, avertissements).
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")
const DayHarness := preload("res://tests/helpers/day_harness.gd")


func _event(id: StringName, event_class: StationEventDef.EventClass, changes: Array[RuleChangeDef],
		window: int = 3, required: StringName = &"") -> StationEventDef:
	var event: StationEventDef = StationEventDef.new()
	event.id = id
	event.key = id
	event.event_class = event_class
	event.window_kind = StationEventDef.WindowKind.PASSENGERS
	event.window_passengers = window
	event.required_rule_id = required
	event.changes = changes
	event.announce_key = "sev_%s_announce" % id
	event.end_key = "sev_%s_end" % id
	return event


## Catalogue de test : calendrier de M12 §3.3, 4 événements.
func _catalog() -> StationEventsDef:
	var def: StationEventsDef = StationEventsDef.new()
	var a: int = StationEventsDef.CLASS_A
	var ab: int = StationEventsDef.CLASS_A | StationEventsDef.CLASS_B
	def.eligible_days = {4: a, 5: a, 6: ab, 7: a, 8: ab, 12: a, 13: a, 14: ab, 15: a, 16: a, 18: ab, 19: ab,
		22: ab, 23: ab, 25: ab, 26: a, 27: ab, 28: ab}
	def.events = [
		_event(&"ev_01", StationEventDef.EventClass.A, [RuleChangeDef.retire(&"r_mrz_valid", "sev_mrz_reader_rb")], 4,
				&"r_mrz_valid"),
		_event(&"ev_02", StationEventDef.EventClass.B, [RuleChangeDef.modify(RuleChangeDef.MOD_COMPARATOR_DOWN, 1)], 3),
		_event(&"ev_04", StationEventDef.EventClass.A, [RuleChangeDef.modify(RuleChangeDef.MOD_CORRECT_BONUS, 2),
				RuleChangeDef.modify(RuleChangeDef.MOD_NO_FREE_CITATIONS, 1)], 5),
		_event(&"ev_07", StationEventDef.EventClass.B, [RuleChangeDef.modify(RuleChangeDef.MOD_MAX_ANOMALIES, 1)], 4),
	]
	return def


func test_schedule_is_pure_and_respects_calendar() -> void:
	var data: DataCatalog = CaseFactory.catalog()
	var def: StationEventsDef = _catalog()
	var totals: Array[int] = []
	var types_seen: Dictionary[StringName, int] = {}
	for campaign_seed: int in range(1, 201):
		var first: Dictionary[int, StationEventPlan] = StationEventService.schedule(campaign_seed, def, data.days)
		var again: Dictionary[int, StationEventPlan] = StationEventService.schedule(campaign_seed, def, data.days)
		assert_eq(first.keys(), again.keys(), "graine %d : déterministe" % campaign_seed)
		var counts: Dictionary[StringName, int] = {}
		var previous: int = -100
		var days: Array = first.keys()
		days.sort()
		for value: Variant in days:
			var day_number: int = int(value)
			var plan: StationEventPlan = first[day_number]
			assert_eq(plan.event.id, again[day_number].event.id)
			assert_eq(plan.announce_after, again[day_number].announce_after)
			assert_true(def.eligible_days.has(day_number), "jour %d éligible" % day_number)
			assert_ne(day_number, previous + 1, "jamais le lendemain d'un événement")
			previous = day_number
			if plan.event.is_class_b():
				assert_ne(def.eligible_days[day_number] & StationEventsDef.CLASS_B, 0, "classe B un jour « A+B » (J%d)" % day_number)
				assert_eq(plan.free_citations_bonus, 1, "compensation des classes B")
			var day: DayDef = data.get_day(day_number)
			if plan.event.required_rule_id != &"":
				assert_true(day.rule_set.has_rule(plan.event.required_rule_id), "prérequis actif")
			for index: int in day.scripted_indices():
				assert_false(plan.covers(index), "J%d : la fenêtre ne couvre aucun cas scénarisé (@%d)" % [day_number, index])
			assert_gt(plan.announce_after, 0, "annonce après un passager")
			assert_eq(plan.start_index, plan.announce_after, "effet au passager suivant")
			counts[plan.event.id] = counts.get(plan.event.id, 0) + 1
			types_seen[plan.event.id] = 1
		for id: StringName in counts:
			assert_lte(counts[id], def.max_per_type, "au plus 2 fois par campagne")
		totals.append(first.size())
	var mean: float = 0.0
	for total: int in totals:
		mean += total
	mean /= totals.size()
	assert_between(mean, 2.5, 6.0, "environ 4 à 5 événements par campagne (moyenne %.2f)" % mean)
	assert_eq(types_seen.size(), 4, "chaque type sort")
	assert_eq(StationEventService.schedule(1, null, data.days).size(), 0, "sans données : aucun événement")


func test_placement_avoids_scripted_indices_or_fails() -> void:
	var day: DayDef = DayDef.new()
	day.day_number = 6
	day.passenger_count = 6
	var scripted: ScriptedCaseDef = ScriptedCaseDef.new()
	scripted.id = &"sc_test"
	scripted.at_index = 3
	day.scripted_cases = [scripted]
	var event: StationEventDef = _event(&"ev_x", StationEventDef.EventClass.A, [], 2)
	for s: int in range(1, 30):
		var plan: StationEventPlan = StationEventService.place(event, day, SeededRng.new(s))
		assert_not_null(plan)
		assert_false(plan.covers(3), "fenêtre [%d, %d)" % [plan.start_index, plan.end_index])
	event.window_passengers = 4
	assert_null(StationEventService.place(event, day, SeededRng.new(1)), "aucune place : pas d'événement")
	event.window_kind = StationEventDef.WindowKind.REST_OF_DAY
	event.window_passengers = 0
	var rest: StationEventPlan = StationEventService.place(event, day, SeededRng.new(2))
	assert_gt(rest.start_index, 3, "après le dernier cas scénarisé")
	assert_eq(rest.end_index, -1)


func _harness(day_number: int) -> DayHarness:
	var h: DayHarness = DayHarness.new()
	h.setup(self, null, day_number)
	# Indépendant des données d'événements (lot B) : plans fournis par le test.
	h.controller.station_events.clear()
	h.controller.day.free_citations_per_day = CaseFactory.catalog().get_day(day_number).free_citations_per_day
	h.controller.close_intro()
	return h


func _plan(event: StationEventDef, announce_after: int, day_number: int) -> StationEventPlan:
	var plan: StationEventPlan = StationEventPlan.new()
	plan.event = event
	plan.day_number = day_number
	plan.announce_after = announce_after
	plan.start_index = announce_after
	plan.end_index = announce_after + event.window_passengers
	return plan


func _play_one(dc: DayController, kind: VerdictKind.Kind = VerdictKind.Kind.APPROVE) -> CaseResult:
	EventBus.next_case_requested.emit()
	if dc.current_case != null:
		EventBus.passenger_arrived.emit(dc.current_case.case_id)
	var c: Case = dc.current_case
	var results: Array[CaseResult] = []
	var on_resolved: Callable = func(_id: StringName, result: CaseResult) -> void: results.append(result)
	EventBus.case_resolved.connect(on_resolved)
	EventBus.verdict_stamped.emit(Verdict.new(c.case_id, kind))
	EventBus.case_resolved.disconnect(on_resolved)
	EventBus.passenger_departed.emit(c.case_id)
	return results[0] if not results.is_empty() else null


func test_announce_before_effect_then_window_ends() -> void:
	var h: DayHarness = _harness(10)
	var dc: DayController = h.controller
	var event: StationEventDef = _event(&"ev_01", StationEventDef.EventClass.A,
			[RuleChangeDef.retire(&"r_mrz_valid", "sev_mrz_reader_rb")], 2)
	var scripted: PackedInt32Array = dc.day.scripted_indices()
	var at: int = 1
	while scripted.has(at) or scripted.has(at + 1) or scripted.has(at + 2):
		at += 1
	dc.station_events = [_plan(event, at, 10)] as Array[StationEventPlan]
	var started: Array[StationEventPlan] = []
	var ended: Array[StationEventPlan] = []
	var on_start: Callable = func(plan: StationEventPlan) -> void: started.append(plan)
	var on_end: Callable = func(plan: StationEventPlan) -> void: ended.append(plan)
	EventBus.station_event_started.connect(on_start)
	EventBus.station_event_ended.connect(on_end)
	for i: int in at:
		_play_one(dc)
	assert_eq(started.size(), 1, "annoncé après le passager %d" % at)
	assert_true(dc.day.rule_set.has_rule(&"r_mrz_valid"), "pas encore d'effet (passager suivant)")
	assert_eq(dc.active_station_events().size(), 1)
	EventBus.next_case_requested.emit()
	if dc.current_case != null:
		EventBus.passenger_arrived.emit(dc.current_case.case_id)
	assert_false(dc.day.rule_set.has_rule(&"r_mrz_valid"), "R21 suspendue pour le passager suivant")
	assert_eq(dc.day.rule_set.build_retired_entries()[0].note_key, "sev_mrz_reader_rb")
	var c: Case = dc.current_case
	EventBus.verdict_stamped.emit(Verdict.new(c.case_id, VerdictKind.Kind.APPROVE))
	EventBus.passenger_departed.emit(c.case_id)
	_play_one(dc)
	assert_eq(ended.size(), 1, "fin de fenêtre après 2 passagers")
	EventBus.next_case_requested.emit()
	if dc.current_case != null:
		EventBus.passenger_arrived.emit(dc.current_case.case_id)
	assert_true(dc.day.rule_set.has_rule(&"r_mrz_valid"), "R21 rétablie")
	assert_true(CaseFactory.catalog().get_day(10).rule_set.has_rule(&"r_mrz_valid"), "données intactes")
	EventBus.station_event_started.disconnect(on_start)
	EventBus.station_event_ended.disconnect(on_end)
	h.teardown()


func test_structural_event_closes_before_scripted_case() -> void:
	var h: DayHarness = _harness(10)
	var dc: DayController = h.controller
	var scripted: PackedInt32Array = dc.day.scripted_indices()
	assert_false(scripted.is_empty(), "le J10 a des cas scénarisés")
	var target: int = -1
	for index: int in scripted:
		if index >= 2 and not scripted.has(index - 1):
			target = index
			break
	assert_gt(target, 0)
	var event: StationEventDef = _event(&"ev_01", StationEventDef.EventClass.A,
			[RuleChangeDef.retire(&"r_mrz_valid")], 10)
	var plan: StationEventPlan = _plan(event, target - 1, 10)
	dc.station_events = [plan] as Array[StationEventPlan]
	for i: int in target:
		_play_one(dc)
	assert_eq(plan.state, StationEventPlan.State.ACTIVE)
	assert_false(dc.day.rule_set.has_rule(&"r_mrz_valid"), "effet en cours avant le cas scénarisé")
	EventBus.next_case_requested.emit()
	if dc.current_case != null:
		EventBus.passenger_arrived.emit(dc.current_case.case_id)
	if dc.builder.get_scripted_case(target) != null:
		assert_eq(plan.state, StationEventPlan.State.ENDED, "clos avant un cas scénarisé")
		assert_true(dc.day.rule_set.has_rule(&"r_mrz_valid"), "le cas scénarisé est jugé sur ses règles")
		assert_true(dc.day.rule_set.overlay_suspended)
	h.teardown()


func test_comparator_down_waives_undocumented_denial_and_inspection_modifiers() -> void:
	var h: DayHarness = _harness(8)
	var dc: DayController = h.controller
	dc.builder.ctx.apply_changes([RuleChangeDef.modify(RuleChangeDef.MOD_COMPARATOR_DOWN, 1)], &"ev_02")
	var waived: bool = false
	var guard: int = 0
	while dc.has_remaining_cases() and guard < 30 and not waived:
		guard += 1
		EventBus.next_case_requested.emit()
		if dc.current_case != null:
			EventBus.passenger_arrived.emit(dc.current_case.case_id)
		var c: Case = dc.current_case
		var expected: VerdictKind.Kind = dc.current_key.expected_verdict
		var results: Array[CaseResult] = []
		var on_resolved: Callable = func(_id: StringName, result: CaseResult) -> void: results.append(result)
		EventBus.case_resolved.connect(on_resolved)
		var kind: VerdictKind.Kind = VerdictKind.Kind.DENY if expected == VerdictKind.Kind.DENY else VerdictKind.Kind.APPROVE
		EventBus.verdict_stamped.emit(Verdict.new(c.case_id, kind))
		EventBus.case_resolved.disconnect(on_resolved)
		EventBus.passenger_departed.emit(c.case_id)
		if expected == VerdictKind.Kind.DENY and not results.is_empty() and results[0].procedure_missed == &"":
			assert_false(results[0].has_citation(), "REFUS NON MOTIVÉ suspendu (EV-02)")
			assert_true(results[0].correct)
			waived = true
	assert_true(waived, "un refus juste non motivé a été rencontré")
	h.dispose()
	# EV-04 : prime d'assiduité et aucun avertissement gratuit.
	var h2: DayHarness = _harness(8)
	var dc2: DayController = h2.controller
	dc2.builder.ctx.apply_changes([RuleChangeDef.modify(RuleChangeDef.MOD_CORRECT_BONUS, 2),
			RuleChangeDef.modify(RuleChangeDef.MOD_NO_FREE_CITATIONS, 1)], &"ev_04")
	var bonus_seen: bool = false
	var fine_seen: bool = false
	for i: int in 12:
		if not dc2.has_remaining_cases():
			break
		EventBus.next_case_requested.emit()
		if dc2.current_case != null:
			EventBus.passenger_arrived.emit(dc2.current_case.case_id)
		var c2: Case = dc2.current_case
		var expected2: VerdictKind.Kind = dc2.current_key.expected_verdict
		var wrong: VerdictKind.Kind = VerdictKind.Kind.DENY if expected2 == VerdictKind.Kind.APPROVE else VerdictKind.Kind.APPROVE
		var kind2: VerdictKind.Kind = expected2 if i % 2 == 0 else wrong
		var results2: Array[CaseResult] = []
		var on_resolved2: Callable = func(_id: StringName, result: CaseResult) -> void: results2.append(result)
		EventBus.case_resolved.connect(on_resolved2)
		EventBus.verdict_stamped.emit(Verdict.new(c2.case_id, kind2))
		EventBus.case_resolved.disconnect(on_resolved2)
		EventBus.passenger_departed.emit(c2.case_id)
		var r: CaseResult = results2[0]
		if r.scripted_id != &"":
			continue
		if r.correct:
			assert_eq(r.wage, dc2.day.credit_per_correct + 2 + (dc2.detain_bonus if r.verdict_kind == VerdictKind.Kind.DETAIN else 0))
			bonus_seen = true
		if r.has_citation():
			assert_gt(r.fine, 0, "inspection : la première citation coûte")
			fine_seen = true
	assert_true(bonus_seen and fine_seen)
	h2.teardown()


func test_class_b_plan_adds_free_citation_and_story_mode_same_calendar() -> void:
	var data: DataCatalog = CaseFactory.catalog()
	var def: StationEventsDef = _catalog()
	var b_day: int = -1
	var plan: StationEventPlan = null
	for campaign_seed: int in range(1, 400):
		var schedule: Dictionary[int, StationEventPlan] = StationEventService.schedule(campaign_seed, def, data.days)
		for day_number: int in schedule:
			if schedule[day_number].event.is_class_b():
				b_day = day_number
				plan = schedule[day_number]
				break
		if plan != null:
			break
	assert_not_null(plan)
	var base: int = data.get_day(b_day).free_citations_per_day
	# Avertissement en plus appliqué par `_begin` quand un plan de classe B est fourni.
	var dc: DayController = autofree(DayController.new())
	dc.apply_to_game_state = false
	dc.data = data
	add_child(dc)
	dc.set_process(false)
	var plans: Array[StationEventPlan] = [plan]
	dc.call(&"_begin", data.get_day(b_day), 7, [] as Array[StringName], {}, plans)
	assert_eq(dc.day.free_citations_per_day, base + 1, "+1 avertissement gratuit (classe B)")
	assert_eq(data.get_day(b_day).free_citations_per_day, base, "données intactes")


## D-136 : calendrier stratifié — nombre cible uniforme entre les bornes
## (3 à 6), un jour par strate, contraintes intactes, rattrapage d'une strate
## sans jour possible, bornes de données respectées.
func test_stratified_schedule_counts_and_strata() -> void:
	var data: DataCatalog = CaseFactory.catalog()
	var def: StationEventsDef = _catalog()
	assert_eq(def.min_per_campaign, 3)
	assert_eq(def.max_per_campaign, 6)
	var histogram: Dictionary[int, int] = {}
	var in_range: int = 0
	var runs: int = 400
	for campaign_seed: int in range(1, runs + 1):
		var schedule: Dictionary[int, StationEventPlan] = StationEventService.schedule(campaign_seed, def, data.days)
		histogram[schedule.size()] = histogram.get(schedule.size(), 0) + 1
		in_range += 1 if schedule.size() >= 3 and schedule.size() <= 6 else 0
		assert_lte(schedule.size(), def.max_per_campaign, "graine %d : au plus 6" % campaign_seed)
		var days: Array = schedule.keys()
		for i: int in range(1, days.size()):
			assert_gt(int(days[i]), int(days[i - 1]) + 1, "graine %d : jours croissants, jamais consécutifs" % campaign_seed)
	assert_gte(float(in_range) / runs, 0.95, "3 à 6 événements : %s" % histogram)
	for count: int in [3, 4, 5, 6]:
		assert_gt(histogram.get(count, 0), runs / 10, "%d événements : tiré (%s)" % [count, histogram])
	# Strates : consécutives, de tailles égales à un jour près, sans perte.
	var numbers: Array[int] = [4, 5, 6, 7, 8, 12, 13, 14, 15, 16, 18, 19, 22, 23, 25, 26, 27, 28]
	var strata: Array[Array] = StationEventService.strata(numbers, 4)
	assert_eq(strata.size(), 4)
	var flat: Array[int] = []
	for stratum: Array in strata:
		assert_between(stratum.size(), 4, 5)
		for value: Variant in stratum:
			flat.append(int(value))
	assert_eq(flat, numbers, "toutes les strates, dans l'ordre")
	assert_eq(StationEventService.strata(numbers, 0).size(), 0)
	assert_eq(StationEventService.strata([4, 5] as Array[int], 6).size(), 2, "pas plus de strates que de jours")
	# Bornes de données : 0 à 0 → aucun événement ; 2 jours seulement → rattrapage borné.
	var none: StationEventsDef = _catalog()
	none.min_per_campaign = 0
	none.max_per_campaign = 0
	assert_eq(StationEventService.schedule(3, none, data.days).size(), 0, "cible 0 : aucun événement")
	var few: StationEventsDef = _catalog()
	few.eligible_days = {6: StationEventsDef.CLASS_A | StationEventsDef.CLASS_B, 7: StationEventsDef.CLASS_A}
	for campaign_seed: int in range(1, 30):
		assert_eq(StationEventService.schedule(campaign_seed, few, data.days).size(), 1,
				"deux jours consécutifs : un seul événement")
