## M8 — Acte II de bout en bout sans UI ; M9 : la campagne réelle va au J30
## (`DayController` + `NullBooth`, soirées par `Campaign` avec choix par
## défaut, pivot du J20 non terminal, D-086) pour trois bots ; signaux du
## contrat UI M8 (`quota_changed`, `revocations_published`,
## `scanner_suggested`, annonces conditionnelles) ; chaque fin F1–F10 atteinte
## par un profil du simulateur (docs/ACT3.md §6.4) ; déterminisme.
extends GutTest

const SaveChecks := preload("res://tests/helpers/save_checks.gd")
const DayHarness := preload("res://tests/helpers/day_harness.gd")
const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const DIR: String = "user://test_act2_campaign_saves"
const MAX_WAIT_SEC: float = 2.0
const CAMPAIGN_SEED: int = 20_871_315
const VK := VerdictKind.Kind

var h: DayHarness = null
var data: DataCatalog = null
var _saved_state: Dictionary = {}
var _announcements: Array[String] = []
var _quota: Array[Vector2i] = []
var _revoked: Array[RevokedEntry] = []
var _scanner: Array[Array] = []


func before_all() -> void:
	data = Gen.data()


func before_each() -> void:
	_saved_state = GameState.to_save_dict()
	Campaign.new_game(data, CAMPAIGN_SEED)
	SaveService.delete_slot(1, DIR)
	_announcements.clear()
	_quota.clear()
	_revoked.clear()
	_scanner.clear()
	EventBus.hall_announced.connect(_on_announced)
	EventBus.quota_changed.connect(_on_quota)
	EventBus.revocations_published.connect(_on_revoked)
	EventBus.scanner_suggested.connect(_on_scanner)


func after_each() -> void:
	EventBus.hall_announced.disconnect(_on_announced)
	EventBus.quota_changed.disconnect(_on_quota)
	EventBus.revocations_published.disconnect(_on_revoked)
	EventBus.scanner_suggested.disconnect(_on_scanner)
	if h != null:
		h.dispose()
		h = null
	SaveService.delete_slot(1, DIR)
	if SaveService.as_int(_saved_state.get("current_day", 0)) >= 1:
		GameState.apply_save_dict(_saved_state)
	else:
		GameState.new_campaign(1)
		GameState.current_day = 0


func _on_announced(key: String) -> void:
	_announcements.append(key)


func _on_quota(used: int, maximum: int) -> void:
	_quota.append(Vector2i(used, maximum))


func _on_revoked(entries: Array[RevokedEntry]) -> void:
	_revoked = entries.duplicate()


func _on_scanner(case_id: StringName, links: Array[Discrepancy], source: StringName) -> void:
	_scanner.append([case_id, links, source])


func _play_day(policy: Callable) -> DaySummary:
	if h != null:
		h.dispose()
	h = DayHarness.new()
	h.setup(self, NullBooth.new(), GameState.current_day, 0, GameState.get_day_seed(), GameState.get_true_flags(),
			Campaign.memory_for_day(data))
	var dc: DayController = h.controller
	dc.close_intro()
	var guard: int = 0
	while dc.phase != DayPhase.Kind.SUMMARY and guard < 40:
		guard += 1
		EventBus.next_case_requested.emit()
		if dc.phase == DayPhase.Kind.SUMMARY:
			break
		var case_id: StringName = dc.current_case_id()
		await wait_until(func() -> bool: return h.events_for(case_id).has(&"documents_presented"), MAX_WAIT_SEC)
		h.investigate_current()
		EventBus.interrogation_requested.emit(InspectionSession.TOPIC_PURPOSE)
		h.stamp(policy.call(dc.current_case, dc.current_key))
		await wait_until(func() -> bool: return dc.phase != DayPhase.Kind.DEPARTING, MAX_WAIT_SEC)
	assert_eq(h.summaries.size(), 1, "day_ended émis une fois (J%d)" % GameState.current_day)
	return h.summaries[0]


func _evening(summary: DaySummary) -> StringName:
	var events: Array[EveningEvent] = Campaign.prepare_events(data)
	var lines: Array[ExpenseLine] = Campaign.prepare_evening(data, events)
	var report: EveningReport = Campaign.preview_evening(data, lines, events)
	return Campaign.close_evening(data, summary, report, 1, DIR)


## Campagne complète J1–J30 ; renvoie la fin.
func _play_campaign(policy: Callable) -> StringName:
	for day_number: int in range(1, 31):
		assert_eq(GameState.current_day, day_number)
		var summary: DaySummary = await _play_day(policy)
		if not Campaign.has_evening(data):
			assert_eq(day_number, 30, "seul le J30 n'a pas de soirée")
			return Campaign.close_final_day(data, summary, 1, DIR)
		var ending: StringName = _evening(summary)
		if ending != EveningReport.ENDING_NONE:
			return ending
	return &""


func _assert_ended(ending: StringName) -> void:
	assert_true(EndingService.ALL_ENDINGS.has(ending), "fin connue : %s" % ending)
	SaveChecks.assert_archived(self, 1, DIR, ending, String(ending))
	var epilogue: Dictionary = Campaign.epilogue(ending)
	assert_gt((epilogue.get("lines", PackedStringArray()) as PackedStringArray).size(), 0)


