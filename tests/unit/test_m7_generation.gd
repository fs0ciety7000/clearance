## M7 — génération J4–J10 (GDD §6, §8 ; NARRATIVE §4) : invariants et cas
## propres sur plusieurs graines, déterminisme, passagers scénarisés SC-06 →
## SC-22 (verdict attendu calculé par le moteur, D-005), avis de recherche,
## implants, origine interdite, enveloppes et codes Lucioles générés.
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const K := AnomalyType.Kind
const VK := VerdictKind.Kind
const SEEDS: int = 20
const FLAGS: Array[StringName] = [&"sc02_turned_away"]

var data: DataCatalog = null
## Jour → liste de journées générées (`Array[GeneratedCase]`), une par graine.
var _days: Dictionary[int, Array] = {}
## Jour → constructeurs, une par graine.
var _builders: Dictionary[int, Array] = {}


func before_all() -> void:
	data = Gen.data()
	for n: int in range(4, 11):
		_days[n] = []
		_builders[n] = []
		for s: int in SEEDS:
			var builder: CaseBuilder = _builder(n, s)
			_builders[n].append(builder)
			_days[n].append(builder.build_day())


func _builder(n: int, s: int) -> CaseBuilder:
	var day: DayDef = data.get_day(n)
	var memory: Dictionary = CaseMemory.resolve(data, day, SeededRng.mix(Gen.BASE_SEED, s), {})
	return CaseBuilder.new(data, day, Gen.day_seed(s, n), FLAGS, memory)


func _scripted(n: int, id: StringName) -> Array[GeneratedCase]:
	var result: Array[GeneratedCase] = []
	for list: Variant in _days[n]:
		var cases: Array = list
		for generated: Variant in cases:
			var g: GeneratedCase = generated
			if g.scripted_id == id:
				result.append(g)
	return result


func test_every_case_respects_invariants_and_cleanliness() -> void:
	var failures: PackedStringArray = []
	var seen: Dictionary[AnomalyType.Kind, int] = {}
	for n: int in _days:
		for list: Variant in _days[n]:
			var cases: Array = list
			assert_eq(cases.size(), data.get_day(n).passenger_count)
			for generated: Variant in cases:
				var g: GeneratedCase = generated
				var where: String = "%s" % g.case.case_id
				if not g.invariant_errors.is_empty():
					failures.append("%s : %s" % [where, g.invariant_errors])
				if g.clean_violation_count != 0:
					failures.append("%s : cas propre en infraction" % where)
				if g.key.anomalies.is_empty() and g.key.expected_verdict != VK.APPROVE:
					failures.append("%s : sans anomalie mais %s" % [where, g.key.get_violated_rule_ids()])
				for kind: AnomalyType.Kind in g.get_anomaly_kinds():
					seen[kind] = seen.get(kind, 0) + 1
	assert_eq(failures.size(), 0, Gen.head(failures))
	for kind: AnomalyType.Kind in [K.PURPOSE_MISMATCH, K.UNDECLARED_IMPLANT, K.BANNED_IMPLANT, K.IMPOSTOR_LOOKALIKE,
			K.RELATIVE_DOCUMENTS, K.BANNED_FACTION, K.INVALID_SEAL, K.MRZ_MISMATCH, K.WANTED_PERSON]:
		assert_gt(seen.get(kind, 0), 0, "%s rencontré J4–J10" % AnomalyType.name_of(kind))


func test_generation_is_deterministic() -> void:
	for n: int in [7, 10]:
		var a: Array[GeneratedCase] = _builder(n, 3).build_day()
		var b: Array[GeneratedCase] = _builder(n, 3).build_day()
		for i: int in a.size():
			assert_eq(CaseSerializer.to_json(a[i]), CaseSerializer.to_json(b[i]), "J%d cas %d" % [n, i])
		# Un cas construit seul est identique au même cas construit dans la journée.
		assert_eq(CaseSerializer.to_json(_builder(n, 3).build(9)), CaseSerializer.to_json(a[9]))


