## Directeur audio du jour (docs/AUDIO.md §2, §4, §6, §11) — nœud de
## `day.tscn` (pas un autoload, ARCHITECTURE P6).
##
## Seul écouteur audio de l'`EventBus` : joue la cue sheet sur les bons bus
## (pools 2D à priorités : `VoicePool`), l'ambiance (boucles + one-shots
## aléatoires), la musique par état (fondus enchaînés) et les barks Tessar
## (`TessarVoice`, rendus dans un thread de travail puis joués par le
## `PassengerAudio` de l'acteur). Ducking musique/ambiance pendant une voix
## et au tampon via les effets `Duck` des bus.
##
## Branchements sans modifier le booth : un `PassengerAudio` est ajouté comme
## enfant de chaque acteur du pool (`BoothDirector.actors`) et un
## `AudioListener3D` est placé côté agent, derrière la vitre (le viewport du
## booth active son écoute 3D). Côté UI : signaux `EventBus`, signaux publics
## de `ComparisonUI` (`hovered`, `toast_shown`, `departure_line_shown`) et
## lecture de son état public (`selection.a`, `tool_bar.stamps`).
class_name AudioDirector
extends Node

## Une cue vient d'être jouée (tests, diagnostic).
signal cue_played(cue: StringName, bus: StringName)

const SFX_VOICES: int = 8
const WORLD_VOICES: int = 2
const UI_VOICES: int = 4
const AMBIENCE_VOICES: int = 2
const MUSIC_FADE_SEC: float = 2.5
const AMBIENCE_FADE_IN_SEC: float = 2.0
const AMBIENCE_FADE_OUT_SEC: float = 3.0
const SILENT_DB: float = -60.0
## Ducking (§2) : voix → Music −6 dB, Ambience −4 dB ; tampon → −3 dB bref.
const DUCK_VOICE_MUSIC_DB: float = -6.0
const DUCK_VOICE_AMBIENCE_DB: float = -4.0
const DUCK_STAMP_DB: float = -3.0
const DUCK_ATTACK_SEC: float = 0.08
const DUCK_RELEASE_SEC: float = 0.4
const DUCK_STAMP_HOLD_SEC: float = 0.15
## Musique « tension » sous 25 % du temps de shift.
const TENSION_RATIO: float = 0.25
## Un demi-ton de plus toutes les 5 s sous le seuil critique.
const CRITICAL_STEP_SEC: float = 5.0
const RULE_CHIME_DELAY_SEC: float = 1.0
const PRINTER_TO_CHIME_SEC: float = 0.9
const SLOT_OUT_DELAY_SEC: float = 0.45
const DOOR_CLOSE_DELAY_SEC: float = 2.5
const HOLO_STAGGER_SEC: float = 0.12
const KNOCK_CHANCE: float = 0.3
## `ui.hover` : au plus un tick tous les 90 ms (balayage rapide de la souris).
const HOVER_MIN_INTERVAL_MSEC: int = 90
## Le tampon remonte après l'impact (`booth.stamp_lift`).
const STAMP_LIFT_DELAY_SEC: float = DS.DUR_SLOW
const PA_MIN_SEC: float = 60.0
const PA_MAX_SEC: float = 150.0
const DROP_MIN_SEC: float = 4.0
const DROP_MAX_SEC: float = 12.0
const BARK_CACHE_MAX: int = 48
## Distance de l'écoute (agent) au repère du comptoir, côté caméra.
const LISTENER_DISTANCE: float = 1.3
const LISTENER_HEIGHT: float = 1.5

const AMBIENCE_LOOPS: Array[StringName] = [&"amb.rain_glass", &"amb.station_bed", &"amb.neon_hum", &"amb.queue_murmur"]

## Booth du jour (`BoothDirector` ; tout autre nœud = pas de 3D).
@export var booth: Node = null
## Rendu des barks dans le thread courant (tests).
@export var sync_barks: bool = false

