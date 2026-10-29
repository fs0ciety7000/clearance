## M11 lot C — écrans de partie (UI_FLOW §8.5, §9.4) : titre (Continuer /
## Nouvelle partie / Charger), Nouvelle partie (emplacement, écrasement,
## difficulté), Charger (reprendre, jour passé, suppression en deux temps),
## mode Récit dans le jeu (puce, horloge sans alerte, Fermer le guichet,
## citations sans amende, Pause > Options « Passer en mode Dur »), tutoriel
## interactif du J1. Focus initial et retour Ⓑ de chaque écran.
## Les sauvegardes vivent dans le dossier de test (`SaveService.use_root`,
## `tests/helpers/gut_pre_run.gd`), jamais dans `user://saves`.
extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const DAY_SCENE: PackedScene = preload("res://scenes/main/day.tscn")

var _story_events: Array[StringName] = []


func before_each() -> void:
	Settings.set_session_value(Settings.KEY_REDUCE_MOTION, true)
	for slot: int in range(1, SaveService.SLOT_COUNT + 1):
		SaveService.delete_slot(slot)
	TutorialOverlay.pending = false
	_story_events.clear()


func after_each() -> void:
	for slot: int in range(1, SaveService.SLOT_COUNT + 1):
		SaveService.delete_slot(slot)
	Settings.clear_session_value(Settings.KEY_REDUCE_MOTION)
	Settings.set_value(Settings.KEY_TUTORIAL, true)
	TutorialOverlay.pending = false
	InputPrompts.simulate_device(InputPrompts.Device.KEYBOARD)
	GameState.new_campaign(1)


## Partie écrite dans `slot` : jours 1..`days` (un instantané par matin).
func _write_slot(slot: int, days: int, story: bool = false, ending: String = "") -> void:
	var data: Dictionary = {"campaign_seed": 500 + slot, "credits": 20 + slot, "score_total": 0, "citations": 0,
		"narrative_flags": {}, "day_history": [], "household": Household.new().to_dict(), "case_memory": {},
		"difficulty": "story" if story else "hard", "play_time_sec": 600 * slot}
	for day: int in range(1, days + 1):
		data["current_day"] = day
		SaveService.save_slot(data, slot, SaveService.DEFAULT_DIR, "2026-10-2%dT10:%02d:00" % [slot, day])
	if not ending.is_empty():
		SaveService.mark_ended(slot, ending)


func _focus_owner() -> Control:
	return get_viewport().gui_get_focus_owner()


func _press_cancel() -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	Input.parse_input_event(event)
	var release: InputEventAction = InputEventAction.new()
	release.action = &"ui_cancel"
	release.pressed = false
	Input.parse_input_event(release)


func _main() -> Control:
	var main: Control = MAIN_SCENE.instantiate()
	main.set(&"change_scene", false)
	add_child_autofree(main)
	await wait_process_frames(3)
	return main


# ---------------------------------------------------------------------------
# Titre
# ---------------------------------------------------------------------------

func test_title_without_saves_focuses_new_game_and_disables_continue_and_load() -> void:
	var main: Control = await _main()
	var continue_button: Button = main.get(&"continue_button")
	var new_game_button: Button = main.get(&"new_game_button")
	var load_button: Button = main.get(&"load_button")
	assert_true(continue_button.disabled, "Continuer désactivé sans partie active")
	assert_eq(continue_button.focus_mode, Control.FOCUS_NONE, "bouton désactivé jamais focalisé")
	assert_true(load_button.disabled, "Charger désactivé sans partie")
	assert_eq(_focus_owner(), new_game_button, "focus initial : NOUVELLE PARTIE")


func test_title_continue_targets_latest_active_slot() -> void:
	_write_slot(1, 3)
	_write_slot(2, 7, true)
	_write_slot(3, 9, false, "f6_drift")
	var main: Control = await _main()
	var continue_button: Button = main.get(&"continue_button")
	assert_false(continue_button.disabled)
	assert_eq(_focus_owner(), continue_button, "focus initial : CONTINUER")
	assert_string_contains(continue_button.text, "7", "partie active la plus récente (emplacement 2, jour 7)")
	assert_false((main.get(&"load_button") as Button).disabled)
	assert_true(main.call(&"continue_game"))
	assert_eq(GameState.active_slot, 2)
	assert_eq(GameState.current_day, 7)
	assert_true(GameState.is_story_mode())


