## EventBus — catalogue des signaux globaux (ARCHITECTURE §7, rév. 2).
##
## Ne déclare que des signaux typés : aucun état, aucune méthode métier.
## Convention : passé pour un fait (`*_started`, `*_stamped`), `*_requested`
## pour une intention de l'UI vers la logique.
##
## Typage : classes du modèle (`Case`, `DayDef`, `FieldRef`…). `CaseResult` et
## `DaySummary` sont typés depuis M4 (contenu minimal, enrichi en M5).
## Pas de `class_name` (autoload, cf. ARCHITECTURE §4).
extends Node

# Les signaux sont émis par d'autres nœuds : l'avertissement est attendu ici.
@warning_ignore_start("unused_signal")

# --- Jour ---------------------------------------------------------------------

## DayController → HUD, Rulebook, Booth.
signal day_started(day: DayDef, rulebook: Array[RulebookEntry])
## DayClock → HUD.
signal day_clock_ticked(remaining_sec: float)
## DayClock → DayController.
signal day_time_expired()
## DayController → UI résumé, GameState.
signal day_ended(summary: DaySummary)
## DayController → UI, BoothDirector (debug).
signal day_phase_changed(phase: DayPhase.Kind, case_id: StringName)

# --- Passager -----------------------------------------------------------------

## UI (bouton « Suivant ») → DayController.
signal next_case_requested()
## DayController → BoothDirector, UI. Transporte `Case`, jamais `CaseKey`.
signal case_presented(case: Case)
## BoothDirector → DayController.
signal passenger_arrived(case_id: StringName)
## BoothDirector (ou DayController sur timeout) → UI documents, InspectionSession.
signal documents_presented(case_id: StringName)
## UI → InspectionSession.
signal document_focused(doc: DocumentInstance)
## InspectionSession / dialogue → BoothDirector.
signal passenger_reaction_triggered(reaction: PassengerReaction.Kind)
## BoothDirector → DayController.
signal passenger_departed(case_id: StringName)
## BoothDirector (clic visage) → UI comparaison.
signal inspection_target_picked(ref: FieldRef)

# --- Inspection / comparaison -------------------------------------------------

## UI → InspectionSession, Booth (FX).
signal inspection_mode_changed(enabled: bool)
## UI → InspectionSession.
signal discrepancy_check_requested(a: FieldRef, b: FieldRef)
## InspectionSession → UI.
signal discrepancy_checked(result: Discrepancy)
## UI → InspectionSession.
signal interrogation_requested(topic: StringName)
## InspectionSession → UI dialogue, Booth.
signal interrogation_answered(topic: StringName, line_key: String)

# --- Verdict / score ----------------------------------------------------------

## UI tampon → DayController.
signal verdict_stamped(verdict: Verdict)
## DayController (via ScoringService) → HUD, BoothDirector.
signal case_resolved(case_id: StringName, result: CaseResult)
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