var ui: ComparisonUI = null
var sfx_pool: VoicePool = null
var world_pool: VoicePool = null
var ui_pool: VoicePool = null
var ambience_pool: VoicePool = null
var ambience_players: Dictionary[StringName, AudioStreamPlayer] = {}
var hum_player: AudioStreamPlayer = null
## Voix 2D de secours (pas de booth 3D).
var voice_2d: AudioStreamPlayer = null
var music_players: Array[AudioStreamPlayer] = []
var music_cue: StringName = &""
var listener: AudioListener3D = null
var passenger_audio: Dictionary[PassengerActor, PassengerAudio] = {}
## Historique : [cue, bus] (les 64 dernières).
var history: Array[Array] = []
var day_duration: float = 0.0
var phase: DayPhase.Kind = DayPhase.Kind.INTRO
var fx_reduced: bool = false

var _current_case: Case = null
var _music_index: int = 0
var _warned: bool = false
var _last_tick_second: int = -1
var _tweens: Dictionary[AudioStreamPlayer, Tween] = {}
var _voice_duck: float = 0.0
var _stamp_duck_left: float = 0.0
var _stamp_duck: float = 0.0
var _pa_left: float = 0.0
var _drop_left: float = 0.0
var _last_a: FieldRef = null
var _holding: Dictionary[VerdictKind.Kind, bool] = {}
var _bark_cache: Dictionary[String, AudioStreamWAV] = {}
## Barks en cours de rendu : [task_id, cache_key, buffer holder, acteur|null, line_key].
var _pending_barks: Array[Array] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _paused_fx: bool = false
## UI dont les signaux publics sont branchés.
var _bound_ui: ComparisonUI = null
var _last_hover_msec: int = -HOVER_MIN_INTERVAL_MSEC
## Image de la dernière réponse d'interrogatoire (la réaction qui la suit
## ne déclenche pas de second bark).
var _answer_frame: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 0xC1EA
	AudioCueBank.preload_all()
	sfx_pool = _pool("SFXPool", AudioBuses.SFX, SFX_VOICES)
	world_pool = _pool("WorldPool", AudioBuses.SFX_WORLD, WORLD_VOICES)
	ui_pool = _pool("UIPool", AudioBuses.UI, UI_VOICES)
	ambience_pool = _pool("AmbiencePool", AudioBuses.AMBIENCE, AMBIENCE_VOICES)
	for cue: StringName in AMBIENCE_LOOPS:
		ambience_players[cue] = _player(String(cue).replace(".", "_"), AudioBuses.AMBIENCE)
	hum_player = _player("HoloHum", AudioBuses.SFX)
	voice_2d = _player("Voice2D", AudioBuses.VOICE)
	voice_2d.finished.connect(_on_voice_finished)
	for i: int in 2:
		music_players.append(_player("Music%d" % i, AudioBuses.MUSIC))
	fx_reduced = Settings.fx_intensity < 1.0
	_connect_bus()
	_attach_booth()
	_pa_left = _rng.randf_range(PA_MIN_SEC, PA_MAX_SEC)
	_drop_left = _rng.randf_range(DROP_MIN_SEC, DROP_MAX_SEC)


func _exit_tree() -> void:
	for pending: Array in _pending_barks:
		var task: int = pending[0]
		WorkerThreadPool.wait_for_task_completion(task)
	_pending_barks.clear()
	_apply_ducks(0.0, 0.0)
	AudioBuses.set_effect_enabled(AudioBuses.MUSIC, AudioBuses.FX_MUFFLE, false)
	_bark_cache.clear()
	AudioCueBank.clear_cache()


func _pool(node_name: String, bus_name: StringName, size: int) -> VoicePool:
	var pool: VoicePool = VoicePool.new()
	pool.name = node_name
	add_child(pool)
	pool.setup(bus_name, size)
	return pool


func _player(node_name: String, bus_name: StringName) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.name = node_name
	p.bus = bus_name
	add_child(p)
	return p


