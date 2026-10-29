## Pilote QA M12 (passe §15) — sous-classe de tools/qa_campaign.gd.
## Campagne réelle J1→fin, puis épilogue J31 par les trois portes :
##   1. écran de fin › UN AN PLUS TARD ; 2. titre › Charger › JOUER « UN AN PLUS TARD » ;
##   3. emplacement supprimé › titre › Dossier › Épilogues › JOUER.
## Contrôles : fichiers de l'emplacement inchangés (hors méta), drapeaux du matin
## epi_ending_* / hh_*, passagers scénarisés du J31, lignes de conclusion sans clé brute.
## Usage (docs/QA.md §15.12) — XDG_DATA_HOME temporaire obligatoire :
##   XDG_DATA_HOME=$(mktemp -d) godot --headless --script res://tools/qa_boot.gd -- \
##       --qa-node=res://tests/qa_drivers/qa_m12_campaign.gd --autoplay --qa-seed=3 --qa-profile=loyal \
##       --qa-speed=10 --qa-reload [--qa-credits=3000] [--qa-story] [--qa-load=<current.json | slot_0.json>]
## Imprime QA_EV_* (événements : annonce, bandeau, cas présentés), QA_EPI_* (épilogue).
extends "res://tools/qa_campaign.gd"

var _phase: String = "campaign"
var _ending: String = ""
var _epi_key: String = ""
var _slot_md5: Dictionary = {}
var _epi_runs: int = 0
var _epi_handled: Dictionary = {}
var _scripted_seen: PackedStringArray = []
var _wait_msec: int = 0
var _epi_world: String = ""


func _ready() -> void:
	super._ready()
	EventBus.day_ended.connect(_on_any_day_ended)
	EventBus.station_event_started.connect(_on_event.bind("START"))
	EventBus.station_event_ended.connect(_on_event.bind("END"))
	EventBus.hall_announced.connect(func(key: String) -> void:
		if key.begins_with("sev_"):
			print("QA_EV_ANNOUNCE day=%d processed=%d key=%s" % [GameState.current_day, _processed(), key]))
	EventBus.case_presented.connect(_on_case_presented)
	EventBus.rules_changed.connect(func(diff: RuleDiff) -> void:
		if GameState.session_mode == GameState.SESSION_CAMPAIGN:
			print("QA_EV_RULES day=%d processed=%d added=%s retired=%s restored=%s" % [GameState.current_day, _processed(),
					diff.added, diff.retired, diff.restored]))


var _active_events: Array[StationEventPlan] = []


func _processed() -> int:
	var scene: DayScene = get_tree().current_scene as DayScene
	if scene == null or scene.day_controller == null:
		return -1
	return scene.day_controller.summary.results.size() if scene.day_controller.summary != null else -1


func _on_event(plan: StationEventPlan, what: String) -> void:
	if what == "START":
		_active_events.append(plan)
	else:
		_active_events.erase(plan)
	print("QA_EV_%s day=%d processed=%d id=%s class=%s window=[%d,%d) announce_after=%d clock=%d-%d free=%d" % [what,
			GameState.current_day, _processed(), plan.event.id, plan.event.event_class, plan.start_index, plan.end_index,
			plan.announce_after, plan.clock_from, plan.clock_to, plan.free_citations_bonus])
	await get_tree().process_frame
	await get_tree().process_frame
	var scene: DayScene = get_tree().current_scene as DayScene
	if scene != null and scene.ui is ComparisonUI:
		var banner: StationEventBanner = (scene.ui as ComparisonUI).event_banner
		print("QA_EV_BANNER day=%d %s visible=%s text=%s" % [GameState.current_day, what,
				banner != null and banner.is_visible_in_tree(), banner.get_text() if banner != null else "<aucun>"])


func _on_case_presented(case: Case) -> void:
	if _active_events.is_empty() or GameState.session_mode != GameState.SESSION_CAMPAIGN:
		return
	var scene: DayScene = get_tree().current_scene as DayScene
	if scene == null:
		return
	var scripted: bool = scene.day_controller.builder.get_scripted_case(case.index) != null
	var ids: PackedStringArray = []
	for p: StationEventPlan in _active_events:
		ids.append("%s(%s)" % [p.event.id, "structural" if p.is_structural() else "overlay"])
	print("QA_EV_CASE day=%d index=%d scripted=%s active=%s suspended=%s" % [GameState.current_day, case.index, scripted,
			",".join(ids), scene.day_controller.builder.ctx.rule_set.overlay_suspended])
	if scripted:
		for p: StationEventPlan in _active_events:
			if p.is_structural():
				_issue("J%d : événement structurel %s actif sur le cas scénarisé %d" % [GameState.current_day, p.event.id, case.index])


