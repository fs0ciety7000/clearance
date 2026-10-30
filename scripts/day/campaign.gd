## Enchaînement des jours de la campagne (GDD §3.2, ARCHITECTURE §10) —
## service statique au-dessus de `GameState` et de `SaveService`.
##
## Shift → bilan → soirée → sauvegarde automatique → jour suivant ; fins
## anticipées (F2, F3) et fin de la démo après le dernier `DayDef` des données.
## Les crédits et citations du shift sont déjà appliqués au fil de l'eau par le
## `DayController` ; la soirée débite les dépenses et remplace le foyer.
## M7 : événements du soir (`prepare_events`, choix par défaut sans UI),
## gains et drapeaux des événements, audit du J9 (F1), dernier jour sans soirée
## (`close_final_day` : J20 depuis D-076, fins F1–F9 ; F1–F7 si les données
## s'arrêtent avant l'Acte II ; épilogue), mémoire des
## passagers (`memory_for_day`), jauges `loyalty` / `lucioles_trust` /
## `suspicion`.
## Acte II (docs/ACT2.md, D-076 → D-079, ARCHITECTURE §7.2) : la soirée du J10
## est un pivot (`act2_started` si la campagne continue) ; drapeaux de contexte
## du foyer et de la conformité pour les conditions du soir
## (`EveningService.context_flags`) ; postes selon les drapeaux et le solde
## (rations, prélèvements, ACV-2) ; `overrun_yesterday` (entrées imputées la
## veille, briefing de la Commission) ; fin du J20 par
## `EndingService.evaluate_final_act2`, épilogues `end2_*`.
## Acte III (docs/ACT3.md, D-086 → D-089, ARCHITECTURE §7.3) : la soirée du
## J20 est un pivot (`act3_started` si la campagne continue ; climat posé par
## la carte de fin d'acte) ; contexte du soir complet (`evening_context` :
## solde, rappel des salaires, climat prévisualisé) ; fin du J30 par
## `EndingService.evaluate_final_act3` (foyer du dernier jour, figure
## finale), épilogues `end3_*`.
## M12 (ARCHITECTURE §11) : **épilogue J31** (`epilogue_seed_for_slot`,
## `epilogue_seed_from_profile`, `start_epilogue`, `close_epilogue` : pas
## d'économie, pas de soirée, conclusion composée, profil, méta
## `epilogue_done` ; la partie terminée n'est jamais modifiée) et **Garde de
## nuit** (`start_garde`, `finish_garde` : records au profil).
class_name Campaign
extends RefCounted

## Fin de la *vertical slice* (après le dernier jour défini dans les données).
const ENDING_DEMO_COMPLETE: StringName = &"demo_complete"
const FLAG_LUCIOLES_CONTACT: StringName = &"lucioles_contact"
const FLAG_LUCIOLES_REPORTED: StringName = &"lucioles_reported"
const FLAG_LUCIOLES_BURNED: StringName = &"lucioles_note_burned"
const FLAG_LOYALTY: StringName = &"loyalty"
const FLAG_TRUST: StringName = &"lucioles_trust"
const FLAG_SUSPICION: StringName = &"suspicion"
const FLAG_ENDING: StringName = &"ending"
## Acte II : au moins une entrée imputée au quota la veille.
const FLAG_OVERRUN_YESTERDAY: StringName = &"overrun_yesterday"
## Signaler le mot des Lucioles (GDD §4.7) : confiance −2.
const REPORT_TRUST_DELTA: int = -2
## Graine de la soirée (Noa malade au premier soir sans chauffage…).
const EVENING_SALT: String = "evening"


## Nouvelle partie : campagne neuve, solde de départ du barème.
## M11 : emplacement (`slot`, écrit au premier soir) et difficulté
## (`GameState.DIFFICULTY_HARD` / `DIFFICULTY_STORY`, D-102).
static func new_game(data: DataCatalog, campaign_seed: int = 0, slot: int = SaveService.DEFAULT_SLOT,
		difficulty: StringName = &"hard") -> void:
	GameState.new_campaign(campaign_seed, slot, difficulty)
	var start: int = data.get_economy().starting_credits if data != null else 0
	if start != 0:
		GameState.add_credits(start)


## Graine déterministe de la soirée du jour courant.
static func evening_seed() -> int:
	return SeededRng.mix_string(SeededRng.day_seed(GameState.campaign_seed, GameState.current_day), EVENING_SALT)


## Mémoire des passagers utile au jour courant (`CaseMemory.resolve`).
static func memory_for_day(data: DataCatalog) -> Dictionary:
	return CaseMemory.resolve(data, data.get_day(GameState.current_day), GameState.campaign_seed, GameState.case_memory)


