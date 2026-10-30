## Passe QA M11 « Confort » (docs/QA.md §14) — non-régression.
##
## Manette seule : les entrées sont de **vrais** événements de manette
## (`InputEventJoypadButton` / `InputEventJoypadMotion` passés à
## `Input.parse_input_event`), jamais des `InputEventAction` : on vérifie donc
## aussi la carte des entrées (`project.godot`) et l'ordre de traitement
## (`_input` du guichet avant l'interface). Parcours réels dans `day.tscn` :
## tutoriel du J1, premier passager (inspection, lien A → B, Rulebook,
## interrogatoire, tampon), J1 complet, bilan, soirée, détention (L3), pause et
## Options (Récit → Dur après 18:00), écran de fin, Charger (jour passé).
## Sauvegardes v6 : migration d'une vraie sauvegarde 0.10.0, quitter en plein
## shift, reprise d'un jour d'une partie terminée puis troncature, fichiers
## abîmés. Les défauts connus appellent `pending("QA-0xx : …")` tant qu'ils
## sont présents (la suite reste verte) et deviennent des assertions strictes
## une fois corrigés (convention §1).
## Les sauvegardes vivent dans le dossier de test (`SaveService.use_root`,
## `tests/helpers/gut_pre_run.gd`), jamais dans `user://saves`.
extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const DAY_SCENE: PackedScene = preload("res://scenes/main/day.tscn")
const FIXTURE_V5: String = "res://tests/fixtures/qa_save_v5_j25_luciole.json"
## Graine du J1 utilisée par les tests M11 existants.
const SEED: int = 20_871_315


func before_each() -> void:
	Settings.set_session_value(Settings.KEY_REDUCE_MOTION, true)
	# M13 : pas de carte d'aide (J4+, J8+) : ces parcours testent le guichet nu
	# (la carte d'aide a ses tests : `test_m13_ui.gd`).
	Settings.set_session_value(Settings.KEY_TUTORIAL_M13_STATEMENTS, false)
	Settings.set_session_value(Settings.KEY_TUTORIAL_M13_SEARCH, false)
	_clear_slots()
	TutorialOverlay.pending = false


func after_each() -> void:
	Engine.time_scale = 1.0
	for action: StringName in [&"stamp_approve", &"inspect_toggle", &"stamp_detain"]:
		Input.action_release(action)
	_clear_slots()
	Settings.clear_session_value(Settings.KEY_REDUCE_MOTION)
	Settings.clear_session_value(Settings.KEY_HOLO_FLICKER)
	Settings.clear_session_value(Settings.KEY_TUTORIAL_M13_STATEMENTS)
	Settings.clear_session_value(Settings.KEY_TUTORIAL_M13_SEARCH)
	Settings.set_value(Settings.KEY_TUTORIAL, true)
	TutorialOverlay.pending = false
	InputPrompts.simulate_device(InputPrompts.Device.KEYBOARD)
	get_tree().paused = false
	GameState.new_campaign(1)


func _clear_slots() -> void:
	for slot: int in range(1, SaveService.SLOT_COUNT + 1):
		SaveService.delete_slot(slot)
	var root: String = SaveService.resolve_dir(SaveService.DEFAULT_DIR)
	for file: String in [SaveService.LEGACY_FILE, SaveService.LEGACY_BACKUP_FILE]:
		if FileAccess.file_exists(root.path_join(file)):
			DirAccess.remove_absolute(root.path_join(file))


# ---------------------------------------------------------------------------
# Outils
# ---------------------------------------------------------------------------

func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


## Appui court d'un bouton de manette (événement réel).
func _pad(button: JoyButton) -> void:
	var down: InputEventJoypadButton = InputEventJoypadButton.new()
	down.button_index = button
	down.pressed = true
	down.pressure = 1.0
	Input.parse_input_event(down)
	await wait_process_frames(2)
	var up: InputEventJoypadButton = InputEventJoypadButton.new()
	up.button_index = button
	up.pressed = false
	Input.parse_input_event(up)
	await wait_process_frames(3)


## Bouton maintenu `seconds` (tampons : maintien de 0,4 s).
func _pad_hold(button: JoyButton, seconds: float) -> void:
	var down: InputEventJoypadButton = InputEventJoypadButton.new()
	down.button_index = button
	down.pressed = true
	Input.parse_input_event(down)
	await wait_seconds(seconds)
	var up: InputEventJoypadButton = InputEventJoypadButton.new()
	up.button_index = button
	Input.parse_input_event(up)
	await wait_process_frames(3)


