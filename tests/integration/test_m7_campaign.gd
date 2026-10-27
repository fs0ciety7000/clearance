## M7 — campagne J1–J10 de bout en bout sans UI (`DayController` +
## `NullBooth`, soirées par `Campaign` avec choix par défaut, J10 sans soirée
## → fin) pour trois bots ; objets glissés dans un vrai shift (signaux
## `item_slipped` / `item_decision_requested` / `item_decided`, refus
## automatique) ; fins F1–F7 atteignables par des profils simulés
## (`BalanceSimulator` + `SimProfile`) ; déterminisme.
extends GutTest

const DayHarness := preload("res://tests/helpers/day_harness.gd")
const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const DIR: String = "user://test_m7_campaign_saves"
const MAX_WAIT_SEC: float = 2.0
const CAMPAIGN_SEED: int = 20_871_315
const VK := VerdictKind.Kind

var h: DayHarness = null
var data: DataCatalog = null
var _saved_state: Dictionary = {}
var _slipped: Array[SlippedItem] = []
var _decided: Array[Array] = []
var _wanted: Array[WantedNotice] = []
var _announcements: Array[String] = []


func before_all() -> void:
	data = Gen.data()


func before_each() -> void:
	_saved_state = GameState.to_save_dict()
	Campaign.new_game(data, CAMPAIGN_SEED)
	SaveService.delete(0, DIR)
	_slipped.clear()
	_decided.clear()
	_wanted.clear()
	_announcements.clear()
	EventBus.item_slipped.connect(_on_item_slipped)
	EventBus.item_decided.connect(_on_item_decided)
	EventBus.wanted_notices_published.connect(_on_wanted)
	EventBus.hall_announced.connect(_on_announced)


func after_each() -> void:
	EventBus.item_slipped.disconnect(_on_item_slipped)
	EventBus.item_decided.disconnect(_on_item_decided)
	EventBus.wanted_notices_published.disconnect(_on_wanted)
	EventBus.hall_announced.disconnect(_on_announced)
	if h != null:
		h.dispose()
		h = null
	SaveService.delete(0, DIR)
	if SaveService.as_int(_saved_state.get("current_day", 0)) >= 1:
		GameState.apply_save_dict(_saved_state)
	else:
		GameState.new_campaign(1)
		GameState.current_day = 0


func _on_item_slipped(item: SlippedItem) -> void:
	_slipped.append(item)


func _on_item_decided(item: SlippedItem, decision: SlippedItem.Decision) -> void:
	_decided.append([item.id, decision])


func _on_wanted(notices: Array[WantedNotice]) -> void:
	_wanted = notices.duplicate()


func _on_announced(key: String) -> void:
	_announcements.append(key)


## Joue le jour courant. `policy(case, key) -> VerdictKind.Kind` ;
## `decide(case, item) -> SlippedItem.Decision` (NONE = laisser le défaut).
func _play_day(policy: Callable, decide: Callable = Callable()) -> DaySummary:
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
		var case_id: StringName = dc.current_case_id()
		await wait_until(func() -> bool: return h.events_for(case_id).has(&"documents_presented"), MAX_WAIT_SEC)
		h.investigate_current()
		_investigate_rule_pairs()
		EventBus.interrogation_requested.emit(InspectionSession.TOPIC_PURPOSE)
		if decide.is_valid():
			for item: SlippedItem in dc.current_case.slipped_items:
				var decision: SlippedItem.Decision = decide.call(dc.current_case, item)
				if decision != SlippedItem.Decision.NONE:
					EventBus.item_decision_requested.emit(item.id, decision)
		var verdict: VerdictKind.Kind = policy.call(dc.current_case, dc.current_key)
		h.stamp(verdict)
		await wait_until(func() -> bool: return dc.phase != DayPhase.Kind.DEPARTING, MAX_WAIT_SEC)
	assert_eq(h.summaries.size(), 1, "day_ended émis une fois (J%d)" % GameState.current_day)
	return h.summaries[0]


