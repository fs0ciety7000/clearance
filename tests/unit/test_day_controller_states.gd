## Machine à états du DayController (ARCHITECTURE §8, §12) : transitions
## valides, signaux hors séquence ou d'un autre `case_id` ignorés (idempotence).
## Sans booth : les signaux du booth sont émis à la main.
extends GutTest

const DayHarness := preload("res://tests/helpers/day_harness.gd")

var h: DayHarness = null


func before_each() -> void:
	h = DayHarness.new()
	h.setup(self, null, 1)


func after_each() -> void:
	h.teardown()


func _to_arriving() -> StringName:
	h.controller.close_intro()
	EventBus.next_case_requested.emit()
	return h.controller.current_case_id()


func test_start_day_emits_intro_and_rulebook() -> void:
	assert_eq(h.controller.phase, DayPhase.Kind.INTRO)
	assert_eq(h.phases, [DayPhase.Kind.INTRO] as Array[DayPhase.Kind])
	assert_false(h.clock.running, "horloge arrêtée en INTRO")


func test_next_case_ignored_during_intro() -> void:
	EventBus.next_case_requested.emit()
	assert_eq(h.controller.phase, DayPhase.Kind.INTRO)
	assert_eq(h.count(&"case_presented"), 0)


func test_close_intro_starts_clock_and_waits() -> void:
	h.controller.close_intro()
	assert_eq(h.controller.phase, DayPhase.Kind.WAITING_CASE)
	assert_true(h.clock.running)
	h.controller.close_intro()
	assert_eq(h.phases.count(DayPhase.Kind.WAITING_CASE), 1, "close_intro idempotent")


func test_case_presented_with_deterministic_id() -> void:
	var id: StringName = _to_arriving()
	assert_eq(id, &"d01_c00")
	assert_eq(h.controller.phase, DayPhase.Kind.ARRIVING)
	assert_eq(h.controller.next_index, 1)
	assert_not_null(h.controller.current_key, "la clé reste côté logique")


func test_next_case_ignored_outside_waiting() -> void:
	_to_arriving()
	EventBus.next_case_requested.emit()
	assert_eq(h.controller.next_index, 1, "« Suivant » martelé : une seule prise en compte")
	assert_eq(h.count(&"case_presented"), 1)


func test_verdict_ignored_before_arrival() -> void:
	_to_arriving()
	h.stamp(VerdictKind.Kind.APPROVE)
	assert_eq(h.controller.phase, DayPhase.Kind.ARRIVING)
	assert_eq(h.results.size(), 0)


func test_arrival_of_other_case_ignored() -> void:
	_to_arriving()
	EventBus.passenger_arrived.emit(&"d01_c07")
	assert_eq(h.controller.phase, DayPhase.Kind.ARRIVING)


func test_duplicate_arrival_is_idempotent() -> void:
	var id: StringName = _to_arriving()
	EventBus.passenger_arrived.emit(id)
	EventBus.passenger_arrived.emit(id)
	assert_eq(h.controller.phase, DayPhase.Kind.INSPECTING)
	assert_eq(h.phases.count(DayPhase.Kind.INSPECTING), 1)


func test_documents_before_arrival_are_remembered() -> void:
	var id: StringName = _to_arriving()
	EventBus.documents_presented.emit(id)
	EventBus.passenger_arrived.emit(id)
	h.controller.advance(h.controller.present_timeout_sec + 1.0)
	assert_eq(h.count(&"documents_presented"), 1, "pas de réémission par timeout")
	assert_eq(h.controller.timeouts_fired, 0)


func test_verdict_for_other_case_ignored() -> void:
	var id: StringName = _to_arriving()
	EventBus.passenger_arrived.emit(id)
	EventBus.verdict_stamped.emit(Verdict.new(&"d01_c05", VerdictKind.Kind.DENY))
	assert_eq(h.controller.phase, DayPhase.Kind.INSPECTING)


func test_verdict_resolves_and_departs() -> void:
	var id: StringName = _to_arriving()
	EventBus.passenger_arrived.emit(id)
	h.stamp(VerdictKind.Kind.DENY)
	assert_eq(h.controller.phase, DayPhase.Kind.DEPARTING)
	assert_eq(h.results.size(), 1)
	assert_eq(h.results[0].case_id, id)
	assert_eq(h.results[0].verdict_kind, VerdictKind.Kind.DENY)
	h.stamp(VerdictKind.Kind.APPROVE)
	assert_eq(h.results.size(), 1, "jamais de double verdict")
	EventBus.passenger_departed.emit(&"d01_c09")
	assert_eq(h.controller.phase, DayPhase.Kind.DEPARTING, "départ d'un autre cas ignoré")
	EventBus.passenger_departed.emit(id)
	assert_eq(h.controller.phase, DayPhase.Kind.WAITING_CASE)
	EventBus.passenger_departed.emit(id)
	assert_eq(h.phases.count(DayPhase.Kind.WAITING_CASE), 2, "départ dupliqué ignoré")


func test_departure_ignored_while_inspecting() -> void:
	var id: StringName = _to_arriving()
	EventBus.passenger_arrived.emit(id)
	EventBus.passenger_departed.emit(id)
	assert_eq(h.controller.phase, DayPhase.Kind.INSPECTING)


func test_missing_day_fails_cleanly() -> void:
	var dc: DayController = DayController.new()
	add_child_autofree(dc)
	var ok: bool = dc.start_day(DayHarness.Gen.data(), 99, 1)
	assert_false(ok)
	assert_push_error("introuvable")
