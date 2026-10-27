## Booth « nul » (ARCHITECTURE §8 bis.6) : remplace `BoothDirector` dans les
## tests d'intégration et le mode debug `--no-booth`.
##
## Sur `case_presented` : `passenger_arrived` puis `documents_presented` ; sur
## `case_resolved` : `passenger_departed`. Chaque émission passe par
## `call_deferred` (asynchronisme réel, pas de réentrance dans le DayController).
class_name NullBooth
extends Node

## Signaux émis (nom, case_id) dans l'ordre, pour les tests.
var emitted: Array[Array] = []


func _ready() -> void:
	EventBus.case_presented.connect(_on_case_presented)
	EventBus.case_resolved.connect(_on_case_resolved)


func _on_case_presented(case: Case) -> void:
	_emit_arrived.call_deferred(case.case_id)


func _on_case_resolved(case_id: StringName, _result: CaseResult) -> void:
	_emit_departed.call_deferred(case_id)


func _emit_arrived(case_id: StringName) -> void:
	emitted.append([&"passenger_arrived", case_id])
	EventBus.passenger_arrived.emit(case_id)
	_emit_documents.call_deferred(case_id)


func _emit_documents(case_id: StringName) -> void:
	emitted.append([&"documents_presented", case_id])
	EventBus.documents_presented.emit(case_id)


func _emit_departed(case_id: StringName) -> void:
	emitted.append([&"passenger_departed", case_id])
	EventBus.passenger_departed.emit(case_id)
