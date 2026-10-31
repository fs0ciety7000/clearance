## Passe QA M14 (docs/QA.md §17) — une fin jouée par le vrai chemin de
## `DayScene.show_end` (`--screen=end --ending=… --flags=…`, `user://` jetable) :
## sélection de la séquence, planches retenues, légendes **lues**, figures
## (visage de la partie ou silhouette), thème, bande 3D en pause, durée de la
## séquence en avance automatique (temps de jeu), puis l'écran de fin, la
## musique sous l'écran de fin et `cinematics_seen` au profil.
##   XDG_DATA_HOME=$(mktemp -d) godot --headless --script res://tools/qa_boot.gd -- \
##     --qa-node=res://tests/qa_drivers/qa_m14_cin.gd --day=29 --seed=3 --screen=end --ending=f1_arrested \
##     --flags=act2_started,act3_started,deposition_arrested [--qa-speed=8] [--qa-manual]
## Sorties : QA14C_CIN, QA14C_PLATE, QA14C_DONE, QA14C_END, QA14C_NONE, QA_ISSUE.
extends Node

var _speed: float = 8.0
var _t: float = 0.0
var _t0: float = -1.0
var _cin: CinematicScreen = null
var _done: bool = false
var _start_msec: int = 0
var _last_index: int = -99
var _manual: bool = false
var _manual_wait: float = 0.0
var _last_usec: int = 0
var _max_ms: float = 0.0
var _frames_ms: PackedFloat32Array = []
var _vram0: float = -1.0
var _vram_max: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-speed="):
			_speed = arg.trim_prefix("--qa-speed=").to_float()
		elif arg == "--qa-manual":
			_manual = true
			Settings.set_session_value(Settings.KEY_CINEMATIC_ADVANCE, Settings.CINEMATIC_MANUAL)
	Engine.time_scale = _speed
	_start_msec = Time.get_ticks_msec()
	get_tree().change_scene_to_file("res://scenes/main/day.tscn")


func _process(delta: float) -> void:
	if _done:
		return
	if Time.get_ticks_msec() - _start_msec > 200_000:
		print("QA_ISSUE délai dépassé")
		_finish()
		return
	var scene: DayScene = get_tree().current_scene as DayScene
	if scene == null:
		return
	_t += delta
	var now: int = Time.get_ticks_usec()
	if _cin != null and is_instance_valid(_cin) and _last_usec > 0:
		var ms: float = (now - _last_usec) / 1000.0
		_frames_ms.append(ms)
		_max_ms = maxf(_max_ms, ms)
		var tex: float = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
		_vram_max = maxf(_vram_max, tex)
	_last_usec = now
	var screen: ScreenBase = scene.screen if is_instance_valid(scene.screen) else null
	if screen is CinematicScreen and _cin == null:
		_cin = screen as CinematicScreen
		_t0 = _t
		_vram0 = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
		_report(scene)
		_cin.finished.connect(func(skipped: bool) -> void:
			var sorted: PackedFloat32Array = _frames_ms.duplicate()
			sorted.sort()
			print("QA14C_DONE skipped=%s game_sec=%.1f expected=%.1f frames=%d p95_ms=%.1f max_ms=%.1f tex_before_mb=%.1f tex_max_mb=%.1f" % [
					skipped, _t - _t0, _cin_total, sorted.size(), sorted[int(sorted.size() * 0.95)] if sorted.size() > 20 else -1.0,
					_max_ms, _vram0, _vram_max]))
	if _cin != null and is_instance_valid(_cin) and _cin.index != _last_index:
		_last_index = _cin.index
		if _cin.index >= 0:
			var plate: PlateDef = _cin.plates[_cin.index]
			print("QA14C_PLATE t=%.1f n=%d id=%s tex_mb=%.1f max_frame_ms=%.1f caption=%s" % [_t - _t0, _cin.index + 1, plate.id,
					Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, _max_ms,
					CinematicScreen.caption_text(plate, _cin.ctx)])
	if _manual and _cin != null and is_instance_valid(_cin):
		# Avance manuelle : rien ne doit avancer seul ; un appui toutes les 12 s de jeu.
		_manual_wait += delta
		if _manual_wait >= 12.0:
			_manual_wait = 0.0
			_cin.request_next()
	if screen is EndScreen:
		_end(scene, screen as EndScreen)
	elif _cin == null and _t > 20.0 and screen == null:
		print("QA14C_NONE screen_history=%s" % [scene.screen_history])
		_finish()


var _cin_total: float = 0.0


func _report(scene: DayScene) -> void:
	var flags: Dictionary[StringName, Variant] = GameState.narrative_flags
	var act: int = EpilogueService.act_of(flags)
	_cin_total = _cin.total_duration()
	var figures: PackedStringArray = []
	var issues: PackedStringArray = []
	for plate: PlateDef in _cin.plates:
		if plate.min_act > act:
			issues.append("planche %s d'acte ≥ %d dans une fin de l'acte %d" % [plate.id, plate.min_act, act])
		var cap: String = CinematicScreen.caption_text(plate, _cin.ctx)
		if cap.is_empty():
			issues.append("légende vide %s" % plate.id)
		elif cap.length() > PlateDef.CAPTION_MAX_CHARS:
			issues.append("légende %s : %d caractères" % [plate.id, cap.length()])
		for slot: FigureSlotDef in plate.figures:
			var face: PassengerAppearance = CinematicService.figure_appearance(slot, _cin.memory, _cin.ctx)
			figures.append("%s/%s=%s" % [plate.id, slot.id, "visage" if face != null else "silhouette"])
	var paused: bool = scene.booth != null and is_instance_valid(scene.booth) and scene.booth.is_rendering_paused()
	if not paused:
		issues.append("bande 3D non suspendue")
	if _cin.plates.size() < CinematicService.MIN_PLATES or _cin.plates.size() > CinematicService.MAX_PLATES:
		issues.append("%d planches" % _cin.plates.size())
	var audio: AudioDirector = scene.find_child("AudioDirector", true, false) as AudioDirector
	print("QA14C_CIN id=%s ending=%s variant=%s act=%d plates=%d title=%s eyebrow=%s total=%.1f figures=%s theme=%s state=%s" % [
			_cin.def.id, _cin.ending, _cin.variant, act, _cin.plates.size(), _cin.title_text, _cin.eyebrow_text, _cin_total,
			",".join(figures), audio.theme_id if audio != null else "", audio.music_state if audio != null else ""])
	for i: String in issues:
		print("QA_ISSUE %s : %s" % [_cin.def.id, i])


func _end(scene: DayScene, end: EndScreen) -> void:
	_done = true
	await get_tree().create_timer(1.0).timeout
	var audio: AudioDirector = scene.find_child("AudioDirector", true, false) as AudioDirector
	var prof: Dictionary = ProfileService.load_profile()
	print("QA14C_END ending=%s theme=%s state=%s clip=%s cin_seen=%s booth_paused=%s history=%s" % [end.ending,
			audio.theme_id if audio != null else "", audio.music_state if audio != null else "",
			audio.music.get_current_clip() if audio != null else "", prof.get("cinematics_seen", []),
			scene.booth.is_rendering_paused() if scene.booth != null and is_instance_valid(scene.booth) else false,
			scene.screen_history])
	_done = false
	_finish()


func _finish() -> void:
	_done = true
	Engine.time_scale = 1.0
	SaveService.delete_slot(SaveService.DEFAULT_SLOT)
	var barrier: Node = get_tree().root.get_node_or_null("AudioMixBarrier")
	if barrier != null:
		barrier.call(&"quit_after_silence", 0)
	else:
		get_tree().quit(0)
