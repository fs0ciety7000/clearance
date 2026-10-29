## M11 — mode Récit (D-102) : le shift ne se termine pas à l'heure (il finit
## quand la file prévue est traitée), amendes à 0 ₵ mais citations comptées,
## passage Récit → Dur en cours de shift (jamais l'inverse) ; « Fermer le
## guichet » une fois le quota atteint ; profil simulé Récit : les 10 fins
## restent atteignables.
extends GutTest

const DayHarness := preload("res://tests/helpers/day_harness.gd")
const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const MAX_WAIT_SEC: float = 2.0
const VK := VerdictKind.Kind
## Jour à amendes (J4 : 2 citations gratuites, puis 5 ₵ / 10 ₵).
const FINE_DAY: int = 4

var data: DataCatalog = null
var h: DayHarness = null
var _saved_state: Dictionary = {}
var _expired: int = 0


func before_all() -> void:
	data = Gen.data()


func before_each() -> void:
	_saved_state = GameState.to_save_dict()
	_expired = 0
	EventBus.day_time_expired.connect(_on_expired)


func after_each() -> void:
	EventBus.day_time_expired.disconnect(_on_expired)
	if h != null:
		h.dispose()
		h = null
	if SaveService.as_int(_saved_state.get("current_day", 0)) >= 1:
		GameState.apply_save_dict(_saved_state)
	else:
		GameState.new_campaign(1)
		GameState.current_day = 0


func _on_expired() -> void:
	_expired += 1


func _start(day_number: int, difficulty: StringName, flags: Dictionary = {}) -> DayController:
	Campaign.new_game(data, 20_871_315, SaveService.DEFAULT_SLOT, difficulty)
	GameState.current_day = day_number
	for flag: Variant in flags:
		GameState.set_flag(StringName(str(flag)), flags[flag])
	h = DayHarness.new()
	h.setup(self, NullBooth.new(), day_number, 0, GameState.get_day_seed(), GameState.get_true_flags(),
			Campaign.memory_for_day(data))
	h.controller.close_intro()
	return h.controller


## Traite `count` passagers (ou toute la file si < 0) avec `policy(key)`.
func _process_cases(dc: DayController, policy: Callable, count: int = -1) -> void:
	var done: int = 0
	while dc.phase != DayPhase.Kind.SUMMARY and (count < 0 or done < count) and done < 40:
		done += 1
		EventBus.next_case_requested.emit()
		if dc.phase == DayPhase.Kind.SUMMARY:
			break
		var case_id: StringName = dc.current_case_id()
		await wait_until(func() -> bool: return h.events_for(case_id).has(&"documents_presented"), MAX_WAIT_SEC)
		h.investigate_current()
		EventBus.interrogation_requested.emit(InspectionSession.TOPIC_PURPOSE)
		h.stamp(policy.call(dc.current_key))
		await wait_until(func() -> bool: return dc.phase != DayPhase.Kind.DEPARTING, MAX_WAIT_SEC)


func _approve_all(_key: CaseKey) -> VerdictKind.Kind:
	return VK.APPROVE


func test_story_shift_ignores_the_clock_and_waives_fines() -> void:
	var dc: DayController = _start(FINE_DAY, GameState.DIFFICULTY_STORY)
	assert_true(dc.story_mode, "Récit lu dans GameState")
	assert_true(h.clock.untimed)
	var citations_before: int = GameState.citations
	await _process_cases(dc, _approve_all, 1)
	h.clock.advance(h.clock.duration_sec + 60.0)
	assert_eq(_expired, 0, "pas de day_time_expired en Récit")
	assert_eq(h.clock.current_minute(), DayDef.SHIFT_START_MIN + DayDef.SHIFT_LENGTH_MIN, "l'horloge s'affiche, arrêtée à 18:00")
	assert_true(h.clock.is_at_end())
	assert_ne(dc.phase, DayPhase.Kind.SUMMARY, "le shift continue après 18:00")
	await _process_cases(dc, _approve_all)
	assert_eq(dc.phase, DayPhase.Kind.SUMMARY, "fin quand la file prévue est traitée")
	var summary: DaySummary = h.summaries[0]
	assert_false(summary.time_expired)
	assert_eq(summary.get_processed_count(), summary.planned_cases, "toute la file")
	assert_gt(summary.get_citation_count(), 2, "citations émises au-delà des gratuites")
	assert_eq(summary.get_fine_total(), 0, "D-102 : amendes à 0 ₵")
	assert_eq(GameState.citations - citations_before, summary.get_citation_count(), "citations comptées")
	for result: CaseResult in summary.results:
		assert_eq(result.credits_delta, result.wage, "%s : net = salaire" % result.case_id)


func test_hard_shift_ends_at_the_hour_with_fines() -> void:
	var dc: DayController = _start(FINE_DAY, GameState.DIFFICULTY_HARD)
	assert_false(dc.story_mode)
	await _process_cases(dc, _approve_all, 5)
	h.clock.advance(h.clock.duration_sec + 60.0)
	assert_eq(_expired, 1)
	assert_eq(dc.phase, DayPhase.Kind.SUMMARY, "Dur : fin à l'heure")
	var summary: DaySummary = h.summaries[0]
	assert_true(summary.time_expired)
	assert_gt(summary.get_fine_total(), 0, "Dur : amendes")


