## D-113 (QA-049) : le mode Récit protège davantage — seuils d'arrestation de
## la Revue (J17) et de la Déposition (J29) relevés, aggravation du foyer plus
## lente — **seulement** en Récit (pseudo-drapeau de contexte
## `EndingService.FLAG_STORY_MODE`) ; le mode Dur garde ses valeurs.
extends GutTest

var economy: EconomyDef = null


func before_all() -> void:
	economy = DataCatalog.load_economy()


func _flags(values: Dictionary, story: bool) -> Dictionary[StringName, Variant]:
	var result: Dictionary[StringName, Variant] = {}
	for key: Variant in values:
		result[StringName(str(key))] = values[key]
	if story:
		result[EndingService.FLAG_STORY_MODE] = true
	return result


func test_hard_values_unchanged_and_story_values_higher() -> void:
	assert_eq(economy.review_arrest_score, 5, "Dur : Revue (D-080)")
	assert_eq(economy.deposition_arrest_score, 7, "Dur : Déposition (D-094)")
	assert_eq(economy.untreated_worsen_evenings, 2, "Dur : aggravation")
	assert_eq(economy.story_review_arrest_score, 7)
	assert_eq(economy.story_deposition_arrest_score, 10)
	assert_eq(economy.story_untreated_worsen_evenings, 3)
	assert_eq(economy.review_arrest_for(false), economy.review_arrest_score)
	assert_eq(economy.deposition_arrest_for(false), economy.deposition_arrest_score)
	assert_eq(economy.untreated_worsen_for(false), economy.untreated_worsen_evenings)
	assert_gt(economy.story_review_arrest_score, economy.review_demote_score, "la rétrogradation reste possible")
	assert_gt(economy.story_deposition_arrest_score, economy.deposition_blame_score, "le blâme reste possible")


func test_evening_context_carries_story_flag_only_in_story() -> void:
	var hard: Dictionary[StringName, Variant] = EveningService.evening_context({}, Household.new(), 0.9, 0, 5, economy, 20)
	var story: Dictionary[StringName, Variant] = EveningService.evening_context({}, Household.new(), 0.9, 0, 5, economy, 20,
			true)
	assert_false(hard.has(EndingService.FLAG_STORY_MODE))
	assert_false(EndingService.is_story(hard))
	assert_true(EndingService.is_story(story))


func test_review_threshold_story_only() -> void:
	var score: int = economy.review_arrest_score
	assert_eq(EndingService.review_outcome(_flags({"suspicion": score}, false), economy)["ending"],
			EndingService.F1_ARRESTED, "Dur : arrêté·e au seuil 5")
	var spared: Dictionary = EndingService.review_outcome(_flags({"suspicion": score}, true), economy)
	assert_eq(spared["ending"], &"", "Récit : pas d'arrestation au seuil du Dur")
	assert_eq(spared["result"], EndingService.AUDIT_RETENTION, "Récit : rétrogradation à la place")
	assert_eq(EndingService.review_outcome(_flags({"suspicion": economy.story_review_arrest_score}, true), economy)["ending"],
			EndingService.F1_ARRESTED, "Récit : F1 reste atteignable")


func test_deposition_threshold_story_only() -> void:
	var score: int = economy.deposition_arrest_score
	assert_eq(EndingService.deposition_outcome(_flags({"suspicion": score}, false), economy)["ending"],
			EndingService.F1_ARRESTED, "Dur : arrêté·e au seuil 7")
	var spared: Dictionary = EndingService.deposition_outcome(_flags({"suspicion": score}, true), economy)
	assert_eq(spared["ending"], &"", "Récit : pas d'arrestation au seuil du Dur")
	assert_eq(spared["result"], EndingService.AUDIT_RETENTION, "Récit : blâme à la place")
	assert_eq(EndingService.deposition_outcome(_flags({"suspicion": economy.story_deposition_arrest_score}, true),
			economy)["ending"], EndingService.F1_ARRESTED, "Récit : F1 reste atteignable")


## Un proche malade sans soins depuis `untreated_worsen_evenings - 1` soirs :
## s'aggrave ce soir en Dur, pas encore en Récit.
func test_household_worsens_more_slowly_in_story() -> void:
	for story: bool in [false, true]:
		var home: Household = Household.new()
		var noa: Household.Member = home.get_member(Household.NOA)
		noa.health = Household.Health.SICK
		noa.untreated_evenings = economy.untreated_worsen_evenings - 1
		var lines: Array[ExpenseLine] = EveningService.build_lines(economy, 3, home)
		for line: ExpenseLine in lines:
			line.paid = line.id != StringName(EveningService.MEDS_PREFIX + String(Household.NOA))
		var report: EveningReport = EveningService.apply(economy, 3, home, lines, 500, 1, [], {}, _flags({}, story))
		var after: Household.Member = report.household.get_member(Household.NOA)
		if story:
			assert_eq(after.health, Household.Health.SICK, "Récit : pas encore aggravé·e")
		else:
			assert_eq(after.health, Household.Health.GRAVELY_SICK, "Dur : aggravé·e")


## Campagne simulée : à graine et précision égales, le Dur ne lit jamais les
## valeurs du Récit (mêmes fins avec des seuils Récit extrêmes).
func test_hard_simulation_ignores_story_values() -> void:
	var data: DataCatalog = DataCatalog.load_from()
	var tuned: EconomyDef = data.get_economy()
	var saved: Array[int] = [tuned.story_review_arrest_score, tuned.story_deposition_arrest_score,
		tuned.story_untreated_worsen_evenings]
	var before: Array[Dictionary] = BalanceSimulator.run_campaign(data, 7, 0.65, BalanceSimulator.Spending.REASONED, 20)
	tuned.story_review_arrest_score = 1
	tuned.story_deposition_arrest_score = 1
	tuned.story_untreated_worsen_evenings = 1
	var after: Array[Dictionary] = BalanceSimulator.run_campaign(data, 7, 0.65, BalanceSimulator.Spending.REASONED, 20)
	tuned.story_review_arrest_score = saved[0]
	tuned.story_deposition_arrest_score = saved[1]
	tuned.story_untreated_worsen_evenings = saved[2]
	assert_eq(after.size(), before.size(), "même nombre de jours")
	assert_eq(str(after[after.size() - 1].get("ending", "")), str(before[before.size() - 1].get("ending", "")))
	assert_eq(after[after.size() - 1].get("balance_after"), before[before.size() - 1].get("balance_after"))
