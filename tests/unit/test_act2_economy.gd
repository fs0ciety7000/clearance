## Acte II (docs/ACT2.md §1, §3, §5 ; D-076 → D-079) — rations d'air,
## prélèvements, revenus, pivot du J10, Revue du J17, fins F1–F9 et épilogues,
## sauvegarde v4.
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const CSV_PATH: String = "res://data/i18n/fr.csv"

var data: DataCatalog = null
var economy: EconomyDef = null
var keys: Dictionary[String, bool] = {}


func before_all() -> void:
	data = Gen.data()
	economy = data.get_economy()
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	while file != null and not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() > 0 and not row[0].is_empty():
			keys[row[0]] = true


func _flags(values: Dictionary) -> Dictionary[StringName, Variant]:
	var result: Dictionary[StringName, Variant] = {}
	for key: Variant in values:
		result[StringName(str(key))] = values[key]
	return result


func _line(lines: Array[ExpenseLine], id: StringName) -> ExpenseLine:
	for line: ExpenseLine in lines:
		if line.id == id:
			return line
	return null


# --- Rations, prélèvements, revenus (M2, D-079) -------------------------------

func test_rations_replace_the_air_tax_and_follow_presence() -> void:
	var home: Household = Household.new()
	assert_gt(economy.air_tax_for(10), 0)
	assert_eq(economy.air_tax_for(11), 0, "J11 : la taxe d'air devient rations")
	var lines: Array[ExpenseLine] = EveningService.build_lines(economy, 11, home)
	assert_null(_line(lines, EveningService.LINE_AIR_TAX))
	var own: ExpenseLine = _line(lines, EveningService.LINE_RATION_SELF)
	assert_true(own != null and own.mandatory, "ration du ou de la contrôleur·euse obligatoire")
	for id: StringName in Household.MEMBER_IDS:
		var ration: ExpenseLine = _line(lines, StringName(EveningService.RATION_PREFIX + String(id)))
		assert_not_null(ration, String(id))
		assert_eq(ration.cost, economy.ration_of(id))
		assert_eq(ration.ration_of, id)
	home.detain_member(Household.ILAN)
	home.send_away(Household.DORA, Household.AWAY_TYCHO)
	var absent: Array[ExpenseLine] = EveningService.build_lines(economy, 12, home)
	assert_null(_line(absent, &"ration_ilan"), "mis·e en attente : pas de ration")
	assert_null(_line(absent, &"ration_dora"), "partie sur le Tycho : pas de ration")
	assert_null(_line(absent, EveningService.LINE_OXYGEN))
	assert_not_null(_line(absent, &"ration_noa"))
	var refused: Array[ExpenseLine] = EveningService.build_lines(economy, 12, Household.new(), _flags({"meter_refused": true}))
	assert_eq(_line(refused, EveningService.LINE_RATION_SELF).cost, economy.ration_self + economy.meter_surcharge,
			"compteur refusé : surtaxe")


func test_unpaid_ration_makes_breathless_then_sick() -> void:
	var home: Household = Household.new()
	for evening: int in 2:
		var lines: Array[ExpenseLine] = EveningService.build_lines(economy, 11 + evening, home)
		EveningService.default_selection(lines, 500)
		_line(lines, &"ration_noa").paid = false
		var report: EveningReport = EveningService.apply(economy, 11 + evening, home, lines, 500, 1)
		home = report.household
		var noa: Household.Member = home.get_member(Household.NOA)
		assert_true(noa.breathless or noa.is_sick(), "soir %d" % evening)
		if evening == 0:
			assert_eq(noa.state_key(), "hh_state_breathless")
			assert_true(report.has_event("hh_ev_breathless", Household.NOA))
	assert_true(home.get_member(Household.NOA).is_sick(), "deux soirs sans ration : malade")
	var paid: Array[ExpenseLine] = EveningService.build_lines(economy, 13, home)
	EveningService.default_selection(paid, 500)
	var after: Household = EveningService.apply(economy, 13, home, paid, 500, 1).household
	assert_false(after.get_member(Household.NOA).breathless, "ration payée : souffle retrouvé")


