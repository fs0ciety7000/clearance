## Pilote QA M12 — Garde de nuit en vraie scène (titre → accueil → guichet → fin de garde → rejouer…).
## Bot « oracle » : verdict attendu, preuves fournies (aucune citation), sauf aux passagers listés
## dans le plan d'erreurs de chaque garde. Lancé par tools/qa_boot.gd (XDG_DATA_HOME temporaire).
##   --qa-garde-long=N : garde 1 jouée juste jusqu'à N passagers puis TERMINER LA GARDE (barre + confirmation).
## Usage (docs/QA.md §15.12) :
##   XDG_DATA_HOME=$(mktemp -d) godot --headless --script res://tools/qa_boot.gd -- \
##       --qa-node=res://tests/qa_drivers/qa_m12_garde.gd --qa-garde-long=70 [--qa-only-long]
##   Capture réelle (xvfb, OpenGL 3) : ajouter --qa-shot-at=<index>:<fichier.png>.
extends Node

const MAIN: String = "res://scenes/main/main.tscn"
var _long: int = 70
var _run: int = 0
## Plans : run → passagers (index 0-based) jugés faux.
var _wrong: Dictionary = {1: [], 2: [3, 8, 12], 3: [0, 1, 2], 4: [4, 5, 6]}
var _code: String = ""
var _seq: Dictionary = {}
var _phase: String = "boot"
var _handled: Dictionary = {}
var _started: int = 0
var _issues: int = 0
var _mem0: int = 0
var _obj0: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-garde-long="):
			_long = arg.trim_prefix("--qa-garde-long=").to_int()
	Engine.time_scale = 8.0
	EventBus.documents_presented.connect(_on_documents)
	EventBus.garde_directive.connect(func(n: int, unit: StringName, action: StringName) -> void:
		print("QA_G_DIRECTIVE run=%d n=%d unit=%s action=%s processed=%d" % [_run, n, unit, action, _processed()])
		_check_card.call_deferred(n))
	EventBus.garde_tier_changed.connect(func(t: int) -> void: print("QA_G_TIER run=%d tier=%d processed=%d" % [_run, t, _processed()]))
	EventBus.garde_error.connect(func(cid: StringName, key: String, n: int) -> void:
		print("QA_G_ERROR run=%d case=%s key=%s errors=%d" % [_run, cid, key, n]))
	EventBus.rules_changed.connect(func(d: RuleDiff) -> void:
		var rb: PackedStringArray = []
		for e: RulebookEntry in d.rulebook:
			rb.append("%s%s%s" % [e.rule_id, "[NEW]" if e.is_new else "", "[RET]" if e.retired else ""])
		print("QA_G_RULES run=%d processed=%d added=%s retired=%s forgotten=%s restored=%s rulebook=%s" % [_run, _processed(),
				d.added, d.retired, d.forgotten, d.restored, " ".join(rb)]))
	EventBus.station_event_started.connect(func(p: StationEventPlan) -> void:
		print("QA_G_EVENT run=%d START %s processed=%d window=[%d,%d)" % [_run, p.event.id, _processed(), p.start_index, p.end_index]))
	EventBus.station_event_ended.connect(func(p: StationEventPlan) -> void:
		print("QA_G_EVENT run=%d END %s processed=%d" % [_run, p.event.id, _processed()]))
	EventBus.garde_ended.connect(func(r: Dictionary) -> void:
		print("QA_G_ENDED run=%d score=%s passengers=%s errors=%d directives=%s palier=%s reason=%s" % [_run, r.get("score"),
				r.get("passengers"), (r.get("errors", []) as Array).size(), r.get("directives"), r.get("tier", r.get("palier")),
				r.get("end_reason")]))
	get_tree().change_scene_to_file.call_deferred(MAIN)
	_started = Time.get_ticks_msec()


func _processed() -> int:
	var s: DayScene = get_tree().current_scene as DayScene
	if s == null or s.day_controller == null or s.day_controller.summary == null:
		return -1
	return s.day_controller.summary.results.size()


func _issue(t: String) -> void:
	_issues += 1
	print("QA_ISSUE " + t)


