## M12 (docs/M12.md §6 ; B56, B62) — équilibrage et propriétés de la Garde de
## nuit (bots constants 80 % et 90 %, bot dégressif (D-136), aucun cas insoluble, exercice garanti,
## déterminisme quels que soient les verdicts) et calendrier des événements de
## station (nombre par campagne, jours et classes permis).
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")

var data: DataCatalog = null


func before_all() -> void:
	data = Gen.data()


func _scores(accuracy: float, count: int, base: int) -> Array[int]:
	var scores: Array[int] = []
	var profile: SimProfile = SimProfile.preset(&"default", accuracy)
	for n: int in count:
		var r: Dictionary = BalanceSimulator.run_garde(data, GardeService.code_from_bits(SeededRng.mix(base, n)), profile, n)
		scores.append(int(r["score"]))
	scores.sort()
	return scores


func _median(sorted: Array[int]) -> float:
	var mid: int = sorted.size() / 2
	return float(sorted[mid]) if sorted.size() % 2 == 1 else (sorted[mid - 1] + sorted[mid]) / 2.0


## Bot constant à 80 % : médiane 11 ± 1, p10 ≥ 3, p90 ≤ 26 (M12 §6.1).
func test_garde_median_with_an_80_percent_bot() -> void:
	var scores: Array[int] = _scores(0.8, 400, 2026)
	var median: float = _median(scores)
	assert_between(median, 10.0, 12.0, "médiane %.1f" % median)
	assert_gte(scores[roundi(0.1 * (scores.size() - 1))], 3, "p10")
	assert_lte(scores[roundi(0.9 * (scores.size() - 1))], 26, "p90")


## Bot constant à 90 % : médiane 25 ± 2.
func test_garde_median_with_a_90_percent_bot() -> void:
	var median: float = _median(_scores(0.9, 300, 1029))
	assert_between(median, 23.0, 27.0, "médiane %.1f" % median)


## Bot dégressif (95 % au palier 0, −4 points par palier, −0,5 point par unité
## active au-delà de 6) : médiane entre 30 et 40 (D-136, mesuré ≈ 36).
func test_garde_median_with_the_decaying_bot() -> void:
	var scores: Array[int] = []
	var profile: SimProfile = SimProfile.garde_decaying()
	for n: int in 200:
		var r: Dictionary = BalanceSimulator.run_garde(data, GardeService.code_from_bits(SeededRng.mix(4711, n)), profile, n)
		scores.append(int(r["score"]))
	scores.sort()
	var median: float = _median(scores)
	assert_between(median, 30.0, 40.0, "médiane %.1f" % median)


## Joueur parfait sur ≈ 10 000 passagers : aucune citation, toute violation a
## une preuve citable, aucun invariant violé, directives exercées.
func test_no_insoluble_case_over_ten_thousand_passengers() -> void:
	var perfect: SimProfile = SimProfile.preset(&"default", 1.0)
	var passengers: int = 0
	var windows: int = 0
	var exercised: int = 0
	var n: int = 0
	while passengers < 10_000:
		var r: Dictionary = BalanceSimulator.run_garde(data, GardeService.code_from_bits(SeededRng.mix(77, n)), perfect, n, 400)
		n += 1
		passengers += int(r["passengers"])
		assert_eq(int(r["citations"]), 0, "garde %d : aucune citation" % n)
		assert_eq(int(r["violations_without_evidence"]), 0, "garde %d : %s" % [n, r["insoluble"]])
		assert_eq(r["invariant_failures"], [], "garde %d" % n)
		var ex: Dictionary = r["exercised"]
		for k: Variant in ex:
			windows += 1
			exercised += 1 if ex[k] else 0
		assert_gte(int(r["palier"]), 4, "garde %d : palier 4 « Rotation » atteint" % n)
	assert_gte(float(exercised) / windows, 0.99, "directives exercées : %d / %d" % [exercised, windows])


## Même graine → mêmes passagers, quels que soient les verdicts (M12 §6.3).
func test_garde_is_deterministic_whatever_the_verdicts() -> void:
	for n: int in 6:
		var code: String = GardeService.code_from_bits(SeededRng.mix(31, n))
		var a: PackedStringArray = []
		var b: PackedStringArray = []
		BalanceSimulator.run_garde(data, code, SimProfile.preset(&"default", 1.0), 1, 60, null, null, a)
		BalanceSimulator.run_garde(data, code, SimProfile.preset(&"default", 0.9), 2, 60, null, null, b)
		var common: int = mini(a.size(), b.size())
		assert_gt(common, 0)
		assert_eq(a.slice(0, common), b.slice(0, common), code)


## Calendrier : 4 à 5 événements en moyenne (M12 §3.4), 3 à 6 dans ≥ 90 % des
## graines (D-136), jamais un jour exclu, jamais de classe B un jour « A seulement ».
func test_event_schedule_counts_and_days() -> void:
	var counts: Array[int] = []
	var def: StationEventsDef = data.station_events
	for n: int in 1000:
		var schedule: Dictionary = BalanceSimulator.event_schedule(data, SeededRng.mix(5, n))
		counts.append(schedule.size())
		for day_number: Variant in schedule:
			var plan: StationEventPlan = schedule[day_number]
			assert_true(def.eligible_days.has(int(day_number)), "J%d éligible" % day_number)
			assert_true((def.eligible_days[int(day_number)] & int(plan.event.event_class)) != 0, "J%d classe" % day_number)
	var total: int = 0
	var in_range: int = 0
	for c: int in counts:
		total += c
		in_range += 1 if c >= 3 and c <= 6 else 0
	var mean: float = float(total) / counts.size()
	assert_between(mean, 4.0, 5.0, "moyenne %.2f" % mean)
	# Cible M12 §6.2 : ≥ 90 % des graines entre 3 et 6 (calendrier stratifié, D-136).
	assert_gte(float(in_range) / counts.size(), 0.90, "3 à 6 événements : %d / %d" % [in_range, counts.size()])
