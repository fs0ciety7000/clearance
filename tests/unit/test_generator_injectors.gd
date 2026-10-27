## Injecteurs d'anomalies (ARCHITECTURE §9.2–§9.3) sur 1 000 graines, avec un
## jour fictif où **toutes** les règles sont actives : chaque injecteur
## provoque la violation attendue, citant le champ corrompu ; propriétés
## spécifiques (sosie 1–2 traits, photo d'un autre ≥ 3, N° ID…).
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const SEEDS: int = 1000
const K := AnomalyType.Kind

## Règle attendue par type (jour « toutes règles »).
const EXPECTED_RULES: Dictionary[AnomalyType.Kind, Array] = {
	K.EXPIRED_DOCUMENT: [&"r_id_card_valid", &"r_permit_valid", &"r_bioscan_valid"],
	K.MISSING_DOCUMENT: [&"r_id_card_required", &"r_permit_required", &"r_bioscan_required"],
	K.PORTRAIT_MISMATCH: [&"r_portrait_match"],
	K.IMPOSTOR_LOOKALIKE: [&"r_portrait_match"],
	K.ID_MISMATCH: [&"r_identity_fields_match"],
	K.NAME_MISMATCH: [&"r_identity_fields_match"],
	K.ORIGIN_ID_MISMATCH: [&"r_origin_block"],
	K.WRONG_ISSUER: [&"r_bioscan_issuer"],
	K.BIOSCAN_UNFIT: [&"r_bioscan_fit"],
}

var _kinds: Array[AnomalyType.Kind] = []
## `[builder, generated, kind]` pour chaque graine (un type imposé par graine).
var _single: Array[Array] = []


func before_all() -> void:
	_kinds = InjectorRegistry.supported_kinds()
	var day: DayDef = Gen.full_day()
	var builder: CaseBuilder = null
	for s: int in SEEDS:
		if s % day.passenger_count == 0:
			builder = CaseBuilder.new(Gen.data(), day, Gen.day_seed(1000 + s, day.day_number))
		var kind: AnomalyType.Kind = _kinds[s % _kinds.size()]
		_single.append([builder, builder.build_with(s % day.passenger_count, [kind]), kind])


func test_at_least_six_anomaly_types_are_injectable() -> void:
	assert_gte(_kinds.size(), 6)
	for kind: AnomalyType.Kind in [K.EXPIRED_DOCUMENT, K.MISSING_DOCUMENT, K.ID_MISMATCH, K.NAME_MISMATCH,
			K.ORIGIN_ID_MISMATCH, K.PORTRAIT_MISMATCH, K.IMPOSTOR_LOOKALIKE]:
		assert_true(_kinds.has(kind), AnomalyType.name_of(kind))
	for kind: AnomalyType.Kind in _kinds:
		assert_true(EXPECTED_RULES.has(kind), AnomalyType.name_of(kind))


func test_each_injector_triggers_its_rule() -> void:
	var failures: PackedStringArray = []
	var per_kind: Dictionary[AnomalyType.Kind, int] = {}
	for triple: Array in _single:
		var builder: CaseBuilder = triple[0]
		var generated: GeneratedCase = triple[1]
		var kind: AnomalyType.Kind = triple[2]
		var where: String = "%s %s" % [AnomalyType.name_of(kind), generated.case.case_id]
		if generated.key.anomalies.size() != 1:
			failures.append("%s : non injectée" % where)
			continue
		per_kind[kind] = per_kind.get(kind, 0) + 1
		var violated: Array[StringName] = generated.key.get_violated_rule_ids()
		var expected: Array = EXPECTED_RULES[kind]
		if not violated.any(func(rule_id: StringName) -> bool: return expected.has(rule_id)):
			failures.append("%s : règles %s" % [where, violated])
		if not CaseBuilder._is_proven(generated.key.anomalies[0], generated.key.expected_violations, builder.ctx):
			failures.append("%s : champ corrompu non cité" % where)
		if generated.key.expected_verdict != VerdictKind.Kind.DENY:
			failures.append("%s : verdict %d" % [where, generated.key.expected_verdict])
		if not generated.invariant_errors.is_empty():
			failures.append("%s : %s" % [where, generated.invariant_errors])
	assert_eq(failures.size(), 0, Gen.head(failures))
	for kind: AnomalyType.Kind in _kinds:
		var injected: int = per_kind.get(kind, 0)
		assert_gt(injected, 50, AnomalyType.name_of(kind))


func test_impostor_lookalike_changes_one_or_two_visible_identity_traits() -> void:
	var failures: PackedStringArray = []
	var catalog: AppearanceCatalog = Gen.data().appearance_catalog
	var compared: Array[StringName] = catalog.get_identity_slots()
	for triple: Array in _single:
		if triple[2] != K.IMPOSTOR_LOOKALIKE:
			continue
		var builder: CaseBuilder = triple[0]
		var generated: GeneratedCase = triple[1]
		var c: Case = generated.case
		var differing: Array[StringName] = FaceComparator.compare_in(Gen.photo(c), c.passenger_presented.appearance, catalog)
		if differing.size() < 1 or differing.size() > 2:
			failures.append("%s : %s" % [c.case_id, differing])
		for slot: StringName in differing:
			var def: AppearanceSlotDef = catalog.get_slot(slot)
			if def == null or not def.identity or not def.visible_in_portrait or not compared.has(slot):
				failures.append("%s : trait %s non biométrique visible" % [c.case_id, slot])
		var check: Discrepancy = DiscrepancyChecker.check(c, FieldRef.passenger_face(), Gen.portrait_ref(c), builder.ctx)
		if check.result != Discrepancy.Result.DISCORDANT or check.differing_traits != differing:
			failures.append("%s : comparateur %d" % [c.case_id, check.result])
		# L'usurpateur a une autre identité que celle des papiers, cohérents entre eux.
		var truth: Passenger = generated.key.truth
		if truth.citizen_id == c.passenger_presented.citizen_id:
			failures.append("%s : même N° ID que les papiers" % c.case_id)
		if generated.key.get_violated_rule_ids().has(&"r_identity_fields_match"):
			failures.append("%s : papiers incohérents" % c.case_id)
		if not c.passenger_presented.appearance.equals(truth.appearance):
			failures.append("%s : visage du passager modifié" % c.case_id)
	assert_eq(failures.size(), 0, Gen.head(failures))


