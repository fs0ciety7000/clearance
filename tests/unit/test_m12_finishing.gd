## M12 lot A2 — finitions d'intégration (ARCHITECTURE §11) : pseudo-drapeaux
## du J31 (`epi_ending_<clé>`, foyer `hh_*`), listes renouvelées republiées
## après `on_rules_changed` (avis, révocations, `rule_list_published`), règle
## remplacée par un cas scénarisé (SC-89a) suivie par le RuleSet du shift.
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")
const DayHarness := preload("res://tests/helpers/day_harness.gd")

var _saved_state: Dictionary = {}


func before_all() -> void:
	_saved_state = GameState.to_save_dict()


func after_each() -> void:
	GameState.apply_save_dict(_saved_state)


func _flags(values: Dictionary) -> Dictionary[StringName, Variant]:
	var flags: Dictionary[StringName, Variant] = {}
	for key: Variant in values:
		flags[StringName(str(key))] = values[key]
	return flags


# --- 1, 2 : matin du J31 ---------------------------------------------------------

func test_morning_flags_carry_ending_and_household_pseudo_flags() -> void:
	var home: Household = Household.new()
	home.detain_member(Household.DORA)
	home.get_member(Household.ILAN).health = Household.Health.LOST
	var flags: Dictionary[StringName, Variant] = _flags({"act2_started": true, "act3_started": true})
	var epi: Dictionary = EpilogueService.make_seed(EndingService.F7_REOPENS, flags, home, {}, 99, 30)
	assert_false((epi["flags"] as Dictionary).has("epi_ending_f7"), "jamais dans la graine (recalculé)")
	var restored: Dictionary = EpilogueService.sanitize_seed(JSON.parse_string(JSON.stringify(epi)))
	var morning: Dictionary[StringName, Variant] = EpilogueService.morning_flags(restored)
	assert_true(FlagCondition.is_flag_true(morning, &"epi_ending_f7"), "fin du J31 : epi_ending_f7")
	assert_false(morning.has(&"epi_ending_f1"))
	assert_true(FlagCondition.is_flag_true(morning, &"hh_noa_present"))
	assert_true(FlagCondition.is_flag_true(morning, &"hh_dora_alive"))
	assert_true(FlagCondition.is_flag_true(morning, &"hh_dora_held"))
	assert_false(FlagCondition.is_flag_true(morning, &"hh_dora_present"))
	assert_false(FlagCondition.is_flag_true(morning, &"hh_ilan_alive"), "Ilan perdu")
	assert_eq(FlagCondition.gauge_value(morning, &"hh_alive"), 2)
	assert_eq(EpilogueService.ending_flag(&"f10"), &"epi_ending_f10")
	assert_eq(EpilogueService.ending_flag(&""), &"")
	# Un vrai drapeau de même nom l'emporte.
	var forced: Dictionary = restored.duplicate(true)
	(forced["flags"] as Dictionary)["hh_noa_present"] = false
	assert_false(FlagCondition.is_flag_true(EpilogueService.morning_flags(forced), &"hh_noa_present"))
	# Session d'épilogue : drapeaux du matin dans le `GameState`.
	GameState.begin_epilogue(restored)
	assert_true(GameState.get_true_flags().has(&"epi_ending_f7"))
	assert_true(GameState.get_true_flags().has(&"hh_dora_held"))
	GameState.end_session()


## Vraies données (monde A) : SC-93c (Ilan, `hh_ilan_alive`) au @6 seulement
## si Ilan est vivant ; message du foyer « parti » (`epi_ending_f1`) au briefing.
func test_real_j31_reads_household_and_ending_pseudo_flags() -> void:
	var def: EpilogueDef = EpilogueService.load_def()
	if def == null or def.get_world(EpilogueService.WORLD_A) == null:
		pending("données d'épilogue absentes")
		return
	var data: DataCatalog = CaseFactory.catalog()
	var flags: Dictionary[StringName, Variant] = _flags({"act2_started": true, "act3_started": true})
	var ids: Dictionary[bool, StringName] = {}
	for alive: bool in [true, false]:
		var home: Household = Household.new()
		if not alive:
			home.get_member(Household.ILAN).health = Household.Health.LOST
		var epi: Dictionary = EpilogueService.make_seed(EndingService.F7_REOPENS, flags, home, {}, 4321, 30)
		var day: DayDef = Campaign.start_epilogue(epi)
		assert_not_null(day)
		var dc: DayController = autofree(DayController.new())
		add_child(dc)
		dc.set_process(false)
		assert_true(dc.start_epilogue(data, day, EpilogueService.day_seed(epi), GameState.get_true_flags(), {}))
		assert_true(FlagCondition.is_flag_true(dc.builder.get_flag_values(), &"epi_ending_f7"), "générateur : fin")
		var scripted: ScriptedCaseDef = dc.builder.get_scripted_case(6)
		ids[alive] = scripted.id if scripted != null else &""
		GameState.end_session()
	assert_eq(ids[true], &"sc_93c", "Ilan vivant : SC-93c")
	assert_ne(ids[false], &"sc_93c", "Ilan perdu : pas de SC-93c")
	# Briefing : condition `epi_ending_f1` (monde A, F1).
	var arrested: Dictionary = EpilogueService.make_seed(EndingService.F1_ARRESTED,
			_flags({"act2_started": true, "act3_started": true}), Household.new(), {}, 1, 30)
	if arrested.is_empty():
		return
	var morning: Dictionary[StringName, Variant] = EpilogueService.morning_flags(arrested)
	var world_day: DayDef = EpilogueService.day_for(arrested)
	var away: bool = false
	for message: BriefingMessageDef in world_day.briefing_messages:
		if message.text_key == "msg_foyer_day31_away":
			away = FlagCondition.check(message.condition, morning)
	assert_true(away, "F1 : message du foyer « parti » au J31")


