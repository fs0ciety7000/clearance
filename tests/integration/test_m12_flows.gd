## M12 lot A — flux bout à bout sur les **vraies données** du lot B
## (`data/epilogue/`, `data/garde/`, `data/events/`) : J31 de chaque monde
## joué depuis une graine (fin à la file vide, conclusion composée, aucune
## économie), Garde de nuit réelle (directives, déterminisme), calendrier des
## événements. En attente (`pending`) tant que les données manquent.
extends GutTest

const DIR: String = "user://test_m12_flows"

var _saved_state: Dictionary = {}
var _saved_slot: int = SaveService.DEFAULT_SLOT
var _data: DataCatalog = null


func before_all() -> void:
	_saved_state = GameState.to_save_dict()
	_saved_slot = GameState.active_slot
	_data = DataCatalog.load_from()


func after_each() -> void:
	GameState.apply_save_dict(_saved_state)
	GameState.active_slot = _saved_slot


func after_all() -> void:
	SaveService.remove_with_fallbacks(DIR.path_join(ProfileService.FILE_NAME))
	DirAccess.remove_absolute(DIR)


## Joue au plus `count` passagers au verdict attendu (sans preuve épinglée).
func _play(dc: DayController, count: int) -> void:
	for i: int in count:
		if not dc.has_remaining_cases() or dc.phase == DayPhase.Kind.SUMMARY:
			return
		EventBus.next_case_requested.emit()
		var c: Case = dc.current_case
		assert_not_null(c, "passager %d construit" % i)
		if c == null:
			return
		EventBus.passenger_arrived.emit(c.case_id)
		EventBus.verdict_stamped.emit(Verdict.new(c.case_id, dc.current_key.expected_verdict))
		EventBus.passenger_departed.emit(c.case_id)


func _controller() -> DayController:
	var clock: DayClock = DayClock.new()
	var dc: DayController = DayController.new()
	dc.clock = clock
	add_child_autofree(clock)
	add_child_autofree(dc)
	clock.set_process(false)
	dc.set_process(false)
	return dc


func test_every_world_plays_from_a_seed_to_its_conclusion() -> void:
	var def: EpilogueDef = EpilogueService.load_def()
	if def == null or def.worlds.size() < 4:
		pending("données d'épilogue du lot B absentes")
		return
	var cases: Dictionary = {
		EndingService.F7_REOPENS: {}, EndingService.F9_STRIKE: {}, EndingService.F10_PONT: {},
		EndingService.F6_DRIFT: {"exit3_drift": true},
	}
	for ending: StringName in cases:
		var flags: Dictionary[StringName, Variant] = {&"act2_started": true, &"act3_started": true}
		for key: Variant in cases[ending]:
			flags[StringName(str(key))] = cases[ending][key]
		var epi: Dictionary = EpilogueService.make_seed(ending, flags, Household.new(), {}, 1234, 30)
		var day: DayDef = Campaign.start_epilogue(epi)
		assert_not_null(day, "%s : monde %s" % [ending, epi.get("world")])
		if day == null:
			continue
		assert_eq(day.day_number, 31)
		var credits: int = GameState.credits
		var dc: DayController = _controller()
		var memory: Dictionary = CaseMemory.resolve(_data, day, GameState.campaign_seed, GameState.case_memory)
		assert_true(dc.start_epilogue(_data, day, EpilogueService.day_seed(epi), GameState.get_true_flags(), memory))
		dc.close_intro()
		_play(dc, day.passenger_count + 2)
		assert_eq(dc.phase, DayPhase.Kind.SUMMARY, "%s : fin à la file vide" % ending)
		assert_eq(dc.summary.get_processed_count(), day.passenger_count)
		assert_eq(GameState.credits, credits, "aucune économie")
		var card: Dictionary = Campaign.close_epilogue(dc.summary, DIR)
		assert_gt((card["lines"] as PackedStringArray).size(), 0, "%s : conclusion composée" % ending)
		assert_eq(card["world"], epi["world"])
		GameState.end_session()


func test_real_garde_runs_and_is_deterministic() -> void:
	if GardeService.load_def() == null:
		pending("données de Garde du lot B absentes")
		return
	var traces: Array = []
	for attempt: int in 2:
		var run: GardeRun = Campaign.start_garde("NUIT-2026-10-29")
		assert_not_null(run)
		var dc: DayController = _controller()
		var seen: Array = []
		var on_directive: Callable = func(n: int, unit: StringName, action: StringName) -> void: seen.append([n, unit, action])
		EventBus.garde_directive.connect(on_directive)
		assert_true(dc.start_garde(_data, run))
		dc.close_intro()
		_play(dc, 25)
		EventBus.garde_directive.disconnect(on_directive)
		assert_gt(run.passengers, 0)
		traces.append(seen.slice(0, mini(seen.size(), 3)))
		GameState.end_session()
	assert_eq(traces[0], traces[1], "même graine, mêmes directives")


func test_real_station_event_calendar() -> void:
	var def: StationEventsDef = StationEventService.load_def()
	if def == null:
		pending("données d'événements du lot B absentes")
		return
	var total: int = 0
	for campaign_seed: int in range(1, 101):
		var schedule: Dictionary[int, StationEventPlan] = StationEventService.schedule(campaign_seed, def, _data.days)
		total += schedule.size()
		for day_number: int in schedule:
			var day: DayDef = _data.get_day(day_number)
			for index: int in day.scripted_indices():
				assert_false(schedule[day_number].covers(index), "J%d @%d : jamais sur un cas scénarisé" % [day_number, index])
	assert_between(total / 100.0, 2.0, 7.0, "événements par campagne (moyenne %.2f)" % (total / 100.0))
