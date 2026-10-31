## M14 — moteur musical (B82, D-176, D-083) : un seul lecteur à volume fixe,
## couches dans le flux (`AudioStreamSynchronized` dans un
## `AudioStreamInteractive`), niveaux N0 → N4 à la mesure, fondus par l'effet
## `Fade` du bus `Music`, sortie propre (QA-039). docs/AUDIO.md §13.
extends GutTest

const BAR_SEC: float = 3.0

var _director: MusicDirector = null


func after_each() -> void:
	if _director != null and is_instance_valid(_director):
		_director.queue_free()
	_director = null
	var fade: AudioEffectAmplify = AudioBuses.get_effect(AudioBuses.MUSIC, AudioBuses.FX_FADE) as AudioEffectAmplify
	if fade != null:
		fade.volume_db = 0.0


## Flux de test : sinus court en boucle (aucun fichier).
func _tone(hz: float) -> AudioStreamWAV:
	var buf: PackedFloat32Array = AudioDsp.gain(AudioDsp.sine(3200, hz, 32000), 0.1)
	return AudioDsp.to_wav(buf, 32000, PackedFloat32Array(), true)


func _layers(count: int = 5) -> Array[AudioStream]:
	var out: Array[AudioStream] = []
	for i: int in count:
		out.append(_tone(220.0 * (i + 1)))
	return out


func _make() -> MusicDirector:
	_director = MusicDirector.new()
	add_child(_director)
	return _director


func _sync(d: MusicDirector, clip: StringName) -> AudioStreamSynchronized:
	return d._clips[clip]["sync"] as AudioStreamSynchronized


# --- Règles pures ----------------------------------------------------------------

func test_level_table_follows_m14() -> void:
	assert_eq(MusicDirector.layers_for_level(0), PackedByteArray([1, 0, 0, 0, 0]), "N0 : L0")
	assert_eq(MusicDirector.layers_for_level(2), PackedByteArray([1, 1, 1, 0, 0]), "N2 : L0–L2")
	assert_eq(MusicDirector.layers_for_level(3), PackedByteArray([1, 1, 1, 1, 0]), "N3 : + L3")
	assert_eq(MusicDirector.layers_for_level(4), PackedByteArray([1, 1, 1, 0, 1]), "N4 : L4 remplace L3")
	assert_eq(MusicDirector.layers_for_level(MusicDirector.LEVEL_EXPOSED), PackedByteArray([1, 0, 0, 1, 0]), "exposé")
	assert_eq(MusicDirector.layers_for_level(3, true), PackedByteArray([1, 1, 1, 0, 0]), "sans mélodie : L3 coupée")


func test_level_steps_are_rate_limited() -> void:
	assert_eq(MusicDirector.next_level(0, 4, 1), 0, "+1 au plus toutes les 2 mesures")
	assert_eq(MusicDirector.next_level(0, 4, 2), 1, "un seul cran à la fois")
	assert_eq(MusicDirector.next_level(4, 0, 3), 4, "−1 au plus toutes les 4 mesures")
	assert_eq(MusicDirector.next_level(4, 0, 4), 3)
	assert_eq(MusicDirector.next_level(2, 2, 10), 2)


func test_music_bus_has_fade_effect() -> void:
	assert_true(AudioBuses.get_effect(AudioBuses.MUSIC, AudioBuses.FX_FADE) is AudioEffectAmplify, "Fade sur Music")
	assert_true(AudioBuses.is_effect_enabled(AudioBuses.MUSIC, AudioBuses.FX_FADE), "Fade actif")
	assert_true(AudioBuses.find_effect(AudioBuses.MUSIC, AudioBuses.FX_DUCK) >= 0, "Duck gardé")


# --- Lecteur ---------------------------------------------------------------------

func test_single_player_with_fixed_volume_and_interactive_stream() -> void:
	var d: MusicDirector = _make()
	d.configure_set(&"ms_test", _layers(), 80.0, 4, PackedFloat32Array([-10.0, -12.0, -14.0, -16.0, -18.0]))
	d.play(&"ms_test", 2)
	var players: int = 0
	for child: Node in d.get_children():
		if child is AudioStreamPlayer:
			players += 1
	assert_eq(players, 1, "un seul lecteur de musique")
	assert_true(d.player.stream is AudioStreamInteractive, "flux interactif")
	assert_true(d.interactive.get_clip_stream(0) is AudioStreamSynchronized, "clip = couches synchronisées")
	assert_eq(d.player.bus, AudioBuses.MUSIC)
	for i: int in 50:
		d.force_level(i % MusicDirector.LEVEL_COUNT)
		d._ramp_layers(0.1)
		d.fade_to(-6.0 * (i % 3), 0.2)
		d._update_fade(0.05)
	assert_eq(d.player.volume_db, 0.0, "volume du lecteur jamais modifié (D-083)")


