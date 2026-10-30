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
## Acte III (docs/ACT3.md M2, B41–B43, ARCHITECTURE §7.3) : Main courante
## tenue au fil du shift (`CaseBuilder.record_verdict`, `ledger_changed`),
## convocations du jour (`summons_published`), quota suspendu selon le climat
## (`DayDef.quota_suspended_if`), annonces horaires au début du shift.
## M11, mode Récit (D-102, `story_mode`, lu dans `GameState` au début du jour) :
## l'horloge ne termine pas le shift (`DayClock.untimed`) — il finit quand la
## file prévue est traitée, ou par `close_booth()` une fois le quota atteint ;
## amendes à 0 ₵ (`CaseResult.waive_fine`), citations comptées. Passage Récit →
## Dur en cours de shift : `EventBus.difficulty_changed`.
## M12 (ARCHITECTURE §11) : le shift travaille sur une **copie** du `DayDef`
## et de son RuleSet (`DayDef.make_shift_copy`) — règles mutables en cours de
## shift (B54) : changements en attente appliqués juste avant de construire
## le passager suivant (`RuleContext.apply_pending`, `rules_changed`), jamais
## sur le passager à la vitre. Pseudo-drapeaux `cm_*` au matin (B59).
## **Événements de station** (B58, D-129) : plan du jour
## (`StationEventService`, campagne) ou de la garde ; annonce après un
## passager, effet au suivant, fin de fenêtre, clôture avant un cas
## scénarisé (surcharges suspendues pendant un cas scénarisé), effets du
## contrôleur (prime, avertissements, comparateur, horloge gelée, file
## allongée). **Modes** (`mode`) : `campaign`, `epilogue` (J31 :
## `start_epilogue`, sans économie ni chrono, B52) et `garde` (Garde de nuit :
## `start_garde`, `GardeRun`, file sans fin, directives tous les 5 passagers,
## fin à 3 erreurs ou `request_end_garde`, B57).
## M13 (ARCHITECTURE §12) : la session reçoit les coûts en temps
## (`EconomyDef.get_interrogation_timing`) et les améliorations possédées
## (drapeaux du matin `upg_*`) ; au tampon, conséquences de la fouille :
## jauge `fouille_abus` (fouille sans motif), relevé du PH-2 (AG-03 :
## `suspicion +1` à l'approbation après une trouvaille interdite),
## `ScriptedCaseDef.flags_on_search` (lot B). Requêtes `statements_active()`,
## `search_available()` (cartes d'aide des tutoriels M13, lot C).
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
## M13 (D-168) : prime de relevé (`EconomyDef.finding_bonus`).
var finding_bonus: int = 0
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
## M11 (D-102) : mode Récit pour ce shift (pas de fin à l'heure, 0 ₵ d'amende).
var story_mode: bool = false
## M11 : guichet fermé par le joueur (Récit, quota atteint) : fin après le cas.
var booth_closed: bool = false
var _fired_announcements: Array[int] = []

## M12 : mode du shift (`DayDef.MODE_CAMPAIGN`, `MODE_EPILOGUE`, `MODE_GARDE`).
var mode: StringName = DayDef.MODE_CAMPAIGN
## M12 (B58) : événements de station du shift (campagne : au plus un par jour).
var station_events: Array[StationEventPlan] = []
## M12 (B58) : événements de station en campagne (faux : aucun, tests, outils).
@export var station_events_enabled: bool = true
## M12 (B57) : garde en cours (mode garde).
var garde_run: GardeRun = null
## M12 : garde terminée (3 erreurs ou « Terminer la garde ») : fin après le passager.
var garde_over: bool = false

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
	EventBus.difficulty_changed.connect(_on_difficulty_changed)


