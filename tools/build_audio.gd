## Génère les assets audio du jeu (docs/AUDIO.md §4, §8) et le
## `default_bus_layout.tres` — reproductible (graines fixes).
##
## Lancé par `bash tools/build_audio.sh` (qui décode d'abord les packs Kenney
## CC0 en WAV et encode ensuite les boucles longues en OGG Vorbis) :
## `godot --headless --script res://tools/build_audio.gd -- --src=<wav Kenney décodés> --loops=<dossier temporaire>`
##
## - Sons courts (SFX, UI, gouttes, annonces PA) : WAV PCM 16 bits mono 48 kHz
##   écrits directement dans `assets/audio/…`.
## - Boucles d'ambiance et de musique : WAV stéréo 24 kHz dans `--loops`,
##   converties en OGG 48 kHz par le script shell.
## Sources : synthèse (bruit filtré, oscillateurs, `TessarVoice`) et sons
## Kenney retravaillés (couches, filtres, rééchantillonnage).
extends SceneTree

const SR: int = 48000
const LOOP_SR: int = 24000
const OUT: String = "res://assets/audio"

var src_dir: String = ""
var loops_dir: String = ""
var only: String = ""
var written: int = 0
var _kenney_cache: Dictionary[String, PackedFloat32Array] = {}


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--src="):
			src_dir = arg.trim_prefix("--src=")
		elif arg.begins_with("--loops="):
			loops_dir = arg.trim_prefix("--loops=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	if src_dir.is_empty() or loops_dir.is_empty():
		push_error("build_audio: --src=<dossier WAV Kenney> et --loops=<dossier> requis")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(loops_dir)
	for sub: String in ["sfx/passenger", "sfx/booth", "sfx/station", "ui", "voice/pa", "ambience", "music"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "/" + sub))
	var t0: int = Time.get_ticks_msec()
	if _want("bus"):
		_build_bus_layout()
	if _want("passenger"):
		_build_passenger()
	if _want("booth"):
		_build_booth()
	if _want("booth") or _want("stamp_lift"):
		_build_stamp_lift()
	if _want("station"):
		_build_station()
	if _want("ui"):
		_build_ui()
	if _want("pa"):
		_build_pa()
	if _want("ambience"):
		_build_ambience()
	if _want("music"):
		_build_music()
	print("build_audio: %d fichiers en %.1f s" % [written, (Time.get_ticks_msec() - t0) / 1000.0])
	quit()


func _want(group: String) -> bool:
	return only.is_empty() or only.split(",").has(group)


# ---------------------------------------------------------------------------
# Entrées / sorties
# ---------------------------------------------------------------------------

## Son Kenney décodé (`<src>/<pack>/<nom>.wav`, mono 48 kHz) → tampon.
func kenney(pack: String, file: String) -> PackedFloat32Array:
	var key: String = pack + "/" + file
	if _kenney_cache.has(key):
		return _kenney_cache[key]
	var path: String = "%s/%s/%s.wav" % [src_dir, pack, file]
	var wav: AudioStreamWAV = AudioStreamWAV.load_from_file(path)
	if wav == null:
		push_error("build_audio: source manquante %s (lancer tools/fetch_assets.sh)" % path)
		return AudioDsp.silence(64)
	var buf: PackedFloat32Array = AudioDsp.from_wav(wav)
	if wav.mix_rate != SR:
		buf = AudioDsp.resample(buf, float(wav.mix_rate) / SR)
	_kenney_cache[key] = buf
	return buf


## Écrit un WAV mono 48 kHz normalisé à `peak_db`.
func save(rel: String, buf: PackedFloat32Array, peak_db: float = -1.0, rate: int = SR, loop: bool = false) -> void:
	var out: PackedFloat32Array = AudioDsp.normalize(buf, peak_db)
	if not loop:
		out = AudioDsp.fade(out, 0.001, 0.01, rate)
	var wav: AudioStreamWAV = AudioDsp.to_wav(out, rate, PackedFloat32Array(), loop)
	var err: Error = wav.save_to_wav(ProjectSettings.globalize_path(OUT + "/" + rel))
	if err != OK:
		push_error("build_audio: écriture %s impossible (%s)" % [rel, error_string(err)])
	written += 1


## Boucle stéréo 24 kHz → dossier temporaire (encodée en OGG ensuite).
func save_loop(name: String, left: PackedFloat32Array, right: PackedFloat32Array, peak_db: float) -> void:
	var p: float = maxf(AudioDsp.peak(left), AudioDsp.peak(right))
	var g: float = db_to_linear(peak_db) / maxf(p, 0.000001)
	var wav: AudioStreamWAV = AudioDsp.to_wav(AudioDsp.gain(left, g), LOOP_SR, AudioDsp.gain(right, g))
	var err: Error = wav.save_to_wav(loops_dir + "/" + name + ".wav")
	if err != OK:
		push_error("build_audio: écriture boucle %s impossible" % name)
	written += 1


func rng_for(tag: String, index: int = 0) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SeededRng.mix(SeededRng.hash_string(tag), index)
	return rng


func n_of(seconds: float, rate: int = SR) -> int:
	return AudioDsp.samples(seconds, rate)


# ---------------------------------------------------------------------------
# Bus
# ---------------------------------------------------------------------------

func _build_bus_layout() -> void:
	AudioBuses.configure_server()
	var layout: AudioBusLayout = AudioServer.generate_bus_layout()
	var err: Error = ResourceSaver.save(layout, AudioBuses.DEFAULT_LAYOUT_PATH)
	if err != OK:
		push_error("build_audio: default_bus_layout.tres non écrit (%s)" % error_string(err))
	written += 1


# ---------------------------------------------------------------------------
# Briques de synthèse
# ---------------------------------------------------------------------------

## Éclaboussure : bruit passe-bande + gouttelettes.
func splash(rng: RandomNumberGenerator, seconds: float, center: float, drops: int) -> PackedFloat32Array:
	var n: int = n_of(seconds)
	var noise: PackedFloat32Array = AudioDsp.filter(AudioDsp.white(n, rng), AudioDsp.Filter.BANDPASS, center, 0.9, SR)
	var buf: PackedFloat32Array = AudioDsp.mul(noise, AudioDsp.env_ad(n, 0.002, seconds * 0.25, SR))
	for d: int in drops:
		var ping: PackedFloat32Array = AudioDsp.ping(rng.randf_range(1800.0, 4200.0), 0.03, 0.006, SR)
		buf = AudioDsp.mix_into(buf, ping, n_of(rng.randf_range(0.005, seconds * 0.7)), rng.randf_range(0.15, 0.35))
	return buf


