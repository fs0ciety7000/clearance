## Soirée au Bloc Pétrel (GDD §5.3, §5.4) — pur, statique, déterministe.
##
## 1. `build_lines()` : postes du soir d'après l'`EconomyDef` (loyer, taxe
##    d'air prélevée d'office, nourriture, chauffage, oxygène de Dora les soirs
##    pairs, médicaments par proche malade).
## 2. `default_selection()` : présélection « raisonnable » dans l'ordre de
##    priorité tant que le solde le permet (le chauffage en dernier : le soir du
##    J1, la plupart des joueurs ne peuvent pas le payer, GDD §5.3).
## 3. `apply()` : débite, fait évoluer le foyer et évalue les fins anticipées
##    F2 (réaffectation) et F3 (famille perdue). L'aléa (Noa malade à 50 % au
##    premier soir sans chauffage) vient d'une graine fournie (`SeededRng`).
## Ordre des effets : soins (proches déjà malades) → nourriture → chauffage →
## oxygène → loyer → dette → fins. Un proche qui tombe malade ce soir n'est
## soigné qu'à partir du soir suivant.
## M7 — événements du soir (`EveningEventDef` du `DayDef`, NARRATIVE §5) :
## `build_events()` (conditions, textes, options, audit), `default_choices()`
## (choix sans UI : option de plus petit `default_rank` disponible et
## finançable — refus/neutre, sauf soins), `apply_line_costs()` (chauffage
## offert, sabotage, médicaments de la Soute) ; `apply()` débite les options,
## crédite les gains, applique les effets (drapeaux, foyer) et l'audit (F1
## possible, prioritaire sur F3 > F2). `lucioles_hostile` est dérivé à la
## clôture d'une soirée ≥ J7 si `lucioles_trust ≤ −2`.
## Acte II (docs/ACT2.md M2, §5.3, §6.1, B30, B32 ; D-076, D-079) : à partir du
## J11, la taxe d'air devient des **rations** (la vôtre prélevée, celles des
## proches présents cochables ; non payée → ESSOUFFLÉ·E, 2 soirs → MALADE ;
## forfait +1 ₵ sans compteur) ; hausses datées (nourriture, oxygène,
## médicaments), oxygène offert (`promotion_offered`), location ACV-2,
## prélèvements de Rééquilibrage (J11, J17 : 30 % au-delà de 40 ₵), salaire
## d'Ilan (`income_lines`) ; seuls les proches **présents** mangent, respirent et
## tombent malades. Événements : effets foyer des lettres, jauges fixées,
## option qui termine la campagne (« Embarquer », F6 au J10), Revue du J17
## (`audit_id = review`), textes à valeurs (`text_args`), drapeaux de contexte
## du foyer et de la conformité (`context_flags`) ; soirée pivot du J10 :
## suspicion divisée (`pivot_day`).
## Acte III (docs/ACT3.md §5.3, §6.1, B47, B48 ; D-086, D-089) : soirée pivot
## du J20 (suspicion divisée, climat d'entrée prévisualisé dans le contexte :
## `evening_context`), loyer et inclusions de l'Anneau D, rations à 1 ₵ au
## climat Vanne, Contribution « pour Tycho » (J25), avance de l'Arbitre retenue
## au J27 (défaut → loyer impayé), prime de chef·fe de guichet et salaire de
## briseur·se de grève, lettres à gain (aides conditionnelles), options à
## effets conditionnels et revérifiées à l'application, Déposition du J29
## (audit calculé après le choix du soir).
class_name EveningService
extends RefCounted

const LINE_RENT: StringName = &"rent"
const LINE_AIR_TAX: StringName = &"air_tax"
const LINE_FOOD: StringName = &"food"
const LINE_HEATING: StringName = &"heating"
const LINE_OXYGEN: StringName = &"oxygen"
## Acte II.
const LINE_RATION_SELF: StringName = &"ration_self"
const RATION_PREFIX: String = "ration_"
const LINE_LEASE: StringName = &"lease"
const LINE_LEVY: StringName = &"levy"
const LINE_ILAN_JOB: StringName = &"inc_ilan_job"
## Acte III.
const LINE_LOAN: StringName = &"loan_repay"
const LINE_HEAD_BONUS: StringName = &"inc_head_bonus"
const LINE_SCAB: StringName = &"inc_scab"
const FLAG_RING_D: StringName = &"moved_ring_d"
const FLAG_VANNE: StringName = &"climate_vanne"
const FLAG_PROMU: StringName = &"climate_promu"
const FLAG_LOAN: StringName = &"arbitre_loan"
const FLAG_LOAN_DEFAULTED: StringName = &"loan_defaulted"
const FLAG_SCAB: StringName = &"ilan_scab"
const FLAG_ACT3: StringName = &"act3_started"
## Pseudo-jauges de contexte (Acte III) : solde du soir, rappel des salaires.
const GAUGE_BALANCE: StringName = &"balance"
const GAUGE_RECALL: StringName = &"recall_amount"
const NOTE_INCLUDED: String = "ev_note_included"
const GROUP_RATIONS: StringName = &"rations"
const FLAG_METER_REFUSED: StringName = &"meter_refused"
const FLAG_PROMOTION_OFFERED: StringName = &"promotion_offered"
const FLAG_PROMOTION_REVOKED: StringName = &"promotion_revoked"
const FLAG_ILAN_JOB: StringName = &"ilan_meter_job"
const FLAG_SCANNER_CONSORTIUM: StringName = &"scanner_consortium"
## Dernier soir des dépenses récurrentes (J19 : le J20 n'a pas de soirée).
const RECURRING_LAST_DAY: int = 19
## Pseudo-jauge de contexte : indice de conformité cumulé × 100.
const GAUGE_COMPLIANCE: StringName = &"compliance_pct"
## Pseudo-jauge de contexte : prélèvement de Rééquilibrage du soir (₵).
const GAUGE_LEVY: StringName = &"levy_amount"
const MEDS_PREFIX: String = "meds_"
const MEDS_LABEL_KEY: String = "ev_line_meds"
const MEDS_NOTE_KEY: String = "ev_note_meds"

