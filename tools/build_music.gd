## Rendu hors ligne de la musique M14 (B80 ; docs/AUDIO.md §13.4,
## docs/M14.md §2.8, D-180) — déterministe et incrémental.
##
## Chaîne : `art_src/music/<id>.json` (partition) → `MusicRenderer` (synthèse
## `AudioDsp`) → WAV PCM 16 bits (dossier de travail, ignoré par git) →
## ffmpeg (Vorbis q3, `-fflags +bitexact -flags:a +bitexact`, métadonnées
## retirées, serial OGG fixe = hachage du nom) → `assets/audio/music/<id>/` ou
## `assets/audio/music/themes/` + `.import` (`loop`, `bpm`, `beat_count`,
## `bar_beats`) + `assets/audio/music/manifest.json` (SHA-256 du WAV et de
## l'OGG, échantillons, LUFS intégré et true peak de l'OGG décodé, hachage de
## la partition et de l'outil ; pour un ensemble : gains des couches qui
## donnent N0 → N4, docs/M14.md §2.5).
##
## Ensemble (`kind = set`) : une boucle par couche, longueur exacte
## `bars × bar_samples`, repli de la queue ; un gain commun aux couches (crête
## de la couche la plus forte à `PEAK_DB`), réduit tant qu'un OGG décodé dépasse
## −1 dBTP. Thème (`kind = theme`) : `main` = ouverture → queue (premier
## passage, d'un seul tenant) puis `tail` = la queue en boucle (repliée) :
## `main` enchaîne sur `tail` sans couture.
## Démo (`--demos`) : la section `demo` de la partition (niveaux par mesure,
## rampes d'une mesure comme à l'exécution) → `docs/mockups/m14_music_<id>_demo.ogg`.
##
## `--defs` (après `godot --import`) : écrit les données lues par le
## `MusicDirector` — `assets/audio/music/sets/<def_id>.tres` (`MusicSetDef` :
## couches, gains des niveaux, gain « exposé »), `themes/<def_id>.tres`
## (`MusicThemeDef`) et `music_library.tres` (`MusicLibraryDef`) — depuis le
## manifeste et les partitions (UID conservés).
## Usage : godot --headless --path . --script res://tools/build_music.gd -- [--only=ms02,thf9] [--force] [--demos]
##   [--work=<dossier WAV>] [--defs] ; ou `bash tools/build_audio.sh --only=music`.
extends SceneTree

const TOOL_VERSION: String = "m14-1"
const SRC_DIR: String = "res://art_src/music"
const OUT_DIR: String = "res://assets/audio/music"
const MANIFEST_PATH: String = "res://assets/audio/music/manifest.json"
const DEMO_DIR: String = "res://docs/mockups"
const DEFAULT_WORK: String = "res://art_src/downloads/_music_build"
## Crête visée des fichiers (dBFS échantillon) ; le true peak décodé doit
## rester ≤ `TRUE_PEAK_MAX`.
const PEAK_DB: float = -1.3
const TRUE_PEAK_MAX: float = -1.0
## Sonie visée de la musique seule par niveau N0 → N4 (docs/M14.md §2.5).
const LEVEL_TARGETS: Array[float] = [-30.0, -28.0, -26.5, -25.0, -24.0]
const EXPOSED_TARGET: float = -20.0
## Volume du bus Music aux réglages par défaut (`Settings.volume_music` 0,8).
const MUSIC_BUS_LINEAR: float = 0.8
const VORBIS_QUALITY: int = 3
const DEMO_QUALITY: int = 5

var _only: PackedStringArray = []
var _force: bool = false
var _demos: bool = false
var _defs: bool = false
var _work: String = ""
var _manifest: Dictionary = {}
var _failures: int = 0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=").split(",", false)
		elif arg == "--force":
			_force = true
		elif arg == "--demos":
			_demos = true
		elif arg == "--defs":
			_defs = true
		elif arg.begins_with("--work="):
			_work = arg.trim_prefix("--work=")
	if _work.is_empty():
		_work = ProjectSettings.globalize_path(DEFAULT_WORK)
	DirAccess.make_dir_recursive_absolute(_work)
	_manifest = _load_manifest()
	if _defs:
		_write_defs()
		quit(0 if _failures == 0 else 1)
		return
	var t0: int = Time.get_ticks_msec()
	var files: PackedStringArray = DirAccess.get_files_at(SRC_DIR)
	files.sort()
	for file: String in files:
		if not file.ends_with(".json"):
			continue
		var score_id: String = file.get_basename()
		if not _only.is_empty() and not _only.has(score_id):
			continue
		_build_score(SRC_DIR + "/" + file)
	_save_manifest()
	print("build_music: %s en %.1f s%s" % ["OK" if _failures == 0 else "ÉCHEC (%d)" % _failures,
		(Time.get_ticks_msec() - t0) / 1000.0, "" if _failures == 0 else " — voir les erreurs ci-dessus"])
	quit(0 if _failures == 0 else 1)


