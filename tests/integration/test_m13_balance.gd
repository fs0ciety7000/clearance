## M13 « Gameplay » — simulation et équilibrage (docs/M13.md §4, D-151 ; B78) :
## jour « 0.12 » reconstruit par `M13Sim.strip`, joueur simulé (questions,
## fouille, motifs, temps), préréglages `presse`, `curieux`, `zele`,
## `economiste`, achats de l'Économat et déterminisme. Les cibles chiffrées
## (≤ 3 points par fin, D-151) se mesurent avec
## `tools/balance_sim.gd -- --m13=compare` sur ≥ 500 graines par préréglage
## (1 000 près du seuil ; lots `--from`, lignes `M13RAW`) : docs/M13.md §4.7
## (passe économique D-168 : prime de relevé, compensation +15 / +10 / +5 s,
## AG-01 → AG-03 à 25 ₵).
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const K := AnomalyType.Kind

var data: DataCatalog = null


func before_all() -> void:
	data = Gen.data()


func test_strip_rebuilds_the_0_12_day() -> void:
	var j8: DayDef = M13Sim.strip(data.get_day(8))
	for rule_id: StringName in M13Sim.RULE_IDS:
		assert_false(j8.rule_set.has_rule(rule_id), String(rule_id))
	assert_true(data.get_day(8).rule_set.has_rule(&"r_search_cause"), "le jour partagé n'est pas modifié")
	assert_eq(j8.duration_sec, data.get_day(8).duration_sec - M13Sim.EXTRA_SECONDS_LATE)
	assert_eq(j8.free_citations_per_day, 2)
	assert_false(j8.anomaly_weights.has(K.CONTRABAND))
	var j4: DayDef = M13Sim.strip(data.get_day(4))
	assert_almost_eq(j4.anomaly_weights[K.PURPOSE_MISMATCH], 0.21, 0.0001, "poids de la 0.12")
	assert_eq(j4.duration_sec, 600.0)
	for scripted: ScriptedCaseDef in j4.scripted_cases:
		assert_false(M13Sim.SCRIPTED_IDS.has(scripted.id))
	var builder: CaseBuilder = CaseBuilder.new(data, j4, Gen.day_seed(1, 4))
	for g: GeneratedCase in builder.build_day():
		assert_true(g.case.statements.is_empty(), "aucune déclaration en 0.12")
		assert_false(g.get_anomaly_kinds().has(K.STATEMENT_MISMATCH))


func test_rushed_player_misses_lies_and_curious_player_finds_them() -> void:
	var rushed: Dictionary = _play_days(&"presse", 0.95, [4, 5, 12, 13])
	var curious: Dictionary = _play_days(&"curieux", 0.95, [4, 5, 12, 13])
	assert_gt(rushed["lies"], 3.0)
	assert_lt(rushed["seen"] / rushed["lies"], curious["seen"] / curious["lies"], "questions = mensonges relevés")
	assert_gt(curious["seen"] / curious["lies"], 0.7)
	assert_gt(rushed["irregular"], curious["irregular"], "un mensonge non entendu passe")


func test_zealous_player_is_cited_for_searches_without_motive() -> void:
	var zealous: Dictionary = _play_days(&"zele", 0.95, [8, 9, 10])
	var careful: Dictionary = _play_days(&"default", 0.95, [8, 9, 10])
	assert_gt(zealous["searches"], careful["searches"])
	assert_gt(zealous["unwarranted"], 3.0, "fouilles sans motif")
	assert_gt(int(zealous["citations"].get("cit_unwarranted_search", 0)), 0, "FOUILLE SANS MOTIF")
	assert_eq(int(careful["citations"].get("cit_unwarranted_search", 0)), 0, "fouille sur motif seulement")
	assert_gt(zealous["seconds"], careful["seconds"], "fouiller coûte du temps")


func test_belt_search_is_done_by_a_careful_player() -> void:
	var careful: Dictionary = _play_days(&"default", 1.0, [19])
	assert_eq(int(careful["citations"].get("cit_search_skipped", 0)), 0, "R47 : fouille faite")
	var rushed: Dictionary = _play_days(&"presse", 1.0, [19])
	assert_gt(int(rushed["citations"].get("cit_search_skipped", 0)), 0, "R47 : FOUILLE OMISE sans fouille")


func test_time_model_and_compensation() -> void:
	var on: Dictionary = _play_days(&"default", 0.8, [4, 8, 12], true, true)
	var off: Dictionary = _play_days(&"default", 0.8, [4, 8, 12], true, false)
	assert_gt(on["seconds"] / on["processed"], off["seconds"] / off["processed"], "M13 : plus de temps par cas")
	assert_gt(on["share"], off["share"] - 0.08, "compensation : file traitée comparable")


