## Passe QA M14 (docs/QA.md §17) — transitions musicales **en temps réel**
## (`Engine.time_scale` = 1 : le fondu `Fade` compte en temps réel, le
## minuteur de `DayScene` en temps de jeu ; les campagnes accélérées ne
## peuvent pas les juger). Échantillonne l'effet `Fade` du bus Music, le
## passe-bas `Muffle`, le clip en cours et l'état de l'`AudioDirector` à chaque
## image, du début à la fin du scénario.
##
## Scénarios (`--qa-scenario=`) :
##   evening : `--day=N --seed=S --screen=evening` → soirée confirmée → « jour
##             suivant » réel (`reload_after_music_fade`) → briefing du jour suivant
##   end     : `--day=30 --seed=S --screen=end --ending=<fin> [--flags=…]` →
##             cinématique (thème après le fondu de 2 s) ; `--qa-skip-at=N` :
##             maintien Ⓑ à la planche N (queue à la mesure suivante) ;
##             écran de fin → « TITRE » réel (`go_to_title`) → titre (`TitleMusic`)
## Sorties : QA14T_FRAME (échantillons espacés), QA14T_MARK (événements), QA14T_RESULT.
extends Node

var _scenario: String = "evening"
var _skip_at: int = -1
var _t0: int = 0
var _last_fade: float = 999.0
var _last_clip: StringName = &""
var _last_state: StringName = &""
var _last_muffle: float = -2.0
var _marks: Array[String] = []
var _phase: String = "start"
var _leave_ms: int = -1
var _scene_ms: int = -1
var _fade_at_exit: float = 0.0
var _min_fade_leaving: float = 0.0
var _done: bool = false
var _handled: Dictionary = {}
var _title_ms: int = -1
var _holding: bool = false
var _scene_id: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-scenario="):
			_scenario = arg.trim_prefix("--qa-scenario=")
		elif arg.begins_with("--qa-skip-at="):
			_skip_at = arg.trim_prefix("--qa-skip-at=").to_int()
	_t0 = Time.get_ticks_msec()
	get_tree().node_added.connect(_on_node_added)
	get_tree().change_scene_to_file("res://scenes/main/day.tscn")


func _ms() -> int:
	return Time.get_ticks_msec() - _t0


func _mark(text: String) -> void:
	var line: String = "QA14T_MARK ms=%d %s" % [_ms(), text]
	_marks.append(line)
	print(line)


func _on_node_added(node: Node) -> void:
	if node is CinematicScreen:
		_mark("cinematic_open")
	elif node is EndScreen:
		_mark("end_screen_open")
	elif node.name == &"TitleMusic":
		_mark("title_music_added")


func _process(_delta: float) -> void:
	if _done:
		return
	if _ms() > 280_000:
		_mark("timeout")
		_finish()
		return
	var tree: SceneTree = get_tree()
	var scene: Node = tree.current_scene
	if scene == null:
		return
	if scene.get_instance_id() != _scene_id:
		_scene_id = scene.get_instance_id()
		_mark("scene %s" % scene.scene_file_path.get_file())
		if _leave_ms >= 0 and _scene_ms < 0:
			_scene_ms = _ms()
			_mark("scene_changed after_leave_ms=%d fade_at_exit=%.1f min_fade=%.1f" % [_scene_ms - _leave_ms, _fade_at_exit, _min_fade_leaving])
	var fade: float = MusicDirector.get_fade_db()
	var day: DayScene = scene as DayScene
	var audio: AudioDirector = day.find_child("AudioDirector", true, false) as AudioDirector if day != null else null
	var music: MusicDirector = audio.music if audio != null else scene.find_child("TitleMusic", true, false) as MusicDirector
	var clip: StringName = music.get_current_clip() if music != null else &""
	var state: StringName = audio.music_state if audio != null else &"title"
	var muffle: float = audio.music_muffle() if audio != null else 0.0
	if absf(fade - _last_fade) > 3.0 or clip != _last_clip or state != _last_state or not is_equal_approx(muffle, _last_muffle):
		print("QA14T_FRAME ms=%d fade=%.1f clip=%s state=%s muffle=%.0f playing=%s level=%d theme=%s paused=%s" % [_ms(), fade,
				clip, state, muffle, music.is_playing() if music != null else false, music.level if music != null else -9,
				audio.theme_id if audio != null else &"", tree.paused])
		_last_fade = fade
		_last_clip = clip
		_last_state = state
		_last_muffle = muffle
	if day != null and day.leaving:
		if _leave_ms < 0:
			_leave_ms = _ms()
			_mark("leaving fade=%.1f" % fade)
		_fade_at_exit = fade
		_min_fade_leaving = minf(_min_fade_leaving, fade)
	if day != null:
		_drive_day(day)
	elif scene.name == &"Main" or scene.scene_file_path.ends_with("main.tscn"):
		if _title_ms < 0:
			_title_ms = _ms()
		if _ms() - _title_ms > 4000:
			var tm: MusicDirector = scene.find_child("TitleMusic", true, false) as MusicDirector
			_mark("title groups=%s clip=%s fade=%.1f playing=%s" % [tm.groups if tm != null else [], tm.get_current_clip() if tm != null else &"",
					fade, tm.is_playing() if tm != null else false])
			_finish()