func test_scripted_cases_follow_narrative() -> void:
	# [jour, id, verdict attendu, règle violée attendue (vide = aucune)].
	var table: Array[Array] = [
		[4, &"sc_06", VK.APPROVE, &""], [4, &"sc_07", VK.DENY, &"r_id_card_valid"],
		[4, &"sc_08", VK.DENY, &"r_purpose_consistent"], [5, &"sc_09", VK.DENY, &"r_bioscan_required"],
		[5, &"sc_10", VK.APPROVE, &""], [6, &"sc_11", VK.APPROVE, &""],
		[6, &"sc_12", VK.DENY, &"r_identity_fields_match"], [7, &"sc_13", VK.DETAIN, &"r_identity_fraud_detain"],
		[7, &"sc_14", VK.DENY, &"r_implants_declared"], [8, &"sc_15", VK.APPROVE, &""],
		[8, &"sc_16", VK.DENY, &"r_tharsis_banned"], [8, &"sc_17", VK.DETAIN, &"r_apparent_age"],
		[9, &"sc_18", VK.APPROVE, &""], [9, &"sc_19", VK.DENY, &"r_seals_valid"],
		[10, &"sc_20", VK.DETAIN, &"r_wanted_detain"], [10, &"sc_21", VK.DENY, &"r_mrz_valid"],
		[10, &"sc_22", VK.DETAIN, &"r_wanted_detain"],
	]
	for row: Array in table:
		var day_number: int = row[0]
		var id: StringName = row[1]
		var verdict: VerdictKind.Kind = row[2]
		var rule_id: StringName = row[3]
		var list: Array[GeneratedCase] = _scripted(day_number, id)
		assert_eq(list.size(), SEEDS, "%s présent chaque jour" % id)
		for g: GeneratedCase in list:
			assert_eq(g.key.expected_verdict, verdict, "%s %s" % [id, g.key.get_violated_rule_ids()])
			if rule_id != &"":
				assert_true(g.key.get_violated_rule_ids().has(rule_id), "%s viole %s" % [id, rule_id])
			assert_eq(g.invariant_errors, PackedStringArray(), String(id))


func test_scripted_case_details() -> void:
	for g: GeneratedCase in _scripted(4, &"sc_07"):
		assert_eq(g.case.slipped_items.size(), 1)
		assert_eq(g.case.slipped_items[0].amount, 20)
		assert_eq(g.case.slipped_items[0].default_decision, SlippedItem.Decision.RETURN)
	for g: GeneratedCase in _scripted(4, &"sc_08"):
		assert_eq(g.case.presentation, CaseBuilder.PRESENTATION_KNOCK, "code 5")
		assert_eq(Gen.doc_value(g.case, &"entry_permit", &"employer"), "SANS EMPLOYEUR")
	for g: GeneratedCase in _scripted(5, &"sc_09"):
		assert_true(g.case.get_document(&"id_card").mrz.ends_with("07"), "code 2 : MRZ en 07")
		assert_false(g.case.has_document(&"bioscan"))
	for g: GeneratedCase in _scripted(5, &"sc_10"):
		assert_true(g.case.get_document(&"entry_permit").serial.ends_with("7"), "code 3")
	for g: GeneratedCase in _scripted(6, &"sc_11"):
		assert_true(g.case.has_document(&"mil_waiver"), "dérogation MIL")
		assert_eq(g.case.passenger_presented.implants, PackedStringArray(["MIL-9"]))
	for g: GeneratedCase in _scripted(7, &"sc_13"):
		assert_eq(g.key.truth.full_name(), "Lev Petrenko", "vraie identité (D-036)")
		assert_eq(g.case.passenger_presented.full_name(), "Soren Whitmore")
		assert_true(g.case.passenger_presented.appearance.is_face_covered(), "visière baissée")
		assert_true(g.case.get_document(&"bioscan").marks.has(CaseBuilder.MARK_LUCIOLE), "code 1")
		assert_true(g.case.dialogue_tags.has(CaseBuilder.TAG_LUCIOLE_PASSWORD), "code 4")
	for g: GeneratedCase in _scripted(7, &"sc_14"):
		assert_true(g.case.passenger_presented.implants.has("DER-19"))
		assert_eq(g.case.slipped_items[0].amount, 25)
	for g: GeneratedCase in _scripted(8, &"sc_17"):
		assert_eq(g.key.truth.given_name, "Fatou")
		assert_eq(Gen.doc_value(g.case, &"id_card", &"given_name"), "Ngozi")
		assert_eq(Gen.doc_value(g.case, &"id_card", &"birth_date"), GameDate.from_ymd(2146, 2, 4))
	for g: GeneratedCase in _scripted(9, &"sc_18"):
		var note: SlippedItem = g.case.slipped_items[0]
		assert_eq(note.kind, SlippedItem.Kind.NOTE)
		assert_true(note.is_allowed(SlippedItem.Decision.REPORT) and note.is_allowed(SlippedItem.Decision.KEEP))
	for g: GeneratedCase in _scripted(10, &"sc_20"):
		assert_eq(g.key.truth.full_name(), "Arkady Novak")
		assert_eq(g.case.passenger_presented.full_name(), "Bastien Duval")
	for g: GeneratedCase in _scripted(10, &"sc_21"):
		assert_true(g.case.get_document(&"id_card").mrz.contains("<<PHILIPA<<"), g.case.get_document(&"id_card").mrz)
		assert_eq(g.case.slipped_items[0].amount, 50)
	for g: GeneratedCase in _scripted(10, &"sc_22"):
		assert_eq(g.case.passenger_presented.citizen_id, "HG-4471-K2Q9")
		assert_eq(g.case.luciole_codes, PackedInt32Array([4, 6, 7]))