## D-168 : la compensation (+10 s à l'Acte II, +5 s à l'Acte III) ne couvre
## pas tout le coût de M13 — sans amélioration, la file reste un peu sous la
## 0.12 (−8 points au plus sur ces jours) ; ce sont les améliorations qui
## rendent le temps, dans la limite de leur gain borné (M13 §3.1 : ≤ 6 s par
## cas, ≈ 12 % de file ; mesuré +7 points). Chaque passager traité en plus au-delà
## du quota est un dépassement (`suspicion`) : c'est la cause n° 1 des écarts de
## fins mesurés par la passe économique (M13 §4.7).
func test_compensation_does_not_outrun_the_0_12_queue() -> void:
	var days: Array = [12, 15, 18, 24, 27]
	var off: Dictionary = _play_days(&"default", 0.8, days, true, false)
	var bare: Dictionary = _play_days(&"default", 0.8, days, true, true)
	var equipped: Dictionary = _play_days(&"default", 0.8, days, true, true, true)
	assert_gt(bare["share"], off["share"] - 0.08, "sans amélioration : file comparable")
	assert_lt(bare["share"], off["share"], "sans amélioration : M13 coûte du temps")
	assert_lt(equipped["share"], off["share"] + 0.10, "équipé : gain borné (≤ 6 s par cas)")
	assert_gt(equipped["share"], bare["share"], "les améliorations rendent du temps")


func test_shop_purchases_follow_the_policy_and_are_deterministic() -> void:
	var smart: Array[Dictionary] = BalanceSimulator.run_campaign(data, 4242, 0.95, BalanceSimulator.Spending.REASONED, 14,
			SimProfile.preset(&"default", 0.95))
	var eager: Array[Dictionary] = BalanceSimulator.run_campaign(data, 4242, 0.95, BalanceSimulator.Spending.REASONED, 14,
			SimProfile.preset(&"economiste", 0.95))
	var never_profile: SimProfile = SimProfile.preset(&"default", 0.95)
	never_profile.upgrade_policy = SimProfile.UPGRADES_NEVER
	var never: Array[Dictionary] = BalanceSimulator.run_campaign(data, 4242, 0.95, BalanceSimulator.Spending.REASONED, 14,
			never_profile)
	assert_eq(_bought(never).size(), 0)
	assert_gte(_bought(eager).size(), _bought(smart).size(), "economiste : achète au moins autant")
	assert_gt(_bought(eager).size(), 0)
	for rows: Array[Dictionary] in [smart, eager]:
		var per_evening: int = 0
		for row: Dictionary in rows:
			per_evening = maxi(per_evening, (row.get("upgrades", []) as Array).size())
		assert_lte(per_evening, 1, "un achat par soir")
	var again: Array[Dictionary] = BalanceSimulator.run_campaign(data, 4242, 0.95, BalanceSimulator.Spending.REASONED, 14,
			SimProfile.preset(&"economiste", 0.95))
	assert_eq(_bought(again), _bought(eager), "déterministe")
	assert_eq(again[again.size() - 1]["balance_after"], eager[eager.size() - 1]["balance_after"])


