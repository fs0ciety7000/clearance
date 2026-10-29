## Correctifs UI de la passe QA M11 (docs/QA.md §14.7) — non-régression :
## - QA-041 : Ⓐ / Entrée activent le contrôle focalisé entre deux passagers ;
##   N et Ⓐ sur SUIVANT (ou sans focus actionnable) appellent le passager ;
## - QA-042 : carte du tutoriel à la croix (accueil piégé, étapes joignables
##   depuis SUIVANT, ← → ↓) et VUE maintenue = passer l'étape ;
## - QA-043 (UI) : emplacement endommagé (puce, REPRENDRE désactivé,
##   SUPPRIMER disponible, CONTINUER l'ignore) ;
## - QA-045 (UI) : grille des jours limitée aux matins lisibles, toast si un
##   chargement échoue malgré tout.
## Entrées : vrais événements de manette / clavier (`Input.parse_input_event`).
## Sauvegardes dans le dossier de test (`SaveService.use_root`).
extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const DAY_SCENE: PackedScene = preload("res://scenes/main/day.tscn")
const SEED: int = 20_871_315


func before_each() -> void:
	Settings.set_session_value(Settings.KEY_REDUCE_MOTION, true)
	_clear_slots()
	TutorialOverlay.pending = false


func after_each() -> void:
	Engine.time_scale = 1.0
	_clear_slots()
	Settings.clear_session_value(Settings.KEY_REDUCE_MOTION)
	Settings.set_value(Settings.KEY_TUTORIAL, true)
	TutorialOverlay.pending = false
	InputPrompts.simulate_device(InputPrompts.Device.KEYBOARD)
	get_tree().paused = false
	GameState.new_campaign(1)


func _clear_slots() -> void:
	for slot: int in range(1, SaveService.SLOT_COUNT + 1):
		SaveService.delete_slot(slot)


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


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


## Touche (keycode et touche physique identiques : Entrée, N).
func _key(key: Key) -> void:
	var down: InputEventKey = InputEventKey.new()
	down.keycode = key
	down.physical_keycode = key
	down.pressed = true
	Input.parse_input_event(down)
	await wait_process_frames(2)
	var up: InputEventKey = InputEventKey.new()
	up.keycode = key
	up.physical_keycode = key
	Input.parse_input_event(up)
	await wait_process_frames(3)


func _day(story: bool = false, tutorial: bool = false) -> DayScene:
	GameState.new_campaign(SEED, 1, GameState.DIFFICULTY_STORY if story else GameState.DIFFICULTY_HARD)
	TutorialOverlay.pending = tutorial
	var scene: DayScene = DAY_SCENE.instantiate()
	add_child_autofree(scene)
	await wait_process_frames(5)
	InputPrompts.simulate_device(InputPrompts.Device.XBOX)
	await _pad(JOY_BUTTON_A)
	await wait_process_frames(3)
	return scene


func _write_slot(slot: int, days: int) -> void:
	var data: Dictionary = {"campaign_seed": 900 + slot, "credits": 20 + slot, "score_total": 0, "citations": 0,
		"narrative_flags": {}, "day_history": [], "household": Household.new().to_dict(), "case_memory": {},
		"difficulty": "hard", "play_time_sec": 600 * slot}
	for day: int in range(1, days + 1):
		data["current_day"] = day
		SaveService.save_slot(data, slot, SaveService.DEFAULT_DIR, "2026-10-2%dT10:%02d:00" % [slot, day])


