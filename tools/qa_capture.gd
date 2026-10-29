## Capture QA réelle d'un écran (docs/QA.md §3) sans `override.cfg` : charge la
## scène de jour (ou `--qa-scene=`) avec les arguments de debug habituels
## (`--day`, `--screen`, `--flags`…), fixe la taille de la fenêtre
## (`--qa-size=1280x800` : Steam Deck), attend `--qa-wait` secondes de temps
## réel puis enregistre la dernière image dans `--qa-out=/chemin.png` et quitte.
## `--qa-quota=n/max` : publie un compteur QUOTA (capture de l'état « ATTEINT »).
## `--qa-after-check=s` : capture `s` secondes après la première comparaison
## (`discrepancy_checked`) — un résultat CONCORDANT ne reste affiché qu'un
## instant (M9 : Répondant ↔ Main courante) ; `--qa-wait` reste le délai maximal.
## Lancé par `tools/qa_boot.gd` (autoloads requis), sous xvfb :
##   xvfb-run -a -s "-screen 0 1920x1200x24" godot --path . --rendering-driver opengl3 \
##       --script res://tools/qa_boot.gd -- --qa-node=res://tools/qa_capture.gd --qa-size=1280x800 \
##       --qa-wait=25 --qa-out=/tmp/qa/j12.png --day=12 --screen=shift --flags=scanner_luciole
extends Node

const DAY_SCENE: String = "res://scenes/main/day.tscn"

var _scene: String = DAY_SCENE
var _size: Vector2i = Vector2i(1920, 1080)
var _wait: float = 20.0
var _out: String = ""
var _quota: PackedInt32Array = []
var _after_check: float = -1.0
var _t: float = 0.0
var _done: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-size="):
			var parts: PackedStringArray = arg.trim_prefix("--qa-size=").split("x")
			_size = Vector2i(parts[0].to_int(), parts[1].to_int())
		elif arg.begins_with("--qa-wait="):
			_wait = arg.trim_prefix("--qa-wait=").to_float()
		elif arg.begins_with("--qa-out="):
			_out = arg.trim_prefix("--qa-out=")
		elif arg.begins_with("--qa-scene="):
			_scene = arg.trim_prefix("--qa-scene=")
		elif arg.begins_with("--qa-quota="):
			var q: PackedStringArray = arg.trim_prefix("--qa-quota=").split("/")
			_quota = PackedInt32Array([q[0].to_int(), q[1].to_int()])
		elif arg.begins_with("--qa-after-check="):
			_after_check = arg.trim_prefix("--qa-after-check=").to_float()
	if _after_check >= 0.0:
		EventBus.discrepancy_checked.connect(_on_checked, CONNECT_ONE_SHOT)
	get_window().size = _size
	get_tree().change_scene_to_file(_scene)


func _on_checked(_result: Discrepancy) -> void:
	_wait = minf(_wait, _t + _after_check)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if _quota.size() == 2 and _t > 2.0:
		EventBus.quota_changed.emit(_quota[0], _quota[1])
	if _t < _wait:
		return
	_done = true
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if _out.is_empty() or image == null:
		push_error("qa_capture: rien à enregistrer")
		get_tree().quit(1)
		return
	image.save_png(_out)
	print("QA_CAPTURE %s %dx%d" % [_out, image.get_width(), image.get_height()])
	# Sons arrêtés et retirés par l'AudioServer avant de quitter (QA-025).
	get_tree().root.get_node("AudioMixBarrier").call(&"quit_after_silence", 0)
