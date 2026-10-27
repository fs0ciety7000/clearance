## GameState — état de campagne (ARCHITECTURE §4).
##
## Porte ce qui survit entre les jours : graine de campagne, jour courant,
## crédits, score, citations, drapeaux narratifs, historique résumé.
## L'état du jour en cours appartient à `DayController`.
## M5 : foyer (`Household`), sauvegarde/chargement JSON entre les jours
## (`save_to_slot` / `load_from_slot`, §10) via `SaveService` (format,
## migrations, validation) ; ce nœud ne fait que (dé)sérialiser son état.
## Pas de `class_name` (autoload).
extends Node

var campaign_seed: int = 0
## Numéro du jour courant (1 = premier jour ; 0 = aucune campagne).
var current_day: int = 0
var credits: int = 0
var score_total: int = 0
var citations: int = 0
var narrative_flags: Dictionary[StringName, Variant] = {}
## Historique résumé : `{day, correct, errors, credits}` par jour terminé
## (M5 : + `processed`, `planned`, `citations`, `wage`, `fines`, `spent`, `balance`).
var day_history: Array[Dictionary] = []
## Foyer de l'agent (Ilan, Noa, Dora — GDD §5.4).
var household: Household = Household.new()


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
	household = Household.new()


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


## Jauge narrative entière (`loyalty`, `lucioles_trust`, `suspicion`) : ajoute
## `delta` et renvoie la nouvelle valeur.
func add_to_flag(flag: StringName, delta: int) -> int:
	var value: int = SaveService.as_int(narrative_flags.get(flag, 0)) + delta
	set_flag(flag, value)
	return value


## Drapeaux « vrais » (booléen vrai ou entier non nul) : `requires_flag` du générateur.
func get_true_flags() -> Array[StringName]:
	var flags: Array[StringName] = []
	for flag: StringName in narrative_flags:
		var value: Variant = narrative_flags[flag]
		if (value is bool and value) or SaveService.as_int(value) != 0 or (value is String and str(value) != ""):
			flags.append(flag)
	return flags


## Enregistre le résumé d'un jour terminé et passe au suivant.
func record_day(correct: int, errors: int, day_credits: int) -> void:
	day_history.append({
		"day": current_day,
		"correct": correct,
		"errors": errors,
		"credits": day_credits,
	})
	current_day += 1


## Variante détaillée (M5) : `entry` complète l'historique (bilan + soirée).
func record_day_entry(entry: Dictionary) -> void:
	var row: Dictionary = entry.duplicate(true)
	row["day"] = current_day
	day_history.append(row)
	current_day += 1


# --- Sauvegarde (ARCHITECTURE §10) -------------------------------------------

## État de campagne sérialisable en JSON (types simples uniquement).
func to_save_dict() -> Dictionary:
	var flags: Dictionary = {}
	for flag: StringName in narrative_flags:
		flags[String(flag)] = narrative_flags[flag]
	return {
		"campaign_seed": campaign_seed,
		"current_day": current_day,
		"credits": credits,
		"score_total": score_total,
		"citations": citations,
		"narrative_flags": flags,
		"day_history": day_history.duplicate(true),
		"household": household.to_dict(),
	}


## Restaure l'état depuis un dictionnaire **validé** par `SaveService`.
func apply_save_dict(data: Dictionary) -> void:
	campaign_seed = SaveService.as_int(data.get("campaign_seed", 0))
	current_day = SaveService.as_int(data.get("current_day", 1), 1)
	credits = SaveService.as_int(data.get("credits", 0))
	score_total = SaveService.as_int(data.get("score_total", 0))
	citations = SaveService.as_int(data.get("citations", 0))
	narrative_flags.clear()
	var flags: Dictionary = data.get("narrative_flags", {})
	for key: Variant in flags:
		narrative_flags[StringName(str(key))] = _json_value(flags[key])
	day_history.clear()
	var history: Array = data.get("day_history", [])
	for entry: Variant in history:
		if entry is Dictionary:
			var row: Dictionary = {}
			for key: Variant in entry:
				row[str(key)] = _json_value(entry[key])
			day_history.append(row)
	var home: Dictionary = data.get("household", {})
	household = Household.from_dict(home)
	EventBus.credits_changed.emit(credits, 0)


func save_to_slot(slot: int = SaveService.DEFAULT_SLOT, dir: String = SaveService.DEFAULT_DIR) -> Error:
	var err: Error = SaveService.save(to_save_dict(), slot, dir)
	if err == OK:
		EventBus.game_saved.emit(slot)
	return err


## Charge une sauvegarde ; `false` si absente ou invalide (état inchangé).
func load_from_slot(slot: int = SaveService.DEFAULT_SLOT, dir: String = SaveService.DEFAULT_DIR) -> bool:
	var data: Dictionary = SaveService.load_slot(slot, dir)
	if data.is_empty():
		return false
	apply_save_dict(data)
	EventBus.game_loaded.emit(slot)
	return true


## JSON ne connaît que les flottants : un nombre entier redevient `int`.
static func _json_value(value: Variant) -> Variant:
	if value is float:
		var f: float = value
		if is_equal_approx(f, roundf(f)):
			return roundi(f)
	return value
