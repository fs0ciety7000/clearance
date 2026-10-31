## Stress D-083 du moteur musical M14 (B82, docs/M14.md §2.9, M-17 ;
## docs/AUDIO.md §13.6) — lancé par `tools/qa_boot.gd` (autoloads requis),
## en général via `bash tools/qa_audio_stress.sh`.
##
## Le moteur testé est le vrai `MusicDirector` (un lecteur à volume fixe,
## `AudioStreamInteractive` de clips `AudioStreamSynchronized`, fondus par
## l'effet `Fade` du bus `Music`). Il est **greffé** sous l'`AudioDirector` de
## chaque `day.tscn` chargée (signal `node_added`), sans toucher au jeu, puis
## brutalisé : niveaux forcés toutes les `--qa-level-every` s (0,5 s par
## défaut ; 0 = à chaque image), changements de clip (fondu croisé dans le
## flux), fondus de bus, relances de lecture.
##
## Modes (`--qa-stress=`) :
## - `reload` (défaut) : la vraie scène (`--day=N --seed=S --autoplay` lus par
##   `DayScene`) rechargée `--qa-reloads=N` fois, toutes les 1–240 images
##   (`--qa-min-frames`, `--qa-max-frames`), briefing comme plein shift : le
##   protocole de QA-030 (docs/QA.md §12.12) ;
## - `campaign` : ajoute `tools/qa_campaign.gd` (même ligne de commande :
##   `--qa-seed`, `--qa-profile`, `--qa-reload`…) et greffe le moteur dans
##   chaque scène de la campagne ;
## - `bare` : scène minimale (le directeur seul), rechargée très souvent :
##   le moteur isolé, des milliers de cycles lecture → libération.
## Contrôles (sensibilité de l'outil, jamais en production) :
## - `--qa-control=off` : aucun moteur greffé (le jeu seul : ligne de base) ;
## - `--qa-control=legacy` : greffe à la place deux lecteurs dont le
##   `volume_db` est réécrit à chaque image (le schéma que D-176 abandonne) ;
## - `--qa-no-barrier` : met `AudioMixBarrier` en pause (le correctif D-083
##   retiré) : montre que le protocole sait faire planter Godot 4.7.2.
## Couches : `--qa-layers=ms03` (les 5 couches de MS-03 ; les boucles M6
## `mus_*` de la phase 1 n'existent plus) ou `ms02` (défaut si présentes).
##
## Sortie : `QA_STRESS …` tous les 25 rechargements, `QA_STRESS_DONE …` puis
## sortie par `AudioMixBarrier.quit_after_silence()` (les fuites éventuelles
## sont imprimées par le moteur : le script shell les compte).
extends Node

const DAY_SCENE: String = "res://scenes/main/day.tscn"
## Couches de repli (`--qa-layers=ms03`) : MS-03 (les boucles M6 `mus_*` ont
## été supprimées en phase 2).
const LEGACY_LAYERS: Array[String] = [
	"res://assets/audio/music/ms03/mus_ms03_l0_loop.ogg",
	"res://assets/audio/music/ms03/mus_ms03_l1_loop.ogg",
	"res://assets/audio/music/ms03/mus_ms03_l2_loop.ogg",
	"res://assets/audio/music/ms03/mus_ms03_l3_loop.ogg",
	"res://assets/audio/music/ms03/mus_ms03_l4_loop.ogg",
]
const MS02_DIR: String = "res://assets/audio/music/ms02"
const CLIP_A: StringName = &"ms02"
const CLIP_B: StringName = &"ms06_test"
const CLIP_THEME: StringName = &"theme_test"

var _mode: String = "reload"
var _control: String = ""
var _no_barrier: bool = false
var _reloads_wanted: int = 1000
var _min_frames: int = 1
var _max_frames: int = 240
var _level_every: float = 0.5
var _speed: float = 8.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _layers: Array[AudioStream] = []
var _layer_source: String = ""

