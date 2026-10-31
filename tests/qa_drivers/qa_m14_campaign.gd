## Passe QA M14 (docs/QA.md §17) — campagne réelle (`tools/qa_campaign.gd`,
## `day.tscn`, bot `--autoplay`) **observée** : musique dynamique, annonces
## d'ambiance, file réelle, Gardes, cinématiques de fin, fondus de sortie.
## Rien n'est modifié dans le jeu : le pilote lit l'état public des nœuds et
## écoute les signaux (`MusicDirector.level_changed` / `bar_passed`,
## `EventBus.*`).
##
## Sorties (une ligne par fait, préfixe `QA14_`) :
##   QA14_LEVEL day= t= lv= state= bar= at_bar= inputs…   (chaque niveau appliqué)
##   QA14_DAYMUSIC day= max_shift= hist= offbar= bad_step= fast_up= fast_down= story_cap= lost_ms=
##   QA14_MIRROR day= samples= diff=          (intensité recalculée depuis les seuls signaux publics)
##   QA14_PA day= key= t= text=  / QA14_PADAY day= count= min_gap= …
##   QA14_QUEUE day= total= planned= ev06= mismatch=
##   QA14_GUARD day= moved_while_inspecting=
##   QA14_FADE from= fade_db= stopped= game_sec=      (sortie de scène)
##   QA14_CIN id= ending= variant= act= plates= captions= figures= theme= state= paused= sec= skipped=
##   QA14_END ending= theme= state=
##   QA_ISSUE … (repris du pilote de campagne)
## Usage :
##   XDG_DATA_HOME=$(mktemp -d) godot --headless --script res://tools/qa_boot.gd -- \
##     --qa-node=res://tests/qa_drivers/qa_m14_campaign.gd --autoplay --qa-seed=3 --qa-profile=loyal \
##     --qa-credits=3000 --qa-speed=10 [--qa-story] [--qa-load=…/current.json] [--qa-cin=auto|tap|hold]
extends "res://tools/qa_campaign.gd"

var _scene_id: int = 0
var _audio: AudioDirector = null
var _music: MusicDirector = null
var _bar_frame: int = -100
var _bar_count: int = 0
var _last_change_bar: int = 0
var _day_log: Dictionary = {}
var _mirror: Dictionary = {}
var _pa_times: Array[float] = []
var _game_t: float = 0.0
var _last_game_announce_t: float = -1000.0
var _cin_mode: String = "auto"
var _cin_seen: Dictionary = {}
var _cin_t0: float = 0.0
var _cin_node: CinematicScreen = null
var _cin_tap_left: float = 0.0
var _leave_t0: float = -1.0
var _leave_real0: int = 0
var _guard_x: float = 0.0
var _guard_moved_inspect: int = 0
var _guard_was_inspecting: bool = false
var _queue_mismatch: int = 0
var _queue_events: Array[String] = []
var _lost_ms: float = 0.0
var _last_real_usec: int = 0
var _ev06_seen: bool = false
var _subtitle_checks: int = 0
var _subtitle_ok: int = 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-cin="):
			_cin_mode = arg.trim_prefix("--qa-cin=")
	EventBus.ambient_announced.connect(_on_ambient)
	EventBus.hall_announced.connect(func(_k: String) -> void: _last_game_announce_t = _game_t)
	EventBus.station_event_started.connect(_on_event_started)
	EventBus.queue_progressed.connect(_on_queue)
	EventBus.discrepancy_checked.connect(_mirror_disc)
	EventBus.case_resolved.connect(func(_id: StringName, _r: CaseResult) -> void: _mirror["resolved_bar"] = _bar_count)
	EventBus.quota_changed.connect(func(u: int, m: int) -> void:
		_mirror["quota_used"] = u
		_mirror["quota_max"] = m)
	EventBus.station_event_ended.connect(func(_p: StationEventPlan) -> void: _mirror["event_w"] = 0.0)
	EventBus.day_started.connect(_on_day_started_obs)
	super._ready()


