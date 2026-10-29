## M12 lot A — épilogue J31 (B52, B53, D-122 → D-125, ARCHITECTURE §11.4) :
## variantes, clés et mondes ; graine (liste blanche, mémoire) ; écriture de
## `day_31.json` à la fin de l'Acte III ; J31 joué depuis la graine **sans
## modifier la partie terminée** ; conclusion composée ; profil.
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")
const DIR: String = "user://test_m12_epilogue"


func before_each() -> void:
	_clear()


var _saved_state: Dictionary = {}
var _saved_slot: int = SaveService.DEFAULT_SLOT


func before_all() -> void:
	_saved_state = GameState.to_save_dict()
	_saved_slot = GameState.active_slot


## L'autoload retrouve exactement son état d'avant la suite.
func after_each() -> void:
	GameState.apply_save_dict(_saved_state)
	GameState.active_slot = _saved_slot


func after_all() -> void:
	_clear()
	DirAccess.remove_absolute(DIR)


func _clear() -> void:
	for slot: int in range(0, SaveService.SLOT_COUNT + 1):
		SaveService.delete_slot(slot, DIR)
	for name: String in [ProfileService.FILE_NAME, ProfileService.V1_BACKUP_FILE]:
		SaveService.remove_with_fallbacks(DIR.path_join(name))


func _flags(pairs: Dictionary) -> Dictionary[StringName, Variant]:
	var flags: Dictionary[StringName, Variant] = {}
	for key: Variant in pairs:
		flags[StringName(str(key))] = pairs[key]
	return flags


func test_variants_keys_and_worlds() -> void:
	var act3: Dictionary = {"act2_started": true, "act3_started": true}
	var cases: Array = [
		[EndingService.F1_ARRESTED, {"deposition_arrested": true}, &"deposition", &"f1", &"a"],
		[EndingService.F1_ARRESTED, {}, &"double", &"f1", &"a"],
		[EndingService.F3_FAMILY_LOST, {}, &"", &"f3", &"a"],
		[EndingService.F4_GLORY, {}, &"", &"f4", &"a"],
		[EndingService.F7_REOPENS, {}, &"", &"f7", &"a"],
		[EndingService.F5_AIR, {"vanne2_brulants": true}, &"b", &"f5b", &"a"],
		[EndingService.F5_AIR, {"climate_vanne": true}, &"c", &"f5c", &"b"],
		[EndingService.F5_AIR, {}, &"s", &"f5s", &"b"],
		[EndingService.F9_STRIKE, {}, &"", &"f9", &"b"],
		[EndingService.F8_REGISTRE, {}, &"", &"f8", &"c"],
		[EndingService.F10_PONT, {}, &"", &"f10", &"c"],
		[EndingService.F2_REASSIGNED, {}, &"", &"f2", &"d"],
		[EndingService.F6_DRIFT, {}, &"t", &"f6t", &"d"],
		[EndingService.F6_DRIFT, {"exit3_drift": true}, &"d", &"f6d", &"d"],
	]
	var keys: Dictionary[StringName, bool] = {}
	for row: Array in cases:
		var pairs: Dictionary = act3.duplicate()
		pairs.merge(row[1])
		var flags: Dictionary[StringName, Variant] = _flags(pairs)
		var ending: StringName = row[0]
		assert_eq(EpilogueService.variant_of(ending, flags), row[2], "%s %s : variante" % [ending, row[1]])
		assert_eq(EpilogueService.ending_key(ending, row[2]), row[3])
		assert_true(EpilogueService.is_eligible(ending, flags))
		assert_eq(EpilogueService.world_of(ending, flags, EpilogueDef.new()), row[4], "monde de %s" % row[3])
		keys[row[3]] = true
	assert_eq(keys.size(), 13, "13 clés de variante (D-124)")
	# Actes I et II : pas de J31 (D-122).
	assert_false(EpilogueService.is_eligible(EndingService.F7_REOPENS, _flags({"act2_started": true})), "fin du J20")
	assert_eq(EpilogueService.world_of(EndingService.F2_REASSIGNED, _flags({})), &"")
	assert_eq(EpilogueService.variant_of(EndingService.F6_DRIFT, _flags({})), &"j10")
	assert_eq(EpilogueService.variant_of(EndingService.F6_DRIFT, _flags({"act2_started": true})), &"j20")
	assert_eq(EpilogueService.variant_of(EndingService.F1_ARRESTED, _flags({"audit_arrested": true})), &"audit")
	assert_eq(EpilogueService.variant_of(EndingService.F1_ARRESTED, _flags({"act2_started": true, "review_arrested": true})), &"review")
	assert_eq(EpilogueService.ending_key(EndingService.F6_DRIFT, &"j20"), &"", "F6 du J20 : pas d'épilogue")
	assert_false(EpilogueService.is_eligible(&"demo_complete", _flags(act3)))
	# Les données l'emportent sur la table.
	var def: EpilogueDef = EpilogueDef.new()
	var ending_def: EpilogueEndingDef = EpilogueEndingDef.new()
	ending_def.key = &"f3"
	ending_def.world = &"b"
	def.endings = [ending_def]
	assert_eq(EpilogueService.world_of(EndingService.F3_FAMILY_LOST, _flags(act3), def), &"b")