# ---------------------------------------------------------------------------
# Partition → fichiers
# ---------------------------------------------------------------------------

func _build_score(path: String) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		_fail("%s : JSON illisible" % path)
		return
	var score: Dictionary = parsed
	var renderer: MusicRenderer = MusicRenderer.new(score)
	if not renderer.errors.is_empty():
		_fail("\n".join(renderer.errors))
		return
	var score_hash: String = _score_hash(text)
	var entry: Dictionary = _manifest.get("scores", {}).get(renderer.id, {})
	if not _force and str(entry.get("score_hash", "")) == score_hash and _outputs_intact(entry) \
			and (not _demos or _demo_intact(entry)):
		print("build_music: %s inchangé (hachage %s…)" % [renderer.id, score_hash.substr(0, 12)])
		return
	var t0: int = Time.get_ticks_msec()
	var kind: String = str(score.get("kind", "set"))
	var result: Dictionary = {}
	if kind == "theme":
		result = _build_theme(renderer, score)
	else:
		result = _build_set(renderer, score)
	if not renderer.errors.is_empty():
		_fail("\n".join(renderer.errors))
		return
	result["score_hash"] = score_hash
	result["source"] = path.trim_prefix("res://")
	result["render_sec"] = snappedf((Time.get_ticks_msec() - t0) / 1000.0, 0.1)
	var scores: Dictionary = _manifest.get("scores", {})
	scores[renderer.id] = result
	_manifest["scores"] = scores
	print("build_music: %s rendu en %.1f s" % [renderer.id, result["render_sec"]])


## Ensemble : couches L0…L4 en boucles exactes, gain commun, gains de niveaux.
func _build_set(r: MusicRenderer, score: Dictionary) -> Dictionary:
	var layers: Array = []
	var peak: float = 0.0
	for stem_id: String in r.stem_ids():
		var lr: Array[PackedFloat32Array] = r.render_stem(stem_id)
		layers.append(lr)
		peak = maxf(peak, maxf(AudioDsp.peak(lr[0]), AudioDsp.peak(lr[1])))
		print("  %s/%s : %d éch., crête %.1f dBFS (avant gain commun)" % [r.id, stem_id, lr[0].size(),
			linear_to_db(maxf(AudioDsp.peak(lr[0]), AudioDsp.peak(lr[1])))])
	var dir: String = "%s/%s" % [OUT_DIR, r.id]
	var names: PackedStringArray = []
	for i: int in layers.size():
		names.append("mus_%s_l%d_loop" % [r.id, i])
	var common_db: float = PEAK_DB - linear_to_db(maxf(peak, 0.000001))
	var files: Dictionary = {}
	for attempt: int in 4:
		files = _write_group(r, layers, names, dir, common_db, true)
		var worst: float = -INF
		for name: String in files:
			worst = maxf(worst, float(files[name].get("true_peak_dbtp", -INF)))
		if worst <= TRUE_PEAK_MAX:
			break
		common_db -= worst - TRUE_PEAK_MAX + 0.1
		print("  true peak %.2f dBTP > %.1f : gain commun abaissé à %.2f dB" % [worst, TRUE_PEAK_MAX, common_db])
	var levels: Dictionary = _solve_levels(r, layers, db_to_linear(common_db))
	var out: Dictionary = {"kind": "set", "tempo": r.tempo, "beats_per_bar": r.beats_per_bar, "bars": r.bars,
		"sample_rate": r.rate, "bar_samples": r.bar_n, "common_gain_db": snappedf(common_db, 0.01), "files": files,
		"levels": levels, "tool_version": TOOL_VERSION}
	if _demos and score.has("demo"):
		out["demo"] = _set_demo(r, score, layers, db_to_linear(common_db), levels)
	return out