func _axis(axis: JoyAxis, value: float) -> void:
	var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
	motion.axis = axis
	motion.axis_value = value
	Input.parse_input_event(motion)
	await wait_process_frames(2)


## Gâchette enfoncée `seconds` puis relâchée (LT inspection, RT APPROUVÉ).
func _trigger(axis: JoyAxis, seconds: float = 0.0) -> void:
	await _axis(axis, 1.0)
	if seconds > 0.0:
		await wait_seconds(seconds)
	await _axis(axis, 0.0)


func _wait_until(cond: Callable, timeout: float = 20.0) -> bool:
	var t: float = 0.0
	while not cond.call() and t < timeout:
		await wait_seconds(0.2)
		t += 0.2
	return cond.call()


## Contrôles atteints à la croix depuis `start` (parcours en largeur).
func _reach(start: Control, max_nodes: int = 120) -> Array[Control]:
	var seen: Array[Control] = [start]
	var queue: Array[Control] = [start]
	while not queue.is_empty() and seen.size() < max_nodes:
		var from: Control = queue.pop_front()
		for dir: JoyButton in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT]:
			if not is_instance_valid(from) or not from.is_visible_in_tree():
				break
			from.grab_focus()
			await wait_process_frames(1)
			await _pad(dir)
			var to: Control = _focus()
			if to != null and not seen.has(to):
				seen.append(to)
				queue.append(to)
	return seen


func _write_slot(slot: int, days: int, story: bool = false, ending: String = "") -> void:
	var data: Dictionary = {"campaign_seed": 700 + slot, "credits": 20 + slot, "score_total": 0, "citations": 0,
		"narrative_flags": {}, "day_history": [], "household": Household.new().to_dict(), "case_memory": {},
		"difficulty": "story" if story else "hard", "play_time_sec": 600 * slot}
	for day: int in range(1, days + 1):
		data["current_day"] = day
		SaveService.save_slot(data, slot, SaveService.DEFAULT_DIR, "2026-10-2%dT10:%02d:00" % [slot, day])
	if not ending.is_empty():
		SaveService.mark_ended(slot, ending)


func _main() -> Control:
	var main: Control = MAIN_SCENE.instantiate()
	main.set(&"change_scene", false)
	add_child_autofree(main)
	await wait_process_frames(3)
	return main


## Scène de jour réelle (nouvelle campagne `SEED`, jour `day`) ; le briefing
## est fermé à la manette (Ⓐ).
func _day(story: bool = false, day: int = 1, tutorial: bool = false) -> DayScene:
	GameState.new_campaign(SEED, 1, GameState.DIFFICULTY_STORY if story else GameState.DIFFICULTY_HARD)
	GameState.current_day = day
	TutorialOverlay.pending = tutorial
	var scene: DayScene = DAY_SCENE.instantiate()
	add_child_autofree(scene)
	await wait_process_frames(5)
	InputPrompts.simulate_device(InputPrompts.Device.XBOX)
	assert_eq(_focus(), scene.briefing.default_focus(), "briefing : focus sur PRENDRE SON POSTE")
	await _pad(JOY_BUTTON_A)
	await wait_process_frames(3)
	return scene


## Ⓐ (passager suivant) puis attente des papiers.
func _call_passenger(scene: DayScene) -> bool:
	var ui: ComparisonUI = scene.ui as ComparisonUI
	await _pad(JOY_BUTTON_A)
	return await _wait_until(func() -> bool: return ui.documents_shown and not ui.verdict_sent)


## Joue le shift à la manette seule (Ⓐ appelle, RT maintenu approuve) jusqu'au bilan.
func _play_shift_with_pad(scene: DayScene) -> int:
	var ui: ComparisonUI = scene.ui as ComparisonUI
	var verdicts: Array[Verdict] = []
	var count: Callable = func(v: Verdict) -> void: verdicts.append(v)
	EventBus.verdict_stamped.connect(count)
	Engine.time_scale = 4.0
	var guard: int = 0
	while scene.last_summary == null and guard < 40:
		guard += 1
		if scene.day_controller.phase == DayPhase.Kind.WAITING_CASE:
			await _pad(JOY_BUTTON_A)
		await _wait_until(func() -> bool: return (ui.documents_shown and not ui.verdict_sent) or scene.last_summary != null, 30.0)
		if scene.last_summary != null:
			break
		await _trigger(JOY_AXIS_TRIGGER_RIGHT, 0.8)
		await _wait_until(func() -> bool: return scene.day_controller.phase == DayPhase.Kind.WAITING_CASE or scene.last_summary != null, 30.0)
	Engine.time_scale = 1.0
	EventBus.verdict_stamped.disconnect(count)
	return verdicts.size()