## Preuves « champ ↔ règle » (premier ↔ dernier champ d'une violation).
func _investigate_rule_pairs() -> void:
	for violation: Violation in h.controller.current_key.expected_violations:
		if violation.refs.size() > 2:
			EventBus.discrepancy_check_requested.emit(violation.refs[0], violation.refs[violation.refs.size() - 1])


## Soirée par défaut (événements : choix par défaut) ; renvoie la fin éventuelle.
func _evening(summary: DaySummary) -> StringName:
	var events: Array[EveningEvent] = Campaign.prepare_events(data)
	var lines: Array[ExpenseLine] = Campaign.prepare_evening(data, events)
	var report: EveningReport = Campaign.preview_evening(data, lines, events)
	var before: int = GameState.credits
	var ending: StringName = Campaign.close_evening(data, summary, report, 0, DIR)
	assert_eq(GameState.credits, before - report.spent + report.gained)
	return ending


## Campagne complète ; renvoie la fin (anticipée ou du J10).
func _play_campaign(policy: Callable, decide: Callable = Callable()) -> StringName:
	for day_number: int in range(1, 11):
		assert_eq(GameState.current_day, day_number)
		var summary: DaySummary = await _play_day(policy, decide)
		if not Campaign.has_evening(data):
			return Campaign.close_final_day(data, summary, 0, DIR)
		var ending: StringName = _evening(summary)
		if ending != EveningReport.ENDING_NONE:
			return ending
		assert_true(SaveService.has_save(0, DIR), "sauvegarde automatique (J%d)" % day_number)
	return &""


func test_conscientious_agent_reaches_glory() -> void:
	var ending: StringName = await _play_campaign(func(_c: Case, key: CaseKey) -> VerdictKind.Kind: return key.expected_verdict)
	assert_eq(ending, EndingService.F4_GLORY, "conformité 100 %, détentions, loyauté ≥ 3")
	assert_almost_eq(Campaign.compliance(), 1.0, 0.001)
	assert_eq(GameState.get_flag(&"final_detained"), true)
	assert_eq(GameState.get_flag(&"inspector_test_passed"), true, "SC-12 refusé, enveloppe rendue d'office")
	assert_eq(GameState.get_flag(&"ending"), String(EndingService.F4_GLORY))
	assert_false(SaveService.has_save(0, DIR), "D-041 : la fin efface la sauvegarde")
	assert_eq(GameState.day_history.size(), 10)
	assert_eq(_wanted.size(), 3, "avis de recherche publiés au J10")
	assert_true(_announcements.has("hall_j7_okonkwo_citation"))
	assert_true(GameState.case_memory.has("sc_22"), "mémoire des passagers")
	var epilogue: Dictionary = Campaign.epilogue(ending)
	assert_eq(epilogue["title_key"], "end_f4_title")


func test_cautious_agent_never_detains_and_the_counter_reopens() -> void:
	var never_detain: Callable = func(_c: Case, key: CaseKey) -> VerdictKind.Kind:
		return VK.DENY if key.expected_verdict == VK.DETAIN else key.expected_verdict
	var ending: StringName = await _play_campaign(never_detain)
	assert_eq(ending, EndingService.F7_REOPENS)
	assert_eq(GameState.get_flag(&"final_denied"), true)
	assert_false(GameState.has_flag(&"final_detained"))


func test_approve_all_bot_ends_the_campaign_cleanly() -> void:
	var ending: StringName = await _play_campaign(func(_c: Case, _key: CaseKey) -> VerdictKind.Kind: return VK.APPROVE)
	assert_true(EndingService.ALL_ENDINGS.has(ending), "fin connue : %s" % ending)
	assert_false(SaveService.has_save(0, DIR))
	assert_eq(GameState.get_flag(&"ending"), String(ending))


