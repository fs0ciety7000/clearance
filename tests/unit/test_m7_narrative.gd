## M7 — couche narrative pure : objets glissés et conséquences de cas
## (`SlippedItem`, `CaseConsequences`), mémoire des passagers (`CaseMemory`),
## sauvegarde v3 (migration v2 → v3), briefings conditionnels, événements du
## soir (choix par défaut, coûts imposés, audit, aveu d'Ilan), fins F1–F7 et
## épilogues (`EndingService`, NARRATIVE §6).
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const VK := VerdictKind.Kind
const SD := SlippedItem.Decision

var data: DataCatalog = null
var economy: EconomyDef = null


func before_all() -> void:
	data = Gen.data()
	economy = data.get_economy()


func _flags(values: Dictionary) -> Dictionary[StringName, Variant]:
	var result: Dictionary[StringName, Variant] = {}
	for key: Variant in values:
		result[StringName(str(key))] = values[key]
	return result


func _scripted(day_number: int, id: StringName) -> ScriptedCaseDef:
	for scripted: ScriptedCaseDef in data.get_day(day_number).scripted_cases:
		if scripted.id == id:
			return scripted
	return null


# --- Objets glissés et conséquences ------------------------------------------

func test_envelope_effects_depend_on_verdict_and_decision() -> void:
	var sc07: ScriptedCaseDef = _scripted(4, &"sc_07")
	var item: SlippedItem = sc07.slipped_item.instantiate(&"d04_c04", 0, {})
	assert_eq(item.id, &"d04_c04_item0")
	assert_eq(item.final_decision(), SD.RETURN, "refus automatique sans décision")
	assert_eq(item.effects_for(VK.APPROVE, SD.KEEP), {&"sc07_bribe_kept": 0, &"suspicion": 1})
	assert_eq(item.effects_for(VK.DENY, SD.KEEP), {&"sc07_bribe_kept": 0, &"sc07_complaint": 0, &"suspicion": 2})
	assert_eq(item.effects_for(VK.DETAIN, SD.KEEP), item.effects_for(VK.DENY, SD.KEEP), "détention → repli deny_*")
	assert_eq(item.credits_for(SD.KEEP), 20)
	assert_eq(item.credits_for(SD.RETURN), 0)
	assert_false(item.is_allowed(SD.REPORT))


func test_case_consequences_combine_verdict_items_and_password() -> void:
	var sc07: ScriptedCaseDef = _scripted(4, &"sc_07")
	var c: Case = Case.new()
	var item: SlippedItem = sc07.slipped_item.instantiate(&"x", 0, {})
	item.decision = SD.KEEP
	c.slipped_items.append(item)
	var flags: Dictionary[StringName, Variant] = _flags({"suspicion": 1})
	var changes: Dictionary[StringName, Variant] = CaseConsequences.compute(sc07, c, VK.DENY, true, false, 4, flags)
	assert_eq(changes[&"suspicion"], 3, "1 (SC-02) + 2 (refus + enveloppe gardée)")
	assert_eq(changes[&"sc07_complaint"], true)
	# SC-13 : détention ≠ refus (NARRATIVE B3) ; phrase de passe : +1 une seule fois.
	var sc13: ScriptedCaseDef = _scripted(7, &"sc_13")
	var detained: Dictionary[StringName, Variant] = CaseConsequences.compute(sc13, Case.new(), VK.DETAIN, true, true, 7,
			_flags({"lucioles_trust": 2, "loyalty": 1}))
	assert_eq(detained[&"sc13_detained"], true)
	assert_eq(detained[&"loyalty"], 2)
	assert_eq(detained[&"lucioles_trust"], 1, "2 − 2 + 1 (phrase de passe)")
	assert_eq(detained[&"password_answered"], true)
	var again: Dictionary[StringName, Variant] = CaseConsequences.compute(null, Case.new(), VK.APPROVE, false, true, 9,
			_flags({"password_answered": true, "suspicion": 1}))
	assert_false(again.has(&"lucioles_trust"), "une seule fois dans la campagne")
	assert_eq(again[&"suspicion"], 2, "répondre le jour de l'audit se voit")
	# SC-16 : famille séparée seulement si Idris est passé.
	var sc16: ScriptedCaseDef = _scripted(8, &"sc_16")
	assert_true(CaseConsequences.compute(sc16, Case.new(), VK.DENY, true, false, 8, _flags({"sc15_idris_passed": true})).has(&"sc16_family_split"))
	assert_false(CaseConsequences.compute(sc16, Case.new(), VK.DENY, true, false, 8, {}).has(&"sc16_family_split"))


