## Directeur audio du jour (docs/AUDIO.md §2, §4, §6, §11) — nœud de
## `day.tscn` (pas un autoload, ARCHITECTURE P6).
##
## Seul écouteur audio de l'`EventBus` : joue la cue sheet sur les bons bus
## (pools 2D à priorités : `VoicePool`), l'ambiance (boucles + one-shots
## aléatoires), la musique dynamique M14 (`MusicDirector` enfant, intensité
## `MusicIntensity`, docs/AUDIO.md §13), les annonces d'ambiance sous-titrées
## (`PaScheduler`, voix Tessar synthétisée à l'exécution) et les barks Tessar
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
## Musique M14 (docs/M14.md §2.5, §2.6, §2.10 ; docs/AUDIO.md §13).
const MUSIC_SETS_DIR: String = "res://assets/audio/music/sets/"
const MUSIC_INDEX_PATH: String = "res://assets/audio/music/index.json"
const SET_TITLE: StringName = &"ms_01"
const SET_ACT1: StringName = &"ms_02"
const SET_ACT2: StringName = &"ms_03"
const SET_ACT3: StringName = &"ms_04"
const SET_GARDE: StringName = &"ms_05"
const SET_EVENING: StringName = &"ms_06"
const SET_EPILOGUE: StringName = &"ms_07"
const GROUP_WARM: StringName = &"warm"
const GROUP_CRISIS: StringName = &"crisis"
## Fondu d'entrée de l'ensemble au chargement du jour.
const MUSIC_ENTER_SEC: float = 1.5
## Fin → thème : fondu de sortie de 2 s (bus) puis le thème depuis le début.
const END_FADE_SEC: float = 2.0
## Fins des actes I–II simulées seulement (démo, `--screen=end`, D-076,
## D-086) : sans cinématique, MS-06 continue sous l'écran de fin (QA-079).
const SIMULATED_EARLY_ENDINGS: Array[StringName] = [EndingService.F4_GLORY, EndingService.F5_AIR,
		EndingService.F7_REOPENS, EndingService.F8_REGISTRE, EndingService.F9_STRIKE]
## Mode Inspection discret : −6 dB et passe-bas 3,5 kHz ; power down : −6 dB
## et passe-bas 400 Hz ; pause : passe-bas 2,5 kHz (effet `Muffle`).
const INSPECTION_DUCK_DB: float = -6.0
const INSPECTION_CUTOFF_HZ: float = 3500.0
const POWER_DOWN_CUTOFF_HZ: float = 400.0
const PAUSE_CUTOFF_HZ: float = 2500.0
const INSPECTION_RAMP_SEC: float = 0.5
## Annonce PA (jeu ou ambiance) : musique −3 dB.
const DUCK_PA_DB: float = -3.0
## EV-05 : identifiant de la coupure de courant (cas particulier « power down »).
const EVENT_POWER_CUT: StringName = &"ev_05"
## Murmure de la file ∝ silhouettes visibles (0 → −6 dB), places de la file.
const MURMUR_MIN_DB: float = -6.0
const QUEUE_PLACES: int = 6
## Annonces d'ambiance : volume de la voix (bus Ambience).
const PA_VOICE_DB: float = -9.0
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
## Musique dynamique (M14) : lecteur unique dans le flux, intensité pure.
var music: MusicDirector = null
var intensity: MusicIntensity = MusicIntensity.new()
var pa_scheduler: PaScheduler = PaScheduler.new()
## Ensemble du jour et de la soirée (null : musique pas rendue → silence).
var day_set: MusicSetDef = null
var evening_set: MusicSetDef = null
## État musical : briefing, shift, evening, end, garde_end, epilogue_end.
var music_state: StringName = &""
## Thème joué (fin ou monde), vide sinon.
var theme_id: StringName = &""
## Lecteur des annonces d'ambiance (voix synthétisée à l'exécution).
var pa_player: AudioStreamPlayer = null
var listener: AudioListener3D = null
var passenger_audio: Dictionary[PassengerActor, PassengerAudio] = {}
## Historique : [cue, bus] (les 64 dernières).
var history: Array[Array] = []
var day_duration: float = 0.0
var phase: DayPhase.Kind = DayPhase.Kind.INTRO
var fx_reduced: bool = false

var _current_case: Case = null
var _day: DayDef = null
var _intensity_left: float = 0.0
var _discrepancy_reset_bars: int = -1
var _inspection_duck: float = 0.0
var _music_extra_db: float = 0.0
var _muffle_cutoff: float = -1.0
var _muffle_on: bool = false
var _since_bark: float = INF
var _since_game_announce: float = INF
var _remaining_sec: float = INF
var _event_id: StringName = &""
var _shift_open: bool = false
var _screen_seen: Node = null
## Rendu d'une annonce d'ambiance en cours : [task_id, `PaJob`].
var _pending_pa: Array = []
## Annonce de jeu en cours (cue `amb.pa_announce`) : ducking PA de la musique.
var _game_pa_left: float = 0.0
## Longueur d'une annonce de jeu (carillon + phrase, `vo_pa_announce_*`).
const GAME_PA_SEC: float = 4.5
var _warned: bool = false
var _last_tick_second: int = -1
var _tweens: Dictionary[AudioStreamPlayer, Tween] = {}
var _voice_duck: float = 0.0
var _stamp_duck_left: float = 0.0
var _stamp_duck: float = 0.0
var _drop_left: float = 0.0
var _last_a: FieldRef = null
var _holding: Dictionary[VerdictKind.Kind, bool] = {}
var _bark_cache: Dictionary[String, AudioStreamWAV] = {}
## Barks en cours de rendu : [task_id, `BarkJob`, cache_key, acteur|null, line_key].
var _pending_barks: Array[Array] = []
## Plus aucun bark accepté (sortie de l'arbre, libération) : QA-030.
var _closing: bool = false
var _inspecting: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _paused_fx: bool = false
## Fondu de sortie avant changement de scène en cours (`fade_out_music`).
var _leaving: bool = false
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
	pa_player = _player("PAVoice", AudioBuses.AMBIENCE)
	pa_player.volume_db = PA_VOICE_DB
	music = MusicDirector.new()
	music.name = "MusicDirector"
	add_child(music)
	music.bar_passed.connect(_on_music_bar)
	if is_zero_approx(Settings.get_float(Settings.KEY_VOLUME_MUSIC)):
		music.set_suspended(true)
	fx_reduced = Settings.fx_intensity < 1.0
	_connect_bus()
	_attach_booth()
	_drop_left = _rng.randf_range(DROP_MIN_SEC, DROP_MAX_SEC)


