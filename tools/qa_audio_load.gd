## Charge audio de la musique M14 (docs/M14.md §6.2 M-10, M-11 ; docs/AUDIO.md
## §13.8) — outil QA, jamais chargé par le jeu.
##
## M-10 (CPU) : deux phases de `--seconds` (60 par défaut) dans le même
## processus, à 60 images/s (`Engine.max_fps`) : **sans musique** (4 boucles
## d'ambiance + un bark en boucle, comme en 0.13 hors musique) puis **avec
## musique au pire cas** (MS-02 au niveau N4, les 5 couches décodées, et un
## changement de clip toutes les 8 s vers MS-06 : fondu croisé de 2 mesures,
## jusqu'à 8 flux Vorbis à la fois). Temps CPU du processus lu dans
## `/proc/self/stat` (utime + stime) ; écart = coût de la musique en % d'un
## cœur. Cible : ≤ 3 %.
## M-11 (mémoire) : `Performance.MEMORY_STATIC` avant et après le chargement
## d'un ensemble de jeu + MS-06 + le plus gros thème (+ sa queue), et la somme
## des tailles des OGG chargés (données compressées résidentes). Cible : ≤ 6 Mo.
## Usage : godot --headless --path . --script res://tools/qa_audio_load.gd -- [--seconds=60] [--json=rapport.json]
##   [--set=ms_04] [--skip-cpu]
extends SceneTree

const SETS_DIR: String = "res://assets/audio/music/sets/"
const INDEX_PATH: String = "res://assets/audio/music/index.json"
const AMBIENCE: Array[String] = ["res://assets/audio/ambience/amb_rain_glass_loop.ogg",
	"res://assets/audio/ambience/amb_station_bed_loop.ogg", "res://assets/audio/ambience/amb_neon_hum_loop.ogg",
	"res://assets/audio/ambience/amb_queue_murmur_loop.ogg"]
const CPU_TARGET_PCT: float = 3.0
const RAM_TARGET_BYTES: int = 6 * 1024 * 1024

var _seconds: float = 60.0
var _json: String = ""
var _set_id: String = "ms_02"
var _skip_cpu: bool = false
var _report: Dictionary = {}
var _director: MusicDirector = null
var _players: Array[AudioStreamPlayer] = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):
			_seconds = arg.trim_prefix("--seconds=").to_float()
		elif arg.begins_with("--json="):
			_json = arg.trim_prefix("--json=")
		elif arg.begins_with("--set="):
			_set_id = arg.trim_prefix("--set=")
		elif arg == "--skip-cpu":
			_skip_cpu = true
	Engine.max_fps = 60
	_run.call_deferred()


func _run() -> void:
	_report["memory"] = _measure_memory()
	if not _skip_cpu:
		_report["cpu"] = await _measure_cpu()
	var ok: bool = bool(_report["memory"].get("ok", false)) and (_skip_cpu or bool(_report["cpu"].get("ok", false)))
	_report["ok"] = ok
	print(JSON.stringify(_report, "  ", true))
	if not _json.is_empty():
		var f: FileAccess = FileAccess.open(_json, FileAccess.WRITE)
		f.store_string(JSON.stringify(_report, "\t", true) + "\n")
	_cleanup()
	quit(0 if ok else 1)


# ---------------------------------------------------------------------------
# M-11 : mémoire
# ---------------------------------------------------------------------------

func _measure_memory() -> Dictionary:
	# 1. Le plus gros thème de fin (flux principal + queue) : pire cas, choisi
	#    sur les tailles de fichiers (chaque thème relâché aussitôt).
	var biggest_path: String = ""
	var biggest_bytes: int = 0
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	if index is Dictionary:
		for theme_id: String in (index as Dictionary).get("themes", {}):
			var path: String = str(index["themes"][theme_id]["path"])
			var theme: MusicThemeDef = load(path) as MusicThemeDef
			if theme == null or not theme.worlds.is_empty():
				continue
			var tb: int = _stream_bytes(theme.stream) + _stream_bytes(theme.tail_stream)
			for v: MusicThemeVariantDef in theme.variants:
				tb = maxi(tb, _stream_bytes(v.stream) + _stream_bytes(theme.tail_stream))
			if tb > biggest_bytes:
				biggest_bytes = tb
				biggest_path = path
	# 2. Ensemble de jeu + MS-06 + ce thème, mesurés ensemble.
	var before: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var resident: Array[Resource] = []
	var bytes: int = 0
	var game: MusicSetDef = load(SETS_DIR + _set_id + ".tres") as MusicSetDef
	var evening: MusicSetDef = load(SETS_DIR + "ms_06.tres") as MusicSetDef
	for s: MusicSetDef in [game, evening]:
		if s == null:
			return {"ok": false, "error": "ensemble manquant"}
		resident.append(s)
		for layer: MusicLayerDef in s.layers:
			if layer.stream != null:
				bytes += _file_bytes(layer.stream.resource_path)
	var biggest: MusicThemeDef = load(biggest_path) as MusicThemeDef if not biggest_path.is_empty() else null
	if biggest != null:
		resident.append(biggest)
		bytes += biggest_bytes
	var after: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var out: Dictionary = {"set": _set_id, "evening": "ms_06", "theme": String(biggest.id) if biggest != null else "",
		"ogg_bytes_resident": bytes, "static_memory_delta_bytes": after - before,
		"target_bytes": RAM_TARGET_BYTES, "ok": bytes <= RAM_TARGET_BYTES}
	print("M-11 : %s + ms_06 + %s : %.2f Mo d'OGG résidents (Δ MEMORY_STATIC %.2f Mo)" % [
		_set_id, out["theme"], bytes / 1048576.0, (after - before) / 1048576.0])
	return out