## Événements du soir du jour courant (M7), choix par défaut non encore posés.
static func prepare_events(data: DataCatalog) -> Array[EveningEvent]:
	var day: DayDef = data.get_day(GameState.current_day)
	var defs: Array[EveningEventDef] = []
	if day != null:
		defs = day.evening_events
	# M13 (QA-069) : lettres d'offre de l'Économat (AG-04, AG-05, AG-06) en fin de liste.
	return EveningService.build_events(defs, evening_flags(), data.get_economy(), GameState.current_day)


## Drapeaux du soir : narratifs + contexte (foyer, conformité ; Acte III :
## solde, rappel des salaires, climat du J20 ; M11 : mode Récit, D-113),
## jamais sauvegardés.
static func evening_flags() -> Dictionary[StringName, Variant]:
	var economy: EconomyDef = DataCatalog.load_economy()
	var levy: int = economy.levy_for(GameState.current_day, GameState.credits)
	return EveningService.evening_context(GameState.narrative_flags, GameState.household, compliance(), levy,
			GameState.current_day, economy, GameState.credits, GameState.is_story_mode())


## Postes de la soirée du jour courant, présélectionnés (coûts imposés par les
## événements et les choix déjà faits).
static func prepare_evening(data: DataCatalog, events: Array[EveningEvent] = [],
		choices: Dictionary[StringName, StringName] = {}) -> Array[ExpenseLine]:
	var lines: Array[ExpenseLine] = EveningService.build_lines(data.get_economy(), GameState.current_day, GameState.household,
			GameState.narrative_flags, GameState.credits)
	EveningService.apply_line_costs(lines, events, choices)
	EveningService.default_selection(lines, GameState.credits)
	# M13 (D-150) : offres de l'Économat, jamais cochées par défaut (`upgrade_id`).
	lines.append_array(EveningService.shop_lines(data.get_economy(), GameState.current_day, GameState.narrative_flags))
	return lines


## Choix par défaut des événements (sans UI), avec le solde restant après les postes.
static func default_choices(events: Array[EveningEvent], lines: Array[ExpenseLine]) -> Dictionary[StringName, StringName]:
	return EveningService.default_choices(events, GameState.credits - EveningService.total_spent(lines))


## Calcule la soirée sans rien modifier (écran de conséquences). `choices`
## vide → choix par défaut des événements.
static func preview_evening(data: DataCatalog, lines: Array[ExpenseLine], events: Array[EveningEvent] = [],
		choices: Dictionary[StringName, StringName] = {}) -> EveningReport:
	var chosen: Dictionary[StringName, StringName] = choices
	if chosen.is_empty() and not events.is_empty():
		chosen = default_choices(events, lines)
	return EveningService.apply(data.get_economy(), GameState.current_day, GameState.household, lines,
			GameState.credits, evening_seed(), events, chosen, evening_flags())


## Valide la soirée : débit, foyer, historique, passage au jour suivant,
## sauvegarde (ou, si la campagne se termine, archivage de la partie et fin
## enregistrée dans le profil : `GameState.end_campaign`, D-101).
## `save_slot` = `SaveService.NO_SLOT` : emplacement actif.
## Renvoie la fin atteinte (`EveningReport.ENDING_*`, `ENDING_DEMO_COMPLETE`) ou vide.
static func close_evening(data: DataCatalog, summary: DaySummary, report: EveningReport,
		save_slot: int = SaveService.NO_SLOT, save_dir: String = SaveService.DEFAULT_DIR) -> StringName:
	GameState.add_credits(report.gained - report.spent)
	GameState.household = report.household
	for flag: StringName in report.flag_changes:
		GameState.set_flag(flag, report.flag_changes[flag])
	# M13 (D-150) : améliorations achetées ce soir (Économat, pastilles, audio).
	for upgrade_id: StringName in report.upgrades_bought:
		EventBus.upgrade_purchased.emit(upgrade_id)
	# Acte II : entrées imputées aujourd'hui → briefing de la Commission demain.
	var overruns: int = summary.get_overrun_count() if summary != null else 0
	if overruns > 0 or GameState.has_flag(FLAG_OVERRUN_YESTERDAY):
		GameState.set_flag(FLAG_OVERRUN_YESTERDAY, overruns > 0)
	var pivot: bool = GameState.current_day == data.get_economy().pivot_day and report.ending == EveningReport.ENDING_NONE
	var pivot3: bool = GameState.current_day == data.get_economy().act3_pivot_day and report.ending == EveningReport.ENDING_NONE \
			and is_act2()
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
		"gained": report.gained + (summary.get_bribe_total() + summary.get_report_total() if summary != null else 0),
		"balance": GameState.credits,
	}
	GameState.record_day_entry(entry)
	if pivot:
		GameState.set_flag(EndingService.FLAG_ACT2, true)
	if pivot3:
		GameState.set_flag(EndingService.FLAG_ACT3, true)
	var ending: StringName = report.ending
	if ending == EveningReport.ENDING_NONE and GameState.current_day > data.get_last_day_number():
		ending = ENDING_DEMO_COMPLETE
	if ending == EveningReport.ENDING_NONE:
		GameState.save_to_slot(save_slot, save_dir)
	else:
		GameState.set_flag(FLAG_ENDING, String(ending))
		GameState.end_campaign(ending, save_slot, save_dir)
	return ending