## Synthèse d'un bark dans un thread de travail (QA-030) : objet autonome qui
## ne référence **aucun** nœud — ni le directeur (`self` d'une lambda), ni un
## acteur, ni l'arbre. Le thread ne lit que `phrase` / `profile` / `mood`
## (immuables pendant le rendu) et n'écrit que `samples` ; le thread principal
## ne lit `samples` qu'après `wait_for_task_completion`.
class BarkJob:
	extends RefCounted
	var phrase: String = ""
	var profile: TessarVoice.Profile = null
	var mood: StringName = &""
	var samples: PackedFloat32Array = PackedFloat32Array()

	func run() -> void:
		samples = TessarVoice.synthesize(phrase, profile, mood)


## Rendu d'une annonce d'ambiance (jingle + voix Tessar en haut-parleur) dans
## un thread de travail : même contrat que `BarkJob` (aucun nœud référencé).
class PaJob:
	extends RefCounted
	var key: String = ""
	var phrase: String = ""
	var text: String = ""
	var profile: TessarVoice.Profile = null
	var world: StringName = &""
	var samples: PackedFloat32Array = PackedFloat32Array()

	func run() -> void:
		samples = PaScheduler.render(phrase, profile, world)


func _enter_tree() -> void:
	_closing = false


func _exit_tree() -> void:
	# QA-030 : plus aucun bark après la sortie de l'arbre (signaux émis par les
	# nœuds frères pendant `reload_current_scene`), puis attente de tous les
	# rendus en cours avant que la scène ne soit libérée.
	_closing = true
	_join_barks()
	_apply_ducks(0.0, 0.0)
	var muffle: AudioEffectLowPassFilter = AudioBuses.get_effect(AudioBuses.MUSIC, AudioBuses.FX_MUFFLE) as AudioEffectLowPassFilter
	if muffle != null:
		muffle.cutoff_hz = PAUSE_CUTOFF_HZ
	AudioBuses.set_effect_enabled(AudioBuses.MUSIC, AudioBuses.FX_MUFFLE, false)
	_muffle_on = false
	_bark_cache.clear()
	_stop_all_players(self)
	AudioCueBank.clear_cache()


## Arrête tous les lecteurs (pools, ambiances, musique, émetteurs) : un flux
## encore joué à la fermeture du jeu reste référencé par l'AudioServer
## (« ObjectDB instances leaked », « resources still in use », QA-016).
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Libéré sans être sorti de l'arbre (tests, `free()` direct) : aucun
		# thread ne doit survivre au directeur.
		_closing = true
		_join_barks()


## Dans l'arbre et pas en fermeture : sinon aucun son (QA-025 : « Playback can
## only happen when a node is inside the scene tree ») et aucun flux remis dans
## le cache d'`AudioCueBank` après `clear_cache()` (ressources retenues à la sortie).
func _is_active() -> bool:
	return not _closing and is_inside_tree()


## Attend la fin de tous les rendus en cours (thread principal) et les oublie.
func _join_barks() -> void:
	for pending: Array in _pending_barks:
		var task: int = pending[0]
		WorkerThreadPool.wait_for_task_completion(task)
	_pending_barks.clear()
	if not _pending_pa.is_empty():
		WorkerThreadPool.wait_for_task_completion(int(_pending_pa[0]))
		_pending_pa = []


static func _stop_all_players(node: Node) -> void:
	for child: Node in node.get_children():
		if child is AudioStreamPlayer:
			var player: AudioStreamPlayer = child
			player.stop()
			player.stream = null
		elif child is AudioStreamPlayer3D:
			var player_3d: AudioStreamPlayer3D = child
			player_3d.stop()
			player_3d.stream = null
		_stop_all_players(child)


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
	# M7 (docs/AUDIO.md §12) : objets glissés, annonces du Hall — cues existantes.
	EventBus.item_slipped.connect(_on_item_slipped)
	EventBus.item_decided.connect(_on_item_decided)
	EventBus.hall_announced.connect(_on_hall_announced)
	# M14 : intensité musicale (entrées publiques), file, Garde.
	EventBus.quota_changed.connect(_on_quota_changed)
	EventBus.station_event_started.connect(_on_station_event_started)
	EventBus.station_event_ended.connect(_on_station_event_ended)
	EventBus.queue_progressed.connect(_on_queue_progressed)
	EventBus.garde_tier_changed.connect(_on_garde_tier_changed)
	EventBus.garde_error.connect(_on_garde_error)


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
	if not b.glass_knocked.is_connected(_on_glass_knocked):
		b.glass_knocked.connect(_on_glass_knocked)
		b.escort_started.connect(_on_escort_started)
		b.escort_finished.connect(_on_escort_finished)
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
	if not _is_active():
		return false
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
	if not _is_active():
		return # scène sortie de l'arbre (signal tardif d'un acteur) : pas d'arbre, pas de minuteur
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
	if not _is_active():
		return
	for cue: StringName in AMBIENCE_LOOPS:
		var p: AudioStreamPlayer = ambience_players[cue]
		if p.playing:
			continue
		# M14 (VH-9) : lit de station de l'acte ou du monde.
		var source: StringName = station_bed_cue(_day) if cue == &"amb.station_bed" else cue
		if not AudioCueBank.has_cue(source) or AudioCueBank.stream_of(source) == null:
			source = cue
		p.stream = AudioCueBank.stream_of(source)
		if p.stream == null:
			continue
		p.volume_db = SILENT_DB
		p.play(_rng.randf() * 4.0)
		var target: float = murmur_db() if cue == &"amb.queue_murmur" else AudioCueBank.volume_db_of(source)
		_fade(p, target, AMBIENCE_FADE_IN_SEC)
		_log(source, AudioBuses.AMBIENCE)


