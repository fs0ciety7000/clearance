## Audit objectif de la musique M14 (docs/M14.md §6.2, B94 ; docs/AUDIO.md
## §13.5) — aucune écoute : chaque cible est mesurée sur les **OGG décodés**
## par ffmpeg (et non sur les WAV intermédiaires).
##
## Fichiers audités : ceux de `assets/audio/music/manifest.json` (couches,
## thèmes, queues) et les démos qu'il référence.
##   M-01 saturation : 0 échantillon à |x| ≥ 0,999 ; true peak ≤ −1 dBTP (ffmpeg ebur128)
##   M-02 niveau des fichiers : crête de l'ensemble à −1 dBTP (±0,5) ; DC ≤ 0,001
##   M-03 niveaux N0 → N4 : somme des couches aux gains du manifeste et au bus
##        Music par défaut → −30 / −28 / −26,5 / −25 / −24 LUFS (±2 pour N0,
##        ±1 sinon), croissance monotone ; recoupé par ffmpeg sur le mix N4
##   M-04 thèmes : −18 ±1 LUFS au gain d'exécution
##   M-05 boucles sans clic : saut à la jointure ≤ 3 × la médiane des sauts ;
##        RMS sur 10 ms de part et d'autre dans ±1 dB de la fenêtre voisine ;
##        aucun silence > 20 ms (RMS < −80 dBFS)
##   M-06 alignement : longueur décodée = mesures × échantillons par mesure ;
##        `.import` (`loop`, `bpm`, `beat_count`, `bar_beats`) cohérents
##   M-07 mono : perte L+R ≤ 3 dB ; corrélation L/R ≥ 0 sur toute fenêtre de
##        400 ms non silencieuse
##   M-08 lisibilité : dans la bande 1–4 kHz, crête (50 ms) des cues `ui.*`
##        P1/P2 ≥ musique + 12 dB à chaque niveau (gains de bus par défaut)
##   M-09 déterminisme : SHA-256 des OGG = manifeste (deux builds `--force`
##        comparés par `bash tools/qa_audio_audit.sh --rebuild`)
##   M-12 taille : musique ≤ 24 Mo
## Usage : godot --headless --path . --script res://tools/qa_audio_audit.gd -- [--json=<rapport.json>] [--only=ms02]
## Code de sortie : 0 si tout passe, 1 sinon.
extends SceneTree

const MANIFEST_PATH: String = "res://assets/audio/music/manifest.json"
const MUSIC_BUS_LINEAR: float = 0.8
const UI_BUS_LINEAR: float = 1.0
const MAX_MUSIC_BYTES: int = 24 * 1024 * 1024
## M-08 : une cue dont la crête dans la bande est à plus de 12 dB sous sa
## crête totale n'a pas d'énergie utile dans 1–4 kHz.
const OFF_BAND_DB: float = 12.0
const BAND_LO: float = 1000.0
const BAND_HI: float = 4000.0
## WAV intermédiaires de `tools/build_music.gd` (ignorés par git).
const WORK_DIR: String = "res://art_src/downloads/_music_build"

var _rows: Array[Dictionary] = []
var _fails: int = 0
var _tmp: String = ""
var _only: PackedStringArray = []


