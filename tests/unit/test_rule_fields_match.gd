## Famille FieldsMatchRule (R07 : nom, prénom, naissance, N° ID identiques).
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")

var _rule: Rule


func before_each() -> void:
	_rule = CaseFactory.rule(&"r_identity_fields_match")


func test_valid_case_has_no_violation() -> void:
	assert_eq(_rule.evaluate(CaseFactory.valid_case(), CaseFactory.context()).size(), 0)


func test_case_and_spaces_are_normalized() -> void:
	var c: Case = CaseFactory.valid_case()
	c.get_document(CaseFactory.PERMIT).set_value(&"family_name", "  vasquez-orlov ")
	assert_eq(_rule.evaluate(c, CaseFactory.context()).size(), 0)


func test_name_mismatch() -> void:
	var c: Case = CaseFactory.valid_case()
	c.get_document(CaseFactory.PERMIT).set_value(&"family_name", "Vasquez-Orlav")
	var violations: Array[Violation] = _rule.evaluate(c, CaseFactory.context())
	assert_eq(violations.size(), 1)
	assert_true(violations[0].has_ref(FieldRef.new(CaseFactory.ID_CARD, &"family_name")))
	assert_true(violations[0].has_ref(FieldRef.new(CaseFactory.PERMIT, &"family_name")))
	assert_eq(violations[0].reason_key, "viol_fields_mismatch")


func test_birth_date_swap_is_mismatch() -> void:
	var c: Case = CaseFactory.valid_case()
	# Inversion jour/mois : 02.11.2151 → 11.02.2151.
	c.get_document(CaseFactory.ID_CARD).set_value(&"birth_date", GameDate.from_ymd(2151, 2, 11))
	assert_eq(_rule.evaluate(c, CaseFactory.context()).size(), 1)


func test_id_mismatch() -> void:
	var c: Case = CaseFactory.valid_case()
	c.get_document(CaseFactory.PERMIT).set_value(&"citizen_id", "HG-4471-K2R9")
	var violations: Array[Violation] = _rule.evaluate(c, CaseFactory.context())
	assert_eq(violations.size(), 1)
	assert_true(violations[0].has_ref(FieldRef.new(CaseFactory.PERMIT, &"citizen_id")))


func test_two_mismatching_paths_give_two_violations() -> void:
	var c: Case = CaseFactory.valid_case()
	c.get_document(CaseFactory.PERMIT).set_value(&"citizen_id", "HG-4471-K2R9")
	c.get_document(CaseFactory.BIOSCAN).set_value(&"given_name", "Myra")
	assert_eq(_rule.evaluate(c, CaseFactory.context()).size(), 2)


func test_single_document_cannot_mismatch() -> void:
	var c: Case = CaseFactory.valid_case([CaseFactory.ID_CARD])
	c.get_document(CaseFactory.ID_CARD).set_value(&"family_name", "Autre")
	assert_eq(_rule.evaluate(c, CaseFactory.context()).size(), 0)


func test_document_filter() -> void:
	var r: FieldsMatchRule = FieldsMatchRule.new()
	r.id = &"r_test"
	r.truth_paths = [&"family_name"]
	r.document_ids = [CaseFactory.ID_CARD, CaseFactory.PERMIT]
	var c: Case = CaseFactory.valid_case()
	c.get_document(CaseFactory.BIOSCAN).set_value(&"family_name", "Autre")
	assert_eq(r.evaluate(c, CaseFactory.context()).size(), 0, "le bio-scan est hors périmètre")


func test_detectable_anomalies_from_data() -> void:
	var kinds: Array[AnomalyType.Kind] = _rule.get_detectable_anomalies()
	assert_true(kinds.has(AnomalyType.Kind.NAME_MISMATCH))
	assert_true(kinds.has(AnomalyType.Kind.ID_MISMATCH))