# ---------------------------------------------------------------------------
# Nouvelle partie
# ---------------------------------------------------------------------------

func test_new_game_focus_on_first_free_slot_and_cancel_returns_to_title() -> void:
	_write_slot(1, 4)
	var main: Control = await _main()
	var ng: NewGameScreen = main.call(&"open_new_game")
	await wait_process_frames(3)
	assert_eq(_focus_owner(), ng.slot_buttons[1], "focus : premier emplacement libre (2)")
	_press_cancel()
	await wait_process_frames(3)
	assert_true(not is_instance_valid(ng) or ng.is_closing(), "Ⓑ : retour au titre")
	assert_null(main.get(&"screen"))
	assert_eq(_focus_owner(), main.get(&"new_game_button"), "focus rendu à NOUVELLE PARTIE")


func test_new_game_all_slots_occupied_asks_confirmation_then_difficulty() -> void:
	_write_slot(1, 4)
	_write_slot(2, 12)
	_write_slot(3, 30, false, "f10_pont")
	var main: Control = await _main()
	var ng: NewGameScreen = main.call(&"open_new_game")
	await wait_process_frames(3)
	assert_eq(_focus_owner(), ng.slot_buttons[0], "tous occupés : premier emplacement")
	ng.choose_slot(2)
	await wait_process_frames(3)
	assert_not_null(ng.dialog, "écrasement : confirmation")
	assert_eq(_focus_owner(), ng.dialog.cancel_button, "focus sur ANNULER")
	# Ⓑ annule la boîte, pas l'écran.
	_press_cancel()
	await wait_process_frames(3)
	assert_null(ng.dialog)
	assert_false(ng.is_closing())
	assert_eq(ng.stage, NewGameScreen.Stage.SLOT)
	assert_eq(_focus_owner(), ng.slot_buttons[1], "focus rendu à l'emplacement 2")
	assert_eq(SaveService.as_int(SaveService.load_meta(2).get("current_day", 0)), 12, "rien d'écrasé")
	ng.choose_slot(2)
	await wait_process_frames(2)
	ng.dialog.accept()
	await wait_process_frames(3)
	assert_eq(ng.stage, NewGameScreen.Stage.DIFFICULTY)
	assert_eq(ng.chosen_slot, 2)
	assert_eq(_focus_owner(), ng.hard_button, "difficulté : Dur par défaut")
	# Ⓑ : retour au choix de l'emplacement.
	_press_cancel()
	await wait_process_frames(3)
	assert_eq(ng.stage, NewGameScreen.Stage.SLOT)
	assert_eq(_focus_owner(), ng.slot_buttons[1])
	# Récit dans l'emplacement 2 : l'ancienne partie est remplacée, l'emplacement occupé aussitôt.
	ng.show_difficulty(2)
	await wait_process_frames(2)
	ng.story_button.pressed.emit()
	assert_eq(GameState.active_slot, 2)
	assert_eq(GameState.current_day, 1)
	assert_true(GameState.is_story_mode())
	var meta: Dictionary = SaveService.load_meta(2)
	assert_eq(SaveService.as_int(meta.get("current_day", 0)), 1, "emplacement occupé dès la création")
	assert_eq(str(meta.get("difficulty", "")), "story")
	assert_eq(SaveService.list_snapshots(2), PackedInt32Array([1]), "anciens jours supprimés")
	assert_eq(SaveService.as_int(SaveService.load_meta(3).get("current_day", 0)), 30, "autres emplacements intacts")
	assert_true(TutorialOverlay.pending, "J1 : tutoriel demandé (réglage actif)")


func test_new_game_free_slot_skips_confirmation() -> void:
	var main: Control = await _main()
	var ng: NewGameScreen = main.call(&"open_new_game")
	await wait_process_frames(3)
	ng.slot_buttons[0].pressed.emit()
	await wait_process_frames(2)
	assert_null(ng.dialog)
	assert_eq(ng.stage, NewGameScreen.Stage.DIFFICULTY)
	Settings.set_value(Settings.KEY_TUTORIAL, false)
	ng.hard_button.pressed.emit()
	assert_false(GameState.is_story_mode())
	assert_eq(GameState.active_slot, 1)
	assert_false(TutorialOverlay.pending, "tutoriel désactivé dans Options : pas proposé")