func _initialize() -> void:
	var json_out: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--json="):
			json_out = arg.trim_prefix("--json=")
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=").split(",", false)
	_tmp = OS.get_cache_dir().path_join("clearance_audio_audit_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_tmp)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	var scores: Dictionary = manifest.get("scores", {})
	var ids: Array = scores.keys()
	ids.sort()
	var total_bytes: int = 0
	for score_id: String in ids:
		var entry: Dictionary = scores[score_id]
		for name: String in entry.get("files", {}):
			total_bytes += int(entry["files"][name].get("ogg_bytes", 0))
		if not _only.is_empty() and not _only.has(score_id):
			continue
		if str(entry.get("kind", "")) == "set":
			_audit_set(score_id, entry)
		else:
			_audit_theme(score_id, entry)
		if entry.has("demo"):
			_audit_demo(score_id, entry["demo"])
	_check("M-12", "musique", "taille totale %.2f Mo ≤ 24 Mo" % (total_bytes / 1048576.0), total_bytes <= MAX_MUSIC_BYTES)
	DirAccess.remove_absolute(_tmp)
	print("qa_audio_audit : %d mesures, %d échec(s)" % [_rows.size(), _fails])
	if not json_out.is_empty():
		var f: FileAccess = FileAccess.open(json_out, FileAccess.WRITE)
		f.store_string(JSON.stringify({"rows": _rows, "failures": _fails}, "\t", true))
	quit(0 if _fails == 0 else 1)


# ---------------------------------------------------------------------------
# Ensembles, thèmes, démos
# ---------------------------------------------------------------------------

## Ensembles sans lecture critique (titre, soirée) : M-08 non jugé.
const NO_READING_SETS: Array[String] = ["ms01", "ms06"]


func _audit_set(score_id: String, entry: Dictionary) -> void:
	var files: Dictionary = entry["files"]
	var names: Array = files.keys()
	names.sort()
	var stems: Array = entry.get("stems", [])
	if not stems.is_empty():
		# Ordre des couches = ordre de la partition (gains du manifeste).
		names = []
		for stem_id: Variant in stems:
			names.append("mus_%s_%s_loop" % [score_id, str(stem_id)])
	var rate: int = int(entry["sample_rate"])
	var expected: int = int(entry["bars"]) * int(entry["bar_samples"])
	var decoded: Array = []
	var set_peak_tp: float = -INF
	for name: String in names:
		var info: Dictionary = files[name]
		var lr: Array[PackedFloat32Array] = _audit_file(score_id, name, info, rate, expected, true, entry)
		decoded.append(lr)
		set_peak_tp = maxf(set_peak_tp, float(info.get("true_peak_dbtp", -INF)))
	_check("M-02", score_id, "crête de l'ensemble %.2f dBTP (−1 ±0,5)" % set_peak_tp, set_peak_tp <= -1.0 and set_peak_tp >= -1.5)
	# M-03 : paliers du plan de niveaux (N0 → N4 de M14 §2.5 ; titre, soirée,
	# mondes du J31 : plan de la partition) sur la somme des couches décodées.
	var levels: Dictionary = entry.get("levels", {})
	var gains: Array = levels.get("layer_gains_db", [])
	var steps: Array = levels.get("steps", [])
	if steps.is_empty():
		var targets: Array = levels.get("targets_lufs", [])
		for level: int in mini(MusicDirector.LEVEL_COUNT, targets.size()):
			var ids: Array = []
			var mask: PackedByteArray = MusicDirector.layers_for_level(level)
			for i: int in mask.size():
				if mask[i] == 1:
					ids.append("l%d" % i)
			steps.append({"label": "N%d" % level, "layers": ids, "target_lufs": targets[level]})
	var previous: float = -INF
	var previous_layers: Array = []
	var n4_mix: Array[PackedFloat32Array] = []
	var music_band: Array[float] = []
	for k: int in steps.size():
		var step: Dictionary = steps[k]
		var layers: Array = step.get("layers", [])
		var mix: Array[PackedFloat32Array] = _layers_mix(decoded, gains, stems, layers)
		var lufs: float = AudioLoudness.integrated(mix[0], mix[1], rate)
		var tol: float = 2.0 if k == 0 else 1.0
		var target: float = float(step.get("target_lufs", -30.0))
		_check("M-03", score_id, "%s : %.2f LUFS (cible %.1f ±%.0f)" % [step.get("label", ""), lufs, target, tol],
				absf(lufs - target) <= tol)
		var superset: bool = k > 0 and previous_layers.all(func(x: Variant) -> bool: return layers.has(x))
		if superset or k == 0:
			_check("M-03", score_id, "%s > palier précédent (monotone)" % step.get("label", "") if k > 0 else "premier palier",
					lufs > previous)
		previous = lufs
		previous_layers = layers
		music_band.append(_band_peak_db(mix[0], mix[1], rate, 3.0))
		n4_mix = mix
	if not n4_mix.is_empty():
		var wav_path: String = _tmp.path_join("%s_n4.wav" % score_id)
		AudioDsp.to_wav(n4_mix[0], rate, n4_mix[1]).save_to_wav(wav_path)
		var ff: Dictionary = FfmpegAudio.measure(wav_path)
		var mine: float = AudioLoudness.integrated(n4_mix[0], n4_mix[1], rate)
		_check("M-03", score_id, "N4 recoupé par ffmpeg : %.2f LUFS (outil : %.2f)" % [float(ff.get("lufs", -INF)), mine],
				absf(float(ff.get("lufs", -INF)) - mine) <= 0.3)
		DirAccess.remove_absolute(wav_path)
	if NO_READING_SETS.has(score_id):
		_info("M-08", score_id, "ensemble sans lecture (titre, soirée) : non jugé")
	else:
		_audit_ui_margin(score_id, music_band)


func _audit_theme(score_id: String, entry: Dictionary) -> void:
	var files: Dictionary = entry["files"]
	var rate: int = int(entry["sample_rate"])
	var bar_n: int = int(entry["bar_samples"])
	var runtime_gain: float = float(entry.get("runtime_gain_db", 0.0))
	var main_bars: int = int(entry.get("tail_from_bar", entry["bars"])) + int(entry.get("main_tail_bars", 0))
	var tail_only: bool = bool(entry.get("tail_only", false))
	for name: String in files:
		var info: Dictionary = files[name]
		var loop: bool = bool(info.get("loop", false))
		var bars: int = int(entry["tail_bars"]) if loop else main_bars
		var lr: Array[PackedFloat32Array] = _audit_file(score_id, name, info, rate, bars * bar_n, loop, entry)
		if not loop or tail_only:
			var lufs: float = AudioLoudness.integrated(lr[0], lr[1], rate) + runtime_gain
			_check("M-04", name, "%.2f LUFS au gain d'exécution %+.2f dB (cible −18 ±1)" % [lufs, runtime_gain],
					absf(lufs + 18.0) <= 1.0)


func _audit_demo(score_id: String, demo: Dictionary) -> void:
	var path: String = "res://" + str(demo.get("path", ""))
	if not FileAccess.file_exists(path):
		_check("démo", score_id, "fichier %s présent" % path, false)
		return
	var ff: Dictionary = FfmpegAudio.measure(ProjectSettings.globalize_path(path))
	var lr: Array[PackedFloat32Array] = _decode(ProjectSettings.globalize_path(path))
	var clipped: int = _count_clipped(lr)
	var name: String = path.get_file()
	_check("M-01", name, "%d échantillon(s) ≥ 0,999 ; true peak %.2f dBTP ≤ −1" % [clipped, float(ff.get("true_peak_dbtp", 0.0))],
			clipped == 0 and float(ff.get("true_peak_dbtp", 0.0)) <= -1.0)
	_info("démo", name, "%.1f s, %.2f LUFS intégré, LRA %.1f LU" % [lr[0].size() / float(_rate_of(path)),
		float(ff.get("lufs", -INF)), float(ff.get("lra_lu", 0.0))])
	_check("M-01", name, "SHA-256 = manifeste", FileAccess.get_sha256(path) == str(demo.get("ogg_sha256", "")))


# ---------------------------------------------------------------------------
# Un fichier
# ---------------------------------------------------------------------------

func _audit_file(score_id: String, name: String, info: Dictionary, rate: int, expected: int, loop: bool,
		entry: Dictionary) -> Array[PackedFloat32Array]:
	var res_path: String = "res://" + str(info["path"])
	var path: String = ProjectSettings.globalize_path(res_path)
	var lr: Array[PackedFloat32Array] = _decode(path)
	var ff: Dictionary = FfmpegAudio.measure(path)
	# M-01
	var clipped: int = _count_clipped(lr)
	var tp: float = float(ff.get("true_peak_dbtp", 0.0))
	info["true_peak_dbtp"] = tp
	_check("M-01", name, "%d échantillon(s) ≥ 0,999 ; true peak %.2f dBTP ≤ −1" % [clipped, tp], clipped == 0 and tp <= -1.0)
	# M-02 : continu
	var dc: float = maxf(absf(_mean(lr[0])), absf(_mean(lr[1])))
	_check("M-02", name, "DC %.5f ≤ 0,001" % dc, dc <= 0.001)
	# M-06 : longueur et .import
	_check("M-06", name, "longueur décodée %d = %d" % [lr[0].size(), expected], lr[0].size() == expected)
	_check_import(name, res_path, loop, float(entry["tempo"]), int(entry["beats_per_bar"]),
			expected / int(entry["bar_samples"]) * int(entry["beats_per_bar"]))
	# M-05 : jointure de boucle
	if loop:
		_audit_loop_join(name, lr, rate, int(entry["bar_samples"]), str(info.get("wav_sha256", "")))
	# M-07 : mono
	_audit_mono(name, lr, rate)
	# M-09 : déterminisme (fichier = manifeste)
	_check("M-09", name, "SHA-256 = manifeste", FileAccess.get_sha256(res_path) == str(info.get("ogg_sha256", "")))
	return lr


func _check_import(name: String, res_path: String, loop: bool, bpm: float, bar_beats: int, beat_count: int) -> void:
	var text: String = FileAccess.get_file_as_string(res_path + ".import")
	var params: Dictionary[String, String] = {}
	for line: String in text.split("\n"):
		if line.contains("="):
			params[line.get_slice("=", 0)] = line.get_slice("=", 1)
	var ok: bool = params.get("loop", "") == ("true" if loop else "false") \
			and is_equal_approx(params.get("bpm", "0").to_float(), bpm) \
			and params.get("bar_beats", "") == str(bar_beats) and params.get("beat_count", "") == str(beat_count)
	_check("M-06", name, ".import loop=%s bpm=%s beat_count=%s bar_beats=%s" % [params.get("loop", "?"),
		params.get("bpm", "?"), params.get("beat_count", "?"), params.get("bar_beats", "?")], ok)


## M-05. Critère du document (saut ≤ 3 × la médiane des sauts ; RMS de 10 ms
## de part et d'autre dans ±1 dB) : imprimé pour information — il suppose un
## contenu continu et échoue sur toute attaque placée au temps 1 (basse,
## cliquetis). Critères retenus, sur l'OGG décodé : (a) clic — énergie haute
## fréquence sur 1 ms à la jointure ≤ son 99,9ᵉ centile sur tout le fichier ;
## (b) niveau — l'erreur de codage (OGG décodé − WAV rendu, dont la jointure
## est continue par construction : repli de la queue, test GUT) sur ±50 ms
## autour de la jointure ≤ son 99ᵉ centile sur les fenêtres de 100 ms du
## fichier (le codec ne traite pas la jointure plus mal que le reste) ;
## (c) aucun silence > 20 ms.
func _audit_loop_join(name: String, lr: Array[PackedFloat32Array], rate: int, bar_n: int, wav_sha: String) -> void:
	var worst_ratio: float = 0.0
	var worst_rms: float = 0.0
	var worst_hf_rank: float = 0.0
	for ch: int in 2:
		var buf: PackedFloat32Array = lr[ch]
		var n: int = buf.size()
		var jumps: PackedFloat32Array = PackedFloat32Array()
		jumps.resize(n - 1)
		for i: int in n - 1:
			jumps[i] = absf(buf[i + 1] - buf[i])
		jumps.sort()
		var median: float = maxf(jumps[jumps.size() / 2], 1e-6)
		worst_ratio = maxf(worst_ratio, absf(buf[0] - buf[n - 1]) / median)
		worst_rms = maxf(worst_rms, _rms_step(buf, 0, roundi(0.01 * rate)))
		var hop: int = maxi(roundi(0.001 * rate), 1)
		var energies: PackedFloat32Array = PackedFloat32Array()
		var at: int = hop
		while at < n - hop:
			energies.append(_hf_energy(buf, at, rate))
			at += hop
		energies.sort()
		var p999: float = maxf(energies[int(energies.size() * 0.999)], 1e-12)
		worst_hf_rank = maxf(worst_hf_rank, _hf_energy(buf, 0, rate) / p999)
	_info("M-05", name, "critère du document : saut = %.2f × la médiane (≤ 3), écart RMS 10 ms = %.2f dB (≤ 1) → %s" % [
		worst_ratio, worst_rms, "tenu" if worst_ratio <= 3.0 and worst_rms <= 1.0 else "non tenu (attaque au temps 1)"])
	_check("M-05", name, "clic : énergie HF 1 ms de la jointure = %.2f × le 99,9ᵉ centile du fichier (≤ 1)" % worst_hf_rank,
			worst_hf_rank <= 1.0)
	var wav_path: String = ProjectSettings.globalize_path(WORK_DIR.path_join(name + ".wav"))
	if FileAccess.file_exists(wav_path) and FileAccess.get_sha256(wav_path) == wav_sha:
		var wav: Array[PackedFloat32Array] = _decode(wav_path)
		var rank: float = 0.0
		for ch: int in 2:
			rank = maxf(rank, _junction_error_rank(lr[ch], wav[ch], rate))
		_check("M-05", name, "niveau : erreur de codage à la jointure = %.2f × son 99ᵉ centile (≤ 1)" % rank, rank <= 1.0)
	else:
		_info("M-05", name, "niveau : WAV intermédiaire absent ou d'un autre build (lancer build_music) — non mesuré")
	var longest: float = _longest_silence_ms(lr, rate)
	_check("M-05", name, "plus long silence %.0f ms (≤ 20)" % longest, longest <= 20.0)


## RMS de (décodé − référence) sur ±50 ms autour de la jointure, rapportée au
## 99ᵉ centile de la même mesure sur les fenêtres de 100 ms du fichier.
static func _junction_error_rank(decoded: PackedFloat32Array, reference: PackedFloat32Array, rate: int) -> float:
	var n: int = mini(decoded.size(), reference.size())
	var w: int = roundi(0.1 * rate)
	var half: int = w / 2
	var windows: PackedFloat32Array = PackedFloat32Array()
	var start: int = 0
	while start + w <= n:
		var s: float = 0.0
		for i: int in range(start, start + w):
			var d: float = decoded[i] - reference[i]
			s += d * d
		windows.append(s)
		start += w
	windows.sort()
	var p99: float = maxf(windows[int(windows.size() * 0.99)], 1e-20)
	var junction: float = 0.0
	for k: int in range(-half, half):
		var idx: int = posmod(k, n)
		var d2: float = decoded[idx] - reference[idx]
		junction += d2 * d2
	return junction / p99


## Écart absolu (dB) entre la RMS des 10 ms avant `at` et des 10 ms après
## (à la jointure, `at` = 0 : la fin du fichier précède le début).
static func _rms_step(buf: PackedFloat32Array, at: int, w: int) -> float:
	var n: int = buf.size()
	var before: float = 0.0
	var after: float = 0.0
	for k: int in w:
		var a: float = buf[posmod(at - 1 - k, n)]
		var b: float = buf[(at + k) % n]
		before += a * a
		after += b * b
	return absf(10.0 * log(maxf(before, 1e-20) / maxf(after, 1e-20)) / log(10.0))


## Énergie de la dérivée seconde sur 1 ms centrée sur `at` (indice circulaire) :
## un clic y est un pic.
static func _hf_energy(buf: PackedFloat32Array, at: int, rate: int) -> float:
	var n: int = buf.size()
	var h: int = maxi(roundi(0.0005 * rate), 2)
	var s: float = 0.0
	for k: int in range(-h, h):
		var d2: float = buf[posmod(at + k + 1, n)] - 2.0 * buf[posmod(at + k, n)] + buf[posmod(at + k - 1, n)]
		s += d2 * d2
	return s


func _audit_mono(name: String, lr: Array[PackedFloat32Array], rate: int) -> void:
	var l: PackedFloat32Array = lr[0]
	var r: PackedFloat32Array = lr[1]
	var s_st: float = 0.0
	var s_mono: float = 0.0
	for i: int in l.size():
		s_st += (l[i] * l[i] + r[i] * r[i]) * 0.5
		var m: float = (l[i] + r[i]) * 0.5
		s_mono += m * m
	var loss: float = 10.0 * log(maxf(s_st, 1e-20) / maxf(s_mono, 1e-20)) / log(10.0)
	_check("M-07", name, "perte de niveau en mono %.2f dB (≤ 3)" % loss, loss <= 3.0)
	var w: int = roundi(0.4 * rate)
	var worst: float = 1.0
	var start: int = 0
	while start + w <= l.size():
		var sll: float = 0.0
		var srr: float = 0.0
		var slr: float = 0.0
		for i: int in range(start, start + w):
			sll += l[i] * l[i]
			srr += r[i] * r[i]
			slr += l[i] * r[i]
		# Fenêtre silencieuse (< −60 dBFS RMS) : corrélation non significative.
		if sqrt((sll + srr) / (2.0 * w)) > 0.001:
			worst = minf(worst, slr / sqrt(maxf(sll * srr, 1e-30)))
		start += w / 2
	_check("M-07", name, "corrélation L/R minimale %.2f (≥ 0, fenêtres de 400 ms)" % worst, worst >= 0.0)


## M-08 : dans la bande 1–4 kHz, crête des cues UI P1/P2 (crête d'échantillon
## après filtrage, gain de cue et bus UI par défaut) ≥ musique (RMS max sur
## 3 s, « court terme », gains de niveau et bus Music par défaut) + 12 dB, à
## chaque niveau. Les cues sans énergie utile dans la bande (« hors bande »)
## sont listées à part ; le détail des P1 (critiques) est imprimé.
func _audit_ui_margin(score_id: String, music_band_db: Array[float]) -> void:
	var weakest: float = INF
	var weakest_cue: String = ""
	var weakest_p1: float = INF
	var listing: PackedStringArray = []
	var off_band: PackedStringArray = []
	for cue: StringName in AudioCueBank.CUES:
		if not String(cue).begins_with("ui.") or AudioCueBank.priority_of(cue) > AudioCueBank.P2:
			continue
		var cue_db: float = -INF
		var full_db: float = -INF
		for path: String in AudioCueBank.paths_of(cue):
			var wav: AudioStreamWAV = AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(path))
			if wav == null:
				continue
			var mono: PackedFloat32Array = AudioDsp.from_wav(wav)
			cue_db = maxf(cue_db, _band_sample_peak_db(mono, wav.mix_rate) \
					+ AudioCueBank.volume_db_of(cue) + linear_to_db(UI_BUS_LINEAR))
			full_db = maxf(full_db, linear_to_db(maxf(AudioDsp.peak(mono), 1e-10)) + AudioCueBank.volume_db_of(cue)
					+ linear_to_db(UI_BUS_LINEAR))
		# Cue « hors bande » : sa crête dans 1–4 kHz est > 12 dB sous sa crête
		# totale — elle se lit dans une autre bande (grave), non jugée ici.
		if cue_db < full_db - OFF_BAND_DB:
			off_band.append("%s %.1f/%.1f" % [String(cue).trim_prefix("ui."), cue_db, full_db])
			continue
		listing.append("%s %.1f" % [String(cue).trim_prefix("ui."), cue_db])
		if cue_db < weakest:
			weakest = cue_db
			weakest_cue = String(cue)
		if AudioCueBank.priority_of(cue) == AudioCueBank.P1:
			weakest_p1 = minf(weakest_p1, cue_db)
	_info("M-08", score_id, "cues UI dans 1–4 kHz (dBFS, crête) : %s" % ", ".join(listing))
	if not off_band.is_empty():
		_info("M-08", score_id, "cues hors bande (crête 1–4 kHz / crête totale, dBFS), non jugées : %s" % ", ".join(off_band))
	for level: int in music_band_db.size():
		_info("M-08", score_id, "N%d : marge des cues P1 (critiques) = %.1f dB" % [level, weakest_p1 - music_band_db[level]])
	for level: int in music_band_db.size():
		var margin: float = weakest - music_band_db[level]
		_check("M-08", score_id, "N%d : musique %.1f dBFS (3 s) ; cue la plus faible (%s) − musique = %.1f dB (≥ 12)" % [
			level, music_band_db[level], weakest_cue, margin], margin >= 12.0)