## Bilan (Ⓐ) puis soirée validée à la manette ; le rechargement de scène est
## coupé (GUT). Renvoie l'écran de soirée.
func _summary_and_evening_with_pad(scene: DayScene) -> EveningScreen:
	await _wait_until(func() -> bool: return scene.screen is ShiftSummaryScreen, 10.0)
	await wait_process_frames(3)
	assert_eq(_focus(), (scene.screen as ShiftSummaryScreen).continue_button, "bilan : focus sur CONTINUER")
	await _pad(JOY_BUTTON_A)
	await wait_process_frames(5)
	var evening: EveningScreen = scene.screen as EveningScreen
	assert_not_null(evening, "Ⓐ : soirée")
	if evening == null:
		return null
	evening.finished.disconnect(scene._after_evening)
	assert_eq(_focus(), evening.confirm_button, "soirée : focus sur VALIDER ET DORMIR")
	await _pad(JOY_BUTTON_A)
	await wait_process_frames(5)
	return evening


# ---------------------------------------------------------------------------
# Manette seule — parcours qui passent
# ---------------------------------------------------------------------------

func test_pad_title_new_game_story_to_day_one() -> void:
	var main: Control = await _main()
	assert_eq(_focus(), main.get(&"new_game_button"), "titre sans partie : NOUVELLE PARTIE")
	await _pad(JOY_BUTTON_A)
	var ng: NewGameScreen = main.get(&"screen") as NewGameScreen
	assert_not_null(ng, "Ⓐ : Nouvelle partie")
	await wait_process_frames(3)
	assert_eq(_focus(), ng.slot_buttons[0], "emplacement libre")
	await _pad(JOY_BUTTON_A)
	await wait_process_frames(3)
	assert_eq(_focus(), ng.hard_button, "difficulté : DUR")
	var started: Array = []
	ng.start_requested.connect(func(s: int, d: StringName) -> void: started.append([s, d]))
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	assert_eq(_focus(), ng.story_button)
	await _pad(JOY_BUTTON_A)
	assert_eq(started, [[1, GameState.DIFFICULTY_STORY]])
	assert_true(GameState.is_story_mode())
	assert_eq(GameState.current_day, 1)
	assert_true(TutorialOverlay.pending, "tutoriel demandé au J1")
	assert_eq(SaveService.list_snapshots(1), PackedInt32Array([1]), "emplacement occupé tout de suite (matin du J1)")


func test_pad_only_tutorial_and_first_passenger() -> void:
	var scene: DayScene = await _day(false, 1, true)
	var ui: ComparisonUI = scene.ui as ComparisonUI
	var tut: TutorialOverlay = scene.tutorial
	assert_not_null(tut, "tutoriel posé après le briefing")
	assert_eq(_focus(), tut.start_button, "accueil : COMMENCER")
	var done: Array = []
	tut.finished.connect(func(completed: bool) -> void: done.append(completed))
	await _pad(JOY_BUTTON_A)
	# QA-041 : Ⓐ sur COMMENCER commence le tutoriel sans appeler de passager ;
	# le focus revient à SUIVANT pour l'étape 1.
	assert_eq(tut.current_step(), TutorialOverlay.Step.LOOK, "Ⓐ COMMENCER : étape 1")
	assert_false(ui.documents_shown, "COMMENCER n'appelle pas le passager")
	assert_eq(_focus(), ui.tool_bar.next_button, "focus rendu à SUIVANT")
	await _pad(JOY_BUTTON_A)
	assert_true(await _wait_until(func() -> bool: return ui.documents_shown), "passager appelé")
	await wait_process_frames(3)
	assert_eq(tut.current_step(), TutorialOverlay.Step.INSPECT, "1. papiers posés")
	await _trigger(JOY_AXIS_TRIGGER_LEFT)
	assert_true(ui.inspection_active, "LT : Mode Inspection")
	assert_true(_focus() is InspectableItem, "inspection à la manette : focus sur un champ")
	assert_eq(tut.current_step(), TutorialOverlay.Step.RULEBOOK, "2. inspection")
	await _pad(JOY_BUTTON_RIGHT_SHOULDER)
	assert_eq(tut.current_step(), TutorialOverlay.Step.LINK, "3. RB : onglet du Rulebook")
	var checks: Array = []
	EventBus.discrepancy_check_requested.connect(func(a: FieldRef, b: FieldRef) -> void: checks.append([a, b]))
	await _pad(JOY_BUTTON_A)
	assert_not_null(ui.selection.a, "Ⓐ : champ A")
	# Croix → jusqu'à une règle du Rulebook (un seul document au premier passager).
	var guard: int = 0
	while _focus() is InspectableItem and ui.workbench.is_ancestor_of(_focus()) and guard < 8:
		guard += 1
		await _pad(JOY_BUTTON_DPAD_RIGHT)
	await _pad(JOY_BUTTON_A)
	assert_eq(checks.size(), 1, "Ⓐ sur une règle : comparaison A → B")
	assert_eq(tut.current_step(), TutorialOverlay.Step.INTERROGATE, "4. lien")
	await wait_seconds(1.0)
	await _pad(JOY_BUTTON_Y)
	assert_true(ui.question_menu_open, "Y : menu des questions")
	await _pad(JOY_BUTTON_A)
	assert_eq(tut.current_step(), TutorialOverlay.Step.STAMP, "5. question posée")
	await wait_seconds(1.0)
	await _trigger(JOY_AXIS_TRIGGER_RIGHT, 0.7)
	assert_eq(done, [true], "6. RT maintenu : tampon, tutoriel terminé")
	assert_false(Settings.get_bool(Settings.KEY_TUTORIAL), "tutoriel plus proposé")