func _on_any_day_ended(summary: DaySummary) -> void:
	if GameState.session_mode != GameState.SESSION_EPILOGUE:
		return
	_scripted_seen = []
	for r: CaseResult in summary.results:
		_scripted_seen.append("%s:%s%s" % [r.scripted_id if r.scripted_id != &"" else &"gen", VerdictKind.Kind.keys()[r.verdict_kind],
				"" if r.correct else "(faux)"])
	print("QA_EPI_DAY run=%d processed=%d/%d citations=%d net=%d cases=%s" % [_epi_runs, summary.get_processed_count(),
			summary.planned_cases, summary.get_citation_count(), summary.get_net(), " ".join(_scripted_seen)])


func _on_new_day() -> void:
	if GameState.session_mode != GameState.SESSION_CAMPAIGN:
		_last_day = GameState.current_day
		_day_started_msec = Time.get_ticks_msec()
		return
	super._on_new_day()


func _process(delta: float) -> void:
	if _done:
		return
	if _phase == "campaign":
		super._process(delta)
		return
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	if Time.get_ticks_msec() - _wait_msec > 240000:
		_issue("BLOCAGE phase %s (scène %s)" % [_phase, scene.name])
		_finish(1)
		return
	if scene is DayScene:
		_drive_epilogue(scene as DayScene)
	elif scene.has_method(&"open_load"):
		_drive_title(scene)


func _on_end(scene: DayScene, end: EndScreen) -> void:
	_ending = str(GameState.get_flag(Campaign.FLAG_ENDING, end.ending))
	var lines: PackedStringArray = end.epilogue_lines()
	for line: String in lines:
		if _looks_like_key(line):
			_issue("fin %s : clé brute « %s »" % [_ending, line])
	print("QA_END seed=%d profile=%s ending=%s day=%d credits=%d compliance=%.2f screens=%s epilogue_lines=%d" % [
			_seed, _profile.name, _ending, GameState.current_day, GameState.credits, Campaign.compliance(),
			scene.screen_history, lines.size()])
	var meta: Dictionary = SaveService.load_meta(SLOT)
	if str(meta.get("status", "")) != SaveService.STATUS_ENDED or str(meta.get("ending_id", "")) != _ending:
		_issue("partie non archivée après la fin (%s)" % meta)
	var eligible: bool = EpilogueService.is_eligible(StringName(_ending), GameState.narrative_flags)
	var variant: StringName = EpilogueService.variant_of(StringName(_ending), GameState.narrative_flags)
	print("QA_EPI_ELIGIBLE ending=%s variant=%s eligible=%s world=%s has_day31=%s meta_epi=%s household=%s" % [_ending, variant,
			eligible, EpilogueService.world_of(StringName(_ending), GameState.narrative_flags), SaveService.has_epilogue(SLOT),
			meta.get(SaveService.KEY_EPILOGUE_AVAILABLE, "?"), GameState.household.to_dict()])
	if not eligible:
		if not end.has_epilogue_lock_hint():
			_issue("fin %s non éligible sans ligne epi_locked_hint" % _ending)
		_finish(0)
		return
	_slot_md5 = _slot_files()
	end.reveal_all()
	_phase = "end_offer"
	_wait_msec = Time.get_ticks_msec()
	await get_tree().create_timer(DS.EPILOGUE_OFFER_DELAY * _speed + 1.0).timeout
	if not end.has_epilogue() or end.epilogue_button == null or not end.epilogue_button.is_visible_in_tree():
		_issue("fin %s éligible : bouton UN AN PLUS TARD absent" % _ending)
		_finish(1)
		return
	var focus: Control = end.get_viewport().gui_get_focus_owner()
	print("QA_EPI_OFFER focus=%s" % (focus.name if focus != null else "<aucun>"))
	_phase = "epi"
	_epi_runs = 1
	end.epilogue_button.pressed.emit()


func _drive_epilogue(scene: DayScene) -> void:
	if GameState.session_mode != GameState.SESSION_EPILOGUE:
		return
	var screen: ScreenBase = scene.screen
	if not _epi_handled.has("start%d" % _epi_runs):
		_epi_handled["start%d" % _epi_runs] = true
		_check_morning()
	if screen is EpilogueScreen and (screen as EpilogueScreen).mode == EpilogueScreen.Mode.CONCLUSION \
			and not _epi_handled.has("concl%d" % _epi_runs):
		_epi_handled["concl%d" % _epi_runs] = true
		_check_conclusion(screen as EpilogueScreen)


func _check_morning() -> void:
	var epi: Dictionary = GameState.epilogue_seed
	_epi_key = EpilogueService.profile_key(epi)
	_epi_world = str(epi.get("world", ""))
	var flags: PackedStringArray = []
	for f: StringName in GameState.narrative_flags:
		var s: String = String(f)
		if s.begins_with("epi_ending_") or s.begins_with("hh_"):
			flags.append("%s=%s" % [s, GameState.narrative_flags[f]])
	flags.sort()
	var expected: StringName = EpilogueService.ending_flag(StringName(str(epi.get("ending_key", ""))))
	if not FlagCondition.is_flag_true(GameState.narrative_flags, expected):
		_issue("J31 run %d : drapeau %s absent" % [_epi_runs, expected])
	var others: int = 0
	for f: StringName in GameState.narrative_flags:
		if String(f).begins_with("epi_ending_") and f != expected and FlagCondition.is_flag_true(GameState.narrative_flags, f):
			others += 1
	if others > 0:
		_issue("J31 run %d : %d autre(s) epi_ending_* vrais" % [_epi_runs, others])
	print("QA_EPI_MORNING run=%d key=%s world=%s slot=%d credits=%d day=%d flags=%s household=%s" % [_epi_runs, _epi_key,
			_epi_world, GameState.epilogue_slot, GameState.credits, GameState.current_day, " ".join(flags),
			JSON.stringify(epi.get("household", {}))])


