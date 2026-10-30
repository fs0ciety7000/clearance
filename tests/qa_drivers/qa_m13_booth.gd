## Pilote QA M13 (docs/QA.md §16) — un jour réel (`day.tscn`, booth 3D, vraie
## `ComparisonUI`, vraie `InspectionSession`) joué par un agent « oracle » qui
## passe par l'interface : question de motif (et d'origine au palier s3+) par
## l'action `interrogate` + Ⓐ, puis **chaque puce** du journal comparée **à la
## souris** (vrais clics sur la puce puis sur le champ du document) à chaque
## champ comparable ; fouille par le menu (motif lu, TOUT SCANNER, objets
## interdits épinglés à l'onglet Contrebande, implants à la carte) ; autres
## violations épinglées (`pick`) ; tampon maintenu du verdict attendu.
## Sorties : `QA_CHIP` (résultat de chaque comparaison), `QA_RESOLVED` (verdict,
## citation, salaire), `QA_SEARCH` (motif, durées `inspection_busy`),
## `QA_MOTIVE` (motif a priori), `QA_R47`, `QA_SCAN_PIN`, `QA_SCRIPTED`
## (effets), `QA_PAD`, `QA_EV_START/END`, `QA_ISSUE` (anomalie constatée, dont
## faux positif), `QA_DAY_END`.
## Options : `--qa-liars=skip` (menteurs approuvés sans question : ENTRÉE
## IRRÉGULIÈRE attendue), `--qa-unwarranted=N` (fouille sans motif confirmée
## au passager N, en règle), `--qa-cancel-unwarranted` (ANNULER à la boîte),
## `--qa-no-search` (jamais de fouille : FOUILLE OMISE), `--qa-pad-chip`
## (manette seule : graphe de focus mesuré par de vrais appuis, 3 puces),
## `--qa-speed=10` ; et les arguments de `DayScene` (`--flags=upg_ag01,…`).
##   XDG_DATA_HOME=$(mktemp -d) godot --headless --script res://tools/qa_boot.gd -- \
##       --qa-node=res://tests/qa_drivers/qa_m13_booth.gd --seed=3 --day=4
extends Node

const DAY: String = "res://scenes/main/day.tscn"

var _speed: float = 10.0
var _liars_skip: bool = false
var _unwarranted_at: int = -1
var _cancel_unwarranted: bool = false
var _no_search: bool = false
var _pad_chip: bool = false
var _pad_done: int = 0
var _running: StringName = &""
var _last: Discrepancy = null
var _issues: int = 0
var _resolved: int = 0
var _fp: int = 0
var _chips: Dictionary = {}
var _motive: StringName = &"?"
var _busy: Array = []
var _dialog_seen: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-speed="):
			_speed = arg.trim_prefix("--qa-speed=").to_float()
		elif arg == "--qa-liars=skip":
			_liars_skip = true
		elif arg.begins_with("--qa-unwarranted="):
			_unwarranted_at = arg.trim_prefix("--qa-unwarranted=").to_int()
		elif arg == "--qa-cancel-unwarranted":
			_cancel_unwarranted = true
		elif arg == "--qa-no-search":
			_no_search = true
		elif arg == "--qa-pad-chip":
			_pad_chip = true
	Engine.time_scale = _speed
	EventBus.discrepancy_checked.connect(func(r: Discrepancy) -> void: _last = r)
	EventBus.documents_presented.connect(_on_documents)
	EventBus.case_resolved.connect(_on_resolved)
	EventBus.search_opened.connect(func(_cid: StringName, motive: StringName) -> void: _motive = motive)
	EventBus.search_confirmation_required.connect(func(_cid: StringName) -> void: _dialog_seen = true)
	EventBus.inspection_busy.connect(func(_cid: StringName, d: float, action: StringName) -> void: _busy.append([action, d]))
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.station_event_started.connect(func(plan: StationEventPlan) -> void:
		print("QA_EV_START %s fenêtre=[%d,%d) profil=%s" % [plan.event.id, plan.start_index, plan.end_index, plan.profile_label_key()]))
	EventBus.station_event_ended.connect(func(plan: StationEventPlan) -> void: print("QA_EV_END %s" % plan.event.id))
	get_tree().change_scene_to_file.call_deferred(DAY)