func test_seed_keeps_whitelist_household_and_memory() -> void:
	var def: EpilogueDef = EpilogueDef.new()
	def.read_flags = [&"final3_dora", &"sc54_sato_reinstated"]
	var flags: Dictionary[StringName, Variant] = _flags({"act3_started": true, "final3_dora": true,
			"sc54_sato_reinstated": true, "loyalty": 4, "climate_vanne": true})
	var home: Household = Household.new()
	home.detain_member(Household.DORA)
	var memory: Dictionary = {"sc_04": {"day": 3, "given_name": "Mira"}, "sc_10": {"day": 5},
			"tuto_concordant": {"day": 1, "verdict": "approve"}}
	var epi: Dictionary = EpilogueService.make_seed(EndingService.F5_AIR, flags, home, memory, 4242, 30, def)
	assert_eq(epi["ending"], "f5_air")
	assert_eq(epi["variant"], "c")
	assert_eq(epi["ending_key"], "f5c")
	assert_eq(epi["world"], "b")
	assert_eq(epi["campaign_seed"], 4242)
	assert_eq((epi["flags"] as Dictionary).keys().size(), 3, "liste blanche + act3_started")
	assert_false((epi["flags"] as Dictionary).has("loyalty"))
	assert_eq((epi["memory"] as Dictionary).keys().size(), 2, "tuto_concordant et sc_04 seulement")
	var restored: Dictionary = EpilogueService.sanitize_seed(JSON.parse_string(JSON.stringify(epi)))
	assert_eq(restored["campaign_seed"], 4242, "aller-retour JSON")
	assert_true(EpilogueService.household_of(restored).get_member(Household.DORA).detained)
	var morning: Dictionary[StringName, Variant] = EpilogueService.morning_flags(restored)
	assert_true(FlagCondition.is_flag_true(morning, &"act3_started"))
	assert_true(FlagCondition.is_flag_true(morning, &"final3_dora"))
	assert_eq(EpilogueService.day_seed(restored), SeededRng.day_seed(4242, 31))
	assert_eq(EpilogueService.profile_key(restored), "f5_air:c")
	assert_true(EpilogueService.make_seed(EndingService.F5_AIR, _flags({}), home, memory, 1, 9).is_empty(), "Acte I : pas de graine")
	assert_true(EpilogueService.sanitize_seed({"ending": "f9_strike"}).is_empty(), "sans monde : invalide")


func _line_group(entries: Array) -> EpilogueLineGroupDef:
	var group: EpilogueLineGroupDef = EpilogueLineGroupDef.new()
	for entry: Array in entries:
		var condition: FlagCondition = null
		if entry[1] != &"":
			condition = FlagCondition.make([entry[1]] as Array[StringName])
		group.lines.append(ConditionalKey.make(entry[0], condition))
	return group