func test_levies_take_thirty_percent_above_the_floor() -> void:
	assert_eq(economy.levy_for(11, 100), 18, "⌊(100 − 40) × 30 %⌋")
	assert_eq(economy.levy_for(17, 41), 0)
	assert_eq(economy.levy_for(17, 30), 0)
	assert_eq(economy.levy_for(12, 500), 0, "hors J11 / J17")
	var lines: Array[ExpenseLine] = EveningService.build_lines(economy, 11, Household.new(), {}, 140)
	var levy: ExpenseLine = _line(lines, EveningService.LINE_LEVY)
	assert_true(levy != null and levy.mandatory and levy.cost == 30)
	var context: Dictionary[StringName, Variant] = EveningService.context_flags({}, Household.new(), 0.9, 30)
	assert_eq(context[EveningService.GAUGE_LEVY], 30, "montant cité par la lettre du J11")
	assert_eq(context[EveningService.GAUGE_COMPLIANCE], 90)
	assert_eq(context[&"hh_present"], 3)


func test_ilan_job_income_and_free_oxygen() -> void:
	var flags: Dictionary[StringName, Variant] = _flags({"ilan_meter_job": true})
	var home: Household = Household.new()
	assert_eq(EveningService.income_lines(economy, economy.ilan_job_first_day - 1, home, flags).size(), 0)
	var income: Array[ExpenseLine] = EveningService.income_lines(economy, economy.ilan_job_first_day, home, flags)
	assert_eq(income.size(), 1)
	assert_eq(income[0].cost, economy.ilan_job_income)
	var lines: Array[ExpenseLine] = EveningService.build_lines(economy, economy.ilan_job_first_day, home, flags)
	EveningService.default_selection(lines, 0)
	var report: EveningReport = EveningService.apply(economy, economy.ilan_job_first_day, home, lines, 0, 1, [], {}, flags)
	assert_eq(report.gained, economy.ilan_job_income)
	home.detain_member(Household.ILAN)
	assert_eq(EveningService.income_lines(economy, economy.ilan_job_first_day, home, flags).size(), 0, "absent : pas de salaire")
	var even_day: int = 12 if economy.oxygen_due(12) else 13
	var promoted: Array[ExpenseLine] = EveningService.build_lines(economy, even_day, Household.new(), _flags({"promotion_offered": true}))
	var oxygen: ExpenseLine = _line(promoted, EveningService.LINE_OXYGEN)
	assert_true(oxygen != null and oxygen.cost == 0 and oxygen.mandatory, "promotion : oxygène fourni")


# --- Pivot du J10 (D-076) ------------------------------------------------------

func test_pivot_halves_suspicion_and_branches_the_letters() -> void:
	var day10: DayDef = data.get_day(10)
	assert_true(day10.has_evening, "le J10 a une soirée")
	var flags: Dictionary[StringName, Variant] = _flags({"suspicion": 5, "final_detained": true, "ilan_supported": true,
			"loyalty": 3})
	var context: Dictionary[StringName, Variant] = EveningService.context_flags(flags, Household.new(), 0.95)
	var events: Array[EveningEvent] = EveningService.build_events(day10.evening_events, context, economy)
	var ids: Array[StringName] = []
	for event: EveningEvent in events:
		ids.append(event.id)
	assert_true(ids.has(&"d10_vannes_failed"))
	assert_true(ids.has(&"d10_ilan_arrested"))
	assert_true(ids.has(&"d10_promo"), "mis en attente + conformité ≥ 85 % + 2 vivants")
	assert_false(ids.has(&"d10_vannes_opened"))
	var lines: Array[ExpenseLine] = EveningService.build_lines(economy, 10, Household.new())
	EveningService.default_selection(lines, 200)
	var report: EveningReport = EveningService.apply(economy, 10, Household.new(), lines, 200, 1, events,
			EveningService.default_choices(events, 200), context)
	assert_eq(report.flag_changes[&"suspicion"], 2, "⌊5 / 2⌋")
	assert_true(report.household.get_member(Household.ILAN).detained, "Ilan arrêté·e à la Soute")
	assert_true(report.household.get_member(Household.ILAN).is_alive(), "mis·e en attente ≠ PERDU")
	assert_false(report.is_game_over(), "le J10 ne termine plus la campagne")


