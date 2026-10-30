## M13 « Gameplay » — données du lot B (docs/M13.md §3, §4.2, §5 ; D-144,
## D-150 → D-154) : jours révisés (temps, avertissements, poids, onglets,
## briefings, intercom, soirées), cas SC-104 → SC-111 et leurs verdicts,
## textes, Économat (AG-01 → AG-06 : offres, un achat par soir, pas de
## découvert, drapeaux, tiroir à double fond), Garde (U21 → U24), événements
## (EV-05, EV-09).
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const M13 := preload("res://tools/build_data_m13.gd")
const K := AnomalyType.Kind
const VK := VerdictKind.Kind
## Durées du shift de la 0.12 (avant compensation M13 §4.2).
const DURATION_012: Dictionary[int, float] = {3: 600.0, 4: 600.0, 7: 660.0, 8: 660.0, 9: 690.0}

var data: DataCatalog = null


func before_all() -> void:
	data = Gen.data()


func test_time_compensation_and_free_citations() -> void:
	for n: int in range(1, 4):
		assert_eq(data.get_day(n).free_citations_per_day, 2, "J%d" % n)
	assert_eq(data.get_day(4).free_citations_per_day, 3, "J4 : 3ᵉ avertissement gratuit (D-144)")
	assert_eq(data.get_day(8).free_citations_per_day, 3, "J8 : 3ᵉ avertissement gratuit (D-144)")
	assert_eq(data.get_day(5).free_citations_per_day, 2)
	assert_eq(data.get_day(3).duration_sec, DURATION_012[3], "J3 inchangé")
	# Compensation mesurée par `balance_sim --m13=compare` (M13 §4.2 proposait +25 / +40 s).
	assert_eq(data.get_day(4).duration_sec, DURATION_012[4] + M13.EXTRA_SECONDS_EARLY, "J4 → J7")
	assert_eq(data.get_day(7).duration_sec, DURATION_012[7] + M13.EXTRA_SECONDS_EARLY)
	assert_eq(data.get_day(8).duration_sec, DURATION_012[8] + M13.EXTRA_SECONDS_LATE, "J8 → J30")
	assert_eq(data.get_day(9).duration_sec, DURATION_012[9] + M13.EXTRA_SECONDS_LATE)
	assert_eq(M13Sim.EXTRA_SECONDS_LATE, M13.EXTRA_SECONDS_LATE, "simulation et données alignées")
	for world: StringName in [&"a", &"b", &"c", &"d"]:
		assert_true(data.get_epilogue_day(world).untimed, "J31 : aucune compensation")


func test_anomaly_weights_and_tabs() -> void:
	assert_almost_eq(data.get_day(4).anomaly_weights[K.STATEMENT_MISMATCH], 0.15, 0.0001)
	assert_almost_eq(data.get_day(4).anomaly_weights[K.PURPOSE_MISMATCH], 0.15, 0.0001, "0,06 pris à PURPOSE_MISMATCH")
	assert_almost_eq(data.get_day(5).anomaly_weights[K.PURPOSE_MISMATCH], 0.08, 0.0001)
	assert_almost_eq(data.get_day(24).anomaly_weights[K.STATEMENT_MISMATCH], 0.12, 0.0001, "poids relevé (gen_stats)")
	assert_eq(data.get_day(12).statement_topic_weights[&"employer"], 0.50)
	assert_false(data.get_day(11).statement_topic_weights.has(&"employer"), "employeur au J12")
	assert_eq(data.get_day(24).statement_topic_weights[&"host"], 0.40)
	for n: int in range(1, 8):
		assert_false(data.get_day(n).anomaly_weights.has(K.CONTRABAND), "J%d : pas de fouille" % n)
		assert_false(data.get_day(n).rulebook_tabs.has("contraband"))
	for n: int in range(8, 31):
		assert_true(data.get_day(n).rulebook_tabs.has("contraband"), "J%d : onglet Contrebande" % n)
		assert_between(data.get_day(n).search_cue_noise_rate, 0.10, 0.12, "J%d" % n)
	assert_gt(data.get_day(19).anomaly_weights[K.CONTRABAND], data.get_day(18).anomaly_weights[K.CONTRABAND], "J19 (R47) : plus de contrebande")
	assert_true(data.get_day(19).rule_set.has_rule(&"r_belt_search"))
	assert_false(data.get_day(18).rule_set.has_rule(&"r_belt_search"))
	var r47: ProcedureRule = data.rules[&"r_belt_search"]
	assert_eq(r47.min_stay_days, 7)
	assert_eq(r47.applies_to_faction_ids, [&"cer"] as Array[StringName])


