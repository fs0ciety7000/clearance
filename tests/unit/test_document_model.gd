## Modèle runtime M2 : DocumentInstance, Case, FieldRef, Passenger, PassengerAppearance.
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")


func test_get_value_resolves_document_and_passenger_fields() -> void:
	var p: Passenger = CaseFactory.passenger()
	var doc: DocumentInstance = CaseFactory.document(CaseFactory.PERMIT, p)
	var family_name: String = doc.get_value(&"family_name")
	var serial: String = doc.get_value(&"serial")
	var expiry: int = doc.get_value(&"expiry_date")
	var issuer: StringName = doc.get_value(&"issuer")
	assert_eq(family_name, "Vasquez-Orlov")
	assert_eq(serial, "PE-2187-30417")
	assert_eq(expiry, doc.expiry_date)
	assert_eq(issuer, &"autorite_transit", "émetteur hérité du type")
	doc.set_value(&"expiry_date", 42)
	assert_eq(doc.expiry_date, 42, "set_value écrit la propriété du document")
	assert_false(doc.values.has(&"expiry_date"))


func test_copy_is_deep_for_portraits() -> void:
	var doc: DocumentInstance = CaseFactory.document(CaseFactory.ID_CARD, CaseFactory.passenger())
	var clone: DocumentInstance = doc.copy()
	var portrait: PortraitValue = clone.get_value(&"portrait")
	portrait.appearance.traits[&"eyes"] = &"eyes_99"
	var original: PortraitValue = doc.get_value(&"portrait")
	assert_ne(original.appearance.get_trait(&"eyes"), &"eyes_99")
	assert_same(clone.type_def, doc.type_def, "la définition est partagée")


func test_case_lookups() -> void:
	var c: Case = CaseFactory.valid_case()
	assert_eq(c.get_document_ids(), [&"id_card", &"entry_permit", &"bioscan"] as Array[StringName])
	assert_eq(c.find_refs_by_truth_path(&"citizen_id").size(), 3)
	assert_eq(c.find_refs_by_kind(FieldDef.FieldKind.PORTRAIT).size(), 1)
	assert_true(c.has_field(FieldRef.new(&"id_card", &"portrait")))
	assert_false(c.has_field(FieldRef.passenger_face()), "pseudo-document")
	var missing: Variant = c.get_value(FieldRef.new(&"id_card", &"nope"))
	assert_true(missing == null)


func test_field_ref_kinds() -> void:
	assert_true(FieldRef.passenger_face().is_passenger_face())
	assert_true(FieldRef.today().is_today())
	assert_false(FieldRef.today().is_rule())
	assert_true(FieldRef.rulebook_rule(&"r_x").is_rule())
	assert_true(FieldRef.new(&"id_card", &"family_name").is_document_field())
	assert_true(FieldRef.new(&"a", &"b").equals(FieldRef.new(&"a", &"b")))
	assert_eq(FieldRef.new(&"a", &"b").key(), "a/b")


func test_passenger_copy_and_overrides() -> void:
	var p: Passenger = CaseFactory.passenger()
	var clone: Passenger = p.copy()
	clone.appearance.traits[&"face"] = &"face_99"
	clone.family_name = "Autre"
	assert_eq(p.family_name, "Vasquez-Orlov")
	assert_ne(p.appearance.get_trait(&"face"), &"face_99")
	var rejected: PackedStringArray = p.apply_overrides({&"given_name": "Ilse", &"unknown": 1, &"stay_days": "x"})
	assert_eq(p.given_name, "Ilse")
	assert_eq(rejected, PackedStringArray(["unknown", "stay_days"]))


func test_appearance_helpers() -> void:
	var a: PassengerAppearance = CaseFactory.appearance()
	assert_false(a.is_face_covered())
	var masked: PassengerAppearance = a.derive({&"headwear": &"visor_down"})
	assert_true(masked.is_face_covered())
	assert_eq(a.distance(masked), 1)
	assert_eq(a.distance(masked, [&"face"] as Array[StringName]), 0)
	assert_true(a.equals(a.copy()))
	assert_false(a.equals(masked))


func test_field_value_normalization() -> void:
	assert_true(FieldValue.equals(" vasquez ", "VASQUEZ"))
	assert_true(FieldValue.equals(&"tyc", "TYC"))
	assert_false(FieldValue.equals(12, "12"), "types différents : faux, sans erreur")
	var date_field: FieldDef = CaseFactory.doc_def(&"id_card").get_field(&"birth_date")
	assert_eq(FieldValue.to_display(GameDate.from_ymd(2151, 11, 2), date_field), "02.11.2151")
