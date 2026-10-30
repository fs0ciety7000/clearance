## Passe QA M13 (docs/QA.md §16) — balayage hors scène des cas scénarisés et
## des déclarations, sur les vrais jours et des historiques de drapeaux
## synthétiques (M13 §4.6 « régression scénarisée sur 50 historiques »).
##
## - verdict attendu de chaque cas scénarisé J1 → J30 identique en 0.12
##   (`M13Sim.strip`) et en 0.13 (`QA_VERDICT`) ;
## - puces de **tous** les cas (générés et scénarisés) comparées à **tous** les
##   champs de documents du cas : une DISCORDANCE chez un passager qui ne ment
##   pas (aucune violation R43 attendue sur cette puce) est un faux positif
##   (`QA_FP`) ; une DISCORDANCE qui ne documenterait pas le refus attendu
##   (`QA_UNDOC`) ;
## - R43 violée sans `STATEMENT_MISMATCH` ni puce scénarisée (`QA_R43`).
## Usage : godot --headless --script res://tests/qa_drivers/qa_m13_scan.gd -- [--histories=50] [--seeds=3]
extends SceneTree

var _histories: int = 50
var _seeds: int = 3
var _counts: Dictionary = {}


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--histories="):
			_histories = arg.trim_prefix("--histories=").to_int()
		elif arg.begins_with("--seeds="):
			_seeds = arg.trim_prefix("--seeds=").to_int()
	_run.call_deferred()


func _bump(key: String, n: int = 1) -> void:
	_counts[key] = int(_counts.get(key, 0)) + n


func _flag_universe(data: DataCatalog) -> Array[StringName]:
	var seen: Dictionary[StringName, bool] = {}
	for n: int in range(1, 31):
		for s: ScriptedCaseDef in data.get_day(n).scripted_cases:
			for d: Dictionary in [s.flags_on_approve, s.flags_on_deny, s.flags_on_detain, s.flags_if_unprocessed,
					s.flags_on_search, s.flags_on_password]:
				for k: StringName in d:
					seen[k] = true
			if s.requires_flag != &"":
				seen[s.requires_flag] = true
			if s.sets_flag != &"":
				seen[s.sets_flag] = true
			if s.condition != null:
				for k: StringName in s.condition.all_of + s.condition.none_of:
					seen[k] = true
	var out: Array[StringName] = []
	for k: StringName in seen:
		out.append(k)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


func _run() -> void:
	var data: DataCatalog = DataCatalog.load_from()
	var universe: Array[StringName] = _flag_universe(data)
	print("QA_SCAN univers de drapeaux : %d" % universe.size())
	var stripped: Dictionary[int, DayDef] = {}
	for n: int in range(1, 31):
		stripped[n] = M13Sim.strip(data.get_day(n))
	var only_day: int = 0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only-day="):
			only_day = arg.trim_prefix("--only-day=").to_int()
	for h: int in _histories:
		var rng: SeededRng = SeededRng.new(SeededRng.mix(4242, h))
		var flags: Array[StringName] = []
		if h > 0:
			for f: StringName in universe:
				if rng.randf() < 0.5:
					flags.append(f)
		for s: int in _seeds:
			var campaign: int = SeededRng.mix(77_000 + h, s)
			for n: int in range(1, 31):
				if only_day > 0 and n != only_day:
					continue
				_scan_day(data, data.get_day(n), stripped[n], campaign, flags, h)
	var keys: Array = _counts.keys()
	keys.sort()
	for k: String in keys:
		print("QA_COUNT %s = %d" % [k, _counts[k]])
	quit(0)