## Souffle (bruit formé) : `shape` = [[durée, gain début, gain fin, centre Hz]…].
func breath(rng: RandomNumberGenerator, shape: Array) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	for part: Array in shape:
		var dur: float = part[0]
		var g0: float = part[1]
		var g1: float = part[2]
		var center: float = part[3]
		var n: int = n_of(dur)
		var noise: PackedFloat32Array = AudioDsp.filter(AudioDsp.white(n, rng), AudioDsp.Filter.BANDPASS, center, 0.8, SR)
		noise = AudioDsp.filter(noise, AudioDsp.Filter.LOWPASS, center * 2.2, 0.7, SR)
		var env: PackedFloat32Array = AudioDsp.silence(n)
		for i: int in n:
			var t: float = float(i) / maxf(n - 1, 1)
			env[i] = lerpf(g0, g1, t) * sin(PI * minf(t * 4.0, 1.0) * 0.5)
		out.append_array(AudioDsp.mul(noise, env))
	return AudioDsp.fade(out, 0.02, 0.08, SR)


## Note de cloche (partiels inharmoniques amortis).
func bell(freq: float, seconds: float, rate: int = SR, decay: float = 0.6) -> PackedFloat32Array:
	var buf: PackedFloat32Array = AudioDsp.ping(freq, seconds, decay, rate)
	buf = AudioDsp.mix_into(buf, AudioDsp.ping(freq * 2.0, seconds, decay * 0.5, rate), 0, 0.35)
	buf = AudioDsp.mix_into(buf, AudioDsp.ping(freq * 2.76, seconds, decay * 0.3, rate), 0, 0.18)
	buf = AudioDsp.mix_into(buf, AudioDsp.ping(freq * 5.4, seconds, decay * 0.12, rate), 0, 0.08)
	return AudioDsp.mul(buf, AudioDsp.env_ahr(buf.size(), 0.003, 0.05, rate))


## Motif « carillon Consortium » : 3 notes de cloche (Hz), écart en s.
func chime(notes: Array[float], spacing: float, rate: int = SR, decay: float = 0.6) -> PackedFloat32Array:
	var out: PackedFloat32Array = AudioDsp.silence(n_of(spacing * notes.size() + decay * 2.0, rate))
	for i: int in notes.size():
		out = AudioDsp.mix_into(out, bell(notes[i], decay * 2.0, rate, decay), n_of(spacing * i, rate), 1.0 - 0.1 * i)
	return out


## Blip holographique (sinus glissant + 2e harmonique, enveloppe sèche).
func blip(f0: float, f1: float, seconds: float, harmonic: float = 0.2) -> PackedFloat32Array:
	var a: PackedFloat32Array = AudioDsp.chirp(f0, f1, seconds, SR)
	a = AudioDsp.mix_into(a, AudioDsp.chirp(f0 * 2.0, f1 * 2.0, seconds, SR), 0, harmonic)
	return AudioDsp.mul(a, AudioDsp.env_ad(a.size(), 0.004, seconds * 0.35, SR))


## Crépitement : impulsions éparses filtrées.
func crackle(rng: RandomNumberGenerator, seconds: float, density: float, center: float) -> PackedFloat32Array:
	var n: int = n_of(seconds)
	var buf: PackedFloat32Array = AudioDsp.silence(n)
	for i: int in n:
		if rng.randf() < density / SR:
			buf[i] = rng.randf_range(-1.0, 1.0)
	return AudioDsp.filter(buf, AudioDsp.Filter.BANDPASS, center, 0.7, SR)


# ---------------------------------------------------------------------------
# Passager
# ---------------------------------------------------------------------------

func _build_passenger() -> void:
	for i: int in 8:
		var rng: RandomNumberGenerator = rng_for("step", i)
		var step: PackedFloat32Array = kenney("impact-sounds", "footstep_concrete_%03d" % (i % 5))
		step = AudioDsp.resample(step, rng.randf_range(0.92, 1.08))
		step = AudioDsp.filter(step, AudioDsp.Filter.HIGHPASS, 110.0, 0.7, SR)
		var metal: PackedFloat32Array = AudioDsp.resample(kenney("impact-sounds", "impactMetal_light_%03d" % ((i + 2) % 5)), rng.randf_range(1.2, 1.5))
		metal = AudioDsp.filter(metal, AudioDsp.Filter.LOWPASS, 2500.0, 0.7, SR)
		var buf: PackedFloat32Array = AudioDsp.gain(step, 1.0 / maxf(AudioDsp.peak(step), 0.001))
		buf = AudioDsp.mix_into(buf, AudioDsp.gain(metal, 1.0 / maxf(AudioDsp.peak(metal), 0.001)), 0, 0.22)
		buf = AudioDsp.mix_into(buf, splash(rng, 0.14, rng.randf_range(2600.0, 4200.0), rng.randi_range(2, 5)), n_of(0.004), 0.55)
		save("sfx/passenger/sfx_passenger_step_metal_wet_%02d.wav" % (i + 1), buf, -3.0)
	for i: int in 3:
		var rng: RandomNumberGenerator = rng_for("step_stop", i)
		var a: PackedFloat32Array = kenney("impact-sounds", "footstep_concrete_%03d" % i)
		var b: PackedFloat32Array = AudioDsp.resample(kenney("impact-sounds", "footstep_concrete_%03d" % (i + 2)), 0.9)
		var buf: PackedFloat32Array = AudioDsp.mix_into(a, b, n_of(0.09), 0.8)
		buf = AudioDsp.mix_into(buf, splash(rng, 0.25, 3000.0, 6), n_of(0.01), 0.9 * AudioDsp.peak(a))
		save("sfx/passenger/sfx_passenger_step_stop_%02d.wav" % (i + 1), buf, -3.0)
	for i: int in 4:
		var rng: RandomNumberGenerator = rng_for("breath_idle", i)
		var c: float = rng.randf_range(900.0, 1300.0)
		save("sfx/passenger/sfx_passenger_breath_idle_%02d.wav" % (i + 1),
				breath(rng, [[rng.randf_range(0.5, 0.7), 0.2, 0.7, c * 1.2], [0.12, 0.05, 0.05, c], [rng.randf_range(0.7, 0.9), 0.8, 0.1, c * 0.85]]), -8.0)
	for i: int in 3:
		var rng: RandomNumberGenerator = rng_for("breath_sigh", i)
		save("sfx/passenger/sfx_passenger_breath_sigh_%02d.wav" % (i + 1),
				breath(rng, [[0.35, 0.3, 0.8, 1300.0], [1.1, 1.0, 0.05, rng.randf_range(700.0, 900.0)]]), -5.0)
	for i: int in 3:
		var rng: RandomNumberGenerator = rng_for("breath_nervous", i)
		var buf: PackedFloat32Array = breath(rng, [[0.22, 0.4, 1.0, 1600.0], [0.08, 0.1, 0.0, 1200.0]])
		var gulp: PackedFloat32Array = AudioDsp.mul(AudioDsp.chirp(320.0, 140.0, 0.09, SR), AudioDsp.env_ad(n_of(0.09), 0.005, 0.03, SR))
		buf = AudioDsp.mix_into(buf, gulp, n_of(0.36), 0.5)
		save("sfx/passenger/sfx_passenger_breath_nervous_%02d.wav" % (i + 1), buf, -6.0)
	for i: int in 4:
		var rng: RandomNumberGenerator = rng_for("cloth", i)
		var n: int = n_of(rng.randf_range(0.4, 0.6))
		var noise: PackedFloat32Array = AudioDsp.filter(AudioDsp.white(n, rng), AudioDsp.Filter.BANDPASS, rng.randf_range(1400.0, 2400.0), 0.6, SR)
		var am: PackedFloat32Array = AudioDsp.one_pole(AudioDsp.white(n, rng), 18.0, SR)
		var env: PackedFloat32Array = AudioDsp.env_ahr(n, 0.05, 0.2, SR)
		for k: int in n:
			env[k] *= 0.4 + absf(am[k]) * 12.0
		var buf: PackedFloat32Array = AudioDsp.mul(noise, env)
		buf = AudioDsp.mix_into(buf, crackle(rng, n / float(SR), 60.0, 3500.0), 0, 0.6)
		save("sfx/passenger/sfx_passenger_cloth_rustle_%02d.wav" % (i + 1), buf, -8.0)
	for i: int in 4:
		var rng: RandomNumberGenerator = rng_for("paper", i)
		var n: int = n_of(rng.randf_range(0.35, 0.5))
		var slide: PackedFloat32Array = AudioDsp.sweep(AudioDsp.white(n, rng), AudioDsp.Filter.BANDPASS, 1800.0, 3800.0, 0.8, SR)
		slide = AudioDsp.mul(slide, AudioDsp.env_ahr(n, 0.04, 0.12, SR))
		var buf: PackedFloat32Array = AudioDsp.mix_into(AudioDsp.gain(slide, 0.5), crackle(rng, n / float(SR), 140.0, 4200.0), 0, 1.2)
		save("sfx/passenger/sfx_passenger_paper_rustle_%02d.wav" % (i + 1), buf, -6.0)
	for i: int in 3:
		var rng: RandomNumberGenerator = rng_for("knock", i)
		var hit: PackedFloat32Array = AudioDsp.filter(kenney("impact-sounds", "impactGlass_heavy_%03d" % i), AudioDsp.Filter.LOWPASS, 1500.0, 0.7, SR)
		hit = AudioDsp.mix_into(hit, AudioDsp.filter(kenney("impact-sounds", "impactSoft_heavy_%03d" % i), AudioDsp.Filter.LOWPASS, 600.0, 0.7, SR), 0, 0.8)
		var buf: PackedFloat32Array = AudioDsp.mix_into(hit.duplicate(), hit, n_of(rng.randf_range(0.16, 0.22)), 0.75)
		save("sfx/passenger/sfx_passenger_knock_glass_%02d.wav" % (i + 1), buf, -3.0)


