## Lecteur de musique dynamique (M14, D-176 ; docs/AUDIO.md §13,
## docs/M14.md §2.9) — nœud de scène, **pas un autoload** (ARCHITECTURE P6).
##
## Sûreté D-083 (course de Godot 4.7.2 sur les `bus_details`, QA-030) :
## - **un seul** `AudioStreamPlayer` (bus `Music`) dont le `volume_db` ne
##   change **jamais** (ni tween, ni écriture par image) : aucun remplacement
##   des `bus_details` de sa lecture ;
## - les couches d'un ensemble sont mélangées **dans le flux** :
##   `AudioStreamInteractive` dont chaque clip est un `AudioStreamSynchronized`
##   (≤ 5 couches) ou un thème ; les niveaux N0 → N4 sont des volumes de couche
##   (`set_sync_stream_volume`, lus par le thread de mixage, aucune allocation) ;
## - les fondus globaux passent par l'effet `Fade` (`AudioEffectAmplify`) du
##   bus `Music`, comme `Duck` ;
## - `_exit_tree` arrête le lecteur et vide son flux (modèle QA-039).
##
## La position de lecture d'un `AudioStreamInteractive` n'est pas exposée par
## Godot 4.7 (`get_playback_position()` = 0) : le directeur tient sa propre
## horloge de mesures en temps réel (`Time.get_ticks_usec`, insensible à
## `Engine.time_scale` et à la pause). Les décisions de niveau tombent au début
## d'une mesure ; chaque couche entre ou sort en une mesure.
##
## Données : `configure_from_def()` (un `MusicSetDef` du lot A : couches,
## gains, masques exposé / sans mélodie / power down, groupes) et
## `configure_theme_def()` (`MusicThemeDef` : `stream` puis `tail_stream` en
## boucle, enchaînés par avance automatique du flux interactif). Les appels
## bas niveau `configure_set()` / `configure_theme()` servent aux outils QA.
class_name MusicDirector
extends Node

## Niveau appliqué (tests, outils QA).
signal level_changed(level: int)

const LEVEL_COUNT: int = 5
const LAYER_COUNT: int = 5
## Niveau « exposé » (briefing) : L0 + L3, en dehors de l'échelle N0 → N4.
const LEVEL_EXPOSED: int = -1
## Volume d'une couche sortie (dB) : en dessous, la couche est inaudible.
const SILENT_DB: float = -80.0
## Couches actives par niveau (docs/M14.md §2.5) : N4 remplace L3 par L4.
const LEVEL_LAYERS: Array[Array] = [
	[1, 0, 0, 0, 0],
	[1, 1, 0, 0, 0],
	[1, 1, 1, 0, 0],
	[1, 1, 1, 1, 0],
	[1, 1, 1, 0, 1],
]
const EXPOSED_LAYERS: Array[int] = [1, 0, 0, 1, 0]
## Montée : +1 niveau au plus toutes les 2 mesures ; descente : −1 toutes les 4.
const BARS_PER_STEP_UP: int = 2
const BARS_PER_STEP_DOWN: int = 4
## Fondu croisé entre deux clips (ensembles ou thèmes), en temps.
const CLIP_FADE_BEATS: float = 8.0

## Lecteur unique, `volume_db` fixe.
var player: AudioStreamPlayer = null
## Flux interactif (un clip par ensemble ou thème).
var interactive: AudioStreamInteractive = null
## Niveau appliqué (−1 = exposé) et niveau demandé.
var level: int = 0
var target_level: int = 0
## Couche L3 coupée (Mode Inspection, chrono critique : docs/M14.md §2.5).
var mute_motif: bool = false
## « Power down » (EV-05, grève du J20) : couches `keeps_on_power_down` seules.
var power_down: bool = false
## Groupes de couches sélectionnés (MS-06 chaud / crise, mondes de MS-07…).
var groups: Array[StringName] = []
## Nombre total d'écritures de volume de couche (outil de stress, tests).
var layer_writes: int = 0

## Description des clips : nom → {sync, bpm, bar_beats, gains (dB), layers}.
var _clips: Dictionary[StringName, Dictionary] = {}
var _clip_order: Array[StringName] = []
var _current_clip: StringName = &""
## Volumes courants des couches du clip actif (amplitude linéaire 0..1).
var _layer_amp: PackedFloat32Array = PackedFloat32Array()
## Dernier volume écrit par couche (dB).
var _layer_db: PackedFloat32Array = PackedFloat32Array()
var _bar_sec: float = 3.0
var _clock_usec: int = 0
var _last_usec: int = 0
var _bar_index: int = 0
var _bars_since_change: int = 0
var _fade_from_db: float = 0.0
var _fade_to_db: float = 0.0
var _fade_left: float = 0.0
var _fade_total: float = 0.0
var _stop_after_fade: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.name = "MusicPlayer"
	player.bus = AudioBuses.MUSIC
	player.volume_db = 0.0
	add_child(player)
	_set_fade_db(0.0)