func _process(delta: float) -> void:
	super._process(delta)
	var now: int = Time.get_ticks_usec()
	var real_dt: float = (now - _last_real_usec) / 1_000_000.0 if _last_real_usec > 0 else 0.0
	_last_real_usec = now
	var scene: DayScene = get_tree().current_scene as DayScene
	if scene == null or not is_instance_valid(scene):
		return
	if scene.get_instance_id() != _scene_id:
		_attach(scene)
	_watch_leave(scene)
	if get_tree().paused:
		return
	_game_t += delta
	if _music != null and is_instance_valid(_music) and _music.is_playing() and real_dt > 0.25:
		_lost_ms += (real_dt - 0.25) * 1000.0
	_watch_mirror()
	_watch_guards(scene)
	_watch_cinematic(scene, delta)


func _attach(scene: DayScene) -> void:
	_scene_id = scene.get_instance_id()
	_audio = scene.find_child("AudioDirector", true, false) as AudioDirector
	_music = _audio.music if _audio != null else null
	_bar_count = 0
	_last_change_bar = 0
	_leave_t0 = -1.0
	if _music != null:
		_music.bar_passed.connect(func(_i: int) -> void:
			_bar_frame = Engine.get_process_frames()
			_bar_count += 1)
		_music.level_changed.connect(_on_level)
	scene.tree_exiting.connect(_on_scene_exit.bind(scene), CONNECT_ONE_SHOT)


func _on_day_started_obs(day: DayDef, _rules: Array[RulebookEntry]) -> void:
	_flush_day()
	_day_log = {"day": day.day_number if day != null else 0, "levels": {}, "offbar": 0, "bad_step": 0, "fast_up": 0,
		"fast_down": 0, "story_cap": 0, "max_shift": -1, "changes": 0, "pa": [], "mirror_n": 0, "mirror_diff": 0,
		"t0": _game_t, "story": GameState.is_story_mode(), "power_low": 0, "power_n": 0, "insp_n": 0, "insp_bad": 0}
	_mirror = {"queue": -1, "disc": 0, "quota_used": 0, "quota_max": day.air_quota if day != null else 0, "event_w": 0.0,
		"tension": day.music_tension if day != null else 0, "resolved_bar": -1}
	_pa_times.clear()
	_lost_ms = 0.0
	_guard_moved_inspect = 0
	_queue_mismatch = 0
	_ev06_seen = false
	_queue_events.clear()


func _flush_day() -> void:
	if _day_log.is_empty():
		return
	var d: Dictionary = _day_log
	var gaps: Array[float] = []
	for i: int in range(1, _pa_times.size()):
		gaps.append(_pa_times[i] - _pa_times[i - 1])
	print("QA14_DAYMUSIC day=%d story=%s max_shift=%d changes=%d hist=%s offbar=%d bad_step=%d fast_up=%d fast_down=%d story_cap=%d lost_ms=%.0f power=%d/%d insp=%d/%d" % [
			d["day"], d["story"], d["max_shift"], d["changes"], d["levels"], d["offbar"], d["bad_step"], d["fast_up"],
			d["fast_down"], d["story_cap"], _lost_ms, d["power_low"], d["power_n"], d["insp_bad"], d["insp_n"]])
	print("QA14_MIRROR day=%d samples=%d diff=%d" % [d["day"], d["mirror_n"], d["mirror_diff"]])
	print("QA14_PADAY day=%d count=%d first=%.0f gaps=%s" % [d["day"], _pa_times.size(),
			(_pa_times[0] - float(d["t0"])) if not _pa_times.is_empty() else -1.0, gaps])
	print("QA14_QUEUE day=%d events=%s mismatch=%d ev06=%s" % [d["day"], " ".join(_queue_events), _queue_mismatch, _ev06_seen])
	print("QA14_GUARD day=%d moved_while_inspecting=%d" % [d["day"], _guard_moved_inspect])
	_day_log = {}


# --- Musique --------------------------------------------------------------------

