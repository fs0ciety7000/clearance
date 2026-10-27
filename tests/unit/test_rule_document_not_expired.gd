## Famille DocumentNotExpiredRule (R02 carte, R05 permis, R12 bio-scan < 30 jours).
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")


func _ctx() -> RuleContext:
	return CaseFactory.context()


func test_valid_documents_are_not_expired() -> void:
	var c: Case = CaseFactory.valid_case()
	for rule_id: StringName in [&"r_id_card_valid", &"r_permit_valid", &"r_bioscan_valid"]:
		assert_eq(CaseFactory.rule(rule_id).evaluate(c, _ctx()).size(), 0, String(rule_id))


func test_expired_id_card() -> void:
	var c: Case = CaseFactory.valid_case()
	c.get_document(CaseFactory.ID_CARD).expiry_date = CaseFactory.today() - 3
	var violations: Array[Violation] = CaseFactory.rule(&"r_id_card_valid").evaluate(c, _ctx())
	assert_eq(violations.size(), 1)
	assert_true(violations[0].has_ref(FieldRef.new(CaseFactory.ID_CARD, &"expiry_date")), "preuve = date d'expiration")
	assert_true(violations[0].has_ref(FieldRef.rulebook_rule(&"r_id_card_valid")))
	assert_eq(violations[0].reason_key, "viol_document_expired")


func test_document_expiring_today_is_still_valid() -> void:
	var c: Case = CaseFactory.valid_case()
	c.get_document(CaseFactory.ID_CARD).expiry_date = CaseFactory.today()
	assert_eq(CaseFactory.rule(&"r_id_card_valid").evaluate(c, _ctx()).size(), 0)


func test_expired_permit_only_flags_permit_rule() -> void:
	var c: Case = CaseFactory.valid_case()
	c.get_document(CaseFactory.PERMIT).expiry_date = CaseFactory.today() - 1
	assert_eq(CaseFactory.rule(&"r_permit_valid").evaluate(c, _ctx()).size(), 1)
	assert_eq(CaseFactory.rule(&"r_id_card_valid").evaluate(c, _ctx()).size(), 0)


func test_absent_document_is_not_an_expiry_violation() -> void:
	var c: Case = CaseFactory.valid_case([CaseFactory.ID_CARD])
	assert_eq(CaseFactory.rule(&"r_permit_valid").evaluate(c, _ctx()).size(), 0)


func test_bioscan_max_age_uses_issue_date() -> void:
	var c: Case = CaseFactory.valid_case()
	var scan: DocumentInstance = c.get_document(CaseFactory.BIOSCAN)
	scan.issue_date = CaseFactory.today() - 29
	scan.expiry_date = CaseFactory.today() + 365 # ignorée par R12
	assert_eq(CaseFactory.rule(&"r_bioscan_valid").evaluate(c, _ctx()).size(), 0, "29 jours : valide")
	scan.issue_date = CaseFactory.today() - 30
	var violations: Array[Violation] = CaseFactory.rule(&"r_bioscan_valid").evaluate(c, _ctx())
	assert_eq(violations.size(), 1, "30 jours : expiré")
	assert_true(violations[0].has_ref(FieldRef.new(CaseFactory.BIOSCAN, &"issue_date")))


func test_detects_expired_document_anomaly() -> void:
	assert_true(CaseFactory.rule(&"r_permit_valid").get_detectable_anomalies().has(AnomalyType.Kind.EXPIRED_DOCUMENT))


func test_check_against_expiry_field() -> void:
	var c: Case = CaseFactory.valid_case()
	var r: Rule = CaseFactory.rule(&"r_id_card_valid")
	var expiry: FieldRef = FieldRef.new(CaseFactory.ID_CARD, &"expiry_date")
	assert_eq(r.check_against(c, expiry, _ctx()), Discrepancy.Result.CONCORDANT)
	c.get_document(CaseFactory.ID_CARD).expiry_date = CaseFactory.today() - 1
	assert_eq(r.check_against(c, expiry, _ctx()), Discrepancy.Result.DISCORDANT)
	assert_eq(r.check_against(c, FieldRef.new(CaseFactory.ID_CARD, &"family_name"), _ctx()), Discrepancy.Result.INCOMPARABLE)
	assert_eq(r.check_against(c, FieldRef.new(CaseFactory.PERMIT, &"expiry_date"), _ctx()), Discrepancy.Result.INCOMPARABLE)