func stop_ambience(fade_sec: float = AMBIENCE_FADE_OUT_SEC) -> void:
	for cue: StringName in AMBIENCE_LOOPS:
		var p: AudioStreamPlayer = ambience_players[cue]
		if p.playing:
			_fade(p, SILENT_DB, fade_sec, true)


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
	if not _is_active():
		return
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
	var job: BarkJob = BarkJob.new()
	job.phrase = phrase
	job.profile = profile
	job.mood = mood
	# Méthode d'un `RefCounted` gardé par `_pending_barks` (pas de lambda : une
	# lambda capture `self`, le nœud, dans le thread de travail).
	var task: int = WorkerThreadPool.add_task(job.run, false, "TessarBark")
	_pending_barks.append([task, job, key, pa, line_key])


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
		var job: BarkJob = pending[1]
		var wav: AudioStreamWAV = AudioDsp.to_wav(job.samples, TessarVoice.SAMPLE_RATE)
		var key: String = pending[2]
		_cache_bark(key, wav)
		var line_key: String = pending[4]
		# Émetteur libéré pendant le rendu : ne jamais typer une instance
		# libérée (QA-012) — voix 2D de secours.
		var holder: Variant = pending[3]
		var pa: PassengerAudio = null
		if is_instance_valid(holder):
			pa = holder
		_say(pa, wav, line_key)


func _cache_bark(key: String, wav: AudioStreamWAV) -> void:
	if _bark_cache.size() >= BARK_CACHE_MAX:
		_bark_cache.clear()
	_bark_cache[key] = wav


func _say(pa: PassengerAudio, wav: AudioStreamWAV, line_key: String) -> void:
	if not _is_active():
		return
	if pa != null and pa.is_inside_tree() and pa.actor != null and pa.actor.visible:
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
	_since_bark = 0.0 # jamais d'annonce d'ambiance sur un bark (PaScheduler)


func _on_voice_finished() -> void:
	pass # le ducking suit `is_voice_active()` à chaque image


func is_voice_active() -> bool:
	if voice_2d.playing:
		return true
	for pa: PassengerAudio in live_passenger_audio():
		if pa.is_speaking():
			return true
	return false


## Émetteurs encore valides ; purge ceux dont l'acteur ou l'émetteur a été
## libéré (booth retiré par `--no-booth`, acteur détruit). Ne type jamais une
## instance libérée (affectation typée = SCRIPT ERROR, QA-012).
func live_passenger_audio() -> Array[PassengerAudio]:
	var live: Array[PassengerAudio] = []
	var kept: Dictionary[PassengerActor, PassengerAudio] = {}
	var actors: Array = passenger_audio.keys()
	var emitters: Array = passenger_audio.values()
	for i: int in emitters.size():
		var actor_value: Variant = actors[i]
		var emitter_value: Variant = emitters[i]
		if not is_instance_valid(actor_value) or not is_instance_valid(emitter_value):
			continue
		var actor: PassengerActor = actor_value
		var emitter: PassengerAudio = emitter_value
		kept[actor] = emitter
		live.append(emitter)
	if kept.size() != emitters.size():
		passenger_audio = kept
	return live


# ---------------------------------------------------------------------------
# Boucle : ducking, sondes UI, one-shots d'ambiance
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_poll_barks()
	_poll_pa()
	_update_ducks(delta)
	_poll_ui()
	_poll_screens()
	_update_pause()
	if get_tree().paused:
		return
	_since_bark = 0.0 if is_voice_active() else _since_bark + delta
	_since_game_announce += delta
	_update_intensity(delta)
	if phase != DayPhase.Kind.INTRO and phase != DayPhase.Kind.SUMMARY:
		_drop_left -= delta
		if _drop_left <= 0.0:
			_drop_left = _rng.randf_range(DROP_MIN_SEC, DROP_MAX_SEC)
			play_cue(&"amb.rain_drop_heavy")
		if _shift_open:
			var key: String = pa_scheduler.tick(delta, {"bark_active": is_voice_active() or not _pending_barks.is_empty(),
				"since_bark": _since_bark, "since_game_announce": _since_game_announce,
				"remaining_sec": _remaining_sec, "power_down": intensity.power_down, "event_id": _event_id})
			if not key.is_empty():
				announce_ambient(key)


func _update_ducks(delta: float) -> void:
	var target: float = 1.0 if is_voice_active() else 0.0
	var rate: float = delta / (DUCK_ATTACK_SEC if target > _voice_duck else DUCK_RELEASE_SEC)
	_voice_duck = move_toward(_voice_duck, target, rate)
	var insp_target: float = 1.0 if intensity.inspection_reduce and music_state == &"shift" else 0.0
	_inspection_duck = move_toward(_inspection_duck, insp_target, delta / INSPECTION_RAMP_SEC)
	_game_pa_left = maxf(_game_pa_left - delta, 0.0)
	_stamp_duck_left = maxf(_stamp_duck_left - delta, 0.0)
	var stamp_target: float = 1.0 if _stamp_duck_left > 0.0 else 0.0
	_stamp_duck = move_toward(_stamp_duck, stamp_target, delta / (0.02 if stamp_target > _stamp_duck else DUCK_RELEASE_SEC))
	_apply_ducks(_voice_duck, _stamp_duck)