## Prépare le jour `day_number` (phase INTRO) et émet `day_started`.
## `memory` : mémoire des passagers scénarisés (`CaseMemory.resolve`).
## M12 : événement de station du jour (campagne, `GameState` appliqué,
## `station_events_enabled`), copie de shift du jour.
func start_day(p_data: DataCatalog, day_number: int, day_seed: int, flags: Array[StringName] = [],
		memory: Dictionary = {}) -> bool:
	data = p_data
	var source: DayDef = data.get_day(day_number) if data != null else null
	if source == null:
		push_error("DayController: jour %d introuvable" % day_number)
		return false
	mode = DayDef.MODE_CAMPAIGN
	garde_run = null
	var plans: Array[StationEventPlan] = []
	if apply_to_game_state and station_events_enabled and GameState.is_campaign_session():
		var events_def: StationEventsDef = StationEventService.load_def()
		if events_def != null:
			var plan: StationEventPlan = StationEventService.plan_for_day(GameState.campaign_seed, events_def, data.days, day_number)
			if plan != null:
				plans.append(plan)
	return _begin(source, day_seed, flags, memory, plans)


## M12 (B52) : J31 « Un an plus tard » sur le `DayDef` du monde
## (`Campaign.start_epilogue`) : sans économie ni chrono (D-123), fin à la
## file vide, aucun événement de station. `day_seed` :
## `EpilogueService.day_seed(graine)`.
func start_epilogue(p_data: DataCatalog, world_day: DayDef, day_seed: int, flags: Array[StringName] = [],
		memory: Dictionary = {}) -> bool:
	data = p_data
	if world_day == null:
		push_error("DayController: monde d'épilogue sans DayDef")
		return false
	mode = DayDef.MODE_EPILOGUE
	garde_run = null
	var plans: Array[StationEventPlan] = []
	return _begin(world_day, day_seed, flags, memory, plans)


## M12 (B57) : Garde de nuit (`Campaign.start_garde`) : jour de shift tiré du
## gabarit (`GardeService.make_day`), file sans fin, socle de règles, puis
## directives, paliers et événements du `GardeRun`.
func start_garde(p_data: DataCatalog, run: GardeRun) -> bool:
	data = p_data
	if run == null or run.def == null:
		push_error("DayController: garde sans données")
		return false
	mode = DayDef.MODE_GARDE
	garde_run = run
	var plans: Array[StationEventPlan] = []
	var flags: Array[StringName] = []
	return _begin(GardeService.make_day(run.def, run), run.queue_seed, flags, {}, plans)


func _begin(source: DayDef, day_seed: int, flags: Array[StringName], memory: Dictionary,
		plans: Array[StationEventPlan]) -> bool:
	# Copie de shift (B54) : RuleSet mutable, champs réglables pour ce shift.
	day = source if source.rule_set != null and source.rule_set.is_shift_copy else source.make_shift_copy()
	if mode != DayDef.MODE_CAMPAIGN:
		day.economy_disabled = day.economy_disabled or mode == DayDef.MODE_GARDE
	station_events = plans
	for plan: StationEventPlan in station_events:
		day.free_citations_per_day += plan.free_citations_bonus
	# Pseudo-drapeaux de verdict `cm_*` (B59), lus au matin par le générateur.
	var remembered: Dictionary = GameState.case_memory if apply_to_game_state and mode != DayDef.MODE_GARDE else memory
	var morning: Dictionary[StringName, Variant] = CaseMemory.with_pseudo_flags(flag_values(), remembered)
	var true_flags: Array[StringName] = flags.duplicate()
	for flag: StringName in CaseMemory.pseudo_flag_names(remembered):
		if not true_flags.has(flag):
			true_flags.append(flag)
	builder = CaseBuilder.new(data, day, day_seed, true_flags, memory, morning)
	# Mutation portée par un cas scénarisé (SC-89a : `rule_replacements`) : le
	# shift suit le jour du générateur (même copie, même RuleSet que `ctx`).
	day = builder.day
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
	finding_bonus = data.get_economy().finding_bonus
	quota = QuotaTracker.for_day(day, builder.get_flag_values())
	quota.sync(builder.ctx)
	scanner_source = PartialScanner.source_for(builder.get_flag_values()) if mode == DayDef.MODE_CAMPAIGN else &""
	shift_ended_early = false
	booth_closed = false
	garde_over = false
	story_mode = apply_to_game_state and mode == DayDef.MODE_CAMPAIGN and GameState.is_story_mode()
	_fired_announcements.clear()
	_started = true
	if clock != null:
		clock.setup(day.duration_sec)
		clock.untimed = story_mode or day.untimed or mode != DayDef.MODE_CAMPAIGN
	_set_phase(DayPhase.Kind.INTRO, &"")
	EventBus.day_started.emit(day, day.rule_set.build_rulebook())
	EventBus.wanted_notices_published.emit(builder.get_wanted_notices())
	EventBus.revocations_published.emit(builder.get_revocations())
	EventBus.summons_published.emit(builder.get_summons())
	EventBus.ledger_changed.emit(builder.get_ledger())
	EventBus.quota_changed.emit(quota.used, quota.maximum if quota.is_active() else 0)
	return true


