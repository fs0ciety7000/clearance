## M14 lot F — file réelle du Hall (VH-1 → VH-3, B86, D-187 ; ARCHITECTURE
## §12 ter.4) : `queue_progressed` émis par le `DayController` à l'ouverture,
## après chaque `case_resolved` et quand EV-06 allonge la file, sur un **vrai**
## jour (données réelles) ; silhouettes tirées du seul roster du matin, jamais
## modifiées par la construction des cas (aucune fuite d'anomalie) ; Garde :
## `total = −1`.
extends GutTest

var _data: DataCatalog = null
var _saved_state: Dictionary = {}
var _saved_slot: int = SaveService.DEFAULT_SLOT
## `[processed, total, upcoming sérialisés, case_resolved émis avant]`.
var _emissions: Array[Array] = []
var _resolved: int = 0


func before_all() -> void:
	_data = DataCatalog.load_from()
	_saved_state = GameState.to_save_dict()
	_saved_slot = GameState.active_slot


func before_each() -> void:
	_emissions.clear()
	_resolved = 0
	EventBus.queue_progressed.connect(_on_queue)
	EventBus.case_resolved.connect(_on_resolved)


func after_each() -> void:
	EventBus.queue_progressed.disconnect(_on_queue)
	EventBus.case_resolved.disconnect(_on_resolved)
	GameState.apply_save_dict(_saved_state)
	GameState.active_slot = _saved_slot


func _on_queue(processed: int, total: int, upcoming: Array[QueueSilhouette]) -> void:
	var rows: Array[Dictionary] = []
	for s: QueueSilhouette in upcoming:
		rows.append(s.serialize())
	_emissions.append([processed, total, rows, _resolved])


func _on_resolved(_case_id: StringName, _result: CaseResult) -> void:
	_resolved += 1


func _controller(apply: bool) -> DayController:
	var clock: DayClock = DayClock.new()
	var dc: DayController = DayController.new()
	dc.clock = clock
	dc.apply_to_game_state = apply
	dc.station_events_enabled = false
	add_child_autofree(clock)
	add_child_autofree(dc)
	clock.set_process(false)
	dc.set_process(false)
	return dc


## Joue au plus `count` passagers au verdict attendu.
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


func _expected(dc: DayController, processed: int, total: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for s: QueueSilhouette in QueueSilhouette.upcoming(dc.builder.roster, processed, total):
		rows.append(s.serialize())
	return rows


func test_emitted_at_start_and_after_each_case_from_the_morning_roster() -> void:
	var dc: DayController = _controller(false)
	assert_true(dc.start_day(_data, 7, SeededRng.day_seed(4242, 7)))
	var total: int = dc.day.passenger_count
	assert_eq(_emissions.size(), 1, "une émission à l'ouverture")
	assert_eq(_emissions[0][0], 0)
	assert_eq(_emissions[0][1], total)
	assert_eq((_emissions[0][2] as Array).size(), mini(total, QueueSilhouette.MAX_UPCOMING))
	assert_eq(int((_emissions[0][2] as Array)[0]["index"]), 0, "tête de file : le premier appelé")
	assert_eq(_emissions[0][2], _expected(dc, 0, total))
	# Silhouette de chaque index au matin, avant toute construction de cas.
	var morning: Dictionary[int, Dictionary] = {}
	for s: QueueSilhouette in QueueSilhouette.upcoming(dc.builder.roster, 0, total, total):
		morning[s.index] = s.serialize()
	dc.close_intro()
	_play(dc, total)
	assert_eq(dc.summary.results.size(), total, "jour complet")
	assert_eq(_emissions.size(), 1 + total, "une émission par cas traité")
	for k: int in range(1, _emissions.size()):
		var e: Array = _emissions[k]
		assert_eq(e[0], k, "processed = cas traités")
		assert_eq(e[3], k, "émis après case_resolved")
		assert_eq(e[1], total)
		var rows: Array = e[2]
		assert_eq(rows.size(), clampi(total - k, 0, QueueSilhouette.MAX_UPCOMING))
		for row: Variant in rows:
			var d: Dictionary = row
			assert_eq(d.keys().size(), QueueSilhouette.FIELDS.size(), "liste blanche des champs")
			# Les cas construits (anomalies injectées, visières, scénarisés) ne
			# changent jamais la silhouette d'un passager encore en file.
			assert_eq(d, morning[int(d["index"])], "silhouette %d stable depuis le matin" % int(d["index"]))
	assert_true((_emissions[_emissions.size() - 1][2] as Array).is_empty(), "file vide à la fin")


func test_crowd_event_lengthens_the_queue_and_reemits() -> void:
	var dc: DayController = _controller(false)
	assert_true(dc.start_day(_data, 12, SeededRng.day_seed(77, 12)))
	var plan: StationEventPlan = StationEventPlan.new()
	plan.event = load("res://data/events/ev_06.tres") as StationEventDef
	plan.day_number = 12
	plan.announce_after = 2
	dc.station_events = [plan]
	var before: int = dc.day.passenger_count
	var extra: int = plan.modifier(RuleChangeDef.MOD_EXTRA_PASSENGERS)
	assert_gt(extra, 0, "EV-06 ajoute des passagers")
	dc.close_intro()
	_play(dc, 2)
	assert_eq(plan.state, StationEventPlan.State.ACTIVE, "EV-06 annoncé après le 2ᵉ passager")
	var last: Array = _emissions[_emissions.size() - 1]
	var previous: Array = _emissions[_emissions.size() - 2]
	assert_eq(previous[0], 2)
	assert_eq(previous[1], before, "après le cas : file d'origine")
	assert_eq(last[0], 2, "même nombre traité")
	assert_eq(last[1], dc.day.passenger_count, "nouvelle longueur de file")
	assert_eq(last[1], before + extra, "la file s'allonge de +3 exactement (M12 §2, EV-06)")
	assert_eq(last[1], dc.summary.planned_cases)
	assert_eq(last[2], _expected(dc, 2, last[1]), "débordement tiré du roster étendu")
	assert_eq((last[2] as Array).size(), mini(last[1] - 2, QueueSilhouette.MAX_UPCOMING))


func test_night_shift_queue_is_endless() -> void:
	if GardeService.load_def() == null:
		pending("données de Garde absentes")
		return
	var run: GardeRun = Campaign.start_garde("NUIT-2026-10-29")
	assert_not_null(run)
	var dc: DayController = _controller(true)
	assert_true(dc.start_garde(_data, run))
	assert_eq(_emissions.size(), 1)
	assert_eq(_emissions[0][1], -1, "Garde : total = −1")
	assert_eq((_emissions[0][2] as Array).size(), QueueSilhouette.MAX_UPCOMING, "file toujours pleine")
	dc.close_intro()
	_play(dc, 3)
	assert_eq(_emissions.size(), 4)
	assert_eq(_emissions[3][0], 3)
	assert_eq(_emissions[3][1], -1)
	GameState.end_session()