func test_layer_volumes_live_in_the_stream_and_ramp_over_a_bar() -> void:
	var d: MusicDirector = _make()
	var gains: PackedFloat32Array = PackedFloat32Array([-10.0, -12.0, -14.0, -16.0, -18.0])
	d.configure_set(&"ms_test", _layers(), 80.0, 4, gains)
	d.play(&"ms_test", 0)
	var sync: AudioStreamSynchronized = _sync(d, &"ms_test")
	assert_almost_eq(sync.get_sync_stream_volume(0), -10.0, 0.01, "N0 : L0 à son gain")
	assert_eq(sync.get_sync_stream_volume(1), MusicDirector.SILENT_DB, "N0 : L1 muette")
	d.force_level(3)
	d._ramp_layers(BAR_SEC * 0.5)
	assert_almost_eq(d.get_layer_amp(1), 0.5, 0.01, "mi-rampe après une demi-mesure")
	d._ramp_layers(BAR_SEC * 0.5)
	assert_almost_eq(sync.get_sync_stream_volume(3), -16.0, 0.01, "N3 : L3 pleine après une mesure")
	assert_eq(sync.get_sync_stream_volume(4), MusicDirector.SILENT_DB, "N3 : L4 muette")
	d.force_level(4)
	d._ramp_layers(BAR_SEC)
	assert_eq(sync.get_sync_stream_volume(3), MusicDirector.SILENT_DB, "N4 : L3 sort")
	assert_almost_eq(sync.get_sync_stream_volume(4), -18.0, 0.01, "N4 : L4 entre")


func test_request_level_applies_only_at_bar_boundaries() -> void:
	var d: MusicDirector = _make()
	d.configure_set(&"ms_test", _layers(), 80.0)
	d.play(&"ms_test", 0)
	var changes: Array[int] = []
	d.level_changed.connect(func(l: int) -> void: changes.append(l))
	d.request_level(4)
	assert_eq(d.level, 0, "pas de changement hors limite de mesure")
	for bar: int in 8:
		d._bars_since_change += 1
		d._on_bar()
	assert_eq(changes, [1, 2, 3, 4] as Array[int], "+1 toutes les 2 mesures")
	changes.clear()
	d.request_level(0)
	for bar: int in 8:
		d._bars_since_change += 1
		d._on_bar()
	assert_eq(changes, [3, 2] as Array[int], "−1 toutes les 4 mesures")


func test_fade_goes_through_the_bus_effect() -> void:
	var d: MusicDirector = _make()
	d.configure_set(&"ms_test", _layers(), 80.0)
	d.play(&"ms_test", 1, 1.5)
	assert_eq(MusicDirector.get_fade_db(), MusicDirector.SILENT_DB, "fondu d'entrée depuis le silence")
	d._update_fade(0.75)
	assert_between(MusicDirector.get_fade_db(), -12.0, -3.0, "mi-fondu (amplitude 0,5 ≈ −6 dB)")
	d._update_fade(1.0)
	assert_almost_eq(MusicDirector.get_fade_db(), 0.0, 0.001)
	d.fade_to(-80.0, 0.5, true)
	d._update_fade(0.6)
	assert_false(d.is_playing(), "fondu de sortie puis arrêt")
	assert_eq(d.player.volume_db, 0.0)


func test_exit_tree_stops_and_clears_the_player() -> void:
	var d: MusicDirector = _make()
	d.configure_set(&"ms_test", _layers(), 80.0)
	d.play(&"ms_test", 2, 1.0)
	var player: AudioStreamPlayer = d.player
	remove_child(d)
	assert_false(player.playing, "arrêté à la sortie de l'arbre")
	assert_null(player.stream, "flux vidé (QA-039)")
	assert_almost_eq(MusicDirector.get_fade_db(), 0.0, 0.001, "Fade remis à 0 dB")
	d.free()
	_director = null