## Vrai si le shift n'a aucune économie (J31, Garde, D-123).
func is_economy_disabled() -> bool:
	return day != null and (day.economy_disabled or mode != DayDef.MODE_CAMPAIGN)


## Heure du shift (minutes depuis minuit), 10:00 sans horloge ; Garde :
## horloge cosmétique (22:00 + 6 min par passager).
func current_minute() -> int:
	if mode == DayDef.MODE_GARDE and garde_run != null:
		return garde_run.clock_minute()
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
	if mode == DayDef.MODE_GARDE:
		return day != null and not garde_over and next_index < day.passenger_count
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
	_advance_station_events(delta)
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
	# M12 (B54, D-129) : changements en attente appliqués avant ce passager ;
	# un cas scénarisé est jugé sur les règles de sa conception.
	_prepare_rules_for(next_index)
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
		inspection.configure(data.get_economy().get_interrogation_timing() if data != null else null,
				builder.get_flag_values())
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
			quota_full, finding_bonus)
	_apply_shift_modifiers_before_citation(result)
	result.quota_counted = quota.counts(current_case)
	var was_full: bool = quota.is_full()
	result.quota_overrun = quota.after_verdict(current_case, verdict.kind)
	quota.sync(builder.ctx)
	# Acte III (R34) : un répondant approuvé entre à la Main courante.
	var ledger_entry: LedgerEntry = builder.record_verdict(current_case, verdict.kind)
	result.passenger_label = _passenger_label(current_case)
	if result.has_citation():
		citations_today += 1
		ScoringService.apply_citation(result, citations_today, day)
		if builder.ctx.modifier(RuleChangeDef.MOD_NO_FREE_CITATIONS) > 0 and result.fine == 0:
			# EV-04 : inspection, aucun avertissement gratuit.
			result.fine = maxi(day.penalty_per_error, 0)
			result.credits_delta = result.wage - result.fine
		if story_mode or is_economy_disabled():
			result.waive_fine()
	if result.correct and builder.ctx.modifier(RuleChangeDef.MOD_CORRECT_BONUS) > 0 and not is_economy_disabled():
		# EV-04 : prime d'assiduité par verdict juste.
		result.wage += builder.ctx.modifier(RuleChangeDef.MOD_CORRECT_BONUS)
		result.credits_delta += builder.ctx.modifier(RuleChangeDef.MOD_CORRECT_BONUS)
	if is_economy_disabled():
		result.wage = 0
		result.credits_delta = 0
	_resolve_items(result)
	result.password_answered = inspection != null and inspection.luciole_replied
	_apply_narrative(result)
	_apply_search_consequences(result)
	summary.add_result(result)
	if apply_to_game_state and mode != DayDef.MODE_GARDE:
		if not is_economy_disabled():
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
	if ledger_entry != null:
		EventBus.ledger_changed.emit(builder.get_ledger())
	var announcement: String = day.hall_announcements.get(summary.results.size(), "")
	if not announcement.is_empty():
		EventBus.hall_announced.emit(announcement)
	_check_case_announcements(summary.results.size())
	if mode == DayDef.MODE_GARDE:
		_after_garde_case(result)
	_update_station_events(summary.results.size())
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
	if apply_to_game_state and mode != DayDef.MODE_GARDE:
		return GameState.narrative_flags
	var empty: Dictionary[StringName, Variant] = {}
	return empty