func _drive_day(day: DayScene) -> void:
	var screen: ScreenBase = day.screen
	if screen == null or not is_instance_valid(screen) or screen.is_closing():
		if day.briefing != null and is_instance_valid(day.briefing) and _phase == "reloaded":
			# Nouveau jour : briefing (exposé) au bout de 4 s, fin du scénario.
			if _ms() - _scene_ms > 4000:
				_mark("briefing fade=%.1f clip=%s" % [MusicDirector.get_fade_db(), _last_clip])
				_finish()
		return
	var id: int = screen.get_instance_id()
	if screen is EveningScreen and not _handled.has(id):
		_handled[id] = true
		_drive_evening.call_deferred(screen as EveningScreen)
	elif screen is CinematicScreen:
		var cin: CinematicScreen = screen as CinematicScreen
		if _skip_at > 0 and not _holding and cin.index + 1 >= _skip_at and cin.phase == CinematicScreen.Phase.PLATES:
			_holding = true
			_mark("hold_start plate=%d" % (cin.index + 1))
			_press(&"cancel", true)
		if not _handled.has(id):
			_handled[id] = true
			cin.finished.connect(func(skipped: bool) -> void:
				_mark("cinematic_finished skipped=%s" % skipped)
				if _holding:
					_press(&"cancel", false))
	elif screen is EndScreen and not _handled.has(id):
		_handled[id] = true
		_mark("end ending=%s" % (screen as EndScreen).ending)
		_end_to_title.call_deferred(screen as EndScreen)


func _drive_evening(evening: EveningScreen) -> void:
	await get_tree().create_timer(3.0).timeout
	evening.confirm()
	await get_tree().create_timer(1.0).timeout
	var button: Button = evening.get_report_button()
	_mark("evening_next")
	_phase = "reloaded"
	if button != null:
		button.pressed.emit()


func _end_to_title(end: EndScreen) -> void:
	await get_tree().create_timer(8.0).timeout
	if not is_instance_valid(end):
		return
	_mark("end_to_title")
	end.close(&"title")


func _press(action: StringName, pressed: bool) -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	get_viewport().push_input(ev)


func _finish() -> void:
	if _done:
		return
	_done = true
	print("QA14T_RESULT scenario=%s leave_to_scene_ms=%d fade_at_exit=%.1f min_fade_leaving=%.1f" % [_scenario,
			(_scene_ms - _leave_ms) if _leave_ms >= 0 and _scene_ms >= 0 else -1, _fade_at_exit, _min_fade_leaving])
	SaveService.delete_slot(SaveService.DEFAULT_SLOT)
	var barrier: Node = get_tree().root.get_node_or_null("AudioMixBarrier")
	if barrier != null:
		barrier.call(&"quit_after_silence", 0)
	else:
		get_tree().quit(0)