# ---------------------------------------------------------------------------
# Guichet
# ---------------------------------------------------------------------------

## Remontée du tampon (`booth.stamp_lift`) : frottement court + ressort qui
## se détend (partiels métalliques, glissando montant). Synthèse pure.
func _build_stamp_lift() -> void:
	for i: int in 2:
		var rng: RandomNumberGenerator = rng_for("stamp_lift", i)
		var n: int = n_of(0.26)
		var rub_n: int = n_of(0.05)
		var rub: PackedFloat32Array = AudioDsp.filter(AudioDsp.white(rub_n, rng), AudioDsp.Filter.BANDPASS, 2600.0 + 300.0 * i, 0.9, SR)
		rub = AudioDsp.mul(rub, AudioDsp.env_ad(rub_n, 0.004, 0.03, SR))
		var spring: PackedFloat32Array = AudioDsp.chirp(320.0 + 30.0 * i, 560.0 + 40.0 * i, 0.09, SR)
		spring = AudioDsp.mul(spring, AudioDsp.env_ad(spring.size(), 0.004, 0.06, SR))
		var buf: PackedFloat32Array = AudioDsp.silence(n)
		buf = AudioDsp.mix_into(buf, rub, 0, 0.6)
		buf = AudioDsp.mix_into(buf, spring, n_of(0.01), 0.5)
		var base: float = 1450.0 * rng.randf_range(0.97, 1.03)
		buf = AudioDsp.mix_into(buf, AudioDsp.ping(base, 0.2, 0.05, SR), n_of(0.02), 0.25)
		buf = AudioDsp.mix_into(buf, AudioDsp.ping(base * 2.76, 0.12, 0.025, SR), n_of(0.02), 0.12)
		save("sfx/booth/sfx_booth_stamp_lift_%02d.wav" % (i + 1), buf, -6.0)