func test_switch_story_to_hard_mid_shift_ends_an_overdue_shift() -> void:
	var dc: DayController = _start(FINE_DAY, GameState.DIFFICULTY_STORY)
	await _process_cases(dc, _approve_all, 2)
	h.clock.advance(h.clock.duration_sec + 60.0)
	assert_ne(dc.phase, DayPhase.Kind.SUMMARY)
	assert_true(GameState.set_difficulty(GameState.DIFFICULTY_STORY), "déjà en Récit : sans effet")
	assert_true(GameState.set_difficulty(GameState.DIFFICULTY_HARD), "Récit → Dur")
	assert_false(dc.story_mode)
	assert_eq(_expired, 1, "horloge au bout : expiration immédiate")
	assert_eq(dc.phase, DayPhase.Kind.SUMMARY)
	assert_false(GameState.set_difficulty(GameState.DIFFICULTY_STORY), "Dur → Récit : jamais")
	assert_eq(GameState.difficulty, GameState.DIFFICULTY_HARD)


func test_close_booth_once_the_quota_is_full() -> void:
	var dc: DayController = _start(11, GameState.DIFFICULTY_STORY, {"act2_started": true})
	assert_true(dc.quota.is_active(), "J11 : quota respiratoire")
	assert_false(dc.can_close_booth(), "quota non atteint")
	assert_false(dc.close_booth())
	var guard: int = 0
	while not dc.quota.is_full() and dc.phase != DayPhase.Kind.SUMMARY and guard < 30:
		guard += 1
		await _process_cases(dc, _approve_all, 1)
	assert_true(dc.quota.is_full(), "quota atteint")
	assert_true(dc.can_close_booth())
	assert_true(dc.close_booth(), "Fermer le guichet")
	assert_eq(dc.phase, DayPhase.Kind.SUMMARY)
	assert_lt(h.summaries[0].get_processed_count(), h.summaries[0].planned_cases, "file non terminée")


func test_story_simulation_waives_fines_and_keeps_citations() -> void:
	var hard: Array[Dictionary] = BalanceSimulator.run_campaign(data, 3, 0.6, BalanceSimulator.Spending.REASONED, 6,
			SimProfile.preset(&"default", 0.6))
	var story_profile: SimProfile = SimProfile.story(&"default", 0.6)
	assert_true(story_profile.story_mode)
	assert_eq(SimProfile.preset(&"story_luciole").name, &"story_luciole")
	assert_true(SimProfile.preset(&"story_luciole").answer_password, "préréglage de base conservé")
	var story: Array[Dictionary] = BalanceSimulator.run_campaign(data, 3, 0.6, BalanceSimulator.Spending.REASONED, 6,
			story_profile)
	var hard_income: int = 0
	var story_income: int = 0
	for row: Dictionary in hard:
		hard_income += SaveService.as_int(row["income"])
	for row: Dictionary in story:
		story_income += SaveService.as_int(row["income"])
	assert_gt(story_income, hard_income, "Récit : pas d'amende, revenu supérieur")
	var summary: DaySummary = DaySimulator.play_day(data, FINE_DAY, 77, story_profile, {}, {}, SeededRng.new(5))
	assert_gt(summary.get_citation_count(), 0)
	assert_eq(summary.get_fine_total(), 0)


## Fin attendue de chaque profil du simulateur, joué en mode Récit (D-102 :
## « toutes les fins accessibles »).
const STORY_ENDING_PROFILES: Dictionary[StringName, StringName] = {
	&"mercenary3": EndingService.F1_ARRESTED, &"evicted": EndingService.F2_REASSIGNED,
	&"negligent": EndingService.F3_FAMILY_LOST, &"loyal": EndingService.F4_GLORY, &"luciole": EndingService.F5_AIR,
	&"drift": EndingService.F6_DRIFT, &"default": EndingService.F7_REOPENS, &"temoin": EndingService.F8_REGISTRE,
	&"solidaire": EndingService.F9_STRIKE, &"passeur": EndingService.F10_PONT,
}


func test_every_ending_is_reachable_in_story_mode() -> void:
	var reached: Array[StringName] = []
	for preset: StringName in STORY_ENDING_PROFILES:
		var wanted: StringName = STORY_ENDING_PROFILES[preset]
		for campaign_seed: int in range(1, 13):
			var rows: Array[Dictionary] = BalanceSimulator.run_campaign(data, campaign_seed, 0.95,
					BalanceSimulator.Spending.REASONED, -1, SimProfile.story(preset, 0.95))
			if rows[rows.size() - 1].get("ending", &"") == wanted:
				reached.append(wanted)
				break
		assert_true(reached.has(wanted), "Récit : %s → %s" % [preset, wanted])
	assert_eq(reached.size(), EndingService.ALL_ENDINGS.size(), "Récit : F1 → F10")