## Groupe de postes « médicaments » (`line_costs`).
const LINE_MEDS: StringName = &"meds"
const FLAG_HOSTILE: StringName = &"lucioles_hostile"
const HOSTILE_FROM_DAY: int = 7
const HOSTILE_TRUST: int = -2

## Ordre de présélection (après la taxe d'air, toujours payée ; Acte II :
## rations des proches après la nourriture).
const PRIORITY: Array[StringName] = [LINE_RENT, LINE_FOOD, GROUP_RATIONS, LINE_OXYGEN, &"meds", LINE_HEATING]


## Prime de signalement du mot des Lucioles (GDD §4.7, `EconomyDef.report_bonus`) :
## montant crédité **ce soir** si le joueur signale, 0 s'il brûle le mot
## (QA-008 : l'écran l'ajoute aux fonds de la soirée, `evening_funds`).
static func report_bonus(economy: EconomyDef, report_it: bool) -> int:
	return economy.report_bonus if report_it else 0


## Fonds disponibles pour les postes et les options du soir : solde au sortir
## du shift (`balance_before` de `apply`) + primes déjà créditées ce soir
## (`report_bonus`). C'est aussi le `balance_before` à passer à `apply`.
static func evening_funds(shift_balance: int, bonuses: int) -> int:
	return shift_balance + bonuses


## Postes de la soirée du jour `day_number`, dans l'ordre d'affichage.
## Acte II : `flags` (compteur refusé, promotion, ACV-2) et `balance` (solde
## du soir, assiette du prélèvement de Rééquilibrage).
static func build_lines(economy: EconomyDef, day_number: int, household: Household,
		flags: Dictionary[StringName, Variant] = {}, balance: int = 0) -> Array[ExpenseLine]:
	var lines: Array[ExpenseLine] = []
	var rations: bool = economy.rations_for(day_number)
	var surcharge: int = economy.meter_surcharge if rations and day_number > economy.ration_start_day \
			and day_number <= RECURRING_LAST_DAY and FlagCondition.is_flag_true(flags, FLAG_METER_REFUSED) else 0
	# Acte III : Anneau D (loyer 30 ₵, chauffage et rations inclus) ; climat
	# Vanne (rations à 1 ₵).
	var act3: bool = day_number >= economy.act3_first_day
	var ring_d: bool = act3 and FlagCondition.is_flag_true(flags, FLAG_RING_D)
	var vanne: bool = act3 and FlagCondition.is_flag_true(flags, FLAG_VANNE)
	lines.append(ExpenseLine.new(LINE_RENT, economy.ring_d_rent if ring_d else economy.rent_for(day_number)))
	if economy.air_tax_for(day_number) > 0:
		lines.append(ExpenseLine.new(LINE_AIR_TAX, economy.air_tax_for(day_number), true))
	if rations:
		var own_cost: int = economy.ration_self + surcharge
		if ring_d:
			own_cost = 0
		elif vanne:
			own_cost = economy.vanne_ration
		var own: ExpenseLine = ExpenseLine.new(LINE_RATION_SELF, own_cost, true)
		own.label_key = "exp_ration_self"
		own.note_key = "exp_meter_surcharge" if surcharge > 0 else (NOTE_INCLUDED if ring_d else "")
		lines.append(own)
	lines.append(ExpenseLine.new(LINE_FOOD, economy.food_for(day_number)))
	if ring_d:
		var included: ExpenseLine = ExpenseLine.new(LINE_HEATING, 0, true)
		included.note_key = NOTE_INCLUDED
		lines.append(included)
	else:
		lines.append(ExpenseLine.new(LINE_HEATING, economy.heating))
	if rations:
		for member: Household.Member in household.present_members():
			var cost: int = economy.ration_of(member.id) + surcharge
			if ring_d:
				cost = 0
			elif vanne:
				cost = economy.vanne_ration
			var ration: ExpenseLine = ExpenseLine.new(StringName(RATION_PREFIX + String(member.id)), cost, ring_d)
			ration.ration_of = member.id
			ration.label_key = "exp_ration_%s" % member.id
			ration.note_key = "exp_meter_surcharge" if surcharge > 0 else (NOTE_INCLUDED if ring_d else "ev_note_ration")
			lines.append(ration)
	var dora: Household.Member = household.get_member(Household.DORA)
	if economy.oxygen_due(day_number) and dora != null and dora.is_present():
		if FlagCondition.is_flag_true(flags, FLAG_PROMOTION_OFFERED) and not FlagCondition.is_flag_true(flags, FLAG_PROMOTION_REVOKED):
			var free: ExpenseLine = ExpenseLine.new(LINE_OXYGEN, 0, true)
			free.note_key = "ev_note_oxygen_free"
			lines.append(free)
		else:
			lines.append(ExpenseLine.new(LINE_OXYGEN, economy.oxygen_for(day_number)))
	for member: Household.Member in household.sick_members():
		var meds: ExpenseLine = ExpenseLine.new(StringName(MEDS_PREFIX + String(member.id)), economy.medicine_for(day_number))
		meds.member_id = member.id
		meds.label_key = MEDS_LABEL_KEY
		meds.note_key = MEDS_NOTE_KEY + ("_grave" if member.health == Household.Health.GRAVELY_SICK else "")
		lines.append(meds)
	if FlagCondition.is_flag_true(flags, FLAG_SCANNER_CONSORTIUM) and day_number <= RECURRING_LAST_DAY:
		var lease: ExpenseLine = ExpenseLine.new(LINE_LEASE, economy.lease_cost, true)
		lease.label_key = "exp_lease"
		lines.append(lease)
	var levy: int = economy.levy_for(day_number, balance)
	if levy > 0:
		var levy_line: ExpenseLine = ExpenseLine.new(LINE_LEVY, levy, true)
		levy_line.label_key = "exp_levy"
		if economy.is_contribution_day(day_number):
			# Acte III : Contribution « pour Tycho » (20 % au-delà de 60 ₵).
			levy_line.label_key = "exp_contribution"
			levy_line.note_key = "ev_note_contribution"
		lines.append(levy_line)
	# Acte III : avance de l'Arbitre retenue (défaut si le solde ne la couvre pas).
	if day_number == economy.loan_day and FlagCondition.is_flag_true(flags, FLAG_LOAN):
		var loan: ExpenseLine = ExpenseLine.new(LINE_LOAN, economy.loan_repay, true)
		loan.label_key = "exp_loan_repay"
		loan.note_key = "ev_note_loan"
		lines.append(loan)
	return lines


