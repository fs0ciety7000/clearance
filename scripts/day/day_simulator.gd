## Simulation rapide d'un jour sans scène ni signaux (debug `--screen=…`,
## équilibrage) : construit les cas du `CaseBuilder`, joue une politique et
## note avec le vrai `ScoringService`. Le résultat est un `DaySummary`
## identique à celui d'un vrai shift (citations numérotées, amendes).
class_name DaySimulator
extends RefCounted

## Question posée par le joueur simulé (R08) — `InspectionSession.TOPIC_PURPOSE`.
const TOPIC_PURPOSE: StringName = &"purpose"
## M12 : flux de l'heure de présentation les jours d'événement sans couvre-feu.
const EVENT_MINUTE_SALT: String = "event_minute"
## M12 : passagers couverts par une fenêtre en secondes (EV-05, 60 s ≈ 2 passagers).
const SECONDS_WINDOW_PASSENGERS: int = 2


## `policy(case: Case, key: CaseKey, index: int) -> VerdictKind.Kind`. Les refus
## sont documentés par les preuves visibles (`evidence_for`) si `document` ;
## la visière est retirée avant le verdict si `remove_visors`.
static func simulate(data: DataCatalog, day_number: int, day_seed: int, policy: Callable,
		document: bool = true, remove_visors: bool = true, processed_limit: int = -1,
		undocumented_indices: Array[int] = []) -> DaySummary:
	var day: DayDef = data.get_day(day_number)
	var builder: CaseBuilder = CaseBuilder.new(data, day, day_seed, [])
	day = builder.day
	var summary: DaySummary = DaySummary.new()
	summary.day_number = day_number
	summary.planned_cases = day.passenger_count
	var citations: int = 0
	var count: int = day.passenger_count if processed_limit < 0 else mini(processed_limit, day.passenger_count)
	for i: int in count:
		var generated: GeneratedCase = builder.build(i)
		var case: Case = generated.case
		var kind: VerdictKind.Kind = policy.call(case, generated.key, i)
		if remove_visors:
			case.remove_visor()
		var verdict: Verdict = Verdict.new(case.case_id, kind)
		if document and kind != VerdictKind.Kind.APPROVE and not undocumented_indices.has(i):
			verdict.flagged = evidence_for(case, generated.key, builder.ctx)
		verdict.elapsed_sec = 30.0
		var result: CaseResult = ScoringService.score(verdict, generated.key, case.case_id, case, day, data.get_economy().detain_bonus)
		result.passenger_label = case.passenger_presented.short_label() if case.passenger_presented != null else ""
		builder.record_verdict(case, kind)
		if result.has_citation():
			citations += 1
			ScoringService.apply_citation(result, citations, day)
		summary.add_result(result)
	summary.time_expired = count < day.passenger_count
	return summary