func _on_level(lv: int) -> void:
	if _day_log.is_empty() or _audio == null:
		return
	var state: StringName = _audio.music_state
	var at_bar: bool = _bar_frame == Engine.get_process_frames()
	var since: int = _bar_count - _last_change_bar
	var prev: int = int(_day_log.get("prev_level", -2))
	_day_log["prev_level"] = lv
	_last_change_bar = _bar_count
	var it: MusicIntensity = _audio.intensity
	print("QA14_LEVEL day=%d t=%.1f lv=%d prev=%d state=%s bar=%d at_bar=%s since_bars=%d q=%d ratio=%.2f disc=%d quota=%d/%d ev=%.2f tens=%d floor=%d cap=%s stable=%s pd=%s insp=%s sm=%.2f" % [
			_day_log["day"], _game_t - float(_day_log["t0"]), lv, prev, state, _bar_count, at_bar, since, it.queue_remaining,
			it.elapsed_ratio, it.discrepancies, it.quota_used, it.quota_max, it.event_weight, it.tension, it.floor_level,
			it.capped, it.stable, it.power_down, it.inspection_reduce, it.smoothed])
	if state != &"shift":
		return
	_day_log["changes"] = int(_day_log["changes"]) + 1
	var levels: Dictionary = _day_log["levels"]
	levels[lv] = int(levels.get(lv, 0)) + 1
	_day_log["max_shift"] = maxi(int(_day_log["max_shift"]), lv)
	if prev < 0:
		return # entrée du shift (exposé → N0)
	if not at_bar:
		_day_log["offbar"] = int(_day_log["offbar"]) + 1
	if absi(lv - prev) != 1:
		_day_log["bad_step"] = int(_day_log["bad_step"]) + 1
	if lv > prev and since < MusicDirector.BARS_PER_STEP_UP:
		_day_log["fast_up"] = int(_day_log["fast_up"]) + 1
	if lv < prev and since < MusicDirector.BARS_PER_STEP_DOWN:
		_day_log["fast_down"] = int(_day_log["fast_down"]) + 1
	if bool(_day_log["story"]) and lv > MusicIntensity.STORY_MAX_LEVEL:
		_day_log["story_cap"] = int(_day_log["story_cap"]) + 1


## Miroir : intensité recalculée **depuis les seuls signaux publics** écoutés
## ici (file, discordances constatées, quota, événement, tension, chrono de
## l'AudioDirector), comparée à la valeur cible de l'AudioDirector.
func _mirror_disc(result: Discrepancy) -> void:
	if result != null and result.result == Discrepancy.Result.DISCORDANT:
		_mirror["disc"] = int(_mirror.get("disc", 0)) + 1
		_mirror["resolved_bar"] = -1


func _on_event_started(plan: StationEventPlan) -> void:
	_last_game_announce_t = _game_t
	if plan != null and plan.event != null and plan.event.id != AudioDirector.EVENT_POWER_CUT:
		_mirror["event_w"] = plan.event.music_weight
	if plan != null and plan.event != null and String(plan.event.id) == "ev_06":
		_ev06_seen = true


