## Enchaînement des jours de la campagne (GDD §3.2, ARCHITECTURE §10) —
## service statique au-dessus de `GameState` et de `SaveService`.
##
## Shift → bilan → soirée → sauvegarde automatique → jour suivant ; fins
## anticipées (F2, F3) et fin de la démo après le dernier `DayDef` des données.
## Les crédits et citations du shift sont déjà appliqués au fil de l'eau par le
## `DayController` ; la soirée débite les dépenses et remplace le foyer.
class_name Campaign
extends RefCounted

## Fin de la *vertical slice* (après le dernier jour défini dans les données).
const ENDING_DEMO_COMPLETE: StringName = &"demo_complete"
const FLAG_LUCIOLES_CONTACT: StringName = &"lucioles_contact"
const FLAG_LUCIOLES_REPORTED: StringName = &"lucioles_reported"
const FLAG_LUCIOLES_BURNED: StringName = &"lucioles_note_burned"
const FLAG_LOYALTY: StringName = &"loyalty"
## Graine de la soirée (Noa malade au premier soir sans chauffage…).
const EVENING_SALT: String = "evening"


## Nouvelle partie : campagne neuve, solde de départ du barème.
static func new_game(data: DataCatalog, campaign_seed: int = 0) -> void:
	GameState.new_campaign(campaign_seed)
	var start: int = data.get_economy().starting_credits if data != null else 0
	if start != 0:
		GameState.add_credits(start)


## Graine déterministe de la soirée du jour courant.
static func evening_seed() -> int:
	return SeededRng.mix_string(SeededRng.day_seed(GameState.campaign_seed, GameState.current_day), EVENING_SALT)


## Postes de la soirée du jour courant, présélectionnés.
static func prepare_evening(data: DataCatalog) -> Array[ExpenseLine]:
	var lines: Array[ExpenseLine] = EveningService.build_lines(data.get_economy(), GameState.current_day, GameState.household)
	EveningService.default_selection(lines, GameState.credits)
	return lines


## Calcule la soirée sans rien modifier (écran de conséquences).
static func preview_evening(data: DataCatalog, lines: Array[ExpenseLine]) -> EveningReport:
	return EveningService.apply(data.get_economy(), GameState.current_day, GameState.household, lines,
			GameState.credits, evening_seed())


## Valide la soirée : débit, foyer, historique, passage au jour suivant,
## sauvegarde (ou suppression de la sauvegarde si la campagne se termine).
## Renvoie la fin atteinte (`EveningReport.ENDING_*`, `ENDING_DEMO_COMPLETE`) ou vide.
static func close_evening(data: DataCatalog, summary: DaySummary, report: EveningReport,
		save_slot: int = SaveService.DEFAULT_SLOT, save_dir: String = SaveService.DEFAULT_DIR) -> StringName:
	GameState.add_credits(-report.spent)
	GameState.household = report.household
	var entry: Dictionary = {
		"processed": summary.get_processed_count() if summary != null else 0,
		"planned": summary.planned_cases if summary != null else 0,
		"correct": summary.get_correct_count() if summary != null else 0,
		"errors": summary.get_error_count() if summary != null else 0,
		"citations": summary.get_citation_count() if summary != null else 0,
		"wage": summary.get_wage_total() if summary != null else 0,
		"fines": summary.get_fine_total() if summary != null else 0,
		"credits": summary.get_net() if summary != null else 0,
		"spent": report.spent,
		"balance": GameState.credits,
	}
	GameState.record_day_entry(entry)
	var ending: StringName = report.ending
	if ending == EveningReport.ENDING_NONE and GameState.current_day > data.get_last_day_number():
		ending = ENDING_DEMO_COMPLETE
	if ending == EveningReport.ENDING_NONE:
		GameState.save_to_slot(save_slot, save_dir)
	else:
		GameState.set_flag(&"ending", String(ending))
		SaveService.delete(save_slot, save_dir)
	return ending


## Le mot des Lucioles (SC-05) attend une décision du joueur ce soir.
static func luciole_note_pending() -> bool:
	return GameState.get_flag(FLAG_LUCIOLES_CONTACT, false) == true \
			and not GameState.has_flag(FLAG_LUCIOLES_REPORTED) and not GameState.has_flag(FLAG_LUCIOLES_BURNED)


## « Signaler » le mot (GDD §4.7, MVP : drapeau + loyauté) ou le brûler.
static func decide_luciole_note(report_it: bool) -> void:
	if report_it:
		GameState.set_flag(FLAG_LUCIOLES_REPORTED, true)
		GameState.add_to_flag(FLAG_LOYALTY, 1)
	else:
		GameState.set_flag(FLAG_LUCIOLES_BURNED, true)


## Indice de conformité cumulé (GDD §5.1) sur l'historique.
static func compliance() -> float:
	var processed: int = 0
	var correct: int = 0
	for entry: Dictionary in GameState.day_history:
		var row_correct: int = SaveService.as_int(entry.get("correct", 0))
		processed += SaveService.as_int(entry.get("processed", row_correct + SaveService.as_int(entry.get("errors", 0))))
		correct += row_correct
	return float(correct) / float(processed) if processed > 0 else 0.0