# ---------------------------------------------------------------------------
# Charger
# ---------------------------------------------------------------------------

func test_load_screen_cards_focus_and_cancel() -> void:
	_write_slot(1, 5)
	_write_slot(3, 30, false, "f10_pont")
	var main: Control = await _main()
	var load_screen: LoadScreen = main.call(&"open_load")
	await wait_process_frames(3)
	assert_eq(load_screen.cards.size(), 3)
	assert_true(load_screen.cards[1].is_free())
	assert_true(load_screen.cards[2].is_ended())
	assert_false(load_screen.resume_buttons.has(3), "partie terminée : pas de REPRENDRE")
	assert_true(load_screen.day_buttons.has(3), "partie terminée : jour passé possible")
	var ending: Label = load_screen.cards[2].find_child("Ending", true, false) as Label
	assert_not_null(ending, "nom de la fin affiché")
	assert_false(ending.text.contains("f10"), "nom lisible, pas l'identifiant : %s" % ending.text)
	assert_eq(_focus_owner(), load_screen.resume_buttons[1], "focus : REPRENDRE de la partie active la plus récente")
	_press_cancel()
	await wait_process_frames(3)
	assert_null(main.get(&"screen"), "Ⓑ : retour au titre")
	assert_eq(_focus_owner(), main.get(&"load_button"))


func test_load_resume_past_day_with_warning_and_single_timeline() -> void:
	_write_slot(1, 6)
	var main: Control = await _main()
	var load_screen: LoadScreen = main.call(&"open_load")
	await wait_process_frames(3)
	load_screen.day_buttons[1].pressed.emit()
	await wait_process_frames(3)
	assert_eq(load_screen.picker_slot, 1)
	assert_eq(load_screen.picker_buttons.size(), 6, "un matin par jour")
	assert_not_null(load_screen.find_child("Warning", true, false), "avertissement « jours suivants remplacés »")
	assert_eq(_focus_owner(), load_screen.picker_buttons[6], "focus : dernier jour")
	# Ⓑ ferme la liste, focus rendu au bouton du jour passé.
	_press_cancel()
	await wait_process_frames(3)
	assert_eq(load_screen.picker_slot, SaveService.NO_SLOT)
	assert_false(load_screen.is_closing())
	assert_eq(_focus_owner(), load_screen.day_buttons[1])
	load_screen.open_day_picker(1)
	await wait_process_frames(2)
	load_screen.choose_day(3)
	await wait_process_frames(3)
	assert_not_null(load_screen.dialog, "jour antérieur : confirmation")
	assert_eq(_focus_owner(), load_screen.dialog.cancel_button, "focus sur ANNULER")
	load_screen.dialog.accept()
	await wait_process_frames(2)
	assert_eq(GameState.current_day, 3, "matin du jour 3 chargé")
	assert_eq(GameState.active_slot, 1)
	assert_eq(SaveService.list_snapshots(1).size(), 6, "rien d'écrit avant la soirée")
	# La soirée suivante remplace les jours postérieurs (une seule ligne de temps).
	GameState.current_day = 4
	GameState.save_to_slot()
	assert_eq(SaveService.list_snapshots(1), PackedInt32Array([1, 2, 3, 4]))


func test_load_delete_is_two_step() -> void:
	_write_slot(2, 3)
	var main: Control = await _main()
	var load_screen: LoadScreen = main.call(&"open_load")
	await wait_process_frames(3)
	load_screen.delete_buttons[2].pressed.emit()
	assert_true(load_screen.is_delete_armed(2), "premier appui : armé")
	assert_true(SaveService.has_save(2), "rien supprimé au premier appui")
	assert_eq(load_screen.delete_buttons[2].theme_type_variation, &"ButtonDanger")
	load_screen.delete_buttons[2].pressed.emit()
	assert_false(SaveService.has_save(2), "second appui : supprimé")
	await wait_process_frames(2)
	assert_true(load_screen.cards[1].is_free())


# ---------------------------------------------------------------------------
# Mode Récit dans le jeu
# ---------------------------------------------------------------------------