## Acte II : revenus récurrents du soir (montants positifs, crédités par
## `apply` avec les gains) — salaire d'Ilan, technicien·ne de rationnement.
static func income_lines(economy: EconomyDef, day_number: int, household: Household,
		flags: Dictionary[StringName, Variant] = {}) -> Array[ExpenseLine]:
	var lines: Array[ExpenseLine] = []
	var ilan: Household.Member = household.get_member(Household.ILAN)
	if FlagCondition.is_flag_true(flags, FLAG_ILAN_JOB) and ilan != null and ilan.is_present() \
			and day_number >= economy.ilan_job_first_day and day_number <= RECURRING_LAST_DAY:
		var job: ExpenseLine = ExpenseLine.new(LINE_ILAN_JOB, economy.ilan_job_income, true)
		job.label_key = "inc_ilan_job"
		lines.append(job)
	# Acte III : prime de chef·fe de guichet (climat Promu·e), briseur·se de grève.
	if FlagCondition.is_flag_true(flags, FLAG_PROMU) and day_number >= economy.act3_first_day \
			and day_number <= economy.act3_last_evening:
		var bonus: ExpenseLine = ExpenseLine.new(LINE_HEAD_BONUS, economy.head_bonus, true)
		bonus.label_key = "inc_head_bonus"
		lines.append(bonus)
	if FlagCondition.is_flag_true(flags, FLAG_SCAB) and ilan != null and ilan.is_present() \
			and day_number >= economy.scab_first_day and day_number <= economy.scab_last_day:
		var scab: ExpenseLine = ExpenseLine.new(LINE_SCAB, economy.scab_income, true)
		scab.label_key = "inc_scab"
		lines.append(scab)
	return lines


## Acte II : drapeaux narratifs complétés de pseudo-drapeaux de contexte (jamais
## sauvegardés) pour les conditions des soirées et des briefings :
## `hh_<proche>_present|alive|held|away|sick` (foyer), jauges `hh_alive`,
## `hh_present`, `compliance_pct` (indice cumulé × 100), drapeau `hh_any_sick`,
## `levy_amount` (prélèvement du soir, texte de la lettre du J11).
static func context_flags(flags: Dictionary[StringName, Variant], household: Household,
		compliance: float = -1.0, levy: int = -1) -> Dictionary[StringName, Variant]:
	var result: Dictionary[StringName, Variant] = flags.duplicate()
	if household != null:
		var any_sick: bool = false
		for member: Household.Member in household.members:
			var stem: String = "hh_%s_" % member.id
			result[StringName(stem + "present")] = member.is_present()
			result[StringName(stem + "alive")] = member.is_alive()
			result[StringName(stem + "held")] = member.detained and member.is_alive()
			result[StringName(stem + "away")] = member.away != &""
			result[StringName(stem + "sick")] = member.is_sick() and member.is_present()
			any_sick = any_sick or (member.is_sick() and member.is_present())
		result[&"hh_any_sick"] = any_sick
		result[&"hh_alive"] = household.alive_count()
		result[&"hh_present"] = household.present_count()
	if compliance >= 0.0:
		result[GAUGE_COMPLIANCE] = roundi(compliance * 100.0)
	if levy >= 0:
		result[GAUGE_LEVY] = levy
	return result