func _check_conclusion(screen: EpilogueScreen) -> void:
	var card: Dictionary = screen.card
	var lines: PackedStringArray = EpilogueScreen.conclusion_lines(card)
	for line: String in lines:
		if _looks_like_key(line) or line.contains("%d") or line.contains("%s"):
			_issue("conclusion : ligne suspecte « %s »" % line)
	if lines.size() > 8 + 2:
		_issue("conclusion : %d lignes" % lines.size())
	print("QA_EPI_CONCLUSION run=%d world=%s key=%s n=%d farewell=%s" % [_epi_runs, card.get("world", ""),
			card.get("ending_key", ""), lines.size(), card.get("farewell_key", "")])
	for line: String in lines:
		print("QA_EPI_LINE   %s" % line)
	# La partie terminée n'est pas modifiée (hors méta epilogue_done).
	if SaveService.has_save(SLOT):
		var now: Dictionary = _slot_files()
		for f: String in _slot_md5:
			if f != "meta.json" and now.get(f, "") != _slot_md5[f]:
				_issue("run %d : %s modifié par le J31" % [_epi_runs, f])
		for f: String in now:
			if not _slot_md5.has(f):
				_issue("run %d : fichier %s créé par le J31" % [_epi_runs, f])
		var meta: Dictionary = SaveService.load_meta(SLOT)
		print("QA_EPI_META status=%s ending=%s done=%s" % [meta.get("status"), meta.get("ending_id"),
				meta.get(SaveService.KEY_EPILOGUE_DONE, "?")])
	var prof: Dictionary = ProfileService.load_profile()
	var entry: Dictionary = (prof.get("epilogues", {}) as Dictionary).get(_epi_key, {})
	print("QA_EPI_PROFILE count=%s unlocked=%s" % [entry.get("count", "?"), prof.get("epilogue_unlocked")])
	if SaveService.as_int(entry.get("count", 0)) != _epi_runs:
		_issue("profil : epilogues[%s].count = %s (attendu %d)" % [_epi_key, entry.get("count"), _epi_runs])
	await get_tree().create_timer(0.5).timeout
	screen.reveal_all()
	await get_tree().create_timer(0.5).timeout
	_phase = "title%d" % _epi_runs
	_wait_msec = Time.get_ticks_msec()
	screen.close(&"title")


func _drive_title(main: Node) -> void:
	if _epi_handled.has(_phase):
		return
	_epi_handled[_phase] = true
	await get_tree().create_timer(0.5).timeout
	if _phase == "title1":
		var load_screen: LoadScreen = main.call(&"open_load")
		await get_tree().process_frame
		var b: Button = load_screen.epilogue_buttons.get(SLOT, null)
		print("QA_EPI_LOAD button=%s text=%s" % [b != null, b.text if b != null else ""])
		if b == null:
			_issue("Charger : pas d'action JOUER « UN AN PLUS TARD »")
			_finish(1)
			return
		_epi_runs = 2
		_phase = "epi"
		_wait_msec = Time.get_ticks_msec()
		b.pressed.emit()
	elif _phase == "title2":
		SaveService.delete_slot(SLOT)
		var dossier: DossierScreen = main.call(&"open_dossier")
		await get_tree().process_frame
		print("QA_EPI_DOSSIER tabs=%s" % [dossier.tabs])
		dossier.show_tab(DossierScreen.TAB_EPILOGUES)
		await get_tree().process_frame
		var b: Button = dossier.epilogue_buttons.get(_epi_key, null)
		print("QA_EPI_DOSSIER keys=%s button=%s" % [dossier.epilogue_buttons.keys(), b.text if b != null else "<aucun>"])
		if b == null:
			_issue("Dossier : pas de JOUER pour %s après suppression de l'emplacement" % _epi_key)
			_finish(1)
			return
		_epi_runs = 3
		_phase = "epi"
		_wait_msec = Time.get_ticks_msec()
		b.pressed.emit()
	elif _phase == "title3":
		_finish(0)


func _slot_files() -> Dictionary:
	var result: Dictionary = {}
	var dir: String = SaveService.resolve_dir(SaveService.DEFAULT_DIR).path_join("slot_%d" % SLOT)
	for f: String in DirAccess.get_files_at(dir):
		result[f] = FileAccess.get_md5(dir.path_join(f))
	return result