## Données d'épilogue de test : monde C sur le J30 réel (7 passagers).
func _def() -> EpilogueDef:
	var def: EpilogueDef = EpilogueDef.new()
	var day: DayDef = CaseFactory.catalog().get_day(30).duplicate() as DayDef
	day.day_number = 31
	day.mode = DayDef.MODE_EPILOGUE
	day.epilogue_world = &"c"
	day.passenger_count = 7
	day.scripted_cases = []
	day.wanted_notices = []
	day.revocations = []
	day.announcements = []
	day.sponsor_links = {}
	day.slot_groups = {}
	day.summons = []
	day.economy_disabled = true
	day.untimed = true
	day.has_evening = false
	day.game_date = GameDate.from_ymd(2188, 4, 11)
	var world: EpilogueWorldDef = EpilogueWorldDef.new()
	world.id = &"c"
	world.day_def = day
	world.eyebrow_key = "epi_eyebrow_c"
	world.line_groups = [
		_line_group([["epi_c_lindgren_signed", &"sc97_form_signed"], ["epi_c_lindgren_passed", &""]]),
		_line_group([["epi_c_okafor_chain", &"sc99_elena_passed"]]),
		_line_group([["epi_c_fig_passed", &"never_set"], ["epi_c_fig_refused", &"never_set_either"]]),
		_line_group([["epi_c_extra_1", &""]]),
		_line_group([["epi_c_extra_2", &""]]),
		_line_group([["epi_c_extra_3", &""]]),
	]
	world.farewell_lines = [ConditionalKey.make("sc100_mira_tessar", FlagCondition.make([&"sc100_figure_passed"] as Array[StringName]))]
	def.worlds = [world]
	var f10: EpilogueEndingDef = EpilogueEndingDef.new()
	f10.key = &"f10"
	f10.world = &"c"
	f10.open_key = "epi_f10_open"
	f10.close_key = "epi_f10_close"
	f10.open_gauge = &"pont31"
	f10.intro_key = "day31_c_intro_f10"
	var f8: EpilogueEndingDef = EpilogueEndingDef.new()
	f8.key = &"f8"
	f8.world = &"c"
	f8.open_key = "epi_f8_open"
	f8.close_key = "epi_f8_close"
	f8.no_home_line = true
	def.endings = [f10, f8]
	def.first_lines = [ConditionalKey.make("epi_first_passed", FlagCondition.make([&"sc90_first_passed"] as Array[StringName])),
		ConditionalKey.make("epi_first_refused")]
	def.home_lines = [ConditionalKey.make("epi_home_noa")]
	def.read_flags = [&"final3_dora"]
	return def


func test_conclusion_order_truncation_args_and_farewell() -> void:
	var def: EpilogueDef = _def()
	var epi: Dictionary = EpilogueService.make_seed(EndingService.F10_PONT, _flags({"act3_started": true}), Household.new(), {}, 5, 30, def)
	var flags: Dictionary[StringName, Variant] = EpilogueService.morning_flags(epi)
	flags[&"sc90_first_passed"] = true
	flags[&"sc99_elena_passed"] = true
	flags[&"sc100_figure_passed"] = true
	flags[&"pont31"] = 4
	var card: Dictionary = EpilogueService.conclusion(epi, flags, 2, def)
	var lines: PackedStringArray = card["lines"]
	assert_eq(lines[0], "epi_f10_open", "ouverture d'abord")
	assert_eq(lines[1], "epi_first_passed", "puis SC-90")
	assert_eq(lines[2], "epi_c_lindgren_passed", "repli du groupe Lindgren")
	assert_eq(lines[3], "epi_c_okafor_chain")
	assert_false(lines.has("epi_c_fig_passed"), "groupe sans ligne vraie : omis")
	assert_eq(lines[lines.size() - 2], "epi_home_noa", "foyer avant la clôture")
	assert_eq(lines[lines.size() - 1], "epi_f10_close", "clôture à la fin")
	assert_lte(lines.size(), def.max_lines, "au plus 8 lignes")
	assert_false(lines.has("epi_c_extra_3"), "les dernières lignes de monde sautent d'abord")
	assert_eq(card["args"]["epi_f10_open"], [4], "%d de F10 : jauge pont31")
	assert_eq(card["tally_args"], [2])
	assert_eq(card["farewell_key"], "sc100_mira_tessar")
	assert_eq(card["eyebrow_key"], "epi_eyebrow_c")
	assert_eq(EpilogueService.intro_key(epi, def), "day31_c_intro_f10")
	var f8: Dictionary = EpilogueService.make_seed(EndingService.F8_REGISTRE, _flags({"act3_started": true}), Household.new(), {}, 5, 30, def)
	var plain: PackedStringArray = EpilogueService.conclusion(f8, EpilogueService.morning_flags(f8), 0, def)["lines"]
	assert_false(plain.has("epi_home_noa"), "pas de ligne du foyer pour cette variante")
	assert_eq(plain[1], "epi_first_refused")


