## EventBus — catalogue des signaux globaux (ARCHITECTURE §7, rév. 3.6 : 36 signaux,
## émetteurs / écouteurs réels ; Acte III : `ledger_changed`, `summons_published`).
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
## M7 — DayController (après `day_started`) → Rulebook (onglet Avis de recherche).
signal wanted_notices_published(notices: Array[WantedNotice])
## M7 — DayController (après le n-ième cas, `DayDef.hall_announcements`) → UI, audio.
signal hall_announced(text_key: String)
## Acte II — DayController (début du jour, après chaque tampon) → barre d'état
## (compteur `QUOTA used/max`, « QUOTA ATTEINT » quand `used >= maximum`).
## `maximum = 0` : pas de quota ce jour.
signal quota_changed(used: int, maximum: int)
## Acte II — DayController (après `day_started`) → Rulebook (onglet Révocations, R30).
signal revocations_published(entries: Array[RevokedEntry])
## Acte II — DayController (aux documents, si un scanner partiel est branché)
## → plan de travail : liens suggérés (pointillés) à confirmer d'un clic
## (`discrepancy_check_requested`). `source` : `acv` (Consortium) ou `luciole`.
signal scanner_suggested(case_id: StringName, links: Array[Discrepancy], source: StringName)
## Acte III — DayController (début du jour, puis après chaque tampon qui
## inscrit un répondant) → Rulebook (onglet Main courante, R34). Liste
## complète, dans l'ordre d'admission ; vide avant le J24.
signal ledger_changed(entries: Array[LedgerEntry])
## Acte III — DayController (après `revocations_published`, chaque jour) →
## Rulebook (onglet Convocations, R36) ; vide avant le J26.
signal summons_published(entries: Array[SummonsEntry])

# --- Passager -----------------------------------------------------------------

## UI (bouton « Suivant ») → DayController.
signal next_case_requested()
## DayController → BoothDirector, UI. Transporte `Case`, jamais `CaseKey`.
signal case_presented(case: Case)
## BoothDirector → DayController.
signal passenger_arrived(case_id: StringName)
## BoothDirector (ou DayController sur timeout) → UI documents, InspectionSession.
signal documents_presented(case_id: StringName)
## UI (`ComparisonUI`, document mis au premier plan) → aucun écouteur à ce
## jour (diagnostic, tests ; réservé au focus des sons / du booth).
signal document_focused(doc: DocumentInstance)
## InspectionSession / dialogue → BoothDirector.
signal passenger_reaction_triggered(reaction: PassengerReaction.Kind)
## BoothDirector → DayController.
signal passenger_departed(case_id: StringName)
## BoothDirector (clic visage) → UI comparaison.
signal inspection_target_picked(ref: FieldRef)
## M7 — DayController (avec les documents) → UI plan de travail, booth.
signal item_slipped(item: SlippedItem)
## M7 — UI (GARDER / RENDRE / REMETTRE À LA GARDE) → DayController.
signal item_decision_requested(item_id: StringName, decision: SlippedItem.Decision)
## M7 — DayController → UI, booth (aussi au tampon pour une décision par défaut).
signal item_decided(item: SlippedItem, decision: SlippedItem.Decision)

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
## M11 (D-101) GameState → écrans Nouvelle partie / Charger : un emplacement a
## été écrit, archivé (fin) ou vidé.
signal save_slots_changed()
## M11 (D-101) GameState → UI : `profile.json` a changé (fin vue, personnage
## croisé, mode Récit utilisé).
signal profile_changed()
## M11 (D-102) GameState → DayController, HUD : passage Récit → Dur.
signal difficulty_changed(difficulty: StringName)
## M11 lot C — RulebookPanel → tutoriel du J1 (`TutorialOverlay`) : le joueur
## a consulté le Rulebook (onglet changé, panneau déplié, carte sélectionnée).
signal rulebook_consulted()

# --- M12 « Rejouabilité » (ARCHITECTURE §11.2) ----------------------------------

