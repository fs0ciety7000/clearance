## Simulation d'équilibrage de la campagne (GDD §5.3, §5.4, §14) — sans scène.
##
## Enchaîne shift → soirée sur les jours des données pour un profil de joueur
## (précision de verdict) et une politique de dépenses, avec les vrais
## `DaySimulator`, `ScoringService` et `EveningService`. Mêmes graines que la
## campagne réelle (`SeededRng.day_seed`, sel « evening » de `Campaign`).
## Utilisé par `tools/balance_sim.gd` et par le test de non-régression
## d'équilibrage (`tests/integration/test_balance.gd`).
## M7 : campagne J1–J10 complète (`DaySimulator.play_day` : drapeaux, objets
## glissés, mémoire des passagers ; soirées avec événements et choix du
## `SimProfile`, audit du J9 ; dernier jour sans soirée → fin F1–F7 par
## `EndingService.evaluate_final`). Les tirages des jours 1–3 sont inchangés
## (mêmes graines, même ordre) : les mesures D-047 restent valables.
## Acte II (docs/ACT2.md §6.4) : campagne J1–J20 — soirée pivot du J10
## (« Embarquer » possible), rations, prélèvements, quota (`SimProfile.overrun`),
## couvre-feu, Revue du J17, fin du J20 par `EndingService.evaluate_final_act2`.
## Acte III (docs/ACT3.md §6.5) : campagne J1–J30 — soirée pivot du J20
## (carte de fin d'acte, climat, « Embarquer » possible), aides
## conditionnelles, Main courante, Déposition du J29, fin du J30
## (`evaluate_final_act3`) ; `run_campaign_from` démarre au J21 depuis un état
## synthétique (climat, solde, profil — `balance_sim --climate=`).
class_name BalanceSimulator
extends RefCounted

## Politique de dépenses du soir.
enum Spending {
	## Joueur raisonnable : loyer > (taxe d'air) > nourriture > oxygène > soins
	## urgents (un proche s'aggraverait ce soir) > chauffage > autres soins.
	REASONED,
	## Présélection de l'écran Foyer acceptée telle quelle (`default_selection`).
	DEFAULT,
}

## Postes suivis dans les rapports (les médicaments sont regroupés sous `meds`).
const TRACKED_LINES: Array[StringName] = [&"rent", &"food", &"heating", &"oxygen", &"meds", &"rations"]
const PLAYER_SALT: String = "balance_player"
## Mêmes valeurs que `Campaign` (qui dépend du `GameState` : non chargé ici).
const EVENING_SALT: String = "evening"
const REPORT_TRUST_DELTA: int = -2


## Joue une campagne. Renvoie une ligne par jour joué :
## `{day, accuracy, income, balance_after, unpaid: Dictionary[StringName, int],
##   sick, grave, lost, hungry, cold, all_sick, ending}` (+ M7 : `bribes`,
## `final` (dernier jour sans soirée), `flags` (copie, dernière ligne)).
## S'arrête à la première fin ou après `last_day` (dernier jour des données si < 1).
## `profile` nul : profil `default` de précision `accuracy`.
static func run_campaign(data: DataCatalog, campaign_seed: int, accuracy: float,
		spending: Spending = Spending.REASONED, last_day: int = -1, profile: SimProfile = null) -> Array[Dictionary]:
	var start: Dictionary = {"day": 1, "credits": data.get_economy().starting_credits, "flags": {},
			"household": Household.new()}
	return run_campaign_from(data, campaign_seed, accuracy, spending, last_day, profile, start)


