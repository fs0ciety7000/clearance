## Cue sheet (docs/AUDIO.md §4) : identifiant de cue → bus, fichiers,
## priorité (1 = critique, jamais volée ; 3 = confort), gain, variations.
## Les variantes sont assemblées à l'exécution en `AudioStreamRandomizer`
## (pitch ±, volume ±, sans répétition).
## Classe-espace de noms : jamais instanciée.
class_name AudioCueBank
extends RefCounted

const ROOT: String = "res://assets/audio/"

const P1: int = 1
const P2: int = 2
const P3: int = 3

## id → [bus, motif de chemin (avec %02d si variantes), nb de variantes,
## priorité, gain dB, pitch aléatoire (facteur), polyphonie max de la cue].
const CUES: Dictionary[StringName, Array] = {
	# Passager (3D : joués par PassengerAudio sur ses émetteurs)
	&"passenger.step": [&"SFX_World", "sfx/passenger/sfx_passenger_step_metal_wet_%02d.wav", 8, P3, -10.0, 1.08, 2],
	&"passenger.step_stop": [&"SFX_World", "sfx/passenger/sfx_passenger_step_stop_%02d.wav", 3, P3, -8.0, 1.04, 1],
	&"passenger.breath_idle": [&"SFX", "sfx/passenger/sfx_passenger_breath_idle_%02d.wav", 4, P3, -14.0, 1.05, 1],
	&"passenger.breath_sigh": [&"SFX", "sfx/passenger/sfx_passenger_breath_sigh_%02d.wav", 3, P2, -10.0, 1.04, 1],
	&"passenger.breath_nervous": [&"SFX", "sfx/passenger/sfx_passenger_breath_nervous_%02d.wav", 3, P2, -10.0, 1.05, 1],
	&"passenger.cloth_rustle": [&"SFX", "sfx/passenger/sfx_passenger_cloth_rustle_%02d.wav", 4, P3, -14.0, 1.06, 1],
	&"passenger.paper_rustle": [&"SFX", "sfx/passenger/sfx_passenger_paper_rustle_%02d.wav", 4, P2, -10.0, 1.05, 1],
	&"passenger.knock_glass": [&"SFX", "sfx/passenger/sfx_passenger_knock_glass_%02d.wav", 3, P3, -6.0, 1.04, 1],
	# Guichet (2D, côté joueur)
	&"booth.slot_in": [&"SFX", "sfx/booth/sfx_booth_slot_in_%02d.wav", 4, P1, -6.0, 1.03, 1],
	&"booth.slot_out": [&"SFX", "sfx/booth/sfx_booth_slot_out_%02d.wav", 4, P2, -8.0, 1.03, 1],
	&"booth.holo_on": [&"SFX", "sfx/booth/sfx_booth_holo_on_%02d.wav", 3, P1, -10.0, 1.03, 3],
	&"booth.holo_off": [&"SFX", "sfx/booth/sfx_booth_holo_off_%02d.wav", 2, P2, -10.0, 1.03, 1],
	&"booth.holo_hum": [&"SFX", "sfx/booth/sfx_booth_holo_hum_loop.wav", 1, P3, -32.0, 1.0, 1],
	&"booth.stamp_approved": [&"SFX", "sfx/booth/sfx_booth_stamp_approved_%02d.wav", 3, P1, -2.0, 1.02, 1],
	&"booth.stamp_denied": [&"SFX", "sfx/booth/sfx_booth_stamp_denied_%02d.wav", 3, P1, -2.0, 1.02, 1],
	&"booth.stamp_lift": [&"SFX", "sfx/booth/sfx_booth_stamp_lift_%02d.wav", 2, P3, -14.0, 1.04, 1],
	&"booth.intercom_on": [&"SFX", "sfx/booth/sfx_booth_intercom_on_%02d.wav", 2, P2, -8.0, 1.02, 1],
	&"booth.intercom_off": [&"SFX", "sfx/booth/sfx_booth_intercom_off_%02d.wav", 2, P2, -8.0, 1.02, 1],
	&"booth.printer_citation": [&"SFX", "sfx/booth/sfx_booth_printer_citation_%02d.wav", 2, P1, -8.0, 1.0, 1],
	&"station.door_open": [&"SFX_World", "sfx/station/sfx_station_door_open_%02d.wav", 2, P2, -14.0, 1.03, 1],
	&"station.door_close": [&"SFX_World", "sfx/station/sfx_station_door_close_%02d.wav", 2, P3, -16.0, 1.03, 1],
	# UI (DS §9)
	&"ui.hover": [&"UI", "ui/ui_hover_01.wav", 1, P3, -18.0, 1.03, 1],
	&"ui.field_select_a": [&"UI", "ui/ui_field_select_a_01.wav", 1, P2, -10.0, 1.0, 1],
	&"ui.field_select_b": [&"UI", "ui/ui_field_select_b_01.wav", 1, P2, -10.0, 1.0, 1],
	&"ui.match": [&"UI", "ui/ui_match_01.wav", 1, P1, -9.0, 1.0, 1],
	&"ui.discrepancy": [&"UI", "ui/ui_discrepancy_%02d.wav", 2, P1, -6.0, 1.0, 1],
	&"ui.incomparable": [&"UI", "ui/ui_incomparable_01.wav", 1, P2, -10.0, 1.0, 1],
	&"ui.inspect_mode_on": [&"UI", "ui/ui_inspect_mode_on_01.wav", 1, P2, -10.0, 1.0, 1],
	&"ui.inspect_mode_off": [&"UI", "ui/ui_inspect_mode_off_01.wav", 1, P2, -10.0, 1.0, 1],
	&"ui.rule_new": [&"UI", "ui/ui_rule_new_01.wav", 1, P1, -6.0, 1.0, 1],
	&"ui.timer_warning": [&"UI", "ui/ui_timer_warning_01.wav", 1, P1, -8.0, 1.0, 1],
	&"ui.timer_critical_tick": [&"UI", "ui/ui_timer_critical_tick_01.wav", 1, P1, -10.0, 1.0, 1],
	&"ui.citation_chime": [&"UI", "ui/ui_citation_chime_01.wav", 1, P1, -6.0, 1.0, 1],
	&"ui.stamp_hold": [&"UI", "ui/ui_stamp_hold_01.wav", 1, P2, -10.0, 1.0, 1],
	&"ui.toast_info": [&"UI", "ui/ui_toast_info_01.wav", 1, P2, -12.0, 1.0, 1],
	&"ui.toast_success": [&"UI", "ui/ui_toast_success_01.wav", 1, P2, -12.0, 1.0, 1],
	&"ui.toast_error": [&"UI", "ui/ui_toast_error_01.wav", 1, P2, -12.0, 1.0, 1],
	# Ambiance
	&"amb.rain_glass": [&"Ambience", "ambience/amb_rain_glass_loop.ogg", 1, P2, -8.0, 1.0, 1],
	&"amb.neon_hum": [&"Ambience", "ambience/amb_neon_hum_loop.ogg", 1, P3, -20.0, 1.0, 1],
	&"amb.station_bed": [&"Ambience", "ambience/amb_station_bed_loop.ogg", 1, P2, -8.0, 1.0, 1],
	&"amb.queue_murmur": [&"Ambience", "ambience/amb_queue_murmur_loop.ogg", 1, P3, -6.0, 1.0, 1],
	&"amb.rain_drop_heavy": [&"Ambience", "ambience/amb_rain_drop_heavy_%02d.wav", 4, P3, -20.0, 1.1, 2],
	&"amb.queue_advance": [&"Ambience", "ambience/amb_queue_advance_%02d.wav", 4, P3, -14.0, 1.05, 1],
	&"amb.pa_announce": [&"Ambience", "voice/pa/vo_pa_announce_%02d.wav", 3, P3, -12.0, 1.0, 1],
	# Musique (états)
	&"mus.briefing": [&"Music", "music/mus_briefing_loop.ogg", 1, P2, -6.0, 1.0, 1],
	&"mus.shift_calm": [&"Music", "music/mus_shift_calm_loop.ogg", 1, P2, -14.0, 1.0, 1],
	&"mus.shift_tension": [&"Music", "music/mus_shift_tension_loop.ogg", 1, P2, -12.0, 1.0, 1],
	&"mus.debrief": [&"Music", "music/mus_debrief_loop.ogg", 1, P2, -6.0, 1.0, 1],
	&"mus.debrief_minor": [&"Music", "music/mus_debrief_minor_loop.ogg", 1, P2, -6.0, 1.0, 1],
}

