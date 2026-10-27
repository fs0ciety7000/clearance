## Intégration M5 (ARCHITECTURE §12, §14) : *vertical slice* de 3 jours sans UI.
## Jours enchaînés (shift → bilan → soirée → sauvegarde → jour suivant) avec
## `NullBooth` et `SilentBooth`, un bot parfait (preuves, visières) et un bot
## qui approuve tout ; économie et citations recalculées indépendamment à
## partir des clés (GDD §5.1, §5.2, §5.3) ; aller-retour de sauvegarde.
extends GutTest

const DayHarness := preload("res://tests/helpers/day_harness.gd")
const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const DIR: String = "user://test_campaign_saves"
const MAX_WAIT_SEC: float = 2.0
const CAMPAIGN_SEED: int = 20_871_315

var h: DayHarness = null
var data: DataCatalog = null
## Par cas joué : [CaseKey, visage masqué au moment du tampon (bool)].
var played: Array[Array] = []
var _saved_state: Dictionary = {}


func before_all() -> void:
	data = Gen.data()


func before_each() -> void:
	_saved_state = GameState.to_save_dict()
	Campaign.new_game(data, CAMPAIGN_SEED)
	SaveService.delete(0, DIR)


func after_each() -> void:
	if h != null:
		h.dispose()
		h = null
	SaveService.delete(0, DIR)
	if SaveService.as_int(_saved_state.get("current_day", 0)) >= 1:
		GameState.apply_save_dict(_saved_state)
	else:
		GameState.new_campaign(1)
		GameState.current_day = 0


## Joue le jour courant de la campagne. `policy(key) -> VerdictKind.Kind`.
func _play_current_day(booth: Node, policy: Callable, investigate: bool) -> DaySummary:
	if h != null:
		h.dispose()
	h = DayHarness.new()
	played.clear()
	h.setup(self, booth, GameState.current_day, 0, GameState.get_day_seed(), GameState.get_true_flags())
	var dc: DayController = h.controller
	dc.close_intro()
	var silent: bool = booth is SilentBooth
	var guard: int = 0
	while dc.phase != DayPhase.Kind.SUMMARY and guard < 64:
		guard += 1
		EventBus.next_case_requested.emit()
		if silent:
			dc.advance(dc.arrive_timeout_sec + 0.1)
			dc.advance(dc.present_timeout_sec + 0.1)
		else:
			var case_id: StringName = dc.current_case_id()
			await wait_until(func() -> bool: return h.events_for(case_id).has(&"documents_presented"), MAX_WAIT_SEC)
		assert_eq(dc.phase, DayPhase.Kind.INSPECTING)
		if investigate:
			h.investigate_current()
		played.append([dc.current_key, dc.current_case.passenger_presented.appearance.is_face_covered()])
		var kind: VerdictKind.Kind = policy.call(dc.current_key)
		h.stamp(kind)
		if silent:
			dc.advance(dc.depart_timeout_sec + 0.1)
		else:
			await wait_until(func() -> bool: return dc.phase != DayPhase.Kind.DEPARTING, MAX_WAIT_SEC)
	assert_eq(h.summaries.size(), 1, "day_ended émis une fois (J%d)" % GameState.current_day)
	return h.summaries[0]


## Soirée par défaut (présélection), sauvegarde ; renvoie la fin éventuelle.
func _evening(summary: DaySummary) -> Array:
	var lines: Array[ExpenseLine] = Campaign.prepare_evening(data)
	var report: EveningReport = Campaign.preview_evening(data, lines)
	var before: int = GameState.credits
	var day_before: int = GameState.current_day
	var ending: StringName = Campaign.close_evening(data, summary, report, 0, DIR)
	assert_eq(GameState.credits, before - report.spent, "solde débité des dépenses")
	assert_eq(GameState.current_day, day_before + 1)
	assert_eq(GameState.household.to_dict(), report.household.to_dict())
	return [ending, report]