func test_set_def_masks_drive_the_layers() -> void:
	var set_def: MusicSetDef = MusicSetDef.new()
	set_def.id = &"ms_02"
	set_def.exposed_gain_db = 6.0
	var roles: Array[StringName] = [MusicLayerDef.ROLE_PAD, MusicLayerDef.ROLE_PULSE, MusicLayerDef.ROLE_RHYTHM,
		MusicLayerDef.ROLE_MOTIF, MusicLayerDef.ROLE_TENSION]
	var streams: Array[AudioStream] = _layers()
	for i: int in 5:
		var layer: MusicLayerDef = MusicLayerDef.new()
		layer.id = StringName("l%d" % i)
		layer.role = roles[i]
		layer.stream = streams[i]
		layer.gain_db = -10.0 - i
		layer.enter_level = i
		layer.exit_level = 4 if i == 3 else -1
		layer.exposed = i == 0 or i == 3
		layer.melodic = i == 3
		layer.keeps_on_power_down = i == 0
		set_def.layers.append(layer)
	var d: MusicDirector = _make()
	d.configure_from_def(set_def)
	d.play(&"ms_02", 3)
	var sync: AudioStreamSynchronized = _sync(d, &"ms_02")
	assert_almost_eq(sync.get_sync_stream_volume(3), -13.0, 0.01, "N3 : L3 au gain de la donnée")
	d.mute_motif = true
	d._ramp_layers(BAR_SEC)
	assert_eq(sync.get_sync_stream_volume(3), MusicDirector.SILENT_DB, "sans mélodie : L3 coupée")
	d.mute_motif = false
	d.force_level(MusicDirector.LEVEL_EXPOSED)
	d._ramp_layers(BAR_SEC)
	assert_almost_eq(sync.get_sync_stream_volume(0), -4.0, 0.01, "exposé : L0 + gain exposé")
	assert_almost_eq(sync.get_sync_stream_volume(3), -7.0, 0.01, "exposé : L3 + gain exposé")
	assert_eq(sync.get_sync_stream_volume(1), MusicDirector.SILENT_DB, "exposé : L1 muette")
	d.force_level(4)
	d.power_down = true
	d._ramp_layers(BAR_SEC)
	for i: int in range(1, 5):
		assert_eq(sync.get_sync_stream_volume(i), MusicDirector.SILENT_DB, "power down : L%d muette" % i)
	assert_almost_eq(sync.get_sync_stream_volume(0), -10.0, 0.01, "power down : L0 seule")


func test_theme_auto_advances_to_its_tail() -> void:
	var d: MusicDirector = _make()
	d.configure_set(&"ms_test", _layers(), 80.0)
	d.configure_theme(&"th_test", _tone(330.0), 75.0, 4, _tone(440.0))
	d.play(&"th_test")
	var main_index: int = d._clip_order.find(&"th_test")
	var tail_index: int = d._clip_order.find(&"th_test_tail")
	assert_true(tail_index >= 0, "clip de queue déclaré")
	assert_eq(d.interactive.get_clip_auto_advance(main_index), AudioStreamInteractive.AUTO_ADVANCE_ENABLED)
	assert_eq(d.interactive.get_clip_auto_advance_next_clip(main_index), tail_index, "thème → queue")
	assert_eq(d.interactive.get_clip_auto_advance(tail_index), AudioStreamInteractive.AUTO_ADVANCE_DISABLED,
			"la queue boucle")


func test_library_mask_and_skip_to_tail() -> void:
	var library: MusicLibraryDef = MusicLibraryDef.load_default()
	if library == null:
		pending("music_library.tres pas encore rendue")
		return
	var d: MusicDirector = _make()
	d.use_library(library)
	var set_def: MusicSetDef = library.get_set(MusicLibraryDef.SET_ACT1)
	assert_not_null(set_def, "MS-02 dans la bibliothèque")
	assert_eq(set_def.layers.size(), 5, "cinq couches")
	for layer: MusicLayerDef in set_def.layers:
		assert_not_null(layer.stream, "%s rendue" % layer.id)
		assert_eq(roundi(layer.stream.get_length() * set_def.sample_rate), set_def.loop_samples(),
				"%s : longueur exacte (M-06)" % layer.id)
	d.play(MusicLibraryDef.SET_ACT1, 3)
	d.set_mask(MusicSetDef.MASK_NO_MELODY)
	d._ramp_layers(set_def.seconds_per_bar())
	assert_eq(_sync(d, MusicLibraryDef.SET_ACT1).get_sync_stream_volume(3), MusicDirector.SILENT_DB, "sans mélodie")
	var theme: MusicThemeDef = library.get_theme(&"th_f9")
	assert_not_null(theme, "TH-F9 dans la bibliothèque")
	assert_not_null(theme.tail_stream, "queue de TH-F9")
	d.play_theme(theme)
	assert_eq(d.get_current_clip(), &"th_f9")
	d.skip_to_tail()
	assert_eq(d.get_current_clip(), &"th_f9_tail", "cinématique passée : queue")
	assert_eq(d.player.volume_db, 0.0)