func _exit_tree() -> void:
	# QA-039 : plus aucune lecture ni aucun flux après la sortie de l'arbre.
	if player != null:
		player.stop()
		player.stream = null
	_set_fade_db(0.0)


## Déclare un ensemble (clip) : `layers` = flux des couches L0…L4 (OGG en
## boucle), `gains_db` = gain de chaque couche à son niveau plein
## (`MusicSetDef`), `bpm` / `bar_beats` pour l'horloge et les transitions.
## À appeler avant `play()` (le flux interactif est construit au premier
## `play()` et n'est plus modifié pendant la lecture).
func configure_set(clip: StringName, layers: Array[AudioStream], bpm: float, bar_beats: int = 4,
		gains_db: PackedFloat32Array = PackedFloat32Array()) -> void:
	var sync: AudioStreamSynchronized = AudioStreamSynchronized.new()
	sync.stream_count = layers.size()
	var gains: PackedFloat32Array = PackedFloat32Array()
	for i: int in layers.size():
		sync.set_sync_stream(i, layers[i])
		sync.set_sync_stream_volume(i, SILENT_DB)
		gains.append(gains_db[i] if i < gains_db.size() else 0.0)
	if not _clips.has(clip):
		_clip_order.append(clip)
	_clips[clip] = {"stream": sync, "sync": sync, "bpm": bpm, "bar_beats": bar_beats, "gains": gains,
		"layers": layers.size()}
	interactive = null


## Déclare un ensemble depuis ses données (`MusicSetDef`) ; clip = `id`.
## Les couches sans flux (pas encore rendues) restent muettes.
func configure_from_def(set_def: MusicSetDef) -> void:
	var streams: Array[AudioStream] = []
	var gains: PackedFloat32Array = PackedFloat32Array()
	for layer: MusicLayerDef in set_def.layers:
		streams.append(layer.stream if layer != null else null)
		gains.append(layer.gain_db if layer != null else 0.0)
	configure_set(set_def.id, streams, set_def.tempo_bpm, set_def.beats_per_bar, gains)
	_clips[set_def.id]["def"] = set_def


## Déclare un thème (clip d'un seul flux, sans couches) ; `tail` : queue
## bouclée enchaînée automatiquement à la fin de `stream` (clip `<clip>_tail`).
func configure_theme(clip: StringName, stream: AudioStream, bpm: float, bar_beats: int = 4,
		tail: AudioStream = null) -> void:
	if not _clips.has(clip):
		_clip_order.append(clip)
	_clips[clip] = {"stream": stream, "sync": null, "bpm": bpm, "bar_beats": bar_beats,
		"gains": PackedFloat32Array(), "layers": 0, "next": StringName(String(clip) + "_tail") if tail != null else &""}
	if tail != null:
		var tail_clip: StringName = StringName(String(clip) + "_tail")
		if not _clips.has(tail_clip):
			_clip_order.append(tail_clip)
		_clips[tail_clip] = {"stream": tail, "sync": null, "bpm": bpm, "bar_beats": bar_beats,
			"gains": PackedFloat32Array(), "layers": 0, "next": &""}
	interactive = null


## Thème depuis ses données (`MusicThemeDef`) ; clip = `id`.
func configure_theme_def(theme: MusicThemeDef, flags: Dictionary[StringName, Variant] = {},
		reduced_fx: bool = false) -> void:
	configure_theme(theme.id, theme.main_stream(flags, reduced_fx), theme.tempo_bpm, theme.beats_per_bar,
			theme.tail_for(flags))


## Déclare tous les ensembles et thèmes d'une bibliothèque
## (`MusicLibraryDef`, ARCHITECTURE §12 ter.2). Les thèmes sont déclarés avec
## leur flux de base ; une variante est choisie par `play_theme()`.
## Paramètre typé `Resource` (lu par propriétés) : nommer ici la classe
## `MusicLibraryDef` (dont les statiques tirent `DayDef` et le graphe de
## classes du jeu) fait fuir ces scripts à la sortie sous Godot 4.7.2
## (≈ 160 « GDScript » et 157 ressources, docs/AUDIO.md §13.3).
func use_library(library: Resource) -> void:
	if library == null:
		return
	for set_def: Variant in library.get(&"sets"):
		if set_def is MusicSetDef:
			configure_from_def(set_def as MusicSetDef)
	for theme: Variant in library.get(&"themes"):
		if theme is MusicThemeDef:
			configure_theme_def(theme as MusicThemeDef)