func test_pad_only_day_one_summary_and_evening() -> void:
	var scene: DayScene = await _day()
	var stamped: int = await _play_shift_with_pad(scene)
	assert_not_null(scene.last_summary, "shift terminé à la manette")
	if scene.last_summary == null:
		return
	assert_eq(stamped, scene.last_summary.get_processed_count(), "chaque passager tamponné au RT")
	var evening: EveningScreen = await _summary_and_evening_with_pad(scene)
	assert_not_null(evening)
	assert_eq(GameState.current_day, 2, "Ⓐ sur VALIDER ET DORMIR : nuit validée")
	assert_eq(SaveService.list_snapshots(1), PackedInt32Array([2]), "sauvegarde du soir")


func test_pad_detention_with_left_stick_click() -> void:
	var scene: DayScene = await _day(false, 7)
	var ui: ComparisonUI = scene.ui as ComparisonUI
	assert_true(await _call_passenger(scene))
	assert_true(ui.get_stamp_button(VerdictKind.Kind.DETAIN).visible, "J7 : DÉTENTION proposée")
	var verdicts: Array[Verdict] = []
	var count: Callable = func(v: Verdict) -> void: verdicts.append(v)
	EventBus.verdict_stamped.connect(count)
	await _pad_hold(JOY_BUTTON_LEFT_STICK, 0.8)
	EventBus.verdict_stamped.disconnect(count)
	assert_eq(verdicts.size(), 1, "L3 maintenu : un tampon")
	if verdicts.size() == 1:
		assert_eq(verdicts[0].kind, VerdictKind.Kind.DETAIN)


func test_pad_pause_story_to_hard_after_closing_time_ends_the_shift() -> void:
	var scene: DayScene = await _day(true)
	assert_true(await _call_passenger(scene))
	scene.day_clock.advance(scene.day_clock.duration_sec + 10.0)
	await wait_process_frames(2)
	assert_false(scene.day_clock.expired, "Récit : l'horloge s'arrête à 18:00 sans fin de shift")
	assert_eq(scene.day_clock.current_minute(), 18 * 60)
	await _pad(JOY_BUTTON_START)
	assert_true(scene.pause_menu.is_open, "Menu : pause")
	assert_eq(_focus(), scene.pause_menu.resume_button)
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_A)
	assert_true(scene.pause_menu.options.visible, "Ⓐ sur OPTIONS")
	var guard: int = 0
	while _focus() != scene.pause_menu.options.hard_mode_button and guard < 40:
		guard += 1
		await _pad(JOY_BUTTON_DPAD_DOWN)
	assert_eq(_focus(), scene.pause_menu.options.hard_mode_button, "croix ↓ jusqu'à PASSER EN MODE DUR")
	await _pad(JOY_BUTTON_A)
	assert_not_null(scene.pause_menu.hard_dialog)
	if scene.pause_menu.hard_dialog == null:
		return
	assert_eq(_focus(), scene.pause_menu.hard_dialog.cancel_button, "confirmation : focus ANNULER")
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	await _pad(JOY_BUTTON_A)
	assert_eq(GameState.difficulty, GameState.DIFFICULTY_HARD)
	assert_true(scene.day_clock.expired, "horloge déjà passée 18:00 : expirée aussitôt")
	assert_false(GameState.set_difficulty(GameState.DIFFICULTY_STORY), "jamais Dur → Récit")
	await _pad(JOY_BUTTON_B)
	await _pad(JOY_BUTTON_B)
	assert_false(scene.pause_menu.is_open, "Ⓑ Ⓑ : options puis pause fermées")
	await _trigger(JOY_AXIS_TRIGGER_RIGHT, 0.8)
	assert_true(await _wait_until(func() -> bool: return scene.last_summary != null, 15.0), "bilan après le passager en cours")


