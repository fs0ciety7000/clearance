## Bilan d'un jour (ARCHITECTURE §7, GDD §3.2, §5) — émis par `EventBus.day_ended`.
##
## Résultats dans l'ordre de traitement + agrégats affichés par l'écran de
## bilan : traités / conformes, citations (avertissements, amendes), salaire,
## net du jour, passagers non traités (manque à gagner, GDD §5.1).
class_name DaySummary
extends RefCounted

var day_number: int = 0
## Résultats dans l'ordre de traitement.
var results: Array[CaseResult] = []
## Passagers prévus ce jour (`DayDef.passenger_count`).
var planned_cases: int = 0
## Le shift s'est terminé par la fin du temps (et non par une file vide).
var time_expired: bool = false
## M7 : drapeaux posés par les cas scénarisés **non traités** (`final_unprocessed`).
var unprocessed_changes: Dictionary[StringName, Variant] = {}


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


## Passagers restés dans la file à la sirène (0 ₵, sans citation).
func get_unprocessed_count() -> int:
	return maxi(planned_cases - results.size(), 0)


func get_citations() -> Array[CaseResult]:
	var list: Array[CaseResult] = []
	for result: CaseResult in results:
		if result.has_citation():
			list.append(result)
	return list


func get_citation_count() -> int:
	return get_citations().size()


func get_warning_count() -> int:
	var count: int = 0
	for result: CaseResult in results:
		if result.is_warning():
			count += 1
	return count


## Salaire brut (crédits gagnés par le travail).
func get_wage_total() -> int:
	var total: int = 0
	for result: CaseResult in results:
		total += result.wage
	return total


func get_fine_total() -> int:
	var total: int = 0
	for result: CaseResult in results:
		total += result.fine
	return total


## Net du jour : salaire − amendes.
func get_net() -> int:
	return get_wage_total() - get_fine_total()


## M7 : enveloppes gardées (« divers non déclaré »).
func get_bribe_total() -> int:
	var total: int = 0
	for result: CaseResult in results:
		total += result.bribe_credits
	return total


## M7 : primes de signalement (objets remis à la Garde).
func get_report_total() -> int:
	var total: int = 0
	for result: CaseResult in results:
		total += result.report_credits
	return total


## Tout ce que le shift a rapporté : net + enveloppes + primes (crédité au
## `GameState` au fil du shift).
func get_total_income() -> int:
	return get_net() + get_bribe_total() + get_report_total()


## Acte II : entrées imputées au guichet (APPROUVÉ au-delà du quota, R23).
func get_overrun_count() -> int:
	var count: int = 0
	for result: CaseResult in results:
		if result.quota_overrun:
			count += 1
	return count


## Acte II : refus motivés par le seul quota atteint.
func get_quota_refusal_count() -> int:
	var count: int = 0
	for result: CaseResult in results:
		if result.quota_refusal:
			count += 1
	return count


## Indice de conformité du jour (cas corrects / cas traités), 0 si aucun cas.
func get_compliance() -> float:
	return float(get_correct_count()) / float(results.size()) if not results.is_empty() else 0.0


## Drapeaux narratifs modifiés pendant le jour, dans l'ordre.
func get_narrative_changes() -> Dictionary[StringName, Variant]:
	var changes: Dictionary[StringName, Variant] = {}
	for result: CaseResult in results:
		for flag: StringName in result.narrative_changes:
			changes[flag] = result.narrative_changes[flag]
	for flag: StringName in unprocessed_changes:
		changes[flag] = unprocessed_changes[flag]
	return changes
