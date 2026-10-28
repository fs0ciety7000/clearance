## Tests de propriétés du générateur (ARCHITECTURE §12) sur 1 000 graines de
## cas J1–J3 (jours complets, rotation) : déterminisme, cas propre, verdict
## (D-005, D-030), N° ID, noms, Okonkwo, invariants de visage, visière.
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const SEEDS: int = 1000

var _cases: Array[Array] = []
## Sérialisation de chaque cas (même ordre que `_cases`).
var _json: PackedStringArray = []


func before_all() -> void:
	_cases = Gen.collect_mvp_cases(SEEDS)
	for pair: Array in _cases:
		var generated: GeneratedCase = pair[1]
		_json.append(CaseSerializer.to_json(generated))


func test_collected_enough_cases() -> void:
	assert_eq(_cases.size(), SEEDS)


func test_determinism_same_seed_same_case() -> void:
	var failures: PackedStringArray = []
	var fresh: Dictionary[String, CaseBuilder] = {}
	for n: int in _cases.size():
		var builder: CaseBuilder = _cases[n][0]
		var generated: GeneratedCase = _cases[n][1]
		# Nouveau builder (roster reconstruit) ; le cas i est construit seul.
		var key: String = "%d|%d" % [builder.day.day_number, builder.day_seed]
		if not fresh.has(key):
			fresh[key] = CaseBuilder.new(Gen.data(), builder.day, builder.day_seed)
		var again: GeneratedCase = fresh[key].build(generated.case.index)
		if CaseSerializer.to_json(again) != _json[n]:
			failures.append(String(generated.case.case_id))
		if not again.case.passenger_presented.appearance.equals(builder.roster.entries[generated.case.index].appearance) \
				and not generated.visor_down:
			failures.append("%s : apparence ≠ roster" % generated.case.case_id)
	assert_eq(failures.size(), 0, Gen.head(failures))


func test_different_seeds_differ() -> void:
	var seen: Dictionary[String, bool] = {}
	for json: String in _json:
		seen[json] = true
	assert_eq(seen.size(), SEEDS, "deux graines ont produit le même cas")


func test_clean_case_has_no_violation() -> void:
	var failures: PackedStringArray = []
	# Chaque graine : le cas propre (avant injection) est conforme du premier coup.
	for pair: Array in _cases:
		var generated: GeneratedCase = pair[1]
		if generated.clean_violation_count != 0 or generated.clean_attempts != 1:
			failures.append("%s : %d violation(s), %d essai(s)" % [generated.case.case_id,
					generated.clean_violation_count, generated.clean_attempts])
	# Chemin complet sans anomalie (1 graine sur 10) : APPROUVÉ, aucune violation.
	for n: int in range(0, _cases.size(), 10):
		var builder: CaseBuilder = _cases[n][0]
		var generated: GeneratedCase = _cases[n][1]
		var clean: GeneratedCase = builder.build_with(generated.case.index, [])
		if not clean.key.expected_violations.is_empty() or clean.key.expected_verdict != VerdictKind.Kind.APPROVE:
			failures.append("%s : %s" % [generated.case.case_id, clean.key.expected_violations])
	assert_eq(failures.size(), 0, Gen.head(failures))


func test_expected_verdict_follows_rule_engine() -> void:
	var failures: PackedStringArray = []
	var approve: int = 0
	for pair: Array in _cases:
		var builder: CaseBuilder = pair[0]
		var generated: GeneratedCase = pair[1]
		var key: CaseKey = generated.key
		var recomputed: Array[Violation] = RuleEngine.validate(generated.case, builder.day.rule_set, builder.ctx)
		if recomputed.size() != key.expected_violations.size():
			failures.append("%s : violations recalculées différentes" % generated.case.case_id)
		if key.expected_verdict != RuleEngine.expected_verdict(key.expected_violations):
			failures.append("%s : verdict ≠ D-030" % generated.case.case_id)
		# Toutes les anomalies M3 sont détectables : APPROUVÉ ⇔ aucune anomalie.
		if (key.expected_verdict == VerdictKind.Kind.APPROVE) != key.anomalies.is_empty():
			failures.append("%s : verdict %d pour %d anomalie(s)" % [generated.case.case_id, key.expected_verdict, key.anomalies.size()])
		if key.expected_verdict == VerdictKind.Kind.DETAIN:
			failures.append("%s : DÉTENTION sans règle de sévérité 3 (J1–J3)" % generated.case.case_id)
		approve += int(key.expected_verdict == VerdictKind.Kind.APPROVE)
		if not generated.invariant_errors.is_empty():
			failures.append("%s : %s" % [generated.case.case_id, generated.invariant_errors])
	assert_eq(failures.size(), 0, Gen.head(failures))
	assert_between(approve, 350, 650, "part d'APPROUVÉ plausible (poids J1–J3)")