## Groupes de couches sélectionnés (`warm` / `crisis`, `world_x`, `ending_seen`).
func set_groups(value: Array[StringName]) -> void:
	groups = value.duplicate()


## Masques `MusicSetDef.MASK_*` : sans mélodie, power down ; `MASK_EXPOSED`
## passe au niveau `LEVEL_EXPOSED` (le niveau de jeu reprend avec `force_level`).
func set_mask(mask: int) -> void:
	mute_motif = (mask & MusicSetDef.MASK_NO_MELODY) != 0
	power_down = (mask & MusicSetDef.MASK_POWER_DOWN) != 0
	if mask & MusicSetDef.MASK_EXPOSED:
		force_level(LEVEL_EXPOSED)


## Joue un thème (variante selon `flags`) : à la mesure suivante s'il y a déjà
## de la musique (fondu croisé dans le flux), sinon tout de suite.
func play_theme(theme: MusicThemeDef, flags: Dictionary[StringName, Variant] = {}, reduced_fx: bool = false) -> void:
	var stream: AudioStream = theme.main_stream(flags, reduced_fx)
	if not _clips.has(theme.id) or _clips[theme.id]["stream"] != stream:
		configure_theme_def(theme, flags, reduced_fx)
		play(theme.id)
		return
	if is_playing() and interactive != null:
		switch_clip(theme.id)
	else:
		play(theme.id)


## Cinématique passée : la queue du thème en cours à la mesure suivante.
func skip_to_tail() -> void:
	var tail: StringName = _clips.get(_current_clip, {}).get("next", &"")
	if tail != &"":
		switch_clip(tail)


func has_clip(clip: StringName) -> bool:
	return _clips.has(clip)


func get_current_clip() -> StringName:
	return _current_clip


## Démarre la lecture sur `clip` au niveau `start_level` (fondu d'entrée
## optionnel par l'effet `Fade`).
func play(clip: StringName, start_level: int = 0, fade_in_sec: float = 0.0) -> void:
	if not _clips.has(clip) or not is_inside_tree():
		return
	if interactive == null:
		_build_interactive()
	player.stop()
	player.stream = interactive
	interactive.initial_clip = _clip_order.find(clip)
	_enter_clip(clip)
	level = start_level
	target_level = start_level
	_snap_layers()
	if fade_in_sec > 0.0:
		_set_fade_db(SILENT_DB)
		fade_to(0.0, fade_in_sec)
	else:
		_set_fade_db(0.0)
	player.play()
	_clock_usec = 0
	_last_usec = Time.get_ticks_usec()
	_bar_index = 0
	_bars_since_change = 0
	level_changed.emit(level)


## Passe à un autre clip à la mesure suivante (fondu croisé de 2 mesures dans
## le flux) ; les couches du nouvel ensemble démarrent au niveau `start_level`.
func switch_clip(clip: StringName, start_level: int = 0) -> void:
	if not _clips.has(clip) or not player.playing or clip == _current_clip:
		return
	var playback: AudioStreamPlaybackInteractive = player.get_stream_playback() as AudioStreamPlaybackInteractive
	if playback == null:
		return
	# Le nouveau clip démarre à la prochaine mesure de l'ancien : l'horloge
	# repart de 0 à cet instant (valeur négative jusque-là).
	var old_bar_usec: int = int(_bar_sec * 1_000_000.0)
	_clock_usec = -((_bar_index + 1) * old_bar_usec - _clock_usec)
	_bar_index = 0
	_enter_clip(clip)
	level = start_level
	target_level = start_level
	_snap_layers()
	playback.switch_to_clip_by_name(clip)
	level_changed.emit(level)


## Demande un niveau (N0 → N4, ou `LEVEL_EXPOSED`) : appliqué aux limites de
## mesure, +1 toutes les 2 mesures au plus, −1 toutes les 4 (D-177).
func request_level(value: int) -> void:
	target_level = clampi(value, LEVEL_EXPOSED, LEVEL_COUNT - 1)


