## Machine à états du jour (ARCHITECTURE §8) — service de jour.
##
## `INTRO → WAITING_CASE → ARRIVING → INSPECTING → RESOLVING → DEPARTING →
## WAITING_CASE … → SUMMARY`. Construit les cas avec le `CaseBuilder` du jour,
## garde la clé de réponse (`CaseKey`, jamais transmise), note le verdict
## (`ScoringService`) et émet `day_started`, `day_phase_changed`,
## `case_presented`, `case_resolved`, `day_ended`.
## Robustesse (§7, §8 bis.6) : tout signal du booth d'un autre `case_id` ou
## hors de l'état attendu est ignoré ; des timeouts de sécurité font avancer
## le jour même sans booth (`SilentBooth`). Ils sont pilotés par `advance()`
## (appelé par `_process`, ou à la main dans les tests).
## M5 : notation complète (`ScoringService` : preuve, procédures, citations),
## rang de la citation du jour et amende, `citation_issued` après
## `case_resolved`, conséquences narratives des cas scénarisés
## (`ScriptedCaseDef.sets_flag` / `flags_on_*`), crédits et drapeaux appliqués
## au `GameState` si `apply_to_game_state`.
## M7 : objets glissés (`item_slipped` aux documents, décisions
## `item_decision_requested` → `item_decided`, décision par défaut au tampon),
## DÉTENTION seulement si `DayDef.detain_enabled` (sinon lue comme REFUS),
## conséquences narratives (`CaseConsequences` : verdict × objets × phrase de
## passe), mémoire des passagers scénarisés (`GameState.case_memory`), avis de
## recherche publiés au début du jour, annonces du Hall, drapeaux des cas
## scénarisés non traités (`flags_if_unprocessed`).
## Acte II (docs/ACT2.md M1, M3, B22–B35, ARCHITECTURE §7.2) : quota
## respiratoire (`QuotaTracker`, `quota_changed`, verdict souple du
## `ScoringService`, entrées imputées), ticket de file à l'heure de
## présentation (`CaseBuilder.presentation_minute`, horloge du shift), liste
## des révocations (`revocations_published`), scanner partiel
## (`scanner_suggested` aux documents), annonces conditionnelles ou horaires
## (`DayDef.announcements`) dont la fin anticipée du shift (grève du J20),
## `luciole_trust_on_breach`.
class_name DayController
extends Node

## `ARRIVING` sans `passenger_arrived` → `INSPECTING` + `push_warning`.
@export var arrive_timeout_sec: float = 15.0
## `INSPECTING` sans `documents_presented` → émis par le DayController.
@export var present_timeout_sec: float = 6.0
## `DEPARTING` sans `passenger_departed` → état suivant.
@export var depart_timeout_sec: float = 12.0

@export var clock: DayClock = null
@export var inspection: InspectionSession = null
## Applique crédits, citations et drapeaux au `GameState` au fil du shift.
@export var apply_to_game_state: bool = true

var data: DataCatalog = null
var day: DayDef = null
var builder: CaseBuilder = null
var phase: DayPhase.Kind = DayPhase.Kind.INTRO
var current_case: Case = null
var current_key: CaseKey = null
## Index du prochain cas à construire.
var next_index: int = 0
var summary: DaySummary = null
var time_expired: bool = false
## Nombre de timeouts de secours déclenchés (diagnostic, tests).
var timeouts_fired: int = 0
## Citations émises aujourd'hui (rang de la prochaine = +1).
var citations_today: int = 0
## Prime de détention (`EconomyDef.detain_bonus`).
var detain_bonus: int = ScoringService.DEFAULT_DETAIN_BONUS
## Cas scénarisé du cas courant (null sinon).
var current_scripted: ScriptedCaseDef = null
## Confiance minimale des Lucioles pour répondre à la phrase de passe (GDD §4.7).
const PASSWORD_TRUST: int = CaseConsequences.PASSWORD_TRUST
## Annonce du Hall quand le quota est atteint (Acte II).
const HALL_QUOTA_FULL: String = "hall_quota_full"

## Acte II : compteur du quota respiratoire du shift (R23).
var quota: QuotaTracker = QuotaTracker.new()
## Acte II : source du scanner partiel branché (`acv`, `luciole`), vide sinon.
var scanner_source: StringName = &""
## Acte II : le shift s'est arrêté sur une annonce (grève du J20).
var shift_ended_early: bool = false
var _fired_announcements: Array[int] = []

var _documents_presented: bool = false
## Temps passé dans la phase courante (timeouts).
var _phase_time: float = 0.0
var _started: bool = false


