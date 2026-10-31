## M14 lot C — vie dans le Hall (B86 → B88 ; M14 §4.2–§4.6 ; D-187, D-188, D-190) :
## file réelle sur un **vrai** roster du jour, débordement EV-06, qualité Bas,
## Gardes (calendrier, arrêt pendant l'inspection, coupure, traversée du J27),
## chemin de patrouille hors du rectangle projeté du visage (+15 %) au cadrage
## normal et au travelling (M-15), Hall par acte (uniformes, bannière) et bande
## 3D en pause pour les cinématiques.
extends GutTest

const BOOTH_SCENE: PackedScene = preload("res://scenes/booth/booth.tscn")
const Gen := preload("res://tests/helpers/generation_fixtures.gd")

var booth: BoothDirector = null
var host: SubViewport = null
var builder: CaseBuilder = null


func before_all() -> void:
	builder = CaseBuilder.new(Gen.data(), Gen.data().get_day(3), Gen.day_seed(0, 3))


func before_each() -> void:
	Settings.set_session_value(Settings.KEY_REDUCE_MOTION, true)
	host = SubViewport.new()
	host.size = Vector2i(1920, 376)
	add_child_autofree(host)
	booth = BOOTH_SCENE.instantiate()
	host.add_child(booth)


func after_each() -> void:
	Settings.clear_session_value(Settings.KEY_REDUCE_MOTION)
	Settings.clear_session_value(Settings.KEY_GRAPHICS_QUALITY)


func _upcoming(processed: int, total: int) -> Array[QueueSilhouette]:
	return QueueSilhouette.upcoming(builder.roster, processed, total)


# --- File réelle (VH-1 → VH-3) ------------------------------------------------------

func test_queue_shows_real_upcoming_passengers_and_empties() -> void:
	var queue: QueueImpostors = booth.queue
	var total: int = mini(builder.roster.size(), 9)
	assert_gt(total, 3, "roster du jour")
	queue.apply_queue(0, total, _upcoming(0, total))
	assert_true(queue.driven)
	# Tête de file + min(restants − 1, 6) silhouettes.
	assert_eq(queue.shown_indices().size(), 1 + QueueSilhouette.visible_count(0, total, QueueImpostors.PLACES))
	for index: int in queue.shown_indices():
		var sil: QueueSilhouette = queue.person(index)["sil"]
		var expected: QueueSilhouette = QueueSilhouette.from_appearance(index, builder.roster.get_entry(index).appearance)
		assert_true(sil.equals(expected), "silhouette %d = passager réel du roster" % index)
	for processed: int in range(1, total):
		queue.apply_queue(processed, total, _upcoming(processed, total))
		assert_eq(queue.visible_queue_count(), mini(total - processed - 1, QueueImpostors.PLACES))
		assert_eq(queue.shown_indices().size(), 1 + queue.visible_queue_count(), "tête + file au J%d" % processed)
	# Dernier passager : file vide derrière lui ; présenté → plus rien.
	assert_eq(queue.visible_queue_count(), 0)
	queue.hide_head()
	var counts: Dictionary[StringName, int] = queue.instance_counts()
	var shown: int = 0
	for shape: StringName in counts:
		shown += counts[shape]
	assert_eq(shown, 1, "la tête reste une instance (masquée, échelle nulle)")


func test_queue_shapes_split_meshes_and_tints_follow_palette() -> void:
	var queue: QueueImpostors = booth.queue
	var sils: Array[QueueSilhouette] = [
		QueueSilhouette.make(0, 2, QueueSilhouette.SHAPE_BARE, 0),
		QueueSilhouette.make(1, 5, QueueSilhouette.SHAPE_HOOD, 1),
		QueueSilhouette.make(2, 7, QueueSilhouette.SHAPE_CAP, -2),
		QueueSilhouette.make(3, 0, QueueSilhouette.SHAPE_HOOD, 0),
	]
	queue.apply_queue(0, 4, sils)
	var counts: Dictionary[StringName, int] = queue.instance_counts()
	assert_eq(counts[QueueSilhouette.SHAPE_BARE], 1)
	assert_eq(counts[QueueSilhouette.SHAPE_HOOD], 2)
	assert_eq(counts[QueueSilhouette.SHAPE_CAP], 1)
	var tint: Color = QueueImpostors.tint_of(5)
	var raw: Color = Color(String(GreyboxStyle.PALETTES[5][0]))
	assert_lt(tint.s, raw.s, "teinte désaturée")
	assert_almost_eq(tint.get_luminance(), raw.get_luminance(), 0.05)