func _apply_ducks(voice_level: float, stamp_level: float) -> void:
	var music_fx: AudioEffectAmplify = AudioBuses.get_effect(AudioBuses.MUSIC, AudioBuses.FX_DUCK) as AudioEffectAmplify
	var amb: AudioEffectAmplify = AudioBuses.get_effect(AudioBuses.AMBIENCE, AudioBuses.FX_DUCK) as AudioEffectAmplify
	var voice_fx: AudioEffectAmplify = AudioBuses.get_effect(AudioBuses.VOICE, AudioBuses.FX_DUCK) as AudioEffectAmplify
	if music_fx != null:
		var pa_on: float = 1.0 if (pa_player != null and pa_player.playing) or _game_pa_left > 0.0 else 0.0
		music_fx.volume_db = DUCK_VOICE_MUSIC_DB * voice_level + DUCK_STAMP_DB * stamp_level \
				+ INSPECTION_DUCK_DB * _inspection_duck + DUCK_PA_DB * pa_on + _music_extra_db
	if amb != null:
		amb.volume_db = DUCK_VOICE_AMBIENCE_DB * voice_level + DUCK_STAMP_DB * stamp_level
	if voice_fx != null:
		voice_fx.volume_db = DUCK_STAMP_DB * stamp_level


## Atténuation courante (dB) de l'effet `Duck` d'un bus.
func duck_db(bus_name: StringName) -> float:
	var fx: AudioEffectAmplify = AudioBuses.get_effect(bus_name, AudioBuses.FX_DUCK) as AudioEffectAmplify
	return fx.volume_db if fx != null else 0.0


## Effet `Muffle` du bus Music (passe-bas) : pause 2,5 kHz, Mode Inspection
## discret 3,5 kHz, power down 400 Hz (le plus bas l'emporte). Écrit seulement
## quand l'état change (paramètre d'effet, jamais un `volume_db` de lecteur).
func _update_pause() -> void:
	var paused: bool = get_tree().paused
	_paused_fx = paused
	var cutoff: float = 20000.0
	# Fondu de sortie (D-208) : l'arbre est en pause, mais ce n'est pas une
	# pause du joueur — fondu de bus seul, sans passe-bas (QA-074).
	if paused and not _leaving:
		cutoff = minf(cutoff, PAUSE_CUTOFF_HZ)
	if music_state == &"shift" and intensity.inspection_reduce:
		cutoff = minf(cutoff, INSPECTION_CUTOFF_HZ)
	if music_state == &"shift" and (intensity.power_down or intensity.action == HallAnnouncementDef.MUSIC_SILENCE):
		cutoff = minf(cutoff, POWER_DOWN_CUTOFF_HZ)
	_set_muffle(cutoff < 20000.0, cutoff)


func _set_muffle(on: bool, cutoff: float) -> void:
	if on == _muffle_on and (not on or is_equal_approx(cutoff, _muffle_cutoff)):
		return
	_muffle_on = on
	_muffle_cutoff = cutoff
	var fx: AudioEffectLowPassFilter = AudioBuses.get_effect(AudioBuses.MUSIC, AudioBuses.FX_MUFFLE) as AudioEffectLowPassFilter
	if fx != null and on:
		fx.cutoff_hz = cutoff
	AudioBuses.set_effect_enabled(AudioBuses.MUSIC, AudioBuses.FX_MUFFLE, on)


## Coupure de la musique en cours (tests, diagnostic) : passe-bas actif et sa fréquence.
func music_muffle() -> float:
	return _muffle_cutoff if _muffle_on else 0.0


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
		p_ui.passenger_line_shown.connect(_on_passenger_line_shown)


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
	if line_key.contains("denied") or line_key.contains("_exit_deny"):
		mood = TessarVoice.MOOD_ANGRY
	elif line_key.contains("detain"):
		mood = TessarVoice.MOOD_NERVOUS
	bark(_current_case, line_key, text, mood)


## M7 : réplique hors interrogatoire (pot-de-vin, phrase de passe) → bark.
func _on_passenger_line_shown(line_key: String, text: String) -> void:
	bark(_current_case, line_key, text, TessarVoice.MOOD_NEUTRAL)


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
	_day = day
	_warned = false
	_last_tick_second = -1
	start_ambience()
	start_day_music(day)
	for entry: RulebookEntry in rulebook:
		if entry.is_new:
			play_cue_later(&"ui.rule_new", RULE_CHIME_DELAY_SEC)
			break


func _on_day_phase_changed(p_phase: DayPhase.Kind, _case_id: StringName) -> void:
	var previous: DayPhase.Kind = phase
	phase = p_phase
	match p_phase:
		DayPhase.Kind.INTRO:
			if music_state == &"shift" or music_state == &"":
				music_state = &"briefing"
				music.force_level(MusicDirector.LEVEL_EXPOSED)
		DayPhase.Kind.WAITING_CASE:
			if previous == DayPhase.Kind.INTRO:
				open_shift_music()


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
	_remaining_sec = remaining if intensity.timed else INF
	intensity.remaining_sec = _remaining_sec
	if day_duration > 0.0:
		intensity.elapsed_ratio = clampf(1.0 - remaining / day_duration, 0.0, 1.0)


func _on_day_ended(summary: DaySummary) -> void:
	phase = DayPhase.Kind.SUMMARY
	hum_player.stop()
	stop_ambience()
	_shift_open = false
	end_shift_music(summary)


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
	if not _is_active():
		return
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
	bark(_current_case, line_key, answer_text(_current_case, line_key), mood)


