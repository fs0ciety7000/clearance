## Famille FieldValueAllowedRule (R14 : statut bio-scan SAIN uniquement).
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")

var _rule: Rule


func before_each() -> void:
	_rule = CaseFactory.rule(&"r_bioscan_fit")


func test_fit_status_is_allowed() -> void:
	assert_eq(_rule.evaluate(CaseFactory.valid_case(), CaseFactory.context()).size(), 0)


func test_quarantine_status_is_violation() -> void:
	var c: Case = CaseFactory.valid_case()
	c.get_document(CaseFactory.BIOSCAN).set_value(&"health_status", Passenger.HEALTH_QUARANTINE)
	var violations: Array[Violation] = _rule.evaluate(c, CaseFactory.context())
	assert_eq(violations.size(), 1)
	assert_true(violations[0].has_ref(FieldRef.new(CaseFactory.BIOSCAN, &"health_status")))
	assert_true(violations[0].has_ref(FieldRef.rulebook_rule(&"r_bioscan_fit")))


func test_check_against() -> void:
	var c: Case = CaseFactory.valid_case()
	var status: FieldRef = FieldRef.new(CaseFactory.BIOSCAN, &"health_status")
	assert_eq(_rule.check_against(c, status, CaseFactory.context()), Discrepancy.Result.CONCORDANT)
	c.get_document(CaseFactory.BIOSCAN).set_value(&"health_status", Passenger.HEALTH_REVIEW)
	assert_eq(_rule.check_against(c, status, CaseFactory.context()), Discrepancy.Result.DISCORDANT)


func test_detects_bioscan_unfit() -> void:
	assert_eq(_rule.get_detectable_anomalies(), [AnomalyType.Kind.BIOSCAN_UNFIT] as Array[AnomalyType.Kind])
