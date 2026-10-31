## M14 — rendu musical hors ligne (B79/B80, D-180) : briques `AudioDsp`,
## `MusicRenderer` (longueur exacte, repli de queue, déterminisme), sonie
## BS.1770 (`AudioLoudness`), partitions d'`art_src/music/` et manifeste
## (M-06 : longueurs et `.import`). docs/AUDIO.md §13.4–§13.5.
extends GutTest

const SR: int = 32000
const MANIFEST_PATH: String = "res://assets/audio/music/manifest.json"


func _mini_score() -> Dictionary:
	return {
		"id": "test_mini", "kind": "set", "tempo": 80, "beats_per_bar": 4, "bars": 2, "tail_bars": 1,
		"sample_rate": SR, "seed": 7,
		"chords": [{"bar": 0, "bars": 2, "bass": "A1", "notes": ["A3", "C4", "E4"]}],
		"motifs": {"MO-1": [{"step": 0, "len": 4, "note": "E5"}, {"step": 4, "len": 4, "note": "C5"}]},
		"instruments": {
			"pad": {"type": "pad", "voices": 2, "cutoff": 900, "attack": 0.3, "release": 0.8, "level": 0.3},
			"bass": {"type": "bass", "level": 0.5},
			"bell": {"type": "bell", "length": 1.0},
			"tick": {"type": "tick", "cutoff": 7000},
		},
		"mix": {"eq": [{"freq": 2000, "q": 0.7, "gain_db": -6}], "reverb": {"rt60": 1.5}, "width": 0.6},
		"stems": [
			{"id": "l0", "tracks": [{"instrument": "pad", "send": 0.3, "chords": {}}]},
			{"id": "l1", "tracks": [{"instrument": "bass", "humanize_ms": 4, "pattern": {"bars": 1, "steps": [
				{"step": 0, "note": "bass"}, {"step": 8, "note": "bass", "prob": 0.5}]}}]},
			{"id": "l3", "tracks": [{"instrument": "bell", "send": 0.5, "events": [{"motif": "MO-1", "bar": 1, "step": 0}]},
				{"instrument": "tick", "pattern": {"bars": 1, "steps": [{"step": 2}, {"step": 6, "prob": 0.5}]}}]},
		],
	}


# --- Briques AudioDsp -------------------------------------------------------------

func test_oscillators_are_bounded_and_band_limited() -> void:
	var saw: PackedFloat32Array = AudioDsp.blep_saw(SR, 440.0, SR)
	var pulse: PackedFloat32Array = AudioDsp.blep_pulse(SR, 440.0, SR, 0.3)
	assert_lt(AudioDsp.peak(saw), 1.2, "dent de scie polyBLEP bornée")
	assert_lt(AudioDsp.peak(pulse), 1.3, "impulsion polyBLEP bornée")
	# Une dent de scie naïve a des marches de 2 ; polyBLEP les adoucit.
	var max_step: float = 0.0
	for i: int in saw.size() - 1:
		max_step = maxf(max_step, absf(saw[i + 1] - saw[i]))
	assert_lt(max_step, 1.5, "discontinuité adoucie (polyBLEP)")


func test_svf_and_fdn_are_stable() -> void:
	var noise: PackedFloat32Array = AudioDsp.white(SR, RandomNumberGenerator.new())
	for mode: AudioDsp.Svf in [AudioDsp.Svf.LOWPASS, AudioDsp.Svf.BANDPASS, AudioDsp.Svf.HIGHPASS]:
		var out: PackedFloat32Array = AudioDsp.svf(noise, mode, PackedFloat32Array([20.0, 15000.0, 300.0]), 4.0, SR)
		assert_lt(AudioDsp.peak(out), 20.0, "SVF stable (mode %d)" % mode)
	var impulse: PackedFloat32Array = AudioDsp.silence(SR * 3)
	impulse[0] = 1.0
	var wet: Array[PackedFloat32Array] = AudioDsp.fdn_reverb(impulse, impulse, SR, 1.0)
	var early: float = AudioDsp.rms(wet[0].slice(0, SR / 2))
	var late: float = AudioDsp.rms(wet[0].slice(SR * 2, SR * 3))
	assert_gt(early, 0.0, "la réverbération répond")
	assert_lt(late, early * 0.01, "RT60 = 1 s : −40 dB et plus après 2 s")


