## M13 lot A (ARCHITECTURE §12.9) : citations FOUILLE SANS MOTIF (R44) et
## FOUILLE OMISE (R47), gravité et priorité, conséquences narratives de la
## fouille (`fouille_abus`, relevé du PH-2 AG-03, `flags_on_search`) et
## coûts transmis par le `DayController` à la session.
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")
const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const DayHarness := preload("res://tests/helpers/day_harness.gd")


func _rules(with_search: bool = true, with_belt: bool = false) -> RuleSet:
	var rs: RuleSet = RuleSet.new()
	if with_search:
		var r44: ProcedureRule = ProcedureRule.new()
		r44.id = &"r_search_cause"
		r44.procedure_id = ProcedureRule.PROCEDURE_SEARCH_CAUSE
		rs.rules.append(r44)
	if with_belt:
		var r47: ProcedureRule = ProcedureRule.new()
		r47.id = &"r_belt_search"
		r47.procedure_id = ProcedureRule.PROCEDURE_BELT_SEARCH
		r47.applies_to_faction_ids = [&"cer"] as Array[StringName]
		r47.min_stay_days = 7
		rs.rules.append(r47)
	return rs


func _day(rs: RuleSet) -> DayDef:
	var day: DayDef = DayDef.new()
	day.rule_set = rs
	day.credit_per_correct = 5
	return day


func _key(expected: VerdictKind.Kind) -> CaseKey:
	var key: CaseKey = CaseKey.new()
	key.expected_verdict = expected
	if expected != VerdictKind.Kind.APPROVE:
		var violation: Violation = Violation.new(&"r_contraband", [FieldRef.rulebook_rule(&"r_contraband")] as Array[FieldRef],
				"viol_contraband", 2)
		key.expected_violations = [violation] as Array[Violation]
	return key


func _verdict(kind: VerdictKind.Kind, searched: bool, motive: StringName = &"") -> Verdict:
	var verdict: Verdict = Verdict.new(&"case_test", kind)
	verdict.search_done = searched
	verdict.search_motive = motive
	verdict.questions_asked = [&"purpose"] as Array[StringName]
	return verdict


func test_unwarranted_search_of_a_passenger_in_order() -> void:
	var c: Case = CaseFactory.valid_case()
	var result: CaseResult = ScoringService.score(_verdict(VerdictKind.Kind.APPROVE, true), _key(VerdictKind.Kind.APPROVE),
			c.case_id, c, _day(_rules()))
	assert_eq(result.citation_reason_key, ScoringService.CIT_UNWARRANTED_SEARCH, "FOUILLE SANS MOTIF")
	assert_eq(result.citation_rule_id, &"r_search_cause")
	assert_eq(result.procedure_missed, ProcedureRule.PROCEDURE_SEARCH_CAUSE)
	assert_true(result.verdict_correct, "le verdict reste juste")
	assert_false(result.correct, "citation de procédure : cas à 0 ₵")
	assert_eq(result.wage, 0)
	assert_eq(ScoringService.GRAVITY[ScoringService.CIT_UNWARRANTED_SEARCH], 1)
	assert_eq(ScoringService.GRAVITY[ScoringService.CIT_SEARCH_SKIPPED], 1)


