## Soirée au Bloc Pétrel (GDD §5.3, §5.4) : postes, présélection, évolution
## du foyer, fins anticipées F2 / F3 ; `Household` (JSON).
extends GutTest

var economy: EconomyDef = EconomyDef.new()


func _lines(day: int, home: Household) -> Array[ExpenseLine]:
	return EveningService.build_lines(economy, day, home)


func _pay(lines: Array[ExpenseLine], ids: Array[StringName]) -> Array[ExpenseLine]:
	for line: ExpenseLine in lines:
		line.paid = line.mandatory or ids.has(line.id)
	return lines


func _all_ids(lines: Array[ExpenseLine]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for line: ExpenseLine in lines:
		ids.append(line.id)
	return ids


func test_lines_follow_gdd() -> void:
	var home: Household = Household.new()
	var d1: Array[ExpenseLine] = _lines(1, home)
	assert_eq(_all_ids(d1), [&"rent", &"air_tax", &"food", &"heating"] as Array[StringName])
	assert_eq(EveningService.total_spent(_pay(d1, _all_ids(d1))), 38, "base quotidienne 38 ₵")
	var d2: Array[ExpenseLine] = _lines(2, home)
	assert_true(_all_ids(d2).has(&"oxygen"), "oxygène de Dora les soirs pairs")
	assert_eq(EveningService.total_spent(_pay(d2, _all_ids(d2))), 48)
	assert_eq(_lines(8, home)[0].cost, 20, "loyer à 20 ₵ au J8")
	home.get_member(Household.NOA).health = Household.Health.SICK
	var meds: Array[ExpenseLine] = _lines(3, home)
	assert_true(_all_ids(meds).has(&"meds_noa"))
	assert_eq(meds[meds.size() - 1].cost, 15)


func test_air_tax_is_mandatory() -> void:
	var lines: Array[ExpenseLine] = _lines(1, Household.new())
	EveningService.default_selection(lines, 0)
	assert_eq(EveningService.total_spent(lines), 5, "seule la taxe d'air, même à 0 ₵")
	var report: EveningReport = EveningService.apply(economy, 1, Household.new(), lines, 0, 1)
	assert_eq(report.balance_after, -5, "la taxe creuse la dette")
	assert_true(report.has_event("hh_ev_debt"))


func test_default_selection_leaves_heating_last() -> void:
	var lines: Array[ExpenseLine] = _lines(1, Household.new())
	EveningService.default_selection(lines, 32)
	var paid: Array[StringName] = []
	for line: ExpenseLine in lines:
		if line.paid:
			paid.append(line.id)
	assert_eq(paid, [&"rent", &"air_tax", &"food"] as Array[StringName], "32 ₵ : pas de chauffage (GDD §5.3)")
	EveningService.default_selection(lines, 40)
	assert_eq(EveningService.total_spent(lines), 38, "40 ₵ : tout est payé")
	assert_false(EveningService.can_toggle_on(_pay(_lines(1, Household.new()), [&"rent", &"food"]), 32, _lines(1, Household.new())[3]))


func test_full_payment_keeps_family_well() -> void:
	var lines: Array[ExpenseLine] = _pay(_lines(1, Household.new()), [&"rent", &"food", &"heating"])
	var report: EveningReport = EveningService.apply(economy, 1, Household.new(), lines, 40, 7)
	assert_eq(report.balance_after, 2)
	assert_eq(report.ending, EveningReport.ENDING_NONE)
	for member: Household.Member in report.household.members:
		assert_eq(member.health, Household.Health.WELL)
		assert_eq(member.state_key(), "hh_state_well")
	assert_true(report.has_event("hh_ev_calm"))


func test_cold_then_sick_and_noa_chance() -> void:
	var home: Household = Household.new()
	var noa_sick_seeds: int = 0
	for seed_value: int in 200:
		var report: EveningReport = EveningService.apply(economy, 1, home, _pay(_lines(1, home), [&"rent", &"food"]), 40, seed_value)
		for member: Household.Member in report.household.members:
			assert_true(member.cold)
		if report.household.get_member(Household.NOA).health == Household.Health.SICK:
			noa_sick_seeds += 1
			assert_true(report.has_event("hh_ev_noa_cough", Household.NOA))
	assert_between(noa_sick_seeds, 70, 130, "Noa malade à ~50 % au premier soir sans chauffage")
	var first: EveningReport = EveningService.apply(economy, 1, home, _pay(_lines(1, home), [&"rent", &"food"]), 40, 3)
	var second: EveningReport = EveningService.apply(economy, 2, first.household, _pay(_lines(2, first.household), [&"rent", &"food", &"oxygen"]), 40, 3)
	for member: Household.Member in second.household.members:
		assert_true(member.is_sick(), "2 soirs sans chauffage : %s malade" % member.id)
	var warm: Array[ExpenseLine] = _pay(_lines(3, second.household), [&"rent", &"food", &"heating"])
	var third: EveningReport = EveningService.apply(economy, 3, second.household, warm, 100, 3)
	for member: Household.Member in third.household.members:
		assert_false(member.cold)


func test_hunger_two_evenings_makes_sick() -> void:
	var home: Household = Household.new()
	var a: EveningReport = EveningService.apply(economy, 1, home, _pay(_lines(1, home), [&"rent", &"heating"]), 40, 1)
	assert_true(a.household.get_member(Household.ILAN).hungry)
	assert_eq(a.household.get_member(Household.ILAN).health, Household.Health.WELL)
	assert_eq(a.household.get_member(Household.ILAN).state_key(), "hh_state_hungry")
	var b: EveningReport = EveningService.apply(economy, 3, a.household, _pay(_lines(3, a.household), [&"rent", &"heating"]), 40, 1)
	assert_eq(b.household.get_member(Household.ILAN).health, Household.Health.SICK)


func test_medicine_cures_and_neglect_kills() -> void:
	var home: Household = Household.new()
	home.get_member(Household.DORA).health = Household.Health.SICK
	var cured: EveningReport = EveningService.apply(economy, 3, home, _pay(_lines(3, home), [&"rent", &"food", &"heating", &"meds_dora"]), 100, 1)
	assert_eq(cured.household.get_member(Household.DORA).health, Household.Health.WELL)
	var state: Household = home
	var healths: Array[Household.Health] = []
	for day: int in [3, 5, 7, 9]: # soirs impairs : pas d'oxygène
		var report: EveningReport = EveningService.apply(economy, day, state, _pay(_lines(day, state), [&"rent", &"food", &"heating"]), 200, 1)
		state = report.household
		healths.append(state.get_member(Household.DORA).health)
	assert_eq(healths, [Household.Health.SICK, Household.Health.GRAVELY_SICK, Household.Health.GRAVELY_SICK, Household.Health.LOST] as Array[Household.Health])


func test_oxygen_misses() -> void:
	var home: Household = Household.new()
	var first: EveningReport = EveningService.apply(economy, 2, home, _pay(_lines(2, home), [&"rent", &"food", &"heating"]), 100, 1)
	assert_eq(first.household.get_member(Household.DORA).health, Household.Health.SICK)
	assert_eq(first.household.oxygen_misses, 1)
	var second: EveningReport = EveningService.apply(economy, 4, first.household, _pay(_lines(4, first.household), [&"rent", &"food", &"heating", &"meds_dora"]), 100, 1)
	assert_eq(second.household.get_member(Household.DORA).health, Household.Health.GRAVELY_SICK, "2ᵉ manquement")


func test_rent_and_debt_endings() -> void:
	var home: Household = Household.new()
	var a: EveningReport = EveningService.apply(economy, 1, home, _pay(_lines(1, home), [&"food", &"heating"]), 40, 1)
	assert_eq(a.ending, EveningReport.ENDING_NONE)
	var b: EveningReport = EveningService.apply(economy, 2, a.household, _pay(_lines(2, a.household), [&"food", &"heating", &"oxygen"]), 40, 1)
	assert_eq(b.ending, EveningReport.ENDING_REASSIGNED, "2 loyers impayés consécutifs → F2")
	var state: Household = Household.new()
	var endings: Array[StringName] = []
	for day: int in [1, 3, 5]:
		var report: EveningReport = EveningService.apply(economy, day, state, _pay(_lines(day, state), [&"rent"]), 0, 1)
		state = report.household
		endings.append(report.ending)
	assert_eq(endings, [&"", &"", EveningReport.ENDING_REASSIGNED] as Array[StringName], "3 soirs en dette → F2")


func test_family_lost_ending_has_priority() -> void:
	var home: Household = Household.new()
	for member: Household.Member in home.members:
		member.health = Household.Health.GRAVELY_SICK
		member.untreated_evenings = 1
	var report: EveningReport = EveningService.apply(economy, 1, home, _pay(_lines(1, home), []), 0, 1)
	assert_true(report.household.all_lost())
	assert_eq(report.ending, EveningReport.ENDING_FAMILY_LOST)


func test_household_json_roundtrip() -> void:
	var home: Household = Household.new()
	home.get_member(Household.NOA).health = Household.Health.GRAVELY_SICK
	home.get_member(Household.ILAN).hungry = true
	home.get_member(Household.DORA).untreated_evenings = 1
	home.cold_streak = 2
	home.unpaid_rent_streak = 1
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(home.to_dict()))
	var back: Household = Household.from_dict(parsed)
	assert_eq(back.to_dict(), home.to_dict())
	assert_eq(Household.from_dict({"members": "corrompu"}).to_dict(), Household.new().to_dict())


func test_apply_does_not_mutate_input() -> void:
	var home: Household = Household.new()
	var before: Dictionary = home.to_dict()
	EveningService.apply(economy, 1, home, _pay(_lines(1, home), []), 0, 1)
	assert_eq(home.to_dict(), before)
