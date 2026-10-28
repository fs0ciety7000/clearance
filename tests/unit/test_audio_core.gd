## Audio (M6) : bus (`default_bus_layout.tres`), Settings → bus (volumes,
## mono), cue sheet, pool de voix (priorités, vol, polyphonie), voix Tessar.
extends GutTest

var _saved: Dictionary[StringName, Variant] = {}


func before_each() -> void:
	_saved.clear()
	for key: StringName in [Settings.KEY_VOLUME_MASTER, Settings.KEY_VOLUME_MUSIC, Settings.KEY_VOLUME_VOICE,
			Settings.KEY_VOLUME_UI, Settings.KEY_AUDIO_MONO]:
		_saved[key] = Settings.get_value(key)


func after_each() -> void:
	for key: StringName in _saved:
		Settings.set_value(key, _saved[key], false)


# --- Bus -----------------------------------------------------------------------

func test_bus_layout_matches_design() -> void:
	var layout_path: String = ProjectSettings.get_setting("audio/buses/default_bus_layout", "")
	assert_eq(layout_path, AudioBuses.DEFAULT_LAYOUT_PATH)
	for entry: Array in AudioBuses.LAYOUT:
		var bus_name: StringName = entry[0]
		var index: int = AudioServer.get_bus_index(bus_name)
		assert_true(index >= 0, "bus %s présent" % bus_name)
		if index > 0:
			var parent: StringName = entry[1]
			assert_eq(AudioServer.get_bus_send(index), parent, "envoi de %s" % bus_name)
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(AudioBuses.SFX_WORLD)), AudioBuses.SFX)


func test_bus_effects() -> void:
	assert_true(AudioBuses.find_effect(AudioBuses.VOICE, AudioBuses.FX_HYGIAPHONE) >= 0, "hygiaphone sur Voice")
	assert_true(AudioBuses.get_effect(AudioBuses.SFX_WORLD, "Hall") is AudioEffectReverb, "réverbération du hall")
	var master: int = AudioServer.get_bus_index(AudioBuses.MASTER)
	var has_limiter: bool = false
	for i: int in AudioServer.get_bus_effect_count(master):
		has_limiter = has_limiter or AudioServer.get_bus_effect(master, i) is AudioEffectHardLimiter
	assert_true(has_limiter, "limiteur sur Master")
	for bus_name: StringName in [AudioBuses.MUSIC, AudioBuses.AMBIENCE, AudioBuses.VOICE]:
		assert_true(AudioBuses.get_effect(bus_name, AudioBuses.FX_DUCK) is AudioEffectAmplify, "Duck sur %s" % bus_name)
	assert_eq(AudioServer.get_bus_effect_count(AudioServer.get_bus_index(AudioBuses.UI)), 0, "UI sec")


func test_settings_volume_drives_bus() -> void:
	Settings.set_value(Settings.KEY_VOLUME_MUSIC, 0.5, false)
	var music: int = AudioServer.get_bus_index(AudioBuses.MUSIC)
	assert_almost_eq(AudioServer.get_bus_volume_db(music), linear_to_db(0.5), 0.01)
	assert_false(AudioServer.is_bus_mute(music))
	Settings.set_value(Settings.KEY_VOLUME_VOICE, 0.0, false)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(AudioBuses.VOICE)), "0 % = coupé")
	Settings.set_value(Settings.KEY_VOLUME_UI, 1.0, false)
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(AudioBuses.UI)), 0.0, 0.01)


func test_settings_mono_toggles_master_effect() -> void:
	Settings.set_value(Settings.KEY_AUDIO_MONO, true, false)
	assert_true(AudioBuses.is_effect_enabled(AudioBuses.MASTER, AudioBuses.FX_MONO))
	var mono: AudioEffectStereoEnhance = AudioBuses.get_effect(AudioBuses.MASTER, AudioBuses.FX_MONO) as AudioEffectStereoEnhance
	assert_eq(mono.pan_pullout, 0.0, "côté supprimé = somme L/R")
	Settings.set_value(Settings.KEY_AUDIO_MONO, false, false)
	assert_false(AudioBuses.is_effect_enabled(AudioBuses.MASTER, AudioBuses.FX_MONO))


# --- Cue sheet -------------------------------------------------------------------

func test_every_cue_loads_on_a_known_bus() -> void:
	var names: Array[StringName] = []
	for entry: Array in AudioBuses.LAYOUT:
		names.append(entry[0])
	for cue: StringName in AudioCueBank.CUES:
		assert_has(names, AudioCueBank.bus_of(cue), "bus de %s" % cue)
		assert_not_null(AudioCueBank.stream_of(cue), "flux de %s" % cue)
		assert_between(AudioCueBank.priority_of(cue), AudioCueBank.P1, AudioCueBank.P3)


func test_variants_become_randomizers_and_loops_loop() -> void:
	assert_true(AudioCueBank.stream_of(&"passenger.step") is AudioStreamRandomizer)
	var rnd: AudioStreamRandomizer = AudioCueBank.stream_of(&"passenger.step") as AudioStreamRandomizer
	assert_eq(rnd.streams_count, 8)
	var rain: AudioStreamOggVorbis = AudioCueBank.stream_of(&"amb.rain_glass") as AudioStreamOggVorbis
	assert_not_null(rain)
	assert_true(rain.loop, "boucle d'ambiance")
	var hum: AudioStreamWAV = AudioCueBank.stream_of(&"booth.holo_hum") as AudioStreamWAV
	assert_ne(hum.loop_mode, AudioStreamWAV.LOOP_DISABLED, "bourdon holo bouclé (import)")


# --- Pool de voix ------------------------------------------------------------------