func _build_booth() -> void:
	for i: int in 4:
		var rng: RandomNumberGenerator = rng_for("slot", i)
		var flap: PackedFloat32Array = AudioDsp.resample(kenney("impact-sounds", "impactMetal_light_%03d" % i), rng.randf_range(0.95, 1.1))
		var n: int = n_of(0.28)
		var slide: PackedFloat32Array = AudioDsp.sweep(AudioDsp.white(n, rng), AudioDsp.Filter.BANDPASS, 2600.0, 900.0, 1.1, SR)
		slide = AudioDsp.mul(slide, AudioDsp.env_ahr(n, 0.03, 0.08, SR))
		var click: PackedFloat32Array = AudioDsp.gain(AudioDsp.resample(kenney("interface-sounds", "click_%03d" % (i % 5 + 1)), 0.8), 0.6)
		var fp: float = maxf(AudioDsp.peak(flap), 0.001)
		var buf_in: PackedFloat32Array = AudioDsp.gain(flap, 1.0 / fp)
		buf_in = AudioDsp.mix_into(buf_in, AudioDsp.gain(slide, 1.6), n_of(0.03), 1.0)
		buf_in = AudioDsp.mix_into(buf_in, click, n_of(0.3), 0.5)
		save("sfx/booth/sfx_booth_slot_in_%02d.wav" % (i + 1), buf_in, -4.0)
		var slide_out: PackedFloat32Array = AudioDsp.reverse(slide)
		var buf_out: PackedFloat32Array = AudioDsp.gain(slide_out, 1.6)
		buf_out = AudioDsp.mix_into(buf_out, AudioDsp.gain(flap, 1.0 / fp), n_of(0.26), 1.0)
		save("sfx/booth/sfx_booth_slot_out_%02d.wav" % (i + 1), buf_out, -5.0)
	for i: int in 3:
		var rng: RandomNumberGenerator = rng_for("holo_on", i)
		var n: int = n_of(0.32)
		var swell: PackedFloat32Array = AudioDsp.sweep(AudioDsp.white(n, rng), AudioDsp.Filter.LOWPASS, 300.0, 6000.0 + 600.0 * i, 0.9, SR)
		var tone: PackedFloat32Array = AudioDsp.chirp(220.0 * (1.0 + 0.03 * i), 880.0 * (1.0 + 0.03 * i), 0.32, SR)
		var env: PackedFloat32Array = AudioDsp.silence(n)
		for k: int in n:
			var t: float = float(k) / n
			env[k] = pow(t, 1.5) * (1.0 - smoothstep(0.85, 1.0, t))
		var buf: PackedFloat32Array = AudioDsp.mul(AudioDsp.mix_into(AudioDsp.gain(swell, 0.5), tone, 0, 0.35), env)
		buf = AudioDsp.mix_into(buf, crackle(rng, 0.32, 240.0, 5000.0), 0, 0.5)
		save("sfx/booth/sfx_booth_holo_on_%02d.wav" % (i + 1), buf, -8.0)
	for i: int in 2:
		var rng: RandomNumberGenerator = rng_for("holo_off", i)
		var n: int = n_of(0.16)
		var swell: PackedFloat32Array = AudioDsp.sweep(AudioDsp.white(n, rng), AudioDsp.Filter.LOWPASS, 5000.0, 250.0, 0.9, SR)
		var tone: PackedFloat32Array = AudioDsp.chirp(800.0 - 60.0 * i, 200.0, 0.16, SR)
		var buf: PackedFloat32Array = AudioDsp.mul(AudioDsp.mix_into(AudioDsp.gain(swell, 0.5), tone, 0, 0.3), AudioDsp.env_ad(n, 0.005, 0.06, SR))
		save("sfx/booth/sfx_booth_holo_off_%02d.wav" % (i + 1), buf, -10.0)
	# Bourdonnement holo (boucle 4 s).
	var hum_rng: RandomNumberGenerator = rng_for("holo_hum")
	var hn: int = n_of(4.0)
	var hum: PackedFloat32Array = AudioDsp.silence(hn)
	for k: int in hn:
		var t: float = float(k) / SR
		hum[k] = sin(TAU * 120.0 * t) * 0.5 + sin(TAU * 240.0 * t) * 0.25 + sin(TAU * 360.0 * t + 0.3) * 0.12 \
				+ sin(TAU * 1210.0 * t) * 0.04 * (0.5 + 0.5 * sin(TAU * 0.5 * t))
	hum = AudioDsp.mix_into(hum, AudioDsp.filter(AudioDsp.white(hn, hum_rng), AudioDsp.Filter.BANDPASS, 3000.0, 0.5, SR), 0, 0.05)
	save("sfx/booth/sfx_booth_holo_hum_loop.wav", hum, -6.0, SR, true)
	for i: int in 3:
		var rng: RandomNumberGenerator = rng_for("stamp_ok", i)
		var thud: PackedFloat32Array = AudioDsp.resample(kenney("impact-sounds", "impactPlate_heavy_%03d" % i), rng.randf_range(0.82, 0.9))
		thud = AudioDsp.gain(thud, 1.0 / maxf(AudioDsp.peak(thud), 0.001))
		var body: PackedFloat32Array = AudioDsp.filter(kenney("impact-sounds", "impactPunch_heavy_%03d" % i), AudioDsp.Filter.LOWPASS, 400.0, 0.8, SR)
		thud = AudioDsp.mix_into(thud, AudioDsp.gain(body, 1.0 / maxf(AudioDsp.peak(body), 0.001)), 0, 0.7)
		var click: PackedFloat32Array = AudioDsp.ping(3150.0 * rng.randf_range(0.98, 1.02), 0.12, 0.025, SR)
		click = AudioDsp.mix_into(click, AudioDsp.ping(4720.0, 0.1, 0.018, SR), 0, 0.6)
		click = AudioDsp.mix_into(click, AudioDsp.ping(6300.0, 0.08, 0.01, SR), 0, 0.3)
		var buf: PackedFloat32Array = AudioDsp.mix_into(thud, click, n_of(0.03), 0.45)
		save("sfx/booth/sfx_booth_stamp_approved_%02d.wav" % (i + 1), AudioDsp.saturate(buf, 1.3), -1.5)
	for i: int in 3:
		var rng: RandomNumberGenerator = rng_for("stamp_ko", i)
		var thud: PackedFloat32Array = AudioDsp.resample(kenney("impact-sounds", "impactPlate_heavy_%03d" % ((i + 1) % 5)), rng.randf_range(0.75, 0.82))
		thud = AudioDsp.gain(thud, 1.0 / maxf(AudioDsp.peak(thud), 0.001))
		var body: PackedFloat32Array = AudioDsp.filter(kenney("impact-sounds", "impactPunch_heavy_%03d" % ((i + 2) % 5)), AudioDsp.Filter.LOWPASS, 350.0, 0.8, SR)
		thud = AudioDsp.mix_into(thud, AudioDsp.gain(body, 1.0 / maxf(AudioDsp.peak(body), 0.001)), 0, 0.8)
		var buzz: PackedFloat32Array = AudioDsp.saw(62.0 + 3.0 * i, 0.2, SR)
		buzz = AudioDsp.mix_into(buzz, AudioDsp.saw(62.0 * 1.5, 0.2, SR, 0.3), 0, 0.4)
		buzz = AudioDsp.filter(buzz, AudioDsp.Filter.LOWPASS, 700.0, 0.9, SR)
		buzz = AudioDsp.mul(buzz, AudioDsp.env_ahr(buzz.size(), 0.01, 0.06, SR))
		var buf: PackedFloat32Array = AudioDsp.mix_into(thud, buzz, n_of(0.025), 0.5)
		save("sfx/booth/sfx_booth_stamp_denied_%02d.wav" % (i + 1), AudioDsp.saturate(buf, 1.3), -1.5)
	for i: int in 2:
		var rng: RandomNumberGenerator = rng_for("intercom", i)
		var sw: PackedFloat32Array = kenney("interface-sounds", "switch_%03d" % (i + 1))
		sw = AudioDsp.gain(sw, 1.0 / maxf(AudioDsp.peak(sw), 0.001))
		var st_n: int = n_of(0.09)
		var stat: PackedFloat32Array = AudioDsp.filter(AudioDsp.white(st_n, rng), AudioDsp.Filter.BANDPASS, 2200.0, 0.8, SR)
		stat = AudioDsp.mul(stat, AudioDsp.env_ad(st_n, 0.003, 0.03, SR))
		var on: PackedFloat32Array = AudioDsp.mix_into(sw.duplicate(), stat, n_of(0.02), 0.6)
		on = AudioDsp.mix_into(on, AudioDsp.ping(2800.0 + 150.0 * i, 0.1, 0.03, SR), n_of(0.04), 0.12)
		save("sfx/booth/sfx_booth_intercom_on_%02d.wav" % (i + 1), on, -9.0)
		var off: PackedFloat32Array = AudioDsp.mix_into(AudioDsp.gain(stat, 0.6), sw, n_of(0.03), 1.0)
		save("sfx/booth/sfx_booth_intercom_off_%02d.wav" % (i + 1), off, -10.0)
	for i: int in 2:
		var rng: RandomNumberGenerator = rng_for("printer", i)
		var n: int = n_of(1.2)
		var buf: PackedFloat32Array = AudioDsp.silence(n)
		var rate_hz: float = 140.0 + 15.0 * i
		var step: int = int(SR / rate_hz)
		var k: int = n_of(0.05)
		while k < n - n_of(0.08):
			buf[k] = rng.randf_range(0.6, 1.0)
			k += step
		buf = AudioDsp.filter(buf, AudioDsp.Filter.BANDPASS, 1800.0, 1.4, SR)
		var feed: PackedFloat32Array = AudioDsp.filter(AudioDsp.white(n, rng), AudioDsp.Filter.HIGHPASS, 3500.0, 0.7, SR)
		buf = AudioDsp.mix_into(buf, AudioDsp.gain(feed, 0.08), 0, 1.0)
		var motor: PackedFloat32Array = AudioDsp.filter(AudioDsp.saw(rate_hz * 2.0, 1.2, SR), AudioDsp.Filter.LOWPASS, 900.0, 0.7, SR)
		buf = AudioDsp.mix_into(buf, motor, 0, 0.06)
		var env: PackedFloat32Array = AudioDsp.env_ahr(n, 0.04, 0.08, SR)
		for j: int in n:
			env[j] *= 0.75 + 0.25 * sin(TAU * 7.0 * j / SR)
		save("sfx/booth/sfx_booth_printer_citation_%02d.wav" % (i + 1), AudioDsp.mul(buf, env), -6.0)


