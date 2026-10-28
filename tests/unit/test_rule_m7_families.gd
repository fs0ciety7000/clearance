## M7 — familles de règles R09, R15–R22 (GDD §7) et comparaisons du mode
## Inspection associées (`DiscrepancyChecker`) : chaque violation d'une règle
## M7 est **prouvable** par la comparaison de ses deux premières références
## (zéro faux positif sur les cas propres), sévérités (DÉTENTION), cas limites
## (dérogation MIL, escalade J7, MRZ « 07 », avis de recherche).
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const K := AnomalyType.Kind
const SEEDS: int = 300
const M7_RULES: Array[StringName] = [&"r_purpose_consistent", &"r_implants_declared", &"r_banned_implants",
		&"r_identity_fraud_detain", &"r_apparent_age", &"r_tharsis_banned", &"r_seals_valid", &"r_mrz_valid"]
const M7_KINDS: Array[AnomalyType.Kind] = [K.PURPOSE_MISMATCH, K.UNDECLARED_IMPLANT, K.BANNED_IMPLANT,
		K.IMPOSTOR_LOOKALIKE, K.RELATIVE_DOCUMENTS, K.BANNED_FACTION, K.INVALID_SEAL, K.MRZ_MISMATCH]

var data: DataCatalog = null


func before_all() -> void:
	data = Gen.data()


func _full_day_builder(s: int) -> CaseBuilder:
	return CaseBuilder.new(data, Gen.full_day(), Gen.day_seed(5000 + s, 5))


func test_every_m7_violation_is_provable_by_its_first_two_refs() -> void:
	var failures: PackedStringArray = []
	var proven: Dictionary[StringName, int] = {}
	for s: int in SEEDS:
		var builder: CaseBuilder = _full_day_builder(floori(s / 12.0))
		var kind: AnomalyType.Kind = M7_KINDS[s % M7_KINDS.size()]
		var index: int = Gen.index_for(builder, kind, s % 12)
		if index < 0:
			continue
		var g: GeneratedCase = builder.build_with(index, [kind])
		g.case.remove_visor()
		for violation: Violation in g.key.expected_violations:
			if not M7_RULES.has(violation.rule_id):
				continue
			var d: Discrepancy = DiscrepancyChecker.check(g.case, violation.refs[0], violation.refs[1], builder.ctx)
			if not d.confirmed:
				failures.append("%s %s : %s ↔ %s → %s" % [violation.rule_id, g.case.case_id, violation.refs[0].key(),
						violation.refs[1].key(), d.reason_key])
			else:
				proven[violation.rule_id] = proven.get(violation.rule_id, 0) + 1
				assert_true(violation.is_documented_by(d))
	assert_eq(failures.size(), 0, Gen.head(failures))
	for rule_id: StringName in M7_RULES:
		assert_gt(proven.get(rule_id, 0), 0, String(rule_id))


func test_clean_cases_never_compare_discordant_on_m7_pairs() -> void:
	var failures: PackedStringArray = []
	for s: int in 40:
		var builder: CaseBuilder = _full_day_builder(100 + s)
		var g: GeneratedCase = builder.build_with(s % 12, [])
		g.case.remove_visor()
		var face: FieldRef = FieldRef.passenger_face()
		var pairs: Array[Array] = []
		for path: StringName in [&"implants", &"birth_date"]:
			for ref: FieldRef in g.case.find_refs_by_truth_path(path):
				pairs.append([face, ref])
		for mrz: FieldRef in g.case.find_refs_by_truth_path(&"document.mrz"):
			for component: StringName in Mrz.COMPONENTS:
				pairs.append([mrz, Rule.find_ref(g.case, mrz.document_id, component)])
		for rule: Rule in builder.day.rule_set.rules:
			for doc: DocumentInstance in g.case.documents:
				for field: FieldDef in doc.type_def.fields:
					pairs.append([rule.get_ref(), FieldRef.new(doc.get_document_id(), field.id)])
		for pair: Array in pairs:
			var a: FieldRef = pair[0]
			var b: FieldRef = pair[1]
			var d: Discrepancy = DiscrepancyChecker.check(g.case, a, b, builder.ctx)
			if d.confirmed:
				failures.append("%s : %s ↔ %s" % [g.case.case_id, a.key(), b.key()])
	assert_eq(failures.size(), 0, Gen.head(failures))


