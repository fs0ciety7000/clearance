## Scène de démonstration / captures du passager final (M6) — debug seulement.
##
## `godot --path . --rendering-driver opengl3 res://scenes/passenger/passenger_demo.tscn -- <args>`
## - `--mode=booth` (défaut) : vrai `booth.tscn` piloté par l'EventBus ;
##   `--state=desk|visor_down|visor_up|react|nervous|shrug|leave|empty` (marche : `desk` + `--at` court) ;
## - `--mode=lineup` : planche de 8 passagers différents (acteurs réels, idle) ;
## - `--mode=portraits` : planche de 8 portraits de documents (`PortraitService`).
## Communs : `--day=N` (1–3), `--seed=N`, `--shot=chemin.png` + `--at=secondes`
## (capture puis sortie), `--fps` (moyenne FPS imprimée à la sortie).
class_name PassengerDemo
extends Node

const BOOTH: PackedScene = preload("res://scenes/booth/booth.tscn")
const ACTOR: PackedScene = preload("res://scenes/passenger/passenger_actor.tscn")
const LINEUP_COUNT: int = 8

var _args: Dictionary[String, String] = {}
var _time: float = 0.0
var _shot_at: float = -1.0
var _frames: int = 0
var _fps_sum: float = 0.0
var _builder: CaseBuilder = null
var _booth: BoothDirector = null
var _case: Case = null
var _script: Array[Array] = []


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else ""
	# Captures en mouvement réel, quel que soit le réglage local du joueur.
	Settings.set_value(Settings.KEY_REDUCE_MOTION, _args.has("reduce-motion"), false)
	var data: DataCatalog = DataCatalog.load_from()
	var day_number: int = _arg("day", "3").to_int()
	var seed_value: int = _arg("seed", "7").to_int()
	_builder = CaseBuilder.new(data, data.get_day(day_number), SeededRng.day_seed(seed_value, day_number))
	_shot_at = _arg("at", "-1").to_float()
	match _arg("mode", "booth"):
		"lineup":
			_lineup()
		"portraits":
			_portraits()
		_:
			_booth_mode(_arg("state", "desk"))


func _process(delta: float) -> void:
	_time += delta
	if _time > 1.0:
		_frames += 1
		_fps_sum += Engine.get_frames_per_second()
	while not _script.is_empty() and _time >= _step_time(_script[0]):
		var step: Array = _script.pop_front()
		var action: Callable = step[1]
		action.call()
	if _shot_at >= 0.0 and _time >= _shot_at:
		_shot_at = -1.0
		_capture.call_deferred()


func _arg(key: String, fallback: String) -> String:
	return _args.get(key, fallback)


static func _step_time(step: Array) -> float:
	var t: float = step[0]
	return t