func test_generated_luciole_carrier_consequences() -> void:
	var c: Case = Case.new()
	c.dialogue_tags = [CaseBuilder.TAG_LUCIOLE]
	assert_eq(CaseConsequences.compute(null, c, VK.APPROVE, true, false, 6, {})[&"lucioles_trust"], 1, "aider")
	assert_true(CaseConsequences.compute(null, c, VK.APPROVE, false, false, 6, {}).is_empty(), "en règle : rien")
	var denounced: Dictionary[StringName, Variant] = CaseConsequences.compute(null, c, VK.DETAIN, true, false, 7, {})
	assert_eq(denounced[&"lucioles_trust"], -2)
	assert_eq(denounced[&"loyalty"], 1)


# --- Mémoire des passagers et sauvegarde v3 -----------------------------------

func test_case_memory_snapshot_and_recall() -> void:
	var campaign_seed: int = 4242
	var entry: Dictionary = CaseMemory.recall(data, campaign_seed, &"sc_04")
	assert_eq(entry["given_name"], "Mira")
	assert_eq(entry["day"], 3)
	var app: PassengerAppearance = CaseMemory.appearance_of(entry)
	assert_not_null(app)
	assert_false(app.is_face_covered(), "visage mémorisé visière relevée")
	var resolved: Dictionary = CaseMemory.resolve(data, data.get_day(10), campaign_seed, {})
	assert_true(resolved.has("sc_04"), "SC-22 a besoin de SC-04")
	var overrides: Dictionary = CaseMemory.identity_overrides(CaseMemory.recall(data, campaign_seed, &"sc_02"))
	assert_eq(overrides[&"given_name"], "Amara")
	assert_true(overrides[&"birth_date"] is int)


func test_continuity_faces_and_identity_across_days() -> void:
	for s: int in 5:
		var campaign_seed: int = SeededRng.mix(31, s)
		for pair: Array in [[4, &"sc_06", &"sc_02"], [7, &"sc_13", &"sc_05"], [10, &"sc_22", &"sc_04"]]:
			var day_number: int = pair[0]
			var id: StringName = pair[1]
			var source: StringName = pair[2]
			var day: DayDef = data.get_day(day_number)
			var memory: Dictionary = CaseMemory.resolve(data, day, campaign_seed, {})
			var builder: CaseBuilder = CaseBuilder.new(data, day, SeededRng.day_seed(campaign_seed, day_number),
					[&"sc02_turned_away"], memory)
			var scripted: ScriptedCaseDef = _scripted(day_number, id)
			var g: GeneratedCase = builder.build(scripted.at_index)
			var entry: Dictionary = memory[String(source)]
			var before: PassengerAppearance = CaseMemory.appearance_of(entry)
			var now: PassengerAppearance = g.case.passenger_presented.appearance.without_visor()
			assert_eq(FaceComparator.compare(before, now, builder.ctx.identity_slots), [] as Array[StringName],
					"%s a le visage de %s" % [id, source])
			if id == &"sc_06":
				var remembered: Dictionary = memory["sc_02"]
				assert_eq(g.case.passenger_presented.full_name(), "Amara Diallo")
				assert_eq(g.case.passenger_presented.citizen_id, remembered["citizen_id"])
				assert_eq(g.case.passenger_presented.birth_date, remembered["birth_date"])