func test_scripted_cases_have_their_intended_verdicts() -> void:
	var expected: Dictionary[StringName, VerdictKind.Kind] = {
		&"sc_104": VK.DENY, &"sc_105": VK.APPROVE, &"sc_106": VK.DENY, &"sc_107": VK.DENY, &"sc_108": VK.DENY,
		&"sc_109": VK.APPROVE, &"sc_111": VK.DETAIN,
	}
	if Passenger.has_truth_path(Statement.PATH_SPONSOR_NAME):
		expected[&"sc_110"] = VK.DENY
	var seen: Dictionary[StringName, int] = {}
	for campaign: int in [20_871_315, 7, 99]:
		for n: int in range(4, 31):
			var day: DayDef = data.get_day(n)
			for scripted: ScriptedCaseDef in day.scripted_cases:
				if not expected.has(scripted.id):
					continue
				var builder: CaseBuilder = CaseBuilder.new(data, day, SeededRng.day_seed(campaign, n), [],
						CaseMemory.resolve(data, day, campaign, {}))
				builder.presentation_minute = 12 * 60
				for g: GeneratedCase in builder.build_day():
					if g.scripted_id != scripted.id:
						continue
					seen[scripted.id] = seen.get(scripted.id, 0) + 1
					var where: String = "%s (graine %d)" % [scripted.id, campaign]
					assert_eq(g.key.expected_verdict, expected[scripted.id], "%s : %s" % [where, g.key.get_violated_rule_ids()])
					assert_eq(g.invariant_errors, PackedStringArray(), where)
					assert_eq(g.clean_violation_count, 0, where + " : cas propre")
	for id: StringName in expected:
		assert_eq(seen.get(id, 0), 3, "%s construit à chaque graine" % id)


func test_scripted_m13_cases_details() -> void:
	var b4: CaseBuilder = CaseBuilder.new(data, data.get_day(4), Gen.day_seed(1, 4))
	var strand: GeneratedCase = b4.build(5)
	assert_eq(strand.scripted_id, &"sc_104")
	assert_eq(strand.key.get_violated_rule_ids(), [&"r_statements"] as Array[StringName], "R43 seule")
	assert_eq(strand.case.get_statement(&"stay").value, Vector2i(18, 24), "« trois semaines »")
	var b8: CaseBuilder = CaseBuilder.new(data, data.get_day(8), Gen.day_seed(1, 8))
	var mbeki: GeneratedCase = b8.build(5)
	assert_eq(mbeki.scripted_id, &"sc_105")
	assert_eq(mbeki.case.search_cues, [SearchLayout.CUE_GLOVE] as Array[StringName])
	assert_true(mbeki.case.declared_implants().has("KIN-11"), "bras de levage déclaré")
	assert_true(mbeki.case.passenger_presented.implants.is_empty(), "invisible au visage")
	var arm: SearchItem = mbeki.case.search_layout.items_in(SearchLayout.ZONE_ARMS)[0]
	assert_eq(arm.implant_code, "KIN-11")
	assert_eq(mbeki.key.expected_verdict, VK.APPROVE)
	assert_eq(DiscrepancyChecker.check(mbeki.case, FieldRef.passenger_face(), Rule.find_ref(mbeki.case, &"id_card", &"implants"),
			b8.ctx).result, Discrepancy.Result.CONCORDANT, "« non visible — fouille »")
	var s105: ScriptedCaseDef = data.get_day(8).get_scripted_case(5)
	assert_eq(s105.flags_on_search, {&"sc105_searched": 0} as Dictionary[StringName, int])
	var b16: CaseBuilder = CaseBuilder.new(data, data.get_day(16), Gen.day_seed(1, 16))
	var ilse: GeneratedCase = b16.build(5)
	assert_eq(ilse.case.cargo_reply, Case.CARGO_EVASIVE)
	assert_eq(ilse.case.cargo_line_key, "sc108_ilse_cargo")
	assert_true(ilse.case.luciole_codes.has(6) and ilse.case.luciole_codes.has(3))
	assert_eq(ilse.case.slipped_items.size(), 1, "le mot des Lucioles")
	var b19: CaseBuilder = CaseBuilder.new(data, data.get_day(19), Gen.day_seed(1, 19), [],
			CaseMemory.resolve(data, data.get_day(19), 1, {}))
	var kerr: GeneratedCase = b19.build(4)
	assert_eq(kerr.scripted_id, &"sc_109")
	var r47: ProcedureRule = data.rules[&"r_belt_search"]
	assert_true(r47.requires_search(kerr.case), "Ceinturier, 14 jours : fouille obligatoire")
	assert_eq(kerr.case.passenger_presented.family_name, "Kerr")