func _ready() -> void:
	EventBus.item_decision_requested.connect(_on_item_decision_requested)
	EventBus.next_case_requested.connect(_on_next_case_requested)
	EventBus.passenger_arrived.connect(_on_passenger_arrived)
	EventBus.documents_presented.connect(_on_documents_presented)
	EventBus.verdict_stamped.connect(_on_verdict_stamped)
	EventBus.passenger_departed.connect(_on_passenger_departed)
	EventBus.day_time_expired.connect(_on_day_time_expired)


## Prépare le jour `day_number` (phase INTRO) et émet `day_started`.
## `memory` : mémoire des passagers scénarisés (`CaseMemory.resolve`).
func start_day(p_data: DataCatalog, day_number: int, day_seed: int, flags: Array[StringName] = [],
		memory: Dictionary = {}) -> bool:
	data = p_data
	day = data.get_day(day_number) if data != null else null
	if day == null:
		push_error("DayController: jour %d introuvable" % day_number)
		return false
	builder = CaseBuilder.new(data, day, day_seed, flags, memory, flag_values())
	summary = DaySummary.new()
	summary.day_number = day.day_number
	summary.planned_cases = day.passenger_count
	next_index = 0
	time_expired = false
	timeouts_fired = 0
	citations_today = 0
	current_case = null
	current_key = null
	current_scripted = null
	detain_bonus = data.get_economy().detain_bonus
	quota = QuotaTracker.for_day(day)
	quota.sync(builder.ctx)
	scanner_source = PartialScanner.source_for(builder.get_flag_values())
	shift_ended_early = false
	_fired_announcements.clear()
	_started = true
	if clock != null:
		clock.setup(day.duration_sec)
	_set_phase(DayPhase.Kind.INTRO, &"")
	EventBus.day_started.emit(day, day.rule_set.build_rulebook())
	EventBus.wanted_notices_published.emit(builder.get_wanted_notices())
	EventBus.revocations_published.emit(builder.get_revocations())
	EventBus.quota_changed.emit(quota.used, quota.maximum if quota.is_active() else 0)
	return true


## Heure du shift (minutes depuis minuit), 10:00 sans horloge.
func current_minute() -> int:
	return clock.current_minute() if clock != null else DayDef.SHIFT_START_MIN


## L'intro du jour est fermée : le shift commence (horloge lancée).
func close_intro() -> void:
	if not _started or phase != DayPhase.Kind.INTRO:
		return
	if clock != null:
		clock.start()
	_set_phase(DayPhase.Kind.WAITING_CASE, &"")


func get_rule_context() -> RuleContext:
	return builder.ctx if builder != null else null


func has_remaining_cases() -> bool:
	return day != null and next_index < day.passenger_count


func current_case_id() -> StringName:
	return current_case.case_id if current_case != null else &""


func _process(delta: float) -> void:
	advance(delta)


## Avance les timeouts de sécurité de `delta` secondes.
func advance(delta: float) -> void:
	if not _started:
		return
	_phase_time += delta
	_check_timed_announcements()
	match phase:
		DayPhase.Kind.ARRIVING:
			if _phase_time >= arrive_timeout_sec:
				push_warning("DayController: timeout ARRIVING (%s)" % current_case_id())
				timeouts_fired += 1
				_enter_inspecting()
		DayPhase.Kind.INSPECTING:
			if not _documents_presented and _phase_time >= present_timeout_sec:
				push_warning("DayController: timeout documents_presented (%s)" % current_case_id())
				timeouts_fired += 1
				# Seul cas où un autre émetteur que le booth émet ce signal (§7).
				EventBus.documents_presented.emit(current_case_id())
		DayPhase.Kind.DEPARTING:
			if _phase_time >= depart_timeout_sec:
				push_warning("DayController: timeout DEPARTING (%s)" % current_case_id())
				timeouts_fired += 1
				_finish_departure()


func _on_next_case_requested() -> void:
	if phase != DayPhase.Kind.WAITING_CASE or not has_remaining_cases():
		return
	# Acte II (R29) : heure de présentation imprimée sur le ticket de file.
	builder.presentation_minute = current_minute()
	var generated: GeneratedCase = builder.build(next_index)
	next_index += 1
	if generated == null or generated.case == null:
		push_error("DayController: cas %d impossible à construire" % (next_index - 1))
		_after_case()
		return
	current_case = generated.case
	current_key = generated.key
	current_scripted = builder.get_scripted_case(current_case.index) if generated.scripted_id != &"" else null
	_documents_presented = false
	if inspection != null:
		inspection.begin(current_case, builder.ctx)
		inspection.luciole_reply_allowed = current_case.dialogue_tags.has(CaseBuilder.TAG_LUCIOLE_PASSWORD) \
				and FlagCondition.gauge_value(flag_values(), CaseConsequences.FLAG_TRUST) >= PASSWORD_TRUST
	# Phase posée avant l'émission : un écouteur synchrone voit ARRIVING.
	phase = DayPhase.Kind.ARRIVING
	_phase_time = 0.0
	EventBus.case_presented.emit(current_case)
	EventBus.day_phase_changed.emit(DayPhase.Kind.ARRIVING, current_case.case_id)