func _pool(size: int) -> VoicePool:
	var pool: VoicePool = VoicePool.new()
	add_child_autofree(pool)
	pool.setup(AudioBuses.SFX, size)
	return pool


func _long_stream() -> AudioStream:
	return AudioCueBank.stream_of(&"amb.station_bed")


func test_pool_steals_lowest_priority_never_p1() -> void:
	var pool: VoicePool = _pool(2)
	var s: AudioStream = _long_stream()
	assert_not_null(pool.play(&"a", s, AudioCueBank.P3, 0.0))
	assert_not_null(pool.play(&"b", s, AudioCueBank.P1, 0.0))
	assert_eq(pool.active_count(), 2)
	# P2 vole la P3.
	assert_not_null(pool.play(&"c", s, AudioCueBank.P2, 0.0))
	assert_eq(pool.stolen, 1)
	assert_does_not_have(pool.active_cues(), &"a")
	# P3 ne peut voler ni P2 ni P1 : abandonnée.
	assert_null(pool.play(&"d", s, AudioCueBank.P3, 0.0))
	assert_eq(pool.dropped, 1)
	# P1 vole la P2, jamais la P1.
	assert_not_null(pool.play(&"e", s, AudioCueBank.P1, 0.0))
	assert_has(pool.active_cues(), &"b")
	assert_has(pool.active_cues(), &"e")
	# Deux P1 en cours : une troisième P1 est abandonnée.
	assert_null(pool.play(&"f", s, AudioCueBank.P1, 0.0))
	assert_eq(pool.active_count(), 2, "jamais plus de voix que le pool")


func test_pool_polyphony_per_cue() -> void:
	var pool: VoicePool = _pool(4)
	var s: AudioStream = _long_stream()
	for i: int in 3:
		pool.play(&"hover", s, AudioCueBank.P3, 0.0, 1.0, 1)
	assert_eq(pool.count_cue(&"hover"), 1, "max_polyphony = 1")
	assert_eq(pool.active_count(), 1)


# --- Tessar ------------------------------------------------------------------------

func _passenger(sex: StringName, seed_value: int, age_band: int = 1) -> Passenger:
	var p: Passenger = Passenger.new()
	p.sex = sex
	p.appearance_seed = seed_value
	p.appearance = PassengerAppearance.new({}, age_band)
	return p


func test_tessar_phrases_follow_lore() -> void:
	assert_eq(TessarVoice.phrase_for("bark_present"), "tal ka nesu")
	assert_eq(TessarVoice.phrase_for("bark_arrival"), "oru ka")
	assert_string_ends_with(TessarVoice.phrase_for("x_question", "Vous êtes sûr ?"), "sa?")
	assert_eq(TessarVoice.phrase_for("line_stay_long", "abc"), TessarVoice.phrase_for("line_stay_long", "abc"), "déterministe")
	var allowed: Array[String] = TessarVoice.CONSONANTS
	for key: String in ["line_purpose_work", "line_stay_short", "line_about_photo", "murmur_3"]:
		var words: Array[Array] = TessarVoice.syllabify(TessarVoice.phrase_for(key, "Je viens pour travailler ici, trois jours."))
		assert_gt(words.size(), 0)
		for w: Array in words:
			for syl: Array in w:
				var onset: String = syl[0]
				assert_true(onset.is_empty() or allowed.has(onset), "attaque « %s » (%s)" % [onset, key])
				var vowel: String = syl[1]
				assert_has(TessarVoice.VOWELS, vowel)
				var coda: String = syl[2]
				assert_true(coda.is_empty() or TessarVoice.CODAS.has(coda), "coda « %s »" % coda)


func test_tessar_voice_per_passenger() -> void:
	var f: TessarVoice.Profile = TessarVoice.profile_for(_passenger(Passenger.SEX_F, 11))
	var m: TessarVoice.Profile = TessarVoice.profile_for(_passenger(Passenger.SEX_M, 11))
	var old: TessarVoice.Profile = TessarVoice.profile_for(_passenger(Passenger.SEX_M, 11, 2))
	assert_gt(f.f0, m.f0, "voix féminine plus aiguë")
	assert_gt(f.formant_scale, m.formant_scale)
	assert_eq(old.family, &"old")
	assert_gt(old.jitter, m.jitter, "voix âgée plus instable")
	var again: TessarVoice.Profile = TessarVoice.profile_for(_passenger(Passenger.SEX_F, 11))
	assert_eq(again.f0, f.f0, "même passager = même voix")
	assert_ne(TessarVoice.profile_for(_passenger(Passenger.SEX_F, 12)).f0, f.f0, "graine différente = autre voix")


func test_tessar_render_is_short_audible_and_deterministic() -> void:
	var prof: TessarVoice.Profile = TessarVoice.profile_for(_passenger(Passenger.SEX_X, 7))
	var a: PackedFloat32Array = TessarVoice.synthesize("kumo ri sava sa?", prof, TessarVoice.MOOD_ANGRY)
	var b: PackedFloat32Array = TessarVoice.synthesize("kumo ri sava sa?", prof, TessarVoice.MOOD_ANGRY)
	assert_eq(a, b, "déterministe")
	var seconds: float = a.size() / float(TessarVoice.SAMPLE_RATE)
	assert_between(seconds, 0.4, 2.6, "bark court")
	assert_almost_eq(linear_to_db(AudioDsp.peak(a)), TessarVoice.PEAK_DB, 0.2, "crête normalisée")
	assert_gt(linear_to_db(AudioDsp.rms(a)), -30.0, "audible")
	var wav: AudioStreamWAV = TessarVoice.render("oru ka", prof)
	assert_eq(wav.mix_rate, TessarVoice.SAMPLE_RATE)
	assert_false(wav.stereo, "mono (spatialisé en 3D)")
	assert_between(wav.get_length(), 0.3, 1.5)