# ---------------------------------------------------------------------------
# Station
# ---------------------------------------------------------------------------

func _build_station() -> void:
	for i: int in 2:
		var rng: RandomNumberGenerator = rng_for("door", i)
		var open: PackedFloat32Array = kenney("sci-fi-sounds", "doorOpen_%03d" % (i + 1))
		var hn: int = n_of(0.6)
		var hiss: PackedFloat32Array = AudioDsp.filter(AudioDsp.white(hn, rng), AudioDsp.Filter.HIGHPASS, 2500.0, 0.7, SR)
		hiss = AudioDsp.mul(hiss, AudioDsp.env_ad(hn, 0.01, 0.18, SR))
		open = AudioDsp.gain(open, 1.0 / maxf(AudioDsp.peak(open), 0.001))
		open = AudioDsp.mix_into(open, hiss, 0, 0.35)
		save("sfx/station/sfx_station_door_open_%02d.wav" % (i + 1), AudioDsp.filter(open, AudioDsp.Filter.LOWPASS, 3500.0, 0.7, SR), -4.0)
		var close: PackedFloat32Array = kenney("sci-fi-sounds", "doorClose_%03d" % (i + 1))
		close = AudioDsp.gain(close, 1.0 / maxf(AudioDsp.peak(close), 0.001))
		var thud: PackedFloat32Array = AudioDsp.filter(kenney("impact-sounds", "impactMetal_heavy_%03d" % i), AudioDsp.Filter.LOWPASS, 900.0, 0.7, SR)
		close = AudioDsp.mix_into(close, AudioDsp.gain(thud, 0.7 / maxf(AudioDsp.peak(thud), 0.001)), maxi(close.size() - n_of(0.25), 0), 1.0)
		save("sfx/station/sfx_station_door_close_%02d.wav" % (i + 1), AudioDsp.filter(close, AudioDsp.Filter.LOWPASS, 3500.0, 0.7, SR), -4.0)
	for i: int in 4:
		var rng: RandomNumberGenerator = rng_for("queue_adv", i)
		var buf: PackedFloat32Array = AudioDsp.silence(n_of(1.2))
		var steps: int = rng.randi_range(2, 4)
		for s: int in steps:
			var st: PackedFloat32Array = kenney("impact-sounds", "footstep_concrete_%03d" % ((i + s) % 5))
			buf = AudioDsp.mix_into(buf, AudioDsp.resample(st, rng.randf_range(0.85, 1.0)), n_of(0.05 + s * rng.randf_range(0.22, 0.32)), rng.randf_range(0.6, 1.0))
		buf = AudioDsp.filter(buf, AudioDsp.Filter.LOWPASS, 1100.0, 0.7, SR)
		save("ambience/amb_queue_advance_%02d.wav" % (i + 1), buf, -6.0)


