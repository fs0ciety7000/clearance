## M11 lot B — manette et lisibilité (UI_FLOW §9, D-085 rév.) : focus initial
## sur chaque écran, focus d'appoint et actions du guichet à la manette,
## carte d'identité redessinée et taille physique des valeurs à 4–5
## documents en 1080p (≥ 13 px) et au Steam Deck émulé (≥ 12 px).
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const CaseFactory := preload("res://tests/helpers/case_factory.gd")
const UI_SCENE: PackedScene = preload("res://scenes/ui/comparison_ui.tscn")
const DECK_SCALE: float = 1280.0 / 1920.0

var data: DataCatalog = null


func before_all() -> void:
	data = Gen.data()


func after_each() -> void:
	InputPrompts.simulate_device(InputPrompts.Device.KEYBOARD)


func _focus_owner() -> Control:
	return get_viewport().gui_get_focus_owner()


func _assert_focus_inside(screen: Control, label: String) -> void:
	var owner_control: Control = _focus_owner()
	assert_not_null(owner_control, "%s : un contrôle a le focus" % label)
	if owner_control != null:
		assert_true(screen.is_ancestor_of(owner_control), "%s : focus dans l'écran (%s)" % [label, owner_control.name])


func _press(action: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release: InputEventAction = InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)


# ---------------------------------------------------------------------------
# Focus initial de chaque écran
# ---------------------------------------------------------------------------

func test_every_day_screen_has_an_initial_focus() -> void:
	# Révélations immédiates (le chapitre ne donne le focus qu'après sa
	# révélation, pour éviter un passage accidentel).
	Settings.set_session_value(Settings.KEY_REDUCE_MOTION, true)
	var screens: Array[ScreenBase] = []
	var briefing: BriefingScreen = BriefingScreen.new()
	briefing.setup(BriefingContent.build(data.get_day(1), {}, Household.new()), Household.new(), 0, data.get_day(1))
	screens.append(briefing)
	var policy: Callable = func(_c: Case, key: CaseKey, _i: int) -> VerdictKind.Kind: return key.expected_verdict
	var summary: ShiftSummaryScreen = ShiftSummaryScreen.new()
	summary.setup(DaySimulator.simulate(data, 1, Gen.day_seed(0, 1), policy, true, true, -1, [4]), data.get_day(1))
	screens.append(summary)
	var lines: Array[ExpenseLine] = EveningService.build_lines(data.get_economy(), 2, Household.new())
	EveningService.default_selection(lines, 30)
	var evening: EveningScreen = EveningScreen.new()
	evening.setup(data.get_day(2), 30, 30, lines, Household.new(), false)
	screens.append(evening)
	var end: EndScreen = EndScreen.new()
	end.setup(Campaign.ENDING_DEMO_COMPLETE, [] as Array[Dictionary], Household.new(), 10, {} as Dictionary[StringName, Variant], 1.0)
	screens.append(end)
	var chapter: ChapterScreen = ChapterScreen.new()
	chapter.setup({} as Dictionary[StringName, Variant], 2)
	screens.append(chapter)
	for screen: ScreenBase in screens:
		add_child_autofree(screen)
		await wait_process_frames(3)
		_assert_focus_inside(screen, screen.get_class() + " " + str(screen.get_script().resource_path.get_file()))
		assert_not_null(screen.focus_guard, "focus d'appoint posé")
		# Focus perdu (clic ailleurs) : une direction le rend à l'écran.
		var owner_control: Control = _focus_owner()
		if owner_control != null:
			owner_control.release_focus()
		assert_true(screen.focus_guard.focus_default(), "focus rendu par défaut")
		_assert_focus_inside(screen, "après perte du focus")
		screen.queue_free()
		await wait_process_frames(1)
	Settings.clear_session_value(Settings.KEY_REDUCE_MOTION)


func test_pause_menu_and_options_are_navigable() -> void:
	var pause: PauseMenu = PauseMenu.new()
	add_child_autofree(pause)
	await wait_process_frames(1)
	pause.open()
	await wait_process_frames(2)
	assert_eq(_focus_owner(), pause.resume_button, "pause : REPRENDRE")
	assert_not_null(pause.find_child("PauseKeys", true, false), "glyphes Échap / Menu")
	pause.show_options()
	await wait_process_frames(2)
	assert_eq(_focus_owner(), pause.options.first_control(), "options : premier réglage")
	for key: StringName in [Settings.KEY_COLOR_VISION, Settings.KEY_HOLO_FLICKER, Settings.KEY_PAD_GLYPHS]:
		assert_true(pause.options.controls.has(key), "réglage %s présent" % key)
	assert_not_null(pause.options.scroll, "options défilantes (Deck, texte 150 %)")
	assert_true(pause.options.scroll.follow_focus, "le défilement suit le focus")
	pause.close()