## Acte III : contexte d'une soirée complet — `context_flags`, solde du soir
## (`balance`, conditions « solde < N » des aides), rappel des salaires
## imputés (`recall_amount`), et le soir du pivot du J20 le **climat d'entrée**
## prévisualisé (`climate_*`, `vanne2_brulants` : même évaluation que les fins
## du J20, D-086) pour les lettres de la soirée pivot.
## M11 (D-113) : `story` pose le pseudo-drapeau `EndingService.FLAG_STORY_MODE`
## (mode Récit : seuils de la Revue / Déposition et aggravation du foyer
## propres au Récit) ; absent en Dur.
static func evening_context(flags: Dictionary[StringName, Variant], household: Household, compliance: float,
		levy: int, day_number: int, economy: EconomyDef, balance: int, story: bool = false) -> Dictionary[StringName, Variant]:
	var result: Dictionary[StringName, Variant] = context_flags(flags, household, compliance, levy)
	result[GAUGE_BALANCE] = balance
	if story:
		result[EndingService.FLAG_STORY_MODE] = true
	if economy != null:
		result[GAUGE_RECALL] = economy.recall_for(FlagCondition.gauge_value(flags, CaseConsequences.FLAG_QUOTA_OVERRUN))
		if day_number == economy.act3_pivot_day and not FlagCondition.is_flag_true(flags, FLAG_ACT3):
			var climate: StringName = EndingService.act2_climate(result, economy)
			result[EndingService.CLIMATE_FLAGS[climate]] = true
			if climate == EndingService.F5_AIR and EndingService.is_burners_variant2(result):
				result[EndingService.FLAG_BRULANTS2] = true
	return result


## Présélection : la taxe d'air, puis les postes par priorité tant que le
## solde reste ≥ 0. Modifie `paid` sur place.
static func default_selection(lines: Array[ExpenseLine], balance: int) -> void:
	for line: ExpenseLine in lines:
		line.paid = line.mandatory
	for group: StringName in PRIORITY:
		for line: ExpenseLine in lines:
			if line.mandatory or line.paid or _group_of(line) != group:
				continue
			if can_toggle_on(lines, balance, line):
				line.paid = true


static func total_spent(lines: Array[ExpenseLine]) -> int:
	var total: int = 0
	for line: ExpenseLine in lines:
		if line.paid:
			total += line.cost
	return total


## Un poste facultatif ne peut être coché que si le solde reste ≥ 0
## (la taxe d'air, elle, peut creuser la dette). M13 : un achat de l'Économat
## au plus par soir (`max_upgrades`), jamais à découvert.
static func can_toggle_on(lines: Array[ExpenseLine], balance: int, line: ExpenseLine, max_upgrades: int = 1) -> bool:
	if line.mandatory or line.paid:
		return true
	if line.upgrade_id != &"" and upgrades_selected(lines) >= max_upgrades:
		return false
	return balance - total_spent(lines) - line.cost >= 0


# ---------------------------------------------------------------------------
# M13 : Économat du Hall (docs/M13.md §3 ; B74, D-150)
# ---------------------------------------------------------------------------

## Préfixe des postes d'achat (`upgrade_ag01`).
const UPGRADE_PREFIX: String = "upgrade_"


## Offres du soir du jour `day_number` (catalogue puis hors catalogue, ordre
## des données) : postes **non cochés**, libellé `exp_upgrade_<id>`, note =
## description de l'effet. Vide avant `shop_open_evening` (J5).
static func shop_lines(economy: EconomyDef, day_number: int, flags: Dictionary[StringName, Variant]) -> Array[ExpenseLine]:
	var lines: Array[ExpenseLine] = []
	if economy == null or day_number < economy.shop_open_evening:
		return lines
	for off_catalog: bool in [false, true]:
		for upgrade: UpgradeDef in economy.upgrades:
			if upgrade == null or upgrade.off_catalog != off_catalog or not upgrade.is_offered(day_number, flags):
				continue
			var line: ExpenseLine = ExpenseLine.new(StringName(UPGRADE_PREFIX + String(upgrade.id)), upgrade.price)
			line.upgrade_id = upgrade.id
			line.label_key = upgrade.expense_key if not upgrade.expense_key.is_empty() else upgrade.name_key
			line.note_key = upgrade.desc_key
			lines.append(line)
	return lines


## Offres achetables ce soir avec le solde restant (`balance` = fonds du soir) :
## offertes, un achat au plus, sans découvert.
static func affordable_upgrades(lines: Array[ExpenseLine], balance: int, max_upgrades: int = 1) -> Array[ExpenseLine]:
	var result: Array[ExpenseLine] = []
	for line: ExpenseLine in lines:
		if line.upgrade_id != &"" and not line.paid and can_toggle_on(lines, balance, line, max_upgrades):
			result.append(line)
	return result


## Nombre d'achats cochés.
static func upgrades_selected(lines: Array[ExpenseLine]) -> int:
	var count: int = 0
	for line: ExpenseLine in lines:
		if line.upgrade_id != &"" and line.paid:
			count += 1
	return count


