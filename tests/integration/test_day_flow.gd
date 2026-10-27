## Intégration (ARCHITECTURE §12) : un jour complet sans UI.
## NullBooth (booth asynchrone) : enchaînement des phases, ordre des signaux
## par cas, notation minimale, fin de jour. SilentBooth : les timeouts de
## sécurité font avancer le jour jusqu'au bilan.
extends GutTest

const DayHarness := preload("res://tests/helpers/day_harness.gd")
const MAX_WAIT_SEC: float = 2.0

var h: DayHarness = null


func before_each() -> void:
	h = DayHarness.new()


func after_each() -> void:
	h.teardown()


func _wait_phase(phase: DayPhase.Kind) -> bool:
	return await wait_until(func() -> bool: return h.controller.phase == phase, MAX_WAIT_SEC)


## Joue tout le jour avec un bot ; `policy(case_key) -> VerdictKind.Kind`.
## `investigate` : le bot documente ses refus et fait retirer les visières (M5).
func _play_day(policy: Callable, investigate: bool = false) -> void:
	h.controller.close_intro()
	var guard: int = 0
	while h.controller.phase != DayPhase.Kind.SUMMARY and guard < 64:
		guard += 1
		assert_eq(h.controller.phase, DayPhase.Kind.WAITING_CASE)
		EventBus.next_case_requested.emit()
		assert_eq(h.controller.phase, DayPhase.Kind.ARRIVING)
		var case_id: StringName = h.controller.current_case_id()
		var ok: bool = await wait_until(func() -> bool: return h.events_for(case_id).has(&"documents_presented"), MAX_WAIT_SEC)
		assert_true(ok, "documents présentés pour %s" % case_id)
		assert_eq(h.controller.phase, DayPhase.Kind.INSPECTING)
		var kind: VerdictKind.Kind = policy.call(h.controller.current_key)
		if investigate:
			h.investigate_current()
		h.stamp(kind)
		assert_eq(h.controller.phase, DayPhase.Kind.DEPARTING)
		await wait_until(func() -> bool: return h.controller.phase != DayPhase.Kind.DEPARTING, MAX_WAIT_SEC)


func test_perfect_bot_full_day_with_null_booth() -> void:
	h.setup(self, NullBooth.new(), 1)
	await _play_day(func(key: CaseKey) -> VerdictKind.Kind: return key.expected_verdict, true)
	var day: DayDef = h.controller.day
	assert_eq(h.controller.phase, DayPhase.Kind.SUMMARY)
	assert_eq(h.summaries.size(), 1, "day_ended émis une seule fois")
	var summary: DaySummary = h.summaries[0]
	assert_eq(summary.get_processed_count(), day.passenger_count)
	assert_eq(summary.get_correct_count(), day.passenger_count, "bot parfait : tout juste")
	assert_eq(summary.get_error_count(), 0)
	assert_false(summary.time_expired)
	assert_eq(h.controller.timeouts_fired, 0, "aucun timeout avec NullBooth")
	# Ordre garanti par cas (§8 bis.6).
	var expected: Array[StringName] = [&"case_presented", &"passenger_arrived", &"documents_presented",
			&"case_resolved", &"passenger_departed"]
	for i: int in day.passenger_count:
		var case_id: StringName = StringName("d%02d_c%02d" % [day.day_number, i])
		assert_eq(h.events_for(case_id), expected, "séquence de %s" % case_id)


func test_approve_all_bot_scores_expected_verdicts() -> void:
	h.setup(self, NullBooth.new(), 2, 3)
	await _play_day(func(_key: CaseKey) -> VerdictKind.Kind: return VerdictKind.Kind.APPROVE)
	assert_eq(h.summaries.size(), 1)
	var correct: int = 0
	for result: CaseResult in h.results:
		assert_eq(result.verdict_kind, VerdictKind.Kind.APPROVE)
		assert_eq(result.correct, result.expected_verdict == VerdictKind.Kind.APPROVE)
		assert_eq(result.missed_violations.is_empty(), result.expected_verdict == VerdictKind.Kind.APPROVE)
		if result.correct:
			correct += 1
	assert_eq(h.summaries[0].get_correct_count(), correct)
	assert_lt(correct, h.results.size(), "le jour 2 contient des cas fautifs")


