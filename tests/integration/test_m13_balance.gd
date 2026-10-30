## M13 « Gameplay » — simulation et équilibrage (docs/M13.md §4, D-151 ; B78) :
## jour « 0.12 » reconstruit par `M13Sim.strip`, joueur simulé (questions,
## fouille, motifs, temps), préréglages `presse`, `curieux`, `zele`,
## `economiste`, achats de l'Économat et déterminisme. Les cibles chiffrées
## (≤ 3 points par fin sur 200 graines) se mesurent avec
## `tools/balance_sim.gd -- --m13=compare` (rapport du lot B).
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


func _bought(rows: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for row: Dictionary in rows:
		for upgrade: Variant in row.get("upgrades", []):
			result.append("J%d %s" % [row["day"], upgrade])
	return result


## Joue des jours isolés (drapeaux vides) et agrège les mesures M13.
func _play_days(preset: StringName, accuracy: float, days: Array, timed: bool = false, m13: bool = true) -> Dictionary:
	var stats: Dictionary = {"lies": 0.0, "seen": 0.0, "searches": 0.0, "unwarranted": 0.0, "seconds": 0.0,
			"processed": 0, "planned": 0, "irregular": 0, "citations": {}, "share": 0.0}
	for seed_index: int in 6:
		for n: int in days:
			var profile: SimProfile = SimProfile.preset(preset, accuracy)
			profile.timed = timed
			profile.m13 = m13
			var flags: Dictionary[StringName, Variant] = {}
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