func test_karplus_decays_and_ms_width_zero_is_mono() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var pluck: PackedFloat32Array = AudioDsp.karplus(SR * 2, 220.0, SR, rng, 0.01, 0.5)
	assert_lt(AudioDsp.rms(pluck.slice(SR, SR * 2)), AudioDsp.rms(pluck.slice(0, SR / 4)), "le pincé s'éteint")
	var l: PackedFloat32Array = AudioDsp.sine(256, 300.0, SR)
	var r: PackedFloat32Array = AudioDsp.sine(256, 500.0, SR)
	var mono: Array[PackedFloat32Array] = AudioDsp.ms_width(l, r, 0.0)
	assert_eq(mono[0], mono[1], "largeur 0 = mono")


# --- MusicRenderer ----------------------------------------------------------------

func test_tempos_fall_on_whole_samples() -> void:
	assert_eq(MusicRenderer.exact_bar_samples(80.0, 4, 32000), 96000, "MS-02 : 3 s à 32 kHz")
	assert_eq(MusicRenderer.exact_bar_samples(75.0, 4, 48000), 153600, "TH-F9 : 3,2 s à 48 kHz")
	assert_eq(MusicRenderer.exact_bar_samples(64.0, 4, 32000), 120000, "MS-04 : 3,75 s")
	assert_eq(MusicRenderer.exact_bar_samples(72.0, 4, 44100), 0, "72 BPM à 44,1 kHz : pas exact")
	assert_eq(MusicRenderer.note_to_midi("A4"), 69)
	assert_eq(MusicRenderer.note_to_midi("F#3"), 54)
	assert_eq(MusicRenderer.note_to_midi("Eb5"), 75)
	assert_eq(MusicRenderer.note_to_midi("H2"), -1)


func test_stems_have_exact_length_and_are_deterministic() -> void:
	var a: MusicRenderer = MusicRenderer.new(_mini_score())
	var b: MusicRenderer = MusicRenderer.new(_mini_score())
	assert_true(a.errors.is_empty(), "partition valide : %s" % [a.errors])
	for stem: String in a.stem_ids():
		var x: Array[PackedFloat32Array] = a.render_stem(stem)
		var y: Array[PackedFloat32Array] = b.render_stem(stem)
		assert_eq(x[0].size(), 2 * a.bar_n, "%s : longueur = mesures × échantillons par mesure" % stem)
		assert_eq(x[0], y[0], "%s : rendu déterministe (gauche)" % stem)
		assert_eq(x[1], y[1], "%s : rendu déterministe (droite)" % stem)
		assert_gt(AudioDsp.peak(x[0]), 0.0001, "%s : non silencieux" % stem)


func test_loop_fold_makes_a_seamless_junction() -> void:
	var r: MusicRenderer = MusicRenderer.new(_mini_score())
	var pad: Array[PackedFloat32Array] = r.render_stem("l0")
	for ch: int in 2:
		var buf: PackedFloat32Array = pad[ch]
		var steps: PackedFloat32Array = PackedFloat32Array()
		for i: int in buf.size() - 1:
			steps.append(absf(buf[i + 1] - buf[i]))
		steps.sort()
		var p99: float = steps[int(steps.size() * 0.99)]
		assert_lt(absf(buf[0] - buf[buf.size() - 1]), maxf(p99, 1e-4) * 3.0, "jointure sans marche (canal %d)" % ch)


func test_layer_processing_is_linear() -> void:
	# Même réverbération et même égaliseur par couche : la somme des couches
	# traitées = le traitement de leur somme (docs/M14.md §2.8).
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var a: PackedFloat32Array = AudioDsp.gain(AudioDsp.white(SR, rng), 0.3)
	var b: PackedFloat32Array = AudioDsp.gain(AudioDsp.blep_saw(SR, 110.0, SR), 0.3)
	var ab: PackedFloat32Array = AudioDsp.silence(SR)
	for i: int in SR:
		ab[i] = a[i] + b[i]
	var wa: Array[PackedFloat32Array] = AudioDsp.fdn_reverb(a, a, SR, 2.0)
	var wb: Array[PackedFloat32Array] = AudioDsp.fdn_reverb(b, b, SR, 2.0)
	var wab: Array[PackedFloat32Array] = AudioDsp.fdn_reverb(ab, ab, SR, 2.0)
	var ea: PackedFloat32Array = AudioDsp.eq_peak(a, 2000.0, 0.7, -6.0, SR)
	var eb: PackedFloat32Array = AudioDsp.eq_peak(b, 2000.0, 0.7, -6.0, SR)
	var eab: PackedFloat32Array = AudioDsp.eq_peak(ab, 2000.0, 0.7, -6.0, SR)
	var err: float = 0.0
	for i: int in SR:
		err = maxf(err, absf(wa[0][i] + wb[0][i] - wab[0][i]))
		err = maxf(err, absf(ea[i] + eb[i] - eab[i]))
	assert_lt(err, 0.0001, "réverbération et égaliseur linéaires (écart %.6f)" % err)