## Conséquences narratives d'un cas scénarisé (GDD §12) : `sets_flag` dès le
## traitement, puis `flags_on_approve` / `flags_on_deny` selon le verdict
## (delta ajouté aux jauges ; 0 = drapeau mis à vrai).
func _apply_narrative(result: CaseResult) -> void:
	if current_scripted != null:
		result.scripted_id = current_scripted.id
	# M13 : les `flags_on_search` sont posés pendant le cas, donc **avant** les
	# effets du verdict (SC-106, SC-108 : `extra_effects` conditionnés à
	# `sc10N_searched`) ; `flag_values()` n'est jamais modifié.
	var flags: Dictionary[StringName, Variant] = flag_values()
	var search_changes: Dictionary[StringName, Variant] = search_flag_changes(result.verdict, flags)
	if not search_changes.is_empty():
		flags = flags.duplicate()
		CaseConsequences.merge_into(flags, search_changes)
	result.narrative_changes = CaseConsequences.compute(current_scripted, current_case, result.verdict_kind,
			not current_key.expected_violations.is_empty(), result.password_answered, day.day_number, flags,
			result.luciole_report, shift_contexts(current_case, result), day.luciole_trust_on_breach,
			day.admission_gauges)
	for flag: StringName in search_changes:
		if not result.narrative_changes.has(flag):
			result.narrative_changes[flag] = search_changes[flag]


## M13 (B72) : `ScriptedCaseDef.flags_on_search` du cas courant si le verdict
## porte une fouille (valeurs absolues calculées sur `flags`) ; vide sinon.
func search_flag_changes(verdict: Verdict, flags: Dictionary[StringName, Variant]) -> Dictionary[StringName, Variant]:
	var changes: Dictionary[StringName, Variant] = {}
	if verdict != null and verdict.search_done and current_scripted != null:
		CaseConsequences.add_all(changes, flags, current_scripted.flags_on_search)
	return changes


## M13 (B72, B74) : conséquences narratives de la fouille, ajoutées aux
## changements du cas (valeurs absolues, comme `CaseConsequences`) ; les
## `flags_on_search` sont posés plus tôt, par `_apply_narrative`.
func _apply_search_consequences(result: CaseResult) -> void:
	var verdict: Verdict = result.verdict
	if verdict == null or current_case == null:
		return
	var flags: Dictionary[StringName, Variant] = flag_values()
	if verdict.search_done and verdict.search_motive == SearchLayout.MOTIVE_NONE:
		CaseConsequences.add(result.narrative_changes, flags, UpgradeDef.FLAG_SEARCH_ABUSE, 1)
	if verdict.kind == VerdictKind.Kind.APPROVE and verdict.search_done \
			and UpgradeDef.owns(builder.get_flag_values(), UpgradeDef.ID_CALIBRATED_GATE) \
			and current_case.search_found_forbidden():
		var gate: UpgradeDef = data.get_economy().get_upgrade(UpgradeDef.ID_CALIBRATED_GATE) if data != null else null
		var amount: int = SaveService.as_int(gate.get_effect(UpgradeDef.EFFECT_SUSPICION_ON_FOUND, 1)) if gate != null else 1
		CaseConsequences.add(result.narrative_changes, flags, CaseConsequences.FLAG_SUSPICION, amount)