func _watch_mirror() -> void:
	if _day_log.is_empty() or _audio == null or _audio.music_state != &"shift":
		return
	var it: MusicIntensity = _audio.intensity
	var rb: int = int(_mirror.get("resolved_bar", -1))
	if rb >= 0 and _bar_count - rb >= MusicIntensity.DISCREPANCY_HOLD_BARS:
		_mirror["disc"] = 0
		_mirror["resolved_bar"] = -1
	if Engine.get_process_frames() % 30 != 0:
		return
	var t: float = MusicIntensity.clock_term(it.elapsed_ratio) if it.timed else 0.0
	var expect: float = MusicIntensity.formula(MusicIntensity.queue_term(int(_mirror["queue"])), t,
			MusicIntensity.discrepancy_term(int(_mirror["disc"])), MusicIntensity.quota_term(int(_mirror["quota_used"]),
			int(_mirror["quota_max"])), float(_mirror["event_w"]), MusicIntensity.tension_term(int(_mirror["tension"])))
	_day_log["mirror_n"] = int(_day_log["mirror_n"]) + 1
	if absf(expect - it.compute()) > 0.08: # tolérance : décalage d'une image sur la remise à zéro des discordances
		_day_log["mirror_diff"] = int(_day_log["mirror_diff"]) + 1
		if int(_day_log["mirror_diff"]) <= 3:
			print("QA14_MIRROR_DIFF day=%d expect=%.3f got=%.3f q=%d/%d disc=%d/%d quota=%d/%d ev=%.2f/%.2f" % [
					_day_log["day"], expect, it.compute(), _mirror["queue"], it.queue_remaining, _mirror["disc"],
					it.discrepancies, _mirror["quota_used"], it.quota_used, _mirror["event_w"], it.event_weight])
	# Coupure : L0 seule (power down) ; Inspection discrète : −6 dB, 3,5 kHz, sans mélodie.
	if it.power_down:
		_day_log["power_n"] = int(_day_log["power_n"]) + 1
		if _music.power_down and _audio.music_muffle() > 0.0 and _audio.music_muffle() <= AudioDirector.POWER_DOWN_CUTOFF_HZ + 1.0:
			_day_log["power_low"] = int(_day_log["power_low"]) + 1
	if it.inspection_reduce and not it.power_down:
		_day_log["insp_n"] = int(_day_log["insp_n"]) + 1
		var muffle: float = _audio.music_muffle()
		if not _music.mute_motif or muffle <= 0.0 or muffle > AudioDirector.INSPECTION_CUTOFF_HZ + 1.0:
			_day_log["insp_bad"] = int(_day_log["insp_bad"]) + 1


# --- Annonces d'ambiance -------------------------------------------------------------

func _on_ambient(key: String, dur: float) -> void:
	var day: int = GameState.current_day
	var text: String = UiText.t(key, "")
	var rel: float = _game_t - float(_day_log.get("t0", 0.0))
	_pa_times.append(_game_t)
	var issues: PackedStringArray = []
	if RegEx.create_from_string("R\\d+").search(text) != null:
		issues.append("code de règle")
	if _game_t - _last_game_announce_t < PaScheduler.GAME_GUARD_SEC:
		issues.append("annonce de jeu %.1f s avant" % (_game_t - _last_game_announce_t))
	if _audio != null and _audio.intensity.power_down:
		issues.append("pendant une coupure")
	if _audio != null and _audio._remaining_sec < PaScheduler.END_GUARD_SEC:
		issues.append("chrono %.0f s" % _audio._remaining_sec)
	# Sous-titre « [Haut-parleur] » (option sous-titres) — lu à l'image suivante.
	_check_subtitle.call_deferred(key)
	print("QA14_PA day=%d key=%s t=%.0f dur=%.1f issues=%s text=%s" % [day, key, rel, dur, issues, text])
	if not issues.is_empty():
		_issue("J%d : annonce %s (%s)" % [day, key, ", ".join(issues)])


func _check_subtitle(key: String) -> void:
	var scene: DayScene = get_tree().current_scene as DayScene
	var ui: ComparisonUI = scene.ui as ComparisonUI if scene != null else null
	if ui == null or ui.subtitles == null:
		return
	_subtitle_checks += 1
	var want: bool = Settings.subtitles
	var shown: bool = ui.subtitles.get_tag() == UiText.t("sub_pa_prefix", "[Haut-parleur]") \
			and ui.subtitles.get_text().contains(UiText.t(key, "§"))
	if shown == want:
		_subtitle_ok += 1
	else:
		_issue("J%d : sous-titre de %s %s (sous-titres %s)" % [GameState.current_day, key, "absent" if want else "affiché", want])


# --- File réelle, Gardes ------------------------------------------------------------