## Texte prononcé d'une réponse : un cadre de déclarations (`line_stmt_*`,
## emplacements `{motif}`…) est composé avec les déclarations du cas
## (`Statement.compose`, casse de phrase), jamais lu brut.
static func answer_text(case: Case, line_key: String) -> String:
	var text: String = UiText.t(line_key, line_key)
	if case == null or case.statements.is_empty() or not text.contains("{"):
		return text
	return Statement.compose(text, case.statements, func(key: String) -> String: return UiText.t(key, key))


func _on_passenger_departed(_case_id: StringName) -> void:
	play_cue(&"booth.intercom_off")
	play_cue_later(&"station.door_close", DOOR_CLOSE_DELAY_SEC)


func _on_inspection_mode_changed(enabled: bool) -> void:
	play_cue(&"ui.inspect_mode_on" if enabled else &"ui.inspect_mode_off")
	_inspecting = enabled
	intensity.inspection_reduce = enabled and Settings.get_bool(Settings.KEY_MUSIC_INSPECTION_REDUCE)


func _on_check_requested(_a: FieldRef, _b: FieldRef) -> void:
	play_cue(&"ui.field_select_b")


func _on_discrepancy_checked(result: Discrepancy) -> void:
	match result.result:
		Discrepancy.Result.DISCORDANT:
			play_cue(&"ui.discrepancy")
			# P3 : discordance **constatée** par le joueur (jamais la vérité du cas).
			intensity.discrepancies += 1
			_discrepancy_reset_bars = -1
		Discrepancy.Result.CONCORDANT:
			play_cue(&"ui.match")
		_:
			play_cue(&"ui.incomparable")


# --- M7 ------------------------------------------------------------------------

## Objet glissé avec les papiers : froissement juste après la fente.
func _on_item_slipped(_item: SlippedItem) -> void:
	play_cue_later(&"passenger.paper_rustle", SLOT_OUT_DELAY_SEC)


## Décision sur un objet : tiroir (froissement), fente (`booth.slot_out`) ou
## appel de la Garde (`booth.intercom_on`).
func _on_item_decided(_item: SlippedItem, decision: SlippedItem.Decision) -> void:
	match decision:
		SlippedItem.Decision.KEEP:
			play_cue(&"passenger.paper_rustle")
		SlippedItem.Decision.RETURN:
			play_cue(&"booth.slot_out")
		SlippedItem.Decision.REPORT:
			play_cue(&"booth.intercom_on")


## Annonce du haut-parleur du Hall (bus Ambience, voix PA existante) ; effet
## musical de l'annonce (`HallAnnouncementDef.music_action`) ; une annonce qui
## termine le shift (grève du J20) coupe le courant (power down).
func _on_hall_announced(text_key: String) -> void:
	_since_game_announce = 0.0
	_game_pa_left = GAME_PA_SEC
	play_cue(&"amb.pa_announce")
	var def: HallAnnouncementDef = announcement_def(_day, text_key)
	if def != null:
		intensity.apply_action(def.music_action)
		if def.ends_shift:
			intensity.power_down = true


## Annonce de jeu du jour de clé `text_key` (null si absente).
static func announcement_def(day: DayDef, text_key: String) -> HallAnnouncementDef:
	if day == null:
		return null
	for def: HallAnnouncementDef in day.announcements:
		if def != null and def.text_key == text_key:
			return def
	return null


## Code 5 : une tape sur la vitre (émetteur du corps de l'acteur, sinon 2D).
func _on_glass_knocked(case_id: StringName, _knock: int) -> void:
	var pa: PassengerAudio = audio_for_case(case_id)
	if pa != null:
		pa.play_body(&"passenger.knock_glass")
		_log(&"passenger.knock_glass", AudioBuses.SFX)
	else:
		play_cue(&"passenger.knock_glass")


## Escorte de la Garde : porte de la station à l'entrée et à la sortie.
func _on_escort_started(_case_id: StringName) -> void:
	play_cue(&"station.door_open")


func _on_escort_finished(_case_id: StringName) -> void:
	play_cue(&"station.door_close")


func _on_verdict_stamped(verdict: Verdict) -> void:
	ui_pool.stop_cue(&"ui.stamp_hold")
	var approved: bool = verdict != null and verdict.kind == VerdictKind.Kind.APPROVE
	play_cue(&"booth.stamp_approved" if approved else &"booth.stamp_denied")
	play_cue_later(&"booth.stamp_lift", STAMP_LIFT_DELAY_SEC)
	_stamp_duck_left = DUCK_STAMP_HOLD_SEC


func _on_case_resolved(_case_id: StringName, _result: CaseResult) -> void:
	_discrepancy_reset_bars = MusicIntensity.DISCREPANCY_HOLD_BARS
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
			for pa: PassengerAudio in live_passenger_audio():
				pa.set_mono(mono)
		Settings.KEY_VOLUME_MUSIC:
			music.set_suspended(is_zero_approx(float(value)))
		Settings.KEY_MUSIC_DYNAMICS:
			intensity.stable = Settings.is_music_stable()
		Settings.KEY_MUSIC_INSPECTION_REDUCE:
			intensity.inspection_reduce = _inspecting and bool(value)


# ---------------------------------------------------------------------------
# M14 : musique dynamique (docs/AUDIO.md §13, docs/M14.md §2.5–§2.10)
# ---------------------------------------------------------------------------

## Ensemble d'un jour joué (même règle que `MusicLibraryDef.set_id_for_day`,
## recopiée ici : aucune référence de type à `MusicLibraryDef` dans un script
## chargé avec la scène, D-197).
static func set_id_for(day_number: int, mode: StringName = DayDef.MODE_CAMPAIGN) -> StringName:
	if mode == DayDef.MODE_GARDE:
		return SET_GARDE
	if mode == DayDef.MODE_EPILOGUE or day_number > 30:
		return SET_EPILOGUE
	if day_number <= 10:
		return SET_ACT1
	return SET_ACT2 if day_number <= 20 else SET_ACT3