# --- 3 : listes republiées ---------------------------------------------------------

func _harness(day_number: int, flags: Array[StringName] = []) -> DayHarness:
	var h: DayHarness = DayHarness.new()
	h.setup(self, null, day_number, 0, 0, flags)
	h.controller.station_events.clear()
	h.controller.close_intro()
	return h


func _play_one(dc: DayController) -> void:
	EventBus.next_case_requested.emit()
	var c: Case = dc.current_case
	if c == null:
		return
	EventBus.passenger_arrived.emit(c.case_id)
	EventBus.verdict_stamped.emit(Verdict.new(c.case_id, dc.current_key.expected_verdict))
	EventBus.passenger_departed.emit(c.case_id)


func test_stolen_list_is_published_after_rules_change() -> void:
	var data: DataCatalog = CaseFactory.catalog()
	var event: StationEventDef = data.events.get(&"ev_07", null)
	if event == null:
		pending("EV-07 absent des données")
		return
	var h: DayHarness = _harness(14)
	var dc: DayController = h.controller
	var plan: StationEventPlan = StationEventService.place(event, dc.day, SeededRng.new(5))
	assert_not_null(plan)
	dc.station_events = [plan] as Array[StationEventPlan]
	var published: Array[Array] = []
	var on_list: Callable = func(label: StringName, entries: Array[RevokedEntry]) -> void:
		published.append([label, entries.size()])
	EventBus.rule_list_published.connect(on_list)
	for i: int in plan.announce_after:
		_play_one(dc)
	assert_eq(published.size(), 0, "rien avant l'effet")
	EventBus.next_case_requested.emit()
	assert_eq(published.size(), 1, "liste publiée avec la règle (avant le passager suivant)")
	if not published.is_empty():
		assert_eq(published[0][0], &"stolen")
		assert_eq(published[0][1], event.list_size, "bulletin de %d N° ID" % event.list_size)
	assert_eq(dc.builder.changed_lists.size(), 0, "listes consommées")
	EventBus.rule_list_published.disconnect(on_list)
	h.teardown()


func test_changed_lists_map_to_their_signals() -> void:
	var h: DayHarness = _harness(12)
	var dc: DayController = h.controller
	var seen: Array[String] = []
	var on_wanted: Callable = func(_n: Array[WantedNotice]) -> void: seen.append("wanted")
	var on_revoked: Callable = func(_e: Array[RevokedEntry]) -> void: seen.append("revoked")
	var on_list: Callable = func(label: StringName, _e: Array[RevokedEntry]) -> void: seen.append("list:%s" % label)
	EventBus.wanted_notices_published.connect(on_wanted)
	EventBus.revocations_published.connect(on_revoked)
	EventBus.rule_list_published.connect(on_list)
	dc.call(&"_publish_changed_lists", PackedStringArray(["wanted", "revoked", "stolen", "wanted"]))
	assert_eq(seen, ["wanted", "revoked", "list:stolen"] as Array[String], "une fois chacune, dans l'ordre")
	EventBus.wanted_notices_published.disconnect(on_wanted)
	EventBus.revocations_published.disconnect(on_revoked)
	EventBus.rule_list_published.disconnect(on_list)
	h.teardown()


# --- 4 : règle remplacée par un cas scénarisé (SC-89a) ---------------------------

