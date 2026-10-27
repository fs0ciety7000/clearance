## Famille OriginIdBlockRule (R10 : 1er chiffre du bloc ID ↔ origine, LORE §5).
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")

var _rule: Rule


func before_each() -> void:
	_rule = CaseFactory.rule(&"r_origin_block")


func test_valid_for_each_mvp_origin() -> void:
	for faction_id: StringName in [&"tyc", &"hal", &"ter"]:
		var c: Case = CaseFactory.valid_case([CaseFactory.ID_CARD, CaseFactory.PERMIT], faction_id)
		assert_eq(_rule.evaluate(c, CaseFactory.context()).size(), 0, String(faction_id))


func test_forged_origin_on_card() -> void:
	var c: Case = CaseFactory.valid_case([CaseFactory.ID_CARD])
	c.get_document(CaseFactory.ID_CARD).set_value(&"citizen_id", "HG-1471-K2Q9")
	var violations: Array[Violation] = _rule.evaluate(c, CaseFactory.context())
	assert_eq(violations.size(), 1)
	assert_true(violations[0].has_ref(FieldRef.new(CaseFactory.ID_CARD, &"citizen_id")))
	assert_true(violations[0].has_ref(FieldRef.new(CaseFactory.ID_CARD, &"origin")))
	assert_eq(violations[0].reason_key, "viol_origin_id_mismatch")


func test_document_without_origin_uses_visible_origin() -> void:
	var c: Case = CaseFactory.valid_case([CaseFactory.ID_CARD, CaseFactory.PERMIT])
	c.get_document(CaseFactory.PERMIT).set_value(&"citizen_id", "HG-2471-K2Q9")
	var violations: Array[Violation] = _rule.evaluate(c, CaseFactory.context())
	assert_eq(violations.size(), 1)
	assert_true(violations[0].has_ref(FieldRef.new(CaseFactory.PERMIT, &"citizen_id")))


func test_unknown_origin_is_skipped() -> void:
	var c: Case = CaseFactory.valid_case([CaseFactory.ID_CARD])
	c.get_document(CaseFactory.ID_CARD).set_value(&"origin", &"cer")
	assert_eq(_rule.evaluate(c, CaseFactory.context()).size(), 0)


func test_check_against_id_and_origin() -> void:
	var c: Case = CaseFactory.valid_case([CaseFactory.ID_CARD])
	var id_ref: FieldRef = FieldRef.new(CaseFactory.ID_CARD, &"citizen_id")
	var origin_ref: FieldRef = FieldRef.new(CaseFactory.ID_CARD, &"origin")
	assert_eq(_rule.check_against(c, id_ref, CaseFactory.context()), Discrepancy.Result.CONCORDANT)
	c.get_document(CaseFactory.ID_CARD).set_value(&"origin", &"ter")
	assert_eq(_rule.check_against(c, id_ref, CaseFactory.context()), Discrepancy.Result.DISCORDANT)
	assert_eq(_rule.check_against(c, origin_ref, CaseFactory.context()), Discrepancy.Result.DISCORDANT)
	assert_eq(_rule.check_against(c, FieldRef.new(CaseFactory.ID_CARD, &"family_name"), CaseFactory.context()), Discrepancy.Result.INCOMPARABLE)


func test_faction_helpers() -> void:
	var tyc: FactionDef = CaseFactory.catalog().factions[&"tyc"]
	assert_eq(tyc.get_id_block_digit(), 4)
	assert_true(tyc.matches_citizen_id("HG-4471-K2Q9"))
	assert_false(tyc.matches_citizen_id("HG-1471-K2Q9"))
