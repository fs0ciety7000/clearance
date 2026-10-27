## Cas scénarisés et tutoriels (GDD §12) générés par le `CaseBuilder`, sur
## plusieurs graines : surcharges, anomalies imposées et paramètres, verdicts.
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const K := AnomalyType.Kind
const SEEDS: int = 40

## Jour → index → cas générés sur `SEEDS` graines (seuls les index scénarisés).
var _cases: Dictionary[String, Array] = {}


func before_all() -> void:
	var indices: Dictionary[int, Array] = {1: [0, 1, 2, 3], 2: [3], 3: [2, 7]}
	for n: int in indices:
		for s: int in SEEDS:
			var builder: CaseBuilder = CaseBuilder.new(Gen.data(), Gen.data().get_day(n), Gen.day_seed(s, n))
			for index: int in indices[n]:
				var key: String = "%d/%d" % [n, index]
				if not _cases.has(key):
					_cases[key] = []
				_cases[key].append(builder.build(index))


func _each(day: int, index: int, check: Callable) -> void:
	var list: Array = _cases["%d/%d" % [day, index]]
	assert_eq(list.size(), SEEDS)
	for generated: Variant in list:
		check.call(generated)


func test_sc01_hal_technician_is_approved() -> void:
	_each(1, 0, func(g: GeneratedCase) -> void:
		assert_eq(g.scripted_id, &"sc_01")
		assert_eq(g.key.truth.faction_id, &"hal")
		assert_eq(g.key.truth.citizen_class, &"C-3")
		assert_eq(g.key.truth.purpose, Passenger.PURPOSE_RETURN)
		assert_eq(g.key.truth.origin_sector, "Anneau C — logements de service")
		assert_true(g.key.truth.citizen_id.begins_with("HG-1"))
		assert_eq(g.key.anomalies.size(), 0)
		assert_eq(g.key.expected_verdict, VerdictKind.Kind.APPROVE)
		assert_false(g.photo_noise, "pas de bruit sur un cas scénarisé")
		assert_true(g.case.dialogue_tags.has(&"sc01_returning_technician")))


func test_sc02_card_expired_three_days() -> void:
	_each(1, 1, func(g: GeneratedCase) -> void:
		assert_eq(g.key.truth.faction_id, &"ter")
		assert_eq(g.key.truth.sex, Passenger.SEX_F)
		assert_eq(g.get_anomaly_kinds(), [K.EXPIRED_DOCUMENT] as Array[AnomalyType.Kind])
		var expiry: int = Gen.doc_value(g.case, &"id_card", &"document.expiry_date")
		assert_eq(Gen.data().get_day(1).game_date - expiry, 3)
		assert_eq(g.key.get_violated_rule_ids(), [&"r_id_card_valid"] as Array[StringName])
		assert_eq(g.key.expected_verdict, VerdictKind.Kind.DENY))


func test_tutorial_cases() -> void:
	_each(1, 2, func(g: GeneratedCase) -> void:
		assert_eq(g.scripted_id, &"tuto_concordant")
		assert_eq(g.key.expected_verdict, VerdictKind.Kind.APPROVE))
	_each(1, 3, func(g: GeneratedCase) -> void:
		assert_eq(g.get_anomaly_kinds(), [K.MISSING_DOCUMENT] as Array[AnomalyType.Kind])
		assert_false(g.case.has_document(&"id_card"))
		assert_eq(g.key.get_violated_rule_ids(), [&"r_id_card_required"] as Array[StringName]))


func test_sc03_photo_of_another_person_with_noise() -> void:
	_each(2, 3, func(g: GeneratedCase) -> void:
		assert_eq(g.key.truth.faction_id, &"tyc")
		assert_eq(g.key.truth.sex, Passenger.SEX_M)
		assert_eq(g.get_anomaly_kinds(), [K.PORTRAIT_MISMATCH] as Array[AnomalyType.Kind])
		var photo: PassengerAppearance = Gen.photo(g.case)
		var face: PassengerAppearance = g.case.passenger_presented.appearance
		assert_gte(FaceComparator.compare_in(photo, face, Gen.data().appearance_catalog).size(), 3)
		assert_ne(photo.get_trait(PassengerAppearance.SLOT_HAIR), face.get_trait(PassengerAppearance.SLOT_HAIR), "bruit : coiffure")
		assert_true(g.case.dialogue_tags.has(CaseBuilder.TAG_OLD_PHOTO))
		assert_eq(g.key.expected_verdict, VerdictKind.Kind.DENY))


func test_sc04_mira_visor_then_approved() -> void:
	var ctx: RuleContext = Gen.data().make_context(3)
	_each(3, 2, func(g: GeneratedCase) -> void:
		var mira: Passenger = g.case.passenger_presented
		assert_eq(mira.full_name(), "Mira Vasquez-Orlov")
		assert_eq(mira.citizen_id, "HG-4471-K2Q9")
		assert_eq(mira.birth_date, GameDate.from_ymd(2151, 11, 2))
		assert_eq(mira.employer, "Kessler-Ashe Orbital")
		var purpose: StringName = Gen.doc_value(g.case, &"entry_permit", &"purpose")
		assert_eq(purpose, Passenger.PURPOSE_WORK)
		assert_true(g.visor_down)
		assert_true(g.case.dialogue_tags.has(CaseBuilder.TAG_VISOR_DOWN))
		assert_eq(g.key.expected_verdict, VerdictKind.Kind.APPROVE)
		var ref: FieldRef = Gen.portrait_ref(g.case)
		assert_eq(DiscrepancyChecker.check(g.case, FieldRef.passenger_face(), ref, ctx).result, Discrepancy.Result.INCOMPARABLE)
		assert_true(g.case.remove_visor())
		assert_false(g.case.remove_visor(), "déjà retirée")
		assert_eq(DiscrepancyChecker.check(g.case, FieldRef.passenger_face(), ref, ctx).result, Discrepancy.Result.CONCORDANT))


func test_sc05_messenger_one_character_on_permit() -> void:
	_each(3, 7, func(g: GeneratedCase) -> void:
		assert_eq(g.get_anomaly_kinds(), [K.ID_MISMATCH] as Array[AnomalyType.Kind])
		var anomaly: Anomaly = g.key.anomalies[0]
		assert_eq(anomaly.document_id, &"entry_permit")
		var before: String = anomaly.original_value
		var after: String = anomaly.injected_value
		var changed: int = 0
		for i: int in before.length():
			changed += int(before[i] != after[i])
		assert_eq(changed, 1)
		assert_eq(g.key.get_violated_rule_ids(), [&"r_identity_fields_match"] as Array[StringName])
		assert_true(g.case.dialogue_tags.has(&"sc05_luciole_messenger")))


func test_requires_flag_gates_a_scripted_case() -> void:
	var day: DayDef = Gen.data().get_day(1).duplicate()
	var gated: ScriptedCaseDef = ScriptedCaseDef.new()
	gated.id = &"gated"
	gated.at_index = 5
	gated.forced_anomalies = [K.MISSING_DOCUMENT]
	gated.requires_flag = &"met_mira"
	day.scripted_cases = [gated]
	var day_seed: int = Gen.day_seed(1, 1)
	assert_eq(CaseBuilder.new(Gen.data(), day, day_seed).build(5).scripted_id, &"")
	var flags: Array[StringName] = [&"met_mira"]
	var flagged: GeneratedCase = CaseBuilder.new(Gen.data(), day, day_seed, flags).build(5)
	assert_eq(flagged.scripted_id, &"gated")
	assert_eq(flagged.get_anomaly_kinds(), [K.MISSING_DOCUMENT] as Array[AnomalyType.Kind])