## Thème : `main` (d'un seul tenant) et `tail` (boucle repliée).
func _build_theme(r: MusicRenderer, score: Dictionary) -> Dictionary:
	var sections: Array = score.get("sections", [])
	var tail_from: int = r.bars
	var tail_bars: int = 0
	for s: Dictionary in sections:
		if bool(s.get("loop", false)):
			tail_from = int(s.get("from_bar", 0))
			tail_bars = int(s.get("bars", 0))
	var mains: Array = []
	var tails: Array = []
	var peak: float = 0.0
	for stem_id: String in r.stem_ids():
		var m: Array[PackedFloat32Array] = r.render_stem(stem_id, 0, r.bars, false)
		mains.append(m)
		peak = maxf(peak, maxf(AudioDsp.peak(m[0]), AudioDsp.peak(m[1])))
		if tail_bars > 0:
			var t: Array[PackedFloat32Array] = r.render_stem(stem_id, tail_from, tail_bars, true)
			tails.append(t)
			peak = maxf(peak, maxf(AudioDsp.peak(t[0]), AudioDsp.peak(t[1])))
	var main_mix: Array[PackedFloat32Array] = _sum(mains)
	var tail_mix: Array[PackedFloat32Array] = []
	if tail_bars > 0:
		tail_mix = _sum(tails)
	peak = maxf(AudioDsp.peak(main_mix[0]), AudioDsp.peak(main_mix[1]))
	if tail_bars > 0:
		peak = maxf(peak, maxf(AudioDsp.peak(tail_mix[0]), AudioDsp.peak(tail_mix[1])))
	var base: String = "mus_th_%s" % r.id.trim_prefix("th")
	var dir: String = "%s/themes" % OUT_DIR
	var common_db: float = PEAK_DB - linear_to_db(maxf(peak, 0.000001))
	var files: Dictionary = {}
	for attempt: int in 4:
		files = _write_group(r, [main_mix], PackedStringArray([base]), dir, common_db, false)
		if tail_bars > 0:
			files.merge(_write_group(r, [tail_mix], PackedStringArray([base + "_tail_loop"]), dir, common_db, true,
					tail_bars))
		var worst: float = -INF
		for name: String in files:
			worst = maxf(worst, float(files[name].get("true_peak_dbtp", -INF)))
		if worst <= TRUE_PEAK_MAX:
			break
		common_db -= worst - TRUE_PEAK_MAX + 0.1
	var g: float = db_to_linear(common_db)
	var lufs: float = AudioLoudness.integrated(AudioDsp.gain(main_mix[0], g), AudioDsp.gain(main_mix[1], g), r.rate)
	var out: Dictionary = {"kind": "theme", "tempo": r.tempo, "beats_per_bar": r.beats_per_bar, "bars": r.bars,
		"tail_from_bar": tail_from, "tail_bars": tail_bars, "sample_rate": r.rate, "bar_samples": r.bar_n,
		"common_gain_db": snappedf(common_db, 0.01), "files": files, "tool_version": TOOL_VERSION,
		# Gain à l'exécution (MusicThemeDef) pour −18 LUFS intégré (docs/M14.md §2.10).
		"runtime_gain_db": snappedf(-18.0 - lufs, 0.01)}
	if _demos and score.has("demo"):
		out["demo"] = _theme_demo(r, score, main_mix, tail_mix, g)
	return out


static func _sum(parts: Array) -> Array[PackedFloat32Array]:
	var first: Array[PackedFloat32Array] = parts[0]
	var l: PackedFloat32Array = first[0].duplicate()
	var rr: PackedFloat32Array = first[1].duplicate()
	for k: int in range(1, parts.size()):
		var p: Array[PackedFloat32Array] = parts[k]
		var pl: PackedFloat32Array = p[0]
		var pr: PackedFloat32Array = p[1]
		for i: int in l.size():
			l[i] += pl[i]
			rr[i] += pr[i]
	return [l, rr]


