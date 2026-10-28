## Intégration du booth greybox réel (headless, temps réel court) :
## `case_presented` → marche → `passenger_arrived` → `present_documents` →
## repère `documents_slot` → `documents_presented` ; `case_resolved` → sortie →
## `passenger_departed` au `ClearMark`. Idempotence par `case_id`, pool de 2.
## « Réduire les animations » activé (sans écriture disque) pour aller vite.
extends GutTest

const BOOTH_SCENE: PackedScene = preload("res://scenes/booth/booth.tscn")
const Gen := preload("res://tests/helpers/generation_fixtures.gd")

var booth: BoothDirector = null
var builder: CaseBuilder = null
var events: Array[Array] = []


func before_all() -> void:
	builder = CaseBuilder.new(Gen.data(), Gen.data().get_day(3), Gen.day_seed(0, 3))


func before_each() -> void:
	Settings.set_session_value(Settings.KEY_REDUCE_MOTION, true)
	events.clear()
	booth = BOOTH_SCENE.instantiate()
	add_child_autofree(booth)
	EventBus.passenger_arrived.connect(_on_arrived)
	EventBus.documents_presented.connect(_on_documents)
	EventBus.passenger_departed.connect(_on_departed)


func after_each() -> void:
	EventBus.passenger_arrived.disconnect(_on_arrived)
	EventBus.documents_presented.disconnect(_on_documents)
	EventBus.passenger_departed.disconnect(_on_departed)
	Settings.clear_session_value(Settings.KEY_REDUCE_MOTION)


func _on_arrived(case_id: StringName) -> void:
	events.append([&"arrived", case_id])


func _on_documents(case_id: StringName) -> void:
	events.append([&"documents", case_id])


func _on_departed(case_id: StringName) -> void:
	events.append([&"departed", case_id])


func _names_for(case_id: StringName) -> Array[StringName]:
	var names: Array[StringName] = []
	for e: Array in events:
		if e[1] == case_id:
			names.append(e[0])
	return names


func _result(case_id: StringName, kind: VerdictKind.Kind) -> CaseResult:
	var r: CaseResult = CaseResult.new(case_id)
	r.verdict_kind = kind
	return r


func test_booth_contract_nodes() -> void:
	for node_name: String in ["BoothCamera", "ArrivalPath", "DeskMark", "ExitApprovedPath", "ExitRefusedPath",
			"LookTargetPlane", "PassengerSlots", "QueueImpostors", "Glass"]:
		assert_not_null(booth.get_node_or_null("%" + node_name), node_name)
	assert_not_null(booth.exit_approved_path.get_node_or_null(^"ClearMark"))
	assert_not_null(booth.exit_refused_path.get_node_or_null(^"ClearMark"))
	assert_eq(booth.actors.size(), BoothDirector.POOL_SIZE)
	assert_almost_eq(booth.camera.fov, 14.0, 0.01)
	var end: Vector3 = booth.arrival_path.curve.get_point_position(booth.arrival_path.curve.point_count - 1)
	assert_almost_eq(end.distance_to(booth.desk_mark.position), 0.0, 0.001, "ArrivalPath finit sur DeskMark")


func test_full_case_choreography_once_per_case() -> void:
	var c: Case = builder.build(0).case
	EventBus.case_presented.emit(c)
	EventBus.case_presented.emit(c) # idempotent
	assert_eq(booth.actors.filter(func(a: PassengerActor) -> bool: return not a.is_free()).size(), 1)
	var ok: bool = await wait_until(func() -> bool: return _names_for(c.case_id).has(&"documents"), 5.0)
	assert_true(ok, "documents présentés")
	assert_eq(_names_for(c.case_id), [&"arrived", &"documents"] as Array[StringName])
	var actor: PassengerActor = booth.get_actor(c.case_id)
	assert_eq(actor.state, PassengerActor.State.AT_DESK)
	assert_true(actor.global_position.distance_to(booth.desk_mark.global_position) < 0.06, "calé sur DeskMark")
	EventBus.case_resolved.emit(c.case_id, _result(c.case_id, VerdictKind.Kind.DENY))
	ok = await wait_until(func() -> bool: return _names_for(c.case_id).has(&"departed"), 6.0)
	assert_true(ok, "passager parti")
	EventBus.case_resolved.emit(c.case_id, _result(c.case_id, VerdictKind.Kind.DENY))
	await wait_seconds(0.3)
	assert_eq(_names_for(c.case_id), [&"arrived", &"documents", &"departed"] as Array[StringName])
	assert_push_warning_count(0, "aucun watchdog : marche, repère et ClearMark ont fonctionné")


func test_pool_overlap_and_reaction_and_visor() -> void:
	var visor_case: Case = builder.build(2).case
	assert_true(visor_case.passenger_presented.appearance.is_face_covered())
	EventBus.case_presented.emit(visor_case)
	await wait_until(func() -> bool: return _names_for(visor_case.case_id).has(&"documents"), 5.0)
	var actor: PassengerActor = booth.get_actor(visor_case.case_id)
	assert_not_null(actor.rig.headwear_root.get_node_or_null(^"Visor"))
	# Retrait de la visière : le cas est muté par l'InspectionSession, puis la réponse.
	visor_case.remove_visor()
	EventBus.interrogation_answered.emit(InspectionSession.TOPIC_REMOVE_VISOR, InspectionSession.LINE_VISOR_REMOVED)
	EventBus.passenger_reaction_triggered.emit(PassengerReaction.Kind.NERVOUS)
	await wait_seconds(0.3)
	var visor: Node3D = actor.rig.headwear_root.get_node_or_null(^"Visor")
	assert_not_null(visor)
	assert_lt(visor.rotation_degrees.x, -30.0, "visière relevée")
	EventBus.case_resolved.emit(visor_case.case_id, _result(visor_case.case_id, VerdictKind.Kind.APPROVE))
	await wait_until(func() -> bool: return _names_for(visor_case.case_id).has(&"departed"), 6.0)
	# Le suivant arrive pendant que le sortant finit sa sortie (pool de 2).
	var next: Case = builder.build(3).case
	EventBus.case_presented.emit(next)
	var other: PassengerActor = booth.get_actor(next.case_id)
	assert_not_null(other)
	await wait_until(func() -> bool: return _names_for(next.case_id).has(&"documents"), 5.0)
	assert_eq(_names_for(next.case_id), [&"arrived", &"documents"] as Array[StringName])


func test_face_click_only_in_inspection_mode() -> void:
	var picked: Array[FieldRef] = []
	var on_pick: Callable = func(ref: FieldRef) -> void: picked.append(ref)
	EventBus.inspection_target_picked.connect(on_pick)
	var c: Case = builder.build(0).case
	EventBus.case_presented.emit(c)
	await wait_until(func() -> bool: return _names_for(c.case_id).has(&"documents"), 5.0)
	var actor: PassengerActor = booth.get_actor(c.case_id)
	actor.face_clicked.emit()
	assert_eq(picked.size(), 0, "hors Mode Inspection : pas de cible")
	EventBus.inspection_mode_changed.emit(true)
	actor.face_clicked.emit()
	assert_eq(picked.size(), 1)
	assert_true(picked[0].is_passenger_face())
	EventBus.inspection_mode_changed.emit(false)
	EventBus.inspection_target_picked.disconnect(on_pick)
