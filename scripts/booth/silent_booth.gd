## Booth muet (ARCHITECTURE §8 bis.6) : n'émet **rien**. Sert à tester les
## timeouts de sécurité du DayController (le jour doit avancer sans booth).
class_name SilentBooth
extends Node

## Cas reçus (diagnostic).
var cases_seen: Array[StringName] = []


func _ready() -> void:
	EventBus.case_presented.connect(_on_case_presented)


func _on_case_presented(case: Case) -> void:
	cases_seen.append(case.case_id)