func test_phase_sequence_of_one_case() -> void:
	h.setup(self, NullBooth.new(), 1)
	h.controller.close_intro()
	h.phases.clear()
	EventBus.next_case_requested.emit()
	await _wait_phase(DayPhase.Kind.INSPECTING)
	h.stamp(VerdictKind.Kind.APPROVE)
	await _wait_phase(DayPhase.Kind.WAITING_CASE)
	assert_eq(h.phases, [DayPhase.Kind.ARRIVING, DayPhase.Kind.INSPECTING, DayPhase.Kind.RESOLVING,
			DayPhase.Kind.DEPARTING, DayPhase.Kind.WAITING_CASE] as Array[DayPhase.Kind])


func test_verdict_reaction_emitted_before_case_resolved() -> void:
	h.setup(self, NullBooth.new(), 1)
	h.controller.close_intro()
	EventBus.next_case_requested.emit()
	await _wait_phase(DayPhase.Kind.INSPECTING)
	h.stamp(VerdictKind.Kind.APPROVE)
	var last: PassengerReaction.Kind = h.reactions[h.reactions.size() - 1]
	assert_eq(last, PassengerReaction.Kind.RELIEVED)


func test_time_expired_while_waiting_ends_day() -> void:
	h.setup(self, NullBooth.new(), 1)
	h.controller.close_intro()
	assert_true(h.clock.running)
	h.clock.advance(h.controller.day.duration_sec + 1.0)
	assert_eq(h.controller.phase, DayPhase.Kind.SUMMARY)
	assert_eq(h.summaries.size(), 1)
	assert_true(h.summaries[0].time_expired)
	assert_false(h.clock.running)


func test_time_expired_during_case_finishes_case_then_summary() -> void:
	h.setup(self, NullBooth.new(), 1)
	h.controller.close_intro()
	EventBus.next_case_requested.emit()
	await _wait_phase(DayPhase.Kind.INSPECTING)
	h.clock.advance(h.controller.day.duration_sec + 1.0)
	assert_eq(h.controller.phase, DayPhase.Kind.INSPECTING, "le passager en cours reste jouable")
	h.stamp(VerdictKind.Kind.DENY)
	await _wait_phase(DayPhase.Kind.SUMMARY)
	assert_eq(h.summaries.size(), 1)
	assert_eq(h.summaries[0].get_processed_count(), 1)
	assert_true(h.summaries[0].time_expired)


func test_silent_booth_timeouts_drive_whole_day() -> void:
	h.setup(self, SilentBooth.new(), 1)
	var dc: DayController = h.controller
	dc.close_intro()
	var n: int = dc.day.passenger_count
	for i: int in n:
		assert_eq(dc.phase, DayPhase.Kind.WAITING_CASE)
		EventBus.next_case_requested.emit()
		assert_eq(dc.phase, DayPhase.Kind.ARRIVING)
		dc.advance(dc.arrive_timeout_sec * 0.5)
		assert_eq(dc.phase, DayPhase.Kind.ARRIVING, "pas de timeout prématuré")
		dc.advance(dc.arrive_timeout_sec)
		assert_eq(dc.phase, DayPhase.Kind.INSPECTING, "timeout ARRIVING")
		dc.advance(dc.present_timeout_sec + 0.1)
		assert_true(h.events_for(dc.current_case_id()).has(&"documents_presented"), "documents émis par le DayController")
		dc.advance(dc.present_timeout_sec + 0.1)
		assert_eq(h.count(&"documents_presented"), i + 1, "émis une seule fois par cas")
		h.stamp(VerdictKind.Kind.APPROVE)
		assert_eq(dc.phase, DayPhase.Kind.DEPARTING)
		dc.advance(dc.depart_timeout_sec + 0.1)
	assert_eq(dc.phase, DayPhase.Kind.SUMMARY)
	assert_eq(h.summaries.size(), 1)
	assert_eq(dc.timeouts_fired, 3 * n)
	assert_eq((h.booth as SilentBooth).cases_seen.size(), n)
	assert_eq(h.count(&"passenger_arrived"), 0, "le booth muet n'a rien émis")


func test_null_booth_emits_deferred() -> void:
	h.setup(self, NullBooth.new(), 1)
	h.controller.close_intro()
	EventBus.next_case_requested.emit()
	assert_eq(h.controller.phase, DayPhase.Kind.ARRIVING, "pas de réentrance synchrone")
	assert_eq(h.count(&"passenger_arrived"), 0)
	await _wait_phase(DayPhase.Kind.INSPECTING)
	assert_eq(h.count(&"passenger_arrived"), 1)
