## Audit du Hall M14 (lot C ; M14 §4.6, M-13 ; BOOTH_SCENE §20) : charge la
## scène de jour réelle (`--day`, `--screen=shift`…), attend `--qa-wait`
## secondes, puis mesure les **appels de dessin de la bande 3D** (render info du
## `SubViewport` du booth, moyenne sur `--qa-sample` secondes) et écrit
## `QA_HALL day=… draws=… primitives=… queue=… guards=…`.
## (`--qa-guard-out` ignore l'arrêt pendant l'inspection : aide de capture.)
## `--qa-escort` : lance l'escorte de la Garde sur le passager au guichet
## (pic du J7 : détention + escorte). `--qa-guard-out` : fait sortir la
## patrouille tout de suite (capture). `--qa-quality=0|1|2` : qualité graphique
## de session (jamais écrite). `--qa-out=…png` : capture de la fenêtre ;
## `--qa-strip=…png` : capture de la bande 3D seule (1920×376).
## Si le `DayController` n'émet pas encore `queue_progressed` (lot F), l'outil
## l'émet lui-même depuis le vrai roster du jour (`CaseBuilder.roster`) et le
## signale (`emulated_queue=1`).
## Lancé par `tools/qa_boot.gd`, sous xvfb (pilote `opengl3`) :
##   xvfb-run -a -s "-screen 0 1920x1200x24" godot --path . --rendering-driver opengl3 \
##       --script res://tools/qa_boot.gd -- --qa-node=res://tools/qa_hall_audit.gd \
##       --day=7 --screen=shift --seed=3 --qa-escort --qa-wait=14
extends Node

const DAY_SCENE: String = "res://scenes/main/day.tscn"

var _wait: float = 14.0
var _sample: float = 3.0
var _size: Vector2i = Vector2i(1920, 1080)
var _out: String = ""
var _strip: String = ""
var _escort: bool = false
var _guard_out: bool = false
var _t: float = 0.0
var _queue_seen: bool = false
var _emulated: bool = false
var _escort_done: bool = false
var _draws: float = 0.0
var _prims: float = 0.0
var _n: int = 0
var _done: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-wait="):
			_wait = arg.trim_prefix("--qa-wait=").to_float()
		elif arg.begins_with("--qa-sample="):
			_sample = arg.trim_prefix("--qa-sample=").to_float()
		elif arg.begins_with("--qa-size="):
			var parts: PackedStringArray = arg.trim_prefix("--qa-size=").split("x")
			_size = Vector2i(parts[0].to_int(), parts[1].to_int())
		elif arg.begins_with("--qa-out="):
			_out = arg.trim_prefix("--qa-out=")
		elif arg.begins_with("--qa-strip="):
			_strip = arg.trim_prefix("--qa-strip=")
		elif arg == "--qa-escort":
			_escort = true
		elif arg == "--qa-guard-out":
			_guard_out = true
		elif arg.begins_with("--qa-quality="):
			# Réglage de session (jamais écrit) : 0 Bas, 1 Moyen, 2 Élevé.
			Settings.set_session_value(Settings.KEY_GRAPHICS_QUALITY, arg.trim_prefix("--qa-quality=").to_float())
	DisplayServer.window_set_size(_size)
	get_tree().root.size = _size
	EventBus.queue_progressed.connect(func(_p: int, _t2: int, _u: Array[QueueSilhouette]) -> void: _queue_seen = true)
	get_tree().change_scene_to_file(DAY_SCENE)


func _booth() -> BoothDirector:
	var scene: Node = get_tree().current_scene
	return scene.get_node_or_null(^"%Booth") as BoothDirector if scene != null else null


func _controller() -> DayController:
	var scene: Node = get_tree().current_scene
	return scene.get_node_or_null(^"%DayController") as DayController if scene != null else null


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var booth: BoothDirector = _booth()
	var controller: DayController = _controller()
	if booth == null or controller == null:
		return
	# File réelle émulée tant que le lot F n'émet pas `queue_progressed`.
	if not _queue_seen and _t > 2.0 and controller.builder != null and controller.builder.roster != null:
		_emulated = true
		_queue_seen = true
		var processed: int = maxi(controller.next_index - 1, 0)
		var total: int = controller.day.passenger_count if controller.day.mode != DayDef.MODE_GARDE else -1
		EventBus.queue_progressed.emit(processed, total, QueueSilhouette.upcoming(controller.builder.roster, processed, total))
	if _guard_out and _t > 2.0 and booth.hall_guards != null:
		# Capture seulement : la patrouille sort et avance même pendant l'inspection.
		if booth.hall_guards.patrol_state == &"idle":
			booth.hall_guards._wait = 0.0
		booth.hall_guards.set_inspecting(false)
	if _escort and not _escort_done:
		var actor: PassengerActor = booth.get_desk_actor()
		if actor != null and actor.state == PassengerActor.State.AT_DESK:
			booth.start_escort(actor)
			_escort_done = true
	if _t > _wait - _sample and _t <= _wait:
		var rid: RID = booth.get_viewport().get_viewport_rid()
		_draws += RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
				RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		_prims += RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
				RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		_n += 1
	if _t > _wait:
		_done = true
		_finish(booth)


func _finish(booth: BoothDirector) -> void:
	await RenderingServer.frame_post_draw
	var counts: Dictionary[StringName, int] = booth.queue.instance_counts()
	var guards: int = booth.hall_guards.instance_total() if booth.hall_guards != null else 0
	print("QA_HALL day=%d quality=%d draws=%.1f primitives=%.0f queue=%s visible_queue=%d guards=%d patrol=%s banner=%s escort=%s emulated_queue=%d" % [
			_controller().day.day_number, Settings.graphics_quality_level(), _draws / maxi(_n, 1), _prims / maxi(_n, 1), counts,
			booth.queue.visible_queue_count(), guards, booth.hall_guards.patrol_state if booth.hall_guards != null else &"-",
			booth.banner != null and booth.banner.visible, booth.is_escorting(), 1 if _emulated else 0])
	if not _out.is_empty():
		get_viewport().get_texture().get_image().save_png(_out)
		print("QA_HALL capture %s" % _out)
	if not _strip.is_empty():
		booth.get_viewport().get_texture().get_image().save_png(_strip)
		print("QA_HALL bande %s" % _strip)
	get_tree().root.get_node("AudioMixBarrier").call(&"quit_after_silence", 0)