func _scan_day(data: DataCatalog, day: DayDef, day12: DayDef, campaign: int, flags: Array[StringName], h: int) -> void:
	var memory: Dictionary = CaseMemory.resolve(data, day, campaign, {})
	var seed: int = SeededRng.day_seed(campaign, day.day_number)
	var b13: CaseBuilder = CaseBuilder.new(data, day, seed, flags, memory)
	b13.presentation_minute = 12 * 60
	var b12: CaseBuilder = CaseBuilder.new(data, day12, seed, flags, memory)
	b12.presentation_minute = 12 * 60
	var cases13: Array[GeneratedCase] = b13.build_day()
	var cases12: Array[GeneratedCase] = b12.build_day()
	var by_id12: Dictionary[StringName, GeneratedCase] = {}
	for g: GeneratedCase in cases12:
		if g != null and g.scripted_id != &"":
			by_id12[g.scripted_id] = g
	var rule: StatementsConsistentRule = StatementsConsistentRule.active_in(b13.ctx.rule_set)
	for g: GeneratedCase in cases13:
		if g == null or g.case == null:
			continue
		var c: Case = g.case
		if g.scripted_id != &"":
			_bump("scripted_built")
			if not g.invariant_errors.is_empty():
				_bump("scripted_invariant_errors")
				print("QA_INV J%d %s h%d : %s" % [day.day_number, g.scripted_id, h, g.invariant_errors])
			var old: GeneratedCase = by_id12.get(g.scripted_id)
			if old != null and old.key.expected_verdict != g.key.expected_verdict and not String(g.scripted_id).begins_with("sc_10") \
					and not String(g.scripted_id).begins_with("sc_11"):
				_bump("verdict_changed")
				print("QA_VERDICT J%d %s h%d : 0.12 %s → 0.13 %s (%s → %s)" % [day.day_number, g.scripted_id, h,
						VerdictKind.Kind.keys()[old.key.expected_verdict], VerdictKind.Kind.keys()[g.key.expected_verdict],
						old.key.get_violated_rule_ids(), g.key.get_violated_rule_ids()])
				for v: Violation in old.key.expected_violations:
					for r: FieldRef in v.refs:
						print("   0.12 %s = %s | 0.13 = %s" % [r.key(), old.case.get_value(r) if r.is_document_field() else "-",
								c.get_value(r) if r.is_document_field() and c.has_field(r) else "-"])
		if c.statements.is_empty() or rule == null:
			continue
		var lying_ids: Dictionary[StringName, bool] = {}
		for v: Violation in g.key.expected_violations:
			if v.rule_id == &"r_statements":
				for ref: FieldRef in v.refs:
					if ref.is_statement():
						lying_ids[ref.get_statement_id()] = true
		var kinds: Array = []
		for a: Anomaly in g.key.anomalies:
			kinds.append(a.type)
		if not lying_ids.is_empty() and not kinds.has(AnomalyType.Kind.STATEMENT_MISMATCH) and g.scripted_id == &"":
			_bump("r43_without_lie")
			print("QA_R43 J%d %s : %s" % [day.day_number, c.case_id, kinds])
		for st: Statement in c.statements:
			st.given = true
			_bump("chips")
			for doc: DocumentInstance in c.documents:
				for field: FieldDef in doc.type_def.fields:
					var ref: FieldRef = FieldRef.new(doc.get_document_id(), field.id)
					if not c.has_field(ref):
						continue
					var d: Discrepancy = DiscrepancyChecker.check(c, st.get_ref(), ref, b13.ctx)
					if d.result != Discrepancy.Result.DISCORDANT:
						continue
					_bump("chip_discordant")
					if lying_ids.has(st.id):
						continue
					var tag: String = "scripted" if g.scripted_id != &"" else ("clean" if kinds.is_empty() else "other_anomaly")
					_bump("fp_" + tag)
					var documented: bool = ScoringService.is_documented([d], g.key.expected_violations)
					if not documented:
						_bump("fp_undocumented_" + tag)
					if tag != "other_anomaly" or not documented:
						print("QA_FP J%d %s %s h%d : %s ↔ %s (%s) doc=%s kinds=%s verdict=%s" % [day.day_number, c.case_id,
								g.scripted_id, h, st, ref.key(), c.get_value(ref), documented, kinds,
								VerdictKind.Kind.keys()[g.key.expected_verdict]])
