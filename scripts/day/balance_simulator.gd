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
const TRACKED_LINES: Array[StringName] = [&"rent", &"food", &"heating", &"oxygen", &"meds"]
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
	var economy: EconomyDef = data.get_economy()
	var final_day: int = last_day if last_day >= 1 else data.get_last_day_number()
	if profile == null:
		profile = SimProfile.preset(&"default", accuracy)
	var household: Household = Household.new()
	var credits: int = economy.starting_credits
	var flags: Dictionary[StringName, Variant] = {}
	var memory: Dictionary = {}
	var processed: int = 0
	var correct: int = 0
	var rows: Array[Dictionary] = []
	for day_number: int in range(1, final_day + 1):
		var day: DayDef = data.get_day(day_number)
		var day_seed: int = SeededRng.day_seed(campaign_seed, day_number)
		var rng: SeededRng = SeededRng.new(SeededRng.mix_string(day_seed, PLAYER_SALT))
		var summary: DaySummary = DaySimulator.play_day(data, day_number, day_seed, profile, flags, memory, rng)
		credits += summary.get_total_income()
		processed += summary.get_processed_count()
		correct += summary.get_correct_count()
		if not day.has_evening:
			var compliance: float = float(correct) / float(processed) if processed > 0 else 0.0
			var final_row: Dictionary = _final_row(day_number, summary, credits, household)
			final_row["ending"] = EndingService.evaluate_final(flags, household, credits, compliance, economy)
			final_row["flags"] = flags.duplicate()
			rows.append(final_row)
			break
		if day_number == 3 and FlagCondition.is_flag_true(flags, &"lucioles_contact"):
			_decide_note(flags, profile, economy)
			if profile.report_note:
				credits += economy.report_bonus
		var events: Array[EveningEvent] = EveningService.build_events(day.evening_events, flags, economy)
		var lines: Array[ExpenseLine] = EveningService.build_lines(economy, day_number, household)
		EveningService.apply_line_costs(lines, events, profile.choices)
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
			var wanted: StringName = profile.choices.get(event.id, &"")
			var option: EveningOptionDef = event.get_option(wanted)
			if option != null and EveningService.can_choose(option, credits - EveningService.total_spent(lines)):
				choices[event.id] = wanted
		var evening_seed: int = SeededRng.mix_string(day_seed, EVENING_SALT)
		var report: EveningReport = EveningService.apply(economy, day_number, household, lines, credits, evening_seed,
				events, choices, flags)
		credits = report.balance_after
		household = report.household
		CaseConsequences.merge_into(flags, report.flag_changes)
		var row: Dictionary = _row(day_number, summary, report)
		row["bribes"] = summary.get_bribe_total()
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
	for id: StringName in [&"rent", &"food", &"oxygen"]:
		var line: ExpenseLine = _find(lines, id)
		if line != null:
			order.append(line)
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