# ---------------------------------------------------------------------------
# UI (DS §9)
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var tick: PackedFloat32Array = AudioDsp.mix_into(AudioDsp.ping(2900.0, 0.03, 0.004, SR), AudioDsp.ping(4300.0, 0.03, 0.002, SR), 0, 0.4)
	save("ui/ui_hover_01.wav", tick, -6.0)
	save("ui/ui_field_select_a_01.wav", blip(660.0, 880.0, 0.09), -4.0)
	save("ui/ui_field_select_b_01.wav", blip(990.0, 1320.0, 0.09), -4.0) # + une quinte
	var match_buf: PackedFloat32Array = blip(587.3, 587.3, 0.09, 0.1)
	match_buf = AudioDsp.mix_into(match_buf, blip(440.0, 440.0, 0.16, 0.1), n_of(0.08), 1.0)
	save("ui/ui_match_01.wav", match_buf, -5.0)
	for i: int in 2:
		var base: float = 659.3 if i == 0 else 622.3
		var a: PackedFloat32Array = AudioDsp.saw(base, 0.28, SR)
		a = AudioDsp.mix_into(a, AudioDsp.saw(base * 1.0595, 0.28, SR, 0.4), 0, 1.0) # seconde mineure
		a = AudioDsp.filter(a, AudioDsp.Filter.LOWPASS, 2400.0, 1.2, SR)
		a = AudioDsp.mix_into(a, AudioDsp.ping(base * 4.0, 0.05, 0.01, SR), 0, 0.3)
		save("ui/ui_discrepancy_%02d.wav" % (i + 1), AudioDsp.mul(a, AudioDsp.env_ad(a.size(), 0.003, 0.1, SR)), -3.0)
	save("ui/ui_incomparable_01.wav", blip(392.0, 330.0, 0.12, 0.05), -7.0)
	# Carillon Consortium (3 notes, signature « jaune ») et variante mineure.
	save("ui/ui_rule_new_01.wav", chime([659.3, 523.3, 784.0], 0.26), -3.0)
	save("ui/ui_citation_chime_01.wav", chime([659.3, 523.3, 622.3], 0.3, SR, 0.5), -4.0)
	var warn: PackedFloat32Array = AudioDsp.filter(AudioDsp.saw(1000.0, 0.16, SR), AudioDsp.Filter.LOWPASS, 2600.0, 0.8, SR)
	warn = AudioDsp.mix_into(warn, AudioDsp.chirp(1000.0, 1000.0, 0.16, SR), 0, 0.8)
	save("ui/ui_timer_warning_01.wav", AudioDsp.mul(warn, AudioDsp.env_ahr(warn.size(), 0.004, 0.03, SR)), -4.0)
	var crit: PackedFloat32Array = AudioDsp.mix_into(AudioDsp.ping(1800.0, 0.05, 0.01, SR), AudioDsp.ping(3600.0, 0.03, 0.004, SR), 0, 0.3)
	save("ui/ui_timer_critical_tick_01.wav", crit, -5.0)
	var rng: RandomNumberGenerator = rng_for("scanner")
	var on_n: int = n_of(0.2)
	var scan: PackedFloat32Array = AudioDsp.sweep(AudioDsp.white(on_n, rng), AudioDsp.Filter.BANDPASS, 600.0, 4800.0, 2.0, SR)
	scan = AudioDsp.mix_into(AudioDsp.gain(scan, 0.6), AudioDsp.chirp(300.0, 1200.0, 0.2, SR), 0, 0.4)
	scan = AudioDsp.mul(scan, AudioDsp.env_ahr(on_n, 0.01, 0.06, SR))
	save("ui/ui_inspect_mode_on_01.wav", scan, -7.0)
	save("ui/ui_inspect_mode_off_01.wav", AudioDsp.mul(AudioDsp.reverse(scan), AudioDsp.env_ahr(on_n, 0.005, 0.08, SR)), -9.0)
	# Tampon maintenu : servo qui se tend (0,4 s, DS.STAMP_HOLD).
	var hold_n: int = n_of(0.42)
	var servo: PackedFloat32Array = AudioDsp.silence(hold_n)
	var phase: float = 0.0
	for k: int in hold_n:
		var t: float = float(k) / hold_n
		phase = fposmod(phase + lerpf(170.0, 330.0, t * t) / SR, 1.0)
		servo[k] = (phase * 2.0 - 1.0) * (0.3 + 0.7 * t)
	servo = AudioDsp.filter(servo, AudioDsp.Filter.LOWPASS, 1400.0, 1.0, SR)
	for c: int in 5:
		servo = AudioDsp.mix_into(servo, AudioDsp.ping(2400.0 + 200.0 * c, 0.02, 0.003, SR), n_of(0.06 + c * 0.075), 0.35)
	save("ui/ui_stamp_hold_01.wav", AudioDsp.mul(servo, AudioDsp.env_ahr(hold_n, 0.02, 0.02, SR)), -8.0)
	save("ui/ui_toast_info_01.wav", blip(880.0, 880.0, 0.08, 0.1), -8.0)
	save("ui/ui_toast_success_01.wav", AudioDsp.mix_into(blip(784.0, 784.0, 0.07), blip(1047.0, 1047.0, 0.1), n_of(0.06), 1.0), -7.0)
	save("ui/ui_toast_error_01.wav", AudioDsp.mix_into(blip(523.0, 523.0, 0.07), blip(392.0, 392.0, 0.12), n_of(0.06), 1.0), -7.0)


# ---------------------------------------------------------------------------
# Annonces PA (Consortium) : carillon + voix Tessar lointaine
# ---------------------------------------------------------------------------

func _build_pa() -> void:
	var phrases: Array[String] = ["vesh ota lumi", "tal ka nesu, somi ravel ota", "oru ka, shen tavi, vesh ota lumi"]
	for i: int in phrases.size():
		var p: Passenger = Passenger.new()
		p.sex = Passenger.SEX_F if i != 1 else Passenger.SEX_M
		p.appearance_seed = 9100 + i
		var prof: TessarVoice.Profile = TessarVoice.profile_for(p)
		prof.jitter = 0.003
		prof.breath = 0.03
		var voice: PackedFloat32Array = TessarVoice.synthesize(phrases[i], prof, TessarVoice.MOOD_PA)
		voice = AudioDsp.resample(voice, float(TessarVoice.SAMPLE_RATE) / SR)
		voice = AudioDsp.filter(voice, AudioDsp.Filter.BANDPASS, 1500.0, 0.6, SR) # haut-parleur
		voice = AudioDsp.saturate(voice, 2.0)
		var buf: PackedFloat32Array = chime([659.3, 523.3, 784.0], 0.3, SR, 0.5)
		buf = AudioDsp.gain(buf, 0.6)
		buf = AudioDsp.mix_into(buf, voice, n_of(1.3), 0.8)
		buf = AudioDsp.space(buf, SR, 0.5, 2.2)
		save("voice/pa/vo_pa_announce_%02d.wav" % (i + 1), AudioDsp.filter(buf, AudioDsp.Filter.LOWPASS, 3200.0, 0.7, SR), -3.0)


# ---------------------------------------------------------------------------
# Ambiances (boucles stéréo 24 kHz → OGG)
# ---------------------------------------------------------------------------