## Écrit WAV + OGG + `.import` d'un groupe de fichiers au même gain, puis les
## mesure (OGG décodé par ffmpeg).
func _write_group(r: MusicRenderer, parts: Array, names: PackedStringArray, dir: String, gain_db: float,
		loop: bool, loop_bars: int = -1) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var out: Dictionary = {}
	var g: float = db_to_linear(gain_db)
	for i: int in parts.size():
		var lr: Array[PackedFloat32Array] = parts[i]
		var name: String = names[i]
		var wav_path: String = "%s/%s.wav" % [_work, name]
		var ogg_res: String = "%s/%s.ogg" % [dir, name]
		var ogg_path: String = ProjectSettings.globalize_path(ogg_res)
		var wav: AudioStreamWAV = AudioDsp.to_wav(AudioDsp.gain(lr[0], g), r.rate, AudioDsp.gain(lr[1], g))
		if wav.save_to_wav(wav_path) != OK:
			_fail("écriture %s impossible" % wav_path)
			continue
		if not _encode(wav_path, ogg_path, VORBIS_QUALITY, name):
			continue
		var bars: int = loop_bars if loop_bars > 0 else lr[0].size() / r.bar_n
		_write_import(ogg_path, loop, r.tempo, bars * r.beats_per_bar, r.beats_per_bar)
		var m: Dictionary = measure(ogg_path)
		m["samples"] = lr[0].size()
		m["wav_sha256"] = FileAccess.get_sha256(wav_path)
		m["ogg_sha256"] = FileAccess.get_sha256(ogg_path)
		m["ogg_bytes"] = FileAccess.get_file_as_bytes(ogg_path).size()
		m["path"] = ogg_res.trim_prefix("res://")
		m["loop"] = loop
		out[name] = m
		print("  %s : %d éch., %.1f LUFS, %.2f dBTP, %d o" % [name, lr[0].size(), m.get("lufs", -INF),
			m.get("true_peak_dbtp", -INF), m["ogg_bytes"]])
	return out


# ---------------------------------------------------------------------------
# Niveaux N0 → N4 : gains des couches (sommation exacte par énergies croisées)
# ---------------------------------------------------------------------------

## Gains (dB, appliqués aux fichiers normalisés, bus Music par défaut inclus)
## qui donnent `LEVEL_TARGETS` ; calcul exact sur les énergies pondérées K
## croisées des couches par sous-bloc de 100 ms.
func _solve_levels(r: MusicRenderer, layers: Array, g: float) -> Dictionary:
	var count: int = layers.size()
	var kw: Array = []
	for lr: Array[PackedFloat32Array] in layers:
		var bus_g: float = g * MUSIC_BUS_LINEAR
		kw.append([AudioLoudness.k_weight(AudioDsp.gain(lr[0], bus_g), r.rate),
			AudioLoudness.k_weight(AudioDsp.gain(lr[1], bus_g), r.rate)])
	var sub: int = roundi(AudioLoudness.SUB_BLOCK_SEC * r.rate)
	var blocks: int = (layers[0][0] as PackedFloat32Array).size() / sub
	# cross[i][j][b] = Σ canaux Σ éch. du sous-bloc b de x_i · x_j.
	var cross: Dictionary[int, PackedFloat64Array] = {}
	for i: int in count:
		for j: int in range(i, count):
			var e: PackedFloat64Array = PackedFloat64Array()
			e.resize(blocks)
			for ch: int in 2:
				var a: PackedFloat64Array = kw[i][ch]
				var b: PackedFloat64Array = kw[j][ch]
				for blk: int in blocks:
					var s: float = 0.0
					var base: int = blk * sub
					for k: int in sub:
						s += a[base + k] * b[base + k]
					e[blk] += s
			cross[i * 16 + j] = e
	var gains: PackedFloat32Array = PackedFloat32Array()
	gains.resize(count)
	var masks: Array[PackedByteArray] = []
	for level: int in MusicDirector.LEVEL_COUNT:
		masks.append(MusicDirector.layers_for_level(level))
	var lufs_of: Callable = func(mask: PackedByteArray, gdb: PackedFloat32Array) -> float:
		var lin: PackedFloat64Array = PackedFloat64Array()
		lin.resize(count)
		for i: int in count:
			lin[i] = db_to_linear(gdb[i]) if i < mask.size() and mask[i] == 1 else 0.0
		var energy: PackedFloat64Array = PackedFloat64Array()
		energy.resize(blocks)
		for i: int in count:
			for j: int in range(i, count):
				var w: float = lin[i] * lin[j] * (1.0 if i == j else 2.0)
				if w == 0.0:
					continue
				var e: PackedFloat64Array = cross[i * 16 + j]
				for blk: int in blocks:
					energy[blk] += e[blk] * w
		return AudioLoudness.integrated_from_sub_blocks(energy, r.rate)
	# Chaque niveau ajoute une couche (N4 : L4 à la place de L3) : on règle la
	# couche ajoutée par dichotomie, les précédentes fixées.
	var added: PackedInt32Array = PackedInt32Array([0, 1, 2, 3, 4])
	for level: int in mini(MusicDirector.LEVEL_COUNT, count):
		var layer: int = added[level]
		var lo: float = -60.0
		var hi: float = 24.0
		for it: int in 40:
			var mid: float = (lo + hi) * 0.5
			gains[layer] = mid
			if lufs_of.call(masks[level], gains) < LEVEL_TARGETS[level]:
				lo = mid
			else:
				hi = mid
		gains[layer] = (lo + hi) * 0.5
	var measured: Array[float] = []
	for level: int in mini(MusicDirector.LEVEL_COUNT, count):
		measured.append(snappedf(lufs_of.call(masks[level], gains), 0.01))
	var exposed: float = lufs_of.call(MusicDirector.layers_for_level(MusicDirector.LEVEL_EXPOSED), gains)
	var gain_list: Array[float] = []
	for v: float in gains:
		gain_list.append(snappedf(v, 0.01))
	print("  niveaux N0→N4 : gains %s dB → %s LUFS ; exposé %.1f LUFS" % [gain_list, measured, exposed])
	return {"layer_gains_db": gain_list, "level_lufs": measured, "targets_lufs": LEVEL_TARGETS,
		"music_bus_db": snappedf(linear_to_db(MUSIC_BUS_LINEAR), 0.01),
		"exposed_lufs": snappedf(exposed, 0.01), "exposed_offset_db": snappedf(EXPOSED_TARGET - exposed, 0.01),
		"method": "BS.1770 (pondération K, portes −70/−10), énergies croisées des couches, bus Music à 0,8"}


