## Mesure de perf indicative (docs/QA.md §5) : charge la scène de jour avec les
## arguments utilisateur (ex. `--screen=shift --day=7`), attend `--qa-warmup`
## secondes puis échantillonne pendant `--qa-sample` secondes : durée moyenne
## et p95 des images (temps réel entre deux `_process`), FPS, temps CPU de
## process / physique, appels de dessin, primitives, mémoire vidéo.
## Indicatif : sous xvfb, le rendu passe par llvmpipe (CPU), pas par un GPU.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/qa_boot.gd -- \
##       --qa-node=res://tools/qa_perf.gd --screen=shift --day=7 --seed=3
extends Node

const DAY_SCENE: String = "res://scenes/main/day.tscn"

var _warmup: float = 8.0
var _sample: float = 10.0
var _t: float = 0.0
var _last_usec: int = 0
var _frames: PackedFloat64Array = []
var _proc: float = 0.0
var _phys: float = 0.0
var _draws: float = 0.0
var _prims: float = 0.0
var _n: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-warmup="):
			_warmup = arg.trim_prefix("--qa-warmup=").to_float()
		elif arg.begins_with("--qa-sample="):
			_sample = arg.trim_prefix("--qa-sample=").to_float()
	get_tree().change_scene_to_file(DAY_SCENE)


func _process(delta: float) -> void:
	_t += delta
	var now: int = Time.get_ticks_usec()
	if _t > _warmup and _last_usec > 0:
		_frames.append((now - _last_usec) / 1000.0)
		_proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		_phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		_draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		_prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		_n += 1
	_last_usec = now
	if _t > _warmup + _sample and _n > 0:
		var sorted: PackedFloat64Array = _frames.duplicate()
		sorted.sort()
		var total: float = 0.0
		for f: float in _frames:
			total += f
		var mean: float = total / _n
		print("QA_PERF frames=%d mean_ms=%.1f p95_ms=%.1f fps=%.1f process_ms=%.2f physics_ms=%.2f draw_calls=%.0f primitives=%.0f vram_mb=%.0f renderer=%s" % [
				_n, mean, sorted[int(_n * 0.95) - 1 if _n > 1 else 0], 1000.0 / mean, _proc / _n, _phys / _n, _draws / _n,
				_prims / _n, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
				RenderingServer.get_video_adapter_name()])
		set_process(false)
		# Sons arrêtés et retirés par l'AudioServer avant de quitter (QA-025).
		get_tree().root.get_node("AudioMixBarrier").call(&"quit_after_silence", 0)