## Achats cochés : drapeau de possession `upg_<id>` et drapeaux d'achat
## (`purchase_flags`, AG-06 : `loyalty +1`), dans `report`.
static func _apply_purchases(report: EveningReport, economy: EconomyDef, lines: Array[ExpenseLine],
		flags: Dictionary[StringName, Variant]) -> void:
	for line: ExpenseLine in lines:
		if line.upgrade_id == &"" or not line.paid:
			continue
		var upgrade: UpgradeDef = economy.get_upgrade(line.upgrade_id) if economy != null else null
		if upgrade == null:
			continue
		report.flag_changes[upgrade.owned_flag()] = true
		CaseConsequences.add_all(report.flag_changes, flags, upgrade.purchase_flags)
		report.upgrades_bought.append(upgrade.id)


## Applique la soirée : débit, évolution du foyer, fins anticipées.
## `household` n'est pas modifié : le rapport porte une copie à jour.
static func apply(economy: EconomyDef, day_number: int, household: Household,
		lines: Array[ExpenseLine], balance_before: int, rng_seed: int, events: Array[EveningEvent] = [],
		choices: Dictionary[StringName, StringName] = {}, flags: Dictionary[StringName, Variant] = {}) -> EveningReport:
	var report: EveningReport = EveningReport.new()
	var home: Household = household.duplicate_household()
	var rng: SeededRng = SeededRng.new(rng_seed)
	report.day_number = day_number
	report.lines = lines
	report.balance_before = balance_before
	report.household = home
	apply_line_costs(lines, events, choices)
	if day_number == economy.pivot_day and economy.pivot_suspicion_divisor > 0:
		_apply_pivot(report, economy, flags)
	elif day_number == economy.act3_pivot_day and economy.pivot_suspicion_divisor > 0:
		_apply_pivot3(report, economy, flags)
	# Acte III : avance de l'Arbitre non couverte par le solde → non retenue,
	# comptée comme un loyer impayé (F2, D-047).
	var loan_defaulted: bool = false
	for line: ExpenseLine in lines:
		if line.id == LINE_LOAN and balance_before < line.cost:
			line.paid = false
			loan_defaulted = true
			report.flag_changes[FLAG_LOAN_DEFAULTED] = true
	var household_effects: Array[StringName] = _apply_events(report, events, choices, flags, economy)
	_apply_purchases(report, economy, lines, flags)
	for income: ExpenseLine in income_lines(economy, day_number, household, flags):
		report.gained += income.cost
		report.income_lines.append(income)
	report.spent = total_spent(lines) + report.event_spent
	report.balance_after = balance_before - report.spent + report.gained

	# 1. Soins des proches déjà malades (Récit : aggravation plus lente, D-113).
	var worsen_evenings: int = economy.untreated_worsen_for(EndingService.is_story(flags))
	for member: Household.Member in home.sick_members():
		if _is_paid(lines, StringName(MEDS_PREFIX + String(member.id))):
			member.untreated_evenings = 0
			if member.health == Household.Health.GRAVELY_SICK:
				member.health = Household.Health.SICK
				report.add_event("hh_ev_better", EveningReport.Tone.GOOD, member.id)
			else:
				member.health = Household.Health.WELL
				report.add_event("hh_ev_cured", EveningReport.Tone.GOOD, member.id)
			continue
		member.untreated_evenings += 1
		if member.untreated_evenings < worsen_evenings:
			report.add_event("hh_ev_untreated", EveningReport.Tone.WARNING, member.id)
			continue
		member.untreated_evenings = 0
		if member.health == Household.Health.SICK:
			member.health = Household.Health.GRAVELY_SICK
			report.add_event("hh_ev_worse", EveningReport.Tone.BAD, member.id)
		else:
			member.health = Household.Health.LOST
			member.hungry = false
			member.cold = false
			report.add_event("hh_ev_lost", EveningReport.Tone.BAD, member.id)

	# 2. Nourriture.
	if _is_paid(lines, LINE_FOOD):
		home.hunger_streak = 0
		for member: Household.Member in home.members:
			member.hungry = false
	else:
		home.hunger_streak += 1
		report.add_event("hh_ev_hungry", EveningReport.Tone.WARNING)
		for member: Household.Member in home.present_members():
			member.hungry = true
			if home.hunger_streak >= economy.deprivation_sick_evenings:
				_fall_sick(member, report, "hh_ev_sick_hunger")

	# 3. Chauffage.
	if _is_paid(lines, LINE_HEATING):
		home.cold_streak = 0
		for member: Household.Member in home.members:
			member.cold = false
	else:
		home.cold_streak += 1
		report.add_event("hh_ev_cold", EveningReport.Tone.WARNING)
		for member: Household.Member in home.present_members():
			member.cold = true
			if home.cold_streak >= economy.deprivation_sick_evenings:
				_fall_sick(member, report, "hh_ev_sick_cold")
		var noa: Household.Member = home.get_member(Household.NOA)
		var roll: float = rng.randf()
		if home.cold_streak == 1 and noa != null and noa.is_present() and roll < economy.noa_cold_sick_chance:
			_fall_sick(noa, report, "hh_ev_noa_cough")

	# 3 bis. Acte II : rations d'air (ESSOUFFLÉ·E, 2 soirs → MALADE).
	for line: ExpenseLine in lines:
		if line.ration_of == &"":
			continue
		var breather: Household.Member = home.get_member(line.ration_of)
		if breather == null or not breather.is_present():
			continue
		if line.paid:
			breather.breathless = false
			breather.breathless_streak = 0
			continue
		breather.breathless = true
		breather.breathless_streak += 1
		report.add_event("hh_ev_breathless", EveningReport.Tone.WARNING, breather.id)
		if breather.breathless_streak >= economy.deprivation_sick_evenings:
			_fall_sick(breather, report, "hh_ev_sick_breath")

	# 4. Oxygène de Dora (soirs pairs).
	var dora: Household.Member = home.get_member(Household.DORA)
	if _has_line(lines, LINE_OXYGEN) and not _is_paid(lines, LINE_OXYGEN) and dora != null and dora.is_present():
		home.oxygen_misses += 1
		if home.oxygen_misses >= economy.oxygen_grave_misses:
			if dora.health != Household.Health.GRAVELY_SICK:
				dora.health = Household.Health.GRAVELY_SICK
				dora.untreated_evenings = 0
			report.add_event("hh_ev_oxygen_grave", EveningReport.Tone.BAD, dora.id)
		else:
			_fall_sick(dora, report, "hh_ev_oxygen")

	# 4 bis. Effets des événements sur le foyer (bio-scan sauté, Ilan dénoncé·e).
	for effect: StringName in household_effects:
		_apply_household_effect(report, effect)

	# 5. Loyer et dette.
	if _is_paid(lines, LINE_RENT):
		home.unpaid_rent_streak = 0
	else:
		home.unpaid_rent_streak += 1
		report.add_event("hh_ev_rent_unpaid", EveningReport.Tone.BAD if home.unpaid_rent_streak >= economy.eviction_unpaid_rent - 1 else EveningReport.Tone.WARNING)
	if loan_defaulted:
		home.unpaid_rent_streak += 1
		report.add_event("hh_ev_loan_defaulted", EveningReport.Tone.BAD)
	if report.balance_after < 0:
		home.debt_streak += 1
		report.add_event("hh_ev_debt", EveningReport.Tone.BAD)
	else:
		home.debt_streak = 0

	# 6. Fins anticipées (priorité GDD §11.2 : F1 (audit) > F3 > F2).
	var merged: Dictionary[StringName, Variant] = flags.duplicate()
	CaseConsequences.merge_into(merged, report.flag_changes)
	if day_number >= HOSTILE_FROM_DAY and FlagCondition.gauge_value(merged, CaseConsequences.FLAG_TRUST) <= HOSTILE_TRUST \
			and not FlagCondition.is_flag_true(merged, FLAG_HOSTILE):
		report.flag_changes[FLAG_HOSTILE] = true
	# Acte II : F1 (audit, Revue) > F3 > F2 > fin choisie (« Embarquer », F6).
	if report.ending == EndingService.F1_ARRESTED:
		pass
	elif home.all_lost():
		report.ending = EveningReport.ENDING_FAMILY_LOST
	elif home.unpaid_rent_streak >= economy.eviction_unpaid_rent or home.debt_streak >= economy.debt_evenings_limit:
		report.ending = EveningReport.ENDING_REASSIGNED
	if report.events.is_empty():
		report.add_event("hh_ev_calm", EveningReport.Tone.GOOD)
	return report