# ---------------------------------------------------------------------------
# Démos (validation client)
# ---------------------------------------------------------------------------

## Démo d'un ensemble : niveaux par mesure, rampes d'une mesure (comme
## `MusicDirector`), gains des niveaux, puis présentation (+`present_db`).
func _set_demo(r: MusicRenderer, score: Dictionary, layers: Array, g: float, levels: Dictionary) -> Dictionary:
	var demo: Dictionary = score["demo"]
	var demo_bars: int = int(demo.get("bars", 24))
	var plan: Array = demo.get("levels", [[0, 0]])
	var fade_bars: int = int(demo.get("fade_out_bars", 2))
	var gains: Array = levels["layer_gains_db"]
	var n: int = demo_bars * r.bar_n
	var loop_n: int = r.bars * r.bar_n
	var out_l: PackedFloat32Array = AudioDsp.silence(n)
	var out_r: PackedFloat32Array = AudioDsp.silence(n)
	var count: int = layers.size()
	var amp: PackedFloat32Array = PackedFloat32Array()
	amp.resize(count)
	var level: int = int(plan[0][1])
	var mask0: PackedByteArray = MusicDirector.layers_for_level(level)
	for i: int in count:
		amp[i] = float(mask0[i])
	var step: float = 1.0 / r.bar_n
	for bar: int in demo_bars:
		for p: Array in plan:
			if int(p[0]) == bar:
				level = int(p[1])
		var mask: PackedByteArray = MusicDirector.layers_for_level(level)
		for i: int in count:
			var lr: Array[PackedFloat32Array] = layers[i]
			var src_l: PackedFloat32Array = lr[0]
			var src_r: PackedFloat32Array = lr[1]
			var lin: float = db_to_linear(float(gains[i])) * g * MUSIC_BUS_LINEAR
			var want: float = float(mask[i])
			var a: float = amp[i]
			if a == 0.0 and want == 0.0:
				continue
			for k: int in r.bar_n:
				var t: int = bar * r.bar_n + k
				if a < want:
					a = minf(a + step, want)
				elif a > want:
					a = maxf(a - step, want)
				var s: int = t % loop_n
				out_l[t] += src_l[s] * a * lin
				out_r[t] += src_r[s] * a * lin
			amp[i] = a
	return _finish_demo(r, demo, out_l, out_r, fade_bars, plan)


## Démo d'un thème : `main` puis la queue en boucle, fondu final.
func _theme_demo(r: MusicRenderer, score: Dictionary, main_mix: Array[PackedFloat32Array],
		tail_mix: Array[PackedFloat32Array], g: float) -> Dictionary:
	var demo: Dictionary = score["demo"]
	var extra_bars: int = int(demo.get("tail_bars", 4))
	var main_l: PackedFloat32Array = AudioDsp.gain(main_mix[0], g)
	var main_r: PackedFloat32Array = AudioDsp.gain(main_mix[1], g)
	if not tail_mix.is_empty():
		var tl: PackedFloat32Array = tail_mix[0]
		var tr: PackedFloat32Array = tail_mix[1]
		for k: int in extra_bars * r.bar_n:
			main_l.append(tl[k % tl.size()] * g)
			main_r.append(tr[k % tr.size()] * g)
	return _finish_demo(r, demo, main_l, main_r, int(demo.get("fade_out_bars", 2)), [])