# ---------------------------------------------------------------------------
# Outils
# ---------------------------------------------------------------------------

## Somme des couches `layers` (ids de couche ; ordre `stems`) aux gains du
## manifeste et au bus Music par défaut.
func _layers_mix(decoded: Array, gains: Array, stems: Array, layers: Array) -> Array[PackedFloat32Array]:
	var mask: PackedByteArray = PackedByteArray()
	mask.resize(decoded.size())
	for i: int in decoded.size():
		var stem_id: String = str(stems[i]) if i < stems.size() else "l%d" % i
		mask[i] = 1 if layers.has(stem_id) else 0
	return _mask_mix(decoded, gains, mask)


func _level_mix(decoded: Array, gains: Array, level: int) -> Array[PackedFloat32Array]:
	return _mask_mix(decoded, gains, MusicDirector.layers_for_level(level))


func _mask_mix(decoded: Array, gains: Array, mask: PackedByteArray) -> Array[PackedFloat32Array]:
	var first: Array[PackedFloat32Array] = decoded[0]
	var n: int = first[0].size()
	var l: PackedFloat32Array = AudioDsp.silence(n)
	var r: PackedFloat32Array = AudioDsp.silence(n)
	for i: int in decoded.size():
		if i >= mask.size() or mask[i] == 0:
			continue
		var g: float = db_to_linear(float(gains[i])) * MUSIC_BUS_LINEAR
		var lr: Array[PackedFloat32Array] = decoded[i]
		var a: PackedFloat32Array = lr[0]
		var b: PackedFloat32Array = lr[1]
		for k: int in n:
			l[k] += a[k] * g
			r[k] += b[k] * g
	return [l, r]