# ---------------------------------------------------------------------------
# M7 : événements du soir
# ---------------------------------------------------------------------------

## Événements du soir dont la condition est vraie, triés par `order`.
static func build_events(defs: Array[EveningEventDef], flags: Dictionary[StringName, Variant],
		economy: EconomyDef) -> Array[EveningEvent]:
	var events: Array[EveningEvent] = []
	var sorted: Array[EveningEventDef] = []
	for def: EveningEventDef in defs:
		if def != null and FlagCondition.check(def.condition, flags) and def.economy_gauges_met(flags, economy):
			sorted.append(def)
	sorted.sort_custom(func(a: EveningEventDef, b: EveningEventDef) -> bool: return a.order < b.order)
	for def: EveningEventDef in sorted:
		var event: EveningEvent = EveningEvent.new()
		event.def = def
		event.id = def.id
		event.kind = def.kind
		event.title_key = def.title_key
		event.text_key = ConditionalKey.first_match(def.text_variants, flags, def.text_key)
		event.extra_keys = ConditionalKey.all_matches(def.extra_keys, flags)
		for option: EveningOptionDef in def.options:
			if option != null and FlagCondition.check(option.condition, flags):
				event.options.append(option)
		if def.kind == EveningEventDef.Kind.AUDIT:
			if def.audit_id == EndingService.AUDIT_REVIEW:
				event.audit = EndingService.review_outcome(flags, economy)
			elif def.audit_id == EndingService.AUDIT_DEPOSITION:
				# Acte III : provisoire (choix par défaut) ; recalculée à l'application
				# avec le choix de la Déposition (`refresh_audit`).
				event.audit = EndingService.deposition_outcome(flags, economy)
			else:
				event.audit = EndingService.audit_outcome(flags, economy)
		for gauge: String in def.text_gauges:
			event.text_args.append(FlagCondition.gauge_value(flags, StringName(gauge)))
		events.append(event)
	return events


## Vrai si l'option est finançable avec `balance` (pas de dette pour une option
## `requires_funds`).
static func can_choose(option: EveningOptionDef, balance: int) -> bool:
	# Une option gratuite reste possible même à découvert (sinon, à solde
	# négatif, le choix par défaut retombait sur la première option sans coût).
	return option != null and (option.cost <= 0 or not option.requires_funds or option.cost <= balance)