## Acte III : campagne à partir d'un état `{day, credits, flags, household,
## processed, correct}` (J21 synthétique d'un climat, `balance_sim --climate=`).
static func run_campaign_from(data: DataCatalog, campaign_seed: int, accuracy: float, spending: Spending,
		last_day: int, profile: SimProfile, start: Dictionary) -> Array[Dictionary]:
	var economy: EconomyDef = data.get_economy()
	var final_day: int = last_day if last_day >= 1 else data.get_last_day_number()
	if profile == null:
		profile = SimProfile.preset(&"default", accuracy)
	var household: Household = start.get("household", Household.new())
	var credits: int = SaveService.as_int(start.get("credits", economy.starting_credits))
	var flags: Dictionary[StringName, Variant] = {}
	var start_flags: Dictionary = start.get("flags", {})
	for key: Variant in start_flags:
		flags[StringName(str(key))] = start_flags[key]
	var memory: Dictionary = {}
	var processed: int = SaveService.as_int(start.get("processed", 0))
	var correct: int = SaveService.as_int(start.get("correct", 0))
	var rows: Array[Dictionary] = []
	for day_number: int in range(SaveService.as_int(start.get("day", 1)), final_day + 1):
		var day: DayDef = data.get_day(day_number)
		var day_seed: int = SeededRng.day_seed(campaign_seed, day_number)
		var rng: SeededRng = SeededRng.new(SeededRng.mix_string(day_seed, PLAYER_SALT))
		var summary: DaySummary = DaySimulator.play_day(data, day_number, day_seed, profile, flags, memory, rng)
		credits += summary.get_total_income()
		processed += summary.get_processed_count()
		correct += summary.get_correct_count()
		var compliance: float = float(correct) / float(processed) if processed > 0 else 0.0
		if not day.has_evening:
			var final_row: Dictionary = _final_row(day_number, summary, credits, household)
			if FlagCondition.is_flag_true(flags, EndingService.FLAG_ACT3):
				EndingService.apply_final_household(flags, household)
				final_row["ending"] = EndingService.evaluate_final_act3(flags, household, credits, compliance, economy)
			elif FlagCondition.is_flag_true(flags, EndingService.FLAG_ACT2):
				final_row["ending"] = EndingService.evaluate_final_act2(flags, household, credits, compliance, economy)
			else:
				final_row["ending"] = EndingService.evaluate_final(flags, household, credits, compliance, economy)
			final_row["flags"] = flags.duplicate()
			final_row["present"] = household.present_count()
			final_row["alive"] = household.alive_count()
			rows.append(final_row)
			break
		if day_number == 3 and FlagCondition.is_flag_true(flags, &"lucioles_contact"):
			_decide_note(flags, profile, economy)
			if profile.report_note:
				credits += economy.report_bonus
		var context: Dictionary[StringName, Variant] = EveningService.evening_context(flags, household, compliance,
				economy.levy_for(day_number, credits), day_number, economy, credits, profile.story_mode)
		var events: Array[EveningEvent] = EveningService.build_events(day.evening_events, context, economy)
		var lines: Array[ExpenseLine] = EveningService.build_lines(economy, day_number, household, flags, credits)
		var wanted_choices: Dictionary[StringName, StringName] = profile.choices_for(events)
		EveningService.apply_line_costs(lines, events, wanted_choices)
		if profile.spending == &"rent_only" or profile.spending == &"none":
			for line: ExpenseLine in lines:
				line.paid = line.mandatory or (profile.spending == &"rent_only" and line.id == EveningService.LINE_RENT)
		elif spending == Spending.DEFAULT:
			EveningService.default_selection(lines, credits)
		else:
			reasoned_selection(economy, lines, credits, household)
		var choices: Dictionary[StringName, StringName] = EveningService.default_choices(events,
				credits - EveningService.total_spent(lines))
		for event: EveningEvent in events:
			var wanted: StringName = wanted_choices.get(event.id, &"")
			var option: EveningOptionDef = event.get_option(wanted)
			if option != null and EveningService.can_choose(option, credits - EveningService.total_spent(lines)):
				choices[event.id] = option.id
		var evening_seed: int = SeededRng.mix_string(day_seed, EVENING_SALT)
		var report: EveningReport = EveningService.apply(economy, day_number, household, lines, credits, evening_seed,
				events, choices, context)
		credits = report.balance_after
		household = report.household
		CaseConsequences.merge_into(flags, report.flag_changes)
		if summary.get_overrun_count() > 0 or flags.has(&"overrun_yesterday"):
			flags[&"overrun_yesterday"] = summary.get_overrun_count() > 0
		if day_number == economy.pivot_day and not report.is_game_over():
			flags[EndingService.FLAG_ACT2] = true
		if day_number == economy.act3_pivot_day and not report.is_game_over() \
				and FlagCondition.is_flag_true(flags, EndingService.FLAG_ACT2):
			flags[EndingService.FLAG_ACT3] = true
		var row: Dictionary = _row(day_number, summary, report)
		row["bribes"] = summary.get_bribe_total()
		row["overruns"] = summary.get_overrun_count()
		row["choices"] = report.choices.duplicate()
		rows.append(row)
		if report.is_game_over():
			row["flags"] = flags.duplicate()
			break
	return rows