func test_top_bar_story_mode_has_badge_no_imminent_alert_and_close_button() -> void:
	var bar: TopBar = TopBar.new()
	add_child_autofree(bar)
	await wait_process_frames(1)
	bar.set_clock(0.0, 300.0)
	assert_eq(bar.clock_state, TopBar.ClockState.CRITICAL, "Dur : alerte de fin à 0 s")
	bar.set_story_mode(true)
	assert_true(bar.story_badge.visible, "puce RÉCIT")
	assert_eq(bar.clock_state, TopBar.ClockState.NORMAL, "Récit : aucune alerte de fin")
	bar.set_clock(0.0, 300.0)
	assert_eq(bar.clock_state, TopBar.ClockState.NORMAL)
	assert_false(bar.get_end_text().contains("IMMINENTE"), "pas de « FIN DE SHIFT IMMINENTE » trompeuse")
	assert_false(bar.close_button.visible)
	bar.set_close_available(true)
	assert_true(bar.close_button.visible, "FERMER LE GUICHET (quota atteint)")
	watch_signals(bar)
	bar.close_button.pressed.emit()
	assert_signal_emitted(bar, "close_booth_pressed")
	bar.set_story_mode(false)
	assert_false(bar.story_badge.visible)
	assert_false(bar.close_button.visible, "Dur : jamais de fermeture anticipée")


func test_story_citation_is_labelled_as_story_warning() -> void:
	var result: CaseResult = CaseResult.new()
	result.citation_reason_key = ScoringService.CIT_IRREGULAR_ENTRY
	result.citation_number = 5
	result.fine = 0
	var ticket: CitationTicket = CitationTicket.make(result, 3, 1, "Règle", 2, false, true)
	add_child_autofree(ticket)
	var sanction: Label = ticket.find_child("Sanction", true, false) as Label
	assert_not_null(sanction)
	assert_false(sanction.text.contains("5/2"), "jamais « AVERTISSEMENT 5/2 » en Récit")
	assert_string_contains(sanction.text, "RÉCIT")


func test_pause_options_story_to_hard_with_confirmation() -> void:
	GameState.new_campaign(77, 1, GameState.DIFFICULTY_STORY)
	EventBus.difficulty_changed.connect(_on_difficulty_changed)
	var pause: PauseMenu = PauseMenu.new()
	add_child_autofree(pause)
	await wait_process_frames(2)
	pause.open()
	pause.show_options()
	await wait_process_frames(3)
	assert_true(pause.options.hard_mode_row.visible, "Récit : ligne « Passer en mode Dur »")
	pause.options.hard_mode_button.pressed.emit()
	await wait_process_frames(3)
	assert_not_null(pause.hard_dialog, "confirmation")
	assert_eq(_focus_owner(), pause.hard_dialog.cancel_button, "focus sur ANNULER")
	# Ⓑ annule la boîte sans fermer les options.
	_press_cancel()
	await wait_process_frames(3)
	assert_null(pause.hard_dialog)
	assert_true(pause.options.visible)
	assert_true(GameState.is_story_mode(), "annuler : toujours en Récit")
	pause.request_hard_mode()
	await wait_process_frames(2)
	pause.hard_dialog.accept()
	await wait_process_frames(2)
	assert_false(GameState.is_story_mode(), "passé en Dur")
	assert_eq(_story_events, [GameState.DIFFICULTY_HARD] as Array[StringName])
	assert_false(pause.options.hard_mode_row.visible, "ligne masquée en Dur (irréversible)")
	assert_false(GameState.set_difficulty(GameState.DIFFICULTY_STORY), "jamais l'inverse")
	pause.close()
	EventBus.difficulty_changed.disconnect(_on_difficulty_changed)


func test_pause_options_hide_hard_mode_in_hard_game_and_on_title() -> void:
	GameState.new_campaign(78, 1, GameState.DIFFICULTY_HARD)
	var pause: PauseMenu = PauseMenu.new()
	add_child_autofree(pause)
	await wait_process_frames(2)
	pause.open()
	pause.show_options()
	assert_false(pause.options.hard_mode_row.visible)
	pause.close()
	GameState.new_campaign(79, 1, GameState.DIFFICULTY_STORY)
	var title_options: OptionsPanel = OptionsPanel.new()
	add_child_autofree(title_options)
	await wait_process_frames(1)
	assert_false(title_options.hard_mode_row.visible, "titre : pas de partie en cours")
	assert_true(title_options.controls.has(Settings.KEY_TUTORIAL), "réglage du tutoriel dans Options")