## Choix par défaut (sans UI) : par événement à choix, l'option disponible de
## plus petit `default_rank` (≥ 0) finançable avec le solde restant.
static func default_choices(events: Array[EveningEvent], balance: int) -> Dictionary[StringName, StringName]:
	var choices: Dictionary[StringName, StringName] = {}
	var remaining: int = balance
	for event: EveningEvent in events:
		if not event.is_choice():
			continue
		var best: EveningOptionDef = null
		for option: EveningOptionDef in event.options:
			if option.default_rank < 0 or not can_choose(option, remaining):
				continue
			if best == null or option.default_rank < best.default_rank:
				best = option
		if best == null:
			for option: EveningOptionDef in event.options:
				if option.cost <= 0:
					best = option
					break
		if best != null:
			choices[event.id] = best.id
			event.default_option = best.id
			remaining -= best.cost - best.gain
	return choices


## Coûts imposés des postes : effets automatiques des événements, puis
## de l'option choisie (`line_costs` : id de poste ou `meds` pour tous les soins).
static func apply_line_costs(lines: Array[ExpenseLine], events: Array[EveningEvent],
		choices: Dictionary[StringName, StringName]) -> void:
	for event: EveningEvent in events:
		_set_costs(lines, event.def.line_costs)
		var chosen: StringName = choices.get(event.id, &"")
		var option: EveningOptionDef = event.get_option(chosen)
		if option != null:
			_set_costs(lines, option.line_costs)


static func _set_costs(lines: Array[ExpenseLine], costs: Dictionary[StringName, int]) -> void:
	for id: StringName in costs:
		for line: ExpenseLine in lines:
			if line.id == id or (id == LINE_MEDS and line.member_id != &""):
				line.cost = costs[id]


## Applique les événements au rapport ; renvoie les effets sur le foyer à
## appliquer après l'évolution normale de la nuit. Acte III : les drapeaux du
## soir déjà posés (`flags` + effets précédents) servent aux conditions
## d'application — option revérifiée (un choix rendu caduc par un autre est
## ignoré : places pour Tycho après celles de la Soute), effets conditionnels
## (`conditional_flags`), Déposition calculée après le choix du soir.
static func _apply_events(report: EveningReport, events: Array[EveningEvent], choices: Dictionary[StringName, StringName],
		flags: Dictionary[StringName, Variant], economy: EconomyDef = null) -> Array[StringName]:
	var effects: Array[StringName] = []
	var current: Dictionary[StringName, Variant] = flags.duplicate()
	for event: EveningEvent in events:
		if report.ending == EndingService.F1_ARRESTED:
			break
		CaseConsequences.merge_into(current, report.flag_changes)
		CaseConsequences.add_all(report.flag_changes, flags, event.def.flags)
		match event.kind:
			EveningEventDef.Kind.AUDIT:
				var outcome: Dictionary = event.audit
				if event.def.audit_id == EndingService.AUDIT_DEPOSITION and economy != null:
					CaseConsequences.merge_into(current, report.flag_changes)
					outcome = EndingService.deposition_outcome(current, economy)
					event.audit = outcome
				report.event_texts.append(str(outcome.get("result_key", "")))
				report.event_spent += SaveService.as_int(outcome.get("cost", 0))
				var audit_flags: Dictionary = outcome.get("flags", {})
				CaseConsequences.add_all(report.flag_changes, flags, audit_flags)
				var ending: StringName = outcome.get("ending", &"")
				if ending != &"":
					report.ending = ending
				report.add_event(str(outcome.get("result_key", "")),
						EveningReport.Tone.BAD if ending != &"" or SaveService.as_int(outcome.get("cost", 0)) > 0 else EveningReport.Tone.INFO)
			EveningEventDef.Kind.LETTER:
				report.event_texts.append(event.text_key)
				report.event_texts.append_array(event.extra_keys)
				report.add_event(event.text_key, EveningReport.Tone.INFO)
				for key: String in event.extra_keys:
					report.add_event(key, EveningReport.Tone.INFO)
				if event.def.household != &"":
					effects.append(event.def.household)
				# Acte III : lettre à gain (aides conditionnelles, rappel des salaires).
				report.gained += event.def.gain
				if event.def.gain_gauge != &"":
					report.gained += FlagCondition.gauge_value(current, event.def.gain_gauge)
			EveningEventDef.Kind.CHOICE:
				var chosen: StringName = choices.get(event.id, event.default_option)
				var option: EveningOptionDef = event.get_option(chosen)
				for key: String in event.extra_keys:
					report.event_texts.append(key)
					report.add_event(key, EveningReport.Tone.INFO)
				if option == null:
					continue
				CaseConsequences.merge_into(current, report.flag_changes)
				if not FlagCondition.check(option.condition, current):
					continue
				report.choices[event.id] = option.id
				report.event_spent += option.cost
				report.gained += option.gain
				CaseConsequences.add_all(report.flag_changes, flags, option.flags)
				for effect: CaseEffectDef in option.conditional_flags:
					if effect != null and FlagCondition.check(effect.condition, current):
						CaseConsequences.add_all(report.flag_changes, flags, effect.flags)
				for gauge: StringName in option.set_gauges:
					report.flag_changes[gauge] = option.set_gauges[gauge]
				if option.ends_campaign != &"" and report.ending == EveningReport.ENDING_NONE:
					report.ending = option.ends_campaign
				if not option.result_key.is_empty():
					report.event_texts.append(option.result_key)
					report.add_event(option.result_key, EveningReport.Tone.INFO)
				if option.household != &"":
					effects.append(option.household)
	return effects


