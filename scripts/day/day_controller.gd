## Machine à états du jour (ARCHITECTURE §8) — service de jour.
##
## `INTRO → WAITING_CASE → ARRIVING → INSPECTING → RESOLVING → DEPARTING →
## WAITING_CASE … → SUMMARY`. Construit les cas avec le `CaseBuilder` du jour,
## garde la clé de réponse (`CaseKey`, jamais transmise), note le verdict
## (`ScoringService`) et émet `day_started`, `day_phase_changed`,
## `case_presented`, `case_resolved`, `day_ended`.
## Robustesse (§7, §8 bis.6) : tout signal du booth d'un autre `case_id` ou
## hors de l'état attendu est ignoré ; des timeouts de sécurité font avancer
## le jour même sans booth (`SilentBooth`). Ils sont pilotés par `advance()`
## (appelé par `_process`, ou à la main dans les tests).
class_name DayController
extends Node

## `ARRIVING` sans `passenger_arrived` → `INSPECTING` + `push_warning`.
@export var arrive_timeout_sec: float = 15.0
## `INSPECTING` sans `documents_presented` → émis par le DayController.
@export var present_timeout_sec: float = 6.0
## `DEPARTING` sans `passenger_departed` → état suivant.
@export var depart_timeout_sec: float = 12.0

@export var clock: DayClock = null
@export var inspection: InspectionSession = null

var data: DataCatalog = null
var day: DayDef = null
var builder: CaseBuilder = null
var phase: DayPhase.Kind = DayPhase.Kind.INTRO
var current_case: Case = null
var current_key: CaseKey = null
## Index du prochain cas à construire.
var next_index: int = 0
var summary: DaySummary = null
var time_expired: bool = false
## Nombre de timeouts de secours déclenchés (diagnostic, tests).
var timeouts_fired: int = 0

var _documents_presented: bool = false
## Temps passé dans la phase courante (timeouts).
var _phase_time: float = 0.0
var _started: bool = false


func _ready() -> void:
	EventBus.next_case_requested.connect(_on_next_case_requested)
	EventBus.passenger_arrived.connect(_on_passenger_arrived)
	EventBus.documents_presented.connect(_on_documents_presented)
	EventBus.verdict_stamped.connect(_on_verdict_stamped)
	EventBus.passenger_departed.connect(_on_passenger_departed)
	EventBus.day_time_expired.connect(_on_day_time_expired)


## Prépare le jour `day_number` (phase INTRO) et émet `day_started`.
func start_day(p_data: DataCatalog, day_number: int, day_seed: int, flags: Array[StringName] = []) -> bool:
	data = p_data
	day = data.get_day(day_number) if data != null else null
	if day == null:
		push_error("DayController: jour %d introuvable" % day_number)
		return false
	builder = CaseBuilder.new(data, day, day_seed, flags)
	summary = DaySummary.new()
	summary.day_number = day.day_number
	summary.planned_cases = day.passenger_count
	next_index = 0
	time_expired = false
	timeouts_fired = 0
	current_case = null
	current_key = null
	_started = true
	if clock != null:
		clock.setup(day.duration_sec)
	_set_phase(DayPhase.Kind.INTRO, &"")
	EventBus.day_started.emit(day, day.rule_set.build_rulebook())
	return true


## L'intro du jour est fermée : le shift commence (horloge lancée).
func close_intro() -> void:
	if not _started or phase != DayPhase.Kind.INTRO:
		return
	if clock != null:
		clock.start()
	_set_phase(DayPhase.Kind.WAITING_CASE, &"")


func get_rule_context() -> RuleContext:
	return builder.ctx if builder != null else null


func has_remaining_cases() -> bool:
	return day != null and next_index < day.passenger_count


func current_case_id() -> StringName:
	return current_case.case_id if current_case != null else &""


func _process(delta: float) -> void:
	advance(delta)