func _capture() -> void:
	await RenderingServer.frame_post_draw
	var path: String = _arg("shot", "")
	if path != "":
		get_viewport().get_texture().get_image().save_png(path)
		print("capture : %s" % path)
	if _booth != null and _booth.get_desk_actor() != null:
		var a: PassengerActor = _booth.get_desk_actor()
		var sk: Skeleton3D = a.rig.skeleton
		print("tête %s cam %s fov %.1f  pied %.3f  hips %.3f  acteur %.3f" % [a.rig.head.global_position, _booth.camera.global_position, _booth.camera.fov,
				(sk.global_transform * sk.get_bone_global_pose(sk.find_bone("LeftFoot"))).origin.y,
				(sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Hips"))).origin.y, a.global_position.y])
	if _args.has("fps"):
		print("rendu : %d primitives, %d draw calls, %d objets, VRAM textures %.1f Mo" % [
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0])
	if _args.has("fps") and _frames > 0:
		print("FPS moyen : %.1f sur %d images (%s)" % [_fps_sum / _frames, _frames, RenderingServer.get_video_adapter_name()])
	get_tree().quit()


func _case_where(predicate: Callable) -> Case:
	for i: int in 40:
		var c: Case = _builder.build(i % _builder.day.passenger_count if _builder.day.passenger_count > 0 else i).case
		var ok: bool = predicate.call(c)
		if ok:
			return c
	return _builder.build(0).case


# --- Booth -------------------------------------------------------------------

func _booth_mode(state: String) -> void:
	_booth = BOOTH.instantiate()
	add_child(_booth)
	var visor: bool = state.begins_with("visor")
	_case = _case_where(func(c: Case) -> bool: return c.passenger_presented.appearance.is_face_covered() == visor)
	var at: Callable = func(t: float, f: Callable) -> void: _script.append([t, f])
	if state != "empty":
		at.call(0.2, func() -> void: EventBus.case_presented.emit(_case))
	match state:
		"visor_up":
			at.call(5.0, func() -> void:
				_case.remove_visor()
				EventBus.interrogation_answered.emit(InspectionSession.TOPIC_REMOVE_VISOR, InspectionSession.LINE_VISOR_REMOVED))
		"react":
			at.call(5.0, func() -> void: EventBus.passenger_reaction_triggered.emit(PassengerReaction.Kind.ANGRY))
		"nervous":
			at.call(5.0, func() -> void: EventBus.passenger_reaction_triggered.emit(PassengerReaction.Kind.NERVOUS))
		"shrug":
			at.call(5.0, func() -> void: EventBus.passenger_reaction_triggered.emit(PassengerReaction.Kind.SHRUG))
		"leave":
			at.call(5.0, func() -> void:
				var r: CaseResult = CaseResult.new(_case.case_id)
				r.verdict_kind = VerdictKind.Kind.DENY
				EventBus.case_resolved.emit(_case.case_id, r))


# --- Planche de passagers ----------------------------------------------------

func _lineup() -> void:
	var world: Node3D = Node3D.new()
	add_child(world)
	var env: Environment = _studio_lights(world, true)
	var spacing: float = 0.62
	for i: int in LINEUP_COUNT:
		var actor: PassengerActor = ACTOR.instantiate()
		world.add_child(actor)
		actor.position = Vector3((i - (LINEUP_COUNT - 1) * 0.5) * spacing, 0.0, 0.0)
		actor.assign(StringName("lineup_%d" % i), i, i * 97)
		actor.apply_appearance(_builder.build(i).case.passenger_presented.appearance)
		actor.set_look_target(actor.global_position + Vector3(0, 1.6, 3.0))
	var cam: Camera3D = Camera3D.new()
	cam.fov = 20.0
	cam.position = Vector3(0, 1.0, 8.2)
	cam.rotation_degrees = Vector3(-2, 0, 0)
	cam.environment = env
	world.add_child(cam)
	cam.current = true


func _studio_lights(world: Node3D, neon: bool) -> Environment:
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#0B0E14")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#3A4556")
	e.ambient_light_energy = 0.9
	env.environment = e
	world.add_child(env)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-25, 20, 0)
	key.light_color = GreyboxStyle.WORLD_KEY
	key.light_energy = 1.2
	world.add_child(key)
	if neon:
		for side: float in [-1.0, 1.0]:
			var rim: DirectionalLight3D = DirectionalLight3D.new()
			rim.rotation_degrees = Vector3(-10, 180 + 60 * side, 0)
			rim.light_color = GreyboxStyle.WORLD_TEAL_DIM if side < 0.0 else GreyboxStyle.WORLD_ROSE_DIM
			rim.light_energy = 2.0
			world.add_child(rim)
	return e


# --- Planche de portraits ----------------------------------------------------

func _portraits() -> void:
	var service: PortraitService = PortraitService.new()
	add_child(service)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#0B0E14")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(24, 24)
	grid.add_theme_constant_override(&"h_separation", 16)
	grid.add_theme_constant_override(&"v_separation", 16)
	add_child(grid)
	for i: int in LINEUP_COUNT:
		var rect: TextureRect = TextureRect.new()
		rect.custom_minimum_size = Vector2(PortraitService.SIZE)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# Photo officielle : sans coiffe ni accessoire (comme le générateur).
		var photo: PassengerAppearance = _builder.build(i).case.passenger_presented.appearance.derive({
			PassengerAppearance.SLOT_HEADWEAR: PassengerAppearance.OPTION_NONE,
			PassengerAppearance.SLOT_ACCESSORY: PassengerAppearance.OPTION_NONE})
		rect.texture = service.get_portrait(photo)
		grid.add_child(rect)
