## Famille RequireDocumentRule (R01 carte requise, R04 permis requis sauf HAL, R11 bio-scan).
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")


func test_valid_case_has_no_violation() -> void:
	var c: Case = CaseFactory.valid_case()
	for rule_id: StringName in [&"r_id_card_required", &"r_permit_required", &"r_bioscan_required"]:
		assert_eq(CaseFactory.rule(rule_id).evaluate(c, CaseFactory.context()).size(), 0, String(rule_id))


func test_missing_id_card_is_violation() -> void:
	var c: Case = CaseFactory.valid_case()
	CaseFactory.remove_document(c, CaseFactory.ID_CARD)
	var violations: Array[Violation] = CaseFactory.rule(&"r_id_card_required").evaluate(c, CaseFactory.context())
	assert_eq(violations.size(), 1)
	assert_eq(violations[0].rule_id, &"r_id_card_required")
	assert_true(violations[0].has_ref(FieldRef.rulebook_rule(&"r_id_card_required")), "preuve = la règle du Rulebook")
	assert_eq(violations[0].reason_key, "viol_missing_document")


func test_missing_permit_is_violation_for_tycho() -> void:
	var c: Case = CaseFactory.valid_case([CaseFactory.ID_CARD], &"tyc")
	assert_eq(CaseFactory.rule(&"r_permit_required").evaluate(c, CaseFactory.context()).size(), 1)


func test_halcyon_native_is_exempt_from_permit() -> void:
	var c: Case = CaseFactory.valid_case([CaseFactory.ID_CARD], &"hal")
	assert_eq(CaseFactory.rule(&"r_permit_required").evaluate(c, CaseFactory.context()).size(), 0)


func test_exemption_reads_visible_origin_on_card() -> void:
	# Le passager se dit HAL mais sa carte affiche TYC : l'agent lit la carte.
	var c: Case = CaseFactory.valid_case([CaseFactory.ID_CARD], &"hal")
	c.get_document(CaseFactory.ID_CARD).set_value(&"origin", &"tyc")
	assert_eq(CaseFactory.rule(&"r_permit_required").evaluate(c, CaseFactory.context()).size(), 1)


func test_detects_missing_document_anomaly() -> void:
	var kinds: Array[AnomalyType.Kind] = CaseFactory.rule(&"r_id_card_required").get_detectable_anomalies()
	assert_eq(kinds, [AnomalyType.Kind.MISSING_DOCUMENT] as Array[AnomalyType.Kind])


func test_required_document_ids() -> void:
	var r: Rule = CaseFactory.rule(&"r_permit_required")
	assert_eq(r.get_required_document_ids(), [&"entry_permit"] as Array[StringName])