func _connect_bus() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_phase_changed.connect(_on_day_phase_changed)
	EventBus.day_clock_ticked.connect(_on_day_clock_ticked)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.case_presented.connect(_on_case_presented)
	EventBus.passenger_arrived.connect(_on_passenger_arrived)
	EventBus.documents_presented.connect(_on_documents_presented)
	EventBus.passenger_reaction_triggered.connect(_on_reaction)
	EventBus.passenger_departed.connect(_on_passenger_departed)
	EventBus.inspection_mode_changed.connect(_on_inspection_mode_changed)
	EventBus.discrepancy_check_requested.connect(_on_check_requested)
	EventBus.discrepancy_checked.connect(_on_discrepancy_checked)
	EventBus.interrogation_answered.connect(_on_interrogation_answered)
	EventBus.verdict_stamped.connect(_on_verdict_stamped)
	EventBus.case_resolved.connect(_on_case_resolved)
	EventBus.citation_issued.connect(_on_citation_issued)
	EventBus.settings_changed.connect(_on_settings_changed)


# ---------------------------------------------------------------------------
# Booth : émetteurs des acteurs, écoute 3D
# ---------------------------------------------------------------------------

func _booth() -> BoothDirector:
	if booth == null or not is_instance_valid(booth):
		return null
	return booth as BoothDirector


func _attach_booth() -> void:
	var b: BoothDirector = _booth()
	if b == null:
		return
	for actor: PassengerActor in b.actors:
		var pa: PassengerAudio = PassengerAudio.new()
		actor.add_child(pa)
		pa.attach(actor)
		pa.voice_started.connect(_on_voice_started)
		pa.voice_finished.connect(_on_voice_finished)
		passenger_audio[actor] = pa
	var vp: Viewport = b.get_viewport()
	if vp != null:
		vp.audio_listener_enable_3d = true
	listener = AudioListener3D.new()
	listener.name = "AgentEars"
	b.add_child(listener)
	var desk: Vector3 = b.desk_mark.global_position
	var to_camera: Vector3 = b.camera.global_position - desk
	to_camera.y = 0.0
	var dir: Vector3 = to_camera.normalized() if to_camera.length() > 0.01 else Vector3.BACK
	listener.global_position = desk + dir * LISTENER_DISTANCE + Vector3.UP * LISTENER_HEIGHT
	listener.look_at(desk + Vector3.UP * LISTENER_HEIGHT, Vector3.UP)
	listener.make_current()


## `PassengerAudio` de l'acteur d'un cas (ou de l'acteur au guichet).
func audio_for_case(case_id: StringName) -> PassengerAudio:
	var b: BoothDirector = _booth()
	if b == null:
		return null
	var actor: PassengerActor = b.get_actor(case_id) if case_id != &"" else null
	if actor == null:
		actor = b.get_desk_actor()
	return passenger_audio.get(actor, null) if actor != null else null


# ---------------------------------------------------------------------------
# Lecture des cues
# ---------------------------------------------------------------------------

## Joue une cue 2D de la cue sheet ; renvoie vrai si elle a obtenu une voix.
func play_cue(cue: StringName, pitch: float = 1.0) -> bool:
	if not AudioCueBank.has_cue(cue):
		push_warning("AudioDirector: cue inconnue %s" % cue)
		return false
	var stream: AudioStream = AudioCueBank.stream_of(cue)
	var bus_name: StringName = AudioCueBank.bus_of(cue)
	var pool: VoicePool = _pool_for(bus_name)
	if stream == null or pool == null:
		return false
	var db: float = AudioCueBank.volume_db_of(cue)
	if fx_reduced and (cue == &"booth.stamp_approved" or cue == &"booth.stamp_denied"):
		db -= 4.0 # « réduire les effets » : tampons adoucis (§9)
	var player: AudioStreamPlayer = pool.play(cue, stream, AudioCueBank.priority_of(cue), db, pitch,
			AudioCueBank.polyphony_of(cue))
	if player == null:
		return false
	_log(cue, bus_name)
	return true


