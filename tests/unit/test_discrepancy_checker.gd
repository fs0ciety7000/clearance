## DiscrepancyChecker : concordant / discordant / incomparable / même champ,
## visage ↔ photo (dont visière), date du jour, champ ↔ règle du Rulebook.
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")

var _case: Case
var _ctx: RuleContext


func before_each() -> void:
	_case = CaseFactory.valid_case([CaseFactory.ID_CARD, CaseFactory.PERMIT], &"tyc")
	_ctx = CaseFactory.catalog().make_context(3)
	_ctx.today = CaseFactory.today()


func _ref(document_id: StringName, field_id: StringName) -> FieldRef:
	return FieldRef.new(document_id, field_id)


func _check(a: FieldRef, b: FieldRef) -> Discrepancy:
	var forward: Discrepancy = DiscrepancyChecker.check(_case, a, b, _ctx)
	var backward: Discrepancy = DiscrepancyChecker.check(_case, b, a, _ctx)
	assert_eq(forward.result, backward.result, "symétrie %s ↔ %s" % [a.key(), b.key()])
	return forward


func test_same_truth_path_concordant() -> void:
	var d: Discrepancy = _check(_ref(CaseFactory.ID_CARD, &"family_name"), _ref(CaseFactory.PERMIT, &"family_name"))
	assert_eq(d.result, Discrepancy.Result.CONCORDANT)
	assert_false(d.confirmed)


func test_same_truth_path_discordant() -> void:
	_case.get_document(CaseFactory.PERMIT).set_value(&"citizen_id", "HG-4471-K2R9")
	var d: Discrepancy = _check(_ref(CaseFactory.ID_CARD, &"citizen_id"), _ref(CaseFactory.PERMIT, &"citizen_id"))
	assert_eq(d.result, Discrepancy.Result.DISCORDANT)
	assert_true(d.confirmed)
	assert_eq(d.reason_key, Discrepancy.REASON_MISMATCH)


func test_different_data_is_incomparable() -> void:
	var d: Discrepancy = _check(_ref(CaseFactory.ID_CARD, &"family_name"), _ref(CaseFactory.PERMIT, &"given_name"))
	assert_eq(d.result, Discrepancy.Result.INCOMPARABLE)
	assert_false(d.confirmed)


func test_same_field_is_incomparable() -> void:
	var ref: FieldRef = _ref(CaseFactory.ID_CARD, &"family_name")
	var d: Discrepancy = _check(ref, _ref(CaseFactory.ID_CARD, &"family_name"))
	assert_eq(d.result, Discrepancy.Result.INCOMPARABLE)
	assert_eq(d.reason_key, Discrepancy.REASON_SAME_FIELD)


func test_unknown_field_is_incomparable() -> void:
	var d: Discrepancy = _check(_ref(CaseFactory.BIOSCAN, &"family_name"), _ref(CaseFactory.ID_CARD, &"family_name"))
	assert_eq(d.result, Discrepancy.Result.INCOMPARABLE)
	assert_eq(d.reason_key, Discrepancy.REASON_UNKNOWN_FIELD)


func test_face_vs_photo_concordant_despite_legit_noise() -> void:
	_case.get_document(CaseFactory.ID_CARD).set_value(&"portrait",
			PortraitValue.new(_case.passenger_presented.appearance.derive({&"hair": &"hair_11"}), 3, 6))
	var d: Discrepancy = _check(FieldRef.passenger_face(), _ref(CaseFactory.ID_CARD, &"portrait"))
	assert_eq(d.result, Discrepancy.Result.CONCORDANT)
	assert_eq(d.differing_traits.size(), 0)


func test_face_vs_photo_discordant_lists_traits() -> void:
	_case.get_document(CaseFactory.ID_CARD).set_value(&"portrait",
			PortraitValue.new(_case.passenger_presented.appearance.derive({&"eyes": &"eyes_01", &"face": &"face_02"})))
	var d: Discrepancy = _check(FieldRef.passenger_face(), _ref(CaseFactory.ID_CARD, &"portrait"))
	assert_eq(d.result, Discrepancy.Result.DISCORDANT)
	assert_eq(d.reason_key, Discrepancy.REASON_FACE_MISMATCH)
	assert_true(d.differing_traits.has(&"eyes"))
	assert_true(d.differing_traits.has(&"face"))


