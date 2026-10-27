## Notation minimale M4 (`ScoringService`, `CaseResult`, `DaySummary`) et
## typage des signaux `case_resolved` / `day_ended` (TODO(M5) levés).
extends GutTest


func _key(expected: VerdictKind.Kind, violations: int = 0) -> CaseKey:
	var key: CaseKey = CaseKey.new()
	key.expected_verdict = expected
	for i: int in violations:
		key.expected_violations.append(Violation.new(StringName("r%d" % i)))
	return key


func test_matching_verdict_is_correct() -> void:
	var result: CaseResult = ScoringService.score(Verdict.new(&"c", VerdictKind.Kind.DENY), _key(VerdictKind.Kind.DENY, 1), &"c")
	assert_true(result.correct)
	assert_eq(result.case_id, &"c")
	assert_eq(result.verdict_kind, VerdictKind.Kind.DENY)
	assert_eq(result.expected_verdict, VerdictKind.Kind.DENY)
	assert_true(result.missed_violations.is_empty())


func test_approving_a_faulty_case_reports_missed_violations() -> void:
	var result: CaseResult = ScoringService.score(Verdict.new(&"c", VerdictKind.Kind.APPROVE), _key(VerdictKind.Kind.DENY, 2), &"c")
	assert_false(result.correct)
	assert_eq(result.missed_violations.size(), 2)


func test_denying_a_clean_case_is_wrong() -> void:
	var result: CaseResult = ScoringService.score(Verdict.new(&"c", VerdictKind.Kind.DENY), _key(VerdictKind.Kind.APPROVE), &"c")
	assert_false(result.correct)
	assert_true(result.missed_violations.is_empty())


func test_deny_where_detain_expected_is_correct() -> void:
	assert_true(ScoringService.is_correct(VerdictKind.Kind.DENY, VerdictKind.Kind.DETAIN), "GDD §4.5")
	assert_false(ScoringService.is_correct(VerdictKind.Kind.DETAIN, VerdictKind.Kind.DENY))
	assert_false(ScoringService.is_correct(VerdictKind.Kind.APPROVE, VerdictKind.Kind.DETAIN))


func test_elapsed_copied_from_verdict() -> void:
	var verdict: Verdict = Verdict.new(&"c", VerdictKind.Kind.APPROVE)
	verdict.elapsed_sec = 12.5
	var result: CaseResult = ScoringService.score(verdict, _key(VerdictKind.Kind.APPROVE), &"c")
	assert_eq(result.elapsed_sec, 12.5)
	assert_eq(result.verdict, verdict)


func test_missing_key_is_an_error() -> void:
	var result: CaseResult = ScoringService.score(Verdict.new(), null, &"c")
	assert_false(result.correct)
	assert_push_error("manquant")


func test_day_summary_counts() -> void:
	var summary: DaySummary = DaySummary.new()
	for correct: bool in [true, false, true]:
		var r: CaseResult = CaseResult.new()
		r.correct = correct
		summary.add_result(r)
	assert_eq(summary.get_processed_count(), 3)
	assert_eq(summary.get_correct_count(), 2)
	assert_eq(summary.get_error_count(), 1)


func test_event_bus_result_types_resolved() -> void:
	var wanted: Dictionary = {&"case_resolved": [1, "CaseResult"], &"day_ended": [0, "DaySummary"]}
	var script: Script = EventBus.get_script()
	for info: Dictionary in script.get_script_signal_list():
		var signal_name: StringName = StringName(str(info["name"]))
		if wanted.has(signal_name):
			var args: Array = info["args"]
			var spec: Array = wanted[signal_name]
			var index: int = spec[0]
			var wanted_class: String = spec[1]
			var arg: Dictionary = args[index]
			assert_eq(str(arg["class_name"]), wanted_class, String(signal_name))