var _reloads: int = 0
var _frames_left: int = 0
var _injected: int = 0
var _level_changes: int = 0
var _clip_switches: int = 0
var _fades: int = 0
var _restarts: int = 0
var _legacy_writes: int = 0
var _layer_writes_total: int = 0
var _directors: Array[MusicDirector] = []
var _legacy: Array[AudioStreamPlayer] = []
var _level_left: float = 0.0
var _clip_left: float = 3.0
var _fade_left: float = 2.0
var _restart_left: float = 9.0
var _last_usec: int = 0
var _done: bool = false
var _started_msec: int = 0
var _campaign: Node = null
var _last_report_msec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var seed_value: int = 0xD083
	var layer_kind: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-stress="):
			_mode = arg.trim_prefix("--qa-stress=")
		elif arg.begins_with("--qa-control="):
			_control = arg.trim_prefix("--qa-control=")
		elif arg == "--qa-no-barrier":
			_no_barrier = true
		elif arg.begins_with("--qa-reloads="):
			_reloads_wanted = arg.trim_prefix("--qa-reloads=").to_int()
		elif arg.begins_with("--qa-min-frames="):
			_min_frames = maxi(arg.trim_prefix("--qa-min-frames=").to_int(), 1)
		elif arg.begins_with("--qa-max-frames="):
			_max_frames = maxi(arg.trim_prefix("--qa-max-frames=").to_int(), 1)
		elif arg.begins_with("--qa-level-every="):
			_level_every = maxf(arg.trim_prefix("--qa-level-every=").to_float(), 0.0)
		elif arg.begins_with("--qa-speed="):
			_speed = arg.trim_prefix("--qa-speed=").to_float()
		elif arg.begins_with("--qa-stress-seed="):
			seed_value = arg.trim_prefix("--qa-stress-seed=").to_int()
		elif arg.begins_with("--qa-layers="):
			layer_kind = arg.trim_prefix("--qa-layers=")
	_rng.seed = seed_value
	_load_layers(layer_kind)
	if _no_barrier:
		var barrier: Node = get_node_or_null(^"/root/AudioMixBarrier")
		if barrier != null:
			barrier.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().node_added.connect(_on_node_added)
	_started_msec = Time.get_ticks_msec()
	_last_usec = Time.get_ticks_usec()
	print("QA_STRESS_START mode=%s control=%s barrier=%s layers=%s reloads=%d frames=%d-%d level_every=%.2f seed=%d" % [
		_mode, _control if not _control.is_empty() else "none", "off" if _no_barrier else "on", _layer_source,
		_reloads_wanted, _min_frames, _max_frames, _level_every, seed_value])
	match _mode:
		"campaign":
			var script: GDScript = load("res://tools/qa_campaign.gd") as GDScript
			_campaign = script.new()
			_campaign.name = "QACampaign"
			get_parent().add_child.call_deferred(_campaign)
		"bare":
			_frames_left = _next_interval()
			_load_bare_scene.call_deferred()
		_:
			Engine.time_scale = _speed
			_frames_left = _next_interval()
			get_tree().change_scene_to_file.call_deferred(DAY_SCENE)


func _load_layers(kind: String) -> void:
	var use_ms02: bool = kind == "ms02" or (kind.is_empty() and ResourceLoader.exists(MS02_DIR + "/mus_ms02_l0_loop.ogg"))
	if use_ms02:
		for i: int in 5:
			_layers.append(load("%s/mus_ms02_l%d_loop.ogg" % [MS02_DIR, i]) as AudioStream)
		_layer_source = "ms02"
	else:
		for path: String in LEGACY_LAYERS:
			_layers.append(load(path) as AudioStream)
		_layer_source = "ms03"


func _next_interval() -> int:
	return _rng.randi_range(_min_frames, _max_frames)


func _on_node_added(node: Node) -> void:
	if _mode == "bare":
		return
	if node is AudioDirector:
		_inject.call_deferred(node)


## Greffe le moteur testé sous `parent` (l'`AudioDirector` de la scène).
func _inject(parent: Node) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	_injected += 1
	if _control == "off":
		return
	if _control == "legacy":
		for i: int in 2:
			var p: AudioStreamPlayer = AudioStreamPlayer.new()
			p.name = "LegacyMusic%d" % i
			p.bus = AudioBuses.MUSIC
			p.stream = _layers[i]
			p.volume_db = -20.0
			parent.add_child(p)
			p.play()
			_legacy.append(p)
		return
	var director: MusicDirector = MusicDirector.new()
	director.name = "MusicDirector"
	parent.add_child(director)
	_configure(director)
	_track(director)
	director.play(CLIP_A, _rng.randi_range(0, MusicDirector.LEVEL_COUNT - 1), 0.5)


func _configure(director: MusicDirector) -> void:
	var gains: PackedFloat32Array = PackedFloat32Array([-12.0, -14.0, -16.0, -14.0, -15.0])
	director.configure_set(CLIP_A, _layers, 80.0, 4, gains)
	var shuffled: Array[AudioStream] = [_layers[2], _layers[0], _layers[4]]
	director.configure_set(CLIP_B, shuffled, 80.0, 4, PackedFloat32Array([-12.0, -14.0, -14.0]))
	director.configure_theme(CLIP_THEME, _layers[3], 80.0, 4)


func _load_bare_scene() -> void:
	var scene: Node = Node.new()
	scene.name = "BareMusicScene"
	var old: Node = get_tree().current_scene
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	if old != null:
		old.queue_free()
	if _control == "legacy":
		_inject(scene)
		return
	var director: MusicDirector = MusicDirector.new()
	director.name = "MusicDirector"
	scene.add_child(director)
	_configure(director)
	_track(director)
	director.play(CLIP_A, _rng.randi_range(0, MusicDirector.LEVEL_COUNT - 1), 0.25)
	_injected += 1