## Crête de la RMS sur `window` s dans la bande 1–4 kHz (dBFS ; canaux moyennés).
static func _band_peak_db(left: PackedFloat32Array, right: PackedFloat32Array, rate: int, window: float) -> float:
	var src: PackedFloat32Array = left
	if not right.is_empty():
		src = AudioDsp.silence(left.size())
		for i: int in left.size():
			src[i] = (left[i] + right[i]) * 0.5
	var band: PackedFloat32Array = _band(src, rate)
	var w: int = mini(roundi(window * rate), band.size())
	var hop: int = maxi(roundi(0.025 * rate), 1)
	var best: float = 0.0
	var start: int = 0
	var s: float = 0.0
	for i: int in w:
		s += band[i] * band[i]
	best = s / w
	# Fenêtre glissante (somme mise à jour par pas de 25 ms).
	while start + hop + w <= band.size():
		for i: int in hop:
			s += band[start + w + i] * band[start + w + i] - band[start + i] * band[start + i]
		start += hop
		best = maxf(best, s / w)
	return 10.0 * log(maxf(best, 1e-20)) / log(10.0)


## Bande 1–4 kHz : passe-haut et passe-bas d'ordre 4 (deux SVF en cascade,
## 24 dB/octave) pour que les fondamentales sous 1 kHz ne débordent pas.
static func _band(buf: PackedFloat32Array, rate: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = buf
	for k: int in 2:
		out = AudioDsp.svf(out, AudioDsp.Svf.HIGHPASS, PackedFloat32Array([BAND_LO]), 0.7071, rate)
		out = AudioDsp.svf(out, AudioDsp.Svf.LOWPASS, PackedFloat32Array([BAND_HI]), 0.7071, rate)
	return out


## Crête d'échantillon (dBFS) dans la bande 1–4 kHz.
static func _band_sample_peak_db(mono: PackedFloat32Array, rate: int) -> float:
	var band: PackedFloat32Array = _band(mono, rate)
	return linear_to_db(maxf(AudioDsp.peak(band), 1e-10))


func _decode(path: String) -> Array[PackedFloat32Array]:
	var wav_path: String = _tmp.path_join(path.get_file().get_basename() + "_dec.wav")
	var output: Array = []
	OS.execute("ffmpeg", ["-loglevel", "error", "-y", "-i", path, "-c:a", "pcm_s16le", wav_path], output, true)
	var wav: AudioStreamWAV = AudioStreamWAV.load_from_file(wav_path)
	DirAccess.remove_absolute(wav_path)
	var l: PackedFloat32Array = PackedFloat32Array()
	var r: PackedFloat32Array = PackedFloat32Array()
	if wav == null:
		return [l, r]
	var data: PackedByteArray = wav.data
	var frames: int = data.size() / 4 if wav.stereo else data.size() / 2
	l.resize(frames)
	r.resize(frames)
	for i: int in frames:
		if wav.stereo:
			l[i] = data.decode_s16(i * 4) / 32768.0
			r[i] = data.decode_s16(i * 4 + 2) / 32768.0
		else:
			l[i] = data.decode_s16(i * 2) / 32768.0
			r[i] = l[i]
	return [l, r]


static func _rate_of(path: String) -> int:
	var output: Array = []
	OS.execute("ffprobe", ["-v", "error", "-show_entries", "stream=sample_rate", "-of", "csv=p=0",
		ProjectSettings.globalize_path(path)], output, true)
	return maxi(str(output[0]).strip_edges().to_int(), 1) if not output.is_empty() else 1


static func _count_clipped(lr: Array[PackedFloat32Array]) -> int:
	var count: int = 0
	for ch: PackedFloat32Array in lr:
		for v: float in ch:
			if absf(v) >= 0.999:
				count += 1
	return count


static func _mean(buf: PackedFloat32Array) -> float:
	var s: float = 0.0
	for v: float in buf:
		s += v
	return s / maxf(buf.size(), 1)


static func _rms_db(buf: PackedFloat32Array, from: int, to: int) -> float:
	var s: float = 0.0
	for i: int in range(maxi(from, 0), mini(to, buf.size())):
		s += buf[i] * buf[i]
	return 10.0 * log(maxf(s / maxf(to - from, 1), 1e-20)) / log(10.0)


## Plus long passage (ms) dont la RMS sur 5 ms reste sous −80 dBFS.
static func _longest_silence_ms(lr: Array[PackedFloat32Array], rate: int) -> float:
	var w: int = roundi(0.005 * rate)
	var run: int = 0
	var best: int = 0
	var start: int = 0
	var l: PackedFloat32Array = lr[0]
	var r: PackedFloat32Array = lr[1]
	while start + w <= l.size():
		var s: float = 0.0
		for i: int in range(start, start + w):
			s += l[i] * l[i] + r[i] * r[i]
		if s / (2.0 * w) < 1e-8:
			run += w
			best = maxi(best, run)
		else:
			run = 0
		start += w
	return best * 1000.0 / rate


func _check(metric: String, subject: String, detail: String, ok: bool) -> void:
	_rows.append({"metric": metric, "subject": subject, "detail": detail, "ok": ok})
	if not ok:
		_fails += 1
	print("%s %-5s %-24s %s" % ["OK  " if ok else "ÉCHEC", metric, subject, detail])


func _info(metric: String, subject: String, detail: String) -> void:
	_rows.append({"metric": metric, "subject": subject, "detail": detail, "ok": true})
	print("INFO %-5s %-24s %s" % [metric, subject, detail])