## M13 : R43 (déclarations conformes) active dans le shift.
func statements_active() -> bool:
	if day == null or day.rule_set == null:
		return false
	for rule: Rule in day.rule_set.rules:
		var script: Script = rule.get_script() as Script if rule != null else null
		if script != null and script.get_global_name() == &"StatementsConsistentRule":
			return true
	return false


## M13 : R44 (fouille sur motif) active dans le shift (portique disponible).
func search_available() -> bool:
	if day == null or day.rule_set == null:
		return false
	for rule: Rule in day.rule_set.rules:
		var procedure: ProcedureRule = rule as ProcedureRule
		if procedure != null and procedure.procedure_id == ProcedureRule.PROCEDURE_SEARCH_CAUSE:
			return true
	return false


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
	if time_expired or shift_ended_early or booth_closed or garde_over or not has_remaining_cases():
		_end_day()
	else:
		_set_phase(DayPhase.Kind.WAITING_CASE, &"")


func _on_day_time_expired() -> void:
	if not _started or story_mode:
		return
	time_expired = true
	if phase == DayPhase.Kind.WAITING_CASE:
		_end_day()


## Mode Récit (D-102) : passe en mode Récit (vrai) ou Dur pour ce shift.
## Repasser en Dur avec l'horloge déjà à 18:00 termine le shift comme à l'heure.
func set_story_mode(value: bool) -> void:
	story_mode = value
	if clock != null:
		clock.set_untimed(value)


func _on_difficulty_changed(_difficulty: StringName) -> void:
	if _started and apply_to_game_state and story_mode and not GameState.is_story_mode():
		set_story_mode(false)


## Mode Récit : « Fermer le guichet » possible une fois le quota du jour
## atteint (jour à quota seulement).
func can_close_booth() -> bool:
	return story_mode and _started and phase != DayPhase.Kind.SUMMARY and quota.is_active() and quota.is_full()


## Ferme le guichet (`can_close_booth`) : bilan tout de suite entre deux
## passagers, sinon après le passager en cours. Renvoie vrai si accepté.
func close_booth() -> bool:
	if not can_close_booth():
		return false
	booth_closed = true
	if phase == DayPhase.Kind.WAITING_CASE:
		_end_day()
	return true


func _end_day() -> void:
	if phase == DayPhase.Kind.SUMMARY:
		return
	if clock != null:
		clock.stop()
	for plan: StationEventPlan in station_events:
		if plan.state == StationEventPlan.State.ACTIVE:
			_end_station_event(plan, false)
	summary.time_expired = time_expired
	# Cas scénarisés restés dans la file (SC-22 : `final_unprocessed`).
	for scripted: ScriptedCaseDef in builder.get_active_scripted_cases():
		if scripted.at_index >= next_index and not scripted.flags_if_unprocessed.is_empty():
			CaseConsequences.add_all(summary.unprocessed_changes, flag_values(), scripted.flags_if_unprocessed)
	if apply_to_game_state:
		for flag: StringName in summary.unprocessed_changes:
			GameState.set_flag(flag, summary.unprocessed_changes[flag])
	_set_phase(DayPhase.Kind.SUMMARY, &"")
	if mode == DayDef.MODE_GARDE and garde_run != null:
		if not garde_run.ended:
			garde_run.quit()
		EventBus.garde_ended.emit(garde_run.to_record())
	EventBus.day_ended.emit(summary)


func _set_phase(p_phase: DayPhase.Kind, case_id: StringName) -> void:
	phase = p_phase
	_phase_time = 0.0
	EventBus.day_phase_changed.emit(p_phase, case_id)


# ---------------------------------------------------------------------------
# M12 (B54) : règles mutables en cours de shift
# ---------------------------------------------------------------------------