func _process(_d: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	if Time.get_ticks_msec() - _started > 520000:
		_issue("BLOCAGE phase %s" % _phase)
		_quit()
		return
	if scene.has_method(&"open_garde"):
		_title(scene)
	elif scene is DayScene:
		_day(scene as DayScene)


func _title(main: Node) -> void:
	if _handled.has("title_" + _phase):
		return
	_handled["title_" + _phase] = true
	await get_tree().create_timer(0.3).timeout
	var gb: Button = main.get(&"garde_button")
	if _phase == "boot":
		print("QA_G_TITLE fresh_profile garde_disabled=%s focus_mode=%d locked_label=%s" % [gb.disabled, gb.focus_mode,
				(main.get(&"garde_locked_label") as Label).text if main.get(&"garde_locked_label") != null else "<aucun>"])
		ProfileService.record(SaveService.DEFAULT_DIR, "", 0, [], false, 2)
		main.call(&"refresh_menu")
		await get_tree().process_frame
		print("QA_G_TITLE after_J1 garde_disabled=%s" % gb.disabled)
		var gs: GardeScreen = main.call(&"open_garde")
		await get_tree().process_frame
		await get_tree().process_frame
		var f: Control = gs.get_viewport().gui_get_focus_owner()
		print("QA_G_HOME daily=%s today=%s focus=%s" % [gs.daily_code, GardeService.today_code(), f.name if f != null else "<aucun>"])
		for t: String in ["k2q9tx", "K2Q-9TX", " k2q-9tx ", "K2O-9TX", "K2I-9TX", "K20-9TX", "K21-9TX", "K2Q9T", "K2Q-9TXZ",
				"nuit-2026-10-29", "NUIT-2026-13-40", "", "é2Q-9TX"]:
			gs.code_input.text = t
			gs.code_input.text_changed.emit(t)
			var n: Dictionary = GardeService.normalize_code(t)
			print("QA_G_CODE «%s» ok=%s code=%s kind=%s err=%s play_disabled=%s status=%s" % [t, n.get("ok"), n.get("code"),
					n.get("kind"), n.get("error_key"), gs.play_code_button.disabled, gs._status_label.text if gs._status_label != null else ""])
		gs.random_button.pressed.emit()
		await get_tree().process_frame
		var f2: Control = gs.get_viewport().gui_get_focus_owner()
		print("QA_G_RANDOM text=%s play_disabled=%s focus=%s" % [gs.code_input.text, gs.play_code_button.disabled,
				f2.name if f2 != null else "<aucun>"])
		gs.code_input.text = "k2q-9tx"
		gs.code_input.text_changed.emit("k2q-9tx")
		_code = "K2Q-9TX"
		_run = 1
		_phase = "run"
		_mem0 = OS.get_static_memory_usage()
		_obj0 = int(Performance.get_monitor(Performance.OBJECT_COUNT))
		gs.play_code_button.pressed.emit()
	elif _phase == "after_new_seed":
		var gs2: Node = main.get(&"screen")
		print("QA_G_NEWSEED screen=%s" % [gs2.get_class() if gs2 == null else gs2.name])
		if gs2 is GardeScreen:
			_run = 3
			_phase = "run"
			_code = (gs2 as GardeScreen).daily_code
			(gs2 as GardeScreen).daily_button.pressed.emit()
		else:
			_issue("NOUVELLE GRAINE n'a pas rouvert l'accueil de la Garde")
			_quit()
	elif _phase == "after_back":
		var gs3: GardeScreen = main.call(&"open_garde")
		await get_tree().process_frame
		_run = 4
		_phase = "run"
		gs3.daily_button.pressed.emit()
	elif _phase == "done":
		var prof: Dictionary = ProfileService.load_profile()
		print("QA_G_PROFILE best_runs=%s" % JSON.stringify(prof.get("best_runs")))
		print("QA_G_PROFILE garde_daily=%s seeds=%s stats=%s" % [JSON.stringify(prof.get("garde_daily")),
				JSON.stringify(prof.get("garde_seeds")), JSON.stringify(prof.get("garde_stats"))])
		_quit()


func _day(scene: DayScene) -> void:
	var dc: DayController = scene.day_controller
	if dc == null:
		return
	if dc.phase == DayPhase.Kind.WAITING_CASE and not _handled.has("next_%d_%d" % [_run, _processed()]):
		_handled["next_%d_%d" % [_run, _processed()]] = true
		var p: int = _processed()
		if _run == 1 and p >= _long and not _handled.has("end1"):
			_handled["end1"] = true
			print("QA_G_MEM run=1 passengers=%d static_mem_delta=%d objects_delta=%d nodes=%d" % [p,
					OS.get_static_memory_usage() - _mem0, int(Performance.get_monitor(Performance.OBJECT_COUNT)) - _obj0,
					int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
			var dlg: ConfirmDialog = scene.request_end_garde()
			await get_tree().create_timer(0.5).timeout
			var f: Control = scene.get_viewport().gui_get_focus_owner()
			print("QA_G_END_DIALOG focus=%s" % (f.name if f != null else "<aucun>"))
			dlg.confirmed.emit()
			return
		if p > 0 and p % 10 == 0:
			print("QA_G_MEM run=%d passengers=%d portraits=%d static_mem_delta=%d objects_delta=%d nodes=%d" % [_run, p, scene.portrait_service.cache_size(),
					OS.get_static_memory_usage() - _mem0, int(Performance.get_monitor(Performance.OBJECT_COUNT)) - _obj0,
					int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
		await get_tree().create_timer(0.4).timeout
		(scene.ui as ComparisonUI).request_next_case()
	var screen: ScreenBase = scene.screen
	if screen is GardeEndScreen and not _handled.has("end_screen_%d" % _run):
		_handled["end_screen_%d" % _run] = true
		await get_tree().create_timer(1.0).timeout
		var es: GardeEndScreen = screen
		var f: Control = es.get_viewport().gui_get_focus_owner()
		print("QA_G_END_SCREEN run=%d code=%s badges=%s focus=%s errors_shown=%d" % [_run, es.code(), es.badges,
				f.name if f != null else "<aucun>", (es.record.get("errors", []) as Array).size()])
		match _run:
			1:
				if OS.get_cmdline_user_args().has("--qa-only-long"):
					_quit()
					return
				_run = 2
				es.replay_button.pressed.emit()
			2:
				_compare_sequences()
				_phase = "after_new_seed"
				es.new_button.pressed.emit()
			3:
				_phase = "after_back"
				es.back_button.pressed.emit()
			_:
				_phase = "done"
				es.back_button.pressed.emit()


func _on_documents(case_id: StringName) -> void:
	var scene: DayScene = get_tree().current_scene as DayScene
	if scene == null or GameState.session_mode != GameState.SESSION_GARDE:
		return
	var dc: DayController = scene.day_controller
	var case: Case = dc.current_case
	var key: CaseKey = dc.current_key
	var idx: int = case.index
	var p: Passenger = case.passenger_presented
	if not _seq.has(_run):
		_seq[_run] = []
	(_seq[_run] as Array).append("%d:%s %s %s" % [idx, p.given_name, p.family_name, p.citizen_id])
	var kinds: PackedStringArray = []
	for a: Anomaly in key.anomalies:
		kinds.append(AnomalyType.name_of(a.type))
	if _run <= 2 and idx < 40:
		print("QA_G_CASE run=%d idx=%d who=%s %s expected=%s anomalies=%s rules=%d" % [_run, idx, p.given_name, p.family_name,
				VerdictKind.Kind.keys()[key.expected_verdict], kinds, dc.builder.ctx.rule_set.rules.size()])
	var shot: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-shot-at="):
			shot = arg.trim_prefix("--qa-shot-at=")
	if not shot.is_empty() and idx == int(shot.split(":")[0]):
		Engine.time_scale = 1.0
		await get_tree().create_timer(2.5).timeout
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(shot.split(":")[1])
		print("QA_G_SHOT idx=%d %s" % [idx, shot.split(":")[1]])
		_quit()
		return
	await get_tree().create_timer(0.6).timeout
	if dc.phase != DayPhase.Kind.INSPECTING or dc.current_case_id() != case_id:
		return
	var wrong: bool = (_wrong.get(_run, []) as Array).has(idx)
	var kind: VerdictKind.Kind = key.expected_verdict
	if wrong:
		kind = VerdictKind.Kind.APPROVE if kind != VerdictKind.Kind.APPROVE else VerdictKind.Kind.DENY
	var v: Verdict = Verdict.new(case_id, kind)
	case.remove_visor()
	if kind != VerdictKind.Kind.APPROVE and not wrong:
		v.flagged = DaySimulator.evidence_for(case, key, dc.builder.ctx)
	v.questions_asked = [DaySimulator.TOPIC_PURPOSE]
	EventBus.verdict_stamped.emit(v)


func _check_card(n: int) -> void:
	await get_tree().process_frame
	var cards: Array[Node] = get_tree().root.find_children("*", "GardeDirectiveCard", true, false)
	var f: Control = get_viewport().gui_get_focus_owner()
	print("QA_G_CARD n=%d cards=%d focus=%s" % [n, cards.size(), f.name if f != null else "<aucun>"])


func _compare_sequences() -> void:
	var a: Array = _seq.get(1, [])
	var b: Array = _seq.get(2, [])
	var n: int = mini(a.size(), b.size())
	var same: int = 0
	for i: int in n:
		if a[i] == b[i]:
			same += 1
		else:
			_issue("déterminisme : passager %d « %s » ≠ « %s »" % [i, a[i], b[i]])
	print("QA_G_DETERMINISM compared=%d identical=%d (run1 %d passagers, run2 %d)" % [n, same, a.size(), b.size()])


func _quit() -> void:
	print("QA_G_DONE issues=%d" % _issues)
	Engine.time_scale = 1.0
	var barrier: Node = get_tree().root.get_node_or_null("AudioMixBarrier")
	if barrier != null:
		barrier.call(&"quit_after_silence", 0)
	else:
		get_tree().quit(0)
