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
class_name EveningService
extends RefCounted

const LINE_RENT: StringName = &"rent"
const LINE_AIR_TAX: StringName = &"air_tax"
const LINE_FOOD: StringName = &"food"
const LINE_HEATING: StringName = &"heating"
const LINE_OXYGEN: StringName = &"oxygen"
const MEDS_PREFIX: String = "meds_"
const MEDS_LABEL_KEY: String = "ev_line_meds"
const MEDS_NOTE_KEY: String = "ev_note_meds"

## Groupe de postes « médicaments » (`line_costs`).
const LINE_MEDS: StringName = &"meds"
const FLAG_HOSTILE: StringName = &"lucioles_hostile"
const HOSTILE_FROM_DAY: int = 7
const HOSTILE_TRUST: int = -2

## Ordre de présélection (après la taxe d'air, toujours payée).
const PRIORITY: Array[StringName] = [LINE_RENT, LINE_FOOD, LINE_OXYGEN, &"meds", LINE_HEATING]


## Postes de la soirée du jour `day_number`, dans l'ordre d'affichage.
static func build_lines(economy: EconomyDef, day_number: int, household: Household) -> Array[ExpenseLine]:
	var lines: Array[ExpenseLine] = []
	lines.append(ExpenseLine.new(LINE_RENT, economy.rent_for(day_number)))
	lines.append(ExpenseLine.new(LINE_AIR_TAX, economy.air_tax_for(day_number), true))
	lines.append(ExpenseLine.new(LINE_FOOD, economy.food))
	lines.append(ExpenseLine.new(LINE_HEATING, economy.heating))
	var dora: Household.Member = household.get_member(Household.DORA)
	if economy.oxygen_due(day_number) and dora != null and dora.is_alive():
		lines.append(ExpenseLine.new(LINE_OXYGEN, economy.oxygen))
	for member: Household.Member in household.sick_members():
		var meds: ExpenseLine = ExpenseLine.new(StringName(MEDS_PREFIX + String(member.id)), economy.medicine_per_member)
		meds.member_id = member.id
		meds.label_key = MEDS_LABEL_KEY
		meds.note_key = MEDS_NOTE_KEY + ("_grave" if member.health == Household.Health.GRAVELY_SICK else "")
		lines.append(meds)
	return lines


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
## (la taxe d'air, elle, peut creuser la dette).
static func can_toggle_on(lines: Array[ExpenseLine], balance: int, line: ExpenseLine) -> bool:
	if line.mandatory or line.paid:
		return true
	return balance - total_spent(lines) - line.cost >= 0


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
	var household_effects: Array[StringName] = _apply_events(report, events, choices, flags)
	report.spent = total_spent(lines) + report.event_spent
	report.balance_after = balance_before - report.spent + report.gained

	# 1. Soins des proches déjà malades.
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
		if member.untreated_evenings < economy.untreated_worsen_evenings:
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
		for member: Household.Member in home.alive_members():
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
		for member: Household.Member in home.alive_members():
			member.cold = true
			if home.cold_streak >= economy.deprivation_sick_evenings:
				_fall_sick(member, report, "hh_ev_sick_cold")
		var noa: Household.Member = home.get_member(Household.NOA)
		var roll: float = rng.randf()
		if home.cold_streak == 1 and noa != null and roll < economy.noa_cold_sick_chance:
			_fall_sick(noa, report, "hh_ev_noa_cough")

	# 4. Oxygène de Dora (soirs pairs).
	var dora: Household.Member = home.get_member(Household.DORA)
	if _has_line(lines, LINE_OXYGEN) and not _is_paid(lines, LINE_OXYGEN) and dora != null and dora.is_alive():
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
		if def != null and FlagCondition.check(def.condition, flags):
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
			event.audit = EndingService.audit_outcome(flags, economy)
		events.append(event)
	return events


## Vrai si l'option est finançable avec `balance` (pas de dette pour une option
## `requires_funds`).
static func can_choose(option: EveningOptionDef, balance: int) -> bool:
	return option != null and (not option.requires_funds or option.cost <= balance)


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
## appliquer après l'évolution normale de la nuit.
static func _apply_events(report: EveningReport, events: Array[EveningEvent], choices: Dictionary[StringName, StringName],
		flags: Dictionary[StringName, Variant]) -> Array[StringName]:
	var effects: Array[StringName] = []
	for event: EveningEvent in events:
		if report.ending == EndingService.F1_ARRESTED:
			break
		CaseConsequences.add_all(report.flag_changes, flags, event.def.flags)
		match event.kind:
			EveningEventDef.Kind.AUDIT:
				var outcome: Dictionary = event.audit
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
			EveningEventDef.Kind.CHOICE:
				var chosen: StringName = choices.get(event.id, event.default_option)
				var option: EveningOptionDef = event.get_option(chosen)
				for key: String in event.extra_keys:
					report.event_texts.append(key)
					report.add_event(key, EveningReport.Tone.INFO)
				if option == null:
					continue
				report.choices[event.id] = option.id
				report.event_spent += option.cost
				report.gained += option.gain
				CaseConsequences.add_all(report.flag_changes, flags, option.flags)
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
			if noa != null:
				_fall_sick(noa, report, "hh_ev_noa_cough")
		EveningOptionDef.HOUSEHOLD_ILAN_DETAINED:
			report.household.detain_member(Household.ILAN)
			report.add_event("hh_ev_ilan_detained", EveningReport.Tone.BAD, Household.ILAN)


static func _fall_sick(member: Household.Member, report: EveningReport, key: String) -> void:
	if member.health != Household.Health.WELL:
		return
	member.health = Household.Health.SICK
	member.untreated_evenings = 0
	report.add_event(key, EveningReport.Tone.BAD, member.id)


static func _group_of(line: ExpenseLine) -> StringName:
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