## Ensemble rendu (`assets/audio/music/sets/<id>.tres`), null s'il n'existe pas
## (musique pas encore rendue : silence, comportement 0.13 sans musique M6).
static func load_set(set_id: StringName) -> MusicSetDef:
	var path: String = MUSIC_SETS_DIR + String(set_id) + ".tres"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as MusicSetDef


static var _index_cache: Dictionary = {}


## Index léger des thèmes (`assets/audio/music/index.json`, écrit par
## `build_music.gd --defs`) : choisir un thème sans charger le catalogue
## (RAM musique ≤ 6 Mo, docs/M14.md §2.12).
static func music_index() -> Dictionary:
	if _index_cache.is_empty() and FileAccess.file_exists(MUSIC_INDEX_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MUSIC_INDEX_PATH))
		if parsed is Dictionary:
			_index_cache = parsed
	return _index_cache


## Thème d'une fin (même règle que `MusicLibraryDef.theme_for_ending` : un
## thème qui nomme la variante, sinon un thème sans variante) ; chemin vide si aucun.
static func theme_path_for_ending(ending: StringName, variant: StringName, index: Dictionary = {}) -> String:
	var themes: Dictionary = (index if not index.is_empty() else music_index()).get("themes", {})
	var ids: Array = themes.keys()
	ids.sort()
	var generic: String = ""
	for theme_key: String in ids:
		var entry: Dictionary = themes[theme_key]
		if not (entry.get("endings", []) as Array).has(String(ending)):
			continue
		var variants: Array = entry.get("ending_variants", [])
		if variants.is_empty():
			if generic.is_empty():
				generic = str(entry["path"])
		elif variants.has(String(variant)):
			return str(entry["path"])
	return generic


## Thème d'un monde du J31 ; chemin vide si aucun.
static func theme_path_for_world(world: StringName, index: Dictionary = {}) -> String:
	var themes: Dictionary = (index if not index.is_empty() else music_index()).get("themes", {})
	var ids: Array = themes.keys()
	ids.sort()
	for theme_key: String in ids:
		if (themes[theme_key].get("worlds", []) as Array).has(String(world)):
			return str(themes[theme_key]["path"])
	return ""


## Début du jour : ensemble du jour (+ soirée MS-06), « exposé » au briefing,
## intensité et annonces d'ambiance remises à zéro.
func start_day_music(day: DayDef) -> void:
	_leaving = false
	music_state = &""
	theme_id = &""
	_shift_open = false
	_event_id = &""
	_remaining_sec = INF
	_discrepancy_reset_bars = -1
	if day == null or not _is_active():
		return
	var garde: bool = day.mode == DayDef.MODE_GARDE
	var epilogue: bool = day.mode == DayDef.MODE_EPILOGUE
	intensity = MusicIntensity.new()
	intensity.timed = not day.untimed and not epilogue
	intensity.capped = GameState.is_story_mode() or epilogue or day.day_number > 30
	intensity.tension = day.music_tension
	intensity.floor_level = day.music_floor
	intensity.stable = Settings.is_music_stable()
	intensity.garde = garde
	intensity.queue_remaining = -1 if garde else day.passenger_count
	intensity.quota_max = day.air_quota
	intensity.inspection_reduce = _inspecting and Settings.get_bool(Settings.KEY_MUSIC_INSPECTION_REDUCE)
	var world: StringName = day.epilogue_world if epilogue else &""
	pa_scheduler.setup(GameState.campaign_seed if not garde else GameState.get_day_seed(), day.day_number, garde,
			world, func(key: String) -> bool: return UiText.has(key))
	day_set = load_set(set_id_for(day.day_number, day.mode))
	evening_set = load_set(SET_EVENING) if day.mode == DayDef.MODE_CAMPAIGN else null
	var groups: Array[StringName] = []
	if epilogue and world != &"":
		groups.append(StringName("world_" + String(world)))
	music.set_groups(groups)
	if day_set == null:
		return
	music.configure_from_def(day_set)
	if evening_set != null:
		music.configure_from_def(evening_set)
	music_state = &"briefing"
	music.play(day_set.id, MusicDirector.LEVEL_EXPOSED, MUSIC_ENTER_SEC)


## Fermeture du briefing : le shift commence à N0 (à la mesure suivante).
func open_shift_music() -> void:
	_shift_open = true
	if music_state != &"briefing":
		return
	music_state = &"shift"
	intensity.smoothed = 0.0
	intensity.level = 0
	music.request_level(0)


## Sirène : bilan et soirée sur MS-06 (fondu croisé de 2 mesures dans le flux),
## Garde : MS-05 au repos, J31 : le thème vient avec la conclusion.
func end_shift_music(summary: DaySummary) -> void:
	intensity.inspection_reduce = false
	intensity.power_down = false
	_music_extra_db = 0.0
	music.mute_motif = false
	music.power_down = false
	music.fast_up = false
	if _day == null or music_state == &"":
		return
	match _day.mode:
		DayDef.MODE_GARDE:
			music_state = &"garde_end"
			music.request_level(1)
		DayDef.MODE_EPILOGUE:
			music_state = &"epilogue_end"
			music.request_level(0)
		_:
			if evening_set == null:
				return
			music_state = &"evening"
			music.set_groups(evening_groups(summary))
			music.switch_clip(evening_set.id, 0)


## MS-06 : couche « crise » si le solde est négatif ou un proche malade ou
## froid, sinon « chaud » (docs/M14.md §2.2).
static func evening_groups(summary: DaySummary = null) -> Array[StringName]:
	var crisis: bool = GameState.credits < 0 or (summary != null and summary.get_net() < 0)
	if GameState.household != null:
		for member: Household.Member in GameState.household.present_members():
			if member.is_sick() or member.cold:
				crisis = true
	return [GROUP_CRISIS if crisis else GROUP_WARM]