func _build_ambience() -> void:
	var sr: int = LOOP_SR
	# Pluie sur vitre : grésillement rose large + ruissellement + gouttelettes.
	var seconds: float = 26.0
	var lr: Array[PackedFloat32Array] = []
	for ch: int in 2:
		var rng: RandomNumberGenerator = rng_for("rain", ch)
		var n: int = AudioDsp.samples(seconds, sr)
		var hiss: PackedFloat32Array = AudioDsp.filter(AudioDsp.pink(n, rng), AudioDsp.Filter.HIGHPASS, 500.0, 0.7, sr)
		hiss = AudioDsp.filter(hiss, AudioDsp.Filter.LOWPASS, 9000.0, 0.7, sr)
		var trickle: PackedFloat32Array = AudioDsp.filter(AudioDsp.white(n, rng), AudioDsp.Filter.BANDPASS, 900.0, 3.0, sr)
		var slow: PackedFloat32Array = AudioDsp.one_pole(AudioDsp.white(n, rng), 1.5, sr)
		for k: int in n:
			trickle[k] *= 0.4 + absf(slow[k]) * 30.0
		var buf: PackedFloat32Array = AudioDsp.mix_into(AudioDsp.gain(hiss, 1.0), trickle, 0, 0.12)
		var drops: int = int(seconds * 45.0)
		for d: int in drops:
			var f: float = rng.randf_range(1800.0, 5500.0)
			var ping: PackedFloat32Array = AudioDsp.ping(f, 0.02, rng.randf_range(0.002, 0.006), sr)
			buf = AudioDsp.mix_into(buf, ping, rng.randi_range(0, n - ping.size() - 1), rng.randf_range(0.02, 0.12))
		lr.append(AudioDsp.make_loop(buf, 1.5, sr))
	save_loop("amb_rain_glass_loop", lr[0], lr[1], -12.0)
	# Gouttes lourdes (one-shots mono 48 kHz).
	for i: int in 4:
		var rng: RandomNumberGenerator = rng_for("heavy_drop", i)
		var f: float = rng.randf_range(1000.0, 1700.0)
		var drop: PackedFloat32Array = AudioDsp.chirp(f * 1.3, f, 0.05, SR)
		drop = AudioDsp.mul(drop, AudioDsp.env_ad(drop.size(), 0.001, 0.012, SR))
		drop = AudioDsp.mix_into(drop, splash(rng, 0.09, 3200.0, 3), n_of(0.004), 0.4)
		save("ambience/amb_rain_drop_heavy_%02d.wav" % (i + 1), drop, -6.0)
	# Néon : 50/100 Hz + harmoniques saturées + crépitements.
	var neon_n: int = AudioDsp.samples(8.0, sr)
	var neon_rng: RandomNumberGenerator = rng_for("neon")
	var neon: PackedFloat32Array = AudioDsp.silence(neon_n)
	for k: int in neon_n:
		var t: float = float(k) / sr
		neon[k] = sin(TAU * 100.0 * t) * 0.6 + sin(TAU * 50.0 * t) * 0.3 + sin(TAU * 200.0 * t) * 0.15
	neon = AudioDsp.saturate(neon, 2.5)
	neon = AudioDsp.filter(neon, AudioDsp.Filter.LOWPASS, 2000.0, 0.7, sr)
	var neon_crackle: PackedFloat32Array = AudioDsp.silence(neon_n)
	for k: int in neon_n:
		if neon_rng.randf() < 6.0 / sr:
			var burst: int = AudioDsp.samples(neon_rng.randf_range(0.01, 0.06), sr)
			for b: int in burst:
				if k + b < neon_n and neon_rng.randf() < 0.3:
					neon_crackle[k + b] = neon_rng.randf_range(-1.0, 1.0)
	neon = AudioDsp.mix_into(neon, AudioDsp.filter(neon_crackle, AudioDsp.Filter.HIGHPASS, 2000.0, 0.7, sr), 0, 0.25)
	neon = AudioDsp.make_loop(neon, 0.5, sr)
	save_loop("amb_neon_hum_loop", neon, neon, -14.0)
	# Lit de station : grondement, ventilation, chocs métalliques lointains.
	var bed: Array[PackedFloat32Array] = []
	for ch: int in 2:
		var rng: RandomNumberGenerator = rng_for("station", ch)
		var n: int = AudioDsp.samples(32.0, sr)
		var rumble: PackedFloat32Array = AudioDsp.filter(AudioDsp.brown(n, rng), AudioDsp.Filter.LOWPASS, 180.0, 0.7, sr)
		var vent: PackedFloat32Array = AudioDsp.filter(AudioDsp.pink(n, rng), AudioDsp.Filter.BANDPASS, 450.0, 0.6, sr)
		var slow: PackedFloat32Array = AudioDsp.one_pole(AudioDsp.white(n, rng), 0.3, sr)
		for k: int in n:
			vent[k] *= 0.7 + slow[k] * 40.0
		var buf: PackedFloat32Array = AudioDsp.mix_into(AudioDsp.gain(rumble, 1.5), vent, 0, 0.5)
		for c: int in 3:
			var clunk: PackedFloat32Array = AudioDsp.resample(kenney("impact-sounds", "impactMetal_heavy_%03d" % ((c + ch) % 5)), float(SR) / sr * 0.7)
			clunk = AudioDsp.filter(clunk, AudioDsp.Filter.LOWPASS, 700.0, 0.7, sr)
			clunk = AudioDsp.space(clunk, sr, 0.8, 3.0, 7.0 * ch)
			buf = AudioDsp.mix_into(buf, clunk, AudioDsp.samples(3.0 + c * 9.5 + ch * 0.07, sr), 0.08 * AudioDsp.peak(rumble) / maxf(AudioDsp.peak(clunk), 0.001) * 6.0)
		bed.append(AudioDsp.make_loop(buf, 2.0, sr))
	save_loop("amb_station_bed_loop", bed[0], bed[1], -10.0)
	# Murmure de la file : voix Tessar superposées, lointaines.
	var mur: Array[PackedFloat32Array] = []
	var mn: int = AudioDsp.samples(22.0, sr)
	mur.append(AudioDsp.silence(mn))
	mur.append(AudioDsp.silence(mn))
	var mrng: RandomNumberGenerator = rng_for("murmur")
	for v: int in 18:
		var p: Passenger = Passenger.new()
		p.sex = [Passenger.SEX_F, Passenger.SEX_M, Passenger.SEX_X][v % 3]
		p.appearance_seed = 500 + v
		var phrase: String = TessarVoice.phrase_for("murmur_%d" % v, "Une phrase quelconque, dans la file.")
		var voice: PackedFloat32Array = TessarVoice.synthesize(phrase, TessarVoice.profile_for(p))
		voice = AudioDsp.resample(voice, float(TessarVoice.SAMPLE_RATE) / sr)
		voice = AudioDsp.filter(voice, AudioDsp.Filter.LOWPASS, 1400.0, 0.7, sr)
		var at: int = mrng.randi_range(0, mn - voice.size() - 1)
		var pan: float = mrng.randf()
		var g: float = mrng.randf_range(0.15, 0.4)
		mur[0] = AudioDsp.mix_into(mur[0], voice, at, g * (1.0 - pan * 0.7))
		mur[1] = AudioDsp.mix_into(mur[1], voice, at, g * (0.3 + pan * 0.7))
	for c: int in 3:
		var cn: int = n_of(0.25, sr)
		var cough: PackedFloat32Array = AudioDsp.filter(AudioDsp.white(cn, mrng), AudioDsp.Filter.BANDPASS, 700.0, 1.0, sr)
		cough = AudioDsp.mul(cough, AudioDsp.env_ad(cn, 0.01, 0.05, sr))
		var at_c: int = AudioDsp.samples(4.0 + c * 6.5, sr)
		mur[c % 2] = AudioDsp.mix_into(mur[c % 2], cough, at_c, 0.3)
		mur[c % 2] = AudioDsp.mix_into(mur[c % 2], cough, at_c + AudioDsp.samples(0.3, sr), 0.2)
	for ch: int in 2:
		mur[ch] = AudioDsp.make_loop(AudioDsp.space(mur[ch], sr, 0.6, 2.5, 5.0 * ch), 1.5, sr)
	save_loop("amb_queue_murmur_loop", mur[0], mur[1], -12.0)


# ---------------------------------------------------------------------------
# Musique (boucles stéréo 24 kHz → OGG) — 80 BPM, mesure 3 s
# ---------------------------------------------------------------------------

const BEAT: float = 0.75
const BAR: float = 3.0
const BARS: int = 8