func test_boarding_the_drift_ends_the_campaign_at_j10() -> void:
	var day10: DayDef = data.get_day(10)
	var context: Dictionary[StringName, Variant] = EveningService.context_flags(_flags({"drift_passes_bought": true}),
			Household.new(), 0.9)
	var events: Array[EveningEvent] = EveningService.build_events(day10.evening_events, context, economy)
	var lines: Array[ExpenseLine] = EveningService.build_lines(economy, 10, Household.new())
	var choices: Dictionary[StringName, StringName] = {&"d10_drift": &"board"}
	var board: EveningReport = EveningService.apply(economy, 10, Household.new(), lines, 200, 1, events, choices, context)
	assert_eq(board.ending, EndingService.F6_DRIFT, "« Embarquer »")
	var stay: EveningReport = EveningService.apply(economy, 10, Household.new(), lines, 200, 1, events,
			{&"d10_drift": &"stay"}, context)
	assert_false(stay.is_game_over())
	assert_eq(stay.gained, 20, "laissez-passer revendus")


# --- Revue du J17 et fins (D-078) ----------------------------------------------

func test_review_outcomes() -> void:
	assert_eq(EndingService.review_score(_flags({"suspicion": 2, "scanner_luciole": true})), 4)
	assert_eq(EndingService.review_score(_flags({"suspicion": 2, "scanner_consortium": true})), 1)
	var arrest: Dictionary = EndingService.review_outcome(_flags({"suspicion": economy.review_arrest_score}), economy)
	assert_eq(arrest["ending"], EndingService.F1_ARRESTED)
	var demoted: Dictionary = EndingService.review_outcome(_flags({"suspicion": economy.review_demote_score}), economy)
	assert_eq(demoted["cost"], economy.review_retention)
	assert_true(demoted["flags"].has(&"promotion_revoked"))
	assert_eq(EndingService.review_outcome({}, economy)["result"], EndingService.AUDIT_CLEAN)


func test_act2_ending_priority() -> void:
	var home: Household = Household.new()
	var cases: Array[Array] = [
		[{"lucioles_trust": 7, "loyalty": 7, "final2_passed": true}, EndingService.F1_ARRESTED],
		[{"final2_passed": true, "lucioles_trust": economy.air2_trust_threshold, "registre_sent": true}, EndingService.F5_AIR],
		[{"strike_joined": true, "solidarite": economy.strike_solidarity_threshold, "registre_sent": true}, EndingService.F9_STRIKE],
		[{"strike_joined": true, "solidarite": economy.strike_solidarity_threshold - 1}, EndingService.F7_REOPENS],
		[{"registre_sent": true, "drift2_passes_bought": true}, EndingService.F8_REGISTRE],
		[{"drift2_passes_bought": true}, EndingService.F6_DRIFT],
		[{"drift2_passes_bought": true, "final2_detained": true, "loyalty": 7}, EndingService.F4_GLORY],
		[{"final2_detained": true, "loyalty": 7, "promotion_revoked": true}, EndingService.F7_REOPENS],
		[{"final2_detained": true, "loyalty": 6}, EndingService.F7_REOPENS],
		[{}, EndingService.F7_REOPENS],
	]
	for spec: Array in cases:
		assert_eq(EndingService.evaluate_final_act2(_flags(spec[0]), home, 200, 0.95, economy), spec[1], str(spec[0]))
	var lost: Household = Household.new()
	for member: Household.Member in lost.members:
		member.health = Household.Health.LOST
	assert_eq(EndingService.evaluate_final_act2(_flags({"final2_passed": true, "lucioles_trust": 9}), lost, 200, 0.95, economy),
			EndingService.F3_FAMILY_LOST)
	var alone: Household = Household.new()
	alone.detain_member(Household.ILAN)
	alone.send_away(Household.DORA, Household.AWAY_TYCHO)
	assert_eq(EndingService.evaluate_final_act2(_flags({"drift2_passes_bought": true}), alone, 200, 0.95, economy),
			EndingService.F7_REOPENS, "F6 : au moins deux présents")
	assert_eq(EndingService.evaluate_final_act2(_flags({"drift2_passes_bought": true}), home, economy.drift_min_credits - 1, 0.95,
			economy), EndingService.F7_REOPENS, "F6 : réserve insuffisante")