## Intensité recalculée à 4 Hz pendant le shift ; décision appliquée à la
## mesure par `MusicDirector` (+1 / 2 mesures, −1 / 4 mesures).
func _update_intensity(delta: float) -> void:
	if music_state != &"shift":
		return
	_intensity_left -= delta
	if _intensity_left > 0.0:
		return
	var step_sec: float = 1.0 / MusicIntensity.UPDATE_HZ
	_intensity_left += step_sec
	if _intensity_left < 0.0:
		_intensity_left = step_sec
	intensity.step(step_sec)
	var decision: Dictionary = intensity.decide(day_set)
	music.request_level(int(decision["level"]))
	var mask: int = int(decision["mask"])
	music.mute_motif = (mask & MusicSetDef.MASK_NO_MELODY) != 0
	music.power_down = (mask & MusicSetDef.MASK_POWER_DOWN) != 0
	music.fast_up = bool(decision.get("fast_up", false))
	_music_extra_db = float(decision["extra_db"])


func _on_music_bar(_index: int) -> void:
	intensity.on_bar()
	if _discrepancy_reset_bars > 0:
		_discrepancy_reset_bars -= 1
		if _discrepancy_reset_bars == 0:
			intensity.discrepancies = 0
			_discrepancy_reset_bars = -1


func _on_quota_changed(used: int, maximum: int) -> void:
	intensity.quota_used = used
	intensity.quota_max = maximum


func _on_station_event_started(plan: StationEventPlan) -> void:
	if plan == null or plan.event == null:
		return
	_since_game_announce = 0.0
	if plan.event.id == EVENT_POWER_CUT:
		intensity.power_down = true
		return
	_event_id = plan.event.id
	intensity.event_weight = plan.event.music_weight


func _on_station_event_ended(plan: StationEventPlan) -> void:
	if plan != null and plan.event != null and plan.event.id == EVENT_POWER_CUT:
		intensity.power_down = false
		return
	_event_id = &""
	intensity.event_weight = 0.0


## File réelle (P1) et murmure ∝ silhouettes visibles (0 → −6 dB) : une
## écriture de volume par avance de la file, jamais par image.
func _on_queue_progressed(processed: int, total: int, _upcoming: Array[QueueSilhouette]) -> void:
	intensity.queue_remaining = total - processed if total >= 0 else -1
	var visible: int = QUEUE_PLACES if total < 0 else QueueSilhouette.visible_count(processed, total, QUEUE_PLACES)
	_murmur_ratio = clampf(float(visible) / QUEUE_PLACES, 0.0, 1.0)
	var p: AudioStreamPlayer = ambience_players.get(&"amb.queue_murmur", null)
	if p != null and p.playing:
		var tween: Tween = _tweens.get(p, null)
		if tween == null or not tween.is_valid():
			p.volume_db = murmur_db()


var _murmur_ratio: float = 1.0


## Volume du murmure de la file pour la file visible courante.
func murmur_db() -> float:
	return AudioCueBank.volume_db_of(&"amb.queue_murmur") + lerpf(MURMUR_MIN_DB, 0.0, _murmur_ratio)


func _on_garde_tier_changed(tier: int) -> void:
	intensity.garde_tier = tier
	intensity.garde_errors = 0


func _on_garde_error(_case_id: StringName, _citation_key: String, _errors: int) -> void:
	intensity.garde_errors += 1


## Lit de station du jour : acte II, acte III, monde D du J31 (VH-9).
static func station_bed_cue(day: DayDef) -> StringName:
	if day == null or day.mode == DayDef.MODE_GARDE:
		return &"amb.station_bed"
	if day.mode == DayDef.MODE_EPILOGUE:
		return &"amb.station_bed_d" if day.epilogue_world == &"d" else &"amb.station_bed"
	if day.day_number > 20:
		return &"amb.station_bed_a3"
	return &"amb.station_bed_a2" if day.day_number > 10 else &"amb.station_bed"


# --- Écrans de fin, cinématiques, épilogue --------------------------------------

## Écran plein cadre de `DayScene` (lu, jamais modifié) : soirée (couche chaud /
## crise), fin (thème), conclusion du J31 (queue du thème de la fin d'origine),
## cinématique du lot D (`CinematicScreen`, reconnue par son nom de classe).
func _poll_screens() -> void:
	var scene: DayScene = owner as DayScene
	if scene == null:
		return
	var value: Variant = scene.screen
	var current: Node = value as Node if is_instance_valid(value) else null
	if current == _screen_seen:
		return
	_screen_seen = current
	if current == null:
		return
	if current is EveningScreen and music_state == &"evening":
		music.set_groups(evening_groups())
	elif current is EndScreen:
		on_end_screen((current as EndScreen).ending)
	elif String(current.name) == "EpilogueConclusion":
		play_epilogue_tail()
	elif is_cinematic_screen(current):
		on_cinematic_started(current)


static func is_cinematic_screen(node: Node) -> bool:
	var script: Script = node.get_script() as Script if node != null else null
	return script != null and script.get_global_name() == &"CinematicScreen"


## Écran de fin : le thème de la fin (déjà lancé par la cinématique, sinon
## maintenant). TH-F7 (`reuse_set_id`) : la sortie sous l'écran de fin.
func on_end_screen(ending: StringName) -> void:
	var flags: Dictionary[StringName, Variant] = GameState.narrative_flags
	if SIMULATED_EARLY_ENDINGS.has(ending) and EpilogueService.act_of(flags) < 3:
		return # fins simulées des actes I–II (pas de cinématique) : MS-06 continue (QA-079)
	var path: String = theme_path_for_ending(ending, EpilogueService.variant_of(ending, flags))
	if path.is_empty() or not ResourceLoader.exists(path):
		return # démo : MS-06 continue
	var theme: MusicThemeDef = load(path) as MusicThemeDef
	if theme == null:
		return
	if theme.id == theme_id and music_state == &"cinematic":
		music_state = &"end"
		if theme.reuse_set_id != &"":
			music.skip_to_tail()
		return
	play_theme(theme, flags, theme.reuse_set_id != &"")
	music_state = &"end"