## Avant de construire le passager `index` : un cas scénarisé clôt les
## événements qui touchent aux règles actives et suspend surcharges et
## modificateurs (D-129, règle 3) ; puis les changements en attente
## s'appliquent (`rules_changed`), et l'heure de présentation est posée.
func _prepare_rules_for(index: int) -> void:
	var ctx: RuleContext = builder.ctx
	var scripted: bool = builder.get_scripted_case(index) != null
	if scripted:
		for plan: StationEventPlan in station_events:
			if plan.state == StationEventPlan.State.ACTIVE and plan.is_structural():
				_end_station_event(plan, true)
	ctx.rule_set.overlay_suspended = scripted
	ctx.now_minute = builder.presentation_minute
	if ctx.has_pending_changes():
		var diff: RuleDiff = ctx.apply_pending()
		if not diff.is_empty():
			_on_rules_applied(diff)


## Après application d'une différence : tampon DÉTENTION et onglets ouverts
## par une directive (Garde), générateur prévenu (`CaseBuilder.on_rules_changed`,
## lot B), puis `rules_changed` et republication des listes renouvelées.
func _on_rules_applied(diff: RuleDiff) -> void:
	if mode == DayDef.MODE_GARDE and garde_run != null:
		for unit_id: StringName in garde_run.active_units:
			var unit: GardeUnitDef = garde_run.def.get_unit(unit_id)
			if unit == null:
				continue
			if unit.enables_detain:
				day.detain_enabled = true
			for tab: String in unit.rulebook_tabs:
				if not day.rulebook_tabs.has(tab):
					day.rulebook_tabs.append(tab)
	var lists: PackedStringArray = []
	if builder.has_method(&"on_rules_changed"):
		builder.call(&"on_rules_changed", diff)
		lists = builder.changed_lists.duplicate()
		builder.changed_lists = PackedStringArray()
	EventBus.rules_changed.emit(diff)
	_publish_changed_lists(lists)


## Republie les listes renouvelées par `CaseBuilder.on_rules_changed`
## (`changed_lists`) : avis (`wanted_notices_published`), révocations
## (`revocations_published`), listes nommées (`rule_list_published`, EV-07
## `stolen`). Après `rules_changed` : l'onglet existe avant sa liste.
func _publish_changed_lists(lists: PackedStringArray) -> void:
	var done: PackedStringArray = []
	for label: String in lists:
		if done.has(label):
			continue
		done.append(label)
		match label:
			"wanted":
				EventBus.wanted_notices_published.emit(builder.get_wanted_notices())
			"revoked", "":
				EventBus.revocations_published.emit(builder.get_revocations())
			_:
				EventBus.rule_list_published.emit(StringName(label), builder.ctx.get_list(StringName(label)))


## Effets du contrôleur avant la citation : EV-02 (comparateur en panne), un
## REFUS ou une DÉTENTION justes mais non motivés ne sont pas cités.
func _apply_shift_modifiers_before_citation(result: CaseResult) -> void:
	if builder.ctx.modifier(RuleChangeDef.MOD_COMPARATOR_DOWN) <= 0:
		return
	if result.citation_reason_key != ScoringService.CIT_UNDOCUMENTED_DENIAL \
			and result.citation_reason_key != ScoringService.CIT_UNDOCUMENTED_DETENTION:
		return
	result.citation_reason_key = ""
	result.citation_rule_id = &""
	result.missed_violations.clear()
	result.documented = true
	result.correct = result.verdict_correct
	if result.correct:
		result.wage = day.credit_per_correct
		if result.verdict_kind == VerdictKind.Kind.DETAIN and result.expected_verdict == VerdictKind.Kind.DETAIN:
			result.wage += detain_bonus
	result.credits_delta = result.wage


# ---------------------------------------------------------------------------
# M12 (B58) : événements de station
# ---------------------------------------------------------------------------

