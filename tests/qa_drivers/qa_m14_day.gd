## Passe QA M14 (docs/QA.md §17) — **une vraie journée sans bot** (`day.tscn`,
## booth 3D, vraie `ComparisonUI`) : le briefing est fermé comme un joueur, puis
## le passager reste à la vitre jusqu'à la sirène. Mesure ce que le bot de
## campagne ne peut pas voir (il vide la file en moins d'une minute) :
## annonces d'ambiance (fréquence, exclusions, sous-titres), montée de
## l'intensité avec le chrono, chrono critique (N4 sans mélodie), coupure
## EV-05, grève du J20, plafond Récit, option Stable, Mode Inspection.
## Lit l'état public des nœuds ; ne modifie rien du jeu (réglages de session
## seulement, jamais persistés).
##
## Usage (racine du projet, `user://` jetable) :
##   XDG_DATA_HOME=$(mktemp -d) godot --headless --script res://tools/qa_boot.gd -- \
##     --qa-node=res://tests/qa_drivers/qa_m14_day.gd --day=8 --seed=7 [--story] \
##     [--qa-speed=8] [--qa-subs=0] [--qa-stable] [--qa-inspect=on|off|toggle] [--qa-normal-inspect]
## Sorties : QA14D_LEVEL, QA14D_PA, QA14D_ANN (annonce de jeu), QA14D_EVENT,
## QA14D_CRIT, QA14D_SUMMARY, QA_ISSUE.
extends Node

const DAY_SCENE: String = "res://scenes/main/day.tscn"
const TIMEOUT_MSEC: int = 540_000

var _speed: float = 8.0
var _inspect: String = "off"
var _t: float = 0.0
var _shift_t0: float = -1.0
var _audio: AudioDirector = null
var _music: MusicDirector = null
var _scene_id: int = 0
var _bar_frame: int = -100
var _bars: int = 0
var _last_change_bar: int = 0
var _prev: int = -2
var _issues: PackedStringArray = []
var _pa: Array[Dictionary] = []
var _game_ann_t: float = -1000.0
var _levels: Dictionary = {}
var _max: int = -1
var _bad: Dictionary = {"offbar": 0, "step": 0, "fast_up": 0, "fast_down": 0, "cap": 0}
var _crit_seen: bool = false
var _crit_ok: bool = false
var _power: Dictionary = {"n": 0, "ok": 0}
var _insp: Dictionary = {"n": 0, "ok": 0}
var _toggle_left: float = 6.0
var _started_msec: int = 0
var _done: bool = false
var _story: bool = false
var _lost_ms: float = 0.0
var _last_usec: int = 0
var _real_at: float = -1.0
var _max_sec: float = -1.0
var _follow: float = 0.0
var _following: bool = false
var _follow_last: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-speed="):
			_speed = maxf(arg.trim_prefix("--qa-speed=").to_float(), 1.0)
		elif arg == "--qa-subs=0":
			Settings.set_session_value(Settings.KEY_SUBTITLES, false)
		elif arg == "--qa-stable":
			Settings.set_session_value(Settings.KEY_MUSIC_DYNAMICS, Settings.MUSIC_STABLE)
		elif arg == "--qa-normal-inspect":
			Settings.set_session_value(Settings.KEY_MUSIC_INSPECTION_REDUCE, false)
		elif arg.begins_with("--qa-inspect="):
			_inspect = arg.trim_prefix("--qa-inspect=")
		elif arg.begins_with("--qa-follow="):
			_follow = arg.trim_prefix("--qa-follow=").to_float()
		elif arg.begins_with("--qa-max-sec="):
			_max_sec = arg.trim_prefix("--qa-max-sec=").to_float()
		elif arg.begins_with("--qa-real-at="):
			_real_at = arg.trim_prefix("--qa-real-at=").to_float()
		elif arg == "--story":
			_story = true
	EventBus.ambient_announced.connect(_on_ambient)
	EventBus.hall_announced.connect(func(k: String) -> void:
		_game_ann_t = _t
		print("QA14D_ANN t=%.0f key=%s" % [_rel(), k]))
	EventBus.station_event_started.connect(func(plan: StationEventPlan) -> void:
		_game_ann_t = _t
		print("QA14D_EVENT t=%.0f start=%s" % [_rel(), plan.event.id if plan != null and plan.event != null else "?"]))
	EventBus.station_event_ended.connect(func(plan: StationEventPlan) -> void:
		print("QA14D_EVENT t=%.0f end=%s" % [_rel(), plan.event.id if plan != null and plan.event != null else "?"]))
	EventBus.day_ended.connect(func(_s: DaySummary) -> void: _end_of_shift.call_deferred())
	Engine.time_scale = _speed
	_started_msec = Time.get_ticks_msec()
	get_tree().change_scene_to_file(DAY_SCENE)


