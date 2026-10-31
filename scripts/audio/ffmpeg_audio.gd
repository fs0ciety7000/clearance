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