## Joue une cue après `delay` secondes (temps de jeu, pause comprise).
func play_cue_later(cue: StringName, delay: float) -> void:
	get_tree().create_timer(delay, true).timeout.connect(func() -> void:
		if is_inside_tree():
			play_cue(cue))


func _pool_for(bus_name: StringName) -> VoicePool:
	match bus_name:
		AudioBuses.SFX:
			return sfx_pool
		AudioBuses.SFX_WORLD:
			return world_pool
		AudioBuses.UI:
			return ui_pool
		AudioBuses.AMBIENCE:
			return ambience_pool
	return null


func _log(cue: StringName, bus_name: StringName) -> void:
	history.append([cue, bus_name])
	if history.size() > 64:
		history.pop_front()
	cue_played.emit(cue, bus_name)


## Cues jouées (ids seuls, ordre chronologique).
func played_cues() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry: Array in history:
		out.append(entry[0])
	return out


# ---------------------------------------------------------------------------
# Ambiance et musique
# ---------------------------------------------------------------------------

func start_ambience() -> void:
	for cue: StringName in AMBIENCE_LOOPS:
		var p: AudioStreamPlayer = ambience_players[cue]
		if p.playing:
			continue
		p.stream = AudioCueBank.stream_of(cue)
		if p.stream == null:
			continue
		p.volume_db = SILENT_DB
		p.play(_rng.randf() * 4.0)
		_fade(p, AudioCueBank.volume_db_of(cue), AMBIENCE_FADE_IN_SEC)
		_log(cue, AudioBuses.AMBIENCE)


func stop_ambience(fade_sec: float = AMBIENCE_FADE_OUT_SEC) -> void:
	for cue: StringName in AMBIENCE_LOOPS:
		var p: AudioStreamPlayer = ambience_players[cue]
		if p.playing:
			_fade(p, SILENT_DB, fade_sec, true)


## État musical (`mus.*`) ; fondu enchaînée, sans effet si déjà actif.
func set_music(cue: StringName) -> void:
	if cue == music_cue:
		return
	music_cue = cue
	var old: AudioStreamPlayer = music_players[_music_index]
	if old.playing:
		_fade(old, SILENT_DB, MUSIC_FADE_SEC, true)
	if cue == &"":
		return
	_music_index = 1 - _music_index
	var p: AudioStreamPlayer = music_players[_music_index]
	p.stop()
	p.stream = AudioCueBank.stream_of(cue)
	if p.stream == null:
		return
	p.volume_db = SILENT_DB
	p.play()
	_fade(p, AudioCueBank.volume_db_of(cue), MUSIC_FADE_SEC)
	_log(cue, AudioBuses.MUSIC)


func _fade(p: AudioStreamPlayer, target_db: float, seconds: float, stop_after: bool = false) -> void:
	var previous: Tween = _tweens.get(p, null)
	if previous != null and previous.is_valid():
		previous.kill()
	var tween: Tween = p.create_tween()
	_tweens[p] = tween
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(p, ^"volume_db", target_db, seconds).set_trans(Tween.TRANS_SINE)
	if stop_after:
		tween.tween_callback(p.stop)


# ---------------------------------------------------------------------------
# Barks (Tessar)
# ---------------------------------------------------------------------------

## Fait parler le passager d'un cas : `line_key` → phrase Tessar (`text` = le
## sous-titre FR, pour la longueur et l'intonation).
func bark(case: Case, line_key: String, text: String, mood: StringName = TessarVoice.MOOD_NEUTRAL) -> void:
	var pa: PassengerAudio = audio_for_case(case.case_id if case != null else &"")
	var profile: TessarVoice.Profile = pa.profile if pa != null else TessarVoice.profile_for(case.passenger_presented if case != null else null)
	var phrase: String = TessarVoice.phrase_for(line_key, text)
	var key: String = "%d|%s|%s" % [profile.voice_seed, phrase, mood]
	if _bark_cache.has(key):
		_say(pa, _bark_cache[key], line_key)
		return
	if sync_barks:
		var wav: AudioStreamWAV = AudioDsp.to_wav(TessarVoice.synthesize(phrase, profile, mood), TessarVoice.SAMPLE_RATE)
		_cache_bark(key, wav)
		_say(pa, wav, line_key)
		return
	var holder: Array[PackedFloat32Array] = [PackedFloat32Array()]
	var task: int = WorkerThreadPool.add_task(func() -> void:
		holder[0] = TessarVoice.synthesize(phrase, profile, mood), false, "TessarBark")
	_pending_barks.append([task, key, holder, pa, line_key])