func _expected_approve_all(day_number: int) -> Dictionary:
	var day: DayDef = data.get_day(day_number)
	var wage: int = 0
	var citations: int = 0
	var fines: int = 0
	var face_rule: bool = day.rule_set.has_rule(&"r_face_uncovered")
	for entry: Array in played:
		var key: CaseKey = entry[0]
		var masked: bool = entry[1]
		var cited: bool = key.expected_verdict != VerdictKind.Kind.APPROVE or (masked and face_rule)
		if cited:
			citations += 1
			fines += [0, 0, 5][mini(citations - 1, 2)] if citations <= 3 else 10
		else:
			wage += day.credit_per_correct
	return {"wage": wage, "citations": citations, "fines": fines}


func test_perfect_bot_three_days_null_booth() -> void:
	var expected_totals: Array[int] = []
	assert_eq(GameState.credits, data.get_economy().starting_credits, "avance du Consortium (D-047)")
	for day_number: int in [1, 2, 3]:
		assert_eq(GameState.current_day, day_number)
		var credits_before: int = GameState.credits
		var summary: DaySummary = await _play_current_day(NullBooth.new(), func(key: CaseKey) -> VerdictKind.Kind: return key.expected_verdict, true)
		var day: DayDef = data.get_day(day_number)
		assert_eq(summary.get_processed_count(), day.passenger_count)
		assert_eq(summary.get_correct_count(), day.passenger_count, "J%d : tout juste, preuves comprises" % day_number)
		assert_eq(summary.get_citation_count(), 0)
		assert_eq(summary.get_wage_total(), 5 * day.passenger_count, "GDD §5.1 : 5 ₵ par cas correct")
		assert_eq(GameState.credits, credits_before + summary.get_net(), "crédits appliqués au fil du shift")
		expected_totals.append(5 * day.passenger_count)
		var result: Array = _evening(summary)
		var report: EveningReport = result[1]
		# M7 : la campagne continue après le J3 (J4–J10, `test_m7_campaign.gd`).
		assert_eq(result[0], EveningReport.ENDING_NONE)
		assert_true(SaveService.has_save(0, DIR), "sauvegarde automatique entre les jours")
		assert_eq(report.ending, EveningReport.ENDING_NONE, "un joueur parfait survit (GDD §5.3)")
		for line: ExpenseLine in report.lines:
			assert_true(line.paid, "J%d : un joueur parfait paie tout (%s, D-047)" % [day_number, line.id])
		for member: Household.Member in report.household.members:
			assert_eq(member.state_key(), "hh_state_well", "J%d : %s en bonne santé" % [day_number, member.id])
	assert_eq(expected_totals, [40, 50, 55] as Array[int])
	assert_eq(GameState.score_total, 145)
	assert_eq(GameState.day_history.size(), 3)
	assert_eq(GameState.get_flag(&"met_mira"), true, "SC-04 rencontré")
	assert_eq(GameState.get_flag(&"lucioles_contact"), true, "SC-05 rencontré")
	assert_false(GameState.has_flag(&"lucioles_trust"), "SC-05 refusé : pas de confiance gagnée")
	assert_eq(GameState.get_flag(&"sc02_turned_away"), true)
	assert_almost_eq(Campaign.compliance(), 1.0, 0.001)