func test_masked_face_is_incomparable() -> void:
	_case.passenger_presented.appearance = _case.passenger_presented.appearance.derive({&"headwear": &"visor_down"})
	var d: Discrepancy = _check(FieldRef.passenger_face(), _ref(CaseFactory.ID_CARD, &"portrait"))
	assert_eq(d.result, Discrepancy.Result.INCOMPARABLE)
	assert_eq(d.reason_key, Discrepancy.REASON_FACE_MASKED)


func test_face_vs_text_field_is_incomparable() -> void:
	var d: Discrepancy = _check(FieldRef.passenger_face(), _ref(CaseFactory.ID_CARD, &"family_name"))
	assert_eq(d.result, Discrepancy.Result.INCOMPARABLE)


func test_expiry_vs_today() -> void:
	var expiry: FieldRef = _ref(CaseFactory.PERMIT, &"expiry_date")
	assert_eq(_check(FieldRef.today(), expiry).result, Discrepancy.Result.CONCORDANT)
	_case.get_document(CaseFactory.PERMIT).expiry_date = CaseFactory.today() - 1
	var d: Discrepancy = _check(FieldRef.today(), expiry)
	assert_eq(d.result, Discrepancy.Result.DISCORDANT)
	assert_eq(d.reason_key, Discrepancy.REASON_EXPIRED)


func test_other_date_vs_today_is_incomparable() -> void:
	assert_eq(_check(FieldRef.today(), _ref(CaseFactory.ID_CARD, &"birth_date")).result, Discrepancy.Result.INCOMPARABLE)


func test_field_vs_active_rule() -> void:
	var rule_ref: FieldRef = FieldRef.rulebook_rule(&"r_id_card_valid")
	var expiry: FieldRef = _ref(CaseFactory.ID_CARD, &"expiry_date")
	assert_eq(_check(rule_ref, expiry).result, Discrepancy.Result.CONCORDANT)
	_case.get_document(CaseFactory.ID_CARD).expiry_date = CaseFactory.today() - 10
	var d: Discrepancy = _check(rule_ref, expiry)
	assert_eq(d.result, Discrepancy.Result.DISCORDANT)
	assert_eq(d.reason_key, Discrepancy.REASON_RULE_VIOLATED)


func test_required_document_rule_vs_dossier() -> void:
	var rule_ref: FieldRef = FieldRef.rulebook_rule(&"r_permit_required")
	var any_field: FieldRef = _ref(CaseFactory.ID_CARD, &"family_name")
	assert_eq(_check(rule_ref, any_field).result, Discrepancy.Result.CONCORDANT)
	CaseFactory.remove_document(_case, CaseFactory.PERMIT)
	assert_eq(_check(rule_ref, any_field).result, Discrepancy.Result.DISCORDANT)


func test_inactive_rule_is_incomparable() -> void:
	# R13 (émetteur du bio-scan) n'est pas active au J3.
	var d: Discrepancy = _check(FieldRef.rulebook_rule(&"r_bioscan_issuer"), _ref(CaseFactory.ID_CARD, &"family_name"))
	assert_eq(d.result, Discrepancy.Result.INCOMPARABLE)
	assert_eq(d.reason_key, Discrepancy.REASON_RULE_INACTIVE)


func test_rule_vs_rule_and_rule_vs_unrelated_field() -> void:
	assert_eq(_check(FieldRef.rulebook_rule(&"r_id_card_valid"), FieldRef.rulebook_rule(&"r_permit_valid")).result,
			Discrepancy.Result.INCOMPARABLE)
	assert_eq(_check(FieldRef.rulebook_rule(&"r_id_card_valid"), _ref(CaseFactory.ID_CARD, &"family_name")).result,
			Discrepancy.Result.INCOMPARABLE)