func _on_difficulty_changed(value: StringName) -> void:
	_story_events.append(value)


# ---------------------------------------------------------------------------
# Tutoriel du J1
# ---------------------------------------------------------------------------

func _tutorial() -> TutorialOverlay:
	var tutorial: TutorialOverlay = TutorialOverlay.new()
	add_child_autofree(tutorial)
	await wait_process_frames(3)
	return tutorial


func test_tutorial_intro_focus_and_steps_advance_on_real_signals() -> void:
	var tutorial: TutorialOverlay = await _tutorial()
	assert_eq(tutorial.step_index, -1)
	assert_eq(_focus_owner(), tutorial.start_button, "accueil : focus sur COMMENCER")
	tutorial.start_button.pressed.emit()
	assert_eq(tutorial.current_step(), TutorialOverlay.Step.LOOK)
	# Un signal d'une autre étape ne fait pas avancer.
	EventBus.verdict_stamped.emit(Verdict.new())
	assert_eq(tutorial.current_step(), TutorialOverlay.Step.LOOK)
	assert_not_null(tutorial.find_child("Prompts", true, false), "invite clavier / manette")
	EventBus.documents_presented.emit(&"c1")
	assert_eq(tutorial.current_step(), TutorialOverlay.Step.INSPECT)
	EventBus.inspection_mode_changed.emit(false)
	assert_eq(tutorial.current_step(), TutorialOverlay.Step.INSPECT, "fermer l'inspection ne compte pas")
	EventBus.inspection_mode_changed.emit(true)
	assert_eq(tutorial.current_step(), TutorialOverlay.Step.RULEBOOK)
	EventBus.rulebook_consulted.emit()
	assert_eq(tutorial.current_step(), TutorialOverlay.Step.LINK)
	EventBus.discrepancy_check_requested.emit(FieldRef.new(), FieldRef.new())
	assert_eq(tutorial.current_step(), TutorialOverlay.Step.INTERROGATE)
	EventBus.interrogation_requested.emit(&"purpose")
	assert_eq(tutorial.current_step(), TutorialOverlay.Step.STAMP)
	watch_signals(tutorial)
	EventBus.verdict_stamped.emit(Verdict.new())
	assert_signal_emitted_with_parameters(tutorial, "finished", [true])
	assert_false(Settings.get_bool(Settings.KEY_TUTORIAL), "terminé : plus proposé")


func test_tutorial_skip_step_and_skip_all() -> void:
	var tutorial: TutorialOverlay = await _tutorial()
	tutorial.begin()
	tutorial.skip_step_button.pressed.emit()
	assert_eq(tutorial.current_step(), TutorialOverlay.Step.INSPECT, "étape passée")
	watch_signals(tutorial)
	tutorial.skip_all_button.pressed.emit()
	assert_signal_emitted_with_parameters(tutorial, "finished", [false])
	assert_false(Settings.get_bool(Settings.KEY_TUTORIAL), "passé : plus proposé")
	await wait_process_frames(1)
	assert_false(is_instance_valid(tutorial), "surimpression retirée")


func test_tutorial_glyphs_follow_gamepad() -> void:
	var tutorial: TutorialOverlay = await _tutorial()
	tutorial.begin()
	var prompts: Node = tutorial.find_child("Prompts", true, false)
	var glyph: PromptGlyph = prompts.get_child(0) as PromptGlyph
	var keyboard_text: String = glyph.get_text()
	InputPrompts.simulate_device(InputPrompts.Device.XBOX)
	await wait_process_frames(1)
	assert_ne(glyph.get_text(), keyboard_text, "invite manette après un appui manette")