static func _apply_household_effect(report: EveningReport, effect: StringName) -> void:
	match effect:
		EveningOptionDef.HOUSEHOLD_NOA_SICK:
			var noa: Household.Member = report.household.get_member(Household.NOA)
			if noa != null and noa.is_present():
				_fall_sick(noa, report, "hh_ev_noa_cough")
		EveningOptionDef.HOUSEHOLD_ILAN_DETAINED:
			report.household.detain_member(Household.ILAN)
			report.add_event("hh_ev_ilan_detained", EveningReport.Tone.BAD, Household.ILAN)
		EveningOptionDef.HOUSEHOLD_ILAN_RELEASED:
			report.household.release_member(Household.ILAN)
			report.add_event("hh_ev_ilan_released", EveningReport.Tone.WARNING, Household.ILAN)
		EveningOptionDef.HOUSEHOLD_ILAN_SOUTE:
			report.household.send_away(Household.ILAN, Household.AWAY_SOUTE)
			report.add_event("hh_ev_ilan_soute", EveningReport.Tone.WARNING, Household.ILAN)
		EveningOptionDef.HOUSEHOLD_ILAN_BACK:
			report.household.bring_home(Household.ILAN, true)
			report.add_event("hh_ev_ilan_back", EveningReport.Tone.WARNING, Household.ILAN)
		EveningOptionDef.HOUSEHOLD_DORA_TYCHO:
			report.household.send_away(Household.DORA, Household.AWAY_TYCHO)
			report.add_event("hh_ev_dora_tycho", EveningReport.Tone.INFO, Household.DORA)
		# Acte III.
		EveningOptionDef.HOUSEHOLD_ILAN_HOME:
			report.household.bring_home(Household.ILAN, false)
			report.add_event("hh_ev_ilan_home", EveningReport.Tone.GOOD, Household.ILAN)
		EveningOptionDef.HOUSEHOLD_ILAN_TYCHO:
			report.household.send_away(Household.ILAN, Household.AWAY_TYCHO)
			report.add_event("hh_ev_ilan_tycho", EveningReport.Tone.INFO, Household.ILAN)
		EveningOptionDef.HOUSEHOLD_DORA_SICK:
			var dora: Household.Member = report.household.get_member(Household.DORA)
			if dora != null and dora.is_present():
				_fall_sick(dora, report, "hh_ev_dora_cough")


## Soirée pivot (J10, D-076) : la Commission « reprend les dossiers » —
## `suspicion := ⌊suspicion / diviseur⌋` (+1 si retenue à l'audit du J9),
## avant les lettres de la soirée (double jeu : +2 ensuite).
static func _apply_pivot(report: EveningReport, economy: EconomyDef, flags: Dictionary[StringName, Variant]) -> void:
	var suspicion: int = FlagCondition.gauge_value(flags, CaseConsequences.FLAG_SUSPICION)
	var halved: int = floori(float(suspicion) / economy.pivot_suspicion_divisor)
	if FlagCondition.is_flag_true(flags, &"audit_retention"):
		halved += 1
	report.flag_changes[CaseConsequences.FLAG_SUSPICION] = halved
	report.flag_changes[&"pivot_done"] = true


## Soirée pivot du J20 (D-086) : l'Arbitre « rouvre les dossiers » —
## `suspicion := ⌊suspicion / diviseur⌋` (+1 si `act3_pivot_bonus_flag`).
static func _apply_pivot3(report: EveningReport, economy: EconomyDef, flags: Dictionary[StringName, Variant]) -> void:
	var suspicion: int = FlagCondition.gauge_value(flags, CaseConsequences.FLAG_SUSPICION)
	var halved: int = floori(float(suspicion) / economy.pivot_suspicion_divisor)
	if economy.act3_pivot_bonus_flag != &"" and FlagCondition.is_flag_true(flags, economy.act3_pivot_bonus_flag):
		halved += 1
	report.flag_changes[CaseConsequences.FLAG_SUSPICION] = halved
	report.flag_changes[&"pivot3_done"] = true


static func _fall_sick(member: Household.Member, report: EveningReport, key: String) -> void:
	if member.health != Household.Health.WELL:
		return
	member.health = Household.Health.SICK
	member.untreated_evenings = 0
	report.add_event(key, EveningReport.Tone.BAD, member.id)


static func _group_of(line: ExpenseLine) -> StringName:
	if line.ration_of != &"":
		return GROUP_RATIONS
	return &"meds" if line.member_id != &"" else line.id


static func _is_paid(lines: Array[ExpenseLine], id: StringName) -> bool:
	for line: ExpenseLine in lines:
		if line.id == id:
			return line.paid
	return false


static func _has_line(lines: Array[ExpenseLine], id: StringName) -> bool:
	for line: ExpenseLine in lines:
		if line.id == id:
			return true
	return false
