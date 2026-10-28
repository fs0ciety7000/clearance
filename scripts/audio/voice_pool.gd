## Pool de lecteurs 2D d'un bus avec priorités et vol de voix
## (docs/AUDIO.md §6) : une cue P1 n'est jamais coupée ; une nouvelle cue
## vole la voix la moins prioritaire (puis la plus ancienne) de priorité
## inférieure ou égale ; sinon elle est abandonnée. Polyphonie par cue :
## au-delà, la plus ancienne instance de la même cue est relancée.
class_name VoicePool
extends Node

var bus: StringName = &"Master"
var players: Array[AudioStreamPlayer] = []
## Nombre de cues abandonnées faute de voix (diagnostic, tests).
var dropped: int = 0
## Nombre de voix volées.
var stolen: int = 0

var _priority: Dictionary[AudioStreamPlayer, int] = {}
var _cue: Dictionary[AudioStreamPlayer, StringName] = {}
var _serial: Dictionary[AudioStreamPlayer, int] = {}
var _counter: int = 0


## Crée `size` lecteurs sur `p_bus`.
func setup(p_bus: StringName, size: int) -> void:
	bus = p_bus
	for i: int in size:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "%s_%d" % [p_bus, i]
		player.bus = p_bus
		add_child(player)
		players.append(player)


## Joue `stream` ; renvoie le lecteur utilisé (null si abandonné).
func play(cue: StringName, stream: AudioStream, priority: int, volume_db: float, pitch: float = 1.0,
		polyphony: int = 0) -> AudioStreamPlayer:
	if stream == null or players.is_empty():
		return null
	var player: AudioStreamPlayer = null
	if polyphony > 0 and count_cue(cue) >= polyphony:
		player = _oldest_of(cue)
	if player == null:
		player = _free_player()
	if player == null:
		player = _victim(priority)
		if player == null:
			dropped += 1
			return null
		stolen += 1
	player.stop()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	_counter += 1
	_priority[player] = priority
	_cue[player] = cue
	_serial[player] = _counter
	player.play()
	return player


func is_busy(player: AudioStreamPlayer) -> bool:
	return player.playing


func active_count() -> int:
	var n: int = 0
	for player: AudioStreamPlayer in players:
		if is_busy(player):
			n += 1
	return n


func count_cue(cue: StringName) -> int:
	var n: int = 0
	for player: AudioStreamPlayer in players:
		if is_busy(player) and _cue.get(player, &"") == cue:
			n += 1
	return n


## Cues en cours (ordre des lecteurs).
func active_cues() -> Array[StringName]:
	var out: Array[StringName] = []
	for player: AudioStreamPlayer in players:
		if is_busy(player):
			out.append(_cue.get(player, &""))
	return out


func stop_cue(cue: StringName) -> void:
	for player: AudioStreamPlayer in players:
		if _cue.get(player, &"") == cue:
			player.stop()


func stop_all() -> void:
	for player: AudioStreamPlayer in players:
		player.stop()


func _free_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in players:
		if not is_busy(player):
			return player
	return null


## Voix à voler : priorité numérique la plus haute (= la moins importante),
## ≥ celle de la nouvelle cue, jamais P1 ; à égalité la plus ancienne.
func _victim(priority: int) -> AudioStreamPlayer:
	var best: AudioStreamPlayer = null
	for player: AudioStreamPlayer in players:
		var p: int = _priority.get(player, AudioCueBank.P3)
		if p <= AudioCueBank.P1 or p < priority:
			continue
		if best == null:
			best = player
			continue
		var bp: int = _priority.get(best, AudioCueBank.P3)
		if p > bp or (p == bp and _serial.get(player, 0) < _serial.get(best, 0)):
			best = player
	return best


func _oldest_of(cue: StringName) -> AudioStreamPlayer:
	var best: AudioStreamPlayer = null
	for player: AudioStreamPlayer in players:
		if not is_busy(player) or _cue.get(player, &"") != cue:
			continue
		if best == null or _serial.get(player, 0) < _serial.get(best, 0):
			best = player
	return best
