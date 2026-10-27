## Intégration complète M4 (headless, temps réel court) : `day.tscn` avec l'UI
## réelle, le booth 3D et les services. Un cas de bout en bout piloté par l'API
## publique de l'UI et de vrais événements souris : briefing → « Suivant » →
## arrivée → documents → Mode Inspection → clic sur le visage **à travers
## l'UI** (bande B transparente) → photo → interrogatoire → tampon maintenu →
## départ. « Réduire les animations » activé (sans écriture disque).
extends GutTest

const DAY_SCENE: PackedScene = preload("res://scenes/main/day.tscn")

var scene: DayScene = null
var picked: Array[FieldRef] = []
var checked: Array[Discrepancy] = []
var answers: Array[String] = []
var _reduce_before: bool = false
var _day_before: int = 0
var _seed_before: int = 0


func before_each() -> void:
	_reduce_before = Settings.reduce_motion
	_day_before = GameState.current_day
	_seed_before = GameState.campaign_seed
	Settings.set_value(Settings.KEY_REDUCE_MOTION, true, false)
	GameState.new_campaign(20_871_315)
	picked.clear()
	checked.clear()
	answers.clear()
	EventBus.inspection_target_picked.connect(_on_picked)
	EventBus.discrepancy_checked.connect(_on_checked)
	EventBus.interrogation_answered.connect(_on_answered)
	scene = DAY_SCENE.instantiate()
	add_child_autofree(scene)


func after_each() -> void:
	EventBus.inspection_target_picked.disconnect(_on_picked)
	EventBus.discrepancy_checked.disconnect(_on_checked)
	EventBus.interrogation_answered.disconnect(_on_answered)
	Settings.set_value(Settings.KEY_REDUCE_MOTION, _reduce_before, false)
	GameState.current_day = _day_before
	GameState.campaign_seed = _seed_before


func _on_picked(ref: FieldRef) -> void:
	picked.append(ref)


func _on_checked(result: Discrepancy) -> void:
	checked.append(result)


func _on_answered(_topic: StringName, line_key: String) -> void:
	answers.append(line_key)


## Clic à une position du canvas : convertie en coordonnées fenêtre (la
## fenêtre headless est minuscule et mise à l'échelle par le stretch).
func _click(canvas_pos: Vector2) -> void:
	var pos: Vector2 = get_viewport().get_final_transform() * canvas_pos
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = pos
		event.global_position = pos
		get_viewport().push_input(event)
		await wait_physics_frames(2)


func test_scene_wiring() -> void:
	var ui: ComparisonUI = scene.ui as ComparisonUI
	assert_not_null(ui, "comparison_ui instanciée")
	assert_true(ui.portrait_provider.is_valid())
	assert_true(ui.face_rect_provider.is_valid())
	assert_lt(scene.booth_container.get_index(), scene.ui_slot.get_index(), "UI au-dessus de la bande 3D")
	assert_eq(scene.day_controller.phase, DayPhase.Kind.INTRO)
	assert_not_null(scene.briefing)
	var face: Rect2 = scene.get_face_rect()
	assert_true(scene.booth_container.get_global_rect().encloses(face), "visage dans la bande B : %s" % face)


func test_one_case_end_to_end() -> void:
	var dc: DayController = scene.day_controller
	var ui: ComparisonUI = scene.ui as ComparisonUI
	scene.briefing.close()
	assert_eq(dc.phase, DayPhase.Kind.WAITING_CASE, "briefing fermé → shift ouvert")
	ui.request_next_case()
	assert_eq(dc.phase, DayPhase.Kind.ARRIVING)
	var ok: bool = await wait_until(func() -> bool: return ui.documents_shown, 5.0)
	assert_true(ok, "documents posés sur le plan de travail")
	assert_eq(dc.phase, DayPhase.Kind.INSPECTING)
	var case: Case = dc.current_case
	if case.passenger_presented.appearance.is_face_covered():
		ui.ask(InspectionSession.TOPIC_REMOVE_VISOR)
		await wait_seconds(0.3)
	ui.set_inspection_active(true)
	assert_true(ui.inspection_active)
	# Clic réel sur le visage, à travers l'UI (bande B en MOUSE_FILTER_IGNORE).
	await wait_seconds(0.4)
	await _click(scene.get_face_rect().get_center())
	ok = await wait_until(func() -> bool: return not picked.is_empty(), 1.0)
	assert_true(ok, "le clic sur le visage atteint le booth")
	if ok:
		assert_true(picked[0].is_passenger_face())
	else:
		ui.pick(FieldRef.passenger_face())
	ui.pick(case.find_refs_by_kind(FieldDef.FieldKind.PORTRAIT)[0])
	ok = await wait_until(func() -> bool: return not checked.is_empty(), 1.0)
	assert_true(ok, "comparaison visage ↔ photo évaluée")
	assert_ne(checked[0].result, Discrepancy.Result.INCOMPARABLE)
	ui.set_inspection_active(false)
	ui.ask(InspectionSession.TOPIC_PURPOSE)
	assert_true(answers.has(InspectionSession.LINE_PURPOSE_PREFIX + String(case.passenger_presented.purpose)))
	var button: StampButton = ui.get_stamp_button(VerdictKind.Kind.APPROVE)
	button.begin_hold()
	await wait_seconds(0.6)
	button.end_hold()
	ok = await wait_until(func() -> bool: return dc.phase == DayPhase.Kind.WAITING_CASE, 5.0)
	assert_true(ok, "départ du passager → « Suivant » de nouveau possible")
	assert_eq(dc.summary.get_processed_count(), 1, "un seul verdict (maintien UI, pas de doublon)")