## Applique un niveau tout de suite (sans attendre la mesure) : outils QA,
## changements d'ensemble. Les couches restent rampées sur une mesure.
func force_level(value: int) -> void:
	var v: int = clampi(value, LEVEL_EXPOSED, LEVEL_COUNT - 1)
	target_level = v
	if v != level:
		level = v
		_bars_since_change = 0
		level_changed.emit(level)


## Fondu global (effet `Fade` du bus `Music`) vers `db` en `seconds`.
func fade_to(db: float, seconds: float, stop_at_end: bool = false) -> void:
	_fade_from_db = get_fade_db()
	_fade_to_db = db
	_fade_total = maxf(seconds, 0.0)
	_fade_left = _fade_total
	_stop_after_fade = stop_at_end
	if _fade_total <= 0.0:
		_set_fade_db(db)
		_finish_fade()


func stop_music() -> void:
	if player != null:
		player.stop()
	_current_clip = &""


func is_playing() -> bool:
	return player != null and player.playing


## Volume courant d'une couche du clip actif (dB, sans le gain de l'ensemble).
func get_layer_amp(index: int) -> float:
	return _layer_amp[index] if index >= 0 and index < _layer_amp.size() else 0.0


## Couches visées par un niveau (1 = présente).
static func layers_for_level(value: int, motif_muted: bool = false) -> PackedByteArray:
	var mask: PackedByteArray = PackedByteArray(EXPOSED_LAYERS if value == LEVEL_EXPOSED \
			else LEVEL_LAYERS[clampi(value, 0, LEVEL_COUNT - 1)])
	if motif_muted:
		mask[3] = 0
	return mask


## Pas de niveau autorisé à une limite de mesure (fonction pure, tests).
static func next_level(current: int, wanted: int, bars_since_change: int) -> int:
	if current == LEVEL_EXPOSED or wanted == LEVEL_EXPOSED:
		return wanted
	if wanted > current and bars_since_change >= BARS_PER_STEP_UP:
		return current + 1
	if wanted < current and bars_since_change >= BARS_PER_STEP_DOWN:
		return current - 1
	return current


static func get_fade_db() -> float:
	var fx: AudioEffectAmplify = AudioBuses.get_effect(AudioBuses.MUSIC, AudioBuses.FX_FADE) as AudioEffectAmplify
	return fx.volume_db if fx != null else 0.0


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var dt: float = clampf((now - _last_usec) / 1_000_000.0, 0.0, 0.25)
	_last_usec = now
	_update_fade(dt)
	if player == null or not player.playing or _current_clip == &"":
		return
	_clock_usec += int(dt * 1_000_000.0)
	var bar: int = int(_clock_usec / (_bar_sec * 1_000_000.0))
	while _bar_index < bar:
		_bar_index += 1
		_bars_since_change += 1
		_on_bar()
	_ramp_layers(dt)


func _on_bar() -> void:
	var next: int = next_level(level, target_level, _bars_since_change)
	if next != level:
		level = next
		_bars_since_change = 0
		level_changed.emit(level)


## Rampe linéaire en amplitude, une mesure du silence au plein ; une seule
## écriture de volume par couche et par image, seulement si elle change.
func _ramp_layers(dt: float) -> void:
	var info: Dictionary = _clips[_current_clip]
	var sync: AudioStreamSynchronized = info["sync"]
	if sync == null:
		return
	var mask: PackedByteArray = _current_mask(info)
	var gains: PackedFloat32Array = _current_gains(info)
	var step: float = dt / maxf(_bar_sec, 0.01)
	for i: int in _layer_amp.size():
		var want: float = 1.0 if i < mask.size() and mask[i] == 1 else 0.0
		var amp: float = _layer_amp[i]
		if not is_equal_approx(amp, want):
			amp = minf(amp + step, want) if want > amp else maxf(amp - step, want)
			_layer_amp[i] = amp
		_write_layer(sync, i, amp, gains[i])


## Écrit le volume d'une couche seulement s'il change (≤ 1 écriture par
## couche et par image) ; muette = `SILENT_DB` exactement.
func _write_layer(sync: AudioStreamSynchronized, i: int, amp: float, gain_db: float) -> void:
	var db: float = SILENT_DB if amp <= 0.0001 else maxf(linear_to_db(amp) + gain_db, SILENT_DB)
	if i < _layer_db.size() and absf(_layer_db[i] - db) < 0.01:
		return
	if i < _layer_db.size():
		_layer_db[i] = db
	sync.set_sync_stream_volume(i, db)
	layer_writes += 1