## Partie de l'Acte III sauvegardée au soir du J29, matin du J30.
func _act3_game(slot: int) -> void:
	GameState.new_campaign(777, slot)
	GameState.current_day = 29
	GameState.set_flag(EndingService.FLAG_ACT2, true)
	GameState.set_flag(EndingService.FLAG_ACT3, true)
	GameState.remember_case(&"sc_04", {"day": 3, "verdict": "approve", "given_name": "Mira"})
	GameState.record_day_entry({"processed": 10, "correct": 9})
	assert_eq(GameState.save_to_slot(SaveService.NO_SLOT, DIR), OK)


func test_end_of_act_three_writes_seed_and_epilogue_never_touches_the_game() -> void:
	_act3_game(2)
	GameState.record_day_entry({"processed": 12, "correct": 12})
	GameState.end_campaign(EndingService.F10_PONT, SaveService.NO_SLOT, DIR)
	GameState.end_campaign(EndingService.F10_PONT, SaveService.NO_SLOT, DIR)
	var meta: Dictionary = SaveService.load_meta(2, DIR)
	assert_eq(meta["status"], SaveService.STATUS_ENDED)
	assert_true(meta.get(SaveService.KEY_EPILOGUE_AVAILABLE, false), "méta : épilogue disponible")
	assert_true(FileAccess.file_exists(SaveService.snapshot_path(2, 31, DIR)), "day_31.json")
	assert_false(SaveService.list_snapshots(2, DIR).has(31), "jamais dans la grille des jours")
	assert_true(SaveService.load_snapshot(2, 31, DIR).is_empty(), "jamais chargé comme état")
	var epi: Dictionary = Campaign.epilogue_seed_for_slot(2, DIR)
	assert_eq(epi["ending_key"], "f10")
	assert_eq(epi["campaign_seed"], 777)
	var profile: Dictionary = ProfileService.load_profile(DIR)
	assert_true(profile["epilogue_unlocked"])
	assert_true((profile["epilogues"] as Dictionary).has("f10_pont:"))
	assert_eq(ProfileService.ending_count(profile, "f10_pont"), 1, "comptée une fois (end_campaign idempotent)")
	assert_eq(profile["last_campaign"]["ending"], "f10_pont")
	assert_eq(profile["last_campaign"]["world"], "c")
	assert_eq(profile["max_day_reached"], 30)
	var current_before: String = FileAccess.get_file_as_string(SaveService.slot_path(2, DIR))
	# J31 depuis la graine de l'emplacement.
	var def: EpilogueDef = _def()
	var day: DayDef = Campaign.start_epilogue(epi, 2, def)
	assert_not_null(day)
	assert_eq(GameState.session_mode, GameState.SESSION_EPILOGUE)
	assert_eq(GameState.current_day, 31)
	assert_eq(GameState.credits, 0)
	var clock: DayClock = DayClock.new()
	var dc: DayController = DayController.new()
	dc.clock = clock
	add_child_autofree(clock)
	add_child_autofree(dc)
	clock.set_process(false)
	dc.set_process(false)
	var memory: Dictionary = CaseMemory.resolve(CaseFactory.catalog(), day, GameState.campaign_seed, GameState.case_memory)
	assert_true(dc.start_epilogue(CaseFactory.catalog(), day, EpilogueService.day_seed(epi), GameState.get_true_flags(), memory))
	assert_eq(dc.mode, DayDef.MODE_EPILOGUE)
	assert_true(clock.untimed, "sans chrono (D-123)")
	assert_true(dc.is_economy_disabled())
	var summaries: Array[DaySummary] = []
	var on_end: Callable = func(summary: DaySummary) -> void: summaries.append(summary)
	EventBus.day_ended.connect(on_end)
	dc.close_intro()
	clock.advance(day.duration_sec + 10.0)
	assert_eq(dc.phase, DayPhase.Kind.WAITING_CASE, "l'horloge ne termine pas le J31")
	for i: int in 7:
		EventBus.next_case_requested.emit()
		if dc.current_case != null:
			EventBus.passenger_arrived.emit(dc.current_case.case_id)
		var c: Case = dc.current_case
		EventBus.verdict_stamped.emit(Verdict.new(c.case_id, VerdictKind.Kind.DENY))
		EventBus.passenger_departed.emit(c.case_id)
	EventBus.day_ended.disconnect(on_end)
	assert_eq(summaries.size(), 1, "fin à la file vide")
	assert_eq(summaries[0].get_processed_count(), 7)
	assert_eq(summaries[0].get_fine_total(), 0, "aucune amende")
	assert_eq(summaries[0].get_wage_total(), 0, "aucun salaire")
	assert_eq(GameState.credits, 0)
	# Rien n'est jamais écrit dans l'emplacement.
	assert_eq(GameState.save_to_slot(SaveService.NO_SLOT, DIR), ERR_UNAVAILABLE)
	GameState.end_campaign(EndingService.F7_REOPENS, 2, DIR)
	var card: Dictionary = Campaign.close_epilogue(summaries[0], DIR, def)
	assert_eq(card["ending_key"], "f10")
	assert_eq(card["tally_args"], [summaries[0].get_citation_count()])
	assert_eq((card["lines"] as PackedStringArray)[0], "epi_f10_open")
	meta = SaveService.load_meta(2, DIR)
	assert_eq(meta["status"], SaveService.STATUS_ENDED, "la partie reste terminée")
	assert_eq(meta["ending_id"], "f10_pont", "fin inchangée")
	assert_true(meta.get(SaveService.KEY_EPILOGUE_DONE, false))
	assert_eq(FileAccess.get_file_as_string(SaveService.slot_path(2, DIR)), current_before, "current.json intact")
	profile = ProfileService.load_profile(DIR)
	var entry: Dictionary = profile["epilogues"]["f10_pont:"]
	assert_eq(entry["count"], 1, "J31 joué une fois")
	assert_eq(entry["last_lines"], Array(card["lines"]))
	assert_false(ProfileService.has_seen_ending(profile, "f7_reopens"), "aucune fin pendant l'épilogue")
	# Rejouable depuis le profil, même après suppression de l'emplacement.
	GameState.end_session()
	SaveService.delete_slot(2, DIR)
	var from_profile: Dictionary = Campaign.epilogue_seed_from_profile("f10_pont:", DIR)
	assert_eq(from_profile["ending_key"], "f10")
	assert_not_null(Campaign.start_epilogue(from_profile, SaveService.NO_SLOT, def))
	assert_eq(GameState.epilogue_slot, SaveService.NO_SLOT)