## M12 (B54) — DayController (au passager suivant, quand des changements en
## attente ont été appliqués : directive de Garde, rotation, événement de
## station) → Rulebook (lignes actives, NOUVEAU, lignes barrées :
## `diff.rulebook`, `diff.retired_entries`), générateur (`CaseBuilder`).
signal rules_changed(diff: RuleDiff)
## M12 (B58) — DayController (annonce, après le passager en cours ; l'effet
## commence au suivant) → bandeau ÉVÉNEMENT, ligne Rulebook, booth, audio.
signal station_event_started(event: StationEventPlan)
## M12 (B58) — DayController (fin de fenêtre, ou avant un cas scénarisé) → UI.
signal station_event_ended(event: StationEventPlan)
## M12 (B58) — DayController → Rulebook : liste nommée publiée (`stolen` :
## onglet « Cartes volées », EV-07) ; vide = retirée.
signal rule_list_published(label: StringName, entries: Array[RevokedEntry])
## M12 (B57) — DayController (mode garde, après le passager qui déclenche la
## directive) → carte « DIRECTIVE DE GARDE N° n » avant le passager suivant.
## `action` : `add`, `retire` (rotation), `restore`.
signal garde_directive(number: int, unit_id: StringName, action: StringName)
## M12 (B57) — DayController (mode garde, après chaque verdict) → HUD de Garde.
signal garde_scored(score: int, points: int)
## M12 (B57) — DayController (mode garde, verdict cité) → HUD (voyants), fin.
signal garde_error(case_id: StringName, citation_key: String, errors: int)
## M12 (B57) — DayController (mode garde) → HUD : palier atteint (0 → 4).
signal garde_tier_changed(tier: int)
## M12 (B57) — DayController (3ᵉ erreur ou « Terminer la garde ») → écran de
## fin de garde (`GardeRun.to_record()` ; records : `Campaign.finish_garde`).
signal garde_ended(record: Dictionary)
## M12 (B52) — Campaign.close_epilogue → carte de conclusion du J31.
signal epilogue_concluded(card: Dictionary)

# --- M13 « Gameplay » (ARCHITECTURE §12.8) --------------------------------------

## M13 (B64, B68) — InspectionSession (réponse à une question porteuse de
## puces, juste après `interrogation_answered`) → journal de dialogue (puces
## sélectionnables), intercom. `statements` : les puces de cette réponse
## (`Statement.given` déjà vrai).
signal statement_given(case_id: StringName, statements: Array[Statement])
## M13 (B70) — UI → InspectionSession : `z1` … `z5` (scanner une zone),
## `all` (TOUT SCANNER), `confirm` / `cancel` (confirmation « sans motif »),
## `close` (refermer la silhouette).
signal search_requested(zone: StringName)
## M13 (B70) — InspectionSession → UI : la demande de fouille n'a **aucun
## motif** ; afficher la confirmation (`ConfirmDialog`, focus sur ANNULER)
## puis émettre `search_requested(&"confirm")` ou `(&"cancel")`.
signal search_confirmation_required(case_id: StringName)
## M13 (B70) — InspectionSession → UI (silhouette, bandeau MOTIF), booth (bras
## levés, cadre), audio, intercom : le portique est engagé ; `motive` figé à la
## demande (`SearchLayout.MOTIVE_*`, `&""` = fouille sans motif confirmée).
signal search_opened(case_id: StringName, motive: StringName)
## M13 (B70) — InspectionSession → UI (liste d'objets, « RAS » si vide), audio :
## une zone a fini son scan (après sa durée).
signal search_zone_scanned(case_id: StringName, zone: StringName, items: Array[SearchItem])
## M13 (B70) — InspectionSession → UI (la File revient), booth, intercom.
signal search_closed(case_id: StringName)
## M13 (B68, B70) — InspectionSession → UI : l'interface est occupée `duration_sec`
## secondes (horloge réelle : question 3 s, confrontation 4 s, activation et
## zones du portique) ; `action` : `question`, `confront`, `repeat`,
## `search_activation`, `search_zone`.
signal inspection_busy(case_id: StringName, duration_sec: float, action: StringName)
## M13 (B74) — Campaign / EveningService (achat confirmé le soir) → UI
## (colonne Économat, pastilles du guichet), audio.
signal upgrade_purchased(upgrade_id: StringName)
