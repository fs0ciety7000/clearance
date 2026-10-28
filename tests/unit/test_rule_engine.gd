## RuleEngine : agrégation, règles désactivées hors RuleSet, verdict attendu,
## clé de réponse ; RuleSet : Rulebook et anomalies détectables.
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")


func _day_ctx(day_number: int) -> RuleContext:
	return CaseFactory.catalog().make_context(day_number)


func test_valid_case_passes_every_mvp_day() -> void:
	var c: Case = CaseFactory.valid_case()
	for day_number: int in [1, 2, 3]:
		var ctx: RuleContext = _day_ctx(day_number)
		assert_eq(RuleEngine.validate(c, ctx.rule_set, ctx).size(), 0, "J%d" % day_number)


func test_aggregates_violations_of_several_rules() -> void:
	var c: Case = CaseFactory.valid_case([CaseFactory.ID_CARD], &"tyc")
	c.get_document(CaseFactory.ID_CARD).expiry_date = CaseFactory.today() - 1
	var ctx: RuleContext = _day_ctx(3)
	var violations: Array[Violation] = RuleEngine.validate(c, ctx.rule_set, ctx)
	assert_eq(CaseFactory.violated_ids(violations), [&"r_id_card_valid", &"r_permit_required"] as Array[StringName],
			"ordre du RuleSet")


func test_rules_outside_rule_set_are_disabled() -> void:
	# Permis manquant + photo d'un autre : ni R03 ni R04 ne sont actives au J1.
	var c: Case = CaseFactory.valid_case([CaseFactory.ID_CARD], &"tyc")
	c.get_document(CaseFactory.ID_CARD).set_value(&"portrait",
			PortraitValue.new(c.passenger_presented.appearance.derive({&"face": &"face_01", &"eyes": &"eyes_01"})))
	var day1: RuleContext = _day_ctx(1)
	assert_eq(RuleEngine.validate(c, day1.rule_set, day1).size(), 0, "J1 : rien à signaler")
	var day2: RuleContext = _day_ctx(2)
	assert_eq(CaseFactory.violated_ids(RuleEngine.validate(c, day2.rule_set, day2)), [&"r_portrait_match"] as Array[StringName])
	var day3: RuleContext = _day_ctx(3)
	assert_eq(RuleEngine.validate(c, day3.rule_set, day3).size(), 2)


func test_expected_verdict() -> void:
	var none: Array[Violation] = []
	assert_eq(RuleEngine.expected_verdict(none), VerdictKind.Kind.APPROVE)
	var deny: Array[Violation] = [Violation.new(&"r_a", [], "", 2)]
	assert_eq(RuleEngine.expected_verdict(deny), VerdictKind.Kind.DENY)
	var detain: Array[Violation] = [Violation.new(&"r_a", [], "", 2), Violation.new(&"r_b", [], "", 3)]
	assert_eq(RuleEngine.expected_verdict(detain), VerdictKind.Kind.DETAIN)


func test_case_key_is_computed_from_final_case() -> void:
	# Une anomalie hors règle active ne change pas le verdict (ajustement « vérité terrain »).
	var c: Case = CaseFactory.valid_case([CaseFactory.ID_CARD], &"tyc")
	var truth: Passenger = c.passenger_presented.copy()
	var anomalies: Array[Anomaly] = [Anomaly.new(AnomalyType.Kind.MISSING_DOCUMENT, CaseFactory.PERMIT)]
	var day1: RuleContext = _day_ctx(1)
	var key1: CaseKey = RuleEngine.build_case_key(c, truth, anomalies, day1.rule_set, day1)
	assert_eq(key1.expected_verdict, VerdictKind.Kind.APPROVE)
	assert_eq(key1.anomalies.size(), 1)
	var day3: RuleContext = _day_ctx(3)
	var key3: CaseKey = RuleEngine.build_case_key(c, truth, anomalies, day3.rule_set, day3)
	assert_eq(key3.expected_verdict, VerdictKind.Kind.DENY)
	assert_eq(key3.get_violated_rule_ids(), [&"r_permit_required"] as Array[StringName])


func test_violation_is_documented_by_confirmed_discrepancy() -> void:
	var c: Case = CaseFactory.valid_case()
	c.get_document(CaseFactory.ID_CARD).expiry_date = CaseFactory.today() - 2
	var ctx: RuleContext = _day_ctx(3)
	var violation: Violation = RuleEngine.validate(c, ctx.rule_set, ctx)[0]
	var proof: Discrepancy = DiscrepancyChecker.check(c, FieldRef.today(), FieldRef.new(CaseFactory.ID_CARD, &"expiry_date"), ctx)
	assert_true(violation.is_documented_by(proof))
	var unrelated: Discrepancy = DiscrepancyChecker.check(c, FieldRef.today(), FieldRef.new(CaseFactory.PERMIT, &"expiry_date"), ctx)
	assert_false(violation.is_documented_by(unrelated), "concordance : pas une preuve")


func test_rulebook_marks_new_rules() -> void:
	var rs: RuleSet = CaseFactory.catalog().rule_sets[&"rs_day03"]
	var entries: Array[RulebookEntry] = rs.build_rulebook()
	assert_eq(entries.size(), 7)
	var new_ids: Array[StringName] = []
	for entry: RulebookEntry in entries:
		if entry.is_new:
			new_ids.append(entry.rule_id)
	assert_eq(new_ids, [&"r_permit_required", &"r_permit_valid", &"r_face_uncovered", &"r_identity_fields_match"] as Array[StringName])


func test_detectable_anomalies_per_day() -> void:
	var day1: RuleSet = CaseFactory.catalog().rule_sets[&"rs_day01"]
	assert_true(day1.can_detect(AnomalyType.Kind.EXPIRED_DOCUMENT))
	assert_true(day1.can_detect(AnomalyType.Kind.MISSING_DOCUMENT))
	assert_false(day1.can_detect(AnomalyType.Kind.PORTRAIT_MISMATCH))
	var day3: RuleSet = CaseFactory.catalog().rule_sets[&"rs_day03"]
	for kind: AnomalyType.Kind in [AnomalyType.Kind.ID_MISMATCH, AnomalyType.Kind.NAME_MISMATCH, AnomalyType.Kind.PORTRAIT_MISMATCH]:
		assert_true(day3.can_detect(kind), AnomalyType.name_of(kind))
	assert_false(day3.can_detect(AnomalyType.Kind.WRONG_ISSUER))


func test_rules_are_not_mutated_by_evaluation() -> void:
	var rs: RuleSet = CaseFactory.catalog().rule_sets[&"rs_day03"]
	var before: Array[String] = []
	for r: Rule in rs.rules:
		before.append(_dump(r))
	var c: Case = CaseFactory.valid_case([CaseFactory.ID_CARD], &"tyc")
	c.get_document(CaseFactory.ID_CARD).expiry_date = 0
	RuleEngine.validate(c, rs, CaseFactory.context(rs))
	for i: int in rs.rules.size():
		assert_eq(_dump(rs.rules[i]), before[i], String(rs.rules[i].id))


func _dump(r: Resource) -> String:
	var parts: PackedStringArray = []
	for p: Dictionary in r.get_property_list():
		var usage: int = p["usage"]
		var prop: String = p["name"]
		if (usage & PROPERTY_USAGE_STORAGE) != 0:
			parts.append("%s=%s" % [prop, r.get(prop)])
	return ";".join(parts)