func test_overflow_only_during_crowd_event_and_not_in_low_quality() -> void:
	var queue: QueueImpostors = booth.queue
	var sils: Array[QueueSilhouette] = []
	for i: int in QueueSilhouette.MAX_UPCOMING:
		sils.append(QueueSilhouette.make(i, i % 12, QueueSilhouette.SHAPE_BARE, 0))
	queue.apply_queue(0, 20, sils)
	assert_eq(queue.visible_queue_count(), 6, "sans EV-06 : 6 places")
	var plan: StationEventPlan = StationEventPlan.new()
	plan.event = StationEventDef.new()
	plan.event.id = &"ev_06"
	EventBus.station_event_started.emit(plan)
	queue.apply_queue(0, 20, sils)
	assert_eq(queue.visible_queue_count(), 9, "EV-06 : +3 places de débordement")
	Settings.set_session_value(Settings.KEY_GRAPHICS_QUALITY, 0.0)
	EventBus.settings_changed.emit(Settings.KEY_GRAPHICS_QUALITY, 0.0)
	queue.apply_queue(0, 20, sils)
	assert_eq(queue.visible_queue_count(), 6, "Bas : pas de débordement")
	var counts: Dictionary[StringName, int] = queue.instance_counts()
	assert_eq(counts[QueueSilhouette.SHAPE_BARE], 7, "Bas : un seul maillage")
	EventBus.station_event_ended.emit(plan)


func test_reduce_motion_freezes_sway_and_step() -> void:
	var mat: ShaderMaterial = booth.queue.material_override as ShaderMaterial
	assert_eq(float(mat.get_shader_parameter(&"motion")), 0.0, "reduce_motion actif dans before_each")
	Settings.set_session_value(Settings.KEY_REDUCE_MOTION, false)
	EventBus.settings_changed.emit(Settings.KEY_REDUCE_MOTION, false)
	assert_eq(float(mat.get_shader_parameter(&"motion")), 1.0)


# --- Gardes (VH-4, VH-5) -------------------------------------------------------------

func test_guard_schedule_by_period() -> void:
	var expect: Dictionary = {
		1: [0, 1], 7: [0, 1], 8: [1, 1], 11: [1, 2], 16: [2, 2], 21: [2, 1], 27: [2, 1], 30: [3, 0],
	}
	for day: int in expect:
		var s: Dictionary = HallAmbience.for_day(day)
		assert_eq([int(s["posts"]), int(s["patrol"])], expect[day], "J%d postes / patrouille" % day)
	assert_true(HallAmbience.for_day(27)["arbiter"])
	assert_false(HallAmbience.for_day(26)["arbiter"])
	assert_eq(int(HallAmbience.for_day(5, &"garde")["posts"]), 1)
	assert_eq(int(HallAmbience.for_day(5, &"garde")["patrol"]), 1)
	var worlds: Dictionary = {&"a": 1, &"b": 0, &"c": 1, &"d": 1}
	for w: StringName in worlds:
		var s: Dictionary = HallAmbience.for_day(31, &"epilogue", w)
		assert_eq(int(s["posts"]), worlds[w], "J31 %s" % w)
		assert_eq(int(s["patrol"]), 0)
	assert_eq(int(HallAmbience.for_day(31, &"epilogue", &"d")["post_mode"]), HallAmbience.POST_CIVIL)


func test_patrol_stops_while_inspecting_and_during_blackout() -> void:
	var guards: HallGuards = booth.hall_guards
	guards.configure(HallAmbience.for_day(12), 3, 2)
	assert_lte(guards.instance_total(), 3)
	guards._wait = 0.0
	guards._process(0.1)
	assert_eq(guards.patrol_state, &"out")
	var x0: float = guards.patrol_x
	EventBus.day_phase_changed.emit(DayPhase.Kind.INSPECTING, &"c1")
	guards._process(1.0)
	assert_eq(guards.patrol_x, x0, "à l'arrêt pendant l'inspection")
	guards.set_inspecting(false)
	guards._process(1.0)
	assert_lt(guards.patrol_x, x0, "repart quand le passager s'en va")
	guards.set_dimmed(true)
	var x1: float = guards.patrol_x
	guards._process(1.0)
	assert_eq(guards.patrol_x, x1, "coupure : patrouille arrêtée")
	assert_eq(guards.multimesh.get_instance_custom_data(0).a, 1.0, "silhouettes assombries")