## Mot des Lucioles du J3 : signalé (loyauté +1, confiance −2) ou brûlé.
static func _decide_note(flags: Dictionary[StringName, Variant], profile: SimProfile, _economy: EconomyDef) -> void:
	if profile.report_note:
		flags[&"lucioles_reported"] = true
		flags[CaseConsequences.FLAG_LOYALTY] = FlagCondition.gauge_value(flags, CaseConsequences.FLAG_LOYALTY) + 1
		flags[CaseConsequences.FLAG_TRUST] = FlagCondition.gauge_value(flags, CaseConsequences.FLAG_TRUST) + REPORT_TRUST_DELTA
	else:
		flags[&"lucioles_note_burned"] = true


## Dernier jour (sans soirée) : bilan seul.
static func _final_row(day_number: int, summary: DaySummary, credits: int, household: Household) -> Dictionary:
	var report: EveningReport = EveningReport.new()
	report.balance_after = credits
	report.household = household
	var row: Dictionary = _row(day_number, summary, report)
	row["final"] = true
	row["bribes"] = summary.get_bribe_total()
	return row


## Politique « raisonnable » : modifie `paid` sur place (taxe d'air d'office).
static func reasoned_selection(economy: EconomyDef, lines: Array[ExpenseLine], balance: int,
		household: Household) -> void:
	var order: Array[ExpenseLine] = []
	for id: StringName in [&"rent", &"food"]:
		var line: ExpenseLine = _find(lines, id)
		if line != null:
			order.append(line)
	# Acte II : rations des proches (essoufflement → maladie) avant l'oxygène.
	for line: ExpenseLine in lines:
		if line.ration_of != &"":
			order.append(line)
	var oxygen: ExpenseLine = _find(lines, &"oxygen")
	if oxygen != null:
		order.append(oxygen)
	var meds: Array[ExpenseLine] = []
	for line: ExpenseLine in lines:
		line.paid = line.mandatory
		if line.member_id != &"":
			meds.append(line)
	# Soins urgents : le proche s'aggraverait (ou serait perdu) dès ce soir.
	# Les lignes de soins suivent l'ordre `sick_members()` (graves d'abord).
	var later: Array[ExpenseLine] = []
	for line: ExpenseLine in meds:
		var member: Household.Member = household.get_member(line.member_id)
		if member != null and member.untreated_evenings + 1 >= economy.untreated_worsen_evenings:
			order.append(line)
		else:
			later.append(line)
	var heating: ExpenseLine = _find(lines, &"heating")
	if heating != null:
		order.append(heating)
	order.append_array(later)
	for line: ExpenseLine in order:
		if EveningService.can_toggle_on(lines, balance, line):
			line.paid = true


## Le foyer est « entièrement malade » : aucun proche en vie et en bonne santé.
static func is_all_sick(household: Household) -> bool:
	for member: Household.Member in household.members:
		if member.health == Household.Health.WELL:
			return false
	return true


static func _row(day_number: int, summary: DaySummary, report: EveningReport) -> Dictionary:
	var unpaid: Dictionary[StringName, int] = {}
	for id: StringName in TRACKED_LINES:
		unpaid[id] = 0
	for line: ExpenseLine in report.lines:
		if line.paid:
			continue
		var group: StringName = &"meds" if line.member_id != &"" else line.id
		if line.ration_of != &"":
			group = &"rations"
		if unpaid.has(group):
			unpaid[group] += 1
	var home: Household = report.household
	var sick: int = 0
	var grave: int = 0
	var lost: int = 0
	var hungry: int = 0
	var cold: int = 0
	for member: Household.Member in home.members:
		match member.health:
			Household.Health.SICK:
				sick += 1
			Household.Health.GRAVELY_SICK:
				grave += 1
			Household.Health.LOST:
				lost += 1
		if member.hungry:
			hungry += 1
		if member.cold:
			cold += 1
	return {
		"day": day_number,
		"accuracy": summary.get_compliance(),
		"income": summary.get_net(),
		"balance_after": report.balance_after,
		"unpaid": unpaid,
		"sick": sick,
		"grave": grave,
		"lost": lost,
		"hungry": hungry,
		"cold": cold,
		"all_sick": is_all_sick(home),
		"ending": report.ending,
	}


static func _find(lines: Array[ExpenseLine], id: StringName) -> ExpenseLine:
	for line: ExpenseLine in lines:
		if line.id == id:
			return line
	return null