static func _file_bytes(path: String) -> int:
	if path.is_empty() or not FileAccess.file_exists(path):
		return 0
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	return f.get_length() if f != null else 0


## Octets des OGG d'un flux (un OGG, ou un `AudioStreamSynchronized` de couches
## partagées avec un ensemble : 0 octet de plus).
static func _stream_bytes(stream: AudioStream) -> int:
	if stream == null or stream is AudioStreamSynchronized:
		return 0
	return _file_bytes(stream.resource_path)


# ---------------------------------------------------------------------------
# M-10 : CPU
# ---------------------------------------------------------------------------

func _measure_cpu() -> Dictionary:
	for path: String in AMBIENCE:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.stream = load(path) as AudioStream
		p.bus = &"Ambience"
		root.add_child(p)
		p.play()
		_players.append(p)
	var bark: AudioStreamPlayer = AudioStreamPlayer.new()
	var voice: PackedFloat32Array = TessarVoice.synthesize("vesh ota lumi, tal ka nesu", TessarVoice.profile_for(Passenger.new()))
	bark.stream = AudioDsp.to_wav(voice, TessarVoice.SAMPLE_RATE, PackedFloat32Array(), true)
	bark.bus = &"Voice"
	root.add_child(bark)
	bark.play()
	_players.append(bark)
	await _wait(2.0)
	var base: Dictionary = await _sample(_seconds)
	print("M-10 sans musique : %.2f %% d'un cœur" % base["pct"])
	_director = MusicDirector.new()
	root.add_child(_director)
	var game: MusicSetDef = load(SETS_DIR + _set_id + ".tres") as MusicSetDef
	var evening: MusicSetDef = load(SETS_DIR + "ms_06.tres") as MusicSetDef
	_director.configure_from_def(game)
	_director.configure_from_def(evening)
	_director.play(game.id, 4)
	await _wait(2.0)
	var switches: int = 0
	var t0: int = Time.get_ticks_msec()
	var ticks0: int = _cpu_ticks()
	var next_switch: float = 8.0
	while (Time.get_ticks_msec() - t0) / 1000.0 < _seconds:
		await process_frame
		var elapsed: float = (Time.get_ticks_msec() - t0) / 1000.0
		if elapsed >= next_switch:
			next_switch += 8.0
			_director.switch_clip(evening.id if _director.get_current_clip() == game.id else game.id,
					4 if _director.get_current_clip() == evening.id else 0)
			switches += 1
	var wall: float = (Time.get_ticks_msec() - t0) / 1000.0
	var cpu_sec: float = (_cpu_ticks() - ticks0) / 100.0
	var music: Dictionary = {"pct": 100.0 * cpu_sec / wall, "cpu_sec": cpu_sec, "wall_sec": wall, "clip_switches": switches}
	print("M-10 avec musique (N4 + fondus croisés) : %.2f %% d'un cœur" % music["pct"])
	var delta: float = float(music["pct"]) - float(base["pct"])
	return {"without_music": base, "with_music": music, "delta_pct": snappedf(delta, 0.01), "target_pct": CPU_TARGET_PCT,
		"ok": delta <= CPU_TARGET_PCT, "fps_cap": Engine.max_fps, "audio_driver": AudioServer.get_driver_name() if AudioServer.has_method(&"get_driver_name") else "?"}


func _sample(seconds: float) -> Dictionary:
	var t0: int = Time.get_ticks_msec()
	var ticks0: int = _cpu_ticks()
	while (Time.get_ticks_msec() - t0) / 1000.0 < seconds:
		await process_frame
	var wall: float = (Time.get_ticks_msec() - t0) / 1000.0
	var cpu_sec: float = (_cpu_ticks() - ticks0) / 100.0
	return {"pct": 100.0 * cpu_sec / wall, "cpu_sec": cpu_sec, "wall_sec": wall}


func _wait(seconds: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < seconds:
		await process_frame


## utime + stime du processus (`/proc/<pid>/stat`, en ticks de 1/100 s).
static func _cpu_ticks() -> int:
	# `FileAccess` lit 0 octet des fichiers de /proc (taille nulle) : `cat`.
	var output: Array = []
	OS.execute("cat", ["/proc/%d/stat" % OS.get_process_id()], output, true)
	var text: String = "".join(output)
	var after: String = text.substr(text.rfind(")") + 2)
	var fields: PackedStringArray = after.split(" ")
	# Champs 14 et 15 de stat(5) = index 11 et 12 après « (comm) ».
	return fields[11].to_int() + fields[12].to_int() if fields.size() > 12 else 0


func _cleanup() -> void:
	for p: AudioStreamPlayer in _players:
		p.stop()
		p.stream = null
	if _director != null:
		_director.queue_free()