func test_search_with_motive_or_on_an_offender_is_not_cited() -> void:
	var c: Case = CaseFactory.valid_case()
	var day: DayDef = _day(_rules())
	var motivated: CaseResult = ScoringService.score(_verdict(VerdictKind.Kind.APPROVE, true, SearchLayout.MOTIVE_CUE),
			_key(VerdictKind.Kind.APPROVE), c.case_id, c, day)
	assert_eq(motivated.citation_reason_key, "", "fouille sur motif")
	assert_true(motivated.correct)
	var offender: CaseResult = ScoringService.score(_verdict(VerdictKind.Kind.DENY, true), _key(VerdictKind.Kind.DENY),
			c.case_id, c, day)
	assert_eq(offender.citation_reason_key, "", "passager en infraction : pas de sanction (refus documenté d'office)")
	var not_searched: CaseResult = ScoringService.score(_verdict(VerdictKind.Kind.APPROVE, false), _key(VerdictKind.Kind.APPROVE),
			c.case_id, c, day)
	assert_true(not_searched.correct)
	var without_r44: CaseResult = ScoringService.score(_verdict(VerdictKind.Kind.APPROVE, true), _key(VerdictKind.Kind.APPROVE),
			c.case_id, c, _day(RuleSet.new()))
	assert_eq(without_r44.citation_reason_key, "", "R44 inactive : aucune procédure")
	assert_false(ScoringService.is_unwarranted_search(_verdict(VerdictKind.Kind.APPROVE, true, &"cue"), VerdictKind.Kind.APPROVE))


func test_unjustified_denial_outranks_the_unwarranted_search() -> void:
	var c: Case = CaseFactory.valid_case()
	var result: CaseResult = ScoringService.score(_verdict(VerdictKind.Kind.DENY, true), _key(VerdictKind.Kind.APPROVE),
			c.case_id, c, _day(_rules()))
	assert_eq(result.citation_reason_key, ScoringService.CIT_UNJUSTIFIED_DENIAL, "au plus une citation, la plus grave")


func test_belt_search_skipped_on_an_approved_long_stay_ceres() -> void:
	var c: Case = CaseFactory.valid_case([CaseFactory.ID_CARD, CaseFactory.PERMIT] as Array[StringName], &"cer")
	var day: DayDef = _day(_rules(true, true))
	var skipped: CaseResult = ScoringService.score(_verdict(VerdictKind.Kind.APPROVE, false), _key(VerdictKind.Kind.APPROVE),
			c.case_id, c, day)
	assert_eq(skipped.citation_reason_key, ScoringService.CIT_SEARCH_SKIPPED, "FOUILLE OMISE")
	assert_eq(skipped.citation_rule_id, &"r_belt_search")
	var searched: CaseResult = ScoringService.score(_verdict(VerdictKind.Kind.APPROVE, true, SearchLayout.MOTIVE_MANDATORY),
			_key(VerdictKind.Kind.APPROVE), c.case_id, c, day)
	assert_true(searched.correct, "fouille faite (motif MF-5)")
	var denied: CaseResult = ScoringService.score(_verdict(VerdictKind.Kind.DENY, false), _key(VerdictKind.Kind.DENY),
			c.case_id, c, day)
	assert_eq(denied.citation_reason_key, "", "un refus n'a pas besoin de fouille")
	c.get_document(CaseFactory.PERMIT).values[&"stay_days"] = 7
	var short_stay: CaseResult = ScoringService.score(_verdict(VerdictKind.Kind.APPROVE, false), _key(VerdictKind.Kind.APPROVE),
			c.case_id, c, day)
	assert_true(short_stay.correct, "7 jours : pas au-delà")
	var tycho: Case = CaseFactory.valid_case([CaseFactory.ID_CARD, CaseFactory.PERMIT] as Array[StringName], &"tyc")
	var other: CaseResult = ScoringService.score(_verdict(VerdictKind.Kind.APPROVE, false), _key(VerdictKind.Kind.APPROVE),
			tycho.case_id, tycho, day)
	assert_true(other.correct, "R47 ne vise que Cérès")


