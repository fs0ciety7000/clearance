## Famille PortraitMatchRule (R03 : la photo correspond au porteur) et FaceComparator.
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")

var _rule: Rule


func before_each() -> void:
	_rule = CaseFactory.rule(&"r_portrait_match")


func _set_photo(c: Case, app: PassengerAppearance) -> void:
	c.get_document(CaseFactory.ID_CARD).set_value(&"portrait", PortraitValue.new(app))


func test_valid_case_has_no_violation() -> void:
	assert_eq(_rule.evaluate(CaseFactory.valid_case(), CaseFactory.context()).size(), 0)


func test_legit_noise_is_not_a_violation() -> void:
	var c: Case = CaseFactory.valid_case()
	var older: PassengerAppearance = c.passenger_presented.appearance.derive(
			{&"hair": &"hair_09", &"headwear": &"cap_01", &"accessory": &"scarf"})
	older.age_band -= 1
	_set_photo(c, older)
	assert_eq(_rule.evaluate(c, CaseFactory.context()).size(), 0, "coiffure, coiffe, accessoire, âge ±1 tolérés")


func test_portrait_of_someone_else() -> void:
	var c: Case = CaseFactory.valid_case()
	_set_photo(c, c.passenger_presented.appearance.derive(
			{&"face": &"face_01", &"eyes": &"eyes_02", &"skin": &"skin_01"}))
	var violations: Array[Violation] = _rule.evaluate(c, CaseFactory.context())
	assert_eq(violations.size(), 1)
	assert_true(violations[0].has_ref(FieldRef.passenger_face()))
	assert_true(violations[0].has_ref(FieldRef.new(CaseFactory.ID_CARD, &"portrait")))
	assert_eq(violations[0].reason_key, "viol_portrait_mismatch")


func test_single_trait_lookalike_is_detected() -> void:
	var c: Case = CaseFactory.valid_case()
	_set_photo(c, c.passenger_presented.appearance.derive({&"nose_mouth": &"nose_mouth_06"}))
	assert_eq(_rule.evaluate(c, CaseFactory.context()).size(), 1)


func test_age_gap_beyond_tolerance_is_detected() -> void:
	var c: Case = CaseFactory.valid_case()
	var photo: PassengerAppearance = c.passenger_presented.appearance.copy()
	photo.age_band += 2
	_set_photo(c, photo)
	assert_eq(_rule.evaluate(c, CaseFactory.context()).size(), 1)


func test_visor_does_not_hide_ground_truth() -> void:
	var c: Case = CaseFactory.valid_case()
	c.passenger_presented.appearance = c.passenger_presented.appearance.derive({&"headwear": &"visor_down"})
	assert_eq(_rule.evaluate(c, CaseFactory.context()).size(), 0, "visière = procédure R06, pas une violation")
	_set_photo(c, c.passenger_presented.appearance.derive({&"eyes": &"eyes_01"}))
	assert_eq(_rule.evaluate(c, CaseFactory.context()).size(), 1)


func test_identity_slots_come_from_context() -> void:
	var c: Case = CaseFactory.valid_case()
	_set_photo(c, c.passenger_presented.appearance.derive({&"hair": &"hair_09"}))
	var ctx: RuleContext = CaseFactory.context()
	ctx.identity_slots = [&"hair"]
	assert_eq(_rule.evaluate(c, ctx).size(), 1)


func test_photos_between_documents() -> void:
	var c: Case = CaseFactory.valid_case([CaseFactory.ID_CARD])
	var second: DocumentInstance = CaseFactory.document(CaseFactory.ID_CARD, c.passenger_presented)
	# Deuxième document à photo : type ad hoc dérivé de la carte.
	var def: DocumentTypeDef = CaseFactory.doc_def(CaseFactory.ID_CARD).duplicate(true)
	def.id = &"id_card_copy"
	second.type_def = def
	second.set_value(&"portrait", PortraitValue.new(c.passenger_presented.appearance.derive({&"face": &"face_09"})))
	c.documents.append(second)
	var r: PortraitMatchRule = PortraitMatchRule.new()
	r.id = &"r_test"
	r.check_passenger_face = false
	var violations: Array[Violation] = r.evaluate(c, CaseFactory.context())
	assert_eq(violations.size(), 1)
	assert_eq(violations[0].reason_key, "viol_portraits_differ")


func test_detectable_anomalies() -> void:
	var kinds: Array[AnomalyType.Kind] = _rule.get_detectable_anomalies()
	for kind: AnomalyType.Kind in [AnomalyType.Kind.PORTRAIT_MISMATCH, AnomalyType.Kind.IMPOSTOR_LOOKALIKE, AnomalyType.Kind.RELATIVE_DOCUMENTS]:
		assert_true(kinds.has(kind), AnomalyType.name_of(kind))


func test_face_comparator_ignores_changeable_slots() -> void:
	var a: PassengerAppearance = CaseFactory.appearance()
	var b: PassengerAppearance = a.derive({&"outfit": &"outfit_suit", &"headwear": &"visor_down", &"hair": &"hair_01"})
	assert_eq(FaceComparator.compare(a, b).size(), 0)
	b = a.derive({&"eyes": &"eyes_01", &"skin": &"skin_02"})
	assert_eq(FaceComparator.compare(a, b), [&"eyes", &"skin"] as Array[StringName])