func test_day_scene_shows_tutorial_after_briefing_on_day_one() -> void:
	GameState.new_campaign(20_871_315)
	TutorialOverlay.pending = true
	var scene: DayScene = DAY_SCENE.instantiate()
	add_child_autofree(scene)
	await wait_process_frames(3)
	assert_false(TutorialOverlay.pending, "demande consommée")
	assert_null(scene.tutorial, "pas pendant le briefing")
	scene.briefing.close()
	await wait_process_frames(3)
	assert_not_null(scene.tutorial, "tutoriel posé à la prise de poste")
	assert_true(scene.tutorial.get_index() < scene.pause_menu.get_index(), "sous le menu pause")
	EventBus.next_case_requested.emit()
	assert_eq(scene.tutorial.current_step(), TutorialOverlay.Step.LOOK, "appeler un passager commence le tutoriel")
	Settings.set_value(Settings.KEY_TUTORIAL, true)


func test_comparison_ui_close_booth_button_reachable_from_next() -> void:
	var ui: ComparisonUI = (load("res://scenes/ui/comparison_ui.tscn") as PackedScene).instantiate()
	add_child_autofree(ui)
	await wait_process_frames(2)
	ui.set_story_mode(true)
	watch_signals(ui)
	ui.set_close_booth_available(true)
	assert_true(ui.top_bar.close_button.visible)
	assert_ne(ui.tool_bar.next_button.focus_neighbor_top, NodePath(), "croix haut depuis SUIVANT")
	ui.top_bar.close_button.pressed.emit()
	assert_signal_emitted(ui, "close_booth_requested")
	EventBus.difficulty_changed.emit(GameState.DIFFICULTY_HARD)
	GameState.difficulty = GameState.DIFFICULTY_HARD
	ui.set_story_mode(false)
	assert_false(ui.top_bar.close_button.visible)
	assert_eq(ui.tool_bar.next_button.focus_neighbor_top, NodePath())


# ---------------------------------------------------------------------------
# Navigation à la croix (UI_FLOW §9.4 règle 6)
# ---------------------------------------------------------------------------

func _press(action: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release: InputEventAction = InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await wait_process_frames(2)


func test_dpad_navigates_title_new_game_load_and_dialogs() -> void:
	_write_slot(1, 5)
	var main: Control = await _main()
	assert_eq(_focus_owner(), main.get(&"continue_button"))
	await _press(&"ui_down")
	assert_eq(_focus_owner(), main.get(&"new_game_button"), "titre : croix ↓")
	await _press(&"ui_down")
	assert_eq(_focus_owner(), main.get(&"load_button"))
	# Nouvelle partie : emplacements à la croix, puis difficulté.
	var ng: NewGameScreen = main.call(&"open_new_game")
	await wait_process_frames(3)
	assert_eq(_focus_owner(), ng.slot_buttons[1])
	await _press(&"ui_right")
	assert_eq(_focus_owner(), ng.slot_buttons[2], "emplacement 3 à droite")
	await _press(&"ui_left")
	await _press(&"ui_left")
	assert_eq(_focus_owner(), ng.slot_buttons[0], "emplacement 1 (occupé) à gauche")
	await _press(&"ui_accept")
	assert_not_null(ng.dialog, "Ⓐ : confirmation d'écrasement")
	assert_eq(_focus_owner(), ng.dialog.cancel_button)
	await _press(&"ui_right")
	assert_eq(_focus_owner(), ng.dialog.accept_button, "focus piégé dans la boîte")
	await _press(&"ui_right")
	assert_eq(_focus_owner(), ng.dialog.cancel_button)
	await _press(&"ui_cancel")
	assert_null(ng.dialog)
	ng.show_difficulty(2)
	await wait_process_frames(2)
	await _press(&"ui_right")
	assert_eq(_focus_owner(), ng.story_button, "difficulté : Récit à droite")
	await _press(&"ui_cancel")
	await _press(&"ui_cancel")
	assert_null(main.get(&"screen"), "deux Ⓑ : retour au titre")
	# Charger : actions d'une carte à la croix.
	var load_screen: LoadScreen = main.call(&"open_load")
	await wait_process_frames(3)
	assert_eq(_focus_owner(), load_screen.resume_buttons[1])
	await _press(&"ui_down")
	assert_eq(_focus_owner(), load_screen.day_buttons[1])
	await _press(&"ui_down")
	assert_eq(_focus_owner(), load_screen.delete_buttons[1])
	await _press(&"ui_down")
	assert_eq(_focus_owner(), load_screen.back_button, "RETOUR sous les cartes")