func test_low_quality_keeps_posts_without_patrol() -> void:
	var guards: HallGuards = booth.hall_guards
	guards.configure(HallAmbience.for_day(18), 5, 0)
	assert_eq(guards.patrol_count(), 0)
	assert_eq(guards.instance_total(), 2)


func test_arbiter_crossing_on_j27_announcement() -> void:
	var day: DayDef = Gen.data().get_day(3).duplicate() as DayDef
	day.day_number = 27
	booth.apply_act_ambience(day)
	EventBus.hall_announced.emit(BoothDirector.ARBITER_ANNOUNCEMENT)
	assert_true(booth.hall_guards.arbiter_active)
	assert_eq(booth.hall_guards.instance_total(), 2 + 1 + 2, "postes + patrouilleur + Arbitre et escorte (1 draw)")
	for i: int in 200:
		booth.hall_guards._process(0.25)
	assert_false(booth.hall_guards.arbiter_active, "traversée terminée")


## M-15 : aucun point du chemin (silhouette entière : pieds → tête, ±0,3 m) dans
## le rectangle projeté du visage + 15 %, cadrage normal et travelling, deux tailles.
func test_patrol_and_arbiter_paths_stay_out_of_face_frame() -> void:
	var samples: Array[Vector3] = []
	for side: int in [-1, 1]:
		var pts: Array[Vector3] = HallGuards.path_points(side)
		for k: int in 21:
			samples.append(pts[0].lerp(pts[1], k / 20.0))
	for k: int in 21:
		var a: Vector2 = HallGuards.arbiter_point(k / 20.0)
		samples.append(Vector3(a.x, 0, a.y))
		samples.append(Vector3(a.x + 0.45, 0, a.y + 0.25))
	for post: Vector3 in HallGuards.POSTS:
		samples.append(Vector3(post.x, 0, post.y))
	for size: Vector2i in [Vector2i(1920, 376), Vector2i(1280, 251)]:
		host.size = size
		for zoom: bool in [false, true]:
			_frame_camera(zoom)
			var face: Rect2 = booth.get_face_viewport_rect()
			assert_gt(face.size.x, 1.0, "rectangle du visage")
			var grown: Rect2 = face.grow_individual(face.size.x * 0.15, face.size.y * 0.15, face.size.x * 0.15, face.size.y * 0.15)
			for p: Vector3 in samples:
				var body: Rect2 = _body_rect(p)
				assert_false(body.intersects(grown), "%s hors visage (%s, travelling %s)" % [p, size, zoom])


func _frame_camera(zoom: bool) -> void:
	var cam: Camera3D = booth.camera
	cam.transform = booth._camera_rest
	cam.fov = BoothDirector.BASE_FOV
	if zoom:
		# Travelling visage (BoothDirector._update_camera, t = 1) vers la tête au guichet.
		var head: Vector3 = booth.desk_mark.global_position + Vector3(0, 1.62, 0)
		var head_local: Vector3 = cam.get_parent_node_3d().global_transform.affine_inverse() * head
		var dolly: Vector3 = booth._camera_rest.origin + Vector3(0, 0, -BoothDirector.FACE_DOLLY)
		cam.transform = Transform3D(Basis.looking_at(head_local - dolly, Vector3.UP), dolly)
		cam.fov = BoothDirector.FACE_FOV


func _body_rect(feet: Vector3) -> Rect2:
	var cam: Camera3D = booth.camera
	var r: Rect2 = Rect2(cam.unproject_position(feet), Vector2.ZERO)
	for dx: float in [-0.32, 0.32]:
		for y: float in [0.0, 0.95, 1.9]:
			r = r.expand(cam.unproject_position(feet + Vector3(dx, y, 0.0)))
	return r


# --- Hall par acte (VH-7, VH-8) ---------------------------------------------------------