func _poll_barks() -> void:
	var i: int = 0
	while i < _pending_barks.size():
		var pending: Array = _pending_barks[i]
		var task: int = pending[0]
		if not WorkerThreadPool.is_task_completed(task):
			i += 1
			continue
		WorkerThreadPool.wait_for_task_completion(task)
		_pending_barks.remove_at(i)
		var holder: Array[PackedFloat32Array] = pending[2]
		var wav: AudioStreamWAV = AudioDsp.to_wav(holder[0], TessarVoice.SAMPLE_RATE)
		var key: String = pending[1]
		_cache_bark(key, wav)
		var pa: PassengerAudio = pending[3]
		var line_key: String = pending[4]
		if pa != null and not is_instance_valid(pa):
			continue
		_say(pa, wav, line_key)


func _cache_bark(key: String, wav: AudioStreamWAV) -> void:
	if _bark_cache.size() >= BARK_CACHE_MAX:
		_bark_cache.clear()
	_bark_cache[key] = wav


func _say(pa: PassengerAudio, wav: AudioStreamWAV, line_key: String) -> void:
	if pa != null and pa.actor != null and pa.actor.visible:
		pa.say(wav, line_key)
	else:
		voice_2d.stop()
		voice_2d.stream = wav
		voice_2d.play()
		_on_voice_started(wav.get_length())
	_log(&"passenger.bark", AudioBuses.VOICE)


func has_pending_barks() -> bool:
	return not _pending_barks.is_empty()


func _on_voice_started(_duration: float) -> void:
	_pa_left = maxf(_pa_left, 6.0) # jamais d'annonce PA sur un bark


func _on_voice_finished() -> void:
	pass # le ducking suit `is_voice_active()` à chaque image


func is_voice_active() -> bool:
	if voice_2d.playing:
		return true
	for pa: PassengerAudio in passenger_audio.values():
		if is_instance_valid(pa) and pa.is_speaking():
			return true
	return false


# ---------------------------------------------------------------------------
# Boucle : ducking, sondes UI, one-shots d'ambiance
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_poll_barks()
	_update_ducks(delta)
	_poll_ui()
	_update_pause()
	if get_tree().paused:
		return
	if phase != DayPhase.Kind.INTRO and phase != DayPhase.Kind.SUMMARY:
		_drop_left -= delta
		if _drop_left <= 0.0:
			_drop_left = _rng.randf_range(DROP_MIN_SEC, DROP_MAX_SEC)
			play_cue(&"amb.rain_drop_heavy")
		_pa_left -= delta
		if _pa_left <= 0.0:
			_pa_left = _rng.randf_range(PA_MIN_SEC, PA_MAX_SEC)
			if not is_voice_active():
				play_cue(&"amb.pa_announce")


func _update_ducks(delta: float) -> void:
	var target: float = 1.0 if is_voice_active() else 0.0
	var rate: float = delta / (DUCK_ATTACK_SEC if target > _voice_duck else DUCK_RELEASE_SEC)
	_voice_duck = move_toward(_voice_duck, target, rate)
	_stamp_duck_left = maxf(_stamp_duck_left - delta, 0.0)
	var stamp_target: float = 1.0 if _stamp_duck_left > 0.0 else 0.0
	_stamp_duck = move_toward(_stamp_duck, stamp_target, delta / (0.02 if stamp_target > _stamp_duck else DUCK_RELEASE_SEC))
	_apply_ducks(_voice_duck, _stamp_duck)


