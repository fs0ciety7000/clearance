## GameState — état de campagne (ARCHITECTURE §4).
##
## Porte ce qui survit entre les jours : graine de campagne, jour courant,
## crédits, score, citations, drapeaux narratifs, historique résumé.
## L'état du jour en cours appartient à `DayController`.
## M5 : foyer (`Household`), sauvegarde/chargement JSON entre les jours
## (`save_to_slot` / `load_from_slot`, §10) via `SaveService` (format,
## migrations, validation) ; ce nœud ne fait que (dé)sérialiser son état.
## M11 (D-101, D-102, ARCHITECTURE §10) : emplacement actif (`active_slot`),
## reprise d'un jour passé (`load_day_snapshot`), fin archivée
## (`end_campaign` : `SaveService.mark_ended` + `ProfileService`), profil
## global alimenté à chaque sauvegarde (personnages croisés, mode Récit),
## difficulté (`difficulty` : `&"hard"` / `&"story"`, Récit → Dur seulement),
## temps de jeu (`play_time_sec`, compté entre deux sauvegardes).
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
## M7 : mémoire des passagers scénarisés (`CaseMemory`), clé = `ScriptedCaseDef.id`.
var case_memory: Dictionary = {}

const DIFFICULTY_HARD: StringName = &"hard"
const DIFFICULTY_STORY: StringName = &"story"
## M11 : emplacement de la partie en cours (1..`SaveService.SLOT_COUNT`).
var active_slot: int = SaveService.DEFAULT_SLOT
## M11 (D-102) : `&"hard"` (défaut) ou `&"story"` (mode Récit : pas de fin de
## shift à l'heure, amendes à 0 ₵). Récit → Dur possible, jamais l'inverse.
var difficulty: StringName = DIFFICULTY_HARD
## Temps de jeu cumulé (s) à la dernière sauvegarde / au chargement.
var play_time_sec: int = 0
## Visage de l'agent (réservé, `meta.portrait_seed`).
var portrait_seed: int = 0
## Début du temps de jeu non encore compté (`Time.get_ticks_msec`).
var _play_mark_msec: int = 0


## Démarre une nouvelle campagne. `p_seed = 0` tire une graine non
## déterministe (seul tirage hors SeededRng, à « Nouvelle partie »).
## M11 : emplacement `slot` (écrit à la première sauvegarde du soir ; la
## nouvelle partie n'efface rien) et difficulté (`&"hard"` / `&"story"`).
func new_campaign(p_seed: int = 0, slot: int = SaveService.DEFAULT_SLOT,
		p_difficulty: StringName = DIFFICULTY_HARD) -> void:
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
	case_memory = {}
	active_slot = slot
	difficulty = DIFFICULTY_STORY if p_difficulty == DIFFICULTY_STORY else DIFFICULTY_HARD
	play_time_sec = 0
	# 31 bits : exact à travers JSON (nombres flottants).
	portrait_seed = SeededRng.mix_string(campaign_seed, "portrait") & 0x7FFFFFFF
	_play_mark_msec = Time.get_ticks_msec()


## Mode Récit (D-102).
func is_story_mode() -> bool:
	return difficulty == DIFFICULTY_STORY


## Change la difficulté en cours de partie : Récit → Dur seulement (D-102).
## Renvoie vrai si la difficulté demandée est en vigueur. Émet
## `difficulty_changed` (le `DayController` en cours remet l'horloge).
func set_difficulty(value: StringName) -> bool:
	if value == difficulty:
		return true
	if value != DIFFICULTY_HARD:
		return false
	difficulty = DIFFICULTY_HARD
	EventBus.difficulty_changed.emit(difficulty)
	return true


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


## M7 : mémorise un passager scénarisé traité (`CaseMemory.snapshot`).
func remember_case(scripted_id: StringName, entry: Dictionary) -> void:
	case_memory[String(scripted_id)] = entry.duplicate(true)


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
		"case_memory": case_memory.duplicate(true),
		"difficulty": String(difficulty),
		"play_time_sec": play_time_sec,
		"portrait_seed": portrait_seed,
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
	case_memory = {}
	var remembered: Variant = data.get("case_memory", {})
	if remembered is Dictionary:
		var dict: Dictionary = remembered
		for key: Variant in dict:
			var entry: Variant = dict[key]
			if entry is Dictionary:
				case_memory[str(key)] = _json_deep(entry)
	difficulty = StringName(SaveService.difficulty_of(data))
	play_time_sec = maxi(SaveService.as_int(data.get("play_time_sec", 0)), 0)
	portrait_seed = SaveService.as_int(data.get("portrait_seed", 0))
	_play_mark_msec = Time.get_ticks_msec()
	EventBus.credits_changed.emit(credits, 0)


