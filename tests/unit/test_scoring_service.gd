## Notation minimale M4 (`ScoringService`, `CaseResult`, `DaySummary`) et
## typage des signaux `case_resolved` / `day_ended` (TODO(M5) levés).
extends GutTest


func _key(expected: VerdictKind.Kind, violations: int = 0) -> CaseKey:
	var key: CaseKey = CaseKey.new()
	key.expected_verdict = expected
	for i: int in violations:
		key.expected_violations.append(Violation.new(StringName("r%d" % i)))
	return key


func test_matching_verdict_is_correct() -> void:
	var result: CaseResult = ScoringService.score(Verdict.new(&"c", VerdictKind.Kind.DENY), _key(VerdictKind.Kind.DENY, 1), &"c")
	assert_true(result.correct)
	assert_eq(result.case_id, &"c")
	assert_eq(result.verdict_kind, VerdictKind.Kind.DENY)
	assert_eq(result.expected_verdict, VerdictKind.Kind.DENY)
	assert_true(result.missed_violations.is_empty())


func test_approving_a_faulty_case_reports_missed_violations() -> void:
	var result: CaseResult = ScoringService.score(Verdict.new(&"c", VerdictKind.Kind.APPROVE), _key(VerdictKind.Kind.DENY, 2), &"c")
	assert_false(result.correct)
	assert_eq(result.missed_violations.size(), 2)


func test_denying_a_clean_case_is_wrong() -> void:
	var result: CaseResult = ScoringService.score(Verdict.new(&"c", VerdictKind.Kind.DENY), _key(VerdictKind.Kind.APPROVE), &"c")
	assert_false(result.correct)
	assert_true(result.missed_violations.is_empty())


func test_deny_where_detain_expected_is_correct() -> void:
	assert_true(ScoringService.is_correct(VerdictKind.Kind.DENY, VerdictKind.Kind.DETAIN), "GDD §4.5")
	assert_false(ScoringService.is_correct(VerdictKind.Kind.DETAIN, VerdictKind.Kind.DENY))
	assert_false(ScoringService.is_correct(VerdictKind.Kind.APPROVE, VerdictKind.Kind.DETAIN))


func test_elapsed_copied_from_verdict() -> void:
	var verdict: Verdict = Verdict.new(&"c", VerdictKind.Kind.APPROVE)
	verdict.elapsed_sec = 12.5
	var result: CaseResult = ScoringService.score(verdict, _key(VerdictKind.Kind.APPROVE), &"c")
	assert_eq(result.elapsed_sec, 12.5)
	assert_eq(result.verdict, verdict)


func test_missing_key_is_an_error() -> void:
	var result: CaseResult = ScoringService.score(Verdict.new(), null, &"c")
	assert_false(result.correct)
	assert_push_error("manquant")


func test_day_summary_counts() -> void:
	var summary: DaySummary = DaySummary.new()
	for correct: bool in [true, false, true]:
		var r: CaseResult = CaseResult.new()
		r.correct = correct
		summary.add_result(r)
	assert_eq(summary.get_processed_count(), 3)
	assert_eq(summary.get_correct_count(), 2)
	assert_eq(summary.get_error_count(), 1)


func test_event_bus_result_types_resolved() -> void:
	var wanted: Dictionary = {&"case_resolved": [1, "CaseResult"], &"day_ended": [0, "DaySummary"]}
	var script: Script = EventBus.get_script()
	for info: Dictionary in script.get_script_signal_list():
		var signal_name: StringName = StringName(str(info["name"]))
		if wanted.has(signal_name):
			var args: Array = info["args"]
			var spec: Array = wanted[signal_name]
			var index: int = spec[0]
			var wanted_class: String = spec[1]
			var arg: Dictionary = args[index]
			assert_eq(str(arg["class_name"]), wanted_class, String(signal_name))


# --- M5 : notation complète (GDD §4.6, §5.1, §5.2 ; D-024, D-031, D-032) ------

const CaseFactory := preload("res://tests/helpers/case_factory.gd")


func _expired_violation() -> Violation:
	var refs: Array[FieldRef] = [FieldRef.new(&"id_card", &"expiry_date"), FieldRef.rulebook_rule(&"r_id_card_valid")]
	return Violation.new(&"r_id_card_valid", refs, "viol_document_expired")


func _deny_key() -> CaseKey:
	var key: CaseKey = CaseKey.new()
	key.expected_verdict = VerdictKind.Kind.DENY
	key.expected_violations.append(_expired_violation())
	return key


func _proof() -> Discrepancy:
	var d: Discrepancy = Discrepancy.new(FieldRef.new(&"id_card", &"expiry_date"), FieldRef.today())
	return d.set_result(Discrepancy.Result.DISCORDANT, Discrepancy.REASON_EXPIRED)