## Avance les timeouts de sécurité de `delta` secondes.
func advance(delta: float) -> void:
	if not _started:
		return
	_phase_time += delta
	match phase:
		DayPhase.Kind.ARRIVING:
			if _phase_time >= arrive_timeout_sec:
				push_warning("DayController: timeout ARRIVING (%s)" % current_case_id())
				timeouts_fired += 1
				_enter_inspecting()
		DayPhase.Kind.INSPECTING:
			if not _documents_presented and _phase_time >= present_timeout_sec:
				push_warning("DayController: timeout documents_presented (%s)" % current_case_id())
				timeouts_fired += 1
				# Seul cas où un autre émetteur que le booth émet ce signal (§7).
				EventBus.documents_presented.emit(current_case_id())
		DayPhase.Kind.DEPARTING:
			if _phase_time >= depart_timeout_sec:
				push_warning("DayController: timeout DEPARTING (%s)" % current_case_id())
				timeouts_fired += 1
				_finish_departure()


func _on_next_case_requested() -> void:
	if phase != DayPhase.Kind.WAITING_CASE or not has_remaining_cases():
		return
	var generated: GeneratedCase = builder.build(next_index)
	next_index += 1
	if generated == null or generated.case == null:
		push_error("DayController: cas %d impossible à construire" % (next_index - 1))
		_after_case()
		return
	current_case = generated.case
	current_key = generated.key
	_documents_presented = false
	if inspection != null:
		inspection.begin(current_case, builder.ctx)
	# Phase posée avant l'émission : un écouteur synchrone voit ARRIVING.
	phase = DayPhase.Kind.ARRIVING
	_phase_time = 0.0
	EventBus.case_presented.emit(current_case)
	EventBus.day_phase_changed.emit(DayPhase.Kind.ARRIVING, current_case.case_id)


func _on_passenger_arrived(case_id: StringName) -> void:
	if phase != DayPhase.Kind.ARRIVING or case_id != current_case_id():
		return
	_enter_inspecting()


func _enter_inspecting() -> void:
	_set_phase(DayPhase.Kind.INSPECTING, current_case_id())


func _on_documents_presented(case_id: StringName) -> void:
	if case_id != current_case_id() or _documents_presented:
		return
	if phase == DayPhase.Kind.INSPECTING or phase == DayPhase.Kind.ARRIVING:
		_documents_presented = true


func _on_verdict_stamped(verdict: Verdict) -> void:
	# Garde logique : le tampon n'est accepté qu'en INSPECTING (pas seulement côté UI).
	if phase != DayPhase.Kind.INSPECTING or verdict == null:
		return
	if verdict.case_id != &"" and verdict.case_id != current_case_id():
		return
	verdict.case_id = current_case_id()
	_set_phase(DayPhase.Kind.RESOLVING, current_case_id())
	if inspection != null:
		inspection.end(verdict)
	var result: CaseResult = ScoringService.score(verdict, current_key, current_case_id())
	summary.add_result(result)
	EventBus.case_resolved.emit(current_case_id(), result)
	_set_phase(DayPhase.Kind.DEPARTING, current_case_id())


func _on_passenger_departed(case_id: StringName) -> void:
	if phase != DayPhase.Kind.DEPARTING or case_id != current_case_id():
		return
	_finish_departure()


func _finish_departure() -> void:
	current_case = null
	current_key = null
	_after_case()


## Après un cas : cas suivant, ou bilan si le temps est écoulé / la file vide.
func _after_case() -> void:
	if time_expired or not has_remaining_cases():
		_end_day()
	else:
		_set_phase(DayPhase.Kind.WAITING_CASE, &"")


func _on_day_time_expired() -> void:
	if not _started:
		return
	time_expired = true
	if phase == DayPhase.Kind.WAITING_CASE:
		_end_day()


func _end_day() -> void:
	if phase == DayPhase.Kind.SUMMARY:
		return
	if clock != null:
		clock.stop()
	summary.time_expired = time_expired
	_set_phase(DayPhase.Kind.SUMMARY, &"")
	EventBus.day_ended.emit(summary)


func _set_phase(p_phase: DayPhase.Kind, case_id: StringName) -> void:
	phase = p_phase
	_phase_time = 0.0
	EventBus.day_phase_changed.emit(p_phase, case_id)