func _on_passenger_arrived(case_id: StringName) -> void:
	if phase != DayPhase.Kind.ARRIVING or case_id != current_case_id():
		return
	_enter_inspecting()


func _enter_inspecting() -> void:
	_set_phase(DayPhase.Kind.INSPECTING, current_case_id())


func _on_documents_presented(case_id: StringName) -> void:
	if case_id != current_case_id() or _documents_presented:
		return
	if phase == DayPhase.Kind.INSPECTING or phase == DayPhase.Kind.ARRIVING:
		_documents_presented = true
		for item: SlippedItem in current_case.slipped_items:
			EventBus.item_slipped.emit(item)
		if scanner_source != &"":
			EventBus.scanner_suggested.emit(case_id, PartialScanner.suggestions(current_case, builder.ctx), scanner_source)


## Décision de l'UI sur un objet glissé du cas courant (modifiable jusqu'au tampon).
func _on_item_decision_requested(item_id: StringName, decision: SlippedItem.Decision) -> void:
	if phase != DayPhase.Kind.INSPECTING or current_case == null:
		return
	var item: SlippedItem = current_case.get_item(item_id)
	if item == null or not item.is_allowed(decision):
		return
	item.decision = decision
	EventBus.item_decided.emit(item, decision)


func _on_verdict_stamped(verdict: Verdict) -> void:
	# Garde logique : le tampon n'est accepté qu'en INSPECTING (pas seulement côté UI).
	if phase != DayPhase.Kind.INSPECTING or verdict == null:
		return
	if verdict.case_id != &"" and verdict.case_id != current_case_id():
		return
	verdict.case_id = current_case_id()
	if verdict.kind == VerdictKind.Kind.DETAIN and not day.detain_enabled:
		verdict.kind = VerdictKind.Kind.DENY
	_set_phase(DayPhase.Kind.RESOLVING, current_case_id())
	if inspection != null:
		inspection.end(verdict)
	var quota_full: bool = quota.before_verdict(current_case)
	var result: CaseResult = ScoringService.score(verdict, current_key, current_case_id(), current_case, day, detain_bonus,
			quota_full)
	result.quota_counted = quota.counts(current_case)
	var was_full: bool = quota.is_full()
	result.quota_overrun = quota.after_verdict(current_case, verdict.kind)
	quota.sync(builder.ctx)
	result.passenger_label = _passenger_label(current_case)
	if result.has_citation():
		citations_today += 1
		ScoringService.apply_citation(result, citations_today, day)
	_resolve_items(result)
	result.password_answered = inspection != null and inspection.luciole_replied
	_apply_narrative(result)
	summary.add_result(result)
	if apply_to_game_state:
		GameState.add_credits(result.credits_delta + result.bribe_credits + result.report_credits)
		GameState.score_total += result.wage
		if result.has_citation():
			GameState.add_citation()
		for flag: StringName in result.narrative_changes:
			GameState.set_flag(flag, result.narrative_changes[flag])
		if current_scripted != null:
			GameState.remember_case(current_scripted.id, CaseMemory.snapshot(day.day_number, current_case, result.verdict_kind))
	EventBus.case_resolved.emit(current_case_id(), result)
	if result.has_citation():
		EventBus.citation_issued.emit(result.citation_reason_key)
	if quota.is_active():
		EventBus.quota_changed.emit(quota.used, quota.maximum)
		if quota.is_full() and not was_full:
			EventBus.hall_announced.emit(HALL_QUOTA_FULL)
	var announcement: String = day.hall_announcements.get(summary.results.size(), "")
	if not announcement.is_empty():
		EventBus.hall_announced.emit(announcement)
	_check_case_announcements(summary.results.size())
	_set_phase(DayPhase.Kind.DEPARTING, current_case_id())