func test_m13_text_keys_exist_and_fit() -> void:
	var keys: PackedStringArray = []
	for n: int in data.days:
		var day: DayDef = data.get_day(n)
		for line: IntercomLineDef in day.intercom_lines:
			keys.append_array([line.text_key, line.speaker_key])
		for message: BriefingMessageDef in day.briefing_messages:
			keys.append_array([message.text_key, message.speaker_key])
		for event: EveningEventDef in day.evening_events:
			keys.append(event.text_key)
			for extra: ConditionalKey in event.extra_keys:
				keys.append(extra.key)
		for announcement: HallAnnouncementDef in day.announcements:
			keys.append(announcement.text_key)
		for scripted: ScriptedCaseDef in day.scripted_cases:
			for variant: ConditionalKey in scripted.line_variants:
				keys.append(variant.key)
			for spec: Variant in scripted.statements.values():
				keys.append(str((spec as Dictionary).get("key", "")))
			for question: Variant in scripted.statement_frames:
				keys.append(str(scripted.statement_frames[question]))
	for rule_id: StringName in [&"r_statements", &"r_search_cause", &"r_contraband", &"r_weapons_detain", &"r_belt_search"]:
		keys.append_array([(data.rules[rule_id] as Rule).title_key, (data.rules[rule_id] as Rule).rulebook_text_key])
	for tier: Rule in data.rule_tiers.values():
		keys.append(tier.rulebook_text_key)
	for upgrade: UpgradeDef in data.get_economy().upgrades:
		keys.append_array([upgrade.name_key, upgrade.desc_key, upgrade.note_key, upgrade.expense_key, upgrade.offer_message_key])
	for item: SearchItemDef in data.search_catalog.items:
		keys.append_array([item.name_key, item.desc_key])
	for unit_id: StringName in [&"u21", &"u22", &"u23", &"u24"]:
		keys.append(data.garde.get_unit(unit_id).title_key)
	var ev09: StationEventDef = data.events[&"ev_09"]
	keys.append_array([ev09.announce_key, ev09.title_key, ev09.rulebook_key, ev09.end_key, ev09.garde_announce_key])
	var tables: StatementTablesDef = data.statement_tables
	keys.append_array(tables.text_lengths.keys())
	for cue: StringName in SearchLayout.CUES:
		keys.append(SearchLayout.cue_line_key(cue, Passenger.SEX_F))
		keys.append(SearchLayout.cue_line_key(cue, Passenger.SEX_M))
	var missing: PackedStringArray = []
	for key: String in keys:
		if not key.is_empty() and not UiText.has(key) and not missing.has(key):
			missing.append(key)
	assert_eq(missing, PackedStringArray(), "clés M13 absentes de fr.csv")
	var too_long: PackedStringArray = []
	var unbalanced: PackedStringArray = []
	var line_key: RegEx = RegEx.create_from_string("^(sc1(0[4-9]|1[01])_[a-z_]+|line_(stmt|cargo|search|about_statement|about_contraband|about_weapon|about_concealed)[a-z_0-9]*|sc(35|75|92|62|65)_[a-z_]*(book|nair|mother)[a-z_]*)$")
	var m13_key: RegEx = RegEx.create_from_string("^(stmt_|line_stmt|line_cargo|line_search|line_about_(statement|contraband|weapon|concealed)|cue_|sc1(0[4-9]|1[01])_|okonkwo_j[48]_|sato_j12_|upg_|shop_|srch_|item_)")
	var csv: FileAccess = FileAccess.open("res://data/i18n/fr.csv", FileAccess.READ)
	csv.get_csv_line()
	while not csv.eof_reached():
		var row: PackedStringArray = csv.get_csv_line()
		if row.size() < 2:
			continue
		if line_key.search(row[0]) != null and not row[0].ends_with("_note") and not row[0].ends_with("_label") \
				and row[1].length() > 90:
			too_long.append("%s (%d)" % [row[0], row[1].length()])
		if m13_key.search(row[0]) != null and row[1].count("‹") != row[1].count("›"):
			unbalanced.append(row[0])
	assert_eq(too_long, PackedStringArray(), "sous-titres > 90 caractères")
	assert_eq(unbalanced, PackedStringArray(), "chevrons Tessar déséquilibrés")