# --- Phase 2 : gain des thèmes, fin → thème, volume à 0 ----------------------------

func test_theme_gain_lives_in_the_stream() -> void:
	var d: MusicDirector = _make()
	d.configure_theme(&"th_g", _tone(330.0), 75.0, 4, _tone(440.0), -4.5)
	var main: AudioStreamSynchronized = d._clips[&"th_g"]["stream"] as AudioStreamSynchronized
	var tail: AudioStreamSynchronized = d._clips[&"th_g_tail"]["stream"] as AudioStreamSynchronized
	assert_not_null(main, "thème enveloppé dans le flux")
	assert_almost_eq(main.get_sync_stream_volume(0), -4.5, 0.001, "gain d'exécution du thème")
	assert_almost_eq(tail.get_sync_stream_volume(0), -4.5, 0.001, "même gain pour la queue")
	d.play(&"th_g")
	assert_eq(d.player.volume_db, 0.0)
	var theme: MusicThemeDef = MusicThemeDef.new()
	theme.set_meta(&"gain_db", -3.3)
	assert_almost_eq(MusicDirector.theme_gain_db(theme), -3.3, 0.001, "métadonnée gain_db")


func test_end_theme_starts_after_the_bus_fade() -> void:
	var d: MusicDirector = _make()
	d.configure_set(&"ms_test", _layers(), 80.0)
	d.play(&"ms_test", 1)
	var theme: MusicThemeDef = MusicThemeDef.new()
	theme.id = &"th_end"
	theme.tempo_bpm = 75.0
	theme.stream = _tone(330.0)
	theme.tail_stream = _tone(440.0)
	d.play_theme_after_fade(theme, {}, false, 2.0)
	assert_true(d.has_pending_theme(), "fondu de sortie d'abord")
	assert_eq(d.get_current_clip(), &"ms_test")
	d._update_fade(1.0)
	assert_lt(MusicDirector.get_fade_db(), -1.0, "le bus Fade descend")
	d._update_fade(1.1)
	assert_false(d.has_pending_theme())
	assert_eq(d.get_current_clip(), &"th_end", "puis le thème depuis le début")
	assert_eq(MusicDirector.get_fade_db(), 0.0, "Fade rouvert")
	assert_eq(d.player.volume_db, 0.0)
	d.play_theme_after_fade(theme, {}, false, 0.0, true)
	assert_eq(d.get_current_clip(), &"th_end_tail", "TH-F7 : la queue directement")


func test_zero_music_volume_stops_the_player() -> void:
	var d: MusicDirector = _make()
	d.configure_set(&"ms_test", _layers(), 80.0)
	d.play(&"ms_test", 2)
	d.set_suspended(true)
	assert_false(d.is_playing(), "volume 0 : lecteur arrêté (CPU nul)")
	d.switch_clip(&"ms_test", 3)
	d.set_suspended(false)
	assert_true(d.is_playing(), "repris au retour du volume")
	assert_eq(d.get_current_clip(), &"ms_test")
	assert_eq(d.level, 3)


func test_bar_signal_ticks_once_per_bar() -> void:
	var d: MusicDirector = _make()
	d.configure_set(&"ms_test", _layers(), 80.0)
	d.play(&"ms_test", 0)
	watch_signals(d)
	d._clock_usec = int(BAR_SEC * 2.5 * 1_000_000.0)
	d._last_usec = Time.get_ticks_usec()
	d._process(0.0)
	assert_signal_emit_count(d, "bar_passed", 2, "une émission par mesure")