# --- Sonie ------------------------------------------------------------------------

func test_loudness_matches_bs1770_reference() -> void:
	# Sinus de 997 Hz à −20 dBFS sur les deux canaux : −20 LUFS (±0,1 ;
	# la pondération K vaut ≈ +0,0 dB à 1 kHz et deux canaux ajoutent +3 dB
	# à la valeur d'un sinus RMS −3 dB).
	var tone: PackedFloat32Array = AudioDsp.gain(AudioDsp.sine(48000 * 5, 997.0, 48000), db_to_linear(-20.0))
	var lufs: float = AudioLoudness.integrated(tone, tone, 48000)
	assert_almost_eq(lufs, -20.0, 0.15, "sinus −20 dBFS stéréo → −20 LUFS (mesuré %.2f)" % lufs)
	var quiet: float = AudioLoudness.integrated(AudioDsp.gain(tone, 0.1), AudioDsp.gain(tone, 0.1), 48000)
	assert_almost_eq(quiet - lufs, -20.0, 0.01, "−20 dB de gain = −20 LU")


# --- Partitions et manifeste (M-06, D-179) ---------------------------------------

func test_scores_parse_and_keep_mo1_apart_from_mo2() -> void:
	var files: PackedStringArray = DirAccess.get_files_at("res://art_src/music")
	var count: int = 0
	for file: String in files:
		if not file.ends_with(".json"):
			continue
		count += 1
		var score: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art_src/music/" + file))
		var r: MusicRenderer = MusicRenderer.new(score)
		assert_true(r.errors.is_empty(), "%s : %s" % [file, r.errors])
		var mo1_bars: Dictionary = {}
		var mo2_bars: Dictionary = {}
		for stem: Dictionary in score.get("stems", []):
			for track: Dictionary in stem.get("tracks", []):
				for ev: Dictionary in track.get("events", []):
					var motif: String = str(ev.get("motif", ""))
					if motif == "MO-1":
						mo1_bars[int(ev.get("bar", 0))] = true
					elif motif == "MO-2":
						mo2_bars[int(ev.get("bar", 0))] = true
		for bar: int in mo1_bars:
			assert_false(mo2_bars.has(bar), "%s : MO-1 et MO-2 jamais dans la même mesure (mesure %d)" % [file, bar])
	assert_gt(count, 0, "au moins une partition")


func test_manifest_files_have_exact_lengths_and_import_params() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		pending("musique pas encore rendue")
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	for score_id: String in manifest.get("scores", {}):
		var entry: Dictionary = manifest["scores"][score_id]
		var bar_n: int = int(entry["bar_samples"])
		assert_eq(bar_n, MusicRenderer.exact_bar_samples(float(entry["tempo"]), int(entry["beats_per_bar"]),
				int(entry["sample_rate"])), "%s : mesure exacte" % score_id)
		for name: String in entry.get("files", {}):
			var f: Dictionary = entry["files"][name]
			var path: String = "res://" + str(f["path"])
			assert_true(FileAccess.file_exists(path), "%s présent" % path)
			assert_eq(int(f["samples"]) % bar_n, 0, "%s : nombre entier de mesures" % name)
			assert_true(float(f.get("true_peak_dbtp", 0.0)) <= -1.0, "%s : true peak ≤ −1 dBTP" % name)
			var text: String = FileAccess.get_file_as_string(path + ".import")
			var loop: bool = bool(f.get("loop", false))
			assert_true(text.contains("loop=%s" % ("true" if loop else "false")), "%s : loop" % name)
			assert_true(text.contains("bar_beats=%d" % int(entry["beats_per_bar"])), "%s : bar_beats" % name)
			assert_true(text.contains("beat_count=%d" % (int(f["samples"]) / bar_n * int(entry["beats_per_bar"]))),
					"%s : beat_count" % name)
			var stream: AudioStream = load(path) as AudioStream
			assert_not_null(stream, "%s importé" % name)
			if stream != null:
				assert_almost_eq(stream.get_length(), float(f["samples"]) / int(entry["sample_rate"]), 0.001,
						"%s : durée" % name)