## Conséquences de la fouille appliquées par le DayController au tampon
## (`fouille_abus`, AG-03, `flags_on_search`), sans GameState.
func test_day_controller_search_consequences() -> void:
	var controller: DayController = DayController.new()
	controller.apply_to_game_state = false
	add_child_autofree(controller)
	controller.set_process(false)
	controller.data = Gen.data()
	controller.builder = CaseBuilder.new(Gen.data(), Gen.data().get_day(8), Gen.day_seed(0, 8), [&"upg_ag03"] as Array[StringName])
	var c: Case = CaseFactory.valid_case()
	var layout: SearchLayout = SearchLayout.new()
	layout.add(SearchLayout.ZONE_TORSO, SearchItem.make(&"cb01", SearchItem.Kind.CONTRABAND, &"oxygen"))
	c.search_layout = layout
	controller.current_case = c
	var zeal: CaseResult = CaseResult.new(c.case_id)
	zeal.verdict = _verdict(VerdictKind.Kind.APPROVE, true)
	controller._apply_search_consequences(zeal)
	assert_eq(zeal.narrative_changes.get(UpgradeDef.FLAG_SEARCH_ABUSE), 1, "fouille sans motif : jauge +1")
	assert_false(zeal.narrative_changes.has(CaseConsequences.FLAG_SUSPICION), "rien de trouvé (zone non scannée)")
	layout.scan(SearchLayout.ZONE_TORSO)
	var relayed: CaseResult = CaseResult.new(c.case_id)
	relayed.verdict = _verdict(VerdictKind.Kind.APPROVE, true, SearchLayout.MOTIVE_CUE)
	controller._apply_search_consequences(relayed)
	assert_eq(relayed.narrative_changes.get(CaseConsequences.FLAG_SUSPICION), 1, "PH-2 : relevé transmis")
	assert_false(relayed.narrative_changes.has(UpgradeDef.FLAG_SEARCH_ABUSE), "fouille sur motif")
	var refused: CaseResult = CaseResult.new(c.case_id)
	refused.verdict = _verdict(VerdictKind.Kind.DENY, true, SearchLayout.MOTIVE_CUE)
	controller._apply_search_consequences(refused)
	assert_true(refused.narrative_changes.is_empty(), "refus : pas de relevé")
	var scripted: ScriptedCaseDef = ScriptedCaseDef.new()
	scripted.flags_on_search = {&"sc105_searched": 0} as Dictionary[StringName, int]
	controller.current_scripted = scripted
	var with_flags: CaseResult = CaseResult.new(c.case_id)
	with_flags.verdict = _verdict(VerdictKind.Kind.DENY, true, SearchLayout.MOTIVE_CUE)
	controller._apply_search_consequences(with_flags)
	assert_eq(with_flags.narrative_changes.get(&"sc105_searched"), true, "flags_on_search (delta 0 = vrai)")
	var not_searched: CaseResult = CaseResult.new(c.case_id)
	not_searched.verdict = _verdict(VerdictKind.Kind.APPROVE, false)
	controller._apply_search_consequences(not_searched)
	assert_true(not_searched.narrative_changes.is_empty(), "sans fouille : rien")
	controller.current_scripted = null
	controller.builder = CaseBuilder.new(Gen.data(), Gen.data().get_day(8), Gen.day_seed(0, 8))
	var without_gate: CaseResult = CaseResult.new(c.case_id)
	without_gate.verdict = _verdict(VerdictKind.Kind.APPROVE, true, SearchLayout.MOTIVE_CUE)
	controller._apply_search_consequences(without_gate)
	assert_true(without_gate.narrative_changes.is_empty(), "sans AG-03 : rien")


## Le DayController transmet à la session les coûts des données et les
## améliorations du matin (AG-01) ; un vrai shift reste jouable.
func test_day_controller_configures_the_session() -> void:
	var harness: DayHarness = DayHarness.new()
	harness.setup(self, NullBooth.new(), 5, 0, 0, [&"upg_ag01"] as Array[StringName])
	var controller: DayController = harness.controller
	var session: InspectionSession = harness.session
	controller.close_intro()
	EventBus.next_case_requested.emit()
	assert_not_null(controller.current_case)
	assert_true(session.hygiaphone, "AG-01 lu dans les drapeaux du matin")
	assert_false(session.calibrated_gate)
	assert_not_null(session.timing)
	assert_false(controller.search_available(), "J5 : pas de portique")
	harness.teardown()