## Sauvegarde du soir dans l'emplacement `slot` (`NO_SLOT` : `active_slot`) :
## état courant, instantané du jour, méta (`SaveService.save_slot`), puis
## profil global (personnages croisés, mode Récit). Émet `game_saved`,
## `save_slots_changed` (et `profile_changed` si le profil change).
func save_to_slot(slot: int = SaveService.NO_SLOT, dir: String = SaveService.DEFAULT_DIR) -> Error:
	var target: int = active_slot if slot == SaveService.NO_SLOT else slot
	_bank_play_time()
	var err: Error = SaveService.save_slot(to_save_dict(), target, dir)
	if err == OK:
		active_slot = target
		EventBus.game_saved.emit(target)
		EventBus.save_slots_changed.emit()
		_record_profile(dir)
	return err


## Charge l'état courant d'un emplacement (`NO_SLOT` : « Continuer », la partie
## active la plus récente, `SaveService.latest_slot`) ; `false` si absent ou
## invalide (état inchangé). L'emplacement chargé devient `active_slot`.
func load_from_slot(slot: int = SaveService.NO_SLOT, dir: String = SaveService.DEFAULT_DIR) -> bool:
	var target: int = SaveService.latest_slot(dir) if slot == SaveService.NO_SLOT else slot
	if target == SaveService.NO_SLOT:
		return false
	var data: Dictionary = SaveService.load_current(target, dir)
	if data.is_empty():
		return false
	apply_save_dict(data)
	active_slot = target
	EventBus.game_loaded.emit(target)
	return true


## Reprend le matin du jour `day` d'un emplacement (instantané `day_NN.json`,
## D-101). Rien n'est écrit : à la sauvegarde suivante (soirée du jour repris),
## les instantanés postérieurs sont supprimés et la partie redevient `active`
## (même terminée). Une partie passée en Dur reste en Dur (D-102). `false` si
## l'instantané est absent ou invalide (état inchangé).
func load_day_snapshot(slot: int, day: int, dir: String = SaveService.DEFAULT_DIR) -> bool:
	var data: Dictionary = SaveService.load_snapshot(slot, day, dir)
	if data.is_empty():
		return false
	var meta: Dictionary = SaveService.load_meta(slot, dir)
	apply_save_dict(data)
	if str(meta.get("difficulty", SaveService.DIFFICULTY_HARD)) == SaveService.DIFFICULTY_HARD:
		difficulty = DIFFICULTY_HARD
	active_slot = slot
	EventBus.game_loaded.emit(slot)
	return true


## Fin de partie (F1–F10, fins anticipées comprises, D-101) : la partie n'est
## plus effacée. Fin enregistrée dans le profil (fins de `EndingService`),
## avec les personnages croisés ; emplacement archivé (`status = ended`,
## `ending_id`) s'il contient bien cette campagne (même graine). Idempotent
## (`Campaign` puis `DayScene.show_end`). `slot` = `NO_SLOT` : `active_slot`.
func end_campaign(ending: StringName, slot: int = SaveService.NO_SLOT, dir: String = SaveService.DEFAULT_DIR) -> void:
	var target: int = active_slot if slot == SaveService.NO_SLOT else slot
	var ending_id: String = String(ending)
	var known: bool = EndingService.ALL_ENDINGS.has(ending)
	var day: int = current_day
	if not day_history.is_empty():
		day = SaveService.as_int(day_history[day_history.size() - 1].get("day", current_day), current_day)
	if ProfileService.record(dir, ending_id if known else "", day, case_memory.keys(), is_story_mode()):
		EventBus.profile_changed.emit()
	if ending_id.is_empty() or not SaveService.has_save(target, dir):
		return
	var meta: Dictionary = SaveService.load_meta(target, dir)
	if SaveService.as_int(meta.get("campaign_seed", 0)) != campaign_seed:
		return
	if str(meta.get("status", "")) == SaveService.STATUS_ENDED and str(meta.get("ending_id", "")) == ending_id:
		return
	if SaveService.mark_ended(target, ending_id, dir) == OK:
		EventBus.save_slots_changed.emit()


## Profil global après une sauvegarde : personnages croisés, mode Récit.
func _record_profile(dir: String) -> void:
	if ProfileService.record(dir, "", current_day, case_memory.keys(), is_story_mode()):
		EventBus.profile_changed.emit()


## Ajoute au temps de jeu le temps écoulé depuis la dernière marque.
func _bank_play_time() -> void:
	var now: int = Time.get_ticks_msec()
	if _play_mark_msec <= 0 or now < _play_mark_msec:
		_play_mark_msec = now
		return
	var seconds: int = floori((now - _play_mark_msec) / 1000.0)
	play_time_sec += seconds
	_play_mark_msec += seconds * 1000


## Variante récursive (dictionnaires et tableaux imbriqués, clés en texte).
static func _json_deep(value: Variant) -> Variant:
	if value is Dictionary:
		var source: Dictionary = value
		var result: Dictionary = {}
		for key: Variant in source:
			result[str(key)] = _json_deep(source[key])
		return result
	if value is Array:
		var list: Array = value
		var copy: Array = []
		for item: Variant in list:
			copy.append(_json_deep(item))
		return copy
	return _json_value(value)


## JSON ne connaît que les flottants : un nombre entier redevient `int`.
static func _json_value(value: Variant) -> Variant:
	if value is float:
		var f: float = value
		if is_equal_approx(f, roundf(f)):
			return roundi(f)
	return value