func test_each_anomaly_is_proven_by_an_active_rule() -> void:
	var failures: PackedStringArray = []
	var injected: int = 0
	for pair: Array in _cases:
		var builder: CaseBuilder = pair[0]
		var generated: GeneratedCase = pair[1]
		for anomaly: Anomaly in generated.key.anomalies:
			injected += 1
			if not builder.day.rule_set.can_detect(anomaly.type):
				failures.append("%s : %s hors RuleSet" % [generated.case.case_id, anomaly])
			if not CaseBuilder._is_proven(anomaly, generated.key.expected_violations, builder.ctx):
				failures.append("%s : %s non prouvée" % [generated.case.case_id, anomaly])
	assert_eq(failures.size(), 0, Gen.head(failures))
	assert_gt(injected, 300)


func test_citizen_ids_follow_format_and_origin() -> void:
	var failures: PackedStringArray = []
	for pair: Array in _cases:
		var generated: GeneratedCase = pair[1]
		var c: Case = generated.case
		var kinds: Array[AnomalyType.Kind] = generated.get_anomaly_kinds()
		var faction: FactionDef = Gen.data().factions[generated.key.truth.faction_id]
		for p: Passenger in [generated.key.truth, c.passenger_presented]:
			if not PassengerGenerator.is_valid_citizen_id_format(p.citizen_id):
				failures.append("%s : format %s" % [c.case_id, p.citizen_id])
		if not faction.matches_citizen_id(generated.key.truth.citizen_id):
			failures.append("%s : vrai N° %s ≠ origine %s" % [c.case_id, generated.key.truth.citizen_id, faction.code])
		for ref: FieldRef in c.find_refs_by_truth_path(&"citizen_id"):
			var value: String = str(c.get_value(ref))
			if not PassengerGenerator.is_valid_citizen_id_format(value):
				failures.append("%s : %s format %s" % [c.case_id, ref.key(), value])
			if not kinds.has(AnomalyType.Kind.ORIGIN_ID_MISMATCH) and not faction.matches_citizen_id(value):
				failures.append("%s : %s origine %s" % [c.case_id, ref.key(), value])
			if not kinds.has(AnomalyType.Kind.ID_MISMATCH) and value != c.passenger_presented.citizen_id:
				failures.append("%s : %s ≠ N° déclaré" % [c.case_id, ref.key()])
	assert_eq(failures.size(), 0, Gen.head(failures))


func test_names_come_from_the_right_pool_and_never_okonkwo() -> void:
	var failures: PackedStringArray = []
	for pair: Array in _cases:
		var generated: GeneratedCase = pair[1]
		var c: Case = generated.case
		var mismatch: bool = generated.get_anomaly_kinds().has(AnomalyType.Kind.NAME_MISMATCH)
		var names: PackedStringArray = []
		for p: Passenger in [generated.key.truth, c.passenger_presented]:
			var pool: NamePool = Gen.data().factions[p.faction_id].name_pool
			names.append_array([p.given_name, p.family_name])
			# Un personnage scénarisé garde son nom (réservé aux tirages, QA-002).
			if generated.scripted_id != &"":
				continue
			if pool.is_reserved_full_name(p.given_name, p.family_name):
				failures.append("%s : nom complet réservé %s %s" % [c.case_id, p.given_name, p.family_name])
			if not pool.given_names_for(p.sex).has(p.given_name):
				failures.append("%s : prénom %s hors réserve %s/%s" % [c.case_id, p.given_name, p.faction_id, p.sex])
			if not pool.get_family_names().has(p.family_name):
				failures.append("%s : nom %s hors réserve %s" % [c.case_id, p.family_name, p.faction_id])
		for path: StringName in [&"given_name", &"family_name"]:
			for ref: FieldRef in c.find_refs_by_truth_path(path):
				var value: String = str(c.get_value(ref))
				names.append(value)
				if not mismatch and value != str(c.passenger_presented.get(path)):
					failures.append("%s : %s ≠ identité déclarée" % [c.case_id, ref.key()])
		for text: String in names:
			if text.to_lower().contains("okonkwo"):
				failures.append("%s : Okonkwo généré" % c.case_id)
	assert_eq(failures.size(), 0, Gen.head(failures))


