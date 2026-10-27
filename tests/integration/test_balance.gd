## Non-régression d'équilibrage du foyer (GDD §5.3, §14, D-047) : simulation
## rapide J1–J3 (`BalanceSimulator`, données réelles, 30 graines) par profil de
## précision avec la politique de dépenses « raisonnable ». Seuils larges : le
## détail se mesure avec `tools/balance_sim.gd` (200 graines).
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const SEEDS: int = 30
const BASE_SEED: int = 1

var data: DataCatalog = null


func before_all() -> void:
	data = Gen.data()


## Agrégats par profil : {all_sick: Array[int] par jour, endings: int,
## any_unpaid: Array[int] par jour, sick_j3: int (proches malades/graves/perdus au J3)}.
func _measure(accuracy: float) -> Dictionary:
	var last: int = data.get_last_day_number()
	var all_sick: Array[int] = []
	var any_unpaid: Array[int] = []
	for i: int in last:
		all_sick.append(0)
		any_unpaid.append(0)
	var endings: int = 0
	var sick_last: int = 0
	for n: int in SEEDS:
		var rows: Array[Dictionary] = BalanceSimulator.run_campaign(data, SeededRng.mix(BASE_SEED, n), accuracy)
		for row: Dictionary in rows:
			var i: int = int(row["day"]) - 1
			if row["all_sick"]:
				all_sick[i] += 1
			var unpaid: Dictionary = row["unpaid"]
			for id: StringName in BalanceSimulator.TRACKED_LINES:
				if int(unpaid[id]) > 0:
					any_unpaid[i] += 1
					break
			if row["ending"] != EveningReport.ENDING_NONE:
				endings += 1
			if i == last - 1:
				sick_last += int(row["sick"]) + int(row["grave"]) + int(row["lost"])
	return {"all_sick": all_sick, "endings": endings, "any_unpaid": any_unpaid, "sick_last": sick_last}


func test_simulation_is_deterministic() -> void:
	var a: Array[Dictionary] = BalanceSimulator.run_campaign(data, 42, 0.8)
	var b: Array[Dictionary] = BalanceSimulator.run_campaign(data, 42, 0.8)
	assert_eq(a, b)
	assert_eq(a.size(), data.get_last_day_number())


func test_reasoned_selection_priorities() -> void:
	var economy: EconomyDef = data.get_economy()
	var home: Household = Household.new()
	home.get_member(Household.NOA).health = Household.Health.SICK
	home.get_member(Household.DORA).health = Household.Health.SICK
	home.get_member(Household.DORA).untreated_evenings = economy.untreated_worsen_evenings - 1
	var lines: Array[ExpenseLine] = EveningService.build_lines(economy, 3, home)
	var budget: int = economy.air_tax + economy.rent + economy.food + economy.medicine_per_member + economy.heating
	BalanceSimulator.reasoned_selection(economy, lines, budget, home)
	var paid: Array[StringName] = []
	for line: ExpenseLine in lines:
		if line.paid:
			paid.append(line.id)
	assert_eq(paid, [&"rent", &"air_tax", &"food", &"heating", &"meds_dora"] as Array[StringName],
			"soins urgents (Dora s'aggraverait) avant le chauffage, soins de Noa en dernier")


func test_good_player_keeps_household_standing() -> void:
	var m: Dictionary = _measure(0.8)
	var all_sick: Array[int] = m["all_sick"]
	assert_lte(all_sick[1], 5, "80 % : foyer entièrement malade au J2 dans ≤ 5/30 cas (mesuré 5 % sur 200 graines)")
	assert_lte(all_sick[all_sick.size() - 1], 6, "80 % : foyer entièrement malade au J3 dans ≤ 6/30 cas")
	assert_eq(m["endings"], 0, "80 % : aucune fin anticipée sur J1–J3")
	var sacrificed: int = 0
	for count: int in m["any_unpaid"]:
		sacrificed += count
	assert_between(sacrificed, 6, 45, "80 % : des postes sacrifiés certains soirs (pression réelle, ~1 soir sur 4)")


func test_excellent_player_pays_almost_everything() -> void:
	var m: Dictionary = _measure(0.95)
	assert_eq(m["endings"], 0)
	var sacrificed: int = 0
	for count: int in m["any_unpaid"]:
		sacrificed += count
	assert_lte(sacrificed, 3, "95 % : presque aucun poste sacrifié sur 90 soirs")
	assert_lte(m["sick_last"], 2, "95 % : foyer en bonne santé au J3")


func test_poor_player_household_degrades_without_early_collapse() -> void:
	var m: Dictionary = _measure(0.6)
	var all_sick: Array[int] = m["all_sick"]
	assert_gte(all_sick[all_sick.size() - 1], 15, "60 % : foyer entièrement malade au J3 dans ≥ 15/30 cas")
	assert_lte(m["endings"], 5, "60 % : fin anticipée rare sur J1–J3 (3 loyers impayés d'affilée)")