func _finish_demo(r: MusicRenderer, demo: Dictionary, l: PackedFloat32Array, rr: PackedFloat32Array,
		fade_bars: int, plan: Array) -> Dictionary:
	var n: int = l.size()
	var fade_n: int = fade_bars * r.bar_n
	for k: int in fade_n:
		var t: float = 1.0 - float(k) / fade_n
		l[n - fade_n + k] *= t * t
		rr[n - fade_n + k] *= t * t
	var gain_db: float = float(demo.get("present_db", 0.0))
	if demo.has("target_lufs"):
		gain_db = float(demo["target_lufs"]) - AudioLoudness.integrated(l, rr, r.rate)
	var name: String = str(demo.get("file", "m14_music_%s_demo" % r.id))
	var wav_path: String = "%s/%s.wav" % [_work, name]
	var ogg_path: String = ProjectSettings.globalize_path("%s/%s.ogg" % [DEMO_DIR, name])
	var m: Dictionary = {}
	for attempt: int in 4:
		var g: float = db_to_linear(gain_db)
		var wav: AudioStreamWAV = AudioDsp.to_wav(AudioDsp.gain(l, g), r.rate, AudioDsp.gain(rr, g))
		wav.save_to_wav(wav_path)
		if not _encode(wav_path, ogg_path, DEMO_QUALITY, name):
			return {}
		m = measure(ogg_path)
		if float(m.get("true_peak_dbtp", 0.0)) <= TRUE_PEAK_MAX:
			break
		gain_db -= float(m["true_peak_dbtp"]) - TRUE_PEAK_MAX + 0.1
	m["present_gain_db"] = snappedf(gain_db, 0.01)
	m["seconds"] = snappedf(float(n) / r.rate, 0.01)
	m["path"] = ("%s/%s.ogg" % [DEMO_DIR, name]).trim_prefix("res://")
	m["ogg_sha256"] = FileAccess.get_sha256(ogg_path)
	if not plan.is_empty():
		m["levels_by_bar"] = plan
		# Sonie à court terme de chaque palier (mesure du WAV final).
		var g2: float = db_to_linear(gain_db)
		var steps: Array = []
		for p_index: int in plan.size():
			var start_bar: int = int(plan[p_index][0]) + 1
			var end_bar: int = int(plan[p_index + 1][0]) if p_index + 1 < plan.size() else n / r.bar_n - fade_bars
			if end_bar - start_bar < 2:
				continue
			var a: PackedFloat32Array = AudioDsp.gain(l.slice(start_bar * r.bar_n, end_bar * r.bar_n), g2)
			var b: PackedFloat32Array = AudioDsp.gain(rr.slice(start_bar * r.bar_n, end_bar * r.bar_n), g2)
			steps.append({"level": int(plan[p_index][1]), "bars": [start_bar, end_bar],
				"lufs": snappedf(AudioLoudness.integrated(a, b, r.rate), 0.01)})
		m["lufs_by_level"] = steps
	print("  démo %s : %.1f s, %.1f LUFS, %.2f dBTP (présentation %+.1f dB)" % [name, m["seconds"],
		m.get("lufs", -INF), m.get("true_peak_dbtp", -INF), gain_db])
	return m


# ---------------------------------------------------------------------------
# ffmpeg, mesures, manifeste
# ---------------------------------------------------------------------------

func _encode(wav_path: String, ogg_path: String, quality: int, name: String) -> bool:
	var err: String = FfmpegAudio.encode_vorbis(wav_path, ogg_path, quality, name)
	if not err.is_empty():
		_fail(err)
		return false
	return true


static func measure(path: String) -> Dictionary:
	return FfmpegAudio.measure(path)