func _on_queue(processed: int, total: int, upcoming: Array[QueueSilhouette]) -> void:
	_mirror["queue"] = total - processed if total >= 0 else -1
	_queue_events.append("%d/%d" % [processed, total])
	var scene: DayScene = get_tree().current_scene as DayScene
	if scene == null or scene.booth == null or not is_instance_valid(scene.booth):
		return
	var queue: QueueImpostors = scene.booth.queue
	if queue == null:
		return
	# Contrôle à l'image suivante (la file applique le signal elle aussi).
	(func() -> void:
		if not is_instance_valid(queue):
			return
		var want: int = QueueSilhouette.visible_count(queue.processed, queue.total, queue.capacity())
		var shown: int = 0
		for index: int in queue.shown_indices():
			if index > queue.processed:
				shown += 1
		if queue.total >= 0 and shown != want:
			_queue_mismatch += 1
			print("QA14_QUEUE_MISMATCH day=%d processed=%d total=%d want=%d shown=%d" % [GameState.current_day, processed, total, want, shown])
		for s: QueueSilhouette in upcoming:
			for field: String in s.serialize():
				if not QueueSilhouette.FIELDS.has(field):
					_issue("J%d : champ de silhouette hors liste blanche %s" % [GameState.current_day, field])).call_deferred()


func _watch_guards(scene: DayScene) -> void:
	if scene.booth == null or not is_instance_valid(scene.booth):
		return
	var guards: HallGuards = scene.booth.hall_guards
	if guards == null:
		return
	var x: float = guards.patrol_x
	var insp: bool = guards.inspecting and scene.day_controller != null \
			and scene.day_controller.phase == DayPhase.Kind.INSPECTING
	if insp and _guard_was_inspecting and not is_equal_approx(x, _guard_x):
		_guard_moved_inspect += 1
	_guard_was_inspecting = insp
	_guard_x = x


# --- Cinématiques ---------------------------------------------------------------------

func _watch_cinematic(scene: DayScene, delta: float) -> void:
	var cin: CinematicScreen = scene.screen as CinematicScreen if is_instance_valid(scene.screen) else null
	if cin == null:
		if _cin_node != null and not is_instance_valid(_cin_node):
			_cin_node = null
		var end: EndScreen = scene.screen as EndScreen if is_instance_valid(scene.screen) else null
		if end != null and not _cin_seen.has(end.get_instance_id()):
			_cin_seen[end.get_instance_id()] = true
			_report_end.call_deferred(end)
		return
	if not _cin_seen.has(cin.get_instance_id()):
		_cin_seen[cin.get_instance_id()] = true
		_cin_node = cin
		_cin_t0 = _game_t
		cin.finished.connect(_on_cin_finished.bind(cin, scene), CONNECT_ONE_SHOT)
		_report_cin_start.call_deferred(cin, scene)
		if _cin_mode == "hold":
			_press(&"cancel", true)
		_cin_tap_left = 1.0
	if _cin_mode == "tap" and cin.phase != CinematicScreen.Phase.DONE:
		_cin_tap_left -= delta
		if _cin_tap_left <= 0.0:
			_cin_tap_left = 1.0
			_press(&"ui_accept", true)
			_press(&"ui_accept", false)


func _press(action: StringName, pressed: bool) -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	get_viewport().push_input(ev)