func _rel() -> float:
	return _t - _shift_t0 if _shift_t0 >= 0.0 else -1.0


func _process(delta: float) -> void:
	if _done:
		return
	if Time.get_ticks_msec() - _started_msec > TIMEOUT_MSEC:
		_issue("délai dépassé")
		_finish()
		return
	var scene: DayScene = get_tree().current_scene as DayScene
	if scene == null:
		return
	if scene.get_instance_id() != _scene_id:
		_scene_id = scene.get_instance_id()
		_audio = scene.find_child("AudioDirector", true, false) as AudioDirector
		_music = _audio.music
		_music.bar_passed.connect(func(_i: int) -> void:
			_bar_frame = Engine.get_process_frames()
			_bars += 1)
		_music.level_changed.connect(_on_level)
	var now: int = Time.get_ticks_usec()
	if _last_usec > 0 and _music != null and _music.is_playing():
		var real_dt: float = (now - _last_usec) / 1_000_000.0
		if real_dt > 0.25:
			_lost_ms += (real_dt - 0.25) * 1000.0
	_last_usec = now
	if _following:
		_follow_tick(scene)
		return
	if get_tree().paused:
		return
	_t += delta
	if scene.briefing != null and is_instance_valid(scene.briefing) and scene.briefing.is_visible_in_tree() \
			and not scene.briefing.is_closing():
		scene.briefing.close()
	if is_instance_valid(scene.screen) and scene.screen.name == &"EpilogueIntro" and not scene.screen.is_closing():
		scene.screen.close(&"start")
	if _shift_t0 < 0.0 and _audio.music_state == &"shift":
		_shift_t0 = _t
	if _audio.music_state != &"shift":
		return
	if _max_sec > 0.0 and _rel() > _max_sec:
		_end_of_shift()
		return
	if _real_at > 0.0 and Engine.time_scale > 1.0 and _audio.intensity.remaining_sec <= _real_at:
		Engine.time_scale = 1.0
		print("QA14D_REALTIME t=%.0f rem=%.0f" % [_rel(), _audio.intensity.remaining_sec])
	_drive_inspection(scene, delta)
	if Engine.get_process_frames() % 20 == 0:
		_sample()


func _drive_inspection(scene: DayScene, delta: float) -> void:
	var ui: ComparisonUI = scene.ui as ComparisonUI
	if ui == null or scene.day_controller.phase != DayPhase.Kind.INSPECTING:
		return
	match _inspect:
		"on":
			if not _audio._inspecting:
				ui.set_inspection_active(true)
		"toggle":
			_toggle_left -= delta
			if _toggle_left <= 0.0:
				_toggle_left = 6.0
				ui.set_inspection_active(not _audio._inspecting)


func _sample() -> void:
	var it: MusicIntensity = _audio.intensity
	if it.power_down:
		_power["n"] += 1
		if _music.power_down and _audio.music_muffle() > 0.0 and _audio.music_muffle() <= AudioDirector.POWER_DOWN_CUTOFF_HZ + 1.0:
			_power["ok"] += 1
	elif _audio._inspecting:
		_insp["n"] += 1
		var reduce: bool = Settings.get_bool(Settings.KEY_MUSIC_INSPECTION_REDUCE)
		var muffled: bool = _audio.music_muffle() > 0.0 and _audio.music_muffle() <= AudioDirector.INSPECTION_CUTOFF_HZ + 1.0
		var ok: bool = (_music.mute_motif and muffled and _audio.duck_db(AudioBuses.MUSIC) <= -5.0) if reduce \
				else (not muffled and not it.inspection_reduce)
		if ok:
			_insp["ok"] += 1
	if it.timed and it.remaining_sec <= MusicIntensity.CRITICAL_SEC and it.remaining_sec > 2.0 and not it.capped \
			and not it.power_down:
		_crit_seen = true
		if _music.level == 4 and _music.mute_motif:
			_crit_ok = true