## M7 : jour simulé complet comme un vrai shift (`DayController`) : drapeaux
## narratifs requis (`flags`, **modifié sur place** avec les conséquences des
## cas : `CaseConsequences`), mémoire des passagers (`memory`, modifiée),
## objets glissés (décision du `profile`, crédits), DÉTENTION seulement si le
## jour l'autorise, phrase de passe, cas scénarisés non traités.
## Acte II : quota respiratoire (`QuotaTracker` ; au-delà du quota, un passager
## en règle est refusé, ou approuvé et imputé si `profile.overrun`), heure de
## présentation (`present_minute` : ticket de file, couvre-feu), contexte du
## shift des effets, fin anticipée sur une annonce (grève du J20).
## Acte III : Main courante (`CaseBuilder.record_verdict` après chaque
## verdict), quota suspendu selon le climat, jauges d'admissions (`pont`).
## M11 : `profile.story_mode` (Récit, D-102) — amendes à 0 ₵.
## M12 (B58) : `plan` — événement de station du jour (`StationEventService`),
## joué comme par le `DayController` : annonce après `announce_after`
## passagers, changements au passager suivant (`on_rules_changed`), fin de
## fenêtre, clôture avant un cas scénarisé, compensation des classes B,
## modificateurs EV-02 / EV-04 / EV-06 ; heure de présentation tirée sur un flux
## à part (les tirages du joueur ne changent pas).
static func play_day(data: DataCatalog, day_number: int, day_seed: int, profile: SimProfile,
		flags: Dictionary[StringName, Variant], memory: Dictionary, rng: SeededRng,
		plan: StationEventPlan = null) -> DaySummary:
	var day: DayDef = data.get_day(day_number)
	if plan != null:
		day = day.make_shift_copy()
		day.free_citations_per_day += plan.free_citations_bonus
	var minute_rng: SeededRng = SeededRng.new(SeededRng.mix_string(day_seed, EVENT_MINUTE_SALT))
	var true_flags: Array[StringName] = []
	for flag: StringName in flags:
		if FlagCondition.is_flag_true(flags, flag):
			true_flags.append(flag)
	var builder: CaseBuilder = CaseBuilder.new(data, day, day_seed, true_flags, memory, flags)
	# SC-89a (`rule_replacements`) : notation sur le jour (et le RuleSet) du générateur.
	day = builder.day
	var summary: DaySummary = DaySummary.new()
	summary.day_number = day_number
	summary.planned_cases = day.passenger_count
	var citations: int = 0
	var quota: QuotaTracker = QuotaTracker.for_day(day, flags)
	quota.sync(builder.ctx)
	var timed: bool = _has_curfew(day)
	var i: int = 0
	while i < day.passenger_count:
		if timed:
			builder.presentation_minute = present_minute(day, i, profile, rng)
		elif plan != null:
			builder.presentation_minute = present_minute(day, i, profile, minute_rng)
		if plan != null:
			_event_before_case(plan, builder, i)
		var generated: GeneratedCase = builder.build(i)
		var case: Case = generated.case
		var correct: bool = rng.chance(profile.accuracy)
		var kind: VerdictKind.Kind = profile.verdict_for(case, generated.key, correct, day.detain_enabled)
		var quota_full: bool = quota.before_verdict(case)
		if quota_full and generated.key.expected_verdict == VerdictKind.Kind.APPROVE and not profile.forces(case):
			# Quota atteint (D-077) : refus correct, ou entrée imputée (0 ₵).
			var approve: bool = profile.overrun if correct else not profile.overrun
			kind = VerdictKind.Kind.APPROVE if approve else VerdictKind.Kind.DENY
		case.remove_visor()
		var verdict: Verdict = Verdict.new(case.case_id, kind)
		if kind != VerdictKind.Kind.APPROVE:
			verdict.flagged = evidence_for(case, generated.key, builder.ctx)
		verdict.elapsed_sec = 30.0
		# Interrogatoire systématique (R08) : une question posée.
		verdict.questions_asked = [TOPIC_PURPOSE]
		var result: CaseResult = ScoringService.score(verdict, generated.key, case.case_id, case, day,
				data.get_economy().detain_bonus, quota_full)
		if plan != null:
			_waive_if_comparator_down(result, builder.ctx, day, data.get_economy().detain_bonus)
		result.quota_counted = quota.counts(case)
		result.quota_overrun = quota.after_verdict(case, kind)
		quota.sync(builder.ctx)
		# Acte III (R34) : Main courante du shift.
		builder.record_verdict(case, kind)
		result.passenger_label = case.passenger_presented.short_label()
		if result.has_citation():
			citations += 1
			ScoringService.apply_citation(result, citations, day)
			if builder.ctx.modifier(RuleChangeDef.MOD_NO_FREE_CITATIONS) > 0 and result.fine == 0:
				# M12 (EV-04) : inspection, aucun avertissement gratuit.
				result.fine = maxi(day.penalty_per_error, 0)
				result.credits_delta = result.wage - result.fine
			if profile.story_mode:
				result.waive_fine()
		if result.correct and builder.ctx.modifier(RuleChangeDef.MOD_CORRECT_BONUS) > 0:
			# M12 (EV-04) : prime d'assiduité par verdict juste.
			result.wage += builder.ctx.modifier(RuleChangeDef.MOD_CORRECT_BONUS)
			result.credits_delta += builder.ctx.modifier(RuleChangeDef.MOD_CORRECT_BONUS)
		for item: SlippedItem in case.slipped_items:
			item.decision = profile.decision_for(case, item, rng.randf())
			result.item_decisions[item.id] = item.decision
			if item.decision == SlippedItem.Decision.REPORT:
				result.report_credits += item.credits_for(item.decision)
			else:
				result.bribe_credits += item.credits_for(item.decision)
		var scripted: ScriptedCaseDef = builder.get_scripted_case(i) if generated.scripted_id != &"" else null
		result.scripted_id = generated.scripted_id
		result.password_answered = profile.answer_password and case.dialogue_tags.has(CaseBuilder.TAG_LUCIOLE_PASSWORD) \
				and FlagCondition.gauge_value(flags, CaseConsequences.FLAG_TRUST) >= CaseConsequences.PASSWORD_TRUST
		result.narrative_changes = CaseConsequences.compute(scripted, case, result.verdict_kind,
				not generated.key.expected_violations.is_empty(), result.password_answered, day_number, flags,
				result.luciole_report, CaseConsequences.contexts_for(day, case, result), day.luciole_trust_on_breach,
				day.admission_gauges)
		CaseConsequences.merge_into(flags, result.narrative_changes)
		if scripted != null:
			memory[String(scripted.id)] = CaseMemory.snapshot(day_number, case, result.verdict_kind)
		summary.add_result(result)
		i += 1
		if plan != null:
			_event_after_case(plan, builder, day, i)
			summary.planned_cases = day.passenger_count
		if _ends_shift(day, summary.results.size(), flags):
			break
	# Cas scénarisés restés dans la file (grève : `flags_if_unprocessed`).
	for scripted_left: ScriptedCaseDef in builder.get_active_scripted_cases():
		if scripted_left.at_index >= summary.results.size() and not scripted_left.flags_if_unprocessed.is_empty():
			CaseConsequences.add_all(summary.unprocessed_changes, flags, scripted_left.flags_if_unprocessed)
	CaseConsequences.merge_into(flags, summary.unprocessed_changes)
	return summary


