## Appels à ffmpeg des outils audio hors ligne (M14 ; docs/AUDIO.md §13.4,
## §13.5) : encodage Vorbis **déterministe** et mesures EBU R128. Jamais
## utilisé à l'exécution du jeu (outils `tools/build_music.gd`,
## `tools/qa_audio_audit.gd`). Classe-espace de noms : jamais instanciée.
class_name FfmpegAudio
extends RefCounted

const FFMPEG: String = "ffmpeg"


## Serial OGG fixe dérivé du nom du fichier (31 bits).
static func serial_for(name: String) -> int:
	return absi(SeededRng.hash_string(name)) % 0x7FFFFFFF


## WAV → OGG Vorbis `quality` : `-fflags +bitexact -flags:a +bitexact`,
## métadonnées retirées, serial fixe : deux encodages = mêmes octets.
## Renvoie "" si OK, sinon le message d'ffmpeg.
static func encode_vorbis(wav_path: String, ogg_path: String, quality: float, name: String,
		sample_rate: int = 0) -> String:
	var args: PackedStringArray = ["-loglevel", "error", "-y", "-i", wav_path, "-map_metadata", "-1",
		"-c:a", "libvorbis", "-q:a", str(quality), "-fflags", "+bitexact", "-flags:a", "+bitexact",
		"-serial_offset", str(serial_for(name))]
	if sample_rate > 0:
		args.append_array(["-ar", str(sample_rate)])
	args.append(ogg_path)
	var output: Array = []
	var code: int = OS.execute(FFMPEG, args, output, true)
	return "" if code == 0 else "ffmpeg (%s) : %s" % [name, "".join(output)]


## LUFS intégré, true peak (dBTP) et LRA d'un fichier (ffmpeg `ebur128=peak=true`).
static func measure(path: String) -> Dictionary:
	var output: Array = []
	OS.execute(FFMPEG, ["-nostats", "-hide_banner", "-i", path, "-af", "ebur128=peak=true", "-f", "null", "-"],
			output, true)
	var text: String = "".join(output)
	var out: Dictionary = {}
	var summary: int = text.rfind("Summary:")
	if summary < 0:
		return out
	for line: String in text.substr(summary).split("\n"):
		var s: String = line.strip_edges()
		if s.begins_with("I:"):
			out["lufs"] = snappedf(s.trim_prefix("I:").replace("LUFS", "").strip_edges().to_float(), 0.01)
		elif s.begins_with("Peak:"):
			out["true_peak_dbtp"] = snappedf(s.trim_prefix("Peak:").replace("dBFS", "").strip_edges().to_float(), 0.01)
		elif s.begins_with("LRA:"):
			out["lra_lu"] = snappedf(s.trim_prefix("LRA:").replace("LU", "").strip_edges().to_float(), 0.01)
	return out


## OGG (ou tout fichier lu par ffmpeg) → [gauche, droite] en flottants
## (WAV 16 bits temporaire dans `tmp_dir`).
static func decode(path: String, tmp_dir: String) -> Array[PackedFloat32Array]:
	DirAccess.make_dir_recursive_absolute(tmp_dir)
	var wav_path: String = tmp_dir.path_join(path.get_file().get_basename() + "_dec.wav")
	var output: Array = []
	OS.execute(FFMPEG, ["-loglevel", "error", "-y", "-i", path, "-c:a", "pcm_s16le", wav_path], output, true)
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


## Clic à la jointure d'une boucle décodée (critère M-05 retenu, docs/AUDIO.md
## §13.5) : énergie HF (dérivée seconde, ±0,5 ms) à l'échantillon 0 rapportée
## au 99,9ᵉ centile de la même mesure tous les 1 ms ; ≤ 1 = pas de clic.
static func junction_click_rank(lr: Array[PackedFloat32Array], rate: int) -> float:
	var worst: float = 0.0
	for ch: int in 2:
		var buf: PackedFloat32Array = lr[ch]
		var n: int = buf.size()
		if n < 16:
			continue
		var hop: int = maxi(roundi(0.001 * rate), 1)
		var energies: PackedFloat32Array = PackedFloat32Array()
		var at: int = hop
		while at < n - hop:
			energies.append(hf_energy(buf, at, rate))
			at += hop
		energies.sort()
		var p999: float = maxf(energies[int(energies.size() * 0.999)], 1e-12)
		worst = maxf(worst, hf_energy(buf, 0, rate) / p999)
	return worst


static func hf_energy(buf: PackedFloat32Array, at: int, rate: int) -> float:
	var n: int = buf.size()
	var h: int = maxi(roundi(0.0005 * rate), 2)
	var s: float = 0.0
	for k: int in range(-h, h):
		var d2: float = buf[posmod(at + k + 1, n)] - 2.0 * buf[posmod(at + k, n)] + buf[posmod(at + k - 1, n)]
		s += d2 * d2
	return s


## Erreur de codage à la jointure (critère M-05 b, docs/AUDIO.md §13.5) :
## énergie de (décodé − WAV) sur ±50 ms autour de l'échantillon 0, rapportée
## au 99ᵉ centile des fenêtres de 100 ms du fichier ; ≤ 1 = jointure fidèle.
static func junction_error_rank(decoded: PackedFloat32Array, reference: PackedFloat32Array, rate: int) -> float:
	var n: int = mini(decoded.size(), reference.size())
	var w: int = roundi(0.1 * rate)
	if n < w:
		return 0.0
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