func _on_level(lv: int) -> void:
	var at_bar: bool = _bar_frame == Engine.get_process_frames()
	var since: int = _bars - _last_change_bar
	_last_change_bar = _bars
	var it: MusicIntensity = _audio.intensity
	var state: StringName = _audio.music_state
	print("QA14D_LEVEL t=%.0f lv=%d prev=%d state=%s at_bar=%s since_bars=%d q=%d ratio=%.2f rem=%.0f disc=%d quota=%d/%d ev=%.2f tens=%d floor=%d cap=%s stable=%s pd=%s insp=%s action=%s sm=%.2f" % [
			_rel(), lv, _prev, state, at_bar, since, it.queue_remaining, it.elapsed_ratio, it.remaining_sec, it.discrepancies,
			it.quota_used, it.quota_max, it.event_weight, it.tension, it.floor_level, it.capped, it.stable, it.power_down,
			it.inspection_reduce, it.action, it.smoothed])
	var prev: int = _prev
	_prev = lv
	if state != &"shift" or prev < 0:
		return
	_levels[lv] = int(_levels.get(lv, 0)) + 1
	_max = maxi(_max, lv)
	if not at_bar:
		_bad["offbar"] += 1
	if absi(lv - prev) != 1:
		_bad["step"] += 1
	if lv > prev and since < MusicDirector.BARS_PER_STEP_UP:
		_bad["fast_up"] += 1
	if lv < prev and since < MusicDirector.BARS_PER_STEP_DOWN:
		_bad["fast_down"] += 1
	if (_story or it.capped) and lv > MusicIntensity.STORY_MAX_LEVEL:
		_bad["cap"] += 1
	if it.stable and lv != MusicIntensity.STABLE_LEVEL and not it.power_down:
		_bad["cap"] += 1


func _on_ambient(key: String, dur: float) -> void:
	var text: String = UiText.t(key, "")
	var issues: PackedStringArray = []
	if RegEx.create_from_string("R\\d+").search(text) != null:
		issues.append("code de règle")
	if _t - _game_ann_t < PaScheduler.GAME_GUARD_SEC:
		issues.append("annonce de jeu %.1f s avant" % (_t - _game_ann_t))
	if _audio.intensity.power_down:
		issues.append("pendant une coupure")
	if _audio._remaining_sec < PaScheduler.END_GUARD_SEC:
		issues.append("chrono %.0f s" % _audio._remaining_sec)
	if _audio.is_voice_active():
		issues.append("bark en cours")
	_pa.append({"t": _rel(), "key": key})
	print("QA14D_PA t=%.0f key=%s dur=%.1f issues=%s text=%s" % [_rel(), key, dur, issues, text])
	_check_subtitle.call_deferred(key)
	for i: String in issues:
		_issue("annonce %s : %s" % [key, i])


func _check_subtitle(key: String) -> void:
	var scene: DayScene = get_tree().current_scene as DayScene
	var ui: ComparisonUI = scene.ui as ComparisonUI if scene != null else null
	if ui == null:
		return
	var want: bool = Settings.subtitles
	var tag: String = ui.subtitles.get_tag()
	var shown: bool = tag == UiText.t("sub_pa_prefix", "[Haut-parleur]") and ui.subtitles.get_text().contains(UiText.t(key, "§"))
	print("QA14D_SUB key=%s want=%s shown=%s tag=%s text=%s toasts=%d" % [key, want, shown, tag, ui.subtitles.get_text(),
			ui.toasts.get_child_count() if ui.toasts != null else -1])
	if shown != want:
		_issue("sous-titre de %s : attendu %s" % [key, want])