func test_upgrades_catalog_and_shop() -> void:
	var economy: EconomyDef = data.get_economy()
	assert_eq(economy.upgrades.size(), 6)
	assert_eq(economy.upgrades_per_evening, 1)
	var prices: Dictionary[StringName, int] = {}
	for upgrade: UpgradeDef in economy.upgrades:
		prices[upgrade.id] = upgrade.price
		assert_between(upgrade.price, 10, 35, String(upgrade.id))
	assert_eq(prices, {&"ag01": 20, &"ag02": 20, &"ag03": 20, &"ag04": 15, &"ag05": 10, &"ag06": 35} as Dictionary[StringName, int])
	var flags: Dictionary[StringName, Variant] = {}
	assert_true(EveningService.shop_lines(economy, 4, flags).is_empty(), "Économat à partir du soir du J5")
	var j5: Array[StringName] = _ids(EveningService.shop_lines(economy, 5, flags))
	assert_eq(j5, [&"ag01"] as Array[StringName], "J5 : hygiaphone ; tiroir sans enveloppe vue")
	flags[&"bribe_seen"] = true
	assert_eq(_ids(EveningService.shop_lines(economy, 6, flags)), [&"ag01", &"ag04", &"ag05"] as Array[StringName])
	assert_false(_ids(EveningService.shop_lines(economy, 9, flags)).has(&"ag05"), "AG-05 : soirs J6–J8 seulement")
	assert_eq(_ids(EveningService.shop_lines(economy, 11, flags)), [&"ag01", &"ag02", &"ag03", &"ag06", &"ag04"] as Array[StringName])
	flags[&"upg_ag01"] = true
	assert_false(_ids(EveningService.shop_lines(economy, 12, flags)).has(&"ag01"), "acquis : plus en vente")
	assert_true(EveningService.shop_lines(economy, 30, flags).is_empty(), "jusqu'au soir du J29")


func test_one_purchase_per_evening_without_overdraft_and_flags() -> void:
	var economy: EconomyDef = data.get_economy()
	var home: Household = Household.new()
	var flags: Dictionary[StringName, Variant] = {&"loyalty": 2}
	var lines: Array[ExpenseLine] = EveningService.build_lines(economy, 11, home, flags, 60)
	EveningService.default_selection(lines, 60)
	var shop: Array[ExpenseLine] = EveningService.shop_lines(economy, 11, flags)
	lines.append_array(shop)
	for line: ExpenseLine in shop:
		assert_false(line.paid, "jamais présélectionné")
	var spent: int = EveningService.total_spent(lines)
	var monitor: ExpenseLine = _line(shop, &"ag06")
	var lamp: ExpenseLine = _line(shop, &"ag02")
	assert_eq(EveningService.can_toggle_on(lines, spent + 34, monitor), false, "pas de découvert")
	assert_true(EveningService.can_toggle_on(lines, spent + 35, monitor))
	monitor.paid = true
	assert_false(EveningService.can_toggle_on(lines, 500, lamp), "un achat par soir")
	var report: EveningReport = EveningService.apply(economy, 11, home, lines, spent + 40, 1, [], {}, flags)
	assert_eq(report.flag_changes.get(&"upg_ag06", false), true)
	assert_eq(report.flag_changes.get(&"loyalty", 0), 3, "AG-06 : loyalty +1")
	assert_eq(report.upgrades_bought, [&"ag06"] as Array[StringName])
	assert_eq(report.balance_after, 40 - 35 + report.gained, "prix débité")