## Le jour courant n'a pas de soirée (`DayDef.has_evening` faux : J20 depuis
## D-076 ; le J10 a une soirée pivot) : le bilan enchaîne sur la fin.
static func has_evening(data: DataCatalog) -> bool:
	var day: DayDef = data.get_day(GameState.current_day)
	return day == null or day.has_evening


## Dernier jour (sans soirée, J20) : historique, évaluation de la fin (Acte II :
## F1–F9, `EndingService.evaluate_final_act2` ; sinon F1–F7,
## `evaluate_final` ; crédits après le bilan), partie archivée et fin
## enregistrée dans le profil (`GameState.end_campaign`, D-101). Renvoie la fin.
static func close_final_day(data: DataCatalog, summary: DaySummary, save_slot: int = SaveService.NO_SLOT,
		save_dir: String = SaveService.DEFAULT_DIR) -> StringName:
	GameState.record_day_entry({
		"processed": summary.get_processed_count() if summary != null else 0,
		"planned": summary.planned_cases if summary != null else 0,
		"correct": summary.get_correct_count() if summary != null else 0,
		"errors": summary.get_error_count() if summary != null else 0,
		"citations": summary.get_citation_count() if summary != null else 0,
		"wage": summary.get_wage_total() if summary != null else 0,
		"fines": summary.get_fine_total() if summary != null else 0,
		"credits": summary.get_net() if summary != null else 0,
		"spent": 0,
		"gained": summary.get_bribe_total() + summary.get_report_total() if summary != null else 0,
		"balance": GameState.credits,
	})
	var ending: StringName
	if is_act3():
		EndingService.apply_final_household(GameState.narrative_flags, GameState.household)
		ending = EndingService.evaluate_final_act3(GameState.narrative_flags, GameState.household, GameState.credits,
				compliance(), data.get_economy())
	elif is_act2():
		ending = EndingService.evaluate_final_act2(GameState.narrative_flags, GameState.household, GameState.credits,
				compliance(), data.get_economy())
	else:
		ending = EndingService.evaluate_final(GameState.narrative_flags, GameState.household, GameState.credits,
				compliance(), data.get_economy())
	GameState.set_flag(FLAG_ENDING, String(ending))
	GameState.end_campaign(ending, save_slot, save_dir)
	return ending


## Épilogue de la fin enregistrée (`EndingService.epilogue`) ; vide hors fins M7.
static func epilogue(ending: StringName) -> Dictionary:
	if not EndingService.ALL_ENDINGS.has(ending):
		return {}
	if is_act3():
		return EndingService.epilogue_act3(ending, GameState.narrative_flags, GameState.household)
	if is_act2():
		return EndingService.epilogue_act2(ending, GameState.narrative_flags, GameState.household)
	return EndingService.epilogue(ending, GameState.narrative_flags, GameState.household)


## Acte III commencé (soirée pivot du J20 passée sans fin).
static func is_act3() -> bool:
	return GameState.get_flag(EndingService.FLAG_ACT3, false) == true


## Acte II commencé (soirée pivot du J10 passée sans fin).
static func is_act2() -> bool:
	return GameState.get_flag(EndingService.FLAG_ACT2, false) == true


## Le mot des Lucioles (SC-05) attend une décision du joueur ce soir.
static func luciole_note_pending() -> bool:
	return GameState.get_flag(FLAG_LUCIOLES_CONTACT, false) == true \
			and not GameState.has_flag(FLAG_LUCIOLES_REPORTED) and not GameState.has_flag(FLAG_LUCIOLES_BURNED)


## Prime affichée sur le bouton « SIGNALER AU CONSORTIUM » (+10 ₵).
static func luciole_report_bonus() -> int:
	return EveningService.report_bonus(DataCatalog.load_economy(), true)


## « Signaler » le mot (GDD §4.7, MVP : drapeau + loyauté) ou le brûler.
## Renvoie la prime **créditée sur le compte** (`GameState.credits`) ce soir :
## l'écran de soirée l'ajoute à ses fonds (`EveningService.evening_funds`,
## QA-008) ; 0 si le mot est brûlé.
static func decide_luciole_note(report_it: bool) -> int:
	var bonus: int = EveningService.report_bonus(DataCatalog.load_economy(), report_it)
	if report_it:
		GameState.set_flag(FLAG_LUCIOLES_REPORTED, true)
		GameState.add_to_flag(FLAG_LOYALTY, 1)
		# M7 (GDD §4.7, NARRATIVE §2.1) : confiance −2, prime de signalement.
		GameState.add_to_flag(FLAG_TRUST, REPORT_TRUST_DELTA)
		GameState.add_credits(bonus)
	else:
		GameState.set_flag(FLAG_LUCIOLES_BURNED, true)
	return bonus