func _corrupt(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{\"version\": 6, \"current_d")
	file.close()


## Emplacement endommagé : `current.json` illisible, aucun instantané lisible,
## méta marquée `damaged` (champ ajouté par `SaveService.list_slots`).
func _damage_slot(slot: int, days: int) -> void:
	_corrupt(SaveService.slot_path(slot))
	for day: int in range(1, days + 1):
		if FileAccess.file_exists(SaveService.snapshot_path(slot, day)):
			DirAccess.remove_absolute(SaveService.snapshot_path(slot, day))
	var meta: Dictionary = SaveService.load_meta(slot)
	meta["damaged"] = true
	var file: FileAccess = FileAccess.open(SaveService.meta_path(slot), FileAccess.WRITE)
	file.store_string(JSON.stringify(meta))
	file.close()


func _main() -> Control:
	var main: Control = MAIN_SCENE.instantiate()
	main.set(&"change_scene", false)
	add_child_autofree(main)
	await wait_process_frames(3)
	return main


# ---------------------------------------------------------------------------
# QA-041 — Ⓐ / Entrée / N entre deux passagers
# ---------------------------------------------------------------------------

func test_keyboard_enter_on_close_booth_closes_and_n_still_calls_a_passenger() -> void:
	var scene: DayScene = await _day(true)
	var ui: ComparisonUI = scene.ui as ComparisonUI
	ui.set_close_booth_available(true)
	var closes: Array = []
	var nexts: Array = []
	ui.close_booth_requested.connect(func() -> void: closes.append(1))
	var on_next: Callable = func() -> void: nexts.append(1)
	EventBus.next_case_requested.connect(on_next)
	ui.top_bar.close_button.grab_focus()
	await _key(KEY_ENTER)
	assert_eq(closes.size(), 1, "Entrée sur FERMER LE GUICHET : guichet fermé")
	assert_eq(nexts.size(), 0, "Entrée n'appelle pas de passager")
	ui.top_bar.close_button.grab_focus()
	await _key(KEY_N)
	EventBus.next_case_requested.disconnect(on_next)
	assert_eq(nexts.size(), 1, "N appelle toujours le passager, quel que soit le focus")
	assert_eq(closes.size(), 1)


func test_pad_a_calls_the_passenger_from_next_or_without_actionable_focus() -> void:
	var scene: DayScene = await _day()
	var ui: ComparisonUI = scene.ui as ComparisonUI
	ui.tool_bar.next_button.grab_focus()
	assert_false(ui.focus_takes_accept(), "SUIVANT : Ⓐ appelle le passager")
	ui.tool_bar.inspect_button.grab_focus()
	assert_eq(ui.focus_takes_accept(), not ui.tool_bar.inspect_button.disabled, "bouton désactivé : pas actionnable")
	var nexts: Array = []
	var on_next: Callable = func() -> void: nexts.append(1)
	EventBus.next_case_requested.connect(on_next)
	ui.tool_bar.next_button.grab_focus()
	await _pad(JOY_BUTTON_A)
	EventBus.next_case_requested.disconnect(on_next)
	assert_eq(nexts.size(), 1, "Ⓐ sur SUIVANT : passager appelé")


func test_next_a_glyph_dims_when_a_would_press_another_control() -> void:
	var scene: DayScene = await _day(true)
	var ui: ComparisonUI = scene.ui as ComparisonUI
	ui.set_close_booth_available(true)
	ui.tool_bar.next_button.grab_focus()
	await wait_process_frames(2)
	assert_eq(ui.tool_bar.next_prompt_alpha(), 1.0, "focus sur SUIVANT : Ⓐ plein")
	await _pad(JOY_BUTTON_DPAD_UP)
	assert_eq(_focus(), ui.top_bar.close_button)
	assert_true(ui.tool_bar.next_prompt_dimmed)
	assert_almost_eq(ui.tool_bar.next_prompt_alpha(), DS.PROMPT_INACTIVE_ALPHA, 0.001, "focus sur FERMER LE GUICHET : Ⓐ atténué")
	InputPrompts.simulate_device(InputPrompts.Device.KEYBOARD)
	await wait_process_frames(2)
	assert_eq(ui.tool_bar.next_prompt_alpha(), 1.0, "clavier : N reste plein")
	InputPrompts.simulate_device(InputPrompts.Device.XBOX)
	await wait_process_frames(2)
	assert_almost_eq(ui.tool_bar.next_prompt_alpha(), DS.PROMPT_INACTIVE_ALPHA, 0.001)
	ui.top_bar.close_button.release_focus()
	await wait_process_frames(2)
	assert_eq(ui.tool_bar.next_prompt_alpha(), 1.0, "aucun focus : Ⓐ appelle le passager, glyphe plein")


# ---------------------------------------------------------------------------
# QA-042 — carte du tutoriel à la croix, VUE maintenue
# ---------------------------------------------------------------------------

func test_tutorial_intro_traps_the_dpad_between_its_two_buttons() -> void:
	var scene: DayScene = await _day(false, true)
	var tut: TutorialOverlay = scene.tutorial
	assert_eq(_focus(), tut.start_button)
	for dir: JoyButton in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
		tut.start_button.grab_focus()
		await _pad(dir)
		assert_eq(_focus(), tut.skip_all_button, "COMMENCER, croix %d : PASSER LE TUTORIEL" % dir)
		await _pad(dir)
		assert_eq(_focus(), tut.start_button, "PASSER LE TUTORIEL, croix %d : COMMENCER" % dir)


func test_tutorial_step_buttons_are_reachable_and_a_skips_the_step() -> void:
	var scene: DayScene = await _day(false, true)
	var tut: TutorialOverlay = scene.tutorial
	var ui: ComparisonUI = scene.ui as ComparisonUI
	await _pad(JOY_BUTTON_A)
	assert_eq(tut.current_step(), TutorialOverlay.Step.LOOK, "COMMENCER")
	assert_eq(_focus(), ui.tool_bar.next_button, "focus rendu à SUIVANT")
	await _pad(JOY_BUTTON_DPAD_UP)
	assert_eq(_focus(), tut.skip_step_button, "croix ↑ depuis SUIVANT : PASSER L'ÉTAPE")
	await _pad(JOY_BUTTON_DPAD_LEFT)
	assert_eq(_focus(), tut.skip_all_button, "croix ← : QUITTER")
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	assert_eq(_focus(), tut.skip_step_button, "croix → : PASSER L'ÉTAPE")
	var nexts: Array = []
	var on_next: Callable = func() -> void: nexts.append(1)
	EventBus.next_case_requested.connect(on_next)
	await _pad(JOY_BUTTON_A)
	EventBus.next_case_requested.disconnect(on_next)
	assert_eq(nexts.size(), 0, "Ⓐ sur PASSER L'ÉTAPE n'appelle pas de passager")
	assert_eq(tut.current_step(), TutorialOverlay.Step.INSPECT, "étape passée")
	assert_eq(_focus(), tut.skip_step_button, "focus gardé sur PASSER L'ÉTAPE")
	await _pad(JOY_BUTTON_DPAD_DOWN)
	assert_eq(_focus(), ui.tool_bar.next_button, "croix ↓ : retour au guichet")


func test_holding_view_skips_the_step_and_keeps_the_rulebook() -> void:
	var scene: DayScene = await _day(false, true)
	var tut: TutorialOverlay = scene.tutorial
	var ui: ComparisonUI = scene.ui as ComparisonUI
	tut.begin()
	await wait_process_frames(3)
	assert_eq(tut.current_step(), TutorialOverlay.Step.LOOK)
	var hint: Control = tut.find_child("SkipHold", true, false) as Control
	assert_not_null(hint, "invite « maintenir VUE »")
	if hint != null:
		assert_true(hint.visible, "invite visible à la manette")
	var collapsed: bool = ui.rulebook.collapsed
	await _pad(JOY_BUTTON_BACK)
	assert_eq(tut.current_step(), TutorialOverlay.Step.LOOK, "appui court : pas de saut")
	assert_ne(ui.rulebook.collapsed, collapsed, "appui court : Rulebook replié / déplié (inchangé)")
	await _pad(JOY_BUTTON_BACK)
	assert_eq(ui.rulebook.collapsed, collapsed)
	await _pad_hold(JOY_BUTTON_BACK, DS.SKIP_HOLD + 0.3)
	assert_eq(tut.current_step(), TutorialOverlay.Step.INSPECT, "VUE maintenue : étape passée")
	assert_eq(ui.rulebook.collapsed, collapsed, "Rulebook rétabli après le maintien")
	InputPrompts.simulate_device(InputPrompts.Device.KEYBOARD)
	await wait_process_frames(2)
	hint = tut.find_child("SkipHold", true, false) as Control
	if hint != null:
		assert_false(hint.visible, "invite masquée au clavier")


# ---------------------------------------------------------------------------
# QA-043 / QA-045 (UI) — Charger
# ---------------------------------------------------------------------------

func test_damaged_slot_card_disables_resume_and_keeps_delete() -> void:
	_write_slot(1, 3)
	_write_slot(2, 4)
	_damage_slot(2, 4)
	var main: Control = await _main()
	assert_eq(SaveSlotCard.continue_slot(), 1, "CONTINUER ignore l'emplacement endommagé")
	assert_string_contains((main.get(&"continue_button") as Button).text, "3", "CONTINUER — JOUR 3")
	var load_screen: LoadScreen = main.call(&"open_load")
	await wait_process_frames(3)
	var card: SaveSlotCard = load_screen.cards[1]
	assert_true(card.is_damaged())
	assert_not_null(card.find_child("Damaged", true, false), "puce SAUVEGARDE ENDOMMAGÉE")
	var chip_text: Array = []
	for label: Node in card.find_children("*", "Label", true, false):
		chip_text.append((label as Label).text)
	assert_has(chip_text, UiText.t("slot_damaged", "SAUVEGARDE ENDOMMAGÉE"), "texte, pas la couleur seule")
	var resume: Button = card.find_child("Resume2", true, false) as Button
	assert_not_null(resume, "REPRENDRE visible")
	if resume != null:
		assert_true(resume.disabled, "REPRENDRE désactivé")
		assert_eq(resume.focus_mode, Control.FOCUS_NONE, "sauté par la croix")
	assert_false(load_screen.resume_buttons.has(2))
	assert_eq(_focus(), load_screen.resume_buttons[1], "focus : REPRENDRE de la partie de Continuer")
	assert_true(load_screen.delete_buttons.has(2), "SUPPRIMER disponible")
	load_screen.press_delete(2)
	load_screen.press_delete(2)
	assert_true(SaveService.load_meta(2).is_empty(), "emplacement endommagé supprimé")


func test_damaged_meta_read_defensively() -> void:
	assert_false(SaveSlotCard.is_meta_damaged({}))
	assert_false(SaveSlotCard.is_meta_damaged({"damaged": false}))
	assert_false(SaveSlotCard.is_meta_damaged({"damaged": "oui"}))
	assert_true(SaveSlotCard.is_meta_damaged({"damaged": true}))
	assert_true(SaveSlotCard.is_meta_damaged({"damaged": 1.0}))


func test_day_grid_lists_only_readable_mornings() -> void:
	_write_slot(3, 5)
	_corrupt(SaveService.snapshot_path(3, 3))
	_corrupt(SaveService.snapshot_path(3, 6) + SaveService.TMP_SUFFIX)
	var main: Control = await _main()
	var load_screen: LoadScreen = main.call(&"open_load")
	await wait_process_frames(3)
	assert_eq(load_screen.loadable_days(3), PackedInt32Array([1, 2, 4, 5]))
	load_screen.open_day_picker(3)
	await wait_process_frames(3)
	var shown: Array = load_screen.picker_buttons.keys()
	shown.sort()
	assert_eq(shown, [1, 2, 4, 5], "ni J3 illisible ni J6 orphelin")
	assert_eq(_focus(), load_screen.picker_buttons[5], "focus : dernier matin lisible")


func test_failed_day_load_shows_a_toast_and_drops_the_day() -> void:
	_write_slot(3, 4)
	var main: Control = await _main()
	var load_screen: LoadScreen = main.call(&"open_load")
	await wait_process_frames(3)
	load_screen.open_day_picker(3)
	await wait_process_frames(3)
	# Le fichier s'abîme après l'ouverture de la grille.
	_corrupt(SaveService.snapshot_path(3, 4))
	var loaded: bool = main.call(&"resume_day", 3, 4)
	await wait_process_frames(3)
	assert_false(loaded)
	assert_eq(load_screen.toasts.get_child_count(), 1, "toast « CHARGEMENT IMPOSSIBLE »")
	var shown: Array = load_screen.picker_buttons.keys()
	shown.sort()
	assert_eq(shown, [1, 2, 3], "matin illisible retiré de la grille")
	assert_eq(_focus(), load_screen.picker_buttons[3])