func _apply_ducks(voice_level: float, stamp_level: float) -> void:
	var music: AudioEffectAmplify = AudioBuses.get_effect(AudioBuses.MUSIC, AudioBuses.FX_DUCK) as AudioEffectAmplify
	var amb: AudioEffectAmplify = AudioBuses.get_effect(AudioBuses.AMBIENCE, AudioBuses.FX_DUCK) as AudioEffectAmplify
	var voice_fx: AudioEffectAmplify = AudioBuses.get_effect(AudioBuses.VOICE, AudioBuses.FX_DUCK) as AudioEffectAmplify
	if music != null:
		music.volume_db = DUCK_VOICE_MUSIC_DB * voice_level + DUCK_STAMP_DB * stamp_level
	if amb != null:
		amb.volume_db = DUCK_VOICE_AMBIENCE_DB * voice_level + DUCK_STAMP_DB * stamp_level
	if voice_fx != null:
		voice_fx.volume_db = DUCK_STAMP_DB * stamp_level


## Atténuation courante (dB) de l'effet `Duck` d'un bus.
func duck_db(bus_name: StringName) -> float:
	var fx: AudioEffectAmplify = AudioBuses.get_effect(bus_name, AudioBuses.FX_DUCK) as AudioEffectAmplify
	return fx.volume_db if fx != null else 0.0


func _update_pause() -> void:
	var paused: bool = get_tree().paused
	if paused != _paused_fx:
		_paused_fx = paused
		AudioBuses.set_effect_enabled(AudioBuses.MUSIC, AudioBuses.FX_MUFFLE, paused)


## Sondes UI (pas de signal public pour la sélection A ni le maintien du
## tampon) : état lu sur `ComparisonUI`.
func _poll_ui() -> void:
	if ui == null or not is_instance_valid(ui):
		ui = _find_ui()
		if ui == null:
			return
	if ui != _bound_ui:
		bind_ui(ui)
	var a: FieldRef = ui.selection.a
	if a != null and (_last_a == null or not a.equals(_last_a)):
		play_cue(&"ui.field_select_a")
	_last_a = a
	if ui.tool_bar == null:
		return
	for kind: VerdictKind.Kind in ui.tool_bar.stamps:
		var stamp: StampButton = ui.tool_bar.stamps[kind]
		var holding: bool = stamp.is_holding()
		if holding and not _holding.get(kind, false):
			play_cue(&"ui.stamp_hold")
		elif not holding and _holding.get(kind, false):
			ui_pool.stop_cue(&"ui.stamp_hold")
		_holding[kind] = holding


## Branche les signaux publics de l'UI (survol, toasts, réplique de départ).
func bind_ui(p_ui: ComparisonUI) -> void:
	ui = p_ui
	_bound_ui = p_ui
	if p_ui == null:
		return
	if not p_ui.hovered.is_connected(_on_ui_hovered):
		p_ui.hovered.connect(_on_ui_hovered)
		p_ui.toast_shown.connect(_on_toast_shown)
		p_ui.departure_line_shown.connect(_on_departure_line_shown)


func _on_ui_hovered(_control: Control) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_hover_msec < HOVER_MIN_INTERVAL_MSEC:
		return
	_last_hover_msec = now
	play_cue(&"ui.hover")


func _on_toast_shown(kind: ToastStack.Kind) -> void:
	match kind:
		ToastStack.Kind.SUCCESS:
			play_cue(&"ui.toast_success")
		ToastStack.Kind.ERROR, ToastStack.Kind.WARNING:
			play_cue(&"ui.toast_error")
		_:
			play_cue(&"ui.toast_info")


