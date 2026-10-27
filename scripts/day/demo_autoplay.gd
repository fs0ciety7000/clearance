## Bot de démonstration (captures, playtest du booth sans UI) — debug seulement.
##
## Appelle le passager suivant, laisse le temps d'arriver, fait retirer la
## visière si besoin, compare le visage à la photo de la carte d'identité, puis
## tamponne en alternant APPROUVÉ / REFUSÉ. Ne lit jamais la clé de réponse.
class_name DemoAutoplay
extends Node

const WAIT_BEFORE_NEXT_SEC: float = 0.6
const INSPECT_SEC: float = 2.6
const AFTER_VISOR_SEC: float = 2.2

var controller: DayController = null
var _wait: float = WAIT_BEFORE_NEXT_SEC
var _docs_for: StringName = &""
var _visor_asked: bool = false
var _face_checked: bool = false
var _approve_next: bool = true


func _ready() -> void:
	EventBus.documents_presented.connect(_on_documents_presented)


func _on_documents_presented(case_id: StringName) -> void:
	_docs_for = case_id
	_visor_asked = false
	_face_checked = false
	_wait = INSPECT_SEC


func _process(delta: float) -> void:
	if controller == null:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	match controller.phase:
		DayPhase.Kind.WAITING_CASE:
			EventBus.next_case_requested.emit()
			_wait = WAIT_BEFORE_NEXT_SEC
		DayPhase.Kind.INSPECTING:
			if _docs_for != controller.current_case_id():
				return
			var case: Case = controller.current_case
			if not _visor_asked and case.passenger_presented.appearance.is_face_covered():
				_visor_asked = true
				EventBus.interrogation_requested.emit(InspectionSession.TOPIC_REMOVE_VISOR)
				_wait = AFTER_VISOR_SEC
				return
			if not _face_checked:
				_face_checked = true
				var portraits: Array[FieldRef] = case.find_refs_by_kind(FieldDef.FieldKind.PORTRAIT)
				if not portraits.is_empty():
					EventBus.discrepancy_check_requested.emit(FieldRef.passenger_face(), portraits[0])
				_wait = 1.2
				return
			var kind: VerdictKind.Kind = VerdictKind.Kind.APPROVE if _approve_next else VerdictKind.Kind.DENY
			_approve_next = not _approve_next
			EventBus.verdict_stamped.emit(Verdict.new(controller.current_case_id(), kind))
			_wait = WAIT_BEFORE_NEXT_SEC