func _day(rule_ids: Array[StringName] = []) -> DayDef:
	var day: DayDef = DayDef.new()
	day.rule_set = CaseFactory.rule_set_of(rule_ids)
	return day


func test_documented_denial_pays_and_no_citation() -> void:
	var verdict: Verdict = Verdict.new(&"c", VerdictKind.Kind.DENY)
	verdict.flagged = [_proof()]
	var result: CaseResult = ScoringService.score(verdict, _deny_key(), &"c", null, _day())
	assert_true(result.correct)
	assert_true(result.documented)
	assert_eq(result.wage, 5)
	assert_eq(result.citation_reason_key, "")


func test_undocumented_denial_is_zero_and_cited() -> void:
	var result: CaseResult = ScoringService.score(Verdict.new(&"c", VerdictKind.Kind.DENY), _deny_key(), &"c", null, _day())
	assert_true(result.verdict_correct, "le verdict est juste")
	assert_false(result.correct, "mais la procédure ne l'est pas (D-024)")
	assert_eq(result.wage, 0)
	assert_eq(result.citation_reason_key, ScoringService.CIT_UNDOCUMENTED_DENIAL)
	assert_eq(result.citation_rule_id, &"r_id_card_valid")
	assert_eq(result.missed_violations.size(), 1, "violation révélée au bilan")


func test_unrelated_discrepancy_does_not_document() -> void:
	var verdict: Verdict = Verdict.new(&"c", VerdictKind.Kind.DENY)
	var other: Discrepancy = Discrepancy.new(FieldRef.new(&"id_card", &"family_name"), FieldRef.new(&"entry_permit", &"family_name"))
	verdict.flagged = [other.set_result(Discrepancy.Result.DISCORDANT, Discrepancy.REASON_MISMATCH)]
	var result: CaseResult = ScoringService.score(verdict, _deny_key(), &"c")
	assert_false(result.documented)


func test_missing_document_is_self_evident() -> void:
	var key: CaseKey = CaseKey.new()
	key.expected_verdict = VerdictKind.Kind.DENY
	var refs: Array[FieldRef] = [FieldRef.rulebook_rule(&"r_id_card_required")]
	key.expected_violations.append(Violation.new(&"r_id_card_required", refs, "viol_missing_document"))
	var result: CaseResult = ScoringService.score(Verdict.new(&"c", VerdictKind.Kind.DENY), key, &"c", null, _day())
	assert_true(result.documented, "D-032 : la règle elle-même prouve l'absence")
	assert_true(result.correct)


func test_approving_fraud_is_irregular_entry() -> void:
	var result: CaseResult = ScoringService.score(Verdict.new(&"c", VerdictKind.Kind.APPROVE), _deny_key(), &"c", null, _day())
	assert_eq(result.citation_reason_key, ScoringService.CIT_IRREGULAR_ENTRY)
	assert_eq(result.wage, 0)
	assert_eq(result.missed_violations.size(), 1)


func test_denying_innocent_is_unjustified() -> void:
	var result: CaseResult = ScoringService.score(Verdict.new(&"c", VerdictKind.Kind.DENY), _key(VerdictKind.Kind.APPROVE), &"c")
	assert_eq(result.citation_reason_key, ScoringService.CIT_UNJUSTIFIED_DENIAL)


func test_detentions() -> void:
	var detain_key: CaseKey = _deny_key()
	detain_key.expected_verdict = VerdictKind.Kind.DETAIN
	var verdict: Verdict = Verdict.new(&"c", VerdictKind.Kind.DETAIN)
	verdict.flagged = [_proof()]
	var ok: CaseResult = ScoringService.score(verdict, detain_key, &"c", null, _day())
	assert_true(ok.correct)
	assert_eq(ok.wage, 10, "+5 ₵ + 5 ₵ de prime")
	var deny_instead: Verdict = Verdict.new(&"c", VerdictKind.Kind.DENY)
	deny_instead.flagged = [_proof()]
	var plain: CaseResult = ScoringService.score(deny_instead, detain_key, &"c", null, _day())
	assert_true(plain.correct, "REFUS au lieu de DÉTENTION : correct")
	assert_eq(plain.wage, 5, "sans prime")
	var abusive: CaseResult = ScoringService.score(verdict, _deny_key(), &"c", null, _day())
	assert_eq(abusive.citation_reason_key, ScoringService.CIT_ABUSIVE_DETENTION)
	var undocumented: CaseResult = ScoringService.score(Verdict.new(&"c", VerdictKind.Kind.DETAIN), detain_key, &"c", null, _day())
	assert_eq(undocumented.citation_reason_key, ScoringService.CIT_UNDOCUMENTED_DETENTION)


