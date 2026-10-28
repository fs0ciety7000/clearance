## Sons 3D d'un passager (docs/AUDIO.md §3) : émetteurs pieds (`SFX_World`),
## corps (`SFX`) et voix (`Voice`, hygiaphone) accrochés à un `PassengerActor`.
##
## Ajouté **à l'exécution** comme enfant de l'acteur par `AudioDirector` :
## aucun script du booth n'est modifié. Écoute `PassengerActor.anim_event`
## (`footstep_l/r`, `documents_slot`, `papers_show`, `visor_off`, `breath_in`…)
## et `arrived`, et joue les respirations d'attente au guichet.
class_name PassengerAudio
extends Node3D

## Une réplique commence (durée en s) / se termine : ducking.
signal voice_started(duration: float)
signal voice_finished()

const UNIT_SIZE: float = 3.0
const MAX_DISTANCE: float = 20.0
const PANNING: float = 0.6
const HEAD_HEIGHT: float = 1.6
const BODY_HEIGHT: float = 1.15
## Attente entre deux respirations au guichet (s) ; ÷2 si nerveux.
const BREATH_MIN: float = 4.0
const BREATH_MAX: float = 9.0
## Désaccord gauche/droite des pas (casse la régularité).
const FOOT_DETUNE: float = 0.02

var actor: PassengerActor = null
var profile: TessarVoice.Profile = TessarVoice.Profile.new()
var nervous: bool = false
var foot: AudioStreamPlayer3D = null
var breath_emitter: AudioStreamPlayer3D = null
var body: AudioStreamPlayer3D = null
var voice: AudioStreamPlayer3D = null
## Dernières cues jouées (tests, diagnostic) : [cue, bus].
var history: Array[Array] = []
## Clé de la réplique en cours.
var voice_line: String = ""

var _breath_left: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Crée les émetteurs et se branche sur `p_actor`.
func attach(p_actor: PassengerActor) -> void:
	actor = p_actor
	name = "PassengerAudio"
	foot = _emitter("FootEmitter", AudioBuses.SFX_WORLD, 0.05, 2)
	breath_emitter = _emitter("BreathEmitter", AudioBuses.SFX, HEAD_HEIGHT - 0.1, 1)
	body = _emitter("BodyEmitter", AudioBuses.SFX, BODY_HEIGHT, 1)
	voice = _emitter("VoiceEmitter", AudioBuses.VOICE, HEAD_HEIGHT, 1)
	voice.finished.connect(_on_voice_finished)
	actor.anim_event.connect(on_anim_event)
	actor.arrived.connect(_on_arrived)
	set_mono(Settings.get_bool(Settings.KEY_AUDIO_MONO))
	_breath_left = _rng.randf_range(BREATH_MIN, BREATH_MAX)


func _emitter(node_name: String, bus_name: StringName, height: float, polyphony: int) -> AudioStreamPlayer3D:
	var e: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	e.name = node_name
	e.bus = bus_name
	e.position = Vector3(0.0, height, 0.0)
	e.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	e.unit_size = UNIT_SIZE
	e.max_distance = MAX_DISTANCE
	e.panning_strength = PANNING
	e.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	e.max_polyphony = polyphony
	add_child(e)
	return e


## Nouveau passager : timbre de voix et graine des variations.
func configure(passenger: Passenger) -> void:
	profile = TessarVoice.profile_for(passenger)
	_rng.seed = profile.voice_seed
	nervous = false
	stop_voice()


## Option Mono (§9) : pas de panoramique 3D.
func set_mono(mono: bool) -> void:
	for e: AudioStreamPlayer3D in [foot, breath_emitter, body, voice]:
		if e != null:
			e.panning_strength = 0.0 if mono else PANNING


## Repères d'animation de l'acteur.
func on_anim_event(event_name: StringName) -> void:
	match event_name:
		&"footstep_l", &"footstep_r":
			play_step(event_name == &"footstep_l")
		&"documents_slot":
			play_body(&"passenger.paper_rustle")
		&"papers_show", &"visor_off", &"cloth":
			play_body(&"passenger.cloth_rustle")
		&"breath_in", &"breath":
			play_breath(&"passenger.breath_idle")


func play_step(left: bool) -> void:
	_play_on(foot, &"passenger.step", 1.0 - FOOT_DETUNE if left else 1.0 + FOOT_DETUNE)


func play_body(cue: StringName) -> void:
	_play_on(body, cue)


func play_breath(cue: StringName) -> void:
	_play_on(breath_emitter, cue)
	_breath_left = _rng.randf_range(BREATH_MIN, BREATH_MAX) * (0.5 if nervous else 1.0)


func _play_on(e: AudioStreamPlayer3D, cue: StringName, pitch: float = 1.0) -> void:
	# QA-025 : un acteur sorti de l'arbre (rechargement de scène pendant une
	# marche, repère d'animation tardif) ne joue rien.
	if e == null or not e.is_inside_tree() or not _audible():
		return
	var stream: AudioStream = AudioCueBank.stream_of(cue)
	if stream == null:
		return
	if e.stream != stream:
		e.stream = stream
	e.volume_db = AudioCueBank.volume_db_of(cue)
	e.pitch_scale = pitch
	e.play()
	_log(cue, StringName(e.bus))


## Joue une réplique (coupe la précédente : jamais deux barks à la fois).
func say(stream: AudioStream, line_key: String = "") -> void:
	if voice == null or stream == null or not voice.is_inside_tree():
		return
	voice.stop()
	voice.stream = stream
	voice.volume_db = 0.0
	voice_line = line_key
	voice.play()
	_log(&"passenger.bark", AudioBuses.VOICE)
	voice_started.emit(stream.get_length())


func stop_voice() -> void:
	if voice != null and voice.playing:
		voice.stop()
		_on_voice_finished()


func is_speaking() -> bool:
	return voice != null and voice.playing


func _on_voice_finished() -> void:
	voice_line = ""
	voice_finished.emit()


func _on_arrived() -> void:
	_play_on(foot, &"passenger.step_stop")


func _process(delta: float) -> void:
	if actor == null or actor.state != PassengerActor.State.AT_DESK or not actor.visible:
		return
	_breath_left -= delta
	if _breath_left <= 0.0:
		if is_speaking():
			_breath_left = 1.0
			return
		play_breath(&"passenger.breath_nervous" if nervous and _rng.randf() < 0.4 else &"passenger.breath_idle")


func _audible() -> bool:
	return actor == null or actor.visible


func _log(cue: StringName, bus_name: StringName) -> void:
	history.append([cue, bus_name])
	if history.size() > 32:
		history.pop_front()