func test_undeclared_military_implant_escalates_from_day_seven() -> void:
	var rule: ImplantsDeclaredRule = data.rules[&"r_implants_declared"]
	for n: int in [6, 7]:
		var builder: CaseBuilder = CaseBuilder.new(data, data.get_day(n), Gen.day_seed(7, n))
		var g: GeneratedCase = builder.build_with(0, [K.UNDECLARED_IMPLANT], {&"implant": "MIL-9"})
		var violations: Array[Violation] = rule.evaluate(g.case, builder.ctx)
		assert_eq(violations.size(), 1)
		assert_eq(violations[0].severity, 3 if n >= 7 else 2, "J%d : MIL- non déclaré" % n)
		assert_eq(g.key.expected_verdict, VerdictKind.Kind.DETAIN if n >= 7 else VerdictKind.Kind.DENY)
	# Contrebande DER-19 non déclarée : refus, jamais une détention.
	var day7: CaseBuilder = CaseBuilder.new(data, data.get_day(7), Gen.day_seed(8, 7))
	assert_eq(day7.build_with(1, [K.UNDECLARED_IMPLANT], {&"implant": "DER-19"}).key.expected_verdict, VerdictKind.Kind.DENY)


func test_military_waiver_must_be_valid() -> void:
	var day: DayDef = data.get_day(6)
	var builder: CaseBuilder = CaseBuilder.new(data, day, Gen.day_seed(2, 6), [], CaseMemory.resolve(data, day, 1, {}))
	var rule: BannedImplantsRule = data.rules[&"r_banned_implants"]
	var g: GeneratedCase = builder.build(2)
	assert_eq(g.scripted_id, &"sc_11")
	assert_eq(rule.evaluate(g.case, builder.ctx).size(), 0, "dérogation valide")
	var waiver: DocumentInstance = g.case.get_document(&"mil_waiver")
	waiver.expiry_date = builder.ctx.today - 1
	assert_eq(rule.evaluate(g.case, builder.ctx).size(), 1, "dérogation expirée")
	waiver.expiry_date = builder.ctx.today + 30
	waiver.set_value(&"citizen_id", "HG-7000-ABCD")
	assert_eq(rule.evaluate(g.case, builder.ctx).size(), 1, "dérogation d'un autre")
	g.case.documents.erase(waiver)
	assert_eq(rule.evaluate(g.case, builder.ctx).size(), 1, "sans dérogation")
	var implants_ref: FieldRef = Rule.find_ref(g.case, &"id_card", &"implants")
	assert_eq(rule.check_against(g.case, implants_ref, builder.ctx), Discrepancy.Result.DISCORDANT)


func test_lookalike_rule_ignores_strangers_and_relatives_detain() -> void:
	var r17: PortraitMatchRule = data.rules[&"r_identity_fraud_detain"]
	var builder: CaseBuilder = CaseBuilder.new(data, data.get_day(8), Gen.day_seed(4, 8))
	var stranger: GeneratedCase = builder.build_with(0, [K.PORTRAIT_MISMATCH])
	assert_eq(r17.evaluate(stranger.case, builder.ctx).size(), 0, "≥ 3 traits : une autre personne (R03 seul)")
	assert_eq(stranger.key.expected_verdict, VerdictKind.Kind.DENY)
	var impostor: GeneratedCase = builder.build_with(1, [K.IMPOSTOR_LOOKALIKE])
	assert_eq(r17.evaluate(impostor.case, builder.ctx).size(), 1)
	assert_eq(impostor.key.expected_verdict, VerdictKind.Kind.DETAIN)
	var relative: GeneratedCase = builder.build_with(2, [K.RELATIVE_DOCUMENTS])
	assert_true(relative.key.get_violated_rule_ids().has(&"r_apparent_age"))
	assert_eq(relative.key.expected_verdict, VerdictKind.Kind.DETAIN)
	assert_eq(relative.case.passenger_presented.family_name, relative.key.truth.family_name, "même nom de famille")
	assert_ne(Gen.doc_value(relative.case, &"id_card", &"birth_date"), relative.key.truth.birth_date)