func test_save_v3_round_trip_and_migration_from_v2() -> void:
	var v2: Dictionary = {
		"version": 2, "campaign_seed": 42, "current_day": 3, "credits": 12, "score_total": 40, "citations": 1,
		"narrative_flags": {"sc02_mercy": true}, "day_history": [], "household": Household.new().to_dict(),
	}
	var migrated: Dictionary = SaveService.parse(JSON.stringify(v2))
	assert_false(migrated.is_empty())
	assert_eq(SaveService.as_int(migrated["version"]), SaveService.VERSION, "v2 → v3 → v4 en chaîne")
	assert_eq(migrated["case_memory"], {})
	assert_eq(SaveService.as_int(migrated["narrative_flags"]["suspicion"]), 1, "D-052 : SC-02 approuvée rétroactive")
	var v2b: Dictionary = v2.duplicate(true)
	v2b["narrative_flags"] = {"sc02_mercy": true, "suspicion": 3}
	assert_eq(SaveService.as_int(SaveService.parse(JSON.stringify(v2b))["narrative_flags"]["suspicion"]), 3, "jamais écrasée")
	# Foyer : membre mis en attente conservé.
	var home: Household = Household.new()
	home.detain_member(Household.ILAN)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(home.to_dict()))
	var restored: Household = Household.from_dict(parsed)
	assert_true(restored.get_member(Household.ILAN).detained)
	assert_eq(restored.get_member(Household.ILAN).state_key(), "hh_state_detained")
	# Acte II (docs/ACT2.md §1.3) : mis·e en attente = vivant·e, absent·e du foyer.
	assert_eq(restored.alive_count(), 3)
	assert_eq(restored.present_count(), 2)


# --- Briefings ----------------------------------------------------------------

func test_briefings_pick_conditional_messages() -> void:
	var home: Household = Household.new()
	var j4: BriefingContent = BriefingContent.build(data.get_day(4), _flags({"lucioles_note_burned": true}), home)
	var texts: Array[String] = []
	for message: Dictionary in j4.messages:
		texts.append(message["text"])
	assert_eq(texts, ["msg_cons_day04", "msg_okonkwo_day04", "msg_luc_day04", "msg_ilan_day04"] as Array[String])
	assert_eq(j4.messages[2]["voice"], BriefingContent.Voice.LUCIOLES)
	# Au plus 4 messages ; l'état du foyer remplace le message narratif d'Ilan.
	home.get_member(Household.NOA).health = Household.Health.SICK
	var j5: BriefingContent = BriefingContent.build(data.get_day(5), _flags({"sc06_reunited": true, "sc07_complaint": true,
			"sc08_passed": true, "lucioles_trust": 1, "sc07_bribe_kept": true}), home)
	assert_eq(j5.messages.size(), BriefingContent.MAX_MESSAGES)
	assert_eq(j5.messages[j5.messages.size() - 1]["text"], "msg_family_noa_sick")
	# Variante d'Ilan au J6 ; message « tout va bien » sans narration au J5.
	var j6: BriefingContent = BriefingContent.build(data.get_day(6), _flags({"lucioles_heating_accepted": true}), Household.new())
	assert_eq(j6.messages[j6.messages.size() - 1]["text"], "msg_ilan_day06")
	var j5_ok: BriefingContent = BriefingContent.build(data.get_day(5), {}, Household.new())
	assert_eq(j5_ok.messages[j5_ok.messages.size() - 1]["text"], "msg_family_ok")
	# Ilan dénoncé·e : plus de message d'Ilan au J10.
	var away: Household = Household.new()
	away.detain_member(Household.ILAN)
	var j10: BriefingContent = BriefingContent.build(data.get_day(10), _flags({"ilan_denounced": true, "okonkwo_shielded": true}), away)
	for message: Dictionary in j10.messages:
		assert_ne(message["speaker"], BriefingContent.SPEAKER_ILAN)


# --- Soirées ------------------------------------------------------------------

func test_evening_events_defaults_and_line_costs() -> void:
	var j5: Array[EveningEvent] = EveningService.build_events(data.get_day(5).evening_events, _flags({"sc10_passed": true}), economy)
	assert_eq(j5.size(), 2, "chauffage offert + lettre d'Ilan")
	var choices: Dictionary[StringName, StringName] = EveningService.default_choices(j5, 100)
	assert_eq(choices[&"d05_heat"], &"refuse", "refus par défaut sans UI")
	var lines: Array[ExpenseLine] = EveningService.build_lines(economy, 5, Household.new())
	EveningService.apply_line_costs(lines, j5, {&"d05_heat": &"accept"})
	for line: ExpenseLine in lines:
		if line.id == &"heating":
			assert_eq(line.cost, 0, "chauffage offert")
	assert_eq(EveningService.build_events(data.get_day(5).evening_events, {}, economy).size(), 1, "sans condition : la lettre seule")
	# J6 : bio-scan gratuit si la médecin est passée, payé sinon, sauté si pas les fonds.
	var j6_free: Array[EveningEvent] = EveningService.build_events(data.get_day(6).evening_events, _flags({"sc09_doctor_passed": true}), economy)
	assert_eq(EveningService.default_choices(j6_free, 0)[&"d06_bioscan"], &"free")
	var j6: Array[EveningEvent] = EveningService.build_events(data.get_day(6).evening_events, {}, economy)
	assert_eq(EveningService.default_choices(j6, 30)[&"d06_bioscan"], &"pay")
	assert_eq(EveningService.default_choices(j6, 10)[&"d06_bioscan"], &"skip")
	var report: EveningReport = EveningService.apply(economy, 6, Household.new(), EveningService.build_lines(economy, 6, Household.new()),
			100, 1, j6, {&"d06_bioscan": &"skip"}, {})
	assert_eq(report.household.get_member(Household.NOA).health, Household.Health.SICK, "bio-scan sauté : Noa malade")
	assert_eq(report.flag_changes[&"noa_bioscan_skipped"], true)