## `.import` d'une boucle : paramètres versionnés (Godot complète le reste à
## l'import et garde ces paramètres).
static func _write_import(ogg_path: String, loop: bool, bpm: float, beat_count: int, bar_beats: int) -> void:
	var import_path: String = ogg_path + ".import"
	var params: Dictionary[String, String] = {"loop": "true" if loop else "false", "loop_offset": "0",
		"bpm": str(snappedf(bpm, 0.001)), "beat_count": str(beat_count), "bar_beats": str(bar_beats)}
	var lines: PackedStringArray = []
	if FileAccess.file_exists(import_path):
		var seen: Dictionary[String, bool] = {}
		for line: String in FileAccess.get_file_as_string(import_path).split("\n"):
			var key: String = line.get_slice("=", 0)
			if params.has(key) and line.contains("="):
				lines.append("%s=%s" % [key, params[key]])
				seen[key] = true
			else:
				lines.append(line)
		for key: String in params:
			if not seen.has(key):
				lines.insert(lines.size() - 1, "%s=%s" % [key, params[key]])
	else:
		lines.append_array(["[remap]", "", "importer=\"oggvorbisstr\"", "type=\"AudioStreamOggVorbis\"", "",
			"[params]", ""])
		for key: String in ["loop", "loop_offset", "bpm", "beat_count", "bar_beats"]:
			lines.insert(lines.size() - 1, "%s=%s" % [key, params[key]])
	var f: FileAccess = FileAccess.open(import_path, FileAccess.WRITE)
	f.store_string("\n".join(lines))


func _score_hash(text: String) -> String:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	ctx.update(TOOL_VERSION.to_utf8_buffer())
	# Le rendu dépend de la partition, du moteur de synthèse et de
	# `TOOL_VERSION` (à incrémenter quand la normalisation ou l'encodage de cet
	# outil changent ; `--defs` et les mesures n'en dépendent pas).
	for src: String in ["res://scripts/audio/music_renderer.gd", "res://scripts/audio/audio_dsp.gd"]:
		ctx.update(FileAccess.get_file_as_string(src).to_utf8_buffer())
	return ctx.finish().hex_encode()


func _outputs_intact(entry: Dictionary) -> bool:
	var files: Dictionary = entry.get("files", {})
	if files.is_empty():
		return false
	for name: String in files:
		var f: Dictionary = files[name]
		var path: String = "res://" + str(f.get("path", ""))
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != str(f.get("ogg_sha256", "")):
			return false
	return true


func _demo_intact(entry: Dictionary) -> bool:
	var demo: Dictionary = entry.get("demo", {})
	var path: String = "res://" + str(demo.get("path", ""))
	return not demo.is_empty() and FileAccess.file_exists(path) \
			and FileAccess.get_sha256(path) == str(demo.get("ogg_sha256", ""))


func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {"format": 1, "scores": {}}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	return parsed if parsed is Dictionary else {"format": 1, "scores": {}}


func _save_manifest() -> void:
	_manifest["format"] = 1
	_manifest["tool_version"] = TOOL_VERSION
	var total: int = 0
	for score_id: String in _manifest.get("scores", {}):
		for name: String in _manifest["scores"][score_id].get("files", {}):
			total += int(_manifest["scores"][score_id]["files"][name].get("ogg_bytes", 0))
	_manifest["total_ogg_bytes"] = total
	var f: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(_manifest, "\t", true) + "\n")


# ---------------------------------------------------------------------------
# Données (`MusicSetDef`, `MusicThemeDef`, `MusicLibraryDef`)
# ---------------------------------------------------------------------------

## Rôles et seuils par défaut des couches L0 → L4 (docs/M14.md §2.3, §2.5).
const DEFAULT_LAYERS: Array[Dictionary] = [
	{"role": "pad", "enter_level": 0, "exit_level": -1, "exposed": true, "melodic": false, "power_down": true},
	{"role": "pulse", "enter_level": 1, "exit_level": -1, "exposed": false, "melodic": false, "power_down": false},
	{"role": "rhythm", "enter_level": 2, "exit_level": -1, "exposed": false, "melodic": false, "power_down": false},
	{"role": "motif", "enter_level": 3, "exit_level": 4, "exposed": true, "melodic": true, "power_down": false},
	{"role": "tension", "enter_level": 4, "exit_level": -1, "exposed": false, "melodic": false, "power_down": false},
]


func _write_defs() -> void:
	var library: MusicLibraryDef = MusicLibraryDef.new()
	var scores: Dictionary = _manifest.get("scores", {})
	var ids: Array = scores.keys()
	ids.sort()
	for score_id: String in ids:
		var entry: Dictionary = scores[score_id]
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://" + str(entry.get("source", ""))))
		if not parsed is Dictionary:
			_fail("%s : partition introuvable" % score_id)
			continue
		var score: Dictionary = parsed
		var def_id: StringName = StringName(str(score.get("def_id", score_id)))
		if str(entry.get("kind", "")) == "set":
			var set_def: MusicSetDef = _set_def(def_id, score, entry)
			if set_def != null:
				var set_path: String = "%s/sets/%s.tres" % [OUT_DIR, def_id]
				_save_res(set_def, set_path)
				# Relu depuis le disque : la bibliothèque référence le fichier.
				library.sets.append(ResourceLoader.load(set_path, "", ResourceLoader.CACHE_MODE_REPLACE) as MusicSetDef)
		else:
			var theme: MusicThemeDef = _theme_def(def_id, score, entry)
			if theme != null:
				var theme_path: String = "%s/themes/%s.tres" % [OUT_DIR, def_id]
				_save_res(theme, theme_path)
				library.themes.append(ResourceLoader.load(theme_path, "", ResourceLoader.CACHE_MODE_REPLACE) as MusicThemeDef)
	_save_res(library, MusicLibraryDef.PATH)
	print("build_music --defs : %d ensemble(s), %d thème(s)" % [library.sets.size(), library.themes.size()])


