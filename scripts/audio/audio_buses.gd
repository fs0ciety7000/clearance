## Architecture des bus audio (docs/AUDIO.md §2) — source de vérité de
## `res://default_bus_layout.tres` (généré par `tools/build_audio.gd`) et
## des noms utilisés par `Settings`, `AudioDirector` et les tests.
##
## ```
## Master ── [Mono (StereoEnhance, off)] [HardLimiter −1 dB]
##  ├── Music      ── [Duck (Amplify)] [Muffle (LowPass, off : pause)]
##  ├── Ambience   ── [Duck (Amplify)] [Glass (LowPass 8 kHz)] [Station (Reverb)]
##  ├── SFX        ── [Compressor 3:1]
##  │    └── SFX_World ── [Hall (Reverb)]
##  ├── Voice      ── [Duck (Amplify)] [Hygiaphone HP 380 Hz + LP 3,4 kHz + EQ + grain] [Booth (Reverb)] [Compressor 4:1]
##  └── UI         ── (sec)
## ```
## Classe-espace de noms : jamais instanciée.
class_name AudioBuses
extends RefCounted

const MASTER: StringName = &"Master"
const MUSIC: StringName = &"Music"
const AMBIENCE: StringName = &"Ambience"
const SFX: StringName = &"SFX"
const SFX_WORLD: StringName = &"SFX_World"
const VOICE: StringName = &"Voice"
const UI: StringName = &"UI"

## Ordre des bus (index 0 = Master) et bus parent (`send`).
const LAYOUT: Array[Array] = [
	[&"Master", &""],
	[&"Music", &"Master"],
	[&"Ambience", &"Master"],
	[&"SFX", &"Master"],
	[&"SFX_World", &"SFX"],
	[&"Voice", &"Master"],
	[&"UI", &"Master"],
]

## Noms d'effets (resource_name) retrouvés à l'exécution.
const FX_MONO: String = "Mono"
const FX_DUCK: String = "Duck"
const FX_MUFFLE: String = "Muffle"
const FX_HYGIAPHONE: String = "Hygiaphone"

const DEFAULT_LAYOUT_PATH: String = "res://default_bus_layout.tres"


## Configure l'`AudioServer` selon `LAYOUT` (outil de build, tests).
static func configure_server() -> void:
	AudioServer.bus_count = LAYOUT.size()
	for i: int in LAYOUT.size():
		var entry: Array = LAYOUT[i]
		var bus_name: StringName = entry[0]
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_volume_db(i, 0.0)
		AudioServer.set_bus_mute(i, false)
		var parent: StringName = entry[1]
		if i > 0:
			AudioServer.set_bus_send(i, parent)
		while AudioServer.get_bus_effect_count(i) > 0:
			AudioServer.remove_bus_effect(i, 0)
		var effects: Array[AudioEffect] = effects_for(bus_name)
		for fx: AudioEffect in effects:
			AudioServer.add_bus_effect(i, fx)
		if bus_name == MASTER:
			AudioServer.set_bus_effect_enabled(i, 0, false) # mono : désactivé par défaut
		elif bus_name == MUSIC:
			AudioServer.set_bus_effect_enabled(i, 1, false) # filtre de pause