func _end_of_shift() -> void:
	var gaps: Array[float] = []
	for i: int in range(1, _pa.size()):
		gaps.append(snappedf(float(_pa[i]["t"]) - float(_pa[i - 1]["t"]), 0.1))
	var keys: PackedStringArray = []
	for p: Dictionary in _pa:
		keys.append(String(p["key"]))
	if _pa.size() > PaScheduler.MAX_PER_SHIFT and not _audio.pa_scheduler.garde:
		_issue("%d annonces > %d" % [_pa.size(), PaScheduler.MAX_PER_SHIFT])
	for g: float in gaps:
		if g < PaScheduler.GAP_MIN_SEC - 0.5:
			_issue("écart entre annonces %.1f s < %.0f" % [g, PaScheduler.GAP_MIN_SEC])
	if not _pa.is_empty() and (float(_pa[0]["t"]) < PaScheduler.FIRST_MIN_SEC - 0.5):
		_issue("première annonce à %.1f s" % float(_pa[0]["t"]))
	var dup: Dictionary = {}
	for k: String in keys:
		if dup.has(k):
			_issue("annonce répétée %s" % k)
		dup[k] = true
	if _crit_seen and not _crit_ok:
		_issue("chrono critique sans N4 ni mélodie coupée")
	print("QA14D_SUMMARY day=%d mode=%s story=%s stable=%s pa=%d first=%.0f gaps=%s keys=%s max_shift=%d hist=%s bad=%s crit=%s/%s power=%s insp=%s lost_ms=%.0f shift_sec=%.0f" % [
			GameState.current_day, _audio._day.mode if _audio._day != null else "?", _story, Settings.is_music_stable(), _pa.size(),
			float(_pa[0]["t"]) if not _pa.is_empty() else -1.0, gaps, ",".join(keys), _max, _levels, _bad, _crit_seen,
			_crit_ok, _power, _insp, _lost_ms, _rel()])
	if _follow > 0.0 and not _following:
		_following = true
		Engine.time_scale = 1.0
		get_tree().create_timer(_follow, true, false, true).timeout.connect(_finish)
		return
	_finish()


## Après la sirène : écrans plein cadre et état musical (cinématique, conclusion…).
func _follow_tick(scene: DayScene) -> void:
	var scr: String = String(scene.screen.name) if is_instance_valid(scene.screen) else "-"
	var line: String = "screen=%s state=%s clip=%s theme=%s fade=%.0f paused_booth=%s" % [scr, _audio.music_state,
			_music.get_current_clip(), _audio.theme_id, MusicDirector.get_fade_db(),
			scene.booth.is_rendering_paused() if scene.booth != null and is_instance_valid(scene.booth) else false]
	if line != _follow_last:
		_follow_last = line
		print("QA14D_FOLLOW ms=%d %s" % [Time.get_ticks_msec() - _started_msec, line])
	var cin: CinematicScreen = scene.screen as CinematicScreen if is_instance_valid(scene.screen) else null
	if cin != null and not cin.has_meta(&"qa_seen"):
		cin.set_meta(&"qa_seen", true)
		var figs: PackedStringArray = []
		for plate: PlateDef in cin.plates:
			for slot: FigureSlotDef in plate.figures:
				figs.append("%s/%s=%s" % [plate.id, slot.id, "visage" if CinematicService.figure_appearance(slot, cin.memory, cin.ctx) != null else "silhouette"])
		var plates: PackedStringArray = []
		for plate: PlateDef in cin.plates:
			plates.append("%s[%s]" % [plate.id, CinematicService.caption_key(plate, cin.ctx)])
		print("QA14D_CIN id=%s title_card=%s total=%.1f plates=%s figures=%s" % [cin.def.id, cin.has_title_card(),
				cin.total_duration(), ",".join(plates), ",".join(figs)])


func _issue(text: String) -> void:
	_issues.append(text)
	print("QA_ISSUE %s" % text)


func _finish() -> void:
	if _done:
		return
	_done = true
	Engine.time_scale = 1.0
	print("QA_DONE issues=%d" % _issues.size())
	SaveService.delete_slot(SaveService.DEFAULT_SLOT)
	var barrier: Node = get_tree().root.get_node_or_null("AudioMixBarrier")
	if barrier != null:
		barrier.call(&"quit_after_silence", 0)
	else:
		get_tree().quit(0)