func test_pad_end_screen_and_load_screen_past_day() -> void:
	GameState.new_campaign(SEED)
	GameState.current_day = 5
	var scene: DayScene = DAY_SCENE.instantiate()
	add_child_autofree(scene)
	await wait_process_frames(5)
	InputPrompts.simulate_device(InputPrompts.Device.XBOX)
	scene.show_end(&"f2_reassigned")
	await wait_process_frames(5)
	var end: EndScreen = scene.screen as EndScreen
	for c: Dictionary in end.finished.get_connections():
		end.finished.disconnect(c["callable"])
	var closed: Array = []
	end.finished.connect(func(choice: StringName) -> void: closed.append(choice))
	assert_eq(_focus(), end.default_focus())
	for i: int in 2:
		if closed.is_empty():
			await _pad(JOY_BUTTON_A)
			await wait_process_frames(3)
	assert_eq(closed, [&"title"], "fin : Ⓐ jusqu'au retour au titre")
	_write_slot(1, 6)
	_write_slot(2, 9, true)
	var main: Control = await _main()
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_DPAD_DOWN)
	assert_eq(_focus(), main.get(&"load_button"))
	await _pad(JOY_BUTTON_A)
	var ls: LoadScreen = main.get(&"screen") as LoadScreen
	assert_not_null(ls)
	if ls == null:
		return
	await wait_process_frames(3)
	assert_eq(_focus(), ls.resume_buttons[2], "REPRENDRE de la partie de Continuer")
	await _pad(JOY_BUTTON_DPAD_LEFT)
	await _pad(JOY_BUTTON_DPAD_DOWN)
	assert_eq(_focus(), ls.day_buttons[1])
	await _pad(JOY_BUTTON_A)
	await wait_process_frames(3)
	assert_eq(_focus(), ls.picker_buttons[6], "grille : dernier jour")
	await _pad(JOY_BUTTON_DPAD_LEFT)
	await _pad(JOY_BUTTON_DPAD_LEFT)
	await _pad(JOY_BUTTON_A)
	assert_not_null(ls.dialog, "jour antérieur : confirmation")
	if ls.dialog == null:
		return
	assert_eq(_focus(), ls.dialog.cancel_button)
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	await _pad(JOY_BUTTON_A)
	assert_eq(GameState.active_slot, 1)
	assert_eq(GameState.current_day, 4, "matin du J4 repris")


# ---------------------------------------------------------------------------
# Sauvegardes v6 — parcours qui passent
# ---------------------------------------------------------------------------