func test_scripted_rule_replacement_is_the_shift_rule_set() -> void:
	var data: DataCatalog = CaseFactory.catalog()
	var source: DayDef = data.get_day(13)
	var has_sc89a: bool = false
	for scripted: ScriptedCaseDef in source.scripted_cases:
		has_sc89a = has_sc89a or (scripted != null and scripted.id == &"sc_89a")
	if not has_sc89a or not source.rule_set.has_rule(&"r_drift_pass"):
		pending("SC-89a absent des données")
		return
	var original: Rule = source.rule_set.get_rule(&"r_drift_pass")
	var rank: int = source.rule_set.get_rule_ids().find(&"r_drift_pass")
	GameState.set_flag(&"sc18_note_reported", true)
	var h: DayHarness = _harness(13, [&"sc18_note_reported"] as Array[StringName])
	var dc: DayController = h.controller
	assert_not_null(dc.builder.get_scripted_case(11), "SC-89a actif")
	assert_same(dc.day, dc.builder.day, "même jour de shift")
	assert_same(dc.day.rule_set, dc.builder.ctx.rule_set, "même RuleSet (moteur et contrôleur)")
	var replaced: DriftPassRule = dc.day.rule_set.get_rule(&"r_drift_pass") as DriftPassRule
	assert_not_null(replaced)
	assert_ne(replaced, original, "variante du cas")
	assert_true(replaced.retired_vessels.has("LONG-RUBAN"), "Long-Ruban retiré du registre")
	assert_eq(dc.day.rule_set.get_rule_ids().find(&"r_drift_pass"), rank, "au même rang du Rulebook")
	assert_eq(dc.day.rule_set.build_retired_entries().size(), source.rule_set.build_retired_entries().size(),
			"aucune ligne barrée")
	assert_false(dc.day.rule_set.new_rule_ids.has(&"r_drift_pass"), "sans badge NOUVEAU")
	assert_same(source.rule_set.get_rule(&"r_drift_pass"), original, "données intactes")
	# Une mutation en cours de shift garde la variante (retrait puis rétablissement).
	dc.builder.ctx.apply_changes([RuleChangeDef.retire(&"r_drift_pass")] as Array[RuleChangeDef], &"test")
	dc.builder.ctx.revert_source(&"test")
	assert_same(dc.day.rule_set.get_rule(&"r_drift_pass"), replaced, "rétablie : toujours la variante")
	h.teardown()


# --- Besoins d'API du lot C ------------------------------------------------------

func test_capture_arguments_are_one_shot() -> void:
	for key: String in ["garde", "epilogue", "skip-cases", "wrong-cases", "hold-card", "call-next", "station-event"]:
		assert_true(DebugArgs.ONE_SHOT.has(key), "--%s : une seule fois par processus" % key)
	var later: Dictionary = DebugArgs.filter(DebugArgs.parse(PackedStringArray(["--garde=K2Q9TX", "--skip-cases=3",
			"--autoplay"])), true)
	assert_false(later.has("garde"))
	assert_false(later.has("skip-cases"))
	assert_true(later.has("autoplay"), "les modes restent")


func test_garde_record_has_clock_and_error_references() -> void:
	if GardeService.load_def() == null:
		pending("données de Garde absentes")
		return
	var run: GardeRun = GardeService.new_run(GardeService.code_from_bits(42))
	assert_not_null(run)
	var result: CaseResult = CaseResult.new()
	result.case_id = &"garde_000"
	result.citation_reason_key = "cit_missed_violation"
	result.citation_rule_id = &"r_id_valid"
	var refs: Array[FieldRef] = [FieldRef.new(&"id_card", &"expiry_date"), FieldRef.rulebook_rule(&"r_id_valid")]
	result.missed_violations = [Violation.new(&"r_id_valid", refs, "viol_expired")] as Array[Violation]
	run.after_case(result)
	var record: Dictionary = run.to_record()
	assert_eq(int(record["clock_minute"]), run.clock_minute(), "heure cosmétique de la garde")
	var errors: Array = record["errors"]
	assert_eq(errors.size(), 1)
	var violations: Array = (errors[0] as Dictionary)["violations"]
	assert_eq(violations.size(), 1)
	assert_eq(violations[0]["rule_id"], "r_id_valid")
	assert_eq(violations[0]["reason_key"], "viol_expired")
	assert_true((violations[0]["refs"] as Array).has("id_card.expiry_date"), "document en cause")
	# Sans violation manquée : toutes les violations du cas.
	var other: CaseResult = CaseResult.new()
	other.expected_violations = [Violation.new(&"r_x", [] as Array[FieldRef], "viol_x")] as Array[Violation]
	assert_eq(GardeRun.violation_refs(other).size(), 1)


func test_rulebook_entry_exposes_named_list() -> void:
	var rule: RevokedIdRule = RevokedIdRule.new()
	rule.id = &"r_ev_stolen_ids"
	rule.list_label = &"stolen"
	rule.list_title_key = "rb_tab_stolen"
	var entry: RulebookEntry = rule.get_rulebook_entry()
	assert_eq(entry.list_label, &"stolen")
	assert_eq(entry.list_title_key, "rb_tab_stolen")
	assert_eq(entry.rule_id, &"r_ev_stolen_ids")
	assert_eq(RevokedIdRule.new().get_rulebook_entry().list_label, &"", "onglet Révocations : vide")


func test_test_storage_is_unique_per_process() -> void:
	var own: String = "user://test_runs/%d" % OS.get_process_id()
	assert_true(Settings.settings_path.begins_with(own), Settings.settings_path)
	assert_true(SaveService.resolve_dir(SaveService.DEFAULT_DIR).begins_with(own), "sauvegardes de ce processus")