static var _streams: Dictionary[StringName, AudioStream] = {}


static func has_cue(id: StringName) -> bool:
	return CUES.has(id)


static func bus_of(id: StringName) -> StringName:
	return CUES[id][0] if CUES.has(id) else &"Master"


static func priority_of(id: StringName) -> int:
	return CUES[id][3] if CUES.has(id) else P3


static func volume_db_of(id: StringName) -> float:
	return CUES[id][4] if CUES.has(id) else 0.0


static func polyphony_of(id: StringName) -> int:
	return CUES[id][6] if CUES.has(id) else 1


## Chemins des fichiers d'une cue.
static func paths_of(id: StringName) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if not CUES.has(id):
		return out
	var pattern: String = CUES[id][1]
	var count: int = CUES[id][2]
	if count <= 1 and not pattern.contains("%"):
		out.append(ROOT + pattern)
		return out
	for i: int in count:
		out.append(ROOT + (pattern % (i + 1)))
	return out


## Flux d'une cue (mis en cache) : fichier seul ou `AudioStreamRandomizer`.
## Les boucles (`*_loop.*`) sont forcées en lecture bouclée. null si absent.
static func stream_of(id: StringName) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var paths: PackedStringArray = paths_of(id)
	var loaded: Array[AudioStream] = []
	for path: String in paths:
		if not ResourceLoader.exists(path):
			push_warning("AudioCueBank: fichier manquant %s (bash tools/build_audio.sh)" % path)
			continue
		var stream: AudioStream = load(path) as AudioStream
		if stream == null:
			continue
		if path.contains("_loop."):
			_set_loop(stream)
		loaded.append(stream)
	var result: AudioStream = null
	var pitch_range: float = CUES[id][5]
	if loaded.size() == 1 and pitch_range <= 1.0:
		result = loaded[0]
	elif not loaded.is_empty():
		var rnd: AudioStreamRandomizer = AudioStreamRandomizer.new()
		rnd.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS if loaded.size() > 2 \
				else AudioStreamRandomizer.PLAYBACK_RANDOM
		rnd.random_pitch = pitch_range
		rnd.random_volume_offset_db = 1.5 if loaded.size() > 2 else 0.0
		for stream: AudioStream in loaded:
			rnd.add_stream(-1, stream)
		result = rnd
	_streams[id] = result
	return result


## Vide le cache (sortie de la scène de jour : pas de ressource retenue).
static func clear_cache() -> void:
	_streams.clear()


## Précharge toutes les cues (évite un accès disque au premier son).
static func preload_all() -> int:
	var count: int = 0
	for id: StringName in CUES:
		if stream_of(id) != null:
			count += 1
	return count


static func _set_loop(stream: AudioStream) -> void:
	var ogg: AudioStreamOggVorbis = stream as AudioStreamOggVorbis
	if ogg != null:
		ogg.loop = true
		return
	# Les WAV bouclés le sont à l'import (`edit/loop_mode=2`, tools/build_audio.sh).