func test_face_unchecked_procedure() -> void:
	var c: Case = CaseFactory.valid_case([CaseFactory.ID_CARD])
	c.passenger_presented.appearance = c.passenger_presented.appearance.derive({PassengerAppearance.SLOT_HEADWEAR: PassengerAppearance.VISOR_DOWN})
	assert_true(c.passenger_presented.appearance.is_face_covered())
	var day: DayDef = _day([&"r_face_uncovered"])
	var masked: CaseResult = ScoringService.score(Verdict.new(&"c", VerdictKind.Kind.APPROVE), _key(VerdictKind.Kind.APPROVE), &"c", c, day)
	assert_eq(masked.citation_reason_key, ScoringService.CIT_FACE_UNCHECKED)
	assert_eq(masked.citation_rule_id, &"r_face_uncovered")
	assert_eq(masked.procedure_missed, ProcedureRule.PROCEDURE_FACE_UNCOVERED)
	assert_true(masked.verdict_correct)
	assert_false(masked.correct)
	assert_eq(masked.wage, 0)
	var without_rule: CaseResult = ScoringService.score(Verdict.new(&"c", VerdictKind.Kind.APPROVE), _key(VerdictKind.Kind.APPROVE), &"c", c, _day())
	assert_true(without_rule.correct, "R06 inactive (J1–J2) : pas de citation")
	c.remove_visor()
	var unmasked: CaseResult = ScoringService.score(Verdict.new(&"c", VerdictKind.Kind.APPROVE), _key(VerdictKind.Kind.APPROVE), &"c", c, day)
	assert_true(unmasked.correct)


func test_tycho_interview_procedure_and_gravity() -> void:
	var c: Case = CaseFactory.valid_case([CaseFactory.ID_CARD], &"tyc")
	var day: DayDef = _day([&"r_tycho_interview"])
	var silent: CaseResult = ScoringService.score(Verdict.new(&"c", VerdictKind.Kind.APPROVE), _key(VerdictKind.Kind.APPROVE), &"c", c, day)
	assert_eq(silent.citation_reason_key, ScoringService.CIT_INTERVIEW_SKIPPED)
	var asked: Verdict = Verdict.new(&"c", VerdictKind.Kind.APPROVE)
	asked.questions_asked = [&"purpose"]
	assert_true(ScoringService.score(asked, _key(VerdictKind.Kind.APPROVE), &"c", c, day).correct)
	# Gravité : ENTRÉE IRRÉGULIÈRE (3) l'emporte sur INTERROGATOIRE OMIS (1).
	var fraud: CaseResult = ScoringService.score(Verdict.new(&"c", VerdictKind.Kind.APPROVE), _deny_key(), &"c", c, day)
	assert_eq(fraud.citation_reason_key, ScoringService.CIT_IRREGULAR_ENTRY)
	var hal: Case = CaseFactory.valid_case([CaseFactory.ID_CARD], &"hal")
	assert_true(ScoringService.score(Verdict.new(&"c", VerdictKind.Kind.APPROVE), _key(VerdictKind.Kind.APPROVE), &"c", hal, day).correct)


func test_fines_escalate() -> void:
	var day: DayDef = DayDef.new()
	assert_eq([1, 2, 3, 4, 5].map(func(n: int) -> int: return ScoringService.fine_for(n, day)), [0, 0, 5, 10, 10], "GDD §5.2")
	var result: CaseResult = ScoringService.score(Verdict.new(&"c", VerdictKind.Kind.APPROVE), _deny_key(), &"c", null, day)
	ScoringService.apply_citation(result, 3, day)
	assert_eq(result.citation_number, 3)
	assert_eq(result.fine, 5)
	assert_eq(result.credits_delta, -5)
	assert_false(result.is_warning())
	ScoringService.apply_citation(result, 1, day)
	assert_true(result.is_warning())


func test_day_summary_economy() -> void:
	var summary: DaySummary = DaySummary.new()
	summary.planned_cases = 5
	var day: DayDef = DayDef.new()
	var verdict: Verdict = Verdict.new(&"c", VerdictKind.Kind.DENY)
	verdict.flagged = [_proof()]
	summary.add_result(ScoringService.score(verdict, _deny_key(), &"a", null, day))
	for n: int in [1, 2, 3]:
		var bad: CaseResult = ScoringService.score(Verdict.new(&"c", VerdictKind.Kind.APPROVE), _deny_key(), &"b", null, day)
		ScoringService.apply_citation(bad, n, day)
		summary.add_result(bad)
	assert_eq(summary.get_unprocessed_count(), 1)
	assert_eq(summary.get_wage_total(), 5)
	assert_eq(summary.get_fine_total(), 5)
	assert_eq(summary.get_net(), 0)
	assert_eq(summary.get_citation_count(), 3)
	assert_eq(summary.get_warning_count(), 2)
	assert_almost_eq(summary.get_compliance(), 0.25, 0.001)