func _on_departure_line_shown(line_key: String, text: String) -> void:
	var mood: StringName = TessarVoice.MOOD_NEUTRAL
	if line_key.contains("denied"):
		mood = TessarVoice.MOOD_ANGRY
	elif line_key.contains("detained"):
		mood = TessarVoice.MOOD_NERVOUS
	bark(_current_case, line_key, text, mood)


func _find_ui() -> ComparisonUI:
	var scene: DayScene = owner as DayScene
	if scene != null:
		return scene.ui as ComparisonUI
	return null


# ---------------------------------------------------------------------------
# EventBus
# ---------------------------------------------------------------------------

func _on_day_started(day: DayDef, rulebook: Array[RulebookEntry]) -> void:
	day_duration = day.duration_sec if day != null else 0.0
	_warned = false
	_last_tick_second = -1
	start_ambience()
	set_music(&"mus.briefing")
	for entry: RulebookEntry in rulebook:
		if entry.is_new:
			play_cue_later(&"ui.rule_new", RULE_CHIME_DELAY_SEC)
			break


func _on_day_phase_changed(p_phase: DayPhase.Kind, _case_id: StringName) -> void:
	var previous: DayPhase.Kind = phase
	phase = p_phase
	match p_phase:
		DayPhase.Kind.INTRO:
			set_music(&"mus.briefing")
		DayPhase.Kind.WAITING_CASE:
			if previous == DayPhase.Kind.INTRO:
				set_music(&"mus.shift_calm")


func _on_day_clock_ticked(remaining: float) -> void:
	if remaining <= DS.TIMER_WARN_SECONDS and not _warned:
		_warned = true
		play_cue(&"ui.timer_warning")
	if remaining <= DS.TIMER_CRITICAL_SECONDS and remaining > 0.0:
		var second: int = ceili(remaining)
		if second != _last_tick_second:
			_last_tick_second = second
			if not fx_reduced: # « réduire les effets » : visuel seul (§9)
				var steps: int = floori((DS.TIMER_CRITICAL_SECONDS - remaining) / CRITICAL_STEP_SEC)
				play_cue(&"ui.timer_critical_tick", pow(2.0, steps / 12.0))
	if day_duration > 0.0 and remaining <= day_duration * TENSION_RATIO and music_cue == &"mus.shift_calm":
		set_music(&"mus.shift_tension")


func _on_day_ended(summary: DaySummary) -> void:
	phase = DayPhase.Kind.SUMMARY
	hum_player.stop()
	stop_ambience()
	var negative: bool = summary != null and summary.get_net() < 0
	set_music(&"mus.debrief_minor" if negative else &"mus.debrief")


func _on_case_presented(case: Case) -> void:
	_current_case = case
	play_cue(&"station.door_open")
	play_cue(&"amb.queue_advance")
	var pa: PassengerAudio = audio_for_case(case.case_id)
	if pa != null:
		pa.configure(case.passenger_presented)
	var key: String = ComparisonUI.scripted_key(case, "arrival", "bark_arrival")
	bark(case, key, UiText.t(key, ""))


func _on_passenger_arrived(_case_id: StringName) -> void:
	play_cue(&"booth.intercom_on")


func _on_documents_presented(case_id: StringName) -> void:
	play_cue(&"booth.slot_in")
	var docs: int = 1
	if _current_case != null and _current_case.case_id == case_id:
		docs = clampi(_current_case.documents.size(), 1, 3)
	for i: int in docs:
		play_cue_later(&"booth.holo_on", 0.25 + HOLO_STAGGER_SEC * i)
	hum_player.stream = AudioCueBank.stream_of(&"booth.holo_hum")
	if hum_player.stream != null and not hum_player.playing:
		hum_player.volume_db = AudioCueBank.volume_db_of(&"booth.holo_hum")
		hum_player.play()
	var key: String = ComparisonUI.scripted_key(_current_case, "present", "bark_present")
	bark(_current_case, key, UiText.t(key, ""))


