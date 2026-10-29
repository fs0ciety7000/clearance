## Pilote QA M12 — un jour de campagne réel (`day.tscn`, `--seed --day --autoplay`) avec son
## événement de station : annonce, bandeau, effet, fin, compensation, cas scénarisés, comparateur.
## Usage (docs/QA.md §15.12) — couples (graine, jour) de §15.4 :
##   XDG_DATA_HOME=$(mktemp -d) godot --headless --script res://tools/qa_boot.gd -- \
##       --qa-node=res://tests/qa_drivers/qa_m12_events.gd --seed=1 --day=18 --autoplay
extends Node

const DAY: String = "res://scenes/main/day.tscn"
var _active: Array[StationEventPlan] = []
var _t0: int = 0
var _checks: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 10.0
	EventBus.station_event_started.connect(_on_ev.bind("START"))
	EventBus.station_event_ended.connect(_on_ev.bind("END"))
	EventBus.hall_announced.connect(func(key: String) -> void:
		print("QA_EV_ANNOUNCE processed=%d minute=%s key=%s text=%s" % [_processed(), _minute(), key, UiText.t(key, key)]))
	EventBus.rules_changed.connect(func(d: RuleDiff) -> void:
		print("QA_EV_RULES processed=%d added=%s retired=%s restored=%s overridden=%s modifiers=%s" % [_processed(), d.added,
				d.retired, d.restored, d.overridden, d.modifiers]))
	EventBus.rule_list_published.connect(func(label: StringName, entries: Array) -> void:
		print("QA_EV_LIST label=%s entries=%d processed=%d" % [label, entries.size(), _processed()]))
	EventBus.case_presented.connect(_on_case)
	EventBus.discrepancy_checked.connect(func(r: Discrepancy) -> void:
		if not _active.is_empty():
			print("QA_EV_CHECK result=%s confirmed=%s" % [Discrepancy.Result.keys()[r.result], r.confirmed]))
	EventBus.case_resolved.connect(func(cid: StringName, r: CaseResult) -> void:
		print("QA_EV_RESOLVED %s idx=%d verdict=%s expected=%s correct=%s cit=%s fine=%d wage=%d active=%d" % [cid, r.case_index,
				VerdictKind.Kind.keys()[r.verdict_kind], VerdictKind.Kind.keys()[r.expected_verdict], r.correct, r.citation_reason_key,
				r.fine, r.wage, _active.size()]))
	EventBus.day_ended.connect(_on_day_ended)
	get_tree().change_scene_to_file.call_deferred(DAY)
	_t0 = Time.get_ticks_msec()


func _scene() -> DayScene:
	return get_tree().current_scene as DayScene


func _processed() -> int:
	var s: DayScene = _scene()
	if s == null or s.day_controller == null or s.day_controller.summary == null:
		return -1
	return s.day_controller.summary.results.size()


func _minute() -> String:
	var s: DayScene = _scene()
	if s == null or s.day_controller == null:
		return "?"
	var m: int = s.day_controller.current_minute()
	return "%02d:%02d" % [m / 60, m % 60]


func _on_ev(plan: StationEventPlan, what: String) -> void:
	if what == "START":
		_active.append(plan)
	else:
		_active.erase(plan)
	var s: DayScene = _scene()
	print("QA_EV_%s processed=%d minute=%s id=%s class=%s window=[%d,%d) announce_after=%d clock=%d-%d secs=%d free=%d warnings_day=%d" % [
			what, _processed(), _minute(), plan.event.id, plan.event.event_class, plan.start_index, plan.end_index, plan.announce_after,
			plan.clock_from, plan.clock_to, plan.seconds, plan.free_citations_bonus,
			s.day_controller.day.free_citations_per_day if s != null else -1])
	await get_tree().process_frame
	await get_tree().process_frame
	if s != null and is_instance_valid(s) and s.ui is ComparisonUI:
		var ui: ComparisonUI = s.ui
		var banner: StationEventBanner = ui.event_banner
		print("QA_EV_BANNER %s visible=%s text=%s" % [what, banner != null and banner.is_visible_in_tree(),
				banner.get_text() if banner != null else "<aucun>"])


func _on_case(case: Case) -> void:
	var s: DayScene = _scene()
	if s == null:
		return
	var dc: DayController = s.day_controller
	var scripted: bool = dc.builder.get_scripted_case(case.index) != null
	var ids: PackedStringArray = []
	for p: StationEventPlan in _active:
		ids.append("%s(%s)" % [p.event.id, "structural" if p.is_structural() else "overlay"])
	var ctx: RuleContext = dc.builder.ctx
	print("QA_EV_CASE idx=%d minute=%s scripted=%s active=%s suspended=%s comparator_down=%d rules=%d purpose=%s fac=%s anomalies=%s" % [
			case.index, _minute(), scripted, ",".join(ids), ctx.rule_set.overlay_suspended,
			ctx.modifier(RuleChangeDef.MOD_COMPARATOR_DOWN), ctx.rule_set.rules.size(), case.passenger_presented.purpose,
			case.passenger_presented.faction_id, _kinds(dc.current_key)])
	if scripted:
		for p: StationEventPlan in _active:
			if p.is_structural():
				print("QA_ISSUE événement structurel %s actif sur le cas scénarisé %d" % [p.event.id, case.index])


static func _kinds(key: CaseKey) -> String:
	if key == null:
		return "?"
	var k: PackedStringArray = []
	for a: Anomaly in key.anomalies:
		k.append(AnomalyType.name_of(a.type))
	return ",".join(k)


func _on_day_ended(summary: DaySummary) -> void:
	var cits: int = 0
	var fines: int = 0
	for r: CaseResult in summary.results:
		if r.citation_reason_key != "":
			cits += 1
		fines += r.fine
	var s: DayScene = _scene()
	print("QA_EV_DAY processed=%d/%d citations=%d fines=%d net=%d free_per_day=%d minute=%s" % [summary.get_processed_count(),
			summary.planned_cases, cits, fines, summary.get_net(), s.day_controller.day.free_citations_per_day if s != null else -1,
			_minute()])
	await get_tree().create_timer(1.0).timeout
	print("QA_EV_DONE")
	get_tree().quit(0)


func _process(_d: float) -> void:
	if Time.get_ticks_msec() - _t0 > 400000:
		print("QA_ISSUE BLOCAGE")
		get_tree().quit(1)