func test_birth_date_matches_apparent_age() -> void:
	var failures: PackedStringArray = []
	for pair: Array in _cases:
		var builder: CaseBuilder = pair[0]
		var generated: GeneratedCase = pair[1]
		var truth: Passenger = generated.key.truth
		var age: int = GameDate.age_on(truth.birth_date, builder.day.game_date)
		if PassengerGenerator.age_band_for_age(age) != truth.appearance.age_band or age < 18:
			failures.append("%s : %d ans, tranche %d" % [generated.case.case_id, age, truth.appearance.age_band])
	assert_eq(failures.size(), 0, Gen.head(failures))


func test_face_invariants_and_visor() -> void:
	var failures: PackedStringArray = []
	var visors: int = 0
	for pair: Array in _cases:
		var builder: CaseBuilder = pair[0]
		var generated: GeneratedCase = pair[1]
		var c: Case = generated.case
		if not c.passenger_presented.appearance.equals(generated.key.truth.appearance):
			failures.append("%s : apparence présentée modifiée" % c.case_id)
		var ref: FieldRef = Gen.portrait_ref(c)
		if ref == null:
			continue
		var face: bool = generated.has_face_anomaly()
		var differing: Array[StringName] = FaceComparator.compare(Gen.photo(c), c.passenger_presented.appearance, builder.ctx.identity_slots)
		if face == differing.is_empty():
			failures.append("%s : visage anomalie=%s différences=%s" % [c.case_id, face, differing])
		if not generated.visor_down:
			continue
		visors += 1
		var masked: Discrepancy = DiscrepancyChecker.check(c, FieldRef.passenger_face(), ref, builder.ctx)
		if masked.result != Discrepancy.Result.INCOMPARABLE or masked.reason_key != Discrepancy.REASON_FACE_MASKED:
			failures.append("%s : visière non INCOMPARABLE" % c.case_id)
		var copy: Case = _copy_case(c)
		copy.remove_visor()
		var after: Discrepancy = DiscrepancyChecker.check(copy, FieldRef.passenger_face(), ref, builder.ctx)
		var expected: Discrepancy.Result = Discrepancy.Result.DISCORDANT if face else Discrepancy.Result.CONCORDANT
		if after.result != expected:
			failures.append("%s : après retrait %d ≠ %d" % [c.case_id, after.result, expected])
	assert_eq(failures.size(), 0, Gen.head(failures))
	assert_gt(visors, 10, "des passagers arrivent visière baissée (J3)")


func test_hal_never_loses_a_permit() -> void:
	for pair: Array in _cases:
		var generated: GeneratedCase = pair[1]
		if generated.key.truth.faction_id != &"hal":
			continue
		for anomaly: Anomaly in generated.key.anomalies:
			assert_false(anomaly.type == AnomalyType.Kind.MISSING_DOCUMENT and anomaly.document_id == &"entry_permit",
					String(generated.case.case_id))


func test_early_expiry_is_one_to_ten_days() -> void:
	var failures: PackedStringArray = []
	for pair: Array in _cases:
		var builder: CaseBuilder = pair[0]
		var generated: GeneratedCase = pair[1]
		for anomaly: Anomaly in generated.key.anomalies:
			if anomaly.type != AnomalyType.Kind.EXPIRED_DOCUMENT:
				continue
			var injected: int = anomaly.injected_value
			var days: int = builder.day.game_date - injected
			if days < 1 or days > 10:
				failures.append("%s : expiré de %d j" % [generated.case.case_id, days])
	assert_eq(failures.size(), 0, Gen.head(failures))


func _copy_case(c: Case) -> Case:
	var result: Case = Case.new()
	result.case_id = c.case_id
	result.passenger_presented = c.passenger_presented.copy()
	for doc: DocumentInstance in c.documents:
		result.documents.append(doc.copy())
	return result