func test_real_v5_save_appears_on_title_and_load_screen() -> void:
	var legacy: String = SaveService.resolve_dir(SaveService.DEFAULT_DIR).path_join(SaveService.LEGACY_FILE)
	DirAccess.make_dir_recursive_absolute(legacy.get_base_dir())
	var text: String = FileAccess.get_file_as_string(FIXTURE_V5)
	var file: FileAccess = FileAccess.open(legacy, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var original: Dictionary = SaveService.parse(text, FIXTURE_V5)
	var main: Control = await _main()
	var cont: Button = main.get(&"continue_button")
	assert_eq(cont.text, "CONTINUER — JOUR 25", "titre : partie 0.10.0 migrée")
	assert_true(FileAccess.file_exists(legacy.get_base_dir().path_join(SaveService.LEGACY_BACKUP_FILE)), "slot_0.v5.bak gardé")
	assert_false(FileAccess.file_exists(legacy), "slot_0.json mis de côté")
	var ls: LoadScreen = main.call(&"open_load")
	await wait_process_frames(3)
	assert_false(ls.cards[0].is_free())
	assert_eq(SaveService.as_int(ls.cards[0].meta.get("act")), 3, "carte : acte III")
	assert_eq(SaveService.list_snapshots(1), PackedInt32Array([25]), "un seul matin : le jour courant")
	ls.close(&"back")
	await wait_process_frames(3)
	assert_true(main.call(&"continue_game"))
	var state: Dictionary = GameState.to_save_dict()
	for key: String in ["campaign_seed", "current_day", "credits", "score_total", "citations"]:
		assert_eq(SaveService.as_int(state[key]), SaveService.as_int(original[key]), "%s inchangé" % key)
	assert_eq((state["narrative_flags"] as Dictionary).size(), (original["narrative_flags"] as Dictionary).size(), "drapeaux")
	assert_eq((state["case_memory"] as Dictionary).size(), (original["case_memory"] as Dictionary).size(), "mémoire des cas")
	assert_eq((state["day_history"] as Array).size(), (original["day_history"] as Array).size(), "historique")
	assert_eq(GameState.difficulty, GameState.DIFFICULTY_HARD)


func test_quit_mid_shift_writes_nothing_and_continue_replays_the_day() -> void:
	_write_slot(2, 3)
	var current_before: String = FileAccess.get_file_as_string(SaveService.slot_path(2))
	var meta_before: String = FileAccess.get_file_as_string(SaveService.meta_path(2))
	assert_true(GameState.load_from_slot())
	var scene: DayScene = DAY_SCENE.instantiate()
	add_child_autofree(scene)
	await wait_process_frames(5)
	scene.pause_menu.quit_to_title_requested.disconnect(scene.go_to_title)
	var quits: Array = []
	scene.pause_menu.quit_to_title_requested.connect(func() -> void: quits.append(1))
	await _pad(JOY_BUTTON_A)
	assert_true(await _call_passenger(scene))
	await _pad(JOY_BUTTON_START)
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_A)
	await _pad(JOY_BUTTON_A)
	assert_eq(quits.size(), 1, "QUITTER VERS LE TITRE en deux temps")
	assert_eq(FileAccess.get_file_as_string(SaveService.slot_path(2)), current_before, "rien d'écrit en plein shift")
	assert_eq(FileAccess.get_file_as_string(SaveService.meta_path(2)), meta_before)
	assert_eq(SaveService.list_snapshots(2), PackedInt32Array([1, 2, 3]))
	get_tree().paused = false
	assert_true(GameState.load_from_slot())
	assert_eq([GameState.active_slot, GameState.current_day], [2, 3], "Continuer : matin du jour abandonné")


func test_resume_first_day_of_ended_game_truncates_and_reactivates() -> void:
	_write_slot(1, 5, false, "f3_family_lost")
	GameState.load_from_slot(1)
	GameState.end_campaign(&"f3_family_lost", 1)
	assert_eq(SaveService.latest_slot(), SaveService.NO_SLOT, "partie terminée : pas de Continuer")
	assert_true(GameState.load_day_snapshot(1, 1))
	var scene: DayScene = DAY_SCENE.instantiate()
	add_child_autofree(scene)
	await wait_process_frames(5)
	InputPrompts.simulate_device(InputPrompts.Device.XBOX)
	await _pad(JOY_BUTTON_A)
	await _play_shift_with_pad(scene)
	await _summary_and_evening_with_pad(scene)
	var meta: Dictionary = SaveService.load_meta(1)
	assert_eq(SaveService.list_snapshots(1), PackedInt32Array([1, 2]), "J3–J5 supprimés : une seule ligne de temps")
	assert_eq(str(meta.get("status")), SaveService.STATUS_ACTIVE, "partie rouverte")
	assert_eq(str(meta.get("ending_id")), "")
	assert_eq(SaveService.latest_slot(), 1, "Continuer : la partie rouverte")
	assert_true(ProfileService.has_seen_ending(ProfileService.load_profile(SaveService.DEFAULT_DIR), "f3_family_lost"),
			"la fin reste au profil")


# ---------------------------------------------------------------------------
# Défauts ouverts (pending tant qu'ils sont présents)
# ---------------------------------------------------------------------------

## QA-041 : entre deux passagers, Ⓐ (= `next_case`, traité par
## `ComparisonUI._input` avant l'interface) appelle un passager au lieu
## d'activer le bouton qui a le focus.
func test_pad_a_on_close_booth_closes_instead_of_calling_a_passenger() -> void:
	var scene: DayScene = await _day(true)
	var ui: ComparisonUI = scene.ui as ComparisonUI
	ui.set_close_booth_available(true)
	var closes: Array = []
	var nexts: Array = []
	ui.close_booth_requested.connect(func() -> void: closes.append(1))
	var on_next: Callable = func() -> void: nexts.append(1)
	EventBus.next_case_requested.connect(on_next)
	ui.tool_bar.next_button.grab_focus()
	await _pad(JOY_BUTTON_DPAD_UP)
	assert_eq(_focus(), ui.top_bar.close_button, "croix ↑ depuis SUIVANT : FERMER LE GUICHET")
	await _pad(JOY_BUTTON_A)
	EventBus.next_case_requested.disconnect(on_next)
	assert_eq(closes.size(), 1, "Ⓐ : guichet fermé")
	assert_eq(nexts.size(), 0, "aucun passager appelé")


