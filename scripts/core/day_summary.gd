## Bilan d'un jour (ARCHITECTURE §7) — émis par `EventBus.day_ended`.
##
## M4 : comptage minimal des cas traités. L'économie (salaire, loyer,
## famille), les citations et l'écran de résumé arrivent en M5.
class_name DaySummary
extends RefCounted

var day_number: int = 0
## Résultats dans l'ordre de traitement.
var results: Array[CaseResult] = []
## Passagers prévus ce jour (`DayDef.passenger_count`).
var planned_cases: int = 0
## Le shift s'est terminé par la fin du temps (et non par une file vide).
var time_expired: bool = false


func add_result(result: CaseResult) -> void:
	results.append(result)


func get_processed_count() -> int:
	return results.size()


func get_correct_count() -> int:
	var count: int = 0
	for result: CaseResult in results:
		if result.correct:
			count += 1
	return count


func get_error_count() -> int:
	return results.size() - get_correct_count()