## Cinématique (lot D) : le thème de la fin depuis le début, calé sur la
## carte de titre ; J31 : le thème du monde. `finished(true)` (passée) → queue.
func on_cinematic_started(screen_node: Node) -> void:
	if screen_node.has_signal(&"finished"):
		screen_node.connect(&"finished", _on_cinematic_finished, CONNECT_ONE_SHOT)
	if _day != null and _day.mode == DayDef.MODE_EPILOGUE:
		var world_path: String = theme_path_for_world(_day.epilogue_world)
		if not world_path.is_empty() and ResourceLoader.exists(world_path):
			play_theme(load(world_path) as MusicThemeDef, {}, false)
			music_state = &"cinematic"
		return
	var ending: StringName = StringName(str(screen_node.get(&"ending"))) if &"ending" in screen_node else &""
	var flags: Dictionary[StringName, Variant] = GameState.narrative_flags
	var path: String = theme_path_for_ending(ending, EpilogueService.variant_of(ending, flags))
	if not path.is_empty() and ResourceLoader.exists(path):
		play_theme(load(path) as MusicThemeDef, flags, false)
		music_state = &"cinematic"


func _on_cinematic_finished(skipped: bool) -> void:
	if skipped:
		skip_music_to_tail()


## Cinématique passée (appel direct possible du lot D) : queue à la mesure suivante.
func skip_music_to_tail() -> void:
	music.skip_to_tail()


## Conclusion du J31 : queue du thème de la fin d'origine (graine d'épilogue).
func play_epilogue_tail() -> void:
	var epi: Dictionary = GameState.epilogue_seed
	var ending: StringName = StringName(str(epi.get("ending", "")))
	var path: String = theme_path_for_ending(ending, StringName(str(epi.get("variant", ""))))
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var theme: MusicThemeDef = load(path) as MusicThemeDef
	if theme != null:
		play_theme(theme, GameState.narrative_flags, true)
		music_state = &"epilogue_end"


## Fondu de sortie de 2 s (effet `Fade`), puis le thème (variante selon les
## drapeaux ; « effets réduits » si `fx_intensity` < 1).
func play_theme(theme: MusicThemeDef, flags: Dictionary[StringName, Variant], tail_first: bool) -> void:
	if theme == null or not _is_active():
		return
	theme_id = theme.id
	music.play_theme_after_fade(theme, flags, fx_reduced, END_FADE_SEC, tail_first)


# --- Annonces d'ambiance (VH-6, B85) -------------------------------------------

static var _pa_profile: TessarVoice.Profile = null


## Voix du haut-parleur (profil fixe : la même voix chaque jour).
static func pa_profile() -> TessarVoice.Profile:
	if _pa_profile == null:
		var p: Passenger = Passenger.new()
		p.sex = Passenger.SEX_F
		p.appearance_seed = 9100
		_pa_profile = TessarVoice.profile_for(p)
		_pa_profile.jitter = 0.003
		_pa_profile.breath = 0.03
	return _pa_profile


## Annonce d'ambiance `key` (texte `fr.csv`, lot E) : rendue dans un thread de
## travail (QA-030), puis jouée sur le bus Ambience et sous-titrée
## (`ambient_announced`, option sous-titres côté UI). Jamais deux à la fois.
func announce_ambient(key: String) -> void:
	if not _is_active() or not _pending_pa.is_empty():
		return
	if not UiText.has(key):
		return # texte du lot E absent : rien (jamais la clé brute en sous-titre)
	var text: String = UiText.t(key, "")
	if text.is_empty():
		return
	var job: PaJob = PaJob.new()
	job.key = key
	job.text = text
	job.phrase = TessarVoice.phrase_for(key, text)
	job.profile = pa_profile()
	job.world = _day.epilogue_world if _day != null and _day.mode == DayDef.MODE_EPILOGUE else &""
	if sync_barks:
		job.run()
		_play_pa(job)
		return
	var task: int = WorkerThreadPool.add_task(job.run, false, "TessarPA")
	_pending_pa = [task, job]


func _poll_pa() -> void:
	if _pending_pa.is_empty():
		return
	var task: int = _pending_pa[0]
	if not WorkerThreadPool.is_task_completed(task):
		return
	WorkerThreadPool.wait_for_task_completion(task)
	var job: PaJob = _pending_pa[1]
	_pending_pa = []
	_play_pa(job)


func _play_pa(job: PaJob) -> void:
	if not _is_active() or job.samples.is_empty():
		return
	var wav: AudioStreamWAV = AudioDsp.to_wav(job.samples, PaScheduler.RATE)
	pa_player.stop()
	pa_player.stream = wav
	pa_player.play()
	_log(&"amb.pa_ambient", AudioBuses.AMBIENCE)
	EventBus.ambient_announced.emit(job.key, PaScheduler.subtitle_seconds(wav.get_length(), job.text))


## Fondu de sortie de la musique par l'effet `Fade` (soirée → jour suivant,
## écran de fin → titre : 1,5 s, docs/M14.md §2.6). À appeler par la scène
## (lot D) avant `reload_current_scene` / `change_scene_to_file` ; renvoie la
## durée à attendre (0 sans musique). La scène est quittée : la pause de
## l'arbre qui suit n'y pose pas le passe-bas de pause (QA-074).
func fade_out_music(seconds: float = MUSIC_ENTER_SEC) -> float:
	if music == null or not music.is_playing():
		return 0.0
	_leaving = true
	music.fade_to(MusicDirector.SILENT_DB, seconds, true)
	return seconds