func test_conscientious_agent_plays_thirty_days() -> void:
	# Agent consciencieux : verdict attendu ; quota atteint, un passager en règle
	# compté au quota est refusé (refus juste, D-077) plutôt qu'imputé (M13 : les
	# tirages des jours changent, les entrées imputées font monter la suspicion).
	var ending: StringName = await _play_campaign(func(c: Case, key: CaseKey) -> VerdictKind.Kind:
		var quota: QuotaTracker = h.controller.quota
		if key.expected_verdict == VerdictKind.Kind.APPROVE and quota.is_active() and quota.is_full() and quota.counts(c):
			return VerdictKind.Kind.DENY
		return key.expected_verdict)
	_assert_ended(ending)
	assert_true(Campaign.is_act3(), "pivot du J20 franchi")
	assert_eq(GameState.day_history.size(), 30, "jusqu'au J30 (fin %s)" % ending)
	assert_ne(ending, EndingService.F1_ARRESTED, "aucun soupçon : pas d'arrestation (suspicion %s, aveux %s, enquête %s)" % [
			GameState.narrative_flags.get(&"suspicion", 0), GameState.narrative_flags.get(&"aveux", 0),
			GameState.narrative_flags.get(&"enquete_cible", false)])
	assert_true(_announcements.has("hall_j17_review"))


func test_cautious_agent_plays_to_an_ending() -> void:
	var ending: StringName = await _play_campaign(func(_c: Case, key: CaseKey) -> VerdictKind.Kind:
		return VK.DENY if key.expected_verdict == VK.DETAIN else key.expected_verdict)
	_assert_ended(ending)
	assert_false(GameState.has_flag(&"final2_detained"))


func test_approve_all_bot_plays_to_an_ending() -> void:
	var ending: StringName = await _play_campaign(func(_c: Case, _key: CaseKey) -> VerdictKind.Kind: return VK.APPROVE)
	_assert_ended(ending)


func test_quota_signals_in_a_real_shift() -> void:
	GameState.current_day = 11
	GameState.set_flag(EndingService.FLAG_ACT2, true)
	var summary: DaySummary = await _play_day(func(_c: Case, _key: CaseKey) -> VerdictKind.Kind: return VK.APPROVE)
	assert_gt(_quota.size(), 1)
	assert_eq(_quota[0], Vector2i(0, 5), "compteur initial")
	assert_eq(_quota[_quota.size() - 1].y, 5)
	assert_gt(_quota[_quota.size() - 1].x, 5, "tout approuver : quota dépassé")
	assert_true(_announcements.has(DayController.HALL_QUOTA_FULL))
	assert_gt(summary.get_overrun_count(), 0)
	for result: CaseResult in summary.results:
		if result.quota_overrun:
			assert_eq(result.wage, 0, "D-077 : 0 ₵ au-delà du quota")


func test_revocations_and_scanner_in_a_real_shift() -> void:
	GameState.current_day = 17
	GameState.set_flag(EndingService.FLAG_ACT2, true)
	GameState.set_flag(&"scanner_luciole", true)
	await _play_day(func(_c: Case, key: CaseKey) -> VerdictKind.Kind: return key.expected_verdict)
	assert_gt(_revoked.size(), 3, "liste de révocations publiée")
	assert_eq(_scanner.size(), h.summaries[0].results.size(), "une suggestion par dossier")
	for entry: Array in _scanner:
		assert_eq(entry[2], PartialScanner.SOURCE_LUCIOLE)
		for link: Discrepancy in entry[1]:
			assert_true(link.confirmed, "scanner : zéro faux positif")


func test_strike_ends_the_last_shift_early() -> void:
	GameState.current_day = 20
	GameState.set_flag(EndingService.FLAG_ACT2, true)
	GameState.set_flag(&"strike_joined", true)
	GameState.set_flag(&"registre_sent", true)
	var summary: DaySummary = await _play_day(func(_c: Case, key: CaseKey) -> VerdictKind.Kind: return key.expected_verdict)
	assert_true(_announcements.has("hall_j20_registre"))
	assert_true(_announcements.has("hall_j20_strike"))
	assert_lt(summary.get_processed_count(), data.get_day(20).passenger_count, "lumières coupées")


## Fin attendue de chaque profil du simulateur (docs/ACT3.md §6.4, campagne J1–J30).
const ENDING_PROFILES: Dictionary[StringName, StringName] = {
	&"mercenary3": EndingService.F1_ARRESTED, &"evicted": EndingService.F2_REASSIGNED,
	&"negligent": EndingService.F3_FAMILY_LOST, &"loyal": EndingService.F4_GLORY, &"luciole": EndingService.F5_AIR,
	&"drift": EndingService.F6_DRIFT, &"default": EndingService.F7_REOPENS, &"temoin": EndingService.F8_REGISTRE,
	&"solidaire": EndingService.F9_STRIKE, &"passeur": EndingService.F10_PONT,
}


func test_every_ending_is_reachable() -> void:
	var reached: Array[StringName] = []
	for preset: StringName in ENDING_PROFILES:
		var wanted: StringName = ENDING_PROFILES[preset]
		for campaign_seed: int in range(1, 9):
			var rows: Array[Dictionary] = BalanceSimulator.run_campaign(data, campaign_seed, 0.95,
					BalanceSimulator.Spending.REASONED, -1, SimProfile.preset(preset, 0.95))
			if rows[rows.size() - 1].get("ending", &"") == wanted:
				reached.append(wanted)
				break
		assert_true(reached.has(wanted), "%s → %s" % [preset, wanted])
	assert_eq(reached.size(), EndingService.ALL_ENDINGS.size(), "F1 → F10")


func test_full_simulation_is_deterministic() -> void:
	for preset: StringName in [&"mercenary2", &"solidaire"]:
		var a: Array[Dictionary] = BalanceSimulator.run_campaign(data, 31, 0.9, BalanceSimulator.Spending.REASONED, -1,
				SimProfile.preset(preset, 0.9))
		var b: Array[Dictionary] = BalanceSimulator.run_campaign(data, 31, 0.9, BalanceSimulator.Spending.REASONED, -1,
				SimProfile.preset(preset, 0.9))
		assert_eq(a, b, String(preset))
