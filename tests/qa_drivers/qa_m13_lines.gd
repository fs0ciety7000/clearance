## QA M13 : répliques composées réellement produites (cadre + puces) sur des
## jours J4 → J30 générés ; écrit les phrases uniques, une par ligne, préfixées
## `QA_LINE`, pour la relecture typographique (docs/QA.md §16).
##   godot --headless --script res://tests/qa_drivers/qa_m13_lines.gd -- [--groups=300]
extends SceneTree
func _initialize() -> void:
	var groups: int = 300
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--groups="):
			groups = arg.trim_prefix("--groups=").to_int()
	var data: DataCatalog = DataCatalog.load_from()
	UiText.ensure_translations()
	var translate: Callable = func(key: String) -> String: return TranslationServer.translate(key)
	var seen: Dictionary[String, int] = {}
	for g: int in groups:
		var n: int = 4 + g % 27
		var b: CaseBuilder = CaseBuilder.new(data, data.get_day(n), SeededRng.day_seed(90_000 + g, n))
		b.presentation_minute = 720
		for gc: GeneratedCase in b.build_day():
			if gc == null or gc.case.statements.is_empty():
				continue
			for q: StringName in gc.case.statement_frames:
				var frame: String = UiText.t(gc.case.statement_frames[q])
				var stmts: Array[Statement] = gc.case.statements_for_question(q)
				var line: String = Statement.compose(frame, stmts, func(k: String) -> String: return UiText.t(k))
				var key: String = "%s | %s" % [gc.case.statement_frames[q], line]
				seen[key] = int(seen.get(key, 0)) + 1
	for k: String in seen:
		print("QA_LINE %s" % k)
	print("QA_LINES %d" % seen.size())
	quit(0)