func _on_reaction(reaction: PassengerReaction.Kind) -> void:
	var name_key: String = str(PassengerReaction.Kind.find_key(reaction)).to_lower()
	var pa: PassengerAudio = audio_for_case(&"")
	match reaction:
		PassengerReaction.Kind.NERVOUS:
			if pa != null:
				pa.nervous = true
				pa.play_breath(&"passenger.breath_nervous")
		PassengerReaction.Kind.SHRUG, PassengerReaction.Kind.RELIEVED:
			if pa != null:
				pa.play_breath(&"passenger.breath_sigh")
		PassengerReaction.Kind.ANGRY:
			if pa != null and _rng.randf() < KNOCK_CHANCE:
				pa.play_body(&"passenger.knock_glass")
	if _answer_frame == Engine.get_process_frames():
		_answer_frame = -1 # réaction d'une réponse : la réplique est déjà dite
		return
	var line: String = UiText.t("react_" + name_key, "")
	if not line.is_empty(): # même condition que le sous-titre (ComparisonUI)
		bark(_current_case, "react_" + name_key, line, TessarVoice.mood_for_reaction(reaction))


func _on_interrogation_answered(_topic: StringName, line_key: String) -> void:
	_answer_frame = Engine.get_process_frames()
	var mood: StringName = TessarVoice.MOOD_NEUTRAL
	if line_key == InspectionSession.LINE_CONFRONT_ANGRY or line_key.contains("_" + InspectionSession.LINE_OUTRAGE_INFIX):
		mood = TessarVoice.MOOD_ANGRY
	elif line_key == InspectionSession.LINE_CONFRONT_NERVOUS or line_key.begins_with(InspectionSession.LINE_ABOUT_PREFIX):
		mood = TessarVoice.MOOD_NERVOUS
	elif line_key == InspectionSession.LINE_GENERIC_SHRUG:
		mood = TessarVoice.MOOD_SHRUG
	bark(_current_case, line_key, UiText.t(line_key, line_key), mood)


func _on_passenger_departed(_case_id: StringName) -> void:
	play_cue(&"booth.intercom_off")
	play_cue_later(&"station.door_close", DOOR_CLOSE_DELAY_SEC)


func _on_inspection_mode_changed(enabled: bool) -> void:
	play_cue(&"ui.inspect_mode_on" if enabled else &"ui.inspect_mode_off")


func _on_check_requested(_a: FieldRef, _b: FieldRef) -> void:
	play_cue(&"ui.field_select_b")


func _on_discrepancy_checked(result: Discrepancy) -> void:
	match result.result:
		Discrepancy.Result.DISCORDANT:
			play_cue(&"ui.discrepancy")
		Discrepancy.Result.CONCORDANT:
			play_cue(&"ui.match")
		_:
			play_cue(&"ui.incomparable")


func _on_verdict_stamped(verdict: Verdict) -> void:
	ui_pool.stop_cue(&"ui.stamp_hold")
	var approved: bool = verdict != null and verdict.kind == VerdictKind.Kind.APPROVE
	play_cue(&"booth.stamp_approved" if approved else &"booth.stamp_denied")
	play_cue_later(&"booth.stamp_lift", STAMP_LIFT_DELAY_SEC)
	_stamp_duck_left = DUCK_STAMP_HOLD_SEC


func _on_case_resolved(_case_id: StringName, _result: CaseResult) -> void:
	hum_player.stop()
	play_cue(&"booth.holo_off")
	play_cue_later(&"booth.slot_out", SLOT_OUT_DELAY_SEC)


func _on_citation_issued(_reason_key: String) -> void:
	play_cue(&"booth.printer_citation")
	play_cue_later(&"ui.citation_chime", PRINTER_TO_CHIME_SEC)


func _on_settings_changed(key: StringName, value: Variant) -> void:
	match key:
		Settings.KEY_FX_INTENSITY:
			var level: float = value
			fx_reduced = level < 1.0
		Settings.KEY_AUDIO_MONO:
			var mono: bool = value
			for pa: PassengerAudio in passenger_audio.values():
				if is_instance_valid(pa):
					pa.set_mono(mono)
