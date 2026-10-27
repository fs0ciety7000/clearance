## GameState — état de campagne (ARCHITECTURE §4).
##
## Porte ce qui survit entre les jours : graine de campagne, jour courant,
## crédits, score, citations, drapeaux narratifs, historique résumé.
## L'état du jour en cours appartient à `DayController` (M5).
## Sauvegarde/chargement JSON (`save_to_slot` / `load_from_slot`, §10) : M5.
## Pas de `class_name` (autoload).
extends Node

var campaign_seed: int = 0
## Numéro du jour courant (1 = premier jour ; 0 = aucune campagne).
var current_day: int = 0
var credits: int = 0
var score_total: int = 0
var citations: int = 0
var narrative_flags: Dictionary[StringName, Variant] = {}
## Historique résumé : `{day, correct, errors, credits}` par jour terminé.
var day_history: Array[Dictionary] = []


## Démarre une nouvelle campagne. `p_seed = 0` tire une graine non
## déterministe (seul tirage hors SeededRng, à « Nouvelle partie »).
func new_campaign(p_seed: int = 0) -> void:
	if p_seed == 0:
		var entropy: RandomNumberGenerator = RandomNumberGenerator.new()
		entropy.randomize()
		p_seed = SeededRng.mix(entropy.randi(), entropy.randi())
	campaign_seed = p_seed
	current_day = 1
	credits = 0
	score_total = 0
	citations = 0
	narrative_flags.clear()
	day_history.clear()


## Graine du jour courant (§9.1).
func get_day_seed() -> int:
	return SeededRng.day_seed(campaign_seed, current_day)


func add_credits(delta: int) -> void:
	if delta == 0:
		return
	credits += delta
	EventBus.credits_changed.emit(credits, delta)


func add_citation() -> void:
	citations += 1


func set_flag(flag: StringName, value: Variant) -> void:
	if narrative_flags.get(flag) == value and narrative_flags.has(flag):
		return
	narrative_flags[flag] = value
	EventBus.narrative_flag_changed.emit(flag, value)


func get_flag(flag: StringName, default_value: Variant = null) -> Variant:
	return narrative_flags.get(flag, default_value)


func has_flag(flag: StringName) -> bool:
	return narrative_flags.has(flag)


## Enregistre le résumé d'un jour terminé et passe au suivant.
func record_day(correct: int, errors: int, day_credits: int) -> void:
	day_history.append({
		"day": current_day,
		"correct": correct,
		"errors": errors,
		"credits": day_credits,
	})
	current_day += 1