func test_pad_a_on_tutorial_skip_skips_instead_of_calling_a_passenger() -> void:
	var scene: DayScene = await _day(false, 1, true)
	var tut: TutorialOverlay = scene.tutorial
	var done: Array = []
	tut.finished.connect(func(completed: bool) -> void: done.append(completed))
	var nexts: Array = []
	var on_next: Callable = func() -> void: nexts.append(1)
	EventBus.next_case_requested.connect(on_next)
	tut.skip_all_button.grab_focus()
	await _pad(JOY_BUTTON_A)
	EventBus.next_case_requested.disconnect(on_next)
	assert_eq(done, [false], "tutoriel passé")
	assert_eq(nexts.size(), 0)


## QA-042 : la carte du tutoriel est hors de la racine du guichet ; le
## `FocusGuard` du guichet reprend toute direction et la rend à SUIVANT.
func test_pad_dpad_reaches_the_tutorial_buttons() -> void:
	var scene: DayScene = await _day(false, 1, true)
	var tut: TutorialOverlay = scene.tutorial
	var ui: ComparisonUI = scene.ui as ComparisonUI
	assert_eq(_focus(), tut.start_button)
	await _pad(JOY_BUTTON_DPAD_LEFT)
	var after_left: Control = _focus()
	var from_start: bool = after_left == tut.skip_all_button
	tut.begin()
	await wait_process_frames(3)
	var reached: Array[Control] = await _reach(ui.tool_bar.next_button)
	var skip_step: bool = reached.has(tut.skip_step_button)
	assert_true(from_start, "croix ← depuis COMMENCER : PASSER LE TUTORIEL (obtenu : %s)" % [
			after_left.name if after_left != null else "rien"])
	assert_true(skip_step, "PASSER L'ÉTAPE joignable à la croix")


## QA-043 : `current.json` illisible alors que l'instantané du même matin est
## intact → « Continuer » reprend l'instantané (`SaveService.load_current`).
func test_corrupt_current_does_not_leave_a_dead_continue_button() -> void:
	_write_slot(1, 4)
	var file: FileAccess = FileAccess.open(SaveService.slot_path(1), FileAccess.WRITE)
	file.store_string("{ corrompu")
	file.close()
	var main: Control = await _main()
	var cont: Button = main.get(&"continue_button")
	assert_false(cont.disabled, "CONTINUER actif : l'instantané du J4 est lisible")
	var loaded: bool = main.call(&"continue_game")
	assert_true(loaded, "Continuer reprend l'instantané day_04.json")
	assert_eq([GameState.active_slot, GameState.current_day], [1, 4])


## QA-043 : rien de lisible (ni `current.json` ni instantané) → emplacement
## marqué `damaged` dans sa méta, jamais proposé par « Continuer ».
func test_unreadable_slot_is_flagged_damaged() -> void:
	_write_slot(1, 3)
	for path: String in [SaveService.slot_path(1), SaveService.snapshot_path(1, 1), SaveService.snapshot_path(1, 2),
			SaveService.snapshot_path(1, 3)]:
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string("{ corrompu")
		file.close()
	var meta: Dictionary = SaveService.list_slots()[0]
	assert_true(SaveService.is_damaged(meta), "méta : %s = true" % SaveService.META_DAMAGED)
	assert_eq(SaveService.as_int(meta.get("slot")), 1)
	assert_eq(SaveService.as_int(meta.get("current_day")), 3, "dernier jour connu (méta intacte)")
	assert_eq(SaveService.latest_slot(), SaveService.NO_SLOT, "pas de Continuer")
	assert_eq(SaveService.list_snapshots(1), PackedInt32Array(), "aucun jour proposé")
	assert_eq(SaveService.first_free_slot(), 2, "pas libre : à supprimer ou écraser")
	assert_false(GameState.load_from_slot(1))
	DirAccess.remove_absolute(SaveService.meta_path(1))
	assert_true(SaveService.is_damaged(SaveService.load_meta(1)), "méta perdue aussi : toujours endommagé")
	assert_eq(SaveService.as_int(SaveService.load_meta(1).get("current_day")), 3, "jour déduit des fichiers")


