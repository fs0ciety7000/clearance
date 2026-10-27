## EventBus — catalogue des signaux globaux (ARCHITECTURE §7, rév. 2).
##
## Ne déclare que des signaux typés : aucun état, aucune méthode métier.
## Convention : passé pour un fait (`*_started`, `*_stamped`), `*_requested`
## pour une intention de l'UI vers la logique.
##
## Typage provisoire (M1) : les classes du modèle (Case, Verdict…) arrivent en
## M2+. En attendant, les paramètres sont typés avec la classe de base la plus
## proche et marqués `# TODO(M2): <Type>` ; les enums sont des `int`.
## Pas de `class_name` (autoload, cf. ARCHITECTURE §4).
extends Node

# Les signaux sont émis par d'autres nœuds : l'avertissement est attendu ici.
@warning_ignore_start("unused_signal")

# --- Jour ---------------------------------------------------------------------

## DayController → HUD, Rulebook, Booth.
signal day_started(day: Resource, rulebook: Array[RefCounted]) # TODO(M2): day: DayDef, rulebook: Array[RulebookEntry]
## DayClock → HUD.
signal day_clock_ticked(remaining_sec: float)
## DayClock → DayController.
signal day_time_expired()
## DayController → UI résumé, GameState.
signal day_ended(summary: RefCounted) # TODO(M5): DaySummary
## DayController → UI, BoothDirector (debug).
signal day_phase_changed(phase: int, case_id: StringName) # TODO(M2): phase: DayPhase.Kind

# --- Passager -----------------------------------------------------------------

## UI (bouton « Suivant ») → DayController.
signal next_case_requested()
## DayController → BoothDirector, UI. Transporte `Case`, jamais `CaseKey`.
signal case_presented(case: RefCounted) # TODO(M2): Case
## BoothDirector → DayController.
signal passenger_arrived(case_id: StringName)
## BoothDirector (ou DayController sur timeout) → UI documents, InspectionSession.
signal documents_presented(case_id: StringName)
## UI → InspectionSession.
signal document_focused(doc: RefCounted) # TODO(M2): DocumentInstance
## InspectionSession / dialogue → BoothDirector.
signal passenger_reaction_triggered(reaction: int) # TODO(M2): PassengerReaction.Kind
## BoothDirector → DayController.
signal passenger_departed(case_id: StringName)
## BoothDirector (clic visage) → UI comparaison.
signal inspection_target_picked(ref: RefCounted) # TODO(M2): FieldRef

# --- Inspection / comparaison -------------------------------------------------

## UI → InspectionSession, Booth (FX).
signal inspection_mode_changed(enabled: bool)
## UI → InspectionSession.
signal discrepancy_check_requested(a: RefCounted, b: RefCounted) # TODO(M2): a: FieldRef, b: FieldRef
## InspectionSession → UI.
signal discrepancy_checked(result: RefCounted) # TODO(M2): Discrepancy
## UI → InspectionSession.
signal interrogation_requested(topic: StringName)
## InspectionSession → UI dialogue, Booth.
signal interrogation_answered(topic: StringName, line_key: String)

# --- Verdict / score ----------------------------------------------------------

## UI tampon → DayController.
signal verdict_stamped(verdict: RefCounted) # TODO(M2): Verdict
## DayController (via ScoringService) → HUD, BoothDirector.
signal case_resolved(case_id: StringName, result: RefCounted) # TODO(M5): CaseResult
## DayController → HUD.
signal citation_issued(reason_key: String)
## GameState → HUD.
signal credits_changed(credits: int, delta: int)

# --- Méta ---------------------------------------------------------------------

## GameState → systèmes narratifs.
signal narrative_flag_changed(flag: StringName, value: Variant)
## Settings → UI, audio, FX.
signal settings_changed(key: StringName, value: Variant)
## GameState → UI.
signal game_saved(slot: int)
## GameState → UI.
signal game_loaded(slot: int)