func _process(_delta: float) -> void:
	if _done:
		return
	var now: int = Time.get_ticks_usec()
	var dt: float = clampf((now - _last_usec) / 1_000_000.0, 0.0, 0.25)
	_last_usec = now
	_prune()
	_poke_engine(dt)
	if _mode == "campaign":
		if Time.get_ticks_msec() - _last_report_msec >= 60_000:
			_last_report_msec = Time.get_ticks_msec()
			_report("QA_STRESS")
		return
	_frames_left -= 1
	if _frames_left > 0:
		return
	_frames_left = _next_interval()
	_reloads += 1
	if _reloads % 25 == 0:
		_report("QA_STRESS")
	if _reloads >= _reloads_wanted:
		_finish()
		return
	if _mode == "bare":
		_load_bare_scene()
	else:
		get_tree().reload_current_scene.call_deferred()


## Les opérations brutales sur chaque moteur vivant.
func _poke_engine(dt: float) -> void:
	_level_left -= dt
	_clip_left -= dt
	_fade_left -= dt
	_restart_left -= dt
	var level_now: bool = _level_left <= 0.0
	if level_now:
		_level_left = _level_every
	for p: AudioStreamPlayer in _legacy:
		if p.is_inside_tree():
			# Schéma abandonné : volume du lecteur réécrit à chaque image.
			p.volume_db = -20.0 + _rng.randf_range(-6.0, 0.0)
			_legacy_writes += 1
	for director: MusicDirector in _directors:
		if not director.is_inside_tree():
			continue
		if level_now:
			director.force_level(_rng.randi_range(MusicDirector.LEVEL_EXPOSED, MusicDirector.LEVEL_COUNT - 1))
			director.mute_motif = _rng.randf() < 0.2
		if _clip_left <= 0.0:
			var clips: Array[StringName] = [CLIP_A, CLIP_B, CLIP_THEME]
			director.switch_clip(clips[_rng.randi_range(0, 2)], _rng.randi_range(0, MusicDirector.LEVEL_COUNT - 1))
			_clip_switches += 1
		if _fade_left <= 0.0:
			director.fade_to(_rng.randf_range(-24.0, 0.0), _rng.randf_range(0.0, 1.5))
			_fades += 1
		if _restart_left <= 0.0:
			director.play(CLIP_A, _rng.randi_range(0, MusicDirector.LEVEL_COUNT - 1), 0.3)
			_restarts += 1
	if _clip_left <= 0.0:
		_clip_left = _rng.randf_range(1.0, 6.0)
	if _fade_left <= 0.0:
		_fade_left = _rng.randf_range(0.5, 3.0)
	if _restart_left <= 0.0:
		_restart_left = _rng.randf_range(5.0, 15.0)


func _prune() -> void:
	var alive: Array[MusicDirector] = []
	for director: Variant in _directors:
		if is_instance_valid(director) and (director as MusicDirector).is_inside_tree():
			alive.append(director as MusicDirector)
	_directors = alive
	var legacy_alive: Array[AudioStreamPlayer] = []
	for p: Variant in _legacy:
		if is_instance_valid(p) and (p as AudioStreamPlayer).is_inside_tree():
			legacy_alive.append(p as AudioStreamPlayer)
	_legacy = legacy_alive


func _track(director: MusicDirector) -> void:
	director.level_changed.connect(func(_l: int) -> void: _level_changes += 1)
	director.tree_exiting.connect(_on_director_exiting.bind(director))
	_directors.append(director)


func _on_director_exiting(director: MusicDirector) -> void:
	_layer_writes_total += director.layer_writes
	director.layer_writes = 0


func _report(tag: String) -> void:
	var writes: int = _layer_writes_total
	for director: Variant in _directors:
		if is_instance_valid(director):
			writes += (director as MusicDirector).layer_writes
	print("%s reloads=%d injected=%d level_changes=%d clip_switches=%d fades=%d restarts=%d layer_writes=%d legacy_writes=%d elapsed=%.0fs" % [
		tag, _reloads, _injected, _level_changes, _clip_switches, _fades, _restarts, writes, _legacy_writes,
		(Time.get_ticks_msec() - _started_msec) / 1000.0])


func _finish() -> void:
	if _done:
		return
	_done = true
	_report("QA_STRESS_DONE")
	Engine.time_scale = 1.0
	var barrier: Node = get_node_or_null(^"/root/AudioMixBarrier")
	if barrier != null:
		barrier.process_mode = Node.PROCESS_MODE_ALWAYS
		barrier.call(&"quit_after_silence", 0)
	else:
		get_tree().quit(0)