const NOTE: Dictionary[String, float] = {
	"E2": 82.41, "F2": 87.31, "G2": 98.0, "A2": 110.0, "B2": 123.47, "C3": 130.81, "D3": 146.83, "E3": 164.81,
	"F3": 174.61, "G3": 196.0, "A3": 220.0, "B3": 246.94, "C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23,
	"G4": 392.0, "A4": 440.0, "C5": 523.25, "E5": 659.26, "G5": 784.0, "Eb5": 622.25,
}


func _build_music() -> void:
	var am: Array[String] = ["A2", "E3", "A3", "C4"]
	var f: Array[String] = ["F2", "C3", "F3", "A3"]
	var c: Array[String] = ["C3", "G3", "C4", "E4"]
	var g: Array[String] = ["G2", "D3", "G3", "B3"]
	var em: Array[String] = ["E2", "B2", "E3", "G3"]
	var dm: Array[String] = ["D3", "A3", "D4", "F4"]
	var e_maj: Array[String] = ["E2", "B2", "E3", "G4"]
	_music_track("mus_briefing_loop", [am, f, c, g], 1400.0, 0.9, 0.0, 0.0, true, -8.0)
	_music_track("mus_shift_calm_loop", [am, am, f, em], 750.0, 0.55, 0.35, 0.0, false, -8.0)
	_music_track("mus_shift_tension_loop", [am, f, am, em], 1500.0, 0.6, 0.6, 0.35, false, -7.0)
	_music_track("mus_debrief_loop", [f, c, g, c], 1600.0, 1.0, 0.0, 0.0, true, -8.0)
	_music_track("mus_debrief_minor_loop", [am, dm, am, e_maj], 1100.0, 1.0, 0.0, 0.0, false, -8.0)


## Boucle de 8 mesures : nappe (2 mesures par accord), basse pulsée en
## croches (`bass`), arpège + charleston (`tension`), motif Consortium.
func _music_track(name: String, chords: Array, cutoff: float, pad_gain: float, bass: float, tension: float,
		motif: bool, peak_db: float) -> void:
	var sr: int = LOOP_SR
	var length: int = AudioDsp.samples(BAR * BARS, sr)
	var tail: int = AudioDsp.samples(3.0, sr)
	var out: Array[PackedFloat32Array] = [AudioDsp.silence(length + tail), AudioDsp.silence(length + tail)]
	var rng: RandomNumberGenerator = rng_for(name)
	var chord_sec: float = BAR * BARS / chords.size()
	for ci: int in chords.size():
		var notes: Array = chords[ci]
		var start: int = AudioDsp.samples(ci * chord_sec, sr)
		for ch: int in 2:
			var pad: PackedFloat32Array = AudioDsp.silence(AudioDsp.samples(chord_sec + 2.0, sr))
			for note: String in notes:
				var hz: float = NOTE[note]
				var detune: float = 1.0 + (0.003 if ch == 0 else -0.003)
				var osc: PackedFloat32Array = AudioDsp.saw(hz * detune, chord_sec + 2.0, sr, rng.randf())
				osc = AudioDsp.mix_into(osc, AudioDsp.saw(hz / detune * 1.001, chord_sec + 2.0, sr, rng.randf()), 0, 0.8)
				pad = AudioDsp.mix_into(pad, osc, 0, 0.25)
			pad = AudioDsp.one_pole(AudioDsp.one_pole(pad, cutoff, sr), cutoff * 1.5, sr)
			pad = AudioDsp.mul(pad, AudioDsp.env_ahr(pad.size(), 1.2, 1.6, sr))
			out[ch] = AudioDsp.mix_into(out[ch], pad, start, pad_gain)
		if bass > 0.0:
			var bass_hz: float = NOTE[notes[0]]
			var eighths: int = int(chord_sec / (BEAT * 0.5))
			for e: int in eighths:
				var nb: int = AudioDsp.samples(0.3, sr)
				var tone: PackedFloat32Array = AudioDsp.saw(bass_hz, 0.3, sr)
				tone = AudioDsp.mix_into(tone, AudioDsp.chirp(bass_hz, bass_hz, 0.3, sr), 0, 1.2)
				tone = AudioDsp.one_pole(tone, 260.0 + 300.0 * tension, sr)
				tone = AudioDsp.mul(tone, AudioDsp.env_ad(nb, 0.005, 0.09, sr))
				var accent: float = 1.0 if e % 2 == 0 else 0.6
				for ch: int in 2:
					out[ch] = AudioDsp.mix_into(out[ch], tone, start + AudioDsp.samples(e * BEAT * 0.5, sr), bass * accent)
		if tension > 0.0:
			var sixteenths: int = int(chord_sec / (BEAT * 0.25))
			for s: int in sixteenths:
				var at: int = start + AudioDsp.samples(s * BEAT * 0.25, sr)
				var hn: int = AudioDsp.samples(0.05, sr)
				var hat: PackedFloat32Array = AudioDsp.filter(AudioDsp.white(hn, rng), AudioDsp.Filter.HIGHPASS, 7000.0, 0.7, sr)
				hat = AudioDsp.mul(hat, AudioDsp.env_ad(hn, 0.001, 0.012, sr))
				var hg: float = tension * (0.25 if s % 4 == 2 else 0.12)
				out[0] = AudioDsp.mix_into(out[0], hat, at, hg * 0.8)
				out[1] = AudioDsp.mix_into(out[1], hat, at, hg)
				var arp_note: float = NOTE[notes[[1, 2, 3, 2][s % 4]]] * 2.0
				var an: int = AudioDsp.samples(0.16, sr)
				var arp: PackedFloat32Array = AudioDsp.one_pole(AudioDsp.saw(arp_note, 0.16, sr), 1800.0, sr)
				arp = AudioDsp.mul(arp, AudioDsp.env_ad(an, 0.003, 0.05, sr))
				out[s % 2] = AudioDsp.mix_into(out[s % 2], arp, at, tension * 0.12)
	if motif:
		for bar_index: int in [0, 4]:
			var notes_hz: Array[float] = [NOTE["E5"], NOTE["C5"], NOTE["G5"]]
			var bell_buf: PackedFloat32Array = chime(notes_hz, BEAT, sr, 0.9)
			var at: int = AudioDsp.samples(bar_index * BAR + BEAT, sr)
			out[0] = AudioDsp.mix_into(out[0], bell_buf, at, 0.14)
			out[1] = AudioDsp.mix_into(out[1], bell_buf, at + AudioDsp.samples(0.012, sr), 0.12)
	for ch: int in 2:
		var spaced: PackedFloat32Array = AudioDsp.space(out[ch], sr, 0.45, 2.0, 6.0 * ch)
		# Repli de la queue sur le début : boucle sans coupure.
		var folded: PackedFloat32Array = AudioDsp.silence(length)
		for k: int in length:
			folded[k] = spaced[k]
		for k: int in mini(tail, spaced.size() - length):
			folded[k] += spaced[length + k]
		out[ch] = folded
	save_loop(name, out[0], out[1], peak_db)