func test_approve_all_bot_three_days_economy_and_citations() -> void:
	var ending: StringName = &""
	for day_number: int in [1, 2, 3]:
		var credits_before: int = GameState.credits
		var summary: DaySummary = await _play_current_day(NullBooth.new(), func(_key: CaseKey) -> VerdictKind.Kind: return VerdictKind.Kind.APPROVE, false)
		var expected: Dictionary = _expected_approve_all(day_number)
		assert_eq(summary.get_wage_total(), expected["wage"], "J%d salaire" % day_number)
		assert_eq(summary.get_citation_count(), expected["citations"], "J%d citations" % day_number)
		assert_eq(summary.get_fine_total(), expected["fines"], "J%d amendes (2 avertissements puis 5, 10…)" % day_number)
		var wage: int = expected["wage"]
		var fines: int = expected["fines"]
		assert_eq(GameState.credits, credits_before + wage - fines)
		assert_gt(summary.get_citation_count(), 0, "des fraudes passent")
		for result: CaseResult in summary.results:
			if result.citation_reason_key == ScoringService.CIT_IRREGULAR_ENTRY:
				assert_false(result.missed_violations.is_empty(), "violations révélées après verdict")
		if day_number == 1:
			assert_eq(GameState.get_flag(&"sc02_mercy"), true, "SC-02 approuvée : drapeau de clémence")
			assert_eq(GameState.get_flag(&"suspicion"), 1, "D-052 : approuver SC-02 = suspicion +1")
		if day_number == 3:
			assert_eq(GameState.get_flag(&"lucioles_trust"), 1, "SC-05 approuvé : confiance des Lucioles +1")
		var result_pair: Array = _evening(summary)
		ending = result_pair[0]
		if ending != EveningReport.ENDING_NONE and ending != Campaign.ENDING_DEMO_COMPLETE:
			break
	# M7 : J1–J3 ne terminent plus la campagne ; une fin anticipée efface la sauvegarde.
	if ending != EveningReport.ENDING_NONE:
		assert_false(SaveService.has_save(0, DIR), "plus de « Continuer » après une fin")
	else:
		assert_true(SaveService.has_save(0, DIR), "la campagne continue au J4")


func test_save_load_roundtrip_between_days() -> void:
	var summary: DaySummary = await _play_current_day(NullBooth.new(), func(key: CaseKey) -> VerdictKind.Kind: return key.expected_verdict, true)
	_evening(summary)
	var snapshot: Dictionary = GameState.to_save_dict()
	assert_true(SaveService.has_save(0, DIR))
	GameState.new_campaign(1)
	assert_ne(GameState.to_save_dict(), snapshot)
	assert_true(GameState.load_from_slot(0, DIR), "Continuer")
	assert_eq(GameState.to_save_dict(), snapshot, "état restauré à l'identique")
	assert_eq(GameState.current_day, 2)
	# Le jour 2 rejoué après chargement est le même que sans interruption.
	var day2: DaySummary = await _play_current_day(NullBooth.new(), func(key: CaseKey) -> VerdictKind.Kind: return key.expected_verdict, true)
	assert_eq(day2.get_correct_count(), data.get_day(2).passenger_count)


func test_silent_booth_three_days() -> void:
	for day_number: int in [1, 2, 3]:
		var summary: DaySummary = await _play_current_day(SilentBooth.new(), func(key: CaseKey) -> VerdictKind.Kind: return key.expected_verdict, true)
		assert_eq(summary.get_processed_count(), data.get_day(day_number).passenger_count)
		assert_eq(summary.get_correct_count(), summary.get_processed_count())
		assert_eq(h.controller.timeouts_fired, 3 * summary.get_processed_count())
		_evening(summary)
	assert_eq(GameState.current_day, 4)


func test_unprocessed_cases_when_time_runs_out() -> void:
	h = DayHarness.new()
	h.setup(self, NullBooth.new(), 1, 0, GameState.get_day_seed())
	h.controller.close_intro()
	EventBus.next_case_requested.emit()
	await wait_until(func() -> bool: return h.controller.phase == DayPhase.Kind.INSPECTING, MAX_WAIT_SEC)
	h.clock.advance(h.controller.day.duration_sec + 1.0)
	h.stamp(VerdictKind.Kind.APPROVE)
	await wait_until(func() -> bool: return h.controller.phase == DayPhase.Kind.SUMMARY, MAX_WAIT_SEC)
	var summary: DaySummary = h.summaries[0]
	assert_eq(summary.get_unprocessed_count(), h.controller.day.passenger_count - 1, "manque à gagner, sans citation")
	assert_eq(summary.get_citation_count(), 0)