func test_act2_epilogues_are_translated() -> void:
	var variants: Array[Dictionary] = [{}, {"registre_sent": true, "strike_joined": true, "ilan_joined_soute": true,
			"dora_departed": true, "final2_detained": true, "sc47_kasimir_passed": true, "review_arrested": true,
			"lindgren_signed": true, "sc41_sato_spared": true, "okonkwo_shielded": true, "sc45_ravel_spared": true,
			"ilan_detained_final": true, "sc43_mateus_detained": true, "sc49_lindgren_yes": true, "sc45_ravel_refused": true}]
	for ending: StringName in EndingService.ALL_ENDINGS:
		for values: Dictionary in variants:
			var epilogue: Dictionary = EndingService.epilogue_act2(ending, _flags(values), Household.new())
			assert_true(keys.has(str(epilogue["title_key"])), "%s : %s" % [ending, epilogue["title_key"]])
			assert_true(keys.has(str(epilogue["eyebrow_key"])), "%s : %s" % [ending, epilogue["eyebrow_key"]])
			assert_gt((epilogue["lines"] as PackedStringArray).size(), 1, String(ending))
			for line: String in epilogue["lines"]:
				assert_true(keys.has(line), "%s : %s" % [ending, line])


func test_act2_data_keys_are_translated() -> void:
	var missing: PackedStringArray = []
	for n: int in range(10, data.get_last_day_number() + 1):
		var day: DayDef = data.get_day(n)
		for event: EveningEventDef in day.evening_events:
			var event_keys: Array[String] = [event.text_key, event.title_key]
			for variant: ConditionalKey in event.text_variants + event.extra_keys:
				event_keys.append(variant.key)
			for key: String in event_keys:
				if not key.is_empty() and not keys.has(key):
					missing.append("J%d %s" % [n, key])
			for option: EveningOptionDef in event.options:
				for key: String in [option.label_key, option.result_key]:
					if not key.is_empty() and not keys.has(key):
						missing.append("J%d %s" % [n, key])
		for announcement: HallAnnouncementDef in day.announcements:
			if not keys.has(announcement.text_key):
				missing.append("J%d %s" % [n, announcement.text_key])
		for revocation: RevocationDef in day.revocations:
			if not revocation.reason_key.is_empty() and not keys.has(revocation.reason_key):
				missing.append("J%d %s" % [n, revocation.reason_key])
	assert_eq(missing.size(), 0, ", ".join(missing.slice(0, 12)))


# --- Sauvegarde v4 ---------------------------------------------------------------

func test_save_migration_v3_to_v4() -> void:
	var home: Dictionary = Household.new().to_dict()
	for member: Variant in home["members"]:
		var dict: Dictionary = member
		dict.erase("breathless")
		dict.erase("breathless_streak")
		dict.erase("away")
		if str(dict.get("id", "")) == "ilan":
			dict["health"] = "lost"
			dict["detained"] = true
		elif str(dict.get("id", "")) == "dora":
			dict["health"] = "lost"
	var v3: Dictionary = {"version": 3, "campaign_seed": 42, "current_day": 9, "credits": 50, "score_total": 40,
			"citations": 1, "narrative_flags": {"suspicion": 2}, "day_history": [], "household": home, "case_memory": {}}
	var migrated: Dictionary = SaveService.parse(JSON.stringify(v3))
	assert_eq(SaveService.as_int(migrated["version"]), 4)
	var restored: Household = Household.from_dict(migrated["household"])
	var ilan: Household.Member = restored.get_member(Household.ILAN)
	assert_true(ilan.is_alive(), "mis·e en attente ≠ PERDU")
	assert_true(ilan.detained)
	assert_false(ilan.is_present())
	assert_eq(ilan.state_key(), "hh_state_detained")
	assert_false(restored.get_member(Household.DORA).is_alive(), "un vrai PERDU le reste")
	assert_false(restored.get_member(Household.NOA).breathless)
	assert_eq(restored.alive_count(), 2)
	assert_eq(restored.present_count(), 1)
	# Aller-retour v4 : absences et essoufflement conservés.
	var now: Household = Household.new()
	now.send_away(Household.ILAN, Household.AWAY_SOUTE)
	now.get_member(Household.NOA).breathless = true
	now.get_member(Household.NOA).breathless_streak = 1
	var back: Household = Household.from_dict(JSON.parse_string(JSON.stringify(now.to_dict())))
	assert_eq(back.get_member(Household.ILAN).away, Household.AWAY_SOUTE)
	assert_eq(back.get_member(Household.ILAN).state_key(), "hh_state_away_soute")
	assert_eq(back.get_member(Household.NOA).breathless_streak, 1)
	back.bring_home(Household.ILAN, true)
	assert_true(back.get_member(Household.ILAN).is_present() and back.get_member(Household.ILAN).is_sick())