func test_portrait_mismatch_is_another_person() -> void:
	var failures: PackedStringArray = []
	for triple: Array in _single:
		if triple[2] != K.PORTRAIT_MISMATCH:
			continue
		var generated: GeneratedCase = triple[1]
		var c: Case = generated.case
		var differing: Array[StringName] = FaceComparator.compare_in(Gen.photo(c), c.passenger_presented.appearance,
				Gen.data().appearance_catalog)
		var traits: int = differing.filter(func(slot: StringName) -> bool: return slot != FaceComparator.AGE_BAND_SLOT).size()
		if traits < 3:
			failures.append("%s : %s" % [c.case_id, differing])
	assert_eq(failures.size(), 0, Gen.head(failures))


func test_id_mismatch_alters_one_or_two_safe_characters() -> void:
	var failures: PackedStringArray = []
	for triple: Array in _single:
		if triple[2] != K.ID_MISMATCH:
			continue
		var generated: GeneratedCase = triple[1]
		var anomaly: Anomaly = generated.key.anomalies[0]
		var before: String = anomaly.original_value
		var after: String = anomaly.injected_value
		var changed: int = 0
		for i: int in before.length():
			if before[i] != after[i]:
				changed += 1
				if "OI01".contains(after[i]):
					failures.append("%s : caractère ambigu %s" % [generated.case.case_id, after])
		if changed < 1 or changed > 2 or before[3] != after[3] or not PassengerGenerator.is_valid_citizen_id_format(after):
			failures.append("%s : %s → %s" % [generated.case.case_id, before, after])
	assert_eq(failures.size(), 0, Gen.head(failures))


func test_origin_id_mismatch_is_consistent_across_documents() -> void:
	var failures: PackedStringArray = []
	for triple: Array in _single:
		if triple[2] != K.ORIGIN_ID_MISMATCH:
			continue
		var generated: GeneratedCase = triple[1]
		var c: Case = generated.case
		var faction: FactionDef = Gen.data().factions[c.passenger_presented.faction_id]
		for ref: FieldRef in c.find_refs_by_truth_path(&"citizen_id"):
			var value: String = str(c.get_value(ref))
			if faction.matches_citizen_id(value) or value != c.passenger_presented.citizen_id:
				failures.append("%s : %s" % [c.case_id, value])
		if generated.key.get_violated_rule_ids() != ([&"r_origin_block"] as Array[StringName]):
			failures.append("%s : %s" % [c.case_id, generated.key.get_violated_rule_ids()])
	assert_eq(failures.size(), 0, Gen.head(failures))


func test_random_multi_anomaly_cases_respect_exclusivity() -> void:
	var day: DayDef = Gen.full_day([0.0, 0.0, 0.5, 0.5])
	var failures: PackedStringArray = []
	var multi: int = 0
	for group: int in 25:
		var builder: CaseBuilder = CaseBuilder.new(Gen.data(), day, Gen.day_seed(5000 + group, day.day_number))
		for generated: GeneratedCase in builder.build_day():
			var faces: int = 0
			var fields: Dictionary[String, bool] = {}
			multi += int(generated.key.anomalies.size() >= 2)
			for anomaly: Anomaly in generated.key.anomalies:
				faces += int(CaseBuilder.FACE_ANOMALIES.has(anomaly.type))
				var key: String = "%s/%s" % [anomaly.document_id, anomaly.field_id]
				if fields.has(key):
					failures.append("%s : deux anomalies sur %s" % [generated.case.case_id, key])
				fields[key] = true
			if faces > 1:
				failures.append("%s : %d anomalies de visage" % [generated.case.case_id, faces])
			if not generated.invariant_errors.is_empty():
				failures.append("%s : %s" % [generated.case.case_id, generated.invariant_errors])
	assert_eq(failures.size(), 0, Gen.head(failures))
	assert_gt(multi, 200, "cas à plusieurs anomalies")


func test_injection_is_skipped_when_rule_is_inactive() -> void:
	# J1 : seules R01/R02 ; aucun type hors RuleSet n'est tiré.
	var builder: CaseBuilder = CaseBuilder.new(Gen.data(), Gen.data().get_day(1), Gen.day_seed(9, 1))
	var drawable: Array[AnomalyType.Kind] = builder.get_drawable_kinds()
	drawable.sort()
	assert_eq(drawable, [K.EXPIRED_DOCUMENT, K.MISSING_DOCUMENT] as Array[AnomalyType.Kind])
	var state: InjectionState = InjectionState.new()
	var c: GeneratedCase = builder.build_with(4, [])
	state.case = c.case
	state.truth = c.key.truth
	state.rng = SeededRng.new(1)
	state.ctx = builder.ctx
	state.data = Gen.data()
	state.appearance_gen = builder.appearance_gen
	for injector: AnomalyInjector in [PortraitMismatchInjector.new(), IdMismatchInjector.new(), WrongIssuerInjector.new()]:
		assert_null(injector.inject(state), AnomalyType.name_of(injector.get_kind()))
	assert_eq(state.used.size(), 0, "aucune modification si l'injection est impossible")