## Événements en cours (bandeau ÉVÉNEMENT).
func active_station_events() -> Array[StationEventPlan]:
	var result: Array[StationEventPlan] = []
	for plan: StationEventPlan in station_events:
		if plan.state == StationEventPlan.State.ACTIVE:
			result.append(plan)
	return result


## Après le `processed`-ième passager : annonces (effet au suivant) et fins
## de fenêtre (campagne ; en Garde, le `GardeRun` les gère).
func _update_station_events(processed: int) -> void:
	if mode == DayDef.MODE_GARDE:
		return
	var minute: int = current_minute()
	for plan: StationEventPlan in station_events:
		match plan.state:
			StationEventPlan.State.PENDING:
				var due: bool = plan.announce_after == processed if plan.announce_after >= 0 \
						else (plan.announce_minute >= 0 and minute >= plan.announce_minute)
				if due and has_remaining_cases():
					_start_station_event(plan)
			StationEventPlan.State.ACTIVE:
				if plan.event.window_kind == StationEventDef.WindowKind.CLOCK:
					if plan.clock_to >= 0 and minute >= plan.clock_to:
						_end_station_event(plan, true)
				elif plan.event.window_kind != StationEventDef.WindowKind.SECONDS and plan.end_index >= 0 \
						and processed >= plan.end_index:
					_end_station_event(plan, true)


## Annonce : changements en attente du passager suivant, effets du contrôleur.
func _start_station_event(plan: StationEventPlan, queue_changes: bool = true) -> void:
	plan.state = StationEventPlan.State.ACTIVE
	# M13 (EV-09, QA-066) : profil annoncé qui vise au moins un passager de la fenêtre.
	if builder.has_method(&"fit_alert_profile"):
		builder.call(&"fit_alert_profile", plan)
	if queue_changes:
		builder.ctx.queue_changes(plan.changes(), plan.source())
	var extra: int = plan.modifier(RuleChangeDef.MOD_EXTRA_PASSENGERS)
	if extra > 0 and mode == DayDef.MODE_CAMPAIGN:
		# EV-06 : file allongée seulement si le générateur sait l'étendre
		# (`CaseBuilder.extend_queue(count)`, lot B : roster du jour).
		if builder.has_method(&"extend_queue"):
			builder.call(&"extend_queue", day.passenger_count + extra)
			day.passenger_count += extra
			summary.planned_cases = day.passenger_count
		else:
			push_warning("DayController: file non extensible (CaseBuilder.extend_queue absent), EV-06 sans passagers en plus")
	var seconds: int = plan.modifier(RuleChangeDef.MOD_EXTRA_SECONDS)
	if seconds > 0 and clock != null and mode == DayDef.MODE_CAMPAIGN:
		clock.duration_sec += seconds
		clock.remaining_sec += seconds
	if plan.event.window_kind == StationEventDef.WindowKind.SECONDS:
		plan.seconds_left = plan.seconds
	if plan.modifier(RuleChangeDef.MOD_CLOCK_FROZEN) > 0 and clock != null:
		clock.stop()
	var announce: String = plan.announce_key()
	if not announce.is_empty():
		EventBus.hall_announced.emit(announce)
	EventBus.station_event_started.emit(plan)


## Fin de fenêtre : annulation au passager suivant (avant un cas scénarisé :
## appliquée avant de le construire), horloge relancée, liste retirée.
func _end_station_event(plan: StationEventPlan, announce: bool) -> void:
	if plan.state != StationEventPlan.State.ACTIVE:
		return
	plan.state = StationEventPlan.State.ENDED
	# Toujours en attente : appliqué après d'éventuels changements encore en
	# attente de la même source (annonce suivie d'une clôture immédiate).
	builder.ctx.queue_revert(plan.source())
	if plan.modifier(RuleChangeDef.MOD_CLOCK_FROZEN) > 0 and clock != null and phase != DayPhase.Kind.SUMMARY \
			and phase != DayPhase.Kind.INTRO:
		clock.start()
	if plan.list_label != &"":
		var empty: Array[RevokedEntry] = []
		builder.ctx.set_list(plan.list_label, empty)
		EventBus.rule_list_published.emit(plan.list_label, empty)
	if announce and plan.event != null and not plan.event.end_key.is_empty():
		EventBus.hall_announced.emit(plan.event.end_key)
	EventBus.station_event_ended.emit(plan)