func test_banned_faction_and_purpose_rules() -> void:
	var r19: FactionBannedRule = data.rules[&"r_tharsis_banned"]
	var r09: PurposeConsistentRule = data.rules[&"r_purpose_consistent"]
	var builder: CaseBuilder = CaseBuilder.new(data, data.get_day(8), Gen.day_seed(9, 8))
	var ctx: RuleContext = builder.ctx
	var c: Case = null
	for i: int in builder.day.passenger_count:
		var candidate: Case = builder.build_with(i, []).case
		if candidate.has_document(&"entry_permit"):
			c = candidate
			break
	assert_not_null(c)
	var card: DocumentInstance = c.get_document(&"id_card")
	card.set_value(&"origin", &"thr")
	var permit: DocumentInstance = c.get_document(&"entry_permit")
	permit.set_value(&"purpose", Passenger.PURPOSE_DIPLOMATIC)
	assert_false(r19.is_violated(c), "THR diplomate admis")
	permit.set_value(&"purpose", Passenger.PURPOSE_TRADE)
	assert_true(r19.is_violated(c))
	assert_eq(r19.check_against(c, FieldRef.new(&"entry_permit", &"purpose"), ctx), Discrepancy.Result.DISCORDANT)
	permit.set_value(&"purpose", Passenger.PURPOSE_WORK)
	permit.set_value(&"employer", "SANS EMPLOYEUR")
	assert_true(r09.failed_checks(c, ctx).has(PurposeConsistentRule.CHECK_EMPLOYER))
	assert_eq(r09.check_against(c, FieldRef.new(&"entry_permit", &"employer"), ctx), Discrepancy.Result.DISCORDANT)
	permit.set_value(&"employer", "Kessler-Ashe Orbital")
	permit.set_value(&"stay_days", 999)
	assert_true(r09.failed_checks(c, ctx).has(PurposeConsistentRule.CHECK_VALIDITY))


func test_wanted_rule_by_face_and_by_name() -> void:
	var day: DayDef = data.get_day(10)
	var builder: CaseBuilder = CaseBuilder.new(data, day, Gen.day_seed(11, 10), [], CaseMemory.resolve(data, day, 11, {}))
	var arkady: GeneratedCase = builder.build(3)
	var face_check: Discrepancy = DiscrepancyChecker.check(arkady.case, FieldRef.wanted(&"wanted_novak"),
			FieldRef.passenger_face(), builder.ctx)
	assert_true(face_check.confirmed, "visage reconnu malgré les papiers d'emprunt")
	assert_eq(face_check.reason_key, Discrepancy.REASON_WANTED_MATCH)
	var name_check: Discrepancy = DiscrepancyChecker.check(arkady.case, FieldRef.wanted(&"wanted_novak"),
			Rule.find_ref(arkady.case, &"id_card", &"family_name"), builder.ctx)
	assert_eq(name_check.result, Discrepancy.Result.CONCORDANT, "le nom d'emprunt ne correspond pas")
	var mira: GeneratedCase = builder.build(10)
	assert_true(mira.case.passenger_presented.appearance.is_face_covered())
	var masked: Discrepancy = DiscrepancyChecker.check(mira.case, FieldRef.wanted(&"wanted_vasquez"),
			FieldRef.passenger_face(), builder.ctx)
	assert_eq(masked.reason_key, Discrepancy.REASON_FACE_MASKED)
	var by_name: Discrepancy = DiscrepancyChecker.check(mira.case, FieldRef.wanted(&"wanted_vasquez"),
			Rule.find_ref(mira.case, &"id_card", &"family_name"), builder.ctx)
	assert_true(by_name.confirmed, "Mira reconnue par le nom, visière baissée")
	assert_eq(DiscrepancyChecker.check(mira.case, FieldRef.wanted(&"inconnu"), FieldRef.passenger_face(), builder.ctx).reason_key,
			Discrepancy.REASON_UNKNOWN_FIELD)


func test_seal_and_mrz_rules() -> void:
	var builder: CaseBuilder = CaseBuilder.new(data, data.get_day(9), Gen.day_seed(12, 9))
	var g: GeneratedCase = builder.build_with(0, [])
	var seal: SealValidRule = data.rules[&"r_seals_valid"]
	var mrz: MrzConsistentRule = data.rules[&"r_mrz_valid"]
	assert_eq(seal.evaluate(g.case, builder.ctx).size(), 0)
	assert_eq(mrz.evaluate(g.case, builder.ctx).size(), 0)
	var card: DocumentInstance = g.case.get_document(&"id_card")
	card.mrz = card.mrz.left(card.mrz.length() - 2) + "07"
	assert_eq(mrz.evaluate(g.case, builder.ctx).size(), 0, "le code Luciole 07 n'est jamais une discordance")
	card.mrz = Mrz.with_component(card.mrz, Mrz.COMPONENT_ORIGIN, "XXX")
	assert_eq(mrz.wrong_components(g.case, builder.ctx), [Mrz.COMPONENT_ORIGIN] as Array[StringName])
	card.seal_id = &"seal_solar_hexagon_old"
	assert_eq(seal.evaluate(g.case, builder.ctx).size(), 1)
	assert_eq(seal.check_against(g.case, Rule.find_ref(g.case, &"id_card", &"document.seal_id"), builder.ctx),
			Discrepancy.Result.DISCORDANT)