func test_audit_outcomes_and_arrest_ends_the_evening() -> void:
	assert_eq(EndingService.audit_outcome(_flags({"suspicion": 4}), economy)["ending"], EndingService.F1_ARRESTED)
	assert_eq(EndingService.audit_outcome(_flags({"suspicion": 4, "inspector_test_passed": true}), economy)["result"],
			EndingService.AUDIT_RETENTION, "test réussi : −1")
	var retention: Dictionary = EndingService.audit_outcome(_flags({"suspicion": 2, "inspector_bribe_taken": true}), economy)
	assert_eq(retention["cost"], 60, "retenue + confiscation")
	assert_eq(EndingService.audit_outcome(_flags({"suspicion": 1}), economy)["result"], EndingService.AUDIT_CLEAN)
	var flags: Dictionary[StringName, Variant] = _flags({"suspicion": 5, "drift_offer": true})
	var events: Array[EveningEvent] = EveningService.build_events(data.get_day(9).evening_events, flags, economy)
	assert_eq(events.size(), 4, "audit, aveu, déposition, laissez-passer")
	var report: EveningReport = EveningService.apply(economy, 9, Household.new(), EveningService.build_lines(economy, 9, Household.new()),
			100, 1, events, EveningService.default_choices(events, 100), flags)
	assert_eq(report.ending, EndingService.F1_ARRESTED)
	assert_false(report.flag_changes.has(&"ilan_confessed"), "la soirée s'arrête à l'arrestation")


func test_ilan_denounced_is_detained_with_bonus() -> void:
	var events: Array[EveningEvent] = EveningService.build_events(data.get_day(9).evening_events, {}, economy)
	var choices: Dictionary[StringName, StringName] = EveningService.default_choices(events, 100)
	assert_eq(choices[&"d09_ilan"], &"forbid", "jamais de dénonciation par défaut")
	assert_eq(choices[&"d09_okonkwo"], &"refuse")
	choices[&"d09_ilan"] = &"denounce"
	var report: EveningReport = EveningService.apply(economy, 9, Household.new(), EveningService.build_lines(economy, 9, Household.new()),
			100, 1, events, choices, {})
	assert_eq(report.gained, 20)
	assert_true(report.household.get_member(Household.ILAN).detained)
	assert_eq(report.flag_changes[&"loyalty"], 3)
	assert_eq(report.flag_changes[&"lucioles_trust"], -3)
	assert_eq(report.flag_changes[&"ilan_confessed"], true)


func test_lucioles_hostile_is_derived_from_day_seven() -> void:
	var lines: Array[ExpenseLine] = EveningService.build_lines(economy, 7, Household.new())
	var hostile: EveningReport = EveningService.apply(economy, 7, Household.new(), lines, 100, 1, [], {}, _flags({"lucioles_trust": -2}))
	assert_eq(hostile.flag_changes.get(&"lucioles_hostile", false), true)
	var early: EveningReport = EveningService.apply(economy, 6, Household.new(), EveningService.build_lines(economy, 6, Household.new()),
			100, 1, [], {}, _flags({"lucioles_trust": -3}))
	assert_false(early.flag_changes.has(&"lucioles_hostile"))
	var sabotage: Array[EveningEvent] = EveningService.build_events(data.get_day(8).evening_events, _flags({"lucioles_hostile": true}), economy)
	var j8: Array[ExpenseLine] = EveningService.build_lines(economy, 8, Household.new())
	EveningService.apply_line_costs(j8, sabotage, {})
	for line: ExpenseLine in j8:
		if line.id == &"heating":
			assert_eq(line.cost, 12, "recycleur saboté : chauffage +6 ₵")
		if line.id == &"air_tax":
			assert_eq(line.cost, economy.air_tax_for(8))