## QA-044 : le statut « terminée » survit à la perte de `meta.json` (écrit
## aussi dans `current.json` par `mark_ended`).
func test_ended_game_stays_ended_when_meta_is_lost() -> void:
	_write_slot(2, 7, false, "f2_reassigned")
	DirAccess.remove_absolute(SaveService.meta_path(2))
	var meta: Dictionary = SaveService.load_meta(2)
	assert_eq(str(meta.get("status")), SaveService.STATUS_ENDED)
	assert_eq(str(meta.get("ending_id")), "f2_reassigned")
	assert_eq(SaveService.latest_slot(), SaveService.NO_SLOT)
	# Reprise d'un jour passé puis soirée : la partie est rouverte.
	assert_true(GameState.load_day_snapshot(2, 5))
	assert_eq(GameState.save_to_slot(), OK)
	DirAccess.remove_absolute(SaveService.meta_path(2))
	assert_eq(str(SaveService.load_meta(2).get("status")), SaveService.STATUS_ACTIVE, "rouverte : active")
	assert_eq(SaveService.latest_slot(), 2)


## QA-045 : `.tmp` orphelin et tronqué (coupure pendant l'écriture d'un nouvel instantané).
func test_orphan_truncated_tmp_snapshot_is_not_offered() -> void:
	_write_slot(3, 5)
	var file: FileAccess = FileAccess.open(SaveService.snapshot_path(3, 6) + SaveService.TMP_SUFFIX, FileAccess.WRITE)
	file.store_string("{\"version\": 6, \"current_d")
	file.close()
	var days: PackedInt32Array = SaveService.list_snapshots(3)
	assert_eq(days, PackedInt32Array([1, 2, 3, 4, 5]), "aucun matin illisible proposé")
	for day: int in days:
		assert_false(SaveService.load_snapshot(3, day).is_empty(), "J%d chargeable" % day)


## QA-046 : Récit → Dur est inscrit tout de suite dans l'emplacement actif.
func test_hard_mode_switch_is_not_undone_by_quitting_before_the_evening() -> void:
	_write_slot(1, 4, true)
	var snapshot_before: String = FileAccess.get_file_as_string(SaveService.snapshot_path(1, 4))
	var saved_at: String = str(SaveService.load_meta(1).get("saved_at"))
	assert_true(GameState.load_from_slot(1))
	assert_true(GameState.set_difficulty(GameState.DIFFICULTY_HARD))
	assert_eq(str(SaveService.load_meta(1).get("difficulty")), SaveService.DIFFICULTY_HARD, "méta à jour")
	assert_eq(str(SaveService.load_meta(1).get("saved_at")), saved_at, "pas une sauvegarde")
	assert_eq(FileAccess.get_file_as_string(SaveService.snapshot_path(1, 4)), snapshot_before, "instantané intact")
	assert_eq(SaveService.list_snapshots(1), PackedInt32Array([1, 2, 3, 4]))
	assert_true(GameState.load_from_slot())
	assert_eq(GameState.difficulty, GameState.DIFFICULTY_HARD, "jamais Dur → Récit, même en quittant")
	assert_true(GameState.load_day_snapshot(1, 2))
	assert_eq(GameState.difficulty, GameState.DIFFICULTY_HARD, "jour passé : reste en Dur")


## QA-047 : `holo_flicker` coupé laisse scintiller les néons instables et les
## écrans holo du guichet (`booth_emissive.gdshader`, réglé par `fx_intensity` seul).
func test_holo_flicker_off_also_freezes_booth_neons_and_screens() -> void:
	var emissive: ShaderMaterial = ShaderMaterial.new()
	emissive.shader = load("res://assets/shaders/booth_emissive.gdshader")
	var holo: ShaderMaterial = ShaderMaterial.new()
	holo.shader = load("res://assets/shaders/booth_holo.gdshader")
	var quality: BoothQuality = BoothQuality.new()
	quality.emissive_material = emissive
	quality.holo_material = holo
	add_child_autofree(quality)
	Settings.set_session_value(Settings.KEY_HOLO_FLICKER, false)
	quality.apply()
	assert_eq(holo.get_shader_parameter(&"flicker"), 0.0, "hologrammes figés")
	var value: Variant = emissive.get_shader_parameter(&"flicker")
	assert_not_null(value, "booth_emissive : uniforme flicker")
	if value == null:
		return
	assert_eq(float(value), 0.0, "néons instables et écrans holo figés")