func _scene() -> DayScene:
	return get_tree().current_scene as DayScene


func _ui() -> ComparisonUI:
	var s: DayScene = _scene()
	return s.ui as ComparisonUI if s != null else null


func _dc() -> DayController:
	var s: DayScene = _scene()
	return s.day_controller if s != null else null


func _sleep(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _issue(text: String) -> void:
	_issues += 1
	print("QA_ISSUE %s" % text)


func _process(_delta: float) -> void:
	var dc: DayController = _dc()
	var ui: ComparisonUI = _ui()
	if dc == null or ui == null:
		return
	var s: DayScene = _scene()
	if s.briefing != null and is_instance_valid(s.briefing):
		s.briefing.close()
		return
	if s.help_card != null and is_instance_valid(s.help_card) and s.help_card.is_visible_in_tree():
		if not s.help_card.is_dismissed():
			print("QA_HELP carte d'aide : %s" % s.help_card.current_key())
			s.help_card.advance()
		return
	if dc.phase == DayPhase.Kind.WAITING_CASE and _running == &"" and dc.has_remaining_cases():
		_running = &"…"
		_call_next.call_deferred()


func _call_next() -> void:
	await _sleep(0.6)
	var ui: ComparisonUI = _ui()
	if ui != null and _dc().phase == DayPhase.Kind.WAITING_CASE:
		ui.request_next_case()
	await _sleep(0.3)
	if _running == &"…":
		_running = &""


func _click(control: Control) -> void:
	var vp: Viewport = control.get_viewport()
	var at: Vector2 = vp.get_final_transform() * (control.get_global_transform_with_canvas() * (control.size * 0.5))
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	vp.push_input(motion)
	for pressed: bool in [true, false]:
		var ev: InputEventMouseButton = InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		vp.push_input(ev)


func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var ev: InputEventAction = InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _joy_button(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var ev: InputEventJoypadButton = InputEventJoypadButton.new()
		ev.button_index = button
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await get_tree().process_frame


func _joy_axis(axis: JoyAxis, value: float) -> void:
	for v: float in [value, 0.0]:
		var ev: InputEventJoypadMotion = InputEventJoypadMotion.new()
		ev.axis = axis
		ev.axis_value = v
		Input.parse_input_event(ev)
		await get_tree().process_frame


func _focus_ref() -> FieldRef:
	var owner: Control = get_viewport().gui_get_focus_owner()
	return (owner as InspectableItem).ref if owner is InspectableItem else null


## Manette seule : graphe de focus **mesuré** par de vrais appuis sur la croix
## (chaque nœud remis au focus par `grab_focus`, puis ↑ ↓ ← →, voisin observé),
## en largeur depuis `start`. Renvoie le chemin de directions vers `target`
## (vide si inatteignable ; `[-1]` si `start` est déjà la cible).
const DIRS: Array[JoyButton] = [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]
const DIR_NAMES: Dictionary = {JOY_BUTTON_DPAD_UP: "↑", JOY_BUTTON_DPAD_DOWN: "↓", JOY_BUTTON_DPAD_LEFT: "←", JOY_BUTTON_DPAD_RIGHT: "→"}


func _label(c: Control) -> String:
	if c is InspectableItem and (c as InspectableItem).ref != null:
		return (c as InspectableItem).ref.key()
	return String(c.name) if c != null else "∅"


func _pad_bfs(start: Control, target: FieldRef) -> Array:
	var prev: Dictionary = {start: [null, -1]}
	var queue: Array[Control] = [start]
	var explored: int = 0
	while not queue.is_empty() and explored < 160:
		var node: Control = queue.pop_front()
		explored += 1
		if node is InspectableItem and (node as InspectableItem).ref != null and (node as InspectableItem).ref.equals(target):
			var path: Array = []
			var cur: Control = node
			while prev[cur][0] != null:
				path.push_front(prev[cur][1])
				cur = prev[cur][0]
			return [true, path, explored]
		for dir: JoyButton in DIRS:
			if not is_instance_valid(node) or not node.is_visible_in_tree():
				break
			node.grab_focus()
			await get_tree().process_frame
			await _joy_button(dir)
			var m: Control = get_viewport().gui_get_focus_owner()
			if m != null and not prev.has(m):
				prev[m] = [node, dir]
				queue.append(m)
	return [false, [], explored]


func _pad_pin(ui: ComparisonUI, chip: StatementChipView, target: FieldRef) -> bool:
	if not ui.inspection_active:
		await _joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
		await _sleep(0.3)
	# Premier appui de la croix (focus d'appoint), puis chemin vers la puce.
	await _joy_button(JOY_BUTTON_DPAD_UP)
	await _sleep(0.1)
	var origin: Control = get_viewport().gui_get_focus_owner()
	if origin == null:
		print("QA_PAD aucun focus après la croix ↑")
		return false
	var to_chip: Array = await _pad_bfs(origin, chip.ref)
	if not to_chip[0]:
		print("QA_PAD puce %s inatteignable depuis %s (%d nœuds explorés)" % [chip.ref.key(), _label(origin), to_chip[2]])
		return false
	origin.grab_focus()
	await get_tree().process_frame
	var names: PackedStringArray = []
	for dir: JoyButton in to_chip[1]:
		await _joy_button(dir)
		names.append(DIR_NAMES[dir])
	if _focus_ref() == null or not _focus_ref().equals(chip.ref):
		print("QA_PAD rejeu du chemin vers la puce raté (%s)" % " ".join(names))
		return false
	_last = null
	await _joy_button(JOY_BUTTON_A)
	await _sleep(0.2)
	var a_ok: bool = ui.selection.a != null and ui.selection.a.equals(chip.ref)
	var to_field: Array = await _pad_bfs(chip, target)
	if not to_field[0]:
		print("QA_PAD champ %s inatteignable depuis la puce (%d nœuds explorés)" % [target.key(), to_field[2]])
		return false
	chip.grab_focus()
	await get_tree().process_frame
	var names2: PackedStringArray = []
	for dir: JoyButton in to_field[1]:
		await _joy_button(dir)
		names2.append(DIR_NAMES[dir])
	await _joy_button(JOY_BUTTON_A)
	await _sleep(0.4)
	print("QA_PAD %s ↔ %s à la manette : A=%s résultat=%s (puce : %s ; champ : %s)" % [chip.ref.key(), target.key(), a_ok,
			Discrepancy.Result.keys()[_last.result] if _last != null else "<rien>", " ".join(names), " ".join(names2)])
	return _last != null


func _still(cid: StringName) -> bool:
	var dc: DayController = _dc()
	return dc != null and dc.phase == DayPhase.Kind.INSPECTING and dc.current_case_id() == cid


func _wait_idle(ui: ComparisonUI, cap: float = 20.0) -> void:
	var t: float = 0.0
	while ui.is_busy() and t < cap:
		await _sleep(0.25)
		t += 0.25


func _on_documents(cid: StringName) -> void:
	if _running == cid:
		return
	_running = cid
	_motive = &"?"
	_dialog_seen = false
	_busy.clear()
	await _sleep(1.0)
	if not _still(cid):
		return
	var dc: DayController = _dc()
	var ui: ComparisonUI = _ui()
	var c: Case = dc.current_case
	var key: CaseKey = dc.current_key
	var idx: int = c.index
	var lying: Dictionary[StringName, bool] = {}
	for v: Violation in key.expected_violations:
		if v.rule_id == &"r_statements":
			for ref: FieldRef in v.refs:
				if ref.is_statement():
					lying[ref.get_statement_id()] = true
	var ictx: RuleContext = _scene().inspection.ctx
	var rule: StatementsConsistentRule = StatementsConsistentRule.active_in(ictx.rule_set if ictx != null else null)
	if c.passenger_presented.appearance.is_face_covered():
		ui.ask(InterrogationTopics.REMOVE_VISOR)
		await _sleep(0.4)
		await _wait_idle(ui)
	var skip: bool = _liars_skip and not lying.is_empty()
	if not skip:
		# Question de motif par le menu : action `interrogate`, focus, Ⓐ.
		_press(&"interrogate")
		await _sleep(0.2)
		var owner: Control = get_viewport().gui_get_focus_owner()
		var label: String = owner.text if owner is Button else str(owner)
		if not ui.asked_topics.has(InterrogationTopics.PURPOSE):
			if owner is Button and label.contains(InterrogationTopics.question_text(InterrogationTopics.PURPOSE, c).left(12)):
				_press(&"ui_accept")
			else:
				print("QA_NOTE menu : focus initial « %s » (pas la question de motif) — ask()" % label)
				ui.close_question_menu()
				ui.ask(InterrogationTopics.PURPOSE)
		await _sleep(0.3)
		await _wait_idle(ui)
		if rule != null and rule.checks_topic(Statement.ID_ORIGIN) and _still(cid):
			ui.ask(InterrogationTopics.ORIGIN)
			await _sleep(0.3)
			await _wait_idle(ui)
	if not _still(cid):
		return
	ui.set_inspection_active(true)
	await _sleep(0.3)
	if _pad_chip and rule != null and _pad_done < 3:
		for chip: StatementChipView in ui.passenger_panel.journal.chips():
			if chip.struck or chip.statement.vague or chip.statement.id == Statement.ID_PROVENANCE:
				continue
			var target: FieldRef = rule.primary_ref(c, chip.statement)
			if target == null:
				continue
			if ui.selection.a != null:
				ui.cancel()
			var ok: bool = await _pad_pin(ui, chip, target)
			_pad_done += 1
			if not ok:
				_issue("manette : épinglage %s ↔ %s impossible (J%d #%d)" % [chip.ref.key(), target.key(), dc.day.day_number, idx + 1])
			break
	# Chaque puce ↔ chaque champ comparable, à la souris.
	if rule != null:
		for chip: StatementChipView in ui.passenger_panel.journal.chips():
			if chip.struck or not _still(cid):
				continue
			var st: Statement = chip.statement
			var refs: Array[FieldRef] = rule.comparable_refs(c, st)
			for ref: FieldRef in refs:
				var item: InspectableItem = ui._find_item(ref)
				if item == null:
					continue
				var view: DocumentView = null
				for v: DocumentView in ui.workbench.views:
					if v.instance != null and v.instance.get_document_id() == ref.document_id:
						view = v
				if view != null:
					ui.workbench.focus_document(ui.workbench.views.find(view))
					await _sleep(0.25)
				_last = null
				if ui.selection.a != null:
					ui.cancel()
				ui.passenger_panel.journal.show_tab(DialogueJournal.TAB_DIALOGUE)
				await get_tree().process_frame
				_click(chip)
				await _sleep(0.15)
				var mouse_a: bool = ui.selection.a != null and ui.selection.a.equals(chip.ref)
				if not mouse_a:
					ui.pick(chip.ref)
					print("QA_NOTE clic sur la puce %s sans effet (rect %s, visible %s) — pick()" % [st.id, chip.get_global_rect(),
							chip.is_visible_in_tree()])
				await _sleep(0.15)
				_click(item)
				await _sleep(0.3)
				if _last == null:
					ui.pick(ref)
					await _sleep(0.3)
					print("QA_NOTE clic sur %s sans effet (rect %s) — pick()" % [ref.key(), item.get_global_rect()])
				var res: String = Discrepancy.Result.keys()[_last.result] if _last != null else "<rien>"
				var reason: String = _last.reason_key if _last != null else ""
				_chips["%s:%s" % [st.id, res]] = int(_chips.get("%s:%s" % [st.id, res], 0)) + 1
				print("QA_CHIP J%d #%d %s %s ↔ %s : %s (%s) mouse_a=%s lying=%s text=« %s »" % [dc.day.day_number, idx + 1,
						String(c.case_id), st, ref.key(), res, reason, mouse_a, lying.has(st.id),
						chip.get_text()])
				if _last != null and _last.result == Discrepancy.Result.DISCORDANT and not lying.has(st.id):
					_fp += 1
					_issue("faux positif : J%d #%d %s ↔ %s" % [dc.day.day_number, idx + 1, st, ref.key()])
				if lying.has(st.id) and ref.equals(rule.primary_ref(c, st)) and (_last == null or _last.result != Discrepancy.Result.DISCORDANT):
					_issue("mensonge non discordant : J%d #%d %s ↔ %s" % [dc.day.day_number, idx + 1, st, ref.key()])
				if lying.has(st.id) and _last != null and _last.result == Discrepancy.Result.DISCORDANT:
					break
	# Fouille : indice, objet interdit, obligation, ou fouille sans motif demandée.
	var forbidden: bool = false
	if c.search_layout != null:
		for it: SearchItem in c.search_layout.items:
			forbidden = forbidden or it.is_forbidden() or (it.is_implant() and not c.declared_implants().has(it.implant_code))
	var r47: bool = false
	for r: Rule in ictx.rule_set.rules:
		if r is ProcedureRule and (r as ProcedureRule).requires_search(c):
			r47 = true
	if ui.search_available() or idx == 0:
		var probe: StringName = InspectionSession.search_motive_for(c, ictx, [] as Array[Discrepancy], [] as Array[StringName])
		print("QA_MOTIVE J%d #%d motif_a_priori=%s origine=%s motif=%s portique=%s" % [dc.day.day_number, idx + 1, probe,
				c.passenger_presented.faction_id, c.passenger_presented.purpose, ui.search_available()])
	if r47:
		print("QA_R47 J%d #%d R47 visé, portique %s" % [dc.day.day_number, idx + 1, "disponible" if ui.search_available() else "HORS SERVICE"])
	var want_search: bool = not _no_search and ui.search_available() and (not c.search_cues.is_empty() or forbidden or r47 or idx + 1 == _unwarranted_at)
	if want_search and _still(cid):
		ui.set_inspection_active(false)
		ui.ask(InterrogationTopics.SEARCH)
		await _sleep(0.3)
		if ui.search_dialog != null:
			print("QA_SEARCH J%d #%d boîte AUCUN MOTIF (focus %s)" % [dc.day.day_number, idx + 1, get_viewport().gui_get_focus_owner()])
			if _cancel_unwarranted:
				ui.search_dialog.cancel()
			else:
				ui.search_dialog.accept()
			await _sleep(0.3)
		await _wait_idle(ui)
		if ui.search_panel.is_open():
			if not ui.search_panel.request_all():
				print("QA_NOTE TOUT SCANNER refusé (busy=%s)" % ui.is_busy())
			await _sleep(0.5)
			var t: float = 0.0
			while ui.search_panel.scanned_zones().size() < 5 and t < 30.0 and _still(cid):
				await _sleep(0.5)
				t += 0.5
			print("QA_SEARCH J%d #%d motif=%s cues=%s forbidden=%s r47=%s zones=%d items=%d busy=%s" % [dc.day.day_number, idx + 1,
					_motive, c.search_cues, forbidden, r47, ui.search_panel.scanned_zones().size(), ui.search_panel.item_views.size(), _busy])
			if not c.search_cues.is_empty() and _motive == SearchLayout.MOTIVE_NONE:
				_issue("indice visible mais motif vide : J%d #%d" % [dc.day.day_number, idx + 1])
			ui.set_inspection_active(true)
			await _sleep(0.2)
			for view: SearchItemView in ui.search_panel.item_views.duplicate():
				if not _still(cid):
					break
				if view.item.is_forbidden():
					ui.rulebook.show_reference_tab(RulebookReference.TAB_CONTRABAND)
					_last = null
					ui.pick(view.ref)
					await _sleep(0.2)
					ui.pick(FieldRef.contraband_entry(view.item.category))
					await _sleep(0.3)
					print("QA_SCAN_PIN %s ↔ contrebande : %s" % [view.item.item_id, Discrepancy.Result.keys()[_last.result] if _last else "<rien>"])
				elif view.item.is_implant():
					var card: FieldRef = Rule.find_ref(c, &"id_card", &"implants")
					if card != null:
						_last = null
						ui.pick(view.ref)
						await _sleep(0.2)
						ui.pick(card)
						await _sleep(0.3)
						print("QA_SCAN_PIN %s ↔ carte : %s" % [view.item.implant_code, Discrepancy.Result.keys()[_last.result] if _last else "<rien>"])
	if not _still(cid):
		return
	# Autres violations attendues : épinglées (oracle), puis le tampon.
	ui.set_inspection_active(true)
	for v: Violation in key.expected_violations:
		if v.rule_id == &"r_statements" or v.refs.size() < 2:
			continue
		var documented: bool = false
		for d: Discrepancy in ui.discrepancies:
			documented = documented or v.is_documented_by(d)
		if documented:
			continue
		var done: bool = false
		for i: int in v.refs.size():
			for j: int in range(i + 1, v.refs.size()):
				if done or not _still(cid):
					continue
				if ui.selection.a != null:
					ui.cancel()
				_last = null
				ui.pick(v.refs[i])
				await _sleep(0.15)
				ui.pick(v.refs[j])
				await _sleep(0.3)
				done = _last != null and _last.confirmed
		if not done:
			print("QA_NOTE violation non épinglable par paires : %s" % v)
	ui.set_inspection_active(false)
	await _sleep(0.2)
	var kind: VerdictKind.Kind = key.expected_verdict
	if skip:
		kind = VerdictKind.Kind.APPROVE
	if key.expected_verdict == VerdictKind.Kind.APPROVE and dc.quota != null and dc.quota.is_full() and dc.quota.counts(c):
		kind = VerdictKind.Kind.DENY
	var button: StampButton = ui.get_stamp_button(kind)
	if button == null or not _still(cid):
		return
	button.begin_hold()
	await _sleep(0.7)
	button.end_hold()


func _on_resolved(cid: StringName, r: CaseResult) -> void:
	_resolved += 1
	var dc: DayController = _dc()
	print("QA_RESOLVED J%d #%d %s %s verdict=%s attendu=%s correct=%s doc=%s cit=%s wage=%d fine=%d motif=%s search=%s zones=%s" % [
			dc.day.day_number if dc else -1, r.case_index + 1, cid, r.scripted_id, VerdictKind.Kind.keys()[r.verdict_kind],
			VerdictKind.Kind.keys()[r.expected_verdict], r.correct, r.documented, r.citation_reason_key, r.wage, r.fine,
			r.verdict.search_motive if r.verdict else &"", r.verdict.search_done if r.verdict else false,
			r.verdict.zones_scanned if r.verdict else []])
	if r.scripted_id != &"":
		print("QA_SCRIPTED %s verdict=%s effets=%s" % [r.scripted_id, VerdictKind.Kind.keys()[r.verdict_kind], r.narrative_changes])
	if not r.correct and not _liars_skip and not _no_search and r.case_index + 1 != _unwarranted_at:
		_issue("verdict de l'oracle incorrect : #%d %s cit=%s viol=%s flagged=%s" % [r.case_index + 1, r.scripted_id, r.citation_reason_key,
				r.expected_violations, r.verdict.flagged if r.verdict else []])
	_running = &""


func _on_day_ended(summary: DaySummary) -> void:
	print("QA_DAY_END résolus=%d puces=%s faux_positifs=%d fouilles=%d sans_motif=%d declarations=%d issues=%d" % [_resolved, _chips,
			_fp, summary.get_search_count(), summary.get_unmotivated_search_count(), summary.get_statement_mismatch_count(), _issues])
	await _sleep(2.0)
	get_tree().quit(0)