## Acte II : heure de présentation simulée du cas `index` (minutes depuis
## minuit) : file régulière de 10:00 à 18:00 (`profile.pace` < 1 = plus rapide)
## et dispersion de ±20 min (docs/ACT2.md §6.4).
static func present_minute(day: DayDef, index: int, profile: SimProfile, rng: SeededRng) -> int:
	var share: float = (index + 0.5) / float(maxi(day.passenger_count, 1))
	var minute: float = DayDef.SHIFT_START_MIN + share * DayDef.SHIFT_LENGTH_MIN * profile.pace
	return clampi(roundi(minute) + rng.randi_range(-20, 20), DayDef.SHIFT_START_MIN,
			DayDef.SHIFT_START_MIN + DayDef.SHIFT_LENGTH_MIN)


static func _has_curfew(day: DayDef) -> bool:
	for rule: Rule in day.rule_set.rules:
		if rule is CurfewRule:
			return true
	return false


## Annonce qui arrête le shift après `processed` cas (grève du J20).
static func _ends_shift(day: DayDef, processed: int, flags: Dictionary[StringName, Variant]) -> bool:
	for def: HallAnnouncementDef in day.announcements:
		if def != null and def.ends_shift and def.after_case == processed and FlagCondition.check(def.condition, flags):
			return true
	return false


## Discordances confirmées qui prouvent les violations d'un cas, telles qu'un
## agent les obtiendrait en comparant les champs désignés par chaque violation.
static func evidence_for(case: Case, key: CaseKey, ctx: RuleContext) -> Array[Discrepancy]:
	var found: Array[Discrepancy] = []
	for violation: Violation in key.expected_violations:
		var refs: Array[FieldRef] = violation.refs
		if refs.size() < 2:
			continue
		var result: Discrepancy = DiscrepancyChecker.check(case, refs[0], refs[1], ctx)
		if not result.confirmed and refs.size() > 2:
			result = DiscrepancyChecker.check(case, refs[0], refs[refs.size() - 1], ctx)
		if result.confirmed:
			found.append(result)
	return found



# ---------------------------------------------------------------------------
# M12 (B58) : événement de station joué comme par le `DayController`
# ---------------------------------------------------------------------------

## Avant le passager `index` : un cas scénarisé clôt les événements qui
## touchent aux règles actives et suspend surcharges et modificateurs (D-129,
## règle 3) ; les changements en attente s'appliquent.
static func _event_before_case(plan: StationEventPlan, builder: CaseBuilder, index: int) -> void:
	var ctx: RuleContext = builder.ctx
	var scripted: bool = builder.get_scripted_case(index) != null
	if scripted and plan.state == StationEventPlan.State.ACTIVE and plan.is_structural():
		_end_event(plan, builder)
	ctx.rule_set.overlay_suspended = scripted
	ctx.now_minute = builder.presentation_minute
	if ctx.has_pending_changes():
		var diff: RuleDiff = ctx.apply_pending()
		if not diff.is_empty():
			builder.on_rules_changed(diff)


## Après `processed` passagers : annonce (effet au suivant), allongement de la
## file (EV-06), fin de fenêtre.
static func _event_after_case(plan: StationEventPlan, builder: CaseBuilder, day: DayDef, processed: int) -> void:
	var minute: int = builder.presentation_minute
	match plan.state:
		StationEventPlan.State.PENDING:
			var due: bool = plan.announce_after == processed if plan.announce_after >= 0 \
					else (plan.announce_minute >= 0 and minute >= plan.announce_minute)
			if due and processed < day.passenger_count:
				plan.state = StationEventPlan.State.ACTIVE
				builder.ctx.queue_changes(plan.changes(), plan.source())
				var extra: int = plan.modifier(RuleChangeDef.MOD_EXTRA_PASSENGERS)
				if extra > 0:
					day.passenger_count += extra
				if plan.event.window_kind == StationEventDef.WindowKind.SECONDS:
					plan.end_index = processed + SECONDS_WINDOW_PASSENGERS
		StationEventPlan.State.ACTIVE:
			if plan.event.window_kind == StationEventDef.WindowKind.CLOCK:
				if plan.clock_to >= 0 and minute >= plan.clock_to:
					_end_event(plan, builder)
			elif plan.end_index >= 0 and processed >= plan.end_index:
				_end_event(plan, builder)


static func _end_event(plan: StationEventPlan, builder: CaseBuilder) -> void:
	if plan.state != StationEventPlan.State.ACTIVE:
		return
	plan.state = StationEventPlan.State.ENDED
	builder.ctx.queue_revert(plan.source())
	if plan.list_label != &"":
		var empty: Array[RevokedEntry] = []
		builder.ctx.set_list(plan.list_label, empty)


## EV-02 (comparateur en panne) : un REFUS / une DÉTENTION justes mais non
## motivés ne sont pas cités (même règle que le `DayController`).
static func _waive_if_comparator_down(result: CaseResult, ctx: RuleContext, day: DayDef, detain_bonus: int) -> void:
	if ctx.modifier(RuleChangeDef.MOD_COMPARATOR_DOWN) <= 0:
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