## Objets glissés au tampon : décision par défaut pour les objets non tranchés
## (refus automatique, `item_decided` émis), crédits gardés / primes.
func _resolve_items(result: CaseResult) -> void:
	for item: SlippedItem in current_case.slipped_items:
		if not item.is_decided():
			item.decision = item.default_decision
			EventBus.item_decided.emit(item, item.decision)
		result.item_decisions[item.id] = item.decision
		var credits: int = item.credits_for(item.decision)
		if item.decision == SlippedItem.Decision.REPORT:
			result.report_credits += credits
		else:
			result.bribe_credits += credits


## Drapeaux narratifs courants (vides hors `GameState`).
func flag_values() -> Dictionary[StringName, Variant]:
	if apply_to_game_state:
		return GameState.narrative_flags
	var empty: Dictionary[StringName, Variant] = {}
	return empty


## Conséquences narratives d'un cas scénarisé (GDD §12) : `sets_flag` dès le
## traitement, puis `flags_on_approve` / `flags_on_deny` selon le verdict
## (delta ajouté aux jauges ; 0 = drapeau mis à vrai).
func _apply_narrative(result: CaseResult) -> void:
	if current_scripted != null:
		result.scripted_id = current_scripted.id
	result.narrative_changes = CaseConsequences.compute(current_scripted, current_case, result.verdict_kind,
			not current_key.expected_violations.is_empty(), result.password_answered, day.day_number, flag_values(),
			result.luciole_report, shift_contexts(current_case, result), day.luciole_trust_on_breach)


## Acte II : contexte du shift d'un verdict (`CaseEffectDef.context`).
func shift_contexts(case: Case, result: CaseResult) -> Array[StringName]:
	return CaseConsequences.contexts_for(day, case, result)


## Annonces après le n-ième cas (`DayDef.announcements`, conditionnelles) ;
## une annonce `ends_shift` arrête le shift après le passager en cours.
func _check_case_announcements(processed: int) -> void:
	for i: int in day.announcements.size():
		var def: HallAnnouncementDef = day.announcements[i]
		if def == null or def.after_case != processed or _fired_announcements.has(i):
			continue
		if not FlagCondition.check(def.condition, flag_values()):
			continue
		_fired_announcements.append(i)
		EventBus.hall_announced.emit(def.text_key)
		if def.ends_shift:
			shift_ended_early = true


## Annonces à heure fixe (`at_minute`, couvre-feu de 16:00 au J16), shift en cours.
func _check_timed_announcements() -> void:
	if day == null or clock == null or not clock.running:
		return
	var minute: int = clock.current_minute()
	for i: int in day.announcements.size():
		var def: HallAnnouncementDef = day.announcements[i]
		if def == null or def.at_minute < 0 or minute < def.at_minute or _fired_announcements.has(i):
			continue
		_fired_announcements.append(i)
		if FlagCondition.check(def.condition, flag_values()):
			EventBus.hall_announced.emit(def.text_key)


static func _passenger_label(case: Case) -> String:
	return case.passenger_presented.short_label() if case != null and case.passenger_presented != null else ""


func _on_passenger_departed(case_id: StringName) -> void:
	if phase != DayPhase.Kind.DEPARTING or case_id != current_case_id():
		return
	_finish_departure()


func _finish_departure() -> void:
	current_case = null
	current_key = null
	current_scripted = null
	_after_case()


## Après un cas : cas suivant, ou bilan si le temps est écoulé / la file vide.
func _after_case() -> void:
	if time_expired or shift_ended_early or not has_remaining_cases():
		_end_day()
	else:
		_set_phase(DayPhase.Kind.WAITING_CASE, &"")


func _on_day_time_expired() -> void:
	if not _started:
		return
	time_expired = true
	if phase == DayPhase.Kind.WAITING_CASE:
		_end_day()


func _end_day() -> void:
	if phase == DayPhase.Kind.SUMMARY:
		return
	if clock != null:
		clock.stop()
	summary.time_expired = time_expired
	# Cas scénarisés restés dans la file (SC-22 : `final_unprocessed`).
	for scripted: ScriptedCaseDef in builder.get_active_scripted_cases():
		if scripted.at_index >= next_index and not scripted.flags_if_unprocessed.is_empty():
			CaseConsequences.add_all(summary.unprocessed_changes, flag_values(), scripted.flags_if_unprocessed)
	if apply_to_game_state:
		for flag: StringName in summary.unprocessed_changes:
			GameState.set_flag(flag, summary.unprocessed_changes[flag])
	_set_phase(DayPhase.Kind.SUMMARY, &"")
	EventBus.day_ended.emit(summary)


func _set_phase(p_phase: DayPhase.Kind, case_id: StringName) -> void:
	phase = p_phase
	_phase_time = 0.0
	EventBus.day_phase_changed.emit(p_phase, case_id)