func test_double_drawer_envelopes_and_audits() -> void:
	var economy: EconomyDef = data.get_economy()
	var flags: Dictionary[StringName, Variant] = {&"upg_ag04": true, &"suspicion": 0}
	var changes: Dictionary[StringName, Variant] = {}
	var effects: Dictionary = {&"suspicion": 1}
	var first: Dictionary = CaseConsequences.drawer_effects(effects, flags, changes)
	assert_eq(first.get(&"suspicion", 0), 1, "1ʳᵉ enveloppe : trace")
	CaseConsequences.merge_into(flags, changes)
	changes.clear()
	assert_false(CaseConsequences.drawer_effects(effects, flags, changes).has(&"suspicion"), "2ᵉ : aucune trace")
	CaseConsequences.merge_into(flags, changes)
	changes.clear()
	assert_eq(CaseConsequences.drawer_effects(effects, flags, changes).get(&"suspicion", 0), 1, "3ᵉ : trace")
	# Audit du J9 : seuil de retenue atteint → tiroir trouvé, +2, confisqué.
	var audited: Dictionary[StringName, Variant] = {&"upg_ag04": true, &"suspicion": 2}
	var outcome: Dictionary = EndingService.audit_outcome(audited, economy)
	assert_eq(outcome["score"], 4)
	assert_eq(outcome["result"], EndingService.AUDIT_ARREST, "l'arrestation devient possible")
	assert_true((outcome["flags"] as Dictionary).has(UpgradeDef.FLAG_DRAWER_FOUND))
	var calm: Dictionary = EndingService.audit_outcome({&"upg_ag04": true, &"suspicion": 1} as Dictionary[StringName, Variant], economy)
	assert_false(calm.get("drawer_found", false), "sous le seuil : tiroir fermé")
	var review: Dictionary = EndingService.review_outcome({&"upg_ag04": true, &"suspicion": 3} as Dictionary[StringName, Variant], economy)
	assert_true(review.get("drawer_found", false), "Revue du J17 ≥ 3")
	var found: Dictionary[StringName, Variant] = {&"upg_ag04": true, &"upg_ag04_found": true}
	assert_false(UpgradeDef.owns(found, UpgradeDef.ID_DOUBLE_DRAWER), "confisqué : effet perdu")


func test_garde_units_events_and_version() -> void:
	var g: GardeDef = data.garde
	assert_eq(g.version, 2, "garde_version 2 (D-152)")
	assert_eq(g.get_unit(&"u21").tier, 2)
	assert_eq(g.get_unit(&"u21").prerequisites, [&"u01"] as Array[StringName])
	assert_eq(g.get_unit(&"u23").prerequisites, [&"u22", &"u11"] as Array[StringName])
	assert_eq((g.get_unit(&"u24").rules[0] as StatementsConsistentRule).tier, 3, "U24 : employeur et origine")
	assert_true(g.get_unit(&"u22").rulebook_tabs.has("contraband"))
	for unit: GardeUnitDef in g.units:
		for rule: Rule in unit.rules:
			assert_false(rule.id == &"r_belt_search", "R47 exclue de la Garde")
			if rule is StatementsConsistentRule:
				assert_false((rule as StatementsConsistentRule).checks_topic(&"host"), "R43 s4 exclue")
	var blackout: StationEventDef = data.events[&"ev_05"]
	var retired: Array[StringName] = []
	for change: RuleChangeDef in blackout.changes:
		if change.op == RuleChangeDef.Op.RETIRE:
			retired.append(change.rule_id)
	assert_true(retired.has(&"r_search_cause"), "EV-05 : portique hors tension")
	var alert: StationEventDef = data.events[&"ev_09"]
	assert_eq(alert.event_class, StationEventDef.EventClass.A)
	assert_eq(alert.required_rule_id, &"r_search_cause")
	assert_eq(alert.changes[0].params.get(&"search_authorized", false), true)
	assert_eq(data.station_events.version, 2, "events_version + 1")


func test_alert_plans_one_or_two_carriers_of_the_profile() -> void:
	var day: DayDef = data.get_day(9).make_shift_copy()
	var builder: CaseBuilder = CaseBuilder.new(data, day, Gen.day_seed(3, 9))
	builder.build(0)
	var alert: StationEventDef = data.events[&"ev_09"]
	var diff: RuleDiff = builder.ctx.apply_changes(alert.changes, alert.id)
	builder.on_rules_changed(diff)
	var forced: Array[int] = []
	for index: int in builder._forced:
		if StringName(str(builder._forced[index].get("rule_id", ""))) == &"r_search_cause":
			forced.append(index)
	assert_between(forced.size(), 1, 2, "1 ou 2 porteurs du profil")
	for index: int in forced:
		assert_between(index, 1, 5, "dans la fenêtre de 5 passagers")
		var g: GeneratedCase = builder.build(index)
		assert_eq(g.case.passenger_presented.faction_id, &"cer", "profil de l'alerte")
		assert_true(g.key.get_violated_rule_ids().has(&"r_contraband"))


func _ids(lines: Array[ExpenseLine]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for line: ExpenseLine in lines:
		ids.append(line.upgrade_id)
	return ids


func _line(lines: Array[ExpenseLine], upgrade_id: StringName) -> ExpenseLine:
	for line: ExpenseLine in lines:
		if line.upgrade_id == upgrade_id:
			return line
	return null
