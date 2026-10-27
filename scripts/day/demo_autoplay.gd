## Bot de démonstration (captures, playtest) — debug seulement (`--autoplay`).
##
## Joue comme un agent qui ne voit que ce qui est affiché (jamais la clé) :
## appelle le passager, fait retirer la visière si besoin, active le Mode
## Inspection et compare des paires visibles (visage ↔ photo, expiration ↔
## date du jour, mêmes données entre documents) jusqu'à une discordance,
## pose la question débloquée, puis tamponne : REFUSÉ si une discordance a été
## constatée, APPROUVÉ sinon. Avec l'UI, passe par son API publique (sélection,
## questions, maintien du tampon) ; sans UI, par l'EventBus.
class_name DemoAutoplay
extends Node

const WAIT_BEFORE_NEXT_SEC: float = 0.8
const LOOK_SEC: float = 1.2
const AFTER_VISOR_SEC: float = 2.4
const PICK_SEC: float = 0.5
const AFTER_CHECK_SEC: float = 1.4
const AFTER_ANSWER_SEC: float = 2.2
const STAMP_HOLD_SEC: float = 0.6
const MAX_CHECKS: int = 5

var controller: DayController = null
var ui: ComparisonUI = null

var _wait: float = WAIT_BEFORE_NEXT_SEC
var _running_for: StringName = &""
var _last_result: Discrepancy = null


func _ready() -> void:
	EventBus.documents_presented.connect(_on_documents_presented)
	EventBus.discrepancy_checked.connect(func(result: Discrepancy) -> void: _last_result = result)


func _process(delta: float) -> void:
	if controller == null or controller.phase != DayPhase.Kind.WAITING_CASE:
		return
	_wait -= delta
	if _wait <= 0.0:
		_wait = WAIT_BEFORE_NEXT_SEC
		if ui != null:
			ui.request_next_case()
		else:
			EventBus.next_case_requested.emit()


func _on_documents_presented(case_id: StringName) -> void:
	if _running_for == case_id:
		return
	_running_for = case_id
	_run_case(case_id)


func _sleep(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _still(case_id: StringName) -> bool:
	return controller.phase == DayPhase.Kind.INSPECTING and controller.current_case_id() == case_id


func _run_case(case_id: StringName) -> void:
	await _sleep(LOOK_SEC)
	if not _still(case_id):
		return
	var case: Case = controller.current_case
	if case.passenger_presented.appearance.is_face_covered():
		_ask(InspectionSession.TOPIC_REMOVE_VISOR)
		await _sleep(AFTER_VISOR_SEC)
		if not _still(case_id):
			return
	var found: Discrepancy = null
	if ui != null:
		ui.set_inspection_active(true)
	var checks: int = 0
	for pair: Array in _candidate_pairs(case):
		if checks >= MAX_CHECKS or not _still(case_id):
			break
		checks += 1
		_last_result = null
		var a: FieldRef = pair[0]
		var b: FieldRef = pair[1]
		await _compare(a, b)
		await _sleep(AFTER_CHECK_SEC)
		if _last_result != null and _last_result.confirmed:
			found = _last_result
			break
	if not _still(case_id):
		return
	if ui != null:
		ui.set_inspection_active(false)
	if found != null:
		var topic: StringName = InterrogationTopics.topic_for(found)
		_ask(topic if topic != &"" else InspectionSession.TOPIC_CONFRONT)
	else:
		_ask(InspectionSession.TOPIC_PURPOSE)
	await _sleep(AFTER_ANSWER_SEC)
	if _still(case_id):
		await _stamp(case_id, VerdictKind.Kind.DENY if found != null else VerdictKind.Kind.APPROVE)


func _compare(a: FieldRef, b: FieldRef) -> void:
	if ui == null:
		EventBus.discrepancy_check_requested.emit(a, b)
		return
	ui.pick(a)
	await _sleep(PICK_SEC)
	ui.pick(b)


func _ask(topic: StringName) -> void:
	if ui != null:
		ui.ask(topic)
	else:
		EventBus.interrogation_requested.emit(topic)


func _stamp(case_id: StringName, kind: VerdictKind.Kind) -> void:
	var button: StampButton = ui.get_stamp_button(kind) if ui != null else null
	if button == null:
		EventBus.verdict_stamped.emit(Verdict.new(case_id, kind))
		return
	button.begin_hold()
	await _sleep(STAMP_HOLD_SEC)
	button.end_hold()


## Paires comparables visibles, dans un ordre « d'agent » : visage ↔ photo,
## expirations ↔ date du jour, puis mêmes données entre deux documents.
static func _candidate_pairs(case: Case) -> Array[Array]:
	var pairs: Array[Array] = []
	for portrait: FieldRef in case.find_refs_by_kind(FieldDef.FieldKind.PORTRAIT):
		pairs.append([FieldRef.passenger_face(), portrait])
	for expiry: FieldRef in case.find_refs_by_truth_path(DiscrepancyChecker.EXPIRY_PATH):
		pairs.append([expiry, FieldRef.today()])
	for path: StringName in [&"family_name", &"citizen_id", &"given_name", &"birth_date"]:
		var refs: Array[FieldRef] = case.find_refs_by_truth_path(path)
		for i: int in range(1, refs.size()):
			pairs.append([refs[0], refs[i]])
	return pairs