func _snap_layers() -> void:
	var info: Dictionary = _clips[_current_clip]
	var sync: AudioStreamSynchronized = info["sync"]
	var count: int = info["layers"]
	_layer_amp.resize(count)
	_layer_db.resize(count)
	_layer_db.fill(INF)
	var mask: PackedByteArray = _current_mask(info)
	var gains: PackedFloat32Array = _current_gains(info)
	for i: int in count:
		_layer_amp[i] = 1.0 if i < mask.size() and mask[i] == 1 else 0.0
		if sync != null:
			_write_layer(sync, i, _layer_amp[i], gains[i])


## Couches visées : masques du `MusicSetDef` s'il y en a un, sinon la table
## N0 → N4 de docs/M14.md §2.5.
func _current_mask(info: Dictionary) -> PackedByteArray:
	var count: int = info["layers"]
	var set_def: MusicSetDef = info.get("def", null)
	if set_def == null:
		var mask: PackedByteArray = layers_for_level(level, mute_motif)
		if power_down:
			mask = PackedByteArray([1, 0, 0, 0, 0])
		mask.resize(count)
		return mask
	var flags: int = 0
	if level == LEVEL_EXPOSED:
		flags |= MusicSetDef.MASK_EXPOSED
	if mute_motif:
		flags |= MusicSetDef.MASK_NO_MELODY
	if power_down:
		flags |= MusicSetDef.MASK_POWER_DOWN
	var out: PackedByteArray = PackedByteArray()
	out.resize(count)
	for index: int in set_def.active_layers(maxi(level, 0), flags, groups):
		out[index] = 1
	return out


func _current_gains(info: Dictionary) -> PackedFloat32Array:
	var gains: PackedFloat32Array = info["gains"]
	var set_def: MusicSetDef = info.get("def", null)
	if set_def == null or level != LEVEL_EXPOSED or is_zero_approx(set_def.exposed_gain_db):
		return gains
	var out: PackedFloat32Array = gains.duplicate()
	for i: int in out.size():
		out[i] += set_def.exposed_gain_db
	return out


func _enter_clip(clip: StringName) -> void:
	_current_clip = clip
	var info: Dictionary = _clips[clip]
	var bpm: float = info["bpm"]
	var beats: int = info["bar_beats"]
	_bar_sec = 60.0 / maxf(bpm, 1.0) * beats


func _build_interactive() -> void:
	interactive = AudioStreamInteractive.new()
	interactive.clip_count = _clip_order.size()
	for i: int in _clip_order.size():
		var clip: StringName = _clip_order[i]
		interactive.set_clip_name(i, clip)
		interactive.set_clip_stream(i, _clips[clip]["stream"])
	for i: int in _clip_order.size():
		var next: StringName = _clips[_clip_order[i]].get("next", &"")
		if next != &"":
			interactive.set_clip_auto_advance(i, AudioStreamInteractive.AUTO_ADVANCE_ENABLED)
			interactive.set_clip_auto_advance_next_clip(i, _clip_order.find(next))
	interactive.add_transition(AudioStreamInteractive.CLIP_ANY, AudioStreamInteractive.CLIP_ANY,
			AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BAR, AudioStreamInteractive.TRANSITION_TO_TIME_START,
			AudioStreamInteractive.FADE_CROSS, CLIP_FADE_BEATS)


func _update_fade(dt: float) -> void:
	if _fade_left <= 0.0:
		return
	_fade_left = maxf(_fade_left - dt, 0.0)
	var t: float = 1.0 - _fade_left / maxf(_fade_total, 0.0001)
	# Fondu en amplitude (perçu comme régulier), écrit une fois par image.
	var a0: float = db_to_linear(_fade_from_db)
	var a1: float = db_to_linear(_fade_to_db)
	_set_fade_db(_amp_to_db(lerpf(a0, a1, t)))
	if _fade_left <= 0.0:
		_set_fade_db(_fade_to_db)
		_finish_fade()


func _finish_fade() -> void:
	if _stop_after_fade:
		_stop_after_fade = false
		stop_music()


static func _set_fade_db(db: float) -> void:
	var fx: AudioEffectAmplify = AudioBuses.get_effect(AudioBuses.MUSIC, AudioBuses.FX_FADE) as AudioEffectAmplify
	if fx != null:
		fx.volume_db = db


static func _amp_to_db(amp: float) -> float:
	return SILENT_DB if amp <= 0.0001 else maxf(linear_to_db(amp), SILENT_DB)