func _set_def(def_id: StringName, score: Dictionary, entry: Dictionary) -> MusicSetDef:
	var s: MusicSetDef = MusicSetDef.new()
	s.id = def_id
	s.tempo_bpm = float(entry["tempo"])
	s.beats_per_bar = int(entry["beats_per_bar"])
	s.bars = int(entry["bars"])
	s.sample_rate = int(entry["sample_rate"])
	var levels: Dictionary = entry.get("levels", {})
	var gains: Array = levels.get("layer_gains_db", [])
	s.exposed_gain_db = float(levels.get("exposed_offset_db", 0.0))
	var stems: Array = score.get("stems", [])
	var files: Dictionary = entry.get("files", {})
	var names: Array = files.keys()
	names.sort()
	for i: int in stems.size():
		var stem: Dictionary = stems[i]
		var meta: Dictionary = DEFAULT_LAYERS[mini(i, DEFAULT_LAYERS.size() - 1)].duplicate()
		meta.merge(stem.get("layer", {}), true)
		var layer: MusicLayerDef = MusicLayerDef.new()
		layer.id = StringName(str(stem.get("id", "l%d" % i)))
		layer.resource_scene_unique_id = "layer_%s" % layer.id
		layer.role = StringName(str(meta["role"]))
		layer.enter_level = int(meta["enter_level"])
		layer.exit_level = int(meta["exit_level"])
		layer.exposed = bool(meta["exposed"])
		layer.melodic = bool(meta["melodic"])
		layer.keeps_on_power_down = bool(meta["power_down"])
		layer.group = StringName(str(meta.get("group", "")))
		layer.gain_db = float(gains[i]) if i < gains.size() else 0.0
		if i < names.size():
			var path: String = "res://" + str(files[names[i]]["path"])
			layer.stream = load(path) as AudioStream
			if layer.stream == null:
				_fail("%s : %s non importé (lancer godot --import avant --defs)" % [def_id, path])
		s.layers.append(layer)
	return s


func _theme_def(def_id: StringName, score: Dictionary, entry: Dictionary) -> MusicThemeDef:
	var t: MusicThemeDef = MusicThemeDef.new()
	t.id = def_id
	t.tempo_bpm = float(entry["tempo"])
	t.beats_per_bar = int(entry["beats_per_bar"])
	t.sample_rate = int(entry["sample_rate"])
	for e: String in score.get("endings", []):
		t.endings.append(StringName(e))
	for v: String in score.get("ending_variants", []):
		t.ending_variants.append(StringName(v))
	for sec: Dictionary in score.get("sections", []):
		var section: MusicSectionDef = MusicSectionDef.new()
		section.id = StringName(str(sec.get("id", "")))
		section.resource_scene_unique_id = "section_%s" % section.id
		section.start_bar = int(sec.get("from_bar", 0))
		section.bars = int(sec.get("bars", 0))
		section.loop = bool(sec.get("loop", false))
		t.sections.append(section)
	var files: Dictionary = entry.get("files", {})
	for name: String in files:
		var path: String = "res://" + str(files[name]["path"])
		var stream: AudioStream = load(path) as AudioStream
		if stream == null:
			_fail("%s : %s non importé (lancer godot --import avant --defs)" % [def_id, path])
		elif bool(files[name].get("loop", false)):
			t.tail_stream = stream
		else:
			t.stream = stream
	return t


func _save_res(res: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var uid: int = ResourceLoader.get_resource_uid(path) if ResourceLoader.exists(path) else ResourceUID.INVALID_ID
	var err: Error = ResourceSaver.save(res, path)
	if err != OK:
		_fail("%s non écrit (%s)" % [path, error_string(err)])
	elif uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(path, uid)


func _fail(message: String) -> void:
	_failures += 1
	push_error("build_music: " + message)