# --- Fins ---------------------------------------------------------------------

func test_final_endings_follow_narrative_conditions() -> void:
	var home: Household = Household.new()
	var cases: Array[Array] = [
		[{"lucioles_trust": 3, "loyalty": 3, "final_detained": true}, 100, 1.0, EndingService.F1_ARRESTED],
		[{"final_passed": true, "lucioles_trust": 4}, 0, 0.5, EndingService.F5_AIR],
		[{"final_passed": true, "lucioles_trust": 3}, 0, 0.5, EndingService.F7_REOPENS],
		[{"drift_passes_bought": true, "final_denied": true}, 30, 0.5, EndingService.F6_DRIFT],
		[{"drift_passes_bought": true, "final_denied": true}, 29, 0.5, EndingService.F7_REOPENS],
		[{"drift_passes_bought": true, "final_detained": true, "loyalty": 3}, 100, 0.9, EndingService.F4_GLORY],
		[{"final_detained": true, "loyalty": 3}, 0, 0.85, EndingService.F4_GLORY],
		[{"final_detained": true, "loyalty": 3}, 0, 0.84, EndingService.F7_REOPENS],
		[{"final_detained": true, "loyalty": 2}, 0, 1.0, EndingService.F7_REOPENS],
		[{"final_unprocessed": true}, 0, 1.0, EndingService.F7_REOPENS],
		[{"final_passed": true, "lucioles_trust": 4, "drift_passes_bought": true}, 100, 1.0, EndingService.F5_AIR],
	]
	for row: Array in cases:
		var values: Dictionary = row[0]
		var credits: int = row[1]
		var compliance: float = row[2]
		var expected: StringName = row[3]
		assert_eq(EndingService.evaluate_final(_flags(values), home, credits, compliance, economy), expected, str(values))
	var lost: Household = Household.new()
	for member: Household.Member in lost.members:
		member.health = Household.Health.LOST
	assert_eq(EndingService.evaluate_final(_flags({"final_passed": true, "lucioles_trust": 9}), lost, 0, 1.0, economy),
			EndingService.F3_FAMILY_LOST)
	var one_left: Household = Household.new()
	one_left.get_member(Household.ILAN).health = Household.Health.LOST
	one_left.get_member(Household.DORA).health = Household.Health.LOST
	assert_eq(EndingService.evaluate_final(_flags({"final_detained": true, "loyalty": 5}), one_left, 0, 1.0, economy),
			EndingService.F7_REOPENS, "F4 exige deux proches")


func test_epilogues_use_conditional_lines() -> void:
	var f4: PackedStringArray = _lines_of(EndingService.F4_GLORY, {"ilan_denounced": true, "sc11_veteran_passed": true})
	assert_true(f4.has("end_f4_l3_ilan"))
	assert_true(f4.has("end_f4_l5_mazur"))
	assert_true(f4.has("end_f4_l4_okonkwo"))
	assert_eq(EndingService.epilogue(EndingService.F4_GLORY, {}, Household.new())["title_key"], "end_f4_title")
	assert_eq(EndingService.epilogue(EndingService.F5_AIR, _flags({"brulants_package": true}), Household.new())["variant"], "brulants")
	assert_eq(_lines_of(EndingService.F5_AIR, {"brulants_package": true})[0], "end_f5b_l1")
	assert_true(_lines_of(EndingService.F1_ARRESTED, {"audit_arrested": true}).has("end_f1_l3_audit"))
	assert_eq(_lines_of(EndingService.F7_REOPENS, {"final_denied": true})[1], "end_f7_l2_denied")
	for ending: StringName in EndingService.ALL_ENDINGS:
		var epilogue: Dictionary = EndingService.epilogue(ending, {}, Household.new())
		var title: String = epilogue["title_key"]
		assert_true(UiText.has(title), "%s : titre traduit" % ending)
		for key: String in _lines_of(ending, {}):
			assert_true(UiText.has(key), "%s : %s traduite" % [ending, key])


func _lines_of(ending: StringName, values: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = EndingService.epilogue(ending, _flags(values), Household.new())["lines"]
	return lines