## Fenêtres en secondes réelles (EV-05) : fin après `seconds`.
func _advance_station_events(delta: float) -> void:
	for plan: StationEventPlan in station_events:
		if plan.state == StationEventPlan.State.ACTIVE and plan.event != null and not plan.garde \
				and plan.event.window_kind == StationEventDef.WindowKind.SECONDS:
			plan.seconds_left -= delta
			if plan.seconds_left <= 0.0:
				_end_station_event(plan, true)


## Liste nommée d'un événement publiée (EV-07 : générée par le lot B dans
## `CaseBuilder.on_rules_changed`, puis publiée ici par `publish_list`).
func publish_list(label: StringName, entries: Array[RevokedEntry]) -> void:
	builder.ctx.set_list(label, entries)
	EventBus.rule_list_published.emit(label, entries)


# ---------------------------------------------------------------------------
# M12 (B57) : Garde de nuit
# ---------------------------------------------------------------------------

## Score, erreurs, fin ; puis directive, palier et événements (changements
## mis en attente : effet au passager suivant).
func _after_garde_case(result: CaseResult) -> void:
	if garde_run == null:
		return
	var step: Dictionary = garde_run.after_case(result, builder.ctx)
	if step["error"]:
		EventBus.garde_error.emit(result.case_id, result.citation_reason_key, garde_run.errors.size())
	else:
		EventBus.garde_scored.emit(garde_run.score, int(step["points"]))
	if step["over"]:
		garde_over = true
		return
	for row: Dictionary in step["queued"]:
		var source: StringName = row.get("source", &"")
		if row.get("revert", false):
			builder.ctx.queue_revert(source)
		else:
			var changes: Array[RuleChangeDef] = []
			for change: Variant in row.get("changes", []):
				if change is RuleChangeDef:
					changes.append(change)
			builder.ctx.queue_changes(changes, source)
	for plan: StationEventPlan in step["events_ended"]:
		if plan.modifier(RuleChangeDef.MOD_CLOCK_FROZEN) > 0 and clock != null:
			clock.start()
		if plan.list_label != &"":
			var empty: Array[RevokedEntry] = []
			builder.ctx.set_list(plan.list_label, empty)
			EventBus.rule_list_published.emit(plan.list_label, empty)
		if not plan.event.end_key.is_empty():
			EventBus.hall_announced.emit(plan.event.end_key)
		EventBus.station_event_ended.emit(plan)
	if step["tier_changed"]:
		GardeService.apply_tier(day, garde_run.current_tier())
		EventBus.garde_tier_changed.emit(garde_run.tier_index)
	var directive: Dictionary = step["directive"]
	if not directive.is_empty():
		EventBus.garde_directive.emit(int(directive["number"]), StringName(directive["unit_id"]),
				StringName(directive["action"]))
	for plan: StationEventPlan in step["events_started"]:
		station_events.append(plan)
		var announce: String = plan.announce_key()
		if not announce.is_empty():
			EventBus.hall_announced.emit(announce)
		EventBus.station_event_started.emit(plan)


## « Terminer la garde » (pause, confirmée) : le score compte ; bilan tout de
## suite entre deux passagers, sinon après le passager en cours.
func request_end_garde() -> bool:
	if mode != DayDef.MODE_GARDE or garde_run == null or not _started or phase == DayPhase.Kind.SUMMARY:
		return false
	garde_run.quit()
	garde_over = true
	if phase == DayPhase.Kind.WAITING_CASE or phase == DayPhase.Kind.INTRO:
		_end_day()
	return true