func _report_cin_start(cin: CinematicScreen, scene: DayScene) -> void:
	if not is_instance_valid(cin):
		return
	var flags: Dictionary[StringName, Variant] = GameState.narrative_flags
	var act: int = EpilogueService.act_of(flags)
	var plates: PackedStringArray = []
	var captions: PackedStringArray = []
	var figures: PackedStringArray = []
	var bad: PackedStringArray = []
	var epilogue: bool = cin.def != null and cin.def.is_epilogue()
	for plate: PlateDef in cin.plates:
		plates.append(String(plate.id))
		var key: String = CinematicService.caption_key(plate, cin.ctx)
		captions.append(key)
		if not UiText.has(key):
			bad.append("légende %s absente" % key)
		if not epilogue and plate.min_act > act:
			bad.append("planche %s (acte ≥ %d) dans une fin de l'acte %d" % [plate.id, plate.min_act, act])
		for slot: FigureSlotDef in plate.figures:
			if slot == null:
				continue
			var face: PassengerAppearance = CinematicService.figure_appearance(slot, cin.memory, cin.ctx)
			var src: String = "silhouette"
			if face != null:
				for candidate: ConditionalKey in slot.memory_cases:
					if candidate != null and FlagCondition.check(candidate.condition, cin.ctx) and cin.memory.has(candidate.key):
						var entry: Dictionary = cin.memory[candidate.key]
						src = "visage:%s:%s" % [candidate.key, entry.get("visor", "?")]
						break
			figures.append("%s/%s=%s" % [plate.id, slot.id, src])
	var paused: bool = scene.booth != null and is_instance_valid(scene.booth) and scene.booth.is_rendering_paused()
	print("QA14_CIN id=%s ending=%s variant=%s act=%d day=%d plates=%s captions=%s figures=%s title=%s seen=%s total=%.1f theme=%s state=%s paused=%s" % [
			cin.def.id if cin.def != null else "?", cin.ending, cin.variant, act, GameState.current_day, ",".join(plates),
			",".join(captions), ",".join(figures), cin.has_title_card(), cin.already_seen, cin.total_duration(),
			_audio.theme_id if _audio != null else "", _audio.music_state if _audio != null else "", paused])
	if cin.plates.size() < CinematicService.MIN_PLATES or cin.plates.size() > CinematicService.MAX_PLATES:
		bad.append("%d planches" % cin.plates.size())
	if not paused:
		bad.append("bande 3D non suspendue")
	for b: String in bad:
		_issue("cinématique %s : %s" % [cin.def.id if cin.def != null else "?", b])


func _on_cin_finished(skipped: bool, cin: CinematicScreen, scene: DayScene) -> void:
	if _cin_mode == "hold":
		_press(&"cancel", false)
	var paused_after: bool = scene.booth != null and is_instance_valid(scene.booth) and scene.booth.is_rendering_paused()
	print("QA14_CIN_DONE id=%s skipped=%s game_sec=%.1f seen_in_profile=%s booth_paused_after=%s" % [
			cin.def.id if cin.def != null else "?", skipped, _game_t - _cin_t0,
			ProfileService.has_seen_cinematic(ProfileService.load_profile(), String(cin.def.id)) if cin.def != null else false,
			paused_after])


func _report_end(end: EndScreen) -> void:
	await get_tree().create_timer(0.5).timeout
	if _audio == null or not is_instance_valid(_audio):
		return
	print("QA14_END ending=%s theme=%s state=%s clip=%s" % [end.ending, _audio.theme_id, _audio.music_state,
			_music.get_current_clip() if _music != null else ""])


# --- Fondus de sortie -------------------------------------------------------------------

var _leave_min_db: float = 0.0
var _leave_last_db: float = 0.0
var _leave_last_playing: bool = false
var _leave_muffle: float = -1.0


func _watch_leave(scene: DayScene) -> void:
	if scene.leaving and _leave_t0 < 0.0:
		_leave_t0 = _game_t
		_leave_real0 = Time.get_ticks_msec()
		_leave_min_db = 0.0
	if scene.leaving:
		_leave_last_db = MusicDirector.get_fade_db()
		_leave_min_db = minf(_leave_min_db, _leave_last_db)
		_leave_last_playing = _music != null and is_instance_valid(_music) and _music.is_playing()
		if _audio != null and is_instance_valid(_audio):
			_leave_muffle = _audio.music_muffle()


func _on_scene_exit(scene: DayScene) -> void:
	print("QA14_FADE day=%d via_game=%s last_fade_db=%.1f min_fade_db=%.1f playing_last=%s muffle=%.0f game_sec=%.2f real_ms=%d screen=%s" % [
			GameState.current_day, scene.leaving, _leave_last_db, _leave_min_db, _leave_last_playing, _leave_muffle,
			(_game_t - _leave_t0) if _leave_t0 >= 0.0 else -1.0,
			(Time.get_ticks_msec() - _leave_real0) if _leave_t0 >= 0.0 else -1,
			scene.screen_history[-1] if not scene.screen_history.is_empty() else ""])
	_flush_day()


func _finish(code: int) -> void:
	_flush_day()
	print("QA14_SUBTITLES checks=%d ok=%d" % [_subtitle_checks, _subtitle_ok])
	super._finish(code)