## Indice de conformité cumulé (GDD §5.1) sur l'historique.
static func compliance() -> float:
	var processed: int = 0
	var correct: int = 0
	for entry: Dictionary in GameState.day_history:
		var row_correct: int = SaveService.as_int(entry.get("correct", 0))
		processed += SaveService.as_int(entry.get("processed", row_correct + SaveService.as_int(entry.get("errors", 0))))
		correct += row_correct
	return float(correct) / float(processed) if processed > 0 else 0.0


# --- M12 : épilogue J31 (D-122 → D-125) ------------------------------------------------

## Graine d'épilogue d'un emplacement terminé (`day_31.json`), vide sinon.
static func epilogue_seed_for_slot(slot: int, dir: String = SaveService.DEFAULT_DIR) -> Dictionary:
	return SaveService.load_epilogue(slot, dir)


## Graine d'épilogue du profil (`<fin>:<variante>`, Dossier › Épilogues).
static func epilogue_seed_from_profile(key: String, dir: String = SaveService.DEFAULT_DIR) -> Dictionary:
	return ProfileService.epilogue_seed(ProfileService.load_profile(dir), key)


## Prépare le J31 depuis une graine : session épilogue du `GameState` (matin
## du J31, rien n'est écrit) ; renvoie le `DayDef` du monde (à passer à
## `DayController.start_epilogue`), null si la graine ou les données manquent.
static func start_epilogue(epi: Dictionary, slot: int = SaveService.NO_SLOT, def: EpilogueDef = null) -> DayDef:
	var clean: Dictionary = EpilogueService.sanitize_seed(epi)
	if clean.is_empty():
		return null
	var day: DayDef = EpilogueService.day_for(clean, def)
	if day == null:
		push_warning("Campaign.start_epilogue: monde « %s » sans DayDef" % clean.get("world", ""))
		return null
	GameState.begin_epilogue(clean, slot)
	return day


## Fin du J31 : conclusion composée (`EpilogueService.conclusion`), épilogue
## vu au profil (nombre de fois, dernières lignes), personnages croisés, méta
## `epilogue_done` de l'emplacement d'origine. La session reste « épilogue »
## jusqu'à `GameState.end_session()` (retour au titre). Émet `epilogue_concluded`.
static func close_epilogue(summary: DaySummary, dir: String = SaveService.DEFAULT_DIR, def: EpilogueDef = null) -> Dictionary:
	if GameState.session_mode != GameState.SESSION_EPILOGUE:
		return {}
	var epi: Dictionary = GameState.epilogue_seed
	var warnings: int = summary.get_citation_count() if summary != null else 0
	var card: Dictionary = EpilogueService.conclusion(epi, GameState.narrative_flags, warnings, def)
	var lines: PackedStringArray = card.get("lines", PackedStringArray())
	var changed: bool = ProfileService.record_epilogue_played(dir, EpilogueService.profile_key(epi), lines, epi)
	if ProfileService.record(dir, "", 0, GameState.case_memory.keys()):
		changed = true
	if changed:
		EventBus.profile_changed.emit()
	if GameState.epilogue_slot != SaveService.NO_SLOT \
			and SaveService.mark_epilogue_done(GameState.epilogue_slot, dir) == OK:
		EventBus.save_slots_changed.emit()
	EventBus.epilogue_concluded.emit(card)
	return card


# --- M12 : Garde de nuit (D-126 → D-128) ------------------------------------------------

## Nouvelle garde sur un code (graine du jour `NUIT-AAAA-MM-JJ` ou code libre) :
## session Garde du `GameState` ; null si le code ou les données sont
## invalides. Le `DayController` la joue (`start_garde`).
static func start_garde(code: String, def: GardeDef = null, events: StationEventsDef = null) -> GardeRun:
	var run: GardeRun = GardeService.new_run(code, def, events)
	if run != null:
		GameState.begin_garde()
	return run


## Garde terminée (3 erreurs ou « Terminer la garde ») : records au profil,
## pastilles `{new_record, daily_record, first_try, rank}`.
static func finish_garde(run: GardeRun, dir: String = SaveService.DEFAULT_DIR) -> Dictionary:
	if run == null or not run.ended:
		return {}
	var badges: Dictionary = GardeService.record_run(run, dir)
	EventBus.profile_changed.emit()
	return badges