## D-168 : prime de relevé — REFUS juste et documenté d'une violation de M13
## (puce de déclaration ou objet révélé), jamais sur un refus de papiers, une
## approbation ou un refus non documenté.
func test_finding_bonus_pays_documented_m13_findings_only() -> void:
	var day: DayDef = DayDef.new()
	day.rule_set = RuleSet.new()
	day.credit_per_correct = 5
	var lie: Violation = Violation.new(&"r_statements", [FieldRef.statement(&"stay"),
			FieldRef.new(&"entry_permit", &"stay_days")] as Array[FieldRef], "viol_statement", 2)
	var paper: Violation = Violation.new(&"r_expired", [FieldRef.new(&"id_card", &"expiry"),
			FieldRef.rulebook_rule(&"r_expired")] as Array[FieldRef], "viol_expired", 2)
	var item: Violation = Violation.new(&"r_contraband", [FieldRef.scan(&"z2", 0),
			FieldRef.contraband_entry(&"oxygen")] as Array[FieldRef], "viol_contraband", 2)
	assert_true(ScoringService.is_m13_finding([lie] as Array[Violation]))
	assert_true(ScoringService.is_m13_finding([item] as Array[Violation]))
	assert_false(ScoringService.is_m13_finding([paper] as Array[Violation]))
	var bonus: int = data.get_economy().finding_bonus
	assert_eq(bonus, 2, "D-168 : prime de relevé de 2 ₵")
	for violation: Violation in [lie, item]:
		var key: CaseKey = CaseKey.new()
		key.expected_verdict = VerdictKind.Kind.DENY
		key.expected_violations = [violation] as Array[Violation]
		var documented: Verdict = Verdict.new(&"c", VerdictKind.Kind.DENY)
		var pin: Discrepancy = Discrepancy.new(violation.refs[0], violation.refs[1])
		pin.confirmed = true
		documented.flagged = [pin] as Array[Discrepancy]
		var paid: CaseResult = ScoringService.score(documented, key, &"c", null, day, 5, false, bonus)
		assert_true(paid.correct)
		assert_eq(paid.wage, 5 + bonus, "REFUS documenté d'une trouvaille de M13")
		var bare: CaseResult = ScoringService.score(Verdict.new(&"c", VerdictKind.Kind.DENY), key, &"c", null, day, 5,
				false, bonus)
		assert_eq(bare.wage, 0, "REFUS NON MOTIVÉ : ni salaire ni prime")
		var missed: CaseResult = ScoringService.score(Verdict.new(&"c", VerdictKind.Kind.APPROVE), key, &"c", null, day, 5,
				false, bonus)
		assert_eq(missed.wage, 0, "ENTRÉE IRRÉGULIÈRE")
	var paper_key: CaseKey = CaseKey.new()
	paper_key.expected_verdict = VerdictKind.Kind.DENY
	paper_key.expected_violations = [paper] as Array[Violation]
	var paper_pin: Discrepancy = Discrepancy.new(paper.refs[0], paper.refs[1])
	paper_pin.confirmed = true
	var paper_verdict: Verdict = Verdict.new(&"c", VerdictKind.Kind.DENY)
	paper_verdict.flagged = [paper_pin] as Array[Discrepancy]
	assert_eq(ScoringService.score(paper_verdict, paper_key, &"c", null, day, 5, false, bonus).wage, 5,
			"refus de papiers : salaire seul")
	# Jour « 0.12 » : aucune prime possible (aucune violation de M13).
	var stripped: Dictionary = _play_days(&"default", 0.95, [12], false, false)
	assert_eq(stripped["lies"], 0.0)


func _bought(rows: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for row: Dictionary in rows:
		for upgrade: Variant in row.get("upgrades", []):
			result.append("J%d %s" % [row["day"], upgrade])
	return result


## Joue des jours isolés (drapeaux vides) et agrège les mesures M13.
func _play_days(preset: StringName, accuracy: float, days: Array, timed: bool = false, m13: bool = true,
		equipped: bool = false) -> Dictionary:
	var stats: Dictionary = {"lies": 0.0, "seen": 0.0, "searches": 0.0, "unwarranted": 0.0, "seconds": 0.0,
			"processed": 0, "planned": 0, "irregular": 0, "citations": {}, "share": 0.0}
	for seed_index: int in 6:
		for n: int in days:
			var profile: SimProfile = SimProfile.preset(preset, accuracy)
			profile.timed = timed
			profile.m13 = m13
			var flags: Dictionary[StringName, Variant] = {}
			if equipped:
				for upgrade_id: StringName in [UpgradeDef.ID_HYGIAPHONE, UpgradeDef.ID_WOOD_LAMP, UpgradeDef.ID_CALIBRATED_GATE,
						UpgradeDef.ID_ANNOTATED_BOOK, UpgradeDef.ID_QUEUE_MONITOR]:
					flags[UpgradeDef.flag_of(upgrade_id)] = true
			var summary: DaySummary = DaySimulator.play_day(data, n, Gen.day_seed(300 + seed_index, n), profile, flags, {},
					SeededRng.new(seed_index * 31 + n))
			stats["lies"] += float(summary.get_meta("m13_lies", 0.0))
			stats["seen"] += float(summary.get_meta("m13_lies_seen", 0.0))
			stats["searches"] += float(summary.get_meta("m13_searches", 0.0))
			stats["unwarranted"] += float(summary.get_meta("m13_unwarranted", 0.0))
			stats["seconds"] += float(summary.get_meta("m13_seconds", 0.0))
			stats["processed"] += summary.get_processed_count()
			stats["planned"] += summary.planned_cases
			for result: CaseResult in summary.results:
				if result.has_citation():
					var key: String = result.citation_reason_key
					(stats["citations"] as Dictionary)[key] = int((stats["citations"] as Dictionary).get(key, 0)) + 1
					if key == ScoringService.CIT_IRREGULAR_ENTRY:
						stats["irregular"] += 1
	stats["share"] = float(stats["processed"]) / maxi(int(stats["planned"]), 1)
	return stats
