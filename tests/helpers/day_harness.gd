## Banc de test d'un jour sans UI (ARCHITECTURE §12) : DayController +
## DayClock + InspectionSession + booth (NullBooth / SilentBooth / aucun), tous
## avec `set_process(false)` (temps piloté par le test : `advance()`).
## Journalise les signaux EventBus du flux d'un cas.
## Usage : `var h := DayHarness.new(); await h.setup(self, NullBooth.new(), 1)`.
extends RefCounted

const Gen := preload("res://tests/helpers/generation_fixtures.gd")

var controller: DayController = null
var clock: DayClock = null
var session: InspectionSession = null
var booth: Node = null
## [nom du signal, case_id] dans l'ordre d'émission.
var events: Array[Array] = []
var phases: Array[DayPhase.Kind] = []
var summaries: Array[DaySummary] = []
var results: Array[CaseResult] = []
var reactions: Array[PassengerReaction.Kind] = []


func setup(test: GutTest, p_booth: Node, day_number: int, group: int = 0) -> void:
	clock = DayClock.new()
	session = InspectionSession.new()
	controller = DayController.new()
	controller.clock = clock
	controller.inspection = session
	for node: Node in [clock, session, controller]:
		test.add_child_autofree(node)
		node.set_process(false)
	if p_booth != null:
		booth = p_booth
		test.add_child_autofree(booth)
	EventBus.case_presented.connect(_on_case_presented)
	EventBus.passenger_arrived.connect(_on_named.bind(&"passenger_arrived"))
	EventBus.documents_presented.connect(_on_named.bind(&"documents_presented"))
	EventBus.passenger_departed.connect(_on_named.bind(&"passenger_departed"))
	EventBus.case_resolved.connect(_on_case_resolved)
	EventBus.day_phase_changed.connect(_on_phase)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.passenger_reaction_triggered.connect(_on_reaction)
	controller.start_day(Gen.data(), day_number, Gen.day_seed(group, day_number))


func teardown() -> void:
	for pair: Array in [
		[EventBus.case_presented, _on_case_presented],
		[EventBus.case_resolved, _on_case_resolved],
		[EventBus.day_phase_changed, _on_phase],
		[EventBus.day_ended, _on_day_ended],
		[EventBus.passenger_reaction_triggered, _on_reaction],
	]:
		var sig: Signal = pair[0]
		var callable: Callable = pair[1]
		if sig.is_connected(callable):
			sig.disconnect(callable)
	for sig: Signal in [EventBus.passenger_arrived, EventBus.documents_presented, EventBus.passenger_departed]:
		for connection: Dictionary in sig.get_connections():
			var callable: Callable = connection["callable"]
			if callable.get_object() == self:
				sig.disconnect(callable)


## Événements d'un cas, dans l'ordre (noms seulement).
func events_for(case_id: StringName) -> Array[StringName]:
	var names: Array[StringName] = []
	for event: Array in events:
		if event[1] == case_id:
			names.append(event[0])
	return names


func count(event_name: StringName) -> int:
	var n: int = 0
	for event: Array in events:
		if event[0] == event_name:
			n += 1
	return n


func stamp(kind: VerdictKind.Kind) -> void:
	EventBus.verdict_stamped.emit(Verdict.new(controller.current_case_id(), kind))


func _on_case_presented(case: Case) -> void:
	events.append([&"case_presented", case.case_id])


func _on_named(case_id: StringName, event_name: StringName) -> void:
	events.append([event_name, case_id])


func _on_case_resolved(case_id: StringName, result: CaseResult) -> void:
	events.append([&"case_resolved", case_id])
	results.append(result)


func _on_phase(phase: DayPhase.Kind, _case_id: StringName) -> void:
	phases.append(phase)


func _on_day_ended(summary: DaySummary) -> void:
	summaries.append(summary)


func _on_reaction(reaction: PassengerReaction.Kind) -> void:
	reactions.append(reaction)