func test_resuming_an_earlier_day_drops_day_31() -> void:
	_act3_game(1)
	GameState.end_campaign(EndingService.F9_STRIKE, SaveService.NO_SLOT, DIR)
	assert_true(SaveService.has_epilogue(1, DIR))
	assert_true(GameState.load_day_snapshot(1, 30, DIR), "reprise du J30")
	assert_eq(GameState.save_to_slot(SaveService.NO_SLOT, DIR), OK)
	assert_false(SaveService.has_epilogue(1, DIR), "une seule ligne de temps : day_31.json supprimé")
	assert_false(SaveService.load_meta(1, DIR).get(SaveService.KEY_EPILOGUE_AVAILABLE, false))


func test_act_two_ending_has_no_epilogue() -> void:
	GameState.new_campaign(55, 3)
	GameState.current_day = 19
	GameState.set_flag(EndingService.FLAG_ACT2, true)
	GameState.record_day_entry({"processed": 3, "correct": 3})
	GameState.save_to_slot(SaveService.NO_SLOT, DIR)
	GameState.end_campaign(EndingService.F7_REOPENS, SaveService.NO_SLOT, DIR)
	assert_false(SaveService.has_epilogue(3, DIR))
	var profile: Dictionary = ProfileService.load_profile(DIR)
	assert_false(profile["epilogue_unlocked"])
	assert_eq(profile["endings_seen"][0]["act"], 2)
	assert_null(Campaign.start_epilogue({}, 3), "graine vide refusée")
	assert_eq(GameState.session_mode, GameState.SESSION_CAMPAIGN)