func test_slipped_items_in_a_real_shift() -> void:
	GameState.current_day = 4
	GameState.set_flag(&"sc02_turned_away", true)
	var keep_valcourt: Callable = func(c: Case, _item: SlippedItem) -> SlippedItem.Decision:
		return SlippedItem.Decision.KEEP if c.dialogue_tags.has(&"sc07_valcourt") else SlippedItem.Decision.NONE
	var credits_before: int = GameState.credits
	var summary: DaySummary = await _play_day(func(_c: Case, key: CaseKey) -> VerdictKind.Kind: return key.expected_verdict,
			keep_valcourt)
	assert_gt(_slipped.size(), 0, "item_slipped émis avec les documents")
	var valcourt: SlippedItem = null
	for item: SlippedItem in _slipped:
		if item.amount == 20 and item.case_id == &"d04_c04":
			valcourt = item
	assert_not_null(valcourt)
	assert_true(_decided.has([valcourt.id, SlippedItem.Decision.KEEP]))
	assert_eq(summary.get_bribe_total(), 20, "seule l'enveloppe de Valcourt est gardée")
	assert_eq(GameState.get_flag(&"sc07_bribe_kept"), true)
	assert_eq(GameState.get_flag(&"sc07_complaint"), true, "refus + enveloppe gardée = plainte")
	assert_eq(GameState.get_flag(&"suspicion"), 2)
	assert_eq(GameState.credits, credits_before + summary.get_total_income())
	# Toute enveloppe générée non tranchée est rendue d'office au tampon.
	for item: SlippedItem in _slipped:
		if item != valcourt:
			assert_true(_decided.has([item.id, SlippedItem.Decision.RETURN]), String(item.id))


func test_detain_is_read_as_deny_before_day_seven() -> void:
	GameState.current_day = 5
	var summary: DaySummary = await _play_day(func(_c: Case, key: CaseKey) -> VerdictKind.Kind:
		return VK.DETAIN if key.expected_verdict != VK.APPROVE else VK.APPROVE)
	for result: CaseResult in summary.results:
		assert_ne(result.verdict_kind, VK.DETAIN, "tampon DÉTENTION indisponible au J5")


func test_simulated_profiles_reach_every_ending() -> void:
	var expected: Dictionary[StringName, Array] = {
		EndingService.F1_ARRESTED: [&"mercenary", 0.95],
		EndingService.F2_REASSIGNED: [&"evicted", 0.95],
		EndingService.F3_FAMILY_LOST: [&"negligent", 0.95],
		EndingService.F4_GLORY: [&"default", 1.0],
		EndingService.F5_AIR: [&"luciole", 1.0],
		EndingService.F6_DRIFT: [&"drift", 1.0],
		EndingService.F7_REOPENS: [&"drift", 1.0, true],
	}
	for ending: StringName in expected:
		var spec: Array = expected[ending]
		var preset: StringName = spec[0]
		var accuracy: float = spec[1]
		var profile: SimProfile = SimProfile.preset(preset, accuracy)
		if spec.size() > 2:
			profile.choices.erase(&"d09_drift")
		var rows: Array[Dictionary] = BalanceSimulator.run_campaign(data, 7, accuracy, BalanceSimulator.Spending.REASONED, -1, profile)
		var reached: StringName = rows[rows.size() - 1]["ending"]
		assert_eq(reached, ending, "profil %s" % preset)


func test_campaign_simulation_is_deterministic() -> void:
	for preset: StringName in [&"default", &"luciole"]:
		var a: Array[Dictionary] = BalanceSimulator.run_campaign(data, 99, 0.8, BalanceSimulator.Spending.REASONED, -1,
				SimProfile.preset(preset, 0.8))
		var b: Array[Dictionary] = BalanceSimulator.run_campaign(data, 99, 0.8, BalanceSimulator.Spending.REASONED, -1,
				SimProfile.preset(preset, 0.8))
		assert_eq(a, b, String(preset))
