## Simulation d'équilibrage de la campagne (GDD §5.3, §5.4, §14) — sans scène.
##
## Enchaîne shift → soirée sur les jours des données pour un profil de joueur
## (précision de verdict) et une politique de dépenses, avec les vrais
## `DaySimulator`, `ScoringService` et `EveningService`. Mêmes graines que la
## campagne réelle (`SeededRng.day_seed`, sel « evening » de `Campaign`).
## Utilisé par `tools/balance_sim.gd` et par le test de non-régression
## d'équilibrage (`tests/integration/test_balance.gd`).
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


## Joue une campagne. Renvoie une ligne par soirée jouée :
## `{day, accuracy, income, balance_after, unpaid: Dictionary[StringName, int],
##   sick, grave, lost, hungry, cold, all_sick, ending}`.
## S'arrête à la première fin anticipée ou après `last_day` (dernier jour des données si < 1).
static func run_campaign(data: DataCatalog, campaign_seed: int, accuracy: float,
		spending: Spending = Spending.REASONED, last_day: int = -1) -> Array[Dictionary]:
	var economy: EconomyDef = data.get_economy()
	var final_day: int = last_day if last_day >= 1 else data.get_last_day_number()
	var household: Household = Household.new()
	var credits: int = economy.starting_credits
	var rows: Array[Dictionary] = []
	for day_number: int in range(1, final_day + 1):
		var day_seed: int = SeededRng.day_seed(campaign_seed, day_number)
		var rng: SeededRng = SeededRng.new(SeededRng.mix_string(day_seed, PLAYER_SALT))
		var policy: Callable = func(_case: Case, key: CaseKey, _index: int) -> VerdictKind.Kind:
			if rng.chance(accuracy):
				return key.expected_verdict
			return VerdictKind.Kind.DENY if key.expected_verdict == VerdictKind.Kind.APPROVE else VerdictKind.Kind.APPROVE
		var summary: DaySummary = DaySimulator.simulate(data, day_number, day_seed, policy)
		credits += summary.get_net()
		var lines: Array[ExpenseLine] = EveningService.build_lines(economy, day_number, household)
		if spending == Spending.DEFAULT:
			EveningService.default_selection(lines, credits)
		else:
			reasoned_selection(economy, lines, credits, household)
		var evening_seed: int = SeededRng.mix_string(day_seed, Campaign.EVENING_SALT)
		var report: EveningReport = EveningService.apply(economy, day_number, household, lines, credits, evening_seed)
		credits = report.balance_after
		household = report.household
		rows.append(_row(day_number, summary, report))
		if report.is_game_over():
			break
	return rows


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