func test_wanted_notices_of_day_ten() -> void:
	for s: int in SEEDS:
		var builder: CaseBuilder = _builders[10][s]
		var notices: Array[WantedNotice] = builder.get_wanted_notices()
		assert_eq(notices.size(), 3)
		var indices: Array[int] = []
		for notice: WantedNotice in notices:
			indices.append(notice.case_index)
		assert_eq(indices, [3, 10, 13] as Array[int])
		assert_eq(notices[1].full_name(), "Mira Vasquez-Orlov")
		assert_eq(notices[0].full_name(), "Arkady Novak")
		var cases: Array = _days[10][s]
		for i: int in cases.size():
			var g: GeneratedCase = cases[i]
			var wanted: bool = g.key.get_violated_rule_ids().has(&"r_wanted_detain")
			assert_eq(wanted, indices.has(i), "J10 cas %d : recherché ⇔ sur l'avis" % i)
		var generated: GeneratedCase = cases[13]
		assert_eq(generated.get_anomaly_kinds(), [K.WANTED_PERSON] as Array[AnomalyType.Kind])
		assert_eq(generated.key.expected_verdict, VK.DETAIN)


func test_implants_drawn_only_when_rule_is_active() -> void:
	var with_implants: Dictionary[int, int] = {}
	for n: int in _days:
		for list: Variant in _days[n]:
			var cases: Array = list
			for generated: Variant in cases:
				var g: GeneratedCase = generated
				if g.scripted_id != &"" or g.key.anomalies.size() > 0:
					continue
				if not g.case.passenger_presented.implants.is_empty():
					with_implants[n] = with_implants.get(n, 0) + 1
					var declared: Variant = Gen.doc_value(g.case, &"id_card", &"implants")
					assert_eq(FieldValue.normalize(declared), FieldValue.normalize(g.case.passenger_presented.implants))
	assert_false(with_implants.has(4) or with_implants.has(5), "pas d'implants avant R15 (J6)")
	assert_gt(with_implants.get(6, 0), 0)


func test_tharsians_are_diplomats_when_banned() -> void:
	var count: int = 0
	for n: int in [8, 9, 10]:
		for list: Variant in _days[n]:
			var cases: Array = list
			for generated: Variant in cases:
				var g: GeneratedCase = generated
				if g.key.truth.faction_id != &"thr" or g.key.anomalies.size() > 0 or g.scripted_id != &"":
					continue
				count += 1
				assert_eq(g.case.passenger_presented.purpose, Passenger.PURPOSE_DIPLOMATIC)
				assert_eq(g.key.expected_verdict, VK.APPROVE)
	assert_gt(count, 0)


func test_generated_bribes_and_luciole_codes() -> void:
	var bribes: int = 0
	var codes: int = 0
	for n: int in _days:
		var day: DayDef = data.get_day(n)
		for list: Variant in _days[n]:
			var cases: Array = list
			for generated: Variant in cases:
				var g: GeneratedCase = generated
				if g.scripted_id != &"":
					continue
				for item: SlippedItem in g.case.slipped_items:
					bribes += 1
					assert_false(g.key.anomalies.is_empty(), "enveloppe seulement en infraction (GDD §5.5)")
					assert_between(item.amount, day.bribe_amounts.x, day.bribe_amounts.y)
					assert_eq(item.effects_for(VK.DENY, SlippedItem.Decision.KEEP), {&"suspicion": 1})
				for code: int in g.case.luciole_codes:
					codes += 1
					assert_gte(n, CaseBuilder.LUCIOLE_CODE_DAYS[code], "code %d introduit au J%d" % [code, CaseBuilder.LUCIOLE_CODE_DAYS[code]])
	assert_gt(bribes, 0)
	assert_gt(codes, 0)


func test_mrz_round_trip() -> void:
	var mrz: String = Mrz.compose("HG-4471-K2Q9", "TYC", "Vasquez-Orlov", "Mira")
	assert_eq(mrz, "HG4471K2Q9<TYC<VASQUEZ<ORLOV<<MIRA<<04")
	var parsed: Dictionary[StringName, String] = Mrz.parse(mrz)
	assert_eq(parsed[Mrz.COMPONENT_FAMILY], "VASQUEZ<ORLOV")
	assert_eq(parsed[Mrz.COMPONENT_GIVEN], "MIRA")
	assert_true(Mrz.component_matches(mrz, Mrz.COMPONENT_ID, "HG-4471-K2Q9"))
	assert_true(Mrz.component_matches(mrz, Mrz.COMPONENT_ORIGIN, &"tyc", "TYC"))
	assert_eq(Mrz.clean("Achebe-Sörensen"), "ACHEBE<SORENSEN")
	assert_eq(Mrz.clean("Kovač"), "KOVAC")
	# Les deux derniers caractères ne comptent jamais (code Luciole 07).
	var luciole: String = mrz.left(mrz.length() - 2) + "07"
	assert_true(Mrz.component_matches(luciole, Mrz.COMPONENT_GIVEN, "Mira"))
	assert_eq(Mrz.issuer_of(luciole), "07")
	assert_false(Mrz.component_matches(Mrz.with_component(mrz, Mrz.COMPONENT_GIVEN, "MIRAA"), Mrz.COMPONENT_GIVEN, "Mira"))