func test_options_color_vision_choice_drives_setting() -> void:
	var before: float = Settings.get_float(Settings.KEY_COLOR_VISION)
	var panel: OptionsPanel = OptionsPanel.new()
	add_child_autofree(panel)
	await wait_process_frames(1)
	var none: Button = panel.controls[Settings.KEY_COLOR_VISION] as Button
	var row: Node = none.get_parent()
	(row.get_child(2) as Button).button_pressed = true
	assert_eq(Settings.color_vision, 2, "tritanopie choisie")
	assert_eq(Palette.mode, Palette.Mode.TRITAN)
	none.button_pressed = true
	assert_eq(Settings.color_vision, 0)
	var flicker: Button = panel.controls[Settings.KEY_HOLO_FLICKER] as Button
	flicker.button_pressed = false
	assert_false(Settings.holo_flicker)
	flicker.button_pressed = true
	Settings.set_value(Settings.KEY_COLOR_VISION, before, false)


# ---------------------------------------------------------------------------
# Guichet à la manette
# ---------------------------------------------------------------------------

func _booth(day_number: int, docs: Array[StringName], extra: Array[StringName] = []) -> ComparisonUI:
	var ui: ComparisonUI = UI_SCENE.instantiate() as ComparisonUI
	add_child_autofree(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ui.size = Vector2(1920, 1080)
	ui.workbench.reduce_motion = true
	var day: DayDef = data.get_day(day_number)
	EventBus.day_started.emit(day, day.rule_set.build_rulebook())
	EventBus.day_phase_changed.emit(DayPhase.Kind.WAITING_CASE, &"")
	var case: Case = CaseFactory.valid_case(docs)
	for doc_id: StringName in extra:
		case.documents.append(CaseFactory.document(doc_id, case.passenger_presented))
	case.index = 0
	EventBus.case_presented.emit(case)
	EventBus.day_phase_changed.emit(DayPhase.Kind.ARRIVING, case.case_id)
	EventBus.day_phase_changed.emit(DayPhase.Kind.INSPECTING, case.case_id)
	EventBus.documents_presented.emit(case.case_id)
	return ui


func test_booth_default_focus_follows_the_phase() -> void:
	var ui: ComparisonUI = UI_SCENE.instantiate() as ComparisonUI
	add_child_autofree(ui)
	await wait_process_frames(1)
	var day: DayDef = data.get_day(2)
	EventBus.day_started.emit(day, day.rule_set.build_rulebook())
	EventBus.day_phase_changed.emit(DayPhase.Kind.WAITING_CASE, &"")
	await wait_process_frames(1)
	assert_eq(ui.default_focus_control(), ui.tool_bar.next_button, "guichet en attente : SUIVANT")
	assert_true(ui.focus_default())
	assert_eq(_focus_owner(), ui.tool_bar.next_button)


func test_gamepad_inspection_focuses_fields_and_cycles_documents() -> void:
	var ui: ComparisonUI = _booth(12, [CaseFactory.ID_CARD, CaseFactory.PERMIT, CaseFactory.BIOSCAN], [&"work_contract"])
	await wait_seconds(1.0)
	InputPrompts.simulate_device(InputPrompts.Device.XBOX)
	assert_true(ui.tool_bar.get_status_text().contains("LT"), "ligne d'état en glyphes manette : %s" % ui.tool_bar.get_status_text())
	ui.set_inspection_active(true)
	await wait_process_frames(2)
	var focused: InspectableItem = _focus_owner() as InspectableItem
	assert_not_null(focused, "inspection à la manette : un champ a le focus (aucun curseur à viser)")
	# Ⓐ sur le champ : champ A choisi.
	var accept: InputEventAction = InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	focused._gui_input(accept)
	assert_not_null(ui.selection.a, "Ⓐ choisit le champ A")
	ui.cancel()
	# Stick droit → : document suivant devant, le focus suit.
	var before: DocumentView = ui.workbench.front_view()
	assert_true(ui.workbench.cycle_front(1))
	var after: DocumentView = ui.workbench.front_view()
	assert_ne(after, before, "document suivant au premier plan")
	assert_true(after.is_ancestor_of(_focus_owner()), "le focus suit le document")
	# Focus posé sur un champ d'un document de pile : il passe devant.
	for view: DocumentView in ui.workbench.views:
		if not ui.workbench.is_front(view):
			view.get_items()[0].grab_focus()
			await wait_process_frames(1)
			assert_true(ui.workbench.is_front(view), "%s : focus → document devant" % view.get_document_id())
			break
	InputPrompts.simulate_device(InputPrompts.Device.KEYBOARD)
	assert_true(ui.tool_bar.get_status_text().length() > 0)


func test_gamepad_zoom_and_face_share_the_right_stick_by_context() -> void:
	var ui: ComparisonUI = _booth(2, [CaseFactory.ID_CARD, CaseFactory.PERMIT])
	await wait_seconds(1.0)
	var r3: InputEventJoypadButton = InputEventJoypadButton.new()
	r3.button_index = JOY_BUTTON_RIGHT_STICK
	r3.pressed = true
	var front: DocumentView = ui.workbench.front_view()
	assert_not_null(front)
	ui._input(r3)
	await wait_seconds(0.4)
	assert_gt(front.zoom, 1.0, "hors inspection, R3 : loupe sur le document de devant")
	ui._input(r3)
	await wait_seconds(0.4)
	ui.set_inspection_active(true)
	ui._input(r3)
	assert_true(ui.selection.a != null and ui.selection.a.is_passenger_face(), "en inspection, R3 : visage (champ A)")


# ---------------------------------------------------------------------------
# Carte d'identité lisible (D-085 rév.)
# ---------------------------------------------------------------------------

func _physical_value_px(view: DocumentView, screen: float) -> float:
	var smallest: float = INF
	for item: DocFieldView in view.fields:
		smallest = minf(smallest, item.value_font_px() * view.get_global_transform().get_scale().x * screen)
	return smallest


func test_id_card_fields_flow_below_the_portrait() -> void:
	var ui: ComparisonUI = _booth(2, [CaseFactory.ID_CARD])
	await wait_seconds(0.6)
	var card: DocumentView = ui.workbench.views[0]
	var below: Node = card.find_child("BelowPortrait", true, false)
	assert_not_null(below, "champs sous la photo, sur toute la largeur")
	var mrz: DocFieldView = card.find_item(FieldRef.new(CaseFactory.ID_CARD, &"mrz")) as DocFieldView
	if mrz != null:
		assert_false(mrz.display_label.is_empty(), "MRZ garde son nom (infobulle, messages)")
		var shown: Array[String] = []
		for label: Node in mrz.find_children("*", "Label", true, false):
			if (label as Label).visible:
				shown.append((label as Label).text)
		assert_eq(shown.size(), 1, "bande MRZ : la valeur seule, sans ligne de libellé")
	# Plus de colonne vide sous la photo : la carte est plus basse que photo + 7 lignes.
	assert_lt(card.get_combined_minimum_size().y, 600.0, "carte plus basse (1080p)")


func test_document_values_reach_13_px_at_1080p_with_four_and_five_documents() -> void:
	for extra: Array[StringName] in [[&"work_contract"] as Array[StringName], [&"work_contract", &"queue_ticket"] as Array[StringName]]:
		var ui: ComparisonUI = _booth(20, [CaseFactory.ID_CARD, CaseFactory.PERMIT, CaseFactory.BIOSCAN], extra)
		ui.emulate_screen_scale(1.0)
		ui.workbench.relayout()
		await wait_seconds(1.0)
		for view: DocumentView in ui.workbench.views:
			if ui.workbench.is_front(view):
				assert_gte(_physical_value_px(view, 1.0), 13.0, "1080p, %d documents : %s ≥ 13 px" % [ui.workbench.views.size(), view.get_document_id()])
		ui.queue_free()
		await wait_process_frames(1)


func test_document_values_reach_12_px_on_steam_deck_with_four_and_five_documents() -> void:
	for extra: Array[StringName] in [[&"work_contract"] as Array[StringName], [&"work_contract", &"queue_ticket"] as Array[StringName]]:
		var ui: ComparisonUI = _booth(20, [CaseFactory.ID_CARD, CaseFactory.PERMIT, CaseFactory.BIOSCAN], extra)
		# Deck : fenêtre 1280×800 → vue logique 1920×1200 (étirement `expand`).
		ui.size = Vector2(1920, 1200)
		ui.emulate_screen_scale(DECK_SCALE)
		ui.workbench.relayout()
		await wait_seconds(1.0)
		for view: DocumentView in ui.workbench.views:
			if ui.workbench.is_front(view):
				assert_gte(_physical_value_px(view, DECK_SCALE), 12.0, "Deck, %d documents : %s ≥ 12 px" % [ui.workbench.views.size(), view.get_document_id()])
		ui.queue_free()
		await wait_process_frames(1)