func test_act_ambience_sets_uniforms_and_banner() -> void:
	var emissive: ShaderMaterial = (booth.get_node(^"Decor/Emissive") as MeshInstance3D).material_override as ShaderMaterial
	var cases: Dictionary = {
		1: [HallAmbience.GRAFFITI_VISIBLE, HallAmbience.DEPARTURES_ON_TIME, HallAmbience.BANNER_NONE],
		11: [HallAmbience.GRAFFITI_COVERED, HallAmbience.DEPARTURES_ON_TIME, HallAmbience.BANNER_QUOTA],
		21: [HallAmbience.GRAFFITI_BIG, HallAmbience.DEPARTURES_ON_TIME, HallAmbience.BANNER_ENQUETE],
		28: [HallAmbience.GRAFFITI_BIG, HallAmbience.DEPARTURES_LAST_ROTATION, HallAmbience.BANNER_ENQUETE],
		30: [HallAmbience.GRAFFITI_BIG_PLUS, HallAmbience.DEPARTURES_LAST_ROTATION, HallAmbience.BANNER_ENQUETE],
	}
	var base_teal: float = (booth.get_node(^"Lights/HallTeal") as OmniLight3D).light_energy
	for day_number: int in cases:
		var day: DayDef = Gen.data().get_day(3).duplicate() as DayDef
		day.day_number = day_number
		booth.apply_act_ambience(day)
		var want: Array = cases[day_number]
		assert_eq(int(emissive.get_shader_parameter(&"graffiti_state")), want[0], "graffiti J%d" % day_number)
		assert_eq(int(emissive.get_shader_parameter(&"departures_status")), want[1], "départs J%d" % day_number)
		var has_banner: bool = want[2] != HallAmbience.BANNER_NONE
		assert_eq(booth.banner != null and booth.banner.visible, has_banner, "bannière J%d" % day_number)
	var teal: float = (booth.get_node(^"Lights/HallTeal") as OmniLight3D).light_energy
	assert_almost_eq(teal, base_teal * 0.9, 0.001, "Acte III : −10 %")
	# Le monde du J31 est porté par le DayDef d'épilogue.
	var epi: DayDef = Gen.data().get_day(3).duplicate() as DayDef
	epi.day_number = 31
	epi.mode = DayDef.MODE_EPILOGUE
	epi.epilogue_world = &"c"
	booth.apply_act_ambience(epi)
	assert_eq(int(emissive.get_shader_parameter(&"graffiti_state")), HallAmbience.GRAFFITI_GLASS)
	assert_true(booth.banner.visible)


func test_crowd_event_delays_transit_line() -> void:
	var day: DayDef = Gen.data().get_day(3).duplicate() as DayDef
	day.day_number = 13
	booth.apply_act_ambience(day)
	var plan: StationEventPlan = StationEventPlan.new()
	plan.event = StationEventDef.new()
	plan.event.id = &"ev_06"
	EventBus.station_event_started.emit(plan)
	var emissive: ShaderMaterial = (booth.get_node(^"Decor/Emissive") as MeshInstance3D).material_override as ShaderMaterial
	assert_eq(int(emissive.get_shader_parameter(&"departures_status")), HallAmbience.DEPARTURES_DELAYED)
	EventBus.station_event_ended.emit(plan)
	assert_eq(int(emissive.get_shader_parameter(&"departures_status")), HallAmbience.DEPARTURES_ON_TIME)


func test_curfew_dims_hall_after_16h_from_j16() -> void:
	var day: DayDef = Gen.data().get_day(3).duplicate() as DayDef
	day.day_number = 17
	booth.apply_act_ambience(day)
	var light: OmniLight3D = booth.get_node(^"Lights/HallRose")
	var before: float = light.light_energy
	EventBus.day_clock_ticked.emit(day.duration_sec * 0.2) # 80 % écoulé : après 16:00
	assert_almost_eq(light.light_energy, before / 0.9 * 0.85, 0.001)


func test_rendering_pause_disables_booth_viewport() -> void:
	host.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	booth.set_rendering_paused(true)
	assert_eq(host.render_target_update_mode, SubViewport.UPDATE_DISABLED)
	assert_true(booth.is_rendering_paused())
	booth.set_rendering_paused(false)
	assert_eq(host.render_target_update_mode, SubViewport.UPDATE_ALWAYS)