## Chaîne d'effets d'un bus (docs/AUDIO.md §2).
static func effects_for(bus_name: StringName) -> Array[AudioEffect]:
	var out: Array[AudioEffect] = []
	match bus_name:
		MASTER:
			var mono: AudioEffectStereoEnhance = AudioEffectStereoEnhance.new()
			mono.resource_name = FX_MONO
			mono.pan_pullout = 0.0 # côté (L−R) supprimé : somme mono
			mono.time_pullout_ms = 0.0
			out.append(mono)
			var limiter: AudioEffectHardLimiter = AudioEffectHardLimiter.new()
			limiter.ceiling_db = -1.0
			limiter.pre_gain_db = 0.0
			limiter.release = 0.1
			out.append(limiter)
		MUSIC:
			out.append(_duck())
			var muffle: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
			muffle.resource_name = FX_MUFFLE
			muffle.cutoff_hz = 2500.0
			out.append(muffle)
		AMBIENCE:
			out.append(_duck())
			var glass: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
			glass.resource_name = "Glass"
			glass.cutoff_hz = 8000.0
			out.append(glass)
			var station: AudioEffectReverb = AudioEffectReverb.new()
			station.resource_name = "Station"
			station.room_size = 0.8
			station.damping = 0.4
			station.wet = 0.25
			station.dry = 1.0
			station.spread = 1.0
			out.append(station)
		SFX:
			var comp: AudioEffectCompressor = AudioEffectCompressor.new()
			comp.ratio = 3.0
			comp.threshold = -12.0
			comp.attack_us = 5000.0
			comp.release_ms = 120.0
			out.append(comp)
		SFX_WORLD:
			var hall: AudioEffectReverb = AudioEffectReverb.new()
			hall.resource_name = "Hall"
			hall.room_size = 0.85
			hall.damping = 0.35
			hall.wet = 0.22
			hall.dry = 1.0
			hall.predelay_msec = 40.0
			out.append(hall)
		VOICE:
			out.append(_duck())
			var hp: AudioEffectHighPassFilter = AudioEffectHighPassFilter.new()
			hp.resource_name = FX_HYGIAPHONE
			hp.cutoff_hz = 380.0
			hp.resonance = 0.6
			out.append(hp)
			var lp: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
			lp.resource_name = FX_HYGIAPHONE + "LP"
			lp.cutoff_hz = 3400.0
			lp.resonance = 0.7
			out.append(lp)
			var eq: AudioEffectEQ6 = AudioEffectEQ6.new()
			eq.set_band_gain_db(2, -2.0) # 320 Hz : moins de « boîte »
			eq.set_band_gain_db(3, 3.0) # 1 kHz : nasal, intelligible
			eq.set_band_gain_db(4, 2.0) # 3,2 kHz : présence
			out.append(eq)
			var grain: AudioEffectDistortion = AudioEffectDistortion.new()
			grain.mode = AudioEffectDistortion.MODE_OVERDRIVE
			grain.drive = 0.12
			grain.pre_gain = 0.0
			grain.post_gain = -1.0
			out.append(grain)
			var booth: AudioEffectReverb = AudioEffectReverb.new()
			booth.resource_name = "Booth"
			booth.room_size = 0.15
			booth.damping = 0.6
			booth.wet = 0.12
			booth.dry = 1.0
			booth.predelay_msec = 8.0
			out.append(booth)
			var comp_v: AudioEffectCompressor = AudioEffectCompressor.new()
			comp_v.ratio = 4.0
			comp_v.threshold = -18.0
			comp_v.attack_us = 3000.0
			comp_v.release_ms = 150.0
			comp_v.gain = 3.0
			out.append(comp_v)
	return out


static func _duck() -> AudioEffectAmplify:
	var duck: AudioEffectAmplify = AudioEffectAmplify.new()
	duck.resource_name = FX_DUCK
	duck.volume_db = 0.0
	return duck


## Index d'un effet nommé sur un bus (−1 si absent).
static func find_effect(bus_name: StringName, fx_name: String) -> int:
	var bus: int = AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return -1
	for i: int in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i).resource_name == fx_name:
			return i
	return -1


## Effet nommé (null si absent).
static func get_effect(bus_name: StringName, fx_name: String) -> AudioEffect:
	var index: int = find_effect(bus_name, fx_name)
	if index < 0:
		return null
	return AudioServer.get_bus_effect(AudioServer.get_bus_index(bus_name), index)


static func set_effect_enabled(bus_name: StringName, fx_name: String, enabled: bool) -> void:
	var index: int = find_effect(bus_name, fx_name)
	if index >= 0:
		AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index(bus_name), index, enabled)


static func is_effect_enabled(bus_name: StringName, fx_name: String) -> bool:
	var index: int = find_effect(bus_name, fx_name)
	return index >= 0 and AudioServer.is_bus_effect_enabled(AudioServer.get_bus_index(bus_name), index)
