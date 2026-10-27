## Famille IssuerAllowedRule (R13 : bio-scan émis par la Clinique Orbitale Meridian).
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")

var _rule: Rule


func before_each() -> void:
	_rule = CaseFactory.rule(&"r_bioscan_issuer")


func test_legit_issuer() -> void:
	assert_eq(_rule.evaluate(CaseFactory.valid_case(), CaseFactory.context()).size(), 0)


func test_fake_clinic() -> void:
	var c: Case = CaseFactory.valid_case()
	c.get_document(CaseFactory.BIOSCAN).issuer_id = &"clinique_meridiane"
	var violations: Array[Violation] = _rule.evaluate(c, CaseFactory.context())
	assert_eq(violations.size(), 1)
	assert_true(violations[0].has_ref(FieldRef.new(CaseFactory.BIOSCAN, &"issuer")))
	assert_eq(violations[0].reason_key, "viol_wrong_issuer")


func test_absent_document() -> void:
	assert_eq(_rule.evaluate(CaseFactory.valid_case([CaseFactory.ID_CARD]), CaseFactory.context()).size(), 0)


func test_check_against_issuer_field() -> void:
	var c: Case = CaseFactory.valid_case()
	var issuer: FieldRef = FieldRef.new(CaseFactory.BIOSCAN, &"issuer")
	assert_eq(_rule.check_against(c, issuer, CaseFactory.context()), Discrepancy.Result.CONCORDANT)
	c.get_document(CaseFactory.BIOSCAN).set_value(&"issuer", &"clinique_meridiane")
	assert_eq(_rule.check_against(c, issuer, CaseFactory.context()), Discrepancy.Result.DISCORDANT)
	assert_eq(_rule.check_against(c, FieldRef.new(CaseFactory.ID_CARD, &"issuer"), CaseFactory.context()), Discrepancy.Result.INCOMPARABLE)


func test_detects_wrong_issuer() -> void:
	assert_eq(_rule.get_detectable_anomalies(), [AnomalyType.Kind.WRONG_ISSUER] as Array[AnomalyType.Kind])
